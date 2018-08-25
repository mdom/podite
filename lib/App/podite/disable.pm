package App::podite::disable;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    my @urls = @{ $opts->{feed} };
    $self->feeds->update( { enabled => 0 }, { url => { -in => \@urls } } );
}

1;
