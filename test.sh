#!/bin/bash
# Bash Menu Script Example

ls -l | while IFS= read -r line ; do
    lines+="$line"
done
ff="foo"

lines+=("$ff")
lines+=("bar")

IFS=$'\n'
var=($(ls -l))
unset IFS
echo ${var[1]}

printf a\\r;
sleep 1
printf "cb"