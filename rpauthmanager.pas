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

  { TRpAuthManager }
  TRpAuthEvent = procedure(ASuccess: Boolean) of object;

  TRpAuthManager = class
  private
    FUrl: string;
    FToken: string;
    FInstallId: string;
    FProfile: TRpUserProfile;
    FTiers: TArray<TRpTier>;
    FIsLoggedIn: Boolean;
    FOnAuthChanged: TRpAuthEvent;
    // OAuth callback state
    FOAuthCode: string;
    FOAuthError: string;
    FOAuthGotCallback: Boolean;

    class var FInstance: TRpAuthManager;
    constructor Create;
    procedure ParseTiers(ATiersArray: TJSONArray);
    procedure ParseProfile(AProfileObj: TJSONObject);
    function GenerateInstallId: string;
    procedure SetIsLoggedIn(Value: Boolean);
    function WaitForOAuthCallback(APort: Integer): Boolean;
    function ExchangeGoogleCode(const ACode, ARedirectUri: string): Boolean;
    function ExchangeMicrosoftCode(const ACode: string): Boolean;

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

class function TRpAuthManager.Instance: TRpAuthManager;
begin
  if FInstance = nil then
    FInstance := TRpAuthManager.Create;
  Result := FInstance;
end;

procedure TRpAuthManager.ParseProfile(AProfileObj: TJSONObject);
begin
  if AProfileObj = nil then Exit;
  FProfile.UserId := (AProfileObj.Values['userId'] as TJSONNumber).AsInt64;
  FProfile.Email := AProfileObj.Values['email'].Value;
  FProfile.UserName := AProfileObj.Values['userName'].Value;
  FProfile.AccountType := (AProfileObj.Values['accountType'] as TJSONNumber).AsInt;
  if AProfileObj.Values['credits'] <> nil then
    FProfile.Credits := (AProfileObj.Values['credits'] as TJSONNumber).AsInt64;
end;

procedure TRpAuthManager.ParseTiers(ATiersArray: TJSONArray);
var
  I: Integer;
  TierObj: TJSONObject;
begin
  SetLength(FTiers, ATiersArray.Count);
  for I := 0 to ATiersArray.Count - 1 do
  begin
    TierObj := ATiersArray.Items[I] as TJSONObject;
    FTiers[I].Id := (TierObj.Values['id'] as TJSONNumber).AsInt64;
    FTiers[I].Name := TierObj.Values['name'].Value;
    FTiers[I].MonthlyPrice := (TierObj.Values['monthlyPrice'] as TJSONNumber).AsDouble;
    FTiers[I].YearlyPrice := (TierObj.Values['yearlyPrice'] as TJSONNumber).AsDouble;
    FTiers[I].MaxCreditsDay := (TierObj.Values['maxCreditsDay'] as TJSONNumber).AsInt64;
    FTiers[I].MaxFreeCredits := (TierObj.Values['maxFreeCredits'] as TJSONNumber).AsInt64;
    FTiers[I].MaxConnections := (TierObj.Values['maxConnections'] as TJSONNumber).AsInt;
    FTiers[I].MaxTables := (TierObj.Values['maxTables'] as TJSONNumber).AsInt;
    FTiers[I].MaxKpis := (TierObj.Values['maxKpis'] as TJSONNumber).AsInt;
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
        try
          FToken := ResponseJson.Values['token'].Value;
          ParseProfile(ResponseJson.Values['profile'] as TJSONObject);
          ParseTiers(ResponseJson.Values['tiers'] as TJSONArray);
          SetIsLoggedIn(True);
          Result := True;
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
  LPosQ, LPosSpace: Integer;
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

    if bind(LListenSocket, LAddr, SizeOf(LAddr)) = SOCKET_ERROR then Exit;
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
        LClientSocket := accept(LListenSocket, @LAddr, @LAddrLen);
        if LClientSocket <> INVALID_SOCKET then
        try
          // Read request
          LBytesRead := recv(LClientSocket, LBuf[0], SizeOf(LBuf) - 1, 0);
          if LBytesRead > 0 then
          begin
            LBuf[LBytesRead] := #0;
            LRequest := string(PAnsiChar(@LBuf[0]));

            // Parse "GET /?code=XXX&state=YYY HTTP/1.1"
            // or    "GET /?error=access_denied HTTP/1.1"
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
                FOAuthCode := LPairs.Values['code'];
                FOAuthError := LPairs.Values['error'];
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
        LResponse := LHttpClient.Post(FUrl + '/api/login/google', LSourceStream);
        if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300) then
        begin
          LResponseJson := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
          if LResponseJson <> nil then
          try
            FToken := LResponseJson.Values['token'].Value;
            ParseProfile(LResponseJson.Values['profile'] as TJSONObject);
            if LResponseJson.Values['tiers'] is TJSONArray then
              ParseTiers(LResponseJson.Values['tiers'] as TJSONArray);
            SetIsLoggedIn(True);
            Result := True;
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

function TRpAuthManager.ExchangeMicrosoftCode(const ACode: string): Boolean;
var
  LHttpClient: TNetHTTPClient;
  LRequest: TJSONObject;
  LSourceStream: TStringStream;
  LResponse: IHTTPResponse;
  LResponseJson: TJSONObject;
begin
  Result := False;
  LHttpClient := TNetHTTPClient.Create(nil);
  try
    LRequest := TJSONObject.Create;
    try
      LRequest.AddPair('microsoftCode', ACode);
      LRequest.AddPair('installId', FInstallId);
      LSourceStream := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
      try
        LHttpClient.ContentType := 'application/json';
        LResponse := LHttpClient.Post(FUrl + '/api/login/microsoft', LSourceStream);
        if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300) then
        begin
          LResponseJson := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
          if LResponseJson <> nil then
          try
            FToken := LResponseJson.Values['token'].Value;
            ParseProfile(LResponseJson.Values['profile'] as TJSONObject);
            if LResponseJson.Values['tiers'] is TJSONArray then
              ParseTiers(LResponseJson.Values['tiers'] as TJSONArray);
            SetIsLoggedIn(True);
            Result := True;
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
    LRedirectUri := 'http://127.0.0.1:' + IntToStr(LPort) + '/';

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
    LRedirectUri := 'http://127.0.0.1:' + IntToStr(LPort) + '/';

    LState := IntToHex(Random(MaxInt), 8) + IntToHex(Random(MaxInt), 8);
    LAuthUrl := 'https://login.microsoftonline.com/' + MS_TENANT + '/oauth2/v2.0/authorize?' +
      'response_type=code&' +
      'scope=openid%20profile%20email%20user.read&' +
      'redirect_uri=' + TNetEncoding.URL.Encode(LRedirectUri) + '&' +
      'client_id=' + MS_CLIENT_ID + '&' +
      'state=' + LState;

    ShellExecute(0, 'open', PChar(LAuthUrl), nil, nil, SW_SHOWNORMAL);

    if WaitForOAuthCallback(LPort) then
      Result := ExchangeMicrosoftCode(FOAuthCode);
  finally
    WSACleanup;
  end;
end;


function TRpAuthManager.RefreshTiers: Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  ResponseJson: TJSONArray;
begin
  Result := False;
  HttpClient := TNetHTTPClient.Create(nil);
  try
    Response := HttpClient.Get(FUrl + '/api/Tiers');
    if Response.StatusCode = 200 then
    begin
      ResponseJson := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONArray;
      try
        ParseTiers(ResponseJson);
        Result := True;
      finally
        ResponseJson.Free;
      end;
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
    RequestBody.AddPair('userEmail', FProfile.Email);
    
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
