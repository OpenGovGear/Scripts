#/usr/bin/env bash

# This script install postgre on a fresh ubuntu install. It also does a few
# housekeeping acctivites: updatedb, ntp. rsyslog, sets up ppk

# The script must ask for the internal subnet ip address to receive db requests
# from and puts an entry in pg_hpa.conf as well as postgresql.conf, and restarts 
# postgres to make the changes effective

echo "Enter the subnet IP address of the main CKAN server:(n if you don't know)"
read ckanIP
if [ ${ckanIP} = "n" ] #give user an out if they don't have the dev id
then
	echo 'Please check CKAN server subnet IP and try again.'
	exit 1
fi

#enable locate command
sudo updatedb

#set timezone
echo "US/Pacific" | sudo tee /etc/timezone
sudo dpkg-reconfigure --frontend noninteractive tzdata

#For time correction
sudo apt-get install -y ntp
sudo service ntp status

#Make sure logging uses the right time too
sudo service rsyslog restart

#install CKAN dependencies
sudo apt-get install -y postgresql libpq-dev

#sed command to make postgresql.conf listen to all ip addresses
cd /etc/postgresql/*/main
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" postgresql.conf

#sed command to set password authentication for ckan server

sudo sed -i "s/127.0.0.1/${ckanIP}/" pg_hba.conf

sudo sed -i "s/RSAAuthentication yes/RSAAuthentication no/" /etc/ssh/sshd_config
sudo sed -i "s/PubkeyAuthentication yes/PubkeyAuthentication no/" /etc/ssh/sshd_config
sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config

#restart postgresand ssh
sudo service postgresql restart
sudo service ssh restart

sudo passwd `whoami`
