package App::podite::status;
use Mojo::Base 'App::podite';

sub run {
    my $self = shift;
    $self->status;
}

1;
