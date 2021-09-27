<#
Script name: create-sddc.ps1
Last update: 27 Sep 2021
Author: Eric Gray, @eric_gray
Description: Deploy an SDDC in a single availability zone or across 2 AZs (Stretched Cluster)

Reference: https://code.vmware.com/docs/11794/cmdlet-reference/doc/New-VmcSddc.html

If list of two subnets are provided, a Stretched Cluster will be deployed. For example:
./create-sddc.ps1 -AwsAccountId 4235223422451 -AwsSubnetId ("subnet-0dfdgvsaeddw3","subnet-0jhe3hdkghsed") -HostCount 4 

#>

#Requires -Modules VMware.VimAutomation.Vmc

param ([string]$SddcName = "SDDC1",
    [parameter(mandatory)][string]$AwsAccountId,
    [parameter(mandatory)][string[]]$AwsSubnetId,
    [string]$SddcCidr = "10.2.0.0/16",
    [string]$AwsRegion = "US_WEST_2",
    [int]$HostCount = 1,
    [switch]$WhatIf = $false)


# make sure there is an active connection to VMware Cloud on AWS
try { Get-VmcOrganization } catch { $Error[0].ToString(); exit 1 }

$awsAcct = Get-AwsAccount | Where-Object AccountNumber -eq $AwsAccountId

$awsSubnetList = Get-AwsVpcSubnet -AwsAccount $awsAcct -Region $AwsRegion | 
    Where-Object { $_.Id -In $AwsSubnetId }

# if 2 subnets are specified, stretched cluster will require even number of hosts
if($awsSubnetList.Count -eq 2){ $stretched = $true } else { $stretched = $false }
if($stretched -and $HostCount % 2) { Write-Host -ForegroundColor Red "Stretched cluster must have even number of hosts"; exit 1 }

$sddcDeployTask = New-VmcSddc -Name $sddcName -Region $awsRegion -HostCount $HostCount -AwsAccount $awsAcct `
    -AwsVpcSubnet $awsSubnetList -ManagementSubnetCidr $sddcCidr -StretchedCluster:$stretched -RunAsync -WhatIf:$WhatIf

Wait-Task -Task $sddcDeployTask
