package App::podite::update;
use Mojo::Base 'App::podite';
use Mojo::Util 'dumper';

sub run {
    my ( $self, $opts ) = @_;
    warn dumper($opts);
    $self->update_feeds( @{ $opts->{podcasts} || [] } );
}

1;
