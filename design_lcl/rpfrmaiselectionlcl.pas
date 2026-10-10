{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpfrmaiselectionlcl                             }
{       AI Provider, Mode and Credit Gauge Frame        }
{       (LCL port of rpfrmaiselectionvcl)               }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpfrmaiselectionlcl;

{ Same public API as TFRpAISelectionVCL. A panel instead of a frame and the
  layout done in code (the LCL has no TGridPanel; the VCL positions most
  controls in code too). RefreshStatusInBackground runs CheckStatus in a
  TRpAsyncWorker instead of an anonymous thread. The unused TRpAITierType
  of the VCL unit is not declared (rpreportdesignercontracts has the real
  one). }

{$mode delphi}

interface

uses
  SysUtils, Classes, Types, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  rpjsonfpc, rpauthmanager, rpaithreadslcl, rpchatmodernstylelcl;

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

  TAgentEndpointInfo = record
    Id: Int64;
    AgentSecret: string;
    DisplayName: string;
    IsOnline: Boolean;
  end;

  TFRpAISelectionLCL = class(TCustomPanel)
  private
    FGaugeValue: Double; // 0.0 to 1.0
    FSpinnerAngle: Integer;
    FAgentEndpoints: array of TAgentEndpointInfo;
    FProgressTokens: TStringList;
    FOnStopRequest: TNotifyEvent;
    FOnProviderChange: TNotifyEvent;
    FShowGauge: Boolean;
    FLblProvider: TLabel;
    FLblMode: TLabel;
    FGaugeHintWindow: THintWindow;
    procedure BuildControls;
    procedure PaintBoxGaugeMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxGaugeShowHint(Sender: TObject; HintInfo: PHintInfo);
    procedure ClearProgressTokens;
    function EnsureProgressTokenEntry(const AProgressId: string): TRpProgressTokenEntry;
    function FormatProgressTokenId(const AProgressId: string): string;
    function GetProgressTokenKey(const AProgressId: string): string;
    procedure UpdateProgressTokenLabel(AEntry: TRpProgressTokenEntry);
    procedure RefreshTokensCaption;
    procedure LayoutNonInferenceControls;
    procedure LayoutInferenceControls;
    procedure LayoutGaugeControls;
    procedure UpdateGaugeVisibility;
    procedure SetGaugeValue(const Value: Double);
    procedure SetShowGauge(const Value: Boolean);
    procedure UpdateSpinnerState;
    procedure ApplyModernStyling;
    function GetAITier: string;
    function GetAIMode: string;
    function GetAgentSecret: string;
    function GetAgentAiId: Int64;
    function GetInferenceActive: Boolean;
    procedure UpdateGaugeDisplay;
  protected
    procedure Resize; override;
    procedure VisibleChanged; override;
  public
    PAI: TPanel;
    PNonInference: TPanel;
    PProviderHost: TPanel;
    PModeHost: TPanel;
    ComboAIProvider: TComboBox;
    ComboAIMode: TComboBox;
    PInferenceProgress: TPanel;
    BStopInference: TButton;
    PTokensHost: TPanel;
    LTokensInfo: TLabel;
    PProgressHost: TPanel;
    PGaugeHost: TPanel;
    PaintBoxGauge: TPaintBox;
    PaintBoxProgress: TPaintBox;
    SpinnerTimer: TTimer;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure PaintBoxGaugePaint(Sender: TObject);
    procedure PaintBoxProgressPaint(Sender: TObject);
    procedure ComboAIModeChange(Sender: TObject);
    procedure ComboAIProviderChange(Sender: TObject);
    procedure BStopInferenceClick(Sender: TObject);
    procedure SpinnerTimerTimer(Sender: TObject);
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
    // Text of the token rows (tests)
    function ProgressTokensText: string;
    // The gauge hint opened by a click: hover hints are unreliable on some
    // widgetsets (Cocoa), this one shows at once and hides by itself
    procedure ShowGaugeHint;
    procedure HideGaugeHint;
    function GaugeHintVisible: Boolean;
    property GaugeValue: Double read FGaugeValue write SetGaugeValue;
    property ShowGauge: Boolean read FShowGauge write SetShowGauge;
    property InferenceActive: Boolean read GetInferenceActive;
    property OnStopRequest: TNotifyEvent read FOnStopRequest write FOnStopRequest;
    // The provider (AITier) changed: chosen or restored
    property OnProviderChange: TNotifyEvent read FOnProviderChange write FOnProviderChange;
    // Properties for the HTTP driver
    property AITier: string read GetAITier;
    property AIMode: string read GetAIMode;
    property AgentSecret: string read GetAgentSecret;
    property AgentAiId: Int64 read GetAgentAiId;
  end;

implementation

