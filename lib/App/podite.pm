package App::podite;
use Mojo::Base -base;

use Mojo::Feed::Reader;
use Mojo::SQLite;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Loader qw(data_section);
use Mojo::Template;
use Mojo::URL;
use Mojo::Util 'slugify', 'encode';
use Mojo::ByteStream 'b';
use Mojo::Date;

use App::podite::Directory;
use App::podite::Render 'render_content';
use App::podite::URLQueue;
use App::podite::Util 'path';
use App::podite::Migrations;
use App::podite::Model::Feeds;
use App::podite::Model::Items;

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

has defaults => sub {
    {
        download_dir    => "~/Podcasts",
        output_template => '<%= "$feed_title/$title.$ext" %>'
    }
};

has directory => sub {
    App::podite::Directory->new;
};

has config => sub {
    my $self = shift;
    if ( !$self->state->{config} ) {
        $self->state->{config} = {};
    }
    return $self->state->{config};
};

sub get_config {
    my ( $self, $key ) = @_;
    return $self->config->{$key} || $self->defaults->{$key};
}

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
    my ( $self, $file ) = @_;
    my $mt = Mojo::Template->new( vars => 1 );
    $mt->parse( data_section(__PACKAGE__)->{'template.opml'} );
    $file->spurt(
        b( $mt->process( { feeds => [ values %{ $self->feeds } ] } ) )
          ->encode );
    return;
}

sub status {
    my ($self) = @_;
    my @rows;
    my @spec;
    my @feeds = grep { $self->is_active($_) } $self->sort_feeds('title');
    for my $feed (@feeds) {
        my @items = $feed->items->each;
        my ( $skipped, $new, $total ) = ( 0, 0, scalar @items );
        for my $item (@items) {
            if ( my $state = $self->item_state($item) ) {
                for ($state) {
                    /^(downloaded|hidden)$/ && next;
                    /^skipped$/ && do { $skipped++; next };
                }
            }
            else {
                $new++;
            }
        }
        my @row = ( $new, $skipped, $total, $feed->title );
        for my $i ( 0 .. 2 ) {
            my $len = length( $row[$i] );
            $spec[$i] = $len if $len >= ( $spec[$i] // 0 );
        }
        push @rows, \@row;
    }
    my $fmt = join( ' / ', map { "\%${_}d" } @spec ) . "   %s";
    list_things( [ map { sprintf( $fmt, @$_ ) } @rows ] );
    return 1;
}

sub render_item {
    my ( $self, $item ) = @_;

    my $summary = substr( render_content($item) || '', 0, 120 );
    return $item->feed->title . ': ' . $item->title . "\n" . $summary . "\n";
}

sub download {
    my ( $self, $feeds, $filter ) = @_;

    return 1 if !$feeds;
    return 1 if !@$feeds;
    $filter = $filter ? $filter : sub { 1 };

    my @items = grep { $filter->($_) }
      sort { $a->published <=> $b->published }
      map  { $_->items->each } @$feeds;

    if ( !@items ) {
        warn "No episodes found.\n";
        return 1;
    }

    my $selection = [ map { [ $self->render_item($_), $_ ] } @items ];

    my %skipped = map { $_->id => $_ } @items;

    my $downloads = choose_many( 'download', $selection );
    my $hide = choose_many( 'hide', $selection, hide => 1 );

    if ($hide) {
        for my $item (@$hide) {
            $self->item_state( $item => 'hidden' );
            delete $skipped{ $item->id };
        }
    }

    ## ensures that elements that are in $hide and $downloads remain
    ## skipped until downloaded
    if ($downloads) {
        for my $item (@$downloads) {
            $skipped{ $item->id } = $item;
        }
    }

    for my $item ( values %skipped ) {
        $self->item_state( $item => 'skipped' );
    }

    return if !$downloads;

    my $q = App::podite::URLQueue->new( ua => $self->ua );
    for my $item (@$downloads) {
        my $download_url = Mojo::URL->new( $item->enclosures->[0]->url );
        my $output_filename = $self->output_filename( $item => $download_url );
        $output_filename->dirname->make_path;
        say "$download_url -> $output_filename";
        $q->add(
            $download_url => sub {
                my ( $ua, $tx, ) = @_;
                $tx->result->content->asset->move_to($output_filename);
                $self->item_state( $item => 'downloaded' );
                warn "Download $output_filename finished\n";
            }
        );
    }
    return $q->wait;
}

sub item_state {
    my ( $self, $item, $state ) = @_;
    my $url       = $item->feed->source;
    my $feed      = $self->state->{subscriptions}->{$url};
    my $old_state = $feed->{items}->{ $item->id };
    if ($state) {
        ## Do not overwrite process state with user decision
        if (   ( $old_state || '' ) eq 'downloaded'
            && ( $state eq 'skipped' || $state eq 'hidden' ) )
        {
            return $old_state;
        }
        return $feed->{items}->{ $item->id } = $state;
    }
    return $old_state;
}

sub output_filename {
    my ( $self, $item, $url ) = @_;
    my $template = $self->get_config('output_template');

    my $feed            = $item->feed;
    my $mt              = Mojo::Template->new( vars => 1 );
    my $remote_filename = $url->path->parts->[-1];
    my $download_dir    = path( $self->get_config('download_dir') );
    my ($remote_ext)    = $remote_filename =~ /\.([^.]+)$/;
    my $filename        = $mt->render(
        $template,
        {
            filename     => $url->path->parts->[-1],
            feed_title   => slugify( $feed->title, 1 ),
            title        => slugify( $item->title, 1 ),
            ext          => $remote_ext,
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

sub cache_feed {
    my ( $self, $url, $feed ) = @_;
    if ($feed) {
        $feed->source( Mojo::URL->new($url) );
        $self->feeds->{$url} = $feed;
    }
    return;
}

sub read_cached_feed {
    my ( $self, $url, $cache_file ) = @_;
    if ( -r $cache_file ) {
        $self->cache_feed( $url => $self->feedr->parse($cache_file) );
    }
    return;
}

sub update {
    my ( $self, @urls ) = @_;
    if ( !@urls ) {
        @urls = $self->feeds->all_urls;
    }
    my $q = App::podite::URLQueue->new( ua => $self->ua );
  Feed:
    for my $url (@urls) {

        my $feed = $self->feeds->find( { url => $url } )->first;

        my $tx = $self->ua->build_tx( GET => $url );
        if ( $feed && $feed->{last_modified} ) {
            $tx->req->headers->if_modified_since( $feed->{last_modified} );
        }
        $q->add(
            $tx => sub {
                my ( $ua, $tx ) = @_;
                if ( my $res = $tx->success ) {
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
                            sub { $self->items->add_or_update( $url, $_ ) } );
                    }
                }
                else {
                    my $err = $tx->error;
                    warn "$err->{code} response for $url: $err->{message}"
                      if $err->{code};
                    warn "Connection error for $url: $err->{message}\n";
                }
            }
        );
    }
    return $q->wait;
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
		<outline text="<%== $feed->title %>"<% if ($feed->description) { %> description="<%== $feed->description %>" <% } %>type="rss" xmlUrl="<%== $feed->source %>" />
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

