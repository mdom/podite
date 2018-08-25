package App::podite::Model::Items;
use Mojo::Base -base;

has 'sql';
has db => sub { shift->sql->db };

sub find {
    my ( $self, $where ) = @_;
    $self->db->select( items => '*', $where )->hashes;
}

sub delete {
    my ( $self, $id ) = @_;
    $self->db->delete( items => { id => $id } );
}

sub add_or_update {
    my ( $self, $url, $item ) = @_;
    my $tx = $self->db->begin;

    my $enclosure = $item->enclosures->first->url;

    if ( !$enclosure ) {
        warn "Item without enclosure\n";
        return;
    }

    my $link = $item->link;

    die "Item in $url without link.\n" if !$link;

    $item = $item->to_hash;

    $item->{feed} = \[ '(select id from feeds where url = ?)', $url ];
    $item->{enclosure} = $enclosure;

    delete $item->{guid};
    delete $item->{id};
    delete $item->{enclosures};

    my $exists = $self->db->select( items => id => { link => $link } )->array;

    if ($exists) {
        $self->db->update( items => $item => { link => $link } );
    }
    else {
        $self->db->insert( items => $item );
    }
    return $tx->commit;
}

1;
