program test_fastserializer;

{*******************************************************}
{                                                       }
{   Cross-validation test for rpfastserializer.pas.     }
{                                                       }
{   Flow:                                               }
{    1. Load ..\fixtures\dotnet_fixture.bin produced by }
{       fixture_gen (C#).                               }
{    2. Deserialize with rpfastserializer into a        }
{       TClientDataSet. Verify column count, row count, }
{       and dump every cell so the user can eyeball any }
{       conversion issue.                               }
{    3. Re-serialize the same dataset back to memory.   }
{    4. Compare byte-for-byte with the original. The    }
{       byte-exact equality is the strong proof that    }
{       the Pascal port matches the C# reference layout.}
{    5. Save the Pascal output to                       }
{       ..\fixtures\pascal_fixture.bin for the inverse  }
{       test (small C# program that reads it back).     }
{                                                       }
{*******************************************************}

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Data.DB,
  Datasnap.DBClient,
  MidasLib,                  { static-link midas so no midas.dll is needed }
  rpfastserializer in '..\..\rpfastserializer.pas';

const
  ExpectedCols = 13;
  ExpectedRows = 6;

function FixturesDir: string;
begin
  Result := TPath.GetFullPath(
              TPath.Combine(ExtractFilePath(ParamStr(0)),
                            '..\fixtures'));
end;

procedure Fail(const Code: Integer; const Msg: string);
begin
  Writeln('FAIL #', Code, ': ', Msg);
  Halt(Code);
end;

function BytesToHex(const Bytes: TBytes; MaxLen: Integer): string;
var
  i, n: Integer;
begin
  n := Length(Bytes);
  if n > MaxLen then n := MaxLen;
  Result := '';
  for i := 0 to n - 1 do
    Result := Result + IntToHex(Bytes[i], 2);
  if Length(Bytes) > MaxLen then
    Result := Result + '...';
end;

procedure DumpField(F: TField);
var
  s: string;
  blob: TBytes;
  blobStream: TStream;
begin
  if F.IsNull then
  begin
    Write('NULL');
    Exit;
  end;
  case F.DataType of
    ftSmallint, ftInteger, ftAutoInc, ftWord:
      Write(F.AsInteger);
    ftLargeint:
      Write(F.AsLargeInt);
    ftBoolean:
      Write(F.AsBoolean);
    ftFloat:
      Write(FloatToStr(F.AsFloat));
    ftSingle:
      Write(FloatToStr(F.AsFloat));
    ftCurrency, ftBCD:
      Write(CurrToStr(F.AsCurrency));
    ftDate, ftTime, ftDateTime, ftTimeStamp:
      Write(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', F.AsDateTime));
    ftByte:
      Write(F.AsInteger);
    ftBlob, ftBytes, ftVarBytes, ftGraphic, ftStream:
      begin
        if F is TBlobField then
        begin
          blobStream := TBlobField(F).DataSet.CreateBlobStream(F, bmRead);
          try
            SetLength(blob, blobStream.Size);
            if blobStream.Size > 0 then
              blobStream.ReadBuffer(blob[0], blobStream.Size);
          finally
            blobStream.Free;
          end;
        end
        else
          blob := F.AsBytes;
        Write('<', Length(blob), 'B: ', BytesToHex(blob, 16), '>');
      end;
  else
    s := F.AsString;
    if Length(s) > 80 then s := Copy(s, 1, 77) + '...';
    Write('"', s, '"');
  end;
end;

procedure DumpDataset(ds: TClientDataSet);
var
  i: Integer;
begin
  ds.First;
  while not ds.Eof do
  begin
    Write('  row ', ds.RecNo - 1, ': ');
    for i := 0 to ds.FieldCount - 1 do
    begin
      if i > 0 then Write(' | ');
      Write(ds.Fields[i].FieldName, '=');
      DumpField(ds.Fields[i]);
    end;
    Writeln;
    ds.Next;
  end;
end;

function CompareBytes(const a, b: TBytes): Integer;
var
  i, lim: Integer;
begin
  if Length(a) <> Length(b) then
    Writeln('Length differs: ', Length(a), ' vs ', Length(b),
            ' (', Length(b) - Length(a), ' bytes)');

  lim := Length(a);
  if Length(b) < lim then lim := Length(b);

  for i := 0 to lim - 1 do
    if a[i] <> b[i] then
    begin
      Writeln('First byte differs at offset ', i,
              ': orig=', IntToHex(a[i], 2),
              '  regen=', IntToHex(b[i], 2));
      Result := i;
      Exit;
    end;

  if Length(a) = Length(b) then
    Result := Length(a)
  else
  begin
    Writeln('First ', lim, ' bytes match but lengths differ.');
    Result := lim;
  end;
end;

procedure HexDumpDiffContext(const original, regen: TBytes; offset: Integer);
var
  start, finish, i: Integer;
  ch: Byte;
begin
  start := offset - 16;
  if start < 0 then start := 0;
  finish := offset + 16;
  if finish >= Length(original) then finish := Length(original) - 1;
  Write('  orig: ');
  for i := start to finish do
  begin
    if i = offset then Write('[');
    ch := original[i];
    Write(IntToHex(ch, 2));
    if i = offset then Write(']');
    Write(' ');
  end;
  Writeln;
  Write('  regen: ');
  for i := start to finish do
  begin
    if i = offset then Write('[');
    if i < Length(regen) then ch := regen[i] else ch := $00;
    Write(IntToHex(ch, 2));
    if i = offset then Write(']');
    Write(' ');
  end;
  Writeln;
end;

var
  fixturePath, outputPath: string;
  original, regen: TBytes;
  inStream, outStream: TMemoryStream;
  ds: TClientDataSet;
  diffOffset: Integer;
  arch: string;
  gTableName: string;

begin
  try
{$IFDEF WIN64}
    arch := 'x64';
{$ELSE}
    arch := 'x86';
{$ENDIF}
    Writeln('=== FastSerializer Pascal cross-test (', arch, ') ===');
    Writeln;

    fixturePath := TPath.Combine(FixturesDir, 'dotnet_fixture.bin');
    if not FileExists(fixturePath) then
      Fail(1, 'Missing fixture: ' + fixturePath +
              ' (run fixture_gen first)');

    Writeln('[1] Loading fixture: ', fixturePath);
    original := TFile.ReadAllBytes(fixturePath);
    Writeln('    size: ', Length(original), ' bytes');
    if not IsFastSerialized(original) then
      Fail(2, 'Fixture does not start with FastSerializer signature');
    Writeln('    signature OK (10 11 12 13)');

    Writeln('[2] Deserialize with rpfastserializer');
    inStream := TMemoryStream.Create;
    ds := TClientDataSet.Create(nil);
    try
      inStream.WriteBuffer(original[0], Length(original));
      inStream.Position := 0;
      FastDeserializeDataSet(ds, inStream, gTableName);
      Writeln('    fields: ', ds.FieldCount,
              '  rows: ', ds.RecordCount,
              '  table: "', gTableName, '"');

      if ds.FieldCount <> ExpectedCols then
        Fail(3, Format('Expected %d columns, got %d',
                       [ExpectedCols, ds.FieldCount]));
      if ds.RecordCount <> ExpectedRows then
        Fail(4, Format('Expected %d rows, got %d',
                       [ExpectedRows, ds.RecordCount]));

      Writeln('[3] Dataset contents:');
      DumpDataset(ds);

      Writeln('[4] Re-serialize and compare');
      outStream := TMemoryStream.Create;
      try
        FastSerializeDataSet(ds, outStream, gTableName);
        SetLength(regen, outStream.Size);
        if outStream.Size > 0 then
        begin
          outStream.Position := 0;
          outStream.ReadBuffer(regen[0], outStream.Size);
        end;
        Writeln('    regenerated size: ', Length(regen), ' bytes');

        diffOffset := CompareBytes(original, regen);
        if diffOffset = Length(original) then
          Writeln('    [BYTE-EXACT MATCH]')
        else
        begin
          Writeln('    [DIFF AT OFFSET ', diffOffset, ']');
          HexDumpDiffContext(original, regen, diffOffset);
        end;

        outputPath := TPath.Combine(FixturesDir, 'pascal_fixture.bin');
        TFile.WriteAllBytes(outputPath, regen);
        Writeln('[5] Wrote pascal_fixture.bin (', Length(regen), ' bytes)');

        if diffOffset = Length(original) then
        begin
          Writeln;
          Writeln('=== PASSED ===');
          Halt(0);
        end
        else
        begin
          Writeln;
          Writeln('=== FAILED ===');
          Halt(10);
        end;
      finally
        outStream.Free;
      end;
    finally
      ds.Free;
      inStream.Free;
    end;
  except
    on E: Exception do
      Fail(99, E.ClassName + ': ' + E.Message);
  end;
end.
