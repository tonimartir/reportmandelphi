{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpformcenterlcl                                 }
{       The dialogs open centered on the form they are  }
{       opened from                                     }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rpformcenterlcl;

{ The Report Manager forms (TFRp*) ask for poScreenCenter or
  poMainFormCenter. The LCL centers the first on a whole monitor and the
  second on the main form, so with two or three monitors a dialog could
  open on another monitor than the designer, and a dialog opened from
  another dialog did not open over it. This unit centers them on the form
  that is active when they are shown (the one they are opened from), or
  on the main form, kept inside the work area of that monitor.

  Many of them are AutoSize forms, whose size is known only while they are
  shown (no resize event comes before), so a form is placed when it
  becomes visible, which takes it to the right monitor, and centered again
  with its final size when it is activated, before it is painted, or at
  the latest by a queued call.

  It works from a Screen handler, so no form has to call it; it is linked
  by rpgraphutilslcl. Only TFRp* forms are moved: the forms of an
  application that shows reports keep their own position.

  The dialog boxes of Windows (print, printer setup, the Data Link of ADO)
  are not forms: Windows places them by their owner, and the Data Link
  centers itself inside the primary monitor, which may be another one.
  RpBeginCenterDialog before showing one centers it on the form. }

{$mode delphi}

interface

uses
  Forms;

// The form centered on AParent, inside the work area of its monitor
procedure RpCenterFormOn(AForm, AParent: TCustomForm);
// The next dialog box of Windows that this thread shows opens centered on
// AParent (nil: the active form, else the main form); RpEndCenterDialog
// after it, also when none was shown. Nothing on other systems.
procedure RpBeginCenterDialog(AParent: TCustomForm = nil);
procedure RpEndCenterDialog;

implementation

uses
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
  Classes, Types, Math, Controls;

type
  TRpFormCenter = class
  private
    // Forms whose Position this unit changed to poDesigned: they are
    // centered again every time they are shown
    FCentered: TList;
    // Forms being shown and the form each one is centered on
    FPending, FParents: TList;
    procedure DropPending(AForm: TCustomForm);
    procedure CenterPending(AForm: TCustomForm);
    procedure EndPending(Data: PtrInt);
  public
    constructor Create;
    destructor Destroy; override;
    procedure FormVisibleChanged(Sender: TObject; Form: TCustomForm);
    procedure ActiveFormChanged(Sender: TObject; Form: TCustomForm);
    procedure RemoveForm(Sender: TObject; Form: TCustomForm);
  end;

var
  FormCenter: TRpFormCenter;

procedure RpCenterFormOn(AForm, AParent: TCustomForm);
var
  R, Area: TRect;
  X, Y: Integer;
begin
  R := AParent.BoundsRect;
  X := R.Left + (R.Right - R.Left - AForm.Width) div 2;
  Y := R.Top + (R.Bottom - R.Top - AForm.Height) div 2;
  Area := Screen.MonitorFromRect(R).WorkareaRect;
  X := Max(Area.Left, Min(Area.Right - AForm.Width, X));
  Y := Max(Area.Top, Min(Area.Bottom - AForm.Height, Y));
  AForm.SetBounds(X, Y, AForm.Width, AForm.Height);
end;

{$IFDEF MSWINDOWS}
var
  DialogHook: HHOOK = 0;
  // The window to center on, until the first dialog box is activated
  DialogParent: HWND = 0;
  // That dialog box, the window it is centered on and its window procedure
  // before this unit: until it is shown, its own moves are corrected
  DialogWnd: HWND = 0;
  DialogOwner: HWND = 0;
  DialogOldProc: LONG_PTR = 0;

// Where a window of AWidth x AHeight goes, centered on AParentWnd
function CenteredOn(AParentWnd: HWND; AWidth, AHeight: Integer): TPoint;
var
  P, Area: TRect;
begin
  GetWindowRect(AParentWnd, P);
  Result.X := P.Left + (P.Right - P.Left - AWidth) div 2;
  Result.Y := P.Top + (P.Bottom - P.Top - AHeight) div 2;
  Area := Screen.MonitorFromRect(P).WorkareaRect;
  Result.X := Max(Area.Left, Min(Area.Right - AWidth, Result.X));
  Result.Y := Max(Area.Top, Min(Area.Bottom - AHeight, Result.Y));
