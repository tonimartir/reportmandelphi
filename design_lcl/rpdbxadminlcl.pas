{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpdbxadminlcl                                   }
{       Connections of dbxconnections for the new       }
{       report wizard (FPC)                             }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpdbxadminlcl;

{ The part of server/web/rpwebdbxadmin (TRpWebDbxAdminService) that the new
  report wizard of the VCL designer (rpmdfnewreportwizardvcl) uses: create a
  connection in dbxconnections, its parameter list with the editor of each
  value, save the edited values and test a connection. rpwebdbxadmin is not
  in the FPC packages (System.JSON, FireDAC metadata, dbExpress), so this is
  the same logic over the same files (TRpConnAdmin: dbxconnections and the
  dbxdrivers sections) for the drivers of the FPC engine:

  - 'Reportman AI Agent' (rpdbHttp): ApiKey and HubDatabaseId; the test is
    api/agent/testconnection, as ExecuteHttpConnectionTest.
  - 'ZeosLib' (rpdatazeos): the [ZeosLib] driver section, with the protocol
    in 'Database Protocol' (the one rpdatainfo reads).
  - 'Sqlite' (rpfiredac): the FireDAC connections of the FPC engine are
    SQLite files opened with SQLdb; the engine opens a connection whose
    DriverName is Sqlite (DriverName=FireDac is refused by the FPC shim), and
    the Delphi FireDAC driver opens it too (DriverName Sqlite).

  The tests run in worker threads (RpExecuteConnectionTest), the rest in the
  main thread. }

{$mode delphi}

interface

uses
  SysUtils, Classes, Generics.Collections, rpdatainfo;

const
  RP_DBX_DRIVER_FAMILY_DBEXPRESS = 'DBExpress';
  RP_DBX_DRIVER_FAMILY_FIREDAC = 'FireDac';
  RP_DBX_DRIVER_FAMILY_AGENT = 'Reportman AI Agent';
  RP_DBX_DRIVER_FAMILY_ZEOS = 'ZeosLib';
  // DriverName of the SQLite connections (FireDAC driver of the FPC engine)
  RP_DBX_DRIVER_SQLITE = 'Sqlite';
  RP_DBX_DBX_DRIVER_PARAM = 'DBXDriverName';
  // The Zeos protocol key read by rpdatainfo
  RP_DBX_ZEOS_PROTOCOL_PARAM = 'Database Protocol';
  RP_DBX_HTTP_TEST_TIMEOUT_MS = 10000;

type
  TRpDbxEditorKind = (
    weText,
    wePassword,
    weCombo,
    weComboEditable,
    weReadOnly,
    weTextArea
  );

  TRpDbxConnectionParam = record
    Name: string;
    Value: string;
    OriginalValue: string;
    IsSensitive: Boolean;
    IsReadOnly: Boolean;
    EditorKind: TRpDbxEditorKind;
    Options: TStringList;
    class function Create: TRpDbxConnectionParam; static;
    procedure Clear;
  end;

  TRpDbxConnectionTestResult = record
    Success: Boolean;
    MessageText: string;
    DriverName: string;
  end;

  { TRpDbxAdminLCL }

  TRpDbxAdminLCL = class
  private
    function CreateConnAdmin: TRpConnAdmin;
    // ADriverId: the DriverID of a FireDac connection (the parameters of
    // that SQLdb driver)
    procedure BuildDriverParamValues(AConnAdmin: TRpConnAdmin;
      const ADriverName: string; AValues: TStrings;
      AEditableOptionNames: TStrings; const ADriverId: string = '');
    procedure FillDriverOptions(AConnAdmin: TRpConnAdmin;
      const AParamName: string; AOptions: TStrings);
    function ResolveEditorKind(const AName, AValue: string; AOptions: TStrings;
      AAllowCustomValue: Boolean): TRpDbxEditorKind;
    procedure WriteNewConnection(AConnAdmin: TRpConnAdmin;
      const AConnectionName, ADriverName, AProtocol: string);
  public
    // Connection names of dbxconnections
    procedure GetConnectionNames(AList: TStrings);
    function ConnectionExists(const AConnectionName: string): Boolean;
    // Stored values of a connection (empty when it does not exist)
    procedure GetConnectionValues(const AConnectionName: string; AValues: TStrings);
    // TRpWebDbxAdminService.CreateConnection: the connection with the
    // defaults of its driver. AProtocol: the Zeos protocol
    procedure CreateConnection(const AConnectionName, ADriverName: string;
      const AProtocol: string = '');
    // TRpWebDbxAdminService.UpdateConnectionParams: writes the values that
    // belong to the driver of the connection
    procedure UpdateConnectionParams(const AConnectionName: string;
      AValues: TStrings);
    // TRpWebDbxAdminService.GetConnectionParams: the parameters of the
    // driver with the stored values, their options and editor. The caller
    // frees the lists with RpFreeConnectionParams
    procedure GetConnectionParams(const AConnectionName: string;
      AParams: TList<TRpDbxConnectionParam>; AOverrideValues: TStrings = nil);
    // The values a test of the connection uses: the stored ones with
    // AOverrideValues on top (TestConnectionValues)
    procedure GetTestValues(const AConnectionName: string; AOverrideValues,
      AResult: TStrings);
  end;

