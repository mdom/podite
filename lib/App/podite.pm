package App::podite;
use Mojo::Base -base;

use Mojo::Feed::Reader;
use Mojo::SQLite;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Loader qw(data_section);
use Mojo::Template;
use Mojo::URL;
use Mojo::Util 'slugify', 'encode', 'tablify';
use Mojo::ByteStream 'b';
use Mojo::Date;
use Mojo::Collection 'c';

use App::podite::Directory;
use App::podite::Render 'render_content';
use App::podite::URLQueue;
use App::podite::Util 'path';
use App::podite::Migrations;
use App::podite::Model::Feeds;
use App::podite::Model::Items;
use App::podite::Model::SearchResults;

our $VERSION = "0.03";

has ua => sub {
    my $self = shift;
    my $ua = Mojo::UserAgent->new( max_redirects => 5 );
    $ua->transactor->name("podite/$VERSION (+https://github.com/mdom/podite)");
    $ua->proxy->detect;
    return $ua;
};

has share_dir => sub {
    my $dir =
        $^O eq 'darwin'     ? "$ENV{HOME}/Library/Application Support"
      : $^O eq 'MSWin32'    ? $ENV{APPDATA}
      : $ENV{XDG_DATA_HOME} ? $ENV{XDG_DATA_HOME}
      :                       "$ENV{HOME}/.local/share";
    path($dir)->child('podite')->make_path;
};

has feeds => sub { App::podite::Model::Feeds->new( sql => shift->sqlite ) };
has items => sub { App::podite::Model::Items->new( sql => shift->sqlite ) };
has search_results =>
  sub { App::podite::Model::SearchResults->new( sql => shift->sqlite ) };

has sqlite => sub {
    my $db     = shift->share_dir->child('podite.sqlite');
    my $sqlite = Mojo::SQLite->new("sqlite:$db");
    $sqlite->auto_migrate(1)->migrations->from_data('App::podite::Migrations');
    return $sqlite;
};

has db => sub { shift->sqlite->db };

has cache_dir => sub {
    shift->share_dir->child('cache')->make_path;
};

has feedr => sub {
    Mojo::Feed::Reader->new;
};

has config => sub {
    {
        download_dir    => "~/Podcasts",
        output_template => '<%= "$feed_title/$title.$ext" %>'
    }
};

sub add_feed {
    my ( $self, @urls ) = @_;
    my @updates;
    for my $url (@urls) {
        $url = Mojo::URL->new($url)->to_string;
        eval { $self->feeds->add_or_update( { url => $url } ) };
    }
    $self->update(@urls);
    return;
}

sub export_opml {
    my ($self) = @_;
    my $mt = Mojo::Template->new( vars => 1 );
    $mt->parse( data_section(__PACKAGE__)->{'template.opml'} );
    print b( $mt->process( { feeds => $self->feeds->find->to_array } ) )
      ->encode;
    return;
}

sub status {
    my ($self) = @_;
    my $feeds = $self->feeds->status;
    $self->feeds->save_order($feeds);
    print tablify(
        $feeds->map(
            sub {
                [
                    $_->{list_order}, $_->{title},
                    $_->{new} || 0, $_->{seen} || 0,
                    $_->{total}
                ];
            }
        )->to_array
    );
}

sub render_item {
    my ( $self, $item ) = @_;

    my $summary = substr( render_content($item) || '', 0, 360 );
    return encode 'UTF-8',
        $item->{list_order} . ' '
      . $item->{feed_title} . ': '
      . $item->{title} . "\n"
      . $summary . "\n";
}

sub download {
    my ( $self, $selection ) = @_;

    my @downloads = $self->items->find_selection($selection)->each;
    my %feeds = map { $_->{url} => $_ } $self->feeds->find->each;

    return if !@downloads;

    my $q = App::podite::URLQueue->new( ua => $self->ua );
    for my $item (@downloads) {
        my $download_url = Mojo::URL->new( $item->{enclosure} );
        my $output_filename =
          $self->output_filename( $item, $feeds{ $item->{feed_url} } );
        $output_filename->dirname->make_path;
        say "$download_url -> $output_filename";
        $q->add(
            $download_url => sub {
                my ( $ua, $tx, ) = @_;
                $tx->result->content->asset->move_to($output_filename);
                $self->items->set_state( downloaded => { id => $item->{id} } );
                warn "Download $output_filename finished\n";
            }
        );
    }
    return $q->wait;
}

