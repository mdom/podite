package App::podite::episodes;
use Mojo::Base 'App::podite';
use Mojo::Util 'tablify';

sub run {
    my $self = shift;
    my $list = [ map { [ $_->{title}, $_->{enclosure} ] }
          $self->items->find_and_save_order->each ];
    print tablify($list);
}

1;
