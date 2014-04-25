#/usr/bin/env bash

#This script runs on the staging server once the client is
#ready to go into prod. It creates a production.ini file, a 
#database dump file, and loads them as well as any custom plug-ins
#to git, where they'll be launched into production. The image it runs 
#on will have GIT installed, the OGG admins ID and password already  <--- not done
#validated using the credential-helper utility 


echo 'Enter the client organization name (lowercase):'
read orgname

echo 'Has a git repository been set up for "${orgName}" on OGG(y/n)?'
read gitconfirm

if [ ${gitconfirm} = "n" ] #create one
then
	echo Please enter your git username
	read gitusername
	
	echo Please enter the new repo name
	read reponame
	
	echo enter project description
	read projectdesc
	    # POST data via git API
        curl -u ${gitusername} https://api.github.com/user/repos -d '{"name":"${reponame}","description":"${projectdesc}"}'
        # add def for location and existance of connect remote repo on github
fi

#create a git repository connected to OpenGovGear somehow
mkdir -p /home/${orgname}
chown `whoami` /home/${orgname}/
cd /home/${orgname}
touch README
#echo "Staging resources for ${orgname}" > README.md
git init
git add README.md
git add README.md
git commit -m 'the script works up to this point'
git remote add origin https://github/com/${gitusername}/${reponame}.git
git push -u origin master
#at this point you have created the repo and pushed the readme.md to it

#Dump database and move dump file to local git repository
. /usr/lib/ckan/default/bin/activate
cd /usr/lib/ckan/default/src/ckan 
paster db dump -c /etc/ckan/${orgname}/development.ini /home/${orgname}/${orgname}_dbdump.sql

#Create production.ini file and move to git file
cp /etc/ckan/${orgname}/development.ini /home/${orgname}/production.ini

#TO-DO
#move any custom plugins to git repository

#commit files to remote git repository
git commit -a -m 'load staged resources'
#git remote add origin https://github.com/OpenGovGear/${orgName}.git
git push -u origin master
#Change ownership of file store to www-data
#sudo chown -R www-data /FSTORE/${orgName}
