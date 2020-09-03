<#
Script name: deploy_photon_ovf_vmc.ps1 
Last update: 1 Sep 2020
Author: Eric Gray, @eric_gray
Description: Quickly deploy a Photon OS OVA or OVF file to VMware Cloud on AWS

Requires VPN to SDDC management network - must be able to connect to the private IP of a host

Obtain the PowerCLI connection information from the VMware Cloud console under the "Settings" tab 

Based on sample code from: 
https://code.vmware.com/samples/4489/using-import-vapp-to-upload-ova-or-ovf-to-vmware-cloud-on-aws
#>

#Requires -Modules VMware.VimAutomation.Vmc


#$ova = "~/Downloads/photon-hw13_uefi-3.0-a383732.ova"
$ova = "~/Downloads/management01/management01.ovf"
$vmName = "management01"
$network = "sddc-cgw-network-1"

$datastore = Get-Datastore -Name "WorkloadDatastore"
$vmHost = Get-Cluster -Name "Cluster-1" | Get-VMHost | Select-Object -First 1
$location = Get-ResourcePool -Name "Compute-ResourcePool"
$folder = Get-Folder -Name "Workloads"
$ovaConfig = Get-OvfConfiguration -Ovf $ova
$ovaConfig.NetworkMapping.sddc_cgw_network_1.Value = $network

Import-VApp -OvfConfiguration $ovaConfig -Source $ova -Name $vmName -VMHost $vmHost `
 -Datastore $datastore -DiskStorageFormat thin -Location $location -InventoryLocation $folder

Get-VM $vmName | Start-VM | Wait-Tools 

do {
    Start-Sleep -Seconds 5
    $guestIp = Get-VM $vmName | Get-VMGuest | Select-Object IPaddress
    } until ($guestIp.IPAddress)

Write-Host -ForegroundColor Green "VM: $vmName has IP: $($guestIp.IPAddress[0])"

