{ Local HTTP(S) server for the tests (fphttpserver on 127.0.0.1, one thread
  per connection). A handler method answers each request; the server keeps
  a log of the requests, the last body and the last headers. }
unit ufakeserver;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, fphttpserver, httpdefs, ssockets, sslbase, opensslsockets;

type
  TFakeServer = class;

  TFakeHandler = procedure(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
    AResponse: TFPHTTPConnectionResponse) of object;

  // Makes the bind address and the connection count public
  TFakeHttpServer = class(TFPHttpServer)
  public
    property Address;
    property ConnectionCount;
  end;

  TFakeServerThread = class(TThread)
  private
    FOwner: TFakeServer;
    FError: string;
  protected
    procedure Execute; override;
  end;

  TFakeServer = class
  private
    FHttp: TFakeHttpServer;
    FThread: TFakeServerThread;
    FPort: Word;
    FUseSSL: Boolean;
    FCertFile: string;
    FKeyFile: string;
    FHandler: TFakeHandler;
    FLock: TRTLCriticalSection;
    FLog: TStringList;
    FLastBody: string;
    FLastHeaders: TStringList;
    FListening: Boolean;
    procedure DoRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
    procedure DoIdle(Sender: TObject);
  public
    constructor Create(AHandler: TFakeHandler; AUseSSL: Boolean = False;
      const ACertFile: string = ''; const AKeyFile: string = '');
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    function BaseURL(const AHost: string = '127.0.0.1'): string;
    function RequestLog: string;
    function RequestCount: Integer;
    function LastBody: string;
    function LastHeader(const AName: string): string;
    procedure ClearLog;
    property Port: Word read FPort;
  end;

procedure SendText(AResponse: TFPHTTPConnectionResponse; ACode: Integer;
  const AContentType, ABody: string);
procedure SendJson(AResponse: TFPHTTPConnectionResponse; ACode: Integer; const AJson: string);
// Server-Sent Events written piece by piece: "data: <event>" + blank line
// for each event, ADelayMs between events, chunked or closed-delimited
procedure SendEvents(AResponse: TFPHTTPConnectionResponse; const AEvents: array of string;
  ADelayMs: Integer; AChunked, ASendDone: Boolean);

implementation

type
  // Access to the protected connection of a response (raw socket writes)
  TResponseAccess = class(TFPHTTPConnectionResponse);

{ TFakeServerThread }

procedure TFakeServerThread.Execute;
begin
  try
    FOwner.FHttp.Active := True;
  except
    on E: Exception do
      FError := E.ClassName + ': ' + E.Message;
  end;
end;

{ TFakeServer }

constructor TFakeServer.Create(AHandler: TFakeHandler; AUseSSL: Boolean;
  const ACertFile, AKeyFile: string);
begin
  inherited Create;
  FHandler := AHandler;
  FUseSSL := AUseSSL;
  FCertFile := ACertFile;
  FKeyFile := AKeyFile;
  InitCriticalSection(FLock);
  FLog := TStringList.Create;
  FLastHeaders := TStringList.Create;
end;

destructor TFakeServer.Destroy;
begin
  Stop;
  FLog.Free;
  FLastHeaders.Free;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

procedure TFakeServer.DoIdle(Sender: TObject);
begin
  FListening := True;
end;

procedure TFakeServer.Start;
var
  LAttempt: Integer;
  LStart: QWord;
begin
  for LAttempt := 1 to 20 do
  begin
    FPort := 20000 + Random(30000);
    FListening := False;
    FHttp := TFakeHttpServer.Create(nil);
    FHttp.Address := '127.0.0.1';
    FHttp.Port := FPort;
    FHttp.Threaded := True;
    FHttp.AcceptIdleTimeout := 50;
    FHttp.OnAcceptIdle := DoIdle;
    FHttp.OnRequest := DoRequest;
    if FUseSSL then
    begin
      FHttp.UseSSL := True;
      FHttp.CertificateData.Certificate.FileName := FCertFile;
      FHttp.CertificateData.PrivateKey.FileName := FKeyFile;
    end;
    FThread := TFakeServerThread.Create(True);
    FThread.FOwner := Self;
    FThread.FreeOnTerminate := False;
    FThread.Start;
    LStart := GetTickCount64;
    while (not FListening) and (not FThread.Finished) and (GetTickCount64 - LStart < 5000) do
      Sleep(10);
    if FListening then
      Exit;
    // Port in use (or other bind error): try another one
    FThread.WaitFor;
    FreeAndNil(FThread);
    FreeAndNil(FHttp);
  end;
  raise Exception.Create('The fake server could not start');
end;

