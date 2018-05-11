ovs-vsctl add-br {{ data_bridge }}
$INTERFACE=(Get-NetIPAddress -AddressFamily ipv4 | Where-Object {$_.IPAddress -match "192.168.0"}|Select-Object InterfaceAlias).InterfaceAlias
$INTERFACE_IP=(Get-NetIPAddress -AddressFamily ipv4 |Where-Object {$_.InterfaceAlias -eq $($INTERFACE)}|Select-Object IPAddress).IPAddress
ovs-vsctl add-port {{ data_bridge }} $INTERFACE
Enable-NetAdapter {{ data_bridge }}
New-NetIPAddress -IPAddress $INTERFACE_IP -InterfaceAlias {{ data_bridge }} -PrefixLength 22