{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpauthmanager                                   }
{       Authentication and Tiers Manager for Hub        }
{                                                       }
{       Copyright (c) 1994-2025 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpauthmanager;

interface

{$I rpconf.inc}

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows, Winapi.Messages,
{$ENDIF}
  SysUtils, Classes, System.JSON, System.NetEncoding, System.DateUtils,
{$IFDEF FIREDAC}
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient,
{$ELSE}
  IdHTTP,
{$ENDIF}
{$IFDEF MSWINDOWS}
  ShellAPI,
{$ENDIF}
  rptypes, System.Generics.Collections;

type
  { TRpTier }
  TRpTier = record
    Id: Int64;
    Name: string;
    MonthlyPrice: Double;
    YearlyPrice: Double;
    MaxCreditsDay: Int64;
    MaxFreeCredits: Int64;
    MaxConnections: Integer;
    MaxTables: Integer;
    MaxColumnsPerTable: Integer;
    MaxKpis: Integer;
  end;

  TRpProfile = record
    UserId: Int64;
    InstallId: string;
    UserName: string;
    Email: string;
    AvatarUrl: string;
    AccountType: Integer;
    TierId: Int64;
    TierName: string;
    DailyMax: Int64;
    DailyConsumed: Int64;
    FreeInitial: Int64;
    FreeRemaining: Int64;
    ServerDay: TDateTime;
    Credits: Int64; // Deprecated but kept for compatibility
  end;

  { TRpAuthEvent }
  TRpAuthEvent = procedure(ASuccess: Boolean) of object;
  { TRpAuthLog }
  TRpAuthLog = procedure(const AMsg: string) of object;

  TRpQueuedAuthListenerPayload = class(TObject)
  public
    Listener: TRpAuthEvent;
    Success: Boolean;
  end;

  { TRpAuthManager }
  TRpAuthManager = class
  private
    FToken: string;
    FInstallId: string;
    FProfile: TRpProfile;
    FTiers: TArray<TRpTier>;
    FIsLoggedIn: Boolean;
    FAIEnabled: Boolean;
    FAILanguage: string;
    FOnLog: TRpAuthLog;
    FLogListeners: TList<TRpAuthLog>;
    FAuthListeners: TList<TRpAuthEvent>;
  {$IFDEF MSWINDOWS}
    FDispatchHandle: HWND;
  {$ENDIF}
    FOAuthCode: string;
    FOAuthError: string;
    FOAuthGotCallback: Boolean;
    procedure DispatchAuthListener(AListener: TRpAuthEvent; ASuccess: Boolean);
  {$IFDEF MSWINDOWS}
    procedure DispatchWndProc(var Msg: TMessage);
  {$ENDIF}

    class var FInstance: TRpAuthManager;
    constructor Create;
    procedure ParseTiers(ATiersArray: TJSONArray);
    procedure ParseProfile(AProfileObj: TJSONObject);
    procedure NotifyListeners(ASuccess: Boolean);
    function GenerateInstallId: string;
    procedure SetIsLoggedIn(Value: Boolean);
    procedure SetAIEnabled(Value: Boolean);
    procedure SetAILanguage(const Value: string);
    function WaitForOAuthCallback(APort: Integer): Boolean;
    function ExchangeGoogleCode(const ACode, ARedirectUri: string): Boolean;
    function ExchangeMicrosoftCode(const ACode, ARedirectUri: string): Boolean;
{$IFDEF FIREDAC}
    procedure AcceptAnyServerCertificate(const Sender: TObject;
      const ARequest: TURLRequest; const Certificate: TCertificate;
      var Accepted: Boolean);
{$ENDIF}
    
    // Persistence
    function GetConfigFileName: string;
    procedure SaveConfig;
    procedure LoadConfig;
    procedure ClearConfig;
    class function ResolveDefaultAILanguage: string; static;
    class function NormalizeAILanguageValue(const AValue: string): string; static;

  public
    class function Instance: TRpAuthManager;
    destructor Destroy; override;
    class function GetSupportedAILanguages: TArray<string>; static;
    class function GetAILanguageDisplayName(const AValue: string): string; static;

{$IFDEF FIREDAC}
    procedure ConfigureDebugHttpClient(AHttpClient: TNetHTTPClient);
{$ENDIF}

    function RequestLoginCode(const AEmail: string): Boolean;
    function LoginWithCode(const AEmail, ACode: string): Boolean;
    procedure Logout;
    function RefreshTiers: Boolean;
    function GetCheckoutUrl(ATierId: Int64; AIsYearly: Boolean): string;
    function GetPortalUrl: string;

    procedure OpenUrl(const AUrl: string);

    // AI/OAuth additions
    function LoginGoogle: Boolean;
    function LoginMicrosoft: Boolean;
    procedure CheckStatus;
    procedure UpdateProfileFromJson(AProfileObj: TJSONObject);
    function UsesFreeCredits: Boolean;
    function GetCreditsRatio: Double;
    function GetCreditsConsumed: Int64;
    function GetCreditsMax: Int64;

    procedure RegisterAuthListener(AListener: TRpAuthEvent);
    procedure UnregisterAuthListener(AListener: TRpAuthEvent);
    procedure RegisterLogListener(AListener: TRpAuthLog);
    procedure UnregisterLogListener(AListener: TRpAuthLog);
    procedure Log(const AMsg: string);

    property Token: string read FToken;
    property InstallId: string read FInstallId write FInstallId;
    property Profile: TRpProfile read FProfile;
    property Tiers: TArray<TRpTier> read FTiers;
    property IsLoggedIn: Boolean read FIsLoggedIn;
    property AIEnabled: Boolean read FAIEnabled write SetAIEnabled;
    property AILanguage: string read FAILanguage write SetAILanguage;
    property OnLog: TRpAuthLog read FOnLog write FOnLog;
  end;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.WinSock,
{$ENDIF}
  IniFiles, IOUtils;

{$IFDEF MSWINDOWS}
const
  WM_RP_AUTH_DISPATCH = WM_USER + 210;
{$ENDIF}

{ TRpAuthManager }

constructor TRpAuthManager.Create;
begin
  inherited Create;
  FIsLoggedIn := False;
  FAIEnabled := True;
  FAILanguage := ResolveDefaultAILanguage;
  FLogListeners := TList<TRpAuthLog>.Create;
  FAuthListeners := TList<TRpAuthEvent>.Create;
{$IFDEF MSWINDOWS}
  FDispatchHandle := AllocateHWnd(DispatchWndProc);
{$ENDIF}
  FInstallId := GenerateInstallId;
  LoadConfig;
end;

function TRpAuthManager.GenerateInstallId: string;
{$IFDEF MSWINDOWS}
var
  VolumeSerialNumber: DWORD;
  MaximumComponentLength, FileSystemFlags: DWORD;
  ComputerName: array[0..MAX_COMPUTERNAME_LENGTH] of Char;
  Size: DWORD;
begin
  Size := MAX_COMPUTERNAME_LENGTH + 1;
  if not GetComputerName(ComputerName, Size) then
    ComputerName := 'UNKNOWN';

  GetVolumeInformation('C:\', nil, 0, @VolumeSerialNumber,
    MaximumComponentLength, FileSystemFlags, nil, 0);

  Result := 'repman-' + IntToHex(VolumeSerialNumber, 8) + '-' +
    LowerCase(string(ComputerName));
end;
{$ELSE}
{$IFDEF LINUX}
var
  LMachineId: string;
  LLines: TStringList;
begin
  LMachineId := '';
  LLines := TStringList.Create;
  try
    if FileExists('/etc/machine-id') then
      LLines.LoadFromFile('/etc/machine-id')
    else if FileExists('/var/lib/dbus/machine-id') then
      LLines.LoadFromFile('/var/lib/dbus/machine-id');
    if LLines.Count>0 then
      LMachineId := Trim(LLines.Strings[0]);
  finally
    LLines.Free;
  end;
  if LMachineId='' then
    LMachineId := Trim(GetEnvironmentVariable('HOSTNAME'));
  if LMachineId='' then
    LMachineId := Trim(GetEnvironmentVariable('USER'));
  if LMachineId='' then
    LMachineId := 'unknown';
  Result := 'repman-linux-' + LowerCase(LMachineId);
end;
{$ENDIF}
{$IFNDEF LINUX}
begin
  Result := 'repman-' + LowerCase(Trim(GetEnvironmentVariable('USER')));
  if Result='repman-' then
    Result := 'repman-unknown';
end;
{$ENDIF}
{$ENDIF}

{$IFDEF FIREDAC}
procedure TRpAuthManager.AcceptAnyServerCertificate(const Sender: TObject;
  const ARequest: TURLRequest; const Certificate: TCertificate;
  var Accepted: Boolean);
begin
{$IFDEF DEBUG}
  Accepted := True;
{$ENDIF}
end;

procedure TRpAuthManager.ConfigureDebugHttpClient(AHttpClient: TNetHTTPClient);
begin
  if AHttpClient = nil then
    Exit;
{$IFDEF DEBUG}
  AHttpClient.OnValidateServerCertificate := Self.AcceptAnyServerCertificate;
{$ENDIF}
end;
{$ENDIF}

destructor TRpAuthManager.Destroy;
begin
{$IFDEF MSWINDOWS}
  if FDispatchHandle <> 0 then
    DeallocateHWnd(FDispatchHandle);
{$ENDIF}
  FLogListeners.Free;
  FAuthListeners.Free;
  inherited Destroy;
end;

{$IFDEF MSWINDOWS}
procedure TRpAuthManager.DispatchWndProc(var Msg: TMessage);
var
  LPayload: TRpQueuedAuthListenerPayload;
begin
  if Msg.Msg = WM_RP_AUTH_DISPATCH then
  begin
    LPayload := TRpQueuedAuthListenerPayload(Msg.WParam);
    try
      if (LPayload <> nil) and Assigned(LPayload.Listener) then
        LPayload.Listener(LPayload.Success);
    finally
      LPayload.Free;
    end;
  end
  else
    Msg.Result := DefWindowProc(FDispatchHandle, Msg.Msg, Msg.WParam, Msg.LParam);
end;
{$ENDIF}

procedure TRpAuthManager.Log(const AMsg: string);
var
  LListener: TRpAuthLog;
begin
{$IFDEF MSWINDOWS}
  OutputDebugString(PChar('RpAuth: ' + AMsg));
{$ENDIF}
  if Assigned(FOnLog) then
    FOnLog(AMsg);
  for LListener in FLogListeners do
    LListener(AMsg);
end;

class function TRpAuthManager.Instance: TRpAuthManager;
begin
  if FInstance = nil then
    FInstance := TRpAuthManager.Create;
  Result := FInstance;
end;

procedure TRpAuthManager.ParseProfile(AProfileObj: TJSONObject);
var
  LValue: TJSONValue;
begin
  if AProfileObj = nil then Exit;
  Log('Parsing User Profile...');
  
  LValue := AProfileObj.GetValue('userId');
  if LValue = nil then LValue := AProfileObj.GetValue('UserId');
  if LValue = nil then LValue := AProfileObj.GetValue('userid');
  if LValue <> nil then 
  begin
    FProfile.UserId := StrToInt64Def(LValue.Value, 0);
    Log('UserId: ' + IntToStr(FProfile.UserId));
  end;

  LValue := AProfileObj.GetValue('email');
  if LValue = nil then LValue := AProfileObj.GetValue('Email');
  if LValue = nil then LValue := AProfileObj.GetValue('email'); // redundant but consistent
  if LValue <> nil then Self.FProfile.Email := LValue.Value;

  LValue := AProfileObj.GetValue('userName');
  if LValue = nil then LValue := AProfileObj.GetValue('UserName');
  if LValue = nil then LValue := AProfileObj.GetValue('username');
  if LValue <> nil then Self.FProfile.UserName := LValue.Value;

  LValue := AProfileObj.GetValue('profileImageUrl');
  if LValue = nil then LValue := AProfileObj.GetValue('ProfileImageUrl');
  if LValue = nil then LValue := AProfileObj.GetValue('profileimageurl');
  if LValue <> nil then Self.FProfile.AvatarUrl := LValue.Value;

  LValue := AProfileObj.GetValue('accountType');
  if LValue = nil then LValue := AProfileObj.GetValue('AccountType');
  if LValue = nil then LValue := AProfileObj.GetValue('accounttype');
  if LValue <> nil then Self.FProfile.AccountType := StrToIntDef(LValue.Value, 0);

  LValue := AProfileObj.GetValue('tierId');
  if LValue = nil then LValue := AProfileObj.GetValue('TierId');
  if LValue = nil then LValue := AProfileObj.GetValue('tierid');
  if LValue <> nil then 
  begin
    FProfile.TierId := StrToInt64Def(LValue.Value, 1);
    Log('TierId: ' + IntToStr(FProfile.TierId));
  end;

  LValue := AProfileObj.GetValue('tierName');
  if LValue = nil then LValue := AProfileObj.GetValue('TierName');
  if LValue = nil then LValue := AProfileObj.GetValue('tiername');
  if LValue <> nil then 
  begin
    FProfile.TierName := LValue.Value;
    Log('TierName: ' + FProfile.TierName);
  end;

  LValue := AProfileObj.GetValue('dailyMax');
  if LValue = nil then LValue := AProfileObj.GetValue('DailyMax');
  if LValue = nil then LValue := AProfileObj.GetValue('dailymax');
  if LValue <> nil then Self.FProfile.DailyMax := StrToInt64Def(LValue.Value, 0);

  LValue := AProfileObj.GetValue('dailyConsumed');
  if LValue = nil then LValue := AProfileObj.GetValue('DailyConsumed');
  if LValue = nil then LValue := AProfileObj.GetValue('dailyconsumed');
  if LValue <> nil then Self.FProfile.DailyConsumed := StrToInt64Def(LValue.Value, 0);

  LValue := AProfileObj.GetValue('freeInitial');
  if LValue = nil then LValue := AProfileObj.GetValue('FreeInitial');
  if LValue = nil then LValue := AProfileObj.GetValue('freeinitial');
  if LValue <> nil then Self.FProfile.FreeInitial := StrToInt64Def(LValue.Value, 0);

  LValue := AProfileObj.GetValue('freeRemaining');
  if LValue = nil then LValue := AProfileObj.GetValue('FreeRemaining');
  if LValue = nil then LValue := AProfileObj.GetValue('freeremaining');
  if LValue <> nil then Self.FProfile.FreeRemaining := StrToInt64Def(LValue.Value, 0);

  LValue := AProfileObj.GetValue('serverDay');
  if LValue = nil then LValue := AProfileObj.GetValue('ServerDay');
  if LValue = nil then LValue := AProfileObj.GetValue('serverday');
  // Simple ISO date parsing for Delphi
  if LValue <> nil then Self.FProfile.ServerDay := ISO8601ToDate(LValue.Value);

  LValue := AProfileObj.GetValue('credits');
  if LValue = nil then LValue := AProfileObj.GetValue('Credits');
  if LValue <> nil then Self.FProfile.Credits := StrToInt64Def(LValue.Value, 0);

  Log('Profile Parsed: ' + Self.FProfile.Email + ' Tier: ' + Self.FProfile.TierName +
    ' (Daily: ' + IntToStr(FProfile.DailyConsumed) + '/' + IntToStr(FProfile.DailyMax) +
    ', Free: ' + IntToStr(FProfile.FreeRemaining) + '/' + IntToStr(FProfile.FreeInitial) + ')');
end;

function TRpAuthManager.UsesFreeCredits: Boolean;
begin
  Result := (FProfile.Email = '') or (FProfile.TierId <= 2);
end;

function TRpAuthManager.GetCreditsRatio: Double;
var
  LMax: Int64;
  LConsumed: Int64;
begin
  if UsesFreeCredits then
  begin
    LMax := FProfile.FreeInitial;
    LConsumed := FProfile.FreeInitial - FProfile.FreeRemaining;
  end
  else
  begin
    LMax := FProfile.DailyMax;
    LConsumed := FProfile.DailyConsumed;
  end;

  if LMax > 0 then
    Result := LConsumed / LMax
  else
    Result := 0.0;
end;

function TRpAuthManager.GetCreditsConsumed: Int64;
begin
  if UsesFreeCredits then
    Result := FProfile.FreeInitial - FProfile.FreeRemaining
  else
    Result := FProfile.DailyConsumed;
end;

function TRpAuthManager.GetCreditsMax: Int64;
begin
  if UsesFreeCredits then
    Result := FProfile.FreeInitial
  else
    Result := FProfile.DailyMax;
end;

procedure TRpAuthManager.CheckStatus;
var
  LClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LRoot: TJSONObject;
  LPicture: TStream;
  LValue: TJSONValue;
  LRequestStartedAt: TDateTime;
  LAvatarStartedAt: TDateTime;
begin
  if FInstallId = '' then Exit;

  LClient := TNetHTTPClient.Create(nil);
  try
    ConfigureDebugHttpClient(LClient);
    if FToken <> '' then
      LClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
    if FInstallId <> '' then
      LClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
    try
      // Use lowercase URL and cast nil to TStream to avoid ambiguous overload
      LRequestStartedAt := Now;
      LResponse := LClient.Post(HUB_API_URL + '/api/userprofile/status', TStream(nil), TStream(nil));
      Log('CheckStatus: Response Status ' + IntToStr(LResponse.StatusCode) +
        ' (' + IntToStr(MilliSecondsBetween(Now, LRequestStartedAt)) + ' ms)');

      if (LResponse.StatusCode = 200) then
      begin
        LRoot := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
        if LRoot <> nil then
        try
          LValue := LRoot.GetValue('profile');
          if LValue = nil then LValue := LRoot.GetValue('Profile');
          if (LValue <> nil) and (LValue is TJSONObject) then
            ParseProfile(LValue as TJSONObject);
          
          LValue := LRoot.GetValue('tiers');
          if LValue = nil then LValue := LRoot.GetValue('Tiers');
          if (LValue <> nil) and (LValue is TJSONArray) then
            ParseTiers(LValue as TJSONArray);
          SaveConfig;
            
          NotifyListeners(True);
          
          // Refresh Avatar if changed
          if FProfile.AvatarUrl <> '' then
          begin
             LPicture := TMemoryStream.Create;
             try
               LAvatarStartedAt := Now;
               LResponse := LClient.Get(FProfile.AvatarUrl);
               Log('CheckStatus Avatar GET: Response Status ' + IntToStr(LResponse.StatusCode) +
                 ' (' + IntToStr(MilliSecondsBetween(Now, LAvatarStartedAt)) + ' ms)');
               if LResponse.StatusCode = 200 then
               begin
                 LPicture.CopyFrom(LResponse.ContentStream, 0);
                 LPicture.Position := 0;
               end;
             finally
               LPicture.Free;
             end;
          end;
        finally
          LRoot.Free;
        end;
      end
      else if LResponse.StatusCode = 401 then
      begin
        if FToken <> '' then
        begin
          Log('CheckStatus: Unauthorized (401). Token expired or invalid. Logging out.');
          Logout;
        end
        else
          Log('CheckStatus: Guest status not available (401).');
      end
      else
      begin
        Log('CheckStatus: Unexpected status ' + IntToStr(LResponse.StatusCode) + ': ' + LResponse.ContentAsString);
      end;
    except
      on E: Exception do
        Log('CheckStatus Error after ' + IntToStr(MilliSecondsBetween(Now, LRequestStartedAt)) +
          ' ms: ' + E.Message);
    end;
  finally
    LClient.Free;
  end;
end;

procedure TRpAuthManager.UpdateProfileFromJson(AProfileObj: TJSONObject);
begin
  if AProfileObj = nil then
    Exit;

  ParseProfile(AProfileObj);
  SaveConfig;
  NotifyListeners(True);
end;

procedure TRpAuthManager.DispatchAuthListener(AListener: TRpAuthEvent; ASuccess: Boolean);
{$IFDEF MSWINDOWS}
var
  LPayload: TRpQueuedAuthListenerPayload;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  if GetCurrentThreadId = MainThreadID then
    AListener(ASuccess)
  else
  begin
    LPayload := TRpQueuedAuthListenerPayload.Create;
    LPayload.Listener := AListener;
    LPayload.Success := ASuccess;
    if not PostMessage(FDispatchHandle, WM_RP_AUTH_DISPATCH, WPARAM(LPayload), 0) then
      LPayload.Free;
  end;
{$ELSE}
  AListener(ASuccess);
{$ENDIF}
end;

procedure TRpAuthManager.NotifyListeners(ASuccess: Boolean);
var
  LListener: TRpAuthEvent;
begin
  for LListener in FAuthListeners do
    DispatchAuthListener(LListener, ASuccess);
end;

procedure TRpAuthManager.ParseTiers(ATiersArray: TJSONArray);
var
  I: Integer;
  TierObj: TJSONObject;
  LValue: TJSONValue;
begin
  if ATiersArray = nil then Exit;
  Log('Parsing Tiers (' + IntToStr(ATiersArray.Count) + ' found)...');
  SetLength(Self.FTiers, ATiersArray.Count);
  for I := 0 to ATiersArray.Count - 1 do
  begin
    TierObj := ATiersArray.Items[I] as TJSONObject;
    
    LValue := TierObj.GetValue('id');
    if LValue = nil then LValue := TierObj.GetValue('Id');
    if LValue <> nil then Self.FTiers[I].Id := StrToInt64Def(LValue.Value, 0);

    LValue := TierObj.GetValue('name');
    if LValue = nil then LValue := TierObj.GetValue('Name');
    if LValue <> nil then Self.FTiers[I].Name := LValue.Value;

    LValue := TierObj.GetValue('monthlyPrice');
    if LValue = nil then LValue := TierObj.GetValue('MonthlyPrice');
    if LValue <> nil then Self.FTiers[I].MonthlyPrice := StrToFloatDef(LValue.Value, 0);

    LValue := TierObj.GetValue('yearlyPrice');
    if LValue = nil then LValue := TierObj.GetValue('YearlyPrice');
    if LValue <> nil then Self.FTiers[I].YearlyPrice := StrToFloatDef(LValue.Value, 0);

    LValue := TierObj.GetValue('maxCreditsDay');
    if LValue = nil then LValue := TierObj.GetValue('MaxCreditsDay');
    if LValue <> nil then Self.FTiers[I].MaxCreditsDay := StrToInt64Def(LValue.Value, 0);

    LValue := TierObj.GetValue('maxFreeCredits');
    if LValue = nil then LValue := TierObj.GetValue('MaxFreeCredits');
    if LValue <> nil then Self.FTiers[I].MaxFreeCredits := StrToInt64Def(LValue.Value, 0);

    LValue := TierObj.GetValue('maxConnections');
    if LValue = nil then LValue := TierObj.GetValue('MaxConnections');
    if LValue <> nil then Self.FTiers[I].MaxConnections := StrToIntDef(LValue.Value, 0);

    LValue := TierObj.GetValue('maxTables');
    if LValue = nil then LValue := TierObj.GetValue('MaxTables');
    if LValue <> nil then Self.FTiers[I].MaxTables := StrToIntDef(LValue.Value, 0);

    LValue := TierObj.GetValue('maxColumnsPerTable');
    if LValue = nil then LValue := TierObj.GetValue('MaxColumnsPerTable');
    if LValue <> nil then Self.FTiers[I].MaxColumnsPerTable := StrToIntDef(LValue.Value, 0);

    LValue := TierObj.GetValue('maxKpis');
    if LValue = nil then LValue := TierObj.GetValue('MaxKpis');
    if LValue <> nil then Self.FTiers[I].MaxKpis := StrToIntDef(LValue.Value, 0);
  end;
end;

function TRpAuthManager.RequestLoginCode(const AEmail: string): Boolean;
{$IFDEF FIREDAC}
var
  HttpClient: TNetHTTPClient;
  RequestBody: TJSONObject;
  SourceStream: TStringStream;
  Response: IHTTPResponse;
begin
  Result := False;
  HttpClient := TNetHTTPClient.Create(nil);
  try
    ConfigureDebugHttpClient(HttpClient);
    RequestBody := TJSONObject.Create;
    RequestBody.AddPair('email', AEmail);
    SourceStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      HttpClient.ContentType := 'application/json';
      if FInstallId <> '' then
        HttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
      try
        Response := HttpClient.Post(HUB_API_URL + '/api/LoginResend/send', SourceStream, TStream(nil));
        Log('Hub API Response Code (Resend): ' + IntToStr(Response.StatusCode));
        Result := Response.StatusCode = 200;
      except
        on E: Exception do
          Log('HTTP Hub Exception (Resend): ' + E.Message);
      end;
    finally
      SourceStream.Free;
      RequestBody.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

function TRpAuthManager.LoginWithCode(const AEmail, ACode: string): Boolean;
{$IFDEF FIREDAC}
var
  HttpClient: TNetHTTPClient;
  RequestBody: TJSONObject;
  SourceStream: TStringStream;
  Response: IHTTPResponse;
  ResponseJson: TJSONObject;
  LValue: TJSONValue;
begin
  Result := False;
  HttpClient := TNetHTTPClient.Create(nil);
  try
    ConfigureDebugHttpClient(HttpClient);
    RequestBody := TJSONObject.Create;
    RequestBody.AddPair('email', AEmail);
    RequestBody.AddPair('emailCode', ACode);
    RequestBody.AddPair('installId', FInstallId);
    
    SourceStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      HttpClient.ContentType := 'application/json';
      if FInstallId <> '' then
        HttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
      Response := HttpClient.Post(HUB_API_URL + '/api/Login/email', SourceStream, TStream(nil));
      if Response.StatusCode = 200 then
      begin
        ResponseJson := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONObject;
        if ResponseJson <> nil then
        try
          LValue := ResponseJson.GetValue('token');
          if LValue = nil then LValue := ResponseJson.GetValue('Token');
          if LValue <> nil then
            FToken := LValue.Value;

          LValue := ResponseJson.GetValue('profile');
          if LValue = nil then LValue := ResponseJson.GetValue('Profile');
          if (LValue <> nil) and (LValue is TJSONObject) then
            ParseProfile(LValue as TJSONObject);

          LValue := ResponseJson.GetValue('tiers');
          if LValue = nil then LValue := ResponseJson.GetValue('Tiers');
          if (LValue <> nil) and (LValue is TJSONArray) then
            ParseTiers(LValue as TJSONArray);

          SetIsLoggedIn(FToken <> '');
          Result := FToken <> '';
          if Result then SaveConfig;
        finally
          ResponseJson.Free;
        end;
      end;
    finally
      SourceStream.Free;
      RequestBody.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

procedure TRpAuthManager.Logout;
begin
  FToken := '';
  FProfile.UserId := 0;
  FProfile.Email := '';
  FProfile.UserName := '';
  FProfile.AvatarUrl := '';
  FProfile.AccountType := 0;
  FProfile.Credits := 0;
  FTiers := [];
  ClearConfig;
  SetIsLoggedIn(False);
end;

procedure TRpAuthManager.SetIsLoggedIn(Value: Boolean);
var
  LListener: TRpAuthEvent;
begin
  FIsLoggedIn := Value;
  for LListener in FAuthListeners do
    DispatchAuthListener(LListener, FIsLoggedIn);
end;

procedure TRpAuthManager.SetAIEnabled(Value: Boolean);
begin
  if FAIEnabled = Value then
    Exit;

  FAIEnabled := Value;
  SaveConfig;
end;

procedure TRpAuthManager.SetAILanguage(const Value: string);
var
  LNormalized: string;
begin
  LNormalized := NormalizeAILanguageValue(Value);
  if SameText(FAILanguage, LNormalized) then
    Exit;

  FAILanguage := LNormalized;
  SaveConfig;
end;

class function TRpAuthManager.GetSupportedAILanguages: TArray<string>;
begin
  Result := TArray<string>.Create(
    'English',
    'Spanish',
    'Italian',
    'French',
    'German',
    'Portuguese',
    'Chinese',
    'Catalan');
end;

class function TRpAuthManager.GetAILanguageDisplayName(const AValue: string): string;
begin
  Result := NormalizeAILanguageValue(AValue);
end;

class function TRpAuthManager.ResolveDefaultAILanguage: string;
var
{$IFDEF MSWINDOWS}
  LBuffer: array[0..15] of Char;
{$ENDIF}
  LCode: string;
  LPos: Integer;
begin
  LCode := '';
{$IFDEF MSWINDOWS}
  if GetLocaleInfo(LOCALE_USER_DEFAULT, LOCALE_SISO639LANGNAME, LBuffer,
    Length(LBuffer)) > 0 then
    LCode := LowerCase(string(LBuffer));
{$ELSE}
  LCode := LowerCase(Trim(GetEnvironmentVariable('LANG')));
  LPos := Pos('.', LCode);
  if LPos > 0 then
    LCode := Copy(LCode, 1, LPos - 1);
  LCode := StringReplace(LCode, '_', '-', [rfReplaceAll]);
{$ENDIF}

  Result := NormalizeAILanguageValue(LCode);
end;

class function TRpAuthManager.NormalizeAILanguageValue(const AValue: string): string;
var
  LValue: string;
begin
  LValue := Trim(AValue);
  if LValue = '' then
    Exit('English');

  if SameText(LValue, 'English') or SameText(LValue, 'en') or SameText(LValue, 'en-US') or SameText(LValue, 'en-GB') then
    Exit('English');
  if SameText(LValue, 'Spanish') or SameText(LValue, 'es') or SameText(LValue, 'es-ES') then
    Exit('Spanish');
  if SameText(LValue, 'Italian') or SameText(LValue, 'it') or SameText(LValue, 'it-IT') then
    Exit('Italian');
  if SameText(LValue, 'French') or SameText(LValue, 'fr') or SameText(LValue, 'fr-FR') then
    Exit('French');
  if SameText(LValue, 'German') or SameText(LValue, 'de') or SameText(LValue, 'de-DE') then
    Exit('German');
  if SameText(LValue, 'Portuguese') or SameText(LValue, 'pt') or SameText(LValue, 'pt-PT') or SameText(LValue, 'pt-BR') then
    Exit('Portuguese');
  if SameText(LValue, 'Chinese') or SameText(LValue, 'zh') or SameText(LValue, 'zh-CN') or SameText(LValue, 'zh-TW') then
    Exit('Chinese');
  if SameText(LValue, 'Catalan') or SameText(LValue, 'ca') or SameText(LValue, 'ca-ES') then
    Exit('Catalan');

  Result := 'English';
end;

procedure TRpAuthManager.RegisterAuthListener(AListener: TRpAuthEvent);
begin
  if FAuthListeners.IndexOf(AListener) < 0 then
    FAuthListeners.Add(AListener);
end;

procedure TRpAuthManager.UnregisterAuthListener(AListener: TRpAuthEvent);
begin
  FAuthListeners.Remove(AListener);
end;

procedure TRpAuthManager.RegisterLogListener(AListener: TRpAuthLog);
begin
  if FLogListeners.IndexOf(AListener) < 0 then
    FLogListeners.Add(AListener);
end;

procedure TRpAuthManager.UnregisterLogListener(AListener: TRpAuthLog);
begin
  FLogListeners.Remove(AListener);
end;

function TRpAuthManager.WaitForOAuthCallback(APort: Integer): Boolean;
{$IFDEF MSWINDOWS}
var
  LListenSocket, LClientSocket: TSocket;
  LAddr: sockaddr_in;
  LAddrLen: Integer;
  LStartTime: TDateTime;
  LFDSet: TFDSet;
  LTimeout: TTimeVal;
  LBuf: array[0..4095] of AnsiChar;
  LBytesRead: Integer;
  LRequest, LQueryString, LResponseHtml: string;
  LPosQ, LPosSpace, i: Integer;
  LPairs: TStringList;
begin
  Result := False;
  FOAuthCode := '';
  FOAuthError := '';
  FOAuthGotCallback := False;

  LListenSocket := Winapi.WinSock.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if LListenSocket = INVALID_SOCKET then Exit;
  try
    FillChar(LAddr, SizeOf(LAddr), 0);
    LAddr.sin_family := AF_INET;
    LAddr.sin_addr.S_addr := htonl(INADDR_LOOPBACK);
    LAddr.sin_port := htons(APort);

    Log('Loopback server listening on port ' + IntToStr(APort) + '...');
    if bind(LListenSocket, TSockAddr(LAddr), SizeOf(LAddr)) = SOCKET_ERROR then Exit;
    if listen(LListenSocket, 1) = SOCKET_ERROR then Exit;

    LStartTime := Now;
    while (not FOAuthGotCallback) and ((Now - LStartTime) < (5 / 24 / 60)) do
    begin
      FD_ZERO(LFDSet);
      FD_SET(LListenSocket, LFDSet);
      LTimeout.tv_sec := 0;
      LTimeout.tv_usec := 200000;

      if select(0, @LFDSet, nil, nil, @LTimeout) > 0 then
      begin
        LAddrLen := SizeOf(LAddr);
        LClientSocket := accept(LListenSocket, PSockAddr(@LAddr), @LAddrLen);
        if LClientSocket <> INVALID_SOCKET then
        try
          LBytesRead := recv(LClientSocket, LBuf[0], SizeOf(LBuf) - 1, 0);
          if LBytesRead > 0 then
          begin
            LBuf[LBytesRead] := #0;
            LRequest := string(PAnsiChar(@LBuf[0]));

            if Pos('/favicon.ico', LRequest) > 0 then
            begin
              LResponseHtml := 'HTTP/1.1 404 Not Found'#13#10'Content-Length: 0'#13#10#13#10;
              send(LClientSocket, PAnsiChar(AnsiString(LResponseHtml))^, Length(AnsiString(LResponseHtml)), 0);
            end
            else
            begin
              LPosQ := Pos('?', LRequest);
            if LPosQ > 0 then
            begin
              LPosSpace := Pos(' ', LRequest, LPosQ);
              if LPosSpace = 0 then LPosSpace := Length(LRequest) + 1;
              LQueryString := Copy(LRequest, LPosQ + 1, LPosSpace - LPosQ - 1);

              LPairs := TStringList.Create;
              try
                LPairs.Delimiter := '&';
                LPairs.StrictDelimiter := True;
                LPairs.DelimitedText := LQueryString;
                FOAuthCode := '';
                FOAuthError := '';
                for i := 0 to LPairs.Count - 1 do
                begin
                  if SameText(LPairs.Names[i], 'code') then
                    Self.FOAuthCode := TNetEncoding.URL.Decode(LPairs.ValueFromIndex[i])
                  else if SameText(LPairs.Names[i], 'error') then
                    Self.FOAuthError := TNetEncoding.URL.Decode(LPairs.ValueFromIndex[i]);
                end;
              finally
                LPairs.Free;
              end;

              if (FOAuthCode <> '') or (FOAuthError <> '') then
              begin
                FOAuthGotCallback := True;
                if FOAuthError <> '' then
                  LResponseHtml := '<html><body><h1>Login failed</h1><p>' + FOAuthError + '</p></body></html>'
                else
                  LResponseHtml := '<html><body><h1>Login successful!</h1><p>You can close this window.</p><script>window.close();</script></body></html>';
                
                LResponseHtml := 'HTTP/1.1 200 OK'#13#10 +
                  'Content-Type: text/html; charset=utf-8'#13#10 +
                  'Content-Length: ' + IntToStr(Length(UTF8Encode(LResponseHtml))) + #13#10 +
                  'Connection: close'#13#10#13#10 +
                  LResponseHtml;
                send(LClientSocket, PAnsiChar(AnsiString(LResponseHtml))^, Length(AnsiString(LResponseHtml)), 0);
              end;
            end;
          end;
        end; // end else begin at 452
      finally
          closesocket(LClientSocket);
        end;
      end;
    end; // end while
    Result := FOAuthGotCallback and (FOAuthCode <> '');
  finally
    closesocket(LListenSocket);
  end;
end;
{$ELSE}
begin
  Result := False;
  Log('OAuth loopback callback is not supported on this platform.');
end;
{$ENDIF}

function TRpAuthManager.ExchangeGoogleCode(const ACode, ARedirectUri: string): Boolean;
{$IFDEF FIREDAC}
var
  LHttpClient: TNetHTTPClient;
  LRequest: TJSONObject;
  LSourceStream: TStringStream;
  LResponse: IHTTPResponse;
  LResponseJson: TJSONObject;
  LValue: TJSONValue;
begin
  Result := False;
  LHttpClient := TNetHTTPClient.Create(nil);
  try
    ConfigureDebugHttpClient(LHttpClient);
    LRequest := TJSONObject.Create;
    try
      LRequest.AddPair('code', ACode);
      LRequest.AddPair('redirectUri', ARedirectUri);
      LRequest.AddPair('installId', FInstallId);
      LSourceStream := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
      try
        LHttpClient.ContentType := 'application/json';
        Log('Step 1: Sending Google Authorization Code to Hub API...');
        try
          if FInstallId <> '' then
            LHttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
          // All API calls use the global HUB_API_URL from rptypes
          LResponse := LHttpClient.Post(HUB_API_URL + '/api/Login/google', LSourceStream, TStream(nil));
          Log('Hub API Response Code: ' + IntToStr(LResponse.StatusCode));
          if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300) then
          begin
            Log('Hub API accepted Google login.');
            LResponseJson := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
            if LResponseJson <> nil then
            try
              LValue := LResponseJson.GetValue('token');
              if LValue = nil then LValue := LResponseJson.GetValue('Token');
              if LValue <> nil then
                FToken := LValue.Value;

              LValue := LResponseJson.GetValue('profile');
              if LValue = nil then LValue := LResponseJson.GetValue('Profile');
              if (LValue <> nil) and (LValue is TJSONObject) then
                ParseProfile(LValue as TJSONObject);

              LValue := LResponseJson.GetValue('tiers');
              if LValue = nil then LValue := LResponseJson.GetValue('Tiers');
              if (LValue <> nil) and (LValue is TJSONArray) then
                ParseTiers(LValue as TJSONArray);

              SetIsLoggedIn(FToken <> '');
              CheckStatus;
              Result := FToken <> '';
              if Result then SaveConfig;
            finally
              LResponseJson.Free;
            end;
          end
          else
            Log('Hub API Hub Error: ' + LResponse.ContentAsString);
        except
          on E: Exception do
            Log('HTTP Hub Exception (' + E.ClassName + '): ' + E.Message);
        end;
      finally
        LSourceStream.Free;
      end;
    finally
      LRequest.Free;
    end;
  finally
    LHttpClient.Free;
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

