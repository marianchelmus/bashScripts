#!/bin/bash
#
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
	echo "Configuring the interface for $OS"
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
		fi
	fi
}

# function to configure static IP on Ubuntu 16.04 with Cloud Init Enabled
ubuntu () {

        echo "---------------------------------------------------------------"
        echo "Configuring the interface for $OS"
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

echo "select the OS  1) Cent0S 2) UBUNTU"

read n
case $n in
    1) centos;;
    2) ubuntu;;
    *) invalid option;;
esac


