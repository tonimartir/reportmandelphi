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
  FireDAC.Comp.Client, FireDAC.Phys.Intf, FireDAC.Phys, FireDAC.DatS,
  FireDAC.Stan.Consts,
{$ENDIF}
  rpmdconsts;

type
  TRpWebEditorKind = (
    weText,
    wePassword,
    weCombo,
    weComboEditable,
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
    function IsDriverSupported(const ADriverName: string): Boolean;
    function IsSensitiveParam(const AName: string): Boolean;
    function IsReadOnlyParam(const AName: string): Boolean;
    function IsClosedOptionSet(const AName: string; AOptions: TStrings): Boolean;
    function ResolveEditorKind(const AName: string; const AValue: string;
      AOptions: TStrings; const AAllowCustomValue: Boolean): TRpWebEditorKind;
    procedure BuildDriverParamValues(AConnAdmin: TRpConnAdmin;
      const ADriverName: string; ASeedValues, AValues: TStrings;
      AOptionsMap: TObjectDictionary<string, TStringList> = nil;
      AEditableOptionNames: TStrings = nil);
{$IFDEF FIREDAC}
    procedure BuildFireDacParamValues(ASeedValues, AValues: TStrings;
      AOptionsMap: TObjectDictionary<string, TStringList>;
      AEditableOptionNames: TStrings);
    procedure FillFireDacOptions(const AParamType: string; AOptions: TStrings);
{$ENDIF}
    procedure FillDriverOptions(AConnAdmin: TRpConnAdmin;
      const AParamName: string; AOptions: TStrings);
    procedure ValidateConnectionName(const AName: string);
    procedure ReloadAfterWrite;
    procedure CopyFileSimple(const ASourceFileName, ADestFileName: string);
    procedure MergeConnectionValues(ABaseValues, AOverrideValues: TStrings);
    procedure MergeKnownConnectionValues(ABaseValues, AOverrideValues: TStrings);
    procedure ListSupportedDrivers(AConnAdmin: TRpConnAdmin; ADrivers: TStrings);
    procedure ListDbExpressConcreteDrivers(AConnAdmin: TRpConnAdmin;
      ADrivers: TStrings);
    procedure AddSafeDetails(const AConnectionName: string; AParams,
      ASafeDetails: TStrings);
    function ExecuteConnectionTest(const AConnectionName: string;
      AParams: TStrings): TRpWebConnectionTestResult;
  public
    constructor Create(const AConnectionsOverride: string = '';
      const ADriversOverride: string = '');

    function GetEffectiveConfigInfo: TRpWebEffectiveConfigInfo;

    procedure ListConnectionTypes(ADrivers: TStrings);
    procedure ListDbExpressDrivers(ADrivers: TStrings);
    procedure ListConnections(AItems: TList<TRpWebConnectionItem>;
      const ADriverFilter: string = '');
    procedure ListDrivers(ADrivers: TStrings);
    procedure GetConnectionParams(const AConnectionName: string;
      AParams: TList<TRpWebConnectionParam>; AOverrideValues: TStrings = nil);

    procedure CreateConnection(const AConnectionName, ADriverName: string;
      const ADbExpressDriverName: string = '');
    procedure UpdateConnectionParams(const AConnectionName: string;
      AValues: TStrings);
    procedure DeleteConnection(const AConnectionName: string);
    procedure DiscoverHubConnections(const AApiKey: string; AConnections: TStrings);

    function LoadRawDbxConnections: TRpWebRawConfigResult;
    function SaveRawDbxConnections(const AConfigText: string;
      const ACreateBackup: Boolean = True): TRpWebRawConfigResult;

    function TestConnection(const AConnectionName: string): TRpWebConnectionTestResult;
    function TestConnectionValues(const AConnectionName: string;
      AValues: TStrings): TRpWebConnectionTestResult;
  end;

implementation

uses
  System.JSON, System.Variants,
{$IFDEF FIREDAC}
  FireDAC.Stan.Util,
{$ENDIF}
  rpreport, rpdatahttp, rpauthmanager;

const
  HTTP_TEST_CONNECTION_TIMEOUT_MS = 10000;
  RP_WEB_DRIVER_FAMILY_DBEXPRESS = 'DBExpress';
  RP_WEB_DRIVER_FAMILY_FIREDAC = 'FireDac';
  RP_WEB_DRIVER_FAMILY_AGENT = 'Reportman AI Agent';
  RP_WEB_DBX_DRIVER_PARAM = 'DBXDriverName';
  RP_WEB_CLEAR_DRIVER_DEFAULTS = '__clear_driver_defaults__';

function ResolveDriverFamily(const ADriverName: string): string;
begin
  if SameText(ADriverName, RP_WEB_DRIVER_FAMILY_FIREDAC) then
    Result := RP_WEB_DRIVER_FAMILY_FIREDAC
  else if SameText(ADriverName, RP_WEB_DRIVER_FAMILY_AGENT) then
    Result := RP_WEB_DRIVER_FAMILY_AGENT
  else
    Result := RP_WEB_DRIVER_FAMILY_DBEXPRESS;
end;

function ResolveEffectiveDriverName(const AValues: TStrings;
  const AFallbackDriverName: string = ''): string;
var
  LFamily: string;
begin
  LFamily := Trim(AValues.Values['DriverName']);
  if SameText(LFamily, RP_WEB_DRIVER_FAMILY_DBEXPRESS) then
    Result := Trim(AValues.Values[RP_WEB_DBX_DRIVER_PARAM])
  else if SameText(LFamily, RP_WEB_DRIVER_FAMILY_FIREDAC) then
    Result := RP_WEB_DRIVER_FAMILY_FIREDAC
  else if SameText(LFamily, RP_WEB_DRIVER_FAMILY_AGENT) then
    Result := RP_WEB_DRIVER_FAMILY_AGENT
  else
    Result := Trim(LFamily);

  if Length(Result) = 0 then
    Result := Trim(AFallbackDriverName);
end;

function ResolveDbxConnectionDriver(const ADriverName: string): TRpDbDriver;
begin
  if SameText(ADriverName, RP_WEB_DRIVER_FAMILY_FIREDAC) then
    Result := rpfiredac
  else if SameText(ADriverName, RP_WEB_DRIVER_FAMILY_AGENT) then
    Result := rpdbHttp
  else
    Result := rpdatadbexpress;
end;

procedure SetNameValuePreserveEmpty(AValues: TStrings; const AName,
  AValue: string);
var
  LIndex: Integer;
begin
  if AValues = nil then
    Exit;
  LIndex := AValues.IndexOfName(AName);
  if LIndex >= 0 then
    AValues[LIndex] := AName + '=' + AValue
  else
    AValues.Add(AName + '=' + AValue);
end;

function ExtractHttpConnectionTestMessage(const AResponseText: string): string;
var
  LResponseJson: TJSONObject;
  LDataJson: TJSONObject;
  LValue: TJSONValue;
begin
  Result := '';
  if Length(Trim(AResponseText)) = 0 then
    Exit;
  LResponseJson := TJSONObject.ParseJSONValue(AResponseText) as TJSONObject;
  try
    if not Assigned(LResponseJson) then
      Exit;
    LDataJson := LResponseJson.Values['data'] as TJSONObject;
    if Assigned(LDataJson) then
    begin
      LValue := LDataJson.Values['message'];
      if Assigned(LValue) then
        Exit(LValue.Value);
    end;
    LValue := LResponseJson.Values['message'];
    if Assigned(LValue) then
      Result := LValue.Value;
  finally
    LResponseJson.Free;
  end;
end;

function BuildHttpConnectionFailureMessage(const AErrorText: string): string;
begin
  Result := 'Agent Connection: Fail' + sLineBreak +
    'Database Connection: Fail';
  if Length(Trim(AErrorText)) > 0 then
    Result := Result + sLineBreak + 'Error: ' + Trim(AErrorText);
end;

function ExecuteHttpConnectionTest(AParams: TStrings; out AMessageText: string): Boolean;
var
  LDatabase: TRpDatabaseHttp;
  LRequestBody: TJSONObject;
  LResponseStream: TStringStream;
begin
  Result := False;
  AMessageText := '';
  LDatabase := TRpDatabaseHttp.Create;
  try
    LDatabase.ApiKey := AParams.Values['ApiKey'];
    LDatabase.HubDatabaseId := StrToInt64Def(AParams.Values['HubDatabaseId'], 0);
    if (LDatabase.ApiKey = '') and (TRpAuthManager.Instance.Token <> '') then
      LDatabase.Token := TRpAuthManager.Instance.Token;
    LRequestBody := TJSONObject.Create;
    try
      LRequestBody.AddPair('hubDatabaseId', TJSONNumber.Create(LDatabase.HubDatabaseId));
      LResponseStream := TStringStream.Create('', TEncoding.UTF8);
      try
        try
          Result := LDatabase.InternalRequest('api/agent/testconnection',
            LRequestBody, LResponseStream, HTTP_TEST_CONNECTION_TIMEOUT_MS);
          if Result then
          begin
            AMessageText := ExtractHttpConnectionTestMessage(LResponseStream.DataString);
            if Length(Trim(AMessageText)) = 0 then
              AMessageText := 'Agent Connection: Success' + sLineBreak +
                'Database Connection: Success';
          end;
        except
          on E: Exception do
          begin
            Result := False;
            AMessageText := BuildHttpConnectionFailureMessage(E.Message);
          end;
        end;
      finally
        LResponseStream.Free;
      end;
    finally
      LRequestBody.Free;
    end;
  finally
    LDatabase.Free;
  end;
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

function TRpWebDbxAdminService.IsDriverSupported(
  const ADriverName: string): Boolean;
begin
  if SameText(ADriverName, RP_WEB_DRIVER_FAMILY_AGENT) then
    Exit(True);
  if SameText(ADriverName, RP_WEB_DRIVER_FAMILY_FIREDAC) then
  begin
{$IFDEF FIREDAC}
    Exit(True);
{$ELSE}
    Exit(False);
{$ENDIF}
  end;
  if SameText(ADriverName, 'ZeosLib') then
  begin
{$IFDEF USEZEOS}
    Exit(True);
{$ELSE}
    Exit(False);
{$ENDIF}
  end;
{$IFDEF MSWINDOWS}
{$IFDEF USESQLEXPRESS}
  Result := True;
{$ELSE}
  Result := False;
{$ENDIF}
{$ELSE}
  Result := False;
{$ENDIF}
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
    SetNameValuePreserveEmpty(ABaseValues, LName,
      AOverrideValues.ValueFromIndex[I]);
  end;
end;

procedure TRpWebDbxAdminService.MergeKnownConnectionValues(ABaseValues,
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
    if SameText(LName, 'DriverName') or (ABaseValues.IndexOfName(LName) >= 0) then
      SetNameValuePreserveEmpty(ABaseValues, LName,
        AOverrideValues.ValueFromIndex[I]);
  end;
end;

procedure TRpWebDbxAdminService.ListSupportedDrivers(AConnAdmin: TRpConnAdmin;
  ADrivers: TStrings);
var
  LAllDrivers: TStringList;
  I: Integer;
begin
  ADrivers.Clear;
  LAllDrivers := TStringList.Create;
  try
    AConnAdmin.GetDriverNames(LAllDrivers);
    for I := 0 to LAllDrivers.Count - 1 do
      if IsDriverSupported(LAllDrivers[I]) then
        ADrivers.Add(LAllDrivers[I]);
  finally
    LAllDrivers.Free;
  end;
end;

procedure TRpWebDbxAdminService.ListDbExpressConcreteDrivers(
  AConnAdmin: TRpConnAdmin; ADrivers: TStrings);
var
  LAllDrivers: TStringList;
  I: Integer;
  LDriverName: string;
begin
  ADrivers.Clear;
  LAllDrivers := TStringList.Create;
  try
    AConnAdmin.GetDriverNames(LAllDrivers);
    for I := 0 to LAllDrivers.Count - 1 do
    begin
      LDriverName := LAllDrivers[I];
      if SameText(LDriverName, 'FireDac') or SameText(LDriverName, 'ZeosLib') or
        SameText(LDriverName, 'Reportman AI Agent') then
        Continue;
      if SameText(LDriverName, 'DBXTrace') or SameText(LDriverName, 'DBXPool') or
        SameText(LDriverName, 'DataSnap') then
        Continue;
      if Length(Trim(AConnAdmin.drivers.ReadString(LDriverName, 'GetDriverFunc', ''))) = 0 then
        Continue;
      ADrivers.Add(LDriverName);
    end;
  finally
    LAllDrivers.Free;
  end;
end;

procedure TRpWebDbxAdminService.BuildDriverParamValues(AConnAdmin: TRpConnAdmin;
  const ADriverName: string; ASeedValues, AValues: TStrings;
  AOptionsMap: TObjectDictionary<string, TStringList>;
  AEditableOptionNames: TStrings);
var
  I: Integer;
  LParamName: string;
  LParamNames: TStringList;
begin
  AValues.Clear;
  if Length(Trim(ADriverName)) = 0 then
    Exit;
{$IFDEF FIREDAC}
  if SameText(Trim(ADriverName), 'FireDac') then
  begin
    BuildFireDacParamValues(ASeedValues, AValues, AOptionsMap,
      AEditableOptionNames);
    if AValues.Count > 0 then
      Exit;
  end;
{$ENDIF}
  LParamNames := TStringList.Create;
  try
    AConnAdmin.drivers.ReadSection(Trim(ADriverName), LParamNames);
    for I := 0 to LParamNames.Count - 1 do
    begin
      LParamName := Trim(LParamNames[I]);
      if Length(LParamName) = 0 then
        Continue;
      if SameText(LParamName, 'GetDriverFunc') or SameText(LParamName, 'VendorLib') or
        SameText(LParamName, 'VendorLibWin64') or SameText(LParamName, 'VendorLibOsx') or
        SameText(LParamName, 'LibraryName') or SameText(LParamName, 'LibraryNameOsx') or
        SameText(LParamName, 'DriverUnit') or SameText(LParamName, 'DriverPackageLoader') or
        SameText(LParamName, 'DriverAssemblyLoader') or SameText(LParamName, 'MetaDataPackageLoader') or
        SameText(LParamName, 'MetaDataAssemblyLoader') or SameText(LParamName, 'DisplayDriverName') then
        Continue;
      SetNameValuePreserveEmpty(AValues, LParamName,
        AConnAdmin.drivers.ReadString(Trim(ADriverName), LParamName, ''));
      if (AEditableOptionNames <> nil) and
        AConnAdmin.drivers.SectionExists(LParamName) and
        (Length(Trim(AConnAdmin.drivers.ReadString(Trim(ADriverName), LParamName, ''))) = 0) and
        (AEditableOptionNames.IndexOf(LParamName) < 0) then
        AEditableOptionNames.Add(LParamName);
    end;
  finally
    LParamNames.Free;
  end;
  if AValues.IndexOfName('DriverName') >= 0 then
    AValues.Delete(AValues.IndexOfName('DriverName'));
  AValues.Insert(0, 'DriverName=' + Trim(ADriverName));
end;

{$IFDEF FIREDAC}
procedure TRpWebDbxAdminService.FillFireDacOptions(const AParamType: string;
  AOptions: TStrings);
var
  LItemType: string;
begin
  if AOptions = nil then
    Exit;
  AOptions.Clear;
  LItemType := Trim(AParamType);
  if LItemType = '@L' then
  begin
    AOptions.Add(S_FD_True);
    AOptions.Add(S_FD_False);
  end
  else if LItemType = '@Y' then
  begin
    AOptions.Add(S_FD_Yes);
    AOptions.Add(S_FD_No);
  end
  else if Pos(';', LItemType) > 0 then
    AOptions.DelimitedText := StringReplace(LItemType, ';', AOptions.Delimiter,
      [rfReplaceAll]);
end;

procedure TRpWebDbxAdminService.BuildFireDacParamValues(ASeedValues,
  AValues: TStrings; AOptionsMap: TObjectDictionary<string, TStringList>;
  AEditableOptionNames: TStrings);
var
  LDriverID: string;
  LBaseKeys: TStringList;
  LOrderedParams: TStringList;
  LManagerMeta: IFDPhysManagerMetadata;
  LDriverMeta: IFDPhysDriverMetadata;
  LParamsTable: TFDDatSTable;
  I: Integer;
  LParamName: string;
  LDefaultValue: string;
  LParamType: string;
  LOptions: TStringList;
  LExistingOptions: TStringList;

  procedure SetDefaultIfSeedEmpty(const AName, ADefaultValue: string);
  begin
    if Length(Trim(ASeedValues.Values[AName])) = 0 then
      SetNameValuePreserveEmpty(AValues, AName, ADefaultValue);
  end;

  procedure ApplyPreferredOrder(const AParamNames: array of string);
  var
    LOrderedValues: TStringList;
    LParamIndex: Integer;
    LCurrentIndex: Integer;
    LCurrentName: string;
  begin
    LOrderedValues := TStringList.Create;
    try
      for LParamIndex := Low(AParamNames) to High(AParamNames) do
      begin
        LCurrentIndex := AValues.IndexOfName(AParamNames[LParamIndex]);
        if LCurrentIndex >= 0 then
          LOrderedValues.Add(AValues[LCurrentIndex]);
      end;

      for LCurrentIndex := 0 to AValues.Count - 1 do
      begin
        LCurrentName := AValues.Names[LCurrentIndex];
        if LOrderedValues.IndexOfName(LCurrentName) < 0 then
          LOrderedValues.Add(AValues[LCurrentIndex]);
      end;

      AValues.Assign(LOrderedValues);
    finally
      LOrderedValues.Free;
    end;
  end;

  procedure EnsureEmptyOptions(const AParamName: string);
  var
    LEmptyOptions: TStringList;
  begin
    if AOptionsMap = nil then
      Exit;
    if AOptionsMap.TryGetValue(AParamName, LExistingOptions) then
      LExistingOptions.Clear
    else
    begin
      LEmptyOptions := TStringList.Create;
      AOptionsMap.Add(AParamName, LEmptyOptions);
    end;
  end;

  procedure ApplyDatabaseOverride;
  begin
    EnsureEmptyOptions('Database');
    SetDefaultIfSeedEmpty('Database', '');
  end;

  procedure ApplyFirebirdOverrides;
  begin
    if not SameText(LDriverID, 'FB') then
      Exit;
    SetDefaultIfSeedEmpty('OSAuthent', 'No');
    SetDefaultIfSeedEmpty('Protocol', 'TCPIP');
    SetDefaultIfSeedEmpty('OpenMode', 'Open');
  end;

  procedure ReadFireDacParams(AKeys: TStrings);
  var
    LRowIndex: Integer;
  begin
    LParamsTable := LDriverMeta.GetConnParams(AKeys);
    try
      for LRowIndex := 0 to LParamsTable.Rows.Count - 1 do
      begin
        LParamName := Trim(VarToStr(LParamsTable.Rows[LRowIndex].GetData('Name')));
        if Length(LParamName) = 0 then
          Continue;

        if LOrderedParams.IndexOf(LParamName) < 0 then
          LOrderedParams.Add(LParamName);

        if AValues.IndexOfName(LParamName) < 0 then
        begin
          LDefaultValue := VarToStr(LParamsTable.Rows[LRowIndex].GetData('DefVal'));
          SetNameValuePreserveEmpty(AValues, LParamName, LDefaultValue);
        end;

        if AOptionsMap <> nil then
        begin
          LParamType := VarToStr(LParamsTable.Rows[LRowIndex].GetData('Type'));
          LOptions := TStringList.Create;
          FillFireDacOptions(LParamType, LOptions);
          if LOptions.Count > 0 then
          begin
            if (AEditableOptionNames <> nil) and
              (((Length(Trim(LDefaultValue)) = 0) or SameText(LParamType, '@S'))) and
              (AEditableOptionNames.IndexOf(LParamName) < 0) then
              AEditableOptionNames.Add(LParamName);
            if AOptionsMap.TryGetValue(LParamName, LExistingOptions) then
            begin
              LExistingOptions.Assign(LOptions);
              LOptions.Free;
            end
            else
              AOptionsMap.Add(LParamName, LOptions);
          end
          else
            LOptions.Free;
        end;
      end;
    finally
      FDFree(LParamsTable);
    end;
  end;
begin
  LDriverID := Trim(ASeedValues.Values['DriverID']);
  if Length(LDriverID) = 0 then
    LDriverID := 'FB';

  LBaseKeys := TStringList.Create;
  LOrderedParams := TStringList.Create;
  try
    SetNameValuePreserveEmpty(LBaseKeys, 'DriverID', LDriverID);
    if FDPhysManager.State = dmsInactive then
      FDPhysManager.Open;
    FDPhysManager.CreateMetadata(LManagerMeta);
    LManagerMeta.CreateDriverMetadata(LDriverID, LDriverMeta);
    ReadFireDacParams(LBaseKeys);

    MergeConnectionValues(AValues, ASeedValues);
    if AValues.IndexOfName('DriverName') >= 0 then
      AValues.Delete(AValues.IndexOfName('DriverName'));
    if AValues.IndexOfName(RP_WEB_DBX_DRIVER_PARAM) >= 0 then
      AValues.Delete(AValues.IndexOfName(RP_WEB_DBX_DRIVER_PARAM));
    SetNameValuePreserveEmpty(AValues, 'DriverID', LDriverID);

    ReadFireDacParams(AValues);
    ApplyDatabaseOverride;
    ApplyFirebirdOverrides;

    for I := LOrderedParams.Count - 1 downto 0 do
    begin
      LParamName := LOrderedParams[I];
      if AValues.IndexOfName(LParamName) >= 0 then
      begin
        LDefaultValue := AValues.Values[LParamName];
        AValues.Delete(AValues.IndexOfName(LParamName));
        AValues.Insert(0, LParamName + '=' + LDefaultValue);
      end;
    end;
  finally
    LOrderedParams.Free;
    LBaseKeys.Free;
  end;

  if AValues.IndexOfName('DriverName') >= 0 then
    AValues.Delete(AValues.IndexOfName('DriverName'));
  AValues.Insert(0, 'DriverName=FireDac');
  ApplyPreferredOrder([
    'DriverName',
    'DriverID',
    'User_name',
    'Password',
    'Server',
    'Database',
    'Port',
    'SqlDialect',
    'CharacterSet',
    'RoleName',
    'Pooled'
  ]);
end;
{$ENDIF}

procedure TRpWebDbxAdminService.AddSafeDetails(const AConnectionName: string;
  AParams, ASafeDetails: TStrings);
var
  I: Integer;
  LName: string;
  LValue: string;
begin
  if ASafeDetails = nil then
    Exit;
  ASafeDetails.Add('Connection=' + AConnectionName);
  for I := 0 to AParams.Count - 1 do
  begin
    LName := Trim(AParams.Names[I]);
    if Length(LName) = 0 then
      Continue;
    LValue := AParams.ValueFromIndex[I];
    if SameText(LName, 'Password') then
    begin
      ASafeDetails.Add(LName + '=' + LValue);
      Continue;
    end;
    if IsSensitiveParam(LName) then
    begin
      if Length(LValue) > 0 then
        ASafeDetails.Add(LName + '=<set>')
      else
        ASafeDetails.Add(LName + '=<empty>');
      Continue;
    end;
    ASafeDetails.Add(LName + '=' + LValue);
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
  LDriverName := ResolveEffectiveDriverName(AParams);
  Result.DriverName := LDriverName;
  AddSafeDetails(AConnectionName, AParams, Result.SafeDetails);
  try
    if SameText(LDriverName, RP_WEB_DRIVER_FAMILY_AGENT) then
    begin
      Result.Success := ExecuteHttpConnectionTest(AParams, Result.MessageText);
      if Length(Trim(Result.MessageText)) = 0 then
        if Result.Success then
          Result.MessageText := SRpConnectionOk
        else
          Result.MessageText := SRpConnectionFailed;
      Exit;
    end;

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
  Result := False;
end;

function TRpWebDbxAdminService.IsClosedOptionSet(const AName: string;
  AOptions: TStrings): Boolean;
begin
  Result := SameText(AName, 'DriverName') or
    SameText(AName, 'DriverID') or
    SameText(AName, RP_WEB_DBX_DRIVER_PARAM);
  if Result then
    Exit;

  if AOptions.Count <> 2 then
    Exit(False);

  Result :=
    ((SameText(AOptions[0], S_FD_True) and SameText(AOptions[1], S_FD_False)) or
     (SameText(AOptions[0], S_FD_False) and SameText(AOptions[1], S_FD_True)) or
     (SameText(AOptions[0], S_FD_Yes) and SameText(AOptions[1], S_FD_No)) or
     (SameText(AOptions[0], S_FD_No) and SameText(AOptions[1], S_FD_Yes)));
end;

function TRpWebDbxAdminService.ResolveEditorKind(const AName,
  AValue: string; AOptions: TStrings; const AAllowCustomValue: Boolean): TRpWebEditorKind;
begin
  if IsReadOnlyParam(AName) then
    Exit(weReadOnly);
  if AOptions.Count > 0 then
  begin
    if IsClosedOptionSet(AName, AOptions) or (not AAllowCustomValue) then
      Exit(weCombo);
    Exit(weComboEditable);
  end;
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
    ListConnectionTypes(AOptions)
  else if SameText(Trim(AParamName), RP_WEB_DBX_DRIVER_PARAM) then
    ListDbExpressConcreteDrivers(AConnAdmin, AOptions)
  else if AConnAdmin.drivers.SectionExists(Trim(AParamName)) then
    AConnAdmin.drivers.ReadSection(Trim(AParamName), AOptions);
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

procedure TRpWebDbxAdminService.ListConnectionTypes(ADrivers: TStrings);
begin
  ADrivers.Clear;
{$IFDEF FIREDAC}
  ADrivers.Add(RP_WEB_DRIVER_FAMILY_FIREDAC);
{$ENDIF}
{$IFDEF MSWINDOWS}
{$IFDEF USESQLEXPRESS}
  ADrivers.Add(RP_WEB_DRIVER_FAMILY_DBEXPRESS);
{$ENDIF}
{$ENDIF}
  ADrivers.Add(RP_WEB_DRIVER_FAMILY_AGENT);
end;

procedure TRpWebDbxAdminService.ListDbExpressDrivers(ADrivers: TStrings);
var
  LConnAdmin: TRpConnAdmin;
begin
  LConnAdmin := CreateConnAdmin;
  try
    ListDbExpressConcreteDrivers(LConnAdmin, ADrivers);
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
      LItem.DisplayDriverName := ResolveDriverFamily(LItem.DriverName);
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
    ListConnectionTypes(ADrivers);
  finally
    LConnAdmin.Free;
  end;
end;

procedure TRpWebDbxAdminService.GetConnectionParams(const AConnectionName: string;
  AParams: TList<TRpWebConnectionParam>; AOverrideValues: TStrings);
var
  LConnAdmin: TRpConnAdmin;
  LStoredValues: TStringList;
  LSeedValues: TStringList;
  LEffectiveValues: TStringList;
  LEditableOptionNames: TStringList;
  LOptionMap: TObjectDictionary<string, TStringList>;
  I: Integer;
  LParam: TRpWebConnectionParam;
  LName: string;
  LDriverName: string;
  LStoredActualDriverName: string;
  LDriverFamily: string;
  LMappedOptions: TStringList;
  LClearDriverDefaults: Boolean;
begin
  AParams.Clear;
  LConnAdmin := CreateConnAdmin;
  LStoredValues := TStringList.Create;
  LSeedValues := TStringList.Create;
  LEffectiveValues := TStringList.Create;
  LEditableOptionNames := TStringList.Create;
  LOptionMap := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  try
    LConnAdmin.GetConnectionParams(AConnectionName, LStoredValues);
    if LStoredValues.Count = 0 then
      raise Exception.Create('Connection not found: ' + AConnectionName);

    LClearDriverDefaults := (AOverrideValues <> nil) and
      SameText(Trim(AOverrideValues.Values[RP_WEB_CLEAR_DRIVER_DEFAULTS]), '1');

    LStoredActualDriverName := Trim(LStoredValues.Values['DriverName']);
    LDriverFamily := ResolveDriverFamily(LStoredActualDriverName);
    if (AOverrideValues <> nil) and
      (Length(Trim(AOverrideValues.Values['DriverName'])) > 0) then
      LDriverFamily := Trim(AOverrideValues.Values['DriverName']);

    if not LClearDriverDefaults then
      LSeedValues.Assign(LStoredValues);
    LSeedValues.Values['DriverName'] := LDriverFamily;
    if SameText(LDriverFamily, RP_WEB_DRIVER_FAMILY_DBEXPRESS) then
      LSeedValues.Values[RP_WEB_DBX_DRIVER_PARAM] := LStoredActualDriverName;
    MergeConnectionValues(LSeedValues, AOverrideValues);
    if LSeedValues.IndexOfName(RP_WEB_CLEAR_DRIVER_DEFAULTS) >= 0 then
      LSeedValues.Delete(LSeedValues.IndexOfName(RP_WEB_CLEAR_DRIVER_DEFAULTS));

    LDriverName := ResolveEffectiveDriverName(LSeedValues, LStoredActualDriverName);

    BuildDriverParamValues(LConnAdmin, LDriverName, LSeedValues,
      LEffectiveValues, LOptionMap, LEditableOptionNames);
    if LEffectiveValues.Count = 0 then
      LEffectiveValues.Assign(LStoredValues);

    if not LClearDriverDefaults then
      MergeKnownConnectionValues(LEffectiveValues, LStoredValues);
    MergeKnownConnectionValues(LEffectiveValues, AOverrideValues);
    if LEffectiveValues.IndexOfName(RP_WEB_CLEAR_DRIVER_DEFAULTS) >= 0 then
      LEffectiveValues.Delete(LEffectiveValues.IndexOfName(RP_WEB_CLEAR_DRIVER_DEFAULTS));
    LEffectiveValues.Values['DriverName'] := LDriverFamily;
    if SameText(LDriverFamily, RP_WEB_DRIVER_FAMILY_DBEXPRESS) then
      LEffectiveValues.Values[RP_WEB_DBX_DRIVER_PARAM] := LDriverName
    else if LEffectiveValues.IndexOfName(RP_WEB_DBX_DRIVER_PARAM) >= 0 then
      LEffectiveValues.Delete(LEffectiveValues.IndexOfName(RP_WEB_DBX_DRIVER_PARAM));

    for I := 0 to LEffectiveValues.Count - 1 do
    begin
      LName := LEffectiveValues.Names[I];
      LParam := TRpWebConnectionParam.Create;
      LParam.Name := LName;
      LParam.Value := LEffectiveValues.ValueFromIndex[I];
      LParam.OriginalValue := LParam.Value;
      LParam.IsSensitive := IsSensitiveParam(LName);
      LParam.IsReadOnly := IsReadOnlyParam(LName);
      if SameText(LName, 'DriverID') then
        FillDriverOptions(LConnAdmin, LName, LParam.Options)
      else if LOptionMap.TryGetValue(LName, LMappedOptions) then
        LParam.Options.Assign(LMappedOptions)
      else
        FillDriverOptions(LConnAdmin, LName, LParam.Options);
      LParam.EditorKind := ResolveEditorKind(LName, LParam.Value,
        LParam.Options, LEditableOptionNames.IndexOf(LName) >= 0);
      AParams.Add(LParam);
    end;
  finally
    LOptionMap.Free;
    LEditableOptionNames.Free;
    LEffectiveValues.Free;
    LSeedValues.Free;
    LStoredValues.Free;
    LConnAdmin.Free;
  end;
end;

procedure TRpWebDbxAdminService.CreateConnection(const AConnectionName,
  ADriverName: string; const ADbExpressDriverName: string);
var
  LConnAdmin: TRpConnAdmin;
  LEffectiveDriverName: string;
begin
  ValidateConnectionName(AConnectionName);
  if Length(Trim(ADriverName)) = 0 then
    raise Exception.Create('Driver name is required');
  LEffectiveDriverName := Trim(ADriverName);
  if SameText(LEffectiveDriverName, 'DBExpress') then
  begin
    LEffectiveDriverName := Trim(ADbExpressDriverName);
    if Length(LEffectiveDriverName) = 0 then
      raise Exception.Create('DBExpress driver is required');
  end;
  LConnAdmin := CreateConnAdmin;
  try
    LConnAdmin.AddConnection(Trim(AConnectionName), LEffectiveDriverName);
    LConnAdmin.config.UpdateFile;
  finally
    LConnAdmin.Free;
  end;
  ReloadAfterWrite;
end;

procedure TRpWebDbxAdminService.DiscoverHubConnections(const AApiKey: string;
  AConnections: TStrings);
begin
  if AConnections = nil then
    Exit;
  AConnections.Clear;
  if Length(Trim(AApiKey)) = 0 then
    Exit;
  if not TRpDatabaseHttp.GetHubDatabases(Trim(AApiKey), AConnections) then
    raise Exception.Create('Failed to connect to Hub for discovery. Check your API Key and internet connection.');
end;

procedure TRpWebDbxAdminService.UpdateConnectionParams(const AConnectionName: string;
  AValues: TStrings);
var
  LConnAdmin: TRpConnAdmin;
  LCurrentParams: TStringList;
  LSeedValues: TStringList;
  LAllowedParams: TStringList;
  I: Integer;
  LName: string;
  LOriginalDriverName: string;
  LNewDriverName: string;
  LDriverFamily: string;
begin
  ValidateConnectionName(AConnectionName);
  LConnAdmin := CreateConnAdmin;
  LCurrentParams := TStringList.Create;
  LSeedValues := TStringList.Create;
  LAllowedParams := TStringList.Create;
  try
    LConnAdmin.GetConnectionParams(AConnectionName, LCurrentParams);
    if LCurrentParams.Count = 0 then
      raise Exception.Create('Connection not found: ' + AConnectionName);

    LOriginalDriverName := Trim(LCurrentParams.Values['DriverName']);
    LDriverFamily := Trim(AValues.Values['DriverName']);
    if Length(LDriverFamily) = 0 then
      LDriverFamily := ResolveDriverFamily(LOriginalDriverName);
    LNewDriverName := ResolveEffectiveDriverName(AValues, LOriginalDriverName);
    if not SameText(LNewDriverName, LOriginalDriverName) then
    begin
      LConnAdmin.AddConnection(AConnectionName, LNewDriverName);
      LCurrentParams.Clear;
      LConnAdmin.GetConnectionParams(AConnectionName, LCurrentParams);
    end;

    LSeedValues.Assign(LCurrentParams);
    MergeConnectionValues(LSeedValues, AValues);
    BuildDriverParamValues(LConnAdmin, LNewDriverName, LSeedValues,
      LAllowedParams, nil);
    if LAllowedParams.Count = 0 then
      LAllowedParams.Assign(LCurrentParams);

    for I := 0 to AValues.Count - 1 do
    begin
      LName := Trim(AValues.Names[I]);
      if Length(LName) = 0 then
        Continue;
      if SameText(LName, RP_WEB_DBX_DRIVER_PARAM) then
        Continue;
      if SameText(LName, 'DriverName') then
      begin
        LConnAdmin.config.WriteString(AConnectionName, 'DriverName', LNewDriverName);
        Continue;
      end;
      if not SameText(LName, 'DriverName') and
        (LAllowedParams.IndexOfName(LName) < 0) then
        Continue;
      LConnAdmin.config.WriteString(AConnectionName, LName,
        AValues.ValueFromIndex[I]);
    end;
    LConnAdmin.config.UpdateFile;
  finally
    LAllowedParams.Free;
    LSeedValues.Free;
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
  LFormParams: TList<TRpWebConnectionParam>;
  LFormParam: TRpWebConnectionParam;
  I: Integer;
  LParams: TStringList;
begin
  LFormParams := TList<TRpWebConnectionParam>.Create;
  LParams := TStringList.Create;
  try
    ValidateConnectionName(AConnectionName);
    GetConnectionParams(AConnectionName, LFormParams, AValues);
    if LFormParams.Count = 0 then
      raise Exception.Create('Connection not found: ' + AConnectionName);

    for I := 0 to LFormParams.Count - 1 do
    begin
      LFormParam := LFormParams[I];
      SetNameValuePreserveEmpty(LParams, LFormParam.Name, '');
    end;
    MergeConnectionValues(LParams, AValues);
    Result := ExecuteConnectionTest(AConnectionName, LParams);
  finally
    for I := 0 to LFormParams.Count - 1 do
    begin
      LFormParam := LFormParams[I];
      LFormParam.Clear;
    end;
    LParams.Free;
    LFormParams.Free;
  end;
end;

end.