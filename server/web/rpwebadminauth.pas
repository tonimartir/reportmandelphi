unit rpwebadminauth;

{$I rpconf.inc}

interface

uses
  Classes, SysUtils, IniFiles, rpwebserverconfigadmin;

type
  TRpWebAdminAuthResult = record
    Success: Boolean;
    UserName: string;
    IsAdmin: Boolean;
    BootstrapRequired: Boolean;
    MessageText: string;
  end;

  TRpWebAdminAuthService = class
  public
    class function TryLogin(const AUserName, APassword: string;
      const AConfigOverride: string = ''): TRpWebAdminAuthResult; static;
    class function BootstrapRequired(const AConfigOverride: string = ''): Boolean; static;
  end;

implementation

class function TRpWebAdminAuthService.TryLogin(const AUserName, APassword: string;
  const AConfigOverride: string): TRpWebAdminAuthResult;
var
  LService: TRpWebServerConfigAdminService;
  LIni: TMemIniFile;
  LUserName: string;
  LStoredPassword: string;
begin
  Result.Success := False;
  Result.UserName := '';
  Result.IsAdmin := False;
  Result.MessageText := 'Incorrect user name or password';
  LService := TRpWebServerConfigAdminService.Create(AConfigOverride);
  try
    Result.BootstrapRequired := LService.BootstrapRequired;
    if Result.BootstrapRequired then
    begin
      Result.MessageText := 'Bootstrap is required before admin login';
      Exit;
    end;
    LUserName := UpperCase(Trim(AUserName));
    if LUserName <> 'ADMIN' then
    begin
      Result.MessageText := 'Current server model only allows ADMIN into the admin area';
      Exit;
    end;
    LIni := TMemIniFile.Create(LService.GetConfigFileName);
    try
      LStoredPassword := LIni.ReadString('USERS', 'ADMIN', '');
    finally
      LIni.Free;
    end;
    if (Length(LStoredPassword) > 0) and (LStoredPassword = APassword) then
    begin
      Result.Success := True;
      Result.UserName := 'ADMIN';
      Result.IsAdmin := True;
      Result.MessageText := '';
    end;
    if not Result.Success and (Length(Result.MessageText) = 0) then
      Result.MessageText := 'Incorrect user name or password';
  finally
    LService.Free;
  end;
end;

class function TRpWebAdminAuthService.BootstrapRequired(
  const AConfigOverride: string): Boolean;
var
  LService: TRpWebServerConfigAdminService;
begin
  LService := TRpWebServerConfigAdminService.Create(AConfigOverride);
  try
    Result := LService.BootstrapRequired;
  finally
    LService.Free;
  end;
end;

end.