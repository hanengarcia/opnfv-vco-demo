# Infrastructure Prep

This Ansible setup prepares two jump servers used to manage the infrastructure.  The
first, `jumpserver`, is a private server that is ONLY used by infrastructure admins,
and the second, `opnfv-demo`, shares responsibilities as both the RHOSP provisioner
as well as a jump server for users of the infrastructure.  The two jump server
approach is used to allow recovery functions in case either one goes south for the winter
as well as to retain a safe entry point for any infrastructure recovery operations.

Given that this is a low level infrastructure playbook, it necessarily needs to be
tweaked based on the actual infrastructure, so this playbook is at best guidance for
anything other than the VCO-2.0 demo hosted in the Cumulus Networks labs.

The baseline topology for the two jumpservers is...
```
          Internet                       Internet
             |                              |
     ------------------             ------------------
    |    jumpserver    |           |    opnfv-demo    |
     ------------------             ------------------
      |      |       |               |            |
      |      |      -------------------           |
      |      |              |                     |
   console  pdu         oob & ipmi            data plane
```

Each of the two infrastructure servers has a seperate Internet connection (i.e. IP address
and as much path separation as possible).  `jumpserver` provides connection services
to console (to each switch and server) and smart PDUs; there are utilties on both
jumpservers that allow infrastrucure admins to get to console/pdu/ipmi interface by name.

Any variation of this infrastructure needs to alter the console/pdu/ipmi utilities as well
as interface and routing configurations based on the topology presented... hopefully, I've
left enough bread-crumbs to help guide you.  Any questions can be directed to
jrrivers@cumulusnetworks.com.
