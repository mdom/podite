package App::podite::enable;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    my @urls = @{ $opts->{feed} };
    $self->feeds->update( { enabled => 1 }, { url => { -in => \@urls } } );
}

1;