uses
  rpmdconsts, LazUTF8;

const
  CAISelectionLabelHeight = 16;
  CAISelectionSpacingV = 2;
  CAISelectionVerticalPadding = 6;
  CAISelectionGaugeSize = 30;
  CAISelectionGaugeColumn = 44;
  CAISelectionLegacyNormalHeight = 50;
  CAISelectionInferenceLineHeight = 18;
  CAISelectionGaugeHintMs = 3000;
  CAISelectionGaugeHintGap = 4;

type
  TRpCheckStatusWorker = class(TRpAsyncWorker)
  public
    DelayMs: Cardinal;
  protected
    procedure Run; override;
  end;

procedure TRpCheckStatusWorker.Run;
begin
  if DelayMs > 0 then
  begin
    TRpAuthManager.Instance.Log(
      'RefreshStatusInBackground: delaying startup auth status request by ' +
      IntToStr(DelayMs) + ' ms for testing.');
    Sleep(DelayMs);
  end;
  TRpAuthManager.Instance.CheckStatus;
end;

destructor TRpProgressTokenEntry.Destroy;
begin
  RowLabel.Free;
  inherited Destroy;
end;

{ TFRpAISelectionLCL }

constructor TFRpAISelectionLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  FGaugeValue := 0.0;
  FSpinnerAngle := 270;
  FShowGauge := True;
  FProgressTokens := TStringList.Create;
  BuildControls;
  Height := PreferredHeight;
  ComboAIProvider.ItemIndex := 0; // Standard
  ComboAIMode.ItemIndex := 0;     // Fast
  SpinnerTimer.Enabled := False;
  ApplyModernStyling;
  UpdateGaugeVisibility;
  RefreshState;
end;

destructor TFRpAISelectionLCL.Destroy;
begin
  SpinnerTimer.Enabled := False;
  ClearProgressTokens;
  FProgressTokens.Free;
  inherited Destroy;
end;

procedure TFRpAISelectionLCL.BuildControls;

  function NewPanel(AParent: TWinControl): TPanel;
  begin
    Result := TPanel.Create(Self);
    Result.Parent := AParent;
    Result.BevelOuter := bvNone;
    Result.Caption := '';
  end;

begin
  PAI := NewPanel(Self);
  PAI.Align := alClient;

  PNonInference := NewPanel(PAI);
  PNonInference.Align := alClient;

  // The combos fill their host (LayoutNonInferenceControls): anchored on both
  // sides their width is fixed, so AutoSize only sets the widgetset height.
  // Cocoa gives a combo a preferred width, and AutoSize setting it back on
  // every Resize would loop.
  PProviderHost := NewPanel(PNonInference);
  ComboAIProvider := TComboBox.Create(Self);
  ComboAIProvider.Parent := PProviderHost;
  ComboAIProvider.Anchors := [akLeft, akTop, akRight];
  ComboAIProvider.Style := csDropDownList;
  ComboAIProvider.Items.Add(TranslateStr(1518, 'Standard'));
  ComboAIProvider.Items.Add(TranslateStr(1519, 'Precision'));
  ComboAIProvider.OnChange := ComboAIProviderChange;

  PModeHost := NewPanel(PNonInference);
  ComboAIMode := TComboBox.Create(Self);
  ComboAIMode.Parent := PModeHost;
  ComboAIMode.Anchors := [akLeft, akTop, akRight];
  ComboAIMode.Style := csDropDownList;
  ComboAIMode.Items.Add(TranslateStr(1520, 'Fast'));
  ComboAIMode.Items.Add(TranslateStr(1521, 'Reasoning'));
  ComboAIMode.OnChange := ComboAIModeChange;

  PGaugeHost := NewPanel(PNonInference);
  PGaugeHost.ShowHint := True;
  PaintBoxGauge := TPaintBox.Create(Self);
  PaintBoxGauge.Parent := PGaugeHost;
  PaintBoxGauge.OnPaint := PaintBoxGaugePaint;
  PaintBoxGauge.ShowHint := True;
  PaintBoxGauge.Cursor := crHandPoint;
  PaintBoxGauge.OnMouseUp := PaintBoxGaugeMouseUp;
  PaintBoxGauge.OnShowHint := PaintBoxGaugeShowHint;

  PInferenceProgress := NewPanel(PAI);
  PInferenceProgress.Align := alClient;
  PInferenceProgress.Visible := False;

  BStopInference := TButton.Create(Self);
  BStopInference.Parent := PInferenceProgress;
  BStopInference.Caption := TranslateStr(1522, 'Stop');
  BStopInference.OnClick := BStopInferenceClick;

  PTokensHost := NewPanel(PInferenceProgress);
  LTokensInfo := TLabel.Create(Self);
  LTokensInfo.Parent := PTokensHost;
  LTokensInfo.Caption := 'Tokens (In/Out): 0 / 0';

  PProgressHost := NewPanel(PInferenceProgress);
  PaintBoxProgress := TPaintBox.Create(Self);
  PaintBoxProgress.Parent := PProgressHost;
  PaintBoxProgress.OnPaint := PaintBoxProgressPaint;

  SpinnerTimer := TTimer.Create(Self);
  SpinnerTimer.Enabled := False;
  SpinnerTimer.Interval := 90;
  SpinnerTimer.OnTimer := SpinnerTimerTimer;
