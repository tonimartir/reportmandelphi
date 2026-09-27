{ Tests of rphttpclientfpc (TNetHTTPClient shim) against a local
  fphttpserver on 127.0.0.1: methods, headers, bodies, status codes,
  redirects, timeouts, charsets, streaming with OnReceiveData, cancel,
  the OAuth loopback listener and, when OpenSSL and the openssl command are
  available, TLS certificate verification against a local HTTPS server. }
unit uhttptests;

{$mode delphi}{$H+}

interface

procedure RunHttpTests;

implementation

uses
  {$IFDEF UNIX}baseunix,{$ENDIF}
  SysUtils, Classes, process, ssockets, fphttpserver, httpdefs, rpjsonfpc, rphttpclientfpc,
  utestutil, ufakeserver, ujsoncases;

type
  THttpRoutes = class
  public
    procedure Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
      AResponse: TFPHTTPConnectionResponse);
  end;

  // Mimics rpdatahttp's stream context: reads the new bytes of the response
  // stream on each OnReceiveData call
  TStreamWatcher = class
  public
    Stream: TMemoryStream;
    LastPos: Int64;
    Text: string;
    Calls: Integer;
    EventsSeenDuringRequest: Integer;
    FirstCallTick: QWord;
    AbortAfterCalls: Integer;
    procedure ReceiveData(const Sender: TObject; AContentLength, AReadCount: Int64;
      var AAbort: Boolean);
  end;

  TLoopbackClient = class(TThread)
  public
    Port: Word;
    FaviconStatus: Integer;
    Status: Integer;
    Body: string;
    Error: string;
  protected
    procedure Execute; override;
  end;

  TLoopbackHandler = class
  public
    Query: string;
    procedure Handle(const APath, AQuery: string; var AStatusCode: Integer;
      var AContentType, AResponseBody: string; var ADone: Boolean);
  end;

  TCertAcceptor = class
  public
    Calls: Integer;
    Subject: string;
    Error: Integer;
    Accept: Boolean;
    procedure Validate(const Sender: TObject; const ARequest: TURLRequest;
      const Certificate: TCertificate; var Accepted: Boolean);
  end;

var
  GServer: TFakeServer;

function CountEvents(const S: string): Integer;
var
  P: Integer;
  LRest: string;
begin
  Result := 0;
  LRest := S;
  P := Pos('data: {', LRest);
  while P > 0 do
  begin
    Inc(Result);
    LRest := Copy(LRest, P + 7, MaxInt);
    P := Pos('data: {', LRest);
  end;
end;

{ THttpRoutes }

procedure THttpRoutes.Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
  AResponse: TFPHTTPConnectionResponse);
var
  P: string;
  LObj: TJSONObject;
  LEvents: array of string;
  I: Integer;
