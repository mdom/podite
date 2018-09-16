package App::podite::OptArgs;
use Mojo::Base -strict;
use OptArgs2;

cmd 'App::podite' => (
    comment => 'the demo command',
    abbrev  => 1,
    optargs => sub {
        arg command => (
            isa      => 'SubCmd',
            required => 1,
            comment  => 'command to run',
        );
    },
);

subcmd 'App::podite::itunes' => (
    comment => 'search the itunes store',
    optargs => sub {
        arg term => (
            isa      => 'Str',
            isa_name => 'TERM',
            required => 1,
            comment  => 'search term',
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

subcmd 'App::podite::status' => ( comment => 'show status of feeds' );

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

subcmd 'App::podite::update' => (
    comment => 'update feeds',
    optargs => sub {
        opt interactive => (
            isa     => 'Flag',
            comment => 'decide podcast state interactively',
            alias   => 'i',
        );
    }
);

subcmd 'App::podite::export' => ( comment => 'export feeds to opml' );

subcmd 'App::podite::episodes' => (
    comment => 'list episodes',
    optargs => sub {
        opt one_line => (
            isa     => 'Flag',
            comment => 'show compact episode list',
        );
        opt interactive => (
            isa     => 'Flag',
            comment => 'decide podcast state interactively',
            alias   => 'i',
        );
        opt format => (
            isa     => 'Str',
            comment => 'display items with format [one-line|full]',
        );
        opt state => (
            isa => 'ArrayRef',
            comment =>
"show only episodes with state hidden, seen, downloaded or hidden",
            alias => 's',
        );
        arg feed => (
            isa      => 'ArrayRef',
            isa_name => 'FEED',
            comment  => 'feed urls',
            greedy   => 1,
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
            isa_name => 'URL',
        );
        arg to => (
            isa      => 'Str',
            required => 1,
            comment  => 'new url',
            isa_name => 'URL',
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
