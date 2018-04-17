package App::podite::status;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    $self->status;
}

1;
