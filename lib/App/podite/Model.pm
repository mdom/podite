package App::podite::Model;
use Mojo::Base -base;

has 'sql';
sub db { shift->sql->db }

sub select {
    my $self = shift;
    $self->db->select( $self->table, @_ );
}

sub update {
    my $self = shift;
    $self->db->update( $self->table, @_ );
}

sub delete {
    my $self = shift;
    $self->db->delete( $self->table, @_ );
}

sub insert {
    my $self = shift;
    $self->db->insert( $self->table, @_ );
}

sub find {
    shift->select( '*', @_ )->hashes;
}

sub find_selection {
    my ( $self, $selection ) = @_;
    my ( @result, @in );
    for ( map { split(',') } @{$selection} ) {
        if (/^\*$/) {
            @result = { '!=', undef };
            last;
        }
        elsif (/^(\d+)-(\d+)$/) {
            push @result, { '>=', $1, '<=', $2 };
        }
        elsif (/^(\d+)-$/) {
            push @result, { '>=', $1 };
        }
        elsif (/^-(\d+)$/) {
            push @result, { '<=', $1 };
        }
        elsif (/^(\d+)$/) {
            push @in, $1;
        }
        else {
            warn "Can't parse $_ as selection.\n";
        }
    }
    if (@in) {
        push @result, { -in => \@in };
    }
    my $column = $self->table . '.list_order';
    return $self->find( { $column => \@result } );
}

sub save_order {
    my ($self, $results ) = @_;
    if ( $results->size ) {
        my $tx = $self->db->begin;
        $self->update( { list_order => undef } );
        my $i = 1;
        for my $item ( $results->each ) {
            $item->{list_order} = $i;
            $self->update( { list_order => $i++ }, { id => $item->{id} } );
        }
        $tx->commit;
    }
    return $results;
}

sub find_and_save_order {
    my $self = shift;
    my $results = $self->find(@_);
    return $self->save_order( $results );
}

1;
