<#
Script name: easy_connect_vmc_nsx.ps1
Last update: 1 Sep 2020
Author: Eric Gray, @eric_gray
Description: Dot-source this script to quickly log in to VMC and NSX

1) Store your VMware Cloud API Token in an environment variable to avoid exposing
it on the command line or inside scripts

2) Load this script into your current PowerCLI session using > . ./easy_connect_vmc_nsx.ps1

3) If above succeeds, run other scripts and commands against your environment
#>

#Requires -Modules VMware.VimAutomation.Vmc, VMware.VMC.NSXT

$refreshToken = $env:TOKEN_DEVOPS
$sddcName = "PROD03"

if(!$refreshToken) { Write-Host -ForegroundColor Red "No API token in env var!"; exit 1}

Write-Host -ForegroundColor Green "Connecting to VMC..."
Connect-Vmc -RefreshToken $refreshToken 
$orgName = Get-VmcOrganization

Write-Host -ForegroundColor Green "Connecting to NSX-T proxy..."
Connect-NSXTProxy -RefreshToken $refreshToken -OrgName $orgName -SDDCName $sddcName

