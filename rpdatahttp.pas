{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpdatahttp                                      }
{       Remote HTTP Hub-Agent Driver                    }
{                                                       }
{       Copyright (c) 1994-2025 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}
unit rpdatahttp;
interface
{$I rpconf.inc}


uses
  SysUtils, Classes, DB,
{$IFDEF FIREDAC}
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient,
{$ELSE}
  // Fallback to Indy if TNetHTTPClient is not available
  IdHTTP, IdSSLOpenSSL,
{$ENDIF}
  System.JSON,
{$IFDEF USERPDATASET}
  DBClient,
{$ENDIF}
  rptypes, rpmdconsts, rpauthmanager;
type

  { TRpDatabaseHttp }
  TRpDatabaseHttp = class(TObject)
  private
    FApiKey: string;
    FToken: string;
    FInstallId: string;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
    FAITier: string;
    FAgentSecret: string;
    FAgentAiId: Int64;
    FConnected: Boolean;
    procedure SetConnected(Value: Boolean);
  public
    class function GetHubDatabases(const AApiKey: string; AList: TStrings): Boolean;
    constructor Create;
    function TestConnection: Boolean;
    property ApiKey: string read FApiKey write FApiKey;
    property Token: string read FToken write FToken;
    property InstallId: string read FInstallId write FInstallId;
    property HubDatabaseId: Int64 read FHubDatabaseId write FHubDatabaseId;
    property HubSchemaId: Int64 read FHubSchemaId write FHubSchemaId;
    property AITier: string read FAITier write FAITier;
    property AgentSecret: string read FAgentSecret write FAgentSecret;
    property AgentAiId: Int64 read FAgentAiId write FAgentAiId;
    property Connected: Boolean read FConnected write SetConnected;
    function SuggestSql(const ASql: string; ACursorPosition: Integer; AMode: string): TJSONObject;
    function GetSchemas(AList: TStrings): Boolean;
    function GetUserSchemas(AList: TStrings): Boolean;
    function GetUserAgents(AList: TStrings): Boolean;
    function InternalRequest(const AAction: string; const RequestBody: TJSONObject; ResponseStream: TStream): Boolean;
    function InternalGetRequest(const AAction: string; ResponseStream: TStream): Boolean;
  end;
  { TRpDatasetHttp }
  TRpDatasetHttp = class(TPersistent)
  private
    FDatabase: TRpDatabaseHttp;
    FSql: string;
    FDataset: TClientDataSet;
  public
    constructor Create(ADatabase: TRpDatabaseHttp; ADataset: TClientDataSet);
    destructor Destroy; override;
    procedure Open;
    property Sql: string read FSql write FSql;
    property Dataset: TClientDataSet read FDataset;
  end;

const
  HUB_API_URL_DEBUG = 'https://api.reportman.es:7006';
  HUB_API_URL_RELEASE = 'https://api.reportman.es:44568';
{$IFDEF DEBUG}
  HUB_API_URL = HUB_API_URL_DEBUG;
{$ELSE}
  HUB_API_URL = HUB_API_URL_RELEASE;
{$ENDIF}

implementation
{ TRpDatabaseHttp }
constructor TRpDatabaseHttp.Create;
begin
  inherited Create;
  FConnected := False;
  FInstallId := TRpAuthManager.Instance.InstallId;
  ;
  FAITier := 'Standard';
end;
procedure TRpDatabaseHttp.SetConnected(Value: Boolean);
begin
  if Value <> FConnected then
  begin
    if Value then
    begin
      if not TestConnection then
         raise Exception.Create(SRpConnectionFailed);
    end;
    FConnected := Value;
  end;
end;
function TRpDatabaseHttp.TestConnection: Boolean;
var
  LRequestBody: TJSONObject;
  LResponseStream: TMemoryStream;
