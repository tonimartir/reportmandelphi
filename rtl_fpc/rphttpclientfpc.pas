{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rphttpclientfpc                                 }
{       Delphi System.Net.HttpClient compatible client  }
{       for Free Pascal (fphttpclient + OpenSSL)        }
{                                                       }
{       This file is under the MPL license              }
{       A copy of the license is in the license.txt     }
{       file included with this distribution            }
{                                                       }
{*******************************************************}

// FPC-only replacement for the part of Delphi's System.Net.HttpClient /
// System.Net.HttpClientComponent used by the shared Hub units (rpauthmanager,
// rpdatahttp): TNetHTTPClient / THTTPClient with CustomHeaders, ContentType,
// Accept, the three timeouts, OnReceiveData (streaming, with abort) and
// OnValidateServerCertificate, returning an IHTTPResponse. As in Delphi, an
// HTTP error status is not an exception; network and TLS failures raise
// ENetHTTPClientException.
//
// TLS uses OpenSSL, loaded at run time (FPC 3.2.2's openssl unit). Two things
// are added over FPC 3.2.2:
// - library names: FPC 3.2.2 does not know OpenSSL 3 (libssl.so.3 on Linux,
//   libssl-3[-x64].dll on Windows); RpPrepareOpenSSL adds them.
// - certificate verification: FPC 3.2.2 does not verify the server
//   certificate by default and never checks the host name. Here the chain is
//   verified against the system trust store (OpenSSL default paths on Linux,
//   the Windows "ROOT" and "CA" stores on Windows, plus RpHttpCAFile or a
//   cacert.pem next to the executable) and the host name / IP must match,
//   as Delphi's client does. OnValidateServerCertificate can accept a
//   certificate that fails verification, as in Delphi.
// - on Unix, SIGPIPE is ignored (unless the application handles it): OpenSSL
//   writing to a closed connection would otherwise end the process.
//
// Also here, because they are the network pieces the Hub login needs:
// RpOpenUrlInBrowser (ShellExecute / xdg-open) and RpWaitForLoopbackRequest,
// a one-shot HTTP listener on 127.0.0.1 for the OAuth redirect.

unit rphttpclientfpc;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, fphttpclient, ssockets, sslsockets,
  opensslsockets, openssl;

type
  ENetException = class(Exception);
  ENetHTTPException = class(ENetException);
  ENetHTTPClientException = class(ENetHTTPException);
  ENetHTTPRequestException = class(ENetHTTPException);
  ENetHTTPResponseException = class(ENetHTTPException);
  ENetHTTPCertificateException = class(ENetHTTPClientException);

  TNameValuePair = record
    Name: string;
    Value: string;
    constructor Create(const AName, AValue: string);
  end;
  TNetHeaders = array of TNameValuePair;

  // Minimal versions of Delphi's types, for OnValidateServerCertificate
  TURLRequest = class(TObject)
  private
    FURL: string;
    FMethodString: string;
  public
    constructor Create(const AMethod, AURL: string);
    property URL: string read FURL;
    property MethodString: string read FMethodString;
  end;

  TCertificate = record
    Subject: string;
    Issuer: string;
    CertName: string;
    DNSName: string;
    // OpenSSL verification error (0 = the chain and host name were valid)
    VerifyError: Integer;
    VerifyErrorText: string;
  end;

  TReceiveDataEvent = procedure(const Sender: TObject; AContentLength,
    AReadCount: Int64; var AAbort: Boolean) of object;
  TValidateCertificateEvent = procedure(const Sender: TObject;
    const ARequest: TURLRequest; const Certificate: TCertificate;
    var Accepted: Boolean) of object;

  IHTTPResponse = interface
    ['{7E2C1A0B-5B9E-4C71-9C44-5A2F3C8E0D11}']
    function GetStatusCode: Integer;
    function GetStatusText: string;
    function GetContentStream: TStream;
    function GetHeaderValue(const AName: string): string;
    function GetHeaders: TNetHeaders;
    function GetContentCharSet: string;
    function GetMimeType: string;
    function GetContentLength: Int64;
    function ContainsHeader(const AName: string): Boolean;
    // Content decoded with AnEncoding, or with the charset of the response
    // (UTF-8 by default). Returned as a UTF-8 string (Lazarus convention).
    function ContentAsString(const AnEncoding: TEncoding = nil): string;
    property StatusCode: Integer read GetStatusCode;
    property StatusText: string read GetStatusText;
    property ContentStream: TStream read GetContentStream;
    property HeaderValue[const AName: string]: string read GetHeaderValue;
    property Headers: TNetHeaders read GetHeaders;
    property ContentCharSet: string read GetContentCharSet;
    property MimeType: string read GetMimeType;
    property ContentLength: Int64 read GetContentLength;
  end;

  { TNetHTTPClient }

  TNetHTTPClient = class(TComponent)
  private
    FCustomHeaders: TStringList;
    FConnectionTimeout: Integer;
    FSendTimeout: Integer;
    FResponseTimeout: Integer;
    FHandleRedirects: Boolean;
    FMaxRedirects: Integer;
    FSynchronizeEvents: Boolean;
    FOnReceiveData: TReceiveDataEvent;
    FOnValidateServerCertificate: TValidateCertificateEvent;
    FCurrentMethod: string;
    FCurrentURL: string;
    function GetCustomHeader(const AName: string): string;
    procedure SetCustomHeader(const AName, AValue: string);
    function GetContentType: string;
    procedure SetContentType(const AValue: string);
    function GetAccept: string;
    procedure SetAccept(const AValue: string);
    function GetAcceptCharSet: string;
    procedure SetAcceptCharSet(const AValue: string);
    function GetAcceptLanguage: string;
    procedure SetAcceptLanguage(const AValue: string);
    function GetUserAgent: string;
    procedure SetUserAgent(const AValue: string);
    procedure DoGetSocketHandler(Sender: TObject; const UseSSL: Boolean;
      out AHandler: TSocketHandler);
  protected
    function DoExecute(const AMethod, AURL: string; ASource,
      AResponseContent: TStream; const AHeaders: TNetHeaders): IHTTPResponse; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute(const ARequestMethod, AURL: string;
      const ASourceStream: TStream = nil; const AContentStream: TStream = nil;
      const AHeaders: TNetHeaders = nil): IHTTPResponse;
    function Get(const AURL: string; const AResponseContent: TStream = nil;
      const AHeaders: TNetHeaders = nil): IHTTPResponse;
    function Head(const AURL: string; const AHeaders: TNetHeaders = nil): IHTTPResponse;
    function Delete(const AURL: string; const AResponseContent: TStream = nil;
      const AHeaders: TNetHeaders = nil): IHTTPResponse;
    function Post(const AURL: string; const ASource: TStream;
      const AResponseContent: TStream = nil;
      const AHeaders: TNetHeaders = nil): IHTTPResponse; overload;
    // Form post (application/x-www-form-urlencoded) of Name=Value lines
    function Post(const AURL: string; const ASource: TStrings;
      const AResponseContent: TStream = nil; const AEncoding: TEncoding = nil;
      const AHeaders: TNetHeaders = nil): IHTTPResponse; overload;
    function Put(const AURL: string; const ASource: TStream = nil;
      const AResponseContent: TStream = nil;
      const AHeaders: TNetHeaders = nil): IHTTPResponse;
    function Patch(const AURL: string; const ASource: TStream = nil;
      const AResponseContent: TStream = nil;
      const AHeaders: TNetHeaders = nil): IHTTPResponse;
    property CustomHeaders[const AName: string]: string read GetCustomHeader write SetCustomHeader;
    property ContentType: string read GetContentType write SetContentType;
    property Accept: string read GetAccept write SetAccept;
    property AcceptCharSet: string read GetAcceptCharSet write SetAcceptCharSet;
    property AcceptLanguage: string read GetAcceptLanguage write SetAcceptLanguage;
    property UserAgent: string read GetUserAgent write SetUserAgent;
    // Milliseconds, 60000 by default as in Delphi. fphttpclient has a single
    // socket I/O timeout (per read/write, so an active stream never times
    // out): it takes ResponseTimeout; SendTimeout is kept for compatibility.
    property ConnectionTimeout: Integer read FConnectionTimeout write FConnectionTimeout;
    property SendTimeout: Integer read FSendTimeout write FSendTimeout;
    property ResponseTimeout: Integer read FResponseTimeout write FResponseTimeout;
    property HandleRedirects: Boolean read FHandleRedirects write FHandleRedirects;
    property MaxRedirects: Integer read FMaxRedirects write FMaxRedirects;
    // Kept for source compatibility: events are always called in the thread
    // that runs the request
    property SynchronizeEvents: Boolean read FSynchronizeEvents write FSynchronizeEvents;
    // Called after each block of the response body has been written to the
    // response stream; set AAbort to stop the request (the call returns the
    // response received so far, as in Delphi)
    property OnReceiveData: TReceiveDataEvent read FOnReceiveData write FOnReceiveData;
    property OnValidateServerCertificate: TValidateCertificateEvent
      read FOnValidateServerCertificate write FOnValidateServerCertificate;
  end;

  THTTPClient = class(TNetHTTPClient)
  public
    constructor Create; reintroduce; overload;
  end;

  TRpLoopbackRequestEvent = procedure(const APath, AQuery: string;
    var AStatusCode: Integer; var AContentType, AResponseBody: string;
    var ADone: Boolean) of object;

