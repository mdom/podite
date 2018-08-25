package App::podite::feeds;

use Mojo::Base 'App::podite';
use Mojo::Util 'tablify';

sub run {
    my ($self) = @_;
    print tablify ( [ map { [ $_->{url}, $_->{title} ] } $self->feeds->find ] );
}

1;