begin
  Result := False;
  LRequestBody := TJSONObject.Create;
  try
    LRequestBody.AddPair('hubDatabaseId', TJSONNumber.Create(FHubDatabaseId));
    LResponseStream := TMemoryStream.Create;
    try
      // The endpoint is as defined in HubApiClient.Sql.cs
      Result := InternalRequest('api/agent/testconnection', LRequestBody, LResponseStream);
      // We could also parse the response to check { success: true, message: ... }
      // But InternalRequest already checks for HTTP 200/201
    finally
      LResponseStream.Free;
    end;
  finally
    LRequestBody.Free;
  end;
end;
function TRpDatabaseHttp.SuggestSql(const ASql: string; ACursorPosition: Integer; AMode: string): TJSONObject;
var
  LRequest, LConfig: TJSONObject;
  LResponseStream: TStringStream;
  LResponseJson: TJSONObject;
begin
  Result := nil;
  LRequest := TJSONObject.Create;
  try
    LRequest.AddPair('sql', ASql);
    LRequest.AddPair('cursorPosition', TJSONNumber.Create(ACursorPosition));
    LRequest.AddPair('mode', AMode);
    LRequest.AddPair('aiTier', FAITier);
    if FAgentSecret <> '' then
      LRequest.AddPair('agentSecret', FAgentSecret);
    if FAgentAiId <> 0 then
      LRequest.AddPair('agentAiId', TJSONNumber.Create(FAgentAiId));
    
    // Config sub-object
    LConfig := TJSONObject.Create;
    LConfig.AddPair('hubDatabaseId', TJSONNumber.Create(FHubDatabaseId));
    if FHubSchemaId <> 0 then
      LConfig.AddPair('hubSchemaId', TJSONNumber.Create(FHubSchemaId));
    LRequest.AddPair('config', LConfig);
    
    LResponseStream := TStringStream.Create;
    try
      if InternalRequest('NlToSql/SuggestSqlCode', LRequest, LResponseStream) then
      begin
        LResponseStream.Position := 0;
        LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
        if LResponseJson <> nil then
          Result := LResponseJson; // Caller owns it
      end;
    finally
      LResponseStream.Free;
    end;
  finally
    LRequest.Free;
  end;
end;

function TRpDatabaseHttp.GetSchemas(AList: TStrings): Boolean;
var
  LResponseStream: TStringStream;
  LResponseJson: TJSONObject;
  LDataArray: TJSONArray;
  I: Integer;
  LItem: TJSONObject;
begin
  Result := False;
  AList.Clear;
  LResponseStream := TStringStream.Create;
  try
    // api/agent/databases returns all schemas/databases
    if InternalRequest('api/agent/databases', nil, LResponseStream) then
    begin
       LResponseStream.Position := 0;
       LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
       try
         if LResponseJson <> nil then
         begin
            LDataArray := LResponseJson.Values['data'] as TJSONArray;
            if LDataArray <> nil then
            begin
               for I := 0 to LDataArray.Count - 1 do
               begin
                  LItem := LDataArray.Items[I] as TJSONObject;
                  AList.Add(LItem.Values['displayName'].Value);
               end;
               Result := True;
            end;
         end;
       finally
         LResponseJson.Free;
       end;
    end;
  finally
    LResponseStream.Free;
  end;
end;
function TRpDatabaseHttp.InternalRequest(const AAction: string; const RequestBody: TJSONObject; ResponseStream: TStream): Boolean;
{$IFDEF FIREDAC}
var
  LHttpClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LSourceStream: TStringStream;
  LErrorStream: TStringStream;
  LUrl: string;
