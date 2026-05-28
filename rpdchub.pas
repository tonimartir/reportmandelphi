// =====================================================================
//   Report Manager - rpdchub
//
//   High-level Direct Channel client that talks to the Reportman Hub.
//
//   Lifecycle:
//    1. POST /api/data-session/start
//       Body: agentApiKey or hubDatabaseId
//       Header: Authorization Bearer <jwt>
//       Response: sessionId, token, iceServers
//    2. Open WebSocket to
//         wss://api.../api/data-session/<sid>/signal?token=<token>
//       via rtcCreateWebSocket from libdatachannel.
//    3. Build offer + ICE candidates (non-trickle), send
//       type=offer sdp over WS, wait for the answer wrapped as
//       source=hub body=(success,data.type=answer,sdp).
//    4. setRemoteDescription(answer); DC opens.
//    5. Send executeSql queries over the DC. Receive progress text
//       frames and binary chunks (zlib-compressed FastSerialized
//       DataTable) interleaved with progress/done.
//    6. Dispose: close DC, peer, WS.
//
//   This unit does NOT implement a session pool or try-direct /
//   HTTP-fallback integration with TRpDatasetHttp - those live in a
//   separate unit (rpdatadirect_pool / rpdatahttp glue).
//
//   Copyright (c) 2026 Toni Martir
//   toni@reportman.es
// =====================================================================

unit rpdchub;

interface

{$I rpconf.inc}

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.JSON,
  System.NetEncoding,
  System.ZLib,
  Data.DB,
  Datasnap.DBClient,
  rplibdatachannel,
  rpfastserializer,
  rpdatadirect;

type
  TRpDcHubProgressPhase = (
    dchpConnecting,
    dchpStarting,
    dchpOpeningSignaling,
    dchpNegotiating,
    dchpExecuting,
    dchpFetching,
    dchpDelivering,
    dchpDecompressing,
    dchpDone
  );

  TRpDcHubProgress = record
    Phase: TRpDcHubProgressPhase;
    ElapsedSec: Integer;
    RowsRead: Int64;
    ColumnCount: Integer;
    BytesSent: Int64;
    BytesTotal: Int64;
    procedure Reset;
  end;

  TRpDcHubProgressEvent = procedure(Sender: TObject;
                                     const Progress: TRpDcHubProgress) of object;

  TRpDcHubParam = record
    Name: string;
    Value: Variant;
  end;
  TRpDcHubParams = array of TRpDcHubParam;

  ERpDcHub = class(Exception);

  TRpDcHubClient = class
  private
    FApiBaseUrl: string;
    FBearerToken: string;
    FInstallId: string;
    FAcceptInvalidCerts: Boolean;
    FHttpClient: THTTPClient;
    FSession: TRpDcSession;
    FSessionId: AnsiString;
    FSignalingWsId: Integer;
    FSignalingWsToken: AnsiString;
    FIceServers: array of AnsiString;
    FOnProgress: TRpDcHubProgressEvent;
    FOpenSignal: TEvent;
    FAnswerSignal: TEvent;
    FAnswerSdp: string;
    FStateLock: TCriticalSection;
    // Outstanding query state - simplified to one query at a time for
    // now; the Pascal client always serializes queries on the same DC
    // (the .NET client supports concurrent but we don't need that yet).
    FCurrentRequestId: string;
    FCurrentBuffer: TMemoryStream;
    FCurrentIsCompressed: Boolean;
    FCurrentSuccess: Boolean;
    FCurrentError: string;
    FCurrentDone: TEvent;
    FBinaryLaneRequestId: string;
    FStartTick: Cardinal;

    procedure ReportProgress(Phase: TRpDcHubProgressPhase;
                             RowsRead: Int64 = 0;
                             ColumnCount: Integer = 0;
                             BytesSent: Int64 = 0;
                             BytesTotal: Int64 = 0);

    // HTTP step. AgentApiKey (if not empty) is also forwarded as the
    // X-Reportman-ApiKey header so the API can authenticate the
    // request when there is no Bearer JWT (the typical Designer /
    // printreptopdf flow - templates execute anywhere with just an
    // ApiKey, no user session).
    procedure StartHttpSession(const StartBody: TJSONObject;
                                const AgentApiKey: string);

    // WebSocket signaling
    procedure OpenSignalingSocket;
    procedure SendSignalingFrame(const JsonText: string);
    procedure HandleSignalingMessage(const JsonText: string);

    // Peer connection callbacks (subscribed on FSession)
    procedure OnSessionLocalDescription(Sender: TObject;
                                         const Sdp, SdpType: string);
    procedure OnSessionLocalCandidate(Sender: TObject;
                                       const Candidate, Mid: string);
    procedure OnSessionOpen(Sender: TObject);
    procedure OnSessionMessage(Sender: TObject;
                                const Data: TBytes;
                                IsText: Boolean);
    procedure OnSessionError(Sender: TObject; const Msg: string);

    // DataChannel message dispatch
    procedure HandleDcText(const Json: string);
    procedure HandleDcBinary(const Chunk: TBytes);
    procedure CompleteCurrentQuery;
  public
    constructor Create(const ApiBaseUrl, BearerToken: string;
                       const InstallId: string = '';
                       AcceptInvalidCerts: Boolean = False);
    destructor Destroy; override;

    // Negotiate a fresh session against the Hub. Accepts EITHER
    // AgentApiKey (legacy) OR HubDatabaseId (post-Bearer-auth). Pass
    // an empty string for whichever you don't have. Returns True on
    // success, False if the channel could not be opened (caller falls
    // back to HTTP).
    function Open(const AgentApiKey: string;
                  HubDatabaseId: Int64;
                  TimeoutSec: Integer = 15): Boolean;

    // Test-only entry point that bypasses the HTTP /start round-trip
    // and goes straight to the WebSocket signaling step with caller-
    // supplied sessionId / token / ICE servers. Used by the Mock-Hub
    // loopback test which embeds a tiny WS server in the same
    // process. Not for production callers.
    function OpenForTest(const WsUrl: AnsiString;
                         const IceServers: array of AnsiString;
                         TimeoutSec: Integer = 10): Boolean;

    // Execute a SQL query and return a TClientDataSet populated with
    // the result. The dataset is owned by the caller. Raises on error.
    procedure Execute(const Sql: string;
                      const Params: TRpDcHubParams;
                      HubDatabaseId: Int64;
                      Dataset: TClientDataSet;
                      TimeoutSec: Integer = 600);

    procedure Close;

    function GetConnectionMode: TRpDcConnectionMode;

    property ConnectionMode: TRpDcConnectionMode read GetConnectionMode;
    property OnProgress: TRpDcHubProgressEvent
      read FOnProgress write FOnProgress;
  end;

