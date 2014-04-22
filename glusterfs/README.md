# GlusterFS deploy tool

## deploy\_glusterfs.cfg
Configure of deploy\_glusterfs.sh

`PKG\_PATH`

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

	chmod +x deploy\_glusterfs.sh

	./deploy\_gluster.sh -p ROOT\_PASS
