package App::podite::itunes;
use Mojo::Base 'App::podite';
use Mojo::Util 'tablify', 'encode';
use Mojo::URL;

has base_url => sub {
    Mojo::URL->new('https://itunes.apple.com/search?media=podcast');
};

sub run {
    my ( $self, $opts ) = @_;
    my $url = $self->base_url->query( [ term => $opts->{term} ] );
    my $i = 1;
    my @feeds;
    for ( @{ $self->ua->get($url)->result->json->{results} } ) {
        next if !$_->{feedUrl};
        push @feeds,
          {
            url        => $_->{feedUrl},
            name       => $_->{trackName},
            artist     => $_->{artistName},
            list_order => $i++,
          };
    }

    my $tx = $self->db->begin;
    $self->db->delete('search_results');
    $self->db->insert(
        search_results => { url => $_->{url}, list_order => $_->{list_order} } )
      for @feeds;
    $tx->commit;

    print encode 'UTF-8', tablify(
        [
            map {
                [
                    $_->{list_order},
                    substr( $_->{name},   0, 60 ),
                    substr( $_->{artist}, 0, 30 )
                ]
            } @feeds
        ]
    );
}

1;
