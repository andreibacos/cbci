#!powershell

# WANT_JSON
# POWERSHELL_COMMON


$params = Parse-Args $args;

$result = @{
    cb_unzip = @{}
    changed = $false
}

$creates = Get-AnsibleParam -obj $params -name "creates" -type "path"
If ($creates -ne $null) {
    If (Test-Path $creates) {
        $result.msg = "The 'creates' file or directory ($creates) already exists."
        Exit-Json $result
    }
}

$overwrite = Get-AnsibleParam -obj $params -name "overwrite" -type "bool" -default "false" -ValidateSet "true","false"

$src = Get-AnsibleParam -obj $params -name "src" -type "path" -failifempty $true
If (-Not (Test-Path -path $src)){
    Fail-Json $result "src file: $src does not exist."
}

$ext = [System.IO.Path]::GetExtension($src)


$dest = Get-AnsibleParam -obj $params -name "dest" -type "path" -failifempty $true
If (-Not (Test-Path $dest -PathType Container)){
    Try{
        New-Item -itemtype directory -path $dest
    }
    Catch {
        $err_msg = $_.Exception.Message
        Fail-Json $result "Error creating $dest directory! Msg: $err_msg"
    }
}

$rm = ConvertTo-Bool (Get-AnsibleParam -obj $params -name "rm" -default "false")

If ($ext -eq ".zip") {
    Try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead($src)
        foreach ($entry in $archive.Entries)
        {
            $entryTargetFilePath = [System.IO.Path]::Combine($dest, $entry.FullName)
            $entryDir = [System.IO.Path]::GetDirectoryName($entryTargetFilePath)
        
            #Ensure the directory of the archive entry exists
            if(!(Test-Path $entryDir )){
                New-Item -ItemType Directory -Path $entryDir | Out-Null 
            }
            
            #If the entry is not a directory entry, then extract entry
            if(!$entryTargetFilePath.EndsWith("\")){
                if(Test-Path -path $entryTargetFilePath){
                    if ($overwrite){
                        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $entryTargetFilePath, $true);
                        $result.changed = $true
                    }
                }
                Else {
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $entryTargetFilePath, $false);
                    $result.changed = $true
                }
            }
        }
    }
    Catch {
        $err_msg = $_.Exception.Message
        Fail-Json $result "Error unzipping $src to $dest! Msg: $err_msg"
    }
}
# Requires PSCX
Else {
    # Check if PSCX is installed
    $list = Get-Module -ListAvailable

    If (-Not ($list -match "PSCX")) {
        Fail-Json $result "PowerShellCommunityExtensions PowerShell Module (PSCX) is required for non-'.zip' compressed archive types."
    }
    Else {
        $result.cb_unzip.pscx_status = "present"
    }

    # Import
    Try {
        Import-Module PSCX
    }
    Catch {
        Fail-Json $result "Error importing module PSCX"
    }

    Try {
        Expand-Archive -Path $src -OutputPath $dest -Force 
        $result.changed = $true
    }
    Catch {
        $err_msg = $_.Exception.Message
        Fail-Json $result "Error expanding $src to $dest! Msg: $err_msg"
    }
}

If ($rm -eq $true){
    Remove-Item $src -Recurse -Force
    $result.cb_unzip.rm = "true"
}

# Fixes a fail error message (when the task actually succeeds) for a "Convert-ToJson: The converted JSON string is in bad format"
# This happens when JSON is parsing a string that ends with a "\", which is possible when specifying a directory to download to.
# This catches that possible error, before assigning the JSON $result
If ($src[$src.length-1] -eq "\") {
    $src = $src.Substring(0, $src.length-1)
}
If ($dest[$dest.length-1] -eq "\") {
    $dest = $dest.Substring(0, $dest.length-1)
}
$result.cb_unzip.src = $src.toString()
$result.cb_unzip.dest = $dest.toString()

Exit-Json $result
