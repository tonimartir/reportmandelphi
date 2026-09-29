{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpfrmloginframelcl                              }
{       Account card of the AI panels: user, tier and   }
{       the account menu (LCL port of rpfrmloginframevcl)}
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpfrmloginframelcl;

{ A panel instead of a TFrame (LCL frames need a form resource). The card is
  painted in OnPaint (the VCL subclasses the window procedure for
  WM_ERASEBKGND and CM_MOUSEENTER/LEAVE); the arrow is drawn (the VCL uses
  the Windows-only Marlett font). Auth events come from RpAuthEvents, in the
  main thread, and the avatar download (disabled, as in the VCL) runs in a
  TRpAsyncWorker. }

{$mode delphi}

interface

uses
  SysUtils, Classes, Types, Graphics, Controls, Forms, ExtCtrls, StdCtrls,
  Menus, rpauthmanager, rpaithreadslcl, rpchatmodernstylelcl;

const
  CRpLoginFrameEnableAuthState = True;
  CRpLoginFrameEnableAvatarDownload = False;

type
  TRpQueuedAvatarPayload = class(TRpAsyncMessage)
  public
    RequestVersion: Integer;
    Bytes: TBytes;
  end;

  TFRpLoginFrameLCL = class(TCustomPanel)
  private
    FAvatarRequestVersion: Integer;
    FAuthListenerRegistered: Boolean;
    FOnAuthChanged: TNotifyEvent;
    FMenuItemLogin: TMenuItem;
    FMenuItemLanguage: TMenuItem;
    FMenuItemPricePlans: TMenuItem;
    FMenuItemConfigureDbSchemas: TMenuItem;
    FMenuItemDbAiAgent: TMenuItem;
    FMenuItemLogoutSeparator: TMenuItem;
    FHover: Boolean;
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    procedure BuildControls;
    procedure UpdateUI;
    procedure BuildPopupMenu;
    procedure BuildLanguageMenu;
    procedure UpdateLanguageMenu;
    procedure AuthChanged(ASuccess: Boolean);
    procedure DownloadAvatarAsync(const AUrl: string);
    procedure HandleMessage(AMessage: TRpAsyncMessage);
    procedure ContainerPaint(Sender: TObject);
    procedure ContainerMouseEnter(Sender: TObject);
    procedure ContainerMouseLeave(Sender: TObject);
    procedure ArrowPaint(Sender: TObject);
    procedure ApplyModernStyling;
  protected
    procedure Resize; override;
  public
    PContainer: TPanel;
    LabelTier: TLabel;
    ImageAvatar: TImage;
    LabelUser: TLabel;
    LabelArrow: TPaintBox;
    BtnLogin: TButton;
    PopupUser: TPopupMenu;
    MenuItemLogout: TMenuItem;
    N1: TMenuItem;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RefreshLayout;
    procedure BtnLoginClick(Sender: TObject);
    procedure MenuItemLoginClick(Sender: TObject);
    procedure MenuItemLogoutClick(Sender: TObject);
    procedure MenuItemLanguageClick(Sender: TObject);
    procedure MenuItemPricePlansClick(Sender: TObject);
    procedure MenuItemConfigureDbSchemasClick(Sender: TObject);
    procedure MenuItemDbAiAgentClick(Sender: TObject);
    procedure ImageAvatarClick(Sender: TObject);
    // Account menu items (tests)
    property MenuItemLogin: TMenuItem read FMenuItemLogin;
    property MenuItemLanguage: TMenuItem read FMenuItemLanguage;
    property OnAuthChanged: TNotifyEvent read FOnAuthChanged write FOnAuthChanged;
  end;

implementation

uses
  rpmdconsts, rphttpclientfpc, LazUTF8, rpfrmloginlcl;

type
  // OnMouseEnter/OnMouseLeave are protected in TControl
  TControlAccess = class(TControl);

  TRpAvatarWorker = class(TRpAsyncWorker)
  public
    Url: string;
    RequestVersion: Integer;
  protected
    procedure Run; override;
  end;

procedure TRpAvatarWorker.Run;
var
  LClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LStream: TMemoryStream;
  LPayload: TRpQueuedAvatarPayload;
