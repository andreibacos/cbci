#!powershell

# WANT_JSON
# POWERSHELL_COMMON

Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"

$parsed_args = Parse-Args $args -supports_check_mode $true

$result = @{changed=$false}

$git_url = Get-AnsibleParam $parsed_args "url" -FailIfEmpty $true
$ref = Get-AnsibleParam $parsed_args "ref" -FailIfEmpty $true
$path = Get-AnsibleParam $parsed_args "path" -FailIfEmpty $true

$check_mode = Get-AnsibleParam $parsed_args "_ansible_check_mode" -Default $false

If ($ref -is [string]) {
    $ref = @($ref)
}

If ($ref -isnot [Array]) {
    Fail-Json $result "ref must be a string or list of ref strings"
}

Function Execute-Command ($commandTitle, $commandPath, $commandArguments)
{
  Try {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $commandPath
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $commandArguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | out-null
    $r = [pscustomobject]@{   
        command = $commandPath + " " + $commandArguments
        stdout = $p.StandardOutput.ReadToEnd()
        stderr = $p.StandardError.ReadToEnd()
        exitcode = $p.ExitCode  
    }
    $p.WaitForExit()
    return $r
  }
  Catch {
    return $r = [pscustomobject]@{
        command = $commandPath + " " + $commandArguments
        stderr = $_
        exitcode = 1
    }    
  }
}

$result.output = @{}

If (-not $check_mode) { 
    if (!(Test-Path $path)) {
        Fail-Json $result "Path $path does not exist"
    } else {
        Execute-Command -commandTitle "git set global email" -commandPath "git" -commandArguments "config --global user.email cbci@cloudbasesolutions.com"
        Execute-Command -commandTitle "git set global user" -commandPath "git" -commandArguments "config --global user.name CBCI"
        foreach ($r in $ref) {
            $fetch_result = Execute-Command -commandTitle "git fetch" -commandPath "git" -commandArguments "-C $path fetch $git_url $r"
            $result.output[$r] = @{}
            $result.output[$r].Add("git fetch", $fetch_result)
            if (($fetch_result.exitcode) -eq 0) {
                $cherry_pick_result = Execute-Command -commandTitle "git cherry pick" -commandPath "git" -commandArguments "-C $path cherry-pick FETCH_HEAD"
                $result.output[$r].Add("git cherry pick", $cherry_pick_result)
                if (($cherry_pick_result.exitcode) -ne 0) {
                    $cherry_pick_abort_result = Execute-Command -commandTitle "git cherry-pick abort" -commandPath "git" -commandArguments "-C $path cherry-pick --abort"
                    $result.output[$r].Add("git cherry-pick abort", $cherry_pick_abort_result)
                } else {
                    $result.changed = $true
                }
            }
        }
    }
}

Exit-Json $result
