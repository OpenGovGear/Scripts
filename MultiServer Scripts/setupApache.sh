#!/bin/bash
# <param1> : Instance Name
###########
strInstanceName=$1

if [ -z "$strInstanceName" ]
then
	read -p "Instance Name: " strInstanceName
fi

#Create a production.ini File
sudo cp /etc/ckan/${strInstanceName}/development.ini /etc/ckan/${strInstanceName}/production.ini

#Install Apache, modwsgi, modrpaf, Nginx
sudo apt-get update
sudo apt-get install apache2 libapache2-mod-wsgi libapache2-mod-rpaf
sudo apt-get install nginx

#Install an email server
sudo apt-get install postfix

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
				 ServerName "
strApacheConf+="$strInstanceName"
strApacheConf+=".ckanhosted.com 
				 ServerAlias www."
strApacheConf+="$strInstanceName"
strApacheConf+=".ckanhosted.com 
				 WSGIScriptAlias / /etc/ckan/"
strApacheConf+="$strInstanceName"
strApacheConf+="/apache.wsgi 
			 WSGIPassAuthorization On 
                
			 WSGIDaemonProcess "
strApacheConf+="$strInstanceName"
strApacheConf+=" display-name="
strApacheConf+="$strInstanceName"
strApacheConf+=" processes=2 threads=15
                
			 WSGIProcessGroup "
strApacheConf+="$strInstanceName
                
			 ErrorLog /var/log/apache2/"
strApacheConf+="$strInstanceName"
strApacheConf+=".error.log
			 CustomLog /var/log/apache2/"
strApacheConf+="$strInstanceName"
strApacheConf+=".custom.log combined
				<IfModule mod_rpaf.c>
				 		RPAFenable On
				 		RPAFsethostname On
				 		RPAFproxy_ips 127.0.0.1
				 	</IfModule>
				 </VirtualHost>"
sudo echo $strApacheConf | sudo tee /etc/apache2/sites-available/${strInstanceName}

#Modify the Apache ports.conf file
sudo sed -i "s/NameVirtualHost \*\:80/NameVirtualHost *:8080/" /etc/ckan/${strInstanceName}/development.ini 
sudo sed -i "s/Listen 80/Listen 8080/" /etc/ckan/${strInstanceName}/development.ini 

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
sudo a2dissite ${strInstanceName}
sudo rm -vi /etc/nginx/sites-enabled/${strInstanceName}
sudo ln -s /etc/nginx/sites-available/${strInstanceName} /etc/nginx/sites-enabled/${strInstanceName}
sudo service apache2 reload
sudo service nginx reload