begin
  Result := False;
  LHttpClient := TNetHTTPClient.Create(nil);
  try
    LSourceStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      LHttpClient.ContentType := 'application/json';
      
      // Authentication Headers - Match AgentController.cs / TokenAuthenticationMiddleware.cs
      if FApiKey <> '' then
        LHttpClient.CustomHeaders['X-Reportman-ApiKey'] := FApiKey;
      
      if FToken <> '' then
        LHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
      
      if FInstallId <> '' then
        LHttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
      LUrl := HUB_API_URL;
      if not LUrl.EndsWith('/') then LUrl := LUrl + '/';
      LUrl := LUrl + AAction;
      LResponse := LHttpClient.Post(LUrl, LSourceStream, ResponseStream);
      
      if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300) then
         Result := True
      else
      begin
         LErrorStream := TStringStream.Create;
         try
           ResponseStream.Position := 0;
           LErrorStream.CopyFrom(ResponseStream, 0);
           raise Exception.CreateFmt('HTTP Error %d: %s'#13#10'%s', [LResponse.StatusCode, LResponse.StatusText, LErrorStream.DataString]);
         finally
           LErrorStream.Free;
         end;
      end;
    finally
      LSourceStream.Free;
    end;
  finally
    LHttpClient.Free;
  end;
end;
{$ELSE}
var
  LIdHttp: TIdHTTP;
  LSourceStream: TStringStream;
  LErrorStream: TStringStream;
  LUrl: string;
begin
  Result := False;
  LIdHttp := TIdHTTP.Create(nil);
  try
    LSourceStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      LIdHttp.Request.ContentType := 'application/json';
      
      if FApiKey <> '' then
        LIdHttp.Request.CustomHeaders.Values['X-Reportman-ApiKey'] := FApiKey;
      
      if FToken <> '' then
        LIdHttp.Request.CustomHeaders.Values['Authorization'] := 'Bearer ' + FToken;
      
      if FInstallId <> '' then
        LIdHttp.Request.CustomHeaders.Values['X-Reportman-WebInstallId'] := FInstallId;
      LUrl := FUrl;
      if not LUrl.EndsWith('/') then LUrl := LUrl + '/';
      LUrl := LUrl + AAction;
      LIdHttp.Post(LUrl, LSourceStream, ResponseStream);
      
      if (LIdHttp.ResponseCode >= 200) and (LIdHttp.ResponseCode < 300) then
         Result := True
      else
      begin
         LErrorStream := TStringStream.Create;
         try
           ResponseStream.Position := 0;
           LErrorStream.CopyFrom(ResponseStream, 0);
           raise Exception.CreateFmt('HTTP Error %d: %s'#13#10'%s', [LIdHttp.ResponseCode, LIdHttp.ResponseText, LErrorStream.DataString]);
         finally
           LErrorStream.Free;
         end;
      end;
    finally
      LSourceStream.Free;
    end;
  finally
    LIdHttp.Free;
  end;
end;
{$ENDIF}
{ TRpDatasetHttp }
constructor TRpDatasetHttp.Create(ADatabase: TRpDatabaseHttp; ADataset: TClientDataSet);
begin
  inherited Create;
  FDatabase := ADatabase;
  FDataset := ADataset;
end;
destructor TRpDatasetHttp.Destroy;
begin
  inherited Destroy;
end;
procedure TRpDatasetHttp.Open;
var
  ColType, ColName: string;
  FDef: TFieldDef;
  RowData: TJSONArray;
  Val: TJSONValue;
  Buffer: TBytes;
  RequestBody: TJSONObject;
  ResponseStream: TMemoryStream;
  ResponseJson: TJSONObject;
  Columns, Rows: TJSONArray;
  I, J: Integer;
  ColObj: TJSONObject;
  LData: TJSONObject;
  jsonString: String;
begin
  if FDatabase = nil then
    raise Exception.Create('Database not assigned');
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('hubDatabaseId', TJSONNumber.Create(FDatabase.HubDatabaseId));
    RequestBody.AddPair('sql', FSql);
    // Parameters support
    RequestBody.AddPair('parameters', TJSONArray.Create); 
    ResponseStream := TMemoryStream.Create;
    try
      if FDatabase.InternalRequest('api/agent/execute', RequestBody, ResponseStream) then
      begin
        ResponseStream.Position := 0;
        SetLength(Buffer, ResponseStream.Size);
        if ResponseStream.Size > 0 then
          ResponseStream.Read(Buffer[0], ResponseStream.Size);
        jsonString:=TEncoding.UTF8.GetString(Buffer);
        ResponseJson := TJSONObject.ParseJSONValue(jsonString) as TJSONObject;
      try
        if ResponseJson = nil then
          raise Exception.Create('Invalid JSON response from Hub');
        if (ResponseJson.Values['success'] <> nil) and (not (ResponseJson.Values['success'] as TJSONBool).AsBoolean) then
        begin
             if ResponseJson.Values['error'] <> nil then
                raise Exception.Create(ResponseJson.Values['error'].Value)
             else
                raise Exception.Create('Request failed');
        end;
        LData := ResponseJson.GetValue('data') as TJSONObject;
        if not Assigned(LData) then
           raise Exception.Create('No data property in result');
        Columns := LData.GetValue('columns') as TJSONArray;
        if not Assigned(Columns) then
           raise Exception.Create('No columns in the result');
        Rows := LData.GetValue('rows') as TJSONArray;
        if not Assigned(Rows) then
           raise Exception.Create('No rows in result');
        if not Assigned(FDataset) then
        begin
          FDataset:=TClientDataSet.Create(nil);
        end;
        FDataset.Close;
        FDataset.FieldDefs.Clear;
        
        // Setup fields
        for I := 0 to Columns.Count - 1 do
        begin
          ColObj := Columns.Items[I] as TJSONObject;
          ColName := ColObj.Values['name'].Value;
          ColType := ColObj.Values['dataType'].Value;
          
          FDef := FDataset.FieldDefs.AddFieldDef;
          FDef.Name := ColName;
          
          // Map .NET types to Delphi TFieldType
          if (ColType = 'Int32') or (ColType = 'Int64') then
            FDef.DataType := ftInteger
          else if (ColType = 'Double') or (ColType = 'Decimal') or (ColType = 'Single') then
            FDef.DataType := ftFloat
          else if (ColType = 'DateTime') then
            FDef.DataType := ftDateTime
          else if (ColType = 'Boolean') then
            FDef.DataType := ftBoolean
          else
          begin
            FDef.DataType := ftString;
            FDef.Size := 255;
          end;
        end;
        FDataset.CreateDataSet;
        // Populate rows
        for I := 0 to Rows.Count - 1 do
        begin
          FDataset.Append;
          RowData := Rows.Items[I] as TJSONArray;
          for J := 0 to Columns.Count - 1 do
          begin
            Val := RowData.Items[J];
            if Val is TJSONNull then
               FDataset.Fields[J].Clear
            else
               FDataset.Fields[J].AsString := Val.Value;
          end;
          FDataset.Post;
        end;
        FDataset.First;
        
      finally
        ResponseJson.Free;
      end;
    end;
    finally
      ResponseStream.Free;
    end;
  finally
    RequestBody.Free;
  end;
end;

class function TRpDatabaseHttp.GetHubDatabases(const AApiKey: string;
  AList: TStrings): Boolean;
var
  LHttpClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LResponseStream: TMemoryStream;
  LJson: TJSONObject;
  LDatabases: TJSONArray;
  LItem: TJSONObject;
  LBuffer: TBytes;
  i: Integer;
begin
  Result := False;
  LHttpClient := TNetHTTPClient.Create(nil);
  LResponseStream := TMemoryStream.Create;
  try
    LHttpClient.CustomHeaders['X-Reportman-ApiKey'] := AApiKey;
    // Use the compiled URL for discovery
    try
      LResponse := LHttpClient.Get(HUB_API_URL + '/api/agent/databases', LResponseStream);
      if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300) then
      begin
        LResponseStream.Position := 0;
        SetLength(LBuffer, LResponseStream.Size);
        if LResponseStream.Size > 0 then
          LResponseStream.Read(LBuffer[0], LResponseStream.Size);
        LJson := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(LBuffer)) as TJSONObject;
        if Assigned(LJson) then
        try
          LDatabases := LJson.GetValue('databases') as TJSONArray;
          if Assigned(LDatabases) then
          begin
            AList.Clear;
            for i := 0 to LDatabases.Count - 1 do
            begin
              LItem := LDatabases.Items[i] as TJSONObject;
              AList.Add(LItem.GetValue('displayName').Value + '=' + LItem.GetValue('hubDatabaseId').Value);
            end;
            Result := True;
          end;
        finally
          LJson.Free;
        end;
      end;
    except
      // Handle connection errors
    end;
  finally
    LResponseStream.Free;
    LHttpClient.Free;
  end;
