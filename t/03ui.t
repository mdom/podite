use Mojo::Base -strict;
use Test::More;
use App::podite::UI qw(choose_many);
use Data::Dumper;

{
    local ( *STDIN, *STDOUT );
    open( *STDIN,  '<', \'1-3 5-8' );
    open( *STDOUT, '>', \my $stdout );
    my $list =
      choose_many( test => [ map { [ $_ => $_ ] } 1 .. 10 ] );
    is_deeply( $list, [qw(1 2 3 5 6 7 8)] );
}

done_testing;
