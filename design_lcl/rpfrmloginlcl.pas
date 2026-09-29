{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpfrmloginlcl                                   }
{       Login Dialog (Google / Microsoft / Email OTP)   }
{       (LCL port of rpfrmloginvcl)                     }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpfrmloginlcl;

{ The VCL dialog calls the blocking TRpAuthManager logins in the main thread
  (the OAuth ones wait up to five minutes for the browser). Here they run in
  a worker thread and the dialog stays responsive: the buttons are disabled
  while a login runs and the log shows its progress. Closing the dialog does
  not cancel an OAuth login in progress: if the user finishes it in the
  browser, TRpAuthManager notifies the forms as usual. }

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  rpauthmanager, rpaithreadslcl;

type
  TRpLoginAction = (rlaGoogle, rlaMicrosoft, rlaSendCode, rlaLoginCode);

  TFRpLoginLCL = class(TForm)
  private
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    FBusy: Boolean;
    procedure BuildControls;
    procedure SetBusy(AValue: Boolean);
    procedure StartAction(AAction: TRpLoginAction);
    procedure HandleMessage(AMessage: TRpAsyncMessage);
    procedure SetStatus(const AText: string; AColor: TColor);
    procedure AddLog(const AMsg: string);
    procedure AuthLog(const AMsg: string);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
  public
    LTitle: TLabel;
    BtnGoogle: TButton;
    BtnMicrosoft: TButton;
    BtnEmail: TButton;
    PanelEmail: TPanel;
    LEmail: TLabel;
    EditEmail: TEdit;
    BtnSendCode: TButton;
    LCode: TLabel;
    EditCode: TEdit;
    BtnLoginCode: TButton;
    LStatus: TLabel;
    MemoLog: TMemo;
    // How to reach the databases: the Reportman Agent and its download page
    LAgentInfo: TLabel;
    LnkAgentDownload: TLabel;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BtnGoogleClick(Sender: TObject);
    procedure BtnMicrosoftClick(Sender: TObject);
    procedure BtnEmailClick(Sender: TObject);
    procedure BtnSendCodeClick(Sender: TObject);
    procedure BtnLoginCodeClick(Sender: TObject);
    procedure LnkAgentDownloadClick(Sender: TObject);
    // A login is running in the worker thread
    property Busy: Boolean read FBusy;
  end;

function ShowLoginDialog(AOwner: TComponent): Boolean;

implementation

uses
  rpmdconsts, rpchatmodernstylelcl, rplcllayout;

type
  TRpLoginResultMessage = class(TRpAsyncMessage)
  public
    Action: TRpLoginAction;
    Success: Boolean;
    ErrorText: string;
  end;

  TRpLoginWorker = class(TRpAsyncWorker)
  public
    Action: TRpLoginAction;
    Email: string;
    Code: string;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
  end;

procedure TRpLoginWorker.Run;
var
  LResult: TRpLoginResultMessage;
  LOk: Boolean;
begin
  case Action of
    rlaGoogle:
      LOk := TRpAuthManager.Instance.LoginGoogle;
    rlaMicrosoft:
      LOk := TRpAuthManager.Instance.LoginMicrosoft;
    rlaSendCode:
      LOk := TRpAuthManager.Instance.RequestLoginCode(Email);
  else
    LOk := TRpAuthManager.Instance.LoginWithCode(Email, Code);
  end;
  LResult := TRpLoginResultMessage.Create;
  LResult.Action := Action;
  LResult.Success := LOk;
  Post(LResult);
end;

procedure TRpLoginWorker.HandleError(E: Exception);
var
  LResult: TRpLoginResultMessage;
begin
  LResult := TRpLoginResultMessage.Create;
  LResult.Action := Action;
  LResult.Success := False;
  LResult.ErrorText := E.Message;
  Post(LResult);
end;

function ShowLoginDialog(AOwner: TComponent): Boolean;
var
  LForm: TFRpLoginLCL;
