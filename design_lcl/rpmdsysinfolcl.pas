{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdsysinfolcl                                  }
{       Form showing info about printer and system      }
{       (LCL port of rpmdsysinfo)                       }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rpmdsysinfolcl;

{$mode delphi}

{ The printer part uses the LCL Printers unit (Printer4Lazarus) on every
  platform. Windows adds what the VCL dialog shows through WinSpool and the
  printer device context (driver, port, forms, device capabilities); Unix
  adds what CUPS knows of the printer (libcups loaded at run time, the same
  for GTK2 and Qt6: model, device URI, location, state, color, duplex,
  copies and collation). }

interface

uses
  SysUtils, Classes, Math, Graphics, Controls, Forms, StdCtrls, ComCtrls,
  ExtCtrls, Printers, InterfaceBase, LCLPlatformDef,
{$IFDEF MSWINDOWS}
  Windows, WinSpool,
{$ENDIF}
{$IFDEF UNIX}
  BaseUnix, dynlibs,
{$ENDIF}
  rpmdconsts, rptypes, rpmunits;

type
  { TFRpSysInfoLCL: built in code (no form resource). Two pages, so that it
    fits small screens (800x600) with any widgetset font. }

  TFRpSysInfoLCL = class(TForm)
  private
    FInfoFilled: Boolean;
    FColumnWidth: Integer;
    FLabelWidth: Integer;
    FRowHeight: Integer;
    procedure BuildControls;
    function AddValue(AParent: TWinControl; ACol, ARow: Integer;
      const ACaption: string; AFullWidth: Boolean = False): TEdit;
    function AddCombo(AParent: TWinControl; ACol, ARow: Integer;
      const ACaption: string): TComboBox;
    procedure FormShowEvent(Sender: TObject);
    procedure FillPrinterInfo;
    procedure FillSystemInfo;
{$IFDEF MSWINDOWS}
    procedure FillWindowsPrinterInfo(const APrinterName: string);
{$ENDIF}
{$IFDEF UNIX}
    procedure FillCupsPrinterInfo(const APrinterName: string);
{$ENDIF}
  public
    PControl: TPageControl;
    TabPrinter: TTabSheet;
    TabSystem: TTabSheet;
    // Selected printer
    EPrinterName: TEdit;
    EStatus: TEdit;
    EDevice: TEdit;
    EDriver: TEdit;
    EColor: TEdit;
    EPort: TEdit;
    EMaxCopies: TEdit;
    ECollation: TEdit;
    EResolution: TEdit;
    ComboSource: TComboBox;
    EFormName: TEdit;
    EDuplex: TEdit;
    EPageSize: TEdit;
    EOrientation: TEdit;
    EFormPageSize: TEdit;
    // Windows (device context)
    ETechnology: TEdit;
    CLineCaps: TComboBox;
    CRasterCaps: TComboBox;
    CPolyCaps: TComboBox;
    CTextCaps: TComboBox;
    CCurveCaps: TComboBox;
    // Other platforms
    ELocation: TEdit;
    EPrinterType: TEdit;
    // System
    EOS: TEdit;
    EVersion: TEdit;
    EProcessors: TEdit;
    EOEMID: TEdit;
    EDisplay: TEdit;
    ComboSeparators: TComboBox;
    EWidgetset: TEdit;
    BOK: TButton;
    constructor Create(AOwner: TComponent); override;
    // Reads the printer and system information (ShowSysInfo does it before
    // showing the dialog)
    procedure FillInfo;
  end;

// Shows the printer and system information dialog
procedure ShowSysInfo;

implementation

uses
  rplcllayout;

{$IFDEF MSWINDOWS}
const
  winspooldrv = 'winspool.drv';
  // Not declared by the FPC 3.2.2 Windows unit
  DC_COLLATE = 22;

function DeviceCapabilitiesW(pDevice, pPort: PWideChar; fwCapability: Word;
  pOutput: PWideChar; pDevMode: PDeviceModeW): LongInt; stdcall;
  external winspooldrv name 'DeviceCapabilitiesW';

type
  TRpOSVersionInfoW = record
    dwOSVersionInfoSize: DWORD;
    dwMajorVersion: DWORD;
    dwMinorVersion: DWORD;
    dwBuildNumber: DWORD;
    dwPlatformId: DWORD;
    szCSDVersion: array[0..127] of WideChar;
  end;
  TRtlGetVersion = function(var AInfo: TRpOSVersionInfoW): LongInt; stdcall;
{$ENDIF}

{$IFDEF UNIX}
type
  // cups.h: cups_option_t, cups_dest_t (stable ABI since CUPS 1.1)
  PRpCupsOption = ^TRpCupsOption;
  TRpCupsOption = record
    name: PAnsiChar;
    value: PAnsiChar;
  end;
  PRpCupsDest = ^TRpCupsDest;
  TRpCupsDest = record
    name: PAnsiChar;
    instance: PAnsiChar;
    is_default: Integer;
    num_options: Integer;
    options: PRpCupsOption;
  end;
  TCupsGetDests = function(dests: Pointer): Integer; cdecl;
  TCupsFreeDests = procedure(num_dests: Integer; dests: PRpCupsDest); cdecl;
  TCupsGetOption = function(name: PAnsiChar; num_options: Integer;
    options: PRpCupsOption): PAnsiChar; cdecl;

const
  // cups_ptype_e
  CUPS_PRINTER_REMOTE = $0002;
  CUPS_PRINTER_COLOR = $0008;
  CUPS_PRINTER_DUPLEX = $0010;
  CUPS_PRINTER_COPIES = $0040;
  CUPS_PRINTER_COLLATE = $0080;
{$ENDIF}

procedure ShowSysInfo;
var
  dia: TFRpSysInfoLCL;
