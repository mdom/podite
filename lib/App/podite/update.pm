package App::podite::update;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    $self->update_feeds( @{ $opts->{podcasts} || [] } );
}

1;
