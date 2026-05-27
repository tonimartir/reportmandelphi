// =====================================================================
//   Report Manager - rpdcpool
//
//   Per-database session cache for TRpDcHubClient. The first SQL on a
//   given hubDatabaseId pays the ~1-3s WebRTC negotiation; subsequent
//   queries on the same database reuse the warm channel for ~50ms
//   round-trips.
//
//   Lifecycle policies mirror the .NET WebRtcChannelPool:
//     - Idle timeout (default 60s): evict if no Execute for that long.
//     - Max lifetime (default 10 min): rotate regardless of activity.
//     - Dead detection: any failed query marks the session dead and
//       the next Acquire opens a fresh one.
//
//   This first version does NOT run a background keepalive timer.
//   On routers with aggressive NAT TTLs the channel may go silent
//   before the idle eviction kicks in; that surfaces as an Execute
//   failure on the *next* query, the pool evicts it, and a fresh
//   negotiation succeeds. The user sees one slow query, not a hang.
//
//   Copyright (c) 2026 Toni Martir
//   toni@reportman.es
// =====================================================================

unit rpdcpool;

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
  rpdchub;

type
  TRpDcPoolEntry = class
  public
    Client: TRpDcHubClient;
    HubDatabaseId: Int64;
    LastUsedTick: Cardinal;
    OpenedTick: Cardinal;
    Busy: Boolean;
    Dead: Boolean;
    destructor Destroy; override;
  end;

  ERpDcPool = class(Exception);

  // Callback the pool uses to open a brand-new session when the cache
  // misses. Lets the caller (a TRpDatasetHttp helper, the loopback
  // test, etc.) decide which target to negotiate against without the
  // pool itself needing HttpClient/JWT/Hub plumbing knowledge.
  // Implementations must return a fully-open TRpDcHubClient or nil.
  TRpDcHubOpenerFunc = reference to function(HubDatabaseId: Int64;
                                              TimeoutSec: Integer): TRpDcHubClient;

  TRpDcHubChannelPool = class
  private
    FLock: TCriticalSection;
    FEntries: TObjectList<TRpDcPoolEntry>;
    FOpener: TRpDcHubOpenerFunc;
    FIdleTimeoutMs: Cardinal;
    FMaxLifetimeMs: Cardinal;

    function FindAliveLocked(HubDatabaseId: Int64): TRpDcPoolEntry;
    function FindLocked(Client: TRpDcHubClient): TRpDcPoolEntry;
    procedure DropLocked(Entry: TRpDcPoolEntry);
  public
    constructor Create(const AOpener: TRpDcHubOpenerFunc;
                       IdleTimeoutSec: Integer = 60;
                       MaxLifetimeSec: Integer = 600);
    destructor Destroy; override;

    // Drop entries that are idle past IdleTimeout, past MaxLifetime,
    // or already dead. Safe to call anytime. Acquire calls this
    // implicitly before consulting the cache.
    procedure SweepStale;

    // Get a usable client for this database. Either returns a cached
    // (alive, non-busy) session marked Busy, or negotiates a new one
    // via the opener callback. Returns nil if negotiation failed; the
    // caller falls back to HTTP. The Pascal style is to release via
    // Release() in a try/finally.
    function Acquire(HubDatabaseId: Int64;
                     TimeoutSec: Integer = 15): TRpDcHubClient;

    // Mark the session idle again (NOT closed). Call from a finally
    // even if Execute threw - the SweepStale at next Acquire will
    // evict any session whose underlying state is bad.
    procedure Release(Client: TRpDcHubClient);

    // Mark the session as definitively unusable. The next Acquire for
    // the same database starts fresh. Call this when Execute throws a
    // transport-level error (signaling lost, DC closed, etc.).
    procedure MarkDead(Client: TRpDcHubClient);

    // Close and free every session in the pool. Safe to call from
    // Destroy.
    procedure CloseAll;

    // Diagnostics.
    function Count: Integer;
    function StatusReport: string;
  end;

implementation

destructor TRpDcPoolEntry.Destroy;
begin
  if Client <> nil then
  begin
    try
      Client.Close;
    except
    end;
    Client.Free;
  end;
  inherited;
end;

constructor TRpDcHubChannelPool.Create(const AOpener: TRpDcHubOpenerFunc;
                                        IdleTimeoutSec: Integer;
                                        MaxLifetimeSec: Integer);
begin
  inherited Create;
  if not Assigned(AOpener) then
    raise ERpDcPool.Create('Opener callback is required');
  FOpener := AOpener;
  FIdleTimeoutMs := Cardinal(IdleTimeoutSec) * 1000;
  FMaxLifetimeMs := Cardinal(MaxLifetimeSec) * 1000;
  FLock := TCriticalSection.Create;
  FEntries := TObjectList<TRpDcPoolEntry>.Create(True);
end;

destructor TRpDcHubChannelPool.Destroy;
begin
  CloseAll;
  FEntries.Free;
  FLock.Free;
  inherited;
end;

