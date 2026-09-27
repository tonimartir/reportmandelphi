{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpaithreadslcl                                  }
{       Worker threads and UI marshalling of the AI     }
{       assistants (FPC has no anonymous methods)       }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpaithreadslcl;

{ The VCL AI units run their network calls in TThread.CreateAnonymousThread
  closures and hand the results to the UI with PostMessage(Handle, WM_USER+n,
  payload). FPC 3.2.2 has no anonymous methods and the LCL has no window
  handles on every widgetset, so the LCL ports use:

  - TRpAsyncMessage: the payload (the VCL TRpQueued*Payload classes derive
    from it). The mailbox owns it and frees it after the handler runs.
  - TRpAsyncMailbox: created by a form or frame with the handler method
    (the VCL WM_USER message handler). Worker threads Post messages from any
    thread; they are delivered in the main thread with
    Application.QueueAsyncCall. The owner calls Detach in its destructor:
    later messages are dropped, so a worker never touches a freed form. The
    mailbox is reference counted (interface) and shared by the owner, its
    workers and the queued delivery.
  - TRpAsyncWorker: a TThread (FreeOnTerminate) with the mailbox; the body
    of the VCL closure goes to Run, the captured variables to fields.
    SyncCall runs a method in the main thread and waits (TThread.Synchronize).
  - IRpAsyncCancel: cancel flag shared with a worker (streaming requests).
  - RpAuthEvents: one listener registered with TRpAuthManager for the whole
    process. The manager queues auth events with TThread.Queue (a form
    destroyed meanwhile would receive them) and calls log listeners in the
    worker thread that logs; the hub outlives every form and forwards both
    in the main thread to the forms registered at that moment. }

{$mode delphi}

interface

uses
  SysUtils, Classes, Forms, Generics.Collections, rpauthmanager;

type
  // Data from a worker thread to the UI; the mailbox frees it
  TRpAsyncMessage = class(TObject)
  end;

  TRpAsyncMessageEvent = procedure(AMessage: TRpAsyncMessage) of object;

  IRpAsyncMailbox = interface
    ['{5B7C4C3A-6F0E-4E47-9A61-2D8B6B0E7A31}']
    // Any thread; the message is freed by the mailbox in every case
    procedure Post(AMessage: TRpAsyncMessage);
    function IsDetached: Boolean;
  end;

  TRpAsyncMailbox = class(TInterfacedObject, IRpAsyncMailbox)
  private
    FLock: TRTLCriticalSection;
    FHandler: TRpAsyncMessageEvent;
    FItems: TList<TRpAsyncMessage>;
    FScheduled: Boolean;
    FDetached: Boolean;
    procedure Deliver(Data: PtrInt);
    procedure DeliverPending;
  public
    constructor Create(AHandler: TRpAsyncMessageEvent);
    destructor Destroy; override;
    procedure Post(AMessage: TRpAsyncMessage);
    function IsDetached: Boolean;
    // Main thread, from the owner destructor: pending and later messages
    // are freed without calling the handler
    procedure Detach;
    // Main thread: delivers the pending messages now
    procedure Flush;
  end;

  IRpAsyncCancel = interface
    ['{0E9B7B8E-2E55-4B5E-8F3C-6A1D2C9B4E77}']
    procedure Cancel;
    function Cancelled: Boolean;
  end;

  TRpAsyncCancel = class(TInterfacedObject, IRpAsyncCancel)
  private
    FCancelled: LongInt;
  public
    procedure Cancel;
    function Cancelled: Boolean;
  end;

  // Base of the worker threads (the VCL anonymous threads)
  TRpAsyncWorker = class(TThread)
  private
    FMailbox: IRpAsyncMailbox;
    FErrorMessage: string;
    procedure QueueBarrier;
  protected
    procedure Execute; override;
    // The thread body; exceptions are caught and passed to HandleError
    procedure Run; virtual; abstract;
    procedure HandleError(E: Exception); virtual;
    procedure Post(AMessage: TRpAsyncMessage);
    // True when the owner of the mailbox was destroyed
    function OwnerGone: Boolean;
    // Runs AMethod in the main thread and waits (TThread.Synchronize). The
    // method must check OwnerGone before touching the owner.
    procedure SyncCall(AMethod: TThreadMethod);
  public
    // Created suspended with FreeOnTerminate; call Start
    constructor Create(const AMailbox: IRpAsyncMailbox);
    destructor Destroy; override;
    property Mailbox: IRpAsyncMailbox read FMailbox;
    property ErrorMessage: string read FErrorMessage;
  end;

  TRpAuthEventHub = class
  private
    FAuthListeners: TList<TRpAuthEvent>;
    FLogListeners: TList<TRpAuthLog>;
    FLock: TRTLCriticalSection;
    FPendingLog: TStringList;
    FLogScheduled: Boolean;
    FRegistered: Boolean;
    procedure EnsureRegistered;
    procedure ManagerAuthChanged(ASuccess: Boolean);
    procedure ManagerLog(const AMsg: string);
    procedure DeliverLog(Data: PtrInt);
    procedure DispatchLog(const AMsg: string);
  public
    constructor Create;
    destructor Destroy; override;
    // Main thread only
    procedure AddAuthListener(AListener: TRpAuthEvent);
    procedure RemoveAuthListener(AListener: TRpAuthEvent);
    procedure AddLogListener(AListener: TRpAuthLog);
    procedure RemoveLogListener(AListener: TRpAuthLog);
    // Delivers the log lines queued by worker threads now (main thread)
    procedure FlushLog;
  end;