implementation

uses
  System.Variants;

// Plain (non-method) callback used by Debug builds to accept any
// server certificate. System.Net.URLClient.TValidateCertificateCallback
// is a `procedure(...)` (not `of object`, not `reference to`), so we
// can only assign a plain global procedure here.
procedure DebugAcceptAnyServerCert(const Sender: TObject;
                                    const ARequest: TURLRequest;
                                    const Certificate: TCertificate;
                                    var Accepted: Boolean);
begin
  Accepted := True;
end;

// ============================================================
// Helpers
// ============================================================

procedure TRpDcHubProgress.Reset;
begin
  Phase := dchpConnecting;
  ElapsedSec := 0;
  RowsRead := 0;
  ColumnCount := 0;
  BytesSent := 0;
  BytesTotal := 0;
end;

function Iso8601ToEpoch(const S: string): Int64;
begin
  // Not used yet, kept as a stub for token expiry handling.
  Result := 0;
end;

function GenGuid: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := LowerCase(GUIDToString(G));
  // Strip braces.
  if (Length(Result) >= 2) and (Result[1] = '{') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function InflateZlib(const Compressed: TBytes): TBytes;
var
  src: TBytesStream;
  z: TZDecompressionStream;
  dst: TMemoryStream;
begin
  src := TBytesStream.Create(Compressed);
  dst := TMemoryStream.Create;
  try
    z := TZDecompressionStream.Create(src, 15);  // 15 = zlib header (RFC 1950)
    try
      dst.CopyFrom(z, 0);
    finally
      z.Free;
    end;
    SetLength(Result, dst.Size);
    if dst.Size > 0 then
    begin
      dst.Position := 0;
      dst.ReadBuffer(Result[0], dst.Size);
    end;
  finally
    src.Free;
    dst.Free;
  end;
end;

