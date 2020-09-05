
#gcloud beta compute instance-groups managed delete jpmig1 --zone=us-east4-c --quiet

gcloud beta compute instance-templates create jpmigvm01-template-1 \
  --image-project=jp-poc-260114 --image=jp-mig-image1 \
  --machine-type=n1-standard-1 --maintenance-policy=migrate \
  --service-account=jpmigvm01-compute@jp-poc-260114.iam.gserviceaccount.com \
  --tags=backend,vpcinternal \
  --disk name=data-disk-1,auto-delete=no,device-name=data-disk-1,mode=rw \
  --disk name=data-disk-2,auto-delete=no,device-name=data-disk-2,mode=rw \
  --restart-on-failure \
  --region=us-east4 \
  --network=projects/jpsharedvpc/global/networks/default --subnet=projects/jpsharedvpc/regions/us-east4/subnetworks/default --private-network-ip=10.150.0.2 --no-address

gcloud beta compute instance-groups managed create jpmigvm01-mig \
    --stateful-disk auto-delete=never,device-name=data-disk-1 \
    --stateful-disk auto-delete=never,device-name=data-disk-2 \
    --size 0 --health-check=jpmig-healthcheck \
    --template jpmigvm01-template-1 \
    --zone=us-east4-c 

gcloud compute instance-groups managed rolling-action start-update jpmigvm01-mig \
        --version=template=jpmigvm01-template-1 \
        --type=opportunistic \
        --replacement-method=recreate --max-surge=0 \
        --zone=us-east4-c 

gcloud compute instance-groups managed create-instance jpmigvm01-mig \
     --instance=jpmigvm01 --zone=us-east4-c

