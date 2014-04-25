#/usr/bin/env bash

#this script runs once on an image where postgres and 
#git are already installed along with other housekeeping
# features like ntp. This script must identify a GIT user
#account and password with privileges over OpenGovGear, or 
#it must be built into the image itself. Must use a credential
#helper to avoid being prompted for credentials when interacting 
#remote repo. 

#The script must ask for the internal subnet ip address to receive db requests from and puts an entry in pg_hpa.conf as well as postgresql.conf, and restarts postgres to make the changes effective

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
