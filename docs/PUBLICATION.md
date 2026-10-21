# Releasing the application

[Русский](PUBLICATION.ru.md#выпуск-приложения)

This guide covers preparing a portable Windows EXE.
Development setup is described in the [Development section](../README.md#development).

## OrientMark QR release tooling

The portable release bundles the application and its required files into one EXE.
Users can run it without installing development tools.

| Component | Location | Role |
|---|---|---|
| Release preparation | [build.ps1](../build.ps1) | Builds the application, adds redistributable runtime libraries and license information, and packages a single EXE. Supports signing both executables or producing an unsigned build with the `-unsigned` suffix. |
| Portable launcher | [tool/portable/launcher.cpp](../tool/portable/launcher.cpp) | Extracts the embedded archive into a separate temporary folder, starts the application, and waits for it to exit. On exit, it removes only the folder it created. |

The portable launcher is used only when packaging the application as a single EXE.
Normal development runs do not require packaging or a signing certificate.

## Requirements

Install the tools listed in the [Development section](../README.md#development).
You can use any code editor; the required Visual Studio components must be
installed regardless of the editor.
Signed releases also require SignTool from the Windows SDK, a code-signing
certificate with its private key in PFX format, and its password.

Run all commands from the project root.

## Signed release

Official releases are signed with the publisher's certificate.

1. Set the version to `x.y.z+build` in `pubspec.yaml`.
2. Copy [.env.example](../.env.example) to `.env` and fill in:
   - `APP_DEVELOPER` — developer name.
   - `APP_ORGANIZATION` — organization.
   - `SIGNING_PFX_PATH` — path to the PFX file.
   - `SIGNING_PFX_PASSWORD` — password.
   - `SIGNING_TIMESTAMP_URL` — optional RFC 3161 timestamp server.
3. Run:

```powershell
.\build.ps1
```

Output: `../OrientMark_relise/OrientMark-QR-<version>.exe`.

```mermaid
flowchart LR
    Source["Source code"] --> Build["Release build"]
    Build --> AppSignature["Application signing"]
    AppSignature --> Package["Portable EXE packaging"]
    Package --> LauncherSignature["Launcher signing"]
    LauncherSignature -->|Manually| Release["GitHub Release publication"]
```

The script builds the application, adds runtime libraries, and signs the inner
EXE and portable launcher. The version is used in the filename, EXE properties,
and interface.

Before publishing, check that the application starts from the final EXE.
Then create a release in the [repository](https://github.com/orient-mark/qr-generator/releases)
and attach the file. The build script does not publish releases automatically.

## Unsigned portable EXE

```powershell
.\build.ps1 -SkipSigning
```

Output: `../OrientMark_relise/OrientMark-QR-<version>-unsigned.exe`.

This mode does not require a certificate, password, `.env` file, or SignTool.
It produces a separate artifact for building and checking the application
without the official publisher's key.

If `.env` exists, the developer and organization details are also used in
unsigned builds. They appear in the application, EXE properties, and PDF author
metadata. When building without `.env`, these fields remain empty.
