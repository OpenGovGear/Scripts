#!/usr/bin/env bash

#this script should be run once on a staging server to set up
#an onboarding client. Once onboarding of the client is done
#and moved to the production server the instance should be removed
#because this script is not set up to run a second time (could be if needed)
#the main purpose of this script is to customize the configuration 
#file, initialize the database catalogue, external file store and 
#plug-ins. Although the production environment will have an external 
#database server, for development purpose that shouldn't be necessary
#just use the local postgres, then dump it and load onto prod using
#git. After work is done on this server, use loadclient script to
#create production.ini file, dump db, and move everything to GIT

#Mount external filestore
#echo "Enter the three letter volume identifier(n if you don't know):"
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

echo Enter your user name for git:
read user

echo 'Enter your email address for git:'
read mail

git config --global user.name "${user}"
git config --global user.email "${mail}"
#git config --global credential.helper store #nice if you want to not have to put password in when you interact with git

#Get all required details about this deployment
echo "Enter client organization's name:"
read orgName

echo "Enter this machine's floating ip address:"
read hostIP

#create this client's directory trees from default
sudo mkdir -p /usr/lib/ckan/${orgName}
sudo chown `whoami` /usr/lib/ckan/${orgName}
virtualenv  --no-site-packages /usr/lib/ckan/${orgName}
. /usr/lib/ckan/${orgName}/bin/activate
pip install -e 'git+https://github.com/ckan/ckan.git@ckan-2.2#egg=ckan'
pip install -r /usr/lib/ckan/${orgName}/src/ckan/requirements.txt
deactivate
. /usr/lib/ckan/${orgName}/bin/activate
sudo cp -r /usr/lib/ckan/${orgName}/src/ckan/ckan/public/base/css/main.css /usr/lib/ckan/${orgName}/src/ckan/ckan/public/base/css/main.debug.css
sudo cp -r /etc/ckan/default /etc/ckan/${orgName}
sudo ln -s /usr/lib/ckan/${orgName}/src/ckan/who.ini /etc/ckan/${orgName}/who.ini

#customize development.ini configuration
cd /etc/ckan/${orgName}
sudo sed -i s/false/true/ development.ini #for development
sudo sed -i s/ckan_default/${orgName}/ development.ini #user for postgres connection
sudo sed -i s/pass/capstone/ development.ini #password for postgres connection
sudo sed -i s/ckan_default/${orgName}_db/ development.ini #table schema
sudo sed -i "s/ckan.site_url=/ckan.site_url = http:\/\/${hostIP}/" development.ini 
sudo sed -i s/default/${orgName}/ development.ini #site_id parameter
sudo sed -i s/CKAN/${orgName}/ development.ini #site_title wish we could make it all caps or capinit
sudo sed -i 's/#solr_url/solr_url/' /etc/ckan/default/development.ini #activate solr
sudo sed -i 's/#ckan\.storage_path/ckan\.storage_path/' development.ini #activate file store
#sudo sed -i s_/var/lib/ckan_/FSTORE/${orgName}_ development.ini #set file store location (external)
sudo sed -i s_/var/lib/ckan_/var/lib/ckan/${orgName}_ #set file store (internal)

#initialise external file store
#sudo mkdir -p /FSTORE/${orgName}
#sudo chown `whoami` /FSTORE/${orgName} #paster runs under the id of 
					#whatever user started it
#sudo chmod u+rwx /FSTORE/${orgName} #because the user guide says so

#initiliase internal file store
sudo mkdir -p /var/lib/ckan/${orgName}
sudo chown `` /var/lib/ckan/${orgName}
sudo chmod u+rwx /var/lib/ckan/${orgName}

#enable CKAN solr search platform on jetty and start
sudo mv /etc/solr/conf/schema.xml /etc/solr/conf/schema.xml.bak
sudo ln -s /usr/lib/ckan/${orgName}/src/ckan/ckan/config/solr/schema.xml /etc/solr/conf/schema.xml
sudo service jetty start

#create client database user, password and schema and initialise db
sudo -u postgres createuser -S -D -R ${orgName}
sudo -u postgres psql -U postgres -d postgres -c "alter user ${orgName} with password 'capstone';"
sudo -u postgres createdb -O ${orgName} ${orgName}_db -E utf-8
cd /usr/lib/ckan/${orgName}/src/ckan
. /usr/lib/ckan/${orgName}/bin/activate
paster db init -c /etc/ckan/${orgName}/development.ini

#serve client on port 5000
paster serve /etc/ckan/${orgName}/development.ini


