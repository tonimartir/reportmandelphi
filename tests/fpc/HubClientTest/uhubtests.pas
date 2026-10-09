{ End-to-end tests of the shared Hub units (rpauthmanager, rpdatahttp,
  rpdatainfo with Driver = rpdbHttp) against a local fake Hub that answers
  the Hub endpoints with canned responses. HUB_API_URL (and the Microsoft
  token endpoint) are redirected to the fake Hub with RpHttpSetUrlRewrite;
  the browser of the OAuth login is simulated with RpOpenUrlHook. }
unit uhubtests;

{$mode delphi}{$H+}

interface

procedure RunHubTests;

implementation

uses
  SysUtils, Classes, DB, DateUtils, IniFiles, fphttpserver, httpdefs, ssockets, rpjsonfpc, rphttpclientfpc,
  rpnetencodingfpc, rptypes, rpparams, rpdatainfo, rpdatahttp, rpauthmanager, rpmdconsts,
  rpreportdesignercontracts, rpaireportcontracts, utestutil, ufakeserver, ujsoncases;

const
  BS = #92; // backslash, so that no tool turns \u escapes into characters

type
  TFakeHub = class
  public
    StatusCalls: Integer;
    procedure Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
      AResponse: TFPHTTPConnectionResponse);
  end;

  TProgressRecorder = class
  public
    Progress: TStringList;
    Results: TStringList;
    CancelAfter: Integer;
    CancelAsked: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure OnProgress(Sender: TObject; const AActor, AStage, AChunkType,
      AChunk: string; AInputTokens, AOutputTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer);
    procedure OnResult(Sender: TObject; AResultJson: TJSONObject; const AErrorMessage: string);
    function OnCancel(Sender: TObject): Boolean;
  end;

  TAuthWatcher = class
  public
    Events: string;
    Logs: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure OnAuth(ASuccess: Boolean);
    procedure OnLog(const AMsg: string);
  end;

  TRedirectThread = class(TThread)
  public
    Url: string;
    Status: Integer;
    Body: string;
  protected
    procedure Execute; override;
  end;

  // Status requests of a worker (RefreshStatusInBackground of the AI panel)
  TStatusThread = class(TThread)
  public
    Rounds: Integer;
  protected
    procedure Execute; override;
  end;

var
  GHub: TFakeServer;
  GHubHandler: TFakeHub;
  GRedirect: TRedirectThread;
  // The simulated browser returns a different OAuth state (forged redirect)
  GTamperState: Boolean = False;

function ProfileJson(const ATierName: string): string;
begin
  Result := '{"userId":7,"email":"ana@example.com","userName":"Ana ' + BS + 'u00d1",' +
    '"profileImageUrl":"' + GHub.BaseURL + '/avatar.png","accountType":1,"tierId":3,' +
    '"tierName":"' + ATierName + '","dailyMax":1000,"dailyConsumed":12,"freeInitial":100,' +
    '"freeRemaining":40,"serverDay":"2024-05-06T00:00:00Z","credits":5}';
end;

function TiersJson: string;
begin
  Result := '[{"id":1,"name":"Free","monthlyPrice":0,"yearlyPrice":0,"maxCreditsDay":10,' +
    '"maxFreeCredits":100,"maxConnections":1,"maxTables":10,"maxColumnsPerTable":20,"maxKpis":1},' +
    '{"id":3,"name":"Pro","monthlyPrice":19.99,"yearlyPrice":199.9,"maxCreditsDay":1000,' +
    '"maxFreeCredits":0,"maxConnections":5,"maxTables":200,"maxColumnsPerTable":100,"maxKpis":50}]';
end;

function LoginJson(const AToken: string): string;
begin
  Result := '{"token":"' + AToken + '","profile":' + ProfileJson('Pro') + ',"tiers":' + TiersJson + '}';
end;

function ExecuteResult: string;
begin
  Result := '{"success":true,"data":{"columns":[' +
    '{"name":"ID","dataType":"Int32"},{"name":"NAME","dataType":"String"},' +
    '{"name":"BALANCE","dataType":"Decimal"},{"name":"CREATED","dataType":"DateTime"},' +
    '{"name":"ACTIVE","dataType":"Boolean"},{"name":"BIGID","dataType":"Int64"},' +
    '{"name":"PHOTO","dataType":"Byte[]"},{"name":"NOTES","dataType":"String"}],' +
    '"rows":[' +
    '[1,"Jos' + BS + 'u00e9",1234.5,"2024-01-15T10:30:00",true,9007199254740993,"AAEC/w==","first"],' +
    '[2,"' + CP([$D1, $61, $6E, $64, $FA, $20, $20AC]) + '",-7.25,"2024-02-29T23:59:59.1234567Z",false,-5,[1,2,255],null],' +
    '[3,"Zo' + BS + 'u00eb",0,"2023-12-31T00:00:00+01:00",true,0,null,""]' +
    ']}}';
end;

function ModifyResultJson: string;
begin
  Result := '{"result":{"contextJson":"{' + BS + '"k' + BS + '":1}","operationsJson":"[]",' +
    '"modifiedReportDocument":"<report/>","explanation":"Hecho ' + BS + 'u00f1",' +
    '"errorMessage":"","reportFormat":"Xml","success":true},' +
    '"steps":[{"inputTokens":10,"modelName":"m1","outputTokens":20,"thinkingTokens":5}],' +
    '"creditsConsumed":42,"debugDetails":"","errorMessage":"",' +
    '"userProfile":{"userId":7,"email":"ana@example.com","tierName":"Pro"}}';
end;

function PreprocessResultJson: string;
begin
  Result := '{"result":{"dataSources":[{"dataInfoName":"CLIENTS","sqlExplanation":"All clients",' +
    '"errorMessage":""}]},"steps":[],"creditsConsumed":3,"debugDetails":"","errorMessage":""}';
end;

function ProgressEvent(const AChunkType, AChunk, AId: string): string;
begin
  Result := '{"actor":"AI","stage":"ReceivingResponse","chunkType":"' + AChunkType +
    '","chunk":"' + AChunk + '","id":"' + AId + '","inputTokens":10,"outputTokens":2,' +
    '"prefillPercentage":0.5}';
end;

function BodyJson(ARequest: TFPHTTPConnectionRequest): TJSONObject;
var
  LValue: TJSONValue;
begin
  LValue := TJSONObject.ParseJSONValue(ARequest.Content);
  if LValue is TJSONObject then
    Result := TJSONObject(LValue)
  else
  begin
    LValue.Free;
    Result := TJSONObject.Create;
  end;
end;

function JsonText(AObject: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  LValue := AObject.GetValue(AName);
  if LValue = nil then
    Result := ''
  else
    Result := LValue.Value;
end;

{ TFakeHub }

procedure TFakeHub.Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
  AResponse: TFPHTTPConnectionResponse);
var
  P, LSql: string;
  LBody: TJSONObject;
  LEvents: array of string;
  I: Integer;
