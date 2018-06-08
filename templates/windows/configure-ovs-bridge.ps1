Remove-VMSwitch {{ data_bridge }}
$INTERFACE=(Get-NetIPAddress -AddressFamily ipv4 | Where-Object {$_.IPAddress -match "192.168.0"}|Select-Object InterfaceAlias).InterfaceAlias
$INTERFACE_IP=(Get-NetIPAddress -AddressFamily ipv4 |Where-Object {$_.InterfaceAlias -eq $($INTERFACE)}|Select-Object IPAddress).IPAddress
New-VMSwitch -Name {{ data_bridge }} -NetAdapterName $INTERFACE -AllowManagementOS $false
Enable-VMSwitchExtension -VMSwitchName {{ data_bridge }} -Name "Cloudbase Open vSwitch Extension"
ovs-vsctl --db=tcp:127.0.0.1:6640 add-br {{ data_bridge_ovs }}
ovs-vsctl --db=tcp:127.0.0.1:6640 add-port {{ data_bridge_ovs }} $INTERFACE
Enable-NetAdapter {{ data_bridge_ovs }}
New-NetIPAddress -IPAddress $INTERFACE_IP -InterfaceAlias {{ data_bridge_ovs }} -PrefixLength 22
