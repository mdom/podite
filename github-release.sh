#!/bin/sh

set -e

minil release

last_tag=$(git describe --abbrev=0 --tags)

github-release release --user mdom --repo podite --tag $last_tag

./bundle-script.sh || exit 1

github-release upload --user mdom --repo podite --tag $last_tag --name podite --file podite.fatpack
