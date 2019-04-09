declare -A lts=( [trusty]=icehouse
                 [xenial]=mitaka
                 [bionic]=queens )
declare -A nonlts=( [cosmic]=rocky
                    [disco]=stein )

# Reverse lookups
declare -A lts_rev=()
for s in ${!lts[@]}; do
    lts_rev[${lts[$s]}]=$s
done
declare -A nonlts_rev=()
for s in ${!nonlts[@]}; do
    nonlts_rev[${nonlts[$s]}]=$s
done
# sorted alphabetically
readarray -t lts_releases_sorted<<<"`echo -n ${lts[@]}| tr ' ' '\n' | sort -r`"
readarray -t nonlts_releases_sorted<<<"`echo -n ${nonlts[@]}| tr ' ' '\n' | sort -r`"
readarray -t all_releases_sorted<<<"`{ echo -n ${lts[@]}; echo " ${nonlts[@]}"; }| tr ' ' '\n'| sort -r`"
