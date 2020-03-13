#!/bin/bash -eu
# Get all non-special variables from existing overlays and bundles
readarray -t vars<<<"`egrep -r ':.+__' overlays| egrep -v '__RESOURCES_PATH__|__SSL_|__VIP__|__SOURCE__|__OS_ORIGIN__'| sed -r 's/.+(__.+__).*/\1/g'| sort -u`"
# Get all module defaults
readarray -t mod_defaults<<<"`find .module_defaults -type l`"
echo "Checking ${#vars[@]} vars..."
for var in ${vars[@]}; do
    found=false
    for defs in ${mod_defaults[@]}; do
        egrep -q "^MOD_PARAMS\[$var\]" $defs && found=true
    done
    $found || echo "$var has no default"
done
echo "Done."
