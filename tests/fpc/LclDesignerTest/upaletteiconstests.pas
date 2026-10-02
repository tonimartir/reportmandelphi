unit upaletteiconstests;

{ The icons of the components of the three packages on the Lazarus palette,
  looked for as the IDE does (TLCLGlyphs, GetDefaultGlyph of imglist.inc):
  the class name for 100 % and the class name with _150 and _200 for 150 and
  200 %, first in the resources of the executable (RT_BITMAP, then
  RT_RCDATA) and then in the Lazarus resources (.lrs). Each one must be a
  PNG of 24, 36 or 48 pixels: an old bitmap of a Delphi .dcr linked with the
  same name would be found first (packages/icons/make_icons.sh). }

{$mode delphi}

interface

procedure RunPaletteIconTests;

implementation

uses
  SysUtils, LResources, Graphics,
  rpmreg, rpreglcl, rpmregdesignlcl, umainform;

const
  // The components registered by rpmreg (reportman_rtl), rpreglcl
  // (reportman_lcl) and rpmregdesignlcl (reportman_designlcl)
  PALETTE_CLASSES: array[0..9] of string = (
    'TRpEvaluator', 'TRpAlias', 'TRpLastUsedStrings', 'TRpTranslator',
    'TPDFReport', 'TLCLReport', 'TRpMaskEdit', 'TRpPreviewControl',
    'TRpDesignerLCL', 'TRpRulerLCL');
  SUFFIXES: array[0..2] of string = ('', '_150', '_200');
  SIZES: array[0..2] of Integer = (24, 36, 48);

procedure Fail(const Msg: string);
begin
  LogMsg('[TEST_FAILED] ' + Msg);
  Halt(1);
end;

// The image of a resource name, loaded as GetDefaultGlyph loads it
function LoadAsTheIDE(const AName: string): TCustomBitmap;
var
  LRes: TLResource;
begin
  Result := CreateBitmapFromResourceName(HINSTANCE, AName);
  if Result = nil then
  begin
    LRes := LazarusResources.Find(AName);
    if LRes <> nil then
      Result := CreateBitmapFromLazarusResource(LRes);
  end;
end;

procedure RunPaletteIconTests;
var
  i, j: Integer;
  LName: string;
  LImage: TCustomBitmap;
begin
  LogMsg('Palette icons: 24, 36 and 48 pixels for every component');
  for i := Low(PALETTE_CLASSES) to High(PALETTE_CLASSES) do
    for j := Low(SUFFIXES) to High(SUFFIXES) do
    begin
      LName := PALETTE_CLASSES[i] + SUFFIXES[j];
      LImage := LoadAsTheIDE(LName);
      try
        if LImage = nil then
          Fail(LName + ': no palette icon');
        if not (LImage is TPortableNetworkGraphic) then
          Fail(LName + ': the icon is a ' + LImage.ClassName +
            ', not the PNG of packages/icons');
        if (LImage.Width <> SIZES[j]) or (LImage.Height <> SIZES[j]) then
          Fail(Format('%s: %dx%d, expected %dx%d',
            [LName, LImage.Width, LImage.Height, SIZES[j], SIZES[j]]));
      finally
        LImage.Free;
      end;
    end;
  LogMsg('Palette icons verified');
end;

end.
