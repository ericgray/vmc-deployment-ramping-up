# vmc-deployment-ramping-up
PowerCLI scripts to automate VMware Cloud on AWS SDDC deployment, firewall config, and initial VM provisioning

## Overview
These are example scripts that have been featured in various demo sessions, provided here for convenience.

You must review and adjust the contents of these PowerCLI scripts before attempting to use in your own environment.

The NSX-T firewall configuration depends on the [VMware.VMC.NSXT](https://www.powershellgallery.com/packages/VMware.VMC.NSXT) PowerShell module by William Lam.

## Prerequisites
These scripts require PowerShell and PowerCLI, the following commands will get you started:

```
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Install-Module -Name VMware.PowerCLI 
Install-Module -Name VMware.VMC.NSXT
```

For more, see the [PowerCLI documentation](https://code.vmware.com/doc/preview?id=11860).

