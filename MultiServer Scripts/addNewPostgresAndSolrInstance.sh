#!/bin/bash

# Pre Start Checks
sudo -u postgres psql -l

echo "You're about to set up a second PostgreSQL and SOLR instance."
read -p "Proceed? (y/n): " blnReply
if [ $blnReply == "n" ]
then
	echo 'Exiting...'
	exit 1
fi

# Variables
read -p "New User Name: " strUserName
read -p "New Database Name: " strDataBaseName
read -p "First Database Name (ckan_default if left blank): " strOldDataBaseName
read -p "Listen Address for CKAN Server: " strCkanServerIP
if [ -z "$strOldDataBaseName" ]
then
	declare "strOldDataBaseName=ckan_default"
fi
echo "New User Name: $strUserName"
echo "New Database Name: $strDataBaseName"
echo "First Database Name: $strOldDataBaseName"
echo "CKAN Server IP: $strCkanServerIP"
echo -n "Is this correct?(y/n): "
read blnReply
if [ $blnReply == "n" ]
then
	echo 'Exiting...'
	exit 1
fi

echo "Set up new SQL User and Database"
sudo -u postgres createuser -S -D -R -P ${strUserName}
sudo -u postgres createdb -O ${strUserName} ${strDataBaseName} -E utf-8

sudo grep -R "$strCkanServerIP" /etc/postgresql/9.1/main/postgresql.conf
if [ $? -eq  1 ]
then
	sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost,$strCkanServerIP'/"  /etc/postgresql/9.1/main/postgresql.conf
fi
	
sudo grep -R "$strCkanServerIP" /etc/postgresql/9.1/main/pg_hba.conf
if [ $? -eq  1 ]
then
    sudo echo "host    all             all             $strCkanServerIP/32                 md5" >> /etc/postgresql/9.1/main/pg_hba.conf
fi

echo "Setting up SOLR"
echo "Adding Second Core to solr.xml."
strContent='<core name="$strDataBaseName" instanceDir="$strDataBaseName"><property name="dataDir" value="/var/lib/solr/data/$strDataBaseName" /></core>'
C=$(echo $strContent | sed 's/\//\\\//g')
sudo sed -i "/<\/cores>/ s/.*/${C}\n&/" /usr/share/solr/solr.xml
echo "Creating the data directory for your new core."
sudo -u jetty mkdir /var/lib/solr/data/$strDataBaseName
echo "Creating the configuration directory for your new core, and copy the config from your first core into it"
sudo mkdir /etc/solr/$strDataBaseName
sudo cp -R /etc/solr/$strOldDataBaseName/conf /etc/solr/$strDataBaseName/
echo "Replacing the /etc/solr/my-second-solr-core/schema.xml file with a symlink to the schema.xml file from your second CKAN instance"
#sudo mkdir /etc/solr/$strDataBaseName/conf/
echo "Because CKAN is on a seperate server we need to create SOLR's Schema.xml. This script is using the 2.3 version, but it's been marked as 2.0 to stop errors"
sudo echo '<?xml version="1.0" encoding="UTF-8" ?>
<!--
 Licensed to the Apache Software Foundation (ASF) under one or more
 contributor license agreements.  See the NOTICE file distributed with
 this work for additional information regarding copyright ownership.
 The ASF licenses this file to You under the Apache License, Version 2.0
 (the "License"); you may not use this file except in compliance with
 the License.  You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->

<schema name="ckan" version="2.0">

