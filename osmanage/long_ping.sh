#!/bin/bash

if [ $# -ne 4 ];then
    echo "Usage:"
    echo "      `basename $0` -a ip_address -i interval"
    exit 0
fi
while getopts 'a:i:' OPT; do
case $OPT in
    a)
	ADDRESS="$OPTARG"
        ;;
    i)
	INTERVAL="$OPTARG"
	;;
    ?)
	echo "Usage:"
	echo "      `basename $0` -a ip_address -i interval"
        exit 0
esac
done

st_time=`date '+%Y%m%d%H%M%S'`

echo $ADDRESS
echo $INTERVAL
echo $st_time

while true
do
date >> /opt/ping_${st_time}.log
ping $ADDRESS -c $INTERVAL >> /opt/ping_${st_time}.log
done