// Family of a DriverName of dbxconnections ('FireDac', 'Reportman AI Agent',
// 'ZeosLib', 'Sqlite' or, for any other, 'DBExpress')
function RpDbxDriverFamily(const ADriverName: string): string;
// The engine driver of a connection
function RpDbxEngineDriver(const ADriverName: string): TRpDbDriver;
procedure RpFreeConnectionParams(AParams: TList<TRpDbxConnectionParam>);
procedure RpValidateConnectionName(const AName: string);
// Tests a connection with AParams (the values of GetTestValues); any
// thread. AToken: session of the Hub (read in the main thread), used by an
// Agent connection without API key
function RpExecuteConnectionTest(const AConnectionName: string; AParams: TStrings;
  const AToken: string): TRpDbxConnectionTestResult;

implementation

uses
  rpparams, rpdatahttp, rpjsonfpc, rpauthmanager, rpsqldbconnfpc;

// A FireDac connection with a DriverID that SQLdb opens
function IsSQLDBConnection(const ADriverName, ADriverId: string): Boolean;
begin
  Result := (RpDbxDriverFamily(ADriverName) = RP_DBX_DRIVER_FAMILY_FIREDAC) and
    (RpSQLDBDriverId(ADriverId) <> '');
end;

procedure SetNameValuePreserveEmpty(AValues: TStrings; const AName, AValue: string);
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

procedure MergeConnectionValues(ABaseValues, AOverrideValues: TStrings);
var
  I: Integer;
  LName: string;
begin
  if (ABaseValues = nil) or (AOverrideValues = nil) then
    Exit;
  for I := 0 to AOverrideValues.Count - 1 do
  begin
    LName := Trim(AOverrideValues.Names[I]);
    if LName = '' then
      Continue;
    SetNameValuePreserveEmpty(ABaseValues, LName, AOverrideValues.ValueFromIndex[I]);
  end;
end;

procedure MergeKnownConnectionValues(ABaseValues, AOverrideValues: TStrings);
var
  I: Integer;
  LName: string;
begin
  if (ABaseValues = nil) or (AOverrideValues = nil) then
    Exit;
  for I := 0 to AOverrideValues.Count - 1 do
  begin
    LName := Trim(AOverrideValues.Names[I]);
    if LName = '' then
      Continue;
    if SameText(LName, 'DriverName') or (ABaseValues.IndexOfName(LName) >= 0) then
      SetNameValuePreserveEmpty(ABaseValues, LName, AOverrideValues.ValueFromIndex[I]);
  end;
end;

function RpDbxDriverFamily(const ADriverName: string): string;
begin
  if SameText(ADriverName, RP_DBX_DRIVER_FAMILY_FIREDAC) then
    Result := RP_DBX_DRIVER_FAMILY_FIREDAC
  else if SameText(ADriverName, RP_DBX_DRIVER_FAMILY_AGENT) then
    Result := RP_DBX_DRIVER_FAMILY_AGENT
  else if SameText(ADriverName, RP_DBX_DRIVER_FAMILY_ZEOS) then
    Result := RP_DBX_DRIVER_FAMILY_ZEOS
  else if SameText(ADriverName, RP_DBX_DRIVER_SQLITE) then
    Result := RP_DBX_DRIVER_SQLITE
  else
    Result := RP_DBX_DRIVER_FAMILY_DBEXPRESS;
end;

// ResolveEffectiveDriverName of rpwebdbxadmin
function ResolveEffectiveDriverName(AValues: TStrings;
  const AFallbackDriverName: string = ''): string;
