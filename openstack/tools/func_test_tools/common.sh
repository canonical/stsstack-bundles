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
                                --destroy-storage $model
        else
            juju destroy-model --yes --force --no-wait --destroy-storage \
                                $model
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
    local msg=$(echo "Func-Test-Pr: https://github.com/openstack-charmers/zaza-openstack-tests/pull/$pr_id"| base64)
    ~/zosci-config/roles/handle-func-test-pr/files/process_func_test_pr.py \
        -f './test-requirements*.txt' \
        -f './src/test-requirements*.txt' \
        "$msg"
}