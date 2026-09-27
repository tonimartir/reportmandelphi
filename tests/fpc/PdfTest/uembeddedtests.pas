unit uembeddedtests;

{$mode objfpc}{$H+}

// Round trip of the embedded files of a report (every stream format) and of
// a metafile (document strings and embedded files). FPC 3.2.2 TStream.Read/
// Write have no TBytes overload (Delphi has): a TBytes variable passed to
// them was read/written as the variable itself, not as its content.

interface

function RunEmbeddedTests: Boolean;

implementation

uses
  Classes, SysUtils, rptypes, rpreport, rpmetafile;

var
  GFailed: Integer;

procedure Check(ACondition: Boolean; const AWhat: string);
begin
  if ACondition then
    WriteLn('   OK   ', AWhat)
  else
  begin
    WriteLn('   FAIL ', AWhat);
    Inc(GFailed);
  end;
end;

function HexOf(const S: RawByteString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    Result := Result + IntToHex(Ord(S[I]), 2);
  Result := Result + ' (cp ' + IntToStr(StringCodePage(S)) + ')';
end;

procedure CheckText(const AExpected, AActual, AWhat: string);
begin
  Check(AActual = AExpected, AWhat);
  if AActual <> AExpected then
    WriteLn('        expected ', HexOf(AExpected), ' got ', HexOf(AActual));
end;

// Non ASCII text (n with tilde, e acute) built from code points at run time,
// so the test does not depend on the source code page (a constant expression
// is converted by the compiler, byte by byte, not to the system code page)
function Accented(const APrefix: string): string;
var
  LText: UnicodeString;
begin
  SetLength(LText, 2);
  LText[1] := WideChar($00F1);
  LText[2] := WideChar($00E9);
  Result := APrefix + string(LText);
end;

const
  CContent = '<factura><total>12.50</total></factura>';

function NewEmbeddedFile: TEmbeddedFile;
var
  LText: AnsiString;
begin
  Result := TEmbeddedFile.Create;
  Result.FileName := Accented('factura-') + '.xml';
  Result.MimeType := 'text/xml';
  Result.Description := Accented('Factura electr') + ' ZUGFeRD';
  Result.CreationDate := '2026-09-28T10:00:00Z';
  Result.ModificationDate := '2026-09-28T11:30:00Z';
  Result.AFRelationShip := PDF_AF_Data;
  Result.Stream := TMemoryStream.Create;
  LText := CContent;
  Result.Stream.Write(LText[1], Length(LText));
  Result.Stream.Position := 0;
end;

function StreamText(AStream: TMemoryStream): string;
var
  LText: AnsiString;
begin
  Result := '';
  if (AStream = nil) or (AStream.Size = 0) then
    Exit;
  SetLength(LText, AStream.Size);
  Move(AStream.Memory^, LText[1], AStream.Size);
  Result := LText;
end;

procedure CheckSameFile(AExpected, AActual: TEmbeddedFile; const AWhere: string;
  ACheckCreation: Boolean);
begin
  CheckText(AExpected.FileName, AActual.FileName, AWhere + ' FileName');
  Check(AActual.MimeType = AExpected.MimeType, AWhere + ' MimeType');
  CheckText(AExpected.Description, AActual.Description, AWhere + ' Description');
  if ACheckCreation then
    Check(AActual.CreationDate = AExpected.CreationDate, AWhere + ' CreationDate');
  Check(AActual.ModificationDate = AExpected.ModificationDate, AWhere + ' ModificationDate');
  Check(AActual.AFRelationShip = AExpected.AFRelationShip, AWhere + ' AFRelationShip');
  Check(StreamText(AActual.Stream) = CContent, AWhere + ' content');
end;

procedure TestReportFormat(AFormat: TRpStreamFormat; const AName: string);
var
  LSource, LTarget: TRpReport;
  LStream: TMemoryStream;
  LExpected: TEmbeddedFile;
begin
  LExpected := NewEmbeddedFile;
  LSource := TRpReport.Create(nil);
  LTarget := TRpReport.Create(nil);
  LStream := TMemoryStream.Create;
  try
    LSource.CreateNew;
    LSource.StreamFormat := AFormat;
    SetLength(LSource.EmbeddedFiles, 1);
    LSource.EmbeddedFiles[0] := LExpected.Clone;
    try
      LSource.SaveToStream(LStream);
      LStream.Position := 0;
      LTarget.LoadFromStream(LStream);
      Check(Length(LTarget.EmbeddedFiles) = 1, 'report ' + AName + ' embedded file count');
      if Length(LTarget.EmbeddedFiles) = 1 then
        CheckSameFile(LExpected, LTarget.EmbeddedFiles[0], 'report ' + AName, True);
    except
      on E: Exception do
        Check(False, 'report ' + AName + ' round trip raised ' + E.ClassName + ': ' + E.Message);
    end;
  finally
    // The reports free their embedded files
    LStream.Free;
    LTarget.Free;
    LSource.Free;
    LExpected.Free;
  end;
end;

procedure TestMetafile(ACompressed: Boolean);
var
  LSource, LTarget: TRpMetafileReport;
  LStream: TMemoryStream;
  LExpected: TEmbeddedFile;
  LName: string;
begin
  if ACompressed then
    LName := 'metafile compressed'
  else
    LName := 'metafile';
  LExpected := NewEmbeddedFile;
  LSource := TRpMetafileReport.Create(nil);
  LTarget := TRpMetafileReport.Create(nil);
  LStream := TMemoryStream.Create;
  try
    try
      LSource.DocAuthor := Accented('Autor ');
      LSource.DocTitle := Accented('T') + 'tulo';
      LSource.NewPage;
      LSource.NewEmbeddedFile(LExpected.FileName, LExpected.MimeType,
        LExpected.AFRelationShip, LExpected.Description, LExpected.CreationDate,
        LExpected.ModificationDate, LExpected.Stream);
      LSource.Finish;
      LSource.SaveToStream(LStream, ACompressed);
      LStream.Position := 0;
      LTarget.LoadFromStream(LStream);
      CheckText(LSource.DocAuthor, LTarget.DocAuthor, LName + ' DocAuthor');
      CheckText(LSource.DocTitle, LTarget.DocTitle, LName + ' DocTitle');
      Check(Length(LTarget.EmbeddedFiles) = 1, LName + ' embedded file count');
      // The metafile format does not store the creation date
      if Length(LTarget.EmbeddedFiles) = 1 then
        CheckSameFile(LExpected, LTarget.EmbeddedFiles[0], LName, False);
    except
      on E: Exception do
        Check(False, LName + ' round trip raised ' + E.ClassName + ': ' + E.Message);
    end;
  finally
    LStream.Free;
    LTarget.Free;
    LSource.Free;
    LExpected.Free;
  end;
end;

procedure TestWriteStringToStream;
var
  LStream: TMemoryStream;
  LLen: Integer;
  LBytes: AnsiString;
begin
  LStream := TMemoryStream.Create;
  try
    rpmetafile.WriteStringToStream(Accented('ab'), LStream);
    LStream.Position := 0;
    LLen := 0;
    LStream.Read(LLen, SizeOf(LLen));
    // 'ab' + two 2 byte UTF-8 sequences
    Check(LLen = 6, 'WriteStringToStream length prefix');
    if LLen <> 6 then
      WriteLn('        length ', LLen, ' of ', HexOf(Accented('ab')));
    SetLength(LBytes, LStream.Size - SizeOf(LLen));
    if Length(LBytes) > 0 then
      LStream.Read(LBytes[1], Length(LBytes));
    Check(LBytes = 'ab'#$C3#$B1#$C3#$A9, 'WriteStringToStream UTF-8 bytes');
  finally
    LStream.Free;
  end;
end;

function RunEmbeddedTests: Boolean;
begin
  GFailed := 0;
  WriteLn('--------------------------------------------------');
  WriteLn('Embedded files and metafile strings round trip');
  WriteLn('--------------------------------------------------');
  TestWriteStringToStream;
  TestReportFormat(rpStreamText, 'text');
  TestReportFormat(rpStreambinary, 'binary');
  TestReportFormat(rpStreamzlib, 'zlib');
  TestReportFormat(rpStreamXML, 'XML');
  TestMetafile(False);
  TestMetafile(True);
  Result := GFailed = 0;
  WriteLn('   ', GFailed, ' failed checks');
  WriteLn;
end;

end.
