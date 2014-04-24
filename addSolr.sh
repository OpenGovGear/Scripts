echo Enter the name of the client to add:
read coreName

sudo sed -i "/<\/cores>/ i\
 <core name=\"${coreName}\" instanceDir=\"${coreName}\"><property name=\"dataDir\" value=\"/var/lib/solr/data/${coreName}\" \/><\/core>" /usr/share/solr/solr.xml