end;

function DialogWndProc(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; forward;

procedure UnsubclassDialog;
begin
  if (DialogWnd <> 0) and IsWindow(DialogWnd) and
    (PtrUInt(GetWindowLongPtrW(DialogWnd, GWLP_WNDPROC)) = PtrUInt(@DialogWndProc)) then
    SetWindowLongPtrW(DialogWnd, GWLP_WNDPROC, DialogOldProc);
  DialogWnd := 0;
  DialogOwner := 0;
  DialogOldProc := 0;
end;

// Some dialog boxes center themselves after they are activated, inside the
// work area of the primary monitor (the Data Link of ADO): until the dialog
// is shown, every move goes to the center of the form instead
function DialogWndProc(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  wp: PWindowPos;
  R: TRect;
  Pt: TPoint;
  OldProc: LONG_PTR;
begin
  OldProc := DialogOldProc;
  if (hWnd = DialogWnd) and (Msg = WM_WINDOWPOSCHANGING) and IsWindow(DialogOwner) then
  begin
    wp := PWindowPos(lParam);
    if (wp^.flags and SWP_NOMOVE) = 0 then
    begin
      if (wp^.flags and SWP_NOSIZE) = 0 then
        Pt := CenteredOn(DialogOwner, wp^.cx, wp^.cy)
      else
      begin
        GetWindowRect(hWnd, R);
        Pt := CenteredOn(DialogOwner, R.Right - R.Left, R.Bottom - R.Top);
      end;
      wp^.x := Pt.X;
      wp^.y := Pt.Y;
    end;
    if (wp^.flags and SWP_SHOWWINDOW) <> 0 then
      UnsubclassDialog;
  end
  else
  if (hWnd = DialogWnd) and (Msg = WM_NCDESTROY) then
    UnsubclassDialog;
  Result := CallWindowProcW(WNDPROC(OldProc), hWnd, Msg, wParam, lParam);
end;

function DialogHookProc(nCode: LongInt; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  AClassName: array[0..15] of AnsiChar;
  R: TRect;
  Pt: TPoint;
begin
  // HCBT_ACTIVATE comes with the final size, before the dialog is painted
  if (nCode = HCBT_ACTIVATE) and (DialogParent <> 0) and IsWindow(DialogParent) and
    (GetClassNameA(HWND(wParam), AClassName, SizeOf(AClassName)) > 0) and
    (AnsiString(AClassName) = '#32770') then
  begin
    GetWindowRect(HWND(wParam), R);
    Pt := CenteredOn(DialogParent, R.Right - R.Left, R.Bottom - R.Top);
    SetWindowPos(HWND(wParam), 0, Pt.X, Pt.Y, 0, 0,
      SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE);
    if not IsWindowVisible(HWND(wParam)) then
    begin
      DialogWnd := HWND(wParam);
      DialogOwner := DialogParent;
      DialogOldProc := SetWindowLongPtrW(DialogWnd, GWLP_WNDPROC,
        LONG_PTR(@DialogWndProc));
    end;
    // Only the first one: the dialogs it opens place themselves on it
    DialogParent := 0;
  end;
  Result := CallNextHookEx(DialogHook, nCode, wParam, lParam);
end;
{$ENDIF}

procedure RpBeginCenterDialog(AParent: TCustomForm);
begin
{$IFDEF MSWINDOWS}
  RpEndCenterDialog;
  if (AParent = nil) or not AParent.Visible then
    AParent := Screen.ActiveCustomForm;
  if (AParent = nil) or not AParent.Visible then
    AParent := Application.MainForm;
  if (AParent = nil) or not AParent.HandleAllocated then
    exit;
  DialogParent := AParent.Handle;
  DialogHook := SetWindowsHookEx(WH_CBT, @DialogHookProc, 0, GetCurrentThreadId);
{$ENDIF}
end;

procedure RpEndCenterDialog;
begin
{$IFDEF MSWINDOWS}
  if DialogHook <> 0 then
    UnhookWindowsHookEx(DialogHook);
  DialogHook := 0;
  DialogParent := 0;
  UnsubclassDialog;
{$ENDIF}
end;

function UsableParent(AForm, AParent: TCustomForm): Boolean;
begin
  Result := (AParent <> nil) and (AParent <> AForm) and AParent.Visible and
    (AParent.WindowState <> wsMinimized);
end;

constructor TRpFormCenter.Create;
begin
  inherited Create;
  FCentered := TList.Create;
  FPending := TList.Create;
  FParents := TList.Create;
end;

destructor TRpFormCenter.Destroy;
begin
  FParents.Free;
  FPending.Free;
  FCentered.Free;
  inherited Destroy;
end;

procedure TRpFormCenter.DropPending(AForm: TCustomForm);
var
  i: Integer;
begin
  i := FPending.IndexOf(AForm);
  if i < 0 then
    exit;
  FPending.Delete(i);
  FParents.Delete(i);
end;

// Centered with its final size, once
procedure TRpFormCenter.CenterPending(AForm: TCustomForm);
var
  i: Integer;
  AParent: TCustomForm;
begin
  i := FPending.IndexOf(AForm);
  if i < 0 then
    exit;
  AParent := TCustomForm(FParents[i]);
  DropPending(AForm);
  if AForm.Visible and (AForm.WindowState = wsNormal) and
    (Screen.CustomFormIndex(AParent) >= 0) then
    RpCenterFormOn(AForm, AParent);
end;

procedure TRpFormCenter.EndPending(Data: PtrInt);
begin
  // Data is only compared: the form may have been freed meanwhile
  if FPending.IndexOf(Pointer(Data)) >= 0 then
    CenterPending(TCustomForm(Pointer(Data)));
end;

procedure TRpFormCenter.ActiveFormChanged(Sender: TObject; Form: TCustomForm);
begin
  if Form <> nil then
    CenterPending(Form);
end;

procedure TRpFormCenter.FormVisibleChanged(Sender: TObject; Form: TCustomForm);
var
  AParent: TCustomForm;
begin
  // Called when Visible changes, before the LCL places the form
  if (not Form.Visible) or Form.Showing then
    exit;
  if (Form = Application.MainForm) or (Form.Parent <> nil) or
    (Form.ParentWindow <> 0) or (Form.WindowState <> wsNormal) then
    exit;
  if Copy(Form.ClassName, 1, 4) <> 'TFRp' then
    exit;
  if (FCentered.IndexOf(Form) < 0) and not (Form.Position in
    [poScreenCenter, poDesktopCenter, poMainFormCenter, poOwnerFormCenter,
     poWorkAreaCenter]) then
    exit;
  AParent := Screen.ActiveCustomForm;
  if not UsableParent(Form, AParent) then
    AParent := Application.MainForm;
  if not UsableParent(Form, AParent) then
    exit;
  if FCentered.IndexOf(Form) < 0 then
    FCentered.Add(Form);
  Form.Position := poDesigned;
  RpCenterFormOn(Form, AParent);
  if FPending.IndexOf(Form) < 0 then
  begin
    FPending.Add(Form);
    FParents.Add(AParent);
    // A form that is not activated (also a modal one: its loop handles it)
    Application.QueueAsyncCall(EndPending, PtrInt(Form));
  end;
end;

procedure TRpFormCenter.RemoveForm(Sender: TObject; Form: TCustomForm);
var
  i: Integer;
begin
  FCentered.Remove(Form);
  DropPending(Form);
  // A parent that goes away: its dialogs stay where they are
  i := FParents.IndexOf(Form);
  while i >= 0 do
  begin
    DropPending(TCustomForm(FPending[i]));
    i := FParents.IndexOf(Form);
  end;
end;

initialization
  FormCenter := TRpFormCenter.Create;
  Screen.AddHandlerFormVisibleChanged(FormCenter.FormVisibleChanged);
  Screen.AddHandlerActiveFormChanged(FormCenter.ActiveFormChanged);
  Screen.AddHandlerRemoveForm(FormCenter.RemoveForm);
finalization
  if Screen <> nil then
  begin
    Screen.RemoveHandlerFormVisibleChanged(FormCenter.FormVisibleChanged);
    Screen.RemoveHandlerActiveFormChanged(FormCenter.ActiveFormChanged);
    Screen.RemoveHandlerRemoveForm(FormCenter.RemoveForm);
  end;
  RpEndCenterDialog;
  if Application <> nil then
    Application.RemoveAsyncCalls(FormCenter);
  FormCenter.Free;
end.