var
  // Verify the server certificate chain and host name (default). Only for
  // diagnostics: turning it off makes the TLS connection unauthenticated.
  RpHttpVerifyServerCertificates: Boolean = True;
  // Extra trusted certificates (PEM file); a cacert.pem next to the
  // executable is used as well if it exists
  RpHttpCAFile: string = '';
  // Replaces the system browser in RpOpenUrlInBrowser (tests, kiosks)
  RpOpenUrlHook: function(const AURL: string): Boolean = nil;

// Loads OpenSSL (1.1 or 3) if it is not loaded yet. Returns False and the
// reason when the libraries cannot be found.
function RpOpenSSLAvailable(out AError: string): Boolean;
// Makes FPC 3.2.2's openssl unit look for OpenSSL 3 as well and, on Unix,
// ignores SIGPIPE if nobody handles it (see IgnoreSigPipe). Called
// automatically before the first TLS connection.
procedure RpPrepareOpenSSL;
// Drops the cached trust store, so that the next connection reads the
// system store and RpHttpCAFile again
procedure RpHttpResetTrustStore;
// Where the trusted certificates came from (diagnostics); empty until the
// first TLS connection
function RpHttpTrustStoreInfo: string;

// Rewrites every request whose URL starts with AFromPrefix (case
// insensitive) to AToPrefix: tests and staging servers. Several prefixes can
// be set; an empty AToPrefix removes that rewrite, an empty AFromPrefix
// removes all of them.
procedure RpHttpSetUrlRewrite(const AFromPrefix, AToPrefix: string);
function RpHttpRewriteUrl(const AURL: string): string;

// Opens the URL in the default browser: ShellExecute on Windows; $BROWSER,
// xdg-open, gio or x-www-browser elsewhere (not sensible-browser: the .deb
// would then need a dependency on sensible-utils, lintian checks it)
function RpOpenUrlInBrowser(const AURL: string): Boolean;

// Listens on 127.0.0.1:APort until AOnRequest sets ADone or ATimeoutMs
// expires; each GET is passed to AOnRequest (path and raw query) and answered
// with its status/body. /favicon.ico gets a 404. Returns True when a request
// set ADone; False on timeout or if the port cannot be opened (AError).
// AOnListening, if assigned, is called once the port is listening and before
// the first accept: open the browser there, so that its redirect can not
// arrive before the listener exists.
function RpWaitForLoopbackRequest(APort: Word; ATimeoutMs: Cardinal;
  AOnRequest: TRpLoopbackRequestEvent; out AError: string;
  AOnListening: TNotifyEvent = nil): Boolean;
// True when a listener can be opened on 127.0.0.1:APort now (the port is free
// and not in a range reserved by the system, as Hyper-V/WSL do on Windows)
function RpLoopbackPortAvailable(APort: Word): Boolean;

implementation

uses
{$IFDEF MSWINDOWS}
  Windows, winsock2, uriparser,
{$ELSE}
  process, baseunix,
{$ENDIF}
  sockets, dynlibs, ctypes, DateUtils;

const
  DefaultUserAgent = 'Reportman FPC HTTP Client/1.0';

{ OpenSSL: library names }

var
  GOpenSSLLock: TRTLCriticalSection;
  GOpenSSLPrepared: Boolean = False;
  GUrlRewriteFrom: array of string;
  GUrlRewriteTo: array of string;
  GUrlRewriteLock: TRTLCriticalSection;

{$IFDEF UNIX}
// OpenSSL writes to the socket with write()/send() without MSG_NOSIGNAL, so
// writing to a connection the peer has closed raises SIGPIPE, whose default
// action ends the process (the designer would close without a word). With
// SIGPIPE ignored the write fails with EPIPE and the request raises an
// exception. Plain sockets (ssockets) already use MSG_NOSIGNAL. A handler
// installed by the application is left alone.
procedure IgnoreSigPipe;
var
  LOld, LNew: SigActionRec;
begin
  FillChar(LOld, SizeOf(LOld), 0);
  if FpSigAction(SIGPIPE, nil, @LOld) <> 0 then
    Exit;
  // SIG_DFL is 0: anything else is SIG_IGN or a handler of the application
  if Assigned(LOld.sa_handler) then
    Exit;
  FillChar(LNew, SizeOf(LNew), 0);
  LNew.sa_handler := SigActionHandler(SIG_IGN);
  FpSigAction(SIGPIPE, @LNew, nil);
end;
{$ENDIF}

procedure RpPrepareOpenSSL;
{$IFDEF MSWINDOWS}
type
  TLibPair = record
    SSL, Crypto: string;
  end;
const
{$IFDEF WIN64}
  Pairs: array[0..1] of TLibPair = (
    (SSL: 'libssl-3-x64.dll'; Crypto: 'libcrypto-3-x64.dll'),
    (SSL: 'libssl-1_1-x64.dll'; Crypto: 'libcrypto-1_1-x64.dll'));
{$ELSE}
  Pairs: array[0..1] of TLibPair = (
    (SSL: 'libssl-3.dll'; Crypto: 'libcrypto-3.dll'),
    (SSL: 'libssl-1_1.dll'; Crypto: 'libcrypto-1_1.dll'));
{$ENDIF}
var
  LCrypto, LSSL: TLibHandle;
  LDir: string;

  function TryLoad(const AName: string): TLibHandle;
  begin
    // The executable folder first, then the normal DLL search order
    Result := LoadLibrary(PChar(LDir + AName));
    if Result = NilHandle then
      Result := LoadLibrary(PChar(AName));
  end;

{$ENDIF}
var
  I: Integer;
begin
  EnterCriticalSection(GOpenSSLLock);
  try
    if GOpenSSLPrepared then
      Exit;
{$IFDEF UNIX}
    IgnoreSigPipe;
{$ENDIF}
    if IsSSLloaded then
    begin
      GOpenSSLPrepared := True;
      Exit;
    end;
{$IFDEF MSWINDOWS}
    // FPC 3.2.2 tries the OpenSSL 1.0 names (ssleay32/libeay32) first and
    // only knows the 1.1 names; prefer OpenSSL 3 and never mix versions.
    LDir := ExtractFilePath(ParamStr(0));
    for I := Low(Pairs) to High(Pairs) do
    begin
      LCrypto := TryLoad(Pairs[I].Crypto);
      if LCrypto = NilHandle then
        Continue;
      LSSL := TryLoad(Pairs[I].SSL);
      if LSSL = NilHandle then
      begin
        FreeLibrary(LCrypto);
        Continue;
      end;
      // Keep them loaded: openssl.pas loads them again by name and gets the
      // same modules
      if FileExists(LDir + Pairs[I].Crypto) then
      begin
        DLLUtilName := LDir + Pairs[I].Crypto;
        DLLSSLName := LDir + Pairs[I].SSL;
      end
      else
      begin
        DLLUtilName := Pairs[I].Crypto;
        DLLSSLName := Pairs[I].SSL;
      end;
      DLLUtilName2 := DLLUtilName;
      DLLSSLName2 := DLLSSLName;
      DLLSSLName3 := DLLSSLName;
      Break;
    end;
{$ELSE}
  {$IFNDEF DARWIN}
    // FPC 3.2.2 tries libssl.so (only with the -dev package), .so.1.1, ...
    // but not .so.3, the only one present on current distributions
    if DLLVersions[2] <> '.3' then
    begin
      for I := High(DLLVersions) downto 3 do
        DLLVersions[I] := DLLVersions[I - 1];
      DLLVersions[2] := '.3';
    end;
  {$ENDIF}
{$ENDIF}
    GOpenSSLPrepared := True;
  finally
    LeaveCriticalSection(GOpenSSLLock);
  end;
