package App::podite::download;
use Mojo::Base 'App::podite';

sub run {
    my ($self, $opts ) = @_;
    $self->download( $opts->{items} );
}

1;
