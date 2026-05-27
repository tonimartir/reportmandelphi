program test_libdc;

{*******************************************************}
{                                                       }
{   Smoke test for rplibdatachannel Pascal binding.     }
{                                                       }
{   Steps verified end-to-end:                          }
{    1. LoadLibrary finds datachannel.dll + companions  }
{       (libssl, libcrypto, juice, legacy) in the same  }
{       folder.                                         }
{    2. cdecl calling convention is correct (otherwise  }
{       crash on x86 immediately on the first call).    }
{    3. rtcConfiguration layout matches the C struct    }
{       (otherwise rtcCreatePeerConnection returns      }
{       negative or crashes).                           }
{    4. cdecl Pascal callbacks are invoked from the     }
{       library's worker threads with valid arguments   }
{       (state, gathering, candidate events).           }
{    5. ICE gathering runs and discovers at least one   }
{       host candidate (loopback or LAN).               }
{    6. rtcGetLocalDescription returns a valid SDP      }
{       offer string.                                   }
{    7. Clean teardown via rtcDeletePeerConnection +    }
{       UnloadLibDataChannel.                           }
{                                                       }
{*******************************************************}

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  System.SyncObjs,
  rplibdatachannel in '..\..\rplibdatachannel.pas';

var
  gStateChanges: Integer = 0;
  gGatheringChanges: Integer = 0;
  gCandidates: Integer = 0;
  gLogLines: Integer = 0;
  gLastSdpLength: Integer = 0;
  gOutputLock: TCriticalSection;

procedure SafeWriteln(const S: string);
begin
  gOutputLock.Acquire;
  try
    Writeln(S);
  finally
    gOutputLock.Release;
  end;
end;

procedure OnLog(level: rtcLogLevel; const Msg: PAnsiChar); cdecl;
const
  LevelName: array[rtcLogLevel] of string = (
    'NONE','FATAL','ERROR','WARN','INFO','DEBUG','VERBOSE');
var
  txt: string;
begin
  AtomicIncrement(gLogLines);
  if Msg <> nil then
    txt := string(AnsiString(Msg))
  else
    txt := '<null>';
  SafeWriteln('   [lib:' + LevelName[level] + '] ' + txt);
end;

procedure OnStateChange(pc: Integer; state: rtcState; ptr: Pointer); cdecl;
const
  Names: array[rtcState] of string = (
    'NEW','CONNECTING','CONNECTED','DISCONNECTED','FAILED','CLOSED');
begin
  AtomicIncrement(gStateChanges);
  SafeWriteln(Format('   [event] state pc=%d -> %s', [pc, Names[state]]));
end;

procedure OnGatheringChange(pc: Integer; state: rtcGatheringState; ptr: Pointer); cdecl;
const
  Names: array[rtcGatheringState] of string = (
    'NEW','IN-PROGRESS','COMPLETE');
begin
  AtomicIncrement(gGatheringChanges);
  SafeWriteln(Format('   [event] gathering pc=%d -> %s', [pc, Names[state]]));
end;

procedure OnLocalCandidate(pc: Integer; const cand, mid: PAnsiChar; ptr: Pointer); cdecl;
var
  candStr, midStr: string;
begin
  AtomicIncrement(gCandidates);
  if cand <> nil then candStr := string(AnsiString(cand)) else candStr := '<null>';
  if mid  <> nil then midStr  := string(AnsiString(mid))  else midStr  := '<null>';
  SafeWriteln(Format('   [event] candidate pc=%d mid=%s -> %s', [pc, midStr, candStr]));
end;

function ResolveDllPath: string;
var
  baseDir: string;
begin
  baseDir := ExtractFilePath(ParamStr(0));
{$IFDEF WIN64}
  Result := baseDir + '..\..\..\activex_ai\resources\x64\datachannel.dll';
{$ELSE}
  Result := baseDir + '..\..\..\activex_ai\resources\x86\datachannel.dll';
{$ENDIF}
  Result := ExpandFileName(Result);
end;

procedure Step(const N: Integer; const desc: string);
begin
  Writeln(Format('[%d] %s', [N, desc]));
end;

procedure OK;
begin
  Writeln('   [OK]');
end;

procedure Fail(const N: Integer; const why: string);
begin
  Writeln(Format('   [FAIL #%d] %s', [N, why]));
  Halt(N);
end;

var
  dllPath: string;
  cfg: rtcConfiguration;
  pc, dc, ret: Integer;
  sdpBuf: array[0..8191] of AnsiChar;
  startTick: Cardinal;
  arch: string;
begin
  gOutputLock := TCriticalSection.Create;
  try
{$IFDEF WIN64}
    arch := 'x64';
{$ELSE}
    arch := 'x86';
{$ENDIF}
    Writeln('=== libdatachannel binding smoke test (', arch, ') ===');
    Writeln;

    dllPath := ResolveDllPath;

    Step(1, 'LoadLibDataChannel');
    Writeln('   path: ', dllPath);
    if not LoadLibDataChannel(dllPath) then
      Fail(1, GetLastLoadError);
    OK;

    Step(2, 'rtcInitLogger(INFO)');
    rtcInitLogger(RTC_LOG_INFO, @OnLog);
    OK;

    Step(3, 'rtcCreatePeerConnection (no ICE servers, defaults)');
    FillChar(cfg, SizeOf(cfg), 0);
    cfg.certificateType    := RTC_CERTIFICATE_DEFAULT;
    cfg.iceTransportPolicy := RTC_TRANSPORT_POLICY_ALL;
    cfg.enableIceTcp       := True;
    pc := rtcCreatePeerConnection(@cfg);
    if pc < 0 then
      Fail(3, Format('rtcCreatePeerConnection returned %d', [pc]));
    Writeln('   PeerConnection id=', pc);
    OK;

    Step(4, 'Register state/gathering/candidate callbacks');
    if rtcSetStateChangeCallback(pc, @OnStateChange) < 0 then
      Fail(4, 'rtcSetStateChangeCallback');
    if rtcSetGatheringStateChangeCallback(pc, @OnGatheringChange) < 0 then
      Fail(4, 'rtcSetGatheringStateChangeCallback');
    if rtcSetLocalCandidateCallback(pc, @OnLocalCandidate) < 0 then
      Fail(4, 'rtcSetLocalCandidateCallback');
    OK;

    Step(5, 'rtcCreateDataChannel("rpdc-test")');
    dc := rtcCreateDataChannel(pc, 'rpdc-test');
    if dc < 0 then
      Fail(5, Format('rtcCreateDataChannel returned %d', [dc]));
    Writeln('   DataChannel id=', dc);
    OK;

    Step(6, 'rtcSetLocalDescription(nil) -> auto-offer + start gathering');
    ret := rtcSetLocalDescription(pc, nil);
    if ret < 0 then
      Fail(6, Format('rtcSetLocalDescription returned %d', [ret]));
    OK;

    Step(7, 'Wait up to 5 seconds for ICE gathering to complete...');
    startTick := GetTickCount;
    while (GetTickCount - startTick < 5000) and (gGatheringChanges < 2) do
      Sleep(50);
    Writeln(Format('   counters: state=%d  gathering=%d  candidates=%d  loglines=%d',
                   [gStateChanges, gGatheringChanges, gCandidates, gLogLines]));

    Step(8, 'rtcGetLocalDescription');
    FillChar(sdpBuf, SizeOf(sdpBuf), 0);
    ret := rtcGetLocalDescription(pc, @sdpBuf[0], SizeOf(sdpBuf));
    if ret < 0 then
      Fail(8, Format('rtcGetLocalDescription returned %d', [ret]));
    gLastSdpLength := ret;
    Writeln('   SDP bytes returned: ', ret);
    Writeln('   first 80 chars: ', Copy(string(AnsiString(PAnsiChar(@sdpBuf[0]))), 1, 80));
    OK;

    Step(9, 'rtcDeletePeerConnection');
    if rtcDeletePeerConnection(pc) < 0 then
      Fail(9, 'rtcDeletePeerConnection returned negative');
    OK;

    Step(10, 'UnloadLibDataChannel');
    if not UnloadLibDataChannel then
      Fail(10, 'UnloadLibDataChannel returned False');
    OK;

    Writeln;
    if (gCandidates > 0) and (gGatheringChanges >= 2) and (gLastSdpLength > 0) then
    begin
      Writeln('=== PASSED ===');
      Writeln(Format('Final: %d state changes, %d gathering events, %d candidates, SDP %d bytes',
                     [gStateChanges, gGatheringChanges, gCandidates, gLastSdpLength]));
      Halt(0);
    end
    else
    begin
      Writeln('=== PARTIAL ===');
      Writeln('Library loaded and basic API works, but ICE produced fewer events than expected.');
      Writeln('Possible causes: firewall blocking, no network interfaces, slow gathering.');
      Halt(50);
    end;
  finally
    gOutputLock.Free;
  end;
end.
