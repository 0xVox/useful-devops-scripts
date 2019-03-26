# GCP Basic Instance Provisioning
This is a simple terraform / powershell combo to launch an f1-micro instance in GCP and open an SSH session into it.
Things you need to do:
- Get a GCP account and set up API access and a terraform service account for your project
- Update the vars in deploy.ps1 with your key location and project name
- Run deploy.ps1