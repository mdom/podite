package App::podite::update;
use Mojo::Base 'App::podite';

has needs_update => 1;

sub run {
    my ( $self, $opts ) = @_;
    $self->status;
}

1;
