package App::podite::Model::Feeds;
use Mojo::Base 'App::podite::Model';

has table => 'feeds';

sub find {
    my ( $self, $where ) = @_;
    if ( !exists $where->{enabled} ) {
        $where->{enabled} = 1;
    }
    $self->db->select( feeds => '*', $where )->hashes;
}

sub exists {
    my ( $self, $feed ) = @_;
    $self->db->select( feeds => id => { url => $feed->{url} } )->array;
}

sub add_or_update {
    my ( $self, $feed ) = @_;
    my $tx = $self->db->begin;
    if ( $self->exists($feed) ) {
        $self->db->update( feeds => $feed, { url => $feed->{url} } );
    }
    else {
        $self->db->insert( feeds => $feed );
    }
    $tx->commit;
}

sub all_urls {
    shift->db->select( feeds => 'url' )->arrays->flatten->each;
}

1;
