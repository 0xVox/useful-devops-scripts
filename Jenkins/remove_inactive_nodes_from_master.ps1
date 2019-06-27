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
    $jenkins_password,

    # Jenkins username
    [Parameter(Mandatory=$true)]
    [string]
    $jenkins_username
)

$ie = New-Object -ComObject 'internetExplorer.Application'
$ie.Visible = $true

$ie.Navigate($jenkins_url)
while ($ie.Busy -eq $true){Start-Sleep -seconds 1;}

# Define Login page buttons
$txt_username = $ie.Document.IHTMLDocument3_GetElementByID("j_username")
$txt_password = $ie.Document.IHTMLDocument3_GetElementByID("j_password")
$btn_login = $ie.Document.IHTMLDocument3_GetElementByID("submit")


# Exec login
$txt_username.Value = $jenkins_username
$txt_password.Value = $jenkins_password
$btn_login.click()

# Wait for login
while ($ie.Busy -eq $true){Start-Sleep -seconds 1;}

# Navigate to computers page
$ie.Navigate("$jenkins_url/computer")

# Wait for page load
while ($ie.Busy -eq $true){Start-Sleep -seconds 1;}

# Get table with computer names
$tbl_computers = $ie.Document.IHTMLDocument3_GetElementByID("computers")

# Declare dynamic array for storing computer names, for building URLs later.
$nodenames_offline = [System.Collections.ArrayList]::new()

foreach($row in $tbl_computers.IHTMLTable_rows)
{
    $splitHtml = $row.innerHTML -Split ' '



    if('data="computer-x.png"><img' -in $splitHtml)
    {
        # Add computer name
        $nodenames_offline.add($row.children[1].IHTMLElement_innerText)
    }
}

foreach($node in $nodenames_offline){
    $ie.Navigate("$jenkins_url/computer/$node/delete")

    while ($ie.Busy -eq $true){Start-Sleep -seconds 1;}

    $btn_delete = $ie.Document.IHTMLDocument3_GetElementByID("yui-gen4-button")
    $btn_delete.click()

    while($ie.Busy -eq $true){Start-Sleep -seconds 1;}
}

# Kill IE Session
$ie.Quit()

