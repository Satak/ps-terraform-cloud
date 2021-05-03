<#
You must set environment variable TF_CLOUD_TOKEN as your Terraform Cloud API Token for authentication!
Example: $Env:TF_CLOUD_TOKEN = 'xxxxxxxxxxxxxx.atlasv1.xxx...'
#>

$TF_CLOUD_TOKEN = $Env:TF_CLOUD_TOKEN | ConvertTo-SecureString -AsPlainText -Force
$TF_CLOUD_ROOT_API_URL = 'https://app.terraform.io/api/v2'
$TF_CLOUD_CONTENT_TYPE = 'application/vnd.api+json'

$DEVOPS_ORGANIZATION = $Env:DEVOPS_ORGANIZATION
$DEVOPS_PROJECT = $Env:DEVOPS_PROJECT

class WorkspaceVariable {
  [string]$Key
  [string]$Value
  [string]$Description
  [string]$Category
  [bool]$IsHCLVariable
  [bool]$IsSensitive

  WorkspaceVariable(
    [string]$Key,
    [string]$Value,
    [string]$Description,
    [string]$Category,
    [bool]$IsHCLVariable,
    [bool]$IsSensitive
  ) {
    $this.Key = $Key
    $this.Value = $Value
    $this.Description = $Description
    $this.Category = $Category
    $this.IsHCLVariable = $IsHCLVariable
    $this.IsSensitive = $IsSensitive
  }
}

function New-WorkspaceVariable {
  <#
    .SYNOPSIS
        Create WorkspaceVariable object by using WorkspaceVariable Class
    .EXAMPLE
        New-WorkspaceVariable -Key 'myKey' -Value 'myValue'
    .PARAMETER Key
        Key/Name of the variable
    .PARAMETER Value
        Value for the variable
    .PARAMETER Description
        Optional description of the variable
    .PARAMETER Category
        Variable category, can be either 'terraform' or 'env'
    .PARAMETER IsHCLVariable
        Is variable value HCL (complex data types)
    .PARAMETER IsSensitive
        Is the variable sensitive (tokens, passwords, etc.)
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$Key,

    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$Value = '',

    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$Description = '',

    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateSet('terraform', 'env')]
    [string[]]$Category = 'terraform',

    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [bool[]]$IsHCLVariable = $false,

    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [bool[]]$IsSensitive = $false
  )
  Begin {}
  Process {
    [WorkspaceVariable]::new($Key, $Value, $Description, $Category, $IsHCLVariable, $IsSensitive )
  }
  End {}
}

function New-TerraformCloudOrganization {
  <#
    .SYNOPSIS
        Create new Terraform Cloud Organization
    .Description
        https://www.terraform.io/docs/cloud/api/organizations.html
    .EXAMPLE
        New-TerraformCloudOrganization -Name MyOrgName -Email name@domain.com
    .PARAMETER Name
        The Name of the Terraform Cloud Organization
    .PARAMETER Email
        Admin email address that will manage this organization
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$Email
  )

  $url = "$TF_CLOUD_ROOT_API_URL/organizations"

  $body = @{
    data = @{
      type       = "organizations"
      attributes = @{
        name  = $Name
        email = $Email
      }
    }
  } | ConvertTo-Json

  Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType $TF_CLOUD_CONTENT_TYPE -Token $TF_CLOUD_TOKEN -Authentication Bearer
}

function New-TerraformCloudWorkspace {
  <#
    .SYNOPSIS
        Create new Terraform Cloud Workspace
    .Description
        https://www.terraform.io/docs/cloud/api/workspaces.html
    .EXAMPLE
        New-TerraformCloudWorkspace -Name MyWorkspace -OrganizationName MyOrganization -OAuthTokenId xxx
    .PARAMETER Name
        The name of the workspace, which can only include letters, numbers, -, and _. This will be used as an identifier and must be unique in the organization.
    .PARAMETER OrganizationName
        The Name of the Terraform Cloud Organization
    .PARAMETER OAuthTokenId
        The VCS Connection (OAuth Connection + Token) to use. This ID can be obtained by the Get-TerraformCloudOAuthToken cmdlet.
    .PARAMETER VCSIdentifier
        A reference to your VCS repository in the format :org/:repo where :org and :repo refer to the organization and repository in your VCS provider. The format for Azure DevOps is :org/:project/_git/:repo.
        If you don't pass this param it assumes that you have set env vars DEVOPS_ORGANIZATION and DEVOPS_PROJECT
    .PARAMETER WorkingDirectory
        A relative path that Terraform will execute within. Default is /src
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$OrganizationName,

    [Parameter(Mandatory)]
    [string]$OAuthTokenId,

    [Parameter()]
    [string]$VCSIdentifier,

    [Parameter()]
    [string]$WorkingDirectory = '/src'
  )

  process {
    $url = "$TF_CLOUD_ROOT_API_URL/organizations/$OrganizationName/workspaces"
    $_identifier = $VCSIdentifier ? $VCSIdentifier : "$DEVOPS_ORGANIZATION/$DEVOPS_PROJECT/_git/$Name"

    $body = @{
      data = @{
        type       = "workspaces"
        attributes = @{
          "name"              = $Name
          "working-directory" = $WorkingDirectory
          "vcs-repo"          = @{
            "identifier"     = $_identifier
            "oauth-token-id" = $OAuthTokenId
          }
        }
      }
    } | ConvertTo-Json -Depth 5

    Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType $TF_CLOUD_CONTENT_TYPE -Token $TF_CLOUD_TOKEN -Authentication Bearer | Select-Object -ExpandProperty data
  }
}

