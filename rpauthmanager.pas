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
  SysUtils, Classes, System.JSON, System.NetEncoding,
{$IFDEF FIREDAC}
  System.Net.HttpClient, System.Net.HttpClientComponent,
{$ELSE}
  IdHTTP,
{$ENDIF}
  ShellAPI, rptypes, System.Generics.Collections;

type
  { TRpTier }
  TRpTier = record
    Id: Int64;
    Name: string;
    MonthlyPrice: Currency;
    YearlyPrice: Currency;
    MaxCreditsDay: Int64;
    MaxFreeCredits: Int64;
    MaxConnections: Integer;
    MaxTables: Integer;
    MaxKpis: Integer;
  end;

  { TRpUserProfile }
  TRpUserProfile = record
    UserId: Int64;
    Email: string;
    UserName: string;
    AvatarUrl: string;
    AccountType: Integer;
    Credits: Int64;
  end;

  { TRpAuthEvent }
  TRpAuthEvent = procedure(ASuccess: Boolean) of object;
  { TRpAuthLog }
  TRpAuthLog = procedure(const AMsg: string) of object;

  { TRpAuthManager }
  TRpAuthManager = class
  private
    FUrl: string;
    FToken: string;
    FInstallId: string;
    FProfile: TRpUserProfile;
    FTiers: TArray<TRpTier>;
    FIsLoggedIn: Boolean;
    FOnLog: TRpAuthLog;
    FAuthListeners: TList<TRpAuthEvent>;
    FOAuthCode: string;
    FOAuthError: string;
    FOAuthGotCallback: Boolean;

    class var FInstance: TRpAuthManager;
    constructor Create;
    procedure ParseTiers(ATiersArray: TJSONArray);
    procedure ParseProfile(AProfileObj: TJSONObject);
    function GenerateInstallId: string;
    procedure SetIsLoggedIn(Value: Boolean);
    procedure Log(const AMsg: string);
    function WaitForOAuthCallback(APort: Integer): Boolean;
    function ExchangeGoogleCode(const ACode, ARedirectUri: string): Boolean;
    function ExchangeMicrosoftCode(const ACode, ARedirectUri: string): Boolean;
    
    // Persistence
    function GetConfigFileName: string;
    procedure SaveConfig;
    procedure LoadConfig;
    procedure ClearConfig;

  public
    class function Instance: TRpAuthManager;
    destructor Destroy; override;

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

    procedure RegisterAuthListener(AListener: TRpAuthEvent);
    procedure UnregisterAuthListener(AListener: TRpAuthEvent);

    property Url: string read FUrl write FUrl;
    property Token: string read FToken;
    property InstallId: string read FInstallId write FInstallId;
    property Profile: TRpUserProfile read FProfile;
    property Tiers: TArray<TRpTier> read FTiers;
    property IsLoggedIn: Boolean read FIsLoggedIn;
    property OnLog: TRpAuthLog read FOnLog write FOnLog;
  end;

implementation

uses Winapi.Windows, Winapi.WinSock, Forms, IniFiles, IOUtils;

{ TRpAuthManager }

constructor TRpAuthManager.Create;
begin
  inherited Create;
{$IFDEF REPMANRELEASE}
  FUrl := 'https://api.reportman.es:44568';
{$ELSE}
  FUrl := 'https://api.reportman.es:7006';
{$ENDIF}
  FIsLoggedIn := False;
  FAuthListeners := TList<TRpAuthEvent>.Create;
  FInstallId := GenerateInstallId;
  LoadConfig;
end;

function TRpAuthManager.GenerateInstallId: string;
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

destructor TRpAuthManager.Destroy;
begin
  FAuthListeners.Free;
  inherited Destroy;
end;