var
  LFamily: string;
begin
  LFamily := Trim(AValues.Values['DriverName']);
  if SameText(LFamily, RP_DBX_DRIVER_FAMILY_DBEXPRESS) then
    Result := Trim(AValues.Values[RP_DBX_DBX_DRIVER_PARAM])
  else
    Result := LFamily;
  if Result = '' then
    Result := Trim(AFallbackDriverName);
end;

function RpDbxEngineDriver(const ADriverName: string): TRpDbDriver;
var
  LFamily: string;
begin
  LFamily := RpDbxDriverFamily(ADriverName);
  if (LFamily = RP_DBX_DRIVER_FAMILY_FIREDAC) or (LFamily = RP_DBX_DRIVER_SQLITE) then
    Result := rpfiredac
  else if LFamily = RP_DBX_DRIVER_FAMILY_AGENT then
    Result := rpdbHttp
  else if LFamily = RP_DBX_DRIVER_FAMILY_ZEOS then
    Result := rpdatazeos
  else
    Result := rpdatadbexpress;
end;

procedure RpFreeConnectionParams(AParams: TList<TRpDbxConnectionParam>);
var
  I: Integer;
begin
  if AParams = nil then
    Exit;
  for I := 0 to AParams.Count - 1 do
    AParams[I].Options.Free;
  AParams.Clear;
end;

procedure RpValidateConnectionName(const AName: string);
var
  LName: string;
begin
  LName := Trim(AName);
  if LName = '' then
    raise Exception.Create('Connection name is required');
  if (Pos('=', LName) > 0) or (Pos('[', LName) > 0) or (Pos(']', LName) > 0) then
    raise Exception.Create('Connection name contains invalid characters');
end;

{ TRpDbxConnectionParam }

class function TRpDbxConnectionParam.Create: TRpDbxConnectionParam;
begin
  Result.Name := '';
  Result.Value := '';
  Result.OriginalValue := '';
  Result.IsSensitive := False;
  Result.IsReadOnly := False;
  Result.EditorKind := weText;
  Result.Options := TStringList.Create;
end;

procedure TRpDbxConnectionParam.Clear;
begin
  FreeAndNil(Options);
  Name := '';
  Value := '';
  OriginalValue := '';
  IsSensitive := False;
  IsReadOnly := False;
  EditorKind := weText;
end;

{ Connection tests }

function ExtractHttpConnectionTestMessage(const AResponseText: string): string;
var
  LValue: TJSONValue;
  LResponseJson, LDataJson: TJSONObject;
  LItem: TJSONValue;
begin
  Result := '';
  if Trim(AResponseText) = '' then
    Exit;
  try
    LValue := TJSONObject.ParseJSONValue(AResponseText);
  except
    Exit;
  end;
  try
    if not (LValue is TJSONObject) then
      Exit;
    LResponseJson := TJSONObject(LValue);
    if LResponseJson.Values['data'] is TJSONObject then
    begin
      LDataJson := TJSONObject(LResponseJson.Values['data']);
      LItem := LDataJson.Values['message'];
      if Assigned(LItem) then
        Exit(LItem.Value);
    end;
    LItem := LResponseJson.Values['message'];
    if Assigned(LItem) then
      Result := LItem.Value;
  finally
    LValue.Free;
  end;
end;

function BuildHttpConnectionFailureMessage(const AErrorText: string): string;
begin
  Result := 'Agent Connection: Fail' + sLineBreak + 'Database Connection: Fail';
  if Trim(AErrorText) <> '' then
    Result := Result + sLineBreak + 'Error: ' + Trim(AErrorText);
end;

// ExecuteHttpConnectionTest of rpwebdbxadmin
function ExecuteHttpConnectionTest(AParams: TStrings; const AToken: string;
  out AMessageText: string): Boolean;
var
  LDatabase: TRpDatabaseHttp;
  LRequestBody: TJSONObject;
  LResponseStream: TStringStream;