function TRpAuthManager.ExchangeMicrosoftCode(const ACode, ARedirectUri: string): Boolean;
{$IFDEF FIREDAC}
var
  LHttpClient: TNetHTTPClient;
  LRequest: TJSONObject;
  LSourceStream: TStringStream;
  LResponse: IHTTPResponse;
  LResponseJson: TJSONObject;
  LValue: TJSONValue;
  LAccessToken: string;
begin
  Result := False;
  LAccessToken := '';
  LHttpClient := TNetHTTPClient.Create(nil);
  try
    ConfigureDebugHttpClient(LHttpClient);
    Log('Step 1: Requesting Microsoft Access Token...');
    LSourceStream := TStringStream.Create(
      'client_id=' + TURLEncoding.URL.Encode('bc88d289-ded3-4389-a62b-2f12ad635dac') +
      '&code=' + TURLEncoding.URL.Encode(ACode) +
      '&redirect_uri=' + TURLEncoding.URL.Encode(ARedirectUri) +
      '&grant_type=authorization_code',
      TEncoding.UTF8);
    try
      LHttpClient.ContentType := 'application/x-www-form-urlencoded';
      if FInstallId <> '' then
        LHttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
      LResponse := LHttpClient.Post('https://login.microsoftonline.com/common/oauth2/v2.0/token', LSourceStream);
      if LResponse.StatusCode = 200 then
      begin
        Log('Microsoft token received.');
        LResponseJson := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
        if LResponseJson <> nil then
        try
          LValue := LResponseJson.GetValue('access_token');
          if LValue <> nil then LAccessToken := LValue.Value;
        finally
          LResponseJson.Free;
        end;
      end;
    finally
      LSourceStream.Free;
    end;

    if LAccessToken = '' then Exit;

    Log('Step 2: Sending Microsoft Access Token to Hub API...');
    LRequest := TJSONObject.Create;
    try
      LRequest.AddPair('microsoftCode', LAccessToken);
      LRequest.AddPair('installId', FInstallId);
      LSourceStream := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
      try
        LHttpClient.ContentType := 'application/json';
        if FInstallId <> '' then
          LHttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
        Log('Step 2: Sending Microsoft Access Token to Hub API...');
        try
          LResponse := LHttpClient.Post(HUB_API_URL + '/api/Login/microsoft', LSourceStream, TStream(nil));
          Log('Hub API Response Code: ' + IntToStr(LResponse.StatusCode));
          if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300) then
          begin
            Log('Hub API accepted Microsoft login.');
            LResponseJson := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
            if LResponseJson <> nil then
            try
              LValue := LResponseJson.GetValue('token');
              if LValue = nil then LValue := LResponseJson.GetValue('Token');
              if LValue <> nil then FToken := LValue.Value;

              LValue := LResponseJson.GetValue('profile');
              if LValue = nil then LValue := LResponseJson.GetValue('Profile');
              if (LValue <> nil) and (LValue is TJSONObject) then
                ParseProfile(LValue as TJSONObject);

              LValue := LResponseJson.GetValue('tiers');
              if LValue = nil then LValue := LResponseJson.GetValue('Tiers');
              if (LValue <> nil) and (LValue is TJSONArray) then
                ParseTiers(LValue as TJSONArray);

              SetIsLoggedIn(FToken <> '');
              CheckStatus;
              Result := FToken <> '';
              if Result then SaveConfig;
            finally
              LResponseJson.Free;
            end;
          end
          else
            Log('Hub API Hub Error: ' + LResponse.ContentAsString);
        except
          on E: Exception do
            Log('HTTP Hub Exception (' + E.ClassName + '): ' + E.Message);
        end;
      finally
        LSourceStream.Free;
      end;
    finally
      LRequest.Free;
    end;
  finally
    LHttpClient.Free;
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

