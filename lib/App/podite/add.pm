package App::podite::add;
use Mojo::Base 'App::podite';

sub run {
    my ($self, $opts ) = @_;
    my @feeds = @{ $opts->{feed}};
    for my $feed ( @feeds ) {
        $self->add_feed( $feed );
    }
}

1;
