unit udatainfotests;

{$mode objfpc}{$H+}

// rpdatainfo helpers shared with Delphi

interface

function RunDataInfoTests: Boolean;

implementation

uses
  SysUtils, rpdatainfo;

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

function RunDataInfoTests: Boolean;
begin
  WriteLn('==================================================');
  WriteLn('rpdatainfo helpers');
  GFailed := 0;
  TestADOPassword;
  WriteLn('rpdatainfo helpers: ', GFailed, ' failed checks');
  Result := GFailed = 0;
end;

end.
