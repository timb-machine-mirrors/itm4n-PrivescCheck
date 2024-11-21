$FunctionDefinitions = @(
    (New-Function advapi32 OpenSCManager ([IntPtr]) @([String], [String], [UInt32]) ([Runtime.InteropServices.CallingConvention]::Winapi) ([Runtime.InteropServices.CharSet]::Unicode) -SetLastError),
    (New-Function advapi32 QueryServiceObjectSecurity ([Bool]) @([IntPtr], [Security.AccessControl.SecurityInfos], [Byte[]], [UInt32], [UInt32].MakeByRefType()) -SetLastError),
    (New-Function advapi32 CloseServiceHandle ([Bool]) @([IntPtr]) -SetLastError),
    (New-Function advapi32 OpenProcessToken ([Bool]) @([IntPtr], [UInt32], [IntPtr].MakeByRefType()) -SetLastError),
    (New-Function advapi32 GetTokenInformation ([Bool]) @([IntPtr], [UInt32], [IntPtr], [UInt32], [UInt32].MakeByRefType()) -SetLastError),
    (New-Function advapi32 LookupAccountSid ([Bool]) @([String], [IntPtr], [System.Text.StringBuilder], [UInt32].MakeByRefType(), [System.Text.StringBuilder], [UInt32].MakeByRefType(), [Int].MakeByRefType()) -SetLastError),
    (New-Function advapi32 LookupPrivilegeName ([Int]) @([String], $script:LUID.MakeByRefType(), [System.Text.StringBuilder], [UInt32].MakeByRefType()) -SetLastError),
    (New-Function advapi32 CredEnumerate ([Bool]) @([IntPtr], [UInt32], [UInt32].MakeByRefType(), [IntPtr].MakeByRefType()) -SetLastError),
    (New-Function advapi32 CredFree ([void]) @([IntPtr])),
    (New-Function advapi32 IsTextUnicode ([Bool]) @([IntPtr], [UInt32], [UInt32].MakeByRefType())),
    (New-Function advapi32 ConvertSidToStringSidW ([Bool]) @([IntPtr], [IntPtr].MakeByRefType()) -SetLastError),
    (New-Function advapi32 IsTokenRestricted ([Bool]) @([IntPtr]) -SetLastError),
    (New-Function advapi32 GetSecurityInfo ([UInt32]) @([IntPtr], [UInt32], [UInt32], [IntPtr].MakeByRefType(), [IntPtr].MakeByRefType(), [IntPtr].MakeByRefType(), [IntPtr].MakeByRefType(), [IntPtr].MakeByRefType()) -SetLastError),
    (New-Function advapi32 ConvertSecurityDescriptorToStringSecurityDescriptor ([Bool]) @([IntPtr], [UInt32], [UInt32], [String].MakeByRefType(), [UInt32].MakeByRefType()) ([Runtime.InteropServices.CallingConvention]::Winapi) ([Runtime.InteropServices.CharSet]::Unicode) -SetLastError),
    (New-Function advapi32 ConvertStringSecurityDescriptorToSecurityDescriptor ([Bool]) @([String], [UInt32], [IntPtr].MakeByRefType(), [UInt32].MakeByRefType()) ([Runtime.InteropServices.CallingConvention]::Winapi) ([Runtime.InteropServices.CharSet]::Unicode) -SetLastError),
    (New-Function advapi32 GetSidSubAuthority ([IntPtr]) @([IntPtr], [UInt32]) -SetLastError),
    (New-Function advapi32 GetSidSubAuthorityCount ([IntPtr]) @([IntPtr]) -SetLastError),

    (New-Function iphlpapi GetAdaptersAddresses ([UInt32]) @([UInt32], [UInt32], [IntPtr], [IntPtr], [UInt32].MakeByRefType())),
    (New-Function iphlpapi GetExtendedTcpTable ([UInt32]) @([IntPtr], [UInt32].MakeByRefType(), [Bool], [UInt32], $script:TCP_TABLE_CLASS, [UInt32]) -SetLastError),
    (New-Function iphlpapi GetExtendedUdpTable ([UInt32]) @([IntPtr], [UInt32].MakeByRefType(), [Bool], [UInt32], $script:UDP_TABLE_CLASS , [UInt32]) -SetLastError),

    (New-Function kernel32 CreateFile ([IntPtr]) @([String], [UInt32], [UInt32], [IntPtr], [UInt32], [UInt32], [IntPtr]) ([Runtime.InteropServices.CallingConvention]::Winapi) ([Runtime.InteropServices.CharSet]::Unicode) -SetLastError),
    (New-Function kernel32 GetCurrentProcess ([IntPtr]) @()),
    (New-Function kernel32 OpenProcess ([IntPtr]) @([UInt32], [Bool], [UInt32]) -SetLastError),
    (New-Function kernel32 OpenThread ([IntPtr]) @([UInt32], [Bool], [UInt32]) -SetLastError),
    (New-Function kernel32 GetProcessId ([UInt32]) @([IntPtr]) -SetLastError),
    (New-Function kernel32 GetThreadId ([UInt32]) @([IntPtr]) -SetLastError),
    (New-Function kernel32 DuplicateHandle ([IntPtr]) @([IntPtr], [IntPtr], [IntPtr], [IntPtr].MakeByRefType(), [UInt32], [Bool], [UInt32]) -SetLastError),
    (New-Function kernel32 CloseHandle ([Bool]) @([IntPtr]) -SetLastError),
    (New-Function kernel32 GetFirmwareEnvironmentVariable ([UInt32]) @([String], [String], [IntPtr], [UInt32]) -SetLastError),
    (New-Function kernel32 GetFirmwareType ([Bool]) @([UInt32].MakeByRefType()) -SetLastError),
    (New-Function kernel32 LocalFree ([IntPtr]) @([IntPtr])),
    (New-Function kernel32 QueryDosDevice ([UInt32]) @([String], [IntPtr], [UInt32]) -SetLastError -EntryPoint QueryDosDeviceW),
    (New-Function kernel32 Wow64DisableWow64FsRedirection ([Bool]) @([IntPtr].MakeByRefType()) ([Runtime.InteropServices.CallingConvention]::Winapi) -SetLastError -EntryPoint Wow64DisableWow64FsRedirection),
    (New-Function kernel32 Wow64RevertWow64FsRedirection ([Bool]) @([IntPtr]) -SetLastError -EntryPoint Wow64RevertWow64FsRedirection),
    (New-Function kernel32 LoadLibrary ([IntPtr]) @([String]) ([Runtime.InteropServices.CallingConvention]::Winapi) ([Runtime.InteropServices.CharSet]::Unicode) -EntryPoint LoadLibraryW -SetLastError),
    (New-Function kernel32 FreeLibrary ([Bool]) @([IntPtr]) -EntryPoint FreeLibrary -SetLastError),
    (New-Function kernel32 GetModuleFileName ([UInt32]) @([IntPtr], [System.Text.StringBuilder], [UInt32]) ([Runtime.InteropServices.CallingConvention]::Winapi) ([Runtime.InteropServices.CharSet]::Unicode) -EntryPoint GetModuleFileNameW -SetLastError),

    (New-Function netapi32 NetGetJoinInformation ([UInt32]) @([IntPtr], [IntPtr].MakeByRefType(), $script:NETSETUP_JOIN_STATUS.MakeByRefType()) -EntryPoint NetGetJoinInformation -Charset Unicode),
    (New-Function netapi32 NetGetAadJoinInformation ([Int32]) @([String], [IntPtr].MakeByRefType()) -EntryPoint NetGetAadJoinInformation -Charset Unicode),
    (New-Function netapi32 NetApiBufferFree ([UInt32]) @([IntPtr]) -EntryPoint NetApiBufferFree),
    (New-Function netapi32 NetFreeAadJoinInformation ([Void]) @([IntPtr]) -EntryPoint NetFreeAadJoinInformation),

    (New-Function ntdll RtlNtStatusToDosError ([UInt32]) @([UInt32]) -EntryPoint RtlNtStatusToDosError),
    (New-Function ntdll RtlInitUnicodeString ([IntPtr]) @($script:UNICODE_STRING.MakeByRefType(), [String]) -EntryPoint RtlInitUnicodeString),
    (New-Function ntdll NtQueryObject ([Int32]) @([IntPtr], [UInt32], [IntPtr], [UInt32], [UInt32].MakeByRefType()) -EntryPoint NtQueryObject),
    (New-Function ntdll NtOpenDirectoryObject ([Int32]) @([IntPtr].MakeByRefType(), [UInt32], $script:OBJECT_ATTRIBUTES.MakeByRefType()) -EntryPoint NtOpenDirectoryObject),
    (New-Function ntdll NtQueryDirectoryObject ([Int32]) @([IntPtr], [IntPtr], [UInt32], [Bool], [Bool], [UInt32].MakeByRefType(), [UInt32].MakeByRefType()) -EntryPoint NtQueryDirectoryObject),
    (New-Function ntdll NtQuerySystemInformation ([Int32]) @([UInt32], [IntPtr], [UInt32], [UInt32].MakeByRefType()) -EntryPoint NtQuerySystemInformation),

    (New-Function shell32 CommandLineToArgvW ([IntPtr]) @([String], [Int32].MakeByRefType()) -SetLastError -EntryPoint CommandLineToArgvW -Charset Unicode),

    (New-Function shlwapi AssocQueryStringW ([Int32]) @($script:ASSOCF, $script:ASSOCSTR, [String], [IntPtr], [System.Text.StringBuilder], [UInt32].MakeByRefType()) -Charset Unicode -EntryPoint AssocQueryStringW),
    (New-Function shlwapi PathRelativePathTo ([Bool]) @([System.Text.StringBuilder], [String], [UInt32], [String], [UInt32]) -Charset Unicode -EntryPoint PathRelativePathToW),

    (New-Function TpmCoreProvisioning TpmGetDeviceInformation ([Int32]) @($script:TPM_DEVICE_INFORMATION.MakeByRefType()) -EntryPoint TpmGetDeviceInformation),
    (New-Function TpmCoreProvisioning TpmGetCapLockoutInfo ([Int32]) @([UInt32].MakeByRefType(), [UInt32].MakeByRefType()) -EntryPoint TpmGetCapLockoutInfo),
    (New-Function TpmCoreProvisioning TpmIsLockedOut ([Int32]) @([Byte].MakeByRefType()) -EntryPoint TpmIsLockedOut),
    (New-Function TpmCoreProvisioning TpmGetDictionaryAttackParameters ([Int32]) @([UInt32].MakeByRefType(), [UInt32].MakeByRefType(), [UInt32].MakeByRefType()) -EntryPoint TpmGetDictionaryAttackParameters),

    (New-Function vaultcli VaultEnumerateVaults ([UInt32]) @([UInt32], [UInt32].MakeByRefType(), [IntPtr].MakeByRefType()) -EntryPoint VaultEnumerateVaults),
    (New-Function vaultcli VaultOpenVault ([UInt32]) @([IntPtr], [UInt32], [IntPtr].MakeByRefType()) -Entrypoint VaultOpenVault),
    (New-Function vaultcli VaultEnumerateItems ([UInt32]) @([IntPtr], [UInt32], [UInt32].MakeByRefType(), [IntPtr].MakeByRefType()) -EntryPoint VaultEnumerateItems),
    (New-Function vaultcli VaultGetItem7 ([UInt32]) @([IntPtr], [Guid].MakeByRefType(), [IntPtr], [IntPtr], [IntPtr], [UInt32], [IntPtr].MakeByRefType()) -EntryPoint VaultGetItem),
    (New-Function vaultcli VaultGetItem8 ([UInt32]) @([IntPtr], [Guid].MakeByRefType(), [IntPtr], [IntPtr], [IntPtr], [IntPtr], [UInt32], [IntPtr].MakeByRefType()) -EntryPoint VaultGetItem),
    (New-Function vaultcli VaultFree ([UInt32]) @([IntPtr]) -EntryPoint VaultFree),
    (New-Function vaultcli VaultCloseVault ([UInt32]) @([IntPtr].MakeByRefType()) -EntryPoint VaultCloseVault),

    (New-Function winspool.drv AddPrinterDriverEx ([Bool]) @([String], [UInt32], [IntPtr], [UInt32]) -Charset Auto -SetLastError -EntryPoint AddPrinterDriverEx),
    (New-Function winspool.drv EnumPrinterDrivers ([Bool]) @([String], [String], [UInt32], [IntPtr], [UInt32], [UInt32].MakeByRefType(), [UInt32].MakeByRefType()) -Charset Auto -SetLastError -EntryPoint EnumPrinterDrivers),
    (New-Function winspool.drv DeletePrinterDriver ([Bool]) @([String], [String], [String]) -Charset Auto -SetLastError -EntryPoint DeletePrinterDriver),
    (New-Function winspool.drv DeletePrinterDriverEx ([Bool]) @([String], [String], [String], [UInt32], [UInt32]) -Charset Auto -SetLastError -EntryPoint DeletePrinterDriverEx),
    (New-Function winspool.drv AddPrinter ([IntPtr]) @([String], [UInt32], [IntPtr]) -Charset Auto -SetLastError -EntryPoint AddPrinter),
    (New-Function winspool.drv DeletePrinter ([Bool]) @([IntPtr]) -SetLastError -EntryPoint DeletePrinter),
    (New-Function winspool.drv ClosePrinter ([Bool]) @([IntPtr]) -SetLastError -EntryPoint ClosePrinter),

    (New-Function wlanapi WlanOpenHandle ([UInt32]) @([UInt32], [IntPtr], [UInt32].MakeByRefType(), [IntPtr].MakeByRefType()) -EntryPoint WlanOpenHandle),
    (New-Function wlanapi WlanCloseHandle ([UInt32]) @([IntPtr], [IntPtr]) -EntryPoint WlanCloseHandle),
    (New-Function wlanapi WlanEnumInterfaces ([UInt32]) @([IntPtr], [IntPtr], [IntPtr].MakeByRefType()) -EntryPoint WlanEnumInterfaces),
    (New-Function wlanapi WlanFreeMemory ([Void]) @([IntPtr]) -EntryPoint WlanFreeMemory),
    (New-Function wlanapi WlanGetProfileList ([UInt32]) @([IntPtr], [Guid], [IntPtr], [IntPtr].MakeByRefType()) -EntryPoint WlanGetProfileList),
    (New-Function wlanapi WlanGetProfile ([UInt32]) @([IntPtr], [Guid], [String], [IntPtr], [String].MakeByRefType(), [UInt32].MakeByRefType(), [UInt32].MakeByRefType()) -EntryPoint WlanGetProfile),

    (New-Function wtsapi32 WTSEnumerateSessionsEx ([Bool]) @([IntPtr], [UInt32].MakeByRefType(), [UInt32], [IntPtr].MakeByRefType(), [UInt32].MakeByRefType()) -SetLastError -EntryPoint WTSEnumerateSessionsExW),
    (New-Function wtsapi32 WTSFreeMemoryEx ([Bool]) @([UInt32], [IntPtr], [UInt32]) -SetLastError -EntryPoint WTSFreeMemoryExW)
)

$Types = $FunctionDefinitions | Add-Win32Type -Module $Module -Namespace 'WinApiModule.NativeMethods'
$script:Advapi32 = $Types['advapi32']
$script:Iphlpapi = $Types['iphlpapi']
$script:Kernel32 = $Types['kernel32']
$script:Netapi32 = $Types['netapi32']
$script:Ntdll    = $Types['ntdll']
$script:Shell32  = $Types['shell32']
$script:Shlwapi  = $Types['shlwapi']
$script:TpmCoreProvisioning = $Types['TpmCoreProvisioning']
$script:Vaultcli = $Types['vaultcli']
$script:Winspool = $Types['winspool.drv']
$script:Wlanapi  = $Types['wlanapi']
$script:Wtsapi32 = $Types['wtsapi32']