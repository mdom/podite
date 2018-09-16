package App::podite::episodes;
use Mojo::Base 'App::podite';
use Mojo::Util 'tablify';

sub run {
    my ( $self, $opts ) = @_;

    my $where;

    if ( $opts->{feed} ) {
        my @feed_ids =
          map { $_->{id} } $self->feeds->find_selection( $opts->{feed} )->each;
        $where->{feed} = { -in => \@feed_ids };
    }

    for (qw(new hidden seen downloaded)) {
        if ( $opts->{$_} ) {
            push @{ $where->{state}->{-in} }, $_;
        }
    }

    if ( !exists $where->{state} ) {
        $where = { state => { -not_in => [ "hidden", "downloaded" ] } };
    }

    my @items = $self->items->find_and_save_order($where)->each;

    if ( $opts->{interactive} ) {
        $self->download_with_prompt(@items);
    }
    elsif ( $opts->{one_line} ) {
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
