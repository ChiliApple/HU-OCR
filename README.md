# HU-OCR v1.0.0

Portable OCR-Lösung für Windows. Überwacht einen Eingangsordner, erkennt neue PDFs automatisch, führt deutsche Texterkennung durch und legt durchsuchbare PDF/A-Dateien im Ausgangsordner ab.

## Features

- **100 % portable** – ein Ordner, kein System-Install, keine Admin-Rechte nötig
- **Auto-Bootstrap** – lädt beim ersten Start Python, Tesseract, Ghostscript, qpdf automatisch nach `bin\`
- **FileSystemWatcher** – neue PDFs werden sofort erkannt
- **Robust** – Debounce, Retry, Timeout, Quarantäne, OneDrive-sicher
- **Deutsche OCR** – Tesseract 5 mit `deu.traineddata`, Deskew + Auto-Rotate
- **PDF/A-Ausgabe** – archivierungssicher
- **Self-Update** – beim Start automatische Versionsprüfung gegen GitHub
- **Multi-PC-Deploy** – Pull.ps1 zieht immer die aktuelle Version aus dem Repo

## Schnellstart

1. Ordner kopieren.
2. `Start-OCR.cmd` doppelklicken.
3. Beim First-Run lädt das Tool alle Abhängigkeiten (ca. 400 MB).
4. Ordner auswählen (Standard: `Scan-Eingang` + `Scan-Ausgang` im Tool-Ordner).
5. PDFs in den Eingangsordner legen → fertig.

Siehe **[Anleitung.md](Anleitung.md)** für Details.

## Architektur

```
Scan-Eingang\          (überwacht)
     ↓
Temp\work_xxx\         (OneDrive-sicher, lokal)
     ↓
 ocrmypdf              (Python in bin\python\, isoliert)
     ↓
Scan-Ausgang\          (durchsuchbare PDF/A)
processed\             (Original-Backup)
```

## Lizenz

Privat – für interne Nutzung.

Basiert auf: [ocrmypdf](https://github.com/ocrmypdf/OCRmyPDF) · [Tesseract](https://github.com/tesseract-ocr/tesseract) · [Ghostscript](https://www.ghostscript.com/) · [qpdf](https://github.com/qpdf/qpdf)
