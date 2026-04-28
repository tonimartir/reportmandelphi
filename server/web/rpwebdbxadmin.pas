unit rpwebdbxadmin;

{$I rpconf.inc}

interface

uses
  Classes, SysUtils, IniFiles, Generics.Collections, rpdatainfo,
{$IFDEF USESQLEXPRESS}
  SQLExpr,
{$IFNDEF DELPHI2009UP}
  DBXpress,
{$ENDIF}
{$ENDIF}
{$IFDEF USEZEOS}
  ZDbcIntfs, ZConnection,
{$ENDIF}
{$IFDEF USEIBX}
{$IFDEF DELPHIXE2UP}
  IBX.IBDatabase,
{$ENDIF}
{$IFNDEF DELPHIXE2UP}
  IBDatabase,
{$ENDIF}
{$ENDIF}
{$IFDEF FIREDAC}
  FireDAC.Comp.Client,
{$ENDIF}
  rpmdconsts;

type
  TRpWebEditorKind = (
    weText,
    wePassword,
    weCombo,
    weReadOnly,
    weTextArea
  );

  TRpWebConnectionParam = record
    Name: string;
    Value: string;
    OriginalValue: string;
    IsSensitive: Boolean;
    IsReadOnly: Boolean;
    EditorKind: TRpWebEditorKind;
    Options: TStringList;
    class function Create: TRpWebConnectionParam; static;
    procedure Clear;
  end;

  TRpWebConnectionItem = record
    Name: string;
    DriverName: string;
    DisplayDriverName: string;
  end;

  TRpWebConnectionTestResult = record
    Success: Boolean;
    MessageText: string;
    DriverName: string;
    SafeDetails: TStringList;
    class function Create: TRpWebConnectionTestResult; static;
    procedure Clear;
  end;

  TRpWebRawConfigResult = record
    Success: Boolean;
    MessageText: string;
    ConfigText: string;
    BackupFileName: string;
  end;

  TRpWebEffectiveConfigInfo = record
    DriversFileName: string;
    ConnectionsFileName: string;
    DriversOverride: string;
    ConnectionsOverride: string;
  end;

  TRpWebDbxAdminService = class
  private
    FConnectionsOverride: string;
    FDriversOverride: string;
    function CreateConnAdmin: TRpConnAdmin;
    function IsSensitiveParam(const AName: string): Boolean;
    function IsReadOnlyParam(const AName: string): Boolean;
    function ResolveEditorKind(const AName: string; const AValue: string;
      AOptions: TStrings): TRpWebEditorKind;
    procedure FillDriverOptions(AConnAdmin: TRpConnAdmin;
      const AParamName: string; AOptions: TStrings);
    procedure ValidateConnectionName(const AName: string);
    procedure ReloadAfterWrite;
    procedure CopyFileSimple(const ASourceFileName, ADestFileName: string);
    procedure MergeConnectionValues(ABaseValues, AOverrideValues: TStrings);
    procedure AddSafeDetails(const AConnectionName: string; AParams,
      ASafeDetails: TStrings);
    function ExecuteConnectionTest(const AConnectionName: string;
      AParams: TStrings): TRpWebConnectionTestResult;
  public
    constructor Create(const AConnectionsOverride: string = '';
      const ADriversOverride: string = '');

    function GetEffectiveConfigInfo: TRpWebEffectiveConfigInfo;

    procedure ListConnections(AItems: TList<TRpWebConnectionItem>;
      const ADriverFilter: string = '');
    procedure ListDrivers(ADrivers: TStrings);
    procedure GetConnectionParams(const AConnectionName: string;
      AParams: TList<TRpWebConnectionParam>);

    procedure CreateConnection(const AConnectionName, ADriverName: string);
    procedure UpdateConnectionParams(const AConnectionName: string;
      AValues: TStrings);
    procedure DeleteConnection(const AConnectionName: string);

    function LoadRawDbxConnections: TRpWebRawConfigResult;
    function SaveRawDbxConnections(const AConfigText: string;
      const ACreateBackup: Boolean = True): TRpWebRawConfigResult;

    function TestConnection(const AConnectionName: string): TRpWebConnectionTestResult;
    function TestConnectionValues(const AConnectionName: string;
      AValues: TStrings): TRpWebConnectionTestResult;
  end;

