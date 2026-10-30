{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpdatamatrix                                    }
{       DataMatrix (ECC 200) symbol generation          }
{                                                       }
{       Uses libdmtx (dmtx*.pas), Pascal translation    }
{       by Ladislav Karrach of the C library by         }
{       Mike Laughton, Vadim A. Misbakh-Soloviov and    }
{       Tim Zaman (https://github.com/dmtx/libdmtx)     }
{                                                       }
{       This unit does not depend on VCL/LCL, so it     }
{       can be used by the cross-platform engine        }
{                                                       }
{*******************************************************}

unit rpdatamatrix;

{$IFDEF FPC}
 {$MODE DELPHI}
{$ENDIF}

interface

uses SysUtils, Classes;

type
 // Module matrix of a DataMatrix symbol, [row][column], row 0 is the top row.
 // True means a dark module. The quiet zone is not included.
 TRpDataMatrixModules = array of array of Boolean;

// Encodes AData (bytes, ASCII scheme) into a DataMatrix ECC 200 square symbol.
// Returns False when AData is empty, raises an exception when it can not be encoded.
function RpDataMatrixEncode(const AData: AnsiString;
 out AModules: TRpDataMatrixModules): Boolean;

// Returns a 24 bit BMP image of the symbol, AModuleSize pixels per module and
// AMargin pixels of white border. Returns nil when AData is empty.
function RpDataMatrixBitmapStream(const AData: AnsiString;
 AModuleSize, AMargin: Integer): TMemoryStream;

implementation

uses dmtx, dmtxencode, dmtxplacemod;

function RpDataMatrixEncode(const AData: AnsiString;
 out AModules: TRpDataMatrixModules): Boolean;
var
 enc: pDmtxEncode;
 rows, cols, row, col, status: Integer;
begin
 Result := False;
 SetLength(AModules, 0);
 if Length(AData) = 0 then
  Exit;
 enc := dmtxEncodeCreate();
 try
  dmtxEncodeSetProp(enc, DmtxPropPixelPacking, Ord(DmtxPack24bppRGB));
  dmtxEncodeSetProp(enc, DmtxPropImageFlip, 0);
  dmtxEncodeSetProp(enc, DmtxPropRowPadBytes, 0);
  dmtxEncodeSetProp(enc, DmtxPropMarginSize, 0);
  dmtxEncodeSetProp(enc, DmtxPropModuleSize, 1);
  dmtxEncodeSetProp(enc, DmtxPropScheme, Ord(DmtxSchemeAscii));
  if dmtxEncodeDataMatrix(enc, Length(AData), PAnsiChar(AData)) = DmtxFail then
   raise Exception.Create('DataMatrix: the data can not be encoded (too long?)');
  rows := enc^.region.symbolRows;
  cols := enc^.region.symbolCols;
  SetLength(AModules, rows, cols);
  // libdmtx symbol coordinates have row 0 at the bottom
  for row := 0 to rows - 1 do
   for col := 0 to cols - 1 do
   begin
    status := dmtxSymbolModuleStatus(enc^.message, enc^.region.sizeIdx,
     rows - 1 - row, col);
    AModules[row][col] := (status and DmtxModuleOnRed) <> 0;
   end;
  Result := True;
 finally
  dmtxEncodeDestroy(enc);
 end;
end;

function RpDataMatrixBitmapStream(const AData: AnsiString;
 AModuleSize, AMargin: Integer): TMemoryStream;
var
 modules: TRpDataMatrixModules;
 rows, cols, width, height, rowSize, x, y, mrow, mcol: Integer;
 line: array of Byte;
 dark: Boolean;
 fileHeader: packed record
  bfType: Word;
  bfSize: LongWord;
  bfReserved1: Word;
  bfReserved2: Word;
  bfOffBits: LongWord;
 end;
 infoHeader: packed record
  biSize: LongWord;
  biWidth: LongInt;
  biHeight: LongInt;
  biPlanes: Word;
  biBitCount: Word;
  biCompression: LongWord;
  biSizeImage: LongWord;
  biXPelsPerMeter: LongInt;
  biYPelsPerMeter: LongInt;
  biClrUsed: LongWord;
  biClrImportant: LongWord;
 end;
begin
 Result := nil;
 if not RpDataMatrixEncode(AData, modules) then
  Exit;
 if AModuleSize < 1 then
  AModuleSize := 1;
 if AMargin < 0 then
  AMargin := 0;
 rows := Length(modules);
 cols := Length(modules[0]);
 width := 2 * AMargin + cols * AModuleSize;
 height := 2 * AMargin + rows * AModuleSize;
 rowSize := ((width * 3) + 3) and not 3;

 FillChar(fileHeader, SizeOf(fileHeader), 0);
 FillChar(infoHeader, SizeOf(infoHeader), 0);
 fileHeader.bfType := $4D42; // 'BM'
 fileHeader.bfOffBits := SizeOf(fileHeader) + SizeOf(infoHeader);
 fileHeader.bfSize := fileHeader.bfOffBits + LongWord(rowSize * height);
 infoHeader.biSize := SizeOf(infoHeader);
 infoHeader.biWidth := width;
 infoHeader.biHeight := height;
 infoHeader.biPlanes := 1;
 infoHeader.biBitCount := 24;
 infoHeader.biSizeImage := rowSize * height;
 infoHeader.biXPelsPerMeter := 3780;
 infoHeader.biYPelsPerMeter := 3780;

 Result := TMemoryStream.Create;
 try
  Result.WriteBuffer(fileHeader, SizeOf(fileHeader));
  Result.WriteBuffer(infoHeader, SizeOf(infoHeader));
  SetLength(line, rowSize);
  // BMP rows are stored bottom-up
  for y := height - 1 downto 0 do
  begin
   FillChar(line[0], rowSize, $FF);
   mrow := y - AMargin;
   if (mrow >= 0) and (mrow < rows * AModuleSize) then
   begin
    mrow := mrow div AModuleSize;
    for x := 0 to cols * AModuleSize - 1 do
    begin
     mcol := x div AModuleSize;
     dark := modules[mrow][mcol];
     if dark then
     begin
      line[(AMargin + x) * 3] := 0;
      line[(AMargin + x) * 3 + 1] := 0;
      line[(AMargin + x) * 3 + 2] := 0;
     end;
    end;
   end;
   Result.WriteBuffer(line[0], rowSize);
  end;
  Result.Position := 0;
 except
  Result.Free;
  raise;
 end;
end;

end.
