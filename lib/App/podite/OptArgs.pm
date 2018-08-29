package App::podite::OptArgs;
use Mojo::Base -strict;
use OptArgs2;

cmd 'App::podite' => (
    comment => 'the demo command',
    optargs => sub {
        arg command => (
            isa      => 'SubCmd',
            required => 1,
            comment  => 'command to run',
        );
    },
);

for (qw(delete enable disable add )) {

    subcmd "App::podite::$_" => (
        comment => "$_ feeds",
        optargs => sub {
            arg feed => (
                isa      => 'ArrayRef',
                required => 1,
                comment  => 'feed urls',
                greedy   => 1,
            );
        },
    );

}
subcmd 'App::podite::feeds' => (
    comment => 'list feeds',
    optargs => sub {
        opt disabled => (
            isa     => 'Flag',
            comment => 'show disabled feeds',
        );
        opt all => (
            isa     => 'Flag',
            comment => 'show enabled and disabled feeds',
        );
    }
);

subcmd 'App::podite::update' => ( comment => 'update feeds' );
subcmd 'App::podite::export' => ( comment => 'export feeds to opml' );

subcmd 'App::podite::episodes' => (
    comment => 'list episodes',
    optargs => sub {
        opt one_line => (
            isa     => 'Flag',
            comment => 'show compact episode list',
        );
    },
);

subcmd "App::podite::move" => (
    comment => "change feed url",
    optargs => sub {
        arg from => (
            isa      => 'Str',
            required => 1,
            comment  => 'old url',
        );
        arg to => (
            isa      => 'Str',
            required => 1,
            comment  => 'new url',
        );
    },
);

for (qw( hide download )) {
    subcmd "App::podite::$_" => (
        comment => "$_ episodes",
        optargs => sub {
            arg items => (
                isa      => 'ArrayRef',
                isa_name => 'ITEM',
                required => 1,
                greedy   => 1,
                comment  => 'epsisodes to $_',
            );
        },
    );

}

1;