begin
  dia := TFRpSysInfoLCL.Create(Application);
  try
    dia.FillInfo;
    dia.ShowModal;
  finally
    dia.Free;
  end;
end;

// FPC 3.2.2 GetCPUCount is always 1 outside Windows
function ProcessorCount: Integer;
{$IFDEF LINUX}
var
  LLines: TStringList;
  I: Integer;
{$ENDIF}
begin
  Result := 0;
{$IFDEF LINUX}
  LLines := TStringList.Create;
  try
    try
      LLines.LoadFromFile('/proc/cpuinfo');
    except
      LLines.Clear;
    end;
    for I := 0 to LLines.Count - 1 do
      if Copy(LLines[I], 1, 9) = 'processor' then
        Inc(Result);
  finally
    LLines.Free;
  end;
{$ENDIF}
  if Result < 1 then
    Result := GetCPUCount;
end;

function YesNo(AValue: Boolean): string;
begin
  if AValue then
    Result := SRpYes
  else
    Result := SRpNo;
end;

function TwipsSizeText(AWidth, AHeight: Integer): string;
begin
  Result := gettextfromtwips(AWidth) + ' x ' + gettextfromtwips(AHeight) + ' ' +
    rpunitlabels[defaultunit];
end;

{ TFRpSysInfoLCL }

constructor TFRpSysInfoLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  // Sizes in pixels of the screen: the LCL does not scale it again
  RpBuiltInScreenPixels(Self);
  Caption := TranslateStr(976, 'System information');
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  OnShow := FormShowEvent;
  BuildControls;
end;

function TFRpSysInfoLCL.AddValue(AParent: TWinControl; ACol, ARow: Integer;
  const ACaption: string; AFullWidth: Boolean): TEdit;
var
  LLabel: TLabel;
  LLeft, LTop, LWidth: Integer;
begin
  LLeft := Scale96ToScreen(8) + ACol * FColumnWidth;
  LTop := Scale96ToScreen(8) + ARow * FRowHeight;
  LLabel := TLabel.Create(Self);
  LLabel.Parent := AParent;
  LLabel.Caption := ACaption;
  LLabel.AutoSize := False;
  LLabel.SetBounds(LLeft, LTop + Scale96ToScreen(4), FLabelWidth - Scale96ToScreen(4),
    Scale96ToScreen(18));
  Result := TEdit.Create(Self);
  Result.Parent := AParent;
  Result.ReadOnly := True;
  Result.TabStop := False;
  if AFullWidth then
    LWidth := 2 * FColumnWidth - FLabelWidth - Scale96ToScreen(8)
  else
    LWidth := FColumnWidth - FLabelWidth - Scale96ToScreen(8);
  Result.SetBounds(LLeft + FLabelWidth, LTop, LWidth, Scale96ToScreen(24));
  LLabel.FocusControl := Result;
end;

function TFRpSysInfoLCL.AddCombo(AParent: TWinControl; ACol, ARow: Integer;
  const ACaption: string): TComboBox;
var
  LLabel: TLabel;
  LLeft, LTop: Integer;
begin
  LLeft := Scale96ToScreen(8) + ACol * FColumnWidth;
  LTop := Scale96ToScreen(8) + ARow * FRowHeight;
  LLabel := TLabel.Create(Self);
  LLabel.Parent := AParent;
  LLabel.Caption := ACaption;
  LLabel.AutoSize := False;
  LLabel.SetBounds(LLeft, LTop + Scale96ToScreen(4), FLabelWidth - Scale96ToScreen(4),
    Scale96ToScreen(18));
  Result := TComboBox.Create(Self);
  Result.Parent := AParent;
  Result.Style := csDropDownList;
  Result.SetBounds(LLeft + FLabelWidth, LTop, FColumnWidth - FLabelWidth - Scale96ToScreen(8),
    Scale96ToScreen(24));
  LLabel.FocusControl := Result;
end;

procedure TFRpSysInfoLCL.BuildControls;
var
  LBottom: TPanel;
  LRow, I, LMaxWidth, LValueWidth: Integer;
  // Not the TBITMAP record of the Windows unit
  LBitmap: Graphics.TBitmap;
  LCaptions: array of string;