begin
  LClient := TNetHTTPClient.Create(nil);
  LStream := TMemoryStream.Create;
  try
    TRpAuthManager.Instance.ConfigureDebugHttpClient(LClient);
    try
      LResponse := LClient.Get(Url, LStream);
      TRpAuthManager.Instance.Log('DownloadAvatar: status ' + IntToStr(LResponse.StatusCode));
      if LResponse.StatusCode = 200 then
      begin
        LPayload := TRpQueuedAvatarPayload.Create;
        LPayload.RequestVersion := RequestVersion;
        SetLength(LPayload.Bytes, LStream.Size);
        if LStream.Size > 0 then
          Move(LStream.Memory^, LPayload.Bytes[0], LStream.Size);
        Post(LPayload);
      end;
    except
      on E: Exception do
        TRpAuthManager.Instance.Log('DownloadAvatar: HTTP error ' + E.Message);
    end;
  finally
    LStream.Free;
    LClient.Free;
  end;
end;

{ TFRpLoginFrameLCL }

constructor TFRpLoginFrameLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  Height := Scale(38);
  Width := Scale(200);
  FMailbox := TRpAsyncMailbox.Create(HandleMessage);
  FMailboxRef := FMailbox;
  FAvatarRequestVersion := 0;
  FAuthListenerRegistered := False;
  FHover := False;
  BuildControls;
  BuildPopupMenu;
  ApplyModernStyling;
  if CRpLoginFrameEnableAuthState then
  begin
    RpAuthEvents.AddAuthListener(AuthChanged);
    FAuthListenerRegistered := True;
  end;
  UpdateUI;
end;

destructor TFRpLoginFrameLCL.Destroy;
begin
  if FAuthListenerRegistered then
  begin
    RpAuthEvents.RemoveAuthListener(AuthChanged);
    FAuthListenerRegistered := False;
  end;
  FMailbox.Detach;
  FMailboxRef := nil;
  inherited Destroy;
end;

procedure TFRpLoginFrameLCL.BuildControls;
begin
  PContainer := TPanel.Create(Self);
  PContainer.Parent := Self;
  PContainer.Align := alClient;
  PContainer.BevelOuter := bvNone;
  PContainer.Caption := '';
  PContainer.OnClick := ImageAvatarClick;

  LabelTier := TLabel.Create(Self);
  LabelTier.Parent := PContainer;
  LabelTier.AutoSize := False;
  LabelTier.Alignment := taCenter;
  LabelTier.Layout := tlCenter;
  LabelTier.SetBounds(Scale(6), Scale(10), Scale(38), Scale(16));
  LabelTier.Visible := False;
  LabelTier.OnClick := ImageAvatarClick;

  ImageAvatar := TImage.Create(Self);
  ImageAvatar.Parent := PContainer;
  ImageAvatar.SetBounds(Scale(46), Scale(5), Scale(28), Scale(28));
  ImageAvatar.Center := True;
  ImageAvatar.Proportional := True;
  ImageAvatar.Stretch := True;
  ImageAvatar.Visible := False;
  ImageAvatar.OnClick := ImageAvatarClick;

  LabelUser := TLabel.Create(Self);
  LabelUser.Parent := PContainer;
  LabelUser.AutoSize := False;
  LabelUser.Layout := tlCenter;
  LabelUser.SetBounds(Scale(80), Scale(10), Scale(80), Scale(20));
  LabelUser.Visible := False;
  LabelUser.OnClick := ImageAvatarClick;

  LabelArrow := TPaintBox.Create(Self);
  LabelArrow.Parent := PContainer;
  LabelArrow.SetBounds(Scale(170), Scale(10), Scale(16), Scale(16));
  LabelArrow.Visible := False;
  LabelArrow.OnPaint := ArrowPaint;
  LabelArrow.OnClick := ImageAvatarClick;

  BtnLogin := TButton.Create(Self);
  BtnLogin.Parent := PContainer;
  BtnLogin.Align := alClient;
  BtnLogin.Visible := False;
  BtnLogin.OnClick := BtnLoginClick;

  PopupUser := TPopupMenu.Create(Self);
  N1 := TMenuItem.Create(PopupUser);
  N1.Caption := '-';
  PopupUser.Items.Add(N1);
  MenuItemLogout := TMenuItem.Create(PopupUser);
  MenuItemLogout.Caption := TranslateStr(1493, 'Logout');
  MenuItemLogout.OnClick := MenuItemLogoutClick;
  PopupUser.Items.Add(MenuItemLogout);
end;

procedure TFRpLoginFrameLCL.ApplyModernStyling;
var
  I: Integer;
  LCtl: TControl;
