#****************************************************************************************************
#
# uninstall-office.ps1
# Copyright (c) 2026 Arthur Taft, Microsoft Croporation. All Rights Reserved.
#
#****************************************************************************************************
#
# Version: 1.2
#
#****************************************************************************************************
#
# Configurable Variables
# ======================
#
# (1) Variable Name: GetHelpCmdSourcePath
# ------------------------------------
#
$GetHelpCmdSourcePath = "https://aka.ms/SaRA_EnterpriseVersionFiles"
#
# (2) Variable Name: GetHelpScenarioArgument
# ---------------------------------------
#
$GetHelpScenarioArgument = "-S OfficeScrubScenario -AcceptEula -LogFolder $PSScriptRoot\LogFiles"
#
# (3) Variable Name: currentTimeStamp
# ------------------------------------
#
# - Default timestamp format used for the file name of the .zip file created by this script
# - Changing the format is optional
#
$currentTimeStamp = Get-Date -Format "yyyy-MMM-dd_HH.mm.ss"
#
# (4) Variable Name: resultsFileName
# -----------------------------------
#
# - Do Not remove <scenario> from this variable (you will break the script)
# - Remove $env:USERNAME if you do not wish to have the username included
# - Changing this variable is optional
#
$resultsFileName = $env:USERNAME + "_<scenario>_$currentTimeStamp.zip"
#
#****************************************************************************************************
#
# ==================
# Begin Main Section ** Nothing below this line <requires> any edits **
# ==================

$currentLocation = $PSScriptRoot
$resultsFilePath = "$currentLocation\$resultsFileName"
$GetHelpCmdExecutableFolder = "$currentLocation\GetHelpCMDExecutable"
$GetHelpCmdExecutablePath = "$GetHelpCmdExecutableFolder\GetHelpCmd.exe"
$LocalLogFolder = "$currentLocation\LogFiles"
$scriptLogFile = "$LocalLogFolder\GetHelpCmd-$currentTimeStamp.txt"
$scriptStartTime = Get-Date

# ------------------------
# Starting Local Functions
# ------------------------

# Create local folders that contain GetHelpCmd files and log files
Function Create-LocalFolders
{
    New-Item -Path $GetHelpCmdExecutableFolder -ItemType "directory" -Force | Out-Null
    New-Item -Path $LocalLogFolder -ItemType "directory" -Force | Out-Null
}

# Cleanup the local folders that were created by the script
Function Clean-LocalFiles
{
    Remove-Item -Path $GetHelpCmdExecutableFolder -Force -Recurse
    Remove-Item -Path $LocalLogFolder -Force -Recurse
}

# Cleanup files created by the script that may remain from a previous run
Function Clean-InitialFiles
{
    $targetZipFileLocation = "$currentLocation\GetHelpCmd.zip"
    # Delete local zip file if it exists
    if (Test-Path -Path $targetZipFileLocation -PathType Leaf)
    {
        Remove-Item -Path $targetZipFileLocation -Force | Out-File -FilePath $scriptLogFile -Append
    }

    if (Test-Path -Path $GetHelpCmdExecutableFolder)
    {
        Remove-Item -Path $GetHelpCmdExecutableFolder -Force -Recurse | Out-File -FilePath $scriptLogFile -Append
    }
}

