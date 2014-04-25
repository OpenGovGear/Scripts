#!/bin/bash

#This script creates a production context in 
#which launchclient will send a client into production.  
#the ckan src is already installed and the default development.ini
#file as well, but none of the necessary configurations have taken
#place,  solr has not been started and who.ini has not been linked
 
#########################################################################################
#Check whether we're using a volume copied from prod
#that doesn't need formatting
#Mount external filestore
#echo "Enter the three letter device identifier for the volume to mount (n if you don't know):"
#read volID

#if [ ${volID} = "n" ] #give user an out if they don't have the dev id
#then
#	echo 'Run sudo fdisk -l to view attached devices'
#	exit 1
#fi

#Check whether we're using a volume copied from prod
#that doesn't need formatting
#echo "Does the volume require formatting(y/n)?"
#read reqfrmt
#if [ ${reqfrmt} = "y" ]
#then
#	sudo mkfs -t ext4 /dev/${volID}
#	echo 'Formatting device $volID as ext4'
#fi

#mount the volume
#sudo mkdir /FSTORE
#sudo mount /dev/${volID} /FSTORE
#################################################################################################
echo "Have you created the ckan_default database user and schema with password on the database server?(y/n)"
read confirmdb
if [ ${confirmdb} = "n" ]
then
	echo 'Please create the database user, schema and password on the database server before continuing.'
	exit 1
fi

echo "Enter the local subnet fixed ip for the database server: (n if unknown)"
read dbserv
if [ ${dbserv} = "n" ]
then
	echo "Please confirm the database server's fixed ip before continuing."
	exit 1
fi

#Install apache and nginx
sudo apt-get install -y apache2 libapache2-mod-wsgi nginx

#TO-DO HOW TO INSTALL POSTFIX FROM COMMAND LINE AND CONFIGURE


#Put nginx and apache configuration files in place
sudo cp scriptFiles/apache.wsgi /etc/ckan/default/.
sudo cp scriptFiles/ogg-proxy /etc/nginx/sites-available/.
sudo ln /etc/nginx/sites-available/ogg-proxy /etc/nginx/sites-enabled/ogg-proxy
sudo rm /etc/nginx/sites-enabled/default

sudo sed -i 's/80/8080/' /etc/apache2/ports.conf
sudo cp scriptFiles/ckan_default /etc/apache2/sites-available/. 
sudo ln -s /usr/lib/ckan/default/src/ckan/who.ini /etc/ckan/default/who.ini
sudo mv /etc/solr/conf/schema.xml /etc/solr/conf/schema.xml.bak
sudo ln -s /usr/lib/ckan/default/src/ckan/ckan/config/solr/schema.xml /etc/solr/conf/schema.xml #TO-DO maybe change this to work with multicore solr

#customize development.ini configuration
cd /etc/ckan/default
#sudo sed -i "s/ckan_default/ckan_default/" development.ini #commented out best way to leave as default user
sudo sed -i "s/pass\@localhost/zandt2014\@${dbserv}/" development.ini #password for postgres connection
sudo sed -i "s/ckan_default/ckan_default_db?sslmode=disable/2" development.ini #table schema name
#sudo sed -i "s/ckan.site_url =/ckan.site_url = http:\/\/${hostIP}/ development.ini" 
sudo sed -i "s/CKAN/DEMO/" development.ini #Site title
sudo sed -i "s/#solr_url/solr_url/" /etc/ckan/default/development.ini #activate solr
#sudo sed -i "s_8983/solr_8983/solr/ckan\_default_" /etc/ckan/default/development.ini #enable this core
sudo sed -i "s/#ckan.storage_path/ckan.storage_path/" development.ini #activate file store
#sudo sed -i "s_/var/lib/ckan_/FSTORE/default_" development.ini #set file store location
sudo sed -i "s_/var/lib/ckan_/var/lib/ckan/default_" development.ini #set internal file store location

#initialise file store in production
#sudo mkdir -p /FSTORE/ckan_default
#sudo chown -R www-data /FSTORE/default #apache user must have permissions over file store 
#sudo chmod u+rwx /FSTORE/default #maintainer's guide says to use this command

#just use var for filestore now in development
sudo mkdir -p /var/lib/ckan/default
sudo chown -R www-data /var/lib/ckan/default #apache user must have permissions over file store 
sudo chmod u+rwx /var/lib/ckan/default #maintainer's guide says to use this command

#enable multicore solr search platform on jetty and start
#sudo cp /home/ubuntu/Scripts/scriptFiles/solr.xml /usr/share/solr/.
#sudo -u jetty mkdir /var/lib/solr/data/ckan_default
#sudo mkdir /etc/solr/ckan_default
#sudo mv /etc/solr/conf /etc/solr/ckan_default/
#sudo mv /etc/solr/ckan_default/conf/schema.xml /etc/solr/ckan_default/conf/schema.xml.bak
#sudo ln -s /usr/lib/ckan/default/src/ckan/ckan/config/solr/schema.xml /etc/solr/ckan_default/conf/schema.xml
#sudo sed -i 's_/var/lib/solr/data_${dataDir}_' /etc/solr/ckan_default/conf/solrconfig.xml
#sudo mkdir /usr/share/solr/ckan_default
#sudo ln -s /etc/solr/ckan_default/conf /usr/share/solr/ckan_default/conf
sudo service jetty start

#initialise db
cd /usr/lib/ckan/default/src/ckan
. /usr/lib/ckan/default/bin/activate
paster db init -c /etc/ckan/default/development.ini

sudo cp /etc/ckan/default/development.ini /etc/ckan/default/production.ini
sudo a2ensite ckan_default
sudo a2dissite default
sudo service apache2 restart
sudo service nginx restart
