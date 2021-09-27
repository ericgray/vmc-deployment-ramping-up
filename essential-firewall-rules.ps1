<#
Script name: essential-firewall-rules.ps1
Last update: 27 Sep 2021
Author: Eric Gray, @eric_gray
Description: Essential NSX-T CGW and MGW firewall rules to enable managing a new VMware Cloud on AWS SDDC 

Use optional -Cleanup switch to delete (undo) all rules and groups defined in this script.

The top portion of this script must be edited to match your unique network requirements.

#>

#Requires -Modules VMware.VimAutomation.Vmc, VMware.VMC.NSXT

param ([switch]$Cleanup=$false)

$myIp = Invoke-RestMethod -Uri https://api.ipify.org
$ipOct = $myIp.split(".")
$adminGroupName = "Admin (x.x.{0}.{1})" -f $ipOct[2], $ipOct[3]

$vpcGroupName = "VPC (10.100/21)"
$vpcCidrs = @("10.100.0.0/21")

$computeGroupName = "Compute seg (192.168.1 + .2)"
$computeCidrs = @("192.168.1.0/24","192.168.2.0/24")

$cgwGroups = @()
$cgwGroups += @{Name = $adminGroupName; IPAddress = $myIp }
$cgwGroups += @{Name = $vpcGroupName; IPAddress = $vpcCidrs }
$cgwGroups += @{Name = $computeGroupName; IPAddress = $computeCidrs }

# The MGW and CGW group definitions start out the same, sync them:
$mgwGroups = @() + $cgwGroups

# Create additional MGW or CGW groups/rules as needed:
# $cgwGroups += @{Name = "X"; IPAddress = @("172.21.0.0/16") } 
# $mgwGroups += @{Name = "Y"; IPAddress = @("172.22.0.0/16") } 


# InfraScope ("Applied To") values: 
# CGW: All Uplinks, VPC Interface, Direct Connect Interface, Internet Interface, VPN Tunnel Interface
# MGW: simply uses MGW
$cgwRules = @()
$cgwRules += @{Name = "$computeGroupName to Any" ; SourceGroup = $computeGroupName; DestinationGroup = @("Any");
    Service = "ANY"; InfraScope = @("All Uplinks","VPN Tunnel Interface") }
$cgwRules += @{Name = "$vpcGroupName to $computeGroupName" ; SourceGroup = $vpcGroupName; DestinationGroup = $computeGroupName; 
    Service = "ANY"; }


# MGW services are: HTTPS, ICMP ALL, VMware VMotion, Provisioning & Remote Console
$mgwRules = @()
$mgwRules += @{Name = "$adminGroupName to vCenter" ; SourceGroup = $adminGroupName; DestinationGroup = "vCenter"; Service = @("HTTPS","ICMP ALL") }
$mgwRules += @{Name = "$vpcGroupName to vCenter" ; SourceGroup = $vpcGroupName; DestinationGroup = "vCenter"; Service = @("HTTPS","ICMP ALL") }
$mgwRules += @{Name = "$vpcGroupName to ESXi" ; SourceGroup = $vpcGroupName; DestinationGroup = "ESXi"; Service = @("HTTPS","ICMP ALL") }
$mgwRules += @{Name = "$vpcGroupName to NSX" ; SourceGroup = $vpcGroupName; DestinationGroup = "NSX Manager"; Service = @("HTTPS") }


#### End of configurable section ####


Function Add-Groups {
    param(
        [Parameter(Mandatory)]$GatewayType,
        [Parameter(Mandatory)]$GroupList
        )

    Write-Host -ForegroundColor Green "Adding $($GatewayType) groups"

    foreach ($group in $GroupList) {
        Write-Host -ForegroundColor Green "Working on group: $($group.Name)"
        if(Get-NSXTGroup -GatewayType $GatewayType -Name $group.Name) {
            Write-Host -ForegroundColor Blue "Group exists, skipping"
        } else {
            Write-Host -ForegroundColor Green "Creating new group..."
            New-NSXTGroup -GatewayType $GatewayType -Name $group.Name -IPAddress $group.IPAddress | Out-Null 
        }
    }
}

Function Remove-Groups {
    param(
        [Parameter(Mandatory)]$GatewayType,
        [Parameter(Mandatory)]$GroupList
        )

    Write-Host -ForegroundColor Green "Removing $($GatewayType) groups"

    foreach ($group in $GroupList) {
        write-output "Working on group: $($group.Name)"
        $fwGroup = Get-NSXTGroup -GatewayType $GatewayType -Name $group.Name
        if($fwGroup.ID) {
            Write-Host -ForegroundColor Red "Group exists, attempting to remove..."
            Remove-NSXTGroup -Id $fwGroup.ID -GatewayType $GatewayType
        } else {
            Write-Host -ForegroundColor Red "Group not found, skipping removal"
        }
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
            Write-Host -ForegroundColor Blue "Rule exists, skipping"            
        } else {
            if($GatewayType -eq "MGW"){
                $InfraScope = "MGW"
            } elseif ($rule.InfraScope) {
                $InfraScope = $rule.InfraScope
            } else {
                $InfraScope = "All Uplinks"
            }


            Write-Host -ForegroundColor Green "Creating new rule..."
            New-NSXTFirewall -GatewayType $GatewayType -Name $rule.Name -SourceGroup $rule.SourceGroup `
            -DestinationGroup $rule.DestinationGroup -Service $rule.Service -InfraScope $InfraScope `
            -Logged $true -SequenceNumber ($ruleSeq++) -Action ALLOW | Out-Null
        }
    }
}

Function Remove-Rules {
    param(
        [Parameter(Mandatory)]$GatewayType,
        [Parameter(Mandatory)]$RuleList
        )

    Write-Host -ForegroundColor Green "Removing $($GatewayType) rules"

    foreach ($rule in $RuleList) {
        Write-Output "Working on rule: $($rule.Name)"
        $fwRule = Get-NSXTFirewall -GatewayType $GatewayType -Name $rule.Name

        if($fwRule.ID) {
            Write-Host -ForegroundColor Red "Rule exists, attempting to remove..."
            Remove-NSXTFirewall -Id $fwRule.ID -GatewayType $GatewayType
        } else {
            Write-Host -ForegroundColor Red "Rule not found, skipping removal"            
        }
    }
}

if($Cleanup.isPresent) {
    Remove-Rules -GatewayType MGW $mgwRules 
    Remove-Groups -GatewayType MGW $mgwGroups 
    Remove-Rules -GatewayType CGW $cgwRules
    Remove-Groups -GatewayType CGW $cgwGroups 
} else {
    Add-Groups -GatewayType CGW $cgwGroups 
    Add-Rules -GatewayType CGW $cgwRules 
    Add-Groups -GatewayType MGW $mgwGroups 
    Add-Rules -GatewayType MGW $mgwRules 
}

