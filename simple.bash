#!/bin/bash
TEMPLATENAME=`gcloud beta compute instance-groups managed list  --filter="zone~us-east4-c AND name~jpmigvm01" --format="value(instanceTemplate)"`
CURRVER="${TEMPLATENAME: -1}"
echo $TEMPLATENAME
echo $CURRVER
gcloud compute instances stop jpaddc02 --zone=northamerica-northeast1-c
