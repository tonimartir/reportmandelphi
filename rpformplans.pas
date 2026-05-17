{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpformplans                                     }
{       Subscription Plans and Pricing UI               }
{                                                       }
{       Copyright (c) 1994-2025 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpformplans;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, rpauthmanager;

type
  TFormRpPlans = class(TForm)
    ListViewTiers: TListView;
    PanelDetails: TPanel;
    MemoFeatures: TMemo;
    ButtonSubscribeMonthly: TButton;
    ButtonSubscribeYearly: TButton;
    ButtonManageBilling: TButton;
    LabelTitle: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure ListViewTiersSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure ButtonSubscribeMonthlyClick(Sender: TObject);
    procedure ButtonSubscribeYearlyClick(Sender: TObject);
    procedure ButtonManageBillingClick(Sender: TObject);
  private
    { Private declarations }
    procedure RefreshTiers;
    procedure UpdateDetails;
  public
    { Public declarations }
    class procedure Execute;
  end;

implementation

{$R *.dfm}

class procedure TFormRpPlans.Execute;
var
  Form: TFormRpPlans;
begin
  Form := TFormRpPlans.Create(nil);
  try
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TFormRpPlans.FormCreate(Sender: TObject);
begin
  RefreshTiers;
  ButtonManageBilling.Visible := TRpAuthManager.Instance.IsLoggedIn;
end;

procedure TFormRpPlans.RefreshTiers;
var
  I: Integer;
  Item: TListItem;
  Tier: TRpTier;
begin
  TRpAuthManager.Instance.RefreshTiers;
  ListViewTiers.Items.BeginUpdate;
  try
    ListViewTiers.Items.Clear;
    for I := 0 to High(TRpAuthManager.Instance.Tiers) do
    begin
      Tier := TRpAuthManager.Instance.Tiers[I];
      // Skip Guest if necessary
      if SameText(Tier.Name, 'Guest') then Continue;

      Item := ListViewTiers.Items.Add;
      Item.Caption := Tier.Name;
      Item.SubItems.Add(Format('%m / month', [Tier.MonthlyPrice]));
      Item.Data := Pointer(Tier.Id);
    end;
  finally
    ListViewTiers.Items.EndUpdate;
  end;
end;

procedure TFormRpPlans.UpdateDetails;
var
  Id: Int64;
  I: Integer;
  Tier: TRpTier;
begin
  if ListViewTiers.Selected = nil then
  begin
    MemoFeatures.Clear;
    ButtonSubscribeMonthly.Enabled := False;
    ButtonSubscribeYearly.Enabled := False;
    Exit;
  end;

  Id := Int64(ListViewTiers.Selected.Data);
  for I := 0 to High(TRpAuthManager.Instance.Tiers) do
  begin
    if TRpAuthManager.Instance.Tiers[I].Id = Id then
    begin
      Tier := TRpAuthManager.Instance.Tiers[I];
      MemoFeatures.Lines.Clear;
      MemoFeatures.Lines.Add('Plan: ' + Tier.Name);
      MemoFeatures.Lines.Add('-------------------------');
      MemoFeatures.Lines.Add(Format('Credits/Day: %d', [Tier.MaxCreditsDay]));
      MemoFeatures.Lines.Add(Format('Free Credits: %d', [Tier.MaxFreeCredits]));
      MemoFeatures.Lines.Add(Format('Max Connections: %d', [Tier.MaxConnections]));
      MemoFeatures.Lines.Add(Format('Max Tables/DB: %d', [Tier.MaxTables]));
      MemoFeatures.Lines.Add(Format('Max KPIs: %d', [Tier.MaxKpis]));
      
      ButtonSubscribeMonthly.Caption := Format('Subscribe Monthly (%m)', [Tier.MonthlyPrice]);
      ButtonSubscribeYearly.Caption := Format('Subscribe Yearly (%m)', [Tier.YearlyPrice]);
      
      ButtonSubscribeMonthly.Enabled := True;
      ButtonSubscribeYearly.Enabled := True;
      Break;
    end;
  end;
end;

procedure TFormRpPlans.ListViewTiersSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  UpdateDetails;
end;

procedure TFormRpPlans.ButtonSubscribeMonthlyClick(Sender: TObject);
var
  Url: string;
begin
  if ListViewTiers.Selected = nil then Exit;
  Url := TRpAuthManager.Instance.GetCheckoutUrl(Int64(ListViewTiers.Selected.Data), False);
  TRpAuthManager.Instance.OpenUrl(Url);
end;

procedure TFormRpPlans.ButtonSubscribeYearlyClick(Sender: TObject);
var
  Url: string;
begin
  if ListViewTiers.Selected = nil then Exit;
  Url := TRpAuthManager.Instance.GetCheckoutUrl(Int64(ListViewTiers.Selected.Data), True);
  TRpAuthManager.Instance.OpenUrl(Url);
end;

procedure TFormRpPlans.ButtonManageBillingClick(Sender: TObject);
var
  Url: string;
begin
  Url := TRpAuthManager.Instance.GetPortalUrl;
  TRpAuthManager.Instance.OpenUrl(Url);
end;

end.
