package App::podite::Model::Feeds;
use Mojo::Base 'App::podite::Model';

has table => 'feeds';

sub find {
    my ( $self, $where ) = @_;
    if ( !exists $where->{enabled} && !exists $where->{list_order} ) {
        $where->{enabled} = 1;
    }
    $self->select( '*', $where )->hashes;
}

sub exists {
    my ( $self, $feed ) = @_;
    $self->select( id => { url => $feed->{url} } )->array;
}

sub add_or_update {
    my ( $self, $feed ) = @_;
    my $tx = $self->db->begin;
    if ( $self->exists($feed) ) {
        $self->update( $feed, { url => $feed->{url} } );
    }
    else {
        $self->insert($feed);
    }
    $tx->commit;
}

sub all_urls {
    shift->select( 'url' )->arrays->flatten->each;
}

1;
