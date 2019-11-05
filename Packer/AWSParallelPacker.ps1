# Run packer in parallel across multiple regions and split their output to seperate log files.
param(
    # regions to deploy to
    [string[]]
    $regions = @("eu-west-1", "eu-west-2", "us-east-1", "ap-southeast-2"),

    # script to execute
    [Parameter(Mandatory=$true)]
    [string]
    $packer_script,

    # Debug
    # If enabled, dont run as job, only run one instance
    [switch]
    $debug
)

$regions | % {
    Remove-Item ".\$_.log" -Force -ErrorAction SilentlyContinue
}

$path = Convert-Path $PSScriptRoot
$scriptBlock = {
    param (
        [Parameter(Mandatory=$true)][string]$region,
        [Parameter(Mandatory=$true)][string]$packer_script,
        [Parameter(Mandatory=$true)][string]$path
    )
    
    cd $path
    Push-Location $path
    packer build -var region=""$region"" $packer_script
}

$jobs = @()
$regions | ForEach-Object {
    $jobs += New-Object PSObject -Property @{
        Job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $_, $packer_script, $path
        Region = $_
    }
}

$num_jobs = $jobs.length
$exclude = @()
$break = $false
Write-Output "Number of jobs : $num_jobs"

if(!$debug.IsPresent){
    try{
        $i = 0
        do{
            $i++
            $job_i = $i % $num_jobs
            $job = $jobs[$job_i]
            if($exclude.length -eq $jobs.length){break} # All jobs have finished
            if($job_i -notin $exclude){
                $cmdOut = Receive-Job $job.Job | Tee-Object -FilePath "$($job.Region).log" -Append
                if($cmdOut.length -gt 0){
                    # This code splits lines where Receive-Job has gathered multiple lines in one fetch, and formats them correctly.
                    $log_line_split = $cmdOut -Split 'amazon-ebs:',3,'SimpleMatch'
                    $log_line_split[0] = "$($log_line_split[0]) amazon-ebs:"
                    if($log_line_split.length -gt 2){
                        $log_line_split[2] = $log_line_split[2] -Replace 'amazon-ebs:',"`n$($job.Region): amazon-ebs:"
                    }
                    Write-Output "$($job.Region): $log_line_split"
                }
                if($job.Job.State -ne "Running"){
                    Write-Output "$($job.Region) $($job.Job.State)!"
                    if($job_i -notin $exclude){
                        $exclude += $job_i
                    }
                }
            }
        } while ($true)
    } catch {
        Write-Output "Error occurred reading processes"
    } finally {
        Get-Job | Stop-Job
    }
}
else 
{
    $region = "eu-west-1"
    packer build -debug -var region=""$region"" .\cm.server.json
}

