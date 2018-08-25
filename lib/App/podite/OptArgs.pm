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

subcmd 'App::podite::add' => (
    comment => 'add feeds ',
    optargs => sub {
        arg feed => (
            isa      => 'ArrayRef',
            required => 1,
            comment  => 'feed urls',
            greedy   => 1,
        );
    },
);

subcmd 'App::podite::feeds' => (
    comment => 'list feeds'
);

subcmd 'App::podite::update' => (
    comment => 'update feeds'
);

subcmd 'App::podite::episodes' => (
    comment => 'list episodes'
);
