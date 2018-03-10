requires 'Config::Tiny';
requires 'Mojo::Base';
requires 'Mojo::File';
requires 'Mojo::IOLoop';
requires 'Mojo::JSON';
requires 'Mojo::URL';
requires 'Mojo::UserAgent';
requires 'Mojo::Util';
requires 'Mojolicious::Plugin::FeedReader';
requires 'Text::Wrap';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
    requires 'perl', '5.008_001';
};
