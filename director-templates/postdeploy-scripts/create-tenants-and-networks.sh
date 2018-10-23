#!/bin/bash

source ~/vco2rc

USERS="dave"
#USERS="metaswitch-ims oam quortus-ims gi-lan quortus-epc f5-network-slicing monitoring acme-inc exfo-active-test"


for user in ${USERS}; do
  openstack user create ${user} --password ${user} --email ${user}@${user}.vco2.lab.local
  openstack project create ${user} --description "vCO2 Project for ${user}"
  openstack role add --project ${user} --user ${user} _member_
  tenantUser=$(openstack user show ${user} -f value -c id)
  tenant=$(openstack project show ${user} -f value -c id)

  #quota updates
  nova quota-update $tenant --instances 10 --cores 20 --ram 32768
  cinder quota-update --volumes 20 --gigabytes 900 $tenant
  neutron quota-update --tenant_id $tenant --port 30 --floatingip 10

  #admin add for visibility
  openstack role add --project ${user} --user admin _member_

done
