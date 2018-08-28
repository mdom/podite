package App::podite::move;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    $self->feeds->update( { url => $opts->{to} },
        { url => $opts->{from} } );
}

1;
