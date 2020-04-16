#!/bin/bash -eu
# Upload amphora image from stsstack swift to overcloud glance.
#
# ./tools/upload_octavia_amphora_image.sh [release] [image-format]

declare release=
declare image_format=

while (( $# > 0 )); do
  case $1 in
    --release|-r)
      release=$2
      shift
      ;;
    --image-format|-f)
      image_format=$2
      shift
      ;;
    --help|-h)
      cat <<EOF
Usage:

./tools/upload_octavia_amphora_image.sh --release RELEASE [--image-format FORMAT]

Options:

--help | -h             This help
--release | -r          The OpenStack release
--image-format | -f     The image format {'qcow2', 'raw'}. The default
                        is qcow2.
EOF
      exit
      ;;
    *)
      echo "Unknown command line option $1"
      exit 1
      ;;
  esac
  shift
done

if [[ -z ${release} ]]; then
  echo "Missing release. Please specify one with --release command line option"
  exit 1
fi

set -x
source ~/novarc
tmp=`mktemp`
source ~/novarc
swift list images > $tmp
ts=`sed -r "s/.+-([[:digit:]]+)-$release.+/\1/g;t;d" $tmp| sort -h| tail -n 1`
img="`egrep "${ts}.+$release" $tmp| tail -n 1`"
rm $tmp

export SWIFT_IP="10.230.19.58"
. ./profiles/common
source novarc
upload_image swift octavia-amphora $img $image_format

image_name=octavia-amphora
if [[ $image_format == raw ]]; then
  image_name=${image_name}-raw
fi

openstack image set --tag octavia-amphora ${image_name}