function TRpAuthManager.LoginGoogle: Boolean;
{$IFDEF MSWINDOWS}
const
  GOOGLE_CLIENT_ID = '446365228848-pn415lkvsetqa7v7fi7ftg96m61ccl5p.apps.googleusercontent.com';
var
  LPort: Integer;
  LRedirectUri, LState, LAuthUrl: string;
  LWSAData: TWSAData;
begin
  Result := False;
  if WSAStartup(MakeWord(2, 2), LWSAData) <> 0 then Exit;
  try
    LPort := 49152 + Random(16384);
    LRedirectUri := 'http://localhost:' + IntToStr(LPort) + '/';
    Log('Auth: Port=' + IntToStr(LPort) + ' RedirectUri=' + LRedirectUri);
    LState := IntToHex(Random(MaxInt), 8);
    LAuthUrl := 'https://accounts.google.com/o/oauth2/v2/auth?response_type=code&scope=openid%20profile%20email&redirect_uri=' + TURLEncoding.URL.Encode(LRedirectUri) + '&client_id=' + GOOGLE_CLIENT_ID + '&state=' + LState;
    ShellExecute(0, 'open', PChar(LAuthUrl), nil, nil, SW_SHOWNORMAL);
    if WaitForOAuthCallback(LPort) then Result := ExchangeGoogleCode(FOAuthCode, LRedirectUri);
  finally
    WSACleanup;
  end;
