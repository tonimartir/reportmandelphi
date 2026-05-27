program test_datadirect;

{*******************************************************}
{                                                       }
{   Loopback end-to-end test for rpdatadirect.pas.      }
{                                                       }
{   See header in rpdatadirect.pas for the protocol.    }
{   This .dpr instantiates two TRpDcSession in the same }
{   process and wires their OnLocal* events into each   }
{   other - no external signaling server.               }
{                                                       }
{*******************************************************}

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.IOUtils,
  System.DateUtils,
  Data.DB,
  Datasnap.DBClient,
  MidasLib,
  rplibdatachannel in '..\..\rplibdatachannel.pas',
  rpfastserializer in '..\..\rpfastserializer.pas',
  rpdatadirect    in '..\..\rpdatadirect.pas';

const
  TestRowCount  = 50;
  TestStringLen = 64;

type
  TLoopbackHarness = class
  public
    SessionA, SessionB: TRpDcSession;
    StateLock: TCriticalSection;
    PingReceivedByB: Boolean;
    DatasetReceivedByB: Boolean;
    DatasetByBHadCorrectRows: Boolean;
    DatasetByBHadCorrectFields: Boolean;
    AckReceivedByA: Boolean;
    AOpened: Boolean;
    BOpened: Boolean;
    BReceivedBytes: Int64;
    BExpectedBytes: Int64;
    AConnectionMode: TRpDcConnectionMode;
    BConnectionMode: TRpDcConnectionMode;
    ErrorMsg: string;
    ExpectedBin: TBytes;
    ReceivedBin: TBytes;
    constructor Create;
    destructor Destroy; override;
    procedure SafeLog(const S: string);

    // A side
    procedure AOnLocalDescription(Sender: TObject;
                                  const Sdp, SdpType: string);
    procedure AOnLocalCandidate(Sender: TObject;
                                const Candidate, Mid: string);
    procedure AOnOpen(Sender: TObject);
    procedure AOnMessage(Sender: TObject; const Data: TBytes; IsText: Boolean);
    procedure AOnError(Sender: TObject; const Msg: string);

    // B side
    procedure BOnLocalDescription(Sender: TObject;
                                  const Sdp, SdpType: string);
    procedure BOnLocalCandidate(Sender: TObject;
                                const Candidate, Mid: string);
    procedure BOnOpen(Sender: TObject);
    procedure BOnMessage(Sender: TObject; const Data: TBytes; IsText: Boolean);
    procedure BOnError(Sender: TObject; const Msg: string);
  end;

var
  H: TLoopbackHarness;

constructor TLoopbackHarness.Create;
begin
  inherited;
  StateLock := TCriticalSection.Create;
end;

destructor TLoopbackHarness.Destroy;
begin
  StateLock.Free;
  inherited;
end;

procedure TLoopbackHarness.SafeLog(const S: string);
begin
  StateLock.Acquire;
  try
    Writeln(S);
  finally
    StateLock.Release;
  end;
end;

function ResolveDllPath: string;
var baseDir: string;
begin
  baseDir := ExtractFilePath(ParamStr(0));
{$IFDEF WIN64}
  Result := baseDir + '..\..\..\activex_ai\resources\x64\datachannel.dll';
{$ELSE}
  Result := baseDir + '..\..\..\activex_ai\resources\x86\datachannel.dll';
{$ENDIF}
  Result := ExpandFileName(Result);
end;

function BuildFixtureDataset: TClientDataSet;
var
  i: Integer;
  s: string;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('id', ftInteger);
  with Result.FieldDefs.AddFieldDef do
  begin
    Name := 'name';
    DataType := ftWideString;
    Size := 256;
  end;
  Result.FieldDefs.Add('value', ftFloat);
  Result.FieldDefs.Add('flag',  ftBoolean);
  Result.FieldDefs.Add('when',  ftDateTime);
  Result.CreateDataSet;

  for i := 1 to TestRowCount do
  begin
    Result.Append;
    Result.FieldByName('id').AsInteger := i;
    s := Format('row %.4d - sample text -', [i]);
    while Length(s) < TestStringLen do
      s := s + 'X';
    Result.FieldByName('name').AsString := s;
    Result.FieldByName('value').AsFloat := i * 1.25;
    Result.FieldByName('flag').AsBoolean := (i mod 2) = 0;
    Result.FieldByName('when').AsDateTime :=
      EncodeDateTime(2026, 5, 27, 9, 0, 0, 0) + (i / 1440);
    Result.Post;
  end;
