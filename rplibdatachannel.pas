{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rplibdatachannel                                }
{                                                       }
{       Pascal binding for libdatachannel v0.24.3       }
{       (paullouisageneau/libdatachannel) covering only }
{       the surface needed by the Reportman Direct      }
{       Channel client: PeerConnection, DataChannel,    }
{       and WebSocket (for signaling).                  }
{                                                       }
{       Track/Media/Packetizer/RTCP/SSRC APIs are NOT   }
{       exposed - we do not transport audio or video.   }
{                                                       }
{       Dynamic loading: the DLL is extracted from an   }
{       OCX resource into LocalAppData on first use,    }
{       then LoadLibrary is invoked with the absolute   }
{       path. Use LoadLibDataChannel/UnloadLibDataChannel}
{                                                       }
{       The DLL itself is built by vcpkg with a static  }
{       CRT (no VC++ Redistributable required on the    }
{       client machine). Companion DLLs that must sit   }
{       in the same folder: juice.dll, legacy.dll,      }
{       libssl-3[-x64].dll, libcrypto-3[-x64].dll.      }
{                                                       }
{       Copyright (c) 2026 Toni Martir                  }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhance this file you must provide       }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rplibdatachannel;

interface

{$I rpconf.inc}

uses
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
  SysUtils;

// All C enums in libdatachannel are 4-byte int. Pascal default may be smaller
// for small enums, so force 4 bytes globally.
{$MINENUMSIZE 4}

const
  // Default file name expected next to the OCX or in the extraction folder.
  // The caller of LoadLibDataChannel passes the full path, this is just the
  // file name used by the extractor / packager.
  RTC_DLL_NAME = 'datachannel.dll';

  // Error codes returned by most rtc* functions.
  RTC_ERR_SUCCESS   =  0;
  RTC_ERR_INVALID   = -1;  // invalid argument
  RTC_ERR_FAILURE   = -2;  // runtime error
  RTC_ERR_NOT_AVAIL = -3;  // element not available
  RTC_ERR_TOO_SMALL = -4;  // buffer too small

