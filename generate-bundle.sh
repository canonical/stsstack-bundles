#!/bin/bash -eu
#
# Author: edward.hope-morley@canonical.com
#
# Description: Use this tool to generate a Juju (2.x) native-format bundle e.g.:
#
#              Trusty + Mitaka Cloud Archive: ./generate-bundle.sh trusty mitaka
#
#              xenial-proposed: ./generate-bundle.sh xenial mitaka proposed
#
#              Xenial + Proposed Newton UCA: ./generate-bundle.sh xenial newton proposed
#
#
series=${1-""}
release=${2-""}
pocket=${3-""}
template=`basename $(pwd)`.yaml.template
target=`basename $(pwd)`.yaml

# PLEASE KEEP THE FOLLOWING UP-TO-DATE AS NEW RELEASES COME OUT AND OLDER ONES ARE DEPRECATED.
# See https://www.ubuntu.com/info/release-end-of-life 
declare -A lts=( [trusty]=icehouse
                 [xenial]=mitaka 
                 [bionic]=queens )
declare -A nonlts=( [zesty]=
                    [artful]= )


[ -e "$template" ] || { echo "Template '$template' not found. Are you in a bundle directory?"; exit 1; }

default_r=false
if [ -z "$series" ]; then
  series=xenial
  release=
  default_r=true
  echo "Using default series '$series' (with distro release of openstack i.e. ${lts[$series]})"
elif ! ( _=${lts[$series]} ) 2>/dev/null; then
  if ! ( _=${nonlts[$series]} ) 2>/dev/null; then 
    echo "Unknown series '$series'. Please specify one of: ${!lts[@]} ${!nonlts[@]}"
    exit 1
  fi
else
  echo "Using series '$series'"
fi

if ! $default_r; then
  if [ -n "$release" ]; then
    echo "Using release '$release'"
  else
    echo -n "Using $series distro release of openstack"
    if ! ( _=${nonlts[$series]} ) 2>/dev/null; then
      echo " i.e. '${lts[$series]}'"
    else
      echo ""
    fi
  fi
fi

if [ -z "$pocket" ]; then
  echo "Using default pocket"
else
  echo "Using pocket '$pocket'"
fi

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
  cat $template| sed -r "/\ssource:.+$/d"| sed -r "/\sopenstack-origin:.+$/d" > ${fout}.tmp
  cat ${fout}.tmp| sed -e "s/__SERIES__/$series/g" > $fout
  rm ${fout}.tmp
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