end;

procedure TFRpAISelectionLCL.ApplyModernStyling;
begin
  // Fonts are inherited from the parent; only backgrounds and labels change
  TRpChatStyle.StylePanelBg(PAI);
  TRpChatStyle.StylePanelBg(PNonInference);
  TRpChatStyle.StylePanelBg(PInferenceProgress);
  TRpChatStyle.StylePanelBg(PProviderHost);
  TRpChatStyle.StylePanelBg(PModeHost);
  TRpChatStyle.StylePanelBg(PGaugeHost);
  TRpChatStyle.StylePanelBg(PTokensHost);
  TRpChatStyle.StylePanelBg(PProgressHost);

  // Micro labels above the combos
  if FLblProvider = nil then
  begin
    FLblProvider := TLabel.Create(Self);
    FLblProvider.Parent := PProviderHost;
    FLblProvider.Caption := UTF8UpperCase(TranslateStr(1516, 'Provider'));
    FLblProvider.AutoSize := False;
    FLblProvider.Alignment := taLeftJustify;
    FLblProvider.Layout := tlBottom;
    FLblProvider.Transparent := True;
  end;
  if FLblMode = nil then
  begin
    FLblMode := TLabel.Create(Self);
    FLblMode.Parent := PModeHost;
    FLblMode.Caption := UTF8UpperCase(TranslateStr(1517, 'Mode'));
    FLblMode.AutoSize := False;
    FLblMode.Alignment := taLeftJustify;
    FLblMode.Layout := tlBottom;
    FLblMode.Transparent := True;
  end;

  TRpChatStyle.StyleInputControl(ComboAIProvider);
  TRpChatStyle.StyleInputControl(ComboAIMode);

  LTokensInfo.AutoSize := False;
  LTokensInfo.Alignment := taLeftJustify;
  LTokensInfo.Layout := tlTop;
  LTokensInfo.Transparent := True;
  LTokensInfo.WordWrap := True;
end;

procedure TFRpAISelectionLCL.RefreshStatusInBackground(ADelayBeforeRequestMs: Cardinal);
var
  LWorker: TRpCheckStatusWorker;
begin
  // No mailbox: the result reaches the forms through the auth events
  LWorker := TRpCheckStatusWorker.Create(nil);
  LWorker.DelayMs := ADelayBeforeRequestMs;
  LWorker.Start;
end;

procedure TFRpAISelectionLCL.Resize;
begin
  inherited Resize;
  if PAI <> nil then
  begin
    LayoutNonInferenceControls;
    LayoutInferenceControls;
    LayoutGaugeControls;
    if PInferenceProgress.Visible then
      RefreshTokensCaption;
  end;
end;

procedure TFRpAISelectionLCL.VisibleChanged;
begin
  inherited VisibleChanged;
  if SpinnerTimer <> nil then
    UpdateSpinnerState;
  if not Visible then
    HideGaugeHint;
end;

procedure TFRpAISelectionLCL.RefreshLayout;
var
  LPreferredHeight: Integer;
begin
  LPreferredHeight := PreferredHeight;
  // Only when the parent does not size it (alClient would loop)
  if (Height <> LPreferredHeight) and (Align in [alNone, alTop, alBottom]) then
    Height := LPreferredHeight;
  UpdateGaugeVisibility;
  LayoutNonInferenceControls;
  LayoutInferenceControls;
  LayoutGaugeControls;
  if PInferenceProgress.Visible then
    RefreshTokensCaption;
  Invalidate;
end;

function TFRpAISelectionLCL.PreferredHeight: Integer;
var
  LContentHeight, LGaugeSize, LLineCount, LLineHeight, LNormalHeight,
    LVerticalPadding, LComboHeight: Integer;
begin
  LNormalHeight := Scale(CAISelectionLegacyNormalHeight);
  // Combos of some widgetsets are taller than the VCL ones
  if ComboAIProvider <> nil then
  begin
    LComboHeight := ComboAIProvider.Height;
    if Scale(CAISelectionLabelHeight + CAISelectionSpacingV + 4) + LComboHeight > LNormalHeight then
      LNormalHeight := Scale(CAISelectionLabelHeight + CAISelectionSpacingV + 4) + LComboHeight;
  end;
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

