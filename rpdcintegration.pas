// =====================================================================
//   Report Manager - rpdcintegration
//
//   Bridges the WebRTC Direct Channel stack (rpdchub + rpdcpool) into
//   the existing rpdatahttp.pas flow. The integration is OFF by
//   default; the host application opts in by calling
//   EnableDirectChannel with the API base URL, JWT and InstallId.
//
//   Once enabled:
//     - TRpDatasetHttp.Open tries pool.Acquire(hubDatabaseId) first.
//     - On success, it serializes the query, sends it over the live
//       DataChannel and lets TRpDcHubClient populate the target
//       TClientDataSet via FastSerializer.
//     - On any failure (channel never opened, query timed out, Agent
//       returned an error) the handler returns False and Open() runs
//       its existing HTTP code path with NO change in semantics.
//
//   This unit owns the singleton pool. Reloading the JWT (logout +
//   login) requires DisableDirectChannel then EnableDirectChannel
//   again - sessions issued under the old token will not be reusable.
//
//   Copyright (c) 2026 Toni Martir
//   toni@reportman.es
// =====================================================================

unit rpdcintegration;

interface

{$I rpconf.inc}

// The entire WebRTC Direct Channel integration is Windows-only - it
// pulls libdatachannel.dll (Windows binary), the .RES bundle with
// the embedded x86/x64 zips, and LoadLibrary-based dynamic loading.
// On Linux / FPC builds (printreptopdf, repwebexe, ...) this unit
// compiles as an empty no-op so the .dpr can `uses rpdcintegration`
// without per-platform conditionals.
{$IFDEF MSWINDOWS}

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.SyncObjs,
  System.IOUtils, System.Zip,
  Data.DB, Datasnap.DBClient,
  rpparams,
  rpmdshfolder,
  rpdatahttp,
  rplibdatachannel,
  rpfastserializer,
  rpdatadirect,
  rpdchub,
  rpdcpool;

const
  // Bumped whenever the embedded libdatachannel.dll set changes.
  // Mirrors the AssetsVersion pattern of Monaco/Markdown - users get
  // a transparent re-extract when they install a new OCX.
  LibDataChannelAssetsVersion = '0.24.3-vcpkg-static-crt';

// Spin up the global pool and install the TRpDatasetHttp hook. The
// DLL is extracted from the embedded LIBDATACHANNEL_{X64,X86}_ZIP
// resources on the first call (or whenever the version file in
// LocalAppData no longer matches LibDataChannelAssetsVersion).
// Idempotent on same arguments; calling with new arguments (e.g.,
// after the user logged in again) closes the old pool and starts a
// new one.
procedure EnableDirectChannel(const AApiBaseUrl, ABearerToken: string;
                              const AInstallId: string;
                              AcceptInvalidCerts: Boolean = False);

// Same as EnableDirectChannel but never raises. Used from the data
// driver (TRpDatabaseHttp.SetConnected) where any extraction failure
// must be silent - the user simply continues with the HTTP path.
// Returns True if the channel was enabled successfully.
function EnableDirectChannelIfPossible(
                              const AApiBaseUrl, ABearerToken: string;
                              const AInstallId: string;
                              AcceptInvalidCerts: Boolean = False): Boolean;

// Close the pool and clear the hook. After this TRpDatasetHttp.Open
// reverts to the HTTP path exclusively.
procedure DisableDirectChannel;

// Returns True if the hook is currently active.
function IsDirectChannelEnabled: Boolean;

// Pool diagnostics passthrough.
function DirectChannelStatusReport: string;

// Resolves to the absolute path of the extracted datachannel.dll
// after a successful EnableDirectChannel. Empty string if the lib
// has not been extracted yet (or extraction failed).
function GetDataChannelDllPath: string;

