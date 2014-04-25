#/usr/bin/env bash

#This script runs on the staging server once the client is
#ready to go into prod. It creates a production.ini file, a 
#database dump file, and loads them as well as any custom plug-ins
#to git, where they'll be launched into production. The image it runs 
#on will have GIT installed, the OGG admins ID and password already  <--- not done
#validated using the credential-helper utility 
#
#currently loads up to users repo not orgs -- needs to be fixed


echo 'Enter the client organization name -- this is also the repo name (lowercase):'
read orgname

echo "Has a git repository been set up for $orgname on OGG -- hit yes or it breaks(y/n)?"
read gitconfirm

if [ ${gitconfirm} = "n" ] #create one
then
	echo Please enter your git username
	read gitusername
	
	echo enter repo description
	read projectdesc
	    # POST data via git API
        curl -u $gitusername https://api.github.com/user/repos -d '{"name":"'"$orgname"'","description":"'"$projectdesc"'"}'
        # add def for location and existance of connect remote repo on github
fi

#create a git repository connected to OpenGovGear somehow
mkdir -p /home/${orgname}
chown -R `whoami` /home/${orgname}
cd /home/${orgname}
touch README
echo "Staging resources for $orgname" > README
git init
git add /home/${orgname}/README
#git push -u origin master
#at this point you have created the repo and pushed the readme.md to it

#Dump database and move dump file to local git repository
. /usr/lib/ckan/default/bin/activate
cd /usr/lib/ckan/default/src/ckan 
paster db dump -c /etc/ckan/${orgname}/development.ini /home/${orgname}/${orgname}_dbdump.sql
deactivate
cd /home/${orgname}

#Create production.ini file and move to git file
cp /etc/ckan/${orgname}/development.ini /home/${orgname}/production.ini

#TO-DO
#move any custom plugins to git repository
#
#
#commit files to remote git repository
git add /home/${orgname}/${orgname}_dbdump.sql
git add /home/${orgname}/production.ini
git remote add origin https://github.com/$gitusername/$orgname.git
git commit -a -m 'load staged resources'
git push -u origin master
#Change ownership of file store to user for both ckan and org
sudo chown -R `whoami` var/lib/ckan/storage
sudo chown -R `whoami` var/lib/ckan/${orgName}