begin
  LForm := TFRpLoginLCL.Create(AOwner);
  try
    Result := LForm.ShowModal = mrOk;
  finally
    LForm.Free;
  end;
end;

{ TFRpLoginLCL }

constructor TFRpLoginLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  // Sizes in pixels of the screen: the LCL does not scale it again
  RpBuiltInScreenPixels(Self);
  FMailbox := TRpAsyncMailbox.Create(HandleMessage);
  FMailboxRef := FMailbox;
  BuildControls;
  RpAuthEvents.AddLogListener(AuthLog);
end;

destructor TFRpLoginLCL.Destroy;
begin
  RpAuthEvents.RemoveLogListener(AuthLog);
  // A login still running goes on without the dialog
  if FBusy then
    Screen.Cursor := crDefault;
  FMailbox.Detach;
  FMailboxRef := nil;
  inherited Destroy;
end;

procedure TFRpLoginLCL.BuildControls;
var
  LLeft, LWidth, LTop: Integer;
begin
  BorderStyle := bsDialog;
  Position := poMainFormCenter;
  Caption := TranslateStr(1499, 'Login to Reportman.AI');
  ClientWidth := Scale(400);
  ClientHeight := Scale(540);
  KeyPreview := True;
  OnKeyPress := FormKeyPress;
  LLeft := Scale(24);
  LWidth := Scale(352);

  LTitle := TLabel.Create(Self);
  LTitle.Parent := Self;
  LTitle.SetBounds(LLeft, Scale(16), LWidth, Scale(24));
  LTitle.Caption := TranslateStr(1500, 'Account Login');
  LTitle.Font.Style := [fsBold];
  LTitle.Font.Size := 12;

  LTop := Scale(56);
  BtnGoogle := TButton.Create(Self);
  BtnGoogle.Parent := Self;
  BtnGoogle.SetBounds(LLeft, LTop, LWidth, Scale(40));
  BtnGoogle.Caption := TranslateStr(1501, 'Login with Google');
  BtnGoogle.OnClick := BtnGoogleClick;

  Inc(LTop, Scale(52));
  BtnMicrosoft := TButton.Create(Self);
  BtnMicrosoft.Parent := Self;
  BtnMicrosoft.SetBounds(LLeft, LTop, LWidth, Scale(40));
  BtnMicrosoft.Caption := TranslateStr(1502, 'Login with Microsoft');
  BtnMicrosoft.OnClick := BtnMicrosoftClick;

  Inc(LTop, Scale(52));
  BtnEmail := TButton.Create(Self);
  BtnEmail.Parent := Self;
  BtnEmail.SetBounds(LLeft, LTop, LWidth, Scale(40));
  BtnEmail.Caption := TranslateStr(1503, 'Login with Email Code');
  BtnEmail.OnClick := BtnEmailClick;

  Inc(LTop, Scale(50));
  PanelEmail := TPanel.Create(Self);
  PanelEmail.Parent := Self;
  PanelEmail.BevelOuter := bvNone;
  PanelEmail.Caption := '';
  PanelEmail.SetBounds(LLeft, LTop, LWidth, Scale(104));
  PanelEmail.Visible := False;

  LEmail := TLabel.Create(Self);
  LEmail.Parent := PanelEmail;
  LEmail.SetBounds(0, Scale(4), Scale(260), Scale(18));
  LEmail.Caption := TranslateStr(1504, 'Email:');

  EditEmail := TEdit.Create(Self);
  EditEmail.Parent := PanelEmail;
  EditEmail.SetBounds(0, Scale(24), Scale(256), Scale(26));

  BtnSendCode := TButton.Create(Self);
  BtnSendCode.Parent := PanelEmail;
  BtnSendCode.SetBounds(Scale(262), Scale(23), Scale(90), Scale(28));
  BtnSendCode.Caption := TranslateStr(1506, 'Send Code');
  BtnSendCode.OnClick := BtnSendCodeClick;

  LCode := TLabel.Create(Self);
  LCode.Parent := PanelEmail;
  LCode.SetBounds(0, Scale(54), Scale(260), Scale(18));
  LCode.Caption := TranslateStr(1505, 'Verification Code:');

  EditCode := TEdit.Create(Self);
  EditCode.Parent := PanelEmail;
  EditCode.SetBounds(0, Scale(74), Scale(256), Scale(26));

  BtnLoginCode := TButton.Create(Self);
  BtnLoginCode.Parent := PanelEmail;
  BtnLoginCode.SetBounds(Scale(262), Scale(73), Scale(90), Scale(28));
  BtnLoginCode.Caption := TranslateStr(1492, 'Login');
  BtnLoginCode.OnClick := BtnLoginCodeClick;

  LStatus := TLabel.Create(Self);
  LStatus.Parent := Self;
  LStatus.AutoSize := False;
  LStatus.WordWrap := True;
  LStatus.SetBounds(LLeft, Scale(330), LWidth, Scale(32));
  LStatus.Caption := TranslateStr(975, 'Ready');

  MemoLog := TMemo.Create(Self);
  MemoLog.Parent := Self;
  MemoLog.SetBounds(LLeft, Scale(366), LWidth, Scale(80));
  MemoLog.ReadOnly := True;
  MemoLog.ScrollBars := ssVertical;
  MemoLog.Color := clInfoBk;
  MemoLog.Font.Color := clInfoText;
  MemoLog.Font.Name := 'Monospace';
{$IFDEF MSWINDOWS}
  MemoLog.Font.Name := 'Consolas';
{$ENDIF}
  MemoLog.Font.Size := 8;
  MemoLog.TabStop := False;

  // Room for three lines (long translations); the link goes under the text
  LAgentInfo := TLabel.Create(Self);
  LAgentInfo.Parent := Self;
  LAgentInfo.WordWrap := True;
  LAgentInfo.ShowAccelChar := False;
  LAgentInfo.SetBounds(LLeft, Scale(456), LWidth, Scale(18));
  // Both sides anchored: the autosize only sets the height of the lines
  LAgentInfo.AnchorParallel(akRight, LLeft, Self);
  LAgentInfo.Anchors := [akLeft, akTop, akRight];
  LAgentInfo.Caption := TranslateStr(1821,
    'To connect to your databases you can use the Reportman Agent (ai.reportman.es).');

  LnkAgentDownload := TLabel.Create(Self);
  LnkAgentDownload.Parent := Self;
  LnkAgentDownload.ShowAccelChar := False;
  LnkAgentDownload.Caption := TranslateStr(1822, 'Download Reportman Agent');
  LnkAgentDownload.Cursor := crHandPoint;
  LnkAgentDownload.Font.Color := clBlue;
  LnkAgentDownload.Font.Style := [fsUnderline];
  LnkAgentDownload.OnClick := LnkAgentDownloadClick;
  LnkAgentDownload.Left := LLeft;
  LnkAgentDownload.AnchorToNeighbour(akTop, Scale(4), LAgentInfo);