begin
  PContainer.ParentBackground := False;
  PContainer.ParentColor := False;
  PContainer.Color := ClrBg;
  PContainer.Cursor := crHandPoint;
  PContainer.OnPaint := ContainerPaint;
  PContainer.OnMouseEnter := ContainerMouseEnter;
  PContainer.OnMouseLeave := ContainerMouseLeave;
  // Hand cursor on the children: the whole card is clickable
  for I := 0 to PContainer.ControlCount - 1 do
  begin
    LCtl := PContainer.Controls[I];
    if LCtl <> BtnLogin then
    begin
      LCtl.Cursor := crHandPoint;
      TControlAccess(LCtl).OnMouseEnter := ContainerMouseEnter;
      TControlAccess(LCtl).OnMouseLeave := ContainerMouseLeave;
    end;
  end;

  LabelUser.ParentFont := False;
  LabelUser.Font.Size := FontSizeUi;
  LabelUser.Font.Style := [fsBold];
  LabelUser.Font.Color := ClrText;
  LabelUser.Transparent := True;

  LabelTier.ParentFont := False;
  LabelTier.Font.Size := FontSizeMicro;
  LabelTier.Font.Style := [fsBold];
  LabelTier.Transparent := False;

  BtnLogin.Caption := 'Sign in with AI';
  BtnLogin.Cursor := crHandPoint;
end;

procedure TFRpLoginFrameLCL.ContainerPaint(Sender: TObject);
var
  R: TRect;
  LBgColor: TColor;
begin
  R := PContainer.ClientRect;
  if FHover then
    LBgColor := ClrAccentSoft
  else
    LBgColor := ClrSurface;
  // Parent color first: no white corners outside the round rect
  PContainer.Canvas.Brush.Color := ClrBg;
  PContainer.Canvas.Brush.Style := bsSolid;
  PContainer.Canvas.FillRect(R);
  TRpChatStyle.DrawRoundRectFlat(PContainer.Canvas, Rect(R.Left, R.Top, R.Right - 1,
    R.Bottom - 1), 6, LBgColor, ClrAccent);
end;

procedure TFRpLoginFrameLCL.ContainerMouseEnter(Sender: TObject);
begin
  if not FHover then
  begin
    FHover := True;
    PContainer.Invalidate;
  end;
end;

procedure TFRpLoginFrameLCL.ContainerMouseLeave(Sender: TObject);
var
  P: TPoint;
begin
  // Leaving the card for one of its labels is not leaving the card
  P := PContainer.ScreenToClient(Mouse.CursorPos);
  if PtInRect(PContainer.ClientRect, P) then
    Exit;
  if FHover then
  begin
    FHover := False;
    PContainer.Invalidate;
  end;
end;

procedure TFRpLoginFrameLCL.ArrowPaint(Sender: TObject);
begin
  TRpChatStyle.DrawIcon(LabelArrow.Canvas, LabelArrow.ClientRect, rpikChevronDown,
    ClrAccent);
end;

procedure TFRpLoginFrameLCL.BuildPopupMenu;
begin
  FMenuItemLogin := TMenuItem.Create(PopupUser);
  FMenuItemLogin.Caption := TranslateStr(1492, 'Login');
  FMenuItemLogin.OnClick := MenuItemLoginClick;

  FMenuItemLanguage := TMenuItem.Create(PopupUser);
  FMenuItemLanguage.Caption := TranslateStr(1494, 'Language');
  BuildLanguageMenu;

  FMenuItemPricePlans := TMenuItem.Create(PopupUser);
  FMenuItemPricePlans.Caption := TranslateStr(1495, 'AI price plans');
  FMenuItemPricePlans.OnClick := MenuItemPricePlansClick;

  FMenuItemConfigureDbSchemas := TMenuItem.Create(PopupUser);
  FMenuItemConfigureDbSchemas.Caption := TranslateStr(1496, 'Configure DB Schemas');
  FMenuItemConfigureDbSchemas.OnClick := MenuItemConfigureDbSchemasClick;

  FMenuItemDbAiAgent := TMenuItem.Create(PopupUser);
  FMenuItemDbAiAgent.Caption := TranslateStr(1497, 'DB & AI Agent');
  FMenuItemDbAiAgent.OnClick := MenuItemDbAiAgentClick;

  FMenuItemLogoutSeparator := TMenuItem.Create(PopupUser);
  FMenuItemLogoutSeparator.Caption := '-';

  PopupUser.Items.Insert(0, FMenuItemLogin);
  PopupUser.Items.Insert(1, FMenuItemLanguage);
  PopupUser.Items.Insert(2, FMenuItemPricePlans);
  PopupUser.Items.Insert(3, FMenuItemConfigureDbSchemas);
  PopupUser.Items.Insert(4, FMenuItemDbAiAgent);
  PopupUser.Items.Insert(5, FMenuItemLogoutSeparator);
