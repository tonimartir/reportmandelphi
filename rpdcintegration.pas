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

uses
  System.SysUtils, System.Classes, System.SyncObjs,
  Data.DB, Datasnap.DBClient,
  rpparams,
  rpdatahttp,
  rplibdatachannel,
  rpfastserializer,
  rpdatadirect,
  rpdchub,
  rpdcpool;

// Spin up the global pool and install the TRpDatasetHttp hook. Idempotent:
// calling twice with the same arguments is a no-op; calling with new
// arguments (e.g., after the user logged in again) closes the old pool
// and starts a new one.
procedure EnableDirectChannel(const AApiBaseUrl, ABearerToken: string;
                              const AInstallId: string;
                              const ADllPath: string;
                              AcceptInvalidCerts: Boolean = False);

// Close the pool and clear the hook. After this TRpDatasetHttp.Open
// reverts to the HTTP path exclusively.
procedure DisableDirectChannel;

// Returns True if the hook is currently active.
function IsDirectChannelEnabled: Boolean;

// Pool diagnostics passthrough.
function DirectChannelStatusReport: string;

implementation

uses
  System.Variants;

var
  GLock: TCriticalSection = nil;
  GPool: TRpDcHubChannelPool = nil;
  GApiBaseUrl: string = '';
  GBearerToken: string = '';
  GInstallId: string = '';
  GAcceptInvalidCerts: Boolean = False;
  GLibraryLoaded: Boolean = False;

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

  client := pool.Acquire(hubDatabaseId, 15);
  if client = nil then Exit;
  try
    hubParams := MakeHubParams(params);
    try
      client.Execute(ASql, hubParams, hubDatabaseId, target, 600);
      Result := True;
    except
      on E: Exception do
      begin
        // Any transport-level failure here (channel died, peer
        // closed, etc.) marks the session dead so the next Acquire
        // negotiates a fresh one. The Open() caller still falls back
        // to HTTP for this single query via Result=False.
        pool.MarkDead(client);
        raise;
      end;
    end;
  finally
    pool.Release(client);
  end;
end;

procedure EnsureLock;
begin
  if GLock = nil then
    GLock := TCriticalSection.Create;
end;

procedure EnableDirectChannel(const AApiBaseUrl, ABearerToken: string;
                              const AInstallId: string;
                              const ADllPath: string;
                              AcceptInvalidCerts: Boolean);
var
  configChanged: Boolean;
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
      if not RpDcInitialize(ADllPath, RTC_LOG_WARNING) then
        raise Exception.Create(
          'EnableDirectChannel: RpDcInitialize failed - ' +
          RpDcLastInitError);
      GLibraryLoaded := True;
    end;

    GApiBaseUrl := AApiBaseUrl;
    GBearerToken := ABearerToken;
    GInstallId := AInstallId;
    GAcceptInvalidCerts := AcceptInvalidCerts;

    GPool := TRpDcHubChannelPool.Create(
      function(HubDatabaseId: Int64; TimeoutSec: Integer): TRpDcHubClient
      var
        c: TRpDcHubClient;
      begin
        c := TRpDcHubClient.Create(GApiBaseUrl, GBearerToken,
                                   GInstallId, GAcceptInvalidCerts);
        try
          // For the Bearer-authenticated path we leave AgentApiKey
          // empty and pass the hub database id - the controller
          // resolves the agentSecret server-side.
          if c.Open('', HubDatabaseId, TimeoutSec) then
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

finalization
  DisableDirectChannel;
  if GLibraryLoaded then
  begin
    RpDcShutdown;
    GLibraryLoaded := False;
  end;
  if GLock <> nil then
  begin
    GLock.Free;
    GLock := nil;
  end;

end.
