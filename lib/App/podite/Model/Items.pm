package App::podite::Model::Items;
use Mojo::Base 'App::podite::Model';

has table => 'items';

sub find {
    my ( $self, $where, $order ) = @_;
    if (   !exists $where->{'feeds.enabled'}
        && !exists $where->{'feeds.list_order'} )
    {
        $where->{'feeds.enabled'} = 1;
    }
    if ( !$order ) {
        $order = [ 'feed', 'published' ];
    }
    my ( $where_stmt, @bind ) = $self->sql->abstract->where( $where, $order );
    $self->db->query(
        qq{
        select items.*, feeds.url as feed_url, feeds.title as feed_title
            from items
            join feeds on feeds.id = items.feed
         $where_stmt
        }, @bind
    )->hashes;
}

sub add_or_update {
    my ( $self, $url, $item ) = @_;
    my $tx = $self->db->begin;

    if ( !$item->{enclosure} ) {
        warn "Item without enclosure\n";
        return;
    }

    $item->{feed} = \[ '(select id from feeds where url = ?)', $url ];

    my $exists = $self->select( id => { link => $item->{link} } )->array;

    if ($exists) {
        $self->update( $item => { guid => $item->{guid} } );
    }
    else {
        $item->{state} = 'new';
        $self->insert( $item );
    }
    return $tx->commit;
}

sub set_state {
    my ( $self, $state, $where ) = @_;
    $self->update( { state => $state }, $where );
}

1;
