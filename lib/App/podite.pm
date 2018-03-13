package App::podite;
use Mojo::Base -base;

use Mojolicious::Plugin::FeedReader;
use Mojo::URL;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::File 'path';
use Mojo::Util 'encode';
use Text::Wrap 'wrap';
use Config::Tiny;
use Fcntl qw(:flock O_RDWR O_CREAT);
use App::podite;
use App::podite::URLQueue;
use File::stat;

our $VERSION = "0.01";

has ua => sub {
    Mojo::UserAgent->new( max_redirects => 5 );
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

has download_dir => sub {
    path( shift->config->{general}->{download_dir} || "$ENV{HOME}/Podcasts" );
};

has config => sub {
    shift->read_config;
};

has 'state_fh';

has state => sub {
    shift->read_state;
};

sub DESTROY {
    my $self = shift;
    $self->write_state;
}

sub run {

    my ( $self, @argv ) = @_;

    $self->ua->proxy->detect;

    $self->share_dir->make_path;
    $self->cache_dir->make_path;
    $self->download_dir->make_path;

    ## TODO Do we even want to suport subcommands?
    my $mode = shift @argv || 'check';
    warn $mode;

    my %allowed_subcommands = ( check => 1 );

    if ( exists $allowed_subcommands{$mode} ) {
        return $self->$mode(@argv);
    }
    return 1;
}

sub check {
    my $self = shift;
    $self->update();
    my $feeds  = $self->config->{feeds};
    my @names  = sort keys %$feeds;
    my $reader = Mojolicious::Plugin::FeedReader->new;
    my @download_items;
  Feed:
    for my $name (@names) {
        my $feed  = $reader->parse_rss( $self->cache_dir->child($name) );
        my @items = @{ $feed->{items} };
      Item:
        while ( my $item = shift @items ) {
            my $decision =
              $self->state->{subscriptions}->{$name}->{items}->{ $item->{guid} }
              || '';
            if ( $decision eq 'downloaded' or $decision eq 'hidden' ) {
                next;
            }

            ## TODO provide that in Mojo::Feed
            $item->{feed_name} = $name;

            ## TODO terminal escape
            print "\n", encode( 'UTF-8', underline( $item->{title} ) );
            my $summary = render_dom( Mojo::DOM->new( $item->{content} ) );
            if ( length($summary) > 800 ) {
                $summary = substr( $summary, 0, 800 ) . "[SNIP]\n";
            }
            print encode( 'UTF-8', $summary ) . "\n";
            while (1) {
                print "Download this item [y,n,N,s,S,q,?]? ";
                my $key = <STDIN>;
                chomp($key);
                if ( $key eq 'y' ) {
                    push @download_items, $item;
                    next Item;
                }
                elsif ( $key eq 'n' ) {
                    $self->state->{subscriptions}->{$name}->{items}
                      ->{ $item->{guid} } = 'hidden';
                    next Item;
                }
                elsif ( $key eq 'N' ) {
                    for ( $item, @items ) {
                        $self->state->{subscriptions}->{$name}->{items}
                          ->{ $item->{guid} } = 'hidden';
                    }
                    next Feed;
                }
                elsif ( $key eq 'S' ) {
                    next Feed;
                }
                elsif ( $key eq 'q' ) {
                    last Feed;
                }
                elsif ( $key eq 's' ) {
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
    for my $item (@download_items) {
        my $feed_name = $item->{feed_name};
        my $url       = Mojo::URL->new( $item->{enclosures}->[0]->{url} );
        my $file =
          $self->download_dir->child($feed_name)
          ->child( $url->path->parts->[-1] );
        $file->dirname->make_path;
        say "$url -> $file";
        $q->add(
            $url => sub {
                my ( $ua, $tx ) = @_;
                $tx->result->content->asset->move_to($file);
                $self->state->{subscriptions}->{$feed_name}->{items}
                  ->{ $item->{guid} } = 'downloaded';
                warn "Download $file finished\n";
            }
        );
    }
    $q->wait;
    return 0;
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
    my ( $self, @names ) = @_;
    my $feeds = $self->config->{feeds};
    if ( !@names ) {
        @names = sort keys %$feeds;
    }
    my $q = App::podite::URLQueue->new( ua => $self->ua );
  Feed:
    for my $name (@names) {
        my $url = $feeds->{$name}->{url};
        if ( !$url ) {
            warn "Unknown feed $name.\n";
            next Feed;
        }
        my $cache_file = $self->cache_dir->child($name);
        my $tx = $self->ua->build_tx( GET => $url );
        if ( -e $cache_file ) {
            my $date = Mojo::Date->new( stat($cache_file)->mtime );
            $tx->req->headers->if_modified_since($date);
        }
        warn "Updating $name.\n";

        $q->add(
            $tx => sub {
                my ( $ua, $tx ) = @_;
                my $res = $tx->result;
                warn "Fetched $name with rc " . $res->code . "\n";
                if ( $res->is_error ) { say $res->message; return; }
                if ( $res->code eq 200 ) {
                    open( my $fh, '>', $cache_file )
                      or die "Can't open cache file $cache_file: $!\n";
                    print $fh $res->body;
                }
            }
        );

    }
    $q->wait;
    return;
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

sub read_config {
    my $self        = shift;
    my $config_file = "$ENV{HOME}/.podite.conf";
    if ( -e $config_file ) {
        my $config = Config::Tiny->read( $config_file, 'utf8' );
        if ( !$config ) {
            die "Can't read config file: " . Config::Tiny->errstr . "\n";
        }
        my %feeds;
        my $root = $config->{_};
        for my $key ( keys %{$config} ) {
            next if !$config->{$key}->{url};
            $config->{feeds}->{$key} = {

                # copy defaults
                %{ $config->{$key} }
            };
            delete $config->{$key};
        }
        return $config;
    }
    return {};
}
1;

__END__

=head1 NAME

podite - command line podcatcher

=head1 LICENSE

Copyright (C) Mario Domgoergen.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Mario Domgoergen E<lt>mdom@taz.deE<gt>

=cut
