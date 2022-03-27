# Powershell script that is a real time monitor and logger of destination response times.

Destination response times are measured via either ICMP or round trip time from a specific listening port.

Optional logging into a comma separated file.

MODULES
-------
Requires the Graphical module. https://github.com/PrateekKumarSingh/Graphical
The Graphical module performs the graph plotting functions.

Usage examples
--------------
.\TCPingChart.ps1 -Logging -PollingTime 6 -MaxStepsOnYAxis 10 -XAxisUnits 60
.\TCPingChart.ps1 -Logging -PollingTime 12 -MaxStepsOnYAxis 4 -XAxisUnits 50
.\TCPingChart.ps1 -Logging -LogFile "c:\scripts\tcpinglog.csv" -PollingTime 6 -MaxStepsOnYAxis 10 -XAxisUnits 60
.\TCPingchart.ps1 -ShowXAxisTitle -Pinglist "c:\scripts\tcpinglist.txt"