function VariantToJson(const V: Variant): TJSONValue;
begin
  if VarIsNull(V) or VarIsEmpty(V) then
    Result := TJSONNull.Create
  else case VarType(V) and varTypeMask of
    varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord, varUInt64, varInt64:
      Result := TJSONNumber.Create(Int64(V));
    varSingle, varDouble, varCurrency:
      Result := TJSONNumber.Create(Double(V));
    varBoolean:
      Result := TJSONBool.Create(Boolean(V));
    varDate:
      Result := TJSONString.Create(FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', VarToDateTime(V)));
  else
    Result := TJSONString.Create(VarToStr(V));
  end;
end;

// ============================================================
// Construction
// ============================================================

constructor TRpDcHubClient.Create(const ApiBaseUrl, BearerToken: string;
                                   const InstallId: string;
                                   AcceptInvalidCerts: Boolean);
begin
  inherited Create;
  if not RpDcIsInitialized then
    raise ERpDcHub.Create(
      'RpDcInitialize must be called before constructing TRpDcHubClient');
  FApiBaseUrl := ApiBaseUrl;
  if (FApiBaseUrl <> '') and (FApiBaseUrl[Length(FApiBaseUrl)] = '/') then
    SetLength(FApiBaseUrl, Length(FApiBaseUrl) - 1);
  FBearerToken := BearerToken;
  FInstallId := InstallId;
  FAcceptInvalidCerts := AcceptInvalidCerts;
  FHttpClient := THTTPClient.Create;
  FSignalingWsId := -1;
  FOpenSignal := TEvent.Create(nil, True, False, '');
  FAnswerSignal := TEvent.Create(nil, True, False, '');
  FCurrentDone := TEvent.Create(nil, True, False, '');
  FCurrentBuffer := TMemoryStream.Create;
  FStateLock := TCriticalSection.Create;
end;

destructor TRpDcHubClient.Destroy;
begin
  Close;
  FCurrentBuffer.Free;
  FOpenSignal.Free;
  FAnswerSignal.Free;
  FCurrentDone.Free;
  FStateLock.Free;
  FHttpClient.Free;
  inherited;
end;

// ============================================================
// HTTP /start
// ============================================================

procedure TRpDcHubClient.StartHttpSession(const StartBody: TJSONObject;
                                           const AgentApiKey: string);
var
  url: string;
  bodyStream: TStringStream;
  resp: IHTTPResponse;
  bodyText, sessionStr, tokenStr: string;
  root, iceEntry: TJSONObject;
  iceArr: TJSONArray;
  i: Integer;
  urlsStr: string;
begin
  url := FApiBaseUrl + '/api/data-session/start';
  bodyStream := TStringStream.Create(StartBody.ToJSON, TEncoding.UTF8);
  try
    FHttpClient.CustomHeaders['Content-Type'] := 'application/json';
    if FBearerToken <> '' then
      FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FBearerToken;
    if FInstallId <> '' then
      FHttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
    // Send the ApiKey as a header too so the server can authenticate
    // the request when no Bearer JWT is available. The endpoint also
    // reads agentApiKey from the JSON body, but having both is
    // harmless and lets future Hub middleware that promotes ApiKey
    // to user context (guest mode) light up automatically.
    if AgentApiKey <> '' then
      FHttpClient.CustomHeaders['X-Reportman-ApiKey'] := AgentApiKey;

{$IFDEF DEBUG}
    if FAcceptInvalidCerts then
      FHttpClient.ValidateServerCertificateCallback := DebugAcceptAnyServerCert;
{$ENDIF}

    resp := FHttpClient.Post(url, bodyStream);
    if (resp.StatusCode < 200) or (resp.StatusCode >= 300) then
      raise ERpDcHub.CreateFmt('start failed: HTTP %d - %s',
        [resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)]);
    bodyText := resp.ContentAsString(TEncoding.UTF8);
  finally
    bodyStream.Free;
  end;

  root := TJSONObject.ParseJSONValue(bodyText) as TJSONObject;
  if root = nil then
    raise ERpDcHub.Create('start response is not a JSON object');
  try
    sessionStr := root.GetValue<string>('sessionId', '');
    tokenStr   := root.GetValue<string>('token', '');
    if (sessionStr = '') or (tokenStr = '') then
      raise ERpDcHub.Create('start response missing sessionId/token');
    FSessionId := AnsiString(sessionStr);
    FSignalingWsToken := AnsiString(tokenStr);

    SetLength(FIceServers, 0);
    if root.TryGetValue<TJSONArray>('iceServers', iceArr) and (iceArr <> nil) then
    begin
      for i := 0 to iceArr.Count - 1 do
      begin
        iceEntry := iceArr.Items[i] as TJSONObject;
        if iceEntry = nil then Continue;
        urlsStr := iceEntry.GetValue<string>('urls', '');
        if urlsStr <> '' then
        begin
          SetLength(FIceServers, Length(FIceServers) + 1);
          FIceServers[High(FIceServers)] := AnsiString(urlsStr);
        end;
      end;
    end;
  finally
    root.Free;
  end;