begin
  AMessageText := '';
  LDatabase := TRpDatabaseHttp.Create;
  try
    LDatabase.ApiKey := AParams.Values['ApiKey'];
    LDatabase.HubDatabaseId := StrToInt64Def(AParams.Values['HubDatabaseId'], 0);
    if (LDatabase.ApiKey = '') and (AToken <> '') then
      LDatabase.Token := AToken;
    LRequestBody := TJSONObject.Create;
    try
      LRequestBody.AddPair('hubDatabaseId', TJSONNumber.Create(LDatabase.HubDatabaseId));
      LResponseStream := TStringStream.Create('');
      try
        try
          Result := LDatabase.InternalRequest('api/agent/testconnection',
            LRequestBody, LResponseStream, RP_DBX_HTTP_TEST_TIMEOUT_MS);
          if Result then
          begin
            AMessageText := ExtractHttpConnectionTestMessage(LResponseStream.DataString);
            if Trim(AMessageText) = '' then
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

function RpExecuteConnectionTest(const AConnectionName: string; AParams: TStrings;
  const AToken: string): TRpDbxConnectionTestResult;
var
  LDriverName: string;
  LList: TRpDatabaseInfoList;
  LItem: TRpDatabaseInfoItem;
  LParams: TRpParamList;
  I: Integer;
  LName: string;
begin
  Result.Success := False;
  Result.MessageText := '';
  LDriverName := ResolveEffectiveDriverName(AParams);
  Result.DriverName := LDriverName;
  try
    if RpDbxDriverFamily(LDriverName) = RP_DBX_DRIVER_FAMILY_AGENT then
    begin
      Result.Success := ExecuteHttpConnectionTest(AParams, AToken, Result.MessageText);
      Exit;
    end;
    // As rpwebdbxadmin: the values go as DBPARAM_ parameters, above the ones
    // stored in dbxconnections
    LList := TRpDatabaseInfoList.Create(nil);
    LParams := TRpParamList.Create(nil);
    try
      for I := 0 to AParams.Count - 1 do
      begin
        LName := Trim(AParams.Names[I]);
        if LName = '' then
          Continue;
        LParams.Add('DBPARAM_' + LName).AsString := WideString(AParams.ValueFromIndex[I]);
      end;
      LItem := LList.Add(AConnectionName);
      LItem.Driver := RpDbxEngineDriver(LDriverName);
      LItem.LoginPrompt := False;
      LItem.Connect(LParams);
      try
        Result.Success := True;
      finally
        LItem.DisConnect;
      end;
    finally
      LParams.Free;
      LList.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.MessageText := E.Message;
    end;
  end;
end;

{ TRpDbxAdminLCL }

function TRpDbxAdminLCL.CreateConnAdmin: TRpConnAdmin;
begin
  // dbxconnections of the designer (DBXConnectionsFileOverride included)
  Result := TRpConnAdmin.Create;
end;

procedure TRpDbxAdminLCL.GetConnectionNames(AList: TStrings);
var
  LConnAdmin: TRpConnAdmin;
begin
  AList.Clear;
  LConnAdmin := CreateConnAdmin;
  try
    LConnAdmin.GetConnectionNames(AList, '');
  finally
    LConnAdmin.Free;
  end;
end;

function TRpDbxAdminLCL.ConnectionExists(const AConnectionName: string): Boolean;
var
  LNames: TStringList;
  I: Integer;
begin
  Result := False;
  LNames := TStringList.Create;
  try
    GetConnectionNames(LNames);
    for I := 0 to LNames.Count - 1 do
      if SameText(LNames[I], Trim(AConnectionName)) then
        Exit(True);
  finally
    LNames.Free;
  end;
end;

procedure TRpDbxAdminLCL.GetConnectionValues(const AConnectionName: string;
  AValues: TStrings);
var
  LConnAdmin: TRpConnAdmin;
begin
  AValues.Clear;
  LConnAdmin := CreateConnAdmin;
  try
    LConnAdmin.GetConnectionParams(AConnectionName, AValues);
  finally
    LConnAdmin.Free;
  end;
end;

procedure TRpDbxAdminLCL.WriteNewConnection(AConnAdmin: TRpConnAdmin;
  const AConnectionName, ADriverName, AProtocol: string);
var
  LValues: TStringList;
  I: Integer;
