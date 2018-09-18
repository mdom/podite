[![Build Status](https://travis-ci.org/mdom/podite.svg?branch=master)](https://travis-ci.org/mdom/podite)
# NAME

podite - Command line podcast aggregator

# SYNOPSIS

    podite

# DESCRIPTION

podite is a modern podcast manager for the command line. It supports
searching and subscribing via itunes, nonblocking network requests
and interactive selection of episodes.

Feeds can be disabled if you are currently not interested in them
without loosing the information which episode you already downloaded.
Episodes can either be skipped if you are not sure if you want to
listen to it or hidden, so they will not clutter your screen.

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

The _feed_ subcommand list all subscribed feeds. The number in the
first column can be used in any subcommand that takes an _FEED_
as argument. The same applies to the first column in the output of
_episodes_. Those selection can be either list of elements or
ranges. See _EXAMPLES_ for an example.

- add URL...

    This action will prompt you for an url of an RSS feed and download it.

- delete FEED...

    Deletes one of your feeds. By deleteting a feed you'll loose any
    data for it, for example the list of downloaded, skipped or ignored
    feed entries. If you just want to temporarily disable a feed use
    _disable_.

- move FEED NEW\_URL

    Changes the url of a feed.

- disable FEED...

    Disable feeds. All state is preserved.

- enable FEED...

    Enables formerly disabled feeds.

- feeds

    List all feeds. The number in the first column can be used as
    argument to all feed related subcommands.

- status

    Displays a list of currently subscribed and active podcasts. For every
    podcast the number of new, skipped and total episodes are listed. A
    episode is counted as skipped if you have already seen it in the download
    dialog but haven't downloaded or hidden it.

- update \[FEED...\]

    Updates all feeds and show their status.

- episodes \[FEED...\]

    List all episodes that are not hidden or downloaded. The number in
    the first column can be used as argument to all episode related
    subcommands.

    - --interactive -i

        When interactive mode is used, a short description is showed for
        every episode and then prompts you what to do with the episode. You
        can select one of the following options:

            y - download this episode
            n - do not download this episode, never ask again
            N - do not download any remaining episode of this podcast
            s - skip episodes
            S - skip all remaining episodes of podcast
            q - quit interactive mode and download episodes
            i - show complete information for episode
            Q - quit, do not download
            ? - show this list

    - --state -s STATE

        Show only episodes with the selected state. The state can either
        be _new_, _skipped_, _seen_, _downloaded_ or _hidden_. This
        option can be given multiple times. Defaults to _new_ and _skipped_.

    - --order ORDER

        List episodes in _ORDER_. This can either be _published_, _feed_
        or _state_. This options can be given multiple times. Defaults to
        _feed_ and _published_.

- download EPISODES...

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
