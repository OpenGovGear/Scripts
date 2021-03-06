#!/usr/bin/env bash

# this script should be run once on a staging server after getCkanSrc.sh
#
# the main purpose of this script is to customize the configuration 
# file, initialize the database catalogue, external file store and 
# plug-ins. Although the production environment will have an external 
# database server, for development purpose that shouldn't be necessary
# just use the local postgres, 
#
# this script will dump it and load onto prod using
# git. Will load everything to git

################################ IGNORE ############################################
#Mount external filestore
#echo "Enter the three letter volume identifier(n if you don't know):"
#read volID

#if [ ${volID} = "n" ] #give user an out if they don't have the dev id
#then
#	echo 'Run sudo fdisk -l to view attached devices'
#	exit 1
#fi

#Check whether we're using a volume copied from prod
#that doesn't need formatting
#echo "Does the volume require formatting(y/n)?"
#read reqfrmt
#if [ ${reqfrmt} = "y" ]
#then
#	sudo mkfs -t ext4 /dev/${volID}
#	echo 'Formatting device $volID as ext4'
#fi

#mount the volume
#sudo mkdir /FSTORE
#sudo mount /dev/${volID} /FSTORE
#####################################################################################

function installTheme {
#TO-DO Some error handling here if they put in an invalid character by accident
	if [ $theme = "1" ]
	then
		themeName="simple_theme"
		className="SimpleThemePlugin"
	elif [ $theme = "2" ]
	then
		themeName="complex_theme"
		className="ComplexThemePlugin"
	elif [ $theme = "3" ]
	then
		themeName="aggregator_theme"
		className="AggregatorThemePlugin"
	elif [ $theme = "4" ]
	then
		themeName="example_theme"
		className="ExampleThemePlugin"
	fi
	orgInitCap=$(echo $orgName|awk '{print toupper(substr($1,1,1))tolower(substr($1,2))}')
	
	#Generate a new organization theme plugin, copy the requested theme with resources from git and rename to match this org
	cd /home/`whoami`/${orgName}-staging/${orgName}
	paster --plugin=ckan create -t ckanext ckanext-${orgName}_theme
	
	oggResourcePath=/home/`whoami`/${orgName}-staging/ckan-plugins/ckanext-${themeName}/ckanext/${themeName}
	orgThemePath=/home/`whoami`/${orgName}-staging/${orgName}/ckanext-${orgName}_theme
	
	
	sed -i "s/PluginClass/${orgInitCap}ThemePlugin/" ${orgThemePath}/setup.py
	sed -i "s/# myplugin/${orgName}_theme/" ${orgThemePath}/setup.py
	sed -i "s/example_theme/${orgName}_theme/" ${orgThemePath}/setup.py
	
	#Copy in the theme's plugin.py, and rename its class to match this organization
	cp ${oggResourcePath}/plugin.py ${orgThemePath}/ckanext/${orgName}_theme/plugin.py
	sed -i "s/${className}/${orgInitCap}ThemePlugin/" ${orgThemePath}/ckanext/${orgName}_theme/plugin.py

	#Copy in the resource folders
	cp -r ${oggResourcePath}/public ${orgThemePath}/ckanext/${orgName}_theme
	cp -r ${oggResourcePath}/templates ${orgThemePath}/ckanext/${orgName}_theme
	cp -r ${oggResourcePath}/fanstatic ${orgThemePath}/ckanext/${orgName}_theme
	
	#Install the plugin into this virutal environment (still activated?)
	cd ${orgThemePath}
	python setup.py develop
	
	#Activate this theme in the organization's development.ini config file
	sudo sed -i "s/ckan.plugins =/ckan.plugins = ${orgName}_theme/" /etc/ckan/${orgName}/development.ini 
	
}

echo Enter your git username:
read gitusername

echo 'Enter your the email address associated with your git account:'
read mail

git config --global user.name "${gitusername}"
git config --global user.email "${mail}"
git config credential.helper store

#Get all required details about this deployment
echo "Enter client organization's name:"
read orgName

echo "Enter client organization's top level domain:"
read tld

echo "Enter client organization description"
read projectdesc

#TO-DO Some error checking/recovery on user input here
echo 'Which theme will this organization use? (1=Simple 2=Complex 3=Aggregator 4=Example) : '
read theme


#create the client's development.ini file and link to who.ini
sudo mkdir -p /etc/ckan/${orgName}
sudo chown -R `whoami` /etc/ckan
cd /usr/lib/ckan/default/src/ckan
. /usr/lib/ckan/default/bin/activate
paster make-config ckan /etc/ckan/${orgName}/development.ini
sudo ln -s /usr/lib/ckan/default/src/ckan/who.ini /etc/ckan/${orgName}/who.ini

