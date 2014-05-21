#!/bin/bash
# Author: dysj4099@gmail.com
# May 21. 2014

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
SHARDS=()
for i in ${!PORTS[@]}; do
    if [ $[i%2] -eq 0 ]; then
        eval ${PORTS[$((i))]}_p=${PORTS[$((i+1))]}
        if [ "${PORTS[$((i))]}" != "config" ] && [ "${PORTS[$((i))]}" != "mongos" ];then
            SHARDS=("${SHARDS[@]}" "${PORTS[$((i))]}")
        fi
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

# Step 4: Mkdir and start services
echo -e "\033[33m--Copy files-- \033[0m"
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

echo -e "\033[33m--Start services-- \033[0m"
for node in ${NODES[@]}; do
    eval node_info=(\${$node[@]})
    for i in ${!node_info[@]}; do
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
        fi
    done
    echo -e "\033[33m--Copy files to ${node_info[0]}-- \033[0m" 
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[0]} mkdir -p ${DATA_PATH}
    sshpass -p ${ROOT_PASS} scp -o StrictHostKeyChecking=no -r /tmp/start_${node}.sh root@${node_info[0]}:${DATA_PATH}
    sshpass -p ${ROOT_PASS} scp -o StrictHostKeyChecking=no -r ${PKG_PATH} /tmp/tmp_${node}_mkdir.sh root@${node_info[0]}:/tmp
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[0]} tar -xzvf /tmp/${ori_name} -C /tmp/
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[0]} mv /tmp/${pkg_name} ${DATA_PATH}/mongodb/
    echo -e "\033[33m--Init on ${node_info[0]}-- \033[0m"
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[0]} /bin/bash /tmp/tmp_${node}_mkdir.sh
    sshpass -p ${ROOT_PASS} ssh -o StrictHostKeyChecking=no root@${node_info[0]} /bin/bash ${DATA_PATH}/start_${node}.sh
done

# Step 5: Config shards and reps
echo -e "\033[33m--Config shards-- \033[0m"

if [ -f "/tmp/tmp_config_mongo.sh" ];then
    rm /tmp/tmp_config_mongo.sh
fi
touch /tmp/tmp_config_mongo.sh
echo "#!/bin/bash" >> /tmp/tmp_config_mongo.sh

for shn in ${SHARDS[@]};do
    eval shns=(\${$shn[@]})
    shn_pn=$shn"_p"
    shard_conf_str="${DATA_PATH}/mongodb/bin/mongo ${shns[0]}:${!shn_pn}/admin -eval \"config={_id:'${shn}',members:["
    tmp_str=""
    for i in ${!shns[@]};do
        if [ -z "$tmp_str" ];then
            tmp_str="{_id:"$i",host:'"${shns[$i]%_arb}:${!shn_pn}"'"
        else
            tmp_str=${tmp_str},"{_id:"$i",host:'"${shns[$i]%_arb}:${!shn_pn}"'"
        fi
        if [[ "${shns[$i]}" =~ _arb$ ]];then
            tmp_str=${tmp_str}",arbiterOnly:true"
        fi
        tmp_str=${tmp_str}"}"
    done
    shard_conf_str=${shard_conf_str}${tmp_str}"]};rs.initiate(config);\""
    echo $shard_conf_str >> /tmp/tmp_config_mongo.sh
    echo "sleep 1" >> /tmp/tmp_config_mongo.sh
    #$shard_conf_str
done

echo "sleep 20" >> /tmp/tmp_config_mongo.sh

echo -e "\033[33m--Config reps-- \033[0m"
for shn in ${SHARDS[@]};do
    eval shns=(\${$shn[@]})
    shn_pn=$shn"_p"
    rep_conf_str="${DATA_PATH}/mongodb/bin/mongo 127.0.0.1:${mongos_p}/admin -eval \"db.runCommand({addshard:'"
    tmp_str=""
    for i in ${!shns[@]};do
        if [ -z "$tmp_str" ];then
            tmp_str="ok"
            rep_conf_str=${rep_conf_str}${shn}/${shns[$i]%_arb}:${!shn_pn}
        else
            rep_conf_str=${rep_conf_str},${shns[$i]%_arb}:${!shn_pn}
        fi
    done
    rep_conf_str=${rep_conf_str}"'});\""
    echo $rep_conf_str >> /tmp/tmp_config_mongo.sh
    echo "sleep 1" >> /tmp/tmp_config_mongo.sh
    #$rep_conf_str
done

sleep 5
/bin/bash /tmp/tmp_config_mongo.sh

echo -e "\033[33m--Clean files-- \033[0m"
rm /tmp/tmp_${node}_mkdir.sh
rm /tmp/start_${node}.sh
rm -rf /tmp/mongodb

echo -e "\033[33m--Install success-- \033[0m"
