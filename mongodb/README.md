# MongoDB deploy tool

## deploy\_mongodb.cfg
Configure of deploy\_mongodb.sh
	
	DATA_PATH=/data/mongo_data
	PKG_PATH=/opt/mongodb-linux-x86_64-2.6.1.tgz
	
	# Nodes in cluster.
	# nodex=(ip service1 service2 ...)
	node1=(10.3.0.6 config mongos shard1 shard4 shard5)
	node2=(10.3.0.8 config mongos shard1 shard2 shard5)
	node3=(10.3.0.9 config mongos shard1 shard2 shard3)
	node4=(10.3.0.10 config mongos shard2 shard3 shard4)
	node5=(10.3.0.12 config mongos shard3 shard4 shard5)
	NODES=(node1 node2 node3 node4 node5)
	
	# Ports of each service
	PORTS=(mongos 27017 config 27016 shard1 27011 shard2 27012 shard3 27013 shard4 27014 shard5 27015)

	# Shards in cluster, '_arb' specify the arbiter node
	shard1=(10.3.0.6 10.3.0.8 10.3.0.9_arb)
	shard2=(10.3.0.8 10.3.0.9 10.3.0.10_arb)
	shard3=(10.3.0.9 10.3.0.10 10.3.0.12_arb)
	shard4=(10.3.0.10 10.3.0.12 10.3.0.6_arb)
	shard5=(10.3.0.12 10.3.0.6 10.3.0.8_arb)

`DATA_PATH`

Path of MongoDB source package.

`nodex` and `NODES`

MongoDB node list.

`PORTS`

Port number of each service.

`shardx`

Sharding information. You can specify arbiter node by add "_arb" suffix.

## deploy\_mongodb.sh

`Usage:`

	chmod +x deploy_mongodb.sh
	./deploy_mongodb.sh -p ROOT_PASS