procedure TFRpAISelectionLCL.LayoutNonInferenceControls;
var
  LabelH, SpacingV, LComboHeight, LGaugeWidth, LWidth, LHalf: Integer;

  procedure PositionPair(AHost: TPanel; ALabel: TLabel; ACombo: TComboBox);
  var
    LComboTop: Integer;
  begin
    if (AHost = nil) or (ACombo = nil) or (AHost.ClientWidth <= 0) then
      Exit;
    if ALabel <> nil then
      ALabel.SetBounds(0, 0, AHost.ClientWidth, LabelH);
    LComboTop := LabelH + SpacingV;
    if (AHost.ClientHeight - LComboTop) < LComboHeight then
      LComboTop := AHost.ClientHeight - LComboHeight;
    if LComboTop < 0 then
      LComboTop := 0;
    ACombo.SetBounds(0, LComboTop, AHost.ClientWidth, ACombo.Height);
  end;

begin
  LabelH := Scale(CAISelectionLabelHeight);
  SpacingV := Scale(CAISelectionSpacingV);
  LComboHeight := ComboAIProvider.Height;
  if ComboAIMode.Height > LComboHeight then
    LComboHeight := ComboAIMode.Height;
  if LComboHeight <= 0 then
    LComboHeight := 22;

  // Provider 50% | Mode 50% | gauge column (the VCL TGridPanel)
  LWidth := PNonInference.ClientWidth;
  if PGaugeHost.Visible then
    LGaugeWidth := Scale(CAISelectionGaugeColumn)
  else
    LGaugeWidth := 0;
  LHalf := (LWidth - LGaugeWidth) div 2;
  PProviderHost.SetBounds(0, 0, LHalf - Scale(4), PNonInference.ClientHeight);
  PModeHost.SetBounds(LHalf + Scale(4), 0, LWidth - LGaugeWidth - LHalf - Scale(8),
    PNonInference.ClientHeight);
  PGaugeHost.SetBounds(LWidth - LGaugeWidth, 0, LGaugeWidth, PNonInference.ClientHeight);

  PositionPair(PProviderHost, FLblProvider, ComboAIProvider);
  PositionPair(PModeHost, FLblMode, ComboAIMode);
end;

procedure TFRpAISelectionLCL.LayoutInferenceControls;
var
  LWidth, LHeight, LStopWidth, LProgressWidth, LButtonHeight: Integer;
begin
  // Stop | token rows | spinner (the VCL GridInference)
  LWidth := PInferenceProgress.ClientWidth;
  LHeight := PInferenceProgress.ClientHeight;
  LStopWidth := TRpChatStyle.TextWidthOf(BStopInference.Font, BStopInference.Caption) + Scale(24);
  if LStopWidth < Scale(56) then
    LStopWidth := Scale(56);
  LButtonHeight := Scale(30);
  if LButtonHeight > LHeight then
    LButtonHeight := LHeight;
  BStopInference.SetBounds(Scale(4), (LHeight - LButtonHeight) div 2, LStopWidth, LButtonHeight);
  LProgressWidth := Scale(CAISelectionGaugeColumn);
  PProgressHost.SetBounds(LWidth - LProgressWidth, 0, LProgressWidth, LHeight);
  PTokensHost.SetBounds(BStopInference.Left + LStopWidth + Scale(8), 0,
    LWidth - LProgressWidth - (BStopInference.Left + LStopWidth + Scale(16)), LHeight);
end;

procedure TFRpAISelectionLCL.LayoutGaugeControls;
var
  GaugeSize, LLeft, LTop: Integer;
begin
  GaugeSize := Scale(CAISelectionGaugeSize);
  if PGaugeHost.Visible then
  begin
    LLeft := (PGaugeHost.ClientWidth - GaugeSize) div 2;
    LTop := (PGaugeHost.ClientHeight - GaugeSize) div 2;
    if LLeft < 0 then
      LLeft := 0;
    if LTop < 0 then
      LTop := 0;
    PaintBoxGauge.SetBounds(LLeft, LTop, GaugeSize, GaugeSize);
  end;
  LLeft := (PProgressHost.ClientWidth - GaugeSize) div 2;
  LTop := (PProgressHost.ClientHeight - GaugeSize) div 2;
  if LLeft < 0 then
    LLeft := 0;
  if LTop < 0 then
    LTop := 0;
  PaintBoxProgress.SetBounds(LLeft, LTop, GaugeSize, GaugeSize);
end;

procedure TFRpAISelectionLCL.UpdateGaugeVisibility;
var
  LShowGauge: Boolean;
