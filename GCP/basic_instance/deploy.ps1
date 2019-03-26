# Deploy.ps1 - Will deploy the gcp instance using the given terraform. 
# Remember to add the location to your terraform service account key file.
# Terraform assumes a bucket with the name *yourproject*-terraform. You can change
# this in the backend.tf file.
# Once provisioned, this script will automatically start an SSH session into your 
# new instance. 

param(
    [switch]$destroy,
    [switch]$nossh
)

$env:GOOGLE_APPLICATION_CREDENTIALS = "YOUR TF SERVICE ACCOUNT KEY LOCATION"
$project = "YOUR PROJECT NAME"

terraform init --force-copy

$my_ip = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

# Configure variables
"ssh_ip = ""$my_ip"""   | Set-Content .\terraform.tfvars
"project = ""$project"""| Add-Content .\terraform.tfvars
"key-location = ""$env:GOOGLE_APPLICATION_CREDENTIALS""" | Add-Content .\terraform.tfvars

if($destroy.IsPresent){
    terraform destroy --auto-approve
} else {
    terraform apply --auto-approve

    $instance_id = (terraform output instance_id)

    if(!$nossh.IsPresent){
        Write-Output "Waiting 30secs for SSHD to start on instance"
        Start-SLeep -s 30
        Write-Output "Connecting via SSH"
        gcloud compute ssh $instance_id
    }
}