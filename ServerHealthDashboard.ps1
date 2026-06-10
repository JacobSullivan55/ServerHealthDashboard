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
    elseif ($DNSStatus -eq "Success" -and $HTTPSStatus) {
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
    font-family: Arial, sans-serif;
    background-color: #eef1f5;
    margin: 0;
    padding: 30px;
    color: #222;
}

.header {
    background-color: #1f2937;
    color: white;
    padding: 25px;
    border-radius: 10px;
    margin-bottom: 20px;
}

.header h1 {
    margin: 0;
    font-size: 32px;
}

.header p {
    margin: 8px 0 0 0;
    color: #d1d5db;
}

.cards {
    display: flex;
    gap: 15px;
    margin-bottom: 20px;
}

.card {
    background-color: white;
    border-radius: 10px;
    padding: 20px;
    flex: 1;
    box-shadow: 0 2px 6px rgba(0,0,0,0.12);
    text-align: center;
}

.card h2 {
    margin: 0;
    font-size: 16px;
    color: #555;
}

.card p {
    font-size: 34px;
    font-weight: bold;
    margin: 10px 0 0 0;
}

.healthyText {
    color: #15803d;
}

.warningText {
    color: #b45309;
}

.criticalText {
    color: #b91c1c;
}

.legend {
    background-color: white;
    padding: 15px;
    border-radius: 10px;
    margin-bottom: 20px;
    box-shadow: 0 2px 6px rgba(0,0,0,0.12);
}

.legend h2 {
    margin-top: 0;
}

.progressContainer {
    background-color: #d1d5db;
    border-radius: 20px;
    overflow: hidden;
    height: 24px;
    margin-top: 10px;
}

.progressBar {
    background-color: #15803d;
    width: $HealthyRate%;
    height: 100%;
    text-align: center;
    color: white;
    font-weight: bold;
    line-height: 24px;
}

table {
    border-collapse: collapse;
    width: 100%;
    background-color: white;
    border-radius: 10px;
    overflow: hidden;
    box-shadow: 0 2px 6px rgba(0,0,0,0.12);
}

th {
    background-color: #111827;
    color: white;
    padding: 12px;
}

td {
    border-bottom: 1px solid #e5e7eb;
    padding: 12px;
    text-align: center;
}

.badge {
    padding: 6px 12px;
    border-radius: 999px;
    font-weight: bold;
    display: inline-block;
}

.healthy {
    background-color: #dcfce7;
    color: #166534;
}

.warning {
    background-color: #fef3c7;
    color: #92400e;
}

.critical {
    background-color: #fee2e2;
    color: #991b1b;
}

.footer {
    margin-top: 20px;
    color: #555;
    font-size: 14px;
}
</style>
</head>
<body>

<div class="header">
    <h1>Server Health Dashboard</h1>
    <p>Infrastructure Monitoring Report | Generated: $(Get-Date)</p>
</div>

<div class="cards">
    <div class="card">
        <h2>Total Checked</h2>
        <p>$TotalServers</p>
    </div>
    <div class="card">
        <h2>Healthy</h2>
        <p class="healthyText">$HealthyServers</p>
    </div>
    <div class="card">
        <h2>Warning</h2>
        <p class="warningText">$WarningServers</p>
    </div>
    <div class="card">
        <h2>Critical</h2>
        <p class="criticalText">$CriticalServers</p>
    </div>
</div>

<div class="legend">
    <h2>Overall Health: $HealthyRate%</h2>
    <div class="progressContainer">
        <div class="progressBar">$HealthyRate%</div>
    </div>
    <p><strong>Healthy:</strong> Ping, DNS, and HTTPS checks passed.</p>
    <p><strong>Warning:</strong> DNS and HTTPS work, but ping may be blocked.</p>
    <p><strong>Critical:</strong> DNS or service checks failed.</p>
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
<td><span class="badge $StatusClass">$($Result.OverallStatus)</span></td>
<td>$($Result.Reachable)</td>
<td>$($Result.DNS)</td>
<td>$($Result.HTTPS443)</td>
<td>$($Result.TimeChecked)</td>
</tr>
"@
}

$HtmlReport += @"
</table>

<div class="footer">
    <p>Generated by ServerHealthDashboard.ps1 using PowerShell.</p>
</div>

</body>
</html>
"@

$HtmlReport | Out-File ".\Reports\ServerHealthDashboard.html"