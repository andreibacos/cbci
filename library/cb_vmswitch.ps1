#!powershell

# WANT_JSON
# POWERSHELL_COMMON

Set-StrictMode -Version 3
$ErrorActionPreference = "Stop"

$parsed_args = Parse-Args $args -supports_check_mode $true

$result = @{changed=$false}

$name = Get-AnsibleParam $parsed_args "name" -FailIfEmpty $true
$management= Get-AnsibleParam $parsed_args "management" -type "bool" -default "false" -ValidateSet "true","false"
$state = Get-AnsibleParam $parsed_args "state" -Default "present" -ValidateSet "present","absent"
$var_subnet = Get-AnsibleParam $parsed_args "subnet" -FailIfEmpty $true

$check_mode = Get-AnsibleParam $parsed_args "_ansible_check_mode" -Default $false

Function ip_in_subnet { 
    param ( 
        [parameter(Mandatory=$true)]
        [Net.IPAddress] 
        $ip, 

        [parameter(Mandatory=$true)] 
        $subnet
    ) 

    [Net.IPAddress]$ip2, $m = $subnet.split('/')

    Switch -RegEx ($m) {
        "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$" {
            $mask = [Net.IPAddress]$m
        }
        "^[\d]+$" {
            $tip=([Convert]::ToUInt32($(("1" * $m).PadRight(32, "0")), 2))
            $dotted = $( For ($i = 3; $i -gt -1; $i--) {
                $r = $tip % [Math]::Pow(256, $i)
                ($tip - $r) / [Math]::Pow(256, $i)
                $tip = $r
            } )
        
            $mask = [Net.IPAddress][String]::Join('.', $dotted)
        }
        default {
            Fail-Json $result "Invalid subnet specified: $subnet"
        }
    }

    if (($ip.address -band $mask.address) -eq ($ip2.address -band $mask.address)) {
        return $true
    } else {
        return $false
    } 
}
$result.log = @()
$result.interface_details =@{}

If (-not $check_mode) {
    $VMswitches = Get-VMSwitch -SwitchType External -ErrorAction SilentlyContinue
    if ($VMswitches){
        foreach($i in $VMswitches){
            $result.log += "Found vmswitch: " + $i.name + ", checking..."
            if ( $i.name -eq $name ) {
                if ( $state -eq "absent" ) {
                    $result.log += "Found vmswitch " + $i.name + ", state is " + $state + ", removing"
                    remove-vmswitch -name $i.name -force
                    $result.changed = $true
                    Exit-Json $result
                }
                $result.log += "Found vmswitch " + $i.name + ", checking ManagementOS"
                if ( $i.allowmanagementos -eq $management ) {
                    $result.log += "ManagementOS matches"
                }
				<#  else {
                    $result.log += "ManagementOS does not match, updating from " + $i.allowmanagementos + " to " + $management
                    Set-VMSwitch -Name $name -AllowManagementOS $management
                    $result.changed = $true
                } #>

                if ( $management ) {
                    $result.log += "ManagementOS is true, checking ip"
                    $sw_name = "vEthernet (" + $i.name + ")"
                    $sw_ip = Get-NetIPAddress -addressfamily ipv4 -interfacealias $sw_name -ErrorAction SilentlyContinue
                    if ($sw_ip) {
                        if (ip_in_subnet -ip $sw_ip.ipaddress -subnet $var_subnet) {
                            $result.log += "ip " + $sw_ip.ipaddress + " is part of subnet " + $var_subnet + ", done"
                            Exit-Json $result
                        } else {
                            $result.log += "ip " + $sw_ip.ipaddress + " is not part of subnet " + $var_subnet
                            remove-vmswitch -name $i.name -force
                            $result.changed = $true
                        }
                    } else {
                        $result.log += "Could not get ip address for vEthernet (" + $i.name + "), removing vmswitch"
                        remove-vmswitch -name $i.name -force
                        $result.changed = $true
                    }
                } else {
                    $result.log += "ManagementOS is " + $management + ", nothing else to check"
                    Exit-Json $result
                }
            } else {
                $result.log += "vmswitch " + $i.name + " does not match $name, ignoring it"
            }
        }
    }
    if ($state -eq "present") {
        $adapters = Get-NetIPAddress -addressfamily ipv4 -ErrorAction SilentlyContinue
        foreach ($adapter in $adapters) {
            $result.log += "checking adapter " + $adapter.interfacealias
            if (ip_in_subnet -ip $adapter.ipaddress -subnet $var_subnet) {
                $result.log += "adapter " + $adapter.interfacealias + " ip " + $adapter.ipaddress + " matches subnet " + $var_subnet
                if ( $adapter.interfacealias -match "vEthernet") {
                    $msg = "a vmswitch with a different name already exists for subnet " + $var_subnet
                    Fail-Json $result $msg
                } else {
                    try {
                        New-VMSwitch -Name $name -NetAdapterName $adapter.interfacealias -AllowManagementOS $management
						Get-VMSwitch
                        $result.interface_details.Add('adapter_name', $adapter.interfacealias)
						$result.interface_details.Add('adapter_ip', $adapter.ipaddress)
						$result.changed = $true
                        Exit-Json $result
                    } catch {
                        Fail-Json $result $_.Exception.Message
                    }
                }
            }
        }   
    }
}

Exit-Json $result
