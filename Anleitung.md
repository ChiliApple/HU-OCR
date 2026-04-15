# HU-OCR – Anleitung

Portable OCR-Lösung für gescannte PDFs. Automatische Texterkennung (Deutsch), Ausgabe als durchsuchbare PDF/A.

## Was das Tool macht

```
Scan-Eingang\datei.pdf
        ↓  (automatisch erkannt, Debounce 2s)
   OCR (Deutsch, Deskew, Auto-Rotate, PDF/A)
        ↓
Scan-Ausgang\datei.pdf   +   processed\datei.pdf (Original)
```

- **Eingangsordner** – hier legt der Scanner die PDFs ab
- **Ausgangsordner** – hier landen die durchsuchbaren PDFs
- **processed** – das Original (Backup)
- **quarantine** – fehlerhafte PDFs (mit Log-Eintrag)

## Dateien im Tool-Ordner

```
HU-OCR\
├── Start-OCR.cmd          ← Normaler Start (doppelklicken)
├── Config-OCR.cmd         ← Ordner neu wählen
├── Pull-OCR.cmd           ← Update aus GitHub ziehen
├── Reset-OCR.cmd          ← Clean-Test (bin\, config, logs löschen)
├── config.json            ← deine Einstellungen (wird beim First-Run erzeugt)
├── config.default.json    ← Vorlage (nicht löschen)
├── LICENSE / NOTICE.md    ← Lizenz + Third-Party-Hinweise
├── README.md              ← Kurzübersicht
├── Anleitung.md           ← diese Datei
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
   - Eigene Ordner wählbar
6. „Speichern" → Watcher startet.

Das Konsolenfenster bleibt offen und zeigt:
```
Starte Watcher: ...\Scan-Eingang
STRG+C zum Beenden.
```

## Normaler Betrieb

- `Start-OCR.cmd` doppelklicken → Watcher startet sofort
- PDFs in `Scan-Eingang` ablegen → nach ~5-30 Sekunden erscheint OCR-Ergebnis in `Scan-Ausgang`
- Original wird in `processed` verschoben
- **Beenden:** STRG+C im Konsolenfenster

## Updates

Beim Start prüft das Tool selbstständig auf neue Versionen (GitHub). Bei neuer Version:

```
  !!  NEUE VERSION VERFUEGBAR: v1.2.0  (aktuell v1.1.0)  !!
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
**Bleibt erhalten:** Skripte + `config.default.json`.

Nächster Start = vollständiger First-Run.

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

**Update-Check antwortet nicht:**
- Harmlos, Tool läuft normal weiter. Nur Info-Meldung im Log.

## Deploy auf neuen PC

**Option A (offline):** Kompletten Ordner inkl. `bin\` kopieren → sofort lauffähig.

**Option B (online):** Nur diese Dateien/Ordner kopieren:
```
Start-OCR.cmd
Reset-OCR.cmd
Config-OCR.cmd
Pull-OCR.cmd
config.default.json
LICENSE
NOTICE.md
README.md
Anleitung.md
scripts\      (kompletter Ordner)
```
→ `Start-OCR.cmd` starten → First-Run läuft, lädt alle Abhängigkeiten.

## Autostart

Aufgabenplanung:
- Neue Aufgabe
- 