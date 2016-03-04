#!/bin/sh

./bundle-script.sh
mv txtnix ../mdom.github.io/txtnix && cd ../mdom.github.io/ && git commit -m txtnix txtnix && git push
