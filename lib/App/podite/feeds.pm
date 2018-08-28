package App::podite::feeds;

use Mojo::Base 'App::podite';
use Mojo::Util 'tablify';

sub run {
    my ( $self, $opts ) = @_;
    my $enabled =
      $opts->{all} ? { -in => [ 0, 1 ] } : $opts->{disabled} ? 0 : 1;
    print tablify (
        [
            map { [ $_->{url}, $_->{title} ] }
              $self->feeds->find( { enabled => $enabled } )->each
        ]
    );
}

1;
