#!/bin/bash
# args: names packageset startAt
pkgset=$1
start=$2
if [[ $3 -gt 0 ]] ; then
    end=$3
else
    end=10000000
fi    
nix eval -f test-evaluation.nix "$1" > "$1"
sed -i "$1" -e 's/\[ //g' -e 's/ ]//g' -e 's/ /\n/g' -e 's/\"//g'  
cat "$1" | while read pkg || [[ -n $line ]];
do
    if [[ $i -ge $start && $i -le $end ]] ; then  
       echo "$i: Building ${pkg}"
       nix build -f test-evaluation.nix rpkgs.${pkg}
    fi
    let "i+=1"
done
