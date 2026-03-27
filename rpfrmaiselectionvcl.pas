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
  Dialogs, StdCtrls, ExtCtrls, System.JSON, rpauthmanager;

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
    ComboAIProvider: TComboBox;
    ComboAIMode: TComboBox;
    PaintBoxGauge: TPaintBox;
    LCredits: TLabel;
    LProvider: TLabel;
    procedure PaintBoxGaugePaint(Sender: TObject);
    procedure ComboAIModeChange(Sender: TObject);
    procedure ComboAIProviderChange(Sender: TObject);
  private
    FGaugeValue: Double; // 0.0 to 1.0
    FAgentEndpoints: array of TAgentEndpointInfo;
    FFreeRemaining: Int64;
    FFreeInitial: Int64;
    FDailyConsumed: Int64;
    FDailyMax: Int64;
    procedure SetGaugeValue(const Value: Double);
    function GetPointOnCircle(const ARect: TRect; const AAngleDegrees: Double): TPoint;
    function GetAITier: string;
    function GetAIMode: string;
    function GetAgentSecret: string;
    function GetAgentAiId: Int64;
    procedure UpdateGaugeDisplay;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshState;
    procedure UpdateFromUserProfile(AProfile: TJSONObject);
    procedure AddAgentEndpoint(AId: Int64; const ASecret, AName: string; AOnline: Boolean);
    procedure ClearAgentEndpoints;
    property GaugeValue: Double read FGaugeValue write SetGaugeValue;
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
  FFreeRemaining := 0;
  FFreeInitial := 0;
  FDailyConsumed := 0;
  FDailyMax := 0;
  ComboAIProvider.ItemIndex := 0; // Standard
  ComboAIMode.ItemIndex := 0;    // Fast
  RefreshState;
end;

procedure TFRpAISelectionVCL.RefreshState;
begin
  UpdateGaugeDisplay;
end;

procedure TFRpAISelectionVCL.UpdateGaugeDisplay;
var
  LProfile: TRpUserProfile;
  LUsed, LMax: Int64;
  LPct: Double;
  LHint: string;
begin
  LProfile := TRpAuthManager.Instance.Profile;

  // If we have data from API userProfile response, use it
  if (FFreeInitial > 0) or (FDailyMax > 0) then
  begin
    // Calculate based on API data
    if FFreeInitial > 0 then
    begin
      LUsed := FFreeInitial - FFreeRemaining;
      LMax := FFreeInitial;
    end
    else
    begin
      LUsed := FDailyConsumed;
      LMax := FDailyMax;
    end;

    if LMax > 0 then
    begin
      LPct := (LUsed / LMax) * 100;
      FGaugeValue := LUsed / LMax;
      LCredits.Caption := Format('%d/%d', [LUsed, LMax]);
      LHint := Format('Used: %d / Max: %d (%.0f%%)', [LUsed, LMax, LPct]) + #13#10 +
               Format('Remaining: %d', [LMax - LUsed]);
    end
    else
    begin
      FGaugeValue := 0;
      LCredits.Caption := 'Free';
      LHint := 'Free tier';
    end;
  end
  else if TRpAuthManager.Instance.IsLoggedIn then
  begin
    LCredits.Caption := IntToStr(LProfile.Credits) + ' credits';
    LHint := IntToStr(LProfile.Credits) + ' credits remaining';
    if LProfile.Credits > 0 then
      FGaugeValue := 0.0
    else
      FGaugeValue := 1.0;
  end
  else
  begin
    LCredits.Caption := 'Guest';
    LHint := 'Guest access - limited credits';
    FGaugeValue := 0;
  end;

  LCredits.Hint := LHint;
  PaintBoxGauge.Hint := LHint;
  PaintBoxGauge.Invalidate;
end;

procedure TFRpAISelectionVCL.UpdateFromUserProfile(AProfile: TJSONObject);
var
  LVal: TJSONValue;
begin
  if AProfile = nil then Exit;

  LVal := AProfile.Values['freeRemaining'];
  if (LVal <> nil) and (LVal is TJSONNumber) then
    FFreeRemaining := TJSONNumber(LVal).AsInt64;

  LVal := AProfile.Values['freeInitial'];
  if (LVal <> nil) and (LVal is TJSONNumber) then
    FFreeInitial := TJSONNumber(LVal).AsInt64;

  LVal := AProfile.Values['dailyConsumed'];
  if (LVal <> nil) and (LVal is TJSONNumber) then
    FDailyConsumed := TJSONNumber(LVal).AsInt64;

  LVal := AProfile.Values['dailyMax'];
  if (LVal <> nil) and (LVal is TJSONNumber) then
    FDailyMax := TJSONNumber(LVal).AsInt64;

  UpdateGaugeDisplay;
end;

procedure TFRpAISelectionVCL.SetGaugeValue(const Value: Double);
begin
  if FGaugeValue <> Value then
  begin
    FGaugeValue := Value;
    PaintBoxGauge.Invalidate;
  end;
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
  PStart, PEnd: TPoint;
begin
  Canvas := PaintBoxGauge.Canvas;
  Rect := PaintBoxGauge.ClientRect;
  InflateRect(Rect, -3, -3);

  // Background circle (track)
  Canvas.Pen.Width := 4;
  Canvas.Pen.Color := $00E0E0E0;
  Canvas.Brush.Style := bsClear;
  Canvas.Ellipse(Rect);

  if FGaugeValue <= 0 then Exit;

  // Indicator color based on usage ratio (matching C# CircularGauge)
  if FGaugeValue < 0.5 then IndicatorColor := $004CAF50  // Material Green
  else if FGaugeValue < 0.75 then IndicatorColor := clYellow
  else if FGaugeValue < 0.9 then IndicatorColor := $0000A5FF  // Orange
  else IndicatorColor := clRed;

  Canvas.Pen.Color := IndicatorColor;

  // C# starts at 90 deg in WPF (Bottom, since +Y is down)
  // In VCL math, +Y is Up if we use CenterY - Sin
  // So 270 is Bottom
  PStart := GetPointOnCircle(Rect, 270);
  PEnd := GetPointOnCircle(Rect, 270 - (FGaugeValue * 360));

  if FGaugeValue >= 0.999 then
    Canvas.Ellipse(Rect)
  else
    Canvas.Arc(Rect.Left, Rect.Top, Rect.Right, Rect.Bottom,
      PEnd.X, PEnd.Y, PStart.X, PStart.Y); // VCL Arc direction fix
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
    LCredits.Visible := False;
  end
  else
  begin
    PaintBoxGauge.Visible := True;
    LCredits.Visible := True;
  end;
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
  LDisplayName: string;
begin
  LLen := Length(FAgentEndpoints);
  SetLength(FAgentEndpoints, LLen + 1);
  FAgentEndpoints[LLen].Id := AId;
  FAgentEndpoints[LLen].AgentSecret := ASecret;
  FAgentEndpoints[LLen].DisplayName := AName;
  FAgentEndpoints[LLen].IsOnline := AOnline;

  if AOnline then
    LDisplayName := AName
  else
    LDisplayName := AName + ' (offline)';
  ComboAIProvider.Items.Add(LDisplayName);
end;

procedure TFRpAISelectionVCL.ClearAgentEndpoints;
begin
  SetLength(FAgentEndpoints, 0);
  while ComboAIProvider.Items.Count > 2 do
    ComboAIProvider.Items.Delete(ComboAIProvider.Items.Count - 1);
  if ComboAIProvider.ItemIndex >= ComboAIProvider.Items.Count then
    ComboAIProvider.ItemIndex := 0;
end;

end.
