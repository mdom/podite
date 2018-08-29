package App::podite::episodes;
use Mojo::Base 'App::podite';
use Mojo::Util 'tablify';

sub run {
    my $self = shift;
    my @items = $self->items->find_and_save_order({ state => { '!=' =>  "hidden" } })->each;
    #print tablify([ map { [ @{$_}{qw(list_order title feed_title)} ] } @items ]);
    for (@items) {
        print $self->render_item( $_ ), "\n";
    }
}

1;
