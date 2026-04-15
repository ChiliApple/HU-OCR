# Third-Party Notices

HU-OCR (the "Software") is a set of PowerShell scripts that orchestrate several
third-party tools. **The Software itself does NOT bundle, ship or redistribute
any of these tools.** On first run, each user's local installation downloads
the tools directly from their respective official release URLs into a local
`bin\` folder. The end user is the entity that downloads and uses those tools
and must accept each tool's own license.

The HU-OCR scripts do not modify the source code of any third-party component.
They invoke each tool as an external process via the Windows command line.

## Third-Party Components

The following components are downloaded at runtime. Each is the property of
its respective copyright holders and is provided under its own license.

### Python (CPython Embeddable Distribution)

- Upstream: https://www.python.org/
- License: Python Software Foundation License (PSF-2.0)
- License text: https://docs.python.org/3/license.html

### ocrmypdf

- Upstream: https://github.com/ocrmypdf/OCRmyPDF
- License: Mozilla Public License 2.0 (MPL-2.0)
- License text: https://www.mozilla.org/en-US/MPL/2.0/

### pikepdf

- Upstream: https://github.com/pikepdf/pikepdf
- License: Mozilla Public License 2.0 (MPL-2.0)

### Tesseract OCR

- Upstream: https://github.com/tesseract-ocr/tesseract
- Windows build: https://github.com/UB-Mannheim/tesseract
- License: Apache License 2.0
- License text: https://www.apache.org/licenses/LICENSE-2.0

### Tesseract trained data (deu, osd)

- Upstream: https://github.com/tesseract-ocr/tessdata_fast
- License: Apache License 2.0

### Ghostscript

- Upstream: https://www.ghostscript.com/ (Artifex Software, Inc.)
- Release artifacts: https://github.com/ArtifexSoftware/ghostpdl-downloads
- License: GNU Affero General Public License v3.0 (AGPL-3.0)
- License text: https://www.gnu.org/licenses/agpl-3.0.html

**Important note on Ghostscript:** Ghostscript is distributed by Artifex under
AGPL-3.0 (with a separate commercial license available from Artifex). HU-OCR
does NOT embed, link against, modify, or redistribute Ghostscript. The HU-OCR
scripts merely download Ghostscript from Artifex's public release URL onto
the end user's computer and invoke `gswin64c.exe` as an independent external
process. By running HU-OCR you will trigger a download of Ghostscript directly
from Artifex to your own machine and you accept Artifex's AGPL (or any
applicable commercial license you may hold) for that copy. If your intended
use is incompatible with AGPL, please obtain a commercial Ghostscript license
from Artifex before using HU-OCR.

### qpdf

- Upstream: https://github.com/qpdf/qpdf
- License: Apache License 2.0 (current versions)

### 7-Zip

- Upstream: https://www.7-zip.org/ and https://github.com/ip7z/7zip
- License: GNU LGPL v2.1, BSD 3-Clause, and (for unRAR code) the unRAR license
- License text: https://www.7-zip.org/license.txt

### Python package dependencies (installed via pip into bin\python\)

Each package ships its own LICENSE file in `bin\python\Lib\site-packages\`.
Common licenses include MIT, BSD, Apache 2.0, HPND (pillow) and MPL-2.0.

---

## Reference URLs are fetched at runtime

The list of upstream download URLs is stored in `config.default.json` under
the `Downloads` key. Users can inspect and modify this list before running the
tool for the first time.

## No warranty

All third-party components are provided by their authors "as is" and HU-OCR
passes through that disclaimer. See the MIT `LICENSE` file for the HU-OCR
scripts' own warranty disclaimer.
