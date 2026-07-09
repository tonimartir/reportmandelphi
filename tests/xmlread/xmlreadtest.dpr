program xmlreadtest;
{*******************************************************}
{  Reads every *.xml (MIDAS/MyBase DATAPACKET 2.0) in   }
{  C:\data\xml with BOTH the reference TClientDataSet    }
{  and our TFDMemTable reader (rpfdmidas.inc), then      }
{  compares field count, names, DataTypes, record count  }
{  and every cell value/null. Exit 0 = all match.        }
{                                                        }
{  These are real-world exports (uppercase R8, empty     }
{  ROWDATA, single-quoted XML decl, &amp;/&quot;).        }
{*******************************************************}
{$APPTYPE CONSOLE}
uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections,
  System.DateUtils, System.StrUtils, System.Math, System.TypInfo, System.IOUtils,
  Data.DB, Data.FmtBcd,
  Datasnap.DBClient, MidasLib,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async,
  FireDAC.DApt, FireDAC.Comp.DataSet, FireDAC.Comp.Client, System.NetEncoding;

{$I ..\..\rpfdmidas.inc}

const
  DIR = 'C:\data\xml';

var
  TotalErrors: Integer = 0;
  TotalChecks: Integer = 0;

function TypeName(ft: TFieldType): string;
begin
  Result := GetEnumName(TypeInfo(TFieldType), Ord(ft));
end;

procedure CompareFile(const FileName: string);
var
  cds: TClientDataSet;
  mem: TFDMemTable;
  i, row, fileErrors: Integer;
  cdsOk: Boolean;
  fcds, fmem: TField;
  sc, sm: string;
begin
  Writeln('');
  Writeln('=== ', ExtractFileName(FileName), ' ===');
  cds := TClientDataSet.Create(nil);
  mem := TFDMemTable.Create(nil);
  fileErrors := 0;
  cdsOk := False;
  try
    // reference reader
    try
      cds.LoadFromFile(FileName);
      cdsOk := True;
    except
      on E: Exception do
        Writeln('  [reference TClientDataSet could NOT load]: ', E.ClassName, ': ', E.Message);
    end;

    // our reader
    try
      FDMemLoadFromMidasFile(mem, FileName);
    except
      on E: Exception do
      begin
        Writeln('  [OUR READER FAILED]: ', E.ClassName, ': ', E.Message);
        Inc(TotalErrors);
        Exit;
      end;
    end;
    Writeln(Format('  our reader: %d fields, %d rows', [mem.FieldCount, mem.RecordCount]));

    if not cdsOk then
    begin
      Writeln('  (no reference to compare against; our reader at least loaded)');
      Exit;
    end;

    // ---- structure ----
    if cds.FieldCount <> mem.FieldCount then
    begin
      Writeln(Format('  FIELD COUNT mismatch: cds=%d mem=%d', [cds.FieldCount, mem.FieldCount]));
      Inc(TotalErrors); Inc(fileErrors);
    end;
    for i := 0 to Min(cds.FieldCount, mem.FieldCount) - 1 do
    begin
      Inc(TotalChecks);
      if not SameText(cds.Fields[i].FieldName, mem.Fields[i].FieldName) then
      begin
        Writeln(Format('  FIELD[%d] NAME: cds=%s mem=%s',
          [i, cds.Fields[i].FieldName, mem.Fields[i].FieldName]));
        Inc(TotalErrors); Inc(fileErrors);
      end;
      Inc(TotalChecks);
      if cds.Fields[i].DataType <> mem.Fields[i].DataType then
      begin
        Writeln(Format('  FIELD[%d] %s TYPE: cds=%s mem=%s',
          [i, cds.Fields[i].FieldName, TypeName(cds.Fields[i].DataType),
           TypeName(mem.Fields[i].DataType)]));
        Inc(TotalErrors); Inc(fileErrors);
      end;
    end;

    // ---- record count ----
    if cds.RecordCount <> mem.RecordCount then
    begin
      Writeln(Format('  RECORD COUNT mismatch: cds=%d mem=%d', [cds.RecordCount, mem.RecordCount]));
      Inc(TotalErrors); Inc(fileErrors);
    end;

    // ---- values ----
    cds.First; mem.First;
    row := 0;
    while (not cds.Eof) and (not mem.Eof) do
    begin
      for i := 0 to cds.FieldCount - 1 do
      begin
        fcds := cds.Fields[i];
        fmem := mem.FindField(fcds.FieldName);
        if fmem = nil then Continue;
        Inc(TotalChecks);
        if fcds.IsNull <> fmem.IsNull then
        begin
          if fileErrors < 25 then
            Writeln(Format('  row %d [%s] NULL: cds=%s mem=%s',
              [row, fcds.FieldName, BoolToStr(fcds.IsNull, True), BoolToStr(fmem.IsNull, True)]));
          Inc(TotalErrors); Inc(fileErrors);
        end
        else if not fcds.IsNull then
        begin
          sc := fcds.AsString;
          sm := fmem.AsString;
          if sc <> sm then
          begin
            if fileErrors < 25 then
              Writeln(Format('  row %d [%s] VALUE: cds=[%s] mem=[%s]',
                [row, fcds.FieldName, sc, sm]));
            Inc(TotalErrors); Inc(fileErrors);
          end;
        end;
      end;
      cds.Next; mem.Next; Inc(row);
    end;

    if fileErrors = 0 then
      Writeln('  OK - identical to reference')
    else
      Writeln(Format('  %d mismatch(es) in this file', [fileErrors]));
  finally
    cds.Free;
    mem.Free;
  end;
end;

var
  files: TArray<string>;
  f: string;
begin
  try
    if not TDirectory.Exists(DIR) then
    begin
      Writeln('Directory not found: ', DIR);
      ExitCode := 3;
      Exit;
    end;
    files := TDirectory.GetFiles(DIR, '*.xml');
    for f in files do
      CompareFile(f);
    Writeln('');
    Writeln(Format('TOTAL: %d checks, %d errors', [TotalChecks, TotalErrors]));
    if TotalErrors = 0 then
    begin
      Writeln('RESULT: PASS');
      ExitCode := 0;
    end
    else
    begin
      Writeln('RESULT: FAIL');
      ExitCode := 1;
    end;
  except
    on E: Exception do
    begin
      Writeln('FATAL: ', E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
