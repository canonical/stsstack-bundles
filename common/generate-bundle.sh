#!/bin/bash -eu
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers
. pipeline/00setup
. pipeline/01import-config-defaults
. pipeline/02configure
. pipeline/03build
# Ensure no unrendered variables
out="`grep -r __ b/${MASTER_OPTS[BUNDLE_NAME]} --exclude=config`"
[ -n "$out" ] || exit
echo -e "ERROR: there are unrendered variables in your bundle:\n$out"
