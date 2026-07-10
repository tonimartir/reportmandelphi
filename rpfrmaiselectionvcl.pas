{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpfrmaiselectionvcl                             }
{       AI Provider, Mode and Credit Gauge Frame        }
{                                                       }
{       Copyright (c) 1994-2025 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpfrmaiselectionvcl;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, CommCtrl, System.JSON,
  rpauthmanager, rpchatmodernstyle;

  const
    CRpStartupNetworkDelayMs = 0;

type

  TRpProgressTokenEntry = class(TObject)
  public
    ProgressId: string;
    InputTokens: Integer;
    OutputTokens: Integer;
    PrefillPercent: Integer;
    RowLabel: TLabel;
    destructor Destroy; override;
  end;

  // Mirrors Desktop NLToSQLProvider: Standard, Precision, Agent
  TRpAITierType = (rpaitStandard, rpaitPrecision, rpaitAgent);

  TAgentEndpointInfo = record
    Id: Int64;
    AgentSecret: string;
    DisplayName: string;
    IsOnline: Boolean;
  end;

  TFRpAISelectionVCL = class(TFrame)
    PAI: TPanel;
    PNonInference: TPanel;
    GridAI: TGridPanel;
    PProviderHost: TPanel;
    PModeHost: TPanel;
    ComboAIProvider: TComboBox;
    ComboAIMode: TComboBox;
    PInferenceProgress: TPanel;
    GridInference: TGridPanel;
    BStopInference: TButton;
    PTokensHost: TPanel;
    LTokensInfo: TLabel;
    PProgressHost: TPanel;
    PGaugeHost: TPanel;
    PaintBoxGauge: TPaintBox;
    PaintBoxProgress: TPaintBox;
    SpinnerTimer: TTimer;
    procedure PaintBoxGaugePaint(Sender: TObject);
    procedure PaintBoxProgressPaint(Sender: TObject);
    procedure ComboAIModeChange(Sender: TObject);
    procedure ComboAIProviderChange(Sender: TObject);
    procedure BStopInferenceClick(Sender: TObject);
    procedure SpinnerTimerTimer(Sender: TObject);
  private
    FGaugeValue: Double; // 0.0 to 1.0
    FSpinnerAngle: Integer;
    FAgentEndpoints: array of TAgentEndpointInfo;
    FProgressTokens: TStringList;
    FOnStopRequest: TNotifyEvent;
    FShowGauge: Boolean;
    FLblProvider: TLabel;
    FLblMode: TLabel;
    procedure ClearProgressTokens;
    procedure CMVisibleChanged(var Message: TMessage); message CM_VISIBLECHANGED;
    function EnsureProgressTokenEntry(const AProgressId: string): TRpProgressTokenEntry;
    function FormatProgressTokenId(const AProgressId: string): string;
    function GetProgressTokenKey(const AProgressId: string): string;
    procedure UpdateProgressTokenLabel(AEntry: TRpProgressTokenEntry);
    procedure RefreshTokensCaption;
    procedure LayoutNonInferenceControls;
    procedure LayoutGaugeControls;
    procedure UpdateGaugeVisibility;
    procedure SetGaugeValue(const Value: Double);
    procedure SetShowGauge(const Value: Boolean);
    procedure UpdateSpinnerState;
    procedure UpdateDropDownWidths;
    procedure ApplyModernStyling;
    function GetAITier: string;
    function GetAIMode: string;
    function GetAgentSecret: string;
    function GetAgentAiId: Int64;
    procedure UpdateGaugeDisplay;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Resize; override;
    function PreferredHeight: Integer;
    procedure RefreshLayout;
    procedure RefreshStatusInBackground(ADelayBeforeRequestMs: Cardinal = 0);
    procedure RefreshState;
    procedure UpdateFromUserProfile(AProfile: TJSONObject);
    procedure AddAgentEndpoint(AId: Int64; const ASecret, AName: string; AOnline: Boolean);
    procedure ClearAgentEndpoints;
    procedure RestoreProviderSelection(const AAITier: string; AAgentAiId: Int64);
    function AgentEndpointCount: Integer;
    procedure SetInferenceProgress(AActive: Boolean);
    procedure TouchProgressToken(const AProgressId: string);
    procedure FinishProgressToken(const AProgressId: string);
    procedure UpdateTokens(AInTokens, AOutTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer = 0);
    property GaugeValue: Double read FGaugeValue write SetGaugeValue;
    property ShowGauge: Boolean read FShowGauge write SetShowGauge;
    property OnStopRequest: TNotifyEvent read FOnStopRequest write FOnStopRequest;
    // Properties for the HTTP driver
    property AITier: string read GetAITier;
    property AIMode: string read GetAIMode;
    property AgentSecret: string read GetAgentSecret;
    property AgentAiId: Int64 read GetAgentAiId;
  end;

implementation

{$R *.dfm}

const
  CAISelectionLabelHeight = 16;
  CAISelectionSpacingV = 2;
  CAISelectionVerticalPadding = 6;
  CAISelectionGaugeSize = 30;
  CAISelectionLegacyNormalHeight = 50;
  CAISelectionInferenceLineHeight = 18;

destructor TRpProgressTokenEntry.Destroy;
begin
  RowLabel.Free;
  inherited;
end;

constructor TFRpAISelectionVCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGaugeValue := 0.0;
  FSpinnerAngle := 270;
  FShowGauge := True;
  FProgressTokens := TStringList.Create;
  Height := PreferredHeight;
  ComboAIProvider.Align := alTop;
  ComboAIMode.Align := alTop;
  ComboAIProvider.ItemIndex := 0; // Standard
  ComboAIMode.ItemIndex := 0;    // Fast
  SpinnerTimer.Enabled := False;
  ApplyModernStyling;
  UpdateGaugeVisibility;
  LayoutGaugeControls;
  UpdateDropDownWidths;
  RefreshState;
end;

destructor TFRpAISelectionVCL.Destroy;
begin
  ClearProgressTokens;
  FProgressTokens.Free;
  inherited Destroy;
end;

procedure TFRpAISelectionVCL.ApplyModernStyling;
begin
  // Inherit font from parent (ParentFont stays True). Only background/colors
  // and label styles are tweaked so size/name match the rest of the chat UI.

  TRpChatStyle.StylePanelBg(PAI);
  TRpChatStyle.StylePanelBg(PNonInference);
  TRpChatStyle.StylePanelBg(PInferenceProgress);
  TRpChatStyle.StylePanelBg(PProviderHost);
  TRpChatStyle.StylePanelBg(PModeHost);
  TRpChatStyle.StylePanelBg(PGaugeHost);
  TRpChatStyle.StylePanelBg(PTokensHost);
  TRpChatStyle.StylePanelBg(PProgressHost);

  // Micro labels above combos
  if FLblProvider = nil then
  begin
    FLblProvider := TLabel.Create(Self);
    FLblProvider.Parent := PProviderHost;
    FLblProvider.Caption := 'PROVIDER';
    FLblProvider.Align := alTop;
    FLblProvider.AutoSize := True;
    FLblProvider.Alignment := taLeftJustify;
    FLblProvider.Layout := tlBottom;
    FLblProvider.Transparent := True;
  end;

  if FLblMode = nil then
  begin
    FLblMode := TLabel.Create(Self);
    FLblMode.Parent := PModeHost;
    FLblMode.Caption := 'MODE';
    FLblMode.Align := alTop;
    FLblMode.AutoSize := True;
    FLblMode.Alignment := taLeftJustify;
    FLblMode.Layout := tlBottom;
    FLblMode.Transparent := True;
  end;

  // Defeat IDE Vcl style washout on combos (keeps ParentFont intact).
  TRpChatStyle.StyleInputControl(ComboAIProvider);
  TRpChatStyle.StyleInputControl(ComboAIMode);

  // Tokens label
  if LTokensInfo <> nil then
  begin
    LTokensInfo.AutoSize := False;
    LTokensInfo.Alignment := taLeftJustify;
    LTokensInfo.Layout := tlTop;
    LTokensInfo.Transparent := True;
    LTokensInfo.WordWrap := True;
  end;
end;

procedure TFRpAISelectionVCL.RefreshStatusInBackground(
  ADelayBeforeRequestMs: Cardinal = 0);
var
  LWorker: TThread;
begin
  LWorker := TThread.CreateAnonymousThread(
    procedure
    begin
      if ADelayBeforeRequestMs > 0 then
      begin
        TRpAuthManager.Instance.Log(
          'RefreshStatusInBackground: delaying startup auth status request by ' +
          IntToStr(ADelayBeforeRequestMs) + ' ms for testing.');
        Sleep(ADelayBeforeRequestMs);
      end;
      TRpAuthManager.Instance.CheckStatus;
    end);
  LWorker.FreeOnTerminate := True;
  LWorker.Start;
end;

procedure TFRpAISelectionVCL.Resize;
begin
  inherited;
  RefreshLayout;
end;

procedure TFRpAISelectionVCL.RefreshLayout;
var
  LPreferredHeight: Integer;
begin
  LPreferredHeight := PreferredHeight;
  if Height <> LPreferredHeight then
    Height := LPreferredHeight;
  if PAI <> nil then
    PAI.SetBounds(0, 0, ClientWidth, ClientHeight);
  if PNonInference <> nil then
    PNonInference.SetBounds(0, 0, PAI.ClientWidth, PAI.ClientHeight);
  if PInferenceProgress <> nil then
    PInferenceProgress.SetBounds(0, 0, PAI.ClientWidth, PAI.ClientHeight);
  if GridAI <> nil then
  begin
    GridAI.SetBounds(0, 0, PNonInference.ClientWidth, PNonInference.ClientHeight);
    GridAI.Realign;
  end;
  if GridInference <> nil then
  begin
    GridInference.SetBounds(0, 0, PInferenceProgress.ClientWidth, PInferenceProgress.ClientHeight);
    GridInference.Realign;
  end;
  UpdateGaugeVisibility;
  LayoutNonInferenceControls;
  LayoutGaugeControls;
  if (PInferenceProgress <> nil) and PInferenceProgress.Visible then
    RefreshTokensCaption;
  UpdateDropDownWidths;
  Invalidate;
end;

function TFRpAISelectionVCL.PreferredHeight: Integer;
var
  LContentHeight: Integer;
  LGaugeSize: Integer;
  LLineCount: Integer;
  LLineHeight: Integer;
  LNormalHeight: Integer;
  LVerticalPadding: Integer;
begin
  LNormalHeight := Scale(CAISelectionLegacyNormalHeight);
  LVerticalPadding := Scale(CAISelectionVerticalPadding);
  LGaugeSize := Scale(CAISelectionGaugeSize);
  LLineHeight := Scale(CAISelectionInferenceLineHeight);

  if (PInferenceProgress <> nil) and PInferenceProgress.Visible then
  begin
    LLineCount := FProgressTokens.Count;
    if LLineCount <= 0 then
      LLineCount := 1;
    LContentHeight := LLineCount * LLineHeight;
    if LGaugeSize > LContentHeight then
      LContentHeight := LGaugeSize;
    Result := LContentHeight + (LVerticalPadding * 2);
    if Result < LNormalHeight then
      Result := LNormalHeight;
    Exit;
  end;

  Result := LNormalHeight;
end;

procedure TFRpAISelectionVCL.LayoutNonInferenceControls;
var
  LabelH: Integer;
  SpacingV: Integer;
  LComboHeight: Integer;
  LComboTop: Integer;
  LHost: TPanel;

  procedure PositionPair(AHost: TPanel; ALabel: TLabel; ACombo: TComboBox);
  begin
    if (AHost = nil) or (ACombo = nil) then Exit;
    if AHost.ClientWidth <= 0 then Exit;
    if ALabel <> nil then
    begin
      ALabel.Align := alNone;
      ALabel.SetBounds(0, 0, AHost.ClientWidth, LabelH);
    end;
    ACombo.Align := alNone;
    LComboTop := LabelH + SpacingV;
    if (AHost.ClientHeight - LComboTop) < LComboHeight then
      LComboTop := AHost.ClientHeight - LComboHeight;
    if LComboTop < 0 then LComboTop := 0;
    ACombo.SetBounds(0, LComboTop, AHost.ClientWidth, LComboHeight);
  end;

begin
  LabelH := Scale(CAISelectionLabelHeight);
  SpacingV := Scale(CAISelectionSpacingV);
  LHost := PProviderHost;
  if LHost = nil then Exit;
  LComboHeight := ComboAIProvider.Height;
  if ComboAIMode.Height > LComboHeight then
    LComboHeight := ComboAIMode.Height;
  if LComboHeight <= 0 then
    LComboHeight := 22;

  PositionPair(PProviderHost, FLblProvider, ComboAIProvider);
  PositionPair(PModeHost, FLblMode, ComboAIMode);
end;

procedure TFRpAISelectionVCL.LayoutGaugeControls;
var
  GaugeSize: Integer;
  LLeft: Integer;
  LTop: Integer;
begin
  GaugeSize := Scale(CAISelectionGaugeSize);
  if (PGaugeHost <> nil) and PGaugeHost.Visible then
  begin
    LLeft := (PGaugeHost.ClientWidth - GaugeSize) div 2;
    LTop := (PGaugeHost.ClientHeight - GaugeSize) div 2;
    if LLeft < 0 then
      LLeft := 0;
    if LTop < 0 then
      LTop := 0;
    PaintBoxGauge.SetBounds(LLeft, LTop, GaugeSize, GaugeSize);
  end;
  if PProgressHost <> nil then
  begin
    LLeft := (PProgressHost.ClientWidth - GaugeSize) div 2;
    LTop := (PProgressHost.ClientHeight - GaugeSize) div 2;
    if LLeft < 0 then
      LLeft := 0;
    if LTop < 0 then
      LTop := 0;
    PaintBoxProgress.SetBounds(LLeft, LTop, GaugeSize, GaugeSize);
  end;
end;

procedure TFRpAISelectionVCL.UpdateGaugeVisibility;
var
  LShowGauge: Boolean;
begin
  LShowGauge := FShowGauge and (ComboAIProvider.ItemIndex < 2);

  if GridAI <> nil then
  begin
    if GridAI.ColumnCollection.Count >= 3 then
    begin
      GridAI.ColumnCollection[2].SizeStyle := ssAbsolute;
      if LShowGauge then
        GridAI.ColumnCollection[2].Value := 44
      else
        GridAI.ColumnCollection[2].Value := 0;
    end;
    GridAI.Realign;
  end;

  if PGaugeHost <> nil then
    PGaugeHost.Visible := LShowGauge;
  if PaintBoxGauge <> nil then
    PaintBoxGauge.Visible := LShowGauge;
end;

procedure TFRpAISelectionVCL.RefreshState;
begin
  LayoutGaugeControls;
  UpdateGaugeDisplay;
end;

procedure TFRpAISelectionVCL.UpdateGaugeDisplay;
var
  LProfile: TRpProfile;
  LUsed, LMax: Int64;
  LPct: Double;
  LHint: string;
  LAuth: TRpAuthManager;
begin
  LAuth := TRpAuthManager.Instance;
  LProfile := LAuth.Profile;

  LUsed := LAuth.GetCreditsConsumed;
  LMax := LAuth.GetCreditsMax;
  FGaugeValue := LAuth.GetCreditsRatio;
  LPct := FGaugeValue * 100;

  if LMax > 0 then
  begin
    if LAuth.UsesFreeCredits then
      LHint := 'Free Credits' + #13#10
    else
      LHint := 'Daily Credit Usage' + #13#10;

    LHint := LHint + 'Used: ' + FormatFloat('#,##0', LUsed) +
      ' (' + FormatFloat('0', LPct) + '%)' + #13#10;
    LHint := LHint + 'Max: ' + FormatFloat('#,##0', LMax);

    if (not LAuth.UsesFreeCredits) and (LProfile.ServerDay > 0) then
      LHint := LHint + #13#10 + DateToStr(LProfile.ServerDay);
  end
  else
  begin
    LHint := 'Free Credits' + #13#10 +
      'Used: 0 (0%)' + #13#10 +
      'Max: 0';
    FGaugeValue := 0.0;
  end;

  PaintBoxGauge.Hint := LHint;
  // Enable hints
  PaintBoxGauge.ShowHint := True;
  SetGaugeValue(FGaugeValue);
end;

procedure TFRpAISelectionVCL.UpdateFromUserProfile(AProfile: TJSONObject);
begin
  TRpAuthManager.Instance.UpdateProfileFromJson(AProfile);
end;

procedure TFRpAISelectionVCL.SetGaugeValue(const Value: Double);
begin
  FGaugeValue := Value;
  if PaintBoxGauge <> nil then
    PaintBoxGauge.Invalidate;
end;

procedure TFRpAISelectionVCL.ClearProgressTokens;
var
  I: Integer;
begin
  if FProgressTokens = nil then
    Exit;
  for I := 0 to FProgressTokens.Count - 1 do
    FProgressTokens.Objects[I].Free;
  FProgressTokens.Clear;
end;

function TFRpAISelectionVCL.GetProgressTokenKey(const AProgressId: string): string;
begin
  Result := Trim(AProgressId);
  if Result = '' then
    Result := '__default__';
end;

function TFRpAISelectionVCL.FormatProgressTokenId(
  const AProgressId: string): string;
var
  LId: string;
begin
  LId := Trim(AProgressId);
  if (LId = '') or SameText(LId, '__default__') then
    Exit('');

  if Length(LId) > 18 then
    LId := Copy(LId, 1, 8) + '...' + Copy(LId, Length(LId) - 3, 4);

  Result := '  #' + LId;
end;

function TFRpAISelectionVCL.EnsureProgressTokenEntry(
  const AProgressId: string): TRpProgressTokenEntry;
var
  LIndex: Integer;
  LKey: string;
begin
  LKey := GetProgressTokenKey(AProgressId);
  LIndex := FProgressTokens.IndexOf(LKey);
  if LIndex >= 0 then
    Exit(TRpProgressTokenEntry(FProgressTokens.Objects[LIndex]));

  Result := TRpProgressTokenEntry.Create;
  Result.ProgressId := LKey;
  Result.RowLabel := TLabel.Create(Self);
  Result.RowLabel.Parent := PTokensHost;
  Result.RowLabel.AutoSize := False;
  Result.RowLabel.Alignment := taLeftJustify;
  Result.RowLabel.Layout := tlCenter;
  Result.RowLabel.Transparent := True;
  Result.RowLabel.WordWrap := False;
  Result.RowLabel.Visible := False;
  UpdateProgressTokenLabel(Result);
  FProgressTokens.AddObject(LKey, Result);
end;

procedure TFRpAISelectionVCL.UpdateProgressTokenLabel(
  AEntry: TRpProgressTokenEntry);
var
  LIndex: Integer;
  LPrefix: string;
  LIdText: string;
  LInputText: string;
begin
  if (AEntry = nil) or (AEntry.RowLabel = nil) then
    Exit;

  LIndex := FProgressTokens.IndexOf(AEntry.ProgressId);
  if LIndex = 0 then
    LPrefix := IntToStr(FProgressTokens.Count) + '- '
  else
    LPrefix := '';

  if (AEntry.PrefillPercent > 0) and (AEntry.OutputTokens = 0) then
    LInputText := IntToStr(AEntry.PrefillPercent) + '% de prefill'
  else
    LInputText := IntToStr(AEntry.InputTokens);

  LIdText := FormatProgressTokenId(AEntry.ProgressId);

  AEntry.RowLabel.Caption := LPrefix + 'Input/Output: ' + LInputText +
    ' / ' + IntToStr(AEntry.OutputTokens) + LIdText;
end;

procedure TFRpAISelectionVCL.RefreshTokensCaption;
var
  I: Integer;
  LEntry: TRpProgressTokenEntry;
  LLineHeight: Integer;
  LTop: Integer;
begin
  LLineHeight := Scale(CAISelectionInferenceLineHeight);
  if LTokensInfo <> nil then
  begin
    LTokensInfo.SetBounds(0, 0, PTokensHost.ClientWidth, PTokensHost.ClientHeight);
    LTokensInfo.Visible := FProgressTokens.Count = 0;
    if LTokensInfo.Visible then
      LTokensInfo.Caption := 'Waiting for inference progress...';
  end;

  LTop := 0;
  for I := 0 to FProgressTokens.Count - 1 do
  begin
    LEntry := TRpProgressTokenEntry(FProgressTokens.Objects[I]);
    if (LEntry = nil) or (LEntry.RowLabel = nil) then
      Continue;

    UpdateProgressTokenLabel(LEntry);
    LEntry.RowLabel.SetBounds(0, LTop, PTokensHost.ClientWidth,
      LLineHeight);
    LEntry.RowLabel.Visible := True;
    Inc(LTop, LLineHeight);
  end;
end;

procedure TFRpAISelectionVCL.SetShowGauge(const Value: Boolean);
begin
  if FShowGauge = Value then
    Exit;
  FShowGauge := Value;
  UpdateGaugeVisibility;
  LayoutGaugeControls;
  Invalidate;
end;

procedure TFRpAISelectionVCL.PaintBoxGaugePaint(Sender: TObject);
var
  R: TRect;
  IndicatorColor, TextColor: TColor;
  DisplayValue: Double;
  PercentageValue: Integer;
  PercentageText: string;
begin
  R := PaintBoxGauge.ClientRect;
  // Clear background
  PaintBoxGauge.Canvas.Brush.Color := ClrBg;
  PaintBoxGauge.Canvas.Brush.Style := bsSolid;
  PaintBoxGauge.Canvas.FillRect(R);

  DisplayValue := FGaugeValue;
  if DisplayValue < 0 then DisplayValue := 0;
  if DisplayValue > 1 then DisplayValue := 1;

  if DisplayValue < 0.5 then IndicatorColor := ClrSuccess
  else if DisplayValue < 0.75 then IndicatorColor := RGB(7, 193, 255) // amber-ish BGR
  else if DisplayValue < 0.9 then IndicatorColor := RGB(0, 152, 255)  // orange BGR
  else IndicatorColor := ClrDanger;

  if DisplayValue > 0 then
    TextColor := IndicatorColor
  else
    TextColor := ClrSubText;

  PercentageValue := Round(DisplayValue * 100);
  if PercentageValue < 0 then
    PercentageValue := 0
  else if PercentageValue > 100 then
    PercentageValue := 100;
  PercentageText := IntToStr(PercentageValue);

  TRpChatStyle.DrawCircularGauge(PaintBoxGauge.Canvas, R, DisplayValue,
    PercentageText, ClrBorder, IndicatorColor, TextColor);
end;

procedure TFRpAISelectionVCL.PaintBoxProgressPaint(Sender: TObject);
var
  R: TRect;
begin
  R := PaintBoxProgress.ClientRect;
  PaintBoxProgress.Canvas.Brush.Color := ClrBg;
  PaintBoxProgress.Canvas.Brush.Style := bsSolid;
  PaintBoxProgress.Canvas.FillRect(R);
  InflateRect(R, -3, -3);

  // Track
  TRpChatStyle.DrawAntialiasedArc(PaintBoxProgress.Canvas, R, 0, 360, ClrBorder, 3);
  // Spinner arc
  TRpChatStyle.DrawAntialiasedArc(PaintBoxProgress.Canvas, R, FSpinnerAngle, -110, ClrAccent, 3);
end;

procedure TFRpAISelectionVCL.ComboAIModeChange(Sender: TObject);
begin
  // Mode changed: Fast or Reasoning
end;

procedure TFRpAISelectionVCL.ComboAIProviderChange(Sender: TObject);
begin
  UpdateGaugeVisibility;
  LayoutGaugeControls;
end;

procedure TFRpAISelectionVCL.CMVisibleChanged(var Message: TMessage);
begin
  inherited;
  UpdateSpinnerState;
end;

procedure TFRpAISelectionVCL.UpdateDropDownWidths;
var
  I: Integer;
  LTextWidth: Integer;
  LMaxWidth: Integer;
begin
  if not ComboAIProvider.HandleAllocated then
    Exit;

  LMaxWidth := ComboAIProvider.Width;
  ComboAIProvider.Canvas.Font.Assign(ComboAIProvider.Font);
  for I := 0 to ComboAIProvider.Items.Count - 1 do
  begin
    LTextWidth := ComboAIProvider.Canvas.TextWidth(ComboAIProvider.Items[I]) + 32;
    if LTextWidth > LMaxWidth then
      LMaxWidth := LTextWidth;
  end;

  SendMessage(ComboAIProvider.Handle, CB_SETDROPPEDWIDTH, LMaxWidth, 0);

  if ComboAIMode.HandleAllocated then
    SendMessage(ComboAIMode.Handle, CB_SETDROPPEDWIDTH, ComboAIMode.Width, 0);
end;

function TFRpAISelectionVCL.GetAITier: string;
begin
  case ComboAIProvider.ItemIndex of
    0: Result := 'Standard';
    1: Result := 'Precision';
  else
    Result := 'LocalAgent';
  end;
end;

function TFRpAISelectionVCL.GetAIMode: string;
begin
  if ComboAIMode.ItemIndex = 1 then
    Result := 'Reasoning'
  else
    Result := 'Fast';
end;

function TFRpAISelectionVCL.GetAgentSecret: string;
var
  LIdx: Integer;
begin
  Result := '';
  LIdx := ComboAIProvider.ItemIndex - 2;
  if (LIdx >= 0) and (LIdx < Length(FAgentEndpoints)) then
    Result := FAgentEndpoints[LIdx].AgentSecret;
end;

function TFRpAISelectionVCL.GetAgentAiId: Int64;
var
  LIdx: Integer;
begin
  Result := 0;
  LIdx := ComboAIProvider.ItemIndex - 2;
  if (LIdx >= 0) and (LIdx < Length(FAgentEndpoints)) then
    Result := FAgentEndpoints[LIdx].Id;
end;

procedure TFRpAISelectionVCL.AddAgentEndpoint(AId: Int64; const ASecret, AName: string; AOnline: Boolean);
var
  LLen: Integer;
begin
  LLen := Length(FAgentEndpoints);
  SetLength(FAgentEndpoints, LLen + 1);
  FAgentEndpoints[LLen].Id := AId;
  FAgentEndpoints[LLen].AgentSecret := ASecret;
  FAgentEndpoints[LLen].DisplayName := AName;
  FAgentEndpoints[LLen].IsOnline := AOnline;
  ComboAIProvider.Items.Add(AName);
  UpdateDropDownWidths;
end;

procedure TFRpAISelectionVCL.ClearAgentEndpoints;
begin
  SetLength(FAgentEndpoints, 0);
  while ComboAIProvider.Items.Count > 2 do
    ComboAIProvider.Items.Delete(ComboAIProvider.Items.Count - 1);
  if ComboAIProvider.ItemIndex >= ComboAIProvider.Items.Count then
    ComboAIProvider.ItemIndex := 0;
  ComboAIProviderChange(ComboAIProvider);
end;

function TFRpAISelectionVCL.AgentEndpointCount: Integer;
begin
  Result := Length(FAgentEndpoints);
end;

procedure TFRpAISelectionVCL.RestoreProviderSelection(const AAITier: string; AAgentAiId: Int64);
var
  I: Integer;
begin
  if SameText(AAITier, 'Precision') then
    ComboAIProvider.ItemIndex := 1
  else if SameText(AAITier, 'LocalAgent') and (AAgentAiId <> 0) then
  begin
    ComboAIProvider.ItemIndex := 0;
    for I := 0 to High(FAgentEndpoints) do
    begin
      if FAgentEndpoints[I].Id = AAgentAiId then
      begin
        ComboAIProvider.ItemIndex := I + 2;
        Break;
      end;
    end;
  end
  else
    ComboAIProvider.ItemIndex := 0;

  ComboAIProviderChange(ComboAIProvider);
end;

procedure TFRpAISelectionVCL.SetInferenceProgress(AActive: Boolean);
begin
  PNonInference.Visible := not AActive;
  PInferenceProgress.Visible := AActive;
  ClearProgressTokens;
  RefreshTokensCaption;
  if PProgressHost <> nil then
    PProgressHost.Constraints.MinWidth := 30;
  if PInferenceProgress <> nil then
    PInferenceProgress.Realign;
  UpdateSpinnerState;
  LayoutGaugeControls;
end;

procedure TFRpAISelectionVCL.TouchProgressToken(const AProgressId: string);
var
  LEntry: TRpProgressTokenEntry;
  LKey: string;
begin
  LKey := GetProgressTokenKey(AProgressId);
  if FProgressTokens.IndexOf(LKey) >= 0 then
    Exit;

  LEntry := EnsureProgressTokenEntry(AProgressId);
  UpdateProgressTokenLabel(LEntry);
  RefreshTokensCaption;
  if (PInferenceProgress <> nil) and PInferenceProgress.Visible then
    RefreshLayout;
end;

procedure TFRpAISelectionVCL.FinishProgressToken(const AProgressId: string);
var
  LIndex: Integer;
  LKey: string;
begin
  LKey := GetProgressTokenKey(AProgressId);
  LIndex := FProgressTokens.IndexOf(LKey);
  if LIndex < 0 then
    Exit;

  FProgressTokens.Objects[LIndex].Free;
  FProgressTokens.Delete(LIndex);
  RefreshTokensCaption;
  if (PInferenceProgress <> nil) and PInferenceProgress.Visible then
    RefreshLayout;
end;

procedure TFRpAISelectionVCL.UpdateTokens(AInTokens, AOutTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer = 0);
var
  LEntry: TRpProgressTokenEntry;
  LKey: string;
begin
  LKey := GetProgressTokenKey(AProgressId);
  if (AInTokens <= 0) and (AOutTokens <= 0) and (APrefillPercent <= 0) and
    (FProgressTokens.IndexOf(LKey) < 0) then
    Exit;

  LEntry := EnsureProgressTokenEntry(AProgressId);
  if AInTokens > LEntry.InputTokens then
    LEntry.InputTokens := AInTokens;
  if AOutTokens > LEntry.OutputTokens then
    LEntry.OutputTokens := AOutTokens;
  if APrefillPercent > LEntry.PrefillPercent then
    LEntry.PrefillPercent := APrefillPercent;
  UpdateProgressTokenLabel(LEntry);
  RefreshTokensCaption;
end;

procedure TFRpAISelectionVCL.BStopInferenceClick(Sender: TObject);
begin
  if Assigned(FOnStopRequest) then
    FOnStopRequest(Self);
end;

procedure TFRpAISelectionVCL.SpinnerTimerTimer(Sender: TObject);
begin
  if not SpinnerTimer.Enabled then
    Exit;
  FSpinnerAngle := (FSpinnerAngle + 24) mod 360;
  if PaintBoxProgress.Visible then
    PaintBoxProgress.Invalidate;
end;

procedure TFRpAISelectionVCL.UpdateSpinnerState;
var
  LShouldAnimate: Boolean;
begin
  LShouldAnimate := Visible and Assigned(PaintBoxProgress) and
    PaintBoxProgress.Visible and Assigned(PInferenceProgress) and
    PInferenceProgress.Visible;
  SpinnerTimer.Enabled := LShouldAnimate;
  if not LShouldAnimate then
  begin
    FSpinnerAngle := 270;
    if Assigned(PaintBoxProgress) then
      PaintBoxProgress.Invalidate;
  end;
end;

end.
