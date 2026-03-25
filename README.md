# Intune ADE Token Monitoring (PRTG)

Dieses PowerShell-Script überwacht die Ablaufdaten von **Apple
Enrollment Program (ADE) Tokens** in Microsoft Intune und gibt die
Ergebnisse im Format eines **PRTG EXE/Script Advanced Sensors** aus.

------------------------------------------------------------------------

## 🚀 Features

-   Überwachung aller ADE Tokens im Tenant
-   Ermittlung des **frühesten Ablaufdatums**
-   Anzeige von:
    -   Tage bis Ablauf
    -   Stunden bis Ablauf
    -   Anzahl Tokens (gesamt / warning / critical / expired)
    -   Optional:
        -   Tage seit letztem Sync
        -   Tage seit letzter Aktualisierung
-   **PRTG-kompatible JSON-Ausgabe**
-   **ASCII-sichere Ausgabe** (keine Unicode-/Encoding-Probleme)
-   Detaillierte Fehlerausgabe bei Graph/API-Problemen

------------------------------------------------------------------------

## 📋 Voraussetzungen

-   PRTG Network Monitor
-   PowerShell (auf Probe oder Core Server)
-   Internetzugriff auf:
    -   login.microsoftonline.com
    -   graph.microsoft.com
-   Microsoft Intune Tenant

### 🔐 Microsoft Entra App Registration

Erforderliche Einstellungen:

-   API Permission (Application): DeviceManagementServiceConfig.Read.All
-   Admin Consent: erforderlich
-   Authentifizierung:
    -   Client ID
    -   Client Secret (Value!)

------------------------------------------------------------------------

## ⚙️ Verwendung in PRTG

### Sensor-Typ

EXE/Script Advanced

### Parameter

-TenantId "%scriptplaceholder1" -ClientId "%scriptplaceholder2"
-ClientSecret "%scriptplaceholder3" -WarningDays 30 -ErrorDays 7

### Platzhalter

-   %scriptplaceholder1 = Tenant ID
-   %scriptplaceholder2 = Client ID
-   %scriptplaceholder3 = Client Secret

------------------------------------------------------------------------

## 📊 Sensor-Channels

-   Days Until Earliest Expiry -- Tage bis zum frühesten Ablauf
-   Hours Until Earliest Expiry -- Stunden bis zum frühesten Ablauf
-   ADE Token Count -- Anzahl aller Tokens
-   Tokens In Warning -- Tokens unter Warning-Schwelle
-   Tokens Critical -- Tokens unter Error-Schwelle
-   Tokens Expired -- Bereits abgelaufene Tokens
-   Days Since Last Successful Sync -- optional
-   Days Since Token Update -- optional

------------------------------------------------------------------------

## 🔔 Schwellenwerte

Standard: - Warning: 30 Tage - Error: 7 Tage

------------------------------------------------------------------------

## 🧠 Funktionsweise

1.  Authentifizierung gegen Microsoft Entra ID
2.  Abruf der ADE Tokens über Graph API:
    https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings
3.  Auswertung der Ablaufdaten
4.  Rückgabe an PRTG als JSON

------------------------------------------------------------------------

## ⚠️ Hinweis

-   Verwendet Graph /beta Endpoint
-   Tokens sind 365 Tage gültig
-   Änderungen an API möglich

------------------------------------------------------------------------

## 🛠 Troubleshooting

### Encoding Fehler (PE231)

Bereits durch ASCII-Normalisierung gelöst

### Auth Fehler

-   Client Secret prüfen
-   Admin Consent prüfen
-   Permissions prüfen

### Keine Daten

-   ADE Token vorhanden?
-   Intune korrekt?

------------------------------------------------------------------------

## 📌 Empfehlung

-   Intervall: täglich
-   Primary Channel: Days Until Earliest Expiry

------------------------------------------------------------------------

## 👤 Autor
RASC79
