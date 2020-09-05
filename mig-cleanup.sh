#!/bin/bash

set -v

# Load parameters
source ./setvars.sh

MIGNAME=${VMNAME}-mig
MIGVER=9

gcloud config set project $PROJECTID
CURRTEMPLATENAME=`gcloud beta compute instance-groups managed list  --filter="zone~${ZONE} AND name~${MIGNAME}" --format="value(instanceTemplate)"`
CURRVER="${CURRTEMPLATENAME: -1}"
IMAGENAME=${VMNAME}-image-$MIGVER
MIGTEMPLATE=${VMNAME}-template-$MIGVER

gcloud config set project $PROJECTID

gcloud beta compute instance-groups managed delete $MIGNAME --zone=${ZONE} --quiet
gcloud beta compute instance-templates delete ${CURRTEMPLATENAME} --quiet
gcloud compute health-checks delete $HEALTHCHECK --quiet
gcloud compute images delete $IMAGENAME --quiet
gcloud beta compute disks delete $DISK1 --quiet --zone=${ZONE}
gcloud beta compute disks delete $DISK2 --quiet --zone=${ZONE}
