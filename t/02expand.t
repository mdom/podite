use Mojo::Base -strict;
use Test::More;
use App::podite::UI 'expand_list';

my @tests = (
    [ '1'         => ['1'] ],
    [ '1 2'       => [qw(1 2)] ],
    [ '1    2'    => [qw(1 2)] ],
    [ '1,2'       => [qw(1 2)] ],
    [ '1,2'       => [qw(1 2)] ],
    [ '1,2 3'     => [qw(1 2 3)] ],
    [ '1 2 3'     => [qw(1 2 3)] ],
    [ '1 2,3'     => [qw(1 2 3)] ],
    [ '1-2'       => [qw(1 2)] ],
    [ '1-2 3 4-6' => [qw(1 2 3 4 5 6)] ],
    [ '1, 9-'     => [qw(1 9 10)] ],
);

for my $test (@tests) {
    is_deeply( [ expand_list( $test->[0], 10 ) ], $test->[1] );
}

done_testing;
