program strtest;
{*******************************************************}
{  Deep investigation of how TClientDataSet serialises   }
{  string data (ftString vs ftWideString / ftMemo /       }
{  ftWideMemo) with special characters, and whether our   }
{  rpfdmidas.inc reader/writer round-trip it faithfully.  }
{                                                        }
{  Phase 1  DISCOVERY : build a CDS, assign a battery of  }
{           torture strings, SaveToFile(dfXMLUTF8), dump   }
{           the raw XML + what CDS actually stored.        }
{  Phase 2  READ      : reload that XML with our reader    }
{           (TFDMemTable) and diff every cell vs CDS.      }
{  Phase 3  WRITE     : our writer -> real CDS, diff.      }
{*******************************************************}
{$APPTYPE CONSOLE}
uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.DateUtils, System.StrUtils, System.Math, System.TypInfo, System.IOUtils,
  {$IFDEF MSWINDOWS}Winapi.Windows,{$ENDIF}
  Data.DB, Data.FmtBcd,
  Datasnap.DBClient, MidasLib,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async,
  FireDAC.DApt, FireDAC.Comp.DataSet, FireDAC.Comp.Client, System.NetEncoding;

{$I ..\..\rpfdmidas.inc}

const
  XMLFILE = 'cds_strings.xml';

