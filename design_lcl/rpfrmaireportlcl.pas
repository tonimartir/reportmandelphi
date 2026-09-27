{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpfrmaireportlcl                                }
{       Report inappropriate or inaccurate AI content   }
{       (LCL port of rpfrmaireportvcl)                  }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpfrmaireportlcl;

{ The "Report content" button of the chat log. The report is sent in a
  worker thread (the VCL sends it in the main thread); the dialog shows
  "Report sent" for a moment and closes. }

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  rpdatahttp, rpaireportcontracts, rpaithreadslcl;

type
  TFRpAIReportLCL = class(TForm)
  private
    FApiKey: string;
    FInstallId: string;
    FIsSending: Boolean;
    FToken: string;
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    FCloseTimer: TTimer;
    procedure BuildControls;
    procedure RefreshButtons;
    procedure HandleMessage(AMessage: TRpAsyncMessage);
    procedure CloseTimerTick(Sender: TObject);
  public
    LTitle: TLabel;
    LProblem: TLabel;
    ComboProblem: TComboBox;
    LDetails: TLabel;
    MemoDetails: TMemo;
    LAIContent: TLabel;
    MemoAIContent: TMemo;
    PDisclaimer: TPanel;
    LDisclaimer: TLabel;
    BSend: TButton;
    BCancel: TButton;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BSendClick(Sender: TObject);
    procedure InitializeDialog(const AAIContent, AToken, AInstallId,
      AApiKey: string);
    property IsSending: Boolean read FIsSending;
  end;

function ExecuteAIReportDialog(AOwner: TComponent; const AAIContent, AToken,
  AInstallId, AApiKey: string): Boolean;

implementation

uses
  rpmdconsts, rpchatmodernstylelcl, rpgraphutilslcl;

type
  TRpAIReportResult = class(TRpAsyncMessage)
  public
    Ok: Boolean;
    ErrorText: string;
  end;

  TRpAIReportWorker = class(TRpAsyncWorker)
  public
    Report: TRpAIReport;
    Token, InstallId, ApiKey: string;
    destructor Destroy; override;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
  end;

destructor TRpAIReportWorker.Destroy;
begin
  Report.Free;
  inherited Destroy;
end;

procedure TRpAIReportWorker.Run;
var
  LHttp: TRpDatabaseHttp;
  LResult: TRpAIReportResult;
begin
  LHttp := TRpDatabaseHttp.Create;
  try
    LHttp.Token := Token;
    LHttp.InstallId := InstallId;
    LHttp.ApiKey := ApiKey;
    LResult := TRpAIReportResult.Create;
    LResult.Ok := LHttp.SubmitAIReport(Report);
    Post(LResult);
  finally
    LHttp.Free;
  end;
end;

procedure TRpAIReportWorker.HandleError(E: Exception);
var
  LResult: TRpAIReportResult;
begin
  LResult := TRpAIReportResult.Create;
  LResult.ErrorText := E.Message;
  Post(LResult);
end;

function ExecuteAIReportDialog(AOwner: TComponent; const AAIContent, AToken,
  AInstallId, AApiKey: string): Boolean;
var
  LForm: TFRpAIReportLCL;
begin
  LForm := TFRpAIReportLCL.Create(AOwner);
  try
    LForm.InitializeDialog(AAIContent, AToken, AInstallId, AApiKey);
    Result := LForm.ShowModal = mrOk;
  finally
    LForm.Free;
  end;
end;

{ TFRpAIReportLCL }

constructor TFRpAIReportLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  FMailbox := TRpAsyncMailbox.Create(HandleMessage);
  FMailboxRef := FMailbox;
  BuildControls;
  FIsSending := False;
  RefreshButtons;
end;

destructor TFRpAIReportLCL.Destroy;
begin
  FMailbox.Detach;
  FMailboxRef := nil;
  inherited Destroy;
end;

procedure TFRpAIReportLCL.BuildControls;
var
  LLeft, LWidth: Integer;