begin
  P := ARequest.PathInfo;
  LBody := BodyJson(ARequest);
  try
    if P = '/api/agent/testconnection' then
    begin
      if JsonText(LBody, 'hubDatabaseId') = '77' then
        SendJson(AResponse, 200, '{"success":true,"message":"Connected"}')
      else
        SendJson(AResponse, 404, '{"success":false,"message":"Unknown database"}');
    end
    else if P = '/api/agent/execute' then
    begin
      LSql := JsonText(LBody, 'sql');
      if LSql = 'FAIL' then
        SendJson(AResponse, 200, '{"success":false,"error":"Table not found"}')
      else if LSql = 'ERROR500' then
        SendText(AResponse, 500, 'text/plain', 'Internal failure')
      else if LSql = 'UNAUTH' then
        SendText(AResponse, 401, 'text/plain', 'Token expired')
      else
        SendJson(AResponse, 200, ExecuteResult);
    end
    else if P = '/api/agent/databases' then
      SendJson(AResponse, 200, '{"databases":[' +
        '{"displayName":"Sales - Main","name":"sales","hubDatabaseId":77,"hubSchemaId":5,' +
        '"schemaTables":[{"name":"CLIENTS","columns":[{"name":"ID"},{"name":"NAME"}]},' +
        '{"name":"ORDERS","columns":[{"name":"ID"},{"name":"CLIENT"},{"name":"TOTAL"}]}]},' +
        '{"displayName":"","name":"stock","hubDatabaseId":78,"hubSchemaId":6}],' +
        '"aiEndpoints":[{"id":3,"name":"Local","agentName":"pc1","agentSecret":"s3","isOnline":true},' +
        '{"id":4,"name":"Cloud","agentName":"srv","agentSecret":"s4","isOnline":false}]}')
    else if P = '/api/agent/gettableschema' then
      SendJson(AResponse, 200, '{"columns":[{"name":"ID","type":"int"},{"name":"NAME","type":"varchar"}],' +
        '"sql":"' + JsonText(LBody, 'sql') + '"}')
    else if (P = '/NlToSql/SuggestSqlCodeStream') or (P = '/NlToSql/TranslateToSQLStream') or
      (P = '/NlToSql/ExplainSQLStream') then
    begin
      SetLength(LEvents, 4);
      LEvents[0] := ProgressEvent('Partial', 'SEL', 'r1');
      LEvents[1] := ProgressEvent('End', 'ECT 1', 'r1');
      // Same response sent whole: must be skipped (already streamed)
      LEvents[2] := ProgressEvent('Full', 'SELECT 1', 'r1');
      LEvents[3] := '{"result":{"sql":"SELECT 1","explanation":"Uno ' + BS + 'u00fa","path":"' + P + '"}}';
      SendEvents(AResponse, LEvents, 50, True, True);
    end
    else if P = '/NlToSql/AnalyzeSchemaStream' then
    begin
      // "Analyze with AI" of the local schema screens; a schema named
      // TooLarge answers the error of the plan
      SetLength(LEvents, 2);
      LEvents[0] := '{"actor":"AI","stage":"Prefill","inputTokens":120,"outputTokens":0}';
      if Pos('"schemaName":"TooLarge"', ARequest.Content) > 0 then
        LEvents[1] := '{"result":null,"errorMessage":"Too many tables for the current tier: ' +
          'Lite allows 15 tables","errorCode":"SchemaTooLargeForTier"}'
      else
        LEvents[1] := '{"result":{"explanation":"## SALES' + BS + 'n- TOTAL ok","creditsConsumed":4},' +
          '"errorMessage":"","userProfile":{"userId":7,"email":"ana@example.com"}}';
      SendEvents(AResponse, LEvents, 50, True, True);
    end
    else if P = '/ReportDesigner/ModifyReportStream' then
    begin
      if Pos('slow', ARequest.Content) > 0 then
      begin
        SetLength(LEvents, 60);
        for I := 0 to High(LEvents) do
          LEvents[I] := ProgressEvent('Partial', 'x' + IntToStr(I), 'm' + IntToStr(I));
        SendEvents(AResponse, LEvents, 100, True, True);
      end
      else
      begin
        SetLength(LEvents, 3);
        LEvents[0] := '{"actor":"Designer","stage":"Planning"}';
        LEvents[1] := ProgressEvent('Partial', '<rep', 'd1');
        LEvents[2] := ModifyResultJson;
        SendEvents(AResponse, LEvents, 50, False, True);
      end;
    end
    else if P = '/ReportDesigner/PreprocessSqlContextStream' then
    begin
      SetLength(LEvents, 2);
      LEvents[0] := '{"actor":"Sql","stage":"Explaining"}';
      LEvents[1] := PreprocessResultJson;
      SendEvents(AResponse, LEvents, 50, True, True);
    end
    else if P = '/ReportmanExpression/SuggestExpressionStream' then
    begin
      SetLength(LEvents, 2);
      LEvents[0] := ProgressEvent('Partial', 'SUM', 'e1');
      LEvents[1] := '{"result":{"expression":"SUM(CLIENTS.BALANCE)"},"errorMessage":""}';
      SendEvents(AResponse, LEvents, 50, True, True);
    end
    else if P = '/api/aireport' then
      SendJson(AResponse, 200, '{}')
    else if P = '/api/LoginResend/send' then
      SendJson(AResponse, 200, '{}')
    else if P = '/api/Login/email' then
    begin
      if JsonText(LBody, 'emailCode') = '123456' then
        SendJson(AResponse, 200, LoginJson('tok123'))
      else
        SendJson(AResponse, 401, '{}');
    end
    else if P = '/api/Login/google' then
    begin
      if (JsonText(LBody, 'code') = 'gcode 1') and (Pos('http://localhost:', JsonText(LBody, 'redirectUri')) = 1) then
        SendJson(AResponse, 200, LoginJson('tokG'))
      else
        SendJson(AResponse, 400, '{"error":"bad code"}');
    end
    else if P = '/mslogin/common/oauth2/v2.0/token' then
    begin
      if Pos('code=mscode', ARequest.Content) > 0 then
        SendJson(AResponse, 200, '{"access_token":"msaccess","token_type":"Bearer"}')
      else
        SendJson(AResponse, 400, '{"error":"invalid_grant"}');
    end
    else if P = '/api/Login/microsoft' then
    begin
      if JsonText(LBody, 'microsoftCode') = 'msaccess' then
        SendJson(AResponse, 200, LoginJson('tokM'))
      else
        SendJson(AResponse, 400, '{}');
    end
    else if P = '/api/userprofile/status' then
    begin
      Inc(StatusCalls);
      if Pos('Bearer tok', ARequest.Authorization) = 1 then
        SendJson(AResponse, 200, '{"profile":' + ProfileJson('Pro+') + ',"tiers":' + TiersJson + '}')
      else
        SendJson(AResponse, 401, '{}');
    end
    else if P = '/api/Tiers' then
      SendJson(AResponse, 200, TiersJson)
    else if P = '/api/stripe/subscribe' then
      SendText(AResponse, 200, 'text/plain', 'https://checkout.example/session/' + JsonText(LBody, 'tierId'))
    else if P = '/api/stripe/portal' then
      SendText(AResponse, 200, 'text/plain', 'https://portal.example/')
    else if P = '/avatar.png' then
      SendText(AResponse, 200, 'image/png', #$89'PNG')
    else
      SendText(AResponse, 404, 'text/plain', 'Unknown endpoint ' + P);
  finally
    LBody.Free;
  end;
end;

{ TProgressRecorder }

constructor TProgressRecorder.Create;
begin
  inherited Create;
  Progress := TStringList.Create;
  Results := TStringList.Create;
end;

destructor TProgressRecorder.Destroy;
begin
  Progress.Free;
  Results.Free;
  inherited Destroy;
end;

procedure TProgressRecorder.OnProgress(Sender: TObject; const AActor, AStage,
  AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
begin
  Progress.Add(Format('%s/%s/%s/%s/%s/%d/%d/%d', [AActor, AStage, AChunkType, AChunk,
    AProgressId, AInputTokens, AOutputTokens, APrefillPercent]));
end;

procedure TProgressRecorder.OnResult(Sender: TObject; AResultJson: TJSONObject;
  const AErrorMessage: string);
begin
  if AResultJson = nil then
    Results.Add('done ' + AErrorMessage)
  else
  begin
    Results.Add(AResultJson.ToJSON);
    AResultJson.Free;
  end;
end;

function TProgressRecorder.OnCancel(Sender: TObject): Boolean;
begin
  CancelAsked := True;
  Result := (CancelAfter > 0) and (Progress.Count >= CancelAfter);
end;

{ TAuthWatcher }

constructor TAuthWatcher.Create;
begin
  inherited Create;
  Logs := TStringList.Create;
end;

destructor TAuthWatcher.Destroy;
begin
  Logs.Free;
  inherited Destroy;
end;

procedure TAuthWatcher.OnAuth(ASuccess: Boolean);
begin
  if ASuccess then
    Events := Events + 'T'
  else
    Events := Events + 'F';
end;

procedure TAuthWatcher.OnLog(const AMsg: string);
begin
  Logs.Add(AMsg);
  if Verbose then
    Log('    auth: ' + AMsg);
end;

{ TRedirectThread: the browser that comes back to the loopback listener }

procedure TRedirectThread.Execute;
var
  LClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
begin
  Sleep(300);
  LClient := TNetHTTPClient.Create(nil);
  try
    try
      LResponse := LClient.Get(Url);
      Status := LResponse.StatusCode;
      Body := LResponse.ContentAsString;
    except
      Status := -1;
    end;
  finally
    LClient.Free;
  end;
end;

function QueryValue(const AURL, AName: string): string;
var
  LList: TStringList;
  P: Integer;
begin
  Result := '';
  P := Pos('?', AURL);
  LList := TStringList.Create;
  try
    LList.Delimiter := '&';
    LList.StrictDelimiter := True;
    LList.DelimitedText := Copy(AURL, P + 1, MaxInt);
    Result := TNetEncoding.URL.Decode(LList.Values[AName]);
  finally
    LList.Free;
  end;
end;

// Replaces the system browser: the identity provider "redirects" at once
function FakeBrowser(const AURL: string): Boolean;
var
  LRedirectUri, LCode, LState: string;
begin
  LRedirectUri := QueryValue(AURL, 'redirect_uri');
  if Pos('accounts.google.com', AURL) > 0 then
    LCode := 'gcode%201'
  else
    LCode := 'mscode';
  LState := QueryValue(AURL, 'state');
  if GTamperState then
    LState := 'X' + LState;
  FreeAndNil(GRedirect);
  GRedirect := TRedirectThread.Create(True);
  GRedirect.FreeOnTerminate := False;
  GRedirect.Url := LRedirectUri + '?code=' + LCode + '&state=' + LState;
  GRedirect.Start;
  Result := LRedirectUri <> '';
end;

{ Tests }

procedure AuthTests(AWatcher: TAuthWatcher);
var
  LAuth: TRpAuthManager;
  LIni: TStringList;
  LIniFile: string;
  LOldSep: Char;
begin
  Section('Hub authentication (rpauthmanager)');
  LAuth := TRpAuthManager.Instance;
  Check(LAuth.InstallId <> '', 'install id: ' + LAuth.InstallId);
  Check(not LAuth.IsLoggedIn, 'not logged in at start (sandbox settings)');
  Check(LAuth.RequestLoginCode('ana@example.com'), 'RequestLoginCode');
  CheckContains('"email":"ana@example.com"', GHub.LastBody, 'RequestLoginCode body');
  CheckEquals(LAuth.InstallId, GHub.LastHeader('X-Reportman-WebInstallId'), 'install id header');
  Check(not LAuth.LoginWithCode('ana@example.com', '000000'), 'LoginWithCode with a wrong code fails');
  Check(LAuth.LoginWithCode('ana@example.com', '123456'), 'LoginWithCode');
  CheckEquals('tok123', LAuth.Token, 'token');
  Check(LAuth.IsLoggedIn, 'logged in');
  CheckEquals('ana@example.com', LAuth.Profile.Email, 'profile email');
  CheckEquals('Ana ' + CP([$D1]), LAuth.Profile.UserName, 'profile user name (\u escape)');
  CheckEquals('Pro', LAuth.Profile.TierName, 'profile tier');
  CheckEquals(3, LAuth.Profile.TierId, 'profile tier id');
  CheckEquals(40, LAuth.Profile.FreeRemaining, 'profile free credits');
  Check(SameDateTime(EncodeDate(2024, 5, 6), LAuth.Profile.ServerDay), 'profile server day (ISO 8601)');
  CheckEquals(2, Length(LAuth.Tiers), 'tiers');
  CheckEquals('Pro', LAuth.Tiers[1].Name, 'tier name');
  CheckEquals(1000, LAuth.Tiers[1].MaxCreditsDay, 'tier credits');
  Check(Pos('T', AWatcher.Events) > 0, 'auth listener notified');
  LIniFile := IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA')) +
    'Reportman' + PathDelim + 'reportman_auth.ini';
  Check(FileExists(LIniFile), 'settings saved in the sandbox: ' + LIniFile);
  LIni := TStringList.Create;
  try
    LIni.LoadFromFile(LIniFile);
    CheckContains('Token=tok123', LIni.Text, 'token saved');
  finally
    LIni.Free;
  end;
  LAuth.CheckStatus;
  CheckEquals('Pro+', LAuth.Profile.TierName, 'CheckStatus updates the profile');
  CheckEquals('Bearer tok123', GHub.LastHeader('Authorization') + '', 'CheckStatus sends the token');
  CheckContains('GET /avatar.png', GHub.RequestLog, 'CheckStatus downloads the avatar');
  // JSON prices use '.' whatever the decimal separator of the locale (they
  // were read with StrToFloatDef and the locale, 0 with a ',' separator)
  LOldSep := DefaultFormatSettings.DecimalSeparator;
  DefaultFormatSettings.DecimalSeparator := ',';
  try
    Check(LAuth.RefreshTiers, 'RefreshTiers');
    Check(Abs(LAuth.Tiers[1].MonthlyPrice - 19.99) < 0.0001,
      'tier monthly price with a '','' decimal separator: ' + FloatToStr(LAuth.Tiers[1].MonthlyPrice));
    Check(Abs(LAuth.Tiers[1].YearlyPrice - 199.9) < 0.0001,
      'tier yearly price with a '','' decimal separator: ' + FloatToStr(LAuth.Tiers[1].YearlyPrice));
  finally
    DefaultFormatSettings.DecimalSeparator := LOldSep;
  end;
  CheckEquals('https://checkout.example/session/3', LAuth.GetCheckoutUrl(3, True), 'GetCheckoutUrl');
  CheckContains('"isYearly":true', GHub.LastBody, 'GetCheckoutUrl body');
  CheckEquals('https://portal.example/', LAuth.GetPortalUrl, 'GetPortalUrl');
  CheckEquals(12, LAuth.GetCreditsConsumed, 'credits consumed (paid tier)');
end;

procedure TStatusThread.Execute;
var
  I: Integer;
begin
  for I := 1 to Rounds do
    TRpAuthManager.Instance.CheckStatus;
end;

// The download page of the Reportman Agent (login dialog, new report wizard,
// connections dialog, user menu) in the language of the AI
procedure AgentDownloadUrlTest;
const
  LANGUAGES: array[0..7] of string = ('English', 'Spanish', 'Italian', 'French',
    'German', 'Portuguese', 'Chinese', 'Catalan');
  URLS: array[0..7] of string = ('https://ai.reportman.es/download',
    'https://ai.reportman.es/es/download', 'https://ai.reportman.es/it/download',
    'https://ai.reportman.es/fr/download', 'https://ai.reportman.es/de/download',
    'https://ai.reportman.es/pt/download', 'https://ai.reportman.es/zh/download',
    'https://ai.reportman.es/ca/download');
var
  LAuth: TRpAuthManager;
  LOldLanguage: string;
  I: Integer;
begin
  Section('Download page of the Reportman Agent in the language of the AI');
  LAuth := TRpAuthManager.Instance;
  LOldLanguage := LAuth.AILanguage;
  try
    for I := Low(LANGUAGES) to High(LANGUAGES) do
    begin
      LAuth.AILanguage := LANGUAGES[I];
      CheckEquals(URLS[I], LAuth.AgentDownloadUrl, LANGUAGES[I]);
    end;
    // Language codes are normalized by the setter
    LAuth.AILanguage := 'es-ES';
    CheckEquals('https://ai.reportman.es/es/download', LAuth.AgentDownloadUrl, 'es-ES');
  finally
    LAuth.AILanguage := LOldLanguage;
  end;
end;

// The workers ask for the status while the main thread reads the session,
// logs out and logs in again. The profile strings were written by both
// threads without a lock and heaptrc found a leaked one (LclAIChatTest);
// the answer to a request of a closed session brought back its profile.
procedure ConcurrentSessionTest(AWatcher: TAuthWatcher);
const
  THREADS = 4;
  ROUNDS = 25;
var
  LAuth: TRpAuthManager;
  LThreads: array[0..THREADS - 1] of TStatusThread;
  LProfile: TRpProfile;
  LTier: TRpTier;
  I, LLoops, LLogouts: Integer;
  LRunning, LConsistent: Boolean;
begin
  Section('Session shared by the main thread and the status workers');
  LAuth := TRpAuthManager.Instance;
  Check(LAuth.IsLoggedIn, 'logged in before the workers start');
  // The log listener of the test (a TStringList) is not thread safe
  LAuth.UnregisterLogListener(AWatcher.OnLog);
  try
    for I := 0 to THREADS - 1 do
    begin
      LThreads[I] := TStatusThread.Create(True);
      LThreads[I].Rounds := ROUNDS;
      LThreads[I].Start;
    end;
    LLoops := 0;
    LLogouts := 0;
    LConsistent := True;
    repeat
      LProfile := LAuth.Profile;
      if Length(LAuth.Tiers) > 0 then
      begin
        LTier := LAuth.Tiers[0];
        if LTier.Name = '' then
          LConsistent := False;
      end;
      // A profile is published whole: the email and the tier go together
      if (LProfile.Email <> '') and (LProfile.TierName = '') then
        LConsistent := False;
      Inc(LLoops);
      if LLoops mod 40 = 0 then
      begin
        LAuth.Logout;
        Inc(LLogouts);
        LAuth.LoginWithCode('ana@example.com', '123456');
      end;
      // The auth listeners run in this thread (TThread.Synchronize)
      CheckSynchronize(1);
      LRunning := False;
      for I := 0 to THREADS - 1 do
        if not LThreads[I].Finished then
          LRunning := True;
    until not LRunning;
    for I := 0 to THREADS - 1 do
    begin
      LThreads[I].WaitFor;
      LThreads[I].Free;
    end;
  finally
    LAuth.RegisterLogListener(AWatcher.OnLog);
  end;
  CheckSynchronize(0);
  Log(Format('  %d reads, %d logouts while %d workers asked %d times for the status',
    [LLoops, LLogouts, THREADS, ROUNDS]));
  Check(LConsistent, 'every profile and tier list read was whole');
  if not LAuth.IsLoggedIn then
    Check(LAuth.LoginWithCode('ana@example.com', '123456'), 'login after the workers');
  // As AuthTests left it for the next tests
  LAuth.CheckStatus;
  Check(LAuth.IsLoggedIn, 'logged in after the workers');
  CheckEquals('tok123', LAuth.Token, 'token after the workers');
  CheckEquals('ana@example.com', LAuth.Profile.Email, 'profile after the workers');
  CheckEquals('Pro+', LAuth.Profile.TierName, 'status applied after the workers');
end;

var
  GConnectionsFile: string;
  GDriversFile: string;

function CreateDatabaseInfo(out AData: TRpDataInfoList): TRpDatabaseInfoList;
var
  LDb: TRpDatabaseInfoItem;
  LItem: TRpDataInfoItem;
begin
  Result := TRpDatabaseInfoList.Create(nil);
  LDb := Result.Add('HUBTEST');
  LDb.Driver := rpdbHttp;
  LDb.LoadParams := True;
  // Connection settings from the sandbox, as a report does with its
  // DBXCONNECTIONS / DBXDRIVERS parameters. (TRpConnAdmin.LoadConfig drops a
  // connections override when it finds no drivers file, so both are given.)
  LDb.UpdateConAdmin;
  LDb.ConAdmin.DBXDriversOverride := GDriversFile;
  LDb.ConAdmin.DBXConnectionsOverride := GConnectionsFile;
  LDb.ConAdmin.LoadConfig;
  AData := TRpDataInfoList.Create(nil);
  LItem := AData.Add('CLIENTS');
  LItem.DatabaseAlias := 'HUBTEST';
  LItem.SQL := 'SELECT * FROM CLIENTS WHERE ID>=@MINID';
end;

// The design assistant of the Hub adds its Agent connections to the report by
// name only: without an entry in the connections file they had no Hub
// database and the data did not open ("500" on the Hub). The designer writes
// them with the Hub database and API key of the design context.
procedure AgentConnectionsTest;
var
  LDatabases: TRpDatabaseInfoList;
  LDesigned, LPartial, LConfigured, LNoKey: TRpDatabaseInfoItem;
  LParams: TRpParamList;
  LIni: TMemIniFile;
  LMessage: string;
  LBody: TJSONObject;

  function AddAgentDatabase(const AAlias: string): TRpDatabaseInfoItem;
  begin
    Result := LDatabases.Add(AAlias);
    Result.Driver := rpdbHttp;
    Result.LoadParams := True;
    Result.UpdateConAdmin;
    Result.ConAdmin.DBXDriversOverride := GDriversFile;
    Result.ConAdmin.DBXConnectionsOverride := GConnectionsFile;
    Result.ConAdmin.LoadConfig;
  end;

begin
  Section('Agent connections added by the design assistant (RpEnsureAgentConnections)');
  // A connection of the file without Hub database, with its own API key
  LIni := TMemIniFile.Create(GConnectionsFile);
  try
    LIni.WriteString('PARTIAL', 'DriverName', 'Reportman AI Agent');
    LIni.WriteString('PARTIAL', 'ApiKey', 'own-key');
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
  LDatabases := TRpDatabaseInfoList.Create(nil);
  LParams := TRpParamList.Create(nil);
  try
    LDesigned := AddAgentDatabase('AIDESIGNED');
    LPartial := AddAgentDatabase('PARTIAL');
    LConfigured := AddAgentDatabase('HUBTEST');
    // Missing in the connections file: no Hub database. The Hub answered with
    // an internal error; now a clear error, without calling it
    GHub.ClearLog;
    LMessage := '';
    try
      LDesigned.Connect(LParams);
    except
      on E: ERpAgentConnectionError do
        LMessage := E.Message + '|' + E.ConnectionName;
    end;
    CheckEquals(Format(SRpAgentNotConfigured, ['AIDESIGNED']) + '|AIDESIGNED', LMessage,
      'a connection missing in the connections file: clear error');
    CheckEquals('', GHub.RequestLog, 'the Hub is not called');
    CheckEquals(0, RpEnsureAgentConnections(LDatabases, 0, 'design-key'),
      'no Hub database in the design context: nothing written');
    CheckEquals(2, RpEnsureAgentConnections(LDatabases, 77, 'design-key'),
      'the missing connection and the one without Hub database written');
    LIni := TMemIniFile.Create(GConnectionsFile);
    try
      CheckEquals('Reportman AI Agent', LIni.ReadString('AIDESIGNED', 'DriverName', ''),
        'written with the Agent driver');
      CheckEquals('77', LIni.ReadString('AIDESIGNED', 'HubDatabaseId', ''),
        'Hub database of the design context');
      CheckEquals('design-key', LIni.ReadString('AIDESIGNED', 'ApiKey', ''),
        'API key of the design context');
      CheckEquals('77', LIni.ReadString('PARTIAL', 'HubDatabaseId', ''),
        'Hub database completed');
      CheckEquals('own-key', LIni.ReadString('PARTIAL', 'ApiKey', ''), 'its API key kept');
      CheckEquals('test-key', LIni.ReadString('HUBTEST', 'ApiKey', ''),
        'a configured connection is left as it is');
    finally
      LIni.Free;
    end;
    CheckEquals(0, RpEnsureAgentConnections(LDatabases, 78, 'other-key'),
      'connections with a Hub database are not changed');
    // It opens now, against the Hub database of the design context
    GHub.ClearLog;
    LDesigned.Connect(LParams);
    CheckEquals(77, LDesigned.HttpHubDatabaseId, 'HubDatabaseId read again');
    CheckEquals('design-key', GHub.LastHeader('X-Reportman-ApiKey'), 'API key header');
    LBody := TJSONObject.ParseJSONValue(GHub.LastBody) as TJSONObject;
    try
      CheckEquals('77', LBody.Values['hubDatabaseId'].Value, 'request hubDatabaseId');
    finally
      LBody.Free;
    end;
    LDesigned.DisConnect;
    LConfigured.DisConnect;
    LPartial.DisConnect;
    // No API key: the session of the user in the designer; without session
    // (printreptopdf, a server) a clear error, without calling the Hub
    LIni := TMemIniFile.Create(GConnectionsFile);
    try
      LIni.WriteString('NOKEY', 'DriverName', 'Reportman AI Agent');
      LIni.WriteString('NOKEY', 'HubDatabaseId', '77');
      LIni.UpdateFile;
    finally
      LIni.Free;
    end;
    LNoKey := AddAgentDatabase('NOKEY');
    TRpAuthManager.Instance.Logout;
    try
      GHub.ClearLog;
      LMessage := '';
      try
        LNoKey.Connect(LParams);
      except
        on E: ERpAgentConnectionError do
          LMessage := E.Message;
      end;
      CheckEquals(Format(SRpAgentNoCredentials, ['NOKEY']), LMessage,
        'no API key and no session: clear error');
      CheckEquals('', GHub.RequestLog, 'the Hub is not called');
    finally
      Check(TRpAuthManager.Instance.LoginWithCode('ana@example.com', '123456'),
        'logged in again');
    end;
    GHub.ClearLog;
    LNoKey.Connect(LParams);
    CheckEquals('', GHub.LastHeader('X-Reportman-ApiKey'), 'with the session: no API key sent');
    CheckEquals('Bearer tok123', GHub.LastHeader('Authorization'), 'the session token is sent');
    LNoKey.DisConnect;
  finally
    LParams.Free;
    LDatabases.Free;
    // The other tests see the connections file as it was
    LIni := TMemIniFile.Create(GConnectionsFile);
    try
      LIni.EraseSection('AIDESIGNED');
      LIni.EraseSection('PARTIAL');
      LIni.EraseSection('NOKEY');
      LIni.UpdateFile;
    finally
      LIni.Free;
    end;
  end;
end;

procedure DataTests;
var
  LDatabases: TRpDatabaseInfoList;
  LData: TRpDataInfoList;
  LItem: TRpDataInfoItem;
  LParams: TRpParamList;
  LParam: TRpParam;
  LDataset: TDataset;
  LBody: TJSONObject;
  LRaised: Boolean;
  LMessage: string;
begin
  Section('rpdbHttp driver through TRpDatabaseInfoItem / TRpDataInfoItem');
  LDatabases := CreateDatabaseInfo(LData);
  LParams := TRpParamList.Create(nil);
  try
    LParam := LParams.Add('MINID');
    LParam.ParamType := rpParamInteger;
    LParam.Value := 5;
    LParam.Datasets.Add('CLIENTS');
    LItem := LData.Items[0];
    GHub.ClearLog;
    LItem.Connect(LDatabases, LParams);
    CheckEquals('POST /api/agent/testconnection;POST /api/agent/execute', GHub.RequestLog,
      'connect tests the connection, then runs the query');
    CheckEquals(77, LDatabases.Items[0].HttpHubDatabaseId, 'HubDatabaseId from the connection settings');
    CheckEquals('test-key', GHub.LastHeader('X-Reportman-ApiKey'), 'API key header');
    CheckEquals(TRpAuthManager.Instance.InstallId, GHub.LastHeader('X-Reportman-WebInstallId'), 'install id header');
    CheckEquals('application/json', GHub.LastHeader('Content-Type'), 'content type');
    LBody := TJSONObject.ParseJSONValue(GHub.LastBody) as TJSONObject;
    try
      CheckEquals('77', LBody.Values['hubDatabaseId'].Value, 'request hubDatabaseId');
      CheckEquals('SELECT * FROM CLIENTS WHERE ID>=@MINID', LBody.Values['sql'].Value, 'request sql');
      CheckEquals('[{"name":"@MINID","value":5,"dbType":11}]', LBody.Values['parameters'].ToJSON,
        'request parameters');
    finally
      LBody.Free;
    end;
    LDataset := LItem.Dataset;
    Check(LDataset <> nil, 'dataset');
    Check(LDataset.Active, 'dataset open');
    CheckEquals(3, LDataset.RecordCount, 'rows');
    CheckEquals(8, LDataset.FieldCount, 'fields');
    Check(LDataset.FieldByName('ID').DataType = ftInteger, 'Int32 -> ftInteger');
    Check(LDataset.FieldByName('NAME').DataType = ftString, 'String -> ftString');
    Check(LDataset.FieldByName('BALANCE').DataType = ftFloat, 'Decimal -> ftFloat');
    Check(LDataset.FieldByName('CREATED').DataType = ftDateTime, 'DateTime -> ftDateTime');
    Check(LDataset.FieldByName('ACTIVE').DataType = ftBoolean, 'Boolean -> ftBoolean');
    Check(LDataset.FieldByName('BIGID').DataType = ftLargeint, 'Int64 -> ftLargeint');
    Check(LDataset.FieldByName('PHOTO').DataType = ftBlob, 'Byte[] -> ftBlob');
    LDataset.First;
    CheckEquals(1, LDataset.FieldByName('ID').AsInteger, 'row 1 ID');
    CheckEquals('Jos' + CP([$E9]), LDataset.FieldByName('NAME').AsString, 'row 1 NAME (\u escape)');
    Check(Abs(LDataset.FieldByName('BALANCE').AsFloat - 1234.5) < 1E-9, 'row 1 BALANCE');
    Check(SameDateTime(EncodeDateTime(2024, 1, 15, 10, 30, 0, 0), LDataset.FieldByName('CREATED').AsDateTime),
      'row 1 CREATED');
    Check(LDataset.FieldByName('ACTIVE').AsBoolean, 'row 1 ACTIVE');
    CheckEquals(9007199254740993, LDataset.FieldByName('BIGID').AsLargeInt, 'row 1 BIGID (beyond 2^53)');
    CheckEquals(#0#1#2#$FF, LDataset.FieldByName('PHOTO').AsString, 'row 1 PHOTO (Base64, bytes >= $80)');
    CheckEquals('first', LDataset.FieldByName('NOTES').AsString, 'row 1 NOTES');
    LDataset.Next;
    CheckEquals(CP([$D1, $61, $6E, $64, $FA, $20, $20AC]), LDataset.FieldByName('NAME').AsString,
      'row 2 NAME (raw UTF-8)');
    Check(Abs(LDataset.FieldByName('BALANCE').AsFloat + 7.25) < 1E-9, 'row 2 BALANCE');
    Check(SameDateTime(EncodeDateTime(2024, 2, 29, 23, 59, 59, 123), LDataset.FieldByName('CREATED').AsDateTime),
      'row 2 CREATED (7 fraction digits, Z)');
    Check(not LDataset.FieldByName('ACTIVE').AsBoolean, 'row 2 ACTIVE');
    CheckEquals(-5, LDataset.FieldByName('BIGID').AsLargeInt, 'row 2 BIGID');
    CheckEquals(#1#2#$FF, LDataset.FieldByName('PHOTO').AsString, 'row 2 PHOTO (byte array)');
    Check(LDataset.FieldByName('NOTES').IsNull, 'row 2 NOTES null');
    LDataset.Next;
    Check(SameDateTime(EncodeDateTime(2023, 12, 30, 23, 0, 0, 0), LDataset.FieldByName('CREATED').AsDateTime),
      'row 3 CREATED (+01:00 to UTC)');
    Check(LDataset.FieldByName('PHOTO').IsNull, 'row 3 PHOTO null');
    CheckEquals('', LDataset.FieldByName('NOTES').AsString, 'row 3 NOTES empty');
    LItem.DisConnect;

    LItem.SQL := 'FAIL';
    LRaised := False;
    try
      LItem.Connect(LDatabases, LParams);
    except
      on E: Exception do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    Check(LRaised, 'an Agent error raises');
    CheckContains('Table not found', LMessage, 'Agent error message');
    LItem.DisConnect;

    LItem.SQL := 'ERROR500';
    LRaised := False;
    try
      LItem.Connect(LDatabases, LParams);
    except
      on E: Exception do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    Check(LRaised, 'HTTP 500 raises');
    CheckContains('HTTP Error 500', LMessage, 'HTTP 500 message');
    CheckContains('Internal failure', LMessage, 'HTTP 500 body in the message');
    LItem.DisConnect;
  finally
    LParams.Free;
    LData.Free;
    LDatabases.Free;
  end;
end;

// "Analyze with AI" of the local schema screens: the request, the result,
// the error of the plan, and the same in a thread of its own
// (RpStartSchemaAnalysis)
procedure AnalyzeSchemaTests(AHttp: TRpDatabaseHttp; ARecorder: TProgressRecorder);
var
  LConfig: TRpApiDatabaseConfig;
  LJson: TJSONObject;
  LTask: IRpSchemaAnalysis;
  LState: TRpSchemaAnalysisState;
  LStart: QWord;
begin
  LConfig := TRpApiDatabaseConfig.Create;
  try
    LConfig.Name := 'FBEXAMPLE';
    LConfig.Dialect := 'Firebird5';
    LConfig.SchemaTablesJson := '[{"name":"SALES","columns":[{"name":"SALEID"}]}]';
    LConfig.SchemaName := 'Ventas';
    ARecorder.Progress.Clear;
    AHttp.AITier := 'Precision';
    try
      LJson := AHttp.AnalyzeSchema(LConfig, 'Reasoning', nil, ARecorder.OnProgress,
        ARecorder.OnCancel);
    finally
      AHttp.AITier := 'Standard';
    end;
    try
      Check(LJson <> nil, 'AnalyzeSchema result');
      CheckEquals('## SALES' + #10 + '- TOTAL ok', LJson.FindValue('result.explanation').Value,
        'AnalyzeSchema explanation (Markdown)');
      CheckEquals('ana@example.com', LJson.FindValue('userProfile.email').Value,
        'AnalyzeSchema profile (the credits)');
    finally
      LJson.Free;
    end;
    CheckEquals(1, ARecorder.Progress.Count, 'AnalyzeSchema progress');
    CheckContains('"aiTier":"Precision"', GHub.LastBody, 'AnalyzeSchema tier');
    CheckContains('"mode":"Reasoning"', GHub.LastBody, 'AnalyzeSchema mode');
    CheckContains('"languageCodeIso":"', GHub.LastBody, 'AnalyzeSchema language');
    CheckContains('"schemaName":"Ventas"', GHub.LastBody, 'AnalyzeSchema inline subschema');
    CheckContains('"schemaTables":[{"name":"SALES"', GHub.LastBody, 'AnalyzeSchema inline tables');
    CheckContains('"agentSecret":"s3"', GHub.LastBody, 'AnalyzeSchema agent');
    CheckEquals('text/event-stream', GHub.LastHeader('Accept'), 'AnalyzeSchema streams');

    // In a thread, as the screens run it, read with a timer
    LTask := RpStartSchemaAnalysis(LConfig, 'Standard', 'Fast', '', 0);
    LStart := GetTickCount64;
    repeat
      Sleep(20);
      LState := LTask.GetState;
    until LState.Finished or (ElapsedMs(LStart) > 10000);
    Check(LState.Finished and not LState.Cancelled, 'RpStartSchemaAnalysis finishes');
    CheckEquals('', LState.ErrorMessage, 'RpStartSchemaAnalysis without error');
    CheckEquals(120, LState.InputTokens, 'RpStartSchemaAnalysis tokens');
    CheckContains('TOTAL ok', LState.ResultJson, 'RpStartSchemaAnalysis final frame');
    CheckContains('"aiTier":"Standard"', GHub.LastBody, 'RpStartSchemaAnalysis tier');
    LTask := nil;

    // The error of the plan comes in the final frame, with its code
    LConfig.SchemaName := 'TooLarge';
    LTask := RpStartSchemaAnalysis(LConfig, 'Standard', 'Fast', '', 0);
    LStart := GetTickCount64;
    repeat
      Sleep(20);
      LState := LTask.GetState;
    until LState.Finished or (ElapsedMs(LStart) > 10000);
    CheckContains('"errorCode":"SchemaTooLargeForTier"', LState.ResultJson,
      'RpStartSchemaAnalysis: the error of the plan with its code');
    LTask := nil;

    // Stop: the task says so and the thread ends on its own
    LTask := RpStartSchemaAnalysis(LConfig, 'Standard', 'Fast', '', 0);
    LTask.Cancel;
    LStart := GetTickCount64;
    repeat
      Sleep(20);
      LState := LTask.GetState;
    until LState.Finished or (ElapsedMs(LStart) > 10000);
    Check(LState.Finished and LState.Cancelled, 'RpStartSchemaAnalysis stopped');
    LTask := nil;
  finally
    LConfig.Free;
  end;
end;

procedure AITests;
var
  LHttp: TRpDatabaseHttp;
  LRecorder: TProgressRecorder;
  LJson: TJSONObject;
  LModify: TRpApiModifyReportRequest;
  LModifyResult: TRpApiModifyReportResult;
  LPre: TRpApiPreprocessSqlContextRequest;
  LPreResult: TRpApiPreprocessSqlContextResult;
  LSource: TRpApiPreprocessSqlContextDataSource;
  LReport: TRpAIReport;
  LList, LSizes: TStringList;
  LStart: QWord;
begin
  Section('AI client methods of TRpDatabaseHttp');
  LHttp := TRpDatabaseHttp.Create;
  LRecorder := TProgressRecorder.Create;
  LList := TStringList.Create;
  try
    LHttp.ApiKey := 'test-key';
    LHttp.HubDatabaseId := 77;
    LHttp.HubSchemaId := 5;
    LHttp.AgentAiId := 3;
    LHttp.AgentSecret := 's3';

    LJson := LHttp.SuggestSql('SELECT', 6, 'Fast', nil, LRecorder.OnProgress, LRecorder.OnCancel);
    try
      Check(LJson <> nil, 'SuggestSql result');
      CheckEquals('SELECT 1', LJson.FindValue('result.sql').Value, 'SuggestSql SQL');
      CheckEquals('Uno ' + CP([$FA]), LJson.FindValue('result.explanation').Value, 'SuggestSql explanation');
    finally
      LJson.Free;
    end;
    CheckEquals(2, LRecorder.Progress.Count, 'streamed progress (the repeated "Full" chunk is skipped)');
    CheckEquals('AI/ReceivingResponse/Partial/SEL/r1/10/2/50', LRecorder.Progress[0], 'progress event fields');
    Check(LRecorder.CancelAsked, 'the cancel callback is polled while streaming');
    CheckEquals('text/event-stream', GHub.LastHeader('Accept'), 'streaming Accept header');
    LJson := TJSONObject.ParseJSONValue(GHub.LastBody) as TJSONObject;
    try
      CheckEquals('6', LJson.Values['cursorPosition'].Value, 'SuggestSql cursor');
      CheckEquals('{"hubDatabaseId":77,"hubSchemaId":5}', LJson.Values['config'].ToJSON, 'SuggestSql config');
      CheckEquals('s3', LJson.Values['agentSecret'].Value, 'SuggestSql agent');
    finally
      LJson.Free;
    end;

    LRecorder.Progress.Clear;
    LJson := LHttp.TranslateToSql('clients with debt', '', 'Reasoning', 'es');
    try
      CheckEquals('/NlToSql/TranslateToSQLStream', LJson.FindValue('result.path').Value, 'TranslateToSql');
    finally
      LJson.Free;
    end;
    CheckContains('"transcribeLanguage":"Spanish"', GHub.LastBody, 'TranslateToSql language');
    CheckContains('"userQuery":["clients with debt"]', GHub.LastBody, 'TranslateToSql prompt');
    // A direct connection: its schema inline (a local subschema) instead of
    // the Hub ids
    LHttp.InlineConfigJson := '{"name":"FBEXAMPLE","schemaTables":[{"name":"SALES",' +
      '"columns":[]}],"schemaName":"Ventas","hubDatabaseId":0,"hubSchemaId":0}';
    try
      LJson := LHttp.TranslateToSql('sales', '', 'Fast', 'es');
      LJson.Free;
    finally
      LHttp.InlineConfigJson := '';
    end;
    CheckContains('"schemaName":"Ventas"', GHub.LastBody, 'TranslateToSql inline subschema');
    CheckContains('"schemaTables":[{"name":"SALES"', GHub.LastBody, 'TranslateToSql inline tables');
    Check(Pos('"hubDatabaseId":77', GHub.LastBody) = 0,
      'TranslateToSql inline: not the Hub database');

    LJson := LHttp.ExplainSql('SELECT 1', 'Fast', 'ca');
    try
      CheckEquals('/NlToSql/ExplainSQLStream', LJson.FindValue('result.path').Value, 'ExplainSql');
    finally
      LJson.Free;
    end;
    CheckContains('"userLanguage":"Catalan"', GHub.LastBody, 'ExplainSql language');

    AnalyzeSchemaTests(LHttp, LRecorder);

    LJson := LHttp.GetTableSchema('SELECT * FROM CLIENTS');
    try
      CheckEquals(2, (LJson.Values['columns'] as TJSONArray).Count, 'GetTableSchema');
    finally
      LJson.Free;
    end;

    LRecorder.Progress.Clear;
    LModify := TRpApiModifyReportRequest.Create;
    try
      LModify.ReportDocument := '<report/>';
      LModify.UserInstructions.Add('Add a title');
      LModify.HubDatabaseId := 77;
      LModifyResult := LHttp.ModifyReport(LModify, nil, LRecorder.OnProgress, LRecorder.OnCancel);
      try
        Check(LModifyResult <> nil, 'ModifyReport result');
        CheckEquals('<report/>', LModifyResult.ResultData.ModifiedReportDocument, 'ModifyReport document');
        CheckEquals('Hecho ' + CP([$F1]), LModifyResult.ResultData.Explanation, 'ModifyReport explanation');
        CheckEquals(42, LModifyResult.CreditsConsumed, 'ModifyReport credits');
        CheckEquals(1, LModifyResult.Steps.Count, 'ModifyReport steps');
        CheckContains('"email":"ana@example.com"', LModifyResult.UserProfileJson, 'ModifyReport profile');
      finally
        LModifyResult.Free;
      end;
      CheckEquals(2, LRecorder.Progress.Count, 'ModifyReport progress (closed-delimited stream)');
      CheckContains('"userInstructions":["Add a title"]', GHub.LastBody, 'ModifyReport request');

      // Cancel in the middle of a long stream
      LRecorder.Progress.Clear;
      LRecorder.CancelAfter := 2;
      LModify.UserInstructions.Text := 'slow';
      LStart := GetTickCount64;
      LModifyResult := LHttp.ModifyReport(LModify, nil, LRecorder.OnProgress, LRecorder.OnCancel);
      Check(LModifyResult = nil, 'cancelled ModifyReport returns nil');
      Check(ElapsedMs(LStart) < 2000, Format('cancel is prompt (%d ms, the stream lasts 6 s)', [ElapsedMs(LStart)]));
      Check(LRecorder.Progress.Count < 10, 'no progress after the cancel');
      LRecorder.CancelAfter := 0;
    finally
      LModify.Free;
    end;

    LPre := TRpApiPreprocessSqlContextRequest.Create;
    try
      LSource := TRpApiPreprocessSqlContextDataSource.Create;
      LSource.DataInfoName := 'CLIENTS';
      LSource.Sql := 'SELECT * FROM CLIENTS';
      LPre.DataSources.Add(LSource);
      LPreResult := LHttp.PreprocessSqlContext(LPre, nil, LRecorder.OnProgress, LRecorder.OnCancel);
      try
        Check(LPreResult <> nil, 'PreprocessSqlContext result (the request after a cancel works)');
        CheckEquals(1, LPreResult.DataSources.Count, 'PreprocessSqlContext data sources');
        CheckEquals('All clients', TRpApiPreprocessSqlContextDataSourceResult(LPreResult.DataSources[0]).SqlExplanation,
          'PreprocessSqlContext explanation');
      finally
        LPreResult.Free;
      end;
    finally
      LPre.Free;
    end;

    LRecorder.Progress.Clear;
    LRecorder.Results.Clear;
    Check(LHttp.SuggestExpressionStream('sum of balance', 'SUM(', 4, 'Fast', False, '{}', nil,
      LRecorder.OnProgress, LRecorder.OnResult, LRecorder.OnCancel), 'SuggestExpressionStream');
    CheckEquals(1, LRecorder.Progress.Count, 'SuggestExpressionStream progress');
    CheckEquals(2, LRecorder.Results.Count, 'SuggestExpressionStream result + done');
    CheckContains('SUM(CLIENTS.BALANCE)', LRecorder.Results[0], 'SuggestExpressionStream expression');
    CheckEquals('done ', LRecorder.Results[1], 'SuggestExpressionStream [DONE]');

    LReport := TRpAIReport.Create;
    try
      LReport.ErrorType := raetInaccurateContent;
      LReport.UserComments := 'wrong';
      LReport.AIContent := 'SELECT 2';
      Check(LHttp.SubmitAIReport(LReport), 'SubmitAIReport');
      CheckEquals('{"errorType":"InaccurateContent","userComments":"wrong","aiContent":"SELECT 2"}',
        GHub.LastBody, 'SubmitAIReport body');
    finally
      LReport.Free;
    end;

    Check(LHttp.GetUserSchemas(LList), 'GetUserSchemas');
    CheckEquals('Sales / Main=77|5', LList[0], 'GetUserSchemas display name');
    CheckEquals('stock=78|6', LList[1], 'GetUserSchemas name when there is no display name');
    CheckContains('GET /api/agent/databases', GHub.RequestLog, 'GetUserSchemas is a GET');
    // The size of each schema for the limits of the plan: its tables and the
    // columns of the widest one (none without schemaTables)
    LSizes := TStringList.Create;
    try
      Check(LHttp.GetUserSchemas(LList, LSizes), 'GetUserSchemas with sizes');
      CheckEquals('Sales / Main=77|5', LList[0], 'GetUserSchemas with sizes: the same list');
      CheckEquals(1, LSizes.Count, 'GetUserSchemas sizes: only with schemaTables');
      CheckEquals('2,3', LSizes.Values['5'], 'GetUserSchemas sizes: tables and widest');
    finally
      LSizes.Free;
    end;
    // GetSchemas sent a nil request body (access violation) and read a "data"
    // list that the Hub does not return
    Check(LHttp.GetSchemas(LList), 'GetSchemas');
    CheckEquals(2, LList.Count, 'GetSchemas count');
    CheckEquals('Sales - Main', LList[0], 'GetSchemas display name');
    CheckEquals('stock', LList[1], 'GetSchemas name when there is no display name');
    Check(LHttp.GetUserAgents(LList), 'GetUserAgents');
    CheckEquals('Local (pc1)=3|s3|1', LList[0], 'GetUserAgents online');
    CheckEquals('Cloud (srv)=4|s4|0', LList[1], 'GetUserAgents offline');
    Check(TRpDatabaseHttp.GetHubDatabases('test-key', LList), 'GetHubDatabases');
    CheckEquals('Sales - Main=77', LList[0], 'GetHubDatabases');
  finally
    LList.Free;
    LRecorder.Free;
    LHttp.Free;
  end;
end;

procedure UnauthorizedTest;
var
  LDatabases: TRpDatabaseInfoList;
  LData: TRpDataInfoList;
  LParams: TRpParamList;
  LRaised: Boolean;
begin
  Section('HTTP 401 logs out');
  Check(TRpAuthManager.Instance.IsLoggedIn, 'logged in before the 401');
  LDatabases := CreateDatabaseInfo(LData);
  LParams := TRpParamList.Create(nil);
  try
    LData.Items[0].SQL := 'UNAUTH';
    LRaised := False;
    try
      LData.Items[0].Connect(LDatabases, LParams);
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, '401 raises');
    Check(not TRpAuthManager.Instance.IsLoggedIn, '401 logs out');
    CheckEquals('', TRpAuthManager.Instance.Token, 'token cleared');
  finally
    LParams.Free;
    LData.Free;
    LDatabases.Free;
  end;
end;

// RpLoopbackPortAvailable: false while another listener holds the port (the
// OAuth port is chosen with it, skipping ports reserved by Hyper-V/WSL)
procedure PortCheckTest;
var
  LHolder: TInetServer;
  LPort: Word;
begin
  LPort := 0;
  LHolder := nil;
  try
    for LPort := 55301 to 55399 do
      if RpLoopbackPortAvailable(LPort) then
        Break;
    Check(RpLoopbackPortAvailable(LPort), 'a free loopback port is available: ' + IntToStr(LPort));
    LHolder := TInetServer.Create('127.0.0.1', LPort);
    LHolder.ReuseAddress := False;
    LHolder.Bind;
    LHolder.Listen;
    Check(not RpLoopbackPortAvailable(LPort), 'a port held by another listener is not available');
  finally
    LHolder.Free;
  end;
  Check(RpLoopbackPortAvailable(LPort), 'the port is available again after closing it');
end;

procedure OAuthTests;
var
  LAuth: TRpAuthManager;
begin
  Section('OAuth login with the loopback redirect (simulated browser)');
  LAuth := TRpAuthManager.Instance;
  RpOpenUrlHook := FakeBrowser;
  try
    Check(LAuth.LoginGoogle, 'LoginGoogle');
    CheckEquals('tokG', LAuth.Token, 'Google token');
    CheckEquals(200, GRedirect.Status, 'the browser got the "login successful" page');
    CheckContains('POST /api/Login/google', GHub.RequestLog, 'code exchanged with the Hub');
    LAuth.Logout;
    Check(LAuth.LoginMicrosoft, 'LoginMicrosoft (token endpoint + Hub)');
    CheckEquals('tokM', LAuth.Token, 'Microsoft token');
    CheckContains('POST /mslogin/common/oauth2/v2.0/token', GHub.RequestLog, 'Microsoft token request');
    LAuth.Logout;
    Check(not LAuth.IsLoggedIn, 'logged out');
    // A redirect whose state is not the one sent is rejected (the state was
    // never checked)
    GTamperState := True;
    try
      Check(not LAuth.LoginGoogle, 'LoginGoogle rejected when the state does not match');
      Check(not LAuth.IsLoggedIn, 'not logged in after the forged redirect');
      GRedirect.WaitFor;
      CheckContains('Login failed', GRedirect.Body, 'the browser gets the "login failed" page');
    finally
      GTamperState := False;
    end;
    // The loopback port is checked before the browser is opened
    PortCheckTest;
  finally
    RpOpenUrlHook := nil;
    if GRedirect <> nil then
    begin
      GRedirect.WaitFor;
      FreeAndNil(GRedirect);
    end;
  end;
end;

procedure RunHubTests;
var
  LWatcher: TAuthWatcher;
  LIni: TStringList;
  LIniFile, LSandbox: string;
begin
  LSandbox := GetEnvironmentVariable('LOCALAPPDATA');
  if Pos('rphubtest', LSandbox) = 0 then
    Fail('the Hub tests must run in the sandbox (LOCALAPPDATA=' + LSandbox + ')');
  // Connection settings of the rpdbHttp database
  LIniFile := IncludeTrailingPathDelimiter(LSandbox) + 'dbxconnections.ini';
  LIni := TStringList.Create;
  try
    LIni.Add('[HUBTEST]');
    LIni.Add('ApiKey=test-key');
    LIni.Add('HubDatabaseId=77');
    LIni.SaveToFile(LIniFile);
    LIni.Clear;
    LIni.Add('[Installed Drivers]');
    GDriversFile := IncludeTrailingPathDelimiter(LSandbox) + 'dbxdrivers.ini';
    LIni.SaveToFile(GDriversFile);
  finally
    LIni.Free;
  end;
  GConnectionsFile := LIniFile;
  GHubHandler := TFakeHub.Create;
  GHub := TFakeServer.Create(GHubHandler.Handle);
  LWatcher := TAuthWatcher.Create;
  try
    GHub.Start;
    Log('  fake Hub on ' + GHub.BaseURL + ' for ' + HUB_API_URL);
    RpHttpSetUrlRewrite(HUB_API_URL, GHub.BaseURL);
    RpHttpSetUrlRewrite('https://login.microsoftonline.com', GHub.BaseURL + '/mslogin');
    TRpAuthManager.Instance.RegisterAuthListener(LWatcher.OnAuth);
    TRpAuthManager.Instance.RegisterLogListener(LWatcher.OnLog);
    try
      AuthTests(LWatcher);
      AgentDownloadUrlTest;
      ConcurrentSessionTest(LWatcher);
      DataTests;
      AgentConnectionsTest;
      AITests;
      UnauthorizedTest;
      OAuthTests;
    finally
      TRpAuthManager.Instance.UnregisterAuthListener(LWatcher.OnAuth);
      TRpAuthManager.Instance.UnregisterLogListener(LWatcher.OnLog);
      RpHttpSetUrlRewrite('', '');
    end;
  finally
    LWatcher.Free;
    GHub.Free;
    GHubHandler.Free;
  end;
end;

end.