sub output_filename {
    my ( $self, $item, $feed ) = @_;
    my $template = $self->config->{output_template};

    my $mt = Mojo::Template->new( vars => 1 );
    my $remote_filename =
      Mojo::URL->new( $item->{enclosure} )->path->parts->[-1];
    my $download_dir = path( $self->config->{download_dir} );
    my ($remote_ext) = $remote_filename =~ /\.([^.]+)$/;
    my $filename     = $mt->render(
        $template,
        {
            filename     => $remote_filename || '',
            feed_title   => slugify( $feed->{title}, 1 ) || '',
            title        => slugify( $item->{title}, 1 ) || '',
            ext          => $remote_ext || '',
            download_dir => $download_dir,
        }
    );
    chomp($filename);
    my $file = path($filename);

    if ( !$file->is_abs ) {
        $file = $download_dir->child($file);
    }
    return $file;
}

sub update {
    my ( $self, @urls ) = @_;
    if ( !@urls ) {
        @urls = $self->feeds->all_urls;
    }
    my $q = App::podite::URLQueue->new( ua => $self->ua );

    $self->items->set_state( 'seen', { state => 'new' } );

    for my $url (@urls) {

        my $feed = $self->feeds->find( { url => $url } )->first;

        my $tx = $self->ua->build_tx( GET => $url );
        if ( $feed && $feed->{last_modified} ) {
            $tx->req->headers->if_modified_since( $feed->{last_modified} );
        }
        $q->add(
            $tx => sub {
                $self->handle_response( $url, @_ );
            }
        );
    }
    return $q->wait;
}

sub handle_response {
    my ( $self, $url, $ua, $tx ) = @_;
    if ( my $res = $tx->success ) {
        return if $res->code eq 304;
        if ( $res->code eq 200 ) {
            my $body = $res->body;
            my $feed = $self->feedr->parse($body);
            if ( !$feed ) {
                warn "Can't parse $url as feed.\n";
                return;
            }

            $self->feeds->add_or_update(
                {
                    url           => $url,
                    title         => $feed->title,
                    last_modified => $res->headers->last_modified
                      || Mojo::Date->new,
                }
            );
            $feed->items->each(
                sub {
                    my $enclosure = $_->enclosures->first;
                    return if !$enclosure;
                    $self->items->add_or_update(
                        $url,
                        {
                            title       => $_->title,
                            content     => $_->content,
                            description => $_->description,
                            published   => $_->published,
                            guid        => $_->id,
                            enclosure   => $_->enclosures->first->url,
                        }
                    );
                }
            );
        }
        else {
            my $err = $tx->error;
            warn "$err->{code} response for $url: $err->{message}"
              if $err->{code};
            warn "Connection error for $url: $err->{message}\n";
        }
    }
}

1;

__DATA__

@@ template.opml

<?xml version="1.0" encoding="utf-8"?>
<opml version="1.0">
	<head>
		<title>My Feeds</title>
	</head>
	<body>
% for my $feed ( @$feeds ) {
		<outline text="<%== $feed->{title} %>" type="rss" xmlUrl="<%== $feed->{url} %>" />
% }
	</body>
</opml>

__END__

=head1 NAME

podite - Command line podcast aggregator

=head1 SYNOPSIS

  podite

=head1 DESCRIPTION

podite downloads podcasts from a set of subscribed rss and atom feeds. It
is optimized for users that don't want to download every podcast from
the feed.  Instead of loading every podcast, it queries the users which
podcasts to download.

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Mario Domgoergen E<lt>mario@domgoergen.com<gt>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 AUTHOR

Mario Domgoergen E<lt>mario@domgoergen.comE<gt>

=cut

