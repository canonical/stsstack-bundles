declare -A parameters=()
declare -a overlays=()

_usage () {
echo "USAGE: `basename $0` [--name n] [--series s] [--release r] [--pocket p] [--replay] --template t --path p $@"
}

get_units()
{
    units=`echo $1| sed -r 's/.+:([[:digit:]])/\1/;t;d'`
    [ -n "$units" ] || units=$3
    parameters[$2]=$units
}

get_param()
{
    read -p "$2" val
    parameters[$1]="$val"
}


generate()
{
for overlay in ${overlays[@]:-}; do
    opts+=( "--overlay $overlay" )
done
ftmp=
if ((${#parameters[@]})); then
    ftmp=`mktemp`
    echo -n "sed -i " > $ftmp
    for p in ${!parameters[@]}; do
        echo -n "-e 's/$p/${parameters[$p]}/g' " >> $ftmp
    done
    opts+=( --bundle-params $ftmp )
fi
`dirname $0`/common/generate-bundle.sh ${opts[@]}
[ -n "$ftmp" ] && rm $ftmp
}