<types>
    <fieldType name="string" class="solr.StrField" sortMissingLast="true" omitNorms="true"/>
    <fieldType name="boolean" class="solr.BoolField" sortMissingLast="true" omitNorms="true"/>
    <fieldtype name="binary" class="solr.BinaryField"/>
    <fieldType name="int" class="solr.TrieIntField" precisionStep="0" omitNorms="true" positionIncrementGap="0"/>
    <fieldType name="float" class="solr.TrieFloatField" precisionStep="0" omitNorms="true" positionIncrementGap="0"/>
    <fieldType name="long" class="solr.TrieLongField" precisionStep="0" omitNorms="true" positionIncrementGap="0"/>
    <fieldType name="double" class="solr.TrieDoubleField" precisionStep="0" omitNorms="true" positionIncrementGap="0"/>
    <fieldType name="tint" class="solr.TrieIntField" precisionStep="8" omitNorms="true" positionIncrementGap="0"/>
    <fieldType name="tfloat" class="solr.TrieFloatField" precisionStep="8" omitNorms="true" positionIncrementGap="0"/>
    <fieldType name="tlong" class="solr.TrieLongField" precisionStep="8" omitNorms="true" positionIncrementGap="0"/>
    <fieldType name="tdouble" class="solr.TrieDoubleField" precisionStep="8" omitNorms="true" positionIncrementGap="0"/>
    <fieldType name="date" class="solr.TrieDateField" omitNorms="true" precisionStep="0" positionIncrementGap="0"/>
    <fieldType name="tdate" class="solr.TrieDateField" omitNorms="true" precisionStep="6" positionIncrementGap="0"/>

    <fieldType name="text" class="solr.TextField" positionIncrementGap="100">
        <analyzer type="index">
            <tokenizer class="solr.WhitespaceTokenizerFactory"/>
            <filter class="solr.WordDelimiterFilterFactory" generateWordParts="1" generateNumberParts="1" catenateWords="1" catenateNumbers="1" catenateAll="0" splitOnCaseChange="1"/>
            <filter class="solr.LowerCaseFilterFactory"/>
            <filter class="solr.SnowballPorterFilterFactory" language="English" protected="protwords.txt"/>
            <filter class="solr.ASCIIFoldingFilterFactory"/>
        </analyzer>
        <analyzer type="query">
            <tokenizer class="solr.WhitespaceTokenizerFactory"/>
            <filter class="solr.SynonymFilterFactory" synonyms="synonyms.txt" ignoreCase="true" expand="true"/>
            <filter class="solr.WordDelimiterFilterFactory" generateWordParts="1" generateNumberParts="1" catenateWords="0" catenateNumbers="0" catenateAll="0" splitOnCaseChange="1"/>
            <filter class="solr.LowerCaseFilterFactory"/>
            <filter class="solr.SnowballPorterFilterFactory" language="English" protected="protwords.txt"/>
            <filter class="solr.ASCIIFoldingFilterFactory"/>
        </analyzer>
    </fieldType>


    <!-- A general unstemmed text field - good if one does not know the language of the field -->
    <fieldType name="textgen" class="solr.TextField" positionIncrementGap="100">
        <analyzer type="index">
            <tokenizer class="solr.WhitespaceTokenizerFactory"/>
            <filter class="solr.WordDelimiterFilterFactory" generateWordParts="1" generateNumberParts="1" catenateWords="1" catenateNumbers="1" catenateAll="0" splitOnCaseChange="0"/>
            <filter class="solr.LowerCaseFilterFactory"/>
        </analyzer>
        <analyzer type="query">
            <tokenizer class="solr.WhitespaceTokenizerFactory"/>
            <filter class="solr.SynonymFilterFactory" synonyms="synonyms.txt" ignoreCase="true" expand="true"/>
            <filter class="solr.WordDelimiterFilterFactory" generateWordParts="1" generateNumberParts="1" catenateWords="0" catenateNumbers="0" catenateAll="0" splitOnCaseChange="0"/>
            <filter class="solr.LowerCaseFilterFactory"/>
        </analyzer>
    </fieldType>
</types>


