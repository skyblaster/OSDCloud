function step-validate-customprefixlist {
    [CmdletBinding()]
    param ()
    #=================================================
    # Start the step
    $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] Start"
    Write-Debug -Message $Message; Write-Verbose -Message $Message

    #=================================================
    # Import IP prefixes from external file
    $ipPrefixesPath = "$($MyInvocation.MyCommand.Module.ModuleBase)\custom\ip-prefixes.psd1"
    if (-not (Test-Path $ipPrefixesPath)) {
        Write-Host -ForegroundColor Red "[$(Get-Date -format G)] IP prefix file not found: $ipPrefixesPath"
        return
    }
    $ipPrefixes = Import-PowerShellDataFile -Path $ipPrefixesPath
    if (-not $ipPrefixes -or $ipPrefixes.Count -eq 0) {
        Write-Host -ForegroundColor Red "[$(Get-Date -format G)] IP prefix file is empty: $ipPrefixesPath"
        return
    }
    #=================================================
    # Get current IP address and attempt web requests to local resources

    $ipAddress = $null
    $firstTwoOctets = $null
    $serverName = $null
    $localImageFileUrl = $null
    $localDriverPackUrl = $null

    #-------------------------------------------------
    # Retrieve IP Address
    try {
        Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Retrieving network configuration using ipconfig..."
        $ipConfigOutput = ipconfig | Select-String "IPv4 Address"
        Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Found $($ipConfigOutput.Count) IPv4 address entries."

        foreach ($line in $ipConfigOutput) {
            if ($line -match "\d+\.\d+\.\d+\.\d+") {
                $ipAddress = $matches[0]
                Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Valid IPv4 address found: $ipAddress"
                break
            }
        }

        if (-not $ipAddress) {
            Write-Host -ForegroundColor Red "[$(Get-Date -format G)] Error: No valid IPv4 address found in ipconfig output."
            throw "No IPv4 address found"
        }

        $firstTwoOctets = $ipAddress.Split('.')[0..1] -join '.'
        Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Extracted IP prefix: $firstTwoOctets"

        # Match server
        if ($ipPrefixes.ContainsKey($firstTwoOctets)) {
            $serverName = $ipPrefixes[$firstTwoOctets]
            $localImageFileUrl = "$serverName/$($global:OSDCloudWorkflowInit.ImageFileName)"
            $localDriverPackUrl = "$serverName/$($global:OSDCloudWorkflowInit.DriverPackObject.FileName)"
        }
        else {
            Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] No matching IP prefix found."
        }
    }
    catch {
        Write-Host -ForegroundColor Red "[$(Get-Date -format G)] Failed to retrieve IP address: $($_.Exception.Message)"
        Write-Error "Failed to retrieve IP address: $($_.Exception.Message)"
    }

    #-------------------------------------------------
    # Try to reach local OS Image
    if ($localImageFileUrl) {
        try {
            Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Attempting to reach the local OS Image Url at $localImageFileUrl"
            $WebRequest = Invoke-WebRequest -Uri $localImageFileUrl -UseBasicParsing -Method Head
            if ($WebRequest.StatusCode -eq 200) {
                Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Local OS Image URL returned a 200 status code. OK."
                $global:OSDCloudWorkflowInit.OperatingSystemObject.Url = $localImageFileUrl
            }
        }
        catch {
            Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Local OS Image URL is not reachable."
        }
    }

    #-------------------------------------------------
    # Try to reach local Driver Pack
    if ($localDriverPackUrl) {
        try {
            Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Attempting to reach the local Driver Pack Url at $localDriverPackUrl"
            $WebRequest = Invoke-WebRequest -Uri $localDriverPackUrl -UseBasicParsing -Method Head
            if ($WebRequest.StatusCode -eq 200) {
                Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Local Driver Pack URL returned a 200 status code. OK."
                $global:OSDCloudWorkflowInit.DriverPackObject.Url = $localDriverPackUrl
            }
        }
        catch {
            Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Local Driver Pack URL is not reachable."
        }
    }
    #=================================================
    # End the function
    $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] End"
    Write-Verbose -Message $Message; Write-Debug -Message $Message
    #=================================================
}