# Copy the GetHelpCmd Execution folders locally
Function Copy-GetHelpLocally($GetHelpCmdSourcePath)
{
    $targetZipFileLocation = "$currentLocation\GetHelpCmd.zip"

    Write-Output "Copying Files from $GetHelpCmdSourcePath" | Out-File -FilePath $scriptLogFile -Append

    # if the source starts with https, just download it
    if ($GetHelpCmdSourcePath.StartsWith("http", 'CurrentCultureIgnoreCase'))
    {
        Write-Output "Getting zip file from web location $GetHelpCmdSourcePath" | Out-File -FilePath $scriptLogFile -Append

            Invoke-WebRequest -URI $GetHelpCmdSourcePath -OutFile $targetZipFileLocation
            $GetHelpCmdSourcePath = $targetZipFileLocation
    }
    else
    {
        if ($GetHelpCmdSourcePath.EndsWith(".zip", 'CurrentCultureIgnoreCase'))
        {
            Copy-Item -Path $GetHelpCmdSourcePath -Destination $targetZipFileLocation -Force | Out-File -FilePath $scriptLogFile -Append
            $GetHelpCmdSourcePath = $targetZipFileLocation
        }
    }

    # if source ends with zip, copy it locally, overwrite if it was downloaded in the previous step
    # if the source ends with zip, extract it
    if ($GetHelpCmdSourcePath.EndsWith(".zip", 'CurrentCultureIgnoreCase'))
    {
        Write-Output "Expanding zip file from $GetHelpCmdSourcePath" | Out-File -FilePath $scriptLogFile -Append
        Expand-Archive -Path $targetZipFileLocation -DestinationPath $GetHelpCmdExecutableFolder -Force
        $GetHelpCmdSourcePath = $GetHelpCmdExecutableFolder
    }

    if($GetHelpCmdSourcePath -ne $GetHelpCmdExecutableFolder)
    {
        # copy files to expected folder
        Write-Output "Copying files from $GetHelpCmdSourcePath" | Out-File -FilePath $scriptLogFile -Append
        Copy-Item -Path $GetHelpCmdSourcePath\* -Destination $GetHelpCmdExecutableFolder -Recurse -Force
        Write-Output "Copied Files To $GetHelpCmdExecutableFolder" | Out-File -FilePath $scriptLogFile -Append
    }

    # Delete local zip file if it exists
    if (Test-Path -Path $targetZipFileLocation -PathType Leaf)
    {
        Remove-Item -Path $targetZipFileLocation -Force
    }

    # Check if the source contains GetHelpCmd.Exe
    if (Test-Path -Path "$GetHelpCmdExecutableFolder\GetHelpCmd.exe" -PathType Leaf)
    {
        return $true
    }
    else
    {
        return $false
    }

}

# Create Zip file with all logs attached
Function Create-LogArchive()
{
    Compress-Archive -Path "$localLogFolder\*" -DestinationPath $resultsFilePath
}

# Checks if elevated execution is needed for this scenario
Function Check-AdminAccess($scenario)
{
    $elevationRequired = $true

    return $elevationRequired
}

