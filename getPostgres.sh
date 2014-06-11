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
sudo apt-get update
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
sudo apt-get install -y postgresql libpq-dev solr-jetty openjdk-6-jdk python-dev python-pip python-virtualenv

#install python virtualenv and ckan source
sudo mkdir -p /usr/lib/ckan/default
sudo chown `whoami` /usr/lib/ckan/default
virtualenv --no-site-packages /usr/lib/ckan/default
. /usr/lib/ckan/default/bin/activate
pip install -e 'git+https://github.com/ckan/ckan.git@ckan-2.2#egg=ckan'

#Enable jetty and configure to serve internally
cd /etc/default
sudo sed -i 's/NO_START=1/NO_START=0/' jetty
sudo sed -i "s/#JETTY_HOST=/JETTY_HOST=0.0.0.0 #/" jetty
sudo sed -i 's/#JETTY_PORT=8080/JETTY_PORT=8983/' jetty
sudo sed -i 's/#JAVA_HOME=/JAVA_HOME=\/usr\/lib\/jvm\/java-6-openjdk-amd64\//' jetty

#enable multicore solr search platform on jetty and start
sudo cp /home/ubuntu/Scripts/scriptFiles/solr.xml /usr/share/solr/.
sudo -u jetty mkdir /var/lib/solr/data/ckan_default
sudo mkdir /etc/solr/ckan_default
sudo mv /etc/solr/conf /etc/solr/ckan_default/
sudo mv /etc/solr/ckan_default/conf/schema.xml /etc/solr/ckan_default/conf/schema.xml.bak
sudo ln -s /usr/lib/ckan/default/src/ckan/ckan/config/solr/schema.xml /etc/solr/ckan_default/conf/schema.xml
sudo sed -i 's_/var/lib/solr/data_${dataDir}_' /etc/solr/ckan_default/conf/solrconfig.xml
sudo mkdir /usr/share/solr/ckan_default
sudo ln -s /etc/solr/ckan_default/conf /usr/share/solr/ckan_default/conf
sudo service jetty start

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
