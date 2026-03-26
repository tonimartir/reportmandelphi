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
  ShellAPI, rptypes;

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
    FOnAuthChanged: TRpAuthEvent;
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

    property Url: string read FUrl write FUrl;
    property Token: string read FToken;
    property InstallId: string read FInstallId write FInstallId;
    property Profile: TRpUserProfile read FProfile;
    property Tiers: TArray<TRpTier> read FTiers;
    property IsLoggedIn: Boolean read FIsLoggedIn;
    property OnAuthChanged: TRpAuthEvent read FOnAuthChanged write FOnAuthChanged;
    property OnLog: TRpAuthLog read FOnLog write FOnLog;
  end;

implementation

uses Winapi.Windows, Winapi.WinSock, Forms;

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
  FInstallId := GenerateInstallId;
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
  if LValue <> nil then FProfile.UserId := StrToInt64Def(LValue.Value, 0);

  LValue := AProfileObj.GetValue('email');
  if LValue = nil then LValue := AProfileObj.GetValue('Email');
  if LValue <> nil then FProfile.Email := LValue.Value;

  LValue := AProfileObj.GetValue('userName');
  if LValue = nil then LValue := AProfileObj.GetValue('UserName');
  if LValue <> nil then FProfile.UserName := LValue.Value;

  LValue := AProfileObj.GetValue('accountType');
  if LValue = nil then LValue := AProfileObj.GetValue('AccountType');
  if LValue <> nil then FProfile.AccountType := StrToIntDef(LValue.Value, 0);

  LValue := AProfileObj.GetValue('credits');
  if LValue = nil then LValue := AProfileObj.GetValue('Credits');
  if LValue <> nil then FProfile.Credits := StrToInt64Def(LValue.Value, 0);

  Log('Profile Parsed: ' + FProfile.Email);
end;

procedure TRpAuthManager.ParseTiers(ATiersArray: TJSONArray);
var
  I: Integer;
  TierObj: TJSONObject;
  LValue: TJSONValue;
begin
  if ATiersArray = nil then Exit;
  Log('Parsing Tiers (' + IntToStr(ATiersArray.Count) + ' found)...');
  SetLength(FTiers, ATiersArray.Count);
  for I := 0 to ATiersArray.Count - 1 do
  begin
    TierObj := ATiersArray.Items[I] as TJSONObject;
    
    LValue := TierObj.GetValue('id');
    if LValue = nil then LValue := TierObj.GetValue('Id');
    if LValue <> nil then FTiers[I].Id := StrToInt64Def(LValue.Value, 0);

    LValue := TierObj.GetValue('name');
    if LValue = nil then LValue := TierObj.GetValue('Name');
    if LValue <> nil then FTiers[I].Name := LValue.Value;

    LValue := TierObj.GetValue('monthlyPrice');
    if LValue = nil then LValue := TierObj.GetValue('MonthlyPrice');
    if LValue <> nil then FTiers[I].MonthlyPrice := StrToFloatDef(LValue.Value, 0);

    LValue := TierObj.GetValue('yearlyPrice');
    if LValue = nil then LValue := TierObj.GetValue('YearlyPrice');
    if LValue <> nil then FTiers[I].YearlyPrice := StrToFloatDef(LValue.Value, 0);

    LValue := TierObj.GetValue('maxCreditsDay');
    if LValue = nil then LValue := TierObj.GetValue('MaxCreditsDay');
    if LValue <> nil then FTiers[I].MaxCreditsDay := StrToInt64Def(LValue.Value, 0);

    LValue := TierObj.GetValue('maxFreeCredits');
    if LValue = nil then LValue := TierObj.GetValue('MaxFreeCredits');
    if LValue <> nil then FTiers[I].MaxFreeCredits := StrToInt64Def(LValue.Value, 0);

    LValue := TierObj.GetValue('maxConnections');
    if LValue = nil then LValue := TierObj.GetValue('MaxConnections');
    if LValue <> nil then FTiers[I].MaxConnections := StrToIntDef(LValue.Value, 0);

    LValue := TierObj.GetValue('maxTables');
    if LValue = nil then LValue := TierObj.GetValue('MaxTables');
    if LValue <> nil then FTiers[I].MaxTables := StrToIntDef(LValue.Value, 0);

    LValue := TierObj.GetValue('maxKpis');
    if LValue = nil then LValue := TierObj.GetValue('MaxKpis');
    if LValue <> nil then FTiers[I].MaxKpis := StrToIntDef(LValue.Value, 0);
  end;
end;

function TRpAuthManager.RequestLoginCode(const AEmail: string): Boolean;
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
      Response := HttpClient.Post(FUrl + '/api/LoginResend/send', SourceStream);
      Result := Response.StatusCode = 200;
    finally
      SourceStream.Free;
      RequestBody.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;

function TRpAuthManager.LoginWithCode(const AEmail, ACode: string): Boolean;
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