# Checks if the current window is elevated
Function Test-IsAdmin # Function credit to: https://devblogs.microsoft.com/scripting/use-function-to-determine-elevation-of-powershell-console/
{
    # Returns True if the script is run from an elevated PowerShell console (Run as administrator)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Download and execute the SaRA scenario
Function Execute-GetHelpCMD($GetHelpCmdSourcePath, $arguments)
{
    $success = $false
    $filesCopied = Copy-GetHelpLocally($GetHelpCmdSourcePath)
    if ([bool]::Parse($filesCopied) -ne $true)
    {
        Write-Host "Could not get GetHelp CMD File locally, exiting..."
        exit
    }

    Write-Output "Executing GetHelp cmd from $GetHelpCmdExecutablePath" | Out-File -FilePath $scriptLogFile -Append
    Write-Output "With arguments : $arguments" | Out-File -FilePath $scriptLogFile -Append

    $scenario = Get-Scenario($arguments)

    Write-Host ""
    Write-Host ">>> Starting the scenario with the following arguments:"
    Write-Host ""
    Write-Host " $GetHelpScenarioArgument"
    Write-Host ""
    Write-Host ">>> Please wait ..."
    Write-Host ""

    $processInfo = new-Object System.Diagnostics.ProcessStartInfo($GetHelpCmdExecutablePath);
    $processInfo.Arguments = $arguments # Do NOT modify - These are required parameters for this scenario

    if(Check-AdminAccess($scenario) -eq $true)
    {
        $processInfo.Verb = "RunAs"
    }

    $processInfo.CreateNoWindow = $true;
    $processInfo.UseShellExecute = $false;
    $processInfo.RedirectStandardOutput = $true;
    $processInfo.RedirectStandardError = $true;
    $process = [System.Diagnostics.Process]::Start($processInfo);
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit();

    if ($stdout) { Write-Host "Output: $stdout" }
    if ($stderr) { Write-Host "Error: $stderr" }

    # https://learn.microsoft.com/microsoft-365/troubleshoot/administration/GetHelp-command-line-version
    # See the above article for possible ExitCode values

    if($process.HasExited -and ($process.ExitCode -eq 0 -or ($process.ExitCode -eq 80)))
    {
        $success = $true
    }

    $process.Dispose();

    # Returns True if the scenario's execution PASSED, otherwise False
    return $success;
}

# Extract scenario name from arguments
Function Get-Scenario($arguments)
{
    $scenario = ""

    $args = $arguments.Split("-")

    foreach ($arg in $args)
    {
        if ($arg.StartsWith("S ") -or $arg.StartsWith("s "))
        {
            $scenario = $arg.Split(" ")[1]
            break;
        }
    }
    return $scenario
}

#
# -------------------
# End Local Functions
# -------------------
#
# ------------
# Begin Script
# ------------
#

function Invoke-Main {

    #Check for an empty $GetHelpCmdSourcePath variable
    if(($GetHelpCmdSourcePath -eq "") -or ($null -eq $GetHelpCmdSourcePath))
    {
        return 20 # GetHelpCmd path empty
    }
    # Check to see if the path is exists
    if (-not ($GetHelpcmdsourcepath -like "https*") -and -not (Test-Path $GetHelpCmdSourcePath))
    {
        return 30 # GetHelpCmd path does not exist
    }
    # Check to see if https path is correct
    if ($GetHelpcmdsourcepath -like "https*" -and -not($GetHelpcmdsourcepath -eq "https://aka.ms/SaRA_EnterpriseVersionFiles"))
    {
        return 31 # https path not correct
    }
    # Check for an empty $GetHelpScenarioArgument variable
    if (($GetHelpScenarioArgument -eq "") -or ($null -eq $GetHelpScenarioArgument))
    {
        return 21 # GetHelpScenario arguments empty
    }

    # Check for an empty $currentTimeStamp variable
    if (($currentTimeStamp -eq "") -or ($null -eq $currentTimeStamp))
    {
        return 22 # current time stamp empty
    }
    # Check for an empty $resultsFileName variable
    if (($resultsFileName -eq "") -or ($null -eq $resultsFileName))
    {
        return 23 # results file name empty
    }
    # Check for the existence and spelling of the required -AcceptEula switch
    if ($GetHelpScenarioArgument -notlike "*-accepteula*")
    {
        return 40 # eula switch not found
    }
    # Check for the required -S switch
    if ($GetHelpScenarioArgument -notlike "*-s *")
    {
        return 41 # -S switch not found
    }

    $scenario = Get-Scenario($GetHelpScenarioArgument)

    # Check to ensure specified scenario name exists and is spelled correctly
    if ($scenario -notin "OfficeScrubScenario")
    {
        return 42 # Scrub Scenario not found
    }

    try
    {
        Clean-InitialFiles
        Create-LocalFolders
        Write-Output "--------------------------------------------" | Out-File -FilePath $scriptLogFile # First log statement to create the file
    }
    catch
    {
        return 32 # Local Path not found
    }

    $resultsFileName = $resultsFileName.Replace("<scenario>", $scenario)
    $resultsFilePath = $resultsFilePath.Replace("<scenario>", $scenario)

    $executionSuccess = Execute-GetHelpCMD $GetHelpCmdSourcePath $GetHelpScenarioArgument

    Write-Host ">>> GetHelpCmd.exe output"
    Write-Host ""
    Write-Host "GetHelpCmd Command Line script execution status: $executionSuccess"
    Write-Host ""

    Write-Output "GetHelpCmd Command Line script execution status: $executionSuccess" | Out-File -FilePath $scriptLogFile -Append
    Write-Output "" | Out-File -FilePath $scriptLogFile -Append

    if($executionSuccess -eq $true)
    {
        Write-Output ">>> Scenario execution completed successfully" | Out-File -FilePath $scriptLogFile -Append
        Write-Host ">>> Scenario execution completed successfully"
    }
    else
    {
        Write-Output ">>> GetHelpCmd ran into a problem or had an error. Please check the GetHelpLog-<date>.log file for details." | Out-File -FilePath $scriptLogFile -Append
        return 50 # scrub failed
    }

    try {
        Create-LogArchive
    }
    catch {
        return 60 # Log archive creation failed
    }

    try {
        Clean-LocalFiles
    }
    catch {
        return 80 # Local file clean failed
    }

#
# ----------------
# Launch page to re-download office in firefox (the superior browser)
# ----------------
#

    try {
        # SYSTEM user needs path for executable, grab from registry first
        $firefoxPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe" -ErrorAction SilentlyContinue).'(defult)'
        if (-not $firefoxPath) {$firefoxPath = "C:\Program Files\Mozilla Firefox\firefox.exe"}

        # Create scheduled task so firefox can launch under the user's profile, not SYSTEM
        $action = New-ScheduledTaskAction -Execute $firefoxPath -Argument "https://portal.office.com/"
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date)
        $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Limited

        Register-ScheduledTask -TaskName "PostScrubLaunch" -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
        Start-ScheduledTask -TaskName "PostScrubLaunch"

        Start-Sleep -Seconds 5
    }
    catch {
        return 90 # Webpage launch failed
    }
    finally {
        Unregister-ScheduledTask -TaskName "PostScrubLaunch" -Confirm:$false -ErrorAction SilentlyContinue
    }

    return 0 # Everything is ok
}

$exitCode = Invoke-Main

exit $exitCode

#
# ****************
#
# End Script
#
# ****************
#
