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
      'advanced_threat_protection',
      'analysis_services_server',
      'api_management',
      'api_management_api',
      'api_management_api_diagnostic',
      'api_management_api_operation',
      'api_management_api_operation_policy',
      'api_management_api_policy',
      'api_management_api_schema',
      'api_management_api_version_set',
      'api_management_authorization_server',
      'api_management_backend',
      'api_management_certificate',
      'api_management_custom_domain',
      'api_management_diagnostic',
      'api_management_email_template',
      'api_management_group',
      'api_management_group_user',
      'api_management_identity_provider_aad',
      'api_management_identity_provider_aadb2c',
      'api_management_identity_provider_facebook',
      'api_management_identity_provider_google',
      'api_management_identity_provider_microsoft',
      'api_management_identity_provider_twitter',
      'api_management_logger',
      'api_management_named_value',
      'api_management_openid_connect_provider',
      'api_management_policy',
      'api_management_product',
      'api_management_product_api',
      'api_management_product_group',
      'api_management_product_policy',
      'api_management_property',
      'api_management_subscription',
      'api_management_user',
      'application_gateway',
      'application_insights',
      'application_insights_analytics_item',
      'application_insights_api_key',
      'application_insights_smart_detection_rule',
      'application_insights_web_test',
      'application_security_group',
      'app_configuration',
      'app_service',
      'app_service_active_slot',
      'app_service_certificate',
      'app_service_certificate_binding',
      'app_service_certificate_order',
      'app_service_custom_hostname_binding',
      'app_service_environment',
      'app_service_environment_v3',
      'app_service_hybrid_connection',
      'app_service_managed_certificate',
      'app_service_plan',
      'app_service_slot',
      'app_service_slot_virtual_network_swift_connection',
      'app_service_source_control_token',
      'app_service_virtual_network_swift_connection',
      'attestation_provider',
      'automation_account',
      'automation_certificate',
      'automation_connection',
      'automation_connection_certificate',
      'automation_connection_classic_certificate',
      'automation_connection_service_principal',
      'automation_credential',
      'automation_dsc_configuration',
      'automation_dsc_nodeconfiguration',
      'automation_job_schedule',
      'automation_module',
      'automation_runbook',
      'automation_schedule',
      'automation_variable_bool',
      'automation_variable_datetime',
      'automation_variable_int',
      'automation_variable_string',
      'availability_set',
      'backup_container_storage_account',
      'backup_policy_file_share',
      'backup_policy_vm',
      'backup_protected_file_share',
      'backup_protected_vm',
      'bastion_host',
      'batch_account',
      'batch_application',
      'batch_certificate',
      'batch_pool',
      'blueprint_assignment',
      'bot_channels_registration',
      'bot_channel_directline',
      'bot_channel_email',
      'bot_channel_ms_teams',
      'bot_channel_slack',
      'bot_connection',
      'bot_web_app',
      'cdn_endpoint',
      'cdn_profile',
      'cognitive_account',
      'communication_service',
      'consumption_budget_resource_group',
      'consumption_budget_subscription',
      'container_group',
      'container_registry',
      'container_registry_scope_map',
      'container_registry_token',
      'container_registry_webhook',
      'cosmosdb_account',
      'cosmosdb_cassandra_keyspace',
      'cosmosdb_cassandra_table',
      'cosmosdb_gremlin_database',
      'cosmosdb_gremlin_graph',
      'cosmosdb_mongo_collection',
      'cosmosdb_mongo_database',
      'cosmosdb_notebook_workspace',
      'cosmosdb_sql_container',
      'cosmosdb_sql_database',
      'cosmosdb_sql_function',
      'cosmosdb_sql_stored_procedure',
      'cosmosdb_sql_trigger',
      'cosmosdb_table',
      'cost_management_export_resource_group',
      'custom_provider',
      'dashboard',
      'database_migration_project',
      'database_migration_service',
      'databox_edge_device',
      'databox_edge_order',
      'databricks_workspace',
      'data_factory',
      'data_factory_dataset_azure_blob',
      'data_factory_dataset_cosmosdb_sqlapi',
      'data_factory_dataset_delimited_text',
      'data_factory_dataset_http',
      'data_factory_dataset_json',
      'data_factory_dataset_mysql',
      'data_factory_dataset_parquet',
      'data_factory_dataset_postgresql',
      'data_factory_dataset_snowflake',
      'data_factory_dataset_sql_server_table',
      'data_factory_integration_runtime_azure',
      'data_factory_integration_runtime_azure_ssis',
      'data_factory_integration_runtime_managed',
      'data_factory_integration_runtime_self_hosted',
      'data_factory_linked_service_azure_blob_storage',
      'data_factory_linked_service_azure_databricks',
      'data_factory_linked_service_azure_file_storage',
      'data_factory_linked_service_azure_function',
      'data_factory_linked_service_azure_sql_database',
      'data_factory_linked_service_azure_table_storage',
      'data_factory_linked_service_cosmosdb',
      'data_factory_linked_service_data_lake_storage_gen2',
      'data_factory_linked_service_key_vault',
      'data_factory_linked_service_mysql',
      'data_factory_linked_service_postgresql',
      'data_factory_linked_service_sftp',
      'data_factory_linked_service_snowflake',
      'data_factory_linked_service_sql_server',
      'data_factory_linked_service_synapse',
      'data_factory_linked_service_web',
      'data_factory_pipeline',
      'data_factory_trigger_schedule',
      'data_lake_analytics_account',
      'data_lake_analytics_firewall_rule',
      'data_lake_store',
      'data_lake_store_file',
      'data_lake_store_firewall_rule',
      'data_lake_store_virtual_network_rule',
      'data_share',
      'data_share_account',
      'data_share_dataset_blob_storage',
      'data_share_dataset_data_lake_gen1',
      'data_share_dataset_data_lake_gen2',
      'data_share_dataset_kusto_cluster',
      'data_share_dataset_kusto_database',
      'dedicated_hardware_security_module',
      'dedicated_host',
      'dedicated_host_group',
      'devspace_controller',
      'dev_test_global_vm_shutdown_schedule',
      'dev_test_lab',
      'dev_test_linux_virtual_machine',
      'dev_test_policy',
      'dev_test_schedule',
      'dev_test_virtual_network',
      'dev_test_windows_virtual_machine',
      'digital_twins_endpoint_eventgrid',
      'digital_twins_endpoint_eventhub',
      'digital_twins_endpoint_servicebus',
      'digital_twins_instance',
      'disk_access',
      'disk_encryption_set',
      'dns_aaaa_record',
      'dns_a_record',
      'dns_caa_record',
      'dns_cname_record',
      'dns_mx_record',
      'dns_ns_record',
      'dns_ptr_record',
      'dns_srv_record',
      'dns_txt_record',
      'dns_zone',
      'eventgrid_domain',
      'eventgrid_domain_topic',
      'eventgrid_event_subscription',
      'eventgrid_system_topic',
      'eventgrid_system_topic_event_subscription',
      'eventgrid_topic',
      'eventhub',
      'eventhub_authorization_rule',
      'eventhub_cluster',
      'eventhub_consumer_group',
      'eventhub_namespace',
      'eventhub_namespace_authorization_rule',
      'eventhub_namespace_disaster_recovery_config',
      'express_route_circuit',
      'express_route_circuit_authorization',
      'express_route_circuit_peering',
      'express_route_gateway',
      'express_route_port',
      'firewall',
      'firewall_application_rule_collection',
      'firewall_nat_rule_collection',
      'firewall_network_rule_collection',
      'firewall_policy',
      'firewall_policy_rule_collection_group',
      'frontdoor',
      'frontdoor_custom_https_configuration',
      'frontdoor_firewall_policy',
      'function_app',
      'function_app_slot',
      'hdinsight_hadoop_cluster',
      'hdinsight_hbase_cluster',
      'hdinsight_interactive_query_cluster',
      'hdinsight_kafka_cluster',
      'hdinsight_ml_services_cluster',
      'hdinsight_rserver_cluster',
      'hdinsight_spark_cluster',
      'hdinsight_storm_cluster',
      'healthbot',
      'healthcare_service',
      'hpc_cache',
      'hpc_cache_access_policy',
      'hpc_cache_blob_target',
      'hpc_cache_nfs_target',
      'image',
      'integration_service_environment',
      'iotcentral_application',
      'iothub',
      'iothub_consumer_group',
      'iothub_dps',
      'iothub_dps_certificate',
      'iothub_dps_shared_access_policy',
      'iothub_endpoint_eventhub',
      'iothub_endpoint_servicebus_queue',
      'iothub_endpoint_servicebus_topic',
      'iothub_endpoint_storage_container',
      'iothub_enrichment',
      'iothub_fallback_route',
      'iothub_route',
      'iothub_shared_access_policy',
      'iot_security_device_group',
      'iot_security_solution',
      'iot_time_series_insights_access_policy',
      'iot_time_series_insights_event_source_iothub',
      'iot_time_series_insights_gen2_environment',
      'iot_time_series_insights_reference_data_set',
      'iot_time_series_insights_standard_environment',
      'ip_group',
      'key_vault',
      'key_vault_access_policy',
      'key_vault_certificate',
      'key_vault_certificate_issuer',
      'key_vault_key',
      'key_vault_managed_hardware_security_module',
      'key_vault_secret',
      'kubernetes_cluster',
      'kubernetes_cluster_node_pool',
      'kusto_attached_database_configuration',
      'kusto_cluster',
      'kusto_cluster_customer_managed_key',
      'kusto_cluster_principal_assignment',
      'kusto_database',
      'kusto_database_principal',
      'kusto_database_principal_assignment',
      'kusto_eventgrid_data_connection',
      'kusto_eventhub_data_connection',
      'kusto_iothub_data_connection',
      'lb',
      'lb_backend_address_pool',
      'lb_backend_address_pool_address',
      'lb_nat_pool',
      'lb_nat_rule',
      'lb_outbound_rule',
      'lb_probe',
      'lb_rule',
      'lighthouse_assignment',
      'lighthouse_definition',
      'linux_virtual_machine',
      'linux_virtual_machine_scale_set',
      'local_network_gateway',
      'logic_app_action_custom',
      'logic_app_action_http',
      'logic_app_integration_account',
      'logic_app_trigger_custom',
      'logic_app_trigger_http_request',
      'logic_app_trigger_recurrence',
      'logic_app_workflow',
      'log_analytics_cluster',
      'log_analytics_cluster_customer_managed_key',
      'log_analytics_datasource_windows_event',
      'log_analytics_datasource_windows_performance_counter',
      'log_analytics_data_export_rule',
      'log_analytics_linked_service',
      'log_analytics_linked_storage_account',
      'log_analytics_saved_search',
      'log_analytics_solution',
      'log_analytics_storage_insights',
      'log_analytics_workspace',
      'machine_learning_workspace',
      'maintenance_assignment_dedicated_host',
      'maintenance_assignment_virtual_machine',
      'maintenance_configuration',
      'managed_application',
      'managed_application_definition',
      'managed_disk',
      'management_group',
      'management_group_subscription_association',
      'management_group_template_deployment',
      'management_lock',
      'maps_account',
      'mariadb_configuration',
      'mariadb_database',
      'mariadb_firewall_rule',
      'mariadb_server',
      'mariadb_virtual_network_rule',
      'marketplace_agreement',
      'media_asset',
      'media_asset_filter',
      'media_content_key_policy',
      'media_job',
      'media_live_event',
      'media_live_event_output',
      'media_services_account',
      'media_streaming_endpoint',
      'media_streaming_locator',
      'media_streaming_policy',
      'media_transform',
      'monitor_aad_diagnostic_setting',
      'monitor_action_group',
      'monitor_action_rule_action_group',
      'monitor_action_rule_suppression',
      'monitor_activity_log_alert',
      'monitor_autoscale_setting',
      'monitor_diagnostic_setting',
      'monitor_log_profile',
      'monitor_metric_alert',
      'monitor_scheduled_query_rules_alert',
      'monitor_scheduled_query_rules_log',
      'monitor_smart_detector_alert_rule',
      'mssql_database',
      'mssql_database_extended_auditing_policy',
      'mssql_database_vulnerability_assessment_rule_baseline',
      'mssql_elasticpool',
      'mssql_firewall_rule',
      'mssql_job_agent',
      'mssql_job_credential',
      'mssql_server',
      'mssql_server_extended_auditing_policy',
      'mssql_server_security_alert_policy',
      'mssql_server_transparent_data_encryption',
      'mssql_server_vulnerability_assessment',
      'mssql_virtual_machine',
      'mssql_virtual_network_rule',
      'mysql_active_directory_administrator',
      'mysql_configuration',
      'mysql_database',
      'mysql_firewall_rule',
      'mysql_server',
      'mysql_server_key',
      'mysql_virtual_network_rule',
      'nat_gateway',
      'nat_gateway_public_ip_association',
      'netapp_account',
      'netapp_pool',
      'netapp_snapshot',
      'netapp_volume',
      'network_connection_monitor',
      'network_ddos_protection_plan',
      'network_interface',
      'network_interface_application_gateway_backend_address_pool_association',
      'network_interface_application_security_group_association',
      'network_interface_backend_address_pool_association',
      'network_interface_nat_rule_association',
      'network_interface_security_group_association',
      'network_packet_capture',
      'network_profile',
      'network_security_group',
      'network_security_rule',
      'network_watcher',
      'network_watcher_flow_log',
      'notification_hub',
      'notification_hub_authorization_rule',
      'notification_hub_namespace',
      'orchestrated_virtual_machine_scale_set',
      'packet_capture',
      'point_to_site_vpn_gateway',
      'policy_assignment',
      'policy_definition',
      'policy_remediation',
      'policy_set_definition',
      'postgresql_active_directory_administrator',
      'postgresql_configuration',
      'postgresql_database',
      'postgresql_firewall_rule',
      'postgresql_flexible_server',
      'postgresql_server',
      'postgresql_server_key',
      'postgresql_virtual_network_rule',
      'powerbi_embedded',
      'private_dns_aaaa_record',
      'private_dns_a_record',
      'private_dns_cname_record',
      'private_dns_mx_record',
      'private_dns_ptr_record',
      'private_dns_srv_record',
      'private_dns_txt_record',
      'private_dns_zone',
      'private_dns_zone_virtual_network_link',
      'private_endpoint',
      'private_link_service',
      'proximity_placement_group',
      'public_ip',
      'public_ip_prefix',
      'purview_account',
      'recovery_services_vault',
      'redis_cache',
      'redis_enterprise_cluster',
      'redis_enterprise_database',
      'redis_firewall_rule',
      'redis_linked_server',
      'relay_hybrid_connection',
      'relay_namespace',
      'resource_group',
      'resource_group_template_deployment',
      'resource_provider_registration',
      'role_assignment',
      'role_definition',
      'route',
      'route_filter',
      'route_table',
      'search_service',
      'security_center_assessment',
      'security_center_assessment_metadata',
      'security_center_assessment_policy',
      'security_center_automation',
      'security_center_auto_provisioning',
      'security_center_contact',
      'security_center_server_vulnerability_assessment',
      'security_center_setting',
      'security_center_subscription_pricing',
      'security_center_workspace',
      'sentinel_alert_rule_fusion',
      'sentinel_alert_rule_machine_learning_behavior_analytics',
      'sentinel_alert_rule_ms_security_incident',
      'sentinel_alert_rule_scheduled',
      'sentinel_data_connector_aws_cloud_trail',
      'sentinel_data_connector_azure_active_directory',
      'sentinel_data_connector_azure_advanced_threat_protection',
      'sentinel_data_connector_azure_security_center',
      'sentinel_data_connector_microsoft_cloud_app_security',
      'sentinel_data_connector_microsoft_defender_advanced_threat_protection',
      'sentinel_data_connector_office_365',
      'sentinel_data_connector_threat_intelligence',
      'servicebus_namespace',
      'servicebus_namespace_authorization_rule',
      'servicebus_namespace_disaster_recovery_config',
      'servicebus_namespace_network_rule_set',
      'servicebus_queue',
      'servicebus_queue_authorization_rule',
      'servicebus_subscription',
      'servicebus_subscription_rule',
      'servicebus_topic',
      'servicebus_topic_authorization_rule',
      'service_fabric_cluster',
      'service_fabric_mesh_application',
      'service_fabric_mesh_local_network',
      'service_fabric_mesh_secret',
      'service_fabric_mesh_secret_value',
      'shared_image',
      'shared_image_gallery',
      'shared_image_version',
      'signalr_service',
      'site_recovery_fabric',
      'site_recovery_network_mapping',
      'site_recovery_protection_container',
      'site_recovery_protection_container_mapping',
      'site_recovery_replicated_vm',
      'site_recovery_replication_policy',
      'snapshot',
      'spatial_anchors_account',
      'spring_cloud_active_deployment',
      'spring_cloud_app',
      'spring_cloud_app_cosmosdb_association',
      'spring_cloud_app_mysql_association',
      'spring_cloud_app_redis_association',
      'spring_cloud_certificate',
      'spring_cloud_custom_domain',
      'spring_cloud_java_deployment',
      'spring_cloud_service',
      'sql_active_directory_administrator',
      'sql_database',
      'sql_elasticpool',
      'sql_failover_group',
      'sql_firewall_rule',
      'sql_server',
      'sql_virtual_network_rule',
      'ssh_public_key',
      'stack_hci_cluster',
      'storage_account',
      'storage_account_customer_managed_key',
      'storage_account_network_rules',
      'storage_blob',
      'storage_blob_inventory_policy',
      'storage_container',
      'storage_data_lake_gen2_filesystem',
      'storage_data_lake_gen2_path',
      'storage_encryption_scope',
      'storage_management_policy',
      'storage_queue',
      'storage_share',
      'storage_share_directory',
      'storage_share_file',
      'storage_sync',
      'storage_sync_cloud_endpoint',
      'storage_sync_group',
      'storage_table',
      'storage_table_entity',
      'stream_analytics_function_javascript_udf',
      'stream_analytics_job',
      'stream_analytics_output_blob',
      'stream_analytics_output_eventhub',
      'stream_analytics_output_mssql',
      'stream_analytics_output_servicebus_queue',
      'stream_analytics_output_servicebus_topic',
      'stream_analytics_reference_input_blob',
      'stream_analytics_stream_input_blob',
      'stream_analytics_stream_input_eventhub',
      'stream_analytics_stream_input_iothub',
      'subnet',
      'subnet_nat_gateway_association',
      'subnet_network_security_group_association',
      'subnet_route_table_association',
      'subnet_service_endpoint_storage_policy',
      'subscription',
      'subscription_template_deployment',
      'synapse_firewall_rule',
      'synapse_managed_private_endpoint',
      'synapse_role_assignment',
      'synapse_spark_pool',
      'synapse_sql_pool',
      'synapse_workspace',
      'template_deployment',
      'tenant_template_deployment',
      'traffic_manager_endpoint',
      'traffic_manager_profile',
      'user_assigned_identity',
      'virtual_desktop_application_group',
      'virtual_desktop_host_pool',
      'virtual_desktop_workspace',
      'virtual_desktop_workspace_application_group_association',
      'virtual_hub',
      'virtual_hub_bgp_connection',
      'virtual_hub_connection',
      'virtual_hub_ip',
      'virtual_hub_route_table',
      'virtual_hub_security_partner_provider',
      'virtual_machine',
      'virtual_machine_configuration_policy_assignment',
      'virtual_machine_data_disk_attachment',
      'virtual_machine_extension',
      'virtual_machine_scale_set',
      'virtual_machine_scale_set_extension',
      'virtual_network',
      'virtual_network_gateway',
      'virtual_network_gateway_connection',
      'virtual_network_peering',
      'virtual_wan',
      'vmware_cluster',
      'vmware_private_cloud',
      'vpn_gateway',
      'vpn_gateway_connection',
      'vpn_server_configuration',
      'vpn_site',
      'web_application_firewall_policy',
      'windows_virtual_machine',
      'windows_virtual_machine_scale_set'
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
