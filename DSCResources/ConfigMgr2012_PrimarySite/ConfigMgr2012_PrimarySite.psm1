#
# The Get-TargetResource cmdlet.
#
function Get-TargetResource
{
    param
    (	
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SiteCode,
	    
        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $SiteName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SQLServer,

        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $DPServer,

        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $MPServer,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $InstallationDirectory,

        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $SMSProviderServer,

        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $SQLServerInstance,

        [ValidateRange(1000,9999)]
        [Uint32] $SQLPort = 1433,

        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $PrereqPath

    )

    try {
        <#
        Get-WmiObject -Class SMS_Site -Namespace root\SMS\Site_$SiteCode -ErrorAction SilentlyContinue
        #>
        $Site = Get-CimInstance -Namespace root/SMS/Site_$SiteCode -ClassName SMS_Site -ErrorAction Stop
        #Write-Verbose -Message "Found Configuration Manager WMI Namespace on this server."
    }
    catch {
        Write-Verbose -Message "Can't find Configuration Manager WMI Namespace on this server."
    }
    Write-Verbose -Message "Found Configuration Manager WMI Namespace on this server."

    $SiteResult = @{
                      SiteCode = $Site.SiteCode
    }

    return $SiteResult
}

#
# The Set-TargetResource cmdlet.
#
Function Set-TargetResource 
{
    param
    (	
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SiteCode,
	    
        [parameter(Mandatory=$false)]
        [string] $SiteName,

        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $DPServer,

        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $MPServer,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [parameter(Mandatory=$false)]
        [string] $InstallationDirectory,

        [parameter(Mandatory=$false)]
        [string] $SMSProviderServer,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SQLServer,

        [parameter(Mandatory=$false)]
        [string] $SQLServerInstance,

        [ValidateRange(1000,9999)]
        [Uint32] $SQLPort = 1433,

        [parameter(Mandatory=$false)]
        [string] $PrereqPath

    )

    if ([string]::IsNullOrEmpty($SiteName)) {
        $SiteName = "Primary Site $SiteCode"
    }
    if ([string]::IsNullOrEmpty($PrereqPath)) {
        $PrereqPath = $(Join-Path $env:SystemDrive CM12Prereqs)
    }
    if ([string]::IsNullOrEmpty($InstallationDirectory)) {
        $InstallationDirectory = $(Join-Path $env:SystemDrive CM12)
    }
    if ([string]::IsNullOrEmpty($MPServer)) {
        $MPServer = ([System.Net.Dns]::GetHostByName(($env:computerName))).HostName
    }
    if ([string]::IsNullOrEmpty($DPServer)) {
        $DPServer = ([System.Net.Dns]::GetHostByName(($env:computerName))).HostName
    }

    Create-InstallINI -SiteCode $SiteCode -SiteName $SiteName -DPServer $DPServer -MPServer $MPServer -InstallationDirectory $InstallationDirectory -SMSProviderServer $SMSProviderServer -SQLServer $SQLServer -SQLPort $SQLPort -PrereqPath $PrereqPath -SQLServerInstance $SQLServerInstance;


    Write-Verbose "Installing ConfigMgr Primary Site $SiteCode"

    $Process = @{
        FilePath = '{0}\SMSSETUP\BIN\X64\setup.exe' -f $SourcePath;
        ArgumentList = '/Script "{0}\temp\CM12Unattend.ini" /NoUserInput' -f $env:windir;
        Wait = $true;
        PassThru = $true;
        RedirectStandardOutput = '{0}\temp\CM12-StdOut.txt' -f $env:windir;
        }
    $Proc = Start-Process @Process;
    $Proc.WaitForExit()

    # Tell the DSC Engine to restart the machine
    #$global:DSCMachineStatus = 1

}

#
# The Test-TargetResource cmdlet.
#
Function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
    param
    (	
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SiteCode,
	    
        [parameter(Mandatory=$false)]
        [string] $SiteName,

        [parameter(Mandatory=$false)]
        [string] $DPServer,

        [parameter(Mandatory=$false)]
        [string] $MPServer,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [parameter(Mandatory=$false)]
        [string] $InstallationDirectory,

        [parameter(Mandatory=$false)]
        [string] $SMSProviderServer,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SQLServer,

        [parameter(Mandatory=$false)]
        [string] $SQLServerInstance,

        [ValidateRange(1000,9999)]
        [Uint32] $SQLPort = 1433,

        [parameter(Mandatory=$false)]
        [string] $PrereqPath

    )

    Write-Verbose "Beginning Test operation"

    try {
        <#
        Get-WmiObject -Class SMS_Site -Namespace root\SMS\Site_$SiteCode -ErrorAction SilentlyContinue
        #>
        $Site = Get-CimInstance -Namespace root/SMS/Site_$SiteCode -ClassName SMS_Site -ErrorAction Stop
        #Write-Verbose -Message "Found Configuration Manager WMI Namespace on this server."
    }
    catch {
        Write-Verbose -Message "Can't find Configuration Manager WMI Namespace on this server. Will start installing Configuration Manager now."
        return $false
    }
    Write-Verbose -Message "Found Configuration Manager WMI Namespace on this server."
    return $true
}

#region Helper Functions

Function Create-InstallINI {

    param
    (	
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SiteCode,
	    
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SiteName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $DPServer,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $MPServer,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $InstallationDirectory,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SMSProviderServer,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SQLServer,
        
        [parameter(Mandatory=$false)]
        [string] $SQLServerInstance = "",

        [ValidateRange(1000,9999)]
        [Uint32] $SQLPort = 1433,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrereqPath

    )

if ([string]::IsNullOrEmpty($SQLServerInstance)) {
    $DBName = "CM_$SiteCode"
}
else {
    $DBName = "$SQLServerInstance\CM_$SiteCode"
}

$Ini = @"
[Identification]
Action=InstallPrimarySite

[Options]
ProductID=EVAL
SiteCode=$SiteCode
SiteName=$SiteName
SMSInstallDir=$InstallationDirectory
SDKServer=$SMSProviderServer
RoleCommunicationProtocol=HTTPorHTTPS
ClientsUsePKICertificate=0
PrerequisiteComp=0
PrerequisitePath=$PrereqPath
MobileDeviceLanguage=0
ManagementPoint=$MPServer
ManagementPointProtocol=HTTP
DistributionPoint=$DPServer
DistributionPointProtocol=HTTP
DistributionPointInstallIIS=0
AdminConsole=1

[SQLConfigOptions]
SQLServerName=$SQLServer
DatabaseName=$DBName
SQLSSBPort=4022

[HierarchyExpansionOption]
"@

$AnswerFile = '{0}\temp\CM12Unattend.ini' -f $env:windir;
Set-Content -Path $AnswerFile -Value $Ini;
Write-Verbose -Message ('Finished writing INI file to: {0}' -f $AnswerFile);

}
#endregion Helper Functions
Export-ModuleMember -Function *-TargetResource