echo Enter the name of the client to add:
read coreName

sudo sed -i "/<\/cores>/ i\
 <core name=\"${coreName}\" instanceDir=\"${coreName}\"><property name=\"dataDir\" value=\"/var/lib/solr/data/${coreName}\" \/><\/core>" /usr/share/solr/solr.xml
sudo -u jetty mkdir /var/lib/solr/data/${coreName}
sudo mkdir /etc/solr/${coreName}
sudo cp -R /etc/solr/ckan_default/conf /etc/solr/${coreName}/
sudo rm /etc/solr/${coreName}/conf/schema.xml
sudo ln -s /usr/lib/ckan/${coreName}/src/ckan/ckan/config/solr/schema.xml /etc/solr/${coreName}/conf/schema.xml
sudo mkdir /usr/share/solr/${coreName}
sudo ln -s /etc/solr/$coreName/conf /usr/share/solr/$coreName/conf
sudo service jetty restart
sudo sed -i "s_8983/solr_8983/solr/${coreName}_" /etc/ckan/${coreName}/development.ini