procedure TRpAuthManager.Logout;
begin
  FToken := '';
  FProfile := Default(TRpUserProfile);
  FTiers := [];
  SetIsLoggedIn(False);
end;

procedure TRpAuthManager.SetIsLoggedIn(Value: Boolean);
begin
  if FIsLoggedIn <> Value then
  begin
    FIsLoggedIn := Value;
    if Assigned(FOnAuthChanged) then
      FOnAuthChanged(FIsLoggedIn);
  end;
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

  // Create listening TCP socket
  LListenSocket := Winapi.WinSock.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if LListenSocket = INVALID_SOCKET then Exit;
  try
    FillChar(LAddr, SizeOf(LAddr), 0);
    LAddr.sin_family := AF_INET;
    LAddr.sin_addr.S_addr := htonl(INADDR_LOOPBACK);
    LAddr.sin_port := htons(APort);

    Log('Loopback server listening on port ' + IntToStr(APort) + '...');
    if bind(LListenSocket, PSockAddr(@LAddr)^, SizeOf(LAddr)) = SOCKET_ERROR then Exit;
    if listen(LListenSocket, 1) = SOCKET_ERROR then Exit;

    // Wait for connection with timeout (5 min)
    LStartTime := Now;
    while (not FOAuthGotCallback) and ((Now - LStartTime) < (5 / 24 / 60)) do
    begin
      Application.ProcessMessages;

      FD_ZERO(LFDSet);
      FD_SET(LListenSocket, LFDSet);
      LTimeout.tv_sec := 0;
      LTimeout.tv_usec := 200000; // 200ms

      if select(0, @LFDSet, nil, nil, @LTimeout) > 0 then
      begin
        LAddrLen := SizeOf(LAddr);
        LClientSocket := accept(LListenSocket, PSockAddr(@LAddr), @LAddrLen);
        if LClientSocket <> INVALID_SOCKET then
        try
          // Read request
          LBytesRead := recv(LClientSocket, LBuf[0], SizeOf(LBuf) - 1, 0);
          if LBytesRead > 0 then
          begin
            LBuf[LBytesRead] := #0;
            LRequest := string(PAnsiChar(@LBuf[0]));

            // Parse "GET /?code=XXX&state=YYY HTTP/1.1"
            // Skip favicon
            if Pos('/favicon.ico', LRequest) > 0 then
            begin
              LResponseHtml := 'HTTP/1.1 404 Not Found'#13#10'Content-Length: 0'#13#10#13#10;
              send(LClientSocket, PAnsiChar(AnsiString(LResponseHtml))^, Length(AnsiString(LResponseHtml)), 0);
              Continue;
            end;

            // Extract query string
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
                    FOAuthCode := LPairs.ValueFromIndex[i]
                  else if SameText(LPairs.Names[i], 'error') then
                    FOAuthError := LPairs.ValueFromIndex[i];
                end;
              finally
                LPairs.Free;
              end;

              if (FOAuthCode <> '') or (FOAuthError <> '') then
              begin
                FOAuthGotCallback := True;
                // Send HTML response
                if FOAuthError <> '' then
                  LResponseHtml := '<html><body><h1 style="color:red;text-align:center;">Login failed</h1>' +
                    '<p style="text-align:center;">' + FOAuthError + '</p></body></html>'
                else
                  LResponseHtml := '<html><body><h1 style="color:green;text-align:center;">Login successful!</h1>' +
                    '<p style="text-align:center;">You can close this window.</p>' +
                    '<script>window.close();</script></body></html>';
                LResponseHtml := 'HTTP/1.1 200 OK'#13#10 +
                  'Content-Type: text/html; charset=utf-8'#13#10 +
                  'Content-Length: ' + IntToStr(Length(UTF8Encode(LResponseHtml))) + #13#10 +
                  'Connection: close'#13#10#13#10 +
                  LResponseHtml;
                send(LClientSocket, PAnsiChar(AnsiString(LResponseHtml))^, Length(AnsiString(LResponseHtml)), 0);
              end;
            end;
          end;
        finally
          closesocket(LClientSocket);
        end;
      end;
    end;

    Result := FOAuthGotCallback and (FOAuthCode <> '') and (FOAuthError = '');
  finally
    closesocket(LListenSocket);
  end;
end;

function TRpAuthManager.ExchangeGoogleCode(const ACode, ARedirectUri: string): Boolean;
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
        LResponse := LHttpClient.Post(FUrl + '/api/login/google', LSourceStream);
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
            if FToken <> '' then
              Log('Google Login SUCCESS. Token received.')
            else
              Log('Google Login FAILURE: Token was empty in response.');
            Result := FToken <> '';
          finally
            LResponseJson.Free;
          end;
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

