# stolen from https://gist.github.com/jberger/5153008
# all errors probably by me
package App::podite::URLQueue;
use Mojo::Base 'Mojo::EventEmitter';
use Mojo::UserAgent;
use Mojo::URL;
use Mojo::IOLoop;

has queue => sub { [] };
has ua => sub { Mojo::UserAgent->new( max_redirects => 5 ) };
has worker => 16;
has delay => sub { Mojo::IOLoop->delay };

sub add {
    my ( $self, $tx, $cb ) = @_;
    push @{ $self->queue }, $tx, $cb;
    return;
}

sub wait {
    my $self = shift;
    if ( @{ $self->queue } ) {
        $self->start->wait;
    }
    return;
}

sub start {
    my ( $self, $cb ) = @_;
    return if !@{ $self->queue };
    $self->{running} = 0;

    my $handle_event = sub {
        my ( $ua, $tx ) = @_;
        $self->emit( start => $ua, $tx );
        $tx->res->on(
            progress => sub {
                my $res = shift;
                $self->emit( progress => $tx, $res );
                return;
            }
        );
        return;
    };

    $self->ua->on( start => $handle_event );

    $self->_refresh;

    return $self->delay->finally(
        sub { $self->ua->unsubscribe( start => $handle_event ) } );
}

sub _refresh {
    my $self = shift;

    my $worker = $self->worker;
    while ( $self->{running} < $worker
        and my ( $tx, $cb ) = splice( @{ $self->queue }, 0, 2 ) )
    {
        $self->{running}++;
        my $end = $self->delay->begin;

        if ( !ref($tx) || !$tx->isa('Mojo::Transaction') ) {
            $tx = $self->ua->build_tx( GET => $tx );
        }

        $self->ua->start(
            $tx,
            sub {
                my ( $ua, $tx ) = @_;
                $cb->( $ua, $tx ) if $cb;
                $self->emit( response => $ua, $tx );

                # refresh worker pool
                $self->{running}--;
                $self->_refresh;
                $end->();
            }
        );
    }
    return;
}

1;
