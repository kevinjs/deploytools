#!/bin/bash
# Author: dysj4099@gmail.com

# Read config
. ./deploy_mongodb.cfg

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

# Step 1: Install sshpass
echo -e "\033[33m--Install sshpass-- \033[0m"
yum -y install sshpass.x86_64

# Step 2: Get ports of each server
for i in ${!PORTS[@]}; do
    if [ $[i%2] -eq 0 ]; then
        eval ${PORTS[$((i))]}_p=${PORTS[$((i+1))]}
    fi
done

# Step 3: Decompress package
echo -e "\033[33m--Decompress package-- \033[0m"
ori_name=$(basename $PKG_PATH)
pkg_name=$(basename $PKG_PATH)
echo $pkg_name
if [[ "${PKG_PATH}" =~ .tgz$ ]];then
    pkg_name=${pkg_name%.*}
elif [[ "${PKG_PATH}" =~ .tar.gz$ ]];then
    pkg_name=${pkg_name%%.*}
fi

node_port=""
c=0
for node in ${NODES[@]}; do
    c=`expr $c + 1`
    eval node_info=(\${$node[@]})

    if [ -f "/tmp/tmp_${node}_mkdir.sh" ];then
        rm /tmp/tmp_${node}_mkdir.sh
    fi
    if [ -f "/tmp/start_${node}.sh" ];then
        rm /tmp/start_${node}.sh
    fi

    touch /tmp/tmp_${node}_mkdir.sh
    touch /tmp/start_${node}.sh

    echo "#!/bin/bash" >> /tmp/tmp_${node}_mkdir.sh
    echo "#!/bin/bash" >> /tmp/start_${node}.sh

    for i in ${!node_info[@]}; do
        if (( $i > 0 ));then
            svr=${node_info[$i]%_arb}
            echo "mkdir -p ${DATA_PATH}/${svr}/log ${DATA_PATH}/${svr}/data" >> /tmp/tmp_${node}_mkdir.sh
        fi
    done

    if [ -z "$node_port" ];then
        node_port=${node_info[0]}:${config_p}
    fi
done

for node in ${NODES[@]}; do
    eval node_info=(\${$node[@]})
    for i in ${!node_info[@]}; do
        # skip line 1 (IP Address)
        if (( $i > 0 ));then
            svr=${node_info[$i]%_arb}
            svr_pn=$svr"_p"

            if [ "$svr" == "config" ];then
                echo "numactl --interleave=all ${DATA_PATH}/mongodb/bin/mongod --configsvr --dbpath ${DATA_PATH}/config/data --port ${!svr_pn} --logpath ${DATA_PATH}/config/log/config.log --fork" >> /tmp/start_${node}.sh
            elif [ "$svr" == "mongos" ];then
                echo "numactl --interleave=all ${DATA_PATH}/mongodb/bin/mongos --configdb $node_port --port ${!svr_pn} --logpath ${DATA_PATH}/mongos/log/mongos.log --fork" >> /tmp/start_${node}.sh
            else
                echo "numactl --interleave=all ${DATA_PATH}/mongodb/bin/mongod --shardsvr --replSet ${svr} --port ${!svr_pn} --dbpath ${DATA_PATH}/${svr}/data --logpath ${DATA_PATH}/${svr}/log/${svr}.log --fork --nojournal --oplogSize 10" >> /tmp/start_${node}.sh
            fi
            #if [ "$svr" != "${node_info[$i]}" ];then
            #    echo "haha"
            #fi
        fi
    done
    echo -e "\033[33m--Copy files to ${node_info[0]}-- \033[0m" 
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[0]} mkdir -p ${DATA_PATH}
    sshpass -p ${ROOT_PASS} scp -o StrictHostKeyChecking=no -r /tmp/start_${node}.sh root@${node_info[0]}:${DATA_PATH}
    sshpass -p ${ROOT_PASS} scp -o StrictHostKeyChecking=no -r ${PKG_PATH} /tmp/tmp_${node}_mkdir.sh root@${node_info[0]}:/tmp
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[0]} tar -xzvf /tmp/${ori_name} -C /tmp/
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[0]} mv /tmp/${pkg_name} ${DATA_PATH}/mongodb/
    echo -e "\033[33m--Initiatation on ${node_info[0]}-- \033[0m"
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[0]} /bin/bash /tmp/tmp_${node}_mkdir.sh
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[0]} /bin/bash ${DATA_PATH}/start_${node}.sh
done

echo -e "\033[33m--Clean files-- \033[0m"
rm /tmp/tmp_${node}_mkdir.sh
rm /tmp/start_${node}.sh
rm -rf /tmp/mongodb
