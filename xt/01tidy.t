use strict;
use warnings;
use Test::PerlTidy;

run_tests(
    exclude => [
        qr{Makefile.PL}, qr{blib/}, qr{App-podite-.*/}, qr{.build/}, qr{.git/}
    ]
);
