#!/bin/bash

for infile in $(ls etc/*.template); do
    outfile=$(echo "$infile" | sed "s/\\.template$//g")
    echo "Rendering $infile => $outfile"
    bash -c "echo -e \"$(cat $infile)\" > $outfile"
done

bin/launcher run -v