begin
  P := ARequest.PathInfo;
  if P = '/hello' then
    SendText(AResponse, 200, 'text/plain', 'Hello ' + ARequest.GetFieldByName('X-Test'))
  else if P = '/echo' then
  begin
    LObj := TJSONObject.Create;
    try
      LObj.AddPair('method', ARequest.Method);
      LObj.AddPair('body', ARequest.Content);
      LObj.AddPair('contentType', ARequest.ContentType);
      LObj.AddPair('authorization', ARequest.Authorization);
      LObj.AddPair('accept', ARequest.Accept);
      LObj.AddPair('custom', ARequest.GetFieldByName('X-Custom'));
      LObj.AddPair('userAgent', ARequest.UserAgent);
      LObj.AddPair('query', ARequest.QueryString);
      SendJson(AResponse, 200, LObj.ToJSON);
    finally
      LObj.Free;
    end;
  end
  else if Copy(P, 1, 8) = '/status/' then
    SendText(AResponse, StrToIntDef(Copy(P, 9, 3), 500), 'text/plain', 'status body')
  else if P = '/redirect' then
  begin
    AResponse.Code := 302;
    AResponse.SetCustomHeader('Location', '/hello');
    AResponse.ContentLength := 0;
    AResponse.SendContent;
  end
  else if P = '/slow' then
  begin
    Sleep(3000);
    SendText(AResponse, 200, 'text/plain', 'late');
  end
  else if P = '/big' then
    SendText(AResponse, 200, 'application/octet-stream', StringOfChar('x', 1000000))
  else if P = '/utf8' then
    SendText(AResponse, 200, 'text/plain; charset=utf-8', CP([$F1, $20AC]))
  else if P = '/latin1' then
    SendText(AResponse, 200, 'text/plain; charset=iso-8859-1', #$F1)
  else if P = '/stream' then
  begin
    SetLength(LEvents, 5);
    for I := 0 to 4 do
      LEvents[I] := '{"n":' + IntToStr(I) + '}';
    SendEvents(AResponse, LEvents, 300, Pos('chunked=1', ARequest.QueryString) > 0, True);
  end
  else if P = '/endless' then
  begin
    SetLength(LEvents, 100);
    for I := 0 to 99 do
      LEvents[I] := '{"n":' + IntToStr(I) + '}';
    SendEvents(AResponse, LEvents, 100, True, True);
  end
  else
    SendText(AResponse, 404, 'text/plain', 'not found');
end;

{ TStreamWatcher }

procedure TStreamWatcher.ReceiveData(const Sender: TObject; AContentLength,
  AReadCount: Int64; var AAbort: Boolean);
var
  LNew: string;
  LCount: Int64;
begin
  Inc(Calls);
  if Calls = 1 then
    FirstCallTick := GetTickCount64;
  LCount := Stream.Size - LastPos;
  if LCount > 0 then
  begin
    SetLength(LNew, LCount);
    Stream.Position := LastPos;
    Stream.ReadBuffer(LNew[1], LCount);
    Inc(LastPos, LCount);
    Text := Text + LNew;
  end;
  EventsSeenDuringRequest := CountEvents(Text);
  if (AbortAfterCalls > 0) and (Calls >= AbortAfterCalls) then
    AAbort := True;
end;

{ TLoopbackClient }

procedure TLoopbackClient.Execute;
var
  LClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
begin
  Sleep(300);
  LClient := TNetHTTPClient.Create(nil);
  try
    try
      LResponse := LClient.Get('http://127.0.0.1:' + IntToStr(Port) + '/favicon.ico');
      FaviconStatus := LResponse.StatusCode;
      LResponse := LClient.Get('http://127.0.0.1:' + IntToStr(Port) +
        '/?state=s1&code=abc%20d%2Fe');
      Status := LResponse.StatusCode;
      Body := LResponse.ContentAsString;
    except
      on E: Exception do
        Error := E.Message;
    end;
  finally
    LClient.Free;
  end;
end;

{ TLoopbackHandler }

procedure TLoopbackHandler.Handle(const APath, AQuery: string; var AStatusCode: Integer;
  var AContentType, AResponseBody: string; var ADone: Boolean);
begin
  Query := AQuery;
  AStatusCode := 200;
  AResponseBody := '<html><body>ok</body></html>';
  ADone := Pos('code=', AQuery) > 0;
end;

{ TCertAcceptor }

procedure TCertAcceptor.Validate(const Sender: TObject; const ARequest: TURLRequest;
  const Certificate: TCertificate; var Accepted: Boolean);
begin
  Inc(Calls);
  Subject := Certificate.Subject;
  Error := Certificate.VerifyError;
  Accepted := Accept;
end;

{ Tests }

procedure BasicTests;
var
  LClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LBody: TStringStream;
  LEcho: TJSONObject;
  LForm: TStringList;
  LStream: TMemoryStream;
  LStart: QWord;
  LRaised: Boolean;
  LMessage: string;
begin
  Section('HTTP client: requests and responses');
  LClient := TNetHTTPClient.Create(nil);
  try
    LClient.CustomHeaders['X-Test'] := 'abc';
    LResponse := LClient.Get(GServer.BaseURL + '/hello');
    CheckEquals(200, LResponse.StatusCode, 'GET status');
    CheckEquals('OK', LResponse.StatusText, 'GET status text');
    CheckEquals('Hello abc', LResponse.ContentAsString, 'GET body and custom header');
    CheckEquals('text/plain', LResponse.MimeType, 'response Content-Type');
    Check(LResponse.ContainsHeader('content-length'), 'response headers');
    LClient.CustomHeaders['X-Test'] := '';

    LResponse := LClient.Get(GServer.BaseURL + '/hello', nil,
      [TNameValuePair.Create('X-Test', 'per request')]);
    CheckEquals('Hello per request', LResponse.ContentAsString, 'headers passed to Get');

    LClient.ContentType := 'application/json';
    LClient.Accept := 'text/event-stream';
    LClient.CustomHeaders['Authorization'] := 'Bearer tok';
    LClient.CustomHeaders['X-Custom'] := 'custom value';
    LBody := TStringStream.Create('{"q":"' + CP([$F1]) + '"}');
    try
      LResponse := LClient.Post(GServer.BaseURL + '/echo?x=1', LBody, TStream(nil));
    finally
      LBody.Free;
    end;
    CheckEquals(200, LResponse.StatusCode, 'POST status');
    LEcho := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    try
      Check(LEcho <> nil, 'POST echo is JSON');
      CheckEquals('POST', LEcho.Values['method'].Value, 'POST method');
      CheckEquals('{"q":"' + CP([$F1]) + '"}', LEcho.Values['body'].Value, 'POST body (UTF-8 bytes kept)');
      CheckEquals('application/json', LEcho.Values['contentType'].Value, 'ContentType header');
      CheckEquals('text/event-stream', LEcho.Values['accept'].Value, 'Accept header');
      CheckEquals('Bearer tok', LEcho.Values['authorization'].Value, 'Authorization header');
      CheckEquals('custom value', LEcho.Values['custom'].Value, 'custom header');
      CheckContains('Reportman', LEcho.Values['userAgent'].Value, 'default User-Agent');
      CheckEquals('x=1', LEcho.Values['query'].Value, 'query string');
    finally
      LEcho.Free;
    end;

    LResponse := LClient.Post(GServer.BaseURL + '/echo', TStream(nil), TStream(nil));
    CheckEquals(200, LResponse.StatusCode, 'POST without body');
    CheckEquals('0', GServer.LastHeader('content-length'), 'POST without body sends Content-Length: 0');

    LResponse := LClient.Put(GServer.BaseURL + '/echo');
    CheckContains('"method":"PUT"', LResponse.ContentAsString, 'PUT');
    LResponse := LClient.Delete(GServer.BaseURL + '/echo');
    CheckContains('"method":"DELETE"', LResponse.ContentAsString, 'DELETE');
    LResponse := LClient.Head(GServer.BaseURL + '/hello');
    CheckEquals(200, LResponse.StatusCode, 'HEAD');
    CheckEquals('', LResponse.ContentAsString, 'HEAD has no body');

    LClient.ContentType := '';
    LForm := TStringList.Create;
    try
      LForm.Add('a=1 2');
      LForm.Add('b=x&y');
      LResponse := LClient.Post(GServer.BaseURL + '/echo', LForm);
    finally
      LForm.Free;
    end;
    CheckContains('application/x-www-form-urlencoded', LResponse.ContentAsString, 'form post content type');
    CheckContains('b=x%26y', LResponse.ContentAsString, 'form post body is URL encoded');

    LResponse := LClient.Get(GServer.BaseURL + '/status/404');
    CheckEquals(404, LResponse.StatusCode, 'HTTP 404 is a response, not an exception');
    CheckEquals('status body', LResponse.ContentAsString, 'body of an error response');
    LResponse := LClient.Get(GServer.BaseURL + '/status/500');
    CheckEquals(500, LResponse.StatusCode, 'HTTP 500');
    LResponse := LClient.Get(GServer.BaseURL + '/status/401');
    CheckEquals(401, LResponse.StatusCode, 'HTTP 401');

    LResponse := LClient.Get(GServer.BaseURL + '/redirect');
    CheckEquals(200, LResponse.StatusCode, 'redirect followed (HandleRedirects)');
    CheckEquals('Hello ', LResponse.ContentAsString, 'redirect target body');
    LClient.HandleRedirects := False;
    LResponse := LClient.Get(GServer.BaseURL + '/redirect');
    CheckEquals(302, LResponse.StatusCode, 'redirect not followed');
    LClient.HandleRedirects := True;

    LResponse := LClient.Get(GServer.BaseURL + '/big');
    CheckEquals(1000000, Length(LResponse.ContentAsString), 'large body');
    LStream := TMemoryStream.Create;
    try
      LStream.WriteBuffer(PChar('prefix')^, 6);
      LResponse := LClient.Get(GServer.BaseURL + '/hello', LStream);
      CheckEquals(6 + 6, LStream.Size, 'body appended to the caller stream');
      CheckEquals('Hello ', LResponse.ContentAsString, 'ContentAsString reads what the request wrote');
    finally
      LStream.Free;
    end;

    LResponse := LClient.Get(GServer.BaseURL + '/utf8');
    CheckEquals(CP([$F1, $20AC]), LResponse.ContentAsString, 'UTF-8 response');
    LResponse := LClient.Get(GServer.BaseURL + '/latin1');
    CheckEquals(CP([$F1]), LResponse.ContentAsString, 'ISO-8859-1 response converted to UTF-8');

    RpHttpSetUrlRewrite('https://api.example.invalid:4444', GServer.BaseURL);
    try
      LResponse := LClient.Get('https://api.example.invalid:4444/hello');
      CheckEquals(200, LResponse.StatusCode, 'URL rewrite (test hook)');
    finally
      RpHttpSetUrlRewrite('', '');
    end;

    LClient.ResponseTimeout := 500;
    LStart := GetTickCount64;
    LRaised := False;
    try
      LClient.Get(GServer.BaseURL + '/slow');
    except
      on E: ENetHTTPClientException do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    Check(LRaised, 'response timeout raises ENetHTTPClientException');
    Check(ElapsedMs(LStart) < 2500, Format('response timeout is honoured (%d ms)', [ElapsedMs(LStart)]));
    LClient.ResponseTimeout := 60000;
  finally
    LClient.Free;
  end;

  LClient := TNetHTTPClient.Create(nil);
  try
    LClient.ConnectionTimeout := 3000;
    LRaised := False;
    LStart := GetTickCount64;
    try
      // Nothing listens on port 9 (discard) of 127.0.0.1
      LClient.Get('http://127.0.0.1:9/');
    except
      on E: ENetHTTPClientException do
        LRaised := True;
    end;
    Check(LRaised, 'connection refused raises ENetHTTPClientException');
    Check(ElapsedMs(LStart) < 4000, 'connection refused fails quickly');
  finally
    LClient.Free;
  end;
end;

procedure StreamTest(AChunked: Boolean);
var
  LClient: TNetHTTPClient;
  LWatcher: TStreamWatcher;
  LResponse: IHTTPResponse;
  LStart, LEnd: QWord;
  LName: string;
begin
  if AChunked then
    LName := 'chunked'
  else
    LName := 'close-delimited';
  LClient := TNetHTTPClient.Create(nil);
  LWatcher := TStreamWatcher.Create;
  LWatcher.Stream := TMemoryStream.Create;
  try
    LClient.Accept := 'text/event-stream';
    LClient.OnReceiveData := LWatcher.ReceiveData;
    LStart := GetTickCount64;
    if AChunked then
      LResponse := LClient.Post(GServer.BaseURL + '/stream?chunked=1', TStream(nil), LWatcher.Stream)
    else
      LResponse := LClient.Post(GServer.BaseURL + '/stream?chunked=0', TStream(nil), LWatcher.Stream);
    LEnd := GetTickCount64;
    CheckEquals(200, LResponse.StatusCode, 'stream (' + LName + ') status');
    Check(LWatcher.Calls >= 5, Format('OnReceiveData called for each event (%s, %d calls)', [LName, LWatcher.Calls]));
    Check(LEnd - LWatcher.FirstCallTick >= 900,
      Format('first event received before the response completed (%s, %d ms before the end)',
      [LName, LEnd - LWatcher.FirstCallTick]));
    CheckEquals(5, LWatcher.EventsSeenDuringRequest, 'all events seen by OnReceiveData (' + LName + ')');
    Check(LEnd - LStart >= 1400, 'the stream took the server time (' + LName + ')');
    CheckContains('data: [DONE]', LResponse.ContentAsString, 'complete content (' + LName + ')');
    CheckEquals(LResponse.ContentAsString, LWatcher.Text, 'data read incrementally = final content (' + LName + ')');
  finally
    LWatcher.Stream.Free;
    LWatcher.Free;
    LClient.Free;
  end;
end;

procedure CancelOnce(ACheck: Boolean);
var
  LClient: TNetHTTPClient;
  LWatcher: TStreamWatcher;
  LResponse: IHTTPResponse;
  LStart: QWord;
begin
  LClient := TNetHTTPClient.Create(nil);
  LWatcher := TStreamWatcher.Create;
  LWatcher.Stream := TMemoryStream.Create;
  try
    LWatcher.AbortAfterCalls := 3;
    LClient.OnReceiveData := LWatcher.ReceiveData;
    LStart := GetTickCount64;
    LResponse := LClient.Post(GServer.BaseURL + '/endless', TStream(nil), LWatcher.Stream);
    if ACheck then
    begin
      Check(ElapsedMs(LStart) < 1500, Format('abort returns promptly (%d ms; the server streams for 10 s)',
        [ElapsedMs(LStart)]));
      CheckEquals(200, LResponse.StatusCode, 'aborted response keeps the status');
      Check(LWatcher.EventsSeenDuringRequest < 10, 'no more data after the abort');
    end;
    LResponse := nil;
  finally
    LWatcher.Stream.Free;
    LWatcher.Free;
    LClient.Free;
  end;
end;

procedure CancelTest;
var
  LClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LBefore: PtrUInt;
begin
  Section('HTTP client: cancel a stream');
  CancelOnce(True);
  LBefore := HeapUsed;
  CancelOnce(False);
  CheckEquals(LBefore, HeapUsed, 'no memory left after an aborted request');
  LClient := TNetHTTPClient.Create(nil);
  try
    LResponse := LClient.Get(GServer.BaseURL + '/hello');
    CheckEquals(200, LResponse.StatusCode, 'the next request works after a cancel');
  finally
    LClient.Free;
  end;
end;

// A port in the range the OAuth login uses that can be opened now (Windows
// excludes some ranges of it, e.g. for Hyper-V)
function FreeLoopbackPort: Word;
var
  LServer: TInetServer;
  I: Integer;
begin
  for I := 1 to 50 do
  begin
    Result := 49152 + Random(16000);
    try
      LServer := TInetServer.Create('127.0.0.1', Result);
      try
        LServer.Bind;
        Exit;
      finally
        LServer.Free;
      end;
    except
      // try another one
    end;
  end;
  Fail('no free loopback port');
end;

procedure LoopbackTest;
var
  LThread: TLoopbackClient;
  LHandler: TLoopbackHandler;
  LPort: Word;
  LError: string;
  LOk: Boolean;
  LStart: QWord;
begin
  Section('OAuth loopback listener');
  LHandler := TLoopbackHandler.Create;
  LThread := TLoopbackClient.Create(True);
  try
    LPort := FreeLoopbackPort;
    LThread.Port := LPort;
    LThread.FreeOnTerminate := False;
    LThread.Start;
    LOk := RpWaitForLoopbackRequest(LPort, 10000, LHandler.Handle, LError);
    LThread.WaitFor;
    Check(LOk, 'listener received the redirect (' + LError + ')');
    CheckEquals('', LThread.Error, 'client side of the redirect');
    CheckEquals(404, LThread.FaviconStatus, '/favicon.ico gets 404 and does not end the wait');
    CheckEquals(200, LThread.Status, 'redirect answered');
    CheckContains('ok', LThread.Body, 'redirect page');
    CheckEquals('state=s1&code=abc%20d%2Fe', LHandler.Query, 'raw query passed to the handler');
  finally
    LThread.Free;
    LHandler.Free;
  end;
  LStart := GetTickCount64;
  LOk := RpWaitForLoopbackRequest(FreeLoopbackPort, 300, nil, LError);
  Check(not LOk, 'listener times out');
  CheckEquals('timeout', LError, 'timeout reported');
  Check(ElapsedMs(LStart) < 1500, 'timeout honoured');
end;

function FindOpenSSLExe: string;
begin
  Result := GetEnvironmentVariable('RP_OPENSSL_EXE');
  if (Result <> '') and FileExists(Result) then
    Exit;
  Result := ExeSearch('openssl' + ExtractFileExt(ParamStr(0)), GetEnvironmentVariable('PATH'));
end;

function MakeCertificate(const ADir: string; out ACert, AKey: string): Boolean;
var
  LExe, LOutput: string;
begin
  Result := False;
  LExe := FindOpenSSLExe;
  if LExe = '' then
    Exit;
  ACert := ADir + 'localhost.crt';
  AKey := ADir + 'localhost.key';
  // A unique subject: OpenSSL looks trusted certificates up by subject, and
  // developer machines often trust other "CN=localhost" certificates (e.g.
  // the ASP.NET Core development certificate in the Windows ROOT store)
  Result := RunCommand(LExe, ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-sha256',
    '-keyout', AKey, '-out', ACert, '-days', '2',
    '-subj', '/CN=Reportman HubClientTest ' + IntToStr(GetProcessID) + '/O=Reportman tests',
    '-addext', 'subjectAltName=DNS:localhost'], LOutput, [poNoConsole]) and
    FileExists(ACert) and FileExists(AKey);
