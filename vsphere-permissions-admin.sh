#!/bin/bash 
set -e
set -x

export GOVC_URL=l
export GOVC_USERNAME=administrator@vsphere.local
export GOVC_PASSWORD=
export GOVC_INSECURE=true

DATACENTER=
CLUSTER=
DATASTORE=
FOLDER= # VM Folder
NETWORK=

#govc folder.create /$DATACENTER/vm/$FOLDER

#GENERAL
#https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.security.doc/GUID-74F53189-EF41-4AC1-A78E-D25621855800.html
#https://unofficial-kubernetes.readthedocs.io/en/latest/getting-started-guides/vsphere/

#CAPI (Cluster API)
#https://github.com/kubernetes-sigs/cluster-api-provider-vsphere/issues/1350
#https://gist.github.com/jcpowermac/64d1ba94e6820d19d3492b8b782672df
#https://access.redhat.com/documentation/en-us/openshift_container_platform/3.10/html/configuring_clusters/install-config-configuring-vsphere

CAPI_USER="rancher@vsphere.local"
CAPI_SECRET=""
set +e
govc sso.user.rm capi 
govc role.remove -force CAPI-VCENTER
govc role.remove -force CAPI-CLUSTER
govc role.remove -force CAPI-DATASTORE
govc role.remove -force CAPI-PORTGROUP
govc role.remove -force CAPI-VM
set -e
govc sso.user.create -R=RegularUser -d "K8s VMware Storage Automation" -p "$CAPI_SECRET" $(cut -d@ -f1 <<< "$CAPI_USER")

govc permissions.set -propagate=true -principal $CAPI_USER -role ReadOnly /
govc permissions.set -propagate=true  -principal $CAPI_USER -role ReadOnly /$DATACENTER
govc permissions.set -propagate=true  -principal $CAPI_USER -role Admin /$DATACENTER # THIS ONE
govc permissions.set -propagate=true -principal $CAPI_USER -role ReadOnly /$DATACENTER/host/$CLUSTER
#govc permissions.set -propagate=false -principal $CAPI_USER -role ReadOnly /$DATACENTER/network/$DSWITCH

govc role.create CAPI-VCENTER Cns.Searchable InventoryService.Tagging.AttachTag InventoryService.Tagging.CreateCategory InventoryService.Tagging.CreateTag InventoryService.Tagging.DeleteCategory InventoryService.Tagging.DeleteTag InventoryService.Tagging.EditCategory InventoryService.Tagging.EditTag Sessions.ValidateSession StorageProfile.View Sessions.GlobalMessage
govc permissions.set -propagate=true -principal $CAPI_USER -role CAPI-VCENTER /

govc role.create CAPI-CLUSTER Host.Config.Storage Resource.AssignVMToPool VApp.AssignResourcePool VApp.Import VirtualMachine.Config.AddNewDisk
govc permissions.set -propagate=true  -principal $CAPI_USER -role CAPI-CLUSTER /$DATACENTER/host/$CLUSTER
govc permissions.set -propagate=true  -principal $CAPI_USER -role Admin /$DATACENTER/host/$CLUSTER

govc role.create CAPI-DATASTORE Datastore.AllocateSpace Datastore.Browse Datastore.FileManagement
govc permissions.set -propagate=true -principal $CAPI_USER -role CAPI-DATASTORE /$DATACENTER/datastore/$DATASTORE
govc permissions.set -propagate=true -principal $CAPI_USER -role Admin /$DATACENTER/datastore/$DATASTORE

govc role.create CAPI-PORTGROUP Network.Assign
govc permissions.set -propagate=true -principal $CAPI_USER -role CAPI-PORTGROUP /$DATACENTER/network/$NETWORK
govc permissions.set -propagate=true -principal $CAPI_USER -role Admin /$DATACENTER/network/$NETWORK

