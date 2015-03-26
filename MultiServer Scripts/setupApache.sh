#!/bin/bash
# <param1> : Instance Name
###########
strInstanceName=$1

if [ -z "$strInstanceName" ]
then
	read -p "Instance Name: " strInstanceName
fi

#Exit if something is wrong
if [ -z "$strInstanceName" ]
then
	echo "This script is for install and setup of Apache"
	echo "./<script name>.sh <param1>"
	echo "<param1> : Instance Name"
	exit 1
fi

#Create a production.ini File
sudo cp /etc/ckan/${strInstanceName}/development.ini /etc/ckan/${strInstanceName}/production.ini

#Install Apache, modwsgi, modrpaf, Nginx
sudo apt-get update -y
sudo apt-get install -y apache2 libapache2-mod-wsgi libapache2-mod-rpaf
sudo apt-get install -y nginx

#Install an email server
sudo apt-get install -y postfix

#Create the WSGI script file
sudo echo -e "import os\n 
activate_this = os.path.join('/usr/lib/ckan/$strInstanceName/bin/activate_this.py')\n 
execfile(activate_this, dict(__file__=activate_this))\n 
                  
from paste.deploy import loadapp\n 
config_filepath = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'production.ini')\n 
from paste.script.util.logging_config import fileConfig\n 
fileConfig(config_filepath)\n 
application = loadapp('config:%s' % config_filepath)"| sudo tee /etc/ckan/${strInstanceName}/apache.wsgi
	
#Create the Apache config file
strApacheConf="<VirtualHost 127.0.0.1:8080>
    ServerName ${strInstanceName}.opengovgear.com
    ServerAlias www.${strInstanceName}.opengovegear.com
    WSGIScriptAlias / /etc/ckan/default/apache.wsgi

    # Pass authorization info on (needed for rest api).
    WSGIPassAuthorization On

    # Deploy as a daemon (avoids conflicts between CKAN instances).
    WSGIDaemonProcess ${strInstanceName} display-name=${strInstanceName} processes=2 threads=15

    WSGIProcessGroup ${strInstanceName}

    ErrorLog /var/log/apache2/${strInstanceName}.error.log
    CustomLog /var/log/apache2/${strInstanceName}.custom.log combined

    <IfModule mod_rpaf.c>
        RPAFenable On
        RPAFsethostname On
        RPAFproxy_ips 127.0.0.1
    </IfModule>
</VirtualHost>"
sudo echo $strApacheConf | sudo tee /etc/apache2/sites-available/${strInstanceName}

#Modify the Apache ports.conf file
sudo sed -i "s/NameVirtualHost \*\:80/NameVirtualHost \*\:8080/" /etc/apache2/ports.conf
sudo sed -i "s/Listen 80/Listen 8080/" /etc/apache2/ports.conf

#Create the Nginx config file
sudo echo "proxy_cache_path /tmp/nginx_cache levels=1:2 keys_zone=cache:30m max_size=250m;
proxy_temp_path /tmp/nginx_proxy 1 2;
   
server {
	client_max_body_size 100M;
	location / {
		proxy_pass http://127.0.0.1:8080/;
		proxy_set_header X-Forwarded-For \$remote_addr;
		proxy_set_header Host \$host;
		proxy_cache cache;
		proxy_cache_bypass \$cookie_auth_tkt;
		proxy_no_cache \$cookie_auth_tkt;
		proxy_cache_valid 30m;
		proxy_cache_key \$host\$scheme\$proxy_host\$request_uri;
		# In emergency comment out line to force caching
		# proxy_ignore_headers X-Accel-Expires Expires Cache-Control;
}
              
		   }" | sudo tee /etc/nginx/sites-available/${strInstanceName}
		   
#Enable your CKAN site
sudo a2ensite ${strInstanceName}
sudo a2dissite default
sudo rm -vi /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/${strInstanceName} /etc/nginx/sites-enabled/${strInstanceName}
sudo service apache2 reload
sudo service nginx reload