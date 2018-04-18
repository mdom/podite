package App::podite;
use Mojo::Base -base;

use Fcntl qw(:flock O_RDWR O_CREAT);
use File::stat;
use Mojo::Feed::Reader;

use Mojo::JSON qw(encode_json decode_json);
use Mojo::Loader qw(data_section);
use Mojo::Template;
use Mojo::URL;
use Mojo::Util 'slugify', 'encode';
use Mojo::ByteStream 'b';

use App::podite::Directory;
use App::podite::Render 'render_content';
use App::podite::UI qw(menu choose_one choose_many prompt list_things yesno);
use App::podite::URLQueue;
use App::podite::Util 'path';

use App::podite::new;
use OptArgs2;

cmd 'App::podite' => (
    comment => '',
    optargs => sub {
        arg command => (
            isa      => 'SubCmd',
            comment  => '',
            required => 1,
            abbrev   => 1,
        );
    },
);

subcmd 'App::podite::new' =>
  ( comment => 'Update all feeds and list new episodes' );

subcmd 'App::podite::update' =>
  ( comment => 'Update all feeds and list feeds' );

subcmd 'App::podite::status' => ( comment => 'List feeds' );

subcmd 'App::podite::download' => (
    comment => 'Download episodes',
    optargs => sub {
        arg list => (
            comment  => 'List of episodes to download',
            isa      => 'Str',
            greedy   => 1,
            required => 1,
        );
    },
);

subcmd 'App::podite::opml' => (
    comment => 'Import or export opml',
    optargs => sub {
        arg command => (
            isa      => 'SubCmd',
            comment  => '',
            required => 1,
            abbrev   => 1,
        );
    },
);

subcmd 'App::podite::opml::import' =>
  ( comment => 'Import feeds from opml file' );
subcmd 'App::podite::opml::export' => (
    comment => 'Export feeds to opml file',
    optargs => sub {
        arg opml_file =>
          ( isa => 'Str', comment => 'Target file', required => 1 );
    },
);

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

has state_file => sub {
    shift->share_dir->child('state');
};

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

has 'state_fh';

has state => sub {
    shift->read_state;
};

has needs_update => 0;

has feeds => sub {
    my $self = shift;
    if ( $self->needs_update ) {
        $self->download_feeds;
    }
    $self->load_feeds;
};

sub get_config {
    my ( $self, $key ) = @_;
    return $self->config->{$key} || $self->defaults->{$key};
}

sub flush {
    my $self = shift;
    if ( $self->state_fh ) {
        $self->write_state;
    }
    return;
}

sub query_feeds {
    my ( $self, $filter ) = @_;
    $filter ||= sub { $self->is_active( $_[0] ) };
    my $query = [
        map { [ $_->title => $_ ] }
        grep { $filter->($_) } $self->sort_feeds('title')
    ];
    return $query;
}

sub items {
    my ( $self, @feeds ) = @_;
    return (
        sort { $b->published <=> $a->published }
        map  { $_->items->each } @feeds
    );
}

sub add_feed {
    my ( $self, @urls ) = @_;
    for my $url (@urls) {
        next if $self->state->{subscriptions}->{$url};
        $url = Mojo::URL->new($url)->to_string;
        $self->download_feeds($url);
        my $feeds = $self->load_feeds($url);
        if ( $feeds->{$url} ) {
            $self->state->{subscriptions}->{$url} = {};
            $self->feeds->{$url} = $feeds->{$url};
        }
    }
    return;
}

sub change_feed_url {
    my ( $self, $feed, $new_url ) = @_;
    if ( $feed && $new_url ) {
        my $old_url = $feed->source;
        $self->feeds->{$new_url} = delete $self->feeds->{$old_url};
        $self->state->{subscriptions}->{$new_url} =
          delete $self->state->{subscriptions}->{$old_url};
        $self->cache_file($old_url)
          ->move_to( $self->cache_file($new_url)->to_string );
    }
    return;
}

sub delete_feed {
    my ( $self, @feeds ) = @_;
    for my $feed (@feeds) {
        my $url = $feed->source;
        delete $self->feeds->{$url};
        delete $self->state->{subscriptions}->{$url};
        unlink $self->cache_file($url)->to_string;
    }
    return;
}