govc role.create CAPI-VM Resource.AssignVMToPool VApp.Import VirtualMachine.Config.AddExistingDisk VirtualMachine.Config.AddNewDisk VirtualMachine.Config.AddRemoveDevice VirtualMachine.Config.AdvancedConfig VirtualMachine.Config.Annotation VirtualMachine.Config.CPUCount VirtualMachine.Config.DiskExtend VirtualMachine.Config.DiskLease VirtualMachine.Config.EditDevice VirtualMachine.Config.Memory VirtualMachine.Config.RemoveDisk VirtualMachine.Config.Rename VirtualMachine.Config.ResetGuestInfo VirtualMachine.Config.Resource VirtualMachine.Config.Settings VirtualMachine.Config.UpgradeVirtualHardware VirtualMachine.Interact.GuestControl VirtualMachine.Interact.PowerOff VirtualMachine.Interact.PowerOn VirtualMachine.Interact.Reset VirtualMachine.Inventory.Create VirtualMachine.Inventory.CreateFromExisting VirtualMachine.Inventory.Delete VirtualMachine.Provisioning.Clone VirtualMachine.Provisioning.DeployTemplate VirtualMachine.Config.ChangeTracking VirtualMachine.Config.RawDevice VirtualMachine.Provisioning.GetVmFiles VirtualMachine.State.CreateSnapshot VirtualMachine.State.RemoveSnapshot VirtualMachine.Provisioning.DiskRandomRead
govc permissions.set -propagate=true -principal $CAPI_USER -role CAPI-VM /$DATACENTER/vm/$FOLDER
govc permissions.set -propagate=true -principal $CAPI_USER -role Admin /$DATACENTER/vm/$FOLDER


#CSI (Cloud Storage Vsphere)
#https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.storage.doc/GUID-AEB07597-F303-4FDD-87D9-0FDA4836E5BB.html
#https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-storage/GUID-AEB07597-F303-4FDD-87D9-0FDA4836E5BB.html
#https://docs.vmware.com/en/VMware-vSphere-Container-Storage-Plug-in/3.0/vmware-vsphere-csp-getting-started/GUID-0AB6E692-AA47-4B6A-8CEA-38B754E16567.html
#https://developer.vmware.com/samples/7400/create-csi-driver-vcenter-roles

CSI_USER="csi@vsphere.local"
CSI_SECRET=""
set +e
govc sso.user.rm csi
govc role.remove -force CNS-SEARCH-AND-SPBM
govc role.remove -force CNS-DATASTORE
govc role.remove -force CNS-HOST-CONFIG-STORAGE
govc role.remove -force CNS-VM
set -e
govc sso.user.create -R=RegularUser -d "K8s VMware Storage Automation" -p "$CSI_SECRET" $(cut -d@ -f1 <<< "$CSI_USER")

# Root vCenter Server (Cloud Native Storage UI, Storage profiles)
govc role.create CNS-SEARCH-AND-SPBM Cns.Searchable StorageProfile.View 
govc permissions.set -propagate=false -principal $CSI_USER -role CNS-SEARCH-AND-SPBM /
govc permissions.set -propagate=false -principal $CSI_USER -role ReadOnly /

# All hosts where Nodes VMs reside (Datacenter)
govc permissions.set -propagate=false -principal $CSI_USER -role ReadOnly /$DATACENTER 

# Datastore where shared Volumes reside
govc role.create CNS-DATASTORE Datastore.FileManagement
govc permissions.set -propagate=false -principal $CSI_USER -role CNS-DATASTORE /$DATACENTER/datastore/$DATASTORE
govc permissions.set -propagate=false -principal $CSI_USER -role ReadOnly /$DATACENTER/datastore/$DATASTORE

# Only for vSAN cluster for file volumes only 
govc role.create CNS-HOST-CONFIG-STORAGE Host.Config.Storage 
govc permissions.set -propagate=false -principal $CSI_USER -role CNS-HOST-CONFIG-STORAGE /$DATACENTER/host/$CLUSTER
govc permissions.set -propagate=false -principal $CSI_USER -role ReadOnly /$DATACENTER/host/$CLUSTER

# All cluster node VMs
govc role.create CNS-VM VirtualMachine.Config.AddExistingDisk VirtualMachine.Config.AddRemoveDevice
govc permissions.set -propagate=true  -principal $CSI_USER -role CNS-VM /$DATACENTER/vm/$FOLDER
govc permissions.set -propagate=true  -principal $CSI_USER -role ReadOnly /$DATACENTER/vm/$FOLDER


#CPI (Cloud Provider Vsphere)
# https://github.com/kubernetes/cloud-provider-vsphere/blob/master/docs/book/vcp_roles.md#required-permission

CPI_USER="cpi@vsphere.local"
CPI_SECRET=""

set +e
govc sso.user.rm cpi
set -e
govc sso.user.create -R=RegularUser -d "K8s VMware Storage Automation" -p "$CPI_SECRET" $(cut -d@ -f1 <<< "$CPI_USER")
govc permissions.set -propagate=false -principal $CPI_USER -role ReadOnly /$DATACENTER
govc permissions.set -propagate=false -principal $CPI_USER -role ReadOnly /$DATACENTER/host/$CLUSTER
govc permissions.set -propagate=true  -principal $CPI_USER -role ReadOnly /$DATACENTER/vm/$FOLDER
#govc role.usage
#govc role.ls

