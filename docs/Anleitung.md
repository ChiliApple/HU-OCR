# HU-OCR – Anleitung

Portable OCR-Lösung für gescannte PDFs. Automatische Texterkennung (Deutsch), Ausgabe als durchsuchbare PDF/A. Optional: automatische Umbenennung nach Keyword-Regeln.

## Was das Tool macht

```
Scan-Eingang\datei.pdf
        ↓  (automatisch erkannt, Debounce 2s)
   OCR (Deutsch, Deskew, Auto-Rotate, PDF/A)
        ↓  (optional: Text-Extraktion + Keyword-Matching)
Scan-Ausgang\{Praefix}_{Timestamp}.pdf   (oder Originalname)
processed\datei.pdf                      (Original-Backup)
```

- **Eingangsordner** – hier legt der Scanner die PDFs ab
- **Ausgangsordner** – hier landen die durchsuchbaren PDFs (Name je nach Regel)
- **processed** – das Original (Backup)
- **quarantine** – fehlerhafte PDFs (mit Log-Eintrag)

## Dateien im Tool-Ordner

```
HU-OCR\
├── Start-OCR.cmd          ← Normaler Start (doppelklicken)
├── Config-OCR.cmd         ← Ordner neu wählen
├── Rules-OCR.cmd          ← Naming-Regeln editieren
├── Pull-OCR.cmd           ← Update aus GitHub ziehen
├── Reset-OCR.cmd          ← Clean-Test (bin\, config, logs löschen)
├── config.json            ← deine Einstellungen (wird beim First-Run erzeugt)
├── config.default.json    ← Vorlage (nicht löschen)
├── assets\icon.ico        ← Icon für GUI + Konsolen-Titel
├── docs\                  ← README, Anleitung, LICENSE, NOTICE
├── scripts\               ← PowerShell-Skripte (nicht direkt aufrufen)
└── bin\                   ← wird beim First-Run befüllt (ca. 400 MB)
```

## Erster Start (First-Run)

1. Ordner `HU-OCR` an beliebigen Pfad kopieren (z.B. `C:\Tools\HU-OCR`).
2. Internet-Verbindung sicherstellen.
3. `Start-OCR.cmd` doppelklicken.
4. Der erste Start lädt automatisch Python, Tesseract, Ghostscript, qpdf (~400 MB, 5–15 Minuten).
5. Ordner-Auswahl-Fenster erscheint:
   - Standard-Vorschlag: `Scan-Eingang` + `Scan-Ausgang` direkt im Tool-Ordner
   - Button „Durchsuchen" öffnet den Explorer im Tool-Ordner
   - Eigene Ordner wählbar (auch UNC-Pfade `\\server\share\...`)
6. „Speichern" → Watcher startet.

## Normaler Betrieb

- `Start-OCR.cmd` doppelklicken → Watcher startet sofort
- PDFs in `Scan-Eingang` ablegen → nach ~5-30 Sekunden erscheint OCR-Ergebnis in `Scan-Ausgang`
- Original wird in `processed` verschoben
- **Beenden:** STRG+C im Konsolenfenster

## Naming-Regeln (automatische Dateinamen)

`Rules-OCR.cmd` doppelklicken → Regel-Editor öffnet sich.

