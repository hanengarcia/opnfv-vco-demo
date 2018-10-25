#!/bin/bash -x

# -------------------------------------------------------
STACKNAME=vco2

# SAFETY CHECKS
if [ "$#" -lt 1 ]; then
  echo "Pass: $0 deploy --> deploy RHOSP"
  echo "Pass: $0 updateUC1 --> update RHOSP undercloud, then reboot"
  echo "Pass: $0 updateUC2 --> update RHOSP undercloud (after reboot)"
  echo "Pass: $0 updateOC --> update RHOSP overcloud"
  exit 1
fi

test "$(whoami)" != 'stack' && (echo "This must be run by the stack user on the
undercloud"; exit 1)

function deployRHOSP {
time openstack overcloud deploy \
  --templates \
  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
  -e ~/templates/overcloud_images.yaml \
  --environment-directory ~/environments \
  --timeout 120 \
  --verbose \
  --stack $STACKNAME
}

function updateUC1 {
echo "Wiping old IPA images."
openstack image list | awk '$2 && $2 != "ID" {print $2}' | xargs -n1 openstack image delete

sudo yum -y update python-tripleoclient
time openstack undercloud upgrade
echo "Reboot the undercloud to update the operating system's kernel and other system packages."
}

function updateUC2 {
rm -rf  ~/images/*
cd ~/images
for i in /usr/share/rhosp-director-images/overcloud-full-latest-13.0.tar /usr/share/rhosp-director-images/ironic-python-agent-latest-13.0.tar; do tar -xvf $i; done
cd ~

time openstack overcloud image upload --image-path /home/stack/images
openstack overcloud node configure $(openstack baremetal node list -c UUID -f value)

openstack image list
ls -l /httpboot
echo "Done updating the undercloud."
}

function updateOC {
openstack overcloud update prepare --stack $STACKNAME --templates \
  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
  -e ~/templates/overcloud_images.yaml \
  --environment-directory ~/environments

openstack overcloud update run --stack $STACKNAME --nodes Controller
openstack overcloud update run --stack $STACKNAME --nodes Compute
openstack overcloud update run --stack $STACKNAME --nodes CephStorage

openstack overcloud ceph-upgrade run --stack $STACKNAME --templates \
  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
  -e ~/templates/overcloud_images.yaml \
  --environment-directory ~/environments

time openstack overcloud update converge --stack $STACKNAME --templates \
  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
  -e ~/templates/overcloud_images.yaml \
  --environment-directory ~/environments

echo "Update complete."
}


if [ $1 = "deploy" ]; then
    deployRHOSP
fi

if [ $1 = "updateUC1" ]; then
    updateUC1
fi

if [ $1 = "updateUC2" ]; then
    updateUC2
fi

if [ $1 = "updateOC" ]; then
    updateOC
fi

exit 0
