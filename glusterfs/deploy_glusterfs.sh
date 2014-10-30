#!/bin/bash
# Install and configure GlusterFS 
# on Ubuntu or Debian.
#
# Author dysj4099@gmail.com
# April 20, 2014

# Read config
. ./deploy_glusterfs.cfg

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

# Step 1. Install sshpass
apt-get install sshpass -y

# Step 2. Compile and install glusterfs on each node.
cat > /tmp/tmp_install_gfs.sh << _wrtend_
#!/bin/bash

apt-get update
apt-get -y --force-yes purge glusterfs-server glusterfs-common
ps -ef | grep gluster | grep -v grep | grep -v deploy_glusterfs.sh | awk '{print \$2}'| xargs kill
apt-get -y --force-yes install build-essential dpkg-dev sshpass libssl-dev flex bison
rm -rf /var/lib/glusterd || true
if [ ! -x /usr/local/sbin/glusterd ];then
    cd /tmp && tar xf /tmp/${G_VER}.tar.gz
    cd /tmp/${G_VER} && ./configure && make && make install
    cd /tmp && rm -rf /tmp/${G_VER}
    ldconfig && update-rc.d -f glusterd defaults
fi
service glusterd restart
sleep 5
rm -rf /tmp/${G_VER}
rm /tmp/${G_VER}.tar.gz
rm /tmp/tmp_install_gfs.sh
_wrtend_

cp ${PKG_PATH} /tmp/

for node in ${NODES[@]}; do
    if [ "${MY_IP}" != "$node" ];then
        echo $node install start
        sshpass -p ${ROOT_PASS} scp -o StrictHostKeyChecking=no -r ${PKG_PATH} ${node}:/tmp/
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
	if [ "${#vol_info[@]}" == "4" ]; then
            /usr/local/sbin/gluster volume create ${vol_info[0]} replica ${vol_info[3]} ${vol_path}
	elif [ "${#vol_info[@]}" == "3" ]; then
            /usr/local/sbin/gluster volume create ${vol_info[0]} ${vol_path}
        fi
        # start volume
        echo /usr/local/sbin/gluster volume start ${vol_info[0]}
    done 
else
    echo "Attach peers error"
    exit 0
fi
