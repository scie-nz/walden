#!/bin/bash

bash -c "echo -e \"$(cat etc/node.properties.template)\" > etc/node.properties"
bash -c "echo -e \"$(cat etc/config.properties.template)\" > etc/config.properties"
bin/launcher run -v
