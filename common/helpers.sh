export CACHED_STDIN=( $@ )
((${#CACHED_STDIN[@]})) || CACHED_STDIN=( "" )
DEFAULT_SERIES=bionic

. $LIB_COMMON/openstack_release_info.sh

_usage () {
cat << EOF
USAGE: `basename $0` INTERNAL_OPTS OPTIONS [OVERLAYS]

OPTIONS:
     --charm-channel
        Charm channel to deploy from (if supported).
     --create-model
        Create Juju model using --name. Switches to model if it already
        exists. If this is not provided then the current Juju model is used.
     --model-config
        Path to YAML config for the model to be created.
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
     --internal-module-path <path>
        (internal only) Bundle module path.
     --internal-template <path>
        (internal only) Bundle base template.
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

get_optval ()
{
    opt=$1
    _f () {
    while (($#)); do
        if [ "$1" = "$opt" ]; then
            echo $2
        fi
        shift
    done
    }
    _f ${CACHED_STDIN[@]}
}

get_param_forced()
{
    has_opt --replay && return

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

    has_opt --replay && return

    val=`get_optstrarg $1`
    if [ -z "$val" ] || $force; then
        if [ -n "$default" ] && ! $force; then
            val="$default"
        else
            read -p "$3" val
        fi
    fi
    [ -z "$val" ] || parameters[$2]="$val"
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
            echo -n "-e 's,$p,${parameters[$p]},g' " >> $ftmp
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
        sed -r -e 's/.+\s+(--[[:alnum:]\-]+).+#__OPT__type:(.+)/      \1 \2/g' \
               -e 's/.+\s+(--[[:alnum:]\-]+).+#__OPT__$/      \1/g;t;d'
}

has_series ()
{
    while (($#)); do
        if [ "$1" = "-s" ] || [ "$1" = "--series" ]; then
             return 0
        fi
        shift
    done
    return 1
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

get_uca_release ()
{
    r=`get_release ${CACHED_STDIN[@]}`
    s=`get_series ${CACHED_STDIN[@]}`
    # no release means its lts so no uca
    [ -n "$r" ] || return
    # lts s+r means no uca
    ltsmatch "$s" "$r" && return
    # else its uca
    echo $release
}

get_pocket ()
{
    while (($#)); do
        if [ "$1" = "-p" ] || [ "$1" = "--pocket" ]; then
             echo $2
             return 0
        fi
        shift
    done
}

cache ()
{
    # ensure cached opts contains any new ones
    declare -A dict
    for e in ${CACHED_STDIN[@]}; do dict[$e]=false; done
    for e in $@; do [ -n ${dict[$e]:-""} ] || CACHED_STDIN+=( $e ); done
}

has_opt ()
{
    opt="$1"
    _f () {
    while (($# > 0))
    do
        [[ "$1" = $opt ]] && return 0
        shift
    done
    return 1
    }
    _f ${CACHED_STDIN[@]}
    return $?
}

check_opt_conflict ()
{
    good=$1
    bad=$2
    `has_opt $bad` || return 0
    echo "ERROR: option $good conflicts with $bad"
    exit 1
}

assert_min_release ()
{
    min=$1
    msg=$2
    r=`get_release ${CACHED_STDIN[@]}`
    [ -n "$r" ] || r=${lts[`get_series ${CACHED_STDIN[@]}`]:-${nonlts[`get_series ${CACHED_STDIN[@]}`]:-""}}
    [[ "$r" < "$min" ]] || return 0
    echo "Min release '$min' required to be able to use $msg (currently using '$r')" 1>&2
    exit 1
}

ltsmatch ()
{
    series="$1"
    release="$2"

    [ -n "$release" ] || return 0
    for s in ${!lts[@]}; do
        [ "$s" = "$series" ] && [ "${lts[$s]}" = "$release" ] && return 0
    done
    return 1
}

nonltsmatch ()
{
    series="$1"
    release="$2"

    [ -n "$release" ] || return 0
    for s in ${!nonlts[@]}; do
        [ "$s" = "$series" ] && [ "${nonlts[$s]}" = "$release" ] && return 0
    done

    return 1
}

ost_series_autocorrect ()
{
    series="$1"
    release="$2"

    if [ -n "$release" ] && ! ltsmatch "$series" "$release" && \
            ! nonltsmatch "$series" "$release"; then
        num_rels=${#lts_releases_sorted[@]}
        newseries=""
        for r in ${lts_releases_sorted[@]}; do
            if [[ "$release" > "$r" ]]; then
                newseries=${lts_rev[$r]}
                break
            fi
        done

        # ensure correct series
        if ! has_series; then
            if ! [ "$series" = "$newseries" ]; then
                echo "Series auto-corrected from '$series' to '$newseries'" 1>&2
            fi
        fi
        series=$newseries
    fi
    echo $series
}

ost_release_autocorrect ()
{
    series="$1"
    release="$2"

    # Attempt to auto-correct series/release name combination errors
    if [ -z "$release" ] || { `ltsmatch "$series" "$release"` || \
            `nonltsmatch "$series" "$release"`; }; then
        release=${lts[$series]:-${nonlts[$series]:-}}
        if [ -z "$release" ]; then
            echo "No release found for series '$series'" 1>&2
            exit 1
        fi
    fi
    echo $release
}

# Requires APP_RELEASE_NAMES set by module generate-bundle.sh
get_app_release_name ()
{
    ubuntu_release="$1"
    release_name=

    [ -n "$release" ] || return 0
    readarray -t names_sorted_asc<<<"`echo ${!APP_RELEASE_NAMES[@]}| \
                                            tr ' ' '\n'| sort`"
    for name in ${names_sorted_asc[@]}; do
        rel=${APP_RELEASE_NAMES[$name]}
        if ! [[ "$rel" > "$ubuntu_release" ]]; then
            release_name=$name
        fi
    done
    echo $release_name
    return 0
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

# get cli model name if available since it might not have been created yet.
get_juju_model ()
{
if `has_opt --create-model`; then
    name="`get_optval --name`"
    if [ -n "$name" ]; then
        echo $name
    fi
else
    juju list-models 2>/dev/null| sed -r 's/^(.+)\* .+/\1/g;t;d'
fi
}

pocket=`get_pocket $@`
# get cli provided values or fallback to default
series=`get_series $@`
release=`get_release $@`

# The following is openstack specific but applies to multiple bundle
# modules so putting it here.
series=`ost_series_autocorrect "$series" "$release"`
release=`ost_release_autocorrect "$series" "$release"`
if ! ltsmatch "$series" "$release" && ! nonltsmatch "$series" "$release" ; then
    source="cloud:${series}-${release}"
else
    source=""
fi
if [ -n "$pocket" ]; then
    if [ -n "$source" ]; then
        source="${source}\/${pocket}"
    else
        source="$pocket";
    fi
fi
if [ "$source" = "proposed" ]; then
    os_origin="distro-proposed"
else
    os_origin="$source"
fi
