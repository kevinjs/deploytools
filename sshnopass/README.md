# The Automatic installation script of ssh connection with no password

## sshnopass.cfg
Configure of sshnopass.sh

	# IP list
	IP_PWS=(192.168.74.4 123123 192.168.74.5 123123)

`IP_PWS`

The pairs of IP address and login password that need ssh connection with no password.
IP_PWS=(IP password IP password ...)

## sshnopass.sh
Execute script.

`Usage:`

        chmod u+x sshnopass.sh

        ./sshnopass.sh