function TRpAuthManager.ExchangeMicrosoftCode(const ACode, ARedirectUri: string): Boolean;
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
    Log('Step 1: Requesting Microsoft Access Token (no secret needed)...');
    LSourceStream := TStringStream.Create(
      'client_id=' + TNetEncoding.URL.Encode('bc88d289-ded3-4389-a62b-2f12ad635dac') +
      '&code=' + TNetEncoding.URL.Encode(ACode) +
      '&redirect_uri=' + TNetEncoding.URL.Encode(ARedirectUri) +
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
          if LValue <> nil then
            LAccessToken := LValue.Value;
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
        LResponse := LHttpClient.Post(FUrl + '/api/login/microsoft', LSourceStream);
        if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300) then
        begin
          Log('Hub API accepted Microsoft login.');
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
          finally
            LResponseJson.Free;
          end;
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

    LState := IntToHex(Random(MaxInt), 8) + IntToHex(Random(MaxInt), 8);
    LAuthUrl := 'https://accounts.google.com/o/oauth2/v2/auth?' +
      'response_type=code&' +
      'scope=openid%20profile%20email&' +
      'redirect_uri=' + TNetEncoding.URL.Encode(LRedirectUri) + '&' +
      'client_id=' + GOOGLE_CLIENT_ID + '&' +
      'state=' + LState;

    ShellExecute(0, 'open', PChar(LAuthUrl), nil, nil, SW_SHOWNORMAL);

    if WaitForOAuthCallback(LPort) then
      Result := ExchangeGoogleCode(FOAuthCode, LRedirectUri);
  finally
    WSACleanup;
  end;
end;

function TRpAuthManager.LoginMicrosoft: Boolean;
const
  MS_CLIENT_ID = 'bc88d289-ded3-4389-a62b-2f12ad635dac';
  MS_TENANT = 'common';
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

    LState := IntToHex(Random(MaxInt), 8) + IntToHex(Random(MaxInt), 8);
    LAuthUrl := 'https://login.microsoftonline.com/' + MS_TENANT + '/oauth2/v2.0/authorize?' +
      'response_type=code&' +
      'scope=openid%20profile%20email%20user.read&' +
      'redirect_uri=' + TNetEncoding.URL.Encode(LRedirectUri) + '&' +
      'client_id=' + MS_CLIENT_ID + '&' +
      'state=' + LState;

    ShellExecute(0, 'open', PChar(LAuthUrl), nil, nil, SW_SHOWNORMAL);

    if WaitForOAuthCallback(LPort) then
      Result := ExchangeMicrosoftCode(FOAuthCode, LRedirectUri);
  finally
    WSACleanup;
  end;
end;

function TRpAuthManager.RefreshTiers: Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  ResponseJsonTable: TJSONValue;
  ResponseJsonArray: TJSONArray;
begin
  Result := False;
  HttpClient := TNetHTTPClient.Create(nil);
  try
    Response := HttpClient.Get(FUrl + '/api/Tiers');
    if Response.StatusCode = 200 then
    begin
      ResponseJsonTable := TJSONObject.ParseJSONValue(Response.ContentAsString);
      if ResponseJsonTable is TJSONArray then
      begin
        ResponseJsonArray := TJSONArray(ResponseJsonTable);
        try
          ParseTiers(ResponseJsonArray);
          Result := True;
        finally
          // ParseTiers doesn't take ownership
        end;
      end;
      if ResponseJsonTable <> nil then
        ResponseJsonTable.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;

function TRpAuthManager.GetCheckoutUrl(ATierId: Int64; AIsYearly: Boolean): string;
var
  HttpClient: TNetHTTPClient;
  RequestBody: TJSONObject;
  SourceStream: TStringStream;
  Response: IHTTPResponse;
begin
  Result := '';
  HttpClient := TNetHTTPClient.Create(nil);
  try
    if FToken <> '' then
       HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;

    RequestBody := TJSONObject.Create;
    RequestBody.AddPair('tierId', TJSONNumber.Create(ATierId));
    RequestBody.AddPair('isYearly', TJSONBool.Create(AIsYearly));
    RequestBody.AddPair('userEmail', TJSONString.Create(FProfile.Email));
    
    SourceStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      HttpClient.ContentType := 'application/json';
      Response := HttpClient.Post(FUrl + '/api/stripe/subscribe', SourceStream);
      if Response.StatusCode = 200 then
        Result := Response.ContentAsString;
    finally
      SourceStream.Free;
      RequestBody.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;

function TRpAuthManager.GetPortalUrl: string;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
begin
  Result := '';
  HttpClient := TNetHTTPClient.Create(nil);
  try
    if FToken <> '' then
       HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;

    Response := HttpClient.Post(FUrl + '/api/stripe/portal', TStream(nil));
    if Response.StatusCode = 200 then
      Result := Response.ContentAsString;
  finally
    HttpClient.Free;
  end;
end;

procedure TRpAuthManager.OpenUrl(const AUrl: string);
begin
  if AUrl <> '' then
    ShellExecute(0, 'open', PChar(AUrl), nil, nil, SW_SHOWNORMAL);
end;

initialization
finalization
  if TRpAuthManager.FInstance <> nil then
    TRpAuthManager.FInstance.Free;

end.
