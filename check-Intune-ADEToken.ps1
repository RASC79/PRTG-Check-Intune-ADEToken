<#
.SYNOPSIS
    Überwacht die Ablaufdaten von Apple Enrollment Program (ADE) Tokens in Microsoft Intune.

.DESCRIPTION
    Dieses Script ruft über die Microsoft Graph API alle vorhandenen ADE Tokens (depOnboardingSettings)
    ab und ermittelt das früheste Ablaufdatum.

    Die Ergebnisse werden im JSON-Format für einen PRTG EXE/Script Advanced Sensor ausgegeben.
    Der Sensor überwacht insbesondere:
        - Tage bis zum frühesten Ablauf
        - Anzahl vorhandener Tokens
        - Anzahl kritischer / ablaufender Tokens

    Das Script ist für den Einsatz auf einem PRTG Probe Server vorgesehen.

.AUTHOR
   Raphael Schlegel

.COMPANY
    Bechtle Schweiz AG

.VERSION
    1.0.0

.DATE
    2026-03-25

.PURPOSE
    Frühzeitige Erkennung ablaufender ADE Tokens zur Vermeidung von
    Enrollment-Problemen bei Apple Geräten (DEP/ADE).

.REQUIREMENTS
    - Microsoft Entra App Registration
    - Application Permission: DeviceManagementServiceConfig.Read.All
    - Admin Consent erteilt
    - Zugriff auf Microsoft Graph API
    - Internetzugriff vom PRTG Probe Server

.PARAMETER TenantId
    Azure / Entra Tenant ID

.PARAMETER ClientId
    Client ID der App Registration

.PARAMETER ClientSecret
    Client Secret (Value) der App Registration

.PARAMETER WarningDays
    Schwellwert für Warnung (Standard: 30 Tage)

.PARAMETER ErrorDays
    Schwellwert für Fehler (Standard: 7 Tage)

.OUTPUT
    JSON im PRTG Advanced Sensor Format

.NOTES
    - Verwendet Microsoft Graph API (beta Endpoint für depOnboardingSettings)
    - Änderungen an der Graph API können Anpassungen erforderlich machen
    - Script ist für automatisierte Ausführung vorgesehen (kein interaktiver Login)

.CHANGELOG
    1.0.0 - Initiale Version
#>
param(
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret,
    [int]$WarningDays = 30,
    [int]$ErrorDays = 7
)

$ErrorActionPreference = 'Stop'

function Write-PrtgResult {
    param(
        [string]$Text,
        [array]$Results
    )

    $Text = ($Text -replace "`r|`n", ' ').Trim()

    $output = @{
        prtg = @{
            text   = $Text
            result = $Results
        }
    }

    Write-Output ($output | ConvertTo-Json -Depth 10 -Compress)
    exit 0
}

function Write-PrtgError {
    param(
        [string]$Text
    )

    $Text = ($Text -replace "`r|`n", ' ').Trim()

    $output = @{
        prtg = @{
            error = 1
            text  = $Text
        }
    }

    Write-Output ($output | ConvertTo-Json -Depth 10 -Compress)
    exit 1
}

function Get-ErrorDetails {
    param(
        [System.Management.Automation.ErrorRecord]$Err
    )

    $message = $Err.Exception.Message

    try {
        $response = $Err.Exception.Response
        if ($null -ne $response) {
            $stream = $response.GetResponseStream()
            if ($null -ne $stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()

                if (-not [string]::IsNullOrWhiteSpace($body)) {
                    try {
                        $json = $body | ConvertFrom-Json

                        if ($json.error_description) {
                            return "$($json.error): $($json.error_description)"
                        }

                        if ($json.error.message) {
                            return $json.error.message
                        }

                        if ($json.error.code -and $json.error.message) {
                            return "$($json.error.code): $($json.error.message)"
                        }

                        return ($body -replace "`r|`n", ' ').Trim()
                    }
                    catch {
                        return ($body -replace "`r|`n", ' ').Trim()
                    }
                }
            }
        }
    }
    catch {
    }

    return ($message -replace "`r|`n", ' ').Trim()
}

function Get-GraphToken {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )

    $tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    $tokenBody = "client_id=$([uri]::EscapeDataString($ClientId))&" +
                 "client_secret=$([uri]::EscapeDataString($ClientSecret))&" +
                 "scope=$([uri]::EscapeDataString('https://graph.microsoft.com/.default'))&" +
                 "grant_type=client_credentials"

    Invoke-RestMethod `
        -Method Post `
        -Uri $tokenUri `
        -Body $tokenBody `
        -ContentType "application/x-www-form-urlencoded"
}

