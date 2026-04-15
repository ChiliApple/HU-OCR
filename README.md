# HU-OCR

Portable OCR-Lösung für Windows. Überwacht einen Eingangsordner, erkennt neue PDFs automatisch, führt deutsche Texterkennung durch und legt durchsuchbare PDF/A-Dateien im Ausgangsordner ab.

## Features

- **100 % portable** – ein Ordner, kein System-Install, keine Admin-Rechte nötig
- **Auto-Bootstrap** – lädt beim ersten Start Python, Tesseract, Ghostscript, qpdf automatisch nach `bin\`
- **FileSystemWatcher** – neue PDFs werden sofort erkannt
- **Robust** – Debounce, Retry, Timeout, Quarantäne
- **Deutsche OCR** – Tesseract 5 mit `deu.traineddata`, Deskew + Auto-Rotate
- **PDF/A-Ausgabe** – archivierungssicher
- **Self-Update** – beim Start automatische Versionsprüfung gegen GitHub
- **Multi-PC-Deploy** – `Pull-OCR.cmd` zieht die aktuelle Version aus dem Repo

## Schnellstart

1. Ordner kopieren.
2. `Start-OCR.cmd` doppelklicken.
3. Beim First-Run lädt das Tool alle Abhängigkeiten (ca. 400 MB).
4. Ordner auswählen (Standard-Vorschlag: `Scan-Eingang` + `Scan-Ausgang` im Tool-Ordner).
5. PDFs in den Eingangsordner legen → fertig.

Siehe **[Anleitung.md](Anleitung.md)** für Details.

## Repo-Struktur

```
HU-OCR\
├── Start-OCR.cmd           (Watcher starten / First-Run)
├── Config-OCR.cmd          (Ordner neu wählen)
├── Pull-OCR.cmd            (Update vom Repo ziehen)
├── Reset-OCR.cmd           (bin\, config, logs löschen)
├── config.default.json     (Vorlage + Download-URLs)
├── LICENSE                 (MIT – für die Skripte)
├── NOTICE.md               (Third-Party-Lizenzen)
├── README.md               (diese Datei)
├── Anleitung.md            (User-Anleitun