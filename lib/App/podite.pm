package App::podite;
use Mojo::Base -base;

use Mojo::Feed::Reader;
use Mojo::URL;
use Mojo::Template;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::File 'path';
use Mojo::Util 'encode', 'slugify';
use Text::Wrap 'wrap';
use Fcntl qw(:flock O_RDWR O_CREAT);
use App::podite;
use App::podite::URLQueue;
use App::podite::Iterator;
use App::podite::UI 'menu';
use File::stat;

our $VERSION = "0.01";

has ua => sub {
    Mojo::UserAgent->new( max_redirects => 5 );
};

has share_dir => sub {
    path("$ENV{HOME}/.local/share/podite/");
};

has state_file => sub {
    shift->share_dir->child('state2');
};

has cache_dir => sub {
    shift->share_dir->child('cache');
};

has feedr => sub {
    Mojo::Feed::Reader->new;
};

has 'state_fh';

has state => sub {
    shift->read_state;
};

sub DESTROY {
    my $self = shift;
    if ( $self->state_fh ) {
        $self->write_state;
    }
}

sub status {
    my ( $self, $url, $feed ) = @_;
    my $feed_state = $self->state->{subscription}->{$url};
    my @items      = $feed->items->each;
    my ( $skipped, $new, $total ) = ( 0, 0, scalar @items );
    for my $item (@items) {
        my $id = $item->id;
        if ( my $state = $feed_state->{$id} ) {
            for ($state) {
                /^(downloaded|hidden)$/ && next;
                /^skipped$/ && do { $skipped++; next };
            }
        }
        else {
            $new++;
        }
    }
    return "$new / $skipped / $total ";
}

sub query_feeds {
    my %feeds = @_;
    return sub {
        [
            map { [ $feeds{$_}->title => $_ ] }
              keys %feeds
        ]
    },;
}

