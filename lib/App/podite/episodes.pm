package App::podite::episodes;
use Mojo::Base 'App::podite';
use Mojo::Util 'tablify';

sub run {
    my ( $self, $opts ) = @_;

    my $where = { state => { '!=' => "hidden" } };

    my @items = $self->items->find_and_save_order($where)->each;

    if ( $opts->{one_line} ) {
        print tablify(
            [
                map {
                    [
                        $_->{list_order}, substr( $_->{title}, 0, 80 ),
                        $_->{feed_title}
                    ]
                } @items
            ]
        );
    }
    else {
        for (@items) {
            print $self->render_item($_), "\n";
        }
    }
}

1;
