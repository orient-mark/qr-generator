# OrientMark QR

A QR code generator for OrientMark applications: control points 31–99, start, finish, and clear.
Runs offline on Windows 10/11 x64.

The source code is distributed under the [MIT License](LICENSE).
Third-party components retain their own licenses:
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md#third-party-licenses).

# User guide
## Running the application
The application does not require installation; simply download the EXE file and run it.
You can download the required version of `OrientMark-QR-<version>.exe` from the [releases page](https://github.com/orient-mark/qr-generator/releases/latest)

The “Check app version” link in the application opens the latest release on GitHub.

## Creating QR codes

1. Select the control points and service codes.
2. Select the export format and layout options.
3. Enable Russian labels on QR codes if needed.
4. Select a folder and click “Create QR codes” or “Create PDF”.

The files are saved in the `OrientMark QR` subfolder.
Replacing existing files requires confirmation.

The interface is available in Russian and English.
The language selector is at the top of the window.
The interface language and printed label language are selected independently.

## Exporting and printing

- **PNG** — a separate image for each selected point.
- **A4 QR sheet · PDF** — 4, 6, or 8 codes per page.
- **Large prism · PDF** — one point per sheet, three faces.
- **Small prisms · PDF** — two points per sheet.

Prisms are available with a glue flap, with slots and tabs, or without fastenings.
The preview lets you browse and zoom in on pages before saving.

Print PDFs at **100% / “Actual size”**.
Cut along solid lines and fold along dashed lines.
Glue the flap on the inside; insert tabs into the slots.

## Development

Requirements:

- Windows 10/11 x64.
- Flutter 3.47+ and Dart 3.13+.
- Visual Studio with **Desktop development with C++** and the Windows SDK.
- Windows Developer Mode for Flutter plugin symbolic links.

Clone the repository and run in debug mode:

```powershell
git clone --branch dev https://github.com/orient-mark/qr-generator.git
cd qr-generator
flutter pub get
flutter run -d windows
```

Build without running:

```powershell
flutter build windows --debug
```

Standard release build:

```powershell
flutter build windows --release
```

The output is in `build/windows/x64/runner/Debug/` or `Release/`.
The entire corresponding folder, including the DLLs and `data/`, is required to run the application.

## Adding an interface language

1. Copy `assets/l10n/en.json`, for example to `assets/l10n/de.json`.
2. Translate the values, preserving the keys and placeholders such as `{count}`, `{page}`,
   and `{version}`. Use UTF-8 JSON.
3. Add an entry to the existing array in `assets/l10n/languages.json`:

```json
{"code": "de", "name": "Deutsch"}
```

The language code must match the filename without its extension.
Use a language supported by Flutter's standard localization;
a regional variant can be written as `pt_BR`.
Keep the base languages `ru` and `en`.

4. Restart the application with `flutter run -d windows` or rebuild it.

The language will appear in the selector automatically.
No changes to Dart code or the asset list are required.
Translation keys and placeholders are checked when loading.
The language selection applies until the application is closed and does not change QR code contents.

## QR compatibility

The data format matches the OrientMark applications:

```json
{"point":{"checkpoint":31}}
{"point":"start"}
{"point":"finish"}
{"point":"cleaning"}
```

The language changes only the printed label. QR codes are black and white, with a
four-module quiet zone and error correction level H.

## Documentation

- [Architecture](docs/ARCHITECTURE.md#architecture)
- [Release guide](docs/PUBLICATION.md#releasing-the-application)
- [Testing](docs/TESTING.md#testing)
