<#
Script name: connect-vmc-nsx-vcenter.ps1
Last update: 27 Sep 2021
Author: Eric Gray, @eric_gray
Description: Quickly log in to VMC, NSX-T, and optionally vCenter Server
#>

#Requires -Modules VMware.VimAutomation.Vmc, VMware.VMC.NSXT

param ($SddcName=$false,
        $RefreshToken=$false,
        [switch]$IncludeVCenterConnect=$false)


$defaultEnvToken = $env:TOKEN


# if token not passed as a param, see if the default env var exists
if(-not $RefreshToken -and -not $defaultEnvToken) {
    Write-Host -ForegroundColor Red "No -RefreshToken param passed and no API token in default env var!"
    exit 1
} elseif (-not $RefreshToken) {
    $RefreshToken = $defaultEnvToken
} 


Write-Host -ForegroundColor Green "Connecting to VMC..."
Connect-Vmc -RefreshToken $refreshToken 

if (-not $global:DefaultVmcServers ) { 
    Write-Host -ForegroundColor Red "Not connected to VMware Cloud - check for a valid refresh token"
    exit 1
} 

$orgName = Get-VmcOrganization

if(!$SddcName) {
    $allSddcs = Get-VmcSddc
    if($allSddcs.Count -eq 1) {  # if org has more than one SDDC, need to specify
        Write-Host -ForegroundColor Blue "Found one SDDC: $allSddcs"
        $SddcName = $allSddcs.Name
    } else {
        Write-Host -ForegroundColor Blue "Found SDDCs: $allSddcs"
        Write-Host -ForegroundColor Red "Could not determine default SDDC, please specifiy with parameter -SddcName."
        exit 1
    }
}

Write-Host -ForegroundColor Green "Connecting to NSX-T proxy..."
Connect-NSXTProxy -RefreshToken $refreshToken -OrgName $orgName -SDDCName $SddcName

if($IncludeVCenterConnect.isPresent) {
    Write-Host -ForegroundColor Green "Connecting to vCenter Server using credentials from SDDC object..." 
    $sddc = Get-VmcSddc -Name $SddcName
    Connect-VIServer -Server $sddc.VCenterHostName -Credential $sddc.VCenterCredentials
} else {
    Write-Host -ForegroundColor Blue "Not attempting to connect to vCenter Server. Use -IncludeVCenterConnect switch to connect using stored credentials." 
    
}