begin
  LShowGauge := FShowGauge and (ComboAIProvider.ItemIndex < 2);
  if PGaugeHost.Visible <> LShowGauge then
  begin
    if not LShowGauge then
      HideGaugeHint;
    PGaugeHost.Visible := LShowGauge;
    PaintBoxGauge.Visible := LShowGauge;
    LayoutNonInferenceControls;
  end;
end;

procedure TFRpAISelectionLCL.RefreshState;
begin
  LayoutGaugeControls;
  UpdateGaugeDisplay;
end;

procedure TFRpAISelectionLCL.UpdateGaugeDisplay;
var
  LProfile: TRpProfile;
  LUsed, LMax, LLeft: Int64;
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
    begin
      // Free credits (a guest, the Free tier) do not renew: what is left
      LLeft := LMax - LUsed;
      if LLeft < 0 then
        LLeft := 0;
      LHint := TranslateStr(1524, 'Free Credits') + LineEnding +
        Format(TranslateStr(1835, 'Left: %s of %s'),
        [FormatFloat('#,##0', LLeft), FormatFloat('#,##0', LMax)]);
    end
    else
    begin
      LHint := TranslateStr(1525, 'Daily Credit Usage') + LineEnding;
      LHint := LHint + TranslateStr(1526, 'Used') + ': ' + FormatFloat('#,##0', LUsed) +
        ' (' + FormatFloat('0', LPct) + '%)' + LineEnding;
      LHint := LHint + TranslateStr(1527, 'Max') + ': ' + FormatFloat('#,##0', LMax);
      if LProfile.ServerDay > 0 then
        LHint := LHint + LineEnding + DateToStr(LProfile.ServerDay);
    end;
  end
  else
  begin
    LHint := TranslateStr(1524, 'Free Credits') + LineEnding +
      TranslateStr(1526, 'Used') + ': 0 (0%)' + LineEnding +
      TranslateStr(1527, 'Max') + ': 0';
    FGaugeValue := 0.0;
  end;
  // A guest also reads what signing in gives: the login gift, credits that never expire
  if not LAuth.IsLoggedIn then
    LHint := LHint + LineEnding + Format(TranslateStr(1833, 'Sign in and get %s free credits that never expire'),
      [FormatFloat('#,##0', LAuth.GetLoginGiftCredits)]);
  PaintBoxGauge.Hint := LHint;
  PaintBoxGauge.ShowHint := True;
  SetGaugeValue(FGaugeValue);
  // The credits changed while the clicked hint is up: show the new text
  if GaugeHintVisible and (FGaugeHintWindow.Caption <> LHint) then
    ShowGaugeHint;
end;

procedure TFRpAISelectionLCL.PaintBoxGaugeMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then
    Exit;
  // A second click closes it
  if GaugeHintVisible then
    HideGaugeHint
  else
    ShowGaugeHint;
end;

procedure TFRpAISelectionLCL.PaintBoxGaugeShowHint(Sender: TObject;
  HintInfo: PHintInfo);
begin
  // No hover hint on top of the clicked one
  if GaugeHintVisible then
    HintInfo^.HintStr := '';
end;

procedure TFRpAISelectionLCL.ShowGaugeHint;
var
  LText: string;
  LRect, LWork: TRect;
  LBelow, LAbove: TPoint;
  LMonitor: TMonitor;
  LWidth, LHeight, LLeft, LTop: Integer;
begin
  LText := PaintBoxGauge.Hint;
  if (LText = '') or not PaintBoxGauge.IsVisible then
    Exit;
  Application.CancelHint;
  if FGaugeHintWindow = nil then
  begin
    FGaugeHintWindow := HintWindowClass.Create(Self);
    FGaugeHintWindow.AutoHide := True;
    FGaugeHintWindow.HideInterval := CAISelectionGaugeHintMs;
  end;
  // Below the gauge, right edges aligned (the gauge is the right column);
  // above it when the screen ends first. ActivateHint keeps it on the monitor.
  LBelow := PaintBoxGauge.ClientToScreen(Point(PaintBoxGauge.Width,
    PaintBoxGauge.Height + Scale(CAISelectionGaugeHintGap)));
  LAbove := PaintBoxGauge.ClientToScreen(Point(PaintBoxGauge.Width,
    -Scale(CAISelectionGaugeHintGap)));
  LMonitor := Screen.MonitorFromPoint(LBelow);
  if LMonitor <> nil then
    LWork := LMonitor.WorkareaRect
  else
    LWork := Screen.WorkAreaRect;
  LRect := FGaugeHintWindow.CalcHintRect((LWork.Right - LWork.Left) div 2, LText, nil);
  LWidth := LRect.Right - LRect.Left;
  LHeight := LRect.Bottom - LRect.Top;
  LLeft := LBelow.X - LWidth;
  LTop := LBelow.Y;
  if (LTop + LHeight > LWork.Bottom) and (LAbove.Y - LHeight >= LWork.Top) then
    LTop := LAbove.Y - LHeight;
  // Hide first: ActivateHint does nothing (nor restarts the timer) when the
  // same text is already shown in the same place
  FGaugeHintWindow.Hide;
  FGaugeHintWindow.ActivateHint(Rect(LLeft, LTop, LLeft + LWidth, LTop + LHeight), LText);