type
  // ============================================================
  // Enumerations
  // ============================================================

  rtcState = (
    RTC_NEW          = 0,
    RTC_CONNECTING   = 1,
    RTC_CONNECTED    = 2,
    RTC_DISCONNECTED = 3,
    RTC_FAILED       = 4,
    RTC_CLOSED       = 5
  );

  rtcIceState = (
    RTC_ICE_NEW          = 0,
    RTC_ICE_CHECKING     = 1,
    RTC_ICE_CONNECTED    = 2,
    RTC_ICE_COMPLETED    = 3,
    RTC_ICE_FAILED       = 4,
    RTC_ICE_DISCONNECTED = 5,
    RTC_ICE_CLOSED       = 6
  );

  rtcGatheringState = (
    RTC_GATHERING_NEW        = 0,
    RTC_GATHERING_INPROGRESS = 1,
    RTC_GATHERING_COMPLETE   = 2
  );

  rtcSignalingState = (
    RTC_SIGNALING_STABLE               = 0,
    RTC_SIGNALING_HAVE_LOCAL_OFFER     = 1,
    RTC_SIGNALING_HAVE_REMOTE_OFFER    = 2,
    RTC_SIGNALING_HAVE_LOCAL_PRANSWER  = 3,
    RTC_SIGNALING_HAVE_REMOTE_PRANSWER = 4
  );

  rtcLogLevel = (
    RTC_LOG_NONE    = 0,
    RTC_LOG_FATAL   = 1,
    RTC_LOG_ERROR   = 2,
    RTC_LOG_WARNING = 3,
    RTC_LOG_INFO    = 4,
    RTC_LOG_DEBUG   = 5,
    RTC_LOG_VERBOSE = 6
  );

  rtcCertificateType = (
    RTC_CERTIFICATE_DEFAULT = 0,  // ECDSA in practice
    RTC_CERTIFICATE_ECDSA   = 1,
    RTC_CERTIFICATE_RSA     = 2
  );

  rtcTransportPolicy = (
    RTC_TRANSPORT_POLICY_ALL   = 0,
    RTC_TRANSPORT_POLICY_RELAY = 1   // only relay candidates (force TURN)
  );

  // ============================================================
  // Callback function types
  //
  // Pascal note: all C callbacks are RTC_API which on Windows defaults to
  // empty (=__cdecl). vcpkg built without CAPI_STDCALL feature so cdecl
  // is correct on both x64 and x86.
  // ============================================================

  rtcLogCallbackFunc = procedure(
    level: rtcLogLevel;
    const Msg: PAnsiChar
  ); cdecl;

  rtcDescriptionCallbackFunc = procedure(
    pc: Integer;
    const sdp: PAnsiChar;
    const sdpType: PAnsiChar;
    ptr: Pointer
  ); cdecl;

  rtcCandidateCallbackFunc = procedure(
    pc: Integer;
    const cand: PAnsiChar;
    const mid: PAnsiChar;
    ptr: Pointer
  ); cdecl;

  rtcStateChangeCallbackFunc = procedure(
    pc: Integer;
    state: rtcState;
    ptr: Pointer
  ); cdecl;

  rtcIceStateChangeCallbackFunc = procedure(
    pc: Integer;
    state: rtcIceState;
    ptr: Pointer
  ); cdecl;

  rtcGatheringStateCallbackFunc = procedure(
    pc: Integer;
    state: rtcGatheringState;
    ptr: Pointer
  ); cdecl;

  rtcSignalingStateCallbackFunc = procedure(
    pc: Integer;
    state: rtcSignalingState;
    ptr: Pointer
  ); cdecl;

  rtcDataChannelCallbackFunc = procedure(
    pc: Integer;
    dc: Integer;
    ptr: Pointer
  ); cdecl;

  rtcOpenCallbackFunc = procedure(
    id: Integer;
    ptr: Pointer
  ); cdecl;

  rtcClosedCallbackFunc = procedure(
    id: Integer;
    ptr: Pointer
  ); cdecl;

  rtcErrorCallbackFunc = procedure(
    id: Integer;
    const error: PAnsiChar;
    ptr: Pointer
  ); cdecl;

  // Note: libdatachannel passes message bytes with the EXACT size (no NUL
  // termination guaranteed). Treat the buffer as raw bytes of `size` length.
  rtcMessageCallbackFunc = procedure(
    id: Integer;
    const Msg: PAnsiChar;
    size: Integer;
    ptr: Pointer
  ); cdecl;

  rtcBufferedAmountLowCallbackFunc = procedure(
    id: Integer;
    ptr: Pointer
  ); cdecl;

  // ============================================================
  // Structures
  //
  // IMPORTANT: layout must match the C struct byte-for-byte. Pascal `bool`
  // does not exist - C99 `bool` is 1 byte. We use ByteBool (1 byte). Padding
  // and alignment follow MSVC default (8-byte align on x64, 4-byte on x86).
  // ============================================================

  PrtcConfiguration = ^rtcConfiguration;
  rtcConfiguration = record
    iceServers: PPAnsiChar;          // const char** - array of strings
    iceServersCount: Integer;
    proxyServer: PAnsiChar;          // libnice only (we use libjuice -> nil)
    bindAddress: PAnsiChar;          // libjuice only, nil = any
    certificateType: rtcCertificateType;
    iceTransportPolicy: rtcTransportPolicy;
    enableIceTcp: ByteBool;
    enableIceUdpMux: ByteBool;       // libjuice only
    disableAutoNegotiation: ByteBool;
    forceMediaTransport: ByteBool;
    portRangeBegin: Word;            // 0 = automatic
    portRangeEnd: Word;              // 0 = automatic
    mtu: Integer;                    // <=0 = automatic
    maxMessageSize: Integer;         // <=0 = default
  end;

  PrtcReliability = ^rtcReliability;
  rtcReliability = record
    unordered: ByteBool;
    unreliable: ByteBool;
    maxPacketLifeTime: Cardinal;     // ignored if reliable
    maxRetransmits: Cardinal;        // ignored if reliable
  end;

  PrtcDataChannelInit = ^rtcDataChannelInit;
  rtcDataChannelInit = record
    reliability: rtcReliability;
    protocol: PAnsiChar;             // nil -> empty string in C
    negotiated: ByteBool;
    manualStream: ByteBool;
    stream: Word;                    // 0..65534, ignored if manualStream=false
  end;

  PrtcWsConfiguration = ^rtcWsConfiguration;
  rtcWsConfiguration = record
    disableTlsVerification: ByteBool;
    proxyServer: PAnsiChar;
    protocols: PPAnsiChar;
    protocolsCount: Integer;
    connectionTimeoutMs: Integer;    // 0=default, <0=disabled
    pingIntervalMs: Integer;         // 0=default, <0=disabled
    maxOutstandingPings: Integer;    // 0=default, <0=disabled
    maxMessageSize: Integer;         // <=0 = default
  end;

  PrtcSctpSettings = ^rtcSctpSettings;
  rtcSctpSettings = record
    recvBufferSize: Integer;
    sendBufferSize: Integer;
    maxChunksOnQueue: Integer;
    initialCongestionWindow: Integer;
    maxBurst: Integer;
    congestionControlModule: Integer;
    delayedSackTimeMs: Integer;
    minRetransmitTimeoutMs: Integer;
    maxRetransmitTimeoutMs: Integer;
    initialRetransmitTimeoutMs: Integer;
    maxRetransmitAttempts: Integer;
    heartbeatIntervalMs: Integer;
  end;

