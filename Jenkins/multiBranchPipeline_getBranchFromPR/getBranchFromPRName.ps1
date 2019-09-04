## getBranchFromPRname.ps1
## Description: When working with a Multibranch Pipeline in Jenkins that is triggered through Pull Requests,
##              the "GIT_BRANCH" environment variable becomes invalid if you need to access the actual branch name
##              the PR came from.

param(
    # Jenkins branch name (Of form, develop, master or PR-***)
    [Parameter(Mandatory=$true)]
    [string]
    $jenkinsBranchName
)

$apiUri = # REPLACE WITH YOUR BITBUCKET PULLREQUEST ENDPOINT
$headers = @{
    "Authorization" = "Basic **** REPLACE WITH BITBUCKET / GITHUB BASIC AUTH TOKEN";   ####
    "cache-control" = "no-cache";
}

if($jenkinsBranchName -Like "PR-*"){
    $pullrequests = [System.Collections.ArrayList]::New()

    # Get all active pull requests
    do{

        $pr_info = (Invoke-WebRequest -Uri $apiUri -Headers $headers -Method GET -UseBasicParsing).content
        $pr_info = ConvertFrom-JSON $pr_info
        foreach ($pr in $pr_info.values) {
            $pullrequests.Add($pr) > $null
        }

        # If API response has "Next page" value - then get it and add the next page of PRs to the object.
        if($pr_info.next.length){
            $apiUri = $pr_info.next
        } else {
            break
        }
    } while ($true)

    # Find corresponding pull request from ID
    # Cut off "PR-"
    $jenkinsPRid = $jenkinsBranchName.Substring(3, $jenkinsBranchName.length - 3)
    foreach($pr in $pullrequests){
        if($pr.id -eq $jenkinsPRid){
            $branch = $pr.source.branch.name
            return $branch
        }
    }

} else {
    return $jenkinsBranchName
}
