package App::podite::Iterator;
use Mojo::Base -base;

has 'array' => sub { [] };
has 'index' => 0;

sub current {
    my $self = shift;
    return if !@{ $self->array };
    $self->array->[ $self->index ];
}

sub next {
    my $self = shift;
    return if !@{ $self->array };
    my $next = $self->index + 1;
    if ( $#{ $self->array } < $next ) {
        return;
    }
    return $self->index($next);
    
}

sub prev {
    my $self = shift;
    return if !@{ $self->array };
    my $prev = $self->index - 1;
    if ( $prev < 0 ) {
        return;
    }
    return $self->index($prev);
}

1;