// ============================================================
// Dynamic-loaded function pointers
//
// They start as nil. LoadLibDataChannel populates them; UnloadLibDataChannel
// clears them. Call IsLibDataChannelLoaded before using any function.
// ============================================================

var

  // ---- Log ----

  // NULL cb on the first call routes log to stdout.
  rtcInitLogger: procedure(
    level: rtcLogLevel;
    cb: rtcLogCallbackFunc
  ); cdecl;

  // ---- User pointer ----
  // Stash an arbitrary Pascal pointer (typically a TObject Self) against any
  // rtc id so callbacks can recover context without globals.

  rtcSetUserPointer: procedure(
    id: Integer;
    ptr: Pointer
  ); cdecl;

  rtcGetUserPointer: function(
    id: Integer
  ): Pointer; cdecl;

  // ---- Peer Connection ----

  rtcCreatePeerConnection: function(
    const config: PrtcConfiguration
  ): Integer; cdecl;

  rtcClosePeerConnection: function(
    pc: Integer
  ): Integer; cdecl;

  rtcDeletePeerConnection: function(
    pc: Integer
  ): Integer; cdecl;

  rtcSetLocalDescriptionCallback: function(
    pc: Integer;
    cb: rtcDescriptionCallbackFunc
  ): Integer; cdecl;

  rtcSetLocalCandidateCallback: function(
    pc: Integer;
    cb: rtcCandidateCallbackFunc
  ): Integer; cdecl;

  rtcSetStateChangeCallback: function(
    pc: Integer;
    cb: rtcStateChangeCallbackFunc
  ): Integer; cdecl;

  rtcSetIceStateChangeCallback: function(
    pc: Integer;
    cb: rtcIceStateChangeCallbackFunc
  ): Integer; cdecl;

  rtcSetGatheringStateChangeCallback: function(
    pc: Integer;
    cb: rtcGatheringStateCallbackFunc
  ): Integer; cdecl;

  rtcSetSignalingStateChangeCallback: function(
    pc: Integer;
    cb: rtcSignalingStateCallbackFunc
  ): Integer; cdecl;

  // type=nil generates an offer or answer automatically depending on state.
  rtcSetLocalDescription: function(
    pc: Integer;
    const sdpType: PAnsiChar
  ): Integer; cdecl;

  rtcSetRemoteDescription: function(
    pc: Integer;
    const sdp: PAnsiChar;
    const sdpType: PAnsiChar
  ): Integer; cdecl;

  rtcAddRemoteCandidate: function(
    pc: Integer;
    const cand: PAnsiChar;
    const mid: PAnsiChar
  ): Integer; cdecl;

  // For getters: pass buffer + size. Returns bytes written including final
  // NUL, or -RTC_ERR_TOO_SMALL if buffer too small (then size is the needed
  // value). Pass buffer=nil, size=0 to query the required size first.
  rtcGetLocalDescription: function(
    pc: Integer;
    buffer: PAnsiChar;
    size: Integer
  ): Integer; cdecl;

  rtcGetRemoteDescription: function(
    pc: Integer;
    buffer: PAnsiChar;
    size: Integer
  ): Integer; cdecl;

  // Useful for transport-mode detection: format is
  // "<local-candidate> | <remote-candidate>" with type=host/srflx/relay.
  rtcGetSelectedCandidatePair: function(
    pc: Integer;
    local: PAnsiChar;
    localSize: Integer;
    remote: PAnsiChar;
    remoteSize: Integer
  ): Integer; cdecl;

  // ---- Common: DataChannel + Track + WebSocket ----

  rtcSetOpenCallback: function(
    id: Integer;
    cb: rtcOpenCallbackFunc
  ): Integer; cdecl;

  rtcSetClosedCallback: function(
    id: Integer;
    cb: rtcClosedCallbackFunc
  ): Integer; cdecl;

  rtcSetErrorCallback: function(
    id: Integer;
    cb: rtcErrorCallbackFunc
  ): Integer; cdecl;

  rtcSetMessageCallback: function(
    id: Integer;
    cb: rtcMessageCallbackFunc
  ): Integer; cdecl;

  // Send raw bytes. For binary data, just pass the buffer as PAnsiChar.
  // Passing size=-1 sends a NUL-terminated string (libdatachannel measures).
  rtcSendMessage: function(
    id: Integer;
    const data: PAnsiChar;
    size: Integer
  ): Integer; cdecl;

  rtcClose: function(
    id: Integer
  ): Integer; cdecl;

  rtcDelete: function(
    id: Integer
  ): Integer; cdecl;

  rtcIsOpen: function(
    id: Integer
  ): ByteBool; cdecl;

  rtcIsClosed: function(
    id: Integer
  ): ByteBool; cdecl;

  rtcMaxMessageSize: function(
    id: Integer
  ): Integer; cdecl;

  rtcGetBufferedAmount: function(
    id: Integer
  ): Integer; cdecl;

  rtcSetBufferedAmountLowThreshold: function(
    id: Integer;
    amount: Integer
  ): Integer; cdecl;

  rtcSetBufferedAmountLowCallback: function(
    id: Integer;
    cb: rtcBufferedAmountLowCallbackFunc
  ): Integer; cdecl;

  // ---- Data Channel ----

  rtcSetDataChannelCallback: function(
    pc: Integer;
    cb: rtcDataChannelCallbackFunc
  ): Integer; cdecl;

  rtcCreateDataChannel: function(
    pc: Integer;
    const RtcLabel: PAnsiChar
  ): Integer; cdecl;

  rtcCreateDataChannelEx: function(
    pc: Integer;
    const RtcLabel: PAnsiChar;
    const init: PrtcDataChannelInit
  ): Integer; cdecl;

  rtcGetDataChannelLabel: function(
    dc: Integer;
    buffer: PAnsiChar;
    size: Integer
  ): Integer; cdecl;

  // ---- WebSocket (used for signaling) ----

  rtcCreateWebSocket: function(
    const url: PAnsiChar
  ): Integer; cdecl;

  rtcCreateWebSocketEx: function(
    const url: PAnsiChar;
    const config: PrtcWsConfiguration
  ): Integer; cdecl;

  rtcDeleteWebSocket: function(
    ws: Integer
  ): Integer; cdecl;

  // ---- Global ----

  rtcSetThreadPoolSize: function(
    count: Cardinal
  ): Integer; cdecl;

  rtcSetSctpSettings: function(
    const settings: PrtcSctpSettings
  ): Integer; cdecl;

  // Optional - preload spins up the worker pool eagerly.
  rtcPreload: procedure; cdecl;

  // Call once at shutdown to release threads/sockets cleanly.
  rtcCleanup: procedure; cdecl;

