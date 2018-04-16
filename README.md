[![Build Status](https://travis-ci.org/mdom/podite.svg?branch=master)](https://travis-ci.org/mdom/podite)
# NAME

podite - Command line podcast aggregator

# SYNOPSIS

    podite

# DESCRIPTION

podite downloads podcasts from a set of subscribed rss and atom feeds. You
can add feeds by url or search for them on gpodder.net. Feeds can be
deactivated if you are currently not interested in them without loosing
the information which episode you already downloaded. Episodes can be
hidden, so they will not clutter your screen (unless you want to!).

# INSTALLATION

The easiest way to install podite is with
[cpanminus](https://github.com/miyagawa/cpanminus):

    cpanm git://github.com/mdom/podite.git

# USAGE

_podite_ is a menu based tool. Just calling podite will bring you to the main
menu. Every submenu or action has a preceding number. You can choose an entry
by entering its number and pressing enter.

When you start podite, it will update all your feeds and print an
overwview. For every feed it will print its new items, skipped items and
the total number of items. You can always update your feeds again by using
the main menu action _update_ or print your feed stats with _status_.

In general, when the prompt ends with a single >, you can pick
only one of the choices given. When the prompt ends with double >,
you can make more than one selection, either seperated with spaces or
commas. You can also use ranges. E.g. "2-5 7,9" to choose 2,3,4,5,7,9
from the list. If the second number in a range is omitted, all remaining
choices are selected. E.g. "7-" to choose 7,8,9 from the list. You can
say _\*_ to choose everything.

You can leave menus by pressing _CTRL-D_. This will also abort an action
when prompted for arguments.

## MENUS

- manage feeds

    This menu is all about managing your feeds.

    - add feed
        - add feed by url

            This action will prompt you for an url of an RSS feed and download it.

        - search and add feed

            Prompts for a search term and presents you with a list of feeds found
            on gpodder.net. You can select multiple feeds.
    - delete feed

        Deletes one of your feeds. Prompts for a list of subscribed feeds. By
        deleteting a feed you'll loose any data for it, for example the list
        of downloaded, skipped or ignored feed entries. If you just want to
        temporarily disable a feed use _deactivate feed_.

    - change feed url

        Changes the url of a feed. Prompts for one feed and the new url you want to
        subscribe this feed under.

    - deactivate feed

        Prompts for a list of feeds to deactivate them. All state is preserved. This
        menu is hidden if there are not active feeds.

    - activate feed

        Prompts for a list of feeds to reactivate them. This menu is hidden if there
        are no deactivated feeds.

- status

    Displays a list of currently subscribed and active podcasts. For every
    podcast the number of new, skipped and total episodes are listed. A
    episode is counted as skipped if you have already seen it in the download
    dialog but haven't downloaded or hidden it.

- update

    Updates all feeds and show their status.

- download

    Downloads or hides a list of episodes. You are first prompted for a list
    of podcasts and then an episode filter. You can either filter by "new",
    "new and skipped" and "all" episodes. The last filter also includes
    hidden episodes. Then podite show the list of all selected episodes with a
    little summary. The you will be prompted for a list of episodes you want
    to download. Then you can select which episodes should be hidden. After
    that your episodes will be downloaded.

- configure

    Configure podite. You are presented with a list of configuration options than
    you can change.

    - download\_dir

        Base directory where downloaded podcasts will be saved.

- quit

    Quit podite.

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