end;
{$ELSE}
begin
  Result := False;
  Log('Google OAuth login is not supported on this platform.');
end;
{$ENDIF}

function TRpAuthManager.LoginMicrosoft: Boolean;
{$IFDEF MSWINDOWS}
const
  MS_CLIENT_ID = 'bc88d289-ded3-4389-a62b-2f12ad635dac';
var
  LPort: Integer;
  LRedirectUri, LState, LAuthUrl: string;
  LWSAData: TWSAData;
begin
  Result := False;
  if WSAStartup(MakeWord(2, 2), LWSAData) <> 0 then Exit;
  try
    LPort := 49152 + Random(16384);
    LRedirectUri := 'http://localhost:' + IntToStr(LPort) + '/';
    Log('Auth: Port=' + IntToStr(LPort) + ' RedirectUri=' + LRedirectUri);
    LState := IntToHex(Random(MaxInt), 8);
    LAuthUrl := 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?response_type=code&scope=openid%20profile%20email%20user.read&redirect_uri=' + TURLEncoding.URL.Encode(LRedirectUri) + '&client_id=' + MS_CLIENT_ID + '&state=' + LState;
    ShellExecute(0, 'open', PChar(LAuthUrl), nil, nil, SW_SHOWNORMAL);
    if WaitForOAuthCallback(LPort) then Result := ExchangeMicrosoftCode(FOAuthCode, LRedirectUri);
  finally
    WSACleanup;
  end;
