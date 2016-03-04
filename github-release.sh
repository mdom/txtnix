#!/bin/sh

set -e

PERL5LIB=./lib:$PERL5LIB

last_tag=$(git describe --abbrev=0 --tags)

github-release release --user mdom --repo txtnix --tag $last_tag

./bundle-script.sh

github-release upload --user mdom --repo txtnix --tag $last_tag --name txtnix --file txtnix
