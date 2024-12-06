#!/bin/bash -u
for vol in $(openstack volume list| grep juju| grep in-use| awk '{print $2}'); do
    echo "Finding attachments for in-use volume $vol"
    for server in $(openstack volume attachment list  --os-volume-api-version 3.27 --volume-id $vol -c 'Server ID' -f value); do
        openstack server show $server && continue
        echo "Deleting attachments for volume $vol from (non-existent) server $server"
        for id in $(openstack volume attachment list  --os-volume-api-version 3.27 --volume-id $vol -c 'ID' -f value); do
            openstack volume attachment delete --os-volume-api-version 3.27 $id
        done
    done
done
