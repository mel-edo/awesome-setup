#!/bin/sh

update=$(checkupdates | wc -l)

if [ $update = 0 ]; then
  echo "Up to Date!"
else
  echo "$update updates available!"
fi

