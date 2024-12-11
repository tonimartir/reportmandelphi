unit rptruetype;


interface

uses
  SysUtils, Classes, Generics.Collections;

type
  TTableData = class
  private
    FTableName: string;
    FLocation: Integer;
    FLength: Integer;
    FChecksum: Integer;
  public
    constructor Create(const ATableName: string; ALocation, ALength, AChecksum: Integer);
    property TableName: string read FTableName write FTableName;
    property Location: Integer read FLocation write FLocation;
    property Length: Integer read FLength write FLength;
    property Checksum: Integer read FChecksum write FChecksum;
  end;


TTrueTypeFontSubSet = class
  private
    const
      TableNameConst: array[0..8] of string = ('cvt ', 'fpgm', 'glyf', 'head', 'hhea', 'hmtx', 'loca', 'maxp', 'prep');
      EntrySelec: array[0..20] of Integer = (0, 0, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4);
      HeadLocaFormatOffset = 51;

      Arg1And2AreWords = 1;
      WeHaveAScale = 8;
      MoreComponents = 32;
      WeHaveAnXAndYScale = 64;
      WeHaveATwoByTwo = 128;
  private
    FPostScriptName: string;
    FTables: TDictionary<string, TTableData>;
    FRFArray: TBytes;
    FLocaShortTable: Boolean;
    FLocaTable: TArray<Integer>;
    FGlyphsUsed: TDictionary<Integer, TArray<Integer>>;
    FGlyphsInList: TList<Integer>;
    FTableGlyphOffset: Integer;
    FNewLocaTable: TArray<Integer>;
    FNewLocaTableOut: TBytes;
    FNewGlyfTable: TBytes;
    FGlyfTableRealSize: Integer;
    FLocaTableRealSize: Integer;
    FOutFont: TBytes;
    FFontPtr: Integer;
    FDirectoryOffset: Cardinal;

    procedure AssembleFont;
    procedure CreateTableDirectory;
    procedure ReadLoca;
    procedure FlatGlyphs;
    procedure CreateNewGlyphTables;
    procedure LocaToBytes;
    procedure CheckGlyphComposite(Glyph: Integer);
    function CalculateChecksum(const Data: TBytes): Integer;
    procedure WriteFontShort(Value: Integer);
    procedure WriteFontInt(Value: Integer);
    procedure WriteFontString(const Value: string);
    procedure ReadBytes(StartIndex: Integer; var Buffer: TBytes; Offset, Length: Integer);
    function GetPostcriptName(Offset: Integer): string;
  public
    constructor Create(const FontName: string; const RFArray: TBytes; GlyphsUsed: TDictionary<Integer, TArray<Integer>>; DirectoryOffset: Cardinal);
    function Execute: TBytes;
  end;
implementation

function ByteArrayToInt(const B: TBytes; Index: Integer; Length: Integer): Integer;
begin
  case Length of
    0: Result := 0;
    1: Result := B[Index];
    2: Result := (B[Index] shl 8) or B[Index + 1];
    3: Result := (B[Index] shl 16) or (B[Index + 1] shl 8) or B[Index + 2];
    4: Result := (B[Index] shl 24) or (B[Index + 1] shl 16) or (B[Index + 2] shl 8) or B[Index + 3];
  else
    raise Exception.Create('Invalid byte length');
  end;
end;

function ByteArrayToUInt(const B: TBytes; Index: Integer; Length: Integer): Cardinal;
begin
  case Length of
    0: Result := 0;
    1: Result := B[Index];
    2: Result := (B[Index] shl 8) or B[Index + 1];
    3: Result := (B[Index] shl 16) or (B[Index + 1] shl 8) or B[Index + 2];
    4: Result := (B[Index] shl 24) or (B[Index + 1] shl 16) or (B[Index + 2] shl 8) or B[Index + 3];
  else
    raise Exception.Create('Invalid byte length');
  end;
end;

function ByteArrayToUShort(const B: TBytes; Index: Integer; Length: Integer): Word;
begin
  case Length of
    0: Result := 0;
    1: Result := B[Index];
    2: Result := (B[Index] shl 8) or B[Index + 1];
  else
    raise Exception.Create('Invalid byte length');
  end;
end;

function ByteArrayToShort(const B: TBytes; Index: Integer; Length: Integer): SmallInt;
var
 int1: Integer;
 int2: Integer;
