#!/bin/bash -eu
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers
. pipeline/01setup
. pipeline/02configure
. pipeline/03build
