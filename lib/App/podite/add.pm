package App::podite::add;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    my @feeds = @{ $opts->{feed} };
    my ( @urls, @selection );
    for (@feeds) {
        if (m{^[\d-]+$}) {
            push @selection, $_;
        }
        else {
            push @urls, $_;
        }
    }
    if (@selection) {
        push @urls,
          map { $_->{url} }
          $self->search_results->find_selection( \@selection )->each;
    }
    for my $url (@urls) {
        $self->add_feed($url);
    }
}

1;