sub activate_feed {
    my ( $self, $feeds ) = @_;
    for my $feed (@$feeds) {
        my $url = $feed->source;
        $self->state->{subscriptions}->{$url}->{inactive} = 0;
        $self->download_feeds($url);
    }
    return;
}

sub deactivate_feed {
    my ( $self, $feeds ) = @_;
    for my $feed (@$feeds) {
        my $url = $feed->source;
        $self->state->{subscriptions}->{$url}->{inactive} = 1;
    }
    return;
}

sub is_active {
    my ( $self, $feed ) = @_;
    return !$self->state->{subscriptions}->{ $feed->source }->{inactive};
}

=pod
            "manage feeds" => [ sub { $self->submenu_manage_feeds } ],
            configure => [ sub { $self->submenu_configure } ],
        ]
    );
}

sub submenu_manage_feeds {
    my ($self) = @_;
    my @commands = (
        'add feed' => [
            'add feed with url' => sub {
                my $url = prompt('url for new feed');
                return 1 if !$url;
                $self->add_feed($url);
                return 1;
            },
            'search and add feed' => sub {
                my $term = prompt('search term') or return 1;

                my $result = $self->directory->search($term);
                if ( !@$result ) {
                    warn "No results.\n";
                    return 1;
                }

                my $selection = [
                    map {
                        [ $_->{title} . "(" . $_->{website} . ")", $_->{url} ]
                    } @$result
                ];
                my $selected = choose_many( $term => $selection );
                $self->add_feed(@$selected) if $selected;
                return 1;
            },
        ],
        'delete feed' => sub {
            my $feeds =
              choose_many( 'which feeds' => sub { $self->query_feeds } )
              or return 1;
            $self->delete_feed(@$feeds);
            return 1;
        },
        'change feed url' => sub {
            my $feed = choose_one( 'change feed', sub { $self->query_feeds } )
              or return 1;

            my $new_url = prompt('new url for feed') or return 1;

            $self->change_feed_url( $feed, $new_url );
            return 1;
        },
        'import feeds from opml' => sub {
            my $file = prompt('filename');
            return 1 if !$file;
            if ( !-e $file ) {
                warn "File $file not found.\n";
                return 1;
            }
            my @subscriptions = $self->feedr->parse_opml( path($file) );
            if (@subscriptions) {
                my $new_feeds =
                  choose_many( 'which feeds' =>
                      [ map { [ $_->{text} => $_->{xmlUrl} ] } @subscriptions ]
                  );
                if ($new_feeds) {
                    $self->add_feed(@$new_feeds);
                }
            }
            return 1;
        },
    );

    my @feeds    = values %{ $self->feeds };
    my $active   = grep { $self->is_active($_) } @feeds;
    my $inactive = @feeds - $active;

    if ($active) {
        push @commands, 'deactivate feed' => sub {
            my $feed = choose_many( 'change feed', sub { $self->query_feeds } )
              or return 1;
            $self->deactivate_feed($feed);
            return 1;
        };
    }

    if ($inactive) {
        push @commands, 'activate feed' => sub {
            my $feed = choose_many(
                'change feed',
                sub {
                    $self->query_feeds( sub { !$self->is_active( $_[0] ) } );
                }
            ) or return 1;
            $self->activate_feed($feed);
            return 1;
        };
    }

    return \@commands;
}

sub submenu_configure {
    my $self = shift;
    my @commands;
    for my $key ( sort keys %{ $self->defaults } ) {
        my $val = $self->get_config($key);
        push @commands, "$key ($val)" => sub {
            my $arg = prompt($key);
            return if !defined $arg;
            ## TODO Check if output_filename compiles and give the user an example
            $self->config->{$key} = $arg;
        };
    }
    return \@commands,;
}

=cut

sub export_opml {
    my ( $self, $file ) = @_;
    my $mt = Mojo::Template->new( vars => 1 );
    $mt->parse( data_section(__PACKAGE__)->{'template.opml'} );
    $file->spurt( b( $mt->process( { feeds => [ values %{ $self->feeds } ] } ) )
          ->encode );
    return;
}

sub item_is_new {
    my ( $self, $item ) = @_;
    return !$self->item_state($item);
}

