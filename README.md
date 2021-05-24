# Terraform Cloud Powershell Module

[![Publish](https://github.com/Satak/ps-terraform-cloud/actions/workflows/publish.yml/badge.svg)](https://github.com/Satak/ps-terraform-cloud/actions/workflows/publish.yml)
[![PS Gallery][psgallery-badge-dt]][powershell-gallery]
[![PS Gallery][psgallery-badge-v]][powershell-gallery]

![Terraform logo](https://raw.githubusercontent.com/Satak/ps-terraform-cloud/master/icon/terraform-cloud-192.png 'Terraform logo')

Powershell module `PS-Terraform-Cloud` to manage Terraform Cloud via Powershell/API

| Version | Info                             | Date (DD.MM.YYYY) |
| ------- | -------------------------------- | ----------------- |
| 0.0.6   | Add all resource types           | 20.05.2021        |
| 0.0.5   | Add `Import-TerraformAzureState` | 20.05.2021        |
| 0.0.3   | Add more commands                | 04.05.2021        |
| 0.0.2   | Init release                     | 03.05.2021        |

## Install

You can install this module from the Powershell Gallery:

```powershell
Install-Module -Name PS-Terraform-Cloud -Force -Confirm:$False
```

## Authentication

If you want to use this module for Terraform Cloud you need to create a personal or teams API token in Terraform Cloud and add that token as an environment variable `TF_CLOUD_TOKEN`. Manually in Powershell setting environment variables is done like this:

```powershell
$Env:TF_CLOUD_TOKEN = 'xxxxxxxxxxxxxx.atlasv1.xxx...'
```

Documentation how to create user token in Terraform Cloud:

<https://www.terraform.io/docs/cloud/users-teams-organizations/users.html#api-tokens>

## Azure DevOps

This module can also use your Azure DevOps **organization** and **project** names from environment variables so you don't need to pass the `VCSIdentifier` variable to `New-TerraformCloudWorkspace` cmdlet:

- `DEVOPS_ORGANIZATION`
- `DEVOPS_PROJECT`

## Terraform Cloud Organization Env Var

You can set `TF_CLOUD_ORGANIZATION` env var (`$Env:TF_CLOUD_ORGANIZATION = 'my-tf-cloud-org'`) so you don't have to explicitly pass Terraform Cloud Organization name to cmdlets.

## `Import-TerraformAzureState`

Cmdlet to import any Azure resource as Terraform state and `.tf` template file.

### Usage

```powershell
Get-AzVirtualNetwork | Import-TerraformAzureState -ResourceType virtual_network -RemoveState -Show
```

### Resource Types

List all resource types from Azure provider:

```powershell
(terraform providers schema -json | ConvertFrom-Json).provider_schemas.'registry.terraform.io/hashicorp/azurerm'.resource_schemas | gm -MemberType NoteProperty | select -ExpandProperty name | % {"'$($_.substring(8))',"} | clip
```

[powershell-gallery]: https://www.powershellgallery.com/packages/PS-Terraform-Cloud/
[psgallery-badge-dt]: https://img.shields.io/powershellgallery/dt/PS-Terraform-Cloud.svg
[psgallery-badge-v]: https://img.shields.io/powershellgallery/v/PS-Terraform-Cloud.svg