// ============================================================
// Loader API
// ============================================================

// Load datachannel.dll (plus the four companion DLLs assumed in the same
// folder: juice.dll, legacy.dll, libssl-3[-x64].dll, libcrypto-3[-x64].dll).
// DllPath is the full path to datachannel.dll. Returns False if anything
// went wrong (use GetLastLoadError for details).
function LoadLibDataChannel(const DllPath: string): Boolean;

// Releases the library. Safe to call when not loaded.
function UnloadLibDataChannel: Boolean;

// True iff LoadLibDataChannel has succeeded and Unload has not been called.
function IsLibDataChannelLoaded: Boolean;

// Diagnostic text of the most recent load attempt failure.
function GetLastLoadError: string;

implementation

var
  FHandle: HMODULE = 0;
  FLastError: string = '';

function GetProc(const Name: AnsiString): Pointer;
begin
  Result := GetProcAddress(FHandle, PAnsiChar(Name));
  if Result = nil then
    FLastError := FLastError + 'Symbol not found: ' + string(Name) + sLineBreak;
end;

function LoadLibDataChannel(const DllPath: string): Boolean;
begin
  if FHandle <> 0 then
  begin
    Result := True;
    Exit;
  end;

  FLastError := '';

  // SetDllDirectory tells the loader to also search the folder that contains
  // datachannel.dll for its companion DLLs (libssl, libcrypto, juice...).
  // Without this, Windows would look only in the EXE folder and System32.
{$IFDEF MSWINDOWS}
  SetDllDirectory(PChar(ExtractFilePath(DllPath)));
{$ENDIF}

  FHandle := LoadLibrary(PChar(DllPath));
  if FHandle = 0 then
  begin
    FLastError := Format('LoadLibrary failed (Win32 error %d) for: %s',
                         [GetLastError, DllPath]);
    Result := False;
    Exit;
  end;

  // Resolve every entry point. If any fails the FLastError accumulates
  // them all so the caller sees the full picture.

  @rtcInitLogger                       := GetProc('rtcInitLogger');
  @rtcSetUserPointer                   := GetProc('rtcSetUserPointer');
  @rtcGetUserPointer                   := GetProc('rtcGetUserPointer');

  @rtcCreatePeerConnection             := GetProc('rtcCreatePeerConnection');
  @rtcClosePeerConnection              := GetProc('rtcClosePeerConnection');
  @rtcDeletePeerConnection             := GetProc('rtcDeletePeerConnection');
  @rtcSetLocalDescriptionCallback      := GetProc('rtcSetLocalDescriptionCallback');
  @rtcSetLocalCandidateCallback        := GetProc('rtcSetLocalCandidateCallback');
  @rtcSetStateChangeCallback           := GetProc('rtcSetStateChangeCallback');
  @rtcSetIceStateChangeCallback        := GetProc('rtcSetIceStateChangeCallback');
  @rtcSetGatheringStateChangeCallback  := GetProc('rtcSetGatheringStateChangeCallback');
  @rtcSetSignalingStateChangeCallback  := GetProc('rtcSetSignalingStateChangeCallback');
  @rtcSetLocalDescription              := GetProc('rtcSetLocalDescription');
  @rtcSetRemoteDescription             := GetProc('rtcSetRemoteDescription');
  @rtcAddRemoteCandidate               := GetProc('rtcAddRemoteCandidate');
  @rtcGetLocalDescription              := GetProc('rtcGetLocalDescription');
  @rtcGetRemoteDescription             := GetProc('rtcGetRemoteDescription');
  @rtcGetSelectedCandidatePair         := GetProc('rtcGetSelectedCandidatePair');

  @rtcSetOpenCallback                  := GetProc('rtcSetOpenCallback');
  @rtcSetClosedCallback                := GetProc('rtcSetClosedCallback');
  @rtcSetErrorCallback                 := GetProc('rtcSetErrorCallback');
  @rtcSetMessageCallback               := GetProc('rtcSetMessageCallback');
  @rtcSendMessage                      := GetProc('rtcSendMessage');
  @rtcClose                            := GetProc('rtcClose');
  @rtcDelete                           := GetProc('rtcDelete');
  @rtcIsOpen                           := GetProc('rtcIsOpen');
  @rtcIsClosed                         := GetProc('rtcIsClosed');
  @rtcMaxMessageSize                   := GetProc('rtcMaxMessageSize');
  @rtcGetBufferedAmount                := GetProc('rtcGetBufferedAmount');
  @rtcSetBufferedAmountLowThreshold    := GetProc('rtcSetBufferedAmountLowThreshold');
  @rtcSetBufferedAmountLowCallback     := GetProc('rtcSetBufferedAmountLowCallback');

  @rtcSetDataChannelCallback           := GetProc('rtcSetDataChannelCallback');
  @rtcCreateDataChannel                := GetProc('rtcCreateDataChannel');
  @rtcCreateDataChannelEx              := GetProc('rtcCreateDataChannelEx');
  @rtcGetDataChannelLabel              := GetProc('rtcGetDataChannelLabel');

  @rtcCreateWebSocket                  := GetProc('rtcCreateWebSocket');
  @rtcCreateWebSocketEx                := GetProc('rtcCreateWebSocketEx');
  @rtcDeleteWebSocket                  := GetProc('rtcDeleteWebSocket');

  @rtcSetThreadPoolSize                := GetProc('rtcSetThreadPoolSize');
  @rtcSetSctpSettings                  := GetProc('rtcSetSctpSettings');
  @rtcPreload                          := GetProc('rtcPreload');
  @rtcCleanup                          := GetProc('rtcCleanup');

  Result := FLastError = '';
  if not Result then
  begin
    FreeLibrary(FHandle);
    FHandle := 0;
  end;
