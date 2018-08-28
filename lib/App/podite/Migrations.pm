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
    last_modified text,
    enabled integer default 1,
    list_order integer
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
    list_order integer,
    foreign key (feed) references feeds(id)
);
