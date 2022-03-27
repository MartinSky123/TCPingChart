<#
.SYNOPSIS
Real time plot and log response times to any destination via either ICMP (Ping) or other specified TCP port.

.DESCRIPTION
Read an input file of destinations, and plot out a chart for each one.  The Y-Axis will dynamically adjust as required.
Plots chart in Task Manager mode, rolling from right to left.

.PARAMETER Logging
Default: off
Switch Logging on.

.PARAMETER ShowXAxisTitle
Default: off
Switch X axis title on.

.PARAMETER HorizontalLines
Default: off
Switch horizontal lines on.

.PARAMETER timeout
Default: 2000ms
Time out of the test in ms.

.PARAMETER LogFile
Default: .\tcpingchart.csv
Full path to log file.

.PARAMETER Pinglist
Default: .\tcpinglist.txt
Full path to list of destinations to ping.  Can be IP addresses or FQDNs. Optionally include the port to test, in the format <FQDN>:<Port>.
If the port is not specified, it will default to ICMP (Ping).
Each destination to be on a separate line.
Any ports specified outside of the range 1 to 65535 will be replaced with ICMP (Ping).

Pinglist file example
---------------------
Test the internet beacon site on port 443 and then on ICMP (Ping).

internetbeacon.msedge.net:443
internetbeacon.msedge.net


.PARAMETER PollingTime
Default: 12 seconds.
Number of seconds between pings. 

.PARAMETER XAxisUnits
Default: 60
Minimum: 50
Define the number of units in the X-axis.  

.PARAMETER YAxisStep
Default: 4
Define value of step on y-axis. 

.EXAMPLES
TCPingChart.ps1 -Logging -PollingTime 6 -MaxStepsOnYAxis 10 -XAxisUnits 60
TCPingChart.ps1 -Logging -LogFile "c:\scripts\tcpinglog.csv" -PollingTime 6 -MaxStepsOnYAxis 10 -XAxisUnits 60
TCPingchart.ps1 -ShowXAxisTitle -Pinglist "c:\scripts\tcpinglist.txt"

.MODULES
Requires the Graphical module. https://github.com/PrateekKumarSingh/Graphical
The Graphical module performs the graph plotting functions.

.AUTHOR
Martin Stephenson

.VERSION
1.0

