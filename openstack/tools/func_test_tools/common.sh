destroy_zaza_models ()
{
    if $(juju destroy-model --help| grep -q "no-prompt"); then
        j3=true
    else
        j3=false
    fi
    for model in $(juju list-models| egrep -o "^zaza-\S+"|tr -d '*'); do
        if $j3; then
            juju destroy-model --no-prompt --force --no-wait \
                                --destroy-storage $model || true
        else
            juju destroy-model --yes --force --no-wait --destroy-storage \
                                $model || true
        fi
    done
}

get_and_update_repo ()
{
    url=$1
    name=$(basename $url)
    path=${2:-$HOME}
    (
    cd $path
    if [[ -d $name ]]; then
        cd $name
        git checkout master
        git pull
    else
        git clone $url
    fi
    )
}

apply_func_test_pr ()
{
    # Similar to https://github.com/openstack-charmers/zosci-config/blob/master/roles/handle-func-test-pr/tasks/main.yaml#L19
    local pr_id=$1
    # We use the zosci-config tools to do this.
    local msg
    msg=$(echo "Func-Test-Pr: https://github.com/openstack-charmers/zaza-openstack-tests/pull/$pr_id"| base64)
    ~/zosci-config/roles/handle-func-test-pr/files/process_func_test_pr.py \
        -f './test-requirements*.txt' \
        -f './src/test-requirements*.txt' \
        "$msg"
}

allocate_port ()
{
    # Returns address of port created.
    #
    local net_name=$1
    local port_name=$2
    local port_id
    port_id=$(openstack port create --network $net_name $port_name -c id -f value)
    openstack port show -c fixed_ips $port_id -f yaml| yq .fixed_ips[0].ip_address
}

create_zaza_vip ()
{
    # Allocates a vip ensuring to use existing ones if they exist.
    #
    # Returns the address of the vip.
    #
    local vip_id=$1
    # We use the same naming convention as ../tools/allocate_vips.sh to avoid conflicts and re-use
    # those vips.
    vip_port_name=ps6-vip-ip$vip_id
    vip_addr=$(openstack port show -c fixed_ips $vip_port_name -f yaml| yq .fixed_ips[0].ip_address)
    if [[ $vip_addr = null ]]; then
        # Pre-allocate ports with addresses used for VIPs so that they don't
        # collide with the deployment itself.
        vip_addr=$(allocate_port net_${OS_USERNAME}-psd $vip_port_name)
    fi
    echo $vip_addr
}