// Last transport observed for a given hubDatabaseId.
//   rcmDirectP2P  - host candidates, no NAT involvement
//   rcmHolePunch  - srflx/prflx pair (NAT/STUN)
//   rcmRelay      - TURN
//   rcmUnknown    - DC up but pair undetermined, OR no DC for this id yet
// The function looks the database up in the live pool; if the entry
// is missing the result is rcmUnknown.
function GetLastTransportForDatabase(
                              HubDatabaseId: Int64): TRpDcConnectionMode;

// True iff the most recent TryDirectImpl call for this database
// returned False (meaning the caller fell back to HTTP). Used by
// the Designer UI to paint the chip as "API" instead of pretending
// the channel is direct when it was not.
function DidFallBackToApiForDatabase(HubDatabaseId: Int64): Boolean;

// Human-readable formatting for the chip caption / log lines.
function FormatTransportMode(AMode: TRpDcConnectionMode;
                             AFallbackApi: Boolean): string;

{$ENDIF MSWINDOWS}

implementation

{$IFDEF MSWINDOWS}

// Embedded x86/x64 zip bundles - the .RES is a Windows PE-format
// resource file produced by brcc32 (LibDataChannelAssets.RC). On
// Linux the entire implementation section is compiled out so the
// resource directive never reaches the compiler.
{$R LibDataChannelAssets.res}

uses
  System.Variants,
  System.Generics.Collections,
  rptypes,
  rpauthmanager;

var
  GLock: TCriticalSection = nil;
  GPool: TRpDcHubChannelPool = nil;
  GApiBaseUrl: string = '';
  GBearerToken: string = '';
  GInstallId: string = '';
  GAcceptInvalidCerts: Boolean = False;
  GLibraryLoaded: Boolean = False;
  GDllPath: string = '';
  // Per-database flag: True when the most recent TryDirectImpl had
  // to fall back to HTTP. Read by the UI chip to display "API" when
  // direct could not be used for that database. Set inside
  // TryDirectImpl, cleared on successful direct executes.
  GFallbackToApi: TDictionary<Int64, Boolean> = nil;
  // Per-database ApiKey, populated by DatabaseConnectHookImpl whenever
  // a TRpDatabaseHttp connects. The opener callback reads from here so
  // each session can authenticate without a Bearer JWT (the Designer
  // never logs the user in - the apikey IS the credential).
  GApiKeyForDb: TDictionary<Int64, string> = nil;
  // Per-database transport snapshot captured by TryDirectImpl right
  // after a successful Execute. The pool's PeekConnectionMode can
  // return rcmUnknown when the UI samples the chip in the brief
  // window between Execute completing and libdc finalizing the
  // candidate pair selection, so we cache the value we observed on
  // the worker thread once we know it is stable.
  GLastTransport: TDictionary<Int64, TRpDcConnectionMode> = nil;

// Mirrors the Monaco/Markdown extraction pattern:
// - %LOCALAPPDATA%\Reportman\DataChannel\{x64|x86}\
// - File 'assets.version' marks the extracted set; bump
//   LibDataChannelAssetsVersion when the zip changes.
// - On version mismatch the folder is wiped and re-extracted from
//   the RT_RCDATA resource bound into the host binary.
// Returns the full path to datachannel.dll (empty if extraction
// fails for any reason - caller falls back to HTTP).
function EnsureDataChannelLibsExtracted: string;
var
  base, versionFile, dll: string;
  resName: string;
  res: TResourceStream;
  zip: TZipFile;
