# NAME

podite - Command line podcast aggregator

# SYNOPSIS

    podite

# DESCRIPTION

podite downloads podcasts from a set of subscribed rss and atom feeds. It
is optimized for users that don't want to download every podcast from
the feed.  Instead, it queries the users which podcasts to download.

# INSTALLATION

The easiest way to install podite is with
[cpanminus](https://github.com/miyagawa/cpanminus):

    cpanm git://github.com/mdom/podite.git

# USAGE

At startup podite reads it's configuration file at ~/.podite.conf. The
configuration file uses the INI format. Every podcasts has it's own section,
the only required property is its url.

    [revolutions]
    url = http://revolutionspodcast.libsyn.com/rss/

It's probably a good idea to never change the name of the section. The name is
used in the state file to track which media file was ignored or downloaded.

After that just call podite. It will check the feeds for updates and ask you
which podcasts you wan't to download, ignore forever or skip for this run.
After you exit this dialog by pressing q, all selected podcasts will be
downloaded to ~/Podcasts.

# COPYRIGHT AND LICENSE

Copyright 2018 Mario Domgoergen

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

Mario Domgoergen
