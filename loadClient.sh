#/usr/bin/env bash

#This script runs on the staging server once the client is
#ready to go into prod. It creates a production.ini file, a 
#database dump file, and loads them as well as any custom plug-ins
#to git, where they'll be launched into production. The image it runs 
#on will have GIT installed, the OGG admins ID and password already 
#validated using the credential-helper utility 


echo 'Enter the client organization name (lowercase):'
read orgName

echo "Has a git repository been set up for ${orgName} on OGG(y/n)?"
read gitconfirm

if [ ${gitconfirm} = "n" ] #give user an out if they forgot
then
	echo Please create client git repository on OGG then load client
	exit 1
fi

#create a git repository connected to OpenGovGear somehow
sudo mkdir -p /home/${orgName}
sudo chown `whoami` /home/${orgName}/
cd /home/${orgName}
git init
touch README
cat "Staging resources for ${orgName}" > README

#Dump database and move dump file to local git repository
. /usr/lib/ckan/default/bin/activate
cd /usr/lib/ckan/default/src/ckan 
paster db dump -c /etc/ckan/${orgName}/development.ini /home/${orgName}/${orgName}_dbdump.sql

#Create production.ini file and move to git file
cp /etc/ckan/${orgName}/development.ini /home/${orgName}/production.ini

#TO-DO
#move any custom plugins to git repository

#commit files to remote git repository
git commit -a -m 'load staged resources'
git remote add origin https://github.com/OpenGovGear/${orgName}.git

#Change ownership of file store to www-data
sudo chown -R www-data /FSTORE/${orgName}
