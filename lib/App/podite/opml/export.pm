package App::podite::opml::export;
use Mojo::Base 'App::podite';
use Mojo::File 'path';

sub run {
    my ( $self, $opts ) = @_;
    $self->export_opml( path( $opts->{opml_file} ) );
}

1;
