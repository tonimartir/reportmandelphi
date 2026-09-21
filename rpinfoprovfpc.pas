{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       TRpFpcInfoProvider                              }
{       Minimal info provider for FPC on Windows        }
{       Uses Windows GDI32 for font metrics             }
{       No DirectWrite / ICU / HarfBuzz dependency      }
{                                                       }
{       Copyright (c) 1994-2024 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpinfoprovfpc;

{$IFDEF FPC}
{$IFDEF MSWINDOWS}

interface

{$I rpconf.inc}

uses
  Classes, SysUtils, Math,
  Windows,
  rpinfoprovid, rptypes, rpmunits, rpmdconsts;

type
  TRpFpcInfoProvider = class(TRpInfoProvider)
  private
    FDC: HDC;
    FFontHandle: HFONT;
    FCurrentName: string;
    FCurrentStyle: Integer;
    procedure SelectGDIFont(pdffont: TRpPDFFont);
    procedure ReleaseGDIFont;
    function MakeLogFont(const aFontName: string; aBold, aItalic: Boolean;
      aPixHeight: Integer): HFONT;
  public
    constructor Create;
    destructor Destroy; override;

    procedure FillFontData(pdffont: TRpPDFFont; data: TRpTTFontData; content: string); override;
    function TextExtent(const Text: WideString;
      var Rect: TRect; adata: TRpTTFontData; pdfFont: TRpPDFFont;
      wordwrap: Boolean; singleline: Boolean; FontSize: Double; IsHtml: Boolean): TRpLineInfoArray; override;
    function NFCNormalize(astring: WideString): WideString; override;
    function GetCharWidth(pdffont: TRpPDFFont; data: TRpTTFontData; charcode: WideChar): Double; override;
    function GetGlyphWidth(pdffont: TRpPDFFont; data: TRpTTFontData; glyph: Integer; charC: WideChar): Double; override;
    function GetKerning(pdffont: TRpPDFFont; data: TRpTTFontData; leftchar, rightchar: WideChar): Integer; override;
    function GetFontStream(data: TRpTTFontData): TMemoryStream; override;
    function GetFullFontStream(data: TRpTTFontData): TMemoryStream; override;
  end;

implementation

{ -----------------------------------------------------------------------
  Windows NFC normalization via NormalizeString API (kernel32 >= Vista)
  Falls back to returning the string unchanged on XP / error.
  ----------------------------------------------------------------------- }

type
  TNormalizationForm = Integer;
  TNormalizeStringProc = function(NormForm: TNormalizationForm;
    lpSrcString: LPCWSTR; cwSrcLength: Integer;
    lpDstString: LPWSTR; cwDstLength: Integer): Integer; stdcall;

var
  _NormalizeString: TNormalizeStringProc = nil;
  _NormalizeChecked: Boolean = False;

procedure LoadNormalizeString;
var
  hLib: HMODULE;
begin
  if _NormalizeChecked then Exit;
  _NormalizeChecked := True;
  hLib := GetModuleHandle('normaliz.dll');
  if hLib = 0 then
    hLib := LoadLibrary('normaliz.dll');
  if hLib <> 0 then
    _NormalizeString := TNormalizeStringProc(GetProcAddress(hLib, 'NormalizeString'));
end;

function NFCNormalizeStr(const S: WideString): WideString;
const
  NormalizationC: TNormalizationForm = 1; { NFC }
var
  requiredChars: Integer;
  writtenChars: Integer;
  buffer: PWideChar;
begin
  Result := S;
  if S = '' then Exit;
  LoadNormalizeString;
  if not Assigned(_NormalizeString) then Exit;
  requiredChars := _NormalizeString(NormalizationC, PWideChar(S), Length(S), nil, 0);
  if requiredChars <= 0 then Exit;
  GetMem(buffer, (requiredChars + 1) * SizeOf(WideChar));
  try
    writtenChars := _NormalizeString(NormalizationC, PWideChar(S), Length(S), buffer, requiredChars);
    if writtenChars > 0 then
    begin
      SetLength(Result, writtenChars);
      Move(buffer^, Result[1], writtenChars * SizeOf(WideChar));
    end;
  finally
    FreeMem(buffer);
  end;
end;

{ -----------------------------------------------------------------------
  Helper: copy a string to a fixed-size WideChar array (LOGFONTW.lfFaceName)
  ----------------------------------------------------------------------- }

procedure CopyToFaceName(var dest: array of WideChar; const src: WideString);
var
  i, maxLen: Integer;
begin
  maxLen := High(dest); { LF_FACESIZE - 1 = 31 }
  if maxLen > Length(src) then
    maxLen := Length(src);
  for i := 0 to maxLen - 1 do
    dest[i] := src[i + 1];
  dest[maxLen] := WideChar(0);
end;

{ -----------------------------------------------------------------------
  Helper: create a LOGFONTW-based HFONT
  ----------------------------------------------------------------------- }

function TRpFpcInfoProvider.MakeLogFont(const aFontName: string; aBold, aItalic: Boolean;
  aPixHeight: Integer): HFONT;
var
  lf: LOGFONTW;
begin
  FillChar(lf, SizeOf(lf), 0);
  lf.lfHeight         := aPixHeight;
  lf.lfWeight         := IfThen(aBold, FW_BOLD, FW_NORMAL);
  lf.lfItalic         := Byte(aItalic);
  lf.lfCharSet        := DEFAULT_CHARSET;
  lf.lfOutPrecision   := OUT_TT_PRECIS;
  lf.lfClipPrecision  := CLIP_DEFAULT_PRECIS;
  lf.lfQuality        := DEFAULT_QUALITY;
  lf.lfPitchAndFamily := DEFAULT_PITCH or FF_DONTCARE;
  CopyToFaceName(lf.lfFaceName, WideString(aFontName));
  Result := CreateFontIndirectW(@lf);
end;

procedure TRpFpcInfoProvider.SelectGDIFont(pdffont: TRpPDFFont);
var
  newKey: Integer;
  newName: string;
  hf: HFONT;
begin
  newName := pdffont.WFontName;
  newKey := pdffont.GetFullStyleKey;
  if (newName = FCurrentName) and (newKey = FCurrentStyle) then Exit;

  ReleaseGDIFont;
  FCurrentName := newName;
  FCurrentStyle := newKey;

  hf := MakeLogFont(newName, pdffont.Bold, pdffont.Italic, -20);
  FFontHandle := hf;
  if FFontHandle <> 0 then
    SelectObject(FDC, FFontHandle);
end;

procedure TRpFpcInfoProvider.ReleaseGDIFont;
begin
  if FFontHandle <> 0 then
  begin
    SelectObject(FDC, GetStockObject(SYSTEM_FONT));
    DeleteObject(FFontHandle);
    FFontHandle := 0;
  end;
end;

{ -----------------------------------------------------------------------
  TRpFpcInfoProvider
  ----------------------------------------------------------------------- }

constructor TRpFpcInfoProvider.Create;
begin
  inherited Create;
  FCurrentName := '';
  FCurrentStyle := 0;
  FFontHandle := 0;
  FDC := CreateCompatibleDC(0);
end;

destructor TRpFpcInfoProvider.Destroy;
begin
  ReleaseGDIFont;
  if FDC <> 0 then
    DeleteDC(FDC);
  inherited Destroy;
end;

{ NFCNormalize }
function TRpFpcInfoProvider.NFCNormalize(astring: WideString): WideString;
begin
  Result := NFCNormalizeStr(astring);
end;

{ FillFontData: populate TRpTTFontData using GDI TextMetrics }
procedure TRpFpcInfoProvider.FillFontData(pdffont: TRpPDFFont; data: TRpTTFontData; content: string);
var
  tm: TEXTMETRICW;
begin
  SelectGDIFont(pdffont);

  FillChar(tm, SizeOf(tm), 0);
  GetTextMetricsW(FDC, @tm);

  data.Height          := tm.tmHeight;
  data.Ascent          := tm.tmAscent;
  data.Descent         := tm.tmDescent;
  data.Leading         := tm.tmExternalLeading;
  data.ExternalLeading := tm.tmExternalLeading;
  data.InternalLeading := tm.tmInternalLeading;
  data.MaxWidth        := tm.tmMaxCharWidth;
  data.AvgWidth        := tm.tmAveCharWidth;
  data.FontWeight      := tm.tmWeight;
  data.FamilyName      := pdffont.WFontName;
  data.FaceName        := pdffont.WFontName;
  data.FullName        := pdffont.WFontName;
  data.postcriptname   := pdffont.WFontName;
  data.StyleName       := '';
  data.ItalicAngle     := 0;
  data.CapHeight       := tm.tmAscent;
  data.embedded        := False;
  data.truetype        := (tm.tmPitchAndFamily and TMPF_TRUETYPE) <> 0;
  data.type1           := False;
  data.CFF             := False;
  data.IsUnicode       := True;
  data.havekerning     := False;
  data.UnitsPerEM      := 1000;

  if pdffont.Bold then
    data.StemV := 120
  else
    data.StemV := 70;

  { PDF font flags: bit 5 (value 32) = Nonsymbolic }
  data.Flags := 32;
  if pdffont.Italic then
    data.Flags := data.Flags or 64;
  if (tm.tmPitchAndFamily and TMPF_FIXED_PITCH) = 0 then
    data.Flags := data.Flags or 1; { FixedPitch }

  data.FontBBox.Left   := 0;
  data.FontBBox.Top    := -data.Descent;
  data.FontBBox.Right  := data.MaxWidth;
  data.FontBBox.Bottom := data.Ascent;

  data.ObjectName        := '';
  data.ObjectIndex       := -1;
  data.ObjectIndexParent := -1;
  data.DescriptorIndex   := -1;
  data.ToUnicodeIndex    := -1;
end;

{ TextExtent: compute line layout using GDI GetTextExtentPoint32W }
function TRpFpcInfoProvider.TextExtent(const Text: WideString;
  var Rect: TRect; adata: TRpTTFontData; pdfFont: TRpPDFFont;
  wordwrap: Boolean; singleline: Boolean; FontSize: Double; IsHtml: Boolean): TRpLineInfoArray;
var
  hf, hfOld: HFONT;
  tm: TEXTMETRICW;
  sz: Windows.SIZE;
  lines: array of WideString;
  lineCount: Integer;
  i, lineStart, lineEnd, wordEnd: Integer;
  lineText: WideString;
  MaxW: Integer;
  LineInfo: TRpLineInfo;
  LineHeight: Integer;
  TotalHeight: Integer;
  MaxLineWidth: Integer;
  dpiY: Integer;
  pixH: Integer;
begin
  Result := nil;
  if Text = '' then Exit;

  dpiY := GetDeviceCaps(FDC, LOGPIXELSY);
  pixH := -Round(FontSize * dpiY / 72.0);
  if pixH = 0 then pixH := -12;

  hf := MakeLogFont(pdfFont.WFontName, pdfFont.Bold, pdfFont.Italic, pixH);
  hfOld := SelectObject(FDC, hf);
  try
    FillChar(tm, SizeOf(tm), 0);
    GetTextMetricsW(FDC, @tm);
    LineHeight := tm.tmHeight + tm.tmExternalLeading;
    MaxW := Rect.Right - Rect.Left;
    if MaxW <= 0 then MaxW := 100000;

    { Split text into lines }
    SetLength(lines, 0);
    lineCount := 0;
    lineStart := 1;
    i := 1;
    while i <= Length(Text) do
    begin
      if (Text[i] = #13) or (Text[i] = #10) then
      begin
        lineText := Copy(Text, lineStart, i - lineStart);
        if wordwrap and (not singleline) then
        begin
          while lineText <> '' do
          begin
            lineEnd := Length(lineText);
            repeat
              GetTextExtentPoint32W(FDC, PWideChar(lineText), lineEnd, sz);
              if (sz.cx <= MaxW) or (lineEnd <= 1) then Break;
              wordEnd := lineEnd;
              while (wordEnd > 1) and (lineText[wordEnd] <> ' ') do
                Dec(wordEnd);
              if wordEnd > 1 then
                lineEnd := wordEnd
              else
                Dec(lineEnd);
            until False;
            SetLength(lines, lineCount + 1);
            lines[lineCount] := Copy(lineText, 1, lineEnd);
            Inc(lineCount);
            lineText := TrimLeft(Copy(lineText, lineEnd + 1, MaxInt));
          end;
        end
        else
        begin
          SetLength(lines, lineCount + 1);
          lines[lineCount] := lineText;
          Inc(lineCount);
        end;
        if (Text[i] = #13) and (i < Length(Text)) and (Text[i+1] = #10) then
          Inc(i);
        lineStart := i + 1;
      end;
      Inc(i);
    end;
    { Last segment }
    lineText := Copy(Text, lineStart, MaxInt);
    if lineText <> '' then
    begin
      if wordwrap and (not singleline) then
      begin
        while lineText <> '' do
        begin
          lineEnd := Length(lineText);
          repeat
            GetTextExtentPoint32W(FDC, PWideChar(lineText), lineEnd, sz);
            if (sz.cx <= MaxW) or (lineEnd <= 1) then Break;
            wordEnd := lineEnd;
            while (wordEnd > 1) and (lineText[wordEnd] <> ' ') do
              Dec(wordEnd);
            if wordEnd > 1 then
              lineEnd := wordEnd
            else
              Dec(lineEnd);
          until False;
          SetLength(lines, lineCount + 1);
          lines[lineCount] := Copy(lineText, 1, lineEnd);
          Inc(lineCount);
          lineText := TrimLeft(Copy(lineText, lineEnd + 1, MaxInt));
        end;
      end
      else
      begin
        SetLength(lines, lineCount + 1);
        lines[lineCount] := lineText;
        Inc(lineCount);
      end;
    end;

    if lineCount = 0 then
    begin
      SetLength(lines, 1);
      lines[0] := '';
      lineCount := 1;
    end;

    if singleline and (lineCount > 1) then
    begin
      lineCount := 1;
      SetLength(lines, 1);
    end;

    SetLength(Result, lineCount);
    TotalHeight := 0;
    MaxLineWidth := 0;
    lineStart := 1;
    for i := 0 to lineCount - 1 do
    begin
      LineInfo.Position  := lineStart;
      LineInfo.Size      := Length(lines[i]);
      LineInfo.TopPos    := TotalHeight;
      LineInfo.height    := LineHeight;
      LineInfo.LineHeight := LineHeight;
      LineInfo.step      := rpcpi12;
      LineInfo.lastline  := (i = lineCount - 1);
      LineInfo.Text      := string(lines[i]);
      SetLength(LineInfo.Glyphs, 0);

      if lines[i] <> '' then
      begin
        GetTextExtentPoint32W(FDC, PWideChar(lines[i]), Length(lines[i]), sz);
        LineInfo.Width := sz.cx;
      end
      else
        LineInfo.Width := 0;

      if LineInfo.Width > MaxLineWidth then
        MaxLineWidth := LineInfo.Width;

      Result[i] := LineInfo;
      Inc(TotalHeight, LineHeight);
      Inc(lineStart, Length(lines[i]));
      if i < lineCount - 1 then
        Inc(lineStart);
    end;

    Rect.Right  := Rect.Left + MaxLineWidth;
    Rect.Bottom := Rect.Top + TotalHeight;
  finally
    SelectObject(FDC, hfOld);
    DeleteObject(hf);
  end;
end;

{ GetCharWidth: return width in 1/1000 of em (PDF glyph width unit) }
function TRpFpcInfoProvider.GetCharWidth(pdffont: TRpPDFFont; data: TRpTTFontData; charcode: WideChar): Double;
var
  hf, hfOld: HFONT;
  tm: TEXTMETRICW;
  charW: Integer;
  dpiX: Integer;
  pixH: Integer;
begin
  Result := 0;
  dpiX := GetDeviceCaps(FDC, LOGPIXELSX);
  pixH := -Round(pdffont.Size * dpiX / 72.0);
  if pixH = 0 then pixH := -12;

  hf := MakeLogFont(pdffont.WFontName, pdffont.Bold, pdffont.Italic, pixH);
  hfOld := SelectObject(FDC, hf);
  try
    FillChar(tm, SizeOf(tm), 0);
    GetTextMetricsW(FDC, @tm);
    if GetCharWidthW(FDC, Ord(charcode), Ord(charcode), @charW) then
    begin
      if tm.tmHeight <> 0 then
        Result := (charW * 1000.0) / tm.tmHeight
      else
        Result := charW;
    end
    else
    begin
      if tm.tmHeight <> 0 then
        Result := tm.tmAveCharWidth * 1000.0 / tm.tmHeight
      else
        Result := tm.tmAveCharWidth;
    end;
  finally
    SelectObject(FDC, hfOld);
    DeleteObject(hf);
  end;
end;

{ GetGlyphWidth: delegates to GetCharWidth }
function TRpFpcInfoProvider.GetGlyphWidth(pdffont: TRpPDFFont; data: TRpTTFontData; glyph: Integer; charC: WideChar): Double;
begin
  Result := GetCharWidth(pdffont, data, charC);
end;

{ GetKerning: no kerning in minimal stub }
function TRpFpcInfoProvider.GetKerning(pdffont: TRpPDFFont; data: TRpTTFontData; leftchar, rightchar: WideChar): Integer;
begin
  Result := 0;
end;

{ GetFontStream: return raw font bytes via GDI GetFontData }
function TRpFpcInfoProvider.GetFontStream(data: TRpTTFontData): TMemoryStream;
var
  hf, hfOld: HFONT;
  dataSize: DWORD;
  ms: TMemoryStream;
begin
  Result := nil;
  hf := MakeLogFont(data.FamilyName, False, False, -20);
  hfOld := SelectObject(FDC, hf);
  try
    dataSize := Windows.GetFontData(FDC, 0, 0, nil, 0);
    if (dataSize <> GDI_ERROR) and (dataSize > 0) then
    begin
      ms := TMemoryStream.Create;
      ms.SetSize(dataSize);
      if Windows.GetFontData(FDC, 0, 0, ms.Memory, dataSize) = dataSize then
        Result := ms
      else
        ms.Free;
    end;
  finally
    SelectObject(FDC, hfOld);
    DeleteObject(hf);
  end;
end;

{ GetFullFontStream: same as GetFontStream for this stub }
function TRpFpcInfoProvider.GetFullFontStream(data: TRpTTFontData): TMemoryStream;
begin
  Result := GetFontStream(data);
end;

{$ENDIF MSWINDOWS}
{$ENDIF FPC}

{$IFNDEF MSWINDOWS}
interface

implementation
{$ENDIF}

end.
