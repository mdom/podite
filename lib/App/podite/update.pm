package App::podite::update;
use Mojo::Base 'App::podite';

sub run {
    my ( $self, $opts ) = @_;
    $self->update;
    if ( $opts->{interactive} ) {
        my @items =
          $self->items->find_and_save_order( { state => 'new' } )->each;
        $self->download_with_prompt(@items);
    }
    else {
        $self->status;
    }
}

1;
