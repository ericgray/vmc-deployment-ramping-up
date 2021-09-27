<#
Script name: deploy-ubuntu-cloudimg.ps1 
Last update: 27 Sep 2021
Author: Eric Gray, @eric_gray
Description: Quickly deploy Ubuntu cloudimg OVA file to VMware Cloud on AWS

Requires VPN to SDDC management network - must be able to connect to the private IP of a host

Import-VApp requires a local file, not a URL. Download latest OVA here:

Invoke-WebRequest -Uri https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.ova -OutFile focal-server-cloudimg-amd64.ova

The Ubuntu images include a default 'ubuntu' user account and during deployment you can provide
your SSH public key and/or a one-time password that must be changed on first login. If the password
parameter is used, then the password must be changed on first login - even when connecting via SSH key.

Note that the Ubuntu image is configured to NOT allow password authentication over SSH, so the password
option is primarily for logging into the VM console directly.  Edit /etc/ssh/sshd_config to change this.

This configuration change may resolve certificate errors:
Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore

Based on sample code from: 
https://code.vmware.com/samples/4489/using-import-vapp-to-upload-ova-or-ovf-to-vmware-cloud-on-aws

#>

#Requires -Modules VMware.VimAutomation.Vmc

param (
    [Parameter(Mandatory)]$OVA,
    [Parameter(Mandatory)]$VMName,
    $Network = "sddc-cgw-network-1",  # default network segment name
    $SSHkey = "~/.ssh/id_rsa.pub",  # this is a sensible default
    $OneTimePassword = $false
    )

function statusMessage {
    param($message)

    Write-Host -ForegroundColor Green "$(Get-Date -DisplayHint time) $message"
}

try {
    if ($null -eq $global:DefaultVIServers ) { 
        throw "Not connected to vCenter Server"
    } else {
        Write-Host "Connected to $global:DefaultVIServers"
    }
}

catch {
    Write-Host -ForegroundColor Red "Not connected. OVA deployment requires vCenter Server connection"
    # $Error[0]
    exit 1
}

if (-Not (Test-Path $OVA -PathType Leaf)) {
    Write-Host -ForegroundColor Red "OVA not found."
    exit 1
}


$datastore = Get-Datastore -Name "WorkloadDatastore"
$vmHost = Get-Cluster -Name "Cluster-1" | Get-VMHost | Select-Object -First 1
$location = Get-ResourcePool -Name "Compute-ResourcePool"
$folder = Get-Folder -Name "Workloads"
$ovaConfig = Get-OvfConfiguration -Ovf $ova
$networkName = ($ovaConfig.NetworkMapping | Get-Member -MemberType CodeProperty).Name
$ovaConfig.NetworkMapping.$networkName.Value = $Network
$ovaConfig.Common.hostname.Value = $VMName

# If this is set, then user must change password on first connect - even if using ssh key
if ($OneTimePassword) { $ovaConfig.Common.password.Value = $OneTimePassword }

if ($SSHkey) { 
    if (Test-Path $SSHkey -PathType Leaf) {
        $ovaConfig.Common.public_keys.Value = Get-Content $SSHkey -First 1
    } else {
        Write-Host -ForegroundColor Red "SSH key $SSHkey not found."
        exit 1
    }
}

statusMessage "Starting import"
    
Import-VApp -OvfConfiguration $ovaConfig -Source $ova -Name $VMName -VMHost $vmHost `
 -Datastore $datastore -DiskStorageFormat thin -Location $location -InventoryLocation $folder

statusMessage "Finished import, powering on VM"

Get-VM $VMName | Start-VM | Wait-Tools 

do {
    Start-Sleep -Seconds 5
    $guestIp = Get-VM $VMName | Get-VMGuest | Select-Object IPaddress
    } until ($guestIp.IPAddress)

statusMessage "VM name: $VMName | IP: $($guestIp.IPAddress[0])"

if ($SSHkey) {
    Write-Host -ForegroundColor Blue "If firewall rules permit access, log in with: ssh ubuntu@$($guestIp.IPAddress[0])"
} else {
    Write-Host -ForegroundColor Blue "SSH key was not provided, log into the VM console (not ssh) with the one-time password."
}