end;

function CompareDatasets(a, b: TClientDataSet; var Mismatch: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  if a.FieldCount <> b.FieldCount then
  begin
    Mismatch := Format('field count: %d vs %d', [a.FieldCount, b.FieldCount]);
    Exit;
  end;
  if a.RecordCount <> b.RecordCount then
  begin
    Mismatch := Format('row count: %d vs %d', [a.RecordCount, b.RecordCount]);
    Exit;
  end;
  for i := 0 to a.FieldCount - 1 do
    if a.Fields[i].FieldName <> b.Fields[i].FieldName then
    begin
      Mismatch := Format('field name [%d]: %s vs %s',
                         [i, a.Fields[i].FieldName, b.Fields[i].FieldName]);
      Exit;
    end;

  a.First; b.First;
  while not a.Eof do
  begin
    for i := 0 to a.FieldCount - 1 do
    begin
      if a.Fields[i].IsNull <> b.Fields[i].IsNull then
      begin
        Mismatch := Format('row %d field %s null mismatch',
                           [a.RecNo, a.Fields[i].FieldName]);
        Exit;
      end;
      if (not a.Fields[i].IsNull) and
         (a.Fields[i].AsString <> b.Fields[i].AsString) then
      begin
        Mismatch := Format('row %d field %s: "%s" vs "%s"',
                           [a.RecNo, a.Fields[i].FieldName,
                            a.Fields[i].AsString, b.Fields[i].AsString]);
        Exit;
      end;
    end;
    a.Next; b.Next;
  end;
  Result := True;
end;

procedure TLoopbackHarness.AOnLocalDescription(Sender: TObject;
                                               const Sdp, SdpType: string);
begin
  SafeLog('[A] local description (' + SdpType + ', ' +
          IntToStr(Length(Sdp)) + ' bytes) -> B');
  SessionB.SetRemoteDescription(Sdp, SdpType);
end;

procedure TLoopbackHarness.AOnLocalCandidate(Sender: TObject;
                                             const Candidate, Mid: string);
begin
  SafeLog('[A] local candidate -> B: ' + Candidate);
  SessionB.AddRemoteCandidate(Candidate, Mid);
end;

procedure TLoopbackHarness.AOnOpen(Sender: TObject);
var
  fixtureDs: TClientDataSet;
  ms: TMemoryStream;
  bytes: TBytes;
begin
  StateLock.Acquire;
  try
    AOpened := True;
    AConnectionMode := SessionA.ConnectionMode;
  finally
    StateLock.Release;
  end;
  SafeLog('[A] DataChannel OPEN');

  SessionA.SendText('PING');

  fixtureDs := BuildFixtureDataset;
  try
    ms := TMemoryStream.Create;
    try
      FastSerializeDataSet(fixtureDs, ms, 'LoopbackTest');
      SetLength(bytes, ms.Size);
      if ms.Size > 0 then
      begin
        ms.Position := 0;
        ms.ReadBuffer(bytes[0], ms.Size);
      end;
      ExpectedBin := bytes;
      StateLock.Acquire;
      try
        BExpectedBytes := Length(bytes);
      finally
        StateLock.Release;
      end;
      SafeLog('[A] sending FastSerializer payload, ' +
              IntToStr(Length(bytes)) + ' bytes');
      SessionA.SendBinary(bytes);
    finally
      ms.Free;
    end;
  finally
    fixtureDs.Free;
  end;
end;

procedure TLoopbackHarness.AOnMessage(Sender: TObject; const Data: TBytes;
                                      IsText: Boolean);
var
  msg: AnsiString;
begin
  if IsText then
  begin
    SetString(msg, PAnsiChar(@Data[0]), Length(Data));
    SafeLog('[A] text from B: "' + string(msg) + '"');
    if string(msg) = 'ACK' then
    begin
      StateLock.Acquire;
      try
        AckReceivedByA := True;
      finally
        StateLock.Release;
      end;
    end;
  end;
end;

procedure TLoopbackHarness.AOnError(Sender: TObject; const Msg: string);
begin
  SafeLog('[A] ERROR: ' + Msg);
  StateLock.Acquire;
  try
    ErrorMsg := 'A: ' + Msg;
  finally
    StateLock.Release;
  end;
end;

procedure TLoopbackHarness.BOnLocalDescription(Sender: TObject;
                                               const Sdp, SdpType: string);
begin
  SafeLog('[B] local description (' + SdpType + ', ' +
          IntToStr(Length(Sdp)) + ' bytes) -> A');
  SessionA.SetRemoteDescription(Sdp, SdpType);
end;

procedure TLoopbackHarness.BOnLocalCandidate(Sender: TObject;
                                             const Candidate, Mid: string);
begin
  SafeLog('[B] local candidate -> A: ' + Candidate);
  SessionA.AddRemoteCandidate(Candidate, Mid);
end;

procedure TLoopbackHarness.BOnOpen(Sender: TObject);
begin
  StateLock.Acquire;
  try
    BOpened := True;
    BConnectionMode := SessionB.ConnectionMode;
  finally
    StateLock.Release;
  end;
  SafeLog('[B] DataChannel OPEN');
end;

procedure TLoopbackHarness.BOnMessage(Sender: TObject; const Data: TBytes;
                                      IsText: Boolean);
var
  msg: AnsiString;
  ms: TMemoryStream;
  receivedDs, expectedDs: TClientDataSet;
  mismatch: string;
  ok: Boolean;
begin
  if IsText then
  begin
    SetString(msg, PAnsiChar(@Data[0]), Length(Data));
    SafeLog('[B] text from A: "' + string(msg) + '"');
    if string(msg) = 'PING' then
    begin
      StateLock.Acquire;
      try
        PingReceivedByB := True;
      finally
        StateLock.Release;
      end;
    end;
    Exit;
  end;

  SafeLog('[B] binary frame: ' + IntToStr(Length(Data)) + ' bytes');
  ReceivedBin := Copy(Data, 0, Length(Data));
  StateLock.Acquire;
  try
    BReceivedBytes := Length(Data);
  finally
    StateLock.Release;
  end;

  if not IsFastSerialized(Data) then
  begin
    SafeLog('[B] FAIL: bytes do not have FastSerializer signature');
    Exit;
  end;

  ms := TMemoryStream.Create;
  receivedDs := TClientDataSet.Create(nil);
  expectedDs := BuildFixtureDataset;
  try
    ms.WriteBuffer(Data[0], Length(Data));
    ms.Position := 0;
    try
      FastDeserializeDataSet(receivedDs, ms);
    except
      on E: Exception do
      begin
        SafeLog('[B] FAIL deserialize: ' + E.Message);
        Exit;
      end;
    end;

    StateLock.Acquire;
    try
      DatasetReceivedByB := True;
      DatasetByBHadCorrectRows := (receivedDs.RecordCount = TestRowCount);
      DatasetByBHadCorrectFields := (receivedDs.FieldCount = 5);
    finally
      StateLock.Release;
    end;

    ok := CompareDatasets(expectedDs, receivedDs, mismatch);
    if ok then
      SafeLog('[B] dataset matches expected (' +
              IntToStr(receivedDs.RecordCount) + ' rows)')
    else
      SafeLog('[B] dataset MISMATCH: ' + mismatch);

    SessionB.SendText('ACK');
  finally
    expectedDs.Free;
    receivedDs.Free;
    ms.Free;
  end;
end;

procedure TLoopbackHarness.BOnError(Sender: TObject; const Msg: string);
begin
  SafeLog('[B] ERROR: ' + Msg);
  StateLock.Acquire;
  try
    if ErrorMsg = '' then ErrorMsg := 'B: ' + Msg;
  finally
    StateLock.Release;
  end;
end;

function WaitFor(const Condition: TFunc<Boolean>; TimeoutMs: Integer): Boolean;
var
  startTick: Cardinal;
begin
  startTick := GetTickCount;
  Result := False;
  while not Condition do
  begin
    if GetTickCount - startTick > Cardinal(TimeoutMs) then
      Exit;
    Sleep(50);
  end;
  Result := True;
end;

function ConnectionModeName(m: TRpDcConnectionMode): string;
begin
  case m of
    rcmDirectP2P: Result := 'P2P (host)';
    rcmHolePunch: Result := 'HolePunch (NAT/STUN)';
    rcmRelay:     Result := 'Relay (TURN)';
  else            Result := 'Unknown';
  end;
end;

var
  arch, dllPath: string;
  failures: Integer;
begin
  failures := 0;
  H := TLoopbackHarness.Create;
  try
{$IFDEF WIN64}
    arch := 'x64';
{$ELSE}
    arch := 'x86';
{$ENDIF}
    Writeln('=== rpdatadirect loopback test (', arch, ') ===');
    Writeln;

    dllPath := ResolveDllPath;
    Writeln('[1] Loading libdatachannel from: ', dllPath);
    if not RpDcInitialize(dllPath, RTC_LOG_WARNING) then
    begin
      Writeln('FAIL: ', RpDcLastInitError);
      Halt(1);
    end;
    Writeln('   library ready');

    Writeln('[2] Creating sessions A (initiator) and B (answerer)');
    H.SessionA := TRpDcSession.Create(True);
    H.SessionB := TRpDcSession.Create(False);

    H.SessionA.OnLocalDescription := H.AOnLocalDescription;
    H.SessionA.OnLocalCandidate   := H.AOnLocalCandidate;
    H.SessionA.OnOpen             := H.AOnOpen;
    H.SessionA.OnMessage          := H.AOnMessage;
    H.SessionA.OnError            := H.AOnError;

    H.SessionB.OnLocalDescription := H.BOnLocalDescription;
    H.SessionB.OnLocalCandidate   := H.BOnLocalCandidate;
    H.SessionB.OnOpen             := H.BOnOpen;
    H.SessionB.OnMessage          := H.BOnMessage;
    H.SessionB.OnError            := H.BOnError;
    Writeln('   sessions wired');

    Writeln('[3] Opening peer connections (no ICE servers, host-only)');
    H.SessionB.Open([]);
    H.SessionA.Open([]);

    Writeln('[4] Waiting for DataChannel open on both sides (10s)...');
    WaitFor(function: Boolean
            begin
              H.StateLock.Acquire;
              try
                Result := H.AOpened and H.BOpened;
              finally
                H.StateLock.Release;
              end;
            end, 10000);

    if not H.AOpened then
    begin
      Writeln('FAIL: A never opened the DataChannel');
      Inc(failures);
    end;
    if not H.BOpened then
    begin
      Writeln('FAIL: B never opened the DataChannel');
      Inc(failures);
    end;

    if failures > 0 then
    begin
      Writeln('Aborting (open failed)');
      Halt(2);
    end;

    Writeln(Format('   A transport: %s', [ConnectionModeName(H.AConnectionMode)]));
    Writeln(Format('   B transport: %s', [ConnectionModeName(H.BConnectionMode)]));

    Writeln('[5] Waiting for PING + payload + ACK (10s)...');
    WaitFor(function: Boolean
            begin
              H.StateLock.Acquire;
              try
                Result := H.PingReceivedByB and
                          H.DatasetReceivedByB and
                          H.AckReceivedByA;
              finally
                H.StateLock.Release;
              end;
            end, 10000);

    Writeln;
    Writeln('Results:');
    Writeln(Format('   PING received by B          : %s', [BoolToStr(H.PingReceivedByB, True)]));
    Writeln(Format('   Dataset received by B        : %s', [BoolToStr(H.DatasetReceivedByB, True)]));
    Writeln(Format('   Dataset row count correct    : %s', [BoolToStr(H.DatasetByBHadCorrectRows, True)]));
    Writeln(Format('   Dataset field count correct  : %s', [BoolToStr(H.DatasetByBHadCorrectFields, True)]));
    Writeln(Format('   ACK received by A            : %s', [BoolToStr(H.AckReceivedByA, True)]));
    Writeln(Format('   Bytes expected / received    : %d / %d', [H.BExpectedBytes, H.BReceivedBytes]));
    if H.ErrorMsg <> '' then
      Writeln('   Last error                   : ', H.ErrorMsg);
    Writeln;

    if not H.PingReceivedByB then Inc(failures);
    if not H.DatasetReceivedByB then Inc(failures);
    if not H.DatasetByBHadCorrectRows then Inc(failures);
    if not H.DatasetByBHadCorrectFields then Inc(failures);
    if not H.AckReceivedByA then Inc(failures);
    if H.BReceivedBytes <> H.BExpectedBytes then Inc(failures);

    Writeln('[6] Closing sessions');
    H.SessionA.Close;
    H.SessionB.Close;
    FreeAndNil(H.SessionA);
    FreeAndNil(H.SessionB);
    RpDcShutdown;

    if failures = 0 then
    begin
      Writeln;
      Writeln('=== PASSED ===');
      Halt(0);
    end
    else
    begin
      Writeln;
      Writeln('=== FAILED (', failures, ' issue(s)) ===');
      Halt(10);
    end;
  finally
    H.Free;
  end;
end.
