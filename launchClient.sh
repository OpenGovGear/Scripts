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

#enable this client's solr core
sudo sed -i "/<\/cores>/ i\
 <core name=\"${orgName}\" instanceDir=\"${orgName}\"><property name=\"dataDir\" value=\"/var/lib/solr/data/${orgName}\" \/><\/core>" /usr/share/solr/solr.xml
sudo -u jetty mkdir /var/lib/solr/data/${orgName}
sudo mkdir /etc/solr/${orgName}
sudo cp -R /etc/solr/ckan_default/conf /etc/solr/${orgName}/
sudo rm /etc/solr/${orgName}/conf/schema.xml
sudo ln -s /usr/lib/ckan/${orgName}/src/ckan/ckan/config/solr/schema.xml /etc/solr/${orgName}/conf/schema.xml
sudo mkdir /usr/share/solr/${orgName}
sudo ln -s /etc/solr/${orgName}/conf /usr/share/solr/${orgName}/conf
sudo service jetty restart
sudo sed -i "s_8983/solr_8983/solr/${orgName}_" /etc/ckan/${orgName}/development.ini

sudo a2ensite ${orgName}
sudo service apache2 restart