sub sort_feeds {
    my ( $self, $sort_by ) = @_;
    my @feeds = values %{ $self->feeds };
    if ( $sort_by eq 'title' ) {
        return ( sort { lc( $a->title ) cmp lc( $b->title ) } @feeds );
    }
    elsif ( $sort_by eq 'added' ) {
        my $states = $self->state->{subscriptions};
        return map { $_->[1] }
          sort     { $a->[0] cmp $b->[0] }
          map { [ $states->{ $_->source }->{date_added}, $_ ] } @feeds;
    }
    die "Unknown sort key\n";
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
    $self->list( [ map { sprintf( $fmt, @$_ ) } @rows ] );
    return 1;
}

sub render_item {
    my ( $self, $item ) = @_;

    my $summary = substr( render_content($item) || '', 0, 120 );
    return $item->feed->title . ': ' . $item->title . "\n" . $summary . "\n";
}

sub hide {
    my ( $self, $hide ) = @_;
    if ($hide) {
        for my $item (@$hide) {
            $self->item_state( $item => 'hidden' );
        }
    }
    return;
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

sub list {
    my ( $self, $list ) = @_;
    $self->state->{last_list} = $list;
    return list_things($list);
}

sub choose {
    my ( $self, $k ) = @_;
    my $things   = $self->state->{last_list};
    my @list     = App::podite::UI::expand_list( $k, scalar @$things );
    my @selected = @{$things}[ map { $_ - 1 } @list ];

    if (@selected) {
        my @things =
          map { ref($_) eq 'ARRAY' && @$_ == 2 ? $_->[1] : $_ } @selected;
        for my $thing (@things) {
            if ( ref $thing eq 'ARRAY' && $thing->[0] eq 'episode' ) {
                ($thing) = grep { $_->id eq $thing->[2] }
                  $self->feeds->{ $thing->[1] }->items->each;
            }
        }
        return \@things;
    }
    return;
}

sub cache_file {
    my ( $self, $url ) = @_;
    return $self->cache_dir->child( slugify($url) );
}

sub download_feeds {
    my ( $self, @urls ) = @_;
    if ( !@urls ) {
        @urls = keys %{ $self->state->{subscriptions} };
    }

    my $q = App::podite::URLQueue->new( ua => $self->ua );
    for my $url (@urls) {
        my $cache_file = $self->cache_file($url);
        my $tx = $self->ua->build_tx( GET => $url );
        if ( -e $cache_file ) {
            my $date = Mojo::Date->new( stat($cache_file)->mtime );
            $tx->req->headers->if_modified_since($date);
        }
        warn "Updating $url.\n";

        $q->add(
            $tx => sub {
                my ( $ua, $tx ) = @_;
                if ( my $res = $tx->success ) {
                    if ( $res->code eq 200 ) {
                        my $body = $res->body;
                        open( my $fh, '>', $cache_file )
                          or die "Can't open cache file $cache_file: $!\n";
                        print $fh $body;
                        close($fh);
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

sub load_feeds {
    my ( $self, @urls ) = @_;
    if ( !@urls ) {
        @urls = keys %{ $self->state->{subscriptions} };
    }
    my %feeds;
    for my $url (@urls) {

        my $cache_file = $self->cache_file($url);

        $cache_file = $self->cache_file($url) if !$cache_file;
        next if !-r $cache_file;
        if ( my $feed = $self->feedr->parse($cache_file) ) {
            $feed->source( Mojo::URL->new($url) );
            $feeds{$url} = $feed;
        }
    }

    return \%feeds;
}

sub write_state {
    my ($self) = @_;
    seek $self->state_fh, 0, 0;
    truncate $self->state_fh, 0;
    return print { $self->state_fh } encode_json( $self->state );
}

sub read_state {
    my ($self)     = @_;
    my $state_file = path( $self->state_file );
    my $fh         = $state_file->open( O_RDWR | O_CREAT )
      or die "Can't open state file $state_file: $!\n";
    flock( $fh, LOCK_EX | LOCK_NB )
      or die "Cannot lock $state_file: $!\n";
    my $content = $state_file->slurp;
    my $json = decode_json( $content || '{}' );
    $self->state_fh($fh);
    return $json;
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