end;

// ============================================================
// WebSocket signaling
// ============================================================

procedure WsOpenCb(id: Integer; ptr: Pointer); cdecl;
var
  c: TRpDcHubClient;
begin
  c := TRpDcHubClient(ptr);
  if c = nil then Exit;
  c.FOpenSignal.SetEvent;
end;

procedure WsClosedCb(id: Integer; ptr: Pointer); cdecl;
begin
  // Currently a no-op - the higher-level error handling notices the
  // closed socket through receive failures.
end;

procedure WsErrorCb(id: Integer; const error: PAnsiChar; ptr: Pointer); cdecl;
var
  c: TRpDcHubClient;
begin
  c := TRpDcHubClient(ptr);
  if c = nil then Exit;
  // Signal the waiters so they unblock; they will see no answer arrived.
  c.FOpenSignal.SetEvent;
  c.FAnswerSignal.SetEvent;
end;

procedure WsMessageCb(id: Integer; const data: PAnsiChar; size: Integer;
                      ptr: Pointer); cdecl;
var
  c: TRpDcHubClient;
  buf: TBytes;
  effLen: Integer;
  s: AnsiString;
begin
  c := TRpDcHubClient(ptr);
  if c = nil then Exit;
  if size < 0 then
  begin
    effLen := -size;
    if (effLen > 0) and (PAnsiChar(data)[effLen - 1] = #0) then
      Dec(effLen);
  end
  else
    effLen := size;
  if effLen <= 0 then Exit;
  SetLength(buf, effLen);
  Move(data^, buf[0], effLen);
  SetString(s, PAnsiChar(@buf[0]), effLen);
  try
    c.HandleSignalingMessage(string(s));
  except
    // Swallow exceptions crossing the C boundary.
  end;
end;

procedure TRpDcHubClient.OpenSignalingSocket;
var
  wsUrl: AnsiString;
  scheme: string;
begin
  // The API uses HTTPS in production / dev, so the signaling socket
  // is wss. We don't try to verify the certificate at the
  // libdatachannel level - rely on FAcceptInvalidCerts and the same
  // TLS trust policy as the HTTP client.
  if Pos('https://', LowerCase(FApiBaseUrl)) = 1 then
    scheme := 'wss'
  else
    scheme := 'ws';

  wsUrl := AnsiString(scheme + '://' +
           Copy(FApiBaseUrl, Pos('://', FApiBaseUrl) + 3, MaxInt) +
           '/api/data-session/' + string(FSessionId) +
           '/signal?token=' + string(FSignalingWsToken));

  FOpenSignal.ResetEvent;
  FSignalingWsId := rtcCreateWebSocket(PAnsiChar(wsUrl));
  if FSignalingWsId < 0 then
    raise ERpDcHub.CreateFmt('rtcCreateWebSocket failed: %d',
                             [FSignalingWsId]);
  rtcSetUserPointer(FSignalingWsId, Self);
  rtcSetOpenCallback(FSignalingWsId, @WsOpenCb);
  rtcSetClosedCallback(FSignalingWsId, @WsClosedCb);
  rtcSetErrorCallback(FSignalingWsId, @WsErrorCb);
  rtcSetMessageCallback(FSignalingWsId, @WsMessageCb);

  // libdatachannel may already be racing the connection.
  if FOpenSignal.WaitFor(10000) <> wrSignaled then
    raise ERpDcHub.Create('signaling WS did not open within 10s');
  if not rtcIsOpen(FSignalingWsId) then
    raise ERpDcHub.Create('signaling WS open signal fired but socket not open');
end;

procedure TRpDcHubClient.SendSignalingFrame(const JsonText: string);
var
  utf8: AnsiString;
begin
  if FSignalingWsId < 0 then
    raise ERpDcHub.Create('signaling WS is not open');
  utf8 := AnsiString(UTF8Encode(JsonText));
  rtcSendMessage(FSignalingWsId, PAnsiChar(utf8), -1);
end;

procedure TRpDcHubClient.HandleSignalingMessage(const JsonText: string);
var
  root, payload, inner, data: TJSONObject;
  source, body, t, sdp: string;
  candObj: TJSONObject;
  candidate, mid: string;
begin
  // Frames the API forwards to us:
  //   {"source":"hub","body":"<inner JSON serialized as string>"}
  //   {"source":"agent","payload":{...}}
  root := TJSONObject.ParseJSONValue(JsonText) as TJSONObject;
  if root = nil then Exit;
  try
    source := root.GetValue<string>('source', '');
    if source = 'hub' then
    begin
      body := root.GetValue<string>('body', '');
      if body = '' then Exit;
      inner := TJSONObject.ParseJSONValue(body) as TJSONObject;
      if inner = nil then Exit;
      try
        if not inner.GetValue<Boolean>('success', False) then Exit;
        data := inner.GetValue<TJSONObject>('data', nil);
        if data = nil then Exit;
        t := data.GetValue<string>('type', '');
        if t = 'answer' then
        begin
          sdp := data.GetValue<string>('sdp', '');
          if sdp <> '' then
          begin
            FStateLock.Acquire;
            try
              FAnswerSdp := sdp;
            finally
              FStateLock.Release;
            end;
            FAnswerSignal.SetEvent;
          end;
        end;
      finally
        inner.Free;
      end;
    end
    else if source = 'agent' then
    begin
      payload := root.GetValue<TJSONObject>('payload', nil);
      if payload = nil then Exit;
      t := payload.GetValue<string>('type', '');
      if t = 'ice' then
      begin
        candObj := payload.GetValue<TJSONObject>('candidate', nil);
        if candObj <> nil then
        begin
          candidate := candObj.GetValue<string>('candidate', '');
          mid := candObj.GetValue<string>('sdpMid', '');
          if candidate <> '' then
          begin
            try
              FSession.AddRemoteCandidate(candidate, mid);
            except
              // Best-effort; a late candidate may fail if the peer is closed.
            end;
          end;
        end;
      end;
    end;
  finally
    root.Free;
  end;
end;

// ============================================================
// Session callbacks
// ============================================================

procedure TRpDcHubClient.OnSessionLocalDescription(Sender: TObject;
                                                   const Sdp, SdpType: string);
var
  frame: TJSONObject;
begin
  // We only forward the offer (the answerer side never speaks first).
  // SdpType arrives as 'offer' here.
  frame := TJSONObject.Create;
  try
    frame.AddPair('type', SdpType);
    frame.AddPair('sdp', Sdp);
    try
      SendSignalingFrame(frame.ToJSON);
    except
      // Logged elsewhere; an unsent offer means the WS died.
    end;
  finally
    frame.Free;
  end;
end;

procedure TRpDcHubClient.OnSessionLocalCandidate(Sender: TObject;
                                                  const Candidate, Mid: string);
var
  frame, candObj: TJSONObject;
begin
  // Send local trickle candidate. Reference C# client uses non-trickle
  // (waits for gather complete), but the Hub also accepts trickle.
  frame := TJSONObject.Create;
  try
    frame.AddPair('type', 'ice');
    candObj := TJSONObject.Create;
    candObj.AddPair('candidate', Candidate);
    if Mid <> '' then candObj.AddPair('sdpMid', Mid);
    frame.AddPair('candidate', candObj);
    try
      SendSignalingFrame(frame.ToJSON);
    except
    end;
  finally
    frame.Free;
  end;
end;

procedure TRpDcHubClient.OnSessionOpen(Sender: TObject);
begin
  // No-op on DC open - the Open() caller observes the open state via
  // a different code path (state polling). We could add a TEvent if
  // multiple consumers need to wait for it.
end;

procedure TRpDcHubClient.OnSessionMessage(Sender: TObject;
                                          const Data: TBytes;
                                          IsText: Boolean);
var
  s: AnsiString;
begin
  if Length(Data) = 0 then Exit;
  if IsText then
  begin
    SetString(s, PAnsiChar(@Data[0]), Length(Data));
    HandleDcText(string(s));
  end
  else
    HandleDcBinary(Data);
end;

procedure TRpDcHubClient.OnSessionError(Sender: TObject; const Msg: string);
begin
  FStateLock.Acquire;
  try
    FCurrentError := Msg;
    FCurrentSuccess := False;
  finally
    FStateLock.Release;
  end;
  FCurrentDone.SetEvent;
end;

// ============================================================
// DataChannel framing
// ============================================================

procedure TRpDcHubClient.HandleDcText(const Json: string);
var
  root, dataNode: TJSONObject;
  rid, t, phase, errMsg, jsonInline: string;
  rowsRead, bytesSent, bytesTotal: Int64;
  cols, elapsed: Integer;
  isBinary, isCompressed, ok: Boolean;
  inlineBytes: TBytes;
begin
  root := TJSONObject.ParseJSONValue(Json) as TJSONObject;
  if root = nil then Exit;
  try
    rid := root.GetValue<string>('requestId', '');
    if (rid = '') or (rid <> FCurrentRequestId) then Exit;
    t := root.GetValue<string>('type', '');
    if t = 'progress' then
    begin
      phase := root.GetValue<string>('phase', '');
      elapsed := root.GetValue<Integer>('elapsedSec', 0);
      if phase = 'executing' then
        ReportProgress(dchpExecuting, 0, 0, 0, 0)
      else if phase = 'fetching' then
      begin
        rowsRead := root.GetValue<Int64>('rowsRead', 0);
        cols := root.GetValue<Integer>('columnCount', 0);
        ReportProgress(dchpFetching, rowsRead, cols, 0, 0);
      end
      else if phase = 'delivering' then
      begin
        bytesSent := root.GetValue<Int64>('bytesSent', 0);
        bytesTotal := root.GetValue<Int64>('bytesTotal', 0);
        isBinary := root.GetValue<Boolean>('binary', False);
        isCompressed := root.GetValue<Boolean>('compressed', False);
        if isBinary then
        begin
          FStateLock.Acquire;
          try
            FBinaryLaneRequestId := rid;
            FCurrentIsCompressed := isCompressed;
          finally
            FStateLock.Release;
          end;
        end;
        ReportProgress(dchpDelivering, 0, 0, bytesSent, bytesTotal);
      end;
    end
    else if t = 'payload' then
    begin
      // Inline JSON payload (no binary frames).
      jsonInline := root.GetValue<string>('json', '');
      if jsonInline <> '' then
      begin
        inlineBytes := TEncoding.UTF8.GetBytes(jsonInline);
        FCurrentBuffer.WriteBuffer(inlineBytes[0], Length(inlineBytes));
      end;
    end
    else if t = 'done' then
    begin
      ok := root.GetValue<Boolean>('success', False);
      if ok then
        errMsg := ''
      else
        errMsg := root.GetValue<string>('error', 'Agent reported failure');
      FStateLock.Acquire;
      try
        FCurrentSuccess := ok;
        FCurrentError := errMsg;
        if FBinaryLaneRequestId = rid then FBinaryLaneRequestId := '';
      finally
        FStateLock.Release;
      end;
      FCurrentDone.SetEvent;
    end;
  finally
    root.Free;
  end;
end;

procedure TRpDcHubClient.HandleDcBinary(const Chunk: TBytes);
begin
  if FBinaryLaneRequestId = '' then Exit;
  if Length(Chunk) = 0 then Exit;
  FCurrentBuffer.WriteBuffer(Chunk[0], Length(Chunk));
end;

procedure TRpDcHubClient.ReportProgress(Phase: TRpDcHubProgressPhase;
                                         RowsRead: Int64;
                                         ColumnCount: Integer;
                                         BytesSent: Int64;
                                         BytesTotal: Int64);
var
  p: TRpDcHubProgress;
begin
  if not Assigned(FOnProgress) then Exit;
  p.Phase := Phase;
  p.ElapsedSec := Integer((GetTickCount - FStartTick) div 1000);
  p.RowsRead := RowsRead;
  p.ColumnCount := ColumnCount;
  p.BytesSent := BytesSent;
  p.BytesTotal := BytesTotal;
  FOnProgress(Self, p);
end;

// ============================================================
// Public Open / Execute
// ============================================================

function TRpDcHubClient.Open(const AgentApiKey: string;
                              HubDatabaseId: Int64;
                              TimeoutSec: Integer): Boolean;
var
  startBody: TJSONObject;
  startTick: Cardinal;
  iceServersAnsi: array of AnsiString;
  i: Integer;
begin
  Result := False;
  FStartTick := GetTickCount;
  startTick := GetTickCount;

  try
    ReportProgress(dchpStarting);
    startBody := TJSONObject.Create;
    try
      if AgentApiKey <> '' then
        startBody.AddPair('agentApiKey', AgentApiKey)
      else
        startBody.AddPair('hubDatabaseId', TJSONNumber.Create(HubDatabaseId));
      StartHttpSession(startBody, AgentApiKey);
    finally
      startBody.Free;
    end;

    ReportProgress(dchpOpeningSignaling);
    OpenSignalingSocket;

    ReportProgress(dchpNegotiating);
    SetLength(iceServersAnsi, Length(FIceServers));
    for i := 0 to High(FIceServers) do
      iceServersAnsi[i] := FIceServers[i];

    FSession := TRpDcSession.Create(True, 'data');
    FSession.OnLocalDescription := OnSessionLocalDescription;
    FSession.OnLocalCandidate   := OnSessionLocalCandidate;
    FSession.OnOpen             := OnSessionOpen;
    FSession.OnMessage          := OnSessionMessage;
    FSession.OnError            := OnSessionError;
    FAnswerSignal.ResetEvent;
    FSession.Open(iceServersAnsi);

    // Wait for the Hub-side answer to arrive over the signaling WS,
    // then plug it into the peer connection.
    if FAnswerSignal.WaitFor(Cardinal(TimeoutSec * 1000)) <> wrSignaled then
      Exit;
    FStateLock.Acquire;
    try
      if FAnswerSdp = '' then Exit;
      FSession.SetRemoteDescription(FAnswerSdp, 'answer');
    finally
      FStateLock.Release;
    end;

    // Now wait for the DC to actually open. We poll because the open
    // event might fire from a different thread; rather than coordinate
    // with an extra TEvent we just spin briefly.
    while not FSession.IsOpen do
    begin
      if GetTickCount - startTick > Cardinal(TimeoutSec * 1000) then Exit;
      Sleep(50);
    end;

    Result := True;
  except
    on E: Exception do
    begin
      // Surface as last error inside the structure; the caller decides
      // to fall back to HTTP. Future: log the exception.
      FCurrentError := E.Message;
    end;
  end;
end;

procedure TRpDcHubClient.Execute(const Sql: string;
                                  const Params: TRpDcHubParams;
                                  HubDatabaseId: Int64;
                                  Dataset: TClientDataSet;
                                  TimeoutSec: Integer);
var
  req, dataObj, paramObj: TJSONObject;
  paramsArr: TJSONArray;
  i: Integer;
  payload: TBytes;
  inflated: TBytes;
  ms: TMemoryStream;
begin
  if (FSession = nil) or (not FSession.IsOpen) then
    raise ERpDcHub.Create('DataChannel is not open');

  FStateLock.Acquire;
  try
    FCurrentRequestId := GenGuid;
    FCurrentBuffer.Clear;
    FCurrentIsCompressed := False;
    FCurrentSuccess := False;
    FCurrentError := '';
    FBinaryLaneRequestId := '';
  finally
    FStateLock.Release;
  end;
  FCurrentDone.ResetEvent;

  req := TJSONObject.Create;
  try
    req.AddPair('requestId', FCurrentRequestId);
    req.AddPair('action', 'execute_sql');
    dataObj := TJSONObject.Create;
    req.AddPair('data', dataObj);
    dataObj.AddPair('hubDatabaseId', TJSONNumber.Create(HubDatabaseId));
    dataObj.AddPair('sql', Sql);
    paramsArr := TJSONArray.Create;
    dataObj.AddPair('parameters', paramsArr);
    for i := 0 to High(Params) do
    begin
      paramObj := TJSONObject.Create;
      paramObj.AddPair('name', Params[i].Name);
      paramObj.AddPair('value', VariantToJson(Params[i].Value));
      paramsArr.AddElement(paramObj);
    end;

    FSession.SendText(req.ToJSON);
  finally
    req.Free;
  end;

  if FCurrentDone.WaitFor(Cardinal(TimeoutSec * 1000)) <> wrSignaled then
    raise ERpDcHub.CreateFmt('Query timeout after %d seconds', [TimeoutSec]);

  if not FCurrentSuccess then
    raise ERpDcHub.Create(FCurrentError);

  // Build the payload from the accumulated buffer.
  SetLength(payload, FCurrentBuffer.Size);
  if FCurrentBuffer.Size > 0 then
  begin
    FCurrentBuffer.Position := 0;
    FCurrentBuffer.ReadBuffer(payload[0], FCurrentBuffer.Size);
  end;

  if FCurrentIsCompressed then
  begin
    ReportProgress(dchpDecompressing);
    inflated := InflateZlib(payload);
  end
  else
    inflated := payload;

  // FastSerializer-decoded into the caller's dataset.
  ms := TMemoryStream.Create;
  try
    if Length(inflated) > 0 then
      ms.WriteBuffer(inflated[0], Length(inflated));
    ms.Position := 0;
    FastDeserializeDataSet(Dataset, ms);
  finally
    ms.Free;
  end;

  ReportProgress(dchpDone);
end;

function TRpDcHubClient.OpenForTest(const WsUrl: AnsiString;
                                     const IceServers: array of AnsiString;
                                     TimeoutSec: Integer): Boolean;
var
  startTick: Cardinal;
  iceServersAnsi: array of AnsiString;
  i: Integer;
begin
  Result := False;
  FStartTick := GetTickCount;
  startTick := GetTickCount;

  try
    // Open the WS directly to the test-supplied URL. We skip the
    // HTTP /start step and assume the caller already arranged the
    // session id and token on the other end.
    FOpenSignal.ResetEvent;
    FSignalingWsId := rtcCreateWebSocket(PAnsiChar(WsUrl));
    if FSignalingWsId < 0 then Exit;
    rtcSetUserPointer(FSignalingWsId, Self);
    rtcSetOpenCallback(FSignalingWsId, @WsOpenCb);
    rtcSetClosedCallback(FSignalingWsId, @WsClosedCb);
    rtcSetErrorCallback(FSignalingWsId, @WsErrorCb);
    rtcSetMessageCallback(FSignalingWsId, @WsMessageCb);
    if FOpenSignal.WaitFor(Cardinal(TimeoutSec * 1000)) <> wrSignaled then Exit;
    if not rtcIsOpen(FSignalingWsId) then Exit;

    SetLength(iceServersAnsi, Length(IceServers));
    for i := 0 to High(IceServers) do
      iceServersAnsi[i] := IceServers[i];

    FSession := TRpDcSession.Create(True, 'data');
    FSession.OnLocalDescription := OnSessionLocalDescription;
    FSession.OnLocalCandidate   := OnSessionLocalCandidate;
    FSession.OnOpen             := OnSessionOpen;
    FSession.OnMessage          := OnSessionMessage;
    FSession.OnError            := OnSessionError;
    FAnswerSignal.ResetEvent;
    FSession.Open(iceServersAnsi);

    if FAnswerSignal.WaitFor(Cardinal(TimeoutSec * 1000)) <> wrSignaled then Exit;
    FStateLock.Acquire;
    try
      if FAnswerSdp = '' then Exit;
      FSession.SetRemoteDescription(FAnswerSdp, 'answer');
    finally
      FStateLock.Release;
    end;

    while not FSession.IsOpen do
    begin
      if GetTickCount - startTick > Cardinal(TimeoutSec * 1000) then Exit;
      Sleep(50);
    end;

    Result := True;
  except
    on E: Exception do
      FCurrentError := E.Message;
  end;
end;

procedure TRpDcHubClient.Close;
begin
  if FSession <> nil then
  begin
    try
      FSession.Close;
    except
    end;
    FreeAndNil(FSession);
  end;
  if FSignalingWsId >= 0 then
  begin
    if Assigned(rtcSetUserPointer) then
      rtcSetUserPointer(FSignalingWsId, nil);
    if Assigned(rtcClose) then
      rtcClose(FSignalingWsId);
    if Assigned(rtcDeleteWebSocket) then
      rtcDeleteWebSocket(FSignalingWsId);
    FSignalingWsId := -1;
  end;
end;

procedure TRpDcHubClient.CompleteCurrentQuery;
begin
  // Currently unused; reserved for cancel handling.
end;

function TRpDcHubClient.GetConnectionMode: TRpDcConnectionMode;
begin
  if FSession <> nil then
    Result := FSession.ConnectionMode
  else
    Result := rcmUnknown;
end;


end.
