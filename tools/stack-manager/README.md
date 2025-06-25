# Stack Resource Management (stack-manager)

In order to keep resource consumption fair across tenants, we implement some rules on how long instances can be left running without intervention. Inside our cloud we collect information on running instances and create per-tenant catalogs where those vms are marked as managed along with information about when they will be shutdown - their TTL. If a VM is included in a catalog and marked for shutdown we say it is "managed". The logic for deciding whether a VM should be managed and how long a ttl to give it is defined as follows:

* if you have any Juju unit vms running they are tagged with a ttl of 3 days
* if you have no Juju unit vms running, your Juju controller VM(s) are tagged with a ttl of 3 days
* if you have no Juju vms running at all then any other vms are tagged with a ttl of 7 days 

Once a VM reaches its TTL it is shutdown. You can mark VMs as unmanaged using the tools in this directory i.e.

* mark-model-vms-unmanaged.sh - use this to mark all vms from a Juju model as unmanaged for the current cycle i.e. they will remain in the catalog until their existing TTL expires but will not be shutdown.

* mark-model-vms-managed.sh - use this to mark all vms from a Juju model as managed i.e. they will remain in the catalog until their existing TTL expires and will be shutdown when it does.

* mark-vms-unmanaged.sh - mark one or more vms as unmanaged.

* mark-vms-managed.sh - mark one or more vms as managed.

* show-managed.sh - show all vms currently marked as managed.

* show-all.sh - show all vms in the catalog i.e. managed or unmanaged.

The catalogs are refreshed every hour or so i order to keep them up to date. When the expiry check runs, if a managed VM is already shutdown the VM is removed from the catalog.

NOTE: bastions are never managed so will not be powered off. 
