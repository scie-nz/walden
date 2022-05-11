#!/bin/bash

# Render all "*.template" files under /trino-server/etc/**.
# For example, render "foo.properties.template" with output written to "foo.properties"
for infile in $(find /trino-server/etc -iname '*.template' ); do
    outfile=$(echo "$infile" | sed "s/\\.template$//g")
    echo "Rendering $infile => $outfile"
    bash -c "echo -e \"$(cat $infile)\" > $outfile"
    rm -v $infile
done

/trino-server/bin/launcher run -v
