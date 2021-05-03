# $Env:TF_CLOUD_TOKEN is set by env
$Env:DEVOPS_ORGANIZATION = 'MY-ORG'
$Env:DEVOPS_PROJECT = 'My-Project'

$organizationName = 'my-organization'
$workspaceName = 'my-workspace'
$varsFile = '.\variables.json'

# import terraform cloud powershell module
import-module (Join-Path (Split-Path -Parent $PSScriptRoot) 'PS-Terraform-Cloud')

# get oauth token from existing terraform organization
$OAuthTokenId = $organizationName | Get-TerraformCloudOAuthClient | Get-TerraformCloudOAuthToken | Select-Object -ExpandProperty id

# create terraform cloud workspace
$workspaceId = New-TerraformCloudWorkspace -Name $workspaceName -OrganizationName $organizationName -OAuthTokenId $OAuthTokenId | Select-Object -ExpandProperty id

# create terraform cloud vars to workspace
Get-Content $varsFile | ConvertFrom-Json | New-WorkspaceVariable | New-TerraformCloudWorkspaceVariable -WorkspaceId $workspaceId | Out-Null
