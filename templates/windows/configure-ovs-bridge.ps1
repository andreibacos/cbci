$INTERFACE=(Get-NetIPAddress -AddressFamily ipv4 | Where-Object {$_.IPAddress -match "192.168.0"}|Select-Object InterfaceAlias).InterfaceAlias
$INTERFACE_IP=(Get-NetIPAddress -AddressFamily ipv4 |Where-Object {$_.InterfaceAlias -eq $($INTERFACE)}|Select-Object IPAddress).IPAddress
Remove-VMSwitch {{ data_bridge }}
New-VMSwitch -Name {{ data_bridge }} -NetAdapter $INTERFACE -AllowManagementOS $false
ovs-vsctl add-br {{ data_bridge_ovs }}
ovs-vsctl add-port {{ data_bridge_ovs }} $INTERFACE
Enable-NetAdapter {{ data_bridge_ovs }}
New-NetIPAddress -IPAddress $INTERFACE_IP -InterfaceAlias {{ data_bridge_ovs }} -PrefixLength 22