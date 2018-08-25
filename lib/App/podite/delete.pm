package App::podite::delete;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    my @feeds = @{ $opts->{feed} };
    return if !@feeds;
    my $tx = $self->users->db->begin;

    my @ids = $self->feeds->all->map( sub { $_->{id} } )->each;
    $self->users->delete( { id   => { -in => \@ids } } );
    $self->items->delete( { feed => { -in => \@ids } } );

    $tx->commit;
}

1;
