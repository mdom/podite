package App::podite::export;
use Mojo::Base 'App::podite';

sub run {
    my ($self) = @_;
    $self->export_opml;
}

1;
