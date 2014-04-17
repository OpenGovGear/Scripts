#!/usr/bin/env bash

#Script to bring in the necessary installation files from 
#git and set up the credential.helper so that the other
#git commands in installation files will work
#deletes the git source because the credential helper would allow
#someone to push changes to our source, so delete the local
#repository  to discourage people from doing so (once the scripts
#are finished)

sudo apt-get install -y git

echo Enter your user name for git:
read user

echo 'Enter your email address for git:'
read mail

git config --global user.name "${user}"
git config --global user.email "${mail}"
git config --global credential.helper store
git clone https://github.com/OpenGovGear/Scripts.git

#sudo cp ./Scripts/initstage /usr/local/bin/.
#sudo cp ./Scripts/newclient /usr/local/bin/.
#sudo cp ./Scripts/loadclient /usr/local/bin/.

#rm -rf ./Scripts