begin
  if RpDbxDriverFamily(ADriverName) = RP_DBX_DRIVER_SQLITE then
  begin
    // The [Sqlite] driver section only has dbExpress loaders: the
    // connection is the database file
    AConnAdmin.config.EraseSection(AConnectionName);
    AConnAdmin.config.WriteString(AConnectionName, 'DriverName', RP_DBX_DRIVER_SQLITE);
    AConnAdmin.config.WriteString(AConnectionName, 'Database', '');
  end
  else if IsSQLDBConnection(ADriverName, AProtocol) then
  begin
    // A FireDAC connection as Delphi writes it: its DriverID and the FireDAC
    // parameters of that driver (SQLdb opens it in the FPC engine)
    AConnAdmin.config.EraseSection(AConnectionName);
    LValues := TStringList.Create;
    try
      BuildDriverParamValues(AConnAdmin, ADriverName, LValues, nil, AProtocol);
      for I := 0 to LValues.Count - 1 do
        AConnAdmin.config.WriteString(AConnectionName, LValues.Names[I],
          LValues.ValueFromIndex[I]);
    finally
      LValues.Free;
    end;
  end
  else
  begin
    AConnAdmin.AddConnection(AConnectionName, ADriverName);
    if (Trim(AProtocol) <> '') and
      (RpDbxDriverFamily(ADriverName) = RP_DBX_DRIVER_FAMILY_ZEOS) then
      AConnAdmin.config.WriteString(AConnectionName, RP_DBX_ZEOS_PROTOCOL_PARAM,
        Trim(AProtocol));
  end;
end;

procedure TRpDbxAdminLCL.CreateConnection(const AConnectionName,
  ADriverName: string; const AProtocol: string);
var
  LConnAdmin: TRpConnAdmin;
begin
  RpValidateConnectionName(AConnectionName);
  if Trim(ADriverName) = '' then
    raise Exception.Create('Driver name is required');
  if RpDbxDriverFamily(ADriverName) = RP_DBX_DRIVER_FAMILY_DBEXPRESS then
    raise Exception.Create('Driver not available in this build: ' + ADriverName);
  LConnAdmin := CreateConnAdmin;
  try
    WriteNewConnection(LConnAdmin, Trim(AConnectionName), Trim(ADriverName), AProtocol);
    LConnAdmin.config.UpdateFile;
  finally
    LConnAdmin.Free;
  end;
end;

procedure TRpDbxAdminLCL.BuildDriverParamValues(AConnAdmin: TRpConnAdmin;
  const ADriverName: string; AValues: TStrings; AEditableOptionNames: TStrings;
  const ADriverId: string);
var
  I: Integer;
  LParamName: string;
  LParamNames: TStringList;
begin
  AValues.Clear;
  if Trim(ADriverName) = '' then
    Exit;
  if RpDbxDriverFamily(ADriverName) = RP_DBX_DRIVER_SQLITE then
  begin
    AValues.Add('DriverName=' + RP_DBX_DRIVER_SQLITE);
    AValues.Add('Database=');
    Exit;
  end;
  // FireDac with a driver of SQLdb: the FireDAC parameters of that driver
  // (the [FireDac] section of the drivers file is the one of Firebird)
  if IsSQLDBConnection(ADriverName, ADriverId) then
  begin
    RpSQLDBDriverParams(ADriverId, AValues);
    AValues.Insert(0, 'DriverID=' + RpSQLDBDriverId(ADriverId));
    AValues.Insert(0, 'DriverName=' + RP_DBX_DRIVER_FAMILY_FIREDAC);
    Exit;
  end;
  LParamNames := TStringList.Create;
  try
    AConnAdmin.drivers.ReadSection(Trim(ADriverName), LParamNames);
    for I := 0 to LParamNames.Count - 1 do
    begin
      LParamName := Trim(LParamNames[I]);
      if LParamName = '' then
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
      // A list of values in the drivers file and no default: any value
      if (AEditableOptionNames <> nil) and
        AConnAdmin.drivers.SectionExists(LParamName) and
        (Trim(AConnAdmin.drivers.ReadString(Trim(ADriverName), LParamName, '')) = '') and
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

procedure TRpDbxAdminLCL.FillDriverOptions(AConnAdmin: TRpConnAdmin;
  const AParamName: string; AOptions: TStrings);
begin
  AOptions.Clear;
  if SameText(Trim(AParamName), 'DriverName') then
  begin
    // The connection types of the FPC engine (ListConnectionTypes)
    AOptions.Add(RP_DBX_DRIVER_SQLITE);
    AOptions.Add(RP_DBX_DRIVER_FAMILY_FIREDAC);
    AOptions.Add(RP_DBX_DRIVER_FAMILY_AGENT);
    AOptions.Add(RP_DBX_DRIVER_FAMILY_ZEOS);
  end
  else if SameText(Trim(AParamName), 'DriverID') then
    // The FireDAC drivers that SQLdb opens
    RpSQLDBDriverIds(AOptions)
  else if AConnAdmin.drivers.SectionExists(Trim(AParamName)) then
    AConnAdmin.drivers.ReadSection(Trim(AParamName), AOptions);