begin
  case Length of
    0: Result := 0;
    1: Result := B[Index];
    2:
     begin
      int1:=B[Index];
      int1:=int1 shl 8;
      int2:=B[Index + 1];
      int1:=int1 + int2;
      Result:=SmallInt(int1);
     end;
     // Result := (Integer(B[Index]) shl 8) or SmallInt(B[Index + 1]);
  else
    raise Exception.Create('Invalid byte length');
  end;
end;


constructor TTableData.Create(const ATableName: string; ALocation, ALength, AChecksum: Integer);
begin
  FTableName := ATableName;
  FLocation := ALocation;
  FLength := ALength;
  FChecksum := AChecksum;
end;

constructor TTrueTypeFontSubSet.Create(const FontName: string; const RFArray: TBytes; GlyphsUsed: TDictionary<Integer, TArray<Integer>>; DirectoryOffset: Cardinal);
begin
  FPostScriptName := UpperCase(Trim(FontName));
  FRFArray := RFArray;
  FGlyphsUsed := GlyphsUsed;
  FGlyphsInList := TList<Integer>.Create;
  FGlyphsInList.AddRange(GlyphsUsed.Keys);
  FDirectoryOffset := DirectoryOffset;
end;

function TTrueTypeFontSubSet.Execute: TBytes;
begin
  CreateTableDirectory;
  ReadLoca;
  FlatGlyphs;
  CreateNewGlyphTables;
  LocaToBytes;
  AssembleFont;
  Result := FOutFont;
end;

procedure TTrueTypeFontSubSet.AssembleFont;
var
  FullFontSize, TablesUsed, Len, Selector, IRef, K: Integer;
  Name: string;
  TableData: TTableData;
begin
  FullFontSize := 0;
  TablesUsed := 2;
  Len := 0;

  for K := Low(TableNameConst) to High(TableNameConst) do
  begin
    Name := TableNameConst[K];
    if (Name = 'glyf') or (Name = 'loca') then
      Continue;
    if not FTables.ContainsKey(Name) then
      Continue;

    TableData := FTables[Name];
    if TableData = nil then
      Continue;

    Inc(TablesUsed);
    FullFontSize := FullFontSize + ((TableData.Length + 3) and not 3);
  end;

  FullFontSize := FullFontSize + Length(FNewLocaTableOut) + Length(FNewGlyfTable);
  IRef := 16 * TablesUsed + 12;
  FullFontSize := FullFontSize + IRef;

  SetLength(FOutFont, FullFontSize);
  FFontPtr := 0;

  WriteFontInt($00010000);
  WriteFontShort(TablesUsed);
  Selector := EntrySelec[TablesUsed];
  WriteFontShort((1 shl Selector) * 16);
  WriteFontShort(Selector);
  WriteFontShort((TablesUsed - (1 shl Selector)) * 16);

  for K := Low(TableNameConst) to High(TableNameConst) do
  begin
    Name := TableNameConst[K];
    if not FTables.ContainsKey(Name) then
      Continue;

    TableData := FTables[Name];
    if TableData = nil then
      Continue;

    WriteFontString(Name);
    if Name = 'glyf' then
    begin
      WriteFontInt(CalculateChecksum(FNewGlyfTable));
      Len := FGlyfTableRealSize;
    end
    else if Name = 'loca' then
    begin
      WriteFontInt(CalculateChecksum(FNewLocaTableOut));
      Len := FLocaTableRealSize;
    end
    else
    begin
      WriteFontInt(TableData.Checksum);
      Len := TableData.Length;
    end;
    WriteFontInt(IRef);
    WriteFontInt(Len);
    IRef := IRef + ((Len + 3) and not 3);
  end;

  for K := Low(TableNameConst) to High(TableNameConst) do
  begin
    Name := TableNameConst[K];
    if not FTables.ContainsKey(Name) then
      Continue;

    TableData := FTables[Name];
    if TableData = nil then
      Continue;

    if Name = 'glyf' then
    begin
      Move(FNewGlyfTable[0], FOutFont[FFontPtr], Length(FNewGlyfTable));
      Inc(FFontPtr, Length(FNewGlyfTable));
    end
    else if Name = 'loca' then
    begin
      Move(FNewLocaTableOut[0], FOutFont[FFontPtr], Length(FNewLocaTableOut));
      Inc(FFontPtr, Length(FNewLocaTableOut));
    end
    else
    begin
      Move(FRFArray[TableData.Location], FOutFont[FFontPtr], TableData.Length);
      Inc(FFontPtr, (TableData.Length + 3) and not 3);
    end;
  end;