end;

function RpOpenSSLAvailable(out AError: string): Boolean;
begin
  AError := '';
  RpPrepareOpenSSL;
  Result := InitSSLInterface;
  if not Result then
{$IFDEF MSWINDOWS}
  {$IFDEF WIN64}
    AError := 'OpenSSL not found: libssl-3-x64.dll and libcrypto-3-x64.dll (or the 1.1 ' +
      'versions) must be next to the executable or in the PATH';
  {$ELSE}
    AError := 'OpenSSL not found: libssl-3.dll and libcrypto-3.dll (or the 1.1 ' +
      'versions) must be next to the executable or in the PATH';
  {$ENDIF}
{$ELSE}
    AError := 'OpenSSL not found: install libssl3 (libssl.so.3) or libssl1.1';
{$ENDIF}
end;

{ OpenSSL: certificate verification (loaded dynamically, works with 1.1
  and 3.x) }

type
  PX509_STORE = Pointer;
  PX509_STORE_CTX = Pointer;
  PX509_VERIFY_PARAM = Pointer;
  PSTACK = Pointer;

  TX509_STORE_new = function: PX509_STORE; cdecl;
  TX509_STORE_free = procedure(AStore: PX509_STORE); cdecl;
  TX509_STORE_set_default_paths = function(AStore: PX509_STORE): cint; cdecl;
  TX509_STORE_load_locations = function(AStore: PX509_STORE; AFile, ADir: PAnsiChar): cint; cdecl;
  TX509_STORE_add_cert = function(AStore: PX509_STORE; ACert: PX509): cint; cdecl;
  Td2i_X509 = function(APX: Pointer; AIn: PPByte; ALen: clong): PX509; cdecl;
  TX509_free = procedure(ACert: PX509); cdecl;
  TX509_STORE_CTX_new = function: PX509_STORE_CTX; cdecl;
  TX509_STORE_CTX_free = procedure(ACtx: PX509_STORE_CTX); cdecl;
  TX509_STORE_CTX_init = function(ACtx: PX509_STORE_CTX; AStore: PX509_STORE;
    ACert: PX509; AChain: PSTACK): cint; cdecl;
  TX509_STORE_CTX_get0_param = function(ACtx: PX509_STORE_CTX): PX509_VERIFY_PARAM; cdecl;
  TX509_VERIFY_PARAM_set1_host = function(AParam: PX509_VERIFY_PARAM; AName: PAnsiChar;
    ALen: csize_t): cint; cdecl;
  TX509_VERIFY_PARAM_set1_ip_asc = function(AParam: PX509_VERIFY_PARAM; AIp: PAnsiChar): cint; cdecl;
  TX509_STORE_CTX_set_purpose = function(ACtx: PX509_STORE_CTX; APurpose: cint): cint; cdecl;
  TX509_verify_cert = function(ACtx: PX509_STORE_CTX): cint; cdecl;
  TX509_STORE_CTX_get_error = function(ACtx: PX509_STORE_CTX): cint; cdecl;
  TX509_verify_cert_error_string = function(AError: clong): PAnsiChar; cdecl;
  TX509_get_name = function(ACert: PX509): Pointer; cdecl;
  TX509_NAME_oneline = function(AName: Pointer; ABuf: PAnsiChar; ASize: cint): PAnsiChar; cdecl;
  TERR_clear_error = procedure; cdecl;
  TSSL_get_peer_certificate = function(ASSL: PSSL): PX509; cdecl;
  TSSL_get_peer_cert_chain = function(ASSL: PSSL): PSTACK; cdecl;

const
  X509_PURPOSE_SSL_SERVER = 2;

var
  GVerifyLoaded: Boolean = False;
  GVerifyOk: Boolean = False;
  GTrustStore: PX509_STORE = nil;
  GTrustStoreInfo: string = '';
  X509_STORE_new: TX509_STORE_new;
  X509_STORE_free: TX509_STORE_free;
  X509_STORE_set_default_paths: TX509_STORE_set_default_paths;
  X509_STORE_load_locations: TX509_STORE_load_locations;
  X509_STORE_add_cert: TX509_STORE_add_cert;
  d2i_X509: Td2i_X509;
  X509_free: TX509_free;
  X509_STORE_CTX_new: TX509_STORE_CTX_new;
  X509_STORE_CTX_free: TX509_STORE_CTX_free;
  X509_STORE_CTX_init: TX509_STORE_CTX_init;
  X509_STORE_CTX_get0_param: TX509_STORE_CTX_get0_param;
  X509_VERIFY_PARAM_set1_host: TX509_VERIFY_PARAM_set1_host;
  X509_VERIFY_PARAM_set1_ip_asc: TX509_VERIFY_PARAM_set1_ip_asc;
  X509_STORE_CTX_set_purpose: TX509_STORE_CTX_set_purpose;
  X509_verify_cert: TX509_verify_cert;
  X509_STORE_CTX_get_error: TX509_STORE_CTX_get_error;
  X509_verify_cert_error_string: TX509_verify_cert_error_string;
  X509_get_subject_name: TX509_get_name;
  X509_get_issuer_name: TX509_get_name;
  X509_NAME_oneline: TX509_NAME_oneline;
  ERR_clear_error: TERR_clear_error;
  SSL_get_peer_certificate_fn: TSSL_get_peer_certificate;
  SSL_get_peer_cert_chain: TSSL_get_peer_cert_chain;

{$IFDEF MSWINDOWS}
type
  HCERTSTORE = Pointer;
  PCCERT_CONTEXT = ^CERT_CONTEXT;
  CERT_CONTEXT = record
    dwCertEncodingType: DWORD;
    pbCertEncoded: PByte;
    cbCertEncoded: DWORD;
    pCertInfo: Pointer;
    hCertStore: HCERTSTORE;
  end;

function CertOpenSystemStoreW(hProv: THandle; szSubsystemProtocol: PWideChar): HCERTSTORE;
  stdcall; external 'crypt32.dll';
function CertEnumCertificatesInStore(hCertStore: HCERTSTORE;
  pPrevCertContext: PCCERT_CONTEXT): PCCERT_CONTEXT; stdcall; external 'crypt32.dll';
function CertCloseStore(hCertStore: HCERTSTORE; dwFlags: DWORD): BOOL;
  stdcall; external 'crypt32.dll';

function AddWindowsStore(AStore: PX509_STORE; const AName: UnicodeString): Integer;
var
  LStore: HCERTSTORE;
  LContext: PCCERT_CONTEXT;
  LData: PByte;
  LCert: PX509;
begin
  Result := 0;
  LStore := CertOpenSystemStoreW(0, PWideChar(AName));
  if LStore = nil then
    Exit;
  try
    LContext := CertEnumCertificatesInStore(LStore, nil);
    while LContext <> nil do
    begin
      LData := LContext^.pbCertEncoded;
      LCert := d2i_X509(nil, @LData, LContext^.cbCertEncoded);
      if LCert <> nil then
      begin
        if X509_STORE_add_cert(AStore, LCert) = 1 then
          Inc(Result);
        X509_free(LCert);
      end;
      LContext := CertEnumCertificatesInStore(LStore, LContext);
    end;
  finally
    CertCloseStore(LStore, 0);
  end;
end;
{$ENDIF}

function LoadVerifyFunctions: Boolean;

  function Crypto(const AName: string): Pointer;
  begin
    Result := GetProcedureAddress(SSLUtilHandle, AName);
    if Result = nil then
      GVerifyOk := False;
  end;

