#!/bin/bash -eu
#
# Author: edward.hope-morley@canonical.com
#
# Description: Use this tool to generate a Juju (2.x) native-format bundle e.g.:
#
#              Trusty + Mitaka Cloud Archive: ./generate-bundle.sh --series trusty --release mitaka
#
#              Xenial (Mitaka) Proposed: ./generate-bundle.sh --series xenial --pocket proposed
#
#              Xenial + Proposed Ocata UCA: ./generate-bundle.sh --series xenial --release ocata --pocket proposed
#
#
series=xenial
release=
pocket=
template=
path=
declare -A lts=( [trusty]=icehouse
                 [xenial]=mitaka
                 [bionic]=queens )
while (($# > 0))
do
    case "$1" in
        --path)
            path=$2
            shift
            ;;
        --series)
            series=$2
            shift
            ;;
        --release)
            release=$2
            shift
            ;;
        --pocket)
            pocket=$2
            shift
            ;;
        --template)
            template=$2
            shift
            ;;
        *)
            echo "ERROR: invalid input '$1'"
            echo "USAGE: `basename $0` [--series s] [--release r] [--pocket p] --template t --path p"
            exit 1
            ;;
    esac
    shift
done

[ -z "$template" ] || [ -z "$path" ] && { echo "ERROR: no template provided with --template"; exit 1; }

ltsmatch ()
{
    [ -z "$release" ] && return 0
    for s in ${!lts[@]}; do
        [ "$s" = "$1" ] && [ "${lts[$s]}" = "$2" ] && return 0
    done
    return 1
}

if ltsmatch $series $release ; then
  _release=''
else
  _release="cloud:${series}-${release}"
fi
[ -z "$pocket" ] || \
  if [ -n "$_release" ]; then
    _release="${_release}\/${pocket}"
  else
    _release="$pocket";
  fi

fout=`mktemp -d`/`basename $template| sed 's/.template//'`
cat $template| sed -e "s/__SERIES__/$series/g" -e "s/__SOURCE__/$_release/g" > ${fout}.tmp
os_origin=$_release
[ "$os_origin" = "proposed" ] && os_origin="distro-proposed"
cat ${fout}.tmp| sed -e "s/__SERIES__/$series/g" -e "s/__OS_ORIGIN__/$os_origin/g" > $fout
dst=`dirname $path`/bundles/
mkdir -p $dst
mv $fout $dst
[ -n "$release" ] || release=${lts[$series]} 
target=${series}-$release
[ -z "$pocket" ] || target=${target}-$pocket
result=$dst`basename $fout`
if [[ "${series,,}" < "xenial" ]]; then
sed -i '/#MIN_XENIAL{/,/#}MIN_XENIAL/{//!d}' $result
fi
sed -ri '/.+MIN_XENIAL.*/d' $result
echo "Your $target bundle can be found at $result"