try {
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        Write-PrtgError "TenantId fehlt."
    }

    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        Write-PrtgError "ClientId fehlt."
    }

    if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
        Write-PrtgError "ClientSecret fehlt."
    }

    if ($WarningDays -lt 1) {
        Write-PrtgError "WarningDays muss groesser als 0 sein."
    }

    if ($ErrorDays -lt 1) {
        Write-PrtgError "ErrorDays muss groesser als 0 sein."
    }

    if ($ErrorDays -ge $WarningDays) {
        Write-PrtgError "ErrorDays muss kleiner als WarningDays sein."
    }

    $tokenResponse = Get-GraphToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

    if (-not $tokenResponse.access_token) {
        Write-PrtgError "Kein Access Token von Microsoft Entra erhalten."
    }

    $headers = @{
        Authorization = "Bearer $($tokenResponse.access_token)"
        Accept        = "application/json"
    }

    $uri = "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings"
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers

    if (-not $response.value) {
        Write-PrtgError "Keine ADE / Enrollment Program Tokens gefunden."
    }

    $nowUtc = (Get-Date).ToUniversalTime()

    $tokenObjects = @()

    foreach ($item in $response.value) {
        if (-not $item.tokenExpirationDateTime) {
            continue
        }

        $expiryUtc = [datetime]::Parse($item.tokenExpirationDateTime).ToUniversalTime()
        $daysLeft  = [math]::Floor(($expiryUtc - $nowUtc).TotalDays)
        $hoursLeft = [math]::Floor(($expiryUtc - $nowUtc).TotalHours)

        $lastSyncDays = $null
        if ($item.lastSuccessfulSyncDateTime) {
            $lastSyncUtc = [datetime]::Parse($item.lastSuccessfulSyncDateTime).ToUniversalTime()
            $lastSyncDays = [math]::Floor(($nowUtc - $lastSyncUtc).TotalDays)
        }

        $renewalDays = $null
        if ($item.lastModifiedDateTime) {
            $modifiedUtc = [datetime]::Parse($item.lastModifiedDateTime).ToUniversalTime()
            $renewalDays = [math]::Floor(($nowUtc - $modifiedUtc).TotalDays)
        }

        $tokenObjects += [pscustomobject]@{
            Id                     = $item.id
            AppleIdentifier        = if ($item.appleIdentifier) { $item.appleIdentifier } else { 'n/a' }
            ExpiryUtc              = $expiryUtc
            DaysLeft               = $daysLeft
            HoursLeft              = $hoursLeft
            LastSyncDays           = $lastSyncDays
            DaysSinceLastModified  = $renewalDays
        }
    }

    if (-not $tokenObjects -or $tokenObjects.Count -eq 0) {
        Write-PrtgError "Tokens gefunden, aber kein tokenExpirationDateTime verfuegbar."
    }

    $sorted = $tokenObjects | Sort-Object DaysLeft
    $worstToken = $sorted | Select-Object -First 1

    $expiredCount  = ($tokenObjects | Where-Object { $_.DaysLeft -lt 0 }).Count
    $warningCount  = ($tokenObjects | Where-Object { $_.DaysLeft -ge 0 -and $_.DaysLeft -le $WarningDays }).Count
    $criticalCount = ($tokenObjects | Where-Object { $_.DaysLeft -ge 0 -and $_.DaysLeft -le $ErrorDays }).Count
    $tokenCount    = $tokenObjects.Count

    $statusPrefix = if ($worstToken.DaysLeft -lt 0) {
        "ADE Token abgelaufen"
    }
    elseif ($worstToken.DaysLeft -le $ErrorDays) {
        "ADE Token kritisch"
    }
    elseif ($worstToken.DaysLeft -le $WarningDays) {
        "ADE Token Warnung"
    }
    else {
        "ADE Token OK"
    }

    $statusText = "{0}: fruehester Ablauf in {1} Tagen | Apple ID: {2} | Ablauf: {3} UTC | Tokens gesamt: {4} | Warnung: {5} | Kritisch: {6} | Abgelaufen: {7}" -f `
        $statusPrefix,
        $worstToken.DaysLeft,
        $worstToken.AppleIdentifier,
        $worstToken.ExpiryUtc.ToString("yyyy-MM-dd HH:mm:ss"),
        $tokenCount,
        $warningCount,
        $criticalCount,
        $expiredCount

    $results = @(
        @{
            channel         = "Days Until Earliest Expiry"
            value           = $worstToken.DaysLeft
            unit            = "Count"
            float           = 0
            LimitMode       = 1
            LimitMinWarning = $WarningDays
            LimitMinError   = $ErrorDays
        },
        @{
            channel = "Hours Until Earliest Expiry"
            value   = $worstToken.HoursLeft
            unit    = "Count"
            float   = 0
        },
        @{
            channel = "ADE Token Count"
            value   = $tokenCount
            unit    = "Count"
            float   = 0
        },
        @{
            channel = "Tokens In Warning"
            value   = $warningCount
            unit    = "Count"
            float   = 0
        },
        @{
            channel = "Tokens Critical"
            value   = $criticalCount
            unit    = "Count"
            float   = 0
        },
        @{
            channel = "Tokens Expired"
            value   = $expiredCount
            unit    = "Count"
            float   = 0
        }
    )

    if ($null -ne $worstToken.LastSyncDays) {
        $results += @{
            channel = "Days Since Last Successful Sync"
            value   = $worstToken.LastSyncDays
            unit    = "Count"
            float   = 0
        }
    }

    if ($null -ne $worstToken.DaysSinceLastModified) {
        $results += @{
            channel = "Days Since Token Update"
            value   = $worstToken.DaysSinceLastModified
            unit    = "Count"
            float   = 0
        }
    }

    Write-PrtgResult -Text $statusText -Results $results
}
catch {
    $details = Get-ErrorDetails -Err $_
    Write-PrtgError $details
}