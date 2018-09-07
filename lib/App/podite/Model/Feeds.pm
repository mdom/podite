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
    shift->select('url')->arrays->flatten->each;
}

sub status {
    shift->db->query(
        q{
        select
                feeds.id,
                feeds.title,
                sum( case when state = "downloaded" then 1 else 0 end ) as downloaded,
                sum( case when state = "hidden"     then 1 else 0 end ) as hidden,
                sum( case when state = "seen"       then 1 else 0 end ) as seen,
                sum( case when state = "new"        then 1 else 0 end ) as new,
                count(*) as total
            from items
            join feeds on feed = feeds.id
            group by feed
            order by feeds.id;
        }
    )->hashes;
}

1;
