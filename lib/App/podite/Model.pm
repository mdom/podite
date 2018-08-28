package App::podite::Model;
use Mojo::Base -base;

has 'sql';
has db => sub { shift->sql->db };

sub update {
    my $self = shift;
    $self->update( $self->table, @_ );
}

sub find_and_save_order {
    my $self    = shift;
    my $results = $self->find(@_);
    if ( $results->size ) {
        my $tx = $self->db->begin;
        $self->db->update( { list_order => 0 } );
        my $i = 1;
        for my $item ( $results->each ) {
            $self->db->update( { list_order => $i++ }, { id => $item->{id} } );
        }
        $tx->commit;
    }
    return $results;
}

1;