// Process wide hub of the TRpAuthManager events for the LCL forms
function RpAuthEvents: TRpAuthEventHub;

// Worker threads still running (tests wait for 0 before checking leaks)
function RpAsyncActiveWorkers: Integer;
// Processes messages until no worker runs and nothing is queued, or the
// timeout expires. Returns True when everything finished.
function RpAsyncWaitIdle(ATimeoutMs: Cardinal): Boolean;

function RpIsMainThread: Boolean;

implementation

var
  GActiveWorkers: LongInt = 0;
  GPendingDeliveries: LongInt = 0;
  GAuthEvents: TRpAuthEventHub = nil;
  GFinalized: Boolean = False;

function RpIsMainThread: Boolean;
begin
  Result := GetCurrentThreadId = MainThreadID;
end;

function RpAsyncActiveWorkers: Integer;
begin
  Result := InterlockedExchangeAdd(GActiveWorkers, 0);
end;

function RpAsyncWaitIdle(ATimeoutMs: Cardinal): Boolean;
var
  LStart: QWord;
begin
  LStart := GetTickCount64;
  repeat
    Application.ProcessMessages;
    CheckSynchronize(0);
    if (RpAsyncActiveWorkers = 0) and
      (InterlockedExchangeAdd(GPendingDeliveries, 0) = 0) then
    begin
      Application.ProcessMessages;
      if GAuthEvents <> nil then
        GAuthEvents.FlushLog;
      Exit(True);
    end;
    Sleep(5);
  until GetTickCount64 - LStart > ATimeoutMs;
  Result := False;
end;

{ TRpAsyncMailbox }

constructor TRpAsyncMailbox.Create(AHandler: TRpAsyncMessageEvent);
begin
  inherited Create;
  InitCriticalSection(FLock);
  FHandler := AHandler;
  FItems := TList<TRpAsyncMessage>.Create;
end;

destructor TRpAsyncMailbox.Destroy;
var
  LItem: TRpAsyncMessage;
begin
  for LItem in FItems do
    LItem.Free;
  FItems.Free;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

procedure TRpAsyncMailbox.Post(AMessage: TRpAsyncMessage);
var
  LSchedule: Boolean;
begin
  if AMessage = nil then
    Exit;
  LSchedule := False;
  EnterCriticalSection(FLock);
  try
    if FDetached or GFinalized then
    begin
      AMessage.Free;
      Exit;
    end;
    FItems.Add(AMessage);
    if not FScheduled then
    begin
      FScheduled := True;
      LSchedule := True;
      // The queued call keeps the mailbox alive until it runs
      _AddRef;
      InterlockedIncrement(GPendingDeliveries);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  if LSchedule then
  begin
    try
      Application.QueueAsyncCall(Deliver, 0);
    except
      // Application shutting down: nobody will read the messages
      EnterCriticalSection(FLock);
      try
        FScheduled := False;
      finally
        LeaveCriticalSection(FLock);
      end;
      InterlockedDecrement(GPendingDeliveries);
      _Release;
    end;
  end;
end;

procedure TRpAsyncMailbox.DeliverPending;
var
  LBatch: TList<TRpAsyncMessage>;
  I: Integer;
begin
  LBatch := TList<TRpAsyncMessage>.Create;
  try
    EnterCriticalSection(FLock);
    try
      LBatch.AddRange(FItems);
      FItems.Clear;
    finally
      LeaveCriticalSection(FLock);
    end;
    for I := 0 to LBatch.Count - 1 do
    begin
      try
        // The handler may destroy the owner (Detach): check every time
        if (not FDetached) and Assigned(FHandler) then
        begin
          try
            FHandler(LBatch[I]);
          except
            Application.HandleException(Self);
          end;
        end;
      finally
        LBatch[I].Free;
        LBatch[I] := nil;
      end;
    end;
  finally
    LBatch.Free;
  end;
