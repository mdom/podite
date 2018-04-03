package App::podite::Directory;
use Mojo::Base -base;

use Mojo::URL;
use Mojo::UserAgent;

has base_url => sub {
    Mojo::URL->new('https://gpodder.net');
};

has ua => sub { Mojo::UserAgent->new };

sub toplist {
    my ( $self, $number ) = @_;
    $number ||= 50;
    return $self->ua->get( $self->base_url->path("/toplist/$number.json") )
      ->result->json;
}

sub search {
    my ( $self, $term ) = @_;
    return {} if !$term;
    my $url = $self->base_url->path("/search.json")->query( q => $term );
    warn "$url\n";
    return $self->ua->get($url)->result->json;
}

1;
