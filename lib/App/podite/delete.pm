package App::podite::delete;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;

    my @ids = map { $_->{id} }
      $self->feeds->find_selection( $opts->{feed} )->each;

    my $tx = $self->sqlite->db->begin;

    $self->items->delete( { feed => { -in => \@ids } } );
    $self->feeds->delete( { id   => { -in => \@ids } } );

    $tx->commit;
}

1;
