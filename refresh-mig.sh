#!/bin/bash

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
LOGFILE=${FILEBASE%.*}-${CURRDATE}.log
IMAGENAME=${VMNAME}-image-$MIGVER
MIGTEMPLATE=${MIGNAME}-template-$MIGVER

write_log()
{
  logmsg=$1
  echo `date`":"${1} >>$LOGFILE 2>/dev/null
}

write_log "Setting default project to ${PROJECTID}"
gcloud config set project $PROJECTID >>$LOGFILE 2>/dev/null

create_new_image()
{
  write_log "Abandoning the instance..."
  gcloud compute instance-groups managed abandon-instances $MIGNAME \
    --instances $VMNAME \
    --zone=$ZONE >>$LOGFILE 2>&1
  RC=$?
  write_log "Done. Return code:$RC"

  write_log "Stopping the instance..."
  gcloud compute instances stop $VMNAME --zone=$ZONE >>$LOGFILE 2>&1
  write_log "Done. Return code:" $?

  write_log "Creating new image..."
  gcloud compute images delete $IMAGENAME --quiet >>$LOGFILE 2>&1
  write_log "Done. Return code:" $?
  gcloud compute images create $IMAGENAME --source-disk $VMNAME \
    --source-disk-zone $ZONE \
    --storage-location $REGION >>$LOGFILE 2>&1
  write_log "Done. Return code:" $?
}

create_new_template()
{
  write_log "Creating new template..."
  gcloud beta compute instance-templates delete $MIGTEMPLATE --quiet >>$LOGFILE 2>&1
  write_log "Done. Return code:" $?
  gcloud beta compute instance-templates create $MIGTEMPLATE \
    --image-project=${PROJECTID} --image=${IMAGENAME} \
    --machine-type=${MACHINETYPE} --maintenance-policy=migrate \
    --service-account=${SERVICEACCT} \
    --tags=${NWTAG} \
    --disk name=${DISK1},auto-delete=no,device-name=${DISK1},mode=rw \
    --disk name=${DISK2},auto-delete=no,device-name=${DISK2},mode=rw \
    --restart-on-failure \
    --region=${REGION} \
    --network=${VPCNAME} --subnet=${SUBNETNAME} --private-network-ip=${IPADDRESS} --no-address >>$LOGFILE 2>&1
  write_log "Done. Return code:" $?
}

update_instance_group()
{
  gcloud compute instance-groups managed rolling-action start-update $MIGNAME \
    --version template=${MIGTEMPLATE} \
    --type=opportunistic \
    --zone $ZONE >>$LOGFILE 2>&1
  write_log "Done. Return code:" $?

  write_log "Updating instance group with new template..."
  gcloud beta compute instance-groups managed set-instance-template $MIGNAME \
    --template=${MIGTEMPLATE} --zone $ZONE >>$LOGFILE 2>&1
  write_log "Done. Return code:" $?

  write_log "Cleaning up old instance..."
  gcloud beta compute instances delete $VMNAME  --project=${PROJECTID}  --zone=${ZONE} --quiet >>$LOGFILE 2>&1
  write_log "Done. Return code:" $?

  write_log "Finalizing instance group..."
  gcloud compute --project $PROJECTID instance-groups managed create-instance $MIGNAME \
    --zone $ZONE --instance $VMNAME >>$LOGFILE 2>&1
  write_log "Done. Return code:" $?
  write_log "Refresh task completed successfully..."
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