sub run {

    my ( $self, @argv ) = @_;

    $self->ua->proxy->detect;

    $self->share_dir->make_path;
    $self->cache_dir->make_path;

    my %feeds = $self->update;

    menu(
        {
            run_on_startup => 'status',
            commands       => [
                {
                    title    => 'manage feeds',
                    commands => [
                        {
                            title  => 'add feed',
                            args   => 'url for new feed> ',
                            action => sub {
                                my $url = shift;
                                if ($url) {
                                    my %new_feeds = $self->update($url);
                                    if ( $new_feeds{$url} ) {
                                        $self->state->{subscriptions}->{$url} =
                                          {};
                                        $feeds{$url} = $new_feeds{$url};
                                    }
                                }
                                return 1;
                            },
                        },
                        {
                            title  => 'delete feed',
                            action => sub {
                                for my $url (@_) {
                                    delete $feeds{$url};
                                    delete $self->state->{subscriptions}
                                      ->{$url};
                                }
                                return 1;
                            },
                            args => query_feeds(%feeds),
                        },
                    ],
                },
                {
                    title  => 'status',
                    action => sub {
                        my $i;
                        while ( my ( $url, $feed ) = each %feeds ) {
                            $DB::single = 1;
                            my $status = $self->status( $url, $feed );
                            say ++$i . ".  $status  " . $feed->title;
                        }
                        return 1;
                    },
                },
                {
                    title  => 'download',
                    action => sub {
                        $self->download( map { $_ => $feeds{$_} } @_ );
                    },
                    args => query_feeds(%feeds),
                },
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

sub download {
    my ( $self, %feeds ) = @_;
    return 1 if !%feeds;

    my @downloads;
  Feed:
    while ( my ( $url, $feed ) = each %feeds ) {
        my @items = $feed->items->each;
      Item:
        for my $item (@items) {
            my $decision = $self->item_state( $url => $item ) || '';
            if ( $decision eq 'downloaded' or $decision eq 'hidden' ) {
                next Item;
            }

            ## TODO terminal escape
            print "\n", encode( 'UTF-8', underline( $item->title ) );
            my $summary = render_dom( Mojo::DOM->new( $item->content ) );
            if ( length($summary) > 800 ) {
                $summary = substr( $summary, 0, 800 ) . "[SNIP]\n";
            }
            print encode( 'UTF-8', $summary ) . "\n";
            while (1) {
                print "Download this item [y,n,N,s,S,q,,?]? ";
                my $key = <STDIN>;
                chomp($key);
                if ( $key eq 'y' ) {
                    push @downloads, [ $url => $item ];
                    next Item;
                }
                elsif ( $key eq 'n' ) {
                    $self->item_state( $url => $item->id => 'hidden' );
                    next Item;
                }
                elsif ( $key eq 'N' ) {
                    for my $item ( $item, @items ) {
                        $self->item_state( $url => $item => 'hidden' );
                    }
                    next Feed;
                }
                elsif ( $key eq 'S' ) {
                    for my $item ( $item, @items ) {
                        $self->item_state( $url => $item => 'skipped' );
                    }
                    next Feed;
                }
                elsif ( $key eq 'q' ) {
                    last Feed;
                }
                elsif ( $key eq 's' ) {
                    $self->item_state( $url => $item => 'skipped' );
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
    }

    my $q = App::podite::URLQueue->new( ua => $self->ua );
    for my $download (@downloads) {
        my ( $feed_url, $item ) = @_;
        my $download_url = Mojo::URL->new( $item->enclosures->[0]->url );
        my $output_filename = $self->output_filename( $item, $download_url );
        $output_filename->dirname->make_path;
        say "$download_url -> $output_filename";
        $q->add(
            $download_url => sub {
                my ( $ua, $tx, ) = @_;
                $tx->result->content->asset->move_to($output_filename);
                $self->item_state( $feed_url => $item => 'downloaded' );
                warn "Download $output_filename finished\n";
            }
        );
    }
    $q->wait;
    return 1;
}

sub item_state {
    my ( $self, $url, $item, $state ) = @_;
    my $items = $self->state->{subscriptions}->{$url}->{items};
    if ($state) {
        return $items->{ $item->id } = $state;
    }
    return $items->{ $item->id };
}

sub output_filename {
    my ( $self, $item, $url ) = @_;
    my $feed_name = $item->{feed_name};
    my $template  = '"$feed_name/$title.$ext"';
    $template .= '\\';
    my $mt              = Mojo::Template->new( vars => 1 );
    my $remote_filename = $url->path->parts->[-1];
    my $download_dir    = path("$ENV{HOME}/Podcasts");
    my ($remote_ext)    = $remote_filename =~ /\.([^.]+)$/;
    my $filename        = path(
        $mt->render(
            $template,
            {
                filename     => $url->path->parts->[-1],
                feed_name    => $feed_name,
                title        => slugify( $item->title, 1 ),
                ext          => $remote_ext,
                download_dir => $download_dir,
            }
        )
    );

    if ( !$filename->is_abs ) {
        $filename = $download_dir->child($filename);
    }
    return $filename;
}

sub underline {
    my $line      = shift;
    my $underline = '=' x length($line);
    return "$line\n$underline\n\n";
}

sub render_dom {
    my $node    = shift;
    my $content = '';

    for ( $node->child_nodes->each ) {
        $content .= render_dom($_);
    }

    if ( is_tag( $node, 'h1' ) ) {
        return underline($content);
    }
    elsif ( $node->tag && $node->tag =~ /^h(\d)$/ ) {
        return ( '#' x $1 ) . " $content\n\n";
    }
    elsif ( $node->type eq 'text' ) {
        $content = $node->content;
        $content =~ s/\.\s\.\s\./.../;
        return '' if $content !~ /\S/;
        return $content;
    }
    elsif ( is_tag( $node, 'a' ) ) {
        my $href = $node->attr('href');
        if ($href) {
            return "\[$content\]\[$href\]";
        }
        return $content;
    }
    elsif ( is_tag( $node, 'location' ) ) {
        return "$content ";
    }
    elsif ( is_tag( $node, 'p' ) ) {
        return Text::Wrap::fill( '', '', $content ) . "\n\n";
    }
    elsif ( is_tag( $node, 'b' ) ) {
        return "*$content*";
    }
    return $content;
}

sub is_tag {
    my ( $node, $tag ) = @_;
    return $node->type eq 'tag' && $node->tag eq $tag;
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
                        ## TODO add source field in Mojo::Feed (Atom ref="self")
                        $feeds{$url} = $feed;
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
    my ($self) = @_;
    my $state_file = $self->state_file;
    sysopen( my $fh, $state_file, O_RDWR | O_CREAT )
      or die "Can't open state file $state_file: $!\n";
    flock( $fh, LOCK_EX | LOCK_NB ) or die "Cannot lock $state_file: $!\n";
    my $content = do { local ($/); <$fh> };
    my $json = decode_json( $content || '{}' );
    $self->state_fh($fh);
    return $json;
}

has defaults => sub {
    {
        download_dir    => "$ENV{HOME}/Podcasts",
        output_filename => '<%= "$feed_name/$title.$ext" %>',
    }
};

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

Mario Domgoergen

=cut