implementation

uses
  rpreport;

function ResolveDbxConnectionDriver(const ADriverName: string): TRpDbDriver;
begin
  if SameText(ADriverName, 'FireDac') then
    Result := rpfiredac
  else if SameText(ADriverName, 'ZeosLib') then
    Result := rpdatazeos
  else if SameText(ADriverName, 'Interbase') or SameText(ADriverName, 'Firebird') then
    Result := rpdataibx
  else if SameText(ADriverName, 'Reportman AI Agent') then
    Result := rpdbHttp
  else
    Result := rpdatadbexpress;
end;

class function TRpWebConnectionParam.Create: TRpWebConnectionParam;
begin
  Result.Name := '';
  Result.Value := '';
  Result.OriginalValue := '';
  Result.IsSensitive := False;
  Result.IsReadOnly := False;
  Result.EditorKind := weText;
  Result.Options := TStringList.Create;
end;

procedure TRpWebConnectionParam.Clear;
begin
  Options.Free;
  Options := nil;
  Name := '';
  Value := '';
  OriginalValue := '';
  IsSensitive := False;
  IsReadOnly := False;
  EditorKind := weText;
end;

class function TRpWebConnectionTestResult.Create: TRpWebConnectionTestResult;
begin
  Result.Success := False;
  Result.MessageText := '';
  Result.DriverName := '';
  Result.SafeDetails := TStringList.Create;
end;

procedure TRpWebConnectionTestResult.Clear;
begin
  SafeDetails.Free;
  SafeDetails := nil;
  Success := False;
  MessageText := '';
  DriverName := '';
end;

constructor TRpWebDbxAdminService.Create(const AConnectionsOverride,
  ADriversOverride: string);
begin
  inherited Create;
  FConnectionsOverride := AConnectionsOverride;
  FDriversOverride := ADriversOverride;
end;

function TRpWebDbxAdminService.CreateConnAdmin: TRpConnAdmin;
begin
  Result := TRpConnAdmin.Create;
  if (Length(Trim(FConnectionsOverride)) > 0) or
    (Length(Trim(FDriversOverride)) > 0) then
  begin
    Result.DBXConnectionsOverride := Trim(FConnectionsOverride);
    Result.DBXDriversOverride := Trim(FDriversOverride);
    Result.LoadConfig;
  end;
end;

procedure TRpWebDbxAdminService.CopyFileSimple(const ASourceFileName,
  ADestFileName: string);
var
  LSource: TFileStream;
  LDest: TFileStream;
begin
  LSource := TFileStream.Create(ASourceFileName, fmOpenRead or fmShareDenyWrite);
  try
    LDest := TFileStream.Create(ADestFileName, fmCreate);
    try
      LDest.CopyFrom(LSource, 0);
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure TRpWebDbxAdminService.MergeConnectionValues(ABaseValues,
  AOverrideValues: TStrings);
var
  I: Integer;
  LName: string;
begin
  if (ABaseValues = nil) or (AOverrideValues = nil) then
    Exit;
  for I := 0 to AOverrideValues.Count - 1 do
  begin
    LName := Trim(AOverrideValues.Names[I]);
    if Length(LName) = 0 then
      Continue;
    ABaseValues.Values[LName] := AOverrideValues.ValueFromIndex[I];
  end;
end;

procedure TRpWebDbxAdminService.AddSafeDetails(const AConnectionName: string;
  AParams, ASafeDetails: TStrings);
var
  I: Integer;
  LName: string;
begin
  if ASafeDetails = nil then
    Exit;
  ASafeDetails.Add('Connection=' + AConnectionName);
  for I := 0 to AParams.Count - 1 do
  begin
    LName := Trim(AParams.Names[I]);
    if Length(LName) = 0 then
      Continue;
    if IsSensitiveParam(LName) then
      Continue;
    ASafeDetails.Add(LName + '=' + AParams.ValueFromIndex[I]);
  end;
end;

function TRpWebDbxAdminService.ExecuteConnectionTest(
  const AConnectionName: string; AParams: TStrings): TRpWebConnectionTestResult;
var
  LDriverName: string;
  LReport: TRpReport;
  LDbInfo: TRpDatabaseInfoItem;
  I: Integer;
  LName: string;
