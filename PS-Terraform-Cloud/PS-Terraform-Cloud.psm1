<#
  .SYNOPSIS
     Powershell module to manage Terraform Cloud via its API
  .DESCRIPTION
     You must set environment variable TF_CLOUD_TOKEN as your Terraform Cloud API Token for authentication!
     Example: $Env:TF_CLOUD_TOKEN = 'xxxxxxxxxxxxxx.atlasv1.xxx...'
#>

$TF_CLOUD_TOKEN = $Env:TF_CLOUD_TOKEN | ConvertTo-SecureString -AsPlainText -Force
$TF_CLOUD_ROOT_API_URL = 'https://app.terraform.io/api/v2'
$TF_CLOUD_CONTENT_TYPE = 'application/vnd.api+json'

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
    [alias('hcl')]
    [bool[]]$IsHCLVariable = $false,

    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [alias('sensitive')]
    [bool[]]$IsSensitive = $false
  )

  Process {
    [WorkspaceVariable]::new($Key, $Value, $Description, $Category, $IsHCLVariable, $IsSensitive )
  }
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
        The Name of the Terraform Cloud Organization, defaults to env var TF_CLOUD_ORGANIZATION
    .PARAMETER Email
        Admin email address that will manage this organization
  #>
  [CmdletBinding()]
  param (
    [Parameter()]
    [string]$Name = $env:TF_CLOUD_ORGANIZATION,

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
        The Name of the Terraform Cloud Organization, defaults to env var TF_CLOUD_ORGANIZATION
    .PARAMETER OAuthTokenId
        The VCS Connection (OAuth Connection + Token) to use. This ID can be obtained by the Get-TerraformCloudOAuthToken cmdlet.
    .PARAMETER VCSIdentifier
        A reference to your VCS repository in the format :org/:repo where :org and :repo refer to the organization and repository in your VCS provider. The format for Azure DevOps is :org/:project/_git/:repo.
        If you don't pass this param it assumes that you have set env vars DEVOPS_ORGANIZATION and DEVOPS_PROJECT
    .PARAMETER WorkingDirectory
        A relative path that Terraform will execute within. Default is /src
    .PARAMETER GlobalRemoteState
        Whether the workspace should allow all workspaces in the organization to access its state data during runs. If false, then only specifically approved workspaces can access its state.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$OAuthTokenId,

    [Parameter()]
    [string]$OrganizationName = $env:TF_CLOUD_ORGANIZATION,

    [Parameter()]
    [string]$VCSIdentifier = "$($Env:DEVOPS_ORGANIZATION)/$($Env:DEVOPS_PROJECT)/_git/$Name",

    [Parameter()]
    [string]$WorkingDirectory = '/src',

    [Parameter()]
    [bool]$GlobalRemoteState = $true
  )

  process {
    $url = "$TF_CLOUD_ROOT_API_URL/organizations/$OrganizationName/workspaces"

    $body = @{
      data = @{
        type       = "workspaces"
        attributes = @{
          "name"                = $Name
          "global-remote-state" = $GlobalRemoteState
          "working-directory"   = $WorkingDirectory
          "vcs-repo"            = @{
            "identifier"     = $VCSIdentifier
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
    .PARAMETER Name
        Provide a Terraform Workspace Name if yo want get single workspace id
    .PARAMETER OrganizationName
        The Name of the Terraform Cloud Organization, defaults to env var TF_CLOUD_ORGANIZATION
  #>
  [CmdletBinding()]
  param (
    [Parameter()]
    [string]$Name,

    [Parameter()]
    [string]$OrganizationName = $env:TF_CLOUD_ORGANIZATION
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

function Remove-TerraformCloudWorkspace {
  <#
    .SYNOPSIS
        Remove-TerraformCloudWorkspace
    .Description
        https://www.terraform.io/docs/cloud/api/workspaces.html#delete-a-workspace
    .EXAMPLE
        $WorkspaceIds | Remove-TerraformCloudWorkspace
    .PARAMETER WorkspaceId
        Terraform Cloud Workspace Id(s)
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [alias('id')]
    [string[]]$WorkspaceId
  )

  process {
    $url = "$TF_CLOUD_ROOT_API_URL/workspaces/$WorkspaceId"
    Invoke-RestMethod -Uri $url -Method Delete -Token $TF_CLOUD_TOKEN -Authentication Bearer
  }

}

function New-TerraformCloudWorkspaceVariable {
  <#
    .SYNOPSIS
        Create new Terraform Cloud Workspace variable(s)
    .Description
        https://www.terraform.io/docs/cloud/api/workspace-variables.html#create-a-variable
    .EXAMPLE
        $WorkspaceVariables | New-TerraformCloudWorkspaceVariable -WorkspaceId $WorkspaceId
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

    Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType $TF_CLOUD_CONTENT_TYPE -Token $TF_CLOUD_TOKEN -Authentication Bearer | Select-Object -ExpandProperty data
  }
}

function Update-TerraformCloudWorkspaceVariable {
  <#
    .SYNOPSIS
        Update Terraform Cloud Workspace variable
    .Description
        https://www.terraform.io/docs/cloud/api/workspace-variables.html#update-variables
    .EXAMPLE
        $WorkspaceVariable | Update-TerraformCloudWorkspaceVariable -WorkspaceId $WorkspaceId -VariableId $VariableId
    .PARAMETER WorkspaceId
        Terraform Cloud Workspace Id
    .PARAMETER VariableId
        Terraform Cloud Workspace Variable Id
    .PARAMETER WorkspaceVariable
        Terraform Cloud Workspace object
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$WorkspaceId,

    [Parameter(Mandatory)]
    [string]$VariableId,

    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [WorkspaceVariable[]]$WorkspaceVariable
  )

  process {
    $url = "$TF_CLOUD_ROOT_API_URL/workspaces/$WorkspaceId/vars/$VariableId"

    $body = @{
      data = @{
        id         = $VariableId
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

    Invoke-RestMethod -Uri $url -Method Patch -Body $body -ContentType $TF_CLOUD_CONTENT_TYPE -Token $TF_CLOUD_TOKEN -Authentication Bearer | select-Object -ExpandProperty data
  }
}

function Get-TerraformCloudWorkspaceVariable {
  <#
    .SYNOPSIS
        Get Terraform Cloud Workspace variable(s)
    .Description
        https://www.terraform.io/docs/cloud/api/workspace-variables.html#list-variables
    .EXAMPLE
        Get-TerraformCloudWorkspaceVariable -WorkspaceId $WorkspaceId
    .PARAMETER WorkspaceId
        Terraform Cloud Workspace Id
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [alias('id')]
    [string[]]$WorkspaceId
  )

  process {
    $url = "$TF_CLOUD_ROOT_API_URL/workspaces/$WorkspaceId/vars"

    Invoke-RestMethod -Uri $url -Token $TF_CLOUD_TOKEN -Authentication Bearer | select-Object -ExpandProperty data
  }
}

function Remove-TerraformCloudWorkspaceVariable {
  <#
    .SYNOPSIS
        Delete Terraform Cloud Workspace variable
    .Description
        https://www.terraform.io/docs/cloud/api/workspace-variables.html#delete-variables
    .EXAMPLE
        $WorkspaceVariables | Remove-TerraformCloudWorkspaceVariable -WorkspaceId $WorkspaceId
    .PARAMETER WorkspaceId
        Terraform Cloud Workspace Id
    .PARAMETER VariableId
        Terraform Cloud Workspace Variable Id
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$WorkspaceId,

    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [alias('id')]
    [string[]]$VariableId
  )

  process {
    $url = "$TF_CLOUD_ROOT_API_URL/workspaces/$WorkspaceId/vars/$VariableId"

    Invoke-RestMethod -Uri $url -Method Delete -Token $TF_CLOUD_TOKEN -Authentication Bearer
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
    .PARAMETER OrganizationName
        The Name of the Terraform Cloud Organization, defaults to env var TF_CLOUD_ORGANIZATION
  #>
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [alias('name')]
    [string]$OrganizationName = $env:TF_CLOUD_ORGANIZATION
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
