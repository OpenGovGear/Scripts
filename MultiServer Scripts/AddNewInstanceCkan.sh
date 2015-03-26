#!/bin/bash
###########
# <param1> : Instance Name
# <param2> : Postgres Server IP
# <param3> : Postgres Server Password
# <param4> : Serve with Apache at the end(y/n)
###########
strInstanceName=$1
strRemote=$2
strPass=$3
strApacheServe=$4

if [ -z "$strInstanceName" ]
then
	read -p "Instance Name: " strInstanceName
fi

if [ -z "$strRemote" ]
then
	read -p "Postgres Server IP: " strRemote
fi

if [ -z "$strPass" ]
then
	read -p "Postgres Server Password: " strPass
fi

if [ -z "$strPasterServe" ]
then
	read -p "Serve with Apache at the end(y/n): " strApacheServe
fi

#Exit if something is wrong (this is a short-circuit)
if [ -z "$strInstanceName" ] || [ -z "$strRemote" ] || [ -z "$strPass" ] || [ -z "$strApacheServe" ]
then
	echo "This script will install a new ckan instance."
	echo "./<script name>.sh <parm1> <param2> <param3> <param4>"
	echo "<param1> : Instance Name"
	echo "<param2> : Postgres Server IP"
	echo "<param3> : Postgres Server Password"
	echo "<param4> : Serve with Paster at the end(y/n)"
	exit 1
fi

#set up python virtual enviroment
sudo mkdir -p /usr/lib/ckan/${strInstanceName}
sudo chown `whoami` /usr/lib/ckan/${strInstanceName}
virtualenv --no-site-packages /usr/lib/ckan/${strInstanceName}
. /usr/lib/ckan/${strInstanceName}/bin/activate

#Install CKAN source
pip install -e 'git+https://github.com/ckan/ckan.git@ckan-2.3#egg=ckan'
pip install -r /usr/lib/ckan/${strInstanceName}/src/ckan/requirements.txt
deactivate
. /usr/lib/ckan/${strInstanceName}/bin/activate

#Create a CKAN Config File
sudo mkdir -p /etc/ckan/${strInstanceName}
sudo chown -R `whoami` /etc/ckan/
cd /usr/lib/ckan/${strInstanceName}/src/ckan
paster make-config ckan /etc/ckan/${strInstanceName}/development.ini

#Format sqlalchamy url
# sqlalchemy.url = postgresql://ckan_default:pass@localhost/ckan_default
sudo sed -i "s/ckan_default\:pass\@localhost\/ckan_default/${strInstanceName}\:{$strPass}\@${strRemote}\/${strInstanceName}/" /etc/ckan/${strInstanceName}/development.ini 
sudo sed -i "s/ckan.site_id = default/ckan.site_id = ${strInstanceName}/" /etc/ckan/${strInstanceName}/development.ini # ckan.site_id = default
sudo sed -i "s/#solr_url = http:\/\/127.0.0.1:8983\/solr/solr_url = http:\/\/${strRemote}:8983\/solr\/${strInstanceName}/" /etc/ckan/${strInstanceName}/development.ini # #solr_url = http://127.0.0.1:8983/solr

cd /usr/lib/ckan/${strInstanceName}/src/ckan
paster db init -c /etc/ckan/${strInstanceName}/development.ini

ln -s /usr/lib/ckan/${strInstanceName}/src/ckan/who.ini /etc/ckan/${strInstanceName}/who.ini

if [ $strApacheServe == "y" ] 
then
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
	echo="<VirtualHost 127.0.0.1:8080> 
		ServerName ${strInstanceName}.opengovgear.com 
		ServerAlias www.${strInstanceName}.opengovgear.com 
		WSGIScriptAlias / /etc/ckan/${strInstanceName}/apache.wsgi 
		
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
	</VirtualHost>" | sudo tee /etc/apache2/sites-available/${strInstanceName}.opengovgear.com 

	#Modify the Apache ports.conf file
	sudo sed -i "s/NameVirtualHost \*\:80 /NameVirtualHost \*\:8080/" /etc/apache2/ports.conf
	sudo sed -i "s/Listen 80 /Listen 8080/" /etc/apache2/ports.conf

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
				  
			   }" | sudo tee /etc/nginx/sites-available/${strInstanceName}.opengovgear.com 
			   
	#Enable your CKAN site
	sudo a2ensite ${strInstanceName}
	sudo a2dissite default
	sudo rm -vi /etc/nginx/sites-enabled/default
	sudo ln -s /etc/nginx/sites-available/${strInstanceName}.opengovgear.com  /etc/nginx/sites-enabled/${strInstanceName}.opengovgear.com 
	sudo service apache2 reload
	sudo service nginx reload
fi