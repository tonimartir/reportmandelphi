{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpfrmloginvcl                                   }
{       Login Dialog (Google / Microsoft / Email OTP)    }
{                                                       }
{       Copyright (c) 1994-2025 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpfrmloginvcl;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, rpauthmanager;

type
  TFRpLoginVCL = class(TForm)
    PanelButtons: TPanel;
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
    procedure BtnGoogleClick(Sender: TObject);
    procedure BtnMicrosoftClick(Sender: TObject);
    procedure BtnEmailClick(Sender: TObject);
    procedure BtnSendCodeClick(Sender: TObject);
    procedure BtnLoginCodeClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure AddLog(const AMsg: string);
    procedure AuthLog(const AMsg: string);
  end;

  function ShowLoginDialog(AOwner: TComponent): Boolean;

implementation

{$R *.dfm}

function ShowLoginDialog(AOwner: TComponent): Boolean;
var
  LForm: TFRpLoginVCL;
begin
  LForm := TFRpLoginVCL.Create(AOwner);
  try
    TRpAuthManager.Instance.OnLog := LForm.AuthLog;
    Result := LForm.ShowModal = mrOk;
  finally
    TRpAuthManager.Instance.OnLog := nil;
    LForm.Free;
  end;
end;

procedure TFRpLoginVCL.FormCreate(Sender: TObject);
begin
  // Handled in ShowLoginDialog for simplicity with Instance
end;

procedure TFRpLoginVCL.AddLog(const AMsg: string);
begin
  MemoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' - ' + AMsg);
  Application.ProcessMessages;
end;

procedure TFRpLoginVCL.AuthLog(const AMsg: string);
begin
  AddLog(AMsg);
end;

procedure TFRpLoginVCL.BtnGoogleClick(Sender: TObject);
begin
  LStatus.Caption := 'Starting Google Login...';
  AddLog('BtnGoogleClick: Requesting Google login');
  LStatus.Font.Color := clWindowText;
  Application.ProcessMessages;

  if TRpAuthManager.Instance.LoginGoogle then
  begin
    AddLog('LoginGoogle returned True');
    ModalResult := mrOk;
  end
  else
  begin
    AddLog('LoginGoogle returned False');
    LStatus.Caption := 'Google login failed or cancelled.';
    LStatus.Font.Color := clRed;
  end;
end;

procedure TFRpLoginVCL.BtnMicrosoftClick(Sender: TObject);
begin
  LStatus.Caption := 'Starting Microsoft Login...';
  AddLog('BtnMicrosoftClick: Requesting Microsoft login');
  LStatus.Font.Color := clWindowText;
  Application.ProcessMessages;

  if TRpAuthManager.Instance.LoginMicrosoft then
  begin
    AddLog('LoginMicrosoft returned True');
    ModalResult := mrOk;
  end
  else
  begin
    AddLog('LoginMicrosoft returned False');
    LStatus.Caption := 'Microsoft login failed or cancelled.';
    LStatus.Font.Color := clRed;
  end;
end;

procedure TFRpLoginVCL.BtnEmailClick(Sender: TObject);
begin
  PanelEmail.Visible := True;
  EditEmail.SetFocus;
end;

procedure TFRpLoginVCL.BtnSendCodeClick(Sender: TObject);
begin
  if (EditEmail.Text = '') or (Pos('@', EditEmail.Text) = 0) then
  begin
    LStatus.Caption := 'Enter a valid email address.';
    LStatus.Font.Color := clRed;
    Exit;
  end;

  LStatus.Caption := 'Sending code...';
  LStatus.Font.Color := clWindowText;
  Application.ProcessMessages;

  if TRpAuthManager.Instance.RequestLoginCode(EditEmail.Text) then
  begin
    LStatus.Caption := 'Code sent! Check your email.';
    LStatus.Font.Color := clGreen;
    EditCode.SetFocus;
  end
  else
  begin
    LStatus.Caption := 'Failed to send code. Try again.';
    LStatus.Font.Color := clRed;
  end;
end;

procedure TFRpLoginVCL.BtnLoginCodeClick(Sender: TObject);
begin
  if EditCode.Text = '' then
  begin
    LStatus.Caption := 'Enter the verification code.';
    LStatus.Font.Color := clRed;
    Exit;
  end;

  LStatus.Caption := 'Logging in...';
  LStatus.Font.Color := clWindowText;
  Application.ProcessMessages;

  if TRpAuthManager.Instance.LoginWithCode(EditEmail.Text, EditCode.Text) then
  begin
    ModalResult := mrOk;
  end
  else
  begin
    LStatus.Caption := 'Invalid code or login failed.';
    LStatus.Font.Color := clRed;
  end;
end;

end.
