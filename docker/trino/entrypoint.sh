#!/bin/bash

for infile in $(ls etc/*.template) $(ls etc/catalog/*.template); do
    outfile=$(echo "$infile" | sed "s/\\.template$//g")
    echo "Rendering $infile => $outfile"
    bash -c "echo -e \"$(cat $infile)\" > $outfile"
    rm -v $infile
done

bin/launcher run -v
