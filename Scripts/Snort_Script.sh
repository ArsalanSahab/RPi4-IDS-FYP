#!/bin/bash

# Script for Installing and Configuring Snort on RPi

function update_upgrade() {

	#update repositories

	echo -ne "updating and upgrade repositories....\n\n"
	#sudo apt-get upgrade -y
	sudo apt-get update -y

}


function install_Snort() {


# install Snort dependencies
# some users may get errors with installing libpcap-dev libpcre3-dev libdumbnet-dev.
# Incase of package not found error, Google appropriate package as your distro
	sudo apt-get install -y build-essential libnet1-dev checkinstall bison vim git flex libpcap-dev libpcre3-dev libdumbnet-dev openssl 
	
# Downloading Snort and DAQ libraries, include sudo if needed 

	cd $HOME && mkdir snort_src && cd snort_src
	wget http://luajit.org/download/LuaJIT-2.0.5.tar.gz
        sudo tar xzvf LuaJIT-2.0.5.tar.gz
        cd LuaJIT-2.0.5/ && make && sudo make install
	cd ..
	echo -ne "Downloading Snort and DAQ...\n\n"
	wget https://www.snort.org/downloads/snort/snort-2.9.12.tar.gz
# Current version by date
	wget https://www.snort.org/downloads/snort/daq-2.0.6.tar.gz

# Installing DAQ

	tar xvzf daq-2.0.6.tar.gz && cd $HOME/snort_src/daq-2.0.6/
	./configure && make
	echo " provide package description as snort-daq and keep all the other options as default."
	sudo checkinstall -D --install=no --fstrans=no
# A package is created in same directory with .dab extension, run it as
	sudo dpkg -i daq_*_armhf.deb
	 cd ..

# Configuring and Installing Snort

	tar xvfz snort-2.9.12.tar.gz && cd snort-2.9.12/
   	./configure --disable-open-appid && make
   	sudo checkinstall -D --install=no --fstrans=no
# follow same process as daq, another .deb package is created for snort, run it as:
	sudo dpkg -i snort_*_armhf.deb 
	cd 
	sudo ldconfig

# confirm Snort installation directory by 
	which snort

# create a symlink to snort directory
	sudo ln -s /usr/local/bin/snort /usr/sbin/snort

#check snort installation
	snort --version

# Add snort group and user
	sudo groupadd snort
	sudo useradd snort -r -s /sbin/nologin -c SNORT_IDS -g snort

# create snort work directories
	sudo mkdir /etc/snort > /dev/null 2>&1
	sudo mkdir /etc/snort/rules > /dev/null 2>&1
	sudo mkdir /etc/snort/preproc_rules > /dev/null 2>&1
	sudo touch /etc/snort/rules/white_list.rules /etc/snort/rules/black_list.rules /etc/snort/rules/local.rules > /dev/null 2>&1
	sudo mkdir /var/log/snort > /dev/null 2>&1
	sudo mkdir /usr/local/lib/snort_dynamicrules > /dev/null 2>&1
	sudo chmod -R 5775 /etc/snort > /dev/null 2>&1
	sudo chmod -R 5775 /var/log/snort > /dev/null 2>&1
	sudo chmod -R 5775 /usr/local/lib/snort_dynamicrules > /dev/null 2>&1
	sudo chown -R snort:snort /etc/snort > /dev/null 2>&1
	sudo chown -R snort:snort /var/log/snort > /dev/null 2>&1
	sudo chown -R snort:snort /usr/local/lib/snort_dynamicrules > /dev/null 2>&1

	sudo cp $HOME/snort_src/snort-2.9.12/etc/*.conf* /etc/snort > /dev/null 2>&1
	sudo cp $HOME/snort_src/snort-2.9.12/etc/*.map /etc/snort > /dev/null 2>&1

# Disable Default rules in snort.conf

	sudo sed -i 's/include \$RULE\_PATH/#include \$RULE\_PATH/' /etc/snort/snort.conf

#Test run snort
	echo -ne "Test running Snort......\n"
	sleep 3
	sudo snort -T -c /etc/snort/snort.conf -i eth0
}

function edit_snort() {

	echo  -ne " Configuring snort.config file...\n"
	echo  -ne " Add your IP address e.g with subnet 192.168.1.0/24... \n"
	echo  -ne " Press ENTER to continue"
	read -n 1 -s
	sudo vim /etc/snort/snort.conf -c "/ipvar HOME_NET"

	echo -ne " Add your EXTERNAL_NET address \n" 
	echo  " Press ENTER to continue....\n "
	read -n 1 -s

	sudo vim /etc/snort/snort.conf -c "/ipvar EXTERNAL_NET"

	echo  -ne " Adding RULE_PATH to snort.conf file \n"
	sudo sed -i 's/RULE_PATH\ \.\.\//RULE_PATH\ \/etc\/snort\//g' /etc/snort/snort.conf
	sudo sed -i 's/_LIST_PATH\ \.\.\//_LIST_PATH\ \/etc\/snort\//g' /etc/snort/snort.conf
	
	echo  -ne " Enabling local.rules....\n "
	sudo sed -i 's/#include \$RULE\_PATH\/local\.rules/include \$RULE\_PATH\/local\.rules/' /etc/snort/snort.conf
	sudo chmod 766 /etc/snort/rules/local.rules
	# Please disable this rule after testing
	#sudo echo 'alert icmp any any -> $HOME_NET any (msg:"PING ATTACK"; sid:10000001; rev:001;)' >> /etc/snort/rules/local.rules

	#Setting Snort OUTPUT formate
	sudo sed -i 's/# unified2/output unified2: filename snort.u2, limit 128/g' /etc/snort/snort.conf

	while true; do
		echo -ne " Unified2 output is configured. To configure another output select: \n\t\t1 - CSV output\n\t\t2 - TCPdump output\n\t\t3 - CSV and TCPdump output\n\t\t4 - None\n\n\tOption [1-4]: "
		read OPTION
		case $OPTION in

			1 )
				echo  -ne "\n\t CSV output will be configured\n"
				sudo sed -i 's/# syslog/output alert_csv: \/var\/log\/alert.csv default/g' /etc/snort/snort.conf
				break
				;;
			2 )
				echo -ne  "\n\tTCPdump output will be configured\n"
				sudo sed -i 's/# pcap/output log_tcpdump: \/var\/log\/snort\/snort.log/g' /etc/snort/snort.conf
				break
				;;
			3 )
				echo  -ne "\n\tCSV and TCPdump output will be configured\n"
				sudo sed -i 's/# syslog/output alert_csv: \/var\/log\/snort\/alert.csv default/g' /etc/snort/snort.conf
				sudo sed -i 's/# pcap/output log_tcpdump: \/var\/log\/snort\/snort.log/g' /etc/snort/snort.conf
				break
				;;
			4 )
				echo  -ne "\n\t No other output will be configured\n\n"
				break
				;;
			* )
				echo  -ne "\n\t Invalid option\n\n"
				;;
		esac
	done

}

function main() {

	update_upgrade

	install_Snort 

	edit_snort

	#barnyard2_ask
}

main




