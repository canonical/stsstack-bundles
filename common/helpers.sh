declare -A parameters=()
declare -a overlays=()

DEFAULT_SERIES=bionic

. $LIB_COMMON/openstack_release_info.sh

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
     --list-overlays
        List supported overlays.
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
     that provide HA or scale-out services. See --list-overlays for
     available overlays.

INTERNAL_OPTS (don't use these):
     --internal-bundle-params <path>
        (internal only) Bundle parameters passed by sub-generator
     --internal-overlay <path>
        (internal only) Overlay to be added to deployment. Can be
        specified multiple times.
     --internal-generator-path <path>
        (internal only) Bundle generator path.
     --internal-template <path>
        (internal only) Bundle generator base template.
     --internal-version-info <path>
        (internal only) 
EOF
list_opts
}

get_optintarg ()
{
    # format we are looking for is --opt:intval
    echo $1| sed -r 's/.+:([[:digit:]])/\1/;t;d'
}

get_optstrarg ()
{
    # format we are looking for is --opt:strval
    echo $1| sed -r 's/.+:([[:alnum:]])/\1/;t;d'
}

get_param_forced()
{
    (($#==4)) && get_param "$@" true || \
         get_param "$@" "" true
}

get_param()
{
    opt=$1
    key=$2
    msg=$3
    default=${4:-""}
    force=${5:-false}

    val=`get_optstrarg $1`
    if [ -z "$val" ] || $force; then
        if [ -n "$default" ] && ! $force; then
            val="$default"
        else
            read -p "$3" val
        fi
    fi
    parameters[$2]="$val"
}


get_units()
{
    opt=$1
    key=$2
    default=$3

    # format we are looking for is --opt:val
    val=`get_optintarg $1`
    if [ -z "$val" ]; then
        val="$default"
    fi
    parameters[$2]="$val"
}



generate()
{
    # path to file containing series/release info
    (($#)) && opts+=( "--internal-version-info $1" )

    for overlay in ${overlays[@]:-}; do
        opts+=( "--internal-overlay $overlay" )
    done

    ftmp=
    if ((${#parameters[@]})); then
        ftmp=`mktemp`
        echo -n "sed -i " > $ftmp
        for p in ${!parameters[@]}; do
            echo -n "-e 's/$p/${parameters[$p]}/g' " >> $ftmp
        done
        opts+=( "--internal-bundle-params $ftmp" )
    fi

    . $LIB_COMMON/generate-bundle-base.sh ${opts[@]}

    [ -n "$ftmp" ] && rm $ftmp
}

list_overlays ()
{
    echo "Supported overlays:"
    grep -v __OPT__ `basename $0`| \
        sed -r 's/.+\s+(--[[:alnum:]\-]+\*?)\).*/\1/g;t;d'
}

list_opts ()
{
    echo -e "\nBUNDLE OPTS:"
    grep __OPT__ `basename $0`| \
        sed -r 's/.+\s+(--[[:alnum:]\-]+).+#__OPT__type:(.+)/      \1 \2/g;t;d'
}

get_series ()
{
    while (($#)); do
        if [ "$1" = "-s" ] || [ "$1" = "--series" ]; then
             echo $2
             return 0
        fi
        shift
    done
    echo $DEFAULT_SERIES
}

get_release ()
{
    while (($#)); do
        if [ "$1" = "-r" ] || [ "$1" = "--release" ]; then
             echo $2
             return 0
        fi
        shift
    done
}

has_opt ()
{
opt="$1"
shift
while (($# > 0))
do
    [[ "$1" =~ $opt ]] && return 0
    shift
done
return 1
}

assert_min_release ()
{
    min=$1
    msg=$2
    shift 2
    r=`get_release $@`
    [ -n "$r" ] || r=${lts[`get_series $@`]:-${nonlts[`get_series $@`]:-""}}
    [[ "$r" < "$min" ]] || return 0
    echo "Min release '$min' required to be able to use $msg (currently using '$r')" 1>&2
    exit 1
}

trap_help ()
{
while (($# > 0))
do
    case "$1" in
        -h|--help)
            _usage
            exit 0
            ;;
    esac
    shift
done
}
