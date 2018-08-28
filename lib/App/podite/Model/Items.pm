package App::podite::Model::Items;
use Mojo::Base 'App::podite::Model';

has table => 'items';

sub find {
    my ( $self, $where, $order ) = @_;
    if ( !exists $where->{'feeds.enabled'} ) {
        $where->{'feeds.enabled'} = 1;
    }
    my ( $where_stmt, @bind ) = $self->sql->abstract->where( $where, $order );
    $self->db->query(
        qq{
        select items.*, feeds.url as feed_url
            from items
            join feeds on feeds.id = items.feed
         $where_stmt
        }, @bind
    )->hashes;
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
        $self->db->update( $item => { link => $link } );
    }
    else {
        $self->db->insert( items => $item );
    }
    return $tx->commit;
}

1;
