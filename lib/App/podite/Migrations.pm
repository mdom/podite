package App::podite::Migrations;
use Mojo::Base -base;

1;

__DATA__
@@ migrations
-- 6 up

create unique index ux_config_key ON config(key);

-- 5 up

create table config (
	key text not null default "",
	value text not null default ""
);

-- 4 up

create table items_new (
    id          integer primary key,
    feed        integer,
    guid        text not null,
    enclosure   text not null,
    title       text,
    content     text,
    description text,
    author      text,
    published   text,
    state       text not null,
    list_order  integer,

    foreign key (feed) references feeds(id),
    check (state in ('new', 'seen', 'downloaded', 'hidden')),
    unique (feed, guid)
);

insert into items_new select * from items;
drop table items;
alter table items_new rename to items;

-- 3 up

create table items_new (
    id          integer primary key,
    feed        integer,
    guid        text not null,
    enclosure   text not null,
    title       text,
    content     text,
    description text,
    author      text,
    published   text,
    state       text not null,
    list_order  integer,

    foreign key (feed) references feeds(id),
    check (state in ('new', 'seen', 'downloaded', 'hidden'))
);

insert into items_new select * from items;
drop table items;
alter table items_new rename to items;

-- 2 up

create table search_results (
    id integer primary key,
    url text not null,
    list_order integer
);

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
    guid text not null,
    enclosure text not null,

    title text,
    content text,
    description text,
    author text,
    published text,

    state text not null check (state in ('new', 'downloaded', 'hidden')),

    list_order integer,
    foreign key (feed) references feeds(id)
);