end;

procedure TRpAsyncMailbox.Deliver(Data: PtrInt);
begin
  try
    EnterCriticalSection(FLock);
    try
      FScheduled := False;
    finally
      LeaveCriticalSection(FLock);
    end;
    DeliverPending;
  finally
    InterlockedDecrement(GPendingDeliveries);
    // May free the mailbox: nothing after this
    _Release;
  end;
end;

procedure TRpAsyncMailbox.Flush;
begin
  _AddRef;
  try
    DeliverPending;
  finally
    _Release;
  end;
end;

function TRpAsyncMailbox.IsDetached: Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Result := FDetached;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TRpAsyncMailbox.Detach;
var
  LItem: TRpAsyncMessage;
begin
  EnterCriticalSection(FLock);
  try
    FDetached := True;
    FHandler := nil;
    for LItem in FItems do
      LItem.Free;
    FItems.Clear;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

{ TRpAsyncCancel }

procedure TRpAsyncCancel.Cancel;
begin
  InterlockedExchange(FCancelled, 1);
end;

function TRpAsyncCancel.Cancelled: Boolean;
begin
  Result := InterlockedExchangeAdd(FCancelled, 0) <> 0;
end;

{ TRpAsyncWorker }

constructor TRpAsyncWorker.Create(const AMailbox: IRpAsyncMailbox);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FMailbox := AMailbox;
  InterlockedIncrement(GActiveWorkers);
end;

destructor TRpAsyncWorker.Destroy;
begin
  FMailbox := nil;
  inherited Destroy;
  InterlockedDecrement(GActiveWorkers);
end;

procedure TRpAsyncWorker.Execute;
begin
  try
    Run;
  except
    on E: Exception do
    begin
      FErrorMessage := E.Message;
      try
        HandleError(E);
      except
        // Never let an exception escape a worker thread
      end;
    end;
  end;
  // FPC 3.2.2: TThread.Destroy removes the events this thread queued with
  // TThread.Queue that the main thread has not run yet (RemoveQueuedEvents
  // compares the ThreadID, also for TThread.Queue(nil, ...)), and leaks
  // them. TRpAuthManager queues its auth events that way (login, logout on
  // a 401, CheckStatus): wait until the main thread has run them. The queue
  // is FIFO, so the synchronized call runs after them.
  try
    Synchronize(QueueBarrier);
  except
  end;
end;

procedure TRpAsyncWorker.QueueBarrier;
begin
  // Nothing: reaching it means the earlier queued events already ran
end;

procedure TRpAsyncWorker.HandleError(E: Exception);
begin
  // Subclasses post an error message to the UI
end;

procedure TRpAsyncWorker.Post(AMessage: TRpAsyncMessage);
begin
  if FMailbox <> nil then
    FMailbox.Post(AMessage)
  else
    AMessage.Free;
end;

function TRpAsyncWorker.OwnerGone: Boolean;
begin
  Result := (FMailbox = nil) or FMailbox.IsDetached;
end;

procedure TRpAsyncWorker.SyncCall(AMethod: TThreadMethod);
begin
  if OwnerGone then
    Exit;
  Synchronize(AMethod);
end;

{ TRpAuthEventHub }

constructor TRpAuthEventHub.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FAuthListeners := TList<TRpAuthEvent>.Create;
  FLogListeners := TList<TRpAuthLog>.Create;
  FPendingLog := TStringList.Create;
end;

destructor TRpAuthEventHub.Destroy;
begin
  if FRegistered then
  begin
    TRpAuthManager.Instance.UnregisterAuthListener(ManagerAuthChanged);
    TRpAuthManager.Instance.UnregisterLogListener(ManagerLog);
    FRegistered := False;
  end;
  if Application <> nil then
    Application.RemoveAsyncCalls(Self);
  FPendingLog.Free;
  FLogListeners.Free;
  FAuthListeners.Free;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

procedure TRpAuthEventHub.EnsureRegistered;
begin
  if FRegistered then
    Exit;
  TRpAuthManager.Instance.RegisterAuthListener(ManagerAuthChanged);
  TRpAuthManager.Instance.RegisterLogListener(ManagerLog);
  FRegistered := True;
end;

function SameAuthEvent(const A, B: TRpAuthEvent): Boolean;
begin
  Result := (TMethod(A).Code = TMethod(B).Code) and (TMethod(A).Data = TMethod(B).Data);
end;