// The battery of test strings (label, value)
function TestStrings: TArray<TPair<string,string>>;
begin
  Result := [
    TPair<string,string>.Create('enye',        'Espana: nino pequeno ' + #$00F1 + #$00D1),          // n~ N~
    TPair<string,string>.Create('euro',         'Precio 100' + #$20AC + ' y 50' + #$00A3),           // EUR GBP
    TPair<string,string>.Create('degree',       'PROTEZIONE 5' + #$00B0 + ' DITO'),                  // degree
    TPair<string,string>.Create('accents',      'naive cafe ' + #$00E1#$00E9#$00ED#$00F3#$00FA#$00FC#$00E7), // aeiou u" c,
    TPair<string,string>.Create('symbols',      #$00A9 + #$00AE + #$2122 + #$00B5 + #$00A7 + #$00BF + #$00A1), // (c)(R)TM mu section
    TPair<string,string>.Create('math_greek',   #$03A9 + #$2248 + #$221A + #$222B + #$03C0),          // Omega ~= sqrt integral pi
    TPair<string,string>.Create('cjk',          #$4E2D#$6587#$6E2C#$8A66),                            // Chinese
    TPair<string,string>.Create('emoji',        'hi ' + #$D83D#$DE00 + #$D83C#$DF89),                 // astral surrogate pairs
    TPair<string,string>.Create('xml_meta',     'a&b<c>d"e' + #$0027 + 'f'),                          // & < > " '
    TPair<string,string>.Create('ctrl_nl',      'line1' + #$000D#$000A + 'line2' + #$0009 + 'tab'),   // CR LF TAB
    TPair<string,string>.Create('quotes_typo',  #$201C + 'curly' + #$201D + ' ' + #$2018 + 'q' + #$2019 + ' dash' + #$2014) // typographic
  ];
end;

var
  Errors: Integer = 0;

function CodePoints(const s: string): string;
var i: Integer;
begin
  Result := '';
  for i := 1 to Length(s) do
    Result := Result + Format('%s%.4X', [IfThen(i>1,' ',''), Ord(s[i])]);
end;

procedure Line;
begin
  Writeln('----------------------------------------------------------------');
end;

// ---------------- Phase 1: discovery -------------------------------------
procedure BuildAndSaveCDS;
var
  cds: TClientDataSet;
  arr: TArray<TPair<string,string>>;
  i: Integer;
  raisedA, raisedMA: Boolean;
begin
  arr := TestStrings;
  cds := TClientDataSet.Create(nil);
  try
    cds.FieldDefs.Add('LABELV', ftString, 20);
    cds.FieldDefs.Add('A_STR',  ftString, 60);       // ANSI
    cds.FieldDefs.Add('W_STR',  ftWideString, 60);   // Unicode
    cds.FieldDefs.Add('A_MEMO', ftMemo);             // ANSI memo
    cds.FieldDefs.Add('W_MEMO', ftWideMemo);         // Unicode memo
    cds.CreateDataSet;

    Writeln('=== PHASE 1: what TClientDataSet STORES (this machine ACP below) ===');
    {$IFDEF MSWINDOWS}
    Writeln('  GetACP() = ', GetACP, '   DefaultSystemCodePage = ', DefaultSystemCodePage);
    {$ENDIF}
    Line;
    for i := 0 to High(arr) do
    begin
      cds.Append;
      cds.FieldByName('LABELV').AsString := arr[i].Key;
      cds.FieldByName('W_STR').AsString := arr[i].Value;   // Unicode: always ok
      cds.FieldByName('W_MEMO').AsString := arr[i].Value;
      raisedA := False; raisedMA := False;
      try cds.FieldByName('A_STR').AsString := arr[i].Value;  except on E: Exception do begin raisedA := True; end; end;
      try cds.FieldByName('A_MEMO').AsString := arr[i].Value; except on E: Exception do begin raisedMA := True; end; end;
      cds.Post;

      cds.Edit; // reopen to read back stored values (post already stored)
      cds.Post;

      Writeln('[', arr[i].Key, ']  input  = ', CodePoints(arr[i].Value));
      Writeln('     A_STR(ansi)  stored = ', CodePoints(cds.FieldByName('A_STR').AsString),
        IfThen(raisedA, '   <ASSIGN RAISED>', ''));
      Writeln('     W_STR(wide)  stored = ', CodePoints(cds.FieldByName('W_STR').AsString));
      Writeln('     A_MEMO       stored = ', CodePoints(cds.FieldByName('A_MEMO').AsString),
        IfThen(raisedMA, '   <ASSIGN RAISED>', ''));
      Writeln('     match A==input? ', cds.FieldByName('A_STR').AsString = arr[i].Value,
              '   W==input? ', cds.FieldByName('W_STR').AsString = arr[i].Value);
    end;
    cds.SaveToFile(XMLFILE, dfXMLUTF8);
    Writeln('');
    Writeln('Saved -> ', XMLFILE);
  finally
    cds.Free;
  end;
end;

procedure DumpRawXML;
var
  bytes: TBytes;
  s: string;
begin
  Line;
  Writeln('=== RAW XML bytes produced by TClientDataSet ===');
  bytes := TFile.ReadAllBytes(XMLFILE);
  // show METADATA (types + WIDTH) as decoded text
  s := TEncoding.UTF8.GetString(bytes);
  Writeln(s);
end;

// ---------------- Phase 2: our reader ------------------------------------
procedure ReadBackAndDiff;
var
  cds: TClientDataSet;
  mem: TFDMemTable;
  i: Integer;
  fc, fm: TField;
  sc, sm: string;
begin
  Line;
  Writeln('=== PHASE 2: our reader (TFDMemTable) vs TClientDataSet ===');
  cds := TClientDataSet.Create(nil);
  mem := TFDMemTable.Create(nil);
  try
    cds.LoadFromFile(XMLFILE);
    FDMemLoadFromMidasFile(mem, XMLFILE);

    Writeln('  field types (cds -> mem):');
    for i := 0 to cds.FieldCount - 1 do
      Writeln(Format('    %-8s cds=%-14s mem=%s', [cds.Fields[i].FieldName,
        GetEnumName(TypeInfo(TFieldType), Ord(cds.Fields[i].DataType)),
        GetEnumName(TypeInfo(TFieldType), Ord(mem.FindField(cds.Fields[i].FieldName).DataType))]));

    cds.First; mem.First;
    while not cds.Eof do
    begin
      for i := 0 to cds.FieldCount - 1 do
      begin
        fc := cds.Fields[i];
        fm := mem.FindField(fc.FieldName);
        if fm = nil then Continue;
        sc := fc.AsString; sm := fm.AsString;
        if sc <> sm then
        begin
          Writeln(Format('  DIFF row[%s] %s:', [cds.FieldByName('LABELV').AsString, fc.FieldName]));
          Writeln('      cds = ', CodePoints(sc));
          Writeln('      mem = ', CodePoints(sm));
          Inc(Errors);
        end;
      end;
      cds.Next; mem.Next;
    end;
    if Errors = 0 then Writeln('  ALL CELLS IDENTICAL to TClientDataSet');
  finally
    cds.Free; mem.Free;
  end;
end;

// ---------------- Phase 3: our writer ------------------------------------
procedure WriteAndDiff;
var
  mem: TFDMemTable;
  cds: TClientDataSet;
  arr: TArray<TPair<string,string>>;
  i, werr: Integer;
  fn: string;
begin
  Line;
  Writeln('=== PHASE 3: our writer (TFDMemTable) -> TClientDataSet ===');
  arr := TestStrings;
  fn := 'our_strings.xml';
  werr := 0;
  mem := TFDMemTable.Create(nil);
  cds := TClientDataSet.Create(nil);
  try
    mem.FieldDefs.Add('LABELV', ftString, 20);
    mem.FieldDefs.Add('W_STR',  ftWideString, 60);
    mem.FieldDefs.Add('W_MEMO', ftWideMemo);
    mem.CreateDataSet;
    for i := 0 to High(arr) do
    begin
      mem.Append;
      mem.FieldByName('LABELV').AsString := arr[i].Key;
      mem.FieldByName('W_STR').AsString := arr[i].Value;
      mem.FieldByName('W_MEMO').AsString := arr[i].Value;
      mem.Post;
    end;
    FDMemSaveToMidasFile(mem, fn);
    cds.LoadFromFile(fn);   // reference reads our output
    cds.First; mem.First;
    while not cds.Eof do
    begin
      if cds.FieldByName('W_STR').AsString <> mem.FieldByName('W_STR').AsString then
      begin
        Writeln(Format('  DIFF row[%s] W_STR: cds=%s mem=%s',
          [mem.FieldByName('LABELV').AsString,
           CodePoints(cds.FieldByName('W_STR').AsString),
           CodePoints(mem.FieldByName('W_STR').AsString)]));
        Inc(werr);
      end;
      cds.Next; mem.Next;
    end;
    if werr = 0 then Writeln('  our writer output read back by CDS: IDENTICAL')
    else Inc(Errors, werr);
  finally
    mem.Free; cds.Free;
  end;
end;

begin
  try
    BuildAndSaveCDS;
    DumpRawXML;
    ReadBackAndDiff;
    WriteAndDiff;
    Line;
    Writeln(Format('TOTAL DIFFS: %d', [Errors]));
    if Errors = 0 then Writeln('RESULT: PASS') else Writeln('RESULT: FAIL');
    ExitCode := IfThen(Errors = 0, 0, 1);
  except
    on E: Exception do
    begin
      Writeln('FATAL: ', E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
