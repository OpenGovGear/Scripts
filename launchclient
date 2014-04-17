#!/usr/bin/env bash

echo "Enter client organization's name(lowercase):"
read orgName

#echo "Enter the road the client organization's main office is on:"
#read orgPswd

echo "Enter the host ip address:"
read hostIP

echo "Enter the database ip address:"
read dbserv

#sudo cp -r /usr/lib/ckan/default /usr/lib/ckan/${orgName}
sudo cp /etc/ckan/${orgName}/development.ini /etc/ckan/${orgName}/production.ini
#cd /etc/ckan/${orgName}
#sed -i s/default/${orgName}/ production.ini
#sudo mkdir /etc/ckan/${orgName}
#bring in the production.ini file

#bring in the extensions

sudo cp /etc/ckan/default/apache.wsgi /etc/ckan/${orgName}/apache.wsgi
cd /etc/ckan/${orgName}
sudo sed -i s/default/${orgName}/ apache.wsgi

sudo cp /etc/apache2/sites-available/ckan_default /etc/apache2/sites-available/${orgName}
cd /etc/apache2/sites-available
sudo sed -i s/ckan_default/${orgName}/ ${orgName}
sudo sed -i s/ckan_default/${orgName}/ ${orgName}
sudo sed -i s/default.ckanhosted.com/data.${orgName}.com/ ${orgName}
sudo sed -i s/default/${orgName}/ ${orgName}

sudo a2ensite ${orgName}
sudo service apache2 restart