begin
  if GVerifyLoaded then
    Exit(GVerifyOk);
  GVerifyLoaded := True;
  GVerifyOk := True;
  X509_STORE_new := TX509_STORE_new(Crypto('X509_STORE_new'));
  X509_STORE_free := TX509_STORE_free(Crypto('X509_STORE_free'));
  X509_STORE_set_default_paths := TX509_STORE_set_default_paths(Crypto('X509_STORE_set_default_paths'));
  X509_STORE_load_locations := TX509_STORE_load_locations(Crypto('X509_STORE_load_locations'));
  X509_STORE_add_cert := TX509_STORE_add_cert(Crypto('X509_STORE_add_cert'));
  d2i_X509 := Td2i_X509(Crypto('d2i_X509'));
  X509_free := TX509_free(Crypto('X509_free'));
  X509_STORE_CTX_new := TX509_STORE_CTX_new(Crypto('X509_STORE_CTX_new'));
  X509_STORE_CTX_free := TX509_STORE_CTX_free(Crypto('X509_STORE_CTX_free'));
  X509_STORE_CTX_init := TX509_STORE_CTX_init(Crypto('X509_STORE_CTX_init'));
  X509_STORE_CTX_get0_param := TX509_STORE_CTX_get0_param(Crypto('X509_STORE_CTX_get0_param'));
  X509_VERIFY_PARAM_set1_host := TX509_VERIFY_PARAM_set1_host(Crypto('X509_VERIFY_PARAM_set1_host'));
  X509_VERIFY_PARAM_set1_ip_asc := TX509_VERIFY_PARAM_set1_ip_asc(Crypto('X509_VERIFY_PARAM_set1_ip_asc'));
  X509_STORE_CTX_set_purpose := TX509_STORE_CTX_set_purpose(Crypto('X509_STORE_CTX_set_purpose'));
  X509_verify_cert := TX509_verify_cert(Crypto('X509_verify_cert'));
  X509_STORE_CTX_get_error := TX509_STORE_CTX_get_error(Crypto('X509_STORE_CTX_get_error'));
  X509_verify_cert_error_string := TX509_verify_cert_error_string(Crypto('X509_verify_cert_error_string'));
  X509_get_subject_name := TX509_get_name(Crypto('X509_get_subject_name'));
  X509_get_issuer_name := TX509_get_name(Crypto('X509_get_issuer_name'));
  X509_NAME_oneline := TX509_NAME_oneline(Crypto('X509_NAME_oneline'));
  ERR_clear_error := TERR_clear_error(Crypto('ERR_clear_error'));
  // OpenSSL 3 renamed it (the old name only exists with deprecated APIs)
  SSL_get_peer_certificate_fn := TSSL_get_peer_certificate(
    GetProcedureAddress(SSLLibHandle, 'SSL_get1_peer_certificate'));
  if not Assigned(SSL_get_peer_certificate_fn) then
    SSL_get_peer_certificate_fn := TSSL_get_peer_certificate(
      GetProcedureAddress(SSLLibHandle, 'SSL_get_peer_certificate'));
  SSL_get_peer_cert_chain := TSSL_get_peer_cert_chain(
    GetProcedureAddress(SSLLibHandle, 'SSL_get_peer_cert_chain'));
  if not (Assigned(SSL_get_peer_certificate_fn) and Assigned(SSL_get_peer_cert_chain)) then
    GVerifyOk := False;
  Result := GVerifyOk;
end;

function GetTrustStore: PX509_STORE;
{$IFNDEF MSWINDOWS}
const
  // Used when OpenSSL's own default paths do not find a bundle (e.g. an
  // OpenSSL built for another distribution)
  BundleFiles: array[0..5] of string = (
    '/etc/ssl/certs/ca-certificates.crt',
    '/etc/pki/tls/certs/ca-bundle.crt',
    '/etc/ssl/ca-bundle.pem',
    '/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem',
    '/etc/ssl/cert.pem',
    '/usr/local/share/certs/ca-root-nss.crt');
var
  I: Integer;
{$ENDIF}
var
  LLocal, LInfo: string;

  procedure LoadFile(const AFile: string);
  begin
    if X509_STORE_load_locations(Result, PAnsiChar(AnsiString(AFile)), nil) = 1 then
      LInfo := LInfo + '; ' + AFile
    else
      LInfo := LInfo + '; ' + AFile + ' (not loaded)';
  end;

begin
  // Called with GOpenSSLLock held
  if GTrustStore <> nil then
    Exit(GTrustStore);
  Result := X509_STORE_new();
  if Result = nil then
    Exit;
  // SSL_CERT_FILE / SSL_CERT_DIR and the OpenSSL directory
  X509_STORE_set_default_paths(Result);
  LInfo := 'OpenSSL default paths';
{$IFDEF MSWINDOWS}
  LInfo := LInfo + '; Windows ROOT: ' + IntToStr(AddWindowsStore(Result, 'ROOT')) +
    '; Windows CA: ' + IntToStr(AddWindowsStore(Result, 'CA'));
{$ELSE}
  for I := Low(BundleFiles) to High(BundleFiles) do
    if FileExists(BundleFiles[I]) then
    begin
      LoadFile(BundleFiles[I]);
      Break;
    end;
{$ENDIF}
  LLocal := ExtractFilePath(ParamStr(0)) + 'cacert.pem';
  if FileExists(LLocal) then
    LoadFile(LLocal);
  if (RpHttpCAFile <> '') and FileExists(RpHttpCAFile) then
    LoadFile(RpHttpCAFile);
  // Duplicates between sources are reported but harmless
  ERR_clear_error();
  GTrustStore := Result;
  GTrustStoreInfo := LInfo;
end;

function RpHttpTrustStoreInfo: string;
begin
  EnterCriticalSection(GOpenSSLLock);
  try
    Result := GTrustStoreInfo;
  finally
    LeaveCriticalSection(GOpenSSLLock);
  end;
end;

procedure RpHttpResetTrustStore;
begin
  EnterCriticalSection(GOpenSSLLock);
  try
    if (GTrustStore <> nil) and Assigned(X509_STORE_free) then
      X509_STORE_free(GTrustStore);
    GTrustStore := nil;
  finally
    LeaveCriticalSection(GOpenSSLLock);
  end;
end;

function X509NameText(AName: Pointer): string;
var
  LBuf: array[0..511] of AnsiChar;
begin
  Result := '';
  if (AName <> nil) and Assigned(X509_NAME_oneline) then
    if X509_NAME_oneline(AName, @LBuf[0], SizeOf(LBuf)) <> nil then
      Result := string(PAnsiChar(@LBuf[0]));
end;

function IsIPAddress(const AHost: string): Boolean;
var
  I: Integer;
begin
  Result := AHost <> '';
  for I := 1 to Length(AHost) do
    if not (AHost[I] in ['0'..'9', '.']) then
      if Pos(':', AHost) = 0 then
        Exit(False);
end;

type
  { TRpOpenSSLSocketHandler }

  TRpOpenSSLSocketHandler = class(TOpenSSLSocketHandler)
  private
    FClient: TNetHTTPClient;
  protected
    function DoVerifyCert: Boolean; override;
  public
    function Recv(const Buffer; Count: Integer): Integer; override;
  end;

function TRpOpenSSLSocketHandler.Recv(const Buffer; Count: Integer): Integer;
var
  E: Integer;
begin
  // FPC 3.2.2 returns 0 (end of data) when the I/O timeout expires, which
  // silently truncates the response; report it as an error instead.
  // Everything else as TOpenSSLSocketHandler.Recv (a close without
  // close_notify still ends a response without Content-Length).
  repeat
    Result := SSL.Read(@Buffer, Count);
    E := SSL.GetError(Result);
    if (E = SSL_ERROR_WANT_READ) and (Socket.IOTimeout > 0) then
      Exit(-1);
  until not (E in [SSL_ERROR_WANT_READ, SSL_ERROR_WANT_WRITE]);
  if E = SSL_ERROR_ZERO_RETURN then
    Result := 0;
end;

function TRpOpenSSLSocketHandler.DoVerifyCert: Boolean;
var
  LHost: string;
  LCert: PX509;
  LCtx: PX509_STORE_CTX;
  LParam: PX509_VERIFY_PARAM;
  LStore: PX509_STORE;
  LError: Integer;
  LInfo: TCertificate;
  LRequest: TURLRequest;
  LAccepted: Boolean;