end;

procedure TTrueTypeFontSubSet.CreateTableDirectory;
var
  ID, NumTables, NIndex, Checksum, Location, Length: Integer;
  Tag: string;
  TData: TTableData;
  MajorVersion, MinorVersion: Word;
  NumFonts, I: Cardinal;
  TTcfHeader, PSName, PSNameNorm, PostNorm: string;
  Offsets: TArray<Cardinal>;
  Found: Boolean;
begin
  FTables := TDictionary<string, TTableData>.Create;

  ID := ByteArrayToInt(FRFArray, FDirectoryOffset, 4);  // Usamos ByteArrayToInt con tres parámetros
  NIndex := FDirectoryOffset + 4;

  if ID <> $00010000 then
  begin
    TTcfHeader := TEncoding.ANSI.GetString(FRFArray, 0, 4);
    if TTcfHeader = 'ttcf' then
    begin
      Inc(FDirectoryOffset, 4);
      MajorVersion := ByteArrayToUShort(FRFArray, FDirectoryOffset, 2);  // Usamos ByteArrayToUShort con tres parámetros
      Inc(FDirectoryOffset, 2);
      MinorVersion := ByteArrayToUShort(FRFArray, FDirectoryOffset, 2);  // Usamos ByteArrayToUShort con tres parámetros
      Inc(FDirectoryOffset, 2);
      NumFonts := ByteArrayToUInt(FRFArray, FDirectoryOffset, 4);  // Usamos ByteArrayToUInt con tres parámetros
      Inc(FDirectoryOffset, 4);

      if NumFonts > 1000 then
        NumFonts := 1000;

      SetLength(Offsets, NumFonts);
      Found := False;

      for I := 0 to NumFonts - 1 do
      begin
        Offsets[I] := ByteArrayToUInt(FRFArray, FDirectoryOffset + I * 4, 4);  // Usamos ByteArrayToUInt con tres parámetros
        PSName := GetPostcriptName(Offsets[I]);
        PSNameNorm := UpperCase(StringReplace(PSName, ',', '-', [rfReplaceAll]));
        PostNorm := UpperCase(StringReplace(FPostScriptName, ',', '-', [rfReplaceAll]));

        if PostNorm = PSNameNorm then
        begin
          Found := True;
          FDirectoryOffset := Offsets[I] + 4;
          NIndex := FDirectoryOffset;
          Break;
        end;
      end;

      if not Found then
      begin
        FDirectoryOffset := Offsets[0] + 4;
        NIndex := FDirectoryOffset;
      end;
    end
    else
      raise Exception.Create('The font is not a TrueType font or TrueType font collection');
  end;

  NumTables := ByteArrayToUShort(FRFArray, NIndex, 2);  // Usamos ByteArrayToUShort con tres parámetros
  Inc(NIndex, 2);
  Inc(NIndex, 6);  // Skip 6 bytes for searchRange, entrySelector, rangeShift

  for I := 0 to NumTables - 1 do
  begin
    Tag := TEncoding.ANSI.GetString(FRFArray, NIndex, 4);
    Inc(NIndex, 4);
    Checksum := ByteArrayToInt(FRFArray, NIndex, 4);  // Usamos ByteArrayToInt con tres parámetros
    Inc(NIndex, 4);
    Location := ByteArrayToInt(FRFArray, NIndex, 4);  // Usamos ByteArrayToInt con tres parámetros
    Inc(NIndex, 4);
    Length := ByteArrayToInt(FRFArray, NIndex, 4);  // Usamos ByteArrayToInt con tres parámetros
    Inc(NIndex, 4);

    TData := TTableData.Create(Tag, Location, Length, Checksum);
    FTables.Add(Tag, TData);
  end;
end;


procedure TTrueTypeFontSubSet.ReadLoca;
var
  TData: TTableData;
  NIndex, Entries, K: Integer;
  CachedLocaTables: TDictionary<string, TArray<Integer>>;
