program test_dchub_loopback;

// =====================================================================
//   Loopback test for rpdchub.pas (full Hub-protocol exchange).
//
//   In a single process we run:
//
//    Client side -----------------------------------------------
//     TRpDcHubClient (the unit under test) opens a WS to the local
//     Mock-Hub, sends an offer through it, waits for the wrapped
//     answer, opens the DataChannel, sends an executeSql request,
//     and reads back a FastSerializer-encoded DataSet wrapped in
//     progress/binary/done frames.
//
//    Mock-Hub side ---------------------------------------------
//     A libdatachannel WebSocket server (rtcCreateWebSocketServer)
//     accepts the client. For each client WS:
//      - Receives the offer text frame.
//      - Spins up a Pascal answerer peer (TRpDcSession with
//        IsInitiator=False).
//      - Wires the answerer's LocalDescription back over the WS
//        wrapped as {source:"hub",body:'{success,data:{type,sdp}}'}.
//      - Wires the answerer's ICE candidates as
//        {source:"agent",payload:{type:"ice",candidate:{...}}}.
//      - When the answerer DC opens, waits for the JSON
//        {requestId, action:"executeSql"} from the client, then
//        responds with progress frames and a binary FastSerializer
//        DataSet wrapped between "delivering binary=true" and
//        "done success=true".
//
//   The test PASSES when the client decodes the dataset and finds
//   the expected row count + field values.
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
  rpdchub         in '..\..\rpdchub.pas';

const
  MockHubRowCount = 30;

type
  TMockHub = class
  public
    StateLock: TCriticalSection;
    WsServerId: Integer;
    WsServerPort: Integer;
    ClientWsId: Integer;  // The accepted client WebSocket on the server side.
    Answerer: TRpDcSession;
    OfferReceived: Boolean;
    DcOpened: Boolean;
    RequestReceived: Boolean;
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

// ============================================================
// Mock-Hub WS server callbacks (cdecl)
// ============================================================

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

// ============================================================
// TMockHub
// ============================================================

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
  if Answerer <> nil then
    Answerer.Free;
  StateLock.Free;
  inherited;
end;

procedure TMockHub.Start;
var
  cfg: rtcWsServerConfiguration;
begin
  FillChar(cfg, SizeOf(cfg), 0);
  cfg.port := 0;                // automatic port
  cfg.enableTls := False;
  cfg.bindAddress := '127.0.0.1';
  cfg.maxMessageSize := 16 * 1024 * 1024;
  WsServerId := rtcCreateWebSocketServer(@cfg, @McWsServerClientCb);
  if WsServerId < 0 then
    raise Exception.CreateFmt('rtcCreateWebSocketServer failed: %d',
                              [WsServerId]);
  rtcSetUserPointer(WsServerId, Self);
  WsServerPort := rtcGetWebSocketServerPort(WsServerId);
  Writeln('[MockHub] listening on ws://127.0.0.1:', WsServerPort, '/');
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
  // The Hub wraps the agent's reply as:
  //   {"source":"hub","body":"<inner serialized JSON>"}
  // where the inner JSON is {"success":true,"data":{"type":"answer","sdp":..}}
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
  Writeln('[MockHub] -> client: hub-wrapped ', SdpType,
          ' (', Length(Sdp), ' bytes sdp)');
  SendToClient(frameStr);
end;

procedure TMockHub.OnAnswererLocalCandidate(Sender: TObject;
                                             const Candidate, Mid: string);
var
  wrap, payload, candObj: TJSONObject;
  frameStr: string;
begin
  // Wrapped as {source:"agent", payload:{type:"ice", candidate:{...}}}.
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
  StateLock.Acquire;
  try
    DcOpened := True;
  finally
    StateLock.Release;
  end;
  Writeln('[MockHub] DC open on the answerer side');
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
    Writeln('[MockHub] DC msg from client: action="', action, '" id=', rid);
    StateLock.Acquire;
    try
      RequestReceived := True;
    finally
      StateLock.Release;
    end;
    if action = 'executeSql' then
      RespondToExecuteSql(rid);
  finally
    root.Free;
  end;
end;

procedure TMockHub.RespondToExecuteSql(const RequestId: string);
var
  ds: TClientDataSet;
  ms: TMemoryStream;
  payload: TBytes;
  chunk: TBytes;
  offset, len: Integer;
  i: Integer;
  progressFrame, doneFrame, deliveringFrame: TJSONObject;
const
  ChunkBytes = 8 * 1024;
