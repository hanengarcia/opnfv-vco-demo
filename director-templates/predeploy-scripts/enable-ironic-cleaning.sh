#!/bin/bash
echo "Enabling Ironic Metadata Disk Cleaning"
sudo egrep "clean|erase" /etc/ironic/ironic.conf | egrep -v \#
sudo sed -i s/automated_clean=False/automated_clean=True/g /etc/ironic/ironic.conf
sudo egrep "clean|erase" /etc/ironic/ironic.conf | egrep -v \#
sudo systemctl restart openstack-ironic-conductor.service
sudo systemctl status openstack-ironic-conductor.service

source ~/stackrc
echo "Cleaning nodes for first time (this will run automatically on stack delete next time)"
for ID in $(openstack baremetal node list -f value -c UUID); do
    openstack baremetal node manage $ID;
    openstack baremetal node provide $ID;
done 
openstack baremetal node list
