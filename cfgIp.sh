#!/bin/bash
# maintainer: Marian Chelmus email: chelmus.marian at gmail.com
# This script will detect your main IP and it will configure it staticaly
# It will only work with Centos 6/7 and Ubuntu 16.04 WITH CLOUD INIT ENABLED
# If cloud init is already disabled it will not attempt to configure your network
# If cloud init is enabled, it will disable it and it will configure the static IP
#
# getting variables
os=$(awk '/^ID=/' /etc/*-release | awk -F'=' '{ print tolower($2) }' | sed 's/"//' | sed 's/["]//')

interface=$(ip addr show | awk '/inet.*brd/{print $NF}' | head -n 1)

netCentos="/etc/sysconfig/network-scripts/ifcfg-$interface"
netUbuntu="/etc/network/interfaces"
mask=$(ip -f inet a show $interface | grep inet | awk '{ print $2 }' | rev | cut -d / -f1 | rev)
maskCentos=$(ip -f inet a show $interface | grep inet | awk '{ print $2 }' | rev | cut -d / -f1 | rev)
maskUbuntu=$(ifconfig $interface | sed -rn '2s/ .*:(.*)$/\1/p')

gateway=$(ip r | grep default | awk '{print $3}')

defIP=$(ip -f inet a show $interface | grep inet | awk '{ print $2 }' | cut -d / -f1)

# cloud init location
cloudInitDisable="/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg"
cloudInit="/etc/network/interfaces.d/50-cloud-init.cfg"
# configure static IP functions

# function to configure static IP on centos
centos () {
        echo "---------------------------------------------------------------"
	if [ ! -f $netCentos ]
	then
		echo "Network configuration file not found... exiting"
		exit 1
	else
		echo -e "Network configuration file located at: "'\033[1m' $netCentos'\033[0m'
		if grep -q dhcp $netCentos
		then
			sed -i "s/dhcp/static/g" $netCentos
			sed -i "s/.*BOOTPROTO.*/&\nIPADDR=\"$defIP\"/" $netCentos
			sed -i "s/.*IPADDR.*/&\nPREFIX=\"$maskCentos\"/" $netCentos
			sed -i "s/.*PREFIX.*/&\nGATEWAY=\"$gateway\"/" $netCentos
			sed -i "s/.*GATEWAY.*/&\nDNS1=\"8.8.8.8\"/" $netCentos
			sed -i "s/.*GATEWAY.*/&\nDNS2=\"8.8.4.4\"/" $netCentos
			echo "Interface was configured:"
			cat $netCentos
		else
			echo "Interface was already configured"
			cat $netCentos
		fi
	fi
}

# function to configure static IP on Ubuntu 16.04 with Cloud Init Enabled
ubuntu () {

        echo "---------------------------------------------------------------"
        if [ ! -f $netUbuntu ]
        then
                echo "Configuration file not found... Exiting"
                exit 1
        else
                if [ -f $cloudInit ] && [ ! -f $cloudInitDisable ]
		then
		        echo "Cloud init is enabled. Disabling..."
	       	        touch  $cloudInitDisable
		        echo "network: {config: disabled}" > $cloudInitDisable
			echo -e "Network configuration file located at: " '\033[1m' $netUbuntu'\033[0m'
                        sed -i 's/source/#&/' $netUbuntu
			echo "auto $interface" >> $netUbuntu
			echo "iface $interface inet static" >> $netUbuntu
			echo "        address $defIP" >> $netUbuntu
                        echo "        netmask $maskUbuntu" >> $netUbuntu
                        echo "        gateway $gateway" >> $netUbuntu
                        echo "        dns-nameservers 8.8.8.8 8.8.4.4" >> $netUbuntu
                        echo "Interface was configured: "
                        cat $netUbuntu
                else
                        echo "Interface was already configured"
                        cat $netUbuntu
                fi
        fi

}


# ifconfig is not installed on minimal and we need it in order to get the netmask
requirements () {
ifconfig > /dev/null 2>&1
if [ $? = 127 ]; then
	echo "Installing net-tools..."
	yum install -y -q net-tools
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
       touch /tmp/iplist
        echo -n "Insert IP [Type 0 to exit]: "
        read IP
        if [[ $IP =~ $ipValidator ]]; then
                echo $IP >> /tmp/iplist
        elif [[ $IP = 0 ]]; then
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

addIpsUbuntu () {
echo "" >> $netUbuntu
for n in `cat /tmp/iplist`
do
	echo "post-up ip a a $n/$mask dev $interface" >> $netUbuntu
done
}

IPsOS () {
if [ $os == 'centos' ];then
	addIpsCentos
elif [ $os ==  'ubuntu' ];then
	addIpsUbuntu
else
	echo "OS not detected. Please be sure that you are running this on centos or ubuntu machine"
fi
}

echo "select the OS  1) Cent0S 2) UBUNTU"

read n
case $n in
    1) centos;;
    2) ubuntu;;
    *) invalid option;;
esac



echo "Do you want to add more IPs? 1) Yes 2) No"
read m
case $m in
	1) requirements;
	   validateIps;
	   IPsOS;;
	2) exit;;
	*) invalid option;;
esac

for z in `cat /tmp/iplist`
do
	echo "Successfuly configured: $z"
done

echo "Please reboot your machine!"
# delete /tmp/iplist
rm -rf /tmp/iplist
