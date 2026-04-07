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
  rpauthmanager;

type
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
    FOnStopRequest: TNotifyEvent;
    procedure CMVisibleChanged(var Message: TMessage); message CM_VISIBLECHANGED;
    procedure DrawCircularArc(ACanvas: TCanvas; const ARect: TRect;
      AStartAngle, ASweepAngle: Double; AColor: TColor; APenWidth: Integer);
    procedure LayoutNonInferenceControls;
    procedure LayoutGaugeControls;
    procedure SetGaugeValue(const Value: Double);
    procedure UpdateSpinnerState;
    procedure UpdateDropDownWidths;
    function GetPointOnCircle(const ARect: TRect; const AAngleDegrees: Double): TPoint;
    function GetAITier: string;
    function GetAIMode: string;
    function GetAgentSecret: string;
    function GetAgentAiId: Int64;
    procedure UpdateGaugeDisplay;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Resize; override;
    procedure RefreshLayout;
    procedure RefreshStatusInBackground;
    procedure RefreshState;
    procedure UpdateFromUserProfile(AProfile: TJSONObject);
    procedure AddAgentEndpoint(AId: Int64; const ASecret, AName: string; AOnline: Boolean);
    procedure ClearAgentEndpoints;
    procedure RestoreProviderSelection(const AAITier: string; AAgentAiId: Int64);
    function AgentEndpointCount: Integer;
    procedure SetInferenceProgress(AActive: Boolean);
    procedure UpdateTokens(AInTokens, AOutTokens: Integer);
    property GaugeValue: Double read FGaugeValue write SetGaugeValue;
    property OnStopRequest: TNotifyEvent read FOnStopRequest write FOnStopRequest;
    // Properties for the HTTP driver
    property AITier: string read GetAITier;
    property AIMode: string read GetAIMode;
    property AgentSecret: string read GetAgentSecret;
    property AgentAiId: Int64 read GetAgentAiId;
  end;

implementation

{$R *.dfm}

constructor TFRpAISelectionVCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGaugeValue := 0.0;
  FSpinnerAngle := 270;
  ComboAIProvider.Align := alTop;
  ComboAIMode.Align := alTop;
  ComboAIProvider.ItemIndex := 0; // Standard
  ComboAIMode.ItemIndex := 0;    // Fast
  SpinnerTimer.Enabled := False;
  LayoutGaugeControls;
  UpdateDropDownWidths;
  RefreshState;
end;

procedure TFRpAISelectionVCL.RefreshStatusInBackground;
var
  LWorker: TThread;
