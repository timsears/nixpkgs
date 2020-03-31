#!/bin/bash
# args: names pkgs start end
pkgs=$1
start=$2
end=100000
if [[ $3 -ne 0 ]] ; then
    end=$3
    echo "building from $start to $end"
fi


i=0
trap "exit" INT
for pkg in $(cat $pkgs)
do
    if [[ $i -ge $start && $i -le $end ]] ; then
       echo "$i of $start to $end: Building ${pkg}"
       nix build -f test-evaluation.nix rPackages.${pkg}
    fi
    let "i+=1"
    
done

