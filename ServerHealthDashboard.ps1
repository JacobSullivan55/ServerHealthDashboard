$Servers = Import-Csv ".\Servers.csv"

$Results = foreach ($Server in $Servers) {

    $PingResult = Test-Connection $Server.ServerName -Count 1 -Quiet

    [PSCustomObject]@{
        Server      = $Server.ServerName
        Reachable   = $PingResult
        TimeChecked = Get-Date
    }
}

$Results | Format-Table

$Results | Export-Csv ".\Reports\ServerHealthReport.csv" -NoTypeInformation