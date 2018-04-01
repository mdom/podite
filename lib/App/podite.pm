package App::podite;
use Mojo::Base -base;

use Mojo::Feed::Reader;
use Mojo::URL;
use Mojo::Template;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Util 'slugify';
use Fcntl qw(:flock O_RDWR O_CREAT);
use App::podite::URLQueue;
use App::podite::UI 'menu';
use App::podite::Util 'path';
use App::podite::Render 'render_item';
use File::stat;
use Scalar::Util 'refaddr';

our $VERSION = "0.01";

has ua => sub {
    my $self = shift;
    my $ua = Mojo::UserAgent->new( max_redirects => 5 );
    $ua->transactor->name("podite/$VERSION (+https://github.com/mdom/podite)");
    $ua->request_timeout( $self->get_config('timeout') );
    return $ua;
};

has share_dir => sub {
    path("$ENV{HOME}/.local/share/podite/");
};

has state_file => sub {
    shift->share_dir->child('state');
};

has cache_dir => sub {
    path("$ENV{HOME}/.cache/podite/");
};

has feedr => sub {
    Mojo::Feed::Reader->new;
};

has defaults => sub {
    { download_dir => "~/Podcasts", timeout => 0 }
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
    my ($self) = @_;
    my $query = [ map { [ $_->title => $_ ] } $self->sort_feeds('title') ];
    return $query;
}

sub items {
    my ( $self, @feeds ) = @_;
    sort { $b->published <=> $a->published } map { $_->items->each } @feeds;
}

sub add_feed {
    my ( $self, $url ) = @_;
    if ($url) {
        $self->update($url);
        if ( $self->feeds->{$url} ) {
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
            run_on_startup => 'status',
            commands       => [
                {
                    title    => 'manage feeds',
                    commands => [
                        {
                            title => 'add feed',
                            args  => [
                                {
                                    prompt => 'url for new feed',
                                    is     => 'string',
                                }
                            ],
                            action => sub {
                                $self->add_feed(@_);
                                return 1;
                            },
                        },
                        {
                            title  => 'delete feed',
                            action => sub {
                                $self->delete_feed(@_);
                                return 1;
                            },
                            args => [
                                {
                                    is   => 'many',
                                    list => sub { $self->query_feeds }
                                }
                            ],
                        },
                        {
                            title => 'change feed url',
                            args  => [
                                {
                                    is     => 'one',
                                    list   => sub { $self->query_feeds },
                                    prompt => 'change feed',
                                },
                                {
                                    prompt => 'new url for feed',
                                    is     => 'string',
                                }
                            ],
                            action => sub {
                                $self->change_feed_url(@_);
                                return 1;
                            },
                        },
                    ],
                },
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
                        $self->download(@_);
                    },
                    args => [
                        {
                            is   => 'many',
                            list => sub { $self->query_feeds },
                        },
                        {
                            is   => 'one',
                            list => [
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
                        }
                    ],
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

sub submenu_configure {
    my $self = shift;
    my @commands;
    for my $key (qw(download_dir timeout)) {
        push @commands, {
            title => sub { "$key (" . $self->get_config($key) . ")" },
            args  => [
                {
                    is     => 'string',
                    prompt => $key,
                },
            ],
            action => sub {
                my ($arg) = @_;
                $self->config->{$key} = $arg;
                if ( $key eq 'timeout' ) {
                    $self->ua->request_timeout($arg);
                }
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
    my @feeds = $self->sort_feeds('title');
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

sub download {
    my ( $self, $feeds, $filter ) = @_;

    return 1 if !$feeds;
    return 1 if !@$feeds;
    $filter = $filter ? $filter : sub { $_[0] };

    my @downloads;

    my @items = grep { $filter->($_) }
      sort { $b->published <=> $a->published }
      map  { $_->items->each } @$feeds;

  Item:
    while ( my $item = shift @items ) {
        my $url = $item->id;

        ## TODO terminal escape
        render_item($item);

        while (1) {
            print "Download this item [y,n,N,s,S,q,,?]? ";
            my $key = <STDIN>;
            chomp($key);
            if ( $key eq 'y' ) {
                push @downloads, $item;
                next Item;
            }
            elsif ( $key eq 'n' ) {
                $self->item_state( $item => 'hidden' );
                next Item;
            }
            elsif ( $key eq 'N' ) {
                @items =
                  $self->skip_feed( $item->feed, 'hidden', $item, @items );
                next Item;
            }
            elsif ( $key eq 'S' ) {
                @items =
                  $self->skip_feed( $item->feed, 'skipped', $item, @items );
                next Item;
            }
            elsif ( $key eq 'q' ) {
                last Item;
            }
            elsif ( $key eq 's' ) {
                $self->item_state( $item => 'skipped' );
                next Item;
            }
            else {
                print "y - download this item\n"
                  . "n - do not download this item, never ask again\n"
                  . "N - do not download this item or any of the remaining ones\n"
                  . "s - skip this item, ask next time\n"
                  . "S - skip this feed, ask next time\n"
                  . "q - quit, do not download this item or any other\n";
                next;
            }
        }
    }

    my $q = App::podite::URLQueue->new( ua => $self->ua );
    for my $item (@downloads) {
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
    $q->wait;
    return 1;
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
    my $template = '<%= "$feed_title/$title.$ext" %>';

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

sub update {
    my ( $self, @urls ) = @_;
    if ( !@urls ) {
        @urls = keys %{ $self->state->{subscriptions} };
    }
    my $q = App::podite::URLQueue->new( ua => $self->ua );
    my %feeds;
  Feed:
    for my $url (@urls) {
        my $cache_file = $self->cache_dir->child( slugify($url) );

        my $tx = $self->ua->build_tx( GET => $url );
        if ( -e $cache_file ) {
            my $date = Mojo::Date->new( stat($cache_file)->mtime );
            $tx->req->headers->if_modified_since($date);
        }
        warn "Updating $url.\n";

        $q->add(
            $tx => sub {
                my ( $ua, $tx ) = @_;
                my $res = eval { $tx->success };
                if ( my $res = $tx->success ) {
                    my $feed;
                    if ( $res->code eq 200 ) {
                        open( my $fh, '>', $cache_file )
                          or die "Can't open cache file $cache_file: $!\n";
                        my $body = $res->body;
                        print $fh $body;
                        $feed = $self->feedr->parse($body);
                    }
                    elsif ( $res->code eq 304 ) {
                        if ( -r $cache_file ) {
                            $feed = $self->feedr->parse($cache_file);
                        }
                    }
                    if ($feed) {
                        $feed->source( Mojo::URL->new($url) );
                        $self->feeds->{$url} = $feed;
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
    $q->wait;
    return %feeds;
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

