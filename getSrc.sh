#!/bin/bash

#This script starts it all. Creates a server with CKAN src
#default config and all dependancies, and starts solr on jetty. 
#Doesn't create database. The image created with this script will be ready to customize
#the config file, establish a database schema, mount a filestore, prep 
#plugins as part of new client staging

sudo apt-get update

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
sudo apt-get install -y python-dev postgresql libpq-dev python-pip python-virtualenv git-core 

#create CKAN src tree and virtualenv
sudo mkdir -p /usr/lib/ckan/default
sudo chown `whoami` /usr/lib/ckan/default
virtualenv /usr/lib/ckan/default

#install CKAN src
. /usr/lib/ckan/default/bin/activate
#pip install -e 'git+https://github.com/ckan/ckan.git@ckan-2.2#egg=ckan' #stable release for production
pip install -e 'git+https://github.com/ckan/ckan.git#egg=ckan' #latest master branch commit for development
pip install -r /usr/lib/ckan/default/src/ckan/requirements.txt
sudo cp /usr/lib/ckan/default/src/ckan/ckan/public/base/css/main.css /usr/lib/ckan/default/src/ckan/ckan/public/base/css/main.debug.css #necessary to enable debug mode, not sure why this file isn't present to begin with, hope this is an acceptable fix but don't know

#JUST THE SOURCE INSTALLED, LET OTHER SCRIPTS INITIALIZE ENVIRONMENT

#create CKAN config file development.ini
#sudo mkdir -p /etc/ckan/default
#sudo chown -R `whoami` /etc/ckan/

#cd /usr/lib/ckan/default/src/ckan
#paster make-config ckan /etc/ckan/default/development.ini

