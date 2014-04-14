#!/bin/bash
# Author jingshao@cnic.cn
# CNIC, CAS

ROOT_PASS=$1

GMETAD_NODE=192.168.40.84
GMOND_NODES=(192.168.40.84 192.168.40.80 192.168.40.81 192.168.40.82 192.168.40.83)

# Restart GMETAD service
if [ ! -z "${ROOT_PASS}" ];then
    echo "Restart begin!"
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${GMETAD_NODE} service gmetad restart
    
    sleep 1
    
    for node in ${GMOND_NODES[@]}; do
        sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node} service gmond restart
        sleep 1
    done

    sleep 1

    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${GMETAD_NODE} service httpd restart
    echo "Restart done!"
else
    echo "Input the ROOT_PASSWORD first."
fi
