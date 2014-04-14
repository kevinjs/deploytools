#!/bin/bash
# Author dysj4099@gmail.com

###############Initialization################
PKG_PATH=/opt/files/glusterfs-3.4.0.tar.gz
ROOT_PASS=test
# Gluster peers
NODES=(192.168.64.87 192.168.64.88)
# Gluster volumes
vol_1=(nova_vol /opt/nova_vol 192.168.64.87,192.168.64.88)
VOLUMES=(vol_1)
#############################################

# Get MY_IP
if [ "${MY_IP}" == "" ];then
        MY_IP=$(python -c "import socket;socket=socket.socket();socket.connect(('8.8.8.8',53));print socket.getsockname()[0];")
fi

# Step 1. Install sshpass
apt-get install sshpass -y

# Step 2. Compile and install glusterfs on each node.
cd /tmp && tar xf ${PKG_PATH}

cat > /tmp/tmp_install_gfs.sh << _wrtend_
#!/bin/bash

apt-get -y --force-yes purge glusterfs-server glusterfs-common
ps ax|grep gluster|grep -v grep|awk '{print $1}'|xargs -L 1 kill
apt-get -y --force-yes install libssl-dev flex bison
rm -rf /var/lib/glusterd || true
if [ ! -x /usr/local/sbin/glusterd ];then
    cd /tmp/glusterfs-3.4.0 && ./configure && make && make install
    cd /tmp && rm -rf /tmp/glusterfs-3.4.0
    ldconfig && update-rc.d -f glusterd defaults
fi
service glusterd restart
sleep 5
rm -rf /tmp/glusterfs-3.4.0
rm /tmp/tmp_install_gfs.sh
_wrtend_

for node in ${NODES[@]}; do
    if [ "${MY_IP}" != "$node" ];then
        echo $node install start
        sshpass -p ${ROOT_PASS} scp -o StrictHostKeyChecking=no -r /tmp/glusterfs-3.4.0 ${node}:/tmp/glusterfs-3.4.0
        sshpass -p ${ROOT_PASS} scp -o StrictHostKeyChecking=no /tmp/tmp_install_gfs.sh ${node}:/tmp/
        sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node} /bin/bash /tmp/tmp_install_gfs.sh
        echo $node install end
    fi
done

/bin/bash tmp_install_gfs.sh

# Step 3. Attach peer
for node in ${NODES[@]}; do
    if [ "${MY_IP}" != "$node" ];then
        /usr/local/sbin/gluster peer probe ${node}
    fi  
done

sleep 15

# Step 4. Verify attach status and create volumes
conn_peer_num=`/usr/local/sbin/gluster peer status | grep Connected | wc -l`
conn_peer_num=`expr $conn_peer_num + 1`

if [ ${conn_peer_num} -eq ${#NODES[@]} ];then
    echo "All peers have been attached."
    for vol in ${VOLUMES[@]};do
        eval vol_info=(\${$vol[@]})
        eval vol_nodes=(${vol_info[2]//,/ })
        vol_path=""
        for node in ${vol_nodes[@]};do
            vol_path=$vol_path$node:${vol_info[1]}" "
        done

        # create volume
        /usr/local/sbin/gluster volume create ${vol_info[0]} replica 2 ${vol_path}
        # start volume
        /usr/local/sbin/gluster volume start ${vol_info[0]}
    done 
else
    echo "Attach peers error"
    exit 0
fi
