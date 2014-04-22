#!/bin/bash
# NOTICE: RabbitMQ should use hostname instead of ip address
# Author dysj4099@gmail.com
# April 15, 2014

# Debug
#set -x

# Read config
. ./deploy_rabbitmq_cluster.cfg

# Set /etc/hosts
touch /tmp/tmp_hosts
for i in ${!NODES[@]}; do
    eval node_info=(\${${NODES[$i]}[@]})
    echo "${node_info[1]}	${node_info[0]}" >> /tmp/tmp_hosts
done

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
	ROOT_PASS="$OPTARG"
        ;;
    ?)
	echo "Usage:"
	echo "      `basename $0` -p password"
        exit 0
esac
done

# Step 1. install sshpass
apt-get install sshpass -y

# Step 2. install and configure
cat > /tmp/tmp_install_rabbitmq.sh << _wrtend_
#!/bin/bash
# Get install parameter
while getopts 'h:r' OPT; do
    case \$OPT in
        h)
	    HOSTNAME_ROOT="\$OPTARG"
            ;;
	r)
	    RAM_MODE=true
            ;;
    esac
done
# Remove old version
apt-get -y --force-yes purge rabbitmq-server
cat /tmp/tmp_hosts >> /etc/hosts
# Install new version
echo "deb http://www.rabbitmq.com/debian/ testing main" >> /etc/apt/sources.list
sudo apt-key add /tmp/rabbitmq-signing-key-public.asc
apt-get update
apt-get -y --force-yes install rabbitmq-server
# Stop service
service rabbitmq-server stop
# Set erlang cookie
echo 'CNICCSDBRABBITMQECCP' > /var/lib/rabbitmq/.erlang.cookie
chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
chmod 400 /var/lib/rabbitmq/.erlang.cookie
# Start service
service rabbitmq-server start
# Set up rabbitmq cluster
/usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
/usr/sbin/rabbitmqctl stop_app
/usr/sbin/rabbitmqctl reset
if \$RAM_MODE;then
    /usr/sbin/rabbitmqctl join_cluster --ram rabbit@\${HOSTNAME_ROOT}
else
    /usr/sbin/rabbitmqctl join_cluster rabbit@\${HOSTNAME_ROOT}
fi
/usr/sbin/rabbitmqctl start_app
service rabbitmq-server restart
_wrtend_

ROOT_HOST=""
for i in ${!NODES[@]}; do
    #idx=`expr $i + 1`
    eval node_info=(\${${NODES[$i]}[@]})
    echo -e "\033[33m Install RabbitMQ on ${node_info[0]} \033[0m"
    if [ $i == 0 ];then
        ROOT_HOST=${node_info[0]}
    fi

    sshpass -p ${ROOT_PASS} scp -o StrictHostKeyChecking=no /tmp/tmp_install_rabbitmq.sh root@${node_info[1]}:/tmp/
    sshpass -p ${ROOT_PASS} scp -o StrictHostKeyChecking=no /tmp/tmp_hosts root@${node_info[1]}:/tmp/
    sshpass -p ${ROOT_PASS} scp -o StrictHostKeyChecking=no ./rabbitmq-signing-key-public.asc root@${node_info[1]}:/tmp/
    if [ "${node_info[2]}" == "ram" ];then
        sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[1]} /bin/bash /tmp/tmp_install_rabbitmq.sh -h ${ROOT_HOST} -r
    else
        sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[1]} /bin/bash /tmp/tmp_install_rabbitmq.sh -h ${ROOT_HOST}
    fi
    echo -e "\033[33m Install RabbitMQ done ${node_info[0]} \033[0m"
done

echo -e "\033[33m Configure RabbitMQ Cluster \033[0m"
for i in ${USERS[@]}; do
    eval user_info=(\${${USERS[$i]}[@]})
    /usr/sbin/rabbitmqctl add_user ${user_info[0]} ${user_info[1]}
    /usr/sbin/rabbitmqctl set_user_tags ${user_info[0]} ${user_info[2]}
    /usr/sbin/rabbitmqctl set_permissions -p / ${user_info[0]} ".*" ".*" ".*"
done

# Set up HA Policy
# for RabbitMQ 3.x
/usr/sbin/rabbitmqctl set_policy ha-all "^" '{"ha-mode":"all"}'
echo -e "\033[33m Configure done \033[0m"

# Install and configure HAProxy
if [ -z "${HAPROXY_ROOT[0]}" ];then
    SET_HA=false
else
    SET_HA=true
fi

if $SET_HA;then
    echo -e "\033[33m Deploy HAProxy on ${HAPROXY_ROOT[0]} \033[0m"
    # Step 1. copy file
    cp ./haproxy.cfg /tmp/tmp_haproxy.cfg

    echo "listen rabbitmq 0.0.0.0:"${HAPROXY_ROOT[1]} >> /tmp/tmp_haproxy.cfg
    echo "	mode	tcp" >> /tmp/tmp_haproxy.cfg
    echo "	balance	roundrobin" >> /tmp/tmp_haproxy.cfg

    # Step 2. append config
    for i in ${!NODES[@]}; do
        eval node_info=(\${${NODES[$i]}[@]})
        echo "	server	${node_info[0]}	${node_info[1]}:5672	check   inter   2000 rise 2 fall 3" >> /tmp/tmp_haproxy.cfg
    done

    # Step 3. create temp install script
cat > /tmp/tmp_deploy_haproxy.sh << _wrtend_
#!/bin/bash
#set -x
service haproxy stop
ps -ef | grep haproxy | grep -v grep | grep -v tmp_deploy_haproxy.sh | awk '{print \$2}' | xargs kill
apt-get -y --force-yes install haproxy
cp /tmp/tmp_haproxy.cfg /etc/haproxy/haproxy.cfg
/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -D
set +x
_wrtend_

    # Step 4. install and configure
    sshpass -p ${ROOT_PASS} scp -o StrictHostKeyChecking=no /tmp/tmp_haproxy.cfg /tmp/tmp_deploy_haproxy.sh root@${HAPROXY_ROOT[0]}:/tmp/
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${HAPROXY_ROOT[0]} /bin/bash /tmp/tmp_deploy_haproxy.sh
    echo "Deploy HAProxy done."
    echo -e "\033[33m Deploy HAProxy done \033[0m"
fi