#customize development.ini configuration
cd /etc/ckan/${orgName}
#for development
sudo sed -i "s/debug = false/debug = true/" development.ini
#user for postgres connection
sudo sed -i "s/ckan_default:pass/${orgName}:zandt2014/" development.ini
#table schema
sudo sed -i "s/ckan_default/${orgName}_db/" development.ini
#site_id parameter
sudo sed -i "s/ckan.site_id = default/ckan.site_id = ${orgName}/" development.ini
#site_title parameter, convert name to allcaps
upperName=$(tr [a-z] [A-Z] <<< "$orgName")
sudo sed -i "s/ckan.site_title = CKAN/ckan.site_title = ${upperName}/" development.ini
sudo sed -i "s/ckan.site_url =/ckan.site_url = data.${orgName}.${tld}/" development.ini
sudo sed -i "s/ckan.locales_offered/#ckan.locales_offered/" development.ini
#activate solr
sudo sed -i 's/#solr_url/solr_url/' development.ini
#activate file store
sudo sed -i 's/#ckan\.storage_path/ckan\.storage_path/' development.ini
#set file store location (external)
#sudo sed -i s_/var/lib/ckan_/FSTORE/${orgName}_ development.ini 
#set file store (internal)
sudo sed -i "s_/var/lib/ckan_/var/lib/ckan/${orgName}_" development.ini 

######################################################################################
#initialise external file store
#sudo mkdir -p /FSTORE/${orgName}
#sudo chown `whoami` /FSTORE/${orgName} #paster runs under the id of 
					#whatever user started it
#sudo chmod u+rwx /FSTORE/${orgName} #because the user guide says so
######################################################################################
#initialize internal file store
sudo mkdir -p /var/lib/ckan/${orgName}
sudo chown 'ubuntu' /var/lib/ckan/${orgName}
sudo chmod u+rwx /var/lib/ckan/${orgName}

#Enable jetty and configure to serve internally
cd /etc/default
sudo sed -i 's/NO_START=1/NO_START=0/' jetty
sudo sed -i 's/#JETTY_HOST=/JETTY_HOST=127.0.0.1 #/' jetty
sudo sed -i 's/#JETTY_PORT=8080/JETTY_PORT=8983/' jetty
sudo sed -i 's/#JAVA_HOME=/JAVA_HOME=\/usr\/lib\/jvm\/java-6-openjdk-amd64\//' jetty

#enable CKAN solr search platform on jetty and start
sudo mv /etc/solr/conf/schema.xml /etc/solr/conf/schema.xml.bak
sudo ln -s /usr/lib/ckan/default/src/ckan/ckan/config/solr/schema.xml /etc/solr/conf/schema.xml
sudo service jetty start

#create client database user, password and schema and initialise db
sudo -u postgres createuser -S -D -R ${orgName}
sudo -u postgres psql -U postgres -d postgres -c "alter user ${orgName} with password 'zandt2014';"
sudo -u postgres createdb -O ${orgName} ${orgName}_db -E utf-8
cd /usr/lib/ckan/default/src/ckan
. /usr/lib/ckan/default/bin/activate
paster db init -c /etc/ckan/${orgName}/development.ini

#create a folder structure for this organization's staging 
sudo mkdir -p /home/`whoami`/${orgName}-staging/${orgName} 
sudo chown -R `whoami` /home/`whoami`/${orgName}-staging

#Bring in our theme extensions from git, use one as the template for this organization's theme
cd /home/`whoami`/${orgName}-staging
git clone https://github.com/OpenGovGear/ckan-plugins.git
installTheme

#create this organization's remote git repository via git API
sudo curl -u $gitusername https://api.github.com/orgs/OpenGovGear/repos -d '{"name":"'"${orgName}-staging"'","description":"'"$projectdesc"'"}'

#create this organization's local git repository and gather resources into it
cd /home/`whoami`/${orgName}-staging/${orgName}
git init
touch README
echo "Staging resources for $orgName" > README
sudo ln /etc/ckan/${orgName}/development.ini /home/`whoami`/${orgName}-staging/${orgName}/development.ini
git add *
git commit -m "Stage development resources for $orgName"
git remote add origin https://github.com/OpenGovGear/${orgName}-staging.git
git push origin master 

# Serve
cd /usr/lib/ckan/default/src/ckan
. /usr/lib/ckan/default/bin/activate
paster serve /etc/ckan/${orgName}/development.ini