#>
#
Param (
        [switch] $Logging,
        [switch] $ShowXAxisTitle,
        [switch] $HorizontalLines,
        [int]$timeout,
        [string]$LogFile = "tcpingchart.csv",
        [string]$Pinglist = "tcpinglist.txt",
        [int]$PollingTime = 12,              # Polling Interval (secs)
        [int]$XAxisUnits,                    # Minimum of 50
        [int]$MaxStepsOnYAxis = 4
)
    # Set default values for key parameters.
    If (!(($timeout -gt 0) -and ($timeout -le 2000))){
        $timeout = 2000
    }
    if (!($XAxisUnits -ge 50)) {
        $XAxisUnits = 60
    }
    #
    #
    import-module Graphical -Force
    #
    # Clear Vars
    $Dests = ""
    $MyLog = ""
    $MSG = ""
    $script:Logger = ""
    $h = 0                                   # init number of ping hosts
    $global:BadHost = 0
    $DisplayPort = ""
    $Port = 0                                # Port 0 denotes ICMP test.
    #
    $ErrorActionPreference = 'Stop'
    #
    # Init Arrays
    $Dests = Get-Content $Pinglist           # Import ping list into an array
    $NumberofDests = $Dests.Count
    $PingHash = @{}                          # declare hashtable to store all Dests and pings for each.
    $PingHash.hosts = @($Dests)              # hosts key of all Destinations
    # Create a hash key for each Dest & the logging header.
    $LogHeader = "Date, Time, "
    While ($h -lt $NumberofDests) {
        $PingHash.$h = @(0) * $XAxisUnits
        $LogHeader = $LogHeader + $PingHash.hosts[$h] + ", "
        $h = $h + 1
    }
    # Log Header
    If ($Logging) {
        Write-Output $LogHeader | Out-File $LogFile
    }
    #
    function Get-IPAddress ($FQDN) {
        $PingIP = [string][System.Net.Dns]::GetHostAddresses($FQDN).IPAddressToString
        if (($PingIP.Contains(".")) -and ($PingIP.Contains(":"))) {
            #IPV4 & IPV6
            $FQDNArray = $PingIP.Split(" ")
            return $FQDNArray[0]
         } else {
            return $PingIP
         }
    }
    #  
    Function Get-Ping ($site) {
        try {
            $result = Test-Connection -ComputerName $site -Count 1
            $msResponse = $result.responsetime
            if ($msResponse -eq 0) {
                return 1
            } else {
                return [int]$msResponse
            } 
        }
        catch [System.Net.NetworkInformation.PingException] {
            return -1
        }
    }
    #
    Function Get-TCPing ($PingIP,$Port){
            $iar = $null
            $timeMs = $null
            $Count = 0
            try {
                $tcpclient = new-Object system.Net.Sockets.TcpClient # Create TCP Client
                $iar = $tcpclient.ConnectAsync($PingIP, [string]$Port) # Tell TCP Client to connect to machine on Port
                $timeMs = (Measure-Command {
                            $wait = $iar.AsyncWaitHandle.WaitOne($timeout, $false) # Set the wait time
                        }).TotalMilliseconds
                #
                if ($iar.status -eq "RanToCompletion") {
                        $TCPPingResult = [int]$timeMs
                        $tcpclient.Dispose()
                        $tcpclient.Close() 
                        return $TCPPingResult
                    }
                    if ($iar.IsFaulted) {
                        $TCPPingResult = [int]$timeMs
                        $tcpclient.Dispose()
                        $tcpclient.Close() 
                        Return -1
                    }
                #
                while ($iar.status -eq "WaitingForActivation") {
                    $Count = $Count + 1
                    sleep 1
                    If ($Count -ge 3) {
                        clear-host
                        write-host "Testing $PingIP Port:$Port.  Retrying:$Count."
                    }
                    if ($iar.status -eq "RanToCompletion") {
                        $TCPPingResult = [int]$timeMs
                        $tcpclient.Dispose()
                        $tcpclient.Close() 
                        return $TCPPingResult
                    }
                    if ($iar.IsFaulted) {
                        $TCPPingResult = [int]$timeMs
                        $tcpclient.Dispose()
                        $tcpclient.Close() 
                        Return -1
                    }
                }
            }
            catch {
                $tcpclient.Dispose()
                $tcpclient.Close() 
                Return -1
            }
            # Below is redundant?
            if ($tcpclient) {
                $tcpclient.Dispose()
                $tcpclient.Close()
            }
    }
    #
    function TrapBadHost() {
        $global:BadHost = 1
        $global:i = $global:i + 1
        Write-Host "The destination $MyDest could not be contacted." -ForegroundColor Red
        $global:MyLog = $global:MyLog + "no response,"
     }
    #
    function round($n) {
        if($n -ge 3){
            return $($n + (10 - $n % 10))
        } else {
            return [system.math]::Round($n)
        }
    }
    #
    # Logging Functions
    function Log-Message ($MSG) {
    	$script:Logger = "$(get-date -format "dd-MM-yyyy,HH:mm:ss")$MSG"
    }
    # Write contents of log to file.
    function Flush-Log {
        Add-Content $LogFile $script:Logger
    }
    #
    # Main Loop
    do {
        #
        If ($BadHost -eq 0){
            $global:i = 0
        }
        $global:BadHost = 0
        try {
              While ($i -lt $NumberofDests) {                                           # Loop through all Dests.
                $n = 0
                While ($n -le $XAxisUnits - 1) {
                      $PingHash.$i[$n] = $PingHash.$i[$n + 1]                           # make the plot creep to the left from right.
                      $n = $n + 1
                }
                #
                try {
                    $MyDest = $PingHash.hosts[$i]
                    $DestArray = $MyDest.split(":")
                    If (([int]$DestArray[1] -gt 0) -and ([int]$DestArray[1] -le 65535)){
                        $Port = $DestArray[1]
                    } else {
                        $Port = 0  
                    }
                    # $PingIP = [string][System.Net.Dns]::GetHostAddresses($DestArray[0]).IPAddressToString
                    $PingIP = Get-IPAddress $DestArray[0]
                    if ($Port) {
                        # TCP
                           $PingHash.$i[$XAxisUnits - 1] = Get-TCPing $PingIP $Port
                    }
                    else {
                        # ICMP
                        $PingHash.$i[$XAxisUnits - 1] = Get-Ping $PingIP
                    }
                    if ($PingHash.$i[$XAxisUnits - 1] -eq -1) {
                        TrapBadHost
                    }
                }
                catch {
                    TrapBadHost
                }
                #
                If ($BadHost -eq 0){
                    $global:MyLog = $global:MyLog + [string]$PingHash.$i[$XAxisUnits - 1] + ","
                    If ($PingHash.$i[$XAxisUnits - 1] -ge 0) {
                            # Y-Axis Scale
                            $max = ($PingHash.$i[1..($XAxisUnits -1)] | Measure-Object -Maximum).maximum
                            $y = 2
                            while ($true) {
                                if (($Max / $y) -le $MaxStepsOnYAxis) {
                                    $PingStep = round($y)
                                    break
                                }    
                                $y = $y + 1
                            }
                        } else { 
                            Write-Host "The destination $MyDest could not be contacted." -ForegroundColor Red
                            sleep 2
                        }
                    #
                    If ($ShowXAxisTitle) {
                        if ($Port -ge 1) {
                            $DisplayPort = [string]$Port
                        } else {
                            $DisplayPort = "ICMP"
                        }
                        $XAxisTitle = "Logging:" + $Logging + ". Frequency:" + $PollingTime + "s. Port:" + $DisplayPort
                    } else {
                        $XAxisTitle = ""
                    }
                    $Datapoints = $PingHash.$i
                    $Mytitle = "Response (ms) " + [string]$PingHash.hosts[$i]
                    # show-graph with all values of a dest.
                    If ($HorizontalLines) {
                        Show-Graph -datapoints $Datapoints -HorizontalLines -GraphTitle $Mytitle -YAxisStep $PingStep -XAxisTitle $XAxisTitle -Type Scatter -Colormap @{20 = 'green'; 250 = 'yellow'; 1000 = 'red'}
                    } else {
                        Show-Graph -datapoints $Datapoints -GraphTitle $Mytitle -YAxisStep $PingStep -XAxisTitle $XAxisTitle -Type Scatter -Colormap @{20 = 'green'; 250 = 'yellow'; 1000 = 'red'}
                    }
                    # increment dest.
                    $global:i = $global:i + 1  
                  }
                  $global:BadHost = 0
                }
                #
                If ($Logging) {
                    Log-Message ("," + [string]$global:MyLog)
                    Flush-Log
                    $global:MyLog = ""
                }
                #
            }
        catch {
                TrapBadHost
        }
            # Sleep Timer
            If ($BadHost -eq 0){
                Start-Sleep -Seconds $PollingTime
                Clear-Host
            }
    #
    } while ($true)
# End.