end;
{$ELSE}
begin
  Result := False;
  Log('Microsoft OAuth login is not supported on this platform.');
end;
{$ENDIF}

function TRpAuthManager.RefreshTiers: Boolean;
{$IFDEF FIREDAC}
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  ResponseJsonValue: TJSONValue;
begin
  Result := False;
  HttpClient := TNetHTTPClient.Create(nil);
  try
    ConfigureDebugHttpClient(HttpClient);
    try
      if FToken <> '' then
        HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
      if FInstallId <> '' then
        HttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
      Response := HttpClient.Get(HUB_API_URL + '/api/Tiers');
      Log('Hub API Response Code (Tiers): ' + IntToStr(Response.StatusCode));
      if Response.StatusCode = 200 then
      begin
        ResponseJsonValue := TJSONObject.ParseJSONValue(Response.ContentAsString);
        if (ResponseJsonValue <> nil) and (ResponseJsonValue is TJSONArray) then
        begin
          ParseTiers(TJSONArray(ResponseJsonValue));
          Result := True;
        end;
        if ResponseJsonValue <> nil then ResponseJsonValue.Free;
      end;
    except
      on E: Exception do
        Log('HTTP Hub Exception (Tiers): ' + E.Message);
    end;
  finally
    HttpClient.Free;
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

