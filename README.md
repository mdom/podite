# NAME

podite - Command line podcast aggregator

# SYNOPSIS

    podite

# DESCRIPTION

podite downloads podcasts from a set of subscribed rss and atom feeds. It
is optimized for users that don't want to download every podcast from
the feed. Instead, it queries the users which podcasts to download.

# INSTALLATION

The easiest way to install podite is with
[cpanminus](https://github.com/miyagawa/cpanminus):

    cpanm < install.list

# USAGE

_podite_ is a menu based tool. Just calling podite will bring you to the main
menu. Every submenu or action has a preceding number. You can choose an entry
by entering its number and pressing enter.

When you start podite, it will update all your feeds and print an
overwview. For every feed it will print its new items, skipped items and
the total number of items. You can always update your feeds again by using
the main menu action _update_ or print your feed stats with _status_.

In general, when the prompt ends with a single >, you can pick only one
of the choices given. When the prompt ends with double >, you can make
more than one selection, either seperated with spaces or commas. You
can also use ranges. E.g. "2-5 7,9" to choose 2,3,4,5,7,9 from the
list. If the second number in a range is omitted, all remaining choices
are selected. E.g. "7-" to choose 7,8,9 from the list. You can say _\*_
to choose everything.

## MENUS

- manage feeds

    This menu is all about managing your feeds.

    - add feed

        This action will prompt you for an url of an RSS feed and download it.

    - delete feed

        Delete one of your feeds. Prompts for a list of subscribed feeds. By
        deleteting a feed you'll loose any data for it, for example the list of
        downloaded, skipped or ignored feed entries.

    - change feed url

        Change the url of a feed. Prompts for one feed and the new url you want to
        subscribe this feed under.

# COPYRIGHT AND LICENSE

Copyright 2018 Mario Domgoergen <mario@domgoergen.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see &lt;http://www.gnu.org/licenses/>.

# AUTHOR

Mario Domgoergen <mario@domgoergen.com>
