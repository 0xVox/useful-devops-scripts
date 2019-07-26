## Author: 0xVox
## Remove any nodes from jenkins that are marked as inactive.
## Basically, you've done a lot of debugging and forgot to unprovision your nodes. Kill them all!

param(
    # Jenkins URL
    [Parameter(Mandatory=$true)]
    [string]
    $jenkins_url,

    # Jenkins password
    [Parameter(Mandatory=$true)]
    [string]
    $api_token,

    # Jenkins username
    [Parameter(Mandatory=$true)]
    [string]
    $api_user
)

$global:api_token = $api_token
$global:api_user = $api_user
$global:CRUMB_URL = "$jenkins_url/crumbIssuer/api/json"

# Return headers with a valid crumb for the request
function getCrumbedHeaders() {

    $headers = $null
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Basic "+
        [System.Convert]::ToBase64String(
            [System.Text.Encoding]::ASCII.GetBytes(
                "$($global:api_user):$global:api_token"
            )
        )
    )

    $crumbContent = ConvertFrom-JSON (Invoke-WebRequest -UseBasicParsing $global:CRUMB_URL -Method GET -Headers $headers).content
    $headers.Add($crumbContent.crumbRequestField, $crumbContent.crumb)
    $headers.Add("Accept", "application/json")

    return $headers
}



$API_APPEND = "api/json"
$COMPUTERS_INFO_URL = "$jenkins_url/computer"
$COMPUTERS_INFO_API = "$COMPUTERS_INFO_URL/$API_APPEND"

$headers = getCrumbedHeaders
$computers_info = ConvertFrom-Json (Invoke-WebRequest -UseBasicParsing $COMPUTERS_INFO_API -Method GET -Headers $headers -ContentType "application/json").content

$offline_nodes = [System.Collections.ArrayList]::New()

foreach($comp in $computers_info.computer) {
    if($comp.offline -eq "true") {
        $offline_nodes.Add($comp)
    }
}

$count = 0
foreach ($node in $offline_nodes) {
    $delete_url = "$COMPUTERS_INFO_URL/$($node.displayName)/doDelete/api/json"
    $headers = getCrumbedHeaders
    Invoke-WebRequest -UseBasicParsing $delete_url -Method POST -Headers $headers -ContentType "application/json"
    $count += 1
}

Write-Output "Removed $count nodes"