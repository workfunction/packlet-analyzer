#!/bin/bash

USAGE="USAGE :\nsh analyzer.sh <ouput file> <IP>"
WIDTH=$(tput cols)
HEIGHT=$(tput lines)

# show the frame
frame () {
    clear
    local i
    for (( i = 0; i < ( ${HEIGHT} - $# + 2 ) / 2; ++i )); do
        echo
    done

    local len=0
    for str in "$@"; do
        len=$(( ${#str} > len ? ${#str} : len ))
    done
    for (( i = 0; i < ( ${WIDTH} - len + 4 ) / 2; ++i )); do
        printf ' '
    done
    for (( i = 0; i < len + 4; ++i )); do
        printf '-'
    done
    printf '\n'

    for str in "$@"; do
        for (( i = 0; i < ( ${WIDTH} - len + 4 ) / 2; ++i )); do
            printf ' '
        done
        printf "| %-${len}s |" "$str"
        printf '\n'
    done

    for (( i = 0; i < ( ${WIDTH} - len + 4 ) / 2; ++i )); do
        printf ' '
    done
    for (( i = 0; i < len + 4; ++i )); do
        printf '-'
    done
    for (( i = 0; i < ( ${HEIGHT} - $# + 1 ) / 2; ++i )); do
        echo
    done
}

# split command output
command () {
    IFS=$'\n'
    lines=($($*))
    frame ${lines[@]}
    unset IFS
}

# determine input arguments
if [ $1 == "--help" ]; then
    echo ${USAGE}
    exit 0
elif [ $# -ne "2" ]; then
    echo "[ERROR] Too few arguments..."
    echo ${USAGE}
    exit -1
fi

# check valid file path
test -d $(dirname $1)
if [ $? -ne "0" ]; then
    echo "[ERROR] Directory does not exist"
    exit -1
fi
path=$(dirname $1)
file=$(basename $1)

# check valid IP address
ping -c 1 -t 1 $2 &> /dev/null
if [ $? -ne "0" ]; then
    echo "[ERROR] Cannot resolve given IP address"
    exit -1
fi
ip=$2

# list and select network interface
ifconfig -a

opt=$(ifconfig -a | grep -E -o "^\w+")
PS3=" [1] Select network interface: 
 -> "
select word in $opt; do
    if [ -n "$word" ]; then
        net=$word
        break
    else
        echo "[ERROR] Invaild option"
    fi
done
echo
echo ${net} selected

# give pcap file size
read -p " [2] Maximum output size(MB): (100MB as default)
 -> " size
if [ -z "${size}" ]; then
    size=100
fi
echo Maximum ${size} MB...

fileName=${$(uuid)##*-}.log

frame "TTC PACKLET ANALYZER" "by Jason Huang"
sleep 1
frame "Testing \"ls -l\" in frames:"
sleep 2
command ls -l
sleep 2
frame "This is all for now"

tshark -i ${net} -w ${fileName} -a filesize:$(( ${size}*1024 ))
