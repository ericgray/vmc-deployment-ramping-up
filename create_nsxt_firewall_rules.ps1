<#
Script name: create_nsxt_firewall_rules.ps1
Last update: 1 Sep 2020
Author: Eric Gray, @eric_gray
Description: Essential NSX-T CGW and MGW firewall rules to enable managing a new VMware Cloud on AWS SDDC 
#>

#Requires -Modules VMware.VimAutomation.Vmc, VMware.VMC.NSXT

$myIp = Invoke-RestMethod -Uri https://api.ipify.org

$cgwGroups = @()
$cgwGroups += @{Name = "Admin"; IPAddress = $myIp }
$cgwGroups += @{Name = "VPC"; IPAddress = @("10.100.0.0/21") }
$cgwGroups += @{Name = "Compute"; IPAddress = @("192.168.1.0/24","192.168.2.0/24") }

# By default, the MGW and CGW configuration is the same, sync them:
$mgwGroups = @() + $cgwGroups

# Create additional MGW or CGW rules as needed, here:
# $cgwGroups += @{Name = "X"; IPAddress = @("172.21.0.0/16") } 
# $mgwGroups += @{Name = "Y"; IPAddress = @("172.22.0.0/16") } 

$cgwRules = @()
$cgwRules += @{Name = "Admin to Compute" ; SourceGroup = @("Admin"); DestinationGroup = @("Compute"); Service = "ANY"; }
$cgwRules += @{Name = "Compute to Any" ; SourceGroup = @("Compute"); DestinationGroup = @("Any"); Service = "ANY"; }
$cgwRules += @{Name = "VPC to Compute" ; SourceGroup = @("VPC"); DestinationGroup = @("Compute"); Service = "ANY"; }

$mgwRules = @()
$mgwRules += @{Name = "To vCenter" ; SourceGroup = @("Admin","VPC","Compute"); DestinationGroup = @("vCenter"); Service = @("HTTPS","ICMP ALL") }
$mgwRules += @{Name = "To ESXi" ; SourceGroup = @("Admin","VPC","Compute"); DestinationGroup = @("ESXi"); Service = @("HTTPS","ICMP ALL") }
# MGW services are: HTTPS, ICMP ALL, VMware VMotion, Provisioning & Remote Console

# End of configurable section

Function Add-Groups {
    param(
        [Parameter(Mandatory)]$GatewayType,
        [Parameter(Mandatory)]$GroupList
        )

    foreach ($group in $GroupList) {
        write-output "Working on group: $($group.Name)"
        if(Get-NSXTGroup -GatewayType $GatewayType -Name $group.Name) {
            Write-Output "Group with name exists, skipping"
            continue
        }
        New-NSXTGroup -GatewayType $GatewayType -Name $group.Name -IPAddress $group.IPAddress
    }
}

Function Add-Rules {
    param(
        [Parameter(Mandatory)]$GatewayType,
        [Parameter(Mandatory)]$RuleList
        )

    Write-Host -ForegroundColor Green "Adding $($GatewayType) rules"

    $ruleSeq = 0
    foreach ($rule in $RuleList) {
        Write-Output "Working on rule: $($rule.Name)"
        if(Get-NSXTFirewall -GatewayType $GatewayType -Name $rule.Name) {
            Write-Output "Rule with name exists, skipping"
            continue
        }
        New-NSXTFirewall -GatewayType $GatewayType -Name $rule.Name -SourceGroup $rule.SourceGroup -DestinationGroup $rule.DestinationGroup -Service $rule.Service `
        -Logged $true -SequenceNumber ($ruleSeq++) -Action ALLOW

    }
}

Add-Groups -GatewayType CGW $cgwGroups
Add-Groups -GatewayType MGW $mgwGroups
Add-Rules -GatewayType CGW $cgwRules
Add-Rules -GatewayType MGW $mgwRules
