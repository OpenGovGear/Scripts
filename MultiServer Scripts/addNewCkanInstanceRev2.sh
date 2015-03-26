#!/bin/bash
###########
# <param1> : Instance Name
# <param2> : Postgres Server IP
# <param3> : Postgres Server Password
# <param4> : Serve with Paster at the end(y/n)
###########
strInstanceName=$1
strRemote=$2
strPass=$3
strPasterServe=$4

if [ -z "$strInstanceName" ]
then
	read -p "Instance Name: " strInstanceName
fi

if [ -z "$strRemote" ]
then
	read -p "Postgres Server IP: " strRemote
fi

if [ -z "$strPass" ]
then
	read -p "Postgres Server Password: " strPass
fi

if [ -z "$strPasterServe" ]
then
	read -p "Serve with Paster at the end(y/n): " strPasterServe
fi

#Exit if something is wrong (this is a short-circuit)
if [ -z "$strInstanceName" ] || [ -z "$strRemote" ] || [ -z "$strPass" ] || [ -z "$strPasterServe" ]
then
	echo "This script will install a new ckan instance."
	echo "./<script name>.sh <parm1> <param2> <param3> <param4>"
	echo "<param1> : Instance Name"
	echo "<param2> : Postgres Server IP"
	echo "<param3> : Postgres Server Password"
	echo "<param4> : Serve with Paster at the end(y/n)"
	exit 1
fi

#set up python virtual enviroment
sudo mkdir -p /usr/lib/ckan/${strInstanceName}
sudo chown `whoami` /usr/lib/ckan/${strInstanceName}
virtualenv --no-site-packages /usr/lib/ckan/${strInstanceName}
. /usr/lib/ckan/${strInstanceName}/bin/activate

#Install CKAN source
pip install -e 'git+https://github.com/ckan/ckan.git@ckan-2.3#egg=ckan'
pip install -r /usr/lib/ckan/${strInstanceName}/src/ckan/requirements.txt
deactivate
. /usr/lib/ckan/${strInstanceName}/bin/activate

#Create a CKAN Config File
sudo mkdir -p /etc/ckan/${strInstanceName}
sudo chown -R `whoami` /etc/ckan/
cd /usr/lib/ckan/${strInstanceName}/src/ckan
paster make-config ckan /etc/ckan/${strInstanceName}/development.ini

#Format sqlalchamy url
# sqlalchemy.url = postgresql://ckan_default:pass@localhost/ckan_default
sudo sed -i "s/ckan_default\:pass\@localhost\/ckan_default/${strInstanceName}\:{$strPass}\@${strRemote}\/${strInstanceName}/" /etc/ckan/${strInstanceName}/development.ini 
sudo sed -i "s/ckan.site_id = default/ckan.site_id = ${strInstanceName}/" /etc/ckan/${strInstanceName}/development.ini # ckan.site_id = default
sudo sed -i "s/#solr_url = http:\/\/127.0.0.1:8983\/solr/solr_url = http:\/\/${strRemote}:8983\/solr\/${strInstanceName}/" /etc/ckan/${strInstanceName}/development.ini # #solr_url = http://127.0.0.1:8983/solr

cd /usr/lib/ckan/${strInstanceName}/src/ckan
paster db init -c /etc/ckan/${strInstanceName}/development.ini

ln -s /usr/lib/ckan/${strInstanceName}/src/ckan/who.ini /etc/ckan/${strInstanceName}/who.ini

if [ $strPasterServe == "y" ] 
then
	cd /usr/lib/ckan/${strInstanceName}/src/ckan
	paster serve /etc/ckan/${strInstanceName}/development.ini
	exit 1
fi