begin
  Result := '';
{$IFDEF WIN64}
  base := ObtainFolderLocalUserConfig('Reportman', 'DataChannel', 'x64');
  resName := 'LIBDATACHANNEL_X64_ZIP';
{$ELSE}
  base := ObtainFolderLocalUserConfig('Reportman', 'DataChannel', 'x86');
  resName := 'LIBDATACHANNEL_X86_ZIP';
{$ENDIF}
  versionFile := TPath.Combine(base, 'assets.version');
  dll := TPath.Combine(base, 'datachannel.dll');

  if TFile.Exists(dll) and TFile.Exists(versionFile) and
     SameText(Trim(TFile.ReadAllText(versionFile, TEncoding.UTF8)),
              LibDataChannelAssetsVersion) then
  begin
    Result := dll;
    Exit;
  end;

  // Wipe stale extraction, recreate, extract.
  try
    if TDirectory.Exists(base) then
      TDirectory.Delete(base, True);
    TDirectory.CreateDirectory(base);

    res := TResourceStream.Create(HInstance, resName, RT_RCDATA);
    try
      zip := TZipFile.Create;
      try
        zip.Open(res, zmRead);
        zip.ExtractAll(base);
      finally
        zip.Free;
      end;
    finally
      res.Free;
    end;

    TFile.WriteAllText(versionFile, LibDataChannelAssetsVersion,
                       TEncoding.UTF8);
  except
    // Any extraction failure means the host binary was built without
    // the embedded RC (linker missed the .res), or the LocalAppData
    // is read-only, etc. The caller treats an empty result as "no
    // direct channel available".
    Exit;
  end;

  if TFile.Exists(dll) then
    Result := dll;
end;

function MakeHubParams(AParams: TRpParamList): TRpDcHubParams;
var
  i, n: Integer;
begin
  if AParams = nil then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  n := 0;
  SetLength(Result, AParams.Count);
  for i := 0 to AParams.Count - 1 do
  begin
    if (AParams[i] = nil) or (Trim(AParams[i].Name) = '') then Continue;
    Result[n].Name := AParams[i].Name;
    Result[n].Value := AParams[i].Value;
    Inc(n);
  end;
  SetLength(Result, n);
end;

procedure EnsureLock;
begin
  if GLock = nil then
    GLock := TCriticalSection.Create;
  if GFallbackToApi = nil then
    GFallbackToApi := TDictionary<Int64, Boolean>.Create;
  if GApiKeyForDb = nil then
    GApiKeyForDb := TDictionary<Int64, string>.Create;
  if GLastTransport = nil then
    GLastTransport := TDictionary<Int64, TRpDcConnectionMode>.Create;
end;

procedure SetLastTransport(HubDatabaseId: Int64;
                            AMode: TRpDcConnectionMode);
begin
  EnsureLock;
  GLock.Acquire;
  try
    GLastTransport.AddOrSetValue(HubDatabaseId, AMode);
  finally
    GLock.Release;
  end;
end;

// Helper: trim SQL for log lines so a 5KB query doesn't flood the
// auth log. Keeps the first 80 chars, single-line.
function SqlHead(const ASql: string): string;
var
  i: Integer;