function TRpAuthManager.GetCheckoutUrl(ATierId: Int64; AIsYearly: Boolean): string;
{$IFDEF FIREDAC}
var
  HttpClient: TNetHTTPClient;
  RequestBody: TJSONObject;
  SourceStream: TStringStream;
  Response: IHTTPResponse;
begin
  Result := '';
  HttpClient := TNetHTTPClient.Create(nil);
  try
    ConfigureDebugHttpClient(HttpClient);
    if FToken <> '' then HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
    RequestBody := TJSONObject.Create;
    RequestBody.AddPair('tierId', TJSONNumber.Create(ATierId));
    RequestBody.AddPair('isYearly', TJSONBool.Create(AIsYearly));
    RequestBody.AddPair('userEmail', Self.FProfile.Email);
    SourceStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      HttpClient.ContentType := 'application/json';
      if FInstallId <> '' then
        HttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
      try
        Response := HttpClient.Post(HUB_API_URL + '/api/stripe/subscribe', SourceStream, TStream(nil));
        Log('Hub API Response Code (Stripe): ' + IntToStr(Response.StatusCode));
        if Response.StatusCode = 200 then Result := Response.ContentAsString;
      except
        on E: Exception do
          Log('HTTP Hub Exception (Stripe): ' + E.Message);
      end;
    finally
      SourceStream.Free;
      RequestBody.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;
{$ELSE}
begin
  Result := '';
