program memtabletest;
{*******************************************************}
{  Round-trip test for the MIDAS/MyBase DataPacket XML  }
{  reader/writer (rpfdmidas.inc) used by the FireDAC    }
{  (Linux) build of the engine.                         }
{                                                       }
{  Builds a table with ONE column of every data type    }
{  plus several rows (edge values + nulls) and checks   }
{  both directions against a REAL TClientDataSet:        }
{    B) TClientDataSet -> dfXMLUTF8 -> our reader        }
{    A) our writer     -> TClientDataSet                 }
{    S) our writer     -> our reader   (stability)       }
{  Every field of every row is compared against the      }
{  golden TClientDataSet. Exit code 0 = all pass.        }
{*******************************************************}
{$APPTYPE CONSOLE}
uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections,
  System.DateUtils, System.StrUtils, System.Math, System.TypInfo, Data.DB, Data.FmtBcd,
  Datasnap.DBClient, MidasLib,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async,
  FireDAC.DApt, FireDAC.Comp.DataSet, FireDAC.Comp.Client, System.NetEncoding;

{$I ..\..\rpfdmidas.inc}

var
  Errors: Integer = 0;
  Checks: Integer = 0;

function Inv: TFormatSettings;
begin
  Result := TFormatSettings.Invariant;
end;

// ------- schema: one column of each type ---------------------------------
procedure BuildSchema(ds: TDataSet);
var fd: TFieldDef;
begin
  ds.FieldDefs.Add('I_SMALL', ftSmallint);
  ds.FieldDefs.Add('I_INT', ftInteger);
  ds.FieldDefs.Add('I_BIG', ftLargeint);
  ds.FieldDefs.Add('I_WORD', ftWord);
  ds.FieldDefs.Add('F_SINGLE', ftSingle);
  ds.FieldDefs.Add('F_FLOAT', ftFloat);
  ds.FieldDefs.Add('F_CURR', ftCurrency);
  fd := ds.FieldDefs.AddFieldDef; fd.Name := 'N_BCD'; fd.DataType := ftBCD; fd.Precision := 18; fd.Size := 4;
  fd := ds.FieldDefs.AddFieldDef; fd.Name := 'N_FMT'; fd.DataType := ftFMTBcd; fd.Precision := 32; fd.Size := 8;
  ds.FieldDefs.Add('B_BOOL', ftBoolean);
  ds.FieldDefs.Add('D_DATE', ftDate);
  ds.FieldDefs.Add('D_TIME', ftTime);
  ds.FieldDefs.Add('D_DT', ftDateTime);
  ds.FieldDefs.Add('D_TS', ftTimeStamp);
  ds.FieldDefs.Add('Field With Space', ftString, 40);   // spaced name
  ds.FieldDefs.Add('S_WIDE', ftWideString, 30);
  ds.FieldDefs.Add('M_MEMO', ftMemo);
  ds.FieldDefs.Add('BL_BYTES', ftBlob);
end;

procedure SetBytes(F: TField; const B: array of Byte);
var t: TBytes; i: Integer;
begin
  SetLength(t, Length(B));
  for i := 0 to High(B) do t[i] := B[i];
  F.AsBytes := t;
end;

