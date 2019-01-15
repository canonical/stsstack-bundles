declare -A parameters=()
declare -a overlays=()

_usage () {
cat << EOF
USAGE: `basename $0` INTERNAL_OPTS OPTIONS [OVERLAYS]

OPTIONS:
     --create-model
        Create Juju model using --name. Switches to model if it already
        exists. If this is not provided then the current Juju model is used.
     -h, --help
        Display this help message.
     --list
        List existing bundles.
     -n, --name n
        Name for bundle. If this is not provided then the default bundle
        location is used.
     -p, --pocket p
        Archive pocket to install packages from e.g. "proposed".
     -r, --release r
        Openstack release. This allows UCA to be used otherwise base archive
        of release is used.
     --replay
        Replay last command for bundle --name (or default bundle if no name
        provided).
     --run
        Automatically execute the generated deployment command.
     -s, --series s
        Ubuntu series.
    --use-stable-charms
        By default the development (cs:~openstack-charmers-next) version of
        the charms are used where available. Use this flag if you want to
        use the stable (released) charms i.e. cs:<charm>.

OVERLAYS:
     You can optionally add one or more feature overlay. These are
     specified as --<overlayname> using the name of an overlay as found in
     the output of running ./generate-bundle.sh --list-overlays.

     Note that overlays listed with a asterisk at the end of the name
     support having a number of units specified using a colon e.g.

     ./generate-bundle.sh --myoverlay:6

     will give you six units of myoverlay. This is useful for overlays
     that provide HA or scale-out services.

INTERNAL_OPTS (don't use these):
     --bundle-params
        (internal only) Bundle paramaters passed by sub-generator
     --overlay p
        (internal only) Overlay to be added to deployment. Can be
        specified multiple times.
     --path p
        (internal only) Target bundle directory
     -t, --template t
        (internal only) Generated bundle templates.
EOF
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
