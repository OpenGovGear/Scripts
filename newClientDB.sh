#!/usr/bin/env bash

#This script runs on a database server that has already
# been initialised to receive remote requests from our main 
#application/web server, it simply creates a new user and database
# corresponding to an onboarding client's organization name. The 
#tables will be initialized and populated from a script on the main 
#server when the client is added there
  
echo "Enter client organization's name:"
read orgName

sudo -u postgres createuser -S -D -R ${orgName}
sudo -u postgres psql -U postgres -d postgres -c "alter user ${orgName} with password 'zandt2014';"
sudo -u postgres createdb -O ${orgName} ${orgName}_db -E utf-8



