unit udatainfotests;

{$mode objfpc}{$H+}

// rpdatainfo helpers shared with Delphi

interface

function RunDataInfoTests: Boolean;

// PdfTest --connections-file: writes the connections file TRpConnAdmin
// chooses and returns True (the test runs itself with other HOME folders)
function PrintConnectionsFile: Boolean;

implementation

uses
  SysUtils, Classes, {$IFDEF UNIX}Process,{$ENDIF} rpdatainfo;

var
  GFailed: Integer;

procedure CheckStr(const AExpected, AActual, AWhat: string);
begin
  if AExpected = AActual then
    WriteLn('   OK   ', AWhat)
  else
  begin
    WriteLn('   FAIL ', AWhat, ': expected "', AExpected, '", got "', AActual, '"');
    Inc(GFailed);
  end;
end;

// The ADO connection string is shown with the password masked
// (EncodeADOPassword); editing another part of it saved the '*'
procedure TestADOPassword;
const
  ORIGINAL = 'Provider=SQLOLEDB;Password=s3cret;Data Source=A';
begin
  WriteLn('-- ADO connection string: masked password kept when editing');
  CheckStr('Provider=SQLOLEDB;Password=******;Data Source=A', EncodeADOPassword(ORIGINAL),
    'password masked');
  CheckStr('Provider=SQLOLEDB;Password=s3cret;Data Source=B',
    RestoreADOPassword('Provider=SQLOLEDB;Password=******;Data Source=B', ORIGINAL),
    'masked password restored');
  CheckStr('Provider=SQLOLEDB;Password=new;Data Source=B',
    RestoreADOPassword('Provider=SQLOLEDB;Password=new;Data Source=B', ORIGINAL),
    'a new password is kept');
  CheckStr('Provider=SQLOLEDB;Data Source=B',
    RestoreADOPassword('Provider=SQLOLEDB;Data Source=B', ORIGINAL),
    'a removed password stays removed');
  CheckStr('Provider=X;Password=**', RestoreADOPassword('Provider=X;Password=**', 'Provider=X'),
    'no original password: unchanged');
end;

function PrintConnectionsFile: Boolean;
var
  LAdmin: TRpConnAdmin;
begin
  Result := (ParamCount >= 1) and (ParamStr(1) = '--connections-file');
  if not Result then
    Exit;
  LAdmin := TRpConnAdmin.Create;
  try
    WriteLn(LAdmin.configfilename);
  finally
    LAdmin.Free;
  end;
end;

{$IFDEF UNIX}
// The connections file of this program run with another HOME
function ConnectionsFileWithHome(const AHome: string): string;
var
  LProcess: TProcess;
  LOutput: TStringList;
  i: Integer;
begin
  LProcess := TProcess.Create(nil);
  LOutput := TStringList.Create;
  try
    LProcess.Executable := ParamStr(0);
    LProcess.Parameters.Add('--connections-file');
    for i := 1 to GetEnvironmentVariableCount do
      if Pos('HOME=', GetEnvironmentString(i)) <> 1 then
        LProcess.Environment.Add(GetEnvironmentString(i));
    LProcess.Environment.Add('HOME=' + AHome);
    LProcess.Options := [poWaitOnExit, poUsePipes];
    LProcess.Execute;
    LOutput.LoadFromStream(LProcess.Output);
    if LOutput.Count > 0 then
      Result := Trim(LOutput[LOutput.Count - 1])
    else
      Result := '';
  finally
    LOutput.Free;
    LProcess.Free;
  end;
end;

procedure WriteEmptyFile(const AFileName: string);
begin
  ForceDirectories(ExtractFileDir(AFileName));
  with TStringList.Create do
  try
    SaveToFile(AFileName);
  finally
    Free;
  end;
end;

// The connections of ~/.borland were ignored without ~/.borland/dbxdrivers
// (the engine took ~/.dbxconnections): first ~/.borland/dbxconnections, then
// ~/.dbxconnections
procedure TestConnectionsFile;
var
  LHome: string;
begin
  WriteLn('-- Connections file: ~/.borland/dbxconnections, then ~/.dbxconnections');
  LHome := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'rpconnhome_' +
    IntToStr(GetProcessID);
  ForceDirectories(LHome);
  try
    CheckStr(LHome + '/.dbxconnections', ConnectionsFileWithHome(LHome),
      'nothing in ~/.borland: ~/.dbxconnections');
    WriteEmptyFile(LHome + '/.borland/dbxconnections');
    CheckStr(LHome + '/.borland/dbxconnections', ConnectionsFileWithHome(LHome),
      '~/.borland/dbxconnections without dbxdrivers, and ~/.dbxconnections');
    DeleteFile(LHome + '/.dbxconnections');
    CheckStr(LHome + '/.borland/dbxconnections', ConnectionsFileWithHome(LHome),
      'only ~/.borland/dbxconnections');
    WriteEmptyFile(LHome + '/.borland/dbxdrivers');
    CheckStr(LHome + '/.borland/dbxconnections', ConnectionsFileWithHome(LHome),
      '~/.borland with dbxdrivers and dbxconnections');
  finally
    DeleteFile(LHome + '/.borland/dbxconnections');
    DeleteFile(LHome + '/.borland/dbxdrivers');
    DeleteFile(LHome + '/.dbxconnections');
    DeleteFile(LHome + '/.dbxdrivers');
    RemoveDir(LHome + '/.borland');
    RemoveDir(LHome);
  end;
end;
{$ENDIF}

function RunDataInfoTests: Boolean;
begin
  WriteLn('==================================================');
  WriteLn('rpdatainfo helpers');
  GFailed := 0;
  TestADOPassword;
  {$IFDEF UNIX}
  TestConnectionsFile;
  {$ENDIF}
  WriteLn('rpdatainfo helpers: ', GFailed, ' failed checks');
  Result := GFailed = 0;
end;

end.
