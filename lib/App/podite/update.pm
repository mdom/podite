package App::podite::update;
use Mojo::Base 'App::podite';

sub run {
    my $self = shift;
    $self->update;
    $self->status;
}

1;