end;

procedure TFRpLoginLCL.LnkAgentDownloadClick(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenAgentDownloadPage;
end;

procedure TFRpLoginLCL.FormKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #27 then
  begin
    Key := #0;
    ModalResult := mrCancel;
  end;
end;

procedure TFRpLoginLCL.AddLog(const AMsg: string);
begin
  MemoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' - ' + AMsg);
  MemoLog.SelStart := Length(MemoLog.Text);
end;

procedure TFRpLoginLCL.AuthLog(const AMsg: string);
begin
  // Delivered in the main thread by RpAuthEvents
  AddLog(AMsg);
end;

procedure TFRpLoginLCL.SetStatus(const AText: string; AColor: TColor);
begin
  LStatus.Caption := AText;
  LStatus.Font.Color := AColor;
end;

procedure TFRpLoginLCL.SetBusy(AValue: Boolean);
begin
  FBusy := AValue;
  BtnGoogle.Enabled := not AValue;
  BtnMicrosoft.Enabled := not AValue;
  BtnEmail.Enabled := not AValue;
  BtnSendCode.Enabled := not AValue;
  BtnLoginCode.Enabled := not AValue;
  if AValue then
    Screen.Cursor := crAppStart
  else
    Screen.Cursor := crDefault;
end;

procedure TFRpLoginLCL.StartAction(AAction: TRpLoginAction);
var
  LWorker: TRpLoginWorker;
