package App::podite::feed::delete;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    $self->delete_feeds( @{ $opts->{url} } );
}

1;