begin
  // The label column fits the longest caption (translations, widgetset
  // fonts), within an 800 pixels wide screen
  LCaptions := [TranslateStr(1061, 'Printer Name'), TranslateStr(1062, 'Printer Status'),
    TranslateStr(1063, 'Device'), TranslateStr(1064, 'Driver'),
    TranslateStr(1065, 'Color selection'), TranslateStr(1066, 'Port'),
    TranslateStr(1067, 'Printer max. hardware copies'),
    TranslateStr(1068, 'Printer supports collation'),
    TranslateStr(1069, 'Printer resolution dpi (HorzxVert)'),
    TranslateStr(1323, 'Paper sources'), SRpFormName, TranslateStr(1804, 'Duplex'),
    SRpPageSize, TranslateStr(98, 'Page orientation'), SRpFormPageSize,
    TranslateStr(1070, 'Technology'), TranslateStr(1071, 'Line capabilities'),
    TranslateStr(1072, 'Raster capabilities'), TranslateStr(1073, 'Polygonal caps'),
    TranslateStr(1074, 'Text capabilities'), TranslateStr(1075, 'Curve caps'),
    TranslateStr(1808, 'Location'), TranslateStr(1809, 'Printer type'),
    TranslateStr(1076, 'Operating system'), TranslateStr(91, 'Version'),
    TranslateStr(1078, 'Number of processors'), TranslateStr(1077, 'OEM ID:'),
    TranslateStr(1079, 'Display (WidthxHeight)'), TranslateStr(1805, 'Separators'),
    TranslateStr(1812, 'Widgetset')];
  FLabelWidth := Scale96ToScreen(120);
  LBitmap := Graphics.TBitmap.Create;
  try
    LBitmap.Canvas.Font := Font;
    for I := 0 to High(LCaptions) do
      FLabelWidth := Max(FLabelWidth, LBitmap.Canvas.TextWidth(LCaptions[I]) +
        Scale96ToScreen(12));
  finally
    LBitmap.Free;
  end;
  FLabelWidth := Min(FLabelWidth, Scale96ToScreen(260));
  // Values of 180 pixels, less when two columns do not fit an 800 pixels
  // wide screen (the labels keep their width)
  LMaxWidth := Min(Screen.WorkAreaWidth, Scale96ToScreen(800)) - Scale96ToScreen(40);
  LValueWidth := Scale96ToScreen(180);
  if 2 * (FLabelWidth + LValueWidth) + Scale96ToScreen(20) > LMaxWidth then
    LValueWidth := Max(Scale96ToScreen(120),
      (LMaxWidth - Scale96ToScreen(20)) div 2 - FLabelWidth);
  FColumnWidth := FLabelWidth + LValueWidth;
  ClientWidth := 2 * FColumnWidth + Scale96ToScreen(20);
  FRowHeight := Scale96ToScreen(32);

  // OK at the bottom, fixed width (no AutoSize button aligned to a side)
  LBottom := TPanel.Create(Self);
  LBottom.Parent := Self;
  LBottom.BevelOuter := bvNone;
  LBottom.Caption := '';
  LBottom.Height := Scale96ToScreen(44);
  LBottom.Align := alBottom;
  BOK := TButton.Create(Self);
  BOK.Parent := LBottom;
  BOK.Caption := SRpOk;
  BOK.Default := True;
  BOK.Cancel := True;
  BOK.ModalResult := mrOk;
  BOK.SetBounds((ClientWidth - Scale96ToScreen(100)) div 2, Scale96ToScreen(8),
    Scale96ToScreen(100), Scale96ToScreen(28));

  PControl := TPageControl.Create(Self);
  PControl.Parent := Self;
  PControl.Align := alClient;
  TabPrinter := TTabSheet.Create(Self);
  TabPrinter.PageControl := PControl;
  TabPrinter.Caption := SRpSelectedPrinter;
  TabSystem := TTabSheet.Create(Self);
  TabSystem.PageControl := PControl;
  TabSystem.Caption := TranslateStr(976, 'System information');

  // Selected printer (the rows of the VCL dialog)
  EPrinterName := AddValue(TabPrinter, 0, 0, TranslateStr(1061, 'Printer Name'));
  EStatus := AddValue(TabPrinter, 1, 0, TranslateStr(1062, 'Printer Status'));
  EDevice := AddValue(TabPrinter, 0, 1, TranslateStr(1063, 'Device'));
  EDriver := AddValue(TabPrinter, 1, 1, TranslateStr(1064, 'Driver'));
  EColor := AddValue(TabPrinter, 0, 2, TranslateStr(1065, 'Color selection'));
  EPort := AddValue(TabPrinter, 1, 2, TranslateStr(1066, 'Port'));
  EMaxCopies := AddValue(TabPrinter, 0, 3, TranslateStr(1067, 'Printer max. hardware copies'));
  ECollation := AddValue(TabPrinter, 1, 3, TranslateStr(1068, 'Printer supports collation'));
  EResolution := AddValue(TabPrinter, 0, 4, TranslateStr(1069, 'Printer resolution dpi (HorzxVert)'));
  ComboSource := AddCombo(TabPrinter, 1, 4, TranslateStr(1323, 'Paper sources'));
  EFormName := AddValue(TabPrinter, 0, 5, SRpFormName);
  EDuplex := AddValue(TabPrinter, 1, 5, TranslateStr(1804, 'Duplex'));
  EPageSize := AddValue(TabPrinter, 0, 6, SRpPageSize);
  EOrientation := AddValue(TabPrinter, 1, 6, TranslateStr(98, 'Page orientation'));
  EFormPageSize := AddValue(TabPrinter, 0, 7, SRpFormPageSize, True);
  LRow := 8;
{$IFDEF MSWINDOWS}
  ETechnology := AddValue(TabPrinter, 0, LRow, TranslateStr(1070, 'Technology'));
  CLineCaps := AddCombo(TabPrinter, 1, LRow, TranslateStr(1071, 'Line capabilities'));
  CRasterCaps := AddCombo(TabPrinter, 0, LRow + 1, TranslateStr(1072, 'Raster capabilities'));
  CPolyCaps := AddCombo(TabPrinter, 1, LRow + 1, TranslateStr(1073, 'Polygonal caps'));
  CTextCaps := AddCombo(TabPrinter, 0, LRow + 2, TranslateStr(1074, 'Text capabilities'));
  CCurveCaps := AddCombo(TabPrinter, 1, LRow + 2, TranslateStr(1075, 'Curve caps'));
  ELocation := AddValue(TabPrinter, 0, LRow + 3, TranslateStr(1808, 'Location'));
  EPrinterType := AddValue(TabPrinter, 1, LRow + 3, TranslateStr(1809, 'Printer type'));
  LRow := LRow + 4;
{$ELSE}
  ELocation := AddValue(TabPrinter, 0, LRow, TranslateStr(1808, 'Location'));
  EPrinterType := AddValue(TabPrinter, 1, LRow, TranslateStr(1809, 'Printer type'));
  LRow := LRow + 1;
{$ENDIF}

  // System information
  EOS := AddValue(TabSystem, 0, 0, TranslateStr(1076, 'Operating system'), True);
  EVersion := AddValue(TabSystem, 0, 1, TranslateStr(91, 'Version'), True);
  EProcessors := AddValue(TabSystem, 0, 2, TranslateStr(1078, 'Number of processors'));
  EOEMID := AddValue(TabSystem, 1, 2, TranslateStr(1077, 'OEM ID:'));
  EDisplay := AddValue(TabSystem, 0, 3, TranslateStr(1079, 'Display (WidthxHeight)'), True);
  ComboSeparators := AddCombo(TabSystem, 0, 4, TranslateStr(1805, 'Separators'));
  EWidgetset := AddValue(TabSystem, 1, 4, TranslateStr(1812, 'Widgetset'));

  // Tabs, borders and the bottom panel around the rows
  ClientHeight := Scale96ToScreen(8) + LRow * FRowHeight + Scale96ToScreen(56) +
    LBottom.Height;
  ActiveControl := BOK;
