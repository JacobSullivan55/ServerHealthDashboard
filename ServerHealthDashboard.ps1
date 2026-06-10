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

    if ($PingStatus -and $DNSStatus -eq "Success" -and $HTTPSStatus) {
        $OverallStatus = "Healthy"
    }
    elseif ($DNSStatus -eq "Success") {
        $OverallStatus = "Warning"
    }
    else {
        $OverallStatus = "Critical"
    }

    [PSCustomObject]@{
        Server        = $ServerName
        OverallStatus = $OverallStatus
        Reachable     = $PingStatus
        DNS           = $DNSStatus
        HTTPS443      = $HTTPSStatus
        TimeChecked   = Get-Date
    }
}

$Results | Format-Table -AutoSize

$Results | Export-Csv ".\Reports\ServerHealthReport.csv" -NoTypeInformation

$TotalServers = $Results.Count
$HealthyServers = ($Results | Where-Object {$_.OverallStatus -eq "Healthy"}).Count
$WarningServers = ($Results | Where-Object {$_.OverallStatus -eq "Warning"}).Count
$CriticalServers = ($Results | Where-Object {$_.OverallStatus -eq "Critical"}).Count

if ($TotalServers -gt 0) {
    $HealthyRate = [math]::Round(($HealthyServers / $TotalServers) * 100, 2)
}
else {
    $HealthyRate = 0
}

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

.summary {
    background-color: white;
    padding: 15px;
    border: 1px solid #dddddd;
    margin-bottom: 20px;
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

.healthy {
    background-color: #c6efce;
    color: #006100;
    font-weight: bold;
}

.warning {
    background-color: #ffeb9c;
    color: #9c6500;
    font-weight: bold;
}

.critical {
    background-color: #ffc7ce;
    color: #9c0006;
    font-weight: bold;
}
</style>
</head>
<body>

<h1>Server Health Dashboard</h1>

<p><strong>Report generated:</strong> $(Get-Date)</p>

<div class="summary">
<h2>Summary</h2>

<p><strong>Servers Checked:</strong> $TotalServers</p>
<p><strong>Healthy:</strong> $HealthyServers</p>
<p><strong>Warning:</strong> $WarningServers</p>
<p><strong>Critical:</strong> $CriticalServers</p>
<p><strong>Healthy Rate:</strong> $HealthyRate%</p>
</div>

<table>
<tr>
<th>Server</th>
<th>Status</th>
<th>Reachable</th>
<th>DNS</th>
<th>HTTPS 443</th>
<th>Time Checked</th>
</tr>
"@

foreach ($Result in $Results) {

    $StatusClass = $Result.OverallStatus.ToLower()

    $HtmlReport += @"
<tr>
<td>$($Result.Server)</td>
<td class="$StatusClass">$($Result.OverallStatus)</td>
<td>$($Result.Reachable)</td>
<td>$($Result.DNS)</td>
<td>$($Result.HTTPS443)</td>
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