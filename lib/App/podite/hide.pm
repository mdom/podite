package App::podite::hide;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    my @ids = map { $_->{id} }  $self->items->find_selection( $opts->{items} )->each; 
    $self->items->set_state( hidden => { id => { -in => \@ids } })
}

1;