function Get-TerraformCloudWorkspace {
  <#
    .SYNOPSIS
        Get Terraform Cloud Workspace(s)
    .Description
        https://www.terraform.io/docs/cloud/api/workspaces.html
    .EXAMPLE
        Get-TerraformCloudWorkspace -OrganizationName MyOrganization
    .PARAMETER OrganizationName
        The Name of the Terraform Cloud Organization
    .PARAMETER Name
        Provide a Terraform Workspace Name if yo want get single workspace id
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$OrganizationName,

    [Parameter()]
    [string]$Name
  )

  $url = "$TF_CLOUD_ROOT_API_URL/organizations/$OrganizationName/workspaces"

  $workspaces = Invoke-RestMethod -Uri $url -Token $TF_CLOUD_TOKEN -Authentication Bearer | select-Object -ExpandProperty data

  if ($Name) {
    $workspaces | where-Object { $_.attributes.name -eq $Name } | Select-Object -ExpandProperty id
  }
  else {
    $workspaces
  }
}

function New-TerraformCloudWorkspaceVariable {
  <#
    .SYNOPSIS
        Create new Terraform Cloud Workspace variable(s)
    .Description
        https://www.terraform.io/docs/cloud/api/workspace-variables.html
    .EXAMPLE
        $WorkspaceVariables | New-TerraformCloudWorkspaceVariable -WorkspaceId xxxx
    .PARAMETER WorkspaceId
        Terraform Cloud Workspace Id
    .PARAMETER WorkspaceVariable
        Terraform Cloud Workspace object
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$WorkspaceId,

    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [WorkspaceVariable[]]$WorkspaceVariable
  )

  process {
    $url = "$TF_CLOUD_ROOT_API_URL/workspaces/$WorkspaceId/vars"

    $body = @{
      data = @{
        type       = "vars"
        attributes = @{
          key         = $WorkspaceVariable.Key
          value       = $WorkspaceVariable.Value
          description = $WorkspaceVariable.Description
          category    = $WorkspaceVariable.Category
          hcl         = $WorkspaceVariable.IsHCLVariable
          sensitive   = $WorkspaceVariable.IsSensitive
        }
      }
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType $TF_CLOUD_CONTENT_TYPE -Token $TF_CLOUD_TOKEN -Authentication Bearer
  }
}

function Get-TerraformCloudOAuthClient {
  <#
    .SYNOPSIS
        List Terraform Cloud OAuth Clients from Organization
    .Description
        https://www.terraform.io/docs/cloud/api/oauth-clients.html
    .EXAMPLE
        Get-TerraformCloudOAuthToken -Name MyOrganization
    .PARAMETER Name
        The Name of the Terraform Cloud Organization
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [alias('name')]
    [string]$OrganizationName
  )
  process {
    $url = "$TF_CLOUD_ROOT_API_URL/organizations/$OrganizationName/oauth-clients"
    Invoke-RestMethod -Uri $url -Token $TF_CLOUD_TOKEN -Authentication Bearer | select-Object -ExpandProperty data
  }
}

function Get-TerraformCloudOAuthToken {
  <#
    .SYNOPSIS
        List Terraform Cloud OAuth Tokens from Organization
    .Description
        https://www.terraform.io/docs/cloud/api/oauth-tokens.html
    .EXAMPLE
        Get-TerraformCloudOAuthToken -OAuthClientId xxx
    .PARAMETER OAuthClientId
        OAuth Client Id from Organization
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [alias('id')]
    [string]$OAuthClientId
  )
  process {
    $url = "$TF_CLOUD_ROOT_API_URL/oauth-clients/$OAuthClientId/oauth-tokens"
    Invoke-RestMethod -Uri $url -Token $TF_CLOUD_TOKEN -Authentication Bearer | select-Object -ExpandProperty data
  }
}