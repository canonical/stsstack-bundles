#!/bin/bash -eu
#
# Author: edward.hope-morley@canonical.com
#
# Description: Use this tool to generate a Juju (2.x) native-format bundle e.g.:
#
#              Trusty + Mitaka Cloud Archive: ./gen-bundle.sh trusty mitaka
#
#              xenial-proposed: ./gen-bundle.sh xenial mitaka proposed
#
#              Xenial + Proposed Newton UCA: ./gen-bundle.sh xenial newton proposed
#
#
series=${1-"xenial"}
release=${2-"ocata"}
pocket=${3-""}
template=`basename $(pwd)`.yaml.template
target=`basename $(pwd)`.yaml

declare -A lts=( [precise]=essex
                 [trusty]=icehouse
                 [xenial]=mitaka )

ltsmatch ()
{
    for s in ${!lts[@]};
        do
            [ "$s" = "$1" ] && [ "${lts[$s]}" = "$2" ] && return 0
        done
    return 1
}

fout=`mktemp`
if [ -z "$series" ] || [ -z "$release" ] ; then
  cat $template| sed -r "/\ssource:.+$/d"| sed -r "/\sopenstack-origin:.+$/d" > $fout
else
  cat $template| sed -e "s/__SERIES__/$series/g" -e "s/__RELEASE__/$release/g" > $fout
  if [ -n "$pocket" ] ; then
      if ltsmatch $series $release ; then
          sed -i -r "s/(openstack-origin:\s)cloud:${series}-${release}__POCKET__/\1distro-$pocket/g" $fout
          sed -i -r "s/(source:\s)cloud:${series}-${release}__POCKET__/\1$pocket/g" $fout
      else
          sed -i -r "s/__POCKET__/\/$pocket/g" $fout
      fi
  else
      sed -i -r "s/__POCKET__//g" $fout
  fi
  if [ `echo -e "$series\nxenia"| sort| head -n 1` = "$series" ]; then
      sed -i -r "s/#__MONGODB__//g" $fout
  fi
fi
mv $fout $target
echo "Bundle successfully written to $target"