function TRpDcHubChannelPool.FindAliveLocked(HubDatabaseId: Int64): TRpDcPoolEntry;
var
  e: TRpDcPoolEntry;
begin
  for e in FEntries do
    if (e.HubDatabaseId = HubDatabaseId) and (not e.Dead) and (not e.Busy) then
      Exit(e);
  Result := nil;
end;

function TRpDcHubChannelPool.FindLocked(Client: TRpDcHubClient): TRpDcPoolEntry;
var
  e: TRpDcPoolEntry;
begin
  for e in FEntries do
    if e.Client = Client then Exit(e);
  Result := nil;
end;

procedure TRpDcHubChannelPool.DropLocked(Entry: TRpDcPoolEntry);
begin
  FEntries.Remove(Entry);   // OwnsObjects=True -> Destroy is called.
end;

procedure TRpDcHubChannelPool.SweepStale;
var
  now: Cardinal;
  i: Integer;
  e: TRpDcPoolEntry;
  evictFor: string;
begin
  now := GetTickCount;
  FLock.Acquire;
  try
    for i := FEntries.Count - 1 downto 0 do
    begin
      e := FEntries[i];
      if e.Busy then Continue;
      evictFor := '';
      if e.Dead then
        evictFor := 'dead'
      else if (FMaxLifetimeMs > 0) and (now - e.OpenedTick > FMaxLifetimeMs) then
        evictFor := 'maxlife'
      else if (FIdleTimeoutMs > 0) and (now - e.LastUsedTick > FIdleTimeoutMs) then
        evictFor := 'idle';
      if evictFor <> '' then
        DropLocked(e);
    end;
  finally
    FLock.Release;
  end;
end;

function TRpDcHubChannelPool.Acquire(HubDatabaseId: Int64;
                                      TimeoutSec: Integer): TRpDcHubClient;
var
  entry: TRpDcPoolEntry;
  newClient: TRpDcHubClient;
  now: Cardinal;
begin
  SweepStale;

  FLock.Acquire;
  try
    entry := FindAliveLocked(HubDatabaseId);
    if entry <> nil then
    begin
      entry.Busy := True;
      entry.LastUsedTick := GetTickCount;
      Exit(entry.Client);
    end;
  finally
    FLock.Release;
  end;

  // Slow path: negotiate a new session OUTSIDE the lock so other
  // databases can be acquired concurrently. We accept the cost of a
  // possible double-open if two threads race here for the same DB;
  // the loser's client will be dropped or pooled separately.
  try
    newClient := FOpener(HubDatabaseId, TimeoutSec);
  except
    newClient := nil;
  end;
  if newClient = nil then Exit(nil);

  now := GetTickCount;
  FLock.Acquire;
  try
    entry := TRpDcPoolEntry.Create;
    entry.Client := newClient;
    entry.HubDatabaseId := HubDatabaseId;
    entry.LastUsedTick := now;
    entry.OpenedTick := now;
    entry.Busy := True;
    entry.Dead := False;
    FEntries.Add(entry);
    Result := newClient;
  finally
    FLock.Release;
  end;
end;

procedure TRpDcHubChannelPool.Release(Client: TRpDcHubClient);
var
  entry: TRpDcPoolEntry;
begin
  if Client = nil then Exit;
  FLock.Acquire;
  try
    entry := FindLocked(Client);
    if entry = nil then Exit;
    entry.Busy := False;
    entry.LastUsedTick := GetTickCount;
  finally
    FLock.Release;
  end;
end;

procedure TRpDcHubChannelPool.MarkDead(Client: TRpDcHubClient);
var
  entry: TRpDcPoolEntry;
begin
  if Client = nil then Exit;
  FLock.Acquire;
  try
    entry := FindLocked(Client);
    if entry = nil then Exit;
    entry.Dead := True;
    entry.Busy := False;  // unblock SweepStale eviction
  finally
    FLock.Release;
  end;
end;

procedure TRpDcHubChannelPool.CloseAll;
begin
  FLock.Acquire;
  try
    FEntries.Clear;  // OwnsObjects=True -> all entries destroyed.
  finally
    FLock.Release;
  end;
end;

function TRpDcHubChannelPool.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FEntries.Count;
  finally
    FLock.Release;
  end;
end;

function TRpDcHubChannelPool.StatusReport: string;
var
  e: TRpDcPoolEntry;
  now: Cardinal;
  sb: TStringBuilder;
begin
  now := GetTickCount;
  sb := TStringBuilder.Create;
  try
    FLock.Acquire;
    try
      sb.Append('pool: ').Append(FEntries.Count).Append(' entries');
      sb.AppendLine;
      for e in FEntries do
      begin
        sb.AppendFormat('  db=%d  busy=%s  dead=%s  idle=%dms  age=%dms',
          [e.HubDatabaseId,
           BoolToStr(e.Busy, True),
           BoolToStr(e.Dead, True),
           now - e.LastUsedTick,
           now - e.OpenedTick]);
        sb.AppendLine;
      end;
    finally
      FLock.Release;
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

end.
