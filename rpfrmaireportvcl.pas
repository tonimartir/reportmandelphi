unit rpfrmaireportvcl;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls,
  rpdatahttp, rpaireportcontracts;

type
  TFRpAIReportVCL = class(TForm)
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
    procedure FormCreate(Sender: TObject);
    procedure BSendClick(Sender: TObject);
  private
    FApiKey: string;
    FInstallId: string;
    FIsSending: Boolean;
    FToken: string;
    procedure RefreshButtons;
    procedure ShowSentStateAndClose;
  public
    procedure InitializeDialog(const AAIContent, AToken, AInstallId,
      AApiKey: string);
  end;

function ExecuteAIReportDialog(AOwner: TComponent; const AAIContent, AToken,
  AInstallId, AApiKey: string): Boolean;

implementation

{$R *.dfm}

uses
  rpgraphutilsvcl;

function ExecuteAIReportDialog(AOwner: TComponent; const AAIContent, AToken,
  AInstallId, AApiKey: string): Boolean;
var
  LForm: TFRpAIReportVCL;
begin
  LForm := TFRpAIReportVCL.Create(AOwner);
  try
    LForm.InitializeDialog(AAIContent, AToken, AInstallId, AApiKey);
    Result := LForm.ShowModal = mrOk;
  finally
    LForm.Free;
  end;
end;

procedure TFRpAIReportVCL.FormCreate(Sender: TObject);
begin
  Caption := 'Report AI-generated content';
  LTitle.Caption := 'Report AI-generated content';
  LProblem.Caption := 'Issue detected:';
  LDetails.Caption := 'Details:';
  LAIContent.Caption := 'AI-generated text:';
  LDisclaimer.Caption := 'This report will be sent anonymously to our servers. It will only be used to reduce incorrect, offensive, or inappropriate responses.';
  BSend.Caption := 'Send';
  BCancel.Caption := 'Cancel';
  ComboProblem.Items.Clear;
  ComboProblem.Items.Add('Inappropriate or offensive content');
  ComboProblem.Items.Add('Inaccurate content');
  ComboProblem.ItemIndex := 0;
  FIsSending := False;
  RefreshButtons;
end;

procedure TFRpAIReportVCL.InitializeDialog(const AAIContent, AToken,
  AInstallId, AApiKey: string);
begin
  MemoAIContent.Lines.Text := AAIContent;
  MemoDetails.Clear;
  FToken := AToken;
  FInstallId := AInstallId;
  FApiKey := AApiKey;
  RefreshButtons;
end;

procedure TFRpAIReportVCL.RefreshButtons;
begin
  BSend.Enabled := (not FIsSending) and (Trim(MemoAIContent.Lines.Text) <> '');
  BCancel.Enabled := not FIsSending;
end;

procedure TFRpAIReportVCL.ShowSentStateAndClose;
var
  LStartTick: Cardinal;
begin
  BSend.Caption := 'Report sent';
  BSend.Enabled := False;
  Repaint;
  Update;
  Application.ProcessMessages;

  LStartTick := GetTickCount;
  while GetTickCount - LStartTick < 900 do
  begin
    Application.ProcessMessages;
    Sleep(10);
  end;

  ModalResult := mrOk;
end;

procedure TFRpAIReportVCL.BSendClick(Sender: TObject);
var
  LHttp: TRpDatabaseHttp;
  LReport: TRpAIReport;
begin
  if FIsSending then
    Exit;

  FIsSending := True;
  RefreshButtons;
  try
    LReport := TRpAIReport.Create;
    try
      if ComboProblem.ItemIndex = 1 then
        LReport.ErrorType := raetInaccurateContent
      else
        LReport.ErrorType := raetInappropriateContent;
      LReport.UserComments := Trim(MemoDetails.Lines.Text);
      LReport.AIContent := MemoAIContent.Lines.Text;

      LHttp := TRpDatabaseHttp.Create;
      try
        LHttp.Token := FToken;
        LHttp.InstallId := FInstallId;
        LHttp.ApiKey := FApiKey;
        if not LHttp.SubmitAIReport(LReport) then
          raise Exception.Create('The report could not be sent.');
      finally
        LHttp.Free;
      end;
    finally
      LReport.Free;
    end;

    ShowSentStateAndClose;
  except
    on E: Exception do
    begin
      FIsSending := False;
      RefreshButtons;
      RpShowMessage(E.Message);
    end;
  end;
end;

end.
