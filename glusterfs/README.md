# GlusterFS deploy tool

## deploy\_glusterfs.cfg
Configure of deploy\_glusterfs.sh

	# Path of package
	PKG_PATH=/opt/files/glusterfs-3.4.0.tar.gz
	# Gluster peer list
	NODES=(192.168.1.1 192.168.1.2 192.168.1.3)
	# Gluster volume list
	# vol_name data_path ips_list replica_num(optional)
	vol_1=(vol_1 /opt/vol_1 192.168.1.1,192.168.1.2 2)
	vol_2=(vol_2 /opt/vol_2 192.168.1.1,192.168.1.2,192.168.1.3)
	VOLUMES=(vol_1 vol_2)

`PKG_PATH`

The path of glusterfs source package. You have to change relevant name in deploy\_glusterfs.sh before install.

`NODES`

Peers list

`vol_x`

Volume information.(vol\_name data\_path peer\_ip\_list replica\_num). The replica\_num is not necessary.

`VOLUMES`

Volume list.

## deploy\_glusterfs.sh
Execute script. You have to change the decompress path if you use another version of gluster before install.

`Usage:`

	chmod +x deploy_glusterfs.sh

	./deploy_gluster.sh -p ROOT_PASS
