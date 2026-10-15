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
  Dialogs, StdCtrls, ExtCtrls, ImageCollection, VirtualImageList, rpauthmanager;

type
  TFRpLoginVCL = class(TForm)
    PanelButtons: TPanel;
    LTitle: TLabel;
    BtnGoogle: TButton;
    BtnMicrosoft: TButton;
    BtnApple: TButton;
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
    LAgentInfo: TLabel;
    LnkAgentDownload: TLabel;
    procedure BtnGoogleClick(Sender: TObject);
    procedure BtnMicrosoftClick(Sender: TObject);
    procedure BtnAppleClick(Sender: TObject);
    procedure BtnEmailClick(Sender: TObject);
    procedure BtnSendCodeClick(Sender: TObject);
    procedure BtnLoginCodeClick(Sender: TObject);
    procedure LnkAgentDownloadClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure AddLog(const AMsg: string);
    procedure AuthLog(const AMsg: string);
    procedure SetupProviderIcons;
  end;

  function ShowLoginDialog(AOwner: TComponent): Boolean;

implementation

{$R *.dfm}

{$I rploginicons.inc}

function ShowLoginDialog(AOwner: TComponent): Boolean;
var
  LForm: TFRpLoginVCL;
begin
  LForm := TFRpLoginVCL.Create(AOwner);
  try
    LForm.SetupProviderIcons;
    TRpAuthManager.Instance.RegisterLogListener(LForm.AuthLog);
    Result := LForm.ShowModal = mrOk;
  finally
    TRpAuthManager.Instance.UnregisterLogListener(LForm.AuthLog);
    LForm.Free;
  end;
end;

procedure TFRpLoginVCL.FormCreate(Sender: TObject);
begin
  // Handled in ShowLoginDialog for simplicity with Instance
end;

// The logo of each provider on its button. The collection keeps the three
// sizes of each icon (rploginicons.inc) and the virtual list draws the one of
// the screen's DPI
procedure TFRpLoginVCL.SetupProviderIcons;
const
  CNames: array[0..3] of string = ('google', 'microsoft', 'apple', 'email');
  CSizes: array[0..2] of Integer = (20, 30, 40);
var
  LCollection: TImageCollection;
  LImages: TVirtualImageList;
  LStream: TMemoryStream;
  LButtons: array[0..3] of TButton;
  I, J: Integer;
begin
  LCollection := TImageCollection.Create(Self);
  for I := Low(CNames) to High(CNames) do
    for J := Low(CSizes) to High(CSizes) do
    begin
      LStream := TMemoryStream.Create;
      try
        if RpLoginIconPng(CNames[I], CSizes[J], LStream) then
        begin
          LStream.Position := 0;
          LCollection.Add(CNames[I], LStream);
        end;
      finally
        LStream.Free;
      end;
    end;
  LImages := TVirtualImageList.Create(Self);
  LImages.ImageCollection := LCollection;
  LImages.Width := MulDiv(20, CurrentPPI, 96);
  LImages.Height := LImages.Width;
  LButtons[0] := BtnGoogle;
  LButtons[1] := BtnMicrosoft;
  LButtons[2] := BtnApple;
  LButtons[3] := BtnEmail;
  for I := Low(CNames) to High(CNames) do
  begin
    LImages.Add(CNames[I], CNames[I]);
    LButtons[I].Images := LImages;
    LButtons[I].ImageIndex := I;
    LButtons[I].ImageAlignment := iaLeft;
    LButtons[I].ImageMargins.Left := MulDiv(16, CurrentPPI, 96);
  end;
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

procedure TFRpLoginVCL.BtnAppleClick(Sender: TObject);
begin
  LStatus.Caption := 'Starting Apple Login...';
  AddLog('BtnAppleClick: Requesting Apple login');
  LStatus.Font.Color := clWindowText;
  Application.ProcessMessages;

  if TRpAuthManager.Instance.LoginApple then
  begin
    AddLog('LoginApple returned True');
    ModalResult := mrOk;
  end
  else
  begin
    AddLog('LoginApple returned False');
    // What the server said (Sign in with Apple not configured...)
    if TRpAuthManager.Instance.LastLoginError <> '' then
      LStatus.Caption := TRpAuthManager.Instance.LastLoginError
    else
      LStatus.Caption := 'Apple login failed or cancelled.';
    LStatus.Font.Color := clRed;
  end;
end;

procedure TFRpLoginVCL.LnkAgentDownloadClick(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenAgentDownloadPage;
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
