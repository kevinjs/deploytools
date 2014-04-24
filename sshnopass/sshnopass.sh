#!/bin/bash
# Automatically install non-interactivly performing password authentication
# Author duyyuan2014@gmail.com
# April 23, 2014

#Read config
. ./sshnopass.cfg

echo ${IP_PWS[@]}

authFile="/tmp/authorized_keys"
#To determine whether authFile exists
#If not, create
if [ ! -f "$authFile" ]; then
    touch "$authFile"
fi

# Install sshpass
apt-get install sshpass -y

#Generate public key for each IP
for i in ${!IP_PWS[@]}; do
    if [ $[i%2] -eq 0 ]; then
        sshpass -p ${IP_PWS[$((i+1))]} ssh -o StrictHostKeyChecking=no root@${IP_PWS[$i]} ssh-keygen -t rsa -P \'\' -f /root/.ssh/id_rsa
        sshpass -p ${IP_PWS[$((i+1))]} scp -o StrictHostKeyChecking=no -r ${IP_PWS[$i]}:/root/.ssh/id_rsa.pub /tmp
        cat /tmp/id_rsa.pub >> $authFile
    fi
done

#Publish the authorized_keys file for each compute
for i in ${!IP_PWS[@]}; do
    if [ $[i%2] -eq 0 ]; then
        sshpass -p ${IP_PWS[$((i+1))]} scp -o StrictHostKeyChecking=no -r $authFile ${IP_PWS[$i]}:/root/.ssh/authorized_keys
        sshpass -p ${IP_PWS[$((i+1))]} ssh -o StrictHostKeyChecking=no root@${IP_PWS[$i]} service ssh restart
    fi
done
