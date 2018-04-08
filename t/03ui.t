use Mojo::Base -strict;
use Test::More;
use App::podite::UI qw(choose_many);
use Data::Dumper;

sub with_stdin {
    my ( $stdin, $test ) = @_;
    local ( *STDIN, *STDOUT );
    open( *STDIN,  '<', \$stdin );
    open( *STDOUT, '>', \my $stdout );
    $test->();
    return $stdout;
}

with_stdin '1-3 5-8' => sub {
    my $selection = [ map { [ $_ => $_ ] } 1 .. 10 ];
    is_deeply( choose_many( test => $selection ), [qw(1 2 3 5 6 7 8)] );
};

with_stdin '13 5' => sub {
    my $selection = [ map { [ $_ => $_ ] } 1 .. 10 ];
    is_deeply( choose_many( test => $selection ), [qw(5)] );
};

with_stdin '13 5' => sub {
    my $selection = [];
    ok( !choose_many( test => $selection ) );
};

done_testing;