begin
  Result := ASql;
  for i := 1 to Length(Result) do
    if (Result[i] = #10) or (Result[i] = #13) or (Result[i] = #9) then
      Result[i] := ' ';
  if Length(Result) > 80 then
    Result := Copy(Result, 1, 77) + '...';
end;

procedure SafeAuthLog(const AMsg: string);
begin
  try
    TRpAuthManager.Instance.Log(AMsg);
  except
    // The auth log is best-effort - never let a logging failure
    // propagate into the data driver.
  end;
end;

// The handler installed into rpdatahttp.RpDatasetDirectTry. Returns
// True only when the dataset was fully populated by the direct path.
function TryDirectImpl(ADatabaseHttp: TObject;
                       const ASql: string;
                       AParams: TObject;
                       ATarget: TObject): Boolean;
var
  pool: TRpDcHubChannelPool;
  database: TRpDatabaseHttp;
  target: TClientDataSet;
  params: TRpParamList;
  client: TRpDcHubClient;
  hubDatabaseId: Int64;
  hubParams: TRpDcHubParams;
  mode: TRpDcConnectionMode;
  rowCount: Integer;
begin
  Result := False;
  GLock.Acquire;
  try
    pool := GPool;
  finally
    GLock.Release;
  end;
  if pool = nil then Exit;

  database := ADatabaseHttp as TRpDatabaseHttp;
  target := ATarget as TClientDataSet;
  if AParams <> nil then
    params := AParams as TRpParamList
  else
    params := nil;

  hubDatabaseId := database.HubDatabaseId;
  if hubDatabaseId <= 0 then Exit;

  SafeAuthLog(Format('DirectChannel: try db=%d sql="%s"',
                     [hubDatabaseId, SqlHead(ASql)]));

  client := pool.Acquire(hubDatabaseId, 15);
  if client = nil then
  begin
    // Could not even open a session: mark this DB as fallback so the
    // UI chip shows "API" rather than a stale Direct/HolePunch from
    // a previous query on the same id.
    GLock.Acquire;
    try
      GFallbackToApi.AddOrSetValue(hubDatabaseId, True);
    finally
      GLock.Release;
    end;
    SafeAuthLog(Format(
      'DirectChannel: db=%d transport=API (HTTP fallback) reason=acquire_failed',
      [hubDatabaseId]));
    Exit;
  end;
  try
    hubParams := MakeHubParams(params);
    try
      client.Execute(ASql, hubParams, hubDatabaseId, target, 600);
      Result := True;
      // Force a re-query of the selected candidate pair now that we
      // know data has flown end-to-end (ICE state callbacks may have
      // raced earlier and left FConnectionMode at rcmUnknown).
      mode := client.RefreshConnectionMode;
      SetLastTransport(hubDatabaseId, mode);
      GLock.Acquire;
      try
        GFallbackToApi.AddOrSetValue(hubDatabaseId, False);
      finally
        GLock.Release;
      end;
      if target <> nil then
        rowCount := target.RecordCount
      else
        rowCount := -1;
      SafeAuthLog(Format(
        'DirectChannel: db=%d transport=%s rows=%d',
        [hubDatabaseId, FormatTransportMode(mode, False), rowCount]));
    except
      on E: Exception do
      begin
        pool.MarkDead(client);
        GLock.Acquire;
        try
          GFallbackToApi.AddOrSetValue(hubDatabaseId, True);
        finally
          GLock.Release;
        end;
        SafeAuthLog(Format(
          'DirectChannel: db=%d transport=API (HTTP fallback) error=%s: %s',
          [hubDatabaseId, E.ClassName, E.Message]));
        raise;
      end;
    end;
  finally
    pool.Release(client);
  end;
end;

function GetApiKeyForDatabase(HubDatabaseId: Int64): string;
begin
  Result := '';
  EnsureLock;
  GLock.Acquire;
  try
    if GApiKeyForDb <> nil then
      GApiKeyForDb.TryGetValue(HubDatabaseId, Result);
  finally
    GLock.Release;
  end;
end;

procedure RegisterApiKeyForDatabase(HubDatabaseId: Int64; const AApiKey: string);
begin
  if HubDatabaseId <= 0 then Exit;
  EnsureLock;
  GLock.Acquire;
  try
    if AApiKey = '' then
      GApiKeyForDb.Remove(HubDatabaseId)
    else
      GApiKeyForDb.AddOrSetValue(HubDatabaseId, AApiKey);
  finally
    GLock.Release;
  end;
end;

function GetLastTransportForDatabase(
                              HubDatabaseId: Int64): TRpDcConnectionMode;
var
  pool: TRpDcHubChannelPool;
  cached: TRpDcConnectionMode;
  hasCached: Boolean;
begin
  Result := rcmUnknown;
  EnsureLock;
  GLock.Acquire;
  try
    hasCached := (GLastTransport <> nil) and
                 GLastTransport.TryGetValue(HubDatabaseId, cached);
    pool := GPool;
  finally
    GLock.Release;
  end;
  // Prefer the value we captured in TryDirectImpl: it was taken right
  // after Execute on the worker thread, with libdc's candidate pair
  // already stable. The pool's PeekConnectionMode is a fallback for
  // sessions that opened but never ran an Execute (e.g. only Open()).
  if hasCached and (cached <> rcmUnknown) then
    Exit(cached);
  if pool <> nil then
    Result := pool.PeekConnectionMode(HubDatabaseId);
  if (Result = rcmUnknown) and hasCached then
    Result := cached;
end;

function DidFallBackToApiForDatabase(HubDatabaseId: Int64): Boolean;
begin
  Result := False;
  EnsureLock;
  GLock.Acquire;
  try
    if GFallbackToApi <> nil then
      GFallbackToApi.TryGetValue(HubDatabaseId, Result);
  finally
    GLock.Release;
  end;
end;

function FormatTransportMode(AMode: TRpDcConnectionMode;
                             AFallbackApi: Boolean): string;
begin
  if AFallbackApi then
    Exit('API (HTTP fallback)');
  case AMode of
    rcmDirectP2P: Result := 'Direct P2P (Host)';
    rcmHolePunch: Result := 'Hole-Punch (NAT/STUN)';
    rcmRelay:     Result := 'Relay (TURN)';
  else
    Result := 'Unknown';
  end;
end;

procedure EnableDirectChannel(const AApiBaseUrl, ABearerToken: string;
                              const AInstallId: string;
                              AcceptInvalidCerts: Boolean);
var
  configChanged: Boolean;
  dllPath: string;
begin
  EnsureLock;
  GLock.Acquire;
  try
    configChanged := (GApiBaseUrl <> AApiBaseUrl) or
                     (GBearerToken <> ABearerToken) or
                     (GInstallId <> AInstallId) or
                     (GAcceptInvalidCerts <> AcceptInvalidCerts);
    if (GPool <> nil) and not configChanged then
      Exit;

    if GPool <> nil then
    begin
      // Re-enabling with new config: drop the old pool first so its
      // entries (negotiated under the old JWT) don't get reused.
      GPool.Free;
      GPool := nil;
    end;

    if not GLibraryLoaded then
    begin
      dllPath := EnsureDataChannelLibsExtracted;
      if dllPath = '' then
        raise Exception.Create(
          'EnableDirectChannel: could not extract datachannel.dll ' +
          '(missing RC resource or LocalAppData not writable)');
      if not RpDcInitialize(dllPath, RTC_LOG_WARNING) then
        raise Exception.Create(
          'EnableDirectChannel: RpDcInitialize failed - ' +
          RpDcLastInitError);
      GLibraryLoaded := True;
      GDllPath := dllPath;
    end;

    GApiBaseUrl := AApiBaseUrl;
    GBearerToken := ABearerToken;
    GInstallId := AInstallId;
    GAcceptInvalidCerts := AcceptInvalidCerts;

    GPool := TRpDcHubChannelPool.Create(
      function(HubDatabaseId: Int64; TimeoutSec: Integer): TRpDcHubClient
      var
        c: TRpDcHubClient;
        apiKey: string;
      begin
        // ApiKey path (Designer / printreptopdf / repwebexe):
        // GetApiKeyForDatabase returns the key registered by
        // DatabaseConnectHookImpl when the TRpDatabaseHttp connected.
        // Empty string is fine for the Bearer path (token in GBearerToken).
        apiKey := GetApiKeyForDatabase(HubDatabaseId);
        c := TRpDcHubClient.Create(GApiBaseUrl, GBearerToken,
                                   GInstallId, GAcceptInvalidCerts);
        try
          if c.Open(apiKey, HubDatabaseId, TimeoutSec) then
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
      end,
      60, 600);  // 60s idle, 10min max-life

    rpdatahttp.RpDatasetDirectTry := TryDirectImpl;
  finally
    GLock.Release;
  end;
end;

procedure DisableDirectChannel;
begin
  EnsureLock;
  GLock.Acquire;
  try
    rpdatahttp.RpDatasetDirectTry := nil;
    if GPool <> nil then
    begin
      GPool.Free;
      GPool := nil;
    end;
    GApiBaseUrl := '';
    GBearerToken := '';
    GInstallId := '';
  finally
    GLock.Release;
  end;
end;

function IsDirectChannelEnabled: Boolean;
begin
  EnsureLock;
  GLock.Acquire;
  try
    Result := GPool <> nil;
  finally
    GLock.Release;
  end;
end;

function EnableDirectChannelIfPossible(
                              const AApiBaseUrl, ABearerToken: string;
                              const AInstallId: string;
                              AcceptInvalidCerts: Boolean): Boolean;
begin
  Result := False;
  try
    EnableDirectChannel(AApiBaseUrl, ABearerToken, AInstallId,
                        AcceptInvalidCerts);
    Result := IsDirectChannelEnabled;
  except
    // Swallow - the caller (typically the data driver right after
    // a successful HTTP connection test) prefers a silent fall-back
    // to HTTP over a noisy popup. Log via AuthManager so the issue
    // surfaces in the diagnostics window without blocking the user.
    on E: Exception do
      try
        TRpAuthManager.Instance.Log(
          'EnableDirectChannelIfPossible failed: ' +
          E.ClassName + ': ' + E.Message);
      except
      end;
  end;
end;

function GetDataChannelDllPath: string;
begin
  EnsureLock;
  GLock.Acquire;
  try
    Result := GDllPath;
  finally
    GLock.Release;
  end;
end;

// Hook registered into rpdatahttp.RpDcDatabaseConnectHook during this
// unit's initialization. It reads the connection metadata off the
// TRpDatabaseHttp and bootstraps the global pool with the current
// token. Returns True iff EnableDirectChannelIfPossible succeeded.
function DatabaseConnectHookImpl(ADatabaseHttp: TObject): Boolean;
var
  database: TRpDatabaseHttp;
  apiBaseUrl: string;
  acceptInvalidCerts: Boolean;
begin
  database := ADatabaseHttp as TRpDatabaseHttp;
  apiBaseUrl := HUB_API_URL;
  // Remember the ApiKey for this database so the pool's opener can
  // authenticate the /api/data-session/start request via header
  // X-Reportman-ApiKey + JSON body agentApiKey. This is the only auth
  // the Designer / printreptopdf / repwebexe have - no user JWT.
  if database.HubDatabaseId > 0 then
    RegisterApiKeyForDatabase(database.HubDatabaseId, database.ApiKey);
  // Debug builds talk to a Kestrel/IIS dev API whose certificate may
  // not chain to a public CA - accept it the same way the regular
  // HTTP client does.
{$IFDEF DEBUG}
  acceptInvalidCerts := True;
{$ELSE}
  acceptInvalidCerts := False;
{$ENDIF}
  Result := EnableDirectChannelIfPossible(
              apiBaseUrl,
              database.Token,
              database.InstallId,
              acceptInvalidCerts);
end;

function DirectChannelStatusReport: string;
var
  p: TRpDcHubChannelPool;
begin
  EnsureLock;
  GLock.Acquire;
  try
    p := GPool;
  finally
    GLock.Release;
  end;
  if p = nil then
    Result := 'Direct channel: DISABLED'
  else
    Result := p.StatusReport;
end;

initialization
  EnsureLock;
  // Register ourselves with rpdatahttp. From the user's point of
  // view the only thing they need to do is add `rpdcintegration` to
  // their project's uses clause - everything else is automatic
  // (extraction on first use, hook installation, pool lifecycle).
  rpdatahttp.RpDcDatabaseConnectHook := DatabaseConnectHookImpl;

finalization
  rpdatahttp.RpDcDatabaseConnectHook := nil;
  DisableDirectChannel;
  if GLibraryLoaded then
  begin
    RpDcShutdown;
    GLibraryLoaded := False;
  end;
  if GFallbackToApi <> nil then
  begin
    GFallbackToApi.Free;
    GFallbackToApi := nil;
  end;
  if GApiKeyForDb <> nil then
  begin
    GApiKeyForDb.Free;
    GApiKeyForDb := nil;
  end;
  if GLastTransport <> nil then
  begin
    GLastTransport.Free;
    GLastTransport := nil;
  end;
  if GLock <> nil then
  begin
    GLock.Free;
    GLock := nil;
  end;

{$ENDIF MSWINDOWS}

end.
