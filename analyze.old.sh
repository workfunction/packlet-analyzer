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
    for (( i = 0; i < ( ${WIDTH} - len - 4 ) / 2; ++i )); do
        printf ' '
    done
    for (( i = 0; i < len + 4; ++i )); do
        printf '-'
    done
    printf '\n'

    for str in "$@"; do
        for (( i = 0; i < ( ${WIDTH} - len - 4 ) / 2; ++i )); do
            printf ' '
        done
        printf "| %-${len}s |" "$str"
        printf '\n'
    done

    for (( i = 0; i < ( ${WIDTH} - len - 4 ) / 2; ++i )); do
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
select word in ${opt}; do
    if [ -n "${word}" ]; then
        net=${word}
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
fileName="${path}/${file}.pcap"

# Main window
frame "TTC PACKLET ANALYZER" "by Jason Huang"
sleep 1

# clear stdin buffer
while read -r -t 0; do read -r; done

op="x"
addr="all"
port="all"
protocol="all"
method="all"

while [ "${op}" != "r" ]; do
    frame "TTC PACKLET ANALYZER" "* Record at ${ip} and Stored at ${fileName}" \
    "* Listen on ${net} and maximum size is ${size} MB" \
    "============================================" \
    "Options:" \
    "[a] Specific address: ${addr}" "[b] Specific ports: ${port}" \
    "[c] Specific protocol: ${protocol}" "[d] Specific http method: ${method}" \
    "============================================" \
    "  [r] Start capture     [x] Clear options" \
    "  [q] Exit the program"
    read -n1 -s op
    case ${op} in 
     "a")
        clear
        read -p " Specific address: " addr
        ;;
     "b")
        clear
        read -p " Specific ports: " port
        ;;
     "c")
        clear
        read -p " Specific protocol: " protocol
        ;;
     "d")
        clear
        read -p " Specific http method: " method
        ;;
     "x")
        addr="all"
        port="all"
        protocol="all"
        method="all"
        ;;
     "q")
        clear
        frame "Goodbye!"
        exit 0
        ;;
    esac
done

filter=""
re_port="^[0-9]+$"
re_port_range="^[0-9]+-[0-9]+$"

if [ ${addr} == "all" ]; then
    addr=""
else
    filter="${filter} -f \"host ${addr}\""
fi

if [ ${port} == "all" ]; then
    port=""
elif [ ${port} =~ ${re_port} ]; then
    filter="${filter} -f \"port ${port}\""
elif [ ${port} =~ ${re_port_range} ]; then
    filter="${filter} -f \"portrange ${port}\""
else
    echo "Bad port!"
    exit 1
fi

if [ ${protocol} == "all" ]; then
    protocol=""
fi

if [ ${method} == "all" ]; then
    method=""
fi



tshark -i ${net} -w ${fileName} -a filesize:$(( ${size}*1024 )) \
${filter} 