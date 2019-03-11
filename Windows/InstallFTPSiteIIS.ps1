## Install FTP Server
## Author: Thomas Brew
## OG Ticket: SRE-7

# Parameter help description
param(
    [Parameter(Mandatory=$true)][string]$FTPUsername,
    [Parameter(Mandatory=$true)][string]$FTPPassword,
    [Parameter(Mandatory=$false)][string]$FTPPort = 21,
    [Parameter(Mandatory=$false)][string]$FTPSiteId = 1,
    [Parameter(Mandatory=$false)][string]$FTPRootDir = 'C:\ftp',
    [Parameter(Mandatory=$false)][string]$FTPSiteName = 'test_ftp'
)

# Install required modules
Write-Output "Installing FTP Modules"
Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature
Install-WindowsFeature Web-Server -IncludeAllSubFeature -IncludeManagementTools
Import-Module WebAdministration

mkdir $FTPRootDir

New-WebFtpSite -Name $FTPSiteName -Port $FTPPort -PhysicalPath $FTPRootDir -ID $FTPSiteId

Write-Output "Setting up windows FTP User and group"
# Create the local Windows group
$FTPUserGroupName = "FTP Users"
$ADSI = [ADSI]"WinNT://$env:ComputerName"
$FTPUserGroup = $ADSI.Create("Group", "$FTPUserGroupName")
$FTPUserGroup.SetInfo()
$FTPUserGroup.Description = "Members of this group can connect through FTP"
$FTPUserGroup.SetInfo()

# Create an FTP user
$CreateUserFTPUser = $ADSI.Create("User", "$FTPUserName")
$CreateUserFTPUser.SetInfo()
$CreateUserFTPUser.SetPassword("$FTPPassword")
$CreateUserFTPUser.SetInfo()

# Add the FTP user and current user to the group FTP Users
Write-Output ([string]::Format("Adding user {0} to FTP Users group", $FTPUserName))

$UserAccount = New-Object System.Security.Principal.NTAccount("$FTPUserName")
$SID = $UserAccount.Translate([System.Security.Principal.SecurityIdentifier])
$Group = [ADSI]"WinNT://$env:ComputerName/$FTPUserGroupName,Group"
$User = [ADSI]"WinNT://$SID"
$Group.Add($User.Path)


Write-Output "Enabling basic authentication on FTP site"
# Enable basic authentication on the FTP site
$FTPSitePath = "IIS:\Sites\$FTPSiteName"
$BasicAuth = 'ftpServer.security.authentication.basicAuthentication.enabled'
Set-ItemProperty -Path $FTPSitePath -Name $BasicAuth -Value $True

# Add an authorization read rule for FTP Users.
$Param = @{
    Filter   = "/system.ftpServer/security/authorization"
    Value    = @{
        accessType  = "Allow"
        roles       = "$FTPUserGroupName"
        permissions = "Read, Write"
    }
    PSPath   = 'IIS:\'
    Location = $FTPSiteName
}
Add-WebConfiguration @Param

Write-Output "Enabling SSL connections to the FTP site"
# Allow SSL Connections
$SSLPolicy = @(
    'ftpServer.security.ssl.controlChannelPolicy',
    'ftpServer.security.ssl.dataChannelPolicy'
)
Set-ItemProperty -Path $FTPSitePath -Name $SSLPolicy[0] -Value $false
Set-ItemProperty -Path $FTPSitePath -Name $SSLPolicy[1] -Value $false

# Allow FTP Group access to root folder
$UserAccount = New-Object System.Security.Principal.NTAccount("$FTPUserGroupName")
$AccessRule = [System.Security.AccessControl.FileSystemAccessRule]::new($UserAccount,
    'FullControl',
    'ContainerInherit,ObjectInherit',
    'None',
    'Allow'
)
$ACL = Get-Acl -Path $FTPRootDir
$ACL.SetAccessRule($AccessRule)
$ACL | Set-Acl -Path $FTPRootDir

Write-Output "Restarting FTP site for config changes to take effect"
# Restart FTP Site for changes to take effect
Restart-WebItem "IIS:\Sites\$FTPSiteName" -Verbose

Write-Output "FTP Site install complete"