end;
{$ENDIF}

function TRpAuthManager.GetPortalUrl: string;
{$IFDEF FIREDAC}
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
begin
  Result := '';
  HttpClient := TNetHTTPClient.Create(nil);
  try
    ConfigureDebugHttpClient(HttpClient);
    if FToken <> '' then HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
    if FInstallId <> '' then HttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
    try
      Response := HttpClient.Post(HUB_API_URL + '/api/stripe/portal', TStream(nil), TStream(nil));
      Log('Hub API Response Code (Portal): ' + IntToStr(Response.StatusCode));
      if Response.StatusCode = 200 then Result := Response.ContentAsString;
    except
      on E: Exception do
        Log('HTTP Hub Exception (Portal): ' + E.Message);
    end;
  finally
    HttpClient.Free;
  end;
end;
{$ELSE}
begin
  Result := '';
end;
{$ENDIF}

procedure TRpAuthManager.OpenUrl(const AUrl: string);
begin
{$IFDEF MSWINDOWS}
  if AUrl <> '' then ShellExecute(0, 'open', PChar(AUrl), nil, nil, SW_SHOWNORMAL);
{$ELSE}
  if AUrl <> '' then
    Log('OpenUrl is not supported on this platform: '+AUrl);
{$ENDIF}
end;