end;

procedure TFRpLoginFrameLCL.BuildLanguageMenu;
var
  LItem: TMenuItem;
  LLanguage: string;
begin
  FMenuItemLanguage.Clear;
  for LLanguage in TRpAuthManager.GetSupportedAILanguages do
  begin
    LItem := TMenuItem.Create(FMenuItemLanguage);
    LItem.Caption := TRpAuthManager.GetAILanguageDisplayName(LLanguage);
    LItem.Hint := LLanguage;
    LItem.RadioItem := True;
    LItem.OnClick := MenuItemLanguageClick;
    FMenuItemLanguage.Add(LItem);
  end;
end;

procedure TFRpLoginFrameLCL.UpdateLanguageMenu;
var
  I: Integer;
  LCurrentLanguage: string;
begin
  if not CRpLoginFrameEnableAuthState then
  begin
    FMenuItemLanguage.Caption := TranslateStr(1494, 'Language');
    for I := 0 to FMenuItemLanguage.Count - 1 do
      FMenuItemLanguage.Items[I].Checked := False;
    Exit;
  end;
  LCurrentLanguage := TRpAuthManager.Instance.AILanguage;
  FMenuItemLanguage.Caption := TranslateStr(1494, 'Language') + ': ' +
    TRpAuthManager.GetAILanguageDisplayName(LCurrentLanguage);
  for I := 0 to FMenuItemLanguage.Count - 1 do
    FMenuItemLanguage.Items[I].Checked := SameText(FMenuItemLanguage.Items[I].Hint,
      LCurrentLanguage);
end;

procedure TFRpLoginFrameLCL.Resize;
begin
  inherited Resize;
  if PContainer <> nil then
    UpdateUI;
end;

procedure TFRpLoginFrameLCL.RefreshLayout;
begin
  UpdateUI;
  Invalidate;
  if PContainer <> nil then
    PContainer.Invalidate;
end;

procedure TFRpLoginFrameLCL.AuthChanged(ASuccess: Boolean);
begin
  if not FAuthListenerRegistered then
    Exit;
  UpdateUI;
  if Assigned(FOnAuthChanged) then
    FOnAuthChanged(Self);
end;

procedure TFRpLoginFrameLCL.UpdateUI;
var
  LProfile: TRpProfile;
  LName: string;
  LUserLeft, LUserWidth, LArrowRight, LTierWidth: Integer;
  LLoggedIn: Boolean;
begin
  if PContainer = nil then
    Exit;
  UpdateLanguageMenu;
  LArrowRight := Scale(8);
  LLoggedIn := CRpLoginFrameEnableAuthState and TRpAuthManager.Instance.IsLoggedIn;

  BtnLogin.Visible := False;
  FMenuItemLogin.Visible := not LLoggedIn;
  FMenuItemLanguage.Visible := True;
  N1.Visible := LLoggedIn;
  FMenuItemLogoutSeparator.Visible := LLoggedIn;
  MenuItemLogout.Visible := LLoggedIn;
  LabelTier.Visible := LLoggedIn;
  ImageAvatar.Visible := LLoggedIn and CRpLoginFrameEnableAvatarDownload;
  LabelUser.Visible := True;
  LabelArrow.Visible := True;

  LabelArrow.SetBounds(PContainer.ClientWidth - LabelArrow.Width - LArrowRight,
    (PContainer.ClientHeight - LabelArrow.Height) div 2, LabelArrow.Width, LabelArrow.Height);

  if LLoggedIn then
  begin
    LProfile := TRpAuthManager.Instance.Profile;
    LabelUser.Caption := LProfile.UserName;
    if LabelUser.Caption = '' then
      LabelUser.Caption := LProfile.Email;

    // Tier badge
    LName := UpperCase(LProfile.TierName);
    if LName = '' then
      LName := 'GUEST';
    if LName = 'ENTERPRISE' then
      LName := 'ENT';
    LabelTier.Caption := LName;
    case LProfile.TierId of
      1: // Guest
        begin
          LabelTier.Color := $E0E0E0;
          LabelTier.Font.Color := $4F4536;
        end;
      2: // Free
        begin
          LabelTier.Color := $F1F2E0;
          LabelTier.Font.Color := $205E1B;
        end;
      3: // Lite
        begin
          LabelTier.Color := $FEF5E1;
          LabelTier.Font.Color := $A1470D;
        end;
      4: // Pro
        begin
          LabelTier.Color := $BD7702;
          LabelTier.Font.Color := clWhite;
        end;
      5: // Enterprise
        begin
          LabelTier.Color := $212121;
          LabelTier.Font.Color := $00D7FF;
        end;
    else
      LabelTier.Color := $E0E0E0;
      LabelTier.Font.Color := $4F4536;
    end;

    if CRpLoginFrameEnableAvatarDownload and (LProfile.AvatarUrl <> '') then
      DownloadAvatarAsync(LProfile.AvatarUrl)
    else
      ImageAvatar.Picture.Clear;

    LTierWidth := TRpChatStyle.TextWidthOf(LabelTier.Font, LName) + Scale(12);
    if LTierWidth < Scale(34) then
      LTierWidth := Scale(34);
    LabelTier.SetBounds(Scale(6), (PContainer.ClientHeight - Scale(16)) div 2,
      LTierWidth, Scale(16));
    if ImageAvatar.Visible then
    begin
      ImageAvatar.Left := LabelTier.Left + LabelTier.Width + Scale(6);
      ImageAvatar.Top := (PContainer.ClientHeight - ImageAvatar.Height) div 2;
      LUserLeft := ImageAvatar.Left + ImageAvatar.Width + Scale(8);
    end
    else
      LUserLeft := LabelTier.Left + LabelTier.Width + Scale(8);
  end
  else
  begin
    LabelUser.Caption := TranslateStr(1498, 'Guest (Login available)');
    LUserLeft := Scale(8);
  end;
  LUserWidth := LabelArrow.Left - LUserLeft - Scale(6);
  if LUserWidth < 0 then
    LUserWidth := 0;
  LabelUser.SetBounds(LUserLeft, 0, LUserWidth, PContainer.ClientHeight);
