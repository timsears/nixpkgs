#!/bin/bash
# args: names packageset startAt
pkgset=$1
start=$3
i=1
nix eval -f test-evaluation.nix "$1" > "$1"
sed -i "$1" -e 's/\[ //g' -e 's/ ]//g' -e 's/ /\n/g' -e 's/\"//g'  
cat "$1" | while read pkg || [[ -n $line ]];
do
    if [[ ${i} -ge ${start} ]] ; then  
       echo "$i: Building ${pkg}"
       nix build -f test-evaluation.nix $2.${pkg}
    fi
    let "i+=1"
done
