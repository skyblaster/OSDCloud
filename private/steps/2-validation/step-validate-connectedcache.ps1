function step-validate-connectedcache {
    [CmdletBinding()]
    param ()
    #=================================================
    # Start the step
    $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] Start"
    Write-Debug -Message $Message; Write-Verbose -Message $Message

    if (Test-Path X:\Windows\System32\DhcpOption.exe) {
        $docachehost = & "X:\Windows\System32\DhcpOption.exe" 235

        # Remove all control characters, including NUL (\x00)
        $docachehost = $docachehost -replace '[\x00-\x1F\x7F]', ''

        # Ensure $docachehost is a string or an array, then split and trim
        # DOCacheHost docs - https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference#cache-server-hostname
        $hostArray = @()
        if ($docachehost) {
            if ($docachehost -is [array]) {
                $hostArray = $docachehost | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ }
            } else {
                $hostArray = [string[]]($docachehost -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            }
        }
        if ($hostArray.Count -ne 0) {
            $baseUrl = $global:OSDCloudWorkflowInit.OperatingSystemObject.Url
            $originalHostname = [uri]$baseUrl | Select-Object -ExpandProperty Host

            # Check each host in the array and rewrite URLs on the first successful connection
            foreach ($cacheHostItem in $hostArray) {
                $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] Testing DOCacheHost: '$cacheHostItem'"
                Write-Debug -Message $Message; Write-Verbose -Message $Message
                $doCacheUrl = ($baseUrl -replace "http://[^/]+", "http://$cacheHostItem") + "?cacheHostOrigin=$originalHostname"
                try {
                    $response = Invoke-WebRequest -Uri $doCacheUrl -UseBasicParsing -Method Head -ErrorAction Stop
                    if ($response.StatusCode -eq 200) {
                        $global:OSDCloudWorkflowInit.OperatingSystemObject.Url = $doCacheUrl
                        $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] Connected Cache validation succeeded with host: $cacheHostItem"
                        Write-Host -ForegroundColor Green $Message
                        $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] Updating the Operating System download URL: $doCacheUrl"
                        Write-Host -ForegroundColor Green $Message                       
                        break
                    }
                } catch {
                    Write-Verbose "Invoke-WebRequest failed: $($_.Exception.Message)"
                }
            }
        }
        else {
            $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] DHCP Option 235 returned an empty string"
            Write-Debug -Message $Message; Write-Verbose -Message $Message
            #return $false
        }
    }
    else {
        $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] DhcpOption.exe was not found"
        Write-Debug -Message $Message; Write-Verbose -Message $Message
    }
    #=================================================
    # End the function
    $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] End"
    Write-Verbose -Message $Message; Write-Debug -Message $Message
    #=================================================
}