begin
  // Build a small fixture dataset.
  ds := TClientDataSet.Create(nil);
  try
    ds.FieldDefs.Add('id', ftInteger);
    with ds.FieldDefs.AddFieldDef do
    begin
      Name := 'note';
      DataType := ftWideString;
      Size := 256;
    end;
    ds.FieldDefs.Add('total', ftFloat);
    ds.CreateDataSet;
    for i := 1 to MockHubRowCount do
    begin
      ds.Append;
      ds.FieldByName('id').AsInteger := i;
      ds.FieldByName('note').AsString := 'mock-row-' + IntToStr(i);
      ds.FieldByName('total').AsFloat := i * 7.5;
      ds.Post;
    end;
    ms := TMemoryStream.Create;
    try
      FastSerializeDataSet(ds, ms, 'MockHubResult');
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

  Writeln('[MockHub] payload built, ', Length(payload), ' bytes uncompressed');

  // Send a "progress phase=executing" first (text).
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

  // Announce delivering with binary=true, compressed=false (skip zlib
  // for this test - we already validated zlib in 5.3).
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

  // Stream the binary payload in chunks.
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

  // Final done frame.
  doneFrame := TJSONObject.Create;
  try
    doneFrame.AddPair('requestId', RequestId);
    doneFrame.AddPair('type', 'done');
    doneFrame.AddPair('success', TJSONBool.Create(True));
    Answerer.SendText(doneFrame.ToJSON);
  finally
    doneFrame.Free;
  end;
  Writeln('[MockHub] done frame sent');
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
  if root = nil then
  begin
    Writeln('[MockHub] WS msg from client: <not JSON, ', Length(Data), 'B>');
    Exit;
  end;
  try
    t := root.GetValue<string>('type', '');
    Writeln('[MockHub] WS msg from client: type="', t, '"');

    if t = 'offer' then
    begin
      sdp := root.GetValue<string>('sdp', '');
      StateLock.Acquire;
      try
        OfferReceived := True;
      finally
        StateLock.Release;
      end;

      // Spin up the Pascal answerer with this offer.
      if Answerer = nil then
      begin
        Answerer := TRpDcSession.Create(False, 'data');
        Answerer.OnLocalDescription := OnAnswererLocalDescription;
        Answerer.OnLocalCandidate   := OnAnswererLocalCandidate;
        Answerer.OnOpen             := OnAnswererOpen;
        Answerer.OnMessage          := OnAnswererMessage;
        Answerer.Open([]);
      end;
      // Feed the offer; libdatachannel will produce an answer
      // automatically and call OnAnswererLocalDescription which wraps
      // it for the client.
      Answerer.SetRemoteDescription(sdp, 'offer');
    end
    else if t = 'ice' then
    begin
      // Trickle candidate from client. Pass it to the answerer.
      // (Non-trickle clients send candidates inside the offer SDP, in
      // which case this branch never fires.)
      if Answerer <> nil then
      begin
        // Extract candidate JSON object
        // root.candidate is the candObj
        // Here we accept inline 'candidate' as a sub-object or omit if absent.
        // Minimal: ignore if not present.
      end;
    end;
  finally
    root.Free;
  end;
end;

// ============================================================
// Main
// ============================================================

var
  arch: string;
  client: TRpDcHubClient;
  ds: TClientDataSet;
  wsUrl: AnsiString;
  failures: Integer;
  i: Integer;
begin
  failures := 0;
{$IFDEF WIN64} arch := 'x64'; {$ELSE} arch := 'x86'; {$ENDIF}
  Writeln('=== rpdchub loopback test (', arch, ') ===');

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
    Writeln('Client connecting to ', string(wsUrl));

    client := TRpDcHubClient.Create('http://localhost:0', '');
    try
      if not client.OpenForTest(wsUrl, [], 10) then
      begin
        Writeln('FAIL: client.OpenForTest returned False');
        Halt(2);
      end;
      Writeln('Client DC open. mode=', Integer(client.ConnectionMode));

      ds := TClientDataSet.Create(nil);
      try
        // The Mock-Hub ignores the SQL and replies with the fixture.
        client.Execute('SELECT 1', [], 0, ds, 10);

        Writeln('Client received dataset: ', ds.RecordCount, ' rows, ',
                ds.FieldCount, ' cols');
        if ds.RecordCount <> MockHubRowCount then
        begin
          Writeln('FAIL: row count ', ds.RecordCount, ' <> ', MockHubRowCount);
          Inc(failures);
        end;
        if ds.FieldCount <> 3 then
        begin
          Writeln('FAIL: field count ', ds.FieldCount, ' <> 3');
          Inc(failures);
        end;
        // Spot-check a few rows.
        ds.First;
        i := 0;
        while not ds.Eof do
        begin
          Inc(i);
          if ds.FieldByName('id').AsInteger <> i then
          begin
            Writeln('FAIL: row ', i, ' id mismatch ',
                    ds.FieldByName('id').AsInteger);
            Inc(failures);
            Break;
          end;
          if ds.FieldByName('note').AsString <> 'mock-row-' + IntToStr(i) then
          begin
            Writeln('FAIL: row ', i, ' note mismatch ',
                    ds.FieldByName('note').AsString);
            Inc(failures);
            Break;
          end;
          ds.Next;
        end;
        if failures = 0 then
          Writeln('All ', MockHubRowCount, ' rows verified.');
      finally
        ds.Free;
      end;
    finally
      client.Free;
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
