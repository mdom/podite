requires 'Mojo::Base';
requires 'Mojo::File';
requires 'Mojo::IOLoop';
requires 'Mojo::JSON';
requires 'Mojo::URL';
requires 'Mojo::UserAgent';
requires 'Mojo::Util';
requires 'Mojo::Feed', '0.16';
requires 'Text::Wrap';
requires 'OptArgs2';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
    requires 'perl', '5.008_001';
};
