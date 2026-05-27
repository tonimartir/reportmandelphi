{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpdatadirect                                    }
{                                                       }
{       High-level WebRTC DataChannel session for the   }
{       Reportman Direct Channel client. Wraps a single }
{       PeerConnection + one DataChannel using the      }
{       rplibdatachannel C-API binding.                 }
{                                                       }
{       This unit deliberately stops at the transport   }
{       layer: it exposes hooks for the application to  }
{       carry signaling messages (offer/answer/ICE) to  }
{       the remote peer, but does NOT contain a WS or   }
{       HTTP signaling client. Different deployments    }
{       use different transports:                       }
{                                                       }
{        - Reportman.Hub signaling via WebSocket        }
{          (use libdatachannel's rtcCreateWebSocket and }
{          shuttle the events between two TRpDcSession  }
{          via the OnLocal* callbacks)                  }
{        - In-process loopback (the cross-test in       }
{          tests/datadirect_test uses this to validate  }
{          everything works without external services). }
{                                                       }
{       Threading: libdatachannel invokes callbacks on  }
{       its worker threads. The Pascal-side events      }
{       fired by this class are therefore NOT on the    }
{       main thread. Subscribers must take their own    }
{       synchronization measures (TThread.Queue or      }
{       similar) when touching the VCL.                 }
{                                                       }
{       Copyright (c) 2026 Toni Martir                  }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpdatadirect;

interface

{$I rpconf.inc}

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  rplibdatachannel;

type
  // The transport mode used by the selected ICE candidate pair.
  // Filled in after the DataChannel opens via rtcGetSelectedCandidatePair.
  // Useful for UI ("Direct LAN" vs "Hole-punch" vs "Relay").
  TRpDcConnectionMode = (
    rcmUnknown,
    rcmDirectP2P,   // host <-> host on the same LAN
    rcmHolePunch,   // srflx / prflx, NAT traversal
    rcmRelay        // relayed via TURN
  );

  TRpDcLocalDescriptionEvent = procedure(Sender: TObject;
                                          const Sdp, SdpType: string) of object;
  TRpDcLocalCandidateEvent   = procedure(Sender: TObject;
                                          const Candidate, Mid: string) of object;
  TRpDcMessageEvent          = procedure(Sender: TObject;
                                          const Data: TBytes;
                                          IsText: Boolean) of object;
  TRpDcNotifyEvent           = procedure(Sender: TObject) of object;
  TRpDcErrorEvent            = procedure(Sender: TObject;
                                          const Msg: string) of object;

  TRpDcSession = class
  private
    FPeerId: Integer;
    FDataChannelId: Integer;
    FIsInitiator: Boolean;
    FState: rtcState;
    FIceState: rtcIceState;
    FConnectionMode: TRpDcConnectionMode;
    FStateLock: TCriticalSection;
    FLastError: string;
    FLabel: AnsiString;

    FOnLocalDescription: TRpDcLocalDescriptionEvent;
    FOnLocalCandidate: TRpDcLocalCandidateEvent;
    FOnMessage: TRpDcMessageEvent;
    FOnOpen: TRpDcNotifyEvent;
    FOnClosed: TRpDcNotifyEvent;
    FOnError: TRpDcErrorEvent;

    procedure InternalSetupPeerCallbacks;
    procedure InternalAttachDataChannel(ADc: Integer);
    procedure InternalQueryConnectionMode;
    function GetIsOpen: Boolean;
  protected
    // Called by the C-level callbacks (which look up the instance via
    // the rtc user pointer). All callbacks run on libdatachannel worker
    // threads.
    procedure HandleLocalDescription(const Sdp, SdpType: string);
    procedure HandleLocalCandidate(const Candidate, Mid: string);
    procedure HandleStateChange(state: rtcState);
    procedure HandleIceStateChange(state: rtcIceState);
    procedure HandleIncomingDataChannel(ADc: Integer);
    procedure HandleDataChannelOpen;
    procedure HandleDataChannelClosed;
    procedure HandleDataChannelError(const Msg: string);
    procedure HandleDataChannelMessage(const Data: TBytes; IsText: Boolean);
  public
    // The constructor only allocates the Pascal-side object - the actual
    // PeerConnection is created in Open(). AInitiator=True for the side
    // that creates the offer; the answerer constructs with AInitiator=
    // False and lets the DC arrive via DataChannel callback.
    constructor Create(AInitiator: Boolean;
                       const ADataChannelLabel: AnsiString = 'reportman-dc');
    destructor Destroy; override;

    // Bring the peer connection up. The initiator also creates the
    // DataChannel here, which triggers immediate ICE gathering.
    procedure Open(const AIceServers: array of AnsiString);

    // Signaling input from the remote side. SetRemoteDescription with
    // SdpType='offer' on the answerer triggers an automatic local
    // answer; SetRemoteDescription with SdpType='answer' on the
    // initiator completes the negotiation.
    procedure SetRemoteDescription(const Sdp, SdpType: string);
    procedure AddRemoteCandidate(const Candidate, Mid: string);

    // Send on the DataChannel. Only valid after OnOpen fires.
    procedure SendText(const Text: string);
    procedure SendBinary(const Data: TBytes);

    procedure Close;

    property IsOpen: Boolean read GetIsOpen;
    property State: rtcState read FState;
    property IceState: rtcIceState read FIceState;
    property ConnectionMode: TRpDcConnectionMode read FConnectionMode;
    property LastError: string read FLastError;
    property IsInitiator: Boolean read FIsInitiator;

    property OnLocalDescription: TRpDcLocalDescriptionEvent
      read FOnLocalDescription write FOnLocalDescription;
    property OnLocalCandidate: TRpDcLocalCandidateEvent
      read FOnLocalCandidate write FOnLocalCandidate;
    property OnMessage: TRpDcMessageEvent
      read FOnMessage write FOnMessage;
    property OnOpen: TRpDcNotifyEvent read FOnOpen write FOnOpen;
    property OnClosed: TRpDcNotifyEvent read FOnClosed write FOnClosed;
    property OnError: TRpDcErrorEvent read FOnError write FOnError;
  end;

  ERpDataDirect = class(Exception);

// ============================================================
// Library lifecycle helpers
// ============================================================

// Load libdatachannel.dll once for the process. Idempotent. The DllPath
// must point to datachannel.dll; its sibling DLLs (juice, libssl,
// libcrypto, legacy) must be in the same folder.
function RpDcInitialize(const DllPath: string;
                        ALogLevel: rtcLogLevel = RTC_LOG_WARNING): Boolean;

// Release the library. Safe to call multiple times.
procedure RpDcShutdown;

function RpDcIsInitialized: Boolean;
function RpDcLastInitError: string;

implementation

// ============================================================
// Helpers
// ============================================================

function ParseCandidateType(const Cand: string): TRpDcConnectionMode;
var
  ix: Integer;
  lower: string;
begin
  // Candidate strings look like
  //   candidate:1 1 UDP 2113937151 192.168.1.10 50000 typ host
  // We classify by the token after 'typ '.
  lower := LowerCase(Cand);
  ix := Pos('typ ', lower);
  if ix = 0 then
  begin
    Result := rcmUnknown;
    Exit;
  end;
  lower := Copy(lower, ix + 4, Length(lower));
  if Pos('relay', lower) = 1 then
    Result := rcmRelay
  else if Pos('host', lower) = 1 then
    Result := rcmDirectP2P
  else if (Pos('srflx', lower) = 1) or (Pos('prflx', lower) = 1) then
    Result := rcmHolePunch
  else
    Result := rcmUnknown;
end;

function CombinedConnectionMode(a, b: TRpDcConnectionMode): TRpDcConnectionMode;
begin
  // Worst of the two ends wins: if either side relays, the pair is
  // relayed. If either side is hole-punching, treat as hole-punch.
  if (a = rcmRelay) or (b = rcmRelay) then
    Result := rcmRelay
  else if (a = rcmHolePunch) or (b = rcmHolePunch) then
    Result := rcmHolePunch
  else if (a = rcmDirectP2P) and (b = rcmDirectP2P) then
    Result := rcmDirectP2P
  else
    Result := rcmUnknown;
end;

// ============================================================
// libdatachannel C callbacks. They look up the TRpDcSession via the
// user pointer set on the peer connection / data channel and dispatch
// to instance methods. All run on worker threads of libdatachannel.
// ============================================================

procedure CbLocalDescription(pc: Integer; const sdp, sdpType: PAnsiChar;
                             ptr: Pointer); cdecl;
var
  ses: TRpDcSession;
begin
  ses := TRpDcSession(ptr);
  if ses = nil then Exit;
  try
    ses.HandleLocalDescription(string(AnsiString(sdp)),
                               string(AnsiString(sdpType)));
  except
    // Swallow exceptions - libdatachannel cannot handle Pascal exceptions
    // crossing the C boundary. The caller will see no event for this
    // SDP, which is bad enough; an uncaught exception would crash the
    // worker thread instead.
  end;
end;

procedure CbLocalCandidate(pc: Integer; const cand, mid: PAnsiChar;
                           ptr: Pointer); cdecl;
var
  ses: TRpDcSession;
begin
  ses := TRpDcSession(ptr);
  if ses = nil then Exit;
  try
    ses.HandleLocalCandidate(string(AnsiString(cand)),
                             string(AnsiString(mid)));
  except
  end;
end;

procedure CbStateChange(pc: Integer; state: rtcState; ptr: Pointer); cdecl;
var
  ses: TRpDcSession;
begin
  ses := TRpDcSession(ptr);
  if ses = nil then Exit;
  try
    ses.HandleStateChange(state);
  except
  end;
end;

procedure CbIceStateChange(pc: Integer; state: rtcIceState; ptr: Pointer); cdecl;
var
  ses: TRpDcSession;
begin
  ses := TRpDcSession(ptr);
  if ses = nil then Exit;
  try
    ses.HandleIceStateChange(state);
  except
  end;
end;

procedure CbDataChannel(pc: Integer; dc: Integer; ptr: Pointer); cdecl;
var
  ses: TRpDcSession;
begin
  ses := TRpDcSession(ptr);
  if ses = nil then Exit;
  try
    ses.HandleIncomingDataChannel(dc);
  except
  end;
end;

procedure CbDcOpen(id: Integer; ptr: Pointer); cdecl;
var
  ses: TRpDcSession;
begin
  ses := TRpDcSession(ptr);
  if ses = nil then Exit;
  try
    ses.HandleDataChannelOpen;
  except
  end;
end;

procedure CbDcClosed(id: Integer; ptr: Pointer); cdecl;
var
  ses: TRpDcSession;
begin
  ses := TRpDcSession(ptr);
  if ses = nil then Exit;
  try
    ses.HandleDataChannelClosed;
  except
  end;
end;

procedure CbDcError(id: Integer; const error: PAnsiChar; ptr: Pointer); cdecl;
var
  ses: TRpDcSession;
  msg: string;
begin
  ses := TRpDcSession(ptr);
  if ses = nil then Exit;
  if error <> nil then msg := string(AnsiString(error)) else msg := '<no error message>';
  try
    ses.HandleDataChannelError(msg);
  except
  end;
end;

procedure CbDcMessage(id: Integer; const data: PAnsiChar; size: Integer;
                      ptr: Pointer); cdecl;
var
  ses: TRpDcSession;
  buf: TBytes;
  isText: Boolean;
  effLen: Integer;
begin
  ses := TRpDcSession(ptr);
  if ses = nil then Exit;

  // libdatachannel convention:
  //   size >= 0  -> binary message, exactly `size` bytes.
  //   size <  0  -> text message; the absolute value of size is the
  //                 buffer length INCLUDING the trailing NUL byte.
  // We strip the NUL on text messages so the consumer sees the
  // human-meaningful byte length.
  if size < 0 then
  begin
    isText := True;
    effLen := -size;
    if (effLen > 0) and (data <> nil) and (PAnsiChar(data)[effLen - 1] = #0) then
      Dec(effLen);
    SetLength(buf, effLen);
    if effLen > 0 then
      Move(data^, buf[0], effLen);
  end
  else
  begin
    isText := False;
    SetLength(buf, size);
    if size > 0 then
      Move(data^, buf[0], size);
  end;
  try
    ses.HandleDataChannelMessage(buf, isText);
  except
  end;
end;

// ============================================================
// Library lifecycle
// ============================================================

var
  GInitialized: Boolean = False;
  GInitError: string = '';
  GInitLock: TCriticalSection = nil;

procedure GlobalLogCallback(level: rtcLogLevel; const Msg: PAnsiChar); cdecl;
begin
  // libdatachannel writes a one-line log message. Honor the level by
  // routing to stderr - the host application can replace this if
  // needed. We don't use Writeln on stdout because the application
  // may want stdout clean.
  if Msg <> nil then
    Writeln(ErrOutput,
            '[libdc:' + IntToStr(Ord(level)) + '] ' +
            string(AnsiString(Msg)));
end;

function RpDcInitialize(const DllPath: string;
                        ALogLevel: rtcLogLevel): Boolean;
begin
  GInitLock.Acquire;
  try
    if GInitialized then
      Exit(True);

    if not LoadLibDataChannel(DllPath) then
    begin
      GInitError := GetLastLoadError;
      Exit(False);
    end;

    if Assigned(rtcInitLogger) then
      rtcInitLogger(ALogLevel, @GlobalLogCallback);

    GInitialized := True;
    GInitError := '';
    Result := True;
  finally
    GInitLock.Release;
  end;
end;

procedure RpDcShutdown;
begin
  GInitLock.Acquire;
  try
    if not GInitialized then
      Exit;
    UnloadLibDataChannel;
    GInitialized := False;
    GInitError := '';
  finally
    GInitLock.Release;
  end;
end;

function RpDcIsInitialized: Boolean;
begin
  Result := GInitialized;
end;

function RpDcLastInitError: string;
begin
  Result := GInitError;
end;

// ============================================================
// TRpDcSession
// ============================================================

constructor TRpDcSession.Create(AInitiator: Boolean;
                                const ADataChannelLabel: AnsiString);
begin
  inherited Create;
  if not GInitialized then
    raise ERpDataDirect.Create(
      'RpDcInitialize must be called before constructing TRpDcSession');
  FStateLock := TCriticalSection.Create;
  FIsInitiator := AInitiator;
  FLabel := ADataChannelLabel;
  if FLabel = '' then FLabel := 'reportman-dc';
  FPeerId := -1;
  FDataChannelId := -1;
  FState := RTC_NEW;
  FIceState := RTC_ICE_NEW;
  FConnectionMode := rcmUnknown;
end;

destructor TRpDcSession.Destroy;
begin
  Close;
  FreeAndNil(FStateLock);
  inherited Destroy;
end;

procedure TRpDcSession.Open(const AIceServers: array of AnsiString);
var
  cfg: rtcConfiguration;
  iceArray: array of PAnsiChar;
  i: Integer;
begin
  if FPeerId >= 0 then
    raise ERpDataDirect.Create('Session already opened');

  FillChar(cfg, SizeOf(cfg), 0);
  cfg.certificateType    := RTC_CERTIFICATE_DEFAULT;
  cfg.iceTransportPolicy := RTC_TRANSPORT_POLICY_ALL;
  cfg.enableIceTcp       := True;

  // Build the ICE server array. libdatachannel takes const char* const*,
  // which from Pascal is a 0-terminated array of PAnsiChar (no, in
  // libdatachannel it is NOT 0-terminated, you pass the count
  // separately). We keep the AnsiStrings alive in AIceServers.
  if Length(AIceServers) > 0 then
  begin
    SetLength(iceArray, Length(AIceServers));
    for i := 0 to High(AIceServers) do
      iceArray[i] := PAnsiChar(AIceServers[i]);
    cfg.iceServers      := @iceArray[0];
    cfg.iceServersCount := Length(AIceServers);
  end;

  FPeerId := rtcCreatePeerConnection(@cfg);
  if FPeerId < 0 then
    raise ERpDataDirect.CreateFmt(
      'rtcCreatePeerConnection failed: %d', [FPeerId]);

  // Register our instance as the user pointer so the C callbacks can
  // find us. Must be set BEFORE installing the callbacks - otherwise
  // an early gathering event would fire before user pointer is set.
  rtcSetUserPointer(FPeerId, Self);

  InternalSetupPeerCallbacks;

  if FIsInitiator then
  begin
    // Create the DataChannel - this also triggers automatic offer
    // generation and ICE gathering.
    FDataChannelId := rtcCreateDataChannel(FPeerId, PAnsiChar(FLabel));
    if FDataChannelId < 0 then
      raise ERpDataDirect.CreateFmt(
        'rtcCreateDataChannel failed: %d', [FDataChannelId]);
    InternalAttachDataChannel(FDataChannelId);
  end;
  // For the answerer the DC arrives via CbDataChannel after the offer
  // has been processed and an answer has been generated.
end;

procedure TRpDcSession.InternalSetupPeerCallbacks;
begin
  rtcSetLocalDescriptionCallback(FPeerId, @CbLocalDescription);
  rtcSetLocalCandidateCallback(FPeerId, @CbLocalCandidate);
  rtcSetStateChangeCallback(FPeerId, @CbStateChange);
  rtcSetIceStateChangeCallback(FPeerId, @CbIceStateChange);
  rtcSetDataChannelCallback(FPeerId, @CbDataChannel);
end;

procedure TRpDcSession.InternalAttachDataChannel(ADc: Integer);
begin
  FDataChannelId := ADc;
  rtcSetUserPointer(FDataChannelId, Self);
  rtcSetOpenCallback(FDataChannelId, @CbDcOpen);
  rtcSetClosedCallback(FDataChannelId, @CbDcClosed);
  rtcSetErrorCallback(FDataChannelId, @CbDcError);
  rtcSetMessageCallback(FDataChannelId, @CbDcMessage);
end;

procedure TRpDcSession.HandleLocalDescription(const Sdp, SdpType: string);
begin
  if Assigned(FOnLocalDescription) then
    FOnLocalDescription(Self, Sdp, SdpType);
end;

procedure TRpDcSession.HandleLocalCandidate(const Candidate, Mid: string);
begin
  if Assigned(FOnLocalCandidate) then
    FOnLocalCandidate(Self, Candidate, Mid);
end;

procedure TRpDcSession.HandleStateChange(state: rtcState);
begin
  FStateLock.Acquire;
  try
    FState := state;
  finally
    FStateLock.Release;
  end;
  if (state = RTC_DISCONNECTED) or (state = RTC_FAILED) or (state = RTC_CLOSED) then
    if Assigned(FOnClosed) then FOnClosed(Self);
end;

procedure TRpDcSession.HandleIceStateChange(state: rtcIceState);
begin
  FStateLock.Acquire;
  try
    FIceState := state;
  finally
    FStateLock.Release;
  end;
  if state = RTC_ICE_CONNECTED then
    InternalQueryConnectionMode;
end;

procedure TRpDcSession.InternalQueryConnectionMode;
var
  localBuf, remoteBuf: array[0..1023] of AnsiChar;
  ret: Integer;
  localMode, remoteMode: TRpDcConnectionMode;
begin
  FillChar(localBuf, SizeOf(localBuf), 0);
  FillChar(remoteBuf, SizeOf(remoteBuf), 0);
  ret := rtcGetSelectedCandidatePair(FPeerId,
                                     @localBuf[0], SizeOf(localBuf),
                                     @remoteBuf[0], SizeOf(remoteBuf));
  if ret < 0 then
  begin
    FConnectionMode := rcmUnknown;
    Exit;
  end;
  localMode  := ParseCandidateType(string(AnsiString(PAnsiChar(@localBuf[0]))));
  remoteMode := ParseCandidateType(string(AnsiString(PAnsiChar(@remoteBuf[0]))));
  FConnectionMode := CombinedConnectionMode(localMode, remoteMode);
end;

procedure TRpDcSession.HandleIncomingDataChannel(ADc: Integer);
begin
  // The answerer side: a DC just arrived from the remote initiator.
  InternalAttachDataChannel(ADc);
end;

procedure TRpDcSession.HandleDataChannelOpen;
begin
  if Assigned(FOnOpen) then FOnOpen(Self);
end;

procedure TRpDcSession.HandleDataChannelClosed;
begin
  if Assigned(FOnClosed) then FOnClosed(Self);
end;

procedure TRpDcSession.HandleDataChannelError(const Msg: string);
begin
  FLastError := Msg;
  if Assigned(FOnError) then FOnError(Self, Msg);
end;

procedure TRpDcSession.HandleDataChannelMessage(const Data: TBytes;
                                                IsText: Boolean);
begin
  if Assigned(FOnMessage) then FOnMessage(Self, Data, IsText);
end;

procedure TRpDcSession.SetRemoteDescription(const Sdp, SdpType: string);
var
  utf8Sdp: AnsiString;
  utf8Type: AnsiString;
  ret: Integer;
begin
  if FPeerId < 0 then
    raise ERpDataDirect.Create('Session is not open');
  utf8Sdp  := AnsiString(UTF8Encode(Sdp));
  utf8Type := AnsiString(SdpType);
  ret := rtcSetRemoteDescription(FPeerId,
                                 PAnsiChar(utf8Sdp),
                                 PAnsiChar(utf8Type));
  if ret < 0 then
    raise ERpDataDirect.CreateFmt(
      'rtcSetRemoteDescription failed: %d', [ret]);
end;

procedure TRpDcSession.AddRemoteCandidate(const Candidate, Mid: string);
var
  utf8Cand, utf8Mid: AnsiString;
  ret: Integer;
begin
  if FPeerId < 0 then
    raise ERpDataDirect.Create('Session is not open');
  utf8Cand := AnsiString(Candidate);
  utf8Mid  := AnsiString(Mid);
  ret := rtcAddRemoteCandidate(FPeerId,
                               PAnsiChar(utf8Cand),
                               PAnsiChar(utf8Mid));
  if ret < 0 then
    raise ERpDataDirect.CreateFmt(
      'rtcAddRemoteCandidate failed: %d', [ret]);
end;

procedure TRpDcSession.SendText(const Text: string);
var
  utf8: AnsiString;
begin
  if FDataChannelId < 0 then
    raise ERpDataDirect.Create('DataChannel is not open');
  utf8 := AnsiString(UTF8Encode(Text));
  // libdatachannel convention: size = -1 means "NUL-terminated text".
  rtcSendMessage(FDataChannelId, PAnsiChar(utf8), -1);
end;

procedure TRpDcSession.SendBinary(const Data: TBytes);
begin
  if FDataChannelId < 0 then
    raise ERpDataDirect.Create('DataChannel is not open');
  if Length(Data) = 0 then Exit;
  rtcSendMessage(FDataChannelId, PAnsiChar(@Data[0]), Length(Data));
end;

function TRpDcSession.GetIsOpen: Boolean;
begin
  Result := (FDataChannelId >= 0) and Assigned(rtcIsOpen) and
            rtcIsOpen(FDataChannelId);
end;

procedure TRpDcSession.Close;
begin
  if FDataChannelId >= 0 then
  begin
    if Assigned(rtcClose) then rtcClose(FDataChannelId);
    if Assigned(rtcSetUserPointer) then rtcSetUserPointer(FDataChannelId, nil);
    if Assigned(rtcDelete) then rtcDelete(FDataChannelId);
    FDataChannelId := -1;
  end;
  if FPeerId >= 0 then
  begin
    if Assigned(rtcClosePeerConnection) then rtcClosePeerConnection(FPeerId);
    if Assigned(rtcSetUserPointer) then rtcSetUserPointer(FPeerId, nil);
    if Assigned(rtcDeletePeerConnection) then rtcDeletePeerConnection(FPeerId);
    FPeerId := -1;
  end;
end;

initialization
  GInitLock := TCriticalSection.Create;

finalization
  RpDcShutdown;
  FreeAndNil(GInitLock);

end.