begin
  Result := True;
  if not RpHttpVerifyServerCertificates then
    Exit;
  LHost := '';
  if Socket is TInetSocket then
    LHost := TInetSocket(Socket).Host;
  LInfo := Default(TCertificate);
  LError := -1;
  LCert := nil;
  EnterCriticalSection(GOpenSSLLock);
  try
    if not LoadVerifyFunctions then
      raise ENetHTTPCertificateException.Create(
        'The OpenSSL library does not provide the certificate verification functions');
    LCert := SSL_get_peer_certificate_fn(SSL.SSL);
    if LCert = nil then
    begin
      LInfo.VerifyError := -1;
      LInfo.VerifyErrorText := 'the server sent no certificate';
    end
    else
    begin
      LInfo.Subject := X509NameText(X509_get_subject_name(LCert));
      LInfo.Issuer := X509NameText(X509_get_issuer_name(LCert));
      LInfo.CertName := LInfo.Subject;
      LInfo.DNSName := LHost;
      LStore := GetTrustStore;
      LCtx := X509_STORE_CTX_new();
      try
        if (LStore <> nil) and (LCtx <> nil) and
          (X509_STORE_CTX_init(LCtx, LStore, LCert, SSL_get_peer_cert_chain(SSL.SSL)) = 1) then
        begin
          X509_STORE_CTX_set_purpose(LCtx, X509_PURPOSE_SSL_SERVER);
          LParam := X509_STORE_CTX_get0_param(LCtx);
          if IsIPAddress(LHost) then
            X509_VERIFY_PARAM_set1_ip_asc(LParam, PAnsiChar(AnsiString(LHost)))
          else
            X509_VERIFY_PARAM_set1_host(LParam, PAnsiChar(AnsiString(LHost)), 0);
          if X509_verify_cert(LCtx) = 1 then
            LError := 0
          else
            LError := X509_STORE_CTX_get_error(LCtx);
        end;
        LInfo.VerifyError := LError;
        if LError > 0 then
          LInfo.VerifyErrorText := string(X509_verify_cert_error_string(LError))
        else if LError < 0 then
          LInfo.VerifyErrorText := 'the certificate could not be verified';
      finally
        if LCtx <> nil then
          X509_STORE_CTX_free(LCtx);
      end;
      ERR_clear_error();
    end;
  finally
    if LCert <> nil then
      X509_free(LCert);
    LeaveCriticalSection(GOpenSSLLock);
  end;
  if LInfo.VerifyError = 0 then
    Exit(True);
  LAccepted := False;
  if Assigned(FClient) and Assigned(FClient.OnValidateServerCertificate) then
  begin
    LRequest := TURLRequest.Create(FClient.FCurrentMethod, FClient.FCurrentURL);
    try
      FClient.OnValidateServerCertificate(FClient, LRequest, LInfo, LAccepted);
    finally
      LRequest.Free;
    end;
  end;
  if not LAccepted then
    raise ENetHTTPCertificateException.CreateFmt(
      'Server certificate for %s not valid: %s', [LHost, LInfo.VerifyErrorText]);
  Result := True;
end;

{ URL rewrite }

procedure RpHttpSetUrlRewrite(const AFromPrefix, AToPrefix: string);
var
  I, J: Integer;
begin
  EnterCriticalSection(GUrlRewriteLock);
  try
    if AFromPrefix = '' then
    begin
      SetLength(GUrlRewriteFrom, 0);
      SetLength(GUrlRewriteTo, 0);
      Exit;
    end;
    for I := 0 to High(GUrlRewriteFrom) do
      if CompareText(GUrlRewriteFrom[I], AFromPrefix) = 0 then
      begin
        if AToPrefix <> '' then
          GUrlRewriteTo[I] := AToPrefix
        else
        begin
          for J := I to High(GUrlRewriteFrom) - 1 do
          begin
            GUrlRewriteFrom[J] := GUrlRewriteFrom[J + 1];
            GUrlRewriteTo[J] := GUrlRewriteTo[J + 1];
          end;
          SetLength(GUrlRewriteFrom, Length(GUrlRewriteFrom) - 1);
          SetLength(GUrlRewriteTo, Length(GUrlRewriteTo) - 1);
        end;
        Exit;
      end;
    if AToPrefix <> '' then
    begin
      SetLength(GUrlRewriteFrom, Length(GUrlRewriteFrom) + 1);
      SetLength(GUrlRewriteTo, Length(GUrlRewriteTo) + 1);
      GUrlRewriteFrom[High(GUrlRewriteFrom)] := AFromPrefix;
      GUrlRewriteTo[High(GUrlRewriteTo)] := AToPrefix;
    end;
  finally
    LeaveCriticalSection(GUrlRewriteLock);
  end;
end;

function RpHttpRewriteUrl(const AURL: string): string;
var
  I: Integer;
begin
  Result := AURL;
  EnterCriticalSection(GUrlRewriteLock);
  try
    for I := 0 to High(GUrlRewriteFrom) do
      if CompareText(Copy(AURL, 1, Length(GUrlRewriteFrom[I])), GUrlRewriteFrom[I]) = 0 then
      begin
        Result := GUrlRewriteTo[I] + Copy(AURL, Length(GUrlRewriteFrom[I]) + 1, MaxInt);
        Break;
      end;
  finally
    LeaveCriticalSection(GUrlRewriteLock);
  end;
end;

{ TNameValuePair }

constructor TNameValuePair.Create(const AName, AValue: string);
begin
  Name := AName;
  Value := AValue;
end;

{ TURLRequest }

constructor TURLRequest.Create(const AMethod, AURL: string);
begin
  inherited Create;
  FMethodString := AMethod;
  FURL := AURL;
end;

{ Response }

type
  TRpHTTPResponse = class(TInterfacedObject, IHTTPResponse)
  private
    FStatusCode: Integer;
    FStatusText: string;
    FHeaders: TStringList;
    FOwnStream: TMemoryStream;
    FContent: TStream;
    FContentStart: Int64;
  public
    constructor Create;
    destructor Destroy; override;
    function GetStatusCode: Integer;
    function GetStatusText: string;
    function GetContentStream: TStream;
    function GetHeaderValue(const AName: string): string;
    function GetHeaders: TNetHeaders;
    function GetContentCharSet: string;
    function GetMimeType: string;
    function GetContentLength: Int64;
    function ContainsHeader(const AName: string): Boolean;
    function ContentAsString(const AnEncoding: TEncoding = nil): string;
  end;

  // Writes through to the response stream and reports each block
  TRpNotifyStream = class(TStream)
  private
    FTarget: TStream;
    FOwner: TNetHTTPClient;
    FClient: TFPHTTPClient;
    FCount: Int64;
  public
    constructor Create(ATarget: TStream; AOwner: TNetHTTPClient; AClient: TFPHTTPClient);
    function Write(const Buffer; Count: Longint): Longint; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TRpHTTPResponse.Create;
begin
  inherited Create;
  FHeaders := TStringList.Create;
  FHeaders.NameValueSeparator := ':';
end;

destructor TRpHTTPResponse.Destroy;
begin
  FHeaders.Free;
  FOwnStream.Free;
  inherited Destroy;
end;

function TRpHTTPResponse.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

function TRpHTTPResponse.GetStatusText: string;
begin
  Result := FStatusText;
end;

function TRpHTTPResponse.GetContentStream: TStream;
begin
  Result := FContent;
end;

function TRpHTTPResponse.GetHeaderValue(const AName: string): string;
begin
  Result := TFPCustomHTTPClient.GetHeader(FHeaders, AName);
end;

function TRpHTTPResponse.ContainsHeader(const AName: string): Boolean;
begin
  Result := TFPCustomHTTPClient.IndexOfHeader(FHeaders, AName) >= 0;
end;

function TRpHTTPResponse.GetHeaders: TNetHeaders;
var
  I, P: Integer;
  S: string;
begin
  Result := nil;
  SetLength(Result, FHeaders.Count);
  for I := 0 to FHeaders.Count - 1 do
  begin
    S := FHeaders[I];
    P := Pos(':', S);
    if P > 0 then
      Result[I] := TNameValuePair.Create(Trim(Copy(S, 1, P - 1)), Trim(Copy(S, P + 1, MaxInt)))
    else
      Result[I] := TNameValuePair.Create(Trim(S), '');
  end;
end;

function TRpHTTPResponse.GetMimeType: string;
var
  P: Integer;
begin
  Result := GetHeaderValue('Content-Type');
  P := Pos(';', Result);
  if P > 0 then
    Result := Copy(Result, 1, P - 1);
  Result := Trim(Result);