begin
  BorderStyle := bsDialog;
  Position := poMainFormCenter;
  Caption := TranslateStr(1543, 'Report AI-generated content');
  ClientWidth := Scale(520);
  ClientHeight := Scale(470);
  LLeft := Scale(16);
  LWidth := ClientWidth - 2 * LLeft;

  LTitle := TLabel.Create(Self);
  LTitle.Parent := Self;
  LTitle.SetBounds(LLeft, Scale(12), LWidth, Scale(22));
  LTitle.Caption := Caption;
  LTitle.Font.Style := [fsBold];
  LTitle.Font.Size := 11;

  LProblem := TLabel.Create(Self);
  LProblem.Parent := Self;
  LProblem.SetBounds(LLeft, Scale(44), LWidth, Scale(18));
  LProblem.Caption := TranslateStr(1544, 'Issue detected:');

  ComboProblem := TComboBox.Create(Self);
  ComboProblem.Parent := Self;
  ComboProblem.Style := csDropDownList;
  ComboProblem.SetBounds(LLeft, Scale(64), LWidth, Scale(26));
  ComboProblem.Items.Add(TranslateStr(1548, 'Inappropriate or offensive content'));
  ComboProblem.Items.Add(TranslateStr(1549, 'Inaccurate content'));
  ComboProblem.ItemIndex := 0;

  LDetails := TLabel.Create(Self);
  LDetails.Parent := Self;
  LDetails.SetBounds(LLeft, Scale(100), LWidth, Scale(18));
  LDetails.Caption := TranslateStr(1545, 'Details:');

  MemoDetails := TMemo.Create(Self);
  MemoDetails.Parent := Self;
  MemoDetails.SetBounds(LLeft, Scale(120), LWidth, Scale(80));
  MemoDetails.ScrollBars := ssVertical;

  LAIContent := TLabel.Create(Self);
  LAIContent.Parent := Self;
  LAIContent.SetBounds(LLeft, Scale(210), LWidth, Scale(18));
  LAIContent.Caption := TranslateStr(1546, 'AI-generated text:');

  MemoAIContent := TMemo.Create(Self);
  MemoAIContent.Parent := Self;
  MemoAIContent.SetBounds(LLeft, Scale(230), LWidth, Scale(120));
  MemoAIContent.ScrollBars := ssVertical;
  MemoAIContent.ReadOnly := True;

  PDisclaimer := TPanel.Create(Self);
  PDisclaimer.Parent := Self;
  PDisclaimer.BevelOuter := bvNone;
  PDisclaimer.Caption := '';
  PDisclaimer.SetBounds(LLeft, Scale(360), LWidth, Scale(52));
  PDisclaimer.ParentColor := False;
  PDisclaimer.Color := ClrAccentSoft;

  LDisclaimer := TLabel.Create(Self);
  LDisclaimer.Parent := PDisclaimer;
  LDisclaimer.AutoSize := False;
  LDisclaimer.WordWrap := True;
  LDisclaimer.SetBounds(Scale(8), Scale(6), LWidth - Scale(16), Scale(40));
  LDisclaimer.Caption := TranslateStr(1547, 'This report will be sent anonymously to our servers. ' +
    'It will only be used to reduce incorrect, offensive, or inappropriate responses.');

  BSend := TButton.Create(Self);
  BSend.Parent := Self;
  BSend.SetBounds(ClientWidth - LLeft - Scale(220), Scale(424), Scale(104), Scale(30));
  BSend.Caption := TranslateStr(1536, 'Send');
  BSend.Default := True;
  BSend.OnClick := BSendClick;

  BCancel := TButton.Create(Self);
  BCancel.Parent := Self;
  BCancel.SetBounds(ClientWidth - LLeft - Scale(104), Scale(424), Scale(104), Scale(30));
  BCancel.Caption := TranslateStr(94, 'Cancel');
  BCancel.Cancel := True;
  BCancel.ModalResult := mrCancel;
end;

procedure TFRpAIReportLCL.InitializeDialog(const AAIContent, AToken,
  AInstallId, AApiKey: string);
begin
  MemoAIContent.Lines.Text := AAIContent;
  MemoDetails.Clear;
  FToken := AToken;
  FInstallId := AInstallId;
  FApiKey := AApiKey;
  RefreshButtons;
end;

procedure TFRpAIReportLCL.RefreshButtons;
begin
  BSend.Enabled := (not FIsSending) and (Trim(MemoAIContent.Lines.Text) <> '');
  BCancel.Enabled := not FIsSending;
end;

procedure TFRpAIReportLCL.BSendClick(Sender: TObject);
var
  LWorker: TRpAIReportWorker;
begin
  if FIsSending then
    Exit;
  FIsSending := True;
  RefreshButtons;
  LWorker := TRpAIReportWorker.Create(FMailboxRef);
  LWorker.Report := TRpAIReport.Create;
  if ComboProblem.ItemIndex = 1 then
    LWorker.Report.ErrorType := raetInaccurateContent
  else
    LWorker.Report.ErrorType := raetInappropriateContent;
  LWorker.Report.UserComments := Trim(MemoDetails.Lines.Text);
  LWorker.Report.AIContent := MemoAIContent.Lines.Text;
  LWorker.Token := FToken;
  LWorker.InstallId := FInstallId;
  LWorker.ApiKey := FApiKey;
  LWorker.Start;
end;

procedure TFRpAIReportLCL.HandleMessage(AMessage: TRpAsyncMessage);
var
  LResult: TRpAIReportResult;
begin
  if not (AMessage is TRpAIReportResult) then
    Exit;
  LResult := TRpAIReportResult(AMessage);
  if LResult.Ok then
  begin
    BSend.Caption := TranslateStr(1550, 'Report sent');
    BSend.Enabled := False;
    // Shown for a moment, as the VCL does
    FCloseTimer := TTimer.Create(Self);
    FCloseTimer.Interval := 900;
    FCloseTimer.OnTimer := CloseTimerTick;
    FCloseTimer.Enabled := True;
  end
  else
  begin
    FIsSending := False;
    RefreshButtons;
    if LResult.ErrorText <> '' then
      RpShowMessage(LResult.ErrorText)
    else
      RpShowMessage(TranslateStr(1551, 'The report could not be sent.'));
  end;
end;

procedure TFRpAIReportLCL.CloseTimerTick(Sender: TObject);
begin
  FCloseTimer.Enabled := False;
  ModalResult := mrOk;
end;

end.
