sudo cp ./solr.xml /usr/share/solr/.
sudo -u jetty mkdir /var/lib/solr/data/ckan_default
sudo mkdir /etc/solr/ckan_default
sudo mv /etc/solr/conf /etc/solr/ckan_default/
sudo mv /etc/solr/ckan_default/conf/schema.xml /etc/solr/ckan_default/conf/schema.xml.bak
sudo ln -s /usr/lib/ckan/default/src/ckan/ckan/config/solr/schema.xml /etc/solr/ckan_default/conf/schema.xml
sudo sed -i 's_/var/lib/solr/data_${dataDir} _' /etc/solr/ckan_default/conf/solrconfig.xml
sudo mkdir /usr/share/solr/ckan_default
sudo ln -s /etc/solr/ckan_default/conf /usr/share/solr/ckan_default/conf
sudo service jetty restart

