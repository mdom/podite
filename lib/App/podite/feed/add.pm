package App::podite::feed::add;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    $self->add_feeds( @{ $opts->{url} } );
}

1;