end;

procedure TFRpAISelectionLCL.HideGaugeHint;
begin
  if FGaugeHintWindow <> nil then
    FGaugeHintWindow.Hide;
end;

function TFRpAISelectionLCL.GaugeHintVisible: Boolean;
begin
  Result := (FGaugeHintWindow <> nil) and FGaugeHintWindow.Visible;
end;

procedure TFRpAISelectionLCL.UpdateFromUserProfile(AProfile: TJSONObject);
begin
  TRpAuthManager.Instance.UpdateProfileFromJson(AProfile);
end;

procedure TFRpAISelectionLCL.SetGaugeValue(const Value: Double);
begin
  FGaugeValue := Value;
  if PaintBoxGauge <> nil then
    PaintBoxGauge.Invalidate;
end;

procedure TFRpAISelectionLCL.ClearProgressTokens;
var
  I: Integer;
begin
  if FProgressTokens = nil then
    Exit;
  for I := 0 to FProgressTokens.Count - 1 do
    FProgressTokens.Objects[I].Free;
  FProgressTokens.Clear;
end;

function TFRpAISelectionLCL.GetProgressTokenKey(const AProgressId: string): string;
begin
  Result := Trim(AProgressId);
  if Result = '' then
    Result := '__default__';
end;

function TFRpAISelectionLCL.FormatProgressTokenId(const AProgressId: string): string;
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

