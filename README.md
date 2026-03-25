# Intune ADE Token Monitoring (PRTG)

Dieses PowerShell-Script überwacht die Ablaufdaten von **Apple Enrollment Program (ADE) Tokens** in Microsoft Intune und gibt die Ergebnisse im Format eines **PRTG EXE/Script Advanced Sensors** aus.

---

## 🚀 Features

- Überwachung aller ADE Tokens im Tenant
- Ermittlung des **frühesten Ablaufdatums**
- Anzeige von:
  - Tage bis Ablauf
  - Stunden bis Ablauf
  - Anzahl Tokens (gesamt / warning / critical / expired)
  - Optional:
    - Tage seit letztem Sync
    - Tage seit letzter Aktualisierung
- **PRTG-kompatible JSON-Ausgabe**
- **ASCII-sichere Ausgabe** (keine Unicode-/Encoding-Probleme)
- Detaillierte Fehlerausgabe bei Graph/API-Problemen

---

## 📋 Voraussetzungen

- PRTG Network Monitor
- PowerShell (auf Probe oder Core Server)
- Internetzugriff auf:
  - `login.microsoftonline.com`
  - `graph.microsoft.com`
- Microsoft Intune Tenant

### 🔐 Microsoft Entra App Registration

Erforderliche Einstellungen:

- **API Permission (Application):**
  