end;

function UnloadLibDataChannel: Boolean;
begin
  if FHandle = 0 then
  begin
    Result := True;
    Exit;
  end;

  // Best-effort cleanup of any background threads inside the DLL before
  // unloading. Safe to call even if rtcPreload was never invoked.
  if Assigned(rtcCleanup) then
    rtcCleanup;

  Result := FreeLibrary(FHandle);
  FHandle := 0;

  // Null out the pointers so future calls trap deterministically instead
  // of jumping to freed code.
  rtcInitLogger                       := nil;
  rtcSetUserPointer                   := nil;
  rtcGetUserPointer                   := nil;
  rtcCreatePeerConnection             := nil;
  rtcClosePeerConnection              := nil;
  rtcDeletePeerConnection             := nil;
  rtcSetLocalDescriptionCallback      := nil;
  rtcSetLocalCandidateCallback        := nil;
  rtcSetStateChangeCallback           := nil;
  rtcSetIceStateChangeCallback        := nil;
  rtcSetGatheringStateChangeCallback  := nil;
  rtcSetSignalingStateChangeCallback  := nil;
  rtcSetLocalDescription              := nil;
  rtcSetRemoteDescription             := nil;
  rtcAddRemoteCandidate               := nil;
  rtcGetLocalDescription              := nil;
  rtcGetRemoteDescription             := nil;
  rtcGetSelectedCandidatePair         := nil;
  rtcSetOpenCallback                  := nil;
  rtcSetClosedCallback                := nil;
  rtcSetErrorCallback                 := nil;
  rtcSetMessageCallback               := nil;
  rtcSendMessage                      := nil;
  rtcClose                            := nil;
  rtcDelete                           := nil;
  rtcIsOpen                           := nil;
  rtcIsClosed                         := nil;
  rtcMaxMessageSize                   := nil;
  rtcGetBufferedAmount                := nil;
  rtcSetBufferedAmountLowThreshold    := nil;
  rtcSetBufferedAmountLowCallback     := nil;
  rtcSetDataChannelCallback           := nil;
  rtcCreateDataChannel                := nil;
  rtcCreateDataChannelEx              := nil;
  rtcGetDataChannelLabel              := nil;
  rtcCreateWebSocket                  := nil;
  rtcCreateWebSocketEx                := nil;
  rtcDeleteWebSocket                  := nil;
  rtcSetThreadPoolSize                := nil;
  rtcSetSctpSettings                  := nil;
  rtcPreload                          := nil;
  rtcCleanup                          := nil;
end;

function IsLibDataChannelLoaded: Boolean;
begin
  Result := FHandle <> 0;
end;

function GetLastLoadError: string;
begin
  Result := FLastError;
end;

initialization

finalization
  UnloadLibDataChannel;

end.
