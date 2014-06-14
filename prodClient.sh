#!/usr/bin/env bash

echo "Enter client organization's name(lowercase):"
read orgName


echo "Have you created a production.ini file, changed debug to false and committed all staging activity to git for this client?(y/n)"
read confirmgit
if [ ${confirmgit} = "n" ]
then
	echo 'Please committed all changes to git and create a production.ini file before continuing.'
	exit 1
fi

echo "Have you created the database user and solr core for this client on the database server?(y/n)"
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

echo "Enter the ckan server's public ip address:"
read hostIP

#bring in the configuration file and extensions
git clone https://github.com/OpenGovGear/${orgName}-staging

sudo mkdir -p /etc/ckan/${orgName}
sudo chown `whoami` /etc/ckan/${orgName}

#point the config file to the database server and make other customizations
#specific to production server
sudo cp ./${orgName}-staging/production.ini /etc/ckan/${orgName}/production.ini
sudo sed -i "s/localhost\/${orgName}_db/${dbserv}\/${orgName}_db/" /etc/ckan/${orgName}/production.ini
sudo ln -s /usr/lib/ckan/default/src/ckan/who.ini /etc/ckan/${orgName}/who.ini

#initialise the db
. /usr/lib/ckan/default/bin/activate
cd /usr/lib/ckan/default/src/ckan
paster db init -c /etc/ckan/${orgName}/production.ini

#install this client's extensions into the virtual environment
sudo cp -r ./${orgName}-staging/ckanext-${orgName}_theme /usr/lib/ckan/default/src
cd /usr/lib/ckan/default/src/ckanext-${orgName}_theme
python setup.py develop

#create this client's virtual host files
sudo cp /etc/ckan/default/apache.wsgi /etc/ckan/${orgName}/apache.wsgi
sudo cp /etc/apache2/sites-available/ckan_default /etc/apache2/sites-available/${orgName}
cd /etc/apache2/sites-available
sudo sed -i s/ckan_default/${orgName}/ ${orgName}
sudo sed -i s/ckan_default/${orgName}/ ${orgName}
sudo sed -i s/default.ckanhosted.com/data.${orgName}.com/ ${orgName}
sudo sed -i s/default/${orgName}/ ${orgName}

#enable this client's solr core
sudo sed -i "s_127.0.0.1:8983/solr_${dbserv}:8983/solr/${orgName}_" /etc/ckan/${orgName}/production.ini

#just use var for filestore now in development
sudo mkdir -p /var/lib/ckan/default
sudo chown -R www-data /var/lib/ckan/default #apache user must have permissions over file store 
sudo chmod u+rwx /var/lib/ckan/default #maintainer's guide says to use this command

sudo a2ensite ${orgName}
sudo service apache2 restart

