unit rpwebselfhosted;

{$I rpconf.inc}

interface

procedure RunSelfHosted;

implementation

uses
  SysUtils, Classes, IniFiles, WebReq, IdHTTPWebBrokerBridge, IdSocketHandle,
  rpmdshfolder, rpwebmodule;

function TryGetCmdLineValue(const ASwitchName: string; out AValue: string): Boolean;
var
  I: Integer;
  LParam: string;
  LPrefix: string;
begin
  Result := False;
  AValue := '';
  LPrefix := '-' + LowerCase(ASwitchName) + '=';
  for I := 1 to ParamCount do
  begin
    LParam := ParamStr(I);
    if Pos(LPrefix, LowerCase(LParam)) = 1 then
    begin
      AValue := Copy(LParam, Length(LPrefix) + 1, Length(LParam));
      Result := True;
      Exit;
    end;
    if SameText(LParam, '-' + ASwitchName) or SameText(LParam, '/' + ASwitchName) then
    begin
      if I < ParamCount then
      begin
        AValue := ParamStr(I + 1);
        Result := True;
      end;
      Exit;
    end;
  end;
end;

function ReadConfigBool(inif: TMemInifile; const Section, Ident: string;
  Default: Boolean): Boolean;
var
  LValue: string;
begin
  LValue := Trim(inif.ReadString(Section, Ident, ''));
  if Length(LValue) < 1 then
  begin
    Result := Default;
    Exit;
  end;
  if SameText(LValue, '1') or SameText(LValue, 'TRUE') or SameText(LValue, 'YES')
    or SameText(LValue, 'ON') then
  begin
    Result := True;
    Exit;
  end;
  if SameText(LValue, '0') or SameText(LValue, 'FALSE') or SameText(LValue, 'NO')
    or SameText(LValue, 'OFF') then
  begin
    Result := False;
    Exit;
  end;
  Result := Default;
end;

function ResolveSelfHostedConfigFileName: string;
begin
  Result := Obtainininamecommonconfig('', '', 'reportmanserver');
end;

function ResolveSelfHostedPort: Integer;
var
  LFileName: string;
  LIni: TMemIniFile;
  LPortText: string;
begin
  Result := 3060;
  if TryGetCmdLineValue('port', LPortText) then
  begin
    Result := StrToIntDef(Trim(LPortText), Result);
    Exit;
  end;

  LFileName := ResolveSelfHostedConfigFileName;
  ForceDirectories(ExtractFilePath(LFileName));
  LIni := TMemIniFile.Create(LFileName);
  try
    Result := LIni.ReadInteger('CONFIG', 'TCPPORT', Result);
  finally
    LIni.Free;
  end;
end;

function ResolveSelfHostedBindAddress: string;
var
  LValue: string;
begin
  Result := '';
  if TryGetCmdLineValue('bind', LValue) then
    Result := Trim(LValue);
end;

function ResolveRequireHttpsState: Boolean;
var
  LIni: TMemIniFile;
begin
  LIni := TMemIniFile.Create(ResolveSelfHostedConfigFileName);
  try
    Result := ReadConfigBool(LIni, 'SECURITY', 'REQUIRE_HTTPS', False);
  finally
    LIni.Free;
  end;
end;

procedure WriteSelfHostedBanner(const APort: Integer; const ABindAddress: string);
begin
  WriteLn('Reportman selfhosted mode enabled');
  WriteLn('Parameters: -selfhosted [-port=<port>] [-bind=<address>]');
  if Length(Trim(ABindAddress)) > 0 then
    WriteLn('Bind address: ' + ABindAddress)
  else
    WriteLn('Bind address: 0.0.0.0');
  WriteLn('Port: ' + IntToStr(APort));
  WriteLn('Config: ' + ResolveSelfHostedConfigFileName);
  WriteLn('Port precedence: command line -port overrides CONFIG/TCPPORT.');
  if ResolveRequireHttpsState then
    WriteLn('Warning: REQUIRE_HTTPS=1 may reject plain HTTP requests in selfhosted mode.');
  WriteLn('Press Enter to stop the server.');
end;

procedure RunSelfHosted;
var
  LServer: TIdHTTPWebBrokerBridge;
  LPort: Integer;
  LBindAddress: string;
  LBinding: TIdSocketHandle;
begin
  LPort := ResolveSelfHostedPort;
  LBindAddress := ResolveSelfHostedBindAddress;
  if WebRequestHandler = nil then
    raise Exception.Create('WebRequestHandler is not available');

  WebRequestHandler.WebModuleClass := Trepwebmod;

  LServer := TIdHTTPWebBrokerBridge.Create(nil);
  try
    LServer.DefaultPort := LPort;
    if Length(Trim(LBindAddress)) > 0 then
    begin
      LBinding := LServer.Bindings.Add;
      LBinding.IP := LBindAddress;
    end;
    LServer.Active := True;
    WriteSelfHostedBanner(LPort, LBindAddress);
    ReadLn;
  finally
    LServer.Active := False;
    LServer.Free;
  end;
end;

end.