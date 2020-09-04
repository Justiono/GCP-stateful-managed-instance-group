# GCP Stateful Managed Instance Group

This is a sample script to periodically refresh a stateful managed instance group (MIG) with a new template and a new boot image from the current VM.
The refresh-mig.bash script will:
- Create a new image
- Create a new template and use the new image in it
- Update the existing MIG with the new template
- Recreate the MIG instance

A simple workflow using Cloud Build and Cloud Scheduler can be used to automate this job.
The cloudbuild.yaml file is a sample of Cloud Build configuration.