function TRpAuthManager.GetConfigFileName: string;
var
  LPath: string;
begin
  LPath := GetEnvironmentVariable('LOCALAPPDATA');
  if LPath = '' then LPath := TPath.GetHomePath;
  LPath := TPath.Combine(LPath, 'Reportman');
  if not TDirectory.Exists(LPath) then
    TDirectory.CreateDirectory(LPath);
  Result := TPath.Combine(LPath, 'reportman_auth.ini');
end;

procedure TRpAuthManager.SaveConfig;
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(GetConfigFileName);
  try
    LIni.WriteString('Auth', 'Token', FToken);
    LIni.WriteString('Auth', 'InstallId', FInstallId);
    
    LIni.WriteString('Profile', 'UserId', IntToStr(FProfile.UserId));
    LIni.WriteString('Profile', 'Email', FProfile.Email);
    LIni.WriteString('Profile', 'UserName', FProfile.UserName);
    LIni.WriteString('Profile', 'AvatarUrl', FProfile.AvatarUrl);
    LIni.WriteInteger('Profile', 'AccountType', FProfile.AccountType);
    LIni.WriteString('Profile', 'TierId', IntToStr(FProfile.TierId));
    LIni.WriteString('Profile', 'TierName', FProfile.TierName);
    LIni.WriteString('Profile', 'DailyMax', IntToStr(FProfile.DailyMax));
    LIni.WriteString('Profile', 'DailyConsumed', IntToStr(FProfile.DailyConsumed));
    LIni.WriteString('Profile', 'FreeInitial', IntToStr(FProfile.FreeInitial));
    LIni.WriteString('Profile', 'FreeRemaining', IntToStr(FProfile.FreeRemaining));
    LIni.WriteString('Profile', 'Credits', IntToStr(FProfile.Credits));
    LIni.WriteBool('Preferences', 'AIEnabled', FAIEnabled);
    LIni.WriteString('Preferences', 'AILanguage', FAILanguage);
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

procedure TRpAuthManager.LoadConfig;
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(GetConfigFileName);
  try
    FToken := LIni.ReadString('Auth', 'Token', '');
    FInstallId := LIni.ReadString('Auth', 'InstallId', FInstallId);
    
    FProfile.UserId := StrToInt64Def(LIni.ReadString('Profile', 'UserId', '0'), 0);
    FProfile.Email := LIni.ReadString('Profile', 'Email', '');
    FProfile.UserName := LIni.ReadString('Profile', 'UserName', '');
    FProfile.AvatarUrl := LIni.ReadString('Profile', 'AvatarUrl', '');
    FProfile.AccountType := LIni.ReadInteger('Profile', 'AccountType', 0);
    FProfile.TierId := StrToInt64Def(LIni.ReadString('Profile', 'TierId', '1'), 1);
    FProfile.TierName := LIni.ReadString('Profile', 'TierName', 'Guest');
    FProfile.DailyMax := StrToInt64Def(LIni.ReadString('Profile', 'DailyMax', '0'), 0);
    FProfile.DailyConsumed := StrToInt64Def(LIni.ReadString('Profile', 'DailyConsumed', '0'), 0);
    FProfile.FreeInitial := StrToInt64Def(LIni.ReadString('Profile', 'FreeInitial', '0'), 0);
    FProfile.FreeRemaining := StrToInt64Def(LIni.ReadString('Profile', 'FreeRemaining', '0'), 0);
    FProfile.Credits := StrToInt64Def(LIni.ReadString('Profile', 'Credits', '0'), 0);
    FAIEnabled := LIni.ReadBool('Preferences', 'AIEnabled', True);
    FAILanguage := NormalizeAILanguageValue(
      LIni.ReadString('Preferences', 'AILanguage', FAILanguage));
    
    FIsLoggedIn := FToken <> '';

    // Do not touch the network while constructing the singleton.
    // UI code triggers status refresh explicitly after the dialog is visible.
    if FIsLoggedIn then
      Log('LoadConfig: deferred CheckStatus until explicit background refresh.');
  finally
    LIni.Free;
  end;
end;

procedure TRpAuthManager.ClearConfig;
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(GetConfigFileName);
  try
    LIni.EraseSection('Auth');
    LIni.EraseSection('Profile');
    LIni.WriteBool('Preferences', 'AIEnabled', FAIEnabled);
    LIni.WriteString('Preferences', 'AILanguage', FAILanguage);
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

initialization
finalization
  if TRpAuthManager.FInstance <> nil then TRpAuthManager.FInstance.Free;
end.