begin
  if FBusy then
    Exit;
  SetBusy(True);
  LWorker := TRpLoginWorker.Create(FMailboxRef);
  LWorker.Action := AAction;
  LWorker.Email := Trim(EditEmail.Text);
  LWorker.Code := Trim(EditCode.Text);
  LWorker.Start;
end;

procedure TFRpLoginLCL.HandleMessage(AMessage: TRpAsyncMessage);
var
  LResult: TRpLoginResultMessage;
begin
  if not (AMessage is TRpLoginResultMessage) then
    Exit;
  LResult := TRpLoginResultMessage(AMessage);
  SetBusy(False);
  if LResult.ErrorText <> '' then
    AddLog(LResult.ErrorText);
  case LResult.Action of
    rlaGoogle, rlaMicrosoft:
      if LResult.Success then
      begin
        AddLog('Login returned True');
        ModalResult := mrOk;
      end
      else
      begin
        AddLog('Login returned False');
        SetStatus(TranslateStr(1508, 'Login failed or cancelled.'), clRed);
      end;
    rlaSendCode:
      if LResult.Success then
      begin
        SetStatus(TranslateStr(1511, 'Code sent! Check your email.'), clGreen);
        if EditCode.CanFocus then
          EditCode.SetFocus;
      end
      else
        SetStatus(TranslateStr(1512, 'Failed to send code. Try again.'), clRed);
    rlaLoginCode:
      if LResult.Success then
        ModalResult := mrOk
      else
        SetStatus(TranslateStr(1515, 'Invalid code or login failed.'), clRed);
  end;
end;

procedure TFRpLoginLCL.BtnGoogleClick(Sender: TObject);
begin
  SetStatus(TranslateStr(1507, 'Complete the login in your browser...'), clWindowText);
  AddLog('BtnGoogleClick: Requesting Google login');
  StartAction(rlaGoogle);
end;

procedure TFRpLoginLCL.BtnMicrosoftClick(Sender: TObject);
begin
  SetStatus(TranslateStr(1507, 'Complete the login in your browser...'), clWindowText);
  AddLog('BtnMicrosoftClick: Requesting Microsoft login');
  StartAction(rlaMicrosoft);
end;

procedure TFRpLoginLCL.BtnEmailClick(Sender: TObject);
begin
  PanelEmail.Visible := True;
  if EditEmail.CanFocus then
    EditEmail.SetFocus;
end;

procedure TFRpLoginLCL.BtnSendCodeClick(Sender: TObject);
begin
  if (Trim(EditEmail.Text) = '') or (Pos('@', EditEmail.Text) = 0) then
  begin
    SetStatus(TranslateStr(1509, 'Enter a valid email address.'), clRed);
    Exit;
  end;
  SetStatus(TranslateStr(1510, 'Sending code...'), clWindowText);
  StartAction(rlaSendCode);
end;

procedure TFRpLoginLCL.BtnLoginCodeClick(Sender: TObject);
begin
  if Trim(EditCode.Text) = '' then
  begin
    SetStatus(TranslateStr(1513, 'Enter the verification code.'), clRed);
    Exit;
  end;
  SetStatus(TranslateStr(1514, 'Logging in...'), clWindowText);
  StartAction(rlaLoginCode);
end;

end.