procedure TRpAuthManager.Log(const AMsg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AMsg);
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
  if LValue <> nil then Self.FProfile.UserId := StrToInt64Def(LValue.Value, 0);

  LValue := AProfileObj.GetValue('email');
  if LValue = nil then LValue := AProfileObj.GetValue('Email');
  if LValue <> nil then Self.FProfile.Email := LValue.Value;

  LValue := AProfileObj.GetValue('userName');
  if LValue = nil then LValue := AProfileObj.GetValue('UserName');
  if LValue <> nil then Self.FProfile.UserName := LValue.Value;

  LValue := AProfileObj.GetValue('avatarUrl');
  if LValue = nil then LValue := AProfileObj.GetValue('AvatarUrl');
  if LValue <> nil then Self.FProfile.AvatarUrl := LValue.Value;

  LValue := AProfileObj.GetValue('accountType');
  if LValue = nil then LValue := AProfileObj.GetValue('AccountType');
  if LValue <> nil then Self.FProfile.AccountType := StrToIntDef(LValue.Value, 0);

  LValue := AProfileObj.GetValue('credits');
  if LValue = nil then LValue := AProfileObj.GetValue('Credits');
  if LValue <> nil then Self.FProfile.Credits := StrToInt64Def(LValue.Value, 0);

  Log('Profile Parsed: ' + Self.FProfile.Email);
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
    RequestBody := TJSONObject.Create;
    RequestBody.AddPair('email', AEmail);
    SourceStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      HttpClient.ContentType := 'application/json';
      try
        Response := HttpClient.Post(FUrl + '/api/LoginResend/send', SourceStream);
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
    RequestBody := TJSONObject.Create;
    RequestBody.AddPair('email', AEmail);
    RequestBody.AddPair('emailCode', ACode);
    RequestBody.AddPair('installId', FInstallId);
    
    SourceStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      HttpClient.ContentType := 'application/json';
      Response := HttpClient.Post(FUrl + '/api/Login/email', SourceStream);
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
    LListener(FIsLoggedIn);
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

function TRpAuthManager.WaitForOAuthCallback(APort: Integer): Boolean;
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
      Application.ProcessMessages;

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
          LResponse := LHttpClient.Post(FUrl + '/api/login/google', LSourceStream);
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
    Log('Step 1: Requesting Microsoft Access Token...');
    LSourceStream := TStringStream.Create(
      'client_id=' + TURLEncoding.URL.Encode('bc88d289-ded3-4389-a62b-2f12ad635dac') +
      '&code=' + TURLEncoding.URL.Encode(ACode) +
      '&redirect_uri=' + TURLEncoding.URL.Encode(ARedirectUri) +
      '&grant_type=authorization_code',
      TEncoding.UTF8);
    try
      LHttpClient.ContentType := 'application/x-www-form-urlencoded';
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
        Log('Step 2: Sending Microsoft Access Token to Hub API...');
        try
          LResponse := LHttpClient.Post(FUrl + '/api/login/microsoft', LSourceStream);
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

function TRpAuthManager.LoginMicrosoft: Boolean;
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
    try
      Response := HttpClient.Get(FUrl + '/api/Tiers');
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
    if FToken <> '' then HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
    RequestBody := TJSONObject.Create;
    RequestBody.AddPair('tierId', TJSONNumber.Create(ATierId));
    RequestBody.AddPair('isYearly', TJSONBool.Create(AIsYearly));
    RequestBody.AddPair('userEmail', Self.FProfile.Email);
    SourceStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      HttpClient.ContentType := 'application/json';
      try
        Response := HttpClient.Post(FUrl + '/api/stripe/subscribe', SourceStream);
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
    if FToken <> '' then HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
    try
      Response := HttpClient.Post(FUrl + '/api/stripe/portal', TStream(nil));
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
  if AUrl <> '' then ShellExecute(0, 'open', PChar(AUrl), nil, nil, SW_SHOWNORMAL);
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
    LIni.WriteString('Profile', 'Credits', IntToStr(FProfile.Credits));
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
    FProfile.Credits := StrToInt64Def(LIni.ReadString('Profile', 'Credits', '0'), 0);
    
    FIsLoggedIn := FToken <> '';
  finally
    LIni.Free;
  end;
end;

procedure TRpAuthManager.ClearConfig;
var
  LFile: string;
begin
  LFile := GetConfigFileName;
  if TFile.Exists(LFile) then
    TFile.Delete(LFile);
end;

initialization
finalization
  if TRpAuthManager.FInstance <> nil then TRpAuthManager.FInstance.Free;
end.