end;

function TRpHTTPResponse.GetContentCharSet: string;
var
  LType: string;
  P: Integer;
begin
  Result := '';
  LType := GetHeaderValue('Content-Type');
  P := Pos('charset=', LowerCase(LType));
  if P > 0 then
  begin
    Result := Trim(Copy(LType, P + 8, MaxInt));
    P := Pos(';', Result);
    if P > 0 then
      Result := Trim(Copy(Result, 1, P - 1));
    Result := StringReplace(Result, '"', '', [rfReplaceAll]);
  end;
end;

function TRpHTTPResponse.GetContentLength: Int64;
begin
  Result := StrToInt64Def(GetHeaderValue('Content-Length'), -1);
  if (Result < 0) and (FContent <> nil) then
    Result := FContent.Size - FContentStart;
end;

function TRpHTTPResponse.ContentAsString(const AnEncoding: TEncoding): string;
var
  LBytes: TBytes;
  LSize: Int64;
  LOldPos: Int64;
  LCharSet: string;
  LEncoding: TEncoding;
  LOwnEncoding: Boolean;
begin
  Result := '';
  if FContent = nil then
    Exit;
  LSize := FContent.Size - FContentStart;
  if LSize <= 0 then
    Exit;
  SetLength(LBytes, LSize);
  LOldPos := FContent.Position;
  try
    FContent.Position := FContentStart;
    FContent.ReadBuffer(LBytes[0], LSize);
  finally
    FContent.Position := LOldPos;
  end;
  LEncoding := AnEncoding;
  LOwnEncoding := False;
  if LEncoding = nil then
  begin
    LCharSet := LowerCase(GetContentCharSet);
    if (LCharSet = 'iso-8859-1') or (LCharSet = 'latin1') then
    begin
      LEncoding := TEncoding.GetEncoding(28591);
      LOwnEncoding := True;
    end
    else if LCharSet = 'windows-1252' then
    begin
      LEncoding := TEncoding.GetEncoding(1252);
      LOwnEncoding := True;
    end;
  end;
  try
    if (LEncoding = nil) or (LEncoding = TEncoding.UTF8) then
      // UTF-8 already: the bytes are the string
      SetString(Result, PAnsiChar(@LBytes[0]), Length(LBytes))
    else
      Result := UTF8Encode(LEncoding.GetString(LBytes));
  finally
    if LOwnEncoding then
      LEncoding.Free;
  end;
end;

{ TRpNotifyStream }

constructor TRpNotifyStream.Create(ATarget: TStream; AOwner: TNetHTTPClient;
  AClient: TFPHTTPClient);
begin
  inherited Create;
  FTarget := ATarget;
  FOwner := AOwner;
  FClient := AClient;
end;

function TRpNotifyStream.Write(const Buffer; Count: Longint): Longint;
var
  LAbort: Boolean;
  LLength: Int64;
begin
  Result := FTarget.Write(Buffer, Count);
  Inc(FCount, Result);
  if Assigned(FOwner.OnReceiveData) then
  begin
    LAbort := False;
    LLength := StrToInt64Def(TFPCustomHTTPClient.GetHeader(FClient.ResponseHeaders,
      'Content-Length'), -1);
    FOwner.OnReceiveData(FOwner, LLength, FCount, LAbort);
    if LAbort then
      FClient.Terminate;
  end;
end;

function TRpNotifyStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := FTarget.Read(Buffer, Count);
end;

function TRpNotifyStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := FTarget.Seek(Offset, Origin);
end;

{ TNetHTTPClient }

constructor TNetHTTPClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCustomHeaders := TStringList.Create;
  FConnectionTimeout := 60000;
  FSendTimeout := 60000;
  FResponseTimeout := 60000;
  FHandleRedirects := True;
  FMaxRedirects := 5;
  FSynchronizeEvents := True;
end;

destructor TNetHTTPClient.Destroy;
begin
  FCustomHeaders.Free;
  inherited Destroy;
end;