begin
  Result := TRpWebConnectionTestResult.Create;
  LDriverName := Trim(AParams.Values['DriverName']);
  Result.DriverName := LDriverName;
  AddSafeDetails(AConnectionName, AParams, Result.SafeDetails);
  try
    LReport := TRpReport.Create(nil);
    try
      if Length(Trim(FConnectionsOverride)) > 0 then
        LReport.Params.Add('DBXCONNECTIONS').AsString := Trim(FConnectionsOverride);
      if Length(Trim(FDriversOverride)) > 0 then
        LReport.Params.Add('DBXDRIVERS').AsString := Trim(FDriversOverride);

      for I := 0 to AParams.Count - 1 do
      begin
        LName := Trim(AParams.Names[I]);
        if Length(LName) = 0 then
          Continue;
        LReport.Params.Add('DBPARAM_' + LName).AsString := AParams.ValueFromIndex[I];
      end;

      LDbInfo := LReport.DatabaseInfo.Add(AConnectionName);
      LDbInfo.Driver := ResolveDbxConnectionDriver(LDriverName);
      LDbInfo.LoginPrompt := False;
      LDbInfo.Connect(LReport.Params);
      try
        Result.Success := True;
        Result.MessageText := SRpConnectionOk;
      finally
        LDbInfo.DisConnect;
      end;
    finally
      LReport.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.MessageText := E.Message;
    end;
  end;
end;

function TRpWebDbxAdminService.IsSensitiveParam(const AName: string): Boolean;
var
  LName: string;
begin
  LName := UpperCase(Trim(AName));
  Result := (Pos('PASSWORD', LName) > 0) or (Pos('PWD', LName) > 0) or
    (Pos('SECRET', LName) > 0) or (Pos('TOKEN', LName) > 0) or
    (Pos('APIKEY', LName) > 0);
end;

function TRpWebDbxAdminService.IsReadOnlyParam(const AName: string): Boolean;
begin
  Result := SameText(Trim(AName), 'DriverName');
end;

function TRpWebDbxAdminService.ResolveEditorKind(const AName,
  AValue: string; AOptions: TStrings): TRpWebEditorKind;