<fields>
    <field name="index_id" type="string" indexed="true" stored="true" required="true" />
    <field name="id" type="string" indexed="true" stored="true" required="true" />
    <field name="site_id" type="string" indexed="true" stored="true" required="true" />
    <field name="title" type="text" indexed="true" stored="true" />
    <field name="entity_type" type="string" indexed="true" stored="true" omitNorms="true" />
    <field name="dataset_type" type="string" indexed="true" stored="true" />
    <field name="state" type="string" indexed="true" stored="true" omitNorms="true" />
    <field name="name" type="string" indexed="true" stored="true" omitNorms="true" />
    <field name="revision_id" type="string" indexed="true" stored="true" omitNorms="true" />
    <field name="version" type="string" indexed="true" stored="true" />
    <field name="url" type="string" indexed="true" stored="true" omitNorms="true" />
    <field name="ckan_url" type="string" indexed="true" stored="true" omitNorms="true" />
    <field name="download_url" type="string" indexed="true" stored="true" omitNorms="true" />
    <field name="notes" type="text" indexed="true" stored="true"/>
    <field name="author" type="textgen" indexed="true" stored="true" />
    <field name="author_email" type="textgen" indexed="true" stored="true" />
    <field name="maintainer" type="textgen" indexed="true" stored="true" />
    <field name="maintainer_email" type="textgen" indexed="true" stored="true" />
    <field name="license" type="string" indexed="true" stored="true" />
    <field name="license_id" type="string" indexed="true" stored="true" />
    <field name="ratings_count" type="int" indexed="true" stored="false" />
    <field name="ratings_average" type="float" indexed="true" stored="false" />
    <field name="tags" type="string" indexed="true" stored="true" multiValued="true"/>
    <field name="groups" type="string" indexed="true" stored="true" multiValued="true"/>

    <field name="capacity" type="string" indexed="true" stored="true" multiValued="false"/>

    <field name="res_name" type="textgen" indexed="true" stored="true" multiValued="true" />
    <field name="res_description" type="textgen" indexed="true" stored="true" multiValued="true"/>
    <field name="res_format" type="string" indexed="true" stored="true" multiValued="true"/>
    <field name="res_url" type="string" indexed="true" stored="true" multiValued="true"/>
    <field name="res_type" type="string" indexed="true" stored="true" multiValued="true"/>

    <!-- catchall field, containing all other searchable text fields (implemented
         via copyField further on in this schema  -->
    <field name="text" type="text" indexed="true" stored="false" multiValued="true"/>
    <field name="urls" type="text" indexed="true" stored="false" multiValued="true"/>

    <field name="depends_on" type="text" indexed="true" stored="false" multiValued="true"/>
    <field name="dependency_of" type="text" indexed="true" stored="false" multiValued="true"/>
    <field name="derives_from" type="text" indexed="true" stored="false" multiValued="true"/>
    <field name="has_derivation" type="text" indexed="true" stored="false" multiValued="true"/>
    <field name="links_to" type="text" indexed="true" stored="false" multiValued="true"/>
    <field name="linked_from" type="text" indexed="true" stored="false" multiValued="true"/>
    <field name="child_of" type="text" indexed="true" stored="false" multiValued="true"/>
    <field name="parent_of" type="text" indexed="true" stored="false" multiValued="true"/>
    <field name="views_total" type="int" indexed="true" stored="false"/>
    <field name="views_recent" type="int" indexed="true" stored="false"/>
    <field name="resources_accessed_total" type="int" indexed="true" stored="false"/>
    <field name="resources_accessed_recent" type="int" indexed="true" stored="false"/>

    <field name="metadata_created" type="date" indexed="true" stored="true" multiValued="false"/>
    <field name="metadata_modified" type="date" indexed="true" stored="true" multiValued="false"/>

    <field name="indexed_ts" type="date" indexed="true" stored="true" default="NOW" multiValued="false"/>

    <!-- Copy the title field into titleString, and treat as a string
         (rather than text type).  This allows us to sort on the titleString -->
    <field name="title_string" type="string" indexed="true" stored="false" />

    <field name="data_dict" type="string" indexed="false" stored="true" />
    <field name="validated_data_dict" type="string" indexed="false" stored="true" />

    <field name="_version_" type="string" indexed="true" stored="true"/>

    <dynamicField name="*_date" type="date" indexed="true" stored="true" multiValued="false"/>

    <dynamicField name="extras_*" type="text" indexed="true" stored="true" multiValued="false"/>
    <dynamicField name="res_extras_*" type="text" indexed="true" stored="true" multiValued="true"/>
    <dynamicField name="vocab_*" type="string" indexed="true" stored="true" multiValued="true"/>
    <dynamicField name="*" type="string" indexed="true"  stored="false"/>
</fields>

<uniqueKey>index_id</uniqueKey>
<defaultSearchField>text</defaultSearchField>
<solrQueryParser defaultOperator="AND"/>

<copyField source="url" dest="urls"/>
<copyField source="ckan_url" dest="urls"/>
<copyField source="download_url" dest="urls"/>
<copyField source="res_url" dest="urls"/>
<copyField source="extras_*" dest="text"/>
<copyField source="res_extras_*" dest="text"/>
<copyField source="vocab_*" dest="text"/>
<copyField source="urls" dest="text"/>
<copyField source="name" dest="text"/>
<copyField source="title" dest="text"/>
<copyField source="text" dest="text"/>
<copyField source="license" dest="text"/>
<copyField source="notes" dest="text"/>
<copyField source="tags" dest="text"/>
<copyField source="groups" dest="text"/>
<copyField source="res_name" dest="text"/>
<copyField source="res_description" dest="text"/>
<copyField source="maintainer" dest="text"/>
<copyField source="author" dest="text"/>

</schema>' > /etc/solr/${strDataBaseName}/conf/schema.xml
echo "Restart Jetty"
sudo service jetty restart
 