end;
function TRpDatabaseHttp.InternalGetRequest(const AAction: string; ResponseStream: TStream): Boolean;
var
  LHttpClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LUrl: string;
begin
  Result := False;
  LHttpClient := TNetHTTPClient.Create(nil);
  try
    LHttpClient.ContentType := 'application/json';
    if FApiKey <> '' then
      LHttpClient.CustomHeaders['X-Reportman-ApiKey'] := FApiKey;
    if FToken <> '' then
      LHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
    if FInstallId <> '' then
      LHttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
    LUrl := HUB_API_URL;
    if not LUrl.EndsWith('/') then LUrl := LUrl + '/';
    LUrl := LUrl + AAction;
    LResponse := LHttpClient.Get(LUrl, ResponseStream);
    Result := (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300);
  finally
    LHttpClient.Free;
  end;
end;
function TRpDatabaseHttp.GetUserSchemas(AList: TStrings): Boolean;
var
  LResponseStream: TStringStream;
  LResponseJson: TJSONObject;
  LDatabases: TJSONArray;
  I: Integer;
  LItem: TJSONObject;
begin
  Result := False;
  AList.Clear;
  LResponseStream := TStringStream.Create;
  try
    if InternalGetRequest('api/agent/databases', LResponseStream) then
    begin
      LResponseStream.Position := 0;
      LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
      if LResponseJson <> nil then
      try
        if LResponseJson.Values['databases'] is TJSONArray then
        begin
          LDatabases := LResponseJson.Values['databases'] as TJSONArray;
          for I := 0 to LDatabases.Count - 1 do
          begin
            LItem := LDatabases.Items[I] as TJSONObject;
            AList.Add(LItem.Values['name'].Value + '=' + LItem.Values['hubSchemaId'].Value);
          end;
          Result := True;
        end;
      finally
        LResponseJson.Free;
      end;
    end;
  finally
    LResponseStream.Free;
  end;
end;
function TRpDatabaseHttp.GetUserAgents(AList: TStrings): Boolean;
var
  LResponseStream: TStringStream;
  LResponseJson: TJSONObject;
  LAiEndpoints: TJSONArray;
  I: Integer;
  LItem: TJSONObject;
begin
  Result := False;
  AList.Clear;
  LResponseStream := TStringStream.Create;
  try
    if InternalGetRequest('api/agent/databases', LResponseStream) then
    begin
      LResponseStream.Position := 0;
      LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
      if LResponseJson <> nil then
      try
        if LResponseJson.Values['aiEndpoints'] is TJSONArray then
        begin
          LAiEndpoints := LResponseJson.Values['aiEndpoints'] as TJSONArray;
          for I := 0 to LAiEndpoints.Count - 1 do
          begin
            LItem := LAiEndpoints.Items[I] as TJSONObject;
            AList.Add(Format('%s (%s)=%s|%s', [
              LItem.Values['name'].Value,
              LItem.Values['agentName'].Value,
              LItem.Values['id'].Value,
              LItem.Values['agentSecret'].Value
            ]));
          end;
          Result := True;
        end;
      finally
        LResponseJson.Free;
      end;
    end;
  finally
    LResponseStream.Free;
  end;
end;
end.
