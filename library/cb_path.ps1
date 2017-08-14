#!powershell

# WANT_JSON
# POWERSHELL_COMMON

Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"

$parsed_args = Parse-Args $args -supports_check_mode $true

$result = @{changed=$false}

$var_name = Get-AnsibleParam $parsed_args "name" -Default "PATH"
$elements = Get-AnsibleParam $parsed_args "elements" -FailIfEmpty $result
$state = Get-AnsibleParam $parsed_args "state" -Default "present" -ValidateSet "present","absent"
$scope = Get-AnsibleParam $parsed_args "scope" -Default "machine" -ValidateSet "machine","user"

$check_mode = Get-AnsibleParam $parsed_args "_ansible_check_mode" -Default $false

If ($elements -is [string]) {
    $elements = @($elements)
}

If ($elements -isnot [Array]) {
    Fail-Json $result "elements must be a string or list of path strings"
}

[System.Collections.ArrayList] $path = [System.Environment]::GetEnvironmentVariable("PATH", $scope).Split(';')
$result.path_value = $path -join ";"


foreach ($element in $elements) {
    if ($state -eq "present") {
        if ($path -notcontains $element){
            $result.changed = $true
            $path.Add($element)
        }
    } else {
        if ($path -contains $element) {
            $path.Remove($element)
            $result.changed = $true
        }
    }
}

If ($result.changed -and -not $check_mode) {
    $result.path_value = $path -join ";"
    [Environment]::SetEnvironmentVariable("Path", ($path -join ";"), [System.EnvironmentVariableTarget]::$scope )
}

Exit-Json $result
