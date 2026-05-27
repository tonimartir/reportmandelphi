program test_dcpool_loopback;

// =====================================================================
//   Loopback test for rpdcpool.pas:
//
//   - Spins up the same Mock-Hub used by test_dchub_loopback.
//   - Creates a TRpDcHubChannelPool with an opener callback that
//     bypasses HTTP /start and goes straight to the local WS.
//   - Acquires for hubDatabaseId=1, runs a query, releases.
//   - Acquires AGAIN for hubDatabaseId=1, asserts the SAME client
//     instance is returned (cache hit), runs a second query.
//   - Confirms pool.Count = 1 throughout.
// =====================================================================

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.JSON,
  System.NetEncoding,
  System.DateUtils,
  Data.DB,
  Datasnap.DBClient,
  MidasLib,
  rplibdatachannel in '..\..\rplibdatachannel.pas',
  rpfastserializer in '..\..\rpfastserializer.pas',
  rpdatadirect    in '..\..\rpdatadirect.pas',
  rpdchub         in '..\..\rpdchub.pas',
  rpdcpool        in '..\..\rpdcpool.pas';

const
  MockHubRowCount = 12;

type
  // Reuse the same Mock-Hub class as the dchub test, kept inline here
  // to avoid splitting the test into more files.
  TMockHub = class
  public
    StateLock: TCriticalSection;
    WsServerId: Integer;
    WsServerPort: Integer;
    ClientWsId: Integer;
    Answerer: TRpDcSession;
    QueryCounter: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure SendToClient(const JsonText: string);
    procedure HandleClientWsMessage(const Data: TBytes; IsText: Boolean);
    procedure OnAnswererLocalDescription(Sender: TObject;
                                          const Sdp, SdpType: string);
    procedure OnAnswererLocalCandidate(Sender: TObject;
                                        const Candidate, Mid: string);
    procedure OnAnswererOpen(Sender: TObject);
    procedure OnAnswererMessage(Sender: TObject;
                                 const Data: TBytes; IsText: Boolean);
    procedure RespondToExecuteSql(const RequestId: string);
  end;

var
  GMock: TMockHub;

function ResolveDllPath: string;
var b: string;
begin
  b := ExtractFilePath(ParamStr(0));
{$IFDEF WIN64}
  Result := ExpandFileName(b + '..\..\..\activex_ai\resources\x64\datachannel.dll');
{$ELSE}
  Result := ExpandFileName(b + '..\..\..\activex_ai\resources\x86\datachannel.dll');
{$ENDIF}
end;

procedure McWsServerClientCb(wsserver: Integer; ws: Integer;
                              ptr: Pointer); cdecl;
forward;
procedure McClientWsMessageCb(id: Integer; const data: PAnsiChar;
                               size: Integer; ptr: Pointer); cdecl;
forward;

procedure McWsServerClientCb(wsserver: Integer; ws: Integer;
                              ptr: Pointer); cdecl;
var
  m: TMockHub;
begin
  m := TMockHub(ptr);
  if m = nil then Exit;
  m.StateLock.Acquire;
  try
    m.ClientWsId := ws;
  finally
    m.StateLock.Release;
  end;
  rtcSetUserPointer(ws, m);
  rtcSetMessageCallback(ws, @McClientWsMessageCb);
end;

procedure McClientWsMessageCb(id: Integer; const data: PAnsiChar;
                               size: Integer; ptr: Pointer); cdecl;
var
  m: TMockHub;
  buf: TBytes;
  effLen: Integer;
  isText: Boolean;