procedure PopulateData(ds: TDataSet);
begin
  // row 0 : normal values
  ds.Append;
  ds.FieldByName('I_SMALL').AsInteger := 100;
  ds.FieldByName('I_INT').AsInteger := 123456;
  ds.FieldByName('I_BIG').AsLargeInt := 123456789012345;
  ds.FieldByName('I_WORD').AsInteger := 60000;
  ds.FieldByName('F_SINGLE').AsSingle := 3.25;
  ds.FieldByName('F_FLOAT').AsFloat := 50/2.54;             // 19.685039370078740, precision
  ds.FieldByName('F_CURR').AsCurrency := 12.34;
  ds.FieldByName('N_BCD').AsBcd := StrToBcd('12345.6789', Inv);
  ds.FieldByName('N_FMT').AsBcd := StrToBcd('1234567890123456.78901234', Inv);
  ds.FieldByName('B_BOOL').AsBoolean := True;
  ds.FieldByName('D_DATE').AsDateTime := EncodeDate(2024, 1, 15);
  ds.FieldByName('D_TIME').AsDateTime := EncodeTime(12, 30, 45, 123);
  ds.FieldByName('D_DT').AsDateTime := EncodeDate(2024, 1, 15) + EncodeTime(9, 8, 7, 456);
  ds.FieldByName('D_TS').AsDateTime := EncodeDate(2024, 6, 30) + EncodeTime(23, 59, 58, 789);
  ds.FieldByName('Field With Space').AsString := 'Hello & <World> "q"';
  ds.FieldByName('S_WIDE').AsString := 'Wide N heart';
  ds.FieldByName('M_MEMO').AsString := 'line1'#13#10'line2 & <b>';
  SetBytes(ds.FieldByName('BL_BYTES'), [1, 2, $AB, $FF, 0, $7F, $80]);
  ds.Post;

  // row 1 : edge / negative values
  ds.Append;
  ds.FieldByName('I_SMALL').AsInteger := -32000;
  ds.FieldByName('I_INT').AsInteger := -2000000000;
  ds.FieldByName('I_BIG').AsLargeInt := -8000000000000000000;
  ds.FieldByName('I_WORD').AsInteger := 0;
  ds.FieldByName('F_SINGLE').AsSingle := -1.5;
  ds.FieldByName('F_FLOAT').AsFloat := -0.00012345678901234;
  ds.FieldByName('F_CURR').AsCurrency := -9999.99;
  ds.FieldByName('N_BCD').AsBcd := StrToBcd('-0.0001', Inv);
  ds.FieldByName('N_FMT').AsBcd := StrToBcd('-123456789012345.12345678', Inv); // 23 sig digits (> double)
  ds.FieldByName('B_BOOL').AsBoolean := False;
  ds.FieldByName('D_DATE').AsDateTime := EncodeDate(1900, 1, 1);
  ds.FieldByName('D_TIME').AsDateTime := EncodeTime(0, 0, 0, 0);
  ds.FieldByName('D_DT').AsDateTime := EncodeDate(2099, 12, 31) + EncodeTime(23, 59, 59, 999);
  ds.FieldByName('D_TS').AsDateTime := EncodeDate(1970, 1, 1) + EncodeTime(0, 0, 1, 1);
  ds.FieldByName('Field With Space').AsString := '';
  ds.FieldByName('S_WIDE').AsString := 'unicode: n a o';
  ds.FieldByName('M_MEMO').AsString := '';
  SetBytes(ds.FieldByName('BL_BYTES'), [0]);
  ds.Post;

  // row 2 : mostly NULL (only two fields set)
  ds.Append;
  ds.FieldByName('I_INT').AsInteger := 7;
  ds.FieldByName('Field With Space').AsString := 'only two set';
  ds.Post;
end;

function BytesEqual(const A, B: TBytes): Boolean;
var i: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for i := 0 to High(A) do if A[i] <> B[i] then Exit(False);
  Result := True;
end;

function SameField(a, b: TField): Boolean;
begin
  if a.IsNull or b.IsNull then Exit(a.IsNull = b.IsNull);
  case a.DataType of
    ftSingle:
      Result := Abs(a.AsFloat - b.AsFloat) <= Abs(a.AsFloat) * 1e-6 + 1e-6;
    ftFloat, ftCurrency:
      Result := Abs(a.AsFloat - b.AsFloat) <= Abs(a.AsFloat) * 1e-12 + 1e-12;
    ftBCD, ftFMTBcd:
      Result := BcdToStr(a.AsBcd, Inv) = BcdToStr(b.AsBcd, Inv);
    ftDate, ftTime, ftDateTime, ftTimeStamp:
      Result := Abs(a.AsDateTime - b.AsDateTime) < 1.5 / (24 * 3600 * 1000); // <1.5ms
    ftBlob, ftGraphic, ftBytes, ftVarBytes:
      Result := BytesEqual(a.AsBytes, b.AsBytes);
    ftBoolean:
      Result := a.AsBoolean = b.AsBoolean;
    ftShortint, ftSmallint, ftByte, ftWord, ftInteger, ftLongWord, ftAutoInc, ftLargeint:
      Result := a.AsLargeInt = b.AsLargeInt;
  else
    Result := a.AsString = b.AsString;
  end;
