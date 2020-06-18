#!/bin/bash

# Instance-specific parameters here

export REGION=us-east4
export ZONE=us-east4-c
export VMNAME=jpmigvm01
export DISK1=data-disk-1
export DISK2=data-disk-1
export MACHINETYPE=n1-standard-1
export SERVICEACCT=jpmigvm01-compute@jp-poc-260114.iam.gserviceaccount.com
export NWTAG="backend,vpcinternal"
export VPCNAME=projects/jpsharedvpc/global/networks/default
export SUBNETNAME=projects/jpsharedvpc/regions/us-east4/subnetworks/default
export IPADDRESS="10.150.0.2"
