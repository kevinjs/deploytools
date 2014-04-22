# RabbitMQ + HAProxy deploy tool

## deploy_rabbitmq_cluster.cfg
Configure of deploy\_glusterfs.sh

	# RabbitMQ Nodes
	# The first node is default root.
	node_1=(mq-1 10.0.1.1 disk)
	node_2=(mq-2 10.0.1.2 ram)
	NODES=(node_1 node_2)

	# Rabbitmq Users
	user_1=(web_admin web.admin monitoring)
	user_2=(mgmt_admin mgmt.admin administrator)
	USERS=(user_1 user_2)

	# HAProxy configure (Optional)
	HAPROXY_ROOT=(10.0.1.3 5672)

`node_x`

RabbitMQ node information. (hostname ip_address mode)

`NODES`

RabbitMQ nodes list.

`user_x`

User of RabbitMQ. You can only use guest on localhost [in RabbitMQ 3.3](http://www.rabbitmq.com/blog/2014/04/02/breaking-things-with-rabbitmq-3-3/). So, you have to create users before use. (username password usertag)

`USERS`

User list.

`HAPROXY_ROOT`

If you want create load balance for RabbitMQ cluster, you have to specify the haproxy root node.

## haproxy.cfg
Execute script. 

`Usage:`

	chmod +x deploy_rabbitmq_cluster.sh

	./deploy_rabbitmq_cluster.sh -p ROOT_PASS

## haproxy.cfg

Sample file of HAProxy configure.

## sources.list

/etc/apt/sources.list using yum.csdb.cn

## rabbitmq-signing-key-public.asc

rabbitmq source file

