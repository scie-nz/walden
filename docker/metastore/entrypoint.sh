#!/bin/bash
mkdir -p conf
bash -c "echo -e \"$(cat /config/metastore-site.xml.template)\" > conf/metastore-site.xml"
bin/schematool -initSchema -dbType postgres -ifNotExists
bin/start-metastore
