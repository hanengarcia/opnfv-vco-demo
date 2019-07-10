#!/bin/bash

# -------------------------------------------------------
# SAFETY CHECKS
test "$(whoami)" != 'stack' && (echo "This must be run by the stack user on the
undercloud"; exit 1)

ironic node-update server-1-1 remove properties/root_device
ironic node-update server-1-2 remove properties/root_device
ironic node-update server-1-3 remove properties/root_device
ironic node-update server-1-4 remove properties/root_device
ironic node-update server-1-5 remove properties/root_device
ironic node-update server-1-6 remove properties/root_device
ironic node-update server-2-1 remove properties/root_device
ironic node-update server-2-2 remove properties/root_device
ironic node-update server-2-3 remove properties/root_device
ironic node-update server-2-4 remove properties/root_device
ironic node-update server-s-1 remove properties/root_device
ironic node-update server-s-2 remove properties/root_device

openstack overcloud node configure server-1-1 --root-device=sda
openstack overcloud node configure server-1-2 --root-device=sda
openstack overcloud node configure server-1-3 --root-device=sda
openstack overcloud node configure server-1-4 --root-device=sda
openstack overcloud node configure server-1-5 --root-device=sda
openstack overcloud node configure server-1-6 --root-device=sda
openstack overcloud node configure server-2-1 --root-device=sda
openstack overcloud node configure server-2-2 --root-device=sda
openstack overcloud node configure server-2-3 --root-device=sda
openstack overcloud node configure server-2-4 --root-device=sda
openstack overcloud node configure server-s-1 --root-device=sda
openstack overcloud node configure server-s-2 --root-device=sda
