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

# EXAMPLES

    $ podite --help

    $ podite add http://feeds.twit.tv/floss.xml https://gastropod.com/feed/

    $ podite feeds
    1 http://feeds.twit.tv/floss.xml   FLOSS Weekly (MP3)
    2 https://gastropod.com/feed/      Gastropod

    $ podite update

    $ podite episodes
    [...]

    $ podite download 1 4-6 20-

# COMMANDS

- add URL...

    This action will prompt you for an url of an RSS feed and download it.

- delete URL...

    Deletes one of your feeds. By deleteting a feed you'll loose any
    data for it, for example the list of downloaded, skipped or ignored
    feed entries. If you just want to temporarily disable a feed use
    _disable_.

- move OLD\_URL NEW\_URL

    Changes the url of a feed.

- disable URL

    Disable feed. All state is preserved.

- enable URL

    Enables a formerly disables feed.

- status

    Displays a list of currently subscribed and active podcasts. For every
    podcast the number of new, skipped and total episodes are listed. A
    episode is counted as skipped if you have already seen it in the download
    dialog but haven't downloaded or hidden it.

- update

    Updates all feeds and show their status.

- download EPISODES

    Downloads episodes.

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

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 57:

    '=item' outside of any '=over'
