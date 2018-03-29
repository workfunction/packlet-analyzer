#!/bin/bash

USAGE="USAGE :\nsh analyzer.sh <ouput file>"
WIDTH=$(tput cols)
HEIGHT=$(tput lines)

# determine input arguments
if [ $1 == "--help" ]; then
    echo ${USAGE}
    exit 0
elif [ $# -ne "1" ]; then
    echo "[ERROR] Bad agruments"
    echo ${USAGE}
    exit -1
fi

# check valid dependency
which tshark > /dev/null
if [ $? -ne "0" ]; then
    echo "[ERROR] You must install tshark first. try \"sudo apt install tshark\""
    exit -1
fi

which unbuffer > /dev/null
if [ $? -ne "0" ]; then
    echo "[ERROR] You must install expect first. try \"sudo apt install expect\""
    exit -1
fi

which dialog > /dev/null
if [ $? -ne "0" ]; then
    echo "[ERROR] You must install dialog first. try \"sudo apt install dialog\""
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
dialog --backtitle "TTC PACKET ANALYZER" \
--title "Welcome" --infobox "script written by Jason Huang" 10 30
sleep 1

# clear stdin buffer
# while read -r -t 0; do read -r; done

addr=""
port=""
protocol=""
method=""
other=""

pass="no"
info=""

re_port="^[0-9]+$"
re_port_range="^[0-9]+-[0-9]+$"

while [ ${pass} != "yes" ]; do

    filter=""

    # open fd
    exec 3>&1

    # Store data to $VALUES variable
    VALUES=$(dialog --backtitle "TTC PACKET ANALYZER" \
    --title "Add a capture" \
    --ok-label "Start capture" --cancel-label "Quit" \
    --form "${info}* pcap file stored at ${fileName} \n* listen on ${net} and maximum size is ${size} MB \nOptions:" \
    15 60 0 \
    "Specific address: "  1 1 "${addr}"     1 25 15 0 \
    "Specific ports: "    2 1 "${port}"     2 25 15 0 \
    "Specific protocol: " 3 1 "${protocol}" 3 25 15 0 \
    "Specific method: "   4 1 "${method}"   4 25 15 0 \
    "Other configure: "   5 1 "${other}"    5 25 30 0 \
    2>&1 1>&3)

    if [ $? -ne 0 ]; then 
        dialog --backtitle "TTC PACKET ANALYZER" \
        --title "Quit" \
        --infobox "\n\n\n\nGoodbye!" 10 30
        exec 3>&-
        sleep 1; clear; exit 0
    fi

    # close fd
    exec 3>&-

    IFS=$'\n'
    options=(${VALUES})
    unset IFS

    addr=${options[0]}
    port=${options[1]}
    protocol=${options[2]}
    method=${options[3]}

    pass="yes"

    # check for ports
    if [ -z "${port}" ]; then
        :
    elif [[ ${port} =~ ${re_port} ]]; then
        filter="port ${port}"
    elif [[ ${port} =~ ${re_port_range} ]]; then
        filter="portrange ${port}"
    else
        info="                 *** Bad port! ***\n"
        pass="no"
    fi

    # check for protocol
    if [ -z ${protocol}]; then
        :
    else
        filter="${protocol} ${filter}"
    fi

    # if method is given, will clean the port and protocol settings
    case ${method} in
    "get")
        filter="port 80 and tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x47455420"
        ;;
    "post")
        filter="port 80 and tcp[((tcp[12:1] & 0xf0) >> 2):5] = 0x504F535420"
        ;;
    "")
        :
        ;;
    *)
        info="                *** Bad method! ***\n"
        pass="no"
        ;;
    esac

    # finally, add the given address
    if [ -z "${addr}" ]; then
        :
    elif [ -z "${filter}" ]; then
        filter="host ${addr}"
    else
        filter="host ${addr} and ${filter}"
    fi

    if [ -z "${other}" ]; then
        :
    else
        filter="${filter} and ${other}"
    fi

    dialog --backtitle "TTC PACKET ANALYZER" \
        --title "Add a capture" \
        --yesno "This is your capture filter: \n\n** ${filter} **\n\nIs that looking good?" 0 0

    if [ $? -ne 0 ]; then 
        pass="no"
    fi

done

logfile='/tmp/pa.log'

# Main process
touch ${logfile}
unbuffer tshark -i ${net} -w ${fileName} -b filesize:$(( ${size}*1024 )) -f "${filter}" > /tmp/pa.log 2>&1 &
sleep 1
tshark_pid=$( ps | grep -P "/tshark\s.+" | grep -P "^\s*\d+" -o )

ps -p ${tshark_pid}
running=$?

progress=("." ".." "..." "...." "....." "...." "..." "..")
i=0

while [ ${running} -eq 0 ]; do

    var=$( cat ${logfile} )
    num=$( echo ${var} | grep -P '\d+$' -o )

    dialog --backtitle "TTC PACKET ANALYZER" \
    --title "Capturing" --timeout 1\
    --ok-label "Stop capture" \
    --msgbox "\nCapturing on ${net}\nFilter ${filter}\n${num} packet captured${progress[$(( $i % 8 ))]}" 10 40 2>/dev/null

    if [ $? -eq 0 ]; then 
        dialog --backtitle "TTC PACKET ANALYZER" \
        --title "Stopping" \
        --infobox "\n\nStop capturing..." 8 40
        kill ${tshark_pid}
        sleep 1
    fi

    ps -p ${tshark_pid} > /dev/null
    running=$?
    i=$(( $i + 1 ))
done

dialog --backtitle "TTC PACKET ANALYZER" \
--title "Finished" \
--infobox "\n\nCapture finished. Goodbye!" 8 40

sleep 2
clear