function TNetHTTPClient.GetCustomHeader(const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FCustomHeaders.Count - 1 do
    if SameText(FCustomHeaders.Names[I], AName) then
      Exit(FCustomHeaders.ValueFromIndex[I]);
end;

procedure TNetHTTPClient.SetCustomHeader(const AName, AValue: string);
var
  I: Integer;
begin
  for I := 0 to FCustomHeaders.Count - 1 do
    if SameText(FCustomHeaders.Names[I], AName) then
    begin
      if AValue = '' then
        FCustomHeaders.Delete(I)
      else
        FCustomHeaders[I] := AName + '=' + AValue;
      Exit;
    end;
  if AValue <> '' then
    FCustomHeaders.Add(AName + '=' + AValue);
end;

function TNetHTTPClient.GetContentType: string;
begin
  Result := GetCustomHeader('Content-Type');
end;

procedure TNetHTTPClient.SetContentType(const AValue: string);
begin
  SetCustomHeader('Content-Type', AValue);
end;

function TNetHTTPClient.GetAccept: string;
begin
  Result := GetCustomHeader('Accept');
end;

procedure TNetHTTPClient.SetAccept(const AValue: string);
begin
  SetCustomHeader('Accept', AValue);
end;

function TNetHTTPClient.GetAcceptCharSet: string;
begin
  Result := GetCustomHeader('Accept-Charset');
end;

procedure TNetHTTPClient.SetAcceptCharSet(const AValue: string);
begin
  SetCustomHeader('Accept-Charset', AValue);
end;

function TNetHTTPClient.GetAcceptLanguage: string;
begin
  Result := GetCustomHeader('Accept-Language');
end;

procedure TNetHTTPClient.SetAcceptLanguage(const AValue: string);
begin
  SetCustomHeader('Accept-Language', AValue);
end;

function TNetHTTPClient.GetUserAgent: string;
begin
  Result := GetCustomHeader('User-Agent');
end;

procedure TNetHTTPClient.SetUserAgent(const AValue: string);
begin
  SetCustomHeader('User-Agent', AValue);
end;

procedure TNetHTTPClient.DoGetSocketHandler(Sender: TObject; const UseSSL: Boolean;
  out AHandler: TSocketHandler);
var
  LError: string;
  LHandler: TRpOpenSSLSocketHandler;
begin
  AHandler := nil;
  if not UseSSL then
    Exit;
  if not RpOpenSSLAvailable(LError) then
    raise ENetHTTPClientException.Create(LError);
  LHandler := TRpOpenSSLSocketHandler.Create;
  LHandler.FClient := Self;
  // Verification is done in DoVerifyCert, after the handshake, against the
  // system trust store; OpenSSL's own check needs a trust store in the
  // context, which FPC 3.2.2 does not set up
  LHandler.VerifyPeerCert := False;
  LHandler.SendHostAsSNI := True;
  AHandler := LHandler;
end;

{$IFDEF MSWINDOWS}
type
  // FPC 3.2.2 TInetSocket waits for the non-blocking connect with select on
  // the write set only, but Windows reports a refused connection in the
  // except set: the connect then waits the whole ConnectTimeout (60 s by
  // default) instead of failing at once. This socket watches both sets.
  TRpProbeSocket = class(TInetSocket)
  protected
    function CheckSocketConnectTimeout(ASocket: cint; AFDSPtr: Pointer;
      ATimeVPtr: Pointer): TCheckTimeoutResult; override;
  end;

var
  GProbeLock: TRTLCriticalSection;
  GProbeOK: TStringList;

const
  // A server that accepted a connection is not checked again for this time
  PROBE_OK_MS = 30000;

function TRpProbeSocket.CheckSocketConnectTimeout(ASocket: cint;
  AFDSPtr: Pointer; ATimeVPtr: Pointer): TCheckTimeoutResult;
var
  LWrite, LExcept: winsock2.TFDSet;
  LTime: winsock2.PTimeVal;
  LRes: LongInt;
  LErr, LErrLen: LongInt;
begin
  LTime := winsock2.PTimeVal(ATimeVPtr);
  LTime^.tv_usec := 0;
  LTime^.tv_sec := ConnectTimeout div 1000;
  winsock2.FD_ZERO(LWrite);
  winsock2.FD_SET(ASocket, LWrite);
  winsock2.FD_ZERO(LExcept);
  winsock2.FD_SET(ASocket, LExcept);
  LRes := winsock2.select(ASocket + 1, nil, @LWrite, @LExcept, LTime);
  if LRes = 0 then
    Exit(ctrTimeout);
  Result := ctrError;
  if LRes < 0 then
    Exit;
  // In the except set: refused or unreachable
  if winsock2.FD_ISSET(ASocket, LExcept) then
    Exit;
  if winsock2.FD_ISSET(ASocket, LWrite) then
  begin
    LErrLen := SizeOf(LErr);
    if (fpGetSockOpt(ASocket, SOL_SOCKET, SO_ERROR, @LErr, @LErrLen) = 0) and
      (LErr = 0) then
      Result := ctrOK;
  end;
end;

// Before the real request, check with TRpProbeSocket that the server accepts
// connections, so that a refused one fails at once as on Linux. A server that
// answered recently is not checked again. Raises ESocketError on failure.
procedure RpProbeServer(const AURL: string; ATimeoutMs: Integer);
var
  LURI: TURI;
  LPort: Word;
  LKey: string;
  I: Integer;
  LNow: QWord;
  LSocket: TRpProbeSocket;
begin
  LURI := ParseURI(AURL);
  if LURI.Host = '' then
    Exit;
  LPort := LURI.Port;
  if LPort = 0 then
    if SameText(LURI.Protocol, 'https') then
      LPort := 443
    else
      LPort := 80;
  LKey := LowerCase(LURI.Host) + ':' + IntToStr(LPort);
  LNow := GetTickCount64;
  EnterCriticalSection(GProbeLock);
  try
    I := GProbeOK.IndexOf(LKey);
    if (I >= 0) and (LNow - QWord(PtrUInt(GProbeOK.Objects[I])) < PROBE_OK_MS) then
      Exit;
  finally
    LeaveCriticalSection(GProbeLock);
  end;
  // Connects in the constructor (no handler), with the request's timeout
  LSocket := TRpProbeSocket.Create(LURI.Host, LPort, ATimeoutMs, nil);
  LSocket.Free;
  EnterCriticalSection(GProbeLock);
  try
    I := GProbeOK.IndexOf(LKey);
    if I < 0 then
      I := GProbeOK.Add(LKey);
    GProbeOK.Objects[I] := TObject(PtrUInt(LNow));
  finally
    LeaveCriticalSection(GProbeLock);
  end;
end;
{$ENDIF}

function TNetHTTPClient.DoExecute(const AMethod, AURL: string; ASource,
  AResponseContent: TStream; const AHeaders: TNetHeaders): IHTTPResponse;
var
  LClient: TFPHTTPClient;
  LResponse: TRpHTTPResponse;
  LTarget: TStream;
  LNotify: TRpNotifyStream;
  I: Integer;
  LUrl, LMethod: string;
  LIOTimeout: Integer;
begin
  LUrl := RpHttpRewriteUrl(AURL);
  LMethod := UpperCase(AMethod);
  FCurrentMethod := LMethod;
  FCurrentURL := LUrl;
  LResponse := TRpHTTPResponse.Create;
  Result := LResponse;
  if AResponseContent <> nil then
  begin
    LTarget := AResponseContent;
    LResponse.FContentStart := AResponseContent.Position;
  end
  else
  begin
    LResponse.FOwnStream := TMemoryStream.Create;
    LTarget := LResponse.FOwnStream;
    LResponse.FContentStart := 0;
  end;
  LResponse.FContent := LTarget;
  LClient := TFPHTTPClient.Create(nil);
  LNotify := TRpNotifyStream.Create(LTarget, Self, LClient);
  try
    LClient.KeepConnection := False;
    LClient.AllowRedirect := FHandleRedirects;
    if FMaxRedirects > 0 then
      LClient.MaxRedirects := FMaxRedirects;
    LClient.ConnectTimeout := FConnectionTimeout;
    // fphttpclient has one socket timeout for sending and receiving; the
    // response timeout is the one that matters (the time the server takes)
    LIOTimeout := FResponseTimeout;
    if LIOTimeout < 0 then
      LIOTimeout := 0;
    LClient.IOTimeout := LIOTimeout;
    LClient.OnGetSocketHandler := DoGetSocketHandler;
    for I := 0 to FCustomHeaders.Count - 1 do
      LClient.AddHeader(FCustomHeaders.Names[I], FCustomHeaders.ValueFromIndex[I]);
    for I := 0 to Length(AHeaders) - 1 do
      LClient.AddHeader(AHeaders[I].Name, AHeaders[I].Value);
    if LClient.IndexOfHeader('User-Agent') < 0 then
      LClient.AddHeader('User-Agent', DefaultUserAgent);
    if ASource <> nil then
    begin
      ASource.Position := 0;
      LClient.RequestBody := ASource;
    end
    else if (LMethod = 'POST') or (LMethod = 'PUT') or (LMethod = 'PATCH') then
      // Some servers and proxies reject a POST without Content-Length (411)
      LClient.AddHeader('Content-Length', '0');
    try
{$IFDEF MSWINDOWS}
      RpProbeServer(LUrl, FConnectionTimeout);
{$ENDIF}
      LClient.HTTPMethod(LMethod, LUrl, LNotify, []);
    except
      on E: ENetHTTPException do
        raise;
      on E: ESocketError do
        raise ENetHTTPClientException.CreateFmt('Error sending data to %s: %s', [LUrl, E.Message]);
      on E: EHTTPClient do
        raise ENetHTTPClientException.CreateFmt('Error receiving data from %s: %s', [LUrl, E.Message]);
      on E: EInOutError do
        raise ENetHTTPClientException.CreateFmt('Error connecting to %s: %s', [LUrl, E.Message]);
    end;
    LResponse.FStatusCode := LClient.ResponseStatusCode;
    LResponse.FStatusText := Trim(LClient.ResponseStatusText);
    LResponse.FHeaders.Assign(LClient.ResponseHeaders);
  finally
    LNotify.Free;
    LClient.Free;
  end;
end;

function TNetHTTPClient.Execute(const ARequestMethod, AURL: string;
  const ASourceStream: TStream; const AContentStream: TStream;
  const AHeaders: TNetHeaders): IHTTPResponse;
begin
  Result := DoExecute(ARequestMethod, AURL, ASourceStream, AContentStream, AHeaders);
end;

function TNetHTTPClient.Get(const AURL: string; const AResponseContent: TStream;
  const AHeaders: TNetHeaders): IHTTPResponse;
begin
  Result := DoExecute('GET', AURL, nil, AResponseContent, AHeaders);
end;

function TNetHTTPClient.Head(const AURL: string; const AHeaders: TNetHeaders): IHTTPResponse;
begin
  Result := DoExecute('HEAD', AURL, nil, nil, AHeaders);
end;

function TNetHTTPClient.Delete(const AURL: string; const AResponseContent: TStream;
  const AHeaders: TNetHeaders): IHTTPResponse;
begin
  Result := DoExecute('DELETE', AURL, nil, AResponseContent, AHeaders);
end;

function TNetHTTPClient.Post(const AURL: string; const ASource: TStream;
  const AResponseContent: TStream; const AHeaders: TNetHeaders): IHTTPResponse;
begin
  Result := DoExecute('POST', AURL, ASource, AResponseContent, AHeaders);
end;

function TNetHTTPClient.Post(const AURL: string; const ASource: TStrings;
  const AResponseContent: TStream; const AEncoding: TEncoding;
  const AHeaders: TNetHeaders): IHTTPResponse;
var
  LBody: string;
  LStream: TStringStream;
  I: Integer;
  LOldType: string;
begin
  LBody := '';
  if ASource <> nil then
    for I := 0 to ASource.Count - 1 do
    begin
      if I > 0 then
        LBody := LBody + '&';
      LBody := LBody + EncodeURLElement(ASource.Names[I]) + '=' +
        EncodeURLElement(ASource.ValueFromIndex[I]);
    end;
  LStream := TStringStream.Create(LBody);
  LOldType := ContentType;
  try
    if LOldType = '' then
      ContentType := 'application/x-www-form-urlencoded';
    Result := DoExecute('POST', AURL, LStream, AResponseContent, AHeaders);
  finally
    ContentType := LOldType;
    LStream.Free;
  end;
end;

function TNetHTTPClient.Put(const AURL: string; const ASource: TStream;
  const AResponseContent: TStream; const AHeaders: TNetHeaders): IHTTPResponse;
begin
  Result := DoExecute('PUT', AURL, ASource, AResponseContent, AHeaders);
end;

function TNetHTTPClient.Patch(const AURL: string; const ASource: TStream;
  const AResponseContent: TStream; const AHeaders: TNetHeaders): IHTTPResponse;
begin
  Result := DoExecute('PATCH', AURL, ASource, AResponseContent, AHeaders);
end;

{ THTTPClient }

constructor THTTPClient.Create;
begin
  inherited Create(nil);
end;

{ Browser }

{$IFDEF MSWINDOWS}
function ShellExecuteW(hwnd: HWND; lpOperation, lpFile, lpParameters,
  lpDirectory: PWideChar; nShowCmd: Integer): HINST; stdcall; external 'shell32.dll';
{$ENDIF}

function RpOpenUrlInBrowser(const AURL: string): Boolean;
{$IFDEF MSWINDOWS}
var
  LUrl: UnicodeString;
begin
  Result := False;
  if AURL = '' then
    Exit;
  if Assigned(RpOpenUrlHook) then
    Exit(RpOpenUrlHook(AURL));
  LUrl := UTF8Decode(AURL);
  Result := ShellExecuteW(0, 'open', PWideChar(LUrl), nil, nil, SW_SHOWNORMAL) > 32;
end;
{$ELSE}
const
  // The URL is passed as $1, never inside the script text
  Script =
    'if [ -n "$BROWSER" ]; then $BROWSER "$1" >/dev/null 2>&1 & exit 0; fi; ' +
    'for b in xdg-open "gio open" x-www-browser; do ' +
    'c=${b%% *}; ' +
    'if command -v "$c" >/dev/null 2>&1; then $b "$1" >/dev/null 2>&1 & exit 0; fi; ' +
    'done; exit 127';
var
  LProcess: TProcess;
begin
  Result := False;
  if AURL = '' then
    Exit;
  if Assigned(RpOpenUrlHook) then
    Exit(RpOpenUrlHook(AURL));
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := '/bin/sh';
    LProcess.Parameters.Add('-c');
    LProcess.Parameters.Add(Script);
    LProcess.Parameters.Add('sh');
    LProcess.Parameters.Add(AURL);
    LProcess.Options := [poWaitOnExit];
    try
      LProcess.Execute;
      Result := LProcess.ExitStatus = 0;
    except
      Result := False;
    end;
  finally
    LProcess.Free;
  end;
end;
{$ENDIF}

{ Loopback listener }

type
  TRpLoopbackServer = class
  private
    FServer: TInetServer;
    FStart: TDateTime;
    FTimeoutMs: Cardinal;
    FOnRequest: TRpLoopbackRequestEvent;
    FDone: Boolean;
    procedure DoIdle(Sender: TObject);
    procedure DoConnect(Sender: TObject; Data: TSocketStream);
  end;

procedure TRpLoopbackServer.DoIdle(Sender: TObject);
begin
  if MilliSecondsBetween(Now, FStart) >= FTimeoutMs then
    FServer.StopAccepting(False);
end;

procedure TRpLoopbackServer.DoConnect(Sender: TObject; Data: TSocketStream);
var
  LRequest, LChunk, LLine, LTarget, LPath, LQuery, LBody, LType, LStatusText, LHeader: string;
  LBuf: array[0..4095] of Char;
  LRead, P, LStatus: Integer;
  LDone: Boolean;
begin
  try
    Data.IOTimeout := 5000;
{$IFDEF LINUX}
    Data.ReadFlags := MSG_NOSIGNAL;
    Data.WriteFlags := MSG_NOSIGNAL;
{$ENDIF}
    // Read the request head (the redirect is a GET without body)
    LRequest := '';
    repeat
      LRead := Data.Read(LBuf[0], SizeOf(LBuf));
      if LRead > 0 then
      begin
        SetString(LChunk, PChar(@LBuf[0]), LRead);
        LRequest := LRequest + LChunk;
      end;
    until (LRead <= 0) or (Pos(#13#10#13#10, LRequest) > 0) or (Length(LRequest) > 65536);
    P := Pos(#13#10, LRequest);
    if P > 0 then
      LLine := Copy(LRequest, 1, P - 1)
    else
      LLine := LRequest;
    // "GET /path?query HTTP/1.1"
    LTarget := LLine;
    P := Pos(' ', LTarget);
    if P > 0 then
      LTarget := Copy(LTarget, P + 1, MaxInt);
    P := Pos(' ', LTarget);
    if P > 0 then
      LTarget := Copy(LTarget, 1, P - 1);
    P := Pos('?', LTarget);
    if P > 0 then
    begin
      LPath := Copy(LTarget, 1, P - 1);
      LQuery := Copy(LTarget, P + 1, MaxInt);
    end
    else
    begin
      LPath := LTarget;
      LQuery := '';
    end;
    LStatus := 404;
    LType := 'text/plain; charset=utf-8';
    LBody := '';
    LDone := False;
    if (LPath <> '/favicon.ico') and Assigned(FOnRequest) then
    begin
      LStatus := 200;
      LType := 'text/html; charset=utf-8';
      FOnRequest(LPath, LQuery, LStatus, LType, LBody, LDone);
    end;
    case LStatus of
      200: LStatusText := 'OK';
      400: LStatusText := 'Bad Request';
      404: LStatusText := 'Not Found';
    else
      LStatusText := 'Status';
    end;
    LHeader := 'HTTP/1.1 ' + IntToStr(LStatus) + ' ' + LStatusText + #13#10 +
      'Content-Type: ' + LType + #13#10 +
      'Content-Length: ' + IntToStr(Length(LBody)) + #13#10 +
      'Connection: close'#13#10#13#10;
    LHeader := LHeader + LBody;
    if LHeader <> '' then
      Data.WriteBuffer(LHeader[1], Length(LHeader));
    if LDone then
    begin
      FDone := True;
      FServer.StopAccepting(False);
    end;
  finally
    Data.Free;
  end;
end;

function RpWaitForLoopbackRequest(APort: Word; ATimeoutMs: Cardinal;
  AOnRequest: TRpLoopbackRequestEvent; out AError: string;
  AOnListening: TNotifyEvent): Boolean;
var
  LServer: TRpLoopbackServer;
begin
  Result := False;
  AError := '';
  LServer := TRpLoopbackServer.Create;
  try
    LServer.FTimeoutMs := ATimeoutMs;
    LServer.FOnRequest := AOnRequest;
    try
      LServer.FServer := TInetServer.Create('127.0.0.1', APort);
      LServer.FServer.ReuseAddress := True;
      LServer.FServer.AcceptIdleTimeOut := 200;
      LServer.FServer.OnIdle := LServer.DoIdle;
      LServer.FServer.OnConnect := LServer.DoConnect;
      LServer.FServer.MaxConnections := -1;
      LServer.FStart := Now;
      LServer.FServer.Bind;
      LServer.FServer.Listen;
      if Assigned(AOnListening) then
        AOnListening(nil);
      LServer.FServer.StartAccepting;
      Result := LServer.FDone;
      if not Result then
        AError := 'timeout';
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    LServer.FServer.Free;
    LServer.Free;
  end;
end;

function RpLoopbackPortAvailable(APort: Word): Boolean;
var
  LServer: TInetServer;
begin
  Result := False;
  LServer := nil;
  try
    try
      LServer := TInetServer.Create('127.0.0.1', APort);
      LServer.ReuseAddress := False;
      LServer.Bind;
      Result := True;
    except
      Result := False;
    end;
  finally
    LServer.Free;
  end;
end;

initialization
  InitCriticalSection(GOpenSSLLock);
  InitCriticalSection(GUrlRewriteLock);
{$IFDEF MSWINDOWS}
  InitCriticalSection(GProbeLock);
  GProbeOK := TStringList.Create;
{$ENDIF}
finalization
{$IFDEF MSWINDOWS}
  GProbeOK.Free;
  DoneCriticalSection(GProbeLock);
{$ENDIF}
  if (GTrustStore <> nil) and Assigned(X509_STORE_free) and IsSSLloaded then
    X509_STORE_free(GTrustStore);
  GTrustStore := nil;
  DoneCriticalSection(GUrlRewriteLock);
  DoneCriticalSection(GOpenSSLLock);
end.
