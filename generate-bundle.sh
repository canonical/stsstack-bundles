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
_series=
release=
pocket=
template=
path=
declare -A lts=( [trusty]=icehouse
                 [xenial]=mitaka
                 [bionic]=queens )

usage () {
echo "USAGE: `basename $0` [--series s] [--release r] [--pocket p] --template t --path p"
}


while (($# > 0))
do
    case "$1" in
        --path)
            path=$2
            shift
            ;;
        --series)
            _series=$2
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
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: invalid input '$1'"
            usage
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

[ -z "$_series" ] || series=$_series

if [ -n "$release" ]; then
    declare -a idx=( ${!lts[@]} )
    i=${#idx[@]}
    __series=${idx[$((--i))]}
    while ! [[ "$release" > "${lts[$__series]}" ]] && ((i>=0)); do
        __series=${idx[$((i--))]}
    done
    # ensure correct series
    [ -n "$_series" ] && [ "$_series" != "$__series" ] && { echo "Series auto-corrected to $__series"; }
    series=$__series
else
    release=${lts[$series]} 
fi

if ltsmatch $series $release ; then
  source=''
else
  source="cloud:${series}-${release}"
fi

if [ -n "$pocket" ]; then
  if [ -n "$source" ]; then
    source="${source}\/${pocket}"
  else
    source="$pocket";
  fi
fi

fout=`mktemp -d`/`basename $template| sed 's/.template//'`
cat $template| sed -e "s/__SERIES__/$series/g" -e "s/__SOURCE__/$source/g" > ${fout}.tmp

os_origin=$source
[ "$os_origin" = "proposed" ] && os_origin="distro-proposed"
cat ${fout}.tmp| sed -e "s/__SERIES__/$series/g" -e "s/__OS_ORIGIN__/$os_origin/g" > $fout

dst=`dirname $path`/bundles/
mkdir -p $dst
mv $fout $dst
target=${series}-$release
[ -z "$pocket" ] || target=${target}-$pocket
result=$dst`basename $fout`

if [[ "${release,,}" < "pike" ]]; then
sed -i '/#MIN_PIKE{/,/#}MIN_PIKE/{//!d}' $result
fi
sed -ri '/.+MIN_PIKE.*/d' $result

if [[ "${release,,}" < "mitaka" ]]; then
sed -i '/#MIN_MITAKA{/,/#}MIN_MITAKA/{//!d}' $result
fi
sed -ri '/.+MIN_MITAKA.*/d' $result

echo "Your $target bundle can be found at $result"