begin
  TData := FTables['head'];
  if TData = nil then
    raise Exception.Create('Table head not found');

  NIndex := TData.Location + HeadLocaFormatOffset;
  FLocaShortTable := ByteArrayToUShort(FRFArray, NIndex, 2) = 0;  // Usamos ByteArrayToUShort con tres parámetros
  Inc(NIndex, 4);

  // Cached Loca Tables
  CachedLocaTables := TDictionary<string, TArray<Integer>>.Create;

  if CachedLocaTables.ContainsKey(FPostScriptName) then
    FLocaTable := CachedLocaTables[FPostScriptName]
  else
  begin
    TData := FTables['loca'];
    if TData = nil then
      raise Exception.Create('Table loca not found');

    NIndex := TData.Location;
    if FLocaShortTable then
    begin
      Entries := TData.Length div 2;
      SetLength(FLocaTable, Entries);

      for K := 0 to Entries - 1 do
      begin
        FLocaTable[K] := ByteArrayToUShort(FRFArray, NIndex, 2) * 2;  // Usamos ByteArrayToUShort con tres parámetros
        Inc(NIndex, 2);
      end;
    end
    else
    begin
      Entries := TData.Length div 4;
      SetLength(FLocaTable, Entries);

      for K := 0 to Entries - 1 do
      begin
        FLocaTable[K] := ByteArrayToInt(FRFArray, NIndex, 4);  // Usamos ByteArrayToInt con tres parámetros
        Inc(NIndex, 4);
      end;
    end;

    CachedLocaTables.Add(FPostScriptName, FLocaTable);
  end;
end;

procedure TTrueTypeFontSubSet.FlatGlyphs;
var
  TData: TTableData;
  Glyph0, K: Integer;
begin
  TData := FTables['glyf'];
  if TData = nil then
    raise Exception.Create('Table glyf not found');

  Glyph0 := 0;
  if not FGlyphsUsed.ContainsKey(Glyph0) then
  begin
    FGlyphsUsed.Add(Glyph0, nil);
    FGlyphsInList.Add(Glyph0);
  end;

  FTableGlyphOffset := TData.Location;

  for K := 0 to FGlyphsInList.Count - 1 do
  begin
    CheckGlyphComposite(FGlyphsInList[K]);
  end;
end;


procedure TTrueTypeFontSubSet.CheckGlyphComposite(Glyph: Integer);
var
  Start, NIndex, NumContours, Flags, CGlyph, Skip: Integer;
begin
  Start := FLocaTable[Glyph];
  if (Glyph < Length(FLocaTable) - 1) and (Start = FLocaTable[Glyph + 1]) then
    Exit;

  NIndex := FTableGlyphOffset + Start;
  NumContours := ByteArrayToShort(FRFArray, NIndex, 2);  // Usamos ByteArrayToShort con tres parámetros
  Inc(NIndex, 2);

  if NumContours >= 0 then
    Exit;

  Inc(NIndex, 8); // Skip 8 bytes of bounding box data

  while True do
  begin
    Flags := ByteArrayToUShort(FRFArray, NIndex, 2);  // Usamos ByteArrayToUShort con tres parámetros
    Inc(NIndex, 2);
    CGlyph := ByteArrayToUShort(FRFArray, NIndex, 2);  // Usamos ByteArrayToUShort con tres parámetros
    Inc(NIndex, 2);

    if not FGlyphsUsed.ContainsKey(CGlyph) then
    begin
      if CGlyph < Length(FLocaTable) then
      begin
        FGlyphsUsed.Add(CGlyph, nil);
        FGlyphsInList.Add(CGlyph);
      end;
    end;

    if (Flags and MoreComponents) = 0 then
      Exit;

    if (Flags and Arg1And2AreWords) <> 0 then
      Skip := 4
    else
      Skip := 2;

    if (Flags and WeHaveAScale) <> 0 then
      Inc(Skip, 2)
    else if (Flags and WeHaveAnXAndYScale) <> 0 then
      Inc(Skip, 4)
    else if (Flags and WeHaveATwoByTwo) <> 0 then
      Inc(Skip, 8);

    Inc(NIndex, Skip);
  end;
end;

procedure TTrueTypeFontSubSet.CreateNewGlyphTables;
var
  ActiveGlyphs: TArray<Integer>;
  GlyfSize, Glyph, GlyphLength, NewGlyphPtr, Start, Len, GlyfPtr, ListGlyf, K: Integer;
