#!/bin/bash

#
# function to configure multiple IPs for centOS
#


# ifconfig is not installed on minimal and we need it in order to get the netmask
requirements () {
ifconfig > /dev/null 2>&1
if [ $? = 127 ]; then
	yum install -qy net-tools
elif [ $? = 0 ]; then
	echo "Net-tools is already installed"
	break
fi
}
#check if the IPs entered are in a valid format and saves them to a /tmp/iplist which will be later removed
validateIps () {

ipValidator='^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$'
while true
do
#	touch /tmp/iplist
	echo -n "Insert IP [Type 0 to exit]: "
	read IP
	if [[ $IP =~ $ipValidator ]]; then
		echo "Good"
		echo $IP >> /tmp/iplist
	elif [[ $IP = 0 ]]; then
		echo "exiting function"
		break
	else
		echo "$IP is not in supported format [Type 0 to exit] "
	fi
done
}


addIpsCentos () {

n="0"
numberofIPs=$(wc -l /tmp/iplist | awk '{print $1}')
interface=$(ip addr show | awk '/inet.*brd/{print $NF}' | head -n 1)
netmask=$(ifconfig $interface | grep netmask | awk '{print$4}')
netCentos="/etc/sysconfig/network-scripts/ifcfg-$interface"
while [ $n -lt $numberofIPs ]
do
	touch $netCentos:$n
	for IP in `cat /tmp/iplist`;do
		echo "Configuring $IP on $netCentos:$n"
		echo "DEVICE=\"$interface:$n\"" >> $netCentos:$n
		echo "IPADDR=\"$IP\"" >> $netCentos:$n
		echo "NETMASK=\"$netmask\"" >> $netCentos:$n
		echo "ONBOOT=\"yes\"" >> $netCentos:$n
		n=$(( $n + 1 ))
	done
done
}

requirements
validateIps
addIpsCentos

rm -rf /tmp/iplist


