#!/bin/bash
###########

#checks
echo "This is to set up a second instance of CKAN."
echo "It is under the assumption that you've set up a Postgres and SOLR on another server already."
echo "You need to know the Postgres server name, IP, and password."
read -p "Do you want to continue?(y/n)" blnSecondInstance

if [ $blnSecondInstance == "n" ]
then
	echo 'This is the wrong script.'
	exit 1
fi

#set up variables
read -p "Name for second instance: " strInstanceName
while [ -z "$strInstanceName" ] 
do
	read -p "Name for second instance: " strInstanceName
done

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

strRemoteHostSetupComplete="n"
while [ $strRemoteHostSetupComplete == "n" ]
do
	echo "------------------------"
	read -p "Remote Host IP: " strRemote
	while [ -z "$strRemote" ] 
	do
		read -p "Remote Host IP: " strRemote
	done

	read -p "Remote Host Pass: " strPass
	while [ -z "$strPass" ] 
	do
		read -p "Remote Host Pass: "  strPass
	done
	echo "$strPass@$strRemote"
	read -p "Correct? (y/n)" strContinue
	if [ $strContinue == "y" ] 
	then
		strRemoteHostSetupComplete="y"
		sudo sed -i "s/pass\@localhost/${strPass}\@${strRemote}/" /etc/ckan/${strInstanceName}/development.ini 
	fi
done


sudo sed -i "s/ckan.site_id = default/ckan.site_id = ${strInstanceName}/" /etc/ckan/${strInstanceName}/development.ini # ckan.site_id = default
sudo sed -i "s/#solr_url = http:\/\/127.0.0.1:8983\/solr/solr_url = http:\/\/${strRemote}:8983\/solr\/${strInstanceName}/" /etc/ckan/${strInstanceName}/development.ini # #solr_url = http://127.0.0.1:8983/solr

cd /usr/lib/ckan/${strInstanceName}/src/ckan
paster db init -c /etc/ckan/${strInstanceName}/development.ini

ln -s /usr/lib/ckan/${strInstanceName}/src/ckan/who.ini /etc/ckan/${strInstanceName}/who.ini

read -p "Would you like to serve with paster right now? (y/n)" strPasterServe
if [ $strPasterServe == "y" ] 
then
	cd /usr/lib/ckan/${strInstanceName}/src/ckan
	paster serve /etc/ckan/${strInstanceName}/development.ini
	exit 1
fi

read -p "Would you like to set Apache up and Serve? (y/n)" strApacheServe
if [ $strApacheServe == "y" ] 
then
	#Create a production.ini File
	sudo cp /etc/ckan/${strInstanceName}/development.ini /etc/ckan/${strInstanceName}/production.ini

	#Install Apache, modwsgi, modrpaf, Nginx
	sudo apt-get update
	sudo apt-get install apache2 libapache2-mod-wsgi libapache2-mod-rpaf
	sudo apt-get install nginx
	
	#Install an email server
	sudo apt-get install postfix
	
	#Create the WSGI script file
	strWSGI="import os
			   activate_this = os.path.join('/usr/lib/ckan/"
	strWSGI+="$strInstanceName"
	strWSGI+="/bin/activate_this.py')
			   execfile(activate_this, dict(__file__=activate_this))
                  
			   from paste.deploy import loadapp
			   config_filepath = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'production.ini')
			   from paste.script.util.logging_config import fileConfig
			   fileConfig(config_filepath)
			   application = loadapp('config:%s' % config_filepath)"
	sudo echo $strWSGI > /etc/ckan/${strInstanceName}/apache.wsgi
	
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
				 # Pass authorization info on (needed for rest api).
				 WSGIPassAuthorization On 
                    
				 # Deploy as a daemon (avoids conflicts between CKAN instances).
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
	sudo echo $strApacheConf > /etc/apache2/sites-available/${strInstanceName}
	
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
			   		proxy_set_header X-Forwarded-For $remote_addr;
			   		proxy_set_header Host $host;
			   		proxy_cache cache;
			   		proxy_cache_bypass $cookie_auth_tkt;
			   		proxy_no_cache $cookie_auth_tkt;
			   		proxy_cache_valid 30m;
			   		proxy_cache_key $host$scheme$proxy_host$request_uri;
			   		# In emergency comment out line to force caching
			   		# proxy_ignore_headers X-Accel-Expires Expires Cache-Control;
			   	}
                  
			   }" >  /etc/nginx/sites-available/${strInstanceName}
	#Enable your CKAN site
	sudo a2ensite ${strInstanceName}
	sudo a2dissite ${strInstanceName}
	sudo rm -vi /etc/nginx/sites-enabled/${strInstanceName}
	sudo ln -s /etc/nginx/sites-available/${strInstanceName} /etc/nginx/sites-enabled/${strInstanceName}
	sudo service apache2 reload
	sudo service nginx reload
	
	echo "Done!"
	exit 1
fi