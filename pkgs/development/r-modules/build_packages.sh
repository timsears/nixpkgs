#!/bin/bash
# args: names packageset startAt
pkgset=$1
start=$2
end=100000
if [[ $3 -gt $end ]] ; then
end=$3
fi

i=0

for pkg in $(cat $pkgset)
do
    if [[ $i -ge $start && $i -le $end ]] ; then  
       echo "$i: Building ${pkg}"
       nix build -f test-evaluation.nix rPackages.${pkg}
    fi
    let "i+=1"
done

