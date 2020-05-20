#!/bin/bash -eu
MOD_DIR=`dirname $0`
. $MOD_DIR/common/helpers
. $MOD_DIR/pipeline/00setup
. $MOD_DIR/pipeline/01import-config-defaults
. $MOD_DIR/pipeline/02configure
. $MOD_DIR/pipeline/03build
# Ensure no unrendered variables
out="`grep -r __ $MOD_DIR/b/${MASTER_OPTS[BUNDLE_NAME]} --exclude=config`"
[ -n "$out" ] || exit
echo -e "ERROR: there are unrendered variables in your bundle:\n$out"