end;

function IsSensitiveParam(const AName: string): Boolean;
var
  LName: string;
begin
  LName := UpperCase(Trim(AName));
  Result := (Pos('PASSWORD', LName) > 0) or (Pos('PWD', LName) > 0) or
    (Pos('SECRET', LName) > 0) or (Pos('TOKEN', LName) > 0) or
    (Pos('APIKEY', LName) > 0);
end;

function IsClosedOptionSet(const AName: string; AOptions: TStrings): Boolean;
begin
  Result := SameText(AName, 'DriverName') or SameText(AName, 'DriverID') or
    SameText(AName, RP_DBX_DBX_DRIVER_PARAM);
  if Result then
    Exit;
  if AOptions.Count <> 2 then
    Exit(False);
  // The boolean pairs of FireDAC (S_FD_True/S_FD_False, S_FD_Yes/S_FD_No)
  Result :=
    ((SameText(AOptions[0], 'True') and SameText(AOptions[1], 'False')) or
     (SameText(AOptions[0], 'False') and SameText(AOptions[1], 'True')) or
     (SameText(AOptions[0], 'Yes') and SameText(AOptions[1], 'No')) or
     (SameText(AOptions[0], 'No') and SameText(AOptions[1], 'Yes')));
end;

function TRpDbxAdminLCL.ResolveEditorKind(const AName, AValue: string;
  AOptions: TStrings; AAllowCustomValue: Boolean): TRpDbxEditorKind;
begin
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

procedure TRpDbxAdminLCL.GetConnectionParams(const AConnectionName: string;
  AParams: TList<TRpDbxConnectionParam>; AOverrideValues: TStrings);
var
  LConnAdmin: TRpConnAdmin;
  LStoredValues, LSeedValues, LEffectiveValues, LEditableOptionNames: TStringList;
  I: Integer;
  LParam: TRpDbxConnectionParam;
  LName, LDriverName, LStoredActualDriverName, LDriverFamily: string;
begin
  RpFreeConnectionParams(AParams);
  LConnAdmin := CreateConnAdmin;
  LStoredValues := TStringList.Create;
  LSeedValues := TStringList.Create;
  LEffectiveValues := TStringList.Create;
  LEditableOptionNames := TStringList.Create;
  try
    LConnAdmin.GetConnectionParams(AConnectionName, LStoredValues);
    if LStoredValues.Count = 0 then
      raise Exception.Create('Connection not found: ' + AConnectionName);

    LStoredActualDriverName := Trim(LStoredValues.Values['DriverName']);
    LDriverFamily := RpDbxDriverFamily(LStoredActualDriverName);
    if (AOverrideValues <> nil) and (Trim(AOverrideValues.Values['DriverName']) <> '') then
      LDriverFamily := Trim(AOverrideValues.Values['DriverName']);

    LSeedValues.Assign(LStoredValues);
    LSeedValues.Values['DriverName'] := LDriverFamily;
    if SameText(LDriverFamily, RP_DBX_DRIVER_FAMILY_DBEXPRESS) then
      LSeedValues.Values[RP_DBX_DBX_DRIVER_PARAM] := LStoredActualDriverName;
    MergeConnectionValues(LSeedValues, AOverrideValues);
    LDriverName := ResolveEffectiveDriverName(LSeedValues, LStoredActualDriverName);

    BuildDriverParamValues(LConnAdmin, LDriverName, LEffectiveValues, LEditableOptionNames,
      LSeedValues.Values['DriverID']);
    if LEffectiveValues.Count = 0 then
      LEffectiveValues.Assign(LStoredValues);
    // A FireDAC connection of SQLdb shows also the parameters that Delphi
    // wrote (the ones of its DriverID in FireDAC)
    if IsSQLDBConnection(LDriverName, LSeedValues.Values['DriverID']) then
      MergeConnectionValues(LEffectiveValues, LStoredValues)
    else
      MergeKnownConnectionValues(LEffectiveValues, LStoredValues);
    MergeKnownConnectionValues(LEffectiveValues, AOverrideValues);
    LEffectiveValues.Values['DriverName'] := LDriverFamily;
    if SameText(LDriverFamily, RP_DBX_DRIVER_FAMILY_DBEXPRESS) then
      LEffectiveValues.Values[RP_DBX_DBX_DRIVER_PARAM] := LDriverName
    else if LEffectiveValues.IndexOfName(RP_DBX_DBX_DRIVER_PARAM) >= 0 then
      LEffectiveValues.Delete(LEffectiveValues.IndexOfName(RP_DBX_DBX_DRIVER_PARAM));

    for I := 0 to LEffectiveValues.Count - 1 do
    begin
      LName := LEffectiveValues.Names[I];
      if LName = '' then
        Continue;
      LParam := TRpDbxConnectionParam.Create;
      LParam.Name := LName;
      LParam.Value := LEffectiveValues.ValueFromIndex[I];
      LParam.OriginalValue := LParam.Value;
      LParam.IsSensitive := IsSensitiveParam(LName);
      LParam.IsReadOnly := False;
      FillDriverOptions(LConnAdmin, LName, LParam.Options);
      LParam.EditorKind := ResolveEditorKind(LName, LParam.Value, LParam.Options,
        LEditableOptionNames.IndexOf(LName) >= 0);
      AParams.Add(LParam);
    end;
  finally
    LEditableOptionNames.Free;
    LEffectiveValues.Free;
    LSeedValues.Free;
    LStoredValues.Free;
    LConnAdmin.Free;
  end;
