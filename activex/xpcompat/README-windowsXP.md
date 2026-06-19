# reportman.ocx — Windows XP registration fix

Branch: `activex_windowsXP`

## Symptom

`regsvr32 reportman.ocx` fails on a clean Windows XP install
("the module could not be found" / "LoadLibrary failed"), even though the same
OCX registers fine on Windows 7/10/11.

## Root cause (measured, not guessed)

The OCX was suspected to depend on **DirectWrite** (`dwrite.dll`). It does not, at
the import level. The 32-bit `reportman.ocx` was disassembled with Embarcadero
`tdump.exe -em` and every imported DLL/function was cross-referenced against what
ships with Windows XP:

* `dwrite.dll` / `d2d1.dll` / `dxgi` are **NOT** in the static import table — the
  Delphi RTL (`Winapi.D2D1`) already resolves `DWriteCreateFactory` /
  `D2D1CreateFactory` with `LoadLibrary`/`GetProcAddress`, so they never block the
  loader. Modern DLLs such as `DWMAPI.DLL`, `Shcore.dll`, `windowscodecs.dll`,
  `gdiplus.dll` appear only as **delay-load** imports, which also do not block
  loading.
* All static imports from `kernel32/user32/gdi32/advapi32/ole32/oleaut32/...`
  resolve on Windows XP (no `GetTickCount64`, condition variables, SRW locks,
  touch/gesture or DPI APIs).
* The **single** blocker is:

  ```
  UIAutomationCore.dll = 'UiaReturnRawElementProvider'
  ```

  `UIAutomationCore.dll` does not ship with a clean Windows XP. It is imported
  **statically** because `Vcl.Controls.TWinControl.WMGetObject` (UI Automation /
  accessibility) calls `UiaReturnRawElementProvider`, which the stock RTL unit
  `Winapi.UIAutomation` binds with `external 'UIAutomationCore.dll'`. The smart
  linker keeps exactly that one symbol, so it is the only `UIAutomationCore.dll`
  import in the final image — but one missing import is enough to fail the load.

## Fix

### 1. Registration (primary) — `xpcompat\Winapi.UIAutomation.pas`

A repo-local, **verbatim copy** of the RTL unit with a single implementation-section
change: `UiaReturnRawElementProvider` is rebound to a `LoadLibrary` /
`GetProcAddress` thunk that returns `0` when `UIAutomationCore.dll` is absent.

The **interface section is byte-identical** to the stock unit, so the precompiled
VCL DCUs that depend on it link without being recompiled (interface CRC unchanged).
The override is wired in via a Win32-only `DCC_UnitSearchPath` entry in
`..\reportman.dproj` (`xpcompat;...`), so only the 32-bit OCX is affected; Win64 is
untouched. Result: `UIAutomationCore.dll` disappears from the import table and the
OCX loads/registers on Windows XP.

### 2. Runtime safety — `rpinfoprovgdi.pas`

* `DWriteFactory` no longer calls `_AddRef` on a nil interface when DirectWrite is
  missing (that was an access violation on XP). It now caches "DirectWrite
  unavailable" and returns `nil`.
* `TextExtent` falls back to a new `TextExtentGDI` (plain GDI measurement, glyph
  indices via `GetGlyphIndicesW`, advances via `GetTextExtentPoint32W`) when
  DirectWrite is unavailable. This keeps simple left-to-right text rendering working
  on XP (no complex shaping / bidi — as requested, DirectWrite text composition is
  **not** reimplemented for XP). The GDI driver already paints with
  `ExtTextOutW(ETO_GLYPH_INDEX)`, so the fallback feeds the existing paint path.

## Verification

`tdump.exe -em binr32\reportman.ocx` after rebuild must show **no**
`UIAutomationCore.dll` import and no other XP-missing static import.
