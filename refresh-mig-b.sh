#!/bin/bash
set -x

if (($# != 2)); then
  echo "Use arguments <project> <step# 1..3>"
  exit 2
fi

PROJECTID=$1
EXECSTEP=$2

# Load parameters
source ./setvars.sh

FILEBASE=`basename $0`
MIGNAME=${VMNAME}-mig
MIGVER=$(date +%u)
CURRDATE=$(date +%F)

gcloud config set project $PROJECTID
CURRTEMPLATENAME=`gcloud beta compute instance-groups managed list  --filter="zone~${ZONE} AND name~${MIGNAME}" --format="value(instanceTemplate)"`
CURRVER="${CURRTEMPLATENAME: -1}"

if [ ${MIGVER} == ${CURRVER} ]
then
    MIGVER=9
fi

IMAGENAME=${VMNAME}-image-$MIGVER
MIGTEMPLATE=${VMNAME}-template-$MIGVER

write_log()
{
  logmsg=$1
  echo `date`":"${1} 
}

write_log "Will be updating to new version of ${MIGVER}"

write_log "Setting default project to ${PROJECTID}"
gcloud config set project $PROJECTID

create_new_image()
{
  write_log "Creating new image..."
  gcloud compute images delete $IMAGENAME --quiet 
  RC=$?
  write_log "Done. Return code:$RC"
  write_log "NOTE: it is safe to ignore NOT FOUND error on the first few runs."
  gcloud compute images create $IMAGENAME --source-disk $VMNAME \
    --source-disk-zone $ZONE \
    --storage-location $REGION  --force
  RC=$?
  if [ ${RC} == "0" ]
  then
        write_log "Done. Return code:$RC"
  else
        write_log "ERR: New image creation failed. Return code:$RC"
        write_log "Manual investigation is required."
        write_log "Exiting with the return code 10..."
	exit 10  
  fi
}

create_new_template()
{
  write_log "Creating new template..."
  gcloud beta compute instance-templates delete $MIGTEMPLATE --quiet 
  RC=$?
  write_log "Done. Return code:$RC"
  write_log "NOTE: it is safe to ignore NOT FOUND error on the first few runs."
  gcloud beta compute instance-templates create $MIGTEMPLATE \
    --image-project=${PROJECTID} --image=${IMAGENAME} \
    --machine-type=${MACHINETYPE} --maintenance-policy=migrate \
    --service-account=${SERVICEACCT} \
    --tags=${NWTAG} \
    --disk name=${DISK1},auto-delete=no,device-name=${DISK1},mode=rw \
    --disk name=${DISK2},auto-delete=no,device-name=${DISK2},mode=rw \
    --restart-on-failure \
    --region=${REGION} \
    --network=${VPCNAME} --subnet=${SUBNETNAME} --private-network-ip=${IPADDRESS} --no-address
  RC=$?
  if [ ${RC} == "0" ]
  then
        write_log "Done. Return code:$RC"
  else
        write_log "ERR: New MIG template creation failed. Return code:$RC"
        write_log "Manual investigation is required."
        write_log "Exiting with the return code 11..."
        exit 11
  fi
}

update_instance_group()
{
  gcloud compute instance-groups managed rolling-action start-update $MIGNAME \
    --version template=${MIGTEMPLATE} \
    --type=opportunistic \
    --zone $ZONE 
  RC=$?
  write_log "Done. Return code:$RC"

  write_log "Updating instance group with new template..."
  gcloud beta compute instance-groups managed set-instance-template $MIGNAME \
    --template=${MIGTEMPLATE} --zone $ZONE 
  RC=$?
  if [ ${RC} == "0" ]
  then
        write_log "Done. Return code:$RC"
  else
        write_log "ERR: MIG update failed. Return code:$RC"
        write_log "Manual investigation is required."
        write_log "Exiting with the return code 12..."
        exit 12
  fi

  write_log "Updating the current instance in the managed instance group..."
  gcloud beta compute --project $PROJECTID instance-groups managed update-instances $MIGNAME \
    --zone $ZONE --instances $VMNAME 
  RC=$?
    if [ ${RC} == "0" ]
  then
        write_log "Done. Return code:$RC"
        write_log "Refresh task completed successfully..."
  else
        write_log "FATAL ERR: MIG instance update failed. Return code:$RC"
        write_log "Immediate investigation is required."
        write_log "Exiting with the return code 13..."
        exit 13
  fi
  write_log "End of log."
}

case $EXECSTEP in
    1)
      create_new_image
      ;;
    2)
      create_new_template
      ;;
    3)
      update_instance_group
      ;;
esac
