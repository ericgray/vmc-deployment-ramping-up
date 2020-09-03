<#
Script name: create_sddc_prod.ps1
Last update: 1 Sep 2020
Author: Eric Gray, @eric_gray
Description: Deploy example SDDC in DevOps org

Reference: https://code.vmware.com/docs/11794/cmdlet-reference/doc/New-VmcSddc.html
#>

#Requires -Modules VMware.VimAutomation.Vmc


$refreshToken = $env:TOKEN_DEVOPS

$sddcName = "PROD03"
$sddcCidr = "10.5.0.0/16"
$awsRegion = "US_WEST_2"
$awsSubnetId = "subnet-029cdbfe9f1a3c9d3" # AZ us-west-2a 10.100.4.0/24

Connect-VmcServer -ApiToken $refreshToken

$awsAcct = Get-AwsAccount
$subnet = Get-AwsVpcSubnet -AwsAccount $awsAcct -Region $awsRegion | ? { $_.Id -eq $awsSubnetId }
$sddcDeployTask = New-VmcSddc -Name $sddcName -Region $awsRegion -HostCount 1 -AwsAccount $awsAcct `
    -AwsVpcSubnet $subnet -ManagementSubnetCidr $sddcCidr -RunAsync

Wait-Task -Task $sddcDeployTask

