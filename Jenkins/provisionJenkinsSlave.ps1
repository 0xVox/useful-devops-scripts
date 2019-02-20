# Author: 0xVox
# Provision Jenkins Slave
# A script for provisioning a Jenkins slave with a master node.
$ErrorActionPreference = "Stop"

$agentJar = "C:\Agents\agent.jar"
$cliJar = "C:\Agents\jenkins-cli.jar"

param (
    [Parameter(Mandatory=$true)][string]$buildNumber,          # Jenkins build number.
    [Parameter(Mandatory=$true)][string]$user,                 # Jenkins service account.
    [Parameter(Mandatory=$true)][string]$apiKey,               # Jenkins API Key.
    [Parameter(Mandatory=$true)][string]$remoteFS,             # Jenkins workspace on the slave machine.
    [Parameter(Mandatory=$true)][string]$workDir,              # Jenkins working directory on slave machine.
    [Parameter(Mandatory=$true)][string]$masterUrl,            # Master node URL. Please include the https / http prefix.
    [Parameter(Mandatory=$true)][string]$masterIp,             # Master node IP address.
    [Parameter(Mandatory=$true)][string]$projectName,          # Name of your project.
    [Parameter(Mandatory=$false)][boolean]$jarsFromS3=$false,  # If set to true, get .jar files from S3. $jarsLocation then refers to S3 key of folder.
                                                               # The .jar files are expected to be agent.jar and jenkins-cli.jar
    [Parameter(Mandatory=$true)][string]$jarsLocation,         # URL Of folder to find jenkins jars, OR the S3 key.
    [Parameter(Mandatory=$false)][string]$jarsS3Bucket,        # Bucket of where to find the .jar files.
    [Parameter(Mandatory=$false)][string]$jarsAWSRegion        # AWS Region of bucket
)

# Runs the jenkins agent as a scheduled task in this case
function RunScriptAsScheduledTask {
    Param(
        [Parameter(Mandatory=$true)][string]$taskName,
        [Parameter(Mandatory=$true)][string]$script
    )
    # Setup Scheduled Task
    $taskAction = New-ScheduledTaskAction "PowerShell.exe" -Argument ('-executionpolicy Bypass -NonInteractive -Command '+$script)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
    Register-ScheduledTask $taskName -Description $taskName -Action $taskAction -Principal $principal
    Start-ScheduledTask -TaskName $taskName
    do{
        Start-Sleep -s 1
        $state = Get-ScheduledTask -TaskName $taskName | Select-Object State
    }
    while($state.State -ne 'Ready')
}

# Gets the .jar files (Into C:\Agents)
function GetAgentFiles {
    if($jarsFromS3){
        Copy-S3Object -KeyPrefix $jarsLocation -LocalFolder c:\Agents -BucketName $jarsS3Bucket -Region $jarsAWSRegion
    } else {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile("$jarsLocation/jenkins-cli.jar", $cliJar)
        $webClient.DownloadFile("$jarsLocation/agent.jar", $agentJar)
    }
}

## Check parameter validity and perform required manipulations.

if($jarsFromS3 -eq $true -and [string]::IsNullOrEmpty($jarsBucket)){
    throw "If getting .jar files from S3 you must specify the -jarsBucket parameter."
}

if(!($masterUrl -Like "http://*" -or $masterUrl -Like "https://*")){
    throw "Please include https / http prefix in the masterUrl parameter."
} else {
    $masterUrlHostsFormat = $masterUrl.Split("://")[1]
    $hostsFileEntry = "`n$masterIp  $masterUrlHostsFormat"
}

## Execution
# Add master node to hosts file (In case of private networks)
$hostsFileEntry | Add-Content "C:\Windows\System32\drivers\etc\hosts"
$auth = $user + ":" + $apiKey
$nodeName = $((Get-WmiObject win32_computersystem).DNSHostName)
$label = "$projectName-$buildNumber"

GetAgentFiles

# Create node on master
$stdin = @"
<?xml version="1.0" encoding="UTF-8"?>
<slave>
  <name>$nodeName</name>
  <description>$projectName</description>
  <remoteFS>$remoteFS</remoteFS>
  <numExecutors>1</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy`$Always"/>
  <launcher class="hudson.slaves.JNLPLauncher">
    <workDirSettings>
      <disabled>false</disabled>
      <workDirPath>$workDir</workDirPath>
      <internalDir>remoting</internalDir>
      <failIfWorkDirIsMissing>false</failIfWorkDirIsMissing>
    </workDirSettings>
  </launcher>
  <label>$label</label>
  <nodeProperties/>
</slave>
"@

# Create node on Master
try{
    $stdin | java -jar $cliJar -s $masterUrl -auth $auth create-node $nodeName
}
catch{
    throw "Failed! Does the node already exist?"
}

# Connect node to master #
# Get secret
$webClient = new-object System.Net.WebClient
$webClient.Headers.Add("Authorization","Basic "+
    [System.Convert]::ToBase64String(
        [System.Text.Encoding]::ASCII.GetBytes("$($user):$apiKey")
    )
)
$outputFile = "C:\Agents\slave-agent.jnlp"
$url = "$masterUrl/computer/$nodeName/slave-agent.jnlp"
$webClient.DownloadFile($url, $outputFile)
$Xpath = '/jnlp/application-desc/argument[1]'
$secret = $(Select-Xml -Content $(Get-Content $outputFile) -XPath $Xpath | Select-Object -ExpandProperty Node).'#text'
Write-Output "The secret is: $secret"

# Run agent
$cmd = "-jar $agentJar -jnlpUrl $masterUrl/computer/$nodeName/slave-agent.jnlp -secret $secret -workDir $workDir"
RunScriptAsScheduledTask "JenkinsSlave" "C:\BuildScripts\RunAgent.ps1 -cmd {$cmd}"

# Test agent connection
Start-Sleep 10
$timeout = Get-Date
Get-Content C:\stderr-slave.txt -Wait -Tail 20 | % {
    Write-Output $_
    if($_ -Like "INFO: Connected"){
        Write-Output "Connection Succesfull!"
        exit 0
    } elseif ((New-Timespan -Start $timeout -End (Get-Date)).Minutes -gt 5){
        Write-Output "5 minute timeout reached, no connection"
        exit 1
    } else {
        Start-Sleep -s 1
    }
}

