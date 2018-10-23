#!/usr/bin/env bash
# prepare the local registery on the undercloud

sudo yum -y install ceph-ansible
#sudo sed -i.orig 's/8787"$/8787 --insecure-registry docker-registry.engineering.redhat.com"/' /etc/sysconfig/docker
sudo systemctl restart docker.service

openstack overcloud container image prepare \
  --namespace=registry.access.redhat.com/rhosp13 \
  --push-destination=192.168.66.18:8787 \
  --prefix=openstack- \
  --tag-from-label {version}-{release} \
  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/neutron-opendaylight.yaml \
  --set ceph_namespace=registry.access.redhat.com/rhceph \
  --set ceph_image=rhceph-3-rhel7 \
  --output-env-file=/home/stack/templates/overcloud_images.yaml \
  --output-images-file=/home/stack/templates/local_registry_images.yaml

#create registry
sudo openstack overcloud container image upload \
  --verbose --config-file ~/templates/local_registry_images.yaml

curl http://192.168.66.18:8787/v2/_catalog | jq .

#update certificates
#sudo cp overcloud-cacert.pem /etc/pki/ca-trust/source/anchors/
#sudo update-ca-trust extract