end;

procedure TFRpSysInfoLCL.FormShowEvent(Sender: TObject);
begin
  if not FInfoFilled then
    FillInfo;
end;

procedure TFRpSysInfoLCL.FillInfo;
begin
  FInfoFilled := True;
  FillSystemInfo;
  FillPrinterInfo;
end;

procedure TFRpSysInfoLCL.FillSystemInfo;
var
{$IFDEF MSWINDOWS}
  LSysInfo: SYSTEM_INFO;
  LVersion: TRpOSVersionInfoW;
  LNtDll: HMODULE;
  LRtlGetVersion: TRtlGetVersion;
  LGotVersion: Boolean;
{$ENDIF}
{$IFDEF UNIX}
  LName: UtsName;
  LLines: TStringList;
  I: Integer;
  LPretty: string;
{$ENDIF}
begin
  ComboSeparators.Items.Clear;
  ComboSeparators.Items.Add(SRpDate + ' ' + DefaultFormatSettings.DateSeparator);
  ComboSeparators.Items.Add(SRpTime + ' ' + DefaultFormatSettings.TimeSeparator);
  ComboSeparators.Items.Add(TranslateStr(1806, 'Decimal') + ' ' +
    DefaultFormatSettings.DecimalSeparator);
  ComboSeparators.Items.Add(TranslateStr(1807, 'Thousand') + ' ' +
    DefaultFormatSettings.ThousandSeparator);
  ComboSeparators.ItemIndex := 0;
  EProcessors.Text := IntToStr(ProcessorCount);
  EDisplay.Text := FormatFloat('#,##0', Screen.Width) + ' x ' +
    FormatFloat('#,##0', Screen.Height) + ' ' + SRpDPIRes + ':' +
    IntToStr(Screen.PixelsPerInch);
  EWidgetset.Text := LCLPlatformDisplayNames[WidgetSet.LCLPlatform];
{$IFDEF MSWINDOWS}
  GetSystemInfo(LSysInfo);
  EOEMID.Text := IntToStr(LSysInfo.dwOemId);
  // RtlGetVersion does not depend on the compatibility of the manifest
  LGotVersion := False;
  FillChar(LVersion, SizeOf(LVersion), 0);
  LVersion.dwOSVersionInfoSize := SizeOf(LVersion);
  LNtDll := GetModuleHandle('ntdll.dll');
  if LNtDll <> 0 then
  begin
    LRtlGetVersion := TRtlGetVersion(GetProcAddress(LNtDll, 'RtlGetVersion'));
    if Assigned(LRtlGetVersion) then
      LGotVersion := LRtlGetVersion(LVersion) = 0;
  end;
  if not LGotVersion then
  begin
    LVersion.dwMajorVersion := Win32MajorVersion;
    LVersion.dwMinorVersion := Win32MinorVersion;
    LVersion.dwBuildNumber := Win32BuildNumber;
  end;
  EOS.Text := 'Windows NT' {$IFDEF CPU64} + ' (64 bits)'{$ELSE} + ' (32 bits)'{$ENDIF};
  EVersion.Text := IntToStr(LVersion.dwMajorVersion) + '.' +
    IntToStr(LVersion.dwMinorVersion) + ' Build:' + IntToStr(LVersion.dwBuildNumber);
  if LGotVersion and (LVersion.szCSDVersion[0] <> #0) then
    EVersion.Text := EVersion.Text + '-' +
      UTF8Encode(WideString(PWideChar(@LVersion.szCSDVersion[0])));
{$ENDIF}
{$IFDEF UNIX}
  // No OEM identifier: the machine architecture
  LPretty := '';
  LLines := TStringList.Create;
  try
    try
      if FileExists('/etc/os-release') then
        LLines.LoadFromFile('/etc/os-release');
    except
      LLines.Clear;
    end;
    for I := 0 to LLines.Count - 1 do
      if Copy(LLines[I], 1, 12) = 'PRETTY_NAME=' then
        LPretty := AnsiDequotedStr(Copy(LLines[I], 13, MaxInt), '"');
  finally
    LLines.Free;
  end;
  FillChar(LName, SizeOf(LName), 0);
  if FpUname(LName) = 0 then
  begin
    EOS.Text := string(PAnsiChar(@LName.Sysname[0]));
    if LPretty <> '' then
      EOS.Text := EOS.Text + ' - ' + LPretty;
    EVersion.Text := string(PAnsiChar(@LName.Release[0])) + ' ' +
      string(PAnsiChar(@LName.Version[0]));
    EOEMID.Text := string(PAnsiChar(@LName.Machine[0]));
  end
  else
    EOS.Text := LPretty;
{$ENDIF}
end;

procedure TFRpSysInfoLCL.FillPrinterInfo;
var
  LName: string;
  LRect: TRect;
  LXDpi, LYDpi, I: Integer;
begin
  ComboSource.Items.Clear;
  ComboSource.Items.Add(SRpUnknown);
  ComboSource.ItemIndex := 0;
  try
    if Printer.Printers.Count < 1 then
    begin
      EStatus.Text := SRpNone;
      Exit;
    end;
    if (Printer.PrinterIndex >= 0) and (Printer.PrinterIndex < Printer.Printers.Count) then
      LName := Printer.Printers[Printer.PrinterIndex]
    else
      LName := Printer.PrinterName;
    EPrinterName.Text := LName;
    EDevice.Text := LName;
    case Printer.PrinterState of
      psReady: EStatus.Text := SRpSReady;
      psPrinting: EStatus.Text := TranslateStr(1813, 'Printing');
      psStopped: EStatus.Text := TranslateStr(1814, 'Stopped');
    else
      EStatus.Text := SRpUnknown;
    end;
    if Printer.PrinterType = ptNetWork then
      EPrinterType.Text := TranslateStr(1811, 'Network')
    else
      EPrinterType.Text := TranslateStr(1810, 'Local');
    LXDpi := Printer.XDPI;
    LYDpi := Printer.YDPI;
    EResolution.Text := IntToStr(LXDpi) + ' x ' + IntToStr(LYDpi);
    if Printer.Orientation in [poPortrait, poReversePortrait] then
      EOrientation.Text := TranslateStr(106, 'Portrait')
    else
      EOrientation.Text := TranslateStr(107, 'Landscape');
    EMaxCopies.Text := YesNo(Printer.CanRenderCopies);
    // Paper and paper sources: not every printer or backend knows them
    try
      EFormName.Text := Printer.PaperSize.PaperName;
      LRect := Printer.PaperSize.PaperRect.PhysicalRect;
      if (LXDpi > 0) and (LYDpi > 0) and (LRect.Right > LRect.Left) then
      begin
        EPageSize.Text := TwipsSizeText(
          Round((LRect.Right - LRect.Left) / LXDpi * TWIPS_PER_INCHESS),
          Round((LRect.Bottom - LRect.Top) / LYDpi * TWIPS_PER_INCHESS));
        EFormPageSize.Text := EPageSize.Text;
      end;
    except
      on E: Exception do
        EFormPageSize.Text := SRpError + '-' + E.Message;
    end;
    try
      if Printer.SupportedBins.Count > 0 then
      begin
        ComboSource.Items.Assign(Printer.SupportedBins);
        I := ComboSource.Items.IndexOf(Printer.BinName);
        if I < 0 then
          I := 0;
        ComboSource.ItemIndex := I;
      end;
    except
      // Unknown, as shown
    end;
{$IFDEF MSWINDOWS}
    FillWindowsPrinterInfo(LName);
{$ENDIF}
{$IFDEF UNIX}
    FillCupsPrinterInfo(LName);
{$ENDIF}
  except
    on E: Exception do
      EStatus.Text := E.Message;
  end;
end;

{$IFDEF MSWINDOWS}
procedure TFRpSysInfoLCL.FillWindowsPrinterInfo(const APrinterName: string);
type
  TBinName = array[0..23] of WideChar;
var
  LName, LPort: WideString;
  LHandle: THandle;
  LNeeded: DWORD;
  LInfo: PPRINTER_INFO_2W;
  LDevMode: PDeviceModeW;
  LSize, LCount, I, LCaps: Integer;
  LForm: PFORM_INFO_1W;
  LBins: array of Word;
  LBinNames: array of TBinName;
  LDC: HDC;
  LWidth, LHeight, LNameLength: Integer;
  LBinName, LDriver: WideString;
begin
  LName := UTF8Decode(APrinterName);
  LDriver := 'WINSPOOL';
  LPort := '';
  LDevMode := nil;
  if not OpenPrinterW(PWideChar(LName), @LHandle, nil) then
    Exit;
  try
    // Driver, port, location and status
    LNeeded := 0;
    GetPrinterW(LHandle, 2, nil, 0, @LNeeded);
    if LNeeded > 0 then
    begin
      LInfo := AllocMem(LNeeded);
      try
        if GetPrinterW(LHandle, 2, PByte(LInfo), LNeeded, @LNeeded) then
        begin
          EDevice.Text := UTF8Encode(WideString(LInfo^.pPrinterName));
          EDriver.Text := UTF8Encode(WideString(LInfo^.pDriverName));
          LPort := LInfo^.pPortName;
          EPort.Text := UTF8Encode(LPort);
          ELocation.Text := UTF8Encode(WideString(LInfo^.pLocation));
          if LInfo^.Status = 0 then
            EStatus.Text := SRpSReady
          else
            EStatus.Text := SRpSUnknownType + ' ($' + IntToHex(LInfo^.Status, 8) + ')';
          if (LInfo^.Attributes and PRINTER_ATTRIBUTE_NETWORK) <> 0 then
            EPrinterType.Text := TranslateStr(1811, 'Network')
          else
            EPrinterType.Text := TranslateStr(1810, 'Local');
        end;
      finally
        FreeMem(LInfo);
      end;
    end;
    // Default document properties of the printer
    LSize := DocumentPropertiesW(0, LHandle, PWideChar(LName), nil, nil, 0);
    if LSize > 0 then
    begin
      LDevMode := AllocMem(LSize);
      if DocumentPropertiesW(0, LHandle, PWideChar(LName), LDevMode, nil,
        DM_OUT_BUFFER) = IDOK then
      begin
        if (LDevMode^.dmFields and DM_ORIENTATION) <> 0 then
        begin
          if LDevMode^.dmOrientation = DMORIENT_PORTRAIT then
            EOrientation.Text := TranslateStr(106, 'Portrait')
          else
          if LDevMode^.dmOrientation = DMORIENT_LANDSCAPE then
            EOrientation.Text := TranslateStr(107, 'Landscape');
        end;
        if (LDevMode^.dmFields and DM_COLOR) <> 0 then
        begin
          if LDevMode^.dmColor = DMCOLOR_COLOR then
            EColor.Text := SRpSColorPrinting
          else
            EColor.Text := SRpSMonoPrinting;
        end;
        if (LDevMode^.dmFields and DM_YRESOLUTION) <> 0 then
          EResolution.Text := FormatFloat('#,##0', LDevMode^.dmPrintQuality) + ' x ' +
            FormatFloat('#,##0', LDevMode^.dmYResolution)
        else
        if LDevMode^.dmPrintQuality <= 0 then
        begin
          case LDevMode^.dmPrintQuality of
            DMRES_HIGH: EResolution.Text := SRpSHighResolution;
            DMRES_MEDIUM: EResolution.Text := SRpSMediumResolution;
            DMRES_LOW: EResolution.Text := SRpSLowResolution;
            DMRES_DRAFT: EResolution.Text := SRpSDraftResolution;
          end;
        end
        else
          EResolution.Text := FormatFloat('#,##0', LDevMode^.dmPrintQuality) + ' x ' +
            FormatFloat('#,##0', LDevMode^.dmPrintQuality);
        // Form and its size (thousandths of millimeter)
        if (LDevMode^.dmFields and DM_FORMNAME) <> 0 then
        begin
          EFormName.Text := UTF8Encode(WideString(PWideChar(@LDevMode^.dmFormName[0])));
          try
            LNeeded := 0;
            GetFormW(LHandle, PWideChar(WideString(PWideChar(@LDevMode^.dmFormName[0]))), 1,
              nil, 0, @LNeeded);
            if LNeeded > 0 then
            begin
              LForm := AllocMem(LNeeded);
              try
                if GetFormW(LHandle, PWideChar(WideString(PWideChar(@LDevMode^.dmFormName[0]))),
                  1, PByte(LForm), LNeeded, @LNeeded) then
                  EFormPageSize.Text := TwipsSizeText(
                    Round(LForm^.Size.cx / 1000 / 10 / CMS_PER_INCHESS * TWIPS_PER_INCHESS),
                    Round(LForm^.Size.cy / 1000 / 10 / CMS_PER_INCHESS * TWIPS_PER_INCHESS));
              finally
                FreeMem(LForm);
              end;
            end;
          except
            on E: Exception do
              EFormPageSize.Text := SRpError + '-' + E.Message;
          end;
        end;
      end;
    end;
    // Capabilities of the driver
    LCount := DeviceCapabilitiesW(PWideChar(LName), PWideChar(LPort), DC_COPIES, nil, LDevMode);
    if LCount > 0 then
      EMaxCopies.Text := FormatFloat('#,##0', LCount);
    ECollation.Text := YesNo(DeviceCapabilitiesW(PWideChar(LName), PWideChar(LPort),
      DC_COLLATE, nil, LDevMode) > 0);
    EDuplex.Text := YesNo(DeviceCapabilitiesW(PWideChar(LName), PWideChar(LPort),
      DC_DUPLEX, nil, LDevMode) > 0);
    // Paper sources: number and name of each bin
    LCount := DeviceCapabilitiesW(PWideChar(LName), PWideChar(LPort), DC_BINS, nil, LDevMode);
    if LCount > 0 then
    begin
      SetLength(LBins, LCount);
      SetLength(LBinNames, LCount);
      FillChar(LBinNames[0], SizeOf(TBinName) * LCount, 0);
      DeviceCapabilitiesW(PWideChar(LName), PWideChar(LPort), DC_BINS, @LBins[0], LDevMode);
      DeviceCapabilitiesW(PWideChar(LName), PWideChar(LPort), DC_BINNAMES, @LBinNames[0],
        LDevMode);
      ComboSource.Items.Clear;
      for I := 0 to LCount - 1 do
      begin
        // 24 characters, not terminated when the name fills them
        LNameLength := 0;
        while (LNameLength < Length(LBinNames[I])) and (LBinNames[I][LNameLength] <> #0) do
          Inc(LNameLength);
        SetString(LBinName, PWideChar(@LBinNames[I][0]), LNameLength);
        ComboSource.Items.Add(IntToStr(LBins[I]) + '-' + UTF8Encode(LBinName));
      end;
      ComboSource.ItemIndex := 0;
    end
    else
    if LCount = 0 then
    begin
      ComboSource.Items.Clear;
      ComboSource.Items.Add(SRpNo);
      ComboSource.ItemIndex := 0;
    end;
    // Device context capabilities (information context, nothing printed)
    LDC := CreateICW(PWideChar(LDriver), PWideChar(LName), nil, LDevMode);
    if LDC <> 0 then
    try
      LWidth := GetDeviceCaps(LDC, PHYSICALWIDTH);
      LHeight := GetDeviceCaps(LDC, PHYSICALHEIGHT);
      if (LWidth > 0) and (GetDeviceCaps(LDC, LOGPIXELSX) > 0) and
         (GetDeviceCaps(LDC, LOGPIXELSY) > 0) then
        EPageSize.Text := TwipsSizeText(
          Round(LWidth / GetDeviceCaps(LDC, LOGPIXELSX) * TWIPS_PER_INCHESS),
          Round(LHeight / GetDeviceCaps(LDC, LOGPIXELSY) * TWIPS_PER_INCHESS));
      case GetDeviceCaps(LDC, TECHNOLOGY) of
        DT_PLOTTER: ETechnology.Text := SRSPlotter;
        DT_RASDISPLAY: ETechnology.Text := SRSRasterDisplay;
        DT_RASPRINTER: ETechnology.Text := SRSRasterPrinter;
        DT_RASCAMERA: ETechnology.Text := SRSRasterCamera;
        DT_CHARSTREAM: ETechnology.Text := SRSCharStream;
        DT_METAFILE: ETechnology.Text := SRpSMetafile;
        DT_DISPFILE: ETechnology.Text := SRSDisplayFile;
      else
        ETechnology.Text := SRpSUnknownType;
      end;
      LCaps := GetDeviceCaps(LDC, LINECAPS);
      if LCaps = LC_NONE then
        CLineCaps.Items.Add(SRpNone)
      else
      begin
        CLineCaps.Items.Add(SRpYes);
        if (LCaps and LC_POLYLINE) <> 0 then CLineCaps.Items.Add(SRpSPolyline);
        if (LCaps and LC_MARKER) <> 0 then CLineCaps.Items.Add(SRpSMarker);
        if (LCaps and LC_WIDE) <> 0 then CLineCaps.Items.Add(SRpSWideCap);
        if (LCaps and LC_STYLED) <> 0 then CLineCaps.Items.Add(SRpSSTyledCap);
        if (LCaps and LC_WIDESTYLED) <> 0 then CLineCaps.Items.Add(SRpSWideSTyledCap);
        if (LCaps and LC_INTERIORS) <> 0 then CLineCaps.Items.Add(SRpSInteriorsCap);
      end;
      CLineCaps.ItemIndex := 0;
      LCaps := GetDeviceCaps(LDC, POLYGONALCAPS);
      if LCaps = PC_NONE then
        CPolyCaps.Items.Add(SRpNone)
      else
      begin
        CPolyCaps.Items.Add(SRpYes);
        if (LCaps and PC_POLYGON) <> 0 then CPolyCaps.Items.Add(SRpSPolygon);
        if (LCaps and PC_RECTANGLE) <> 0 then CPolyCaps.Items.Add(SRpSRectanglecap);
        if (LCaps and PC_WINDPOLYGON) <> 0 then CPolyCaps.Items.Add(SRpSWindPolygon);
        if (LCaps and PC_STYLED) <> 0 then CPolyCaps.Items.Add(SRpSSTyledCap);
        if (LCaps and PC_WIDE) <> 0 then CPolyCaps.Items.Add(SRpSWideCap);
        if (LCaps and PC_WIDESTYLED) <> 0 then CPolyCaps.Items.Add(SRpSWideSTyledCap);
        if (LCaps and PC_INTERIORS) <> 0 then CPolyCaps.Items.Add(SRpSInteriorsCap);
      end;
      CPolyCaps.ItemIndex := 0;
      LCaps := GetDeviceCaps(LDC, CURVECAPS);
      if LCaps = CC_NONE then
        CCurveCaps.Items.Add(SRpNone)
      else
      begin
        CCurveCaps.Items.Add(SRpYes);
        if (LCaps and CC_CIRCLES) <> 0 then CCurveCaps.Items.Add(SRpSCircleCap);
        if (LCaps and CC_PIE) <> 0 then CCurveCaps.Items.Add(SRpSPiecap);
        if (LCaps and CC_CHORD) <> 0 then CCurveCaps.Items.Add(SRpSCHordCap);
        if (LCaps and CC_ELLIPSES) <> 0 then CCurveCaps.Items.Add(SRpSEllipses);
        if (LCaps and CC_ROUNDRECT) <> 0 then CCurveCaps.Items.Add(SRpSRoundRectCap);
        if (LCaps and CC_STYLED) <> 0 then CCurveCaps.Items.Add(SRpSSTyledCap);
        if (LCaps and CC_WIDE) <> 0 then CCurveCaps.Items.Add(SRpSWideCap);
        if (LCaps and CC_WIDESTYLED) <> 0 then CCurveCaps.Items.Add(SRpSWideSTyledCap);
        if (LCaps and CC_INTERIORS) <> 0 then CCurveCaps.Items.Add(SRpSInteriorsCap);
      end;
      CCurveCaps.ItemIndex := 0;
      LCaps := GetDeviceCaps(LDC, RASTERCAPS);
      if (LCaps and RC_BANDING) <> 0 then CRasterCaps.Items.Add(SRpSBandingRequired);
      if (LCaps and RC_BITBLT) <> 0 then CRasterCaps.Items.Add(SRpSBitmapTransfer);
      if (LCaps and RC_BITMAP64) <> 0 then CRasterCaps.Items.Add(SRpSBitmapTransfer64);
      if (LCaps and RC_DI_BITMAP) <> 0 then CRasterCaps.Items.Add(SRpSDIBTransfer);
      if (LCaps and RC_DIBTODEV) <> 0 then CRasterCaps.Items.Add(SRpSDIBDevTransfer);
      if (LCaps and RC_FLOODFILL) <> 0 then CRasterCaps.Items.Add(SRpSFloodFillcap);
      if (LCaps and RC_GDI20_OUTPUT) <> 0 then CRasterCaps.Items.Add(SRpSGDI20Out);
      if (LCaps and RC_PALETTE) <> 0 then CRasterCaps.Items.Add(SRPSPaletteDev);
      if (LCaps and RC_SCALING) <> 0 then CRasterCaps.Items.Add(SRpSScalingCap);
      if (LCaps and RC_STRETCHBLT) <> 0 then CRasterCaps.Items.Add(SRpSStretchCap);
      if (LCaps and RC_STRETCHDIB) <> 0 then CRasterCaps.Items.Add(SRpSStretchDIBCap);
      if CRasterCaps.Items.Count = 0 then
        CRasterCaps.Items.Add(SRpNone)
      else
        CRasterCaps.Items.Insert(0, SRpYes);
      CRasterCaps.ItemIndex := 0;
      LCaps := GetDeviceCaps(LDC, TEXTCAPS);
      if (LCaps and TC_OP_CHARACTER) <> 0 then CTextCaps.Items.Add(SRpSCharOutput);
      if (LCaps and TC_OP_STROKE) <> 0 then CTextCaps.Items.Add(SRpSCharStroke);
      if (LCaps and TC_CP_STROKE) <> 0 then CTextCaps.Items.Add(SRpSClipStroke);
      if (LCaps and TC_CR_90) <> 0 then CTextCaps.Items.Add(SRpS90Rotation);
      if (LCaps and TC_CR_ANY) <> 0 then CTextCaps.Items.Add(SRpSAnyRotation);
      if (LCaps and TC_SF_X_YINDEP) <> 0 then CTextCaps.Items.Add(SRpSScaleXY);
      if (LCaps and TC_SA_DOUBLE) <> 0 then CTextCaps.Items.Add(SRpSDoubleChar);
      if (LCaps and TC_SA_INTEGER) <> 0 then CTextCaps.Items.Add(SRpSIntegerScale);
      if (LCaps and TC_SA_CONTIN) <> 0 then CTextCaps.Items.Add(SRpSAnyrScale);
      if (LCaps and TC_EA_DOUBLE) <> 0 then CTextCaps.Items.Add(SRpSDoubleWeight);
      if (LCaps and TC_IA_ABLE) <> 0 then CTextCaps.Items.Add(SRpItalic);
      if (LCaps and TC_UA_ABLE) <> 0 then CTextCaps.Items.Add(SRpUnderline);
      if (LCaps and TC_SO_ABLE) <> 0 then CTextCaps.Items.Add(SRpStrikeOut);
      if (LCaps and TC_RA_ABLE) <> 0 then CTextCaps.Items.Add(SRpRasterFonts);
      if (LCaps and TC_VA_ABLE) <> 0 then CTextCaps.Items.Add(SRpVectorFonts);
      if (LCaps and TC_SCROLLBLT) <> 0 then CTextCaps.Items.Add(SRpNobitBlockScroll);
      if CTextCaps.Items.Count = 0 then
        CTextCaps.Items.Add(SRpNone)
      else
        CTextCaps.Items.Insert(0, SRpYes);
      CTextCaps.ItemIndex := 0;
    finally
      DeleteDC(LDC);
    end;
  finally
    if Assigned(LDevMode) then
      FreeMem(LDevMode);
    ClosePrinter(LHandle);
  end;
end;
{$ENDIF}

{$IFDEF UNIX}
procedure TFRpSysInfoLCL.FillCupsPrinterInfo(const APrinterName: string);
var
  LLib: TLibHandle;
  LGetDests: TCupsGetDests;
  LFreeDests: TCupsFreeDests;
  LGetOption: TCupsGetOption;
  LDests, LDest: PRpCupsDest;
  LCount, I, LType: Integer;

  function Option(const AName: string): string;
  var
    LValue: PAnsiChar;
  begin
    LValue := LGetOption(PAnsiChar(AName), LDest^.num_options, LDest^.options);
    if Assigned(LValue) then
      Result := string(LValue)
    else
      Result := '';
  end;

begin
  LLib := LoadLibrary('libcups.so.2');
  if LLib = NilHandle then
    LLib := LoadLibrary('libcups.so');
  if LLib = NilHandle then
    Exit;
  try
    LGetDests := TCupsGetDests(GetProcedureAddress(LLib, 'cupsGetDests'));
    LFreeDests := TCupsFreeDests(GetProcedureAddress(LLib, 'cupsFreeDests'));
    LGetOption := TCupsGetOption(GetProcedureAddress(LLib, 'cupsGetOption'));
    if not (Assigned(LGetDests) and Assigned(LFreeDests) and Assigned(LGetOption)) then
      Exit;
    LDests := nil;
    LCount := LGetDests(@LDests);
    try
      for I := 0 to LCount - 1 do
      begin
        LDest := PRpCupsDest(PByte(LDests) + I * SizeOf(TRpCupsDest));
        if (LDest^.instance <> nil) or (string(LDest^.name) <> APrinterName) then
          Continue;
        if Option('printer-info') <> '' then
          EDevice.Text := Option('printer-info');
        EDriver.Text := Option('printer-make-and-model');
        EPort.Text := Option('device-uri');
        ELocation.Text := Option('printer-location');
        if Option('printer-state') = '3' then
          EStatus.Text := SRpSReady
        else
        if Option('printer-state') = '4' then
          EStatus.Text := TranslateStr(1813, 'Printing')
        else
        if Option('printer-state') = '5' then
          EStatus.Text := TranslateStr(1814, 'Stopped');
        if (Option('printer-state-reasons') <> '') and
           (Option('printer-state-reasons') <> 'none') then
          EStatus.Text := EStatus.Text + ' (' + Option('printer-state-reasons') + ')';
        LType := StrToIntDef(Option('printer-type'), -1);
        if LType >= 0 then
        begin
          if (LType and CUPS_PRINTER_COLOR) <> 0 then
            EColor.Text := SRpSColorPrinting
          else
            EColor.Text := SRpSMonoPrinting;
          EDuplex.Text := YesNo((LType and CUPS_PRINTER_DUPLEX) <> 0);
          EMaxCopies.Text := YesNo((LType and CUPS_PRINTER_COPIES) <> 0);
          ECollation.Text := YesNo((LType and CUPS_PRINTER_COLLATE) <> 0);
          if (LType and CUPS_PRINTER_REMOTE) <> 0 then
            EPrinterType.Text := TranslateStr(1811, 'Network')
          else
            EPrinterType.Text := TranslateStr(1810, 'Local');
        end;
        Break;
      end;
    finally
      if Assigned(LDests) then
        LFreeDests(LCount, LDests);
    end;
  finally
    UnloadLibrary(LLib);
  end;
end;
{$ENDIF}

end.
