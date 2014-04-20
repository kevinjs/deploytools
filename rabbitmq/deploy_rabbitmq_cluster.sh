#!/bin/bash
# NOTICE: RabbitMQ should use hostname instead of ip address
# Author dysj4099@gmail.com
# April 15, 2014

# Read config
. ./deploy_rabbitmq_cluster.cfg

# Get MY_IP
if [ "${MY_IP}" == "" ];then
    MY_IP=$(python -c "import socket;socket=socket.socket();socket.connect(('8.8.8.8',53));print socket.getsockname()[0];")
fi

# Get ROOT_PASS from keyboard
if [ $# -ne 2 ];then
    echo "Usage:"
    echo "      `basename $0` -p password"
    exit 0
fi
while getopts 'p:l:' OPT; do
case $OPT in
    p)
	ROOT_PASS="$OPTARG";;
    ?)
	echo "Usage:"
	echo "      `basename $0` -p password"
        exit 0
esac
done

# Step 1. install sshpass
if ! os_is_package_installed sshpass; then
    os_echo 'Install SSHPASS'
    os_install_package sshpass > /dev/null 2>&1
fi

# Step 2.