function TFRpAISelectionLCL.EnsureProgressTokenEntry(
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
  Result.RowLabel := TLabel.Create(nil);
  Result.RowLabel.Parent := PTokensHost;
  Result.RowLabel.AutoSize := False;
  Result.RowLabel.Alignment := taLeftJustify;
  Result.RowLabel.Layout := tlCenter;
  Result.RowLabel.Transparent := True;
  Result.RowLabel.WordWrap := False;
  Result.RowLabel.Visible := False;
  FProgressTokens.AddObject(LKey, Result);
  UpdateProgressTokenLabel(Result);
end;

procedure TFRpAISelectionLCL.UpdateProgressTokenLabel(AEntry: TRpProgressTokenEntry);
var
  LIndex: Integer;
  LPrefix, LIdText, LInputText: string;
begin
  if (AEntry = nil) or (AEntry.RowLabel = nil) then
    Exit;
  LIndex := FProgressTokens.IndexOf(AEntry.ProgressId);
  if LIndex = 0 then
    LPrefix := IntToStr(FProgressTokens.Count) + '- '
  else
    LPrefix := '';
  // The VCL writes "% de prefill" (Spanish) here
  if (AEntry.PrefillPercent > 0) and (AEntry.OutputTokens = 0) then
    LInputText := IntToStr(AEntry.PrefillPercent) + '% prefill'
  else
    LInputText := IntToStr(AEntry.InputTokens);
  LIdText := FormatProgressTokenId(AEntry.ProgressId);
  AEntry.RowLabel.Caption := LPrefix + 'Input/Output: ' + LInputText +
    ' / ' + IntToStr(AEntry.OutputTokens) + LIdText;
end;

procedure TFRpAISelectionLCL.RefreshTokensCaption;
var
  I, LLineHeight, LTop: Integer;
  LEntry: TRpProgressTokenEntry;
begin
  LLineHeight := Scale(CAISelectionInferenceLineHeight);
  LTokensInfo.SetBounds(0, 0, PTokensHost.ClientWidth, PTokensHost.ClientHeight);
  LTokensInfo.Visible := FProgressTokens.Count = 0;
  if LTokensInfo.Visible then
    LTokensInfo.Caption := TranslateStr(1523, 'Waiting for inference progress...');
  LTop := (PTokensHost.ClientHeight - FProgressTokens.Count * LLineHeight) div 2;
  if LTop < 0 then
    LTop := 0;
  for I := 0 to FProgressTokens.Count - 1 do
  begin
    LEntry := TRpProgressTokenEntry(FProgressTokens.Objects[I]);
    if (LEntry = nil) or (LEntry.RowLabel = nil) then
      Continue;
    UpdateProgressTokenLabel(LEntry);
    LEntry.RowLabel.SetBounds(0, LTop, PTokensHost.ClientWidth, LLineHeight);
    LEntry.RowLabel.Visible := True;
    Inc(LTop, LLineHeight);
  end;
end;

function TFRpAISelectionLCL.ProgressTokensText: string;
var
  I: Integer;
  LEntry: TRpProgressTokenEntry;
begin
  Result := '';
  for I := 0 to FProgressTokens.Count - 1 do
  begin
    LEntry := TRpProgressTokenEntry(FProgressTokens.Objects[I]);
    UpdateProgressTokenLabel(LEntry);
    if Result <> '' then
      Result := Result + LineEnding;
    Result := Result + LEntry.RowLabel.Caption;
  end;
end;

procedure TFRpAISelectionLCL.SetShowGauge(const Value: Boolean);
begin
  if FShowGauge = Value then
    Exit;
  FShowGauge := Value;
  UpdateGaugeVisibility;
  LayoutGaugeControls;
  Invalidate;
end;

procedure TFRpAISelectionLCL.PaintBoxGaugePaint(Sender: TObject);
var
  R: TRect;
  IndicatorColor, TextColor: TColor;
  DisplayValue: Double;
  PercentageValue: Integer;
begin
  R := PaintBoxGauge.ClientRect;
  PaintBoxGauge.Canvas.Brush.Color := ClrBg;
  PaintBoxGauge.Canvas.Brush.Style := bsSolid;
  PaintBoxGauge.Canvas.FillRect(R);

  DisplayValue := FGaugeValue;
  if DisplayValue < 0 then
    DisplayValue := 0;
  if DisplayValue > 1 then
    DisplayValue := 1;
  if DisplayValue < 0.5 then
    IndicatorColor := ClrSuccess
  else if DisplayValue < 0.75 then
    IndicatorColor := RGBToColor(255, 193, 7)  // amber
  else if DisplayValue < 0.9 then
    IndicatorColor := RGBToColor(255, 152, 0)  // orange
  else
    IndicatorColor := ClrDanger;
  if DisplayValue > 0 then
    TextColor := IndicatorColor
  else
    TextColor := ClrSubText;

  PercentageValue := Round(DisplayValue * 100);
  if PercentageValue < 0 then
    PercentageValue := 0
  else if PercentageValue > 100 then
    PercentageValue := 100;
  TRpChatStyle.DrawCircularGauge(PaintBoxGauge.Canvas, R, DisplayValue,
    IntToStr(PercentageValue), ClrBorder, IndicatorColor, TextColor);
end;

procedure TFRpAISelectionLCL.PaintBoxProgressPaint(Sender: TObject);
var
  R: TRect;
begin
  R := PaintBoxProgress.ClientRect;
  PaintBoxProgress.Canvas.Brush.Color := ClrBg;
  PaintBoxProgress.Canvas.Brush.Style := bsSolid;
  PaintBoxProgress.Canvas.FillRect(R);
  InflateRect(R, -3, -3);
  TRpChatStyle.DrawAntialiasedArc(PaintBoxProgress.Canvas, R, 0, 360, ClrBorder, 3);
  TRpChatStyle.DrawAntialiasedArc(PaintBoxProgress.Canvas, R, FSpinnerAngle, -110, ClrAccent, 3);
end;

procedure TFRpAISelectionLCL.ComboAIModeChange(Sender: TObject);
begin
  // Mode changed: Fast or Reasoning
end;

procedure TFRpAISelectionLCL.ComboAIProviderChange(Sender: TObject);
begin
  UpdateGaugeVisibility;
  LayoutGaugeControls;
  if Assigned(FOnProviderChange) then
    FOnProviderChange(Self);
end;

function TFRpAISelectionLCL.GetAITier: string;
begin
  case ComboAIProvider.ItemIndex of
    0: Result := 'Standard';
    1: Result := 'Precision';
  else
    Result := 'LocalAgent';
  end;
end;

function TFRpAISelectionLCL.GetAIMode: string;
begin
  if ComboAIMode.ItemIndex = 1 then
    Result := 'Reasoning'
  else
    Result := 'Fast';
end;

function TFRpAISelectionLCL.GetAgentSecret: string;
var
  LIdx: Integer;
begin
  Result := '';
  LIdx := ComboAIProvider.ItemIndex - 2;
  if (LIdx >= 0) and (LIdx < Length(FAgentEndpoints)) then
    Result := FAgentEndpoints[LIdx].AgentSecret;
end;

function TFRpAISelectionLCL.GetAgentAiId: Int64;
var
  LIdx: Integer;
begin
  Result := 0;
  LIdx := ComboAIProvider.ItemIndex - 2;
  if (LIdx >= 0) and (LIdx < Length(FAgentEndpoints)) then
    Result := FAgentEndpoints[LIdx].Id;
end;

function TFRpAISelectionLCL.GetInferenceActive: Boolean;
begin
  Result := PInferenceProgress.Visible;
end;

procedure TFRpAISelectionLCL.AddAgentEndpoint(AId: Int64; const ASecret, AName: string;
  AOnline: Boolean);
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
end;

procedure TFRpAISelectionLCL.ClearAgentEndpoints;
var
  LWasAgent: Boolean;
begin
  // Windows leaves no selection when the selected item is deleted, Qt
  // selects another one: an agent selection always goes back to Standard
  LWasAgent := ComboAIProvider.ItemIndex >= 2;
  SetLength(FAgentEndpoints, 0);
  while ComboAIProvider.Items.Count > 2 do
    ComboAIProvider.Items.Delete(ComboAIProvider.Items.Count - 1);
  if LWasAgent or (ComboAIProvider.ItemIndex >= ComboAIProvider.Items.Count) or
    (ComboAIProvider.ItemIndex < 0) then
    ComboAIProvider.ItemIndex := 0;
  ComboAIProviderChange(ComboAIProvider);
end;

function TFRpAISelectionLCL.AgentEndpointCount: Integer;
begin
  Result := Length(FAgentEndpoints);
end;

procedure TFRpAISelectionLCL.RestoreProviderSelection(const AAITier: string;
  AAgentAiId: Int64);
var
  I: Integer;
begin
  if SameText(AAITier, 'Precision') then
    ComboAIProvider.ItemIndex := 1
  else if SameText(AAITier, 'LocalAgent') and (AAgentAiId <> 0) then
  begin
    ComboAIProvider.ItemIndex := 0;
    for I := 0 to High(FAgentEndpoints) do
      if FAgentEndpoints[I].Id = AAgentAiId then
      begin
        ComboAIProvider.ItemIndex := I + 2;
        Break;
      end;
  end
  else
    ComboAIProvider.ItemIndex := 0;
  ComboAIProviderChange(ComboAIProvider);
end;

procedure TFRpAISelectionLCL.SetInferenceProgress(AActive: Boolean);
begin
  if AActive then
    HideGaugeHint;
  PNonInference.Visible := not AActive;
  PInferenceProgress.Visible := AActive;
  ClearProgressTokens;
  LayoutInferenceControls;
  RefreshTokensCaption;
  UpdateSpinnerState;
  LayoutGaugeControls;
end;

procedure TFRpAISelectionLCL.TouchProgressToken(const AProgressId: string);
var
  LEntry: TRpProgressTokenEntry;
begin
  if FProgressTokens.IndexOf(GetProgressTokenKey(AProgressId)) >= 0 then
    Exit;
  LEntry := EnsureProgressTokenEntry(AProgressId);
  UpdateProgressTokenLabel(LEntry);
  RefreshTokensCaption;
  if PInferenceProgress.Visible then
    RefreshLayout;
end;

procedure TFRpAISelectionLCL.FinishProgressToken(const AProgressId: string);
var
  LIndex: Integer;
begin
  LIndex := FProgressTokens.IndexOf(GetProgressTokenKey(AProgressId));
  if LIndex < 0 then
    Exit;
  FProgressTokens.Objects[LIndex].Free;
  FProgressTokens.Delete(LIndex);
  RefreshTokensCaption;
  if PInferenceProgress.Visible then
    RefreshLayout;
end;

procedure TFRpAISelectionLCL.UpdateTokens(AInTokens, AOutTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
var
  LEntry: TRpProgressTokenEntry;
begin
  if (AInTokens <= 0) and (AOutTokens <= 0) and (APrefillPercent <= 0) and
    (FProgressTokens.IndexOf(GetProgressTokenKey(AProgressId)) < 0) then
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

procedure TFRpAISelectionLCL.BStopInferenceClick(Sender: TObject);
begin
  if Assigned(FOnStopRequest) then
    FOnStopRequest(Self);
end;

procedure TFRpAISelectionLCL.SpinnerTimerTimer(Sender: TObject);
begin
  if not SpinnerTimer.Enabled then
    Exit;
  FSpinnerAngle := (FSpinnerAngle + 24) mod 360;
  if PaintBoxProgress.Visible then
    PaintBoxProgress.Invalidate;
end;

procedure TFRpAISelectionLCL.UpdateSpinnerState;
var
  LShouldAnimate: Boolean;
begin
  LShouldAnimate := Visible and PaintBoxProgress.Visible and PInferenceProgress.Visible;
  SpinnerTimer.Enabled := LShouldAnimate;
  if not LShouldAnimate then
  begin
    FSpinnerAngle := 270;
    PaintBoxProgress.Invalidate;
  end;
end;

end.