begin
  SetLength(FNewLocaTable, Length(FLocaTable));
  ActiveGlyphs := FGlyphsInList.ToArray;
  TArray.Sort<Integer>(ActiveGlyphs);

  GlyfSize := 0;
  for K := 0 to High(ActiveGlyphs) do
  begin
    Glyph := ActiveGlyphs[K];
    GlyphLength := FLocaTable[Glyph + 1] - FLocaTable[Glyph];
    if FLocaShortTable then
      GlyphLength := GlyphLength * 2;
    Inc(GlyfSize, GlyphLength);
  end;

  FGlyfTableRealSize := GlyfSize;
  GlyfSize := (GlyfSize + 3) and not 3;
  SetLength(FNewGlyfTable, GlyfSize);

  GlyfPtr := 0;
  ListGlyf := 0;

  for K := 0 to High(FNewLocaTable) do
  begin
    NewGlyphPtr := GlyfPtr;
    if FLocaShortTable then
      NewGlyphPtr := GlyfPtr div 2;

    FNewLocaTable[K] := NewGlyphPtr;

    if (ListGlyf < Length(ActiveGlyphs)) and (ActiveGlyphs[ListGlyf] = K) then
    begin
      Inc(ListGlyf);
      Start := FLocaTable[K];
      Len := FLocaTable[K + 1] - Start;

      if FLocaShortTable then
        Len := Len * 2;

      if Len > 0 then
      begin
        ReadBytes(FTableGlyphOffset + Start, FNewGlyfTable, GlyfPtr, Len);
        Inc(GlyfPtr, Len);
      end;
    end;
  end;
end;

procedure TTrueTypeFontSubSet.LocaToBytes;
var
  K: Integer;
begin
  if FLocaShortTable then
    FLocaTableRealSize := Length(FNewLocaTable) * 2
  else
    FLocaTableRealSize := Length(FNewLocaTable) * 4;

  SetLength(FNewLocaTableOut, (FLocaTableRealSize + 3) and not 3);
  FOutFont := FNewLocaTableOut;
  FFontPtr := 0;

  for K := 0 to High(FNewLocaTable) do
  begin
    if FLocaShortTable then
      WriteFontShort(FNewLocaTable[K] div 2)
    else
      WriteFontInt(FNewLocaTable[K]);
  end;
end;

procedure TTrueTypeFontSubSet.WriteFontShort(Value: Integer);
begin
  FOutFont[FFontPtr] := (Value shr 8) and $FF;
  Inc(FFontPtr);
  FOutFont[FFontPtr] := Value and $FF;
  Inc(FFontPtr);
end;

procedure TTrueTypeFontSubSet.WriteFontInt(Value: Integer);
begin
  FOutFont[FFontPtr] := (Value shr 24) and $FF;
  Inc(FFontPtr);
  FOutFont[FFontPtr] := (Value shr 16) and $FF;
  Inc(FFontPtr);
  FOutFont[FFontPtr] := (Value shr 8) and $FF;
  Inc(FFontPtr);
  FOutFont[FFontPtr] := Value and $FF;
  Inc(FFontPtr);
end;


