#!/bin/bash -u
STAGING_DIR=`mktemp -d`
clean ()
{
    rm -rf $STAGING_DIR
}
trap clean INT EXIT
. ~/novarc