end;

procedure TFRpLoginFrameLCL.DownloadAvatarAsync(const AUrl: string);
var
  LWorker: TRpAvatarWorker;
begin
  if AUrl = '' then
    Exit;
  Inc(FAvatarRequestVersion);
  TRpAuthManager.Instance.Log('DownloadAvatar: scheduling ' + AUrl);
  LWorker := TRpAvatarWorker.Create(FMailboxRef);
  LWorker.Url := AUrl;
  LWorker.RequestVersion := FAvatarRequestVersion;
  LWorker.Start;
end;

procedure TFRpLoginFrameLCL.HandleMessage(AMessage: TRpAsyncMessage);
var
  LPayload: TRpQueuedAvatarPayload;
  LStream: TBytesStream;
begin
  if not (AMessage is TRpQueuedAvatarPayload) then
    Exit;
  LPayload := TRpQueuedAvatarPayload(AMessage);
  if LPayload.RequestVersion <> FAvatarRequestVersion then
    Exit;
  LStream := TBytesStream.Create(LPayload.Bytes);
  try
    try
      ImageAvatar.Picture.LoadFromStream(LStream);
      TRpAuthManager.Instance.Log('DownloadAvatar: successfully loaded image.');
    except
      on E: Exception do
        TRpAuthManager.Instance.Log('DownloadAvatar: LoadFromStream error: ' + E.Message);
    end;
  finally
    LStream.Free;
  end;
end;

procedure TFRpLoginFrameLCL.BtnLoginClick(Sender: TObject);
begin
  ShowLoginDialog(Self);
end;

procedure TFRpLoginFrameLCL.MenuItemLoginClick(Sender: TObject);
begin
  ShowLoginDialog(Self);
end;

procedure TFRpLoginFrameLCL.ImageAvatarClick(Sender: TObject);
var
  LPoint: TPoint;
begin
  UpdateLanguageMenu;
  LPoint := PContainer.ClientToScreen(Point(PContainer.ClientWidth, PContainer.ClientHeight));
  PopupUser.Popup(LPoint.X, LPoint.Y);
end;

procedure TFRpLoginFrameLCL.MenuItemLanguageClick(Sender: TObject);
begin
  if Sender is TMenuItem then
  begin
    TRpAuthManager.Instance.AILanguage := TMenuItem(Sender).Hint;
    UpdateUI;
  end;
end;

procedure TFRpLoginFrameLCL.MenuItemPricePlansClick(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenUrl('https://app.reportman.es/subscription');
end;

procedure TFRpLoginFrameLCL.MenuItemConfigureDbSchemasClick(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenUrl('https://app.reportman.es/database-config');
end;

procedure TFRpLoginFrameLCL.MenuItemDbAiAgentClick(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenAgentDownloadPage;
end;

procedure TFRpLoginFrameLCL.MenuItemLogoutClick(Sender: TObject);
begin
  TRpAuthManager.Instance.Logout;
end;

end.