begin
  m := TMockHub(ptr);
  if m = nil then Exit;
  if size < 0 then
  begin
    isText := True;
    effLen := -size;
    if (effLen > 0) and (PAnsiChar(data)[effLen - 1] = #0) then
      Dec(effLen);
  end
  else
  begin
    isText := False;
    effLen := size;
  end;
  if effLen <= 0 then Exit;
  SetLength(buf, effLen);
  Move(data^, buf[0], effLen);
  try
    m.HandleClientWsMessage(buf, isText);
  except
  end;
end;

constructor TMockHub.Create;
begin
  inherited;
  StateLock := TCriticalSection.Create;
  WsServerId := -1;
  ClientWsId := -1;
end;

destructor TMockHub.Destroy;
begin
  if WsServerId >= 0 then
  begin
    if Assigned(rtcDeleteWebSocketServer) then
      rtcDeleteWebSocketServer(WsServerId);
    WsServerId := -1;
  end;
  if Answerer <> nil then Answerer.Free;
  StateLock.Free;
  inherited;
end;

procedure TMockHub.Start;
var
  cfg: rtcWsServerConfiguration;
begin
  FillChar(cfg, SizeOf(cfg), 0);
  cfg.port := 0;
  cfg.enableTls := False;
  cfg.bindAddress := '127.0.0.1';
  cfg.maxMessageSize := 16 * 1024 * 1024;
  WsServerId := rtcCreateWebSocketServer(@cfg, @McWsServerClientCb);
  if WsServerId < 0 then
    raise Exception.CreateFmt('rtcCreateWebSocketServer failed: %d',
                              [WsServerId]);
  rtcSetUserPointer(WsServerId, Self);
  WsServerPort := rtcGetWebSocketServerPort(WsServerId);
end;

procedure TMockHub.SendToClient(const JsonText: string);
var
  utf8: AnsiString;
  wsId: Integer;
begin
  StateLock.Acquire;
  try
    wsId := ClientWsId;
  finally
    StateLock.Release;
  end;
  if wsId < 0 then Exit;
  utf8 := AnsiString(UTF8Encode(JsonText));
  rtcSendMessage(wsId, PAnsiChar(utf8), -1);
end;

procedure TMockHub.OnAnswererLocalDescription(Sender: TObject;
                                               const Sdp, SdpType: string);
var
  wrap, body, data: TJSONObject;
  bodyStr, frameStr: string;
begin
  data := TJSONObject.Create;
  data.AddPair('type', SdpType);
  data.AddPair('sdp', Sdp);
  body := TJSONObject.Create;
  body.AddPair('success', TJSONBool.Create(True));
  body.AddPair('data', data);
  bodyStr := body.ToJSON;
  body.Free;
  wrap := TJSONObject.Create;
  wrap.AddPair('source', 'hub');
  wrap.AddPair('body', bodyStr);
  frameStr := wrap.ToJSON;
  wrap.Free;
  SendToClient(frameStr);
end;

procedure TMockHub.OnAnswererLocalCandidate(Sender: TObject;
                                             const Candidate, Mid: string);
var
  wrap, payload, candObj: TJSONObject;
  frameStr: string;
begin
  candObj := TJSONObject.Create;
  candObj.AddPair('candidate', Candidate);
  if Mid <> '' then candObj.AddPair('sdpMid', Mid);
  payload := TJSONObject.Create;
  payload.AddPair('type', 'ice');
  payload.AddPair('candidate', candObj);
  wrap := TJSONObject.Create;
  wrap.AddPair('source', 'agent');
  wrap.AddPair('payload', payload);
  frameStr := wrap.ToJSON;
  wrap.Free;
  SendToClient(frameStr);
end;

procedure TMockHub.OnAnswererOpen(Sender: TObject);
begin
end;

procedure TMockHub.OnAnswererMessage(Sender: TObject;
                                      const Data: TBytes; IsText: Boolean);
var
  s: AnsiString;
  root: TJSONObject;
  rid, action: string;
begin
  if not IsText then Exit;
  if Length(Data) = 0 then Exit;
  SetString(s, PAnsiChar(@Data[0]), Length(Data));
  root := TJSONObject.ParseJSONValue(string(s)) as TJSONObject;
  if root = nil then Exit;
  try
    rid := root.GetValue<string>('requestId', '');
    action := root.GetValue<string>('action', '');
    if action = 'executeSql' then
    begin
      AtomicIncrement(QueryCounter);
      RespondToExecuteSql(rid);
    end;
  finally
    root.Free;
  end;
end;

procedure TMockHub.RespondToExecuteSql(const RequestId: string);
var
  ds: TClientDataSet;
  ms: TMemoryStream;
  payload, chunk: TBytes;
  offset, len, i: Integer;
  progressFrame, deliveringFrame, doneFrame: TJSONObject;
const
  ChunkBytes = 8 * 1024;
begin
  ds := TClientDataSet.Create(nil);
  try
    ds.FieldDefs.Add('id', ftInteger);
    with ds.FieldDefs.AddFieldDef do
    begin
      Name := 'tag';
      DataType := ftWideString;
      Size := 64;
    end;
    ds.CreateDataSet;
    for i := 1 to MockHubRowCount do
    begin
      ds.Append;
      ds.FieldByName('id').AsInteger := i;
      ds.FieldByName('tag').AsString :=
        Format('q%d-r%d', [QueryCounter, i]);
      ds.Post;
    end;
    ms := TMemoryStream.Create;
    try
      FastSerializeDataSet(ds, ms, 'PoolFixture');
      SetLength(payload, ms.Size);
      if ms.Size > 0 then
      begin
        ms.Position := 0;
        ms.ReadBuffer(payload[0], ms.Size);
      end;
    finally
      ms.Free;
    end;
  finally
    ds.Free;
  end;

  progressFrame := TJSONObject.Create;
  try
    progressFrame.AddPair('requestId', RequestId);
    progressFrame.AddPair('type', 'progress');
    progressFrame.AddPair('phase', 'executing');
    progressFrame.AddPair('elapsedSec', TJSONNumber.Create(0));
    Answerer.SendText(progressFrame.ToJSON);
  finally
    progressFrame.Free;
  end;

  deliveringFrame := TJSONObject.Create;
  try
    deliveringFrame.AddPair('requestId', RequestId);
    deliveringFrame.AddPair('type', 'progress');
    deliveringFrame.AddPair('phase', 'delivering');
    deliveringFrame.AddPair('elapsedSec', TJSONNumber.Create(0));
    deliveringFrame.AddPair('bytesSent', TJSONNumber.Create(0));
    deliveringFrame.AddPair('bytesTotal', TJSONNumber.Create(Length(payload)));
    deliveringFrame.AddPair('binary', TJSONBool.Create(True));
    deliveringFrame.AddPair('compressed', TJSONBool.Create(False));
    Answerer.SendText(deliveringFrame.ToJSON);
  finally
    deliveringFrame.Free;
  end;

  offset := 0;
  while offset < Length(payload) do
  begin
    len := Length(payload) - offset;
    if len > ChunkBytes then len := ChunkBytes;
    SetLength(chunk, len);
    Move(payload[offset], chunk[0], len);
    Answerer.SendBinary(chunk);
    Inc(offset, len);
  end;

  doneFrame := TJSONObject.Create;
  try
    doneFrame.AddPair('requestId', RequestId);
    doneFrame.AddPair('type', 'done');
    doneFrame.AddPair('success', TJSONBool.Create(True));
    Answerer.SendText(doneFrame.ToJSON);
  finally
    doneFrame.Free;
  end;
end;

procedure TMockHub.HandleClientWsMessage(const Data: TBytes; IsText: Boolean);
var
  s: AnsiString;
  root: TJSONObject;
  t, sdp: string;
begin
  if not IsText then Exit;
  if Length(Data) = 0 then Exit;
  SetString(s, PAnsiChar(@Data[0]), Length(Data));
  root := TJSONObject.ParseJSONValue(string(s)) as TJSONObject;
  if root = nil then Exit;
  try
    t := root.GetValue<string>('type', '');
    if t = 'offer' then
    begin
      sdp := root.GetValue<string>('sdp', '');
      if Answerer = nil then
      begin
        Answerer := TRpDcSession.Create(False, 'data');
        Answerer.OnLocalDescription := OnAnswererLocalDescription;
        Answerer.OnLocalCandidate   := OnAnswererLocalCandidate;
        Answerer.OnOpen             := OnAnswererOpen;
        Answerer.OnMessage          := OnAnswererMessage;
        Answerer.Open([]);
      end;
      Answerer.SetRemoteDescription(sdp, 'offer');
    end;
  finally
    root.Free;
  end;
end;

// =====================================================================
// Main
// =====================================================================

var
  arch: string;
  pool: TRpDcHubChannelPool;
  c1, c2: TRpDcHubClient;
  ds: TClientDataSet;
  wsUrl: AnsiString;
  opener: TRpDcHubOpenerFunc;
  failures: Integer;
  expectedTag: string;

begin
  failures := 0;
{$IFDEF WIN64} arch := 'x64'; {$ELSE} arch := 'x86'; {$ENDIF}
  Writeln('=== rpdcpool loopback test (', arch, ') ===');

  if not RpDcInitialize(ResolveDllPath, RTC_LOG_WARNING) then
  begin
    Writeln('FAIL init: ', RpDcLastInitError);
    Halt(1);
  end;

  GMock := TMockHub.Create;
  try
    GMock.Start;
    wsUrl := AnsiString('ws://127.0.0.1:' + IntToStr(GMock.WsServerPort) +
                        '/api/data-session/test/signal?token=fake');
    Writeln('Mock-Hub listening on ', string(wsUrl));

    opener :=
      function(HubDatabaseId: Int64; TimeoutSec: Integer): TRpDcHubClient
      var
        c: TRpDcHubClient;
      begin
        c := TRpDcHubClient.Create('http://localhost:0', '');
        try
          if c.OpenForTest(wsUrl, [], TimeoutSec) then
            Result := c
          else
          begin
            c.Free;
            Result := nil;
          end;
        except
          c.Free;
          Result := nil;
        end;
      end;

    pool := TRpDcHubChannelPool.Create(opener, 60, 600);
    try
      // -- First acquire / execute / release ----------------------
      Writeln;
      Writeln('[1] Pool.Acquire (hubDatabaseId=1, fresh)');
      Flush(Output);
      try
        c1 := pool.Acquire(1, 10);
      except
        on E: Exception do
        begin
          Writeln('EXCEPTION in Acquire: ', E.ClassName, ': ', E.Message);
          Halt(99);
        end;
      end;
      Writeln('   Acquire returned ', NativeUInt(c1));
      Flush(Output);
      if c1 = nil then
      begin
        Writeln('FAIL: first Acquire returned nil');
        Inc(failures);
        Halt(2);
      end;
      Writeln('   client A = $', IntToHex(NativeUInt(c1), 8),
              '  poolCount=', pool.Count);

      ds := TClientDataSet.Create(nil);
      try
        c1.Execute('SELECT *', [], 1, ds, 10);
        Writeln('   query 1 returned ', ds.RecordCount, ' rows');
        if ds.RecordCount <> MockHubRowCount then Inc(failures);
        // Row 1 should be tagged "q1-r1" because this was query #1.
        ds.First;
        expectedTag := 'q1-r1';
        if ds.FieldByName('tag').AsString <> expectedTag then
        begin
          Writeln('FAIL: row 1 tag = "', ds.FieldByName('tag').AsString,
                  '" expected "', expectedTag, '"');
          Inc(failures);
        end;
      finally
        ds.Free;
      end;
      pool.Release(c1);
      Writeln('   released');

      // -- Second acquire MUST hit the cache --------------------------
      Writeln;
      Writeln('[2] Pool.Acquire (hubDatabaseId=1, cached?)');
      c2 := pool.Acquire(1, 10);
      Writeln('   client B = $', IntToHex(NativeUInt(c2), 8),
              '  poolCount=', pool.Count);
      if c2 = nil then
      begin
        Writeln('FAIL: second Acquire returned nil');
        Inc(failures);
        Halt(3);
      end;
      if NativeUInt(c2) <> NativeUInt(c1) then
      begin
        Writeln('FAIL: second Acquire returned a DIFFERENT instance ' +
                '(expected cache hit)');
        Inc(failures);
      end
      else
        Writeln('   CACHE HIT confirmed - same instance returned');

      if pool.Count <> 1 then
      begin
        Writeln('FAIL: pool.Count = ', pool.Count, ' (expected 1)');
        Inc(failures);
      end;

      ds := TClientDataSet.Create(nil);
      try
        c2.Execute('SELECT *', [], 1, ds, 10);
        Writeln('   query 2 returned ', ds.RecordCount, ' rows');
        if ds.RecordCount <> MockHubRowCount then Inc(failures);
        // Row 1 should be tagged "q2-r1" because the Mock-Hub
        // counter increments per query.
        ds.First;
        expectedTag := 'q2-r1';
        if ds.FieldByName('tag').AsString <> expectedTag then
        begin
          Writeln('FAIL: row 1 tag = "', ds.FieldByName('tag').AsString,
                  '" expected "', expectedTag, '"');
          Inc(failures);
        end
        else
          Writeln('   query #2 tag confirmed: same DC, fresh request');
      finally
        ds.Free;
      end;
      pool.Release(c2);

      // -- Status report ---------------------------------------------
      Writeln;
      Writeln('[3] Final status:');
      Writeln(pool.StatusReport);
    finally
      pool.Free;
    end;
  finally
    GMock.Free;
  end;
  RpDcShutdown;

  if failures = 0 then
  begin
    Writeln('=== PASSED ===');
    Halt(0);
  end
  else
  begin
    Writeln('=== FAILED (', failures, ' issue(s)) ===');
    Halt(10);
  end;
end.
