# $Env:TF_CLOUD_TOKEN is set in VSCode envs or other runtime
$Env:DEVOPS_ORGANIZATION = 'MY-ORG'
$Env:DEVOPS_PROJECT = 'My-Project'
$Env:TF_CLOUD_ORGANIZATION = 'my-tf-cloud-org'

$workspaceName = 'my-workspace'
$varsFile = '.\variables.json'

# import terraform cloud powershell module
# import-module '../PS-Terraform-Cloud' -Force
import-module (Join-Path (Split-Path -Parent $PSScriptRoot) 'PS-Terraform-Cloud') -Force

# get oauth token from existing terraform organization
$OAuthTokenId = Get-TerraformCloudOAuthClient | Get-TerraformCloudOAuthToken | Select-Object -ExpandProperty id

# get terraform cloud workspace by name
$workspaceId = Get-TerraformCloudWorkspace -Name $workspaceName

# create terraform cloud workspace if not found by name
if (!$workspaceId) {
  $workspaceId = New-TerraformCloudWorkspace -Name $workspaceName -OAuthTokenId $OAuthTokenId | Select-Object -ExpandProperty id
}

# create terraform cloud vars to workspace
Get-Content $varsFile | ConvertFrom-Json | New-WorkspaceVariable | New-TerraformCloudWorkspaceVariable -WorkspaceId $workspaceId | Out-Null
