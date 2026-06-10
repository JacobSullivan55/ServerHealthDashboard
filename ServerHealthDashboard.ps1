$Servers = Import-Csv ".\Servers.csv"

$Results = foreach ($Server in $Servers) {

    $ServerName = $Server.ServerName

    $PingStatus = Test-Connection $ServerName -Count 1 -Quiet

    try {
        Resolve-DnsName $ServerName -ErrorAction Stop | Out-Null
        $DNSStatus = "Success"
    }
    catch {
        $DNSStatus = "Failed"
    }

    try {
        $Port443 = Test-NetConnection $ServerName -Port 443 -WarningAction SilentlyContinue
        $HTTPSStatus = $Port443.TcpTestSucceeded
    }
    catch {
        $HTTPSStatus = $false
    }

    [PSCustomObject]@{
        Server      = $ServerName
        Reachable   = $PingStatus
        DNS         = $DNSStatus
        HTTPS443    = $HTTPSStatus
        TimeChecked = Get-Date
    }
}

$Results | Format-Table -AutoSize

$Results | Export-Csv ".\Reports\ServerHealthReport.csv" -NoTypeInformation

$HtmlReport = @"
<html>
<head>
    <title>Server Health Dashboard</title>
    <style>
        body {
            font-family: Arial;
            background-color: #f4f4f4;
            margin: 30px;
        }

        h1 {
            color: #333333;
        }

        table {
            border-collapse: collapse;
            width: 100%;
            background-color: white;
        }

        th {
            background-color: #333333;
            color: white;
            padding: 10px;
        }

        td {
            border: 1px solid #dddddd;
            padding: 10px;
            text-align: center;
        }

        .success {
            background-color: #c6efce;
            color: #006100;
            font-weight: bold;
        }

        .fail {
            background-color: #ffc7ce;
            color: #9c0006;
            font-weight: bold;
        }
    </style>
</head>
<body>

<h1>Server Health Dashboard</h1>

<p>Report generated: $(Get-Date)</p>

<table>
<tr>
    <th>Server</th>
    <th>Reachable</th>
    <th>DNS</th>
    <th>HTTPS 443</th>
    <th>Time Checked</th>
</tr>
"@

foreach ($Result in $Results) {

    $ReachClass = if ($Result.Reachable -eq $true) { "success" } else { "fail" }
    $DNSClass = if ($Result.DNS -eq "Success") { "success" } else { "fail" }
    $HTTPSClass = if ($Result.HTTPS443 -eq $true) { "success" } else { "fail" }

    $HtmlReport += @"
<tr>
    <td>$($Result.Server)</td>
    <td class="$ReachClass">$($Result.Reachable)</td>
    <td class="$DNSClass">$($Result.DNS)</td>
    <td class="$HTTPSClass">$($Result.HTTPS443)</td>
    <td>$($Result.TimeChecked)</td>
</tr>
"@
}

$HtmlReport += @"
</table>

</body>
</html>
"@

$HtmlReport | Out-File ".\Reports\ServerHealthDashboard.html"