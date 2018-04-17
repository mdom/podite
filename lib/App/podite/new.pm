package App::podite::new;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    $self->update;
    my @items = grep { $self->item_is_new($_) }
      sort { $a->published <=> $b->published }
      map  { $_->items->each } values %{ $self->feeds };
    my $selection = [
        map {
            [
                $self->render_item($_),
                [ episode => $_->feed->source => $_->id ]
            ]
        } @items
    ];
    $self->list($selection);
}

1;