begin
  LWorker := TThread.CreateAnonymousThread(
    procedure
    begin
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
begin
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
  LayoutNonInferenceControls;
  LayoutGaugeControls;
  UpdateDropDownWidths;
  Invalidate;
end;

procedure TFRpAISelectionVCL.LayoutNonInferenceControls;
const
  ComboHorizontalPadding = 2;
var
  LComboHeight: Integer;
  LProviderTop: Integer;
  LModeTop: Integer;
begin
  if (PProviderHost = nil) or (PModeHost = nil) or (ComboAIProvider = nil) or
    (ComboAIMode = nil) then
    Exit;

  if (PProviderHost.ClientWidth <= 0) or (PModeHost.ClientWidth <= 0) then
    Exit;

  LComboHeight := ComboAIProvider.Height;
  if ComboAIMode.Height > LComboHeight then
    LComboHeight := ComboAIMode.Height;
  if LComboHeight <= 0 then
    LComboHeight := 21;

  LProviderTop := (PProviderHost.ClientHeight - LComboHeight) div 2;
  if LProviderTop < 0 then
    LProviderTop := 0;

  LModeTop := (PModeHost.ClientHeight - LComboHeight) div 2;
  if LModeTop < 0 then
    LModeTop := 0;

  PProviderHost.Padding.Left := ComboHorizontalPadding;
  PProviderHost.Padding.Right := ComboHorizontalPadding;
  PProviderHost.Padding.Top := LProviderTop;
  PProviderHost.Padding.Bottom := PProviderHost.ClientHeight - LProviderTop - LComboHeight;
  if PProviderHost.Padding.Bottom < 0 then
    PProviderHost.Padding.Bottom := 0;

  PModeHost.Padding.Left := ComboHorizontalPadding;
  PModeHost.Padding.Right := ComboHorizontalPadding;
  PModeHost.Padding.Top := LModeTop;
  PModeHost.Padding.Bottom := PModeHost.ClientHeight - LModeTop - LComboHeight;
  if PModeHost.Padding.Bottom < 0 then
    PModeHost.Padding.Bottom := 0;

  ComboAIProvider.Height := LComboHeight;
  ComboAIMode.Height := LComboHeight;
  PProviderHost.Realign;
  PModeHost.Realign;
end;

procedure TFRpAISelectionVCL.LayoutGaugeControls;
const
  GaugeSize = 30;
var
  LLeft: Integer;
  LTop: Integer;
begin
  if PGaugeHost <> nil then
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
  PaintBoxGauge.Invalidate;
end;

procedure TFRpAISelectionVCL.DrawCircularArc(ACanvas: TCanvas;
  const ARect: TRect; AStartAngle, ASweepAngle: Double; AColor: TColor;
  APenWidth: Integer);
var
  AngleStep: Double;
  AngleValue: Double;
  PointCount: Integer;
  PointIndex: Integer;
  GaugePoints: array of TPoint;
begin
  PointCount := Round(Abs(ASweepAngle) / 8) + 2;
  if PointCount < 2 then
    PointCount := 2;
  SetLength(GaugePoints, PointCount);
  AngleStep := ASweepAngle / (PointCount - 1);
  AngleValue := AStartAngle;
  for PointIndex := 0 to PointCount - 1 do
  begin
    GaugePoints[PointIndex] := GetPointOnCircle(ARect, AngleValue);
    AngleValue := AngleValue + AngleStep;
  end;
  ACanvas.Pen.Width := APenWidth;
  ACanvas.Pen.Color := AColor;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Polyline(GaugePoints);
end;

function TFRpAISelectionVCL.GetPointOnCircle(const ARect: TRect; const AAngleDegrees: Double): TPoint;
var
  RadiusX, RadiusY, CenterX, CenterY: Integer;
  Rad: Double;
begin
  RadiusX := ARect.Width div 2;
  RadiusY := ARect.Height div 2;
  CenterX := ARect.Left + RadiusX;
  CenterY := ARect.Top + RadiusY;
  Rad := AAngleDegrees * PI / 180.0;
  Result.X := Round(CenterX + RadiusX * Cos(Rad));
  Result.Y := Round(CenterY - RadiusY * Sin(Rad));
end;

procedure TFRpAISelectionVCL.PaintBoxGaugePaint(Sender: TObject);
var
  Canvas: TCanvas;
  Rect: TRect;
  IndicatorColor: TColor;
  DisplayValue: Double;
  PercentageValue: Integer;
  PercentageText: string;
  AngleStep: Double;
  AngleValue: Double;
  PointCount: Integer;
  PointIndex: Integer;
  GaugePoints: array of TPoint;
  TextRect: TRect;
begin
  Canvas := PaintBoxGauge.Canvas;
  Rect := PaintBoxGauge.ClientRect;
  InflateRect(Rect, -3, -3);
  DisplayValue := FGaugeValue;

  // Background circle (track)
  Canvas.Pen.Width := 4;
  Canvas.Pen.Color := $00C0C0C0;
  Canvas.Brush.Style := bsClear;
  Canvas.Ellipse(Rect);

  // Indicator color based on usage ratio (matching C# CircularGauge)
  if DisplayValue < 0.5 then IndicatorColor := RGB(76, 175, 80)
  else if DisplayValue < 0.75 then IndicatorColor := RGB(255, 193, 7)
  else if DisplayValue < 0.9 then IndicatorColor := RGB(255, 152, 0)
  else IndicatorColor := RGB(244, 67, 54);

  if DisplayValue > 0 then
  begin
    Canvas.Pen.Color := IndicatorColor;
    if DisplayValue >= 0.999 then
      Canvas.Ellipse(Rect)
    else
    begin
      PointCount := Round(DisplayValue * 72) + 1;
      if PointCount < 2 then
        PointCount := 2;
      SetLength(GaugePoints, PointCount);
      AngleStep := (DisplayValue * 360) / (PointCount - 1);
      AngleValue := 270;
      for PointIndex := 0 to PointCount - 1 do
      begin
        GaugePoints[PointIndex] := GetPointOnCircle(Rect, AngleValue);
        AngleValue := AngleValue - AngleStep;
      end;
      Canvas.Polyline(GaugePoints);
    end;
  end;

  PercentageValue := Round(DisplayValue * 100);
  if PercentageValue < 0 then
    PercentageValue := 0
  else if PercentageValue > 100 then
    PercentageValue := 100;
  PercentageText := IntToStr(PercentageValue) + '%';

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Style := [];
  Canvas.Font.Height := -7;
  if DisplayValue > 0 then
    Canvas.Font.Color := IndicatorColor
  else
    Canvas.Font.Color := $00707070;
  TextRect := Rect;
  DrawText(Canvas.Handle, PChar(PercentageText), Length(PercentageText), TextRect,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
end;

procedure TFRpAISelectionVCL.PaintBoxProgressPaint(Sender: TObject);
var
  Canvas: TCanvas;
  Rect: TRect;
begin
  Canvas := PaintBoxProgress.Canvas;
  Rect := PaintBoxProgress.ClientRect;
  InflateRect(Rect, -3, -3);

  Canvas.Pen.Width := 3;
  Canvas.Pen.Color := $00D8D8D8;
  Canvas.Brush.Style := bsClear;
  Canvas.Ellipse(Rect);

  DrawCircularArc(Canvas, Rect, FSpinnerAngle, -110, RGB(0, 122, 204), 4);
end;

procedure TFRpAISelectionVCL.ComboAIModeChange(Sender: TObject);
begin
  // Mode changed: Fast or Reasoning
end;

procedure TFRpAISelectionVCL.ComboAIProviderChange(Sender: TObject);
begin
  // Provider changed: hide gauge for Agent tier (no cloud credits)
  if ComboAIProvider.ItemIndex >= 2 then
  begin
    PaintBoxGauge.Visible := False;
  end
  else
  begin
    PaintBoxGauge.Visible := True;
  end;
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
  if AActive then
    LTokensInfo.Caption := 'Tokens (In/Out): 0 / 0';
  if PProgressHost <> nil then
    PProgressHost.Constraints.MinWidth := 30;
  if PInferenceProgress <> nil then
    PInferenceProgress.Realign;
  UpdateSpinnerState;
  LayoutGaugeControls;
end;

procedure TFRpAISelectionVCL.UpdateTokens(AInTokens, AOutTokens: Integer);
begin
  LTokensInfo.Caption := 'Tokens (In/Out): ' + IntToStr(AInTokens) + ' / ' + IntToStr(AOutTokens);
  if PInferenceProgress.Visible then
    PInferenceProgress.Realign;
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