procedure TTrueTypeFontSubSet.WriteFontString(const Value: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.ANSI.GetBytes(Value);
  Move(Bytes[0], FOutFont[FFontPtr], Length(Bytes));
  Inc(FFontPtr, Length(Bytes));
end;

procedure TTrueTypeFontSubSet.ReadBytes(StartIndex: Integer; var Buffer: TBytes; Offset, Length: Integer);
begin
  if Length = 0 then
    Exit;

  Move(FRFArray[StartIndex], Buffer[Offset], Length);
end;

{$OVERFLOWCHECKS OFF}
function TTrueTypeFontSubSet.CalculateChecksum(const Data: TBytes): Integer;
var
  Len, K, Ptr: Integer;
  V0, V1, V2, V3: Integer;
begin
  Len := Length(Data) div 4;
  V0 := 0;
  V1 := 0;
  V2 := 0;
  V3 := 0;
  Ptr := 0;

  for K := 0 to Len - 1 do
  begin
    V3 := V3 + (Data[Ptr] and $FF);
    Inc(Ptr);
    V2 := V2 + (Data[Ptr] and $FF);
    Inc(Ptr);
    V1 := V1 + (Data[Ptr] and $FF);
    Inc(Ptr);
    V0 := V0 + (Data[Ptr] and $FF);
    Inc(Ptr);
  end;

  Result := V0 + (V1 shl 8) + (V2 shl 16) + (V3 shl 24);
end;
{$OVERFLOWCHECKS ON}



function TTrueTypeFontSubSet.GetPostcriptName(Offset: Integer): string;
var
  ID, NumTables, NIndex, Checksum, Location, Length, NameOffset, StringOffset, I: Integer;
  Format, NameCount, PlatformId, PlatformSpecificId, LanguageId, NameId, Offset2, Len: Word;
  TData: TTableData;
  ByteName: TBytes;
  Name, PostName: string;
begin
  ID := ByteArrayToInt(FRFArray, Offset, 4);  // Usamos ByteArrayToInt con tres parámetros
  Inc(Offset, 4);

  if ID <> $00010000 then
    raise Exception.Create('Font collection to font offset error');

  NumTables := ByteArrayToUShort(FRFArray, Offset, 2);  // Usamos ByteArrayToUShort con tres parámetros
  Inc(Offset, 2);

  Inc(Offset, 6); // Skip searchRange, entrySelector, rangeShift

  TData := nil;

  for I := 0 to NumTables - 1 do
  begin
    Name := TEncoding.ANSI.GetString(FRFArray, Offset, 4);
    Inc(Offset, 4);
    Checksum := ByteArrayToInt(FRFArray, Offset, 4);  // Usamos ByteArrayToInt con tres parámetros
    Inc(Offset, 4);
    Location := ByteArrayToInt(FRFArray, Offset, 4);  // Usamos ByteArrayToInt con tres parámetros
    Inc(Offset, 4);
    Length := ByteArrayToInt(FRFArray, Offset, 4);  // Usamos ByteArrayToInt con tres parámetros
    Inc(Offset, 4);

    if Name = 'name' then
    begin
      TData := TTableData.Create(Name, Location, Length, Checksum);
      Break;
    end;
  end;

  if TData = nil then
    Exit('');

  Offset := TData.Location;
  Format := ByteArrayToUShort(FRFArray, Offset, 2);  // Usamos ByteArrayToUShort con tres parámetros
  Inc(Offset, 2);
  NameCount := ByteArrayToUShort(FRFArray, Offset, 2); // Usamos ByteArrayToUShort con tres parámetros
  Inc(Offset, 2);
  StringOffset := ByteArrayToUShort(FRFArray, Offset, 2); // Usamos ByteArrayToUShort con tres parámetros
  Inc(Offset, 2);

  PostName := '';

  for I := 0 to NameCount - 1 do
  begin
    PlatformId := ByteArrayToUShort(FRFArray, Offset, 2); // Usamos ByteArrayToUShort con tres parámetros
    Inc(Offset, 2);
    PlatformSpecificId := ByteArrayToUShort(FRFArray, Offset, 2); // Usamos ByteArrayToUShort con tres parámetros
    Inc(Offset, 2);
    LanguageId := ByteArrayToUShort(FRFArray, Offset, 2); // Usamos ByteArrayToUShort con tres parámetros
    Inc(Offset, 2);
    NameId := ByteArrayToUShort(FRFArray, Offset, 2); // Usamos ByteArrayToUShort con tres parámetros
    Inc(Offset, 2);
    Len := ByteArrayToUShort(FRFArray, Offset, 2); // Usamos ByteArrayToUShort con tres parámetros
    Inc(Offset, 2);
    Offset2 := ByteArrayToUShort(FRFArray, Offset, 2); // Usamos ByteArrayToUShort con tres parámetros
    Inc(Offset, 2);

    NameOffset := TData.Location + StringOffset + Offset2;
    SetLength(ByteName, Len);
    Move(FRFArray[NameOffset], ByteName[0], Len);

    if PlatformId = 0 then
      Name := TEncoding.Unicode.GetString(ByteName)
    else if PlatformId = 3 then
    begin
      Name := '';
      for NIndex := 0 to Len div 2 - 1 do
        Name := Name + WideChar(PWord(@ByteName[NIndex * 2])^);
    end
    else
      Name := TEncoding.ANSI.GetString(ByteName);

    if NameId = 6 then
    begin
      PostName := Name;
      Break;
    end;
  end;

  Result := PostName;
end;



end.


