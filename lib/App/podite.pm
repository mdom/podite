package App::podite;
use Mojo::Base -base;

use Mojo::Feed::Reader;
use Mojo::URL;
use Mojo::Template;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Util 'slugify', 'encode';
use Fcntl qw(:flock O_RDWR O_CREAT);
use App::podite::URLQueue;
use App::podite::UI qw(menu choose_one choose_many prompt);
use App::podite::Util 'path';
use App::podite::Render 'render_content';
use App::podite::Directory;
use File::stat;
use Scalar::Util 'refaddr';

our $VERSION = "0.01";

has ua => sub {
    my $self = shift;
    my $ua = Mojo::UserAgent->new( max_redirects => 5 );
    $ua->transactor->name("podite/$VERSION (+https://github.com/mdom/podite)");
    return $ua;
};

has share_dir => sub {
    path("$ENV{HOME}/.local/share/podite/");
};

has state_file => sub {
    shift->share_dir->child('state');
};

has cache_dir => sub {
    shift->share_dir->child('cache');
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

has feeds => sub { {} };

sub get_config {
    my ( $self, $key ) = @_;
    $self->config->{$key} || $self->defaults->{$key};
}

sub DESTROY {
    my $self = shift;
    if ( $self->state_fh ) {
        $self->write_state;
    }
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
    sort { $b->published <=> $a->published } map { $_->items->each } @feeds;
}

sub add_feed {
    my ( $self, $url ) = @_;
    if ($url) {
        $url = Mojo::URL->new($url)->to_string;
        $self->update($url);
        if ( $self->feeds->{$url} && !$self->state->{subscriptions}->{$url} ) {
            $self->state->{subscriptions}->{$url} =
              {};
        }
    }
    return;
}

sub change_feed_url {
    my ( $self, $feed, $new_url ) = @_;
    if ( $feed && $new_url ) {
        $self->feeds->{$new_url} = delete $self->feeds->{ $feed->source };
        $self->state->{subscriptions}->{$new_url} =
          delete $self->state->{subscriptions}->{ $feed->source };
        $self->cache_dir->child( slugify( $feed->source ) )
          ->move_to( $self->cache_dir->child( slugify($new_url) )->to_string );
    }
    return;
}

sub delete_feed {
    my ( $self, $feeds ) = @_;
    for my $feed (@$feeds) {
        delete $self->feeds->{ $feed->source };
        delete $self->state->{subscriptions}->{ $feed->source };
        unlink $self->cache_dir->child( slugify( $feed->source ) )->to_string;
    }
    return;
}

sub activate_feed {
    my ( $self, $feeds ) = @_;
    for my $feed (@$feeds) {
        my $url = $feed->source;
        $self->state->{subscriptions}->{$url}->{inactive} = 0;
        $self->update($url);
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

sub run {

    my ( $self, @argv ) = @_;

    $self->ua->proxy->detect;

    $self->share_dir->make_path;
    $self->cache_dir->make_path;

    $self->update;

    if ( my $cmd = shift @argv ) {
        if ( $cmd eq 'new' ) {
            $self->download(
                [ values %{ $self->feeds } ],
                sub { $self->item_is_new( $_[0] ) }
            );
            exit 0;
        }
    }

    menu(
        {
            run_on_startup => sub { $self->status },
            commands       => [
                sub { $self->submenu_manage_feeds },
                {
                    title  => 'status',
                    action => sub { $self->status; return 1; },
                },
                {
                    title  => 'update',
                    action => sub { $self->update; $self->status; return 1; },
                },
                {
                    title  => 'download',
                    action => sub {
                        my $feeds = choose_many(
                            'filter by feed' => sub { $self->query_feeds } );
                        return 1 if !$feeds || !@$feeds;

                        my $filter = choose_one(
                            'filter by state' => [
                                [ all => sub { 1 } ],
                                [
                                    new => sub {
                                        $self->item_is_new( $_[0] );
                                    },
                                ],
                                [
                                    'new & skipped' => sub {
                                        my $state = $self->item_state($_);
                                        !$state || $state eq 'skipped';
                                    }
                                ],
                            ]
                        );
                        return 1 if !$filter;
                        $self->download( $feeds, $filter );
                        return 1;
                    },
                },
                sub { $self->submenu_configure },
                {
                    title  => 'quit',
                    action => sub { 0 },
                },
            ],
        }
    );

    say "Bye.";
    exit 0;
}

sub is_active {
    my ( $self, $feed ) = @_;
    !$self->state->{subscriptions}->{ $feed->source }->{inactive};
}

sub submenu_manage_feeds {
    my ($self) = @_;
    my @commands = (
        {
            title    => 'add feed',
            commands => [
                {
                    title  => 'add feed with url',
                    action => sub {
                        my $url = prompt('url for new feed');
                        return 1 if !$url;
                        $self->add_feed($url);
                        return 1;
                    },
                },
                {
                    title  => 'search and add feed',
                    action => sub {
                        my $term = prompt('search term');
                        return 1 if !$term;

                        my $result = $self->directory->search($term);
                        if ( !@$result ) {
                            warn "No results.\n";
                            return 1;
                        }

                        my $selection = [
                            map {
                                [
                                    $_->{title} . "(" . $_->{website} . ")",
                                    $_->{url}
                                ]
                            } @$result
                        ];
                        my $selected = choose_many( $term => $selection );
                        $self->add_feed(@$selected) if $selected;
                        return 1;
                    },
                },
            ]
        },
        {
            title  => 'delete feed',
            action => sub {
                my $feeds =
                  choose_many( 'which feeds' => sub { $self->query_feeds } );
                return 1 if !$feeds;
                $self->delete_feed($feeds);
                return 1;
            },
        },
        {
            title  => 'change feed url',
            action => sub {
                my $feed =
                  choose_one( 'change feed', sub { $self->query_feeds } );
                return 1 if !$feed;

                my $new_url = prompt('new url for feed');
                return 1 if !$new_url;

                $self->change_feed_url( $feed, $new_url );
                return 1;
            },
        },
    );

    my @feeds    = values %{ $self->feeds };
    my $active   = grep { $self->is_active($_) } @feeds;
    my $inactive = @feeds - $active;

    if ($active) {
        push @commands, {
            title  => 'deactivate feed',
            action => sub {
                my $feed =
                  choose_many( 'change feed', sub { $self->query_feeds } );
                return 1 if !$feed;
                $self->deactivate_feed($feed);
                return 1;
            },
        };
    }

    if ($inactive) {
        push @commands, {
            title  => 'activate feed',
            action => sub {
                my $feed = choose_many(
                    'change feed',
                    sub {
                        $self->query_feeds( sub { !$self->is_active( $_[0] ) }
                        );
                    }
                );
                return 1 if !$feed;
                $self->activate_feed($feed);
                return 1;
            },
        };
    }

    return {
        title    => 'manage feeds',
        commands => \@commands
    };
}

sub submenu_configure {
    my $self = shift;
    my @commands;
    for my $key ( keys %{ $self->defaults } ) {
        push @commands, {
            title  => sub { "$key (" . $self->get_config($key) . ")" },
            action => sub {
                my $arg = prompt($key);
                return if !defined $arg;
                ## TODO Check if output_filename compiles and give the user an example
                $self->config->{$key} = $arg;
            },
        };
    }
    return {
        title    => 'configure',
        commands => \@commands,
    };
}

sub item_is_new {
    my ( $self, $item ) = @_;
    return !$self->item_state($item);
}

sub sort_feeds {
    my ( $self, $sort_by ) = @_;
    my @feeds = values %{ $self->feeds };
    if ( $sort_by eq 'title' ) {
        return sort { lc( $a->title ) cmp lc( $b->title ) } @feeds;
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
            @spec[$i] = $len if $len >= ( $spec[$i] // 0 );
        }
        push @rows, \@row;
    }
    my $fmt = '%-'
      . length( @rows + 1 ) . 'd.   '
      . join( ' / ', map { "\%${_}d" } @spec )
      . "   %s\n";
    for my $i ( 0 .. $#rows ) {
        printf( $fmt, $i + 1, @{ $rows[$i] } );
    }
    return 1;
}

sub render_item {
    my ( $self, $item ) = @_;

    my $summary = substr( render_content($item) || '', 0, 120 );
    return encode( 'UTF-8',
        $item->feed->title . ': ' . $item->title . "\n" . $summary )
      . "\n";
}

sub download {
    my ( $self, $feeds, $filter ) = @_;

    return 1 if !$feeds;
    return 1 if !@$feeds;
    $filter = $filter ? $filter : sub { 1 };

    my @items = grep { $filter->($_) }
      sort { $a->published <=> $b->published }
      map  { $_->items->each } @$feeds;

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

sub skip_feed {
    my ( $self, $feed, $state, @items ) = @_;
    my @new_items;
    for my $item (@items) {
        $self->item_state( $item => $state );
        if ( refaddr( $item->feed ) != refaddr($feed) ) {
            push @new_items, $item;
        }
    }
    return @new_items;
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
        @urls = keys %{ $self->state->{subscriptions} };
    }
    my $q = App::podite::URLQueue->new( ua => $self->ua );
  Feed:
    for my $url (@urls) {

        my $cache_file = $self->cache_dir->child( slugify($url) );

        if ( exists $self->state->{subscriptions}->{$url}
            && $self->state->{subscriptions}->{$url}->{inactive} )
        {
            $self->read_cached_feed( $url => $cache_file );
            next;
        }

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
                        my $feed = $self->feedr->parse($body);
                        if ( !$feed ) {
                            warn "Can't parse $url as feed.\n";
                            return;
                        }

                        open( my $fh, '>', $cache_file )
                          or die "Can't open cache file $cache_file: $!\n";
                        print $fh $body;

                        $self->cache_feed( $url => $self->feedr->parse($body) );
                    }
                    elsif ( $res->code eq 304 ) {
                        $self->read_cached_feed( $url => $cache_file );
                    }
                }
                else {
                    my $err = $tx->error;
                    warn "$err->{code} response: $err->{message}"
                      if $err->{code};
                    warn "Connection error: $err->{message}\n";
                }
            }
        );
    }
    return $q->wait;
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

