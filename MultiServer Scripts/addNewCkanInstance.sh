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
fi