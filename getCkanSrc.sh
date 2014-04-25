#!/bin/bash

#This script starts it all. Creates a server with CKAN src, default 
#config and all dependancies, and starts solr on jetty. Doesn't create 
#database. The image created with this script will be ready to customize
#the config file, establish a database schema, mount a filestore, prep 
#plugins as part of new client staging

#enable locate command
updatedb

#set timezone
echo "US/Pacific" | sudo tee /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata

#For time correction
apt-get install -y ntp
service ntp status

#Make sure logging uses the right time too
service rsyslog restart

#install CKAN dependencies
apt-get install -y python-dev postgresql libpq-dev python-pip python-virtualenv git-core solr-jetty openjdk-6-jdk apache2 libapache2-mod-wsgi nginx

#Enable jetty and configure to serve internally
cd /etc/default
sed -i 's/NO_START=1/NO_START=0/' jetty
sed -i 's/#JETTY_HOST=/JETTY_HOST=127.0.0.1 #/' jetty
sed -i 's/#JETTY_PORT=8080/JETTY_PORT=8983/' jetty
sed -i 's/#JAVA_HOME=/JAVA_HOME=\/usr\/lib\/jvm\/java-6-openjdk-amd64\//' jetty

#create CKAN src tree and virtualenv
mkdir -p /usr/lib/ckan/default
chown $SUDO_USER /usr/lib/ckan/default
virtualenv /usr/lib/ckan/default

#install CKAN src
. /usr/lib/ckan/default/bin/activate
pip install -e 'git+https://github.com/ckan/ckan.git@ckan-2.2#egg=ckan'
pip install -r /usr/lib/ckan/default/src/ckan/requirements.txt
cp /usr/lib/ckan/default/src/ckan/ckan/public/base/css/main.css /usr/lib/ckan/default/src/ckan/ckan/public/base/css/main.debug.css #necessary to enable debug mode, not sure why this file isn't present to begin with, hope this is an acceptable fix but don't know

#create CKAN config file development.ini
mkdir -p /etc/ckan/default
chown -R $SUDO_USER /etc/ckan/
cd /usr/lib/ckan/default/src/ckan
paster make-config ckan /etc/ckan/default/development.ini

