#!/usr/bin/env bash

next_day=
for day in {1..25}; do
    day2d=$(printf "%02d" $day)
    if [ ! -d "$day2d" ]; then
        next_day="$day2d"
        break
    fi
done

if [ -z "$next_day" ]; then
    echo "No more days to create workspaces for."
    exit 1
fi

cp -r day01 "day$next_day"
cd "$next_day" || exit 7
touch example_input.txt
touch input.txt