procedure TFakeServer.Stop;
var
  LStart: QWord;
begin
  if FHttp = nil then
    Exit;
  try
    FHttp.Active := False;
  except
  end;
  if FThread <> nil then
  begin
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  // Let connection threads (slow handlers) finish
  LStart := GetTickCount64;
  while (FHttp.ConnectionCount > 0) and (GetTickCount64 - LStart < 10000) do
    Sleep(20);
  FreeAndNil(FHttp);
end;

function TFakeServer.BaseURL(const AHost: string): string;
begin
  if FUseSSL then
    Result := 'https://' + AHost + ':' + IntToStr(FPort)
  else
    Result := 'http://' + AHost + ':' + IntToStr(FPort);
end;

procedure TFakeServer.DoRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
var
  I: Integer;
  N, V: string;
begin
  EnterCriticalSection(FLock);
  try
    FLog.Add(ARequest.Method + ' ' + ARequest.PathInfo);
    FLastBody := ARequest.Content;
    FLastHeaders.Clear;
    for I := 0 to ARequest.CustomHeaders.Count - 1 do
    begin
      ARequest.CustomHeaders.GetNameValue(I, N, V);
      FLastHeaders.Add(LowerCase(N) + '=' + V);
    end;
    FLastHeaders.Add('content-type=' + ARequest.ContentType);
    FLastHeaders.Add('authorization=' + ARequest.Authorization);
    FLastHeaders.Add('accept=' + ARequest.Accept);
    FLastHeaders.Add('user-agent=' + ARequest.UserAgent);
    FLastHeaders.Add('content-length=' + IntToStr(ARequest.ContentLength));
  finally
    LeaveCriticalSection(FLock);
  end;
  if Assigned(FHandler) then
    FHandler(Self, ARequest, AResponse)
  else
    SendText(AResponse, 404, 'text/plain', 'no handler');
end;

function TFakeServer.RequestLog: string;
begin
  EnterCriticalSection(FLock);
  try
    Result := StringReplace(Trim(FLog.Text), sLineBreak, ';', [rfReplaceAll]);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TFakeServer.RequestCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FLog.Count;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TFakeServer.LastBody: string;
begin
  EnterCriticalSection(FLock);
  try
    Result := FLastBody;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TFakeServer.LastHeader(const AName: string): string;
begin
  EnterCriticalSection(FLock);
  try
    Result := FLastHeaders.Values[LowerCase(AName)];
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TFakeServer.ClearLog;
begin
  EnterCriticalSection(FLock);
  try
    FLog.Clear;
    FLastBody := '';
    FLastHeaders.Clear;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

{ Helpers }

procedure SendText(AResponse: TFPHTTPConnectionResponse; ACode: Integer;
  const AContentType, ABody: string);
begin
  AResponse.Code := ACode;
  AResponse.ContentType := AContentType;
  AResponse.FreeContentStream := True;
  AResponse.ContentStream := TStringStream.Create(ABody);
  AResponse.ContentLength := Length(ABody);
  AResponse.SendContent;
end;

procedure SendJson(AResponse: TFPHTTPConnectionResponse; ACode: Integer; const AJson: string);
begin
  SendText(AResponse, ACode, 'application/json; charset=utf-8', AJson);
end;

procedure SendEvents(AResponse: TFPHTTPConnectionResponse; const AEvents: array of string;
  ADelayMs: Integer; AChunked, ASendDone: Boolean);
var
  I: Integer;
  LSocket: TSocketStream;

  procedure Put(const S: string);
  var
    LFrame: string;
  begin
    if AChunked then
      LFrame := IntToHex(Length(S), 1) + #13#10 + S + #13#10
    else
      LFrame := S;
    if LFrame <> '' then
      LSocket.WriteBuffer(LFrame[1], Length(LFrame));
  end;

begin
  AResponse.Code := 200;
  AResponse.ContentType := 'text/event-stream';
  if AChunked then
    AResponse.SetCustomHeader('Transfer-Encoding', 'chunked');
  AResponse.SetCustomHeader('Cache-Control', 'no-cache');
  AResponse.SendHeaders;
  LSocket := TResponseAccess(AResponse).Connection.Socket;
  try
    for I := Low(AEvents) to High(AEvents) do
    begin
      Put('data: ' + AEvents[I] + #10#10);
      if ADelayMs > 0 then
        Sleep(ADelayMs);
    end;
    if ASendDone then
      Put('data: [DONE]'#10#10);
    if AChunked then
      LSocket.WriteBuffer(PChar('0'#13#10#13#10)^, 5);
  except
    // The client went away (cancel test)
  end;
end;

initialization
  Randomize;
end.