function SameAuthLog(const A, B: TRpAuthLog): Boolean;
begin
  Result := (TMethod(A).Code = TMethod(B).Code) and (TMethod(A).Data = TMethod(B).Data);
end;

procedure TRpAuthEventHub.AddAuthListener(AListener: TRpAuthEvent);
var
  I: Integer;
begin
  EnsureRegistered;
  for I := 0 to FAuthListeners.Count - 1 do
    if SameAuthEvent(FAuthListeners[I], AListener) then
      Exit;
  FAuthListeners.Add(AListener);
end;

procedure TRpAuthEventHub.RemoveAuthListener(AListener: TRpAuthEvent);
var
  I: Integer;
begin
  for I := FAuthListeners.Count - 1 downto 0 do
    if SameAuthEvent(FAuthListeners[I], AListener) then
      FAuthListeners.Delete(I);
end;

procedure TRpAuthEventHub.AddLogListener(AListener: TRpAuthLog);
var
  I: Integer;
begin
  EnsureRegistered;
  for I := 0 to FLogListeners.Count - 1 do
    if SameAuthLog(FLogListeners[I], AListener) then
      Exit;
  FLogListeners.Add(AListener);
end;

procedure TRpAuthEventHub.RemoveLogListener(AListener: TRpAuthLog);
var
  I: Integer;
begin
  for I := FLogListeners.Count - 1 downto 0 do
    if SameAuthLog(FLogListeners[I], AListener) then
      FLogListeners.Delete(I);
end;

procedure TRpAuthEventHub.ManagerAuthChanged(ASuccess: Boolean);
var
  LListeners: TArray<TRpAuthEvent>;
  LListener: TRpAuthEvent;
  I: Integer;
  LStillThere: Boolean;
begin
  // TRpAuthManager calls this in the main thread (directly or queued)
  LListeners := FAuthListeners.ToArray;
  for LListener in LListeners do
  begin
    // A listener may remove others (a form closed by the event)
    LStillThere := False;
    for I := 0 to FAuthListeners.Count - 1 do
      if SameAuthEvent(FAuthListeners[I], LListener) then
      begin
        LStillThere := True;
        Break;
      end;
    if LStillThere then
      LListener(ASuccess);
  end;
end;

procedure TRpAuthEventHub.DispatchLog(const AMsg: string);
var
  LListeners: TArray<TRpAuthLog>;
  LListener: TRpAuthLog;
  I: Integer;
  LStillThere: Boolean;
begin
  LListeners := FLogListeners.ToArray;
  for LListener in LListeners do
  begin
    LStillThere := False;
    for I := 0 to FLogListeners.Count - 1 do
      if SameAuthLog(FLogListeners[I], LListener) then
      begin
        LStillThere := True;
        Break;
      end;
    if LStillThere then
      LListener(AMsg);
  end;
end;

procedure TRpAuthEventHub.ManagerLog(const AMsg: string);
var
  LSchedule: Boolean;
begin
  if RpIsMainThread then
  begin
    // Keep the order with the lines queued before
    FlushLog;
    DispatchLog(AMsg);
    Exit;
  end;
  LSchedule := False;
  EnterCriticalSection(FLock);
  try
    if GFinalized then
      Exit;
    FPendingLog.Add(AMsg);
    if not FLogScheduled then
    begin
      FLogScheduled := True;
      LSchedule := True;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  if LSchedule then
  begin
    try
      Application.QueueAsyncCall(DeliverLog, 0);
    except
      EnterCriticalSection(FLock);
      try
        FLogScheduled := False;
        FPendingLog.Clear;
      finally
        LeaveCriticalSection(FLock);
      end;
    end;
  end;
end;

procedure TRpAuthEventHub.DeliverLog(Data: PtrInt);
begin
  EnterCriticalSection(FLock);
  try
    FLogScheduled := False;
  finally
    LeaveCriticalSection(FLock);
  end;
  FlushLog;
end;

procedure TRpAuthEventHub.FlushLog;
var
  LLines: TStringList;
  I: Integer;
begin
  LLines := TStringList.Create;
  try
    EnterCriticalSection(FLock);
    try
      LLines.Assign(FPendingLog);
      FPendingLog.Clear;
    finally
      LeaveCriticalSection(FLock);
    end;
    for I := 0 to LLines.Count - 1 do
      DispatchLog(LLines[I]);
  finally
    LLines.Free;
  end;
end;

function RpAuthEvents: TRpAuthEventHub;
begin
  if GAuthEvents = nil then
    GAuthEvents := TRpAuthEventHub.Create;
  Result := GAuthEvents;
end;

initialization

finalization
  GFinalized := True;
  FreeAndNil(GAuthEvents);
end.
