#!/bin/bash

target_server=192.168.1.1

cd /opt; wget http://repo.zabbix.com/zabbix/2.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_2.2-1+precise_all.deb
dpkg -i zabbix-release_2.2-1+precise_all.deb
apt-get update -y
apt-get install zabbix-agent -y

sed -i "s/Server=127.0.0.1/Server=$target_server/" /etc/zabbix/zabbix_agentd.conf

/etc/init.d/zabbix-agent restart
rm /opt/zabbix-release_2.2-1+precise_all.deb
