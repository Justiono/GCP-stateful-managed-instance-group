#!/bin/bash

set -x

# Load parameters
source ./setvars.sh

MIGVER=9	# dummy version as starting point, could use any value

MIGNAME=${VMNAME}-mig
CURRDATE=$(date +%F)

gcloud config set project $PROJECTID

IMAGENAME=${VMNAME}-image-$MIGVER
MIGTEMPLATE=${VMNAME}-template-${MIGVER}


# You may remove the data disks and Vm creation if they are existing resources

# Create data disks
gcloud beta compute disks create $DISK1 --project=${PROJECTID} --type=pd-standard --size=200GB --zone=${ZONE} --physical-block-size=4096
gcloud beta compute disks create $DISK2 --project=${PROJECTID} --type=pd-standard --size=200GB --zone=${ZONE} --physical-block-size=4096

# Create a new Windows VM
# You may want to create this manually or use an existing instance

gcloud beta compute --project=${PROJECTID} instances create ${VMNAME} --zone=$ZONE --machine-type=${MACHINETYPE} \
      --subnet=${SUBNETNAME} --private-network-ip=${IPADDRESS} --no-address --maintenance-policy=MIGRATE \
      --service-account=${SERVICEACCT} --scopes=https://www.googleapis.com/auth/cloud-platform \
      --image=windows-server-2016-dc-v20200813 --image-project=windows-cloud --boot-disk-size=50GB \
      --boot-disk-type=pd-standard --boot-disk-device-name=${VMNAME} \
      --disk=boot=no,mode=rw,auto-delete=no,name=${DISK1},device-name=${DISK1} \
      --disk=boot=no,mode=rw,auto-delete=no,name=${DISK2},device-name=${DISK2} \
      --no-shielded-secure-boot \
      --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any
RC=$?
if [ ${RC} != "0" ]
  then
        echo "Operation failed! Exiting now..."
        exit 10
fi

# Create initial consistent image
gcloud compute instances stop $VMNAME --zone=$ZONE 
gcloud compute images delete $IMAGENAME --quiet		# just in case an image exists with the same name

echo "Ignore this kind of message: ERROR: (gcloud.compute.images.delete) Could not fetch resource:"

gcloud compute images create $IMAGENAME --source-disk $VMNAME \
    --source-disk-zone $ZONE \
    --storage-location $REGION 
RC=$?
if [ ${RC} == "0" ]
then
        echo "A new image was created. Return code:$RC"
	echo "The VM will be deleted."
        gcloud compute instances delete $VMNAME --zone=$ZONE --quiet
else
        echo "Failed to create a new image from the VM. Return code:$RC"
        echo "Starting the VM and exiting..."
        gcloud compute instances start $VMNAME --zone=$ZONE
	exit 10
fi


# Create health-check
gcloud compute health-checks create tcp ${HEALTHCHECK} \
    --description="Sample health check for a Windows file server" \
    --check-interval=30s --port=3389 --timeout=10 \
    --healthy-threshold=2 \
    --unhealthy-threshold=3

RC=$?
if [ ${RC} != "0" ]
  then
        echo "Operation failed! Exiting now..."
        exit 10
fi

# Create MIG template

gcloud beta compute instance-templates create $MIGTEMPLATE \
  --image-project=${PROJECTID} --image=${IMAGENAME} \
  --machine-type=${MACHINETYPE} --maintenance-policy=migrate \
  --service-account=${SERVICEACCT} \
  --tags=${NWTAG} \
  --disk=name=${DISK1},auto-delete=no,device-name=${DISK1},mode=rw,boot=no \
  --disk=name=${DISK2},auto-delete=no,device-name=${DISK2},mode=rw,boot=no \
  --restart-on-failure \
  --region=${REGION} \
  --network=${VPCNAME} --subnet=${SUBNETNAME} --private-network-ip=${IPADDRESS} --no-address

RC=$?
if [ ${RC} != "0" ]
  then
        echo "Operation failed! Exiting now..."
        exit 10
fi

# Create Stateful MIG 

gcloud beta compute instance-groups managed create $MIGNAME \
    --stateful-disk auto-delete=never,device-name=${DISK1} \
    --stateful-disk auto-delete=never,device-name=${DISK2} \
    --size 0 --health-check=${HEALTHCHECK} \
    --template ${MIGTEMPLATE} \
    --zone=${ZONE}

RC=$?
if [ ${RC} != "0" ]
  then
        echo "Operation failed! Exiting now..."
        exit 10
fi

gcloud compute instance-groups managed rolling-action start-update $MIGNAME \
        --version=template=${MIGTEMPLATE} \
        --type=opportunistic \
        --replacement-method=recreate --max-surge=0 \
        --zone=${ZONE}

RC=$?
if [ ${RC} != "0" ]
  then
        echo "Operation failed! Exiting now..."
        exit 10
fi

gcloud compute instance-groups managed create-instance $MIGNAME \
     --instance=${VMNAME} --zone=${ZONE}
