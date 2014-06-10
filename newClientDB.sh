#!/usr/bin/env bash

#This script runs on a database server that has already
# been initialised to receive remote requests from our main 
#application/web server, it simply creates a new user and database
# corresponding to an onboarding client's organization name. The 
#tables will be initialized and populated from a script on the main 
#server when the client is added there
  
echo "Enter client organization's name:"
read orgName

sudo -u postgres createuser -S -D -R ${orgName}
sudo -u postgres psql -U postgres -d postgres -c "alter user ${orgName} with password 'zandt2014';"
sudo -u postgres createdb -O ${orgName} ${orgName}_db -E utf-8

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