end;

procedure TlsTest;
var
  LError, LDir, LCert, LKey: string;
  LServer: TFakeServer;
  LRoutes: THttpRoutes;
  LClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LAcceptor: TCertAcceptor;
  LRaised: Boolean;
{$IFDEF UNIX}
  LAction: SigActionRec;
{$ENDIF}
begin
  Section('TLS: certificate verification against a local HTTPS server');
  if not RpOpenSSLAvailable(LError) then
  begin
    Skip('OpenSSL not available: ' + LError);
    Exit;
  end;
{$IFDEF UNIX}
  // A TLS peer that closes the connection while OpenSSL writes (e.g. the
  // server sending its session tickets after the client rejected the
  // certificate) must not kill the process with SIGPIPE
  FillChar(LAction, SizeOf(LAction), 0);
  FpSigAction(SIGPIPE, nil, @LAction);
  Check(@LAction.sa_handler = Pointer(PtrUInt(SIG_IGN)), 'SIGPIPE ignored once OpenSSL is loaded');
{$ENDIF}
  LDir := IncludeTrailingPathDelimiter(GetTempDir) + 'rphubtls_' + IntToStr(GetProcessID) + PathDelim;
  ForceDirectories(LDir);
  if not MakeCertificate(LDir, LCert, LKey) then
  begin
    Skip('openssl command not found (set RP_OPENSSL_EXE), TLS tests skipped');
    Exit;
  end;
  LRoutes := THttpRoutes.Create;
  LServer := TFakeServer.Create(LRoutes.Handle, True, LCert, LKey);
  LAcceptor := TCertAcceptor.Create;
  LClient := TNetHTTPClient.Create(nil);
  try
    LServer.Start;
    LRaised := False;
    try
      LClient.Get(LServer.BaseURL('localhost') + '/hello');
    except
      on E: ENetHTTPClientException do
      begin
        LRaised := True;
        LError := E.Message;
      end;
    end;
    Check(LRaised, 'an untrusted (self-signed) certificate is rejected');
    CheckContains('not valid', LError, 'certificate error message: ' + LError);

    LAcceptor.Accept := True;
    LClient.OnValidateServerCertificate := LAcceptor.Validate;
    LResponse := LClient.Get(LServer.BaseURL('localhost') + '/hello');
    CheckEquals(200, LResponse.StatusCode, 'OnValidateServerCertificate can accept it');
    CheckEquals(1, LAcceptor.Calls, 'OnValidateServerCertificate called once');
    CheckContains('CN=Reportman HubClientTest', LAcceptor.Subject, 'certificate subject passed to the event: ' +
      LAcceptor.Subject);
    Check(LAcceptor.Error <> 0, 'verification error passed to the event');
    LClient.OnValidateServerCertificate := nil;

    // Trust the certificate: valid for "localhost", not for 127.0.0.1
    RpHttpCAFile := LCert;
    RpHttpResetTrustStore;
    try
      LResponse := LClient.Get(LServer.BaseURL('localhost') + '/hello');
    except
      on E: Exception do
        Fail('trusted certificate: ' + E.Message + ' [trust store: ' + RpHttpTrustStoreInfo + ']');
    end;
    Log('  trust store: ' + RpHttpTrustStoreInfo);
    CheckEquals(200, LResponse.StatusCode, 'trusted certificate and matching host name');
    CheckEquals('Hello ', LResponse.ContentAsString, 'body over TLS');
    LRaised := False;
    try
      LClient.Get(LServer.BaseURL('127.0.0.1') + '/hello');
    except
      on E: ENetHTTPClientException do
      begin
        LRaised := True;
        LError := E.Message;
      end;
    end;
    Check(LRaised, 'host name mismatch is rejected (' + LError + ')');
  finally
    RpHttpCAFile := '';
    RpHttpResetTrustStore;
    LClient.Free;
    LServer.Free;
    LRoutes.Free;
    LAcceptor.Free;
    DeleteFile(LCert);
    DeleteFile(LKey);
    RemoveDir(LDir);
  end;
end;

procedure RunHttpTests;
var
  LRoutes: THttpRoutes;
begin
  LRoutes := THttpRoutes.Create;
  GServer := TFakeServer.Create(LRoutes.Handle);
  try
    GServer.Start;
    Log('  fake server on ' + GServer.BaseURL);
    BasicTests;
    Section('HTTP client: streaming (OnReceiveData)');
    StreamTest(True);
    StreamTest(False);
    CancelTest;
  finally
    GServer.Free;
    LRoutes.Free;
  end;
  LoopbackTest;
  TlsTest;
end;

end.
