 openstack subnet unset --allocation-pool start=192.168.202.5,end=192.168.202.254 edge-data202-subnet
 openstack subnet set --allocation-pool start=192.168.202.5,end=192.168.202.240 edge-data202-subnet
 openstack subnet unset --allocation-pool start=192.168.203.5,end=192.168.203.254 epc-ctrl203-subnet
 openstack subnet set --allocation-pool start=192.168.203.5,end=192.168.203.240 epc-ctrl203-subnet
 openstack subnet unset --allocation-pool start=192.168.204.5,end=192.168.204.254 epc-data204-subnet
 openstack subnet set --allocation-pool start=192.168.204.5,end=192.168.204.240 epc-data204-subnet
 openstack subnet unset --allocation-pool start=192.168.205.5,end=192.168.205.254 ims-ctrl205-subnet
 openstack subnet set --allocation-pool start=192.168.205.5,end=192.168.205.240 ims-ctrl205-subnet
 openstack subnet unset --allocation-pool start=192.168.206.5,end=192.168.206.254 ims-data206-subnet
 openstack subnet set --allocation-pool start=192.168.206.5,end=192.168.206.240 ims-data206-subnet
 openstack subnet unset --allocation-pool start=192.168.207.5,end=192.168.207.254 gilan207-subnet
 openstack subnet set --allocation-pool start=192.168.207.5,end=192.168.207.240 gilan207-subnet
 openstack subnet unset --allocation-pool start=192.168.208.5,end=192.168.208.254 oam208-subnet
 openstack subnet set --allocation-pool start=192.168.208.5,end=192.168.208.240 oam208-subnet

