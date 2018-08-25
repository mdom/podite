package App::podite::Migrations;
use Mojo::Base -base;

1;

__DATA__
@@ migrations
-- 1 up

create table feeds (
    id integer primary key,
    url text not null unique,
    title text,
    last_modified text
);

create table items (
    id integer primary key,
    feed integer,
    link text not null,
    enclosure text not null,

    title text,
    content text,
    description text,
    author text,
    published text,

    downloaded integer default 0,
    hidden integer default 0,
    foreign key (feed) references feeds(id)
);