begin
  if IsReadOnlyParam(AName) then
    Exit(weReadOnly);
  if AOptions.Count > 0 then
    Exit(weCombo);
  if IsSensitiveParam(AName) then
    Exit(wePassword);
  if (Pos(#10, AValue) > 0) or (Pos(#13, AValue) > 0) or (Length(AValue) > 120) then
    Exit(weTextArea);
  Result := weText;
end;

procedure TRpWebDbxAdminService.FillDriverOptions(AConnAdmin: TRpConnAdmin;
  const AParamName: string; AOptions: TStrings);
begin
  AOptions.Clear;
  if SameText(Trim(AParamName), 'DriverName') then
    AConnAdmin.GetDriverNames(AOptions);
end;

procedure TRpWebDbxAdminService.ValidateConnectionName(const AName: string);
var
  LName: string;
begin
  LName := Trim(AName);
  if Length(LName) = 0 then
    raise Exception.Create('Connection name is required');
  if (Pos('=', LName) > 0) or (Pos('[', LName) > 0) or (Pos(']', LName) > 0) then
    raise Exception.Create('Connection name contains invalid characters');
end;

procedure TRpWebDbxAdminService.ReloadAfterWrite;
var
  LConnAdmin: TRpConnAdmin;
begin
  LConnAdmin := CreateConnAdmin;
  try
  finally
    LConnAdmin.Free;
  end;
end;

function TRpWebDbxAdminService.GetEffectiveConfigInfo: TRpWebEffectiveConfigInfo;
var
  LConnAdmin: TRpConnAdmin;
begin
  LConnAdmin := CreateConnAdmin;
  try
    Result.DriversFileName := LConnAdmin.driverfilename;
    Result.ConnectionsFileName := LConnAdmin.configfilename;
    Result.DriversOverride := FDriversOverride;
    Result.ConnectionsOverride := FConnectionsOverride;
  finally
    LConnAdmin.Free;
  end;
end;

procedure TRpWebDbxAdminService.ListConnections(AItems: TList<TRpWebConnectionItem>;
  const ADriverFilter: string);
var
  LConnAdmin: TRpConnAdmin;
  LNames: TStringList;
  I: Integer;
  LItem: TRpWebConnectionItem;
begin
  AItems.Clear;
  LConnAdmin := CreateConnAdmin;
  LNames := TStringList.Create;
  try
    LConnAdmin.GetConnectionNames(LNames, ADriverFilter);
    for I := 0 to LNames.Count - 1 do
    begin
      LItem.Name := LNames[I];
      LItem.DriverName := LConnAdmin.config.ReadString(LItem.Name, 'DriverName', '');
      LItem.DisplayDriverName := LItem.DriverName;
      AItems.Add(LItem);
    end;
  finally
    LNames.Free;
    LConnAdmin.Free;
  end;
end;

procedure TRpWebDbxAdminService.ListDrivers(ADrivers: TStrings);
var
  LConnAdmin: TRpConnAdmin;
begin
  LConnAdmin := CreateConnAdmin;
  try
    LConnAdmin.GetDriverNames(ADrivers);
  finally
    LConnAdmin.Free;
  end;
end;

procedure TRpWebDbxAdminService.GetConnectionParams(const AConnectionName: string;
  AParams: TList<TRpWebConnectionParam>);
var
  LConnAdmin: TRpConnAdmin;
  LValues: TStringList;
  I: Integer;
  LParam: TRpWebConnectionParam;
  LName: string;
begin
  AParams.Clear;
  LConnAdmin := CreateConnAdmin;
  LValues := TStringList.Create;
  try
    LConnAdmin.GetConnectionParams(AConnectionName, LValues);
    if LValues.Count = 0 then
      raise Exception.Create('Connection not found: ' + AConnectionName);
    for I := 0 to LValues.Count - 1 do
    begin
      LName := LValues.Names[I];
      LParam := TRpWebConnectionParam.Create;
      LParam.Name := LName;
      LParam.Value := LValues.ValueFromIndex[I];
      LParam.OriginalValue := LParam.Value;
      LParam.IsSensitive := IsSensitiveParam(LName);
      LParam.IsReadOnly := IsReadOnlyParam(LName);
      FillDriverOptions(LConnAdmin, LName, LParam.Options);
      LParam.EditorKind := ResolveEditorKind(LName, LParam.Value, LParam.Options);
      AParams.Add(LParam);
    end;
  finally
    LValues.Free;
    LConnAdmin.Free;
  end;
end;

procedure TRpWebDbxAdminService.CreateConnection(const AConnectionName,
  ADriverName: string);
var
  LConnAdmin: TRpConnAdmin;
begin
  ValidateConnectionName(AConnectionName);
  if Length(Trim(ADriverName)) = 0 then
    raise Exception.Create('Driver name is required');
  LConnAdmin := CreateConnAdmin;
  try
    LConnAdmin.AddConnection(Trim(AConnectionName), Trim(ADriverName));
    LConnAdmin.config.UpdateFile;
  finally
    LConnAdmin.Free;
  end;
  ReloadAfterWrite;
end;

procedure TRpWebDbxAdminService.UpdateConnectionParams(const AConnectionName: string;
  AValues: TStrings);
var
  LConnAdmin: TRpConnAdmin;
  LCurrentParams: TStringList;
  I: Integer;
  LName: string;
begin
  ValidateConnectionName(AConnectionName);
  LConnAdmin := CreateConnAdmin;
  LCurrentParams := TStringList.Create;
  try
    LConnAdmin.GetConnectionParams(AConnectionName, LCurrentParams);
    if LCurrentParams.Count = 0 then
      raise Exception.Create('Connection not found: ' + AConnectionName);
    for I := 0 to AValues.Count - 1 do
    begin
      LName := Trim(AValues.Names[I]);
      if Length(LName) = 0 then
        Continue;
      if IsReadOnlyParam(LName) then
        Continue;
      LConnAdmin.config.WriteString(AConnectionName, LName,
        AValues.ValueFromIndex[I]);
    end;
    LConnAdmin.config.UpdateFile;
  finally
    LCurrentParams.Free;
    LConnAdmin.Free;
  end;
  ReloadAfterWrite;
end;

procedure TRpWebDbxAdminService.DeleteConnection(const AConnectionName: string);
var
  LConnAdmin: TRpConnAdmin;
begin
  ValidateConnectionName(AConnectionName);
  LConnAdmin := CreateConnAdmin;
  try
    LConnAdmin.DeleteConnection(AConnectionName);
    LConnAdmin.config.UpdateFile;
  finally
    LConnAdmin.Free;
  end;
  ReloadAfterWrite;
end;

function TRpWebDbxAdminService.LoadRawDbxConnections: TRpWebRawConfigResult;
var
  LConnAdmin: TRpConnAdmin;
  LText: TStringList;
begin
  Result.Success := True;
  Result.MessageText := '';
  Result.ConfigText := '';
  Result.BackupFileName := '';
  LConnAdmin := CreateConnAdmin;
  LText := TStringList.Create;
  try
    if FileExists(LConnAdmin.configfilename) then
      LText.LoadFromFile(LConnAdmin.configfilename);
    Result.ConfigText := LText.Text;
  finally
    LText.Free;
    LConnAdmin.Free;
  end;
end;

function TRpWebDbxAdminService.SaveRawDbxConnections(const AConfigText: string;
  const ACreateBackup: Boolean): TRpWebRawConfigResult;
var
  LConnAdmin: TRpConnAdmin;
  LText: TStringList;
  LTempIni: TMemIniFile;
  LSections: TStringList;
  LTempFileName: string;
begin
  Result.Success := False;
  Result.MessageText := '';
  Result.ConfigText := AConfigText;
  Result.BackupFileName := '';
  if Length(Trim(AConfigText)) = 0 then
    raise Exception.Create('dbxconnections.ini text is required');
  LConnAdmin := CreateConnAdmin;
  LText := TStringList.Create;
  LSections := TStringList.Create;
  LTempFileName := '';
  try
    ForceDirectories(ExtractFilePath(LConnAdmin.configfilename));
    LTempFileName := ChangeFileExt(LConnAdmin.configfilename, '.validate.tmp');
    LText.Text := AConfigText;
    LText.SaveToFile(LTempFileName);
    LTempIni := TMemIniFile.Create(LTempFileName);
    try
      LTempIni.ReadSections(LSections);
    finally
      LTempIni.Free;
    end;
    if ACreateBackup and FileExists(LConnAdmin.configfilename) then
    begin
      Result.BackupFileName := LConnAdmin.configfilename + '.' +
        FormatDateTime('yyyymmdd_hhnnss', Now) + '.bak';
      CopyFileSimple(LConnAdmin.configfilename, Result.BackupFileName);
    end;
    LText.SaveToFile(LConnAdmin.configfilename);
    if FileExists(LTempFileName) then
      DeleteFile(LTempFileName);
    ReloadAfterWrite;
    Result.Success := True;
    Result.MessageText := 'dbxconnections.ini saved';
  finally
    if (Length(LTempFileName) > 0) and FileExists(LTempFileName) then
      DeleteFile(LTempFileName);
    LSections.Free;
    LText.Free;
    LConnAdmin.Free;
  end;
end;

function TRpWebDbxAdminService.TestConnection(
  const AConnectionName: string): TRpWebConnectionTestResult;
var
  LConnAdmin: TRpConnAdmin;
  LParams: TStringList;
begin
  LConnAdmin := CreateConnAdmin;
  LParams := TStringList.Create;
  try
    ValidateConnectionName(AConnectionName);
    LConnAdmin.GetConnectionParams(AConnectionName, LParams);
    Result := ExecuteConnectionTest(AConnectionName, LParams);
  finally
    LParams.Free;
    LConnAdmin.Free;
  end;
end;

function TRpWebDbxAdminService.TestConnectionValues(const AConnectionName: string;
  AValues: TStrings): TRpWebConnectionTestResult;
var
  LConnAdmin: TRpConnAdmin;
  LParams: TStringList;
begin
  LConnAdmin := CreateConnAdmin;
  LParams := TStringList.Create;
  try
    ValidateConnectionName(AConnectionName);
    LConnAdmin.GetConnectionParams(AConnectionName, LParams);
    MergeConnectionValues(LParams, AValues);
    Result := ExecuteConnectionTest(AConnectionName, LParams);
  finally
    LParams.Free;
    LConnAdmin.Free;
  end;
end;

end.