end;

procedure VerifyAgainstGolden(const ATitle: string; D, Golden: TDataSet);
var
  row, i: Integer;
  gf, df: TField;
begin
  Writeln('--- ', ATitle, ' ---');
  if D.RecordCount <> Golden.RecordCount then
  begin
    Writeln('  FAIL rowcount: got ', D.RecordCount, ' expected ', Golden.RecordCount);
    Inc(Errors);
    Exit;
  end;
  if D.FieldCount <> Golden.FieldCount then
  begin
    Writeln('  FAIL fieldcount: got ', D.FieldCount, ' expected ', Golden.FieldCount);
    Inc(Errors);
  end;
  Golden.First; D.First;
  row := 0;
  while not Golden.Eof do
  begin
    for i := 0 to Golden.FieldCount - 1 do
    begin
      gf := Golden.Fields[i];
      df := D.FindField(gf.FieldName);
      Inc(Checks);
      if df = nil then
      begin
        Writeln(Format('  FAIL row %d field "%s": missing in target', [row, gf.FieldName]));
        Inc(Errors);
      end
      else if not SameField(df, gf) then
      begin
        Writeln(Format('  FAIL row %d field "%s" (%s): got "%s" expected "%s"',
          [row, gf.FieldName, GetEnumName(TypeInfo(TFieldType), Ord(gf.DataType)),
           df.AsString, gf.AsString]));
        Inc(Errors);
      end;
    end;
    Golden.Next; D.Next; Inc(row);
  end;
  Writeln(Format('  %d checks, %d errors so far', [Checks, Errors]));
end;

var
  golden: TClientDataSet;
  gfmem: TFDMemTable;
  fmemRead, fmemStable: TFDMemTable;
  rcds: TClientDataSet;
  ms, ms2: TMemoryStream;
begin
  try
    // golden reference in a real TClientDataSet (native midas)
    golden := TClientDataSet.Create(nil);
    BuildSchema(golden); golden.CreateDataSet; PopulateData(golden);

    // an equivalent golden in a TFDMemTable (independent population, no reader)
    gfmem := TFDMemTable.Create(nil);
    BuildSchema(gfmem); gfmem.CreateDataSet; PopulateData(gfmem);

    Writeln('golden CDS rows=', golden.RecordCount, ' fields=', golden.FieldCount);

    // B) TClientDataSet -> dfXMLUTF8 -> our reader -> TFDMemTable
    ms := TMemoryStream.Create;
    golden.SaveToStream(ms, dfXMLUTF8);
    ms.Position := 0;
    fmemRead := TFDMemTable.Create(nil);
    FDMemLoadFromMidasStream(fmemRead, ms);
    VerifyAgainstGolden('B) CDS(dfXMLUTF8) -> our READER -> FDMemTable', fmemRead, golden);

    // A) our writer (from the independent FDMem golden) -> TClientDataSet
    ms2 := TMemoryStream.Create;
    FDMemSaveToMidasStream(gfmem, ms2);
    ms2.Position := 0;
    rcds := TClientDataSet.Create(nil);
    rcds.LoadFromStream(ms2);
    VerifyAgainstGolden('A) FDMemTable -> our WRITER -> real TClientDataSet', rcds, golden);

    // S) our writer -> our reader (round-trip stability)
    ms2.Position := 0;
    fmemStable := TFDMemTable.Create(nil);
    FDMemLoadFromMidasStream(fmemStable, ms2);
    VerifyAgainstGolden('S) our WRITER -> our READER (stability)', fmemStable, golden);
  except
    on E: Exception do
    begin
      Writeln('EXCEPTION: ', E.ClassName, ': ', E.Message);
      Inc(Errors);
    end;
  end;

  Writeln('=====================================');
  Writeln(Format('TOTAL: %d checks, %d ERRORS', [Checks, Errors]));
  if Errors > 0 then
    Halt(1);
end.
