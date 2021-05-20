<#
  .SYNOPSIS
     Powershell module to manage Terraform Cloud via its API
  .DESCRIPTION
     You must set environment variable TF_CLOUD_TOKEN as your Terraform Cloud API Token for authentication!
     Example: $Env:TF_CLOUD_TOKEN = 'xxxxxxxxxxxxxx.atlasv1.xxx...'
#>

if ($Env:TF_CLOUD_TOKEN) {
  $TF_CLOUD_TOKEN = $Env:TF_CLOUD_TOKEN | ConvertTo-SecureString -AsPlainText -Force
}

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

function Import-TerraformAzureState {
  <#
    .SYNOPSIS
        Imports terraform state from Azure
    .Description
        https://www.terraform.io/docs/cli/import/index.html
    .EXAMPLE
        Get-AzContainerRegistry | Select id | Import-TerraformAzureState -ResourceType container_registry
    .PARAMETER ResourceType
        Terraform resource type without azurerm_ prefix
    .PARAMETER ResourceId
        Azure resource id, accepts ValueFromPipeline
    .PARAMETER RemoveState
        Switch to remove the terraform.tfstate file in the end
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [validateSet(
      'advisor_recommendations',
      'api_management',
      'api_management_api',
      'api_management_api_version_set',
      'api_management_group',
      'api_management_product',
      'api_management_user',
      'app_configuration',
      'app_service',
      'app_service_certificate',
      'app_service_certificate_order',
      'app_service_environment',
      'app_service_environment_v3',
      'app_service_plan',
      'application_gateway',
      'application_insights',
      'application_security_group',
      'attestation_provider',
      'automation_account',
      'automation_variable_bool',
      'automation_variable_datetime',
      'automation_variable_int',
      'automation_variable_string',
      'availability_set',
      'backup_policy_vm',
      'batch_account',
      'batch_certificate',
      'batch_pool',
      'billing_enrollment_account_scope',
      'billing_mca_account_scope',
      'blueprint_definition',
      'blueprint_published_version',
      'cdn_profile',
      'client_config',
      'cognitive_account',
      'container_registry',
      'container_registry_scope_map',
      'container_registry_token',
      'cosmosdb_account',
      'data_factory',
      'data_lake_store',
      'data_share',
      'data_share_account',
      'data_share_dataset_blob_storage',
      'data_share_dataset_data_lake_gen1',
      'data_share_dataset_data_lake_gen2',
      'data_share_dataset_kusto_cluster',
      'data_share_dataset_kusto_database',
      'database_migration_project',
      'database_migration_service',
      'databricks_workspace',
      'dedicated_host',
      'dedicated_host_group',
      'dev_test_lab',
      'dev_test_virtual_network',
      'digital_twins_instance',
      'disk_access',
      'disk_encryption_set',
      'dns_zone',
      'eventgrid_domain_topic',
      'eventgrid_topic',
      'eventhub',
      'eventhub_authorization_rule',
      'eventhub_consumer_group',
      'eventhub_namespace',
      'eventhub_namespace_authorization_rule',
      'express_route_circuit',
      'firewall',
      'firewall_policy',
      'function_app',
      'function_app_host_keys',
      'hdinsight_cluster',
      'healthcare_service',
      'image',
      'images',
      'iothub',
      'iothub_dps',
      'iothub_dps_shared_access_policy',
      'iothub_shared_access_policy',
      'ip_group',
      'key_vault',
      'key_vault_access_policy',
      'key_vault_certificate',
      'key_vault_certificate_data',
      'key_vault_certificate_issuer',
      'key_vault_key',
      'key_vault_managed_hardware_security_module',
      'key_vault_secret',
      'kubernetes_cluster',
      'kubernetes_cluster_node_pool',
      'kubernetes_service_versions',
      'kusto_cluster',
      'lb',
      'lb_backend_address_pool',
      'lb_rule',
      'log_analytics_workspace',
      'logic_app_integration_account',
      'logic_app_workflow',
      'machine_learning_workspace',
      'maintenance_configuration',
      'managed_application_definition',
      'managed_disk',
      'management_group',
      'maps_account',
      'mariadb_server',
      'monitor_action_group',
      'monitor_diagnostic_categories',
      'monitor_log_profile',
      'monitor_scheduled_query_rules_alert',
      'monitor_scheduled_query_rules_log',
      'mssql_database',
      'mssql_elasticpool',
      'mssql_server',
      'mysql_server',
      'nat_gateway',
      'netapp_account',
      'netapp_pool',
      'netapp_snapshot',
      'netapp_volume',
      'network_ddos_protection_plan',
      'network_interface',
      'network_security_group',
      'network_service_tags',
      'network_watcher',
      'notification_hub',
      'notification_hub_namespace',
      'platform_image',
      'policy_definition',
      'policy_set_definition',
      'postgresql_flexible_server',
      'postgresql_server',
      'private_dns_zone',
      'private_endpoint_connection',
      'private_link_service',
      'private_link_service_endpoint_connections',
      'proximity_placement_group',
      'public_ip',
      'public_ip_prefix',
      'public_ips',
      'recovery_services_vault',
      'redis_cache',
      'resource_group',
      'resources',
      'role_definition',
      'route_filter',
      'route_table',
      'search_service',
      'sentinel_alert_rule',
      'sentinel_alert_rule_template',
      'servicebus_namespace',
      'servicebus_namespace_authorization_rule',
      'servicebus_namespace_disaster_recovery_config',
      'servicebus_queue',
      'servicebus_queue_authorization_rule',
      'servicebus_subscription',
      'servicebus_topic',
      'servicebus_topic_authorization_rule',
      'shared_image',
      'shared_image_gallery',
      'shared_image_version',
      'shared_image_versions',
      'signalr_service',
      'snapshot',
      'spring_cloud_app',
      'spring_cloud_service',
      'sql_database',
      'sql_server',
      'ssh_public_key',
      'storage_account',
      'storage_account_blob_container_sas',
      'storage_account_sas',
      'storage_blob',
      'storage_container',
      'storage_encryption_scope',
      'storage_management_policy',
      'storage_sync',
      'storage_sync_group',
      'storage_table_entity',
      'stream_analytics_job',
      'subnet',
      'subscription',
      'subscriptions',
      'synapse_workspace',
      'template_spec_version',
      'traffic_manager_geographical_location',
      'traffic_manager_profile',
      'user_assigned_identity',
      'virtual_hub',
      'virtual_machine',
      'virtual_machine_scale_set',
      'virtual_network',
      'virtual_network_gateway',
      'virtual_network_gateway_connection',
      'virtual_wan',
      'vmware_private_cloud',
      'web_application_firewall_policy',
      'windows_virtual_machine',
      'linux_virtual_machine'
    )
    ]
    [string]$ResourceType,

    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('id')]
    [string]$ResourceId,

    [switch]$Show,
    [switch]$RemoveState
  )

  begin {

  }
  process {
    $id = $ResourceId.Replace('/', '_')

    $tempFileName = "$id-$ResourceType-temp.tf"
    $outFileName = "$id-$ResourceType-out.txt"
    $resourceName = 'temp_resource'

    $content = @"
provider "azurerm" {
  features {}
}

resource "azurerm_$ResourceType" "$resourceName" {}
"@

    Remove-Item $tempFileName -ErrorAction SilentlyContinue
    Remove-Item $outFileName -ErrorAction SilentlyContinue

    New-Item -Name $tempFileName -Force

    $content | Set-Content -Path $tempFileName

    terraform init
    terraform import "azurerm_$ResourceType.$resourceName" "$ResourceId"

    if ($Show.IsPresent) {
      terraform show -no-color
    }

    New-Item -Name $outFileName -Force
    terraform show -no-color | Set-Content -Path $outFileName

    Remove-Item $tempFileName -ErrorAction SilentlyContinue

    if ($RemoveState.IsPresent) {
      Remove-Item 'terraform.tfstate' -ErrorAction SilentlyContinue
    }
  }

}