end;

procedure TRpDbxAdminLCL.UpdateConnectionParams(const AConnectionName: string;
  AValues: TStrings);
var
  LConnAdmin: TRpConnAdmin;
  LCurrentParams, LAllowedParams: TStringList;
  I: Integer;
  LName, LOriginalDriverName, LNewDriverName, LDriverId: string;
begin
  RpValidateConnectionName(AConnectionName);
  LConnAdmin := CreateConnAdmin;
  LCurrentParams := TStringList.Create;
  LAllowedParams := TStringList.Create;
  try
    LConnAdmin.GetConnectionParams(AConnectionName, LCurrentParams);
    if LCurrentParams.Count = 0 then
      raise Exception.Create('Connection not found: ' + AConnectionName);

    LOriginalDriverName := Trim(LCurrentParams.Values['DriverName']);
    LNewDriverName := ResolveEffectiveDriverName(AValues, LOriginalDriverName);
    if not SameText(LNewDriverName, LOriginalDriverName) then
    begin
      // Another driver: the connection starts again with its defaults
      WriteNewConnection(LConnAdmin, AConnectionName, LNewDriverName, '');
      LCurrentParams.Clear;
      LConnAdmin.GetConnectionParams(AConnectionName, LCurrentParams);
    end;

    LDriverId := Trim(AValues.Values['DriverID']);
    if LDriverId = '' then
      LDriverId := Trim(LCurrentParams.Values['DriverID']);
    BuildDriverParamValues(LConnAdmin, LNewDriverName, LAllowedParams, nil, LDriverId);
    if LAllowedParams.Count = 0 then
      LAllowedParams.Assign(LCurrentParams)
    else if IsSQLDBConnection(LNewDriverName, LDriverId) then
      MergeConnectionValues(LAllowedParams, LCurrentParams);

    for I := 0 to AValues.Count - 1 do
    begin
      LName := Trim(AValues.Names[I]);
      if LName = '' then
        Continue;
      if SameText(LName, RP_DBX_DBX_DRIVER_PARAM) then
        Continue;
      if SameText(LName, 'DriverName') then
      begin
        LConnAdmin.config.WriteString(AConnectionName, 'DriverName', LNewDriverName);
        Continue;
      end;
      if LAllowedParams.IndexOfName(LName) < 0 then
        Continue;
      LConnAdmin.config.WriteString(AConnectionName, LName, AValues.ValueFromIndex[I]);
    end;
    LConnAdmin.config.UpdateFile;
  finally
    LAllowedParams.Free;
    LCurrentParams.Free;
    LConnAdmin.Free;
  end;
end;

procedure TRpDbxAdminLCL.GetTestValues(const AConnectionName: string;
  AOverrideValues, AResult: TStrings);
begin
  RpValidateConnectionName(AConnectionName);
  GetConnectionValues(AConnectionName, AResult);
  if AResult.Count = 0 then
    raise Exception.Create('Connection not found: ' + AConnectionName);
  MergeConnectionValues(AResult, AOverrideValues);
end;

end.
