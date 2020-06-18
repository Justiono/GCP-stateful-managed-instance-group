#!/bin/bash

export _MIGVER=$(date +%u)
export _CURRDATE=$(date +%F)
export _REGION=us-east4
export _ZONE=us-east4-c
export _VMNAME=jpmigvm01
export _MIGNAME=${_VMNAME}-mig
export _DISK1=data-disk-1
export _DISKDEV1=jpdata-disk-1
export _DISK2=data-disk-1
export _DISKDEV2=jpdata-disk-2
export _MACHINETYPE=n1-standard-1
export _SERVICEACCT=jpmigvm01-compute@jp-poc-260114.iam.gserviceaccount.com
export _NWTAG="backend,vpcinternal"
export _VPCNAME=projects/jpsharedvpc/global/networks/default
export _SUBNETNAME=projects/jpsharedvpc/regions/us-east4/subnetworks/default
export _IPADDRESS="10.150.0.2"
export _IMAGENAME=${VMNAME}-image-$MIGVER
export _MIGTEMPLATE=${MIGNAME}-template-$MIGVER
