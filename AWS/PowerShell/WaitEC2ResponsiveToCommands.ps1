# Author: 0xVox
# Wait for an EC2 instance to be responsive to commands sent to it.
# This was created as a result of Terraform often failing due to not 
# being aware of whether the instance was truly ready to execute.


param(
    [Parameter(Mandatory=$true)][string]$instanceid,
    # Assumes a credentials file is present on the executing machine
    # In my case it was a Jenkins build server
    [Parameter(Mandatory=$true)][string]$awsprofile
)

#################
### Execution ###
#################

Initialize-AWSDefaults -ProfileName $awsprofile -region eu-west-1

while($(Get-Ec2Instance -InstanceId $instanceid).Instances.State.Name.Value -ne 'running'){
    Write-Output "Waiting for instance to start"
    Start-Sleep -s 15
}
while(!$(Invoke-SSMCommand {$env:COMPUTERNAME} -InstanceId $instanceid -ErrorAction SilentlyContinue)){
    Write-Output "Waiting for instance to accept SSM Commands"
    Start-Sleep -s 15
}

Write-Output "Instance accepts commands!"