**Pro Regel einstellbar:**
- **Name** – nur zur Übersicht (z.B. „Rechnung Energie")
- **Keywords** – eine Zeile pro Wort (z.B. `Energiegemeinschaft`, `Stromrechnung`)
- **MatchMode** – `any` (ein Keyword reicht) oder `all` (alle müssen vorkommen)
- **Prefix** – kommt in den Dateinamen (z.B. `RE_Energie`)
- **Priority** – bei mehreren Treffern gewinnt die höchste (0-99)
- **Enabled** – Haken im ListView = aktiv

**Globale Einstellungen im Editor:**
- **Naming-Regeln aktiv** – Master-Schalter
- **Template (Treffer)** – z.B. `{Prefix}_{Timestamp}` ergibt `RE_Energie_20260415-1204.pdf`
- **Template (Kein Treffer)** – z.B. `{OriginalName}` behält den Dateinamen
- Platzhalter: `{Prefix}`, `{Timestamp}`, `{OriginalName}`

**Matching-Verhalten:**
- Case-insensitive
- Diakritika-tolerant (`ä` = `a`, `ß` = `ss` etc.)
- Whitespace-tolerant (auch über Zeilenumbrüche hinweg: `IT-\nInfrastruktur` matcht `IT-Infrastruktur`)
- Liest ersten `NamingTextBytes` Bytes der Output-PDF (Default 2048)
- Text-Extraktion per `pdfminer` (Text-Layer + OCR-Text, beides)

**Troubleshooting bei Naming-Regeln:**
- Setze in `config.json` `NamingDebug: true` → detaillierte Logs (Sidecar-Text + Keyword-Prüfung pro Regel)
- WARNUNG: Mit `NamingDebug: true` landen PDF-Textauszüge in Log-Files → DSGVO-Aspekt beachten
- Default ist `false` (keine PDF-Inhalte in Logs)

## Updates

Beim Start prüft das Tool selbstständig auf neue Versionen (GitHub). Bei neuer Version:

```
  !!  NEUE VERSION VERFUEGBAR: v1.5.0  (aktuell v1.4.0)  !!
  Jetzt updaten? (j/N):
```

- `j` → `Pull.ps1` startet in neuem Fenster, lädt aktuelle Skripte, danach Tool neu starten
- `N` → Tool läuft weiter mit aktueller Version

**Manuelles Update:** `Pull-OCR.cmd` doppelklicken.

## Ordner neu wählen

`Config-OCR.cmd` doppelklicken → GUI öffnet sich, neue Ordner auswählen, speichern.

## Komplett zurücksetzen (Clean Test)

`Reset-OCR.cmd` doppelklicken.

Löscht `bin\`, `logs\`, `processed\`, `quarantine\`, `.firstrun.done`, `config.json`.
**Bleibt erhalten:** Skripte + `config.default.json` + `docs\` + `assets\`.

Nächster Start = vollständiger First-Run.

## Netzwerkpfade

UNC-Pfade (`\\server\share\scan-in\`) werden automatisch erkannt:
- Reconnect bei Share-Ausfall
- Health-Check alle 30s
- Größerer FSW-Buffer (64 KB)

Empfehlung: gemapptes Laufwerk (z.B. `Z:\scan-in\`) ist robuster als reines UNC.

## Fehlersuche

**Nichts passiert nach PDF-Ablage:**
- Konsolenfenster offen und zeigt „Starte Watcher"? Sonst: `Start-OCR.cmd` erneut starten.
- PDF wirklich im konfigurierten Eingangsordner? Pfad steht im Konsolenfenster.

**Datei landet in `quarantine\`:**
- Log ansehen: `logs\ocr_YYYY-MM-DD.log`
- Mögliche Ursachen: beschädigte PDF, verschlüsselt, kein Lesezugriff

**OCR fehlgeschlagen (Timeout):**
- Standard-Timeout 5 Minuten pro Datei
- Bei sehr großen PDFs in `config.json`: `OcrTimeoutSec` erhöhen

**Regel greift nicht obwohl Keyword im Dokument:**
- Prüfe ob Keyword im Text-Layer steht (nicht nur im Bild/Logo)
- Bei Logo-Text: `--skip-text` in `OcrArguments` durch `--redo-ocr` ersetzen (CPU-intensiver)
- `NamingDebug: true` aktivieren und erneut testen – zeigt den extrahierten Text

## Deploy auf neuen PC

**Option A (offline):** Kompletten Ordner inkl. `bin\` kopieren → sofort lauffähig.

**Option B (online):** Nur diese Dateien/Ordner kopieren:
```
Start-OCR.cmd
Reset-OCR.cmd
Config-OCR.cmd
Rules-OCR.cmd
Pull-OCR.cmd
config.default.json
scripts\       (kompletter Ordner)
docs\          (kompletter Ordner)
assets\        (kompletter Ordner)
```
→ `Start-OCR.cmd` starten → First-Run läuft, lädt alle Abhängigkeiten.

## Autostart

Aufgabenplanung:
- Neue Aufgabe
- Trigger: Bei Anmeldung
- Aktion: `...\HU-OCR\Start-OCR.cmd`
- Einstellung: „Nur ausführen wenn Benutzer angemeldet ist"

## Sicherheit

- Keine System-Installation (Python/Tesseract etc. nur in `bin\`)
- Keine Admin-Rechte nötig
- Alle OCR-Verarbeitung lokal, keine Cloud-Uploads
- Update-Check ist eine reine HTTP-GET-Anfrage an GitHub (public, unauthentifiziert)
- PDF-Inhalte gelangen NUR bei `NamingDebug: true` in die Log-Files

## Lizenz

- HU-OCR-Skripte: **MIT** – siehe [LICENSE](./LICENSE)
- Third-Party-Tools: eigene Lizenzen beim First-Run akzeptiert – siehe [NOTICE.md](./NOTICE.md)
- **Ghostscript** ist **AGPL-3.0** – Details in [NOTICE.md](./NOTICE.md)

## Config-Datei

`config.json` im Tool-Ordner. Änderbar mit Texteditor:

| Feld | Bedeutung |
|---|---|
| `InputFolder` / `OutputFolder` | Scan-Ordner |
| `ProcessedFolder` / `QuarantineFolder` | Backup / Fehlerhafte PDFs |
| `OcrArguments` | ocrmypdf-Kommandozeilen-Optionen |
| `OcrTimeoutSec` | Mindest-Timeout pro Datei (Standard 300s) |
| `OcrTimeoutPerMbSec` | Sekunden pro MB Dateigröße (Standard 60). Effektiver Timeout = Max(OcrTimeoutSec, Dateigröße×OcrTimeoutPerMbSec). Beispiel: 67 MB → 67×60 = 4020s |
| `LogRetentionDays` | Log-Dateien älter als X Tage werden gelöscht |
| `NamingEnabled` | Master-Schalter für Regel-Engine |
| `NamingTemplate` | Dateinamens-Vorlage bei Treffer |
| `NamingTemplateFallback` | Vorlage ohne Treffer |
| `NamingTextBytes` | Wie viele Bytes der Output-PDF geprüft werden (Default 2048) |
| `NamingDebug` | PDF-Text in Logs (Default false) |
| `NamingRules` | Array aus Name/Keywords/MatchMode/Prefix/Priority/Enabled |
| `Downloads` | URLs der Bootstrap-Komponenten |
