#!/bin/bash
#<2018-09-10 dcain>
# -------------------------------------------------------
# This script only needs to be run once after initial deployment
# Assumes systems with subscriptions
# Written specifically for VCOv2 Demo

# -------------------------------------------------------
# HARD CODED VARIABLES
inventory_file=$HOME/ansible/hosts
stack_name=vco2

# -------------------------------------------------------
# SAFETY CHECKS
if [ "$#" -lt 1 ]; then
  echo "Pass: $0 lldp --> turn on lldp via script and package installs"
  echo "Pass: $0 ssh --> allow ssh as root via external interface on all nodes"
  echo "Pass: $0 ocpost --> enabling fencing, post deployment verification"
  exit 1
fi

test "$(whoami)" != 'stack' && (echo "This must be run by the stack user on the
undercloud"; exit 1)

controllers=$(grep controllers $inventory_file -A 1 | tail -1 | awk {'print $1'})
if [[ -z $controllers ]]; then
    echo "No host under [controllers] in $inventory_file. Exiting. "
exit 1 
fi

if ! hash ansible 2>/dev/null; then
    echo "Cannot find ansible command. Exiting. "
exit 1 
fi

function lldp {
# -------------------------------------------------------
# INSTALL PRE-REQ SOFTWARE & COPY LLDP SCRIPT TO ALL NODES
echo "Installing software via yum and copying lldp script to enable network discovery"
ansible -m shell -a "yum -y install lldpad" -i $inventory_file all -b
ansible -m copy -a "src=$HOME/postdeploy-scripts/lldp.sh dest=/home/heat-admin/lldp.sh mode=0744" -i $inventory_file all -b
ansible -m shell -a "systemctl start lldpad" -i $inventory_file all -b
ansible -m shell -a "systemctl enable lldpad" -i $inventory_file all -b
ansible -m shell -a "cd /home/heat-admin; ./lldp.sh" -i $inventory_file all -b

}

function ssh {
# -------------------------------------------------------
# ALLOW SSH AS ROOT VIA PASSWORD AUTHENTICATION
echo "Allowing ssh as root, password authentication"
ansible -m shell -a "sed -i 's|[#]*PasswordAuthentication no|PasswordAuthentication yes|g' /etc/ssh/sshd_config" -i $inventory_file all -b --ssh-common-args='-o StrictHostKeyChecking=no'
ansible -m shell -a "systemctl restart sshd.service" -i $inventory_file all -b
}

function ocpost {

echo "Creating Overcloud postdeployment validation/verification"
source ~/vco2rc

#upload fedora 28 cloud image
echo "Uploading fedora 28 and rhel7 cloud images to image store"
cd $HOME/postdeploy-scripts/
curl -L https://download.fedoraproject.org/pub/fedora/linux/releases/28/Cloud/x86_64/images/Fedora-Cloud-Base-28-1.1.x86_64.qcow2 > fedora28.qcow2
qemu-img convert fedora28.qcow2 fedora28.raw
openstack image create --disk-format raw --container-format bare --file $HOME/postdeploy-scripts/fedora28.raw  --public fedora28
openstack image create --disk-format raw --container-format bare --file $HOME/postdeploy-scripts/rhel7.raw  --public rhel7

#create new project/user/tenant
openstack user create redhat --password redhat --email redhat@example.com
openstack project create redhat-tenant
openstack role add --project redhat-tenant --user redhat _member_
tenantUser=$(openstack user list | awk '/redhat/ {print $2}')
tenant=$(openstack project list | awk '/redhat/ {print $2}')

#quota updates
nova quota-update $tenant --instances 500 --cores 500 --ram 1228800
cinder quota-update --volumes 500 --gigabytes 216000 $tenant
neutron quota-update --tenant_id $tenant --port 100000 --floatingip 200

#create custom flavors
#openstack flavor create --public baremetal --id auto --ram 1024 --disk 20 --vcpus 1 --property baremetal=true --public
openstack flavor create --public m1.small --id auto --ram 1024 --disk 10 --vcpus 1 --public
openstack flavor create --public m1.medium --id auto --ram 4096 --disk 20 --vcpus 2 --public
openstack flavor create --public f5-gi-lan --id auto --ram 16384 --disk 250 --vcpus 4 --public
openstack flavor create --public f5-session-dir --id auto --ram 8192 --disk 142 --vcpus 4 --public
openstack flavor create --public ng1-normal --id auto --ram 32768 --disk 1100 --vcpus 8 --public
openstack flavor create --public vstream-normal --id auto --ram 32768 --disk 500 --vcpus 8 --public
openstack flavor create --public quortus-medium --id auto --ram 4096 --disk 40 --vcpus 2 --public
openstack flavor create --public quortus-small --id auto --ram 2048 --disk 40 --vcpus 1 --public
#openstack flavor create --id auto --ram 1024 --disk 10 --vcpus 2 dpdk-flavor.s1 --public
#openstack flavor set \
#  --property hw:mem_page_size=large \
#  --property hw:cpu_policy=dedicated \
#  --property hw:cpu_thread_policy=prefer \
#  --property hw:numa_mempolicy=preferred \
#  --property hw:numa_nodes=1 \
#  dpdk-flavor.s1

#aggregates and hosts
#openstack aggregate create --property baremetal=true baremetal-hosts
#openstack aggregate add host baremetal-hosts server-1-5
#openstack aggregate add host baremetal-hosts server-1-6
#openstack aggregate add host baremetal-hosts server-1-7
#openstack aggregate add host baremetal-hosts server-1-8
#openstack aggregate create --zone=dpdk1 dpdk1
#openstack aggregate create --zone=dpdk2 dpdk2
#openstack aggregate add host dpdk1 $stack_name-compute-0.localdomain
#openstack aggregate add host dpdk2 $stack_name-compute-1.localdomain

#security groups inbound exception as admin user
admin_project_id=$(openstack project list | grep admin | awk '{print $2}')
admin_sec_group_id=$(openstack security group list | grep $admin_project_id | awk '{print $2}')

openstack security group rule create $admin_sec_group_id --protocol icmp --ingress
openstack security group rule create $admin_sec_group_id --protocol tcp --dst-port 22 --ingress

#security groups exception as redhat user
source ~/redhatrc
neutron security-group-rule-create --direction ingress --protocol icmp default
neutron security-group-rule-create --direction ingress --protocol tcp --port_range_min 22 --port_range_max 22 default

# Keypair creation as redhat user for SSH through floating ip
openstack keypair create dcain > ~/dcain.pem
chmod 600 ~/dcain.pem

# Tenant Network as redhat user
openstack network create tenant1
openstack subnet create tenant1-subnet --network tenant1 --dhcp --allocation-pool start=172.255.1.2,end=172.255.1.254 --dns-nameserver 192.168.0.254 --gateway 172.255.1.1 --subnet-range 172.255.1.0/24
openstack router create tenant1-router
subnet_id=$(neutron subnet-list | awk ' /172.255.1./ {print $2 } ')
openstack router add subnet tenant1-router $subnet_id

#provider DPDK networks as admin user
#source ~/rhlen-mwcrc
#openstack network create dpdk211 --provider-physical-network dpdk --provider-network-type vlan --provider-segment 211 --share
#openstack subnet create dpdk211-subnet --network dpdk211 --dhcp --allocation-pool start=172.16.211.2,end=172.16.211.100 --dns-nameserver 172.21.172.1 --gateway 172.16.211.1 --subnet-range 172.16.211.0/24
#openstack network create dpdk212 --provider-physical-network dpdk --provider-network-type vlan --provider-segment 212 --share
#openstack subnet create dpdk212-subnet --network dpdk212 --dhcp --allocation-pool start=172.16.212.2,end=172.16.212.100 --dns-nameserver 172.21.172.1 --gateway 172.16.212.1 --subnet-range 172.16.212.0/24

#provider networks as admin user for non-DPDK setup
#vlans 26,201-208
source ~/vco2rc
openstack network create internet26 --provider-physical-network datacentre --provider-network-type vlan --provider-segment 26 --share
openstack subnet create internet26-subnet --network internet26 --dhcp --allocation-pool start=172.21.26.5,end=172.21.26.254 --dns-nameserver 192.168.0.254 --gateway 172.21.26.1 --subnet-range 172.21.26.0/24
#openstack network create baremetal67 --provider-physical-network datacentre --provider-network-type vlan --provider-segment 67 --share
#openstack subnet create baremetal67-subnet --network baremetal67 --dhcp --allocation-pool start=192.168.67.20,end=192.168.67.254 --dns-nameserver 192.168.0.254 --gateway 192.168.67.1 --subnet-range 192.168.67.0/24 --ip-version 4
openstack network create edge-ctrl201 --provider-physical-network datacentre --provider-network-type vlan --provider-segment 201 --share
openstack subnet create edge-ctrl201-subnet --network edge-ctrl201 --dhcp --allocation-pool start=192.168.201.5,end=192.168.201.240 --dns-nameserver 192.168.0.254 --subnet-range 192.168.201.0/24 --gateway none
openstack network create edge-data202 --provider-physical-network datacentre --provider-network-type vlan --provider-segment 202 --share
openstack subnet create edge-data202-subnet --network edge-data202 --dhcp --allocation-pool start=192.168.202.5,end=192.168.202.240 --dns-nameserver 192.168.0.254 --subnet-range 192.168.202.0/24 --gateway none
openstack network create epc-ctrl203 --provider-physical-network datacentre --provider-network-type vlan --provider-segment 203 --share
openstack subnet create epc-ctrl203-subnet --network epc-ctrl203 --dhcp --allocation-pool start=192.168.203.5,end=192.168.203.240 --dns-nameserver 192.168.0.254 --subnet-range 192.168.203.0/24 --gateway none
openstack network create epc-data204 --provider-physical-network datacentre --provider-network-type vlan --provider-segment 204 --share
openstack subnet create epc-data204-subnet --network epc-data204 --dhcp --allocation-pool start=192.168.204.5,end=192.168.204.240 --dns-nameserver 192.168.0.254 --subnet-range 192.168.204.0/24 --gateway none
openstack network create ims-ctrl205 --provider-physical-network datacentre --provider-network-type vlan --provider-segment 205 --share
openstack subnet create ims-ctrl205-subnet --network ims-ctrl205 --dhcp --allocation-pool start=192.168.205.5,end=192.168.205.240 --dns-nameserver 192.168.0.254 --subnet-range 192.168.205.0/24 --gateway none
openstack network create ims-data206 --provider-physical-network datacentre --provider-network-type vlan --provider-segment 206 --share
openstack subnet create ims-data206-subnet --network ims-data206 --dhcp --allocation-pool start=192.168.206.5,end=192.168.206.240 --dns-nameserver 192.168.0.254 --subnet-range 192.168.206.0/24 --gateway none
openstack network create gilan207 --provider-physical-network datacentre --provider-network-type vlan --provider-segment 207 --share
openstack subnet create gilan207-subnet --network gilan207 --dhcp --allocation-pool start=192.168.207.5,end=192.168.207.240 --dns-nameserver 192.168.0.254 --subnet-range 192.168.207.0/24 --gateway none
openstack network create oam208 --provider-physical-network datacentre --provider-network-type vlan --provider-segment 208 --share
openstack subnet create oam208-subnet --network oam208 --dhcp --allocation-pool start=192.168.208.5,end=192.168.208.240 --dns-nameserver 192.168.0.254 --subnet-range 192.168.208.0/24 --gateway 192.168.208.1
openstack network create corporate --share
openstack subnet create corporate-subnet --network corporate --dhcp --allocation-pool start=172.255.2.5,end=172.255.2.254 --dns-nameserver 192.168.0.254 --subnet-range 172.255.2.0/24 --gateway none

# OAM208 Tenant Network as admin user
openstack router create oam208-router
subnet_id=$(neutron subnet-list | awk ' /192.168.208./ {print $2 } ')
openstack router add subnet oam208-router $subnet_id

# Ironic in the overcloud baremetal router creation
#openstack router create baremetal67-router
#openstack router add subnet baremetal67-router baremetal67-subnet

# Ironic in the overcloud deployment images
#openstack image create --container-format aki --disk-format aki --public --file ~/images/ironic-python-agent.kernel bm-deploy-kernel
#openstack image create --container-format ari --disk-format ari --public --file ~/images/ironic-python-agent.initramfs bm-deploy-ramdisk

# Ironic in the overcloud user images rhel7
#cd ~/postdeploy-scripts/
#export DIB_LOCAL_IMAGE=~/postdeploy-scripts/rhel-server-7.4-x86_64-kvm.qcow2
#disk-image-create rhel7 baremetal -o rhel-image
#KERNEL_ID=$(openstack image create --file rhel-image.vmlinuz --public --container-format aki --disk-format aki -f value -c id rhel-image.vmlinuz)
#RAMDISK_ID=$(openstack image create --file rhel-image.initrd --public --container-format ari --disk-format ari -f value -c id rhel-image.initrd)
#openstack image create --file rhel-image.qcow2 --public --container-format bare --disk-format qcow2 --property kernel_id=$KERNEL_ID --property ramdisk_id=$RAMDISK_ID rhel-image

# Ironic in the overcloud user images centos7
#export DIB_LOCAL_IMAGE=~/postdeploy-scripts/CentOS-7-x86_64-GenericCloud.qcow2.qcow2
#disk-image-create centos7 baremetal dhcp-all-interfaces grub2 -o centos-image
#KERNEL_ID=$(openstack image create --file centos-image.vmlinuz --public --container-format aki --disk-format aki -f value -c id centos-image.vmlinuz)
#RAMDISK_ID=$(openstack image create --file centos-image.initrd --public --container-format ari --disk-format ari -f value -c id centos-image.initrd)
#openstack image create --file centos-image.qcow2 --public --container-format bare --disk-format qcow2 --property kernel_id=$KERNEL_ID --property ramdisk_id=$RAMDISK_ID centos-image


# Floating IP network as admin user, tie to oam208 network too
openstack network create floating --external --provider-network-type vlan --provider-physical-network datacentre --provider-segment 25
openstack subnet create floating-subnet --network floating --no-dhcp --gateway 172.21.25.1 --allocation-pool start=172.21.25.171,end=172.21.25.254 --dns-nameserver 192.168.0.254 --subnet-range 172.21.25.0/24
route_id=$(openstack router list | awk ' /tenant1/ { print $2 } ')
ext_net_id=$(openstack network list | awk ' /floating/ { print $2 } ')
#openstack router set $route_id --external-gateway $ext_net_id
neutron router-gateway-set $route_id $ext_net_id
route_id=$(openstack router list | awk ' /oam208/ { print $2 } ')
neutron router-gateway-set $route_id $ext_net_id

# Floating IP allocate 15
source ~/redhatrc
for i in {1..2}
do
    openstack floating ip create floating
done

# instance booting dpdk example
#openstack server create --flavor dpdk-flavor.s1 --availability-zone dpdk1 --image rhel7 --nic net-id=38e99f1a-6168-4006-bfcf-15d7f1a50608 --nic net-id=50e66689-b208-4ca1-a681-55dc9db764f0 --key-name dcain vnf-0-1
#openstack server create --flavor dpdk-flavor.s1 --availability-zone dpdk2 --image rhel7 --nic net-id=38e99f1a-6168-4006-bfcf-15d7f1a50608 --nic net-id=50e66689-b208-4ca1-a681-55dc9db764f0 --key-name dcain vnf-1-1

#instance booting non-dpdk example
#openstack server create --flavor m1.medium --image rhel7 --nic net-id=963549c3-fe2e-49a0-a312-996a0950c03f --key-name dcain dcain1

}

if [ $1 = "lldp" ]; then
    lldp
fi

if [ $1 = "ssh" ]; then
    ssh
fi

if [ $1 = "ocpost" ]; then
    ocpost
fi

exit 0
