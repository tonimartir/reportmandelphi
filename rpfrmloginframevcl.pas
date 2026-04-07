unit rpfrmloginframevcl;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Types,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Menus, rpauthmanager, rpfrmloginvcl, System.Net.HttpClient, System.Net.HttpClientComponent,
  Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, Vcl.Imaging.GIFImg;

type
  TRpQueuedAvatarPayload = class(TObject)
  public
    RequestVersion: Integer;
    Bytes: TBytes;
  end;

  TFRpLoginFrameVCL = class(TFrame)
    PContainer: TPanel;
    LabelTier: TLabel;
    ImageAvatar: TImage;
    LabelUser: TLabel;
    LabelArrow: TLabel;
    BtnLogin: TButton;
    PopupUser: TPopupMenu;
    MenuItemLogout: TMenuItem;
    N1: TMenuItem;
    procedure BtnLoginClick(Sender: TObject);
    procedure MenuItemLoginClick(Sender: TObject);
    procedure MenuItemLogoutClick(Sender: TObject);
    procedure MenuItemLanguageClick(Sender: TObject);
    procedure ImageAvatarClick(Sender: TObject);
  private
    FAvatarRequestVersion: Integer;
    FOnAuthChanged: TNotifyEvent;
    FMenuItemLogin: TMenuItem;
    FMenuItemLanguage: TMenuItem;
    FMenuItemLogoutSeparator: TMenuItem;
    procedure WMApplyAvatar(var Message: TMessage); message WM_USER + 203;
    procedure UpdateUI;
    procedure BuildPopupMenu;
    procedure BuildLanguageMenu;
    procedure UpdateLanguageMenu;
    procedure AuthChanged(ASuccess: Boolean);
    procedure DownloadAvatarAsync(const AUrl: string);
  protected
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure Resize; override;
    procedure RefreshLayout;
    property OnAuthChanged: TNotifyEvent read FOnAuthChanged write FOnAuthChanged;
  end;

implementation

{$R *.dfm}

constructor TFRpLoginFrameVCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAvatarRequestVersion := 0;
  BuildPopupMenu;
  TRpAuthManager.Instance.RegisterAuthListener(AuthChanged);
end;

procedure TFRpLoginFrameVCL.AfterConstruction;
begin
  inherited;
  UpdateUI;
end;

procedure TFRpLoginFrameVCL.BuildPopupMenu;
begin
  FMenuItemLogin := TMenuItem.Create(PopupUser);
  FMenuItemLogin.Caption := 'Login';
  FMenuItemLogin.OnClick := MenuItemLoginClick;

  FMenuItemLanguage := TMenuItem.Create(PopupUser);
  FMenuItemLanguage.Caption := 'Language';
  BuildLanguageMenu;

  FMenuItemLogoutSeparator := TMenuItem.Create(PopupUser);
  FMenuItemLogoutSeparator.Caption := '-';

  PopupUser.Items.Insert(0, FMenuItemLogin);
  PopupUser.Items.Insert(1, FMenuItemLanguage);
  PopupUser.Items.Insert(3, FMenuItemLogoutSeparator);
end;

procedure TFRpLoginFrameVCL.BuildLanguageMenu;
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

procedure TFRpLoginFrameVCL.UpdateLanguageMenu;
var
  I: Integer;
  LCurrentLanguage: string;
begin
  LCurrentLanguage := TRpAuthManager.Instance.AILanguage;
  FMenuItemLanguage.Caption := 'Language: ' + TRpAuthManager.GetAILanguageDisplayName(LCurrentLanguage);
  for I := 0 to FMenuItemLanguage.Count - 1 do
    FMenuItemLanguage.Items[I].Checked := SameText(FMenuItemLanguage.Items[I].Hint, LCurrentLanguage);
end;

procedure TFRpLoginFrameVCL.Resize;
begin
  inherited;
  RefreshLayout;
end;

procedure TFRpLoginFrameVCL.RefreshLayout;
begin
  if PContainer <> nil then
  begin
    PContainer.SetBounds(0, 0, ClientWidth, ClientHeight);
    PContainer.Realign;
  end;
  UpdateUI;
  Realign;
  Invalidate;
end;

destructor TFRpLoginFrameVCL.Destroy;
begin
  TRpAuthManager.Instance.UnregisterAuthListener(AuthChanged);
  inherited;
end;

procedure TFRpLoginFrameVCL.AuthChanged(ASuccess: Boolean);
begin
  UpdateUI;
  if Assigned(FOnAuthChanged) then
    FOnAuthChanged(Self);
end;

procedure TFRpLoginFrameVCL.UpdateUI;
const
  TierLeft = 6;
  TierGap = 6;
  AvatarGap = 6;
  UserGap = 8;
  GuestLeft = 8;
  ArrowRightMargin = 8;
var
  LProfile: TRpProfile;
  LName: string;
  LUserLeft: Integer;
  LUserWidth: Integer;
begin
  UpdateLanguageMenu;
  if TRpAuthManager.Instance.IsLoggedIn then
  begin
    BtnLogin.Visible := False;
    FMenuItemLogin.Visible := False;
    FMenuItemLanguage.Visible := True;
    N1.Visible := True;
    FMenuItemLogoutSeparator.Visible := True;
    MenuItemLogout.Visible := True;
    LabelTier.Visible := True;
    ImageAvatar.Visible := True;
    LabelUser.Visible := True;
    LabelArrow.Visible := True;
    
    LProfile := TRpAuthManager.Instance.Profile;
    LabelUser.Caption := LProfile.UserName;
    
    // Tier Badge Styling
    LName := UpperCase(LProfile.TierName);
    if LName = '' then LName := 'GUEST';
    if LName = 'ENTERPRISE' then LName := 'ENT';
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
          LabelTier.Color := $BD7702; // Dark Blue
          LabelTier.Font.Color := clWhite;
        end;
      5: // Enterprise
        begin
          LabelTier.Color := $212121;
          LabelTier.Font.Color := $00D7FF; // Gold
        end;
    else
      // Default / Unknown
      LabelTier.Color := $E0E0E0;
      LabelTier.Font.Color := $4F4536;
    end;

    if LProfile.AvatarUrl <> '' then
      DownloadAvatarAsync(LProfile.AvatarUrl)
    else
      ImageAvatar.Picture := nil;

    LabelTier.Left := TierLeft;
    ImageAvatar.Left := LabelTier.Left + LabelTier.Width + TierGap;
    LabelArrow.Left := PContainer.ClientWidth - LabelArrow.Width - ArrowRightMargin;
    LUserLeft := ImageAvatar.Left + ImageAvatar.Width + UserGap;
    LUserWidth := LabelArrow.Left - LUserLeft - AvatarGap;
    if LUserWidth < 0 then
      LUserWidth := 0;
    LabelUser.Left := LUserLeft;
    LabelUser.Width := LUserWidth;

    // Vertically center labels
    LabelUser.Top := (PContainer.Height - LabelUser.Height) div 2;
    LabelArrow.Top := (PContainer.Height - LabelArrow.Height) div 2;
    LabelTier.Top := (PContainer.Height - LabelTier.Height) div 2;
    ImageAvatar.Top := (PContainer.Height - ImageAvatar.Height) div 2;
  end
  else
  begin
    BtnLogin.Visible := False;
    FMenuItemLogin.Visible := True;
    FMenuItemLanguage.Visible := True;
    N1.Visible := False;
    FMenuItemLogoutSeparator.Visible := False;
    MenuItemLogout.Visible := False;
    LabelTier.Visible := False;
    ImageAvatar.Visible := False;
    LabelUser.Visible := True;
    LabelArrow.Visible := True;
    LabelUser.Caption := 'Guest (Login available)';
    LabelArrow.Left := PContainer.ClientWidth - LabelArrow.Width - ArrowRightMargin;
    LUserLeft := GuestLeft;
    LUserWidth := LabelArrow.Left - LUserLeft - UserGap;
    if LUserWidth < 0 then
      LUserWidth := 0;
    LabelUser.Left := LUserLeft;
    LabelUser.Width := LUserWidth;
    LabelUser.Top := (PContainer.Height - LabelUser.Height) div 2;
    LabelArrow.Top := (PContainer.Height - LabelArrow.Height) div 2;
  end;
end;

procedure TFRpLoginFrameVCL.DownloadAvatarAsync(const AUrl: string);
var
  LPayload: TRpQueuedAvatarPayload;
  LRequestVersion: Integer;
  LWorker: TThread;
begin
  if AUrl = '' then Exit;

  Inc(FAvatarRequestVersion);
  LRequestVersion := FAvatarRequestVersion;
  TRpAuthManager.Instance.Log('DownloadAvatar: scheduling ' + AUrl);

  LWorker := TThread.CreateAnonymousThread(
    procedure
    var
      LBytes: TBytes;
      LHttpClient: TNetHTTPClient;
      LResponse: IHTTPResponse;
      LStream: TMemoryStream;
    begin
      LHttpClient := TNetHTTPClient.Create(nil);
      LStream := TMemoryStream.Create;
      try
        TRpAuthManager.Instance.ConfigureDebugHttpClient(LHttpClient);
        try
          LResponse := LHttpClient.Get(AUrl, LStream);
          TRpAuthManager.Instance.Log('DownloadAvatar: status ' + IntToStr(LResponse.StatusCode));
          if LResponse.StatusCode = 200 then
          begin
            SetLength(LBytes, LStream.Size);
            if LStream.Size > 0 then
            begin
              LStream.Position := 0;
              Move(LStream.Memory^, LBytes[0], LStream.Size);
            end;

            LPayload := TRpQueuedAvatarPayload.Create;
            LPayload.RequestVersion := LRequestVersion;
            LPayload.Bytes := Copy(LBytes, 0, Length(LBytes));
            if HandleAllocated then
              PostMessage(Handle, WM_USER + 203, WPARAM(LPayload), 0)
            else
              LPayload.Free;
          end;
        except
          on E: Exception do
            TRpAuthManager.Instance.Log('DownloadAvatar: HTTP error ' + E.Message);
        end;
      finally
        LStream.Free;
        LHttpClient.Free;
      end;
    end);
  LWorker.FreeOnTerminate := True;
  LWorker.Start;
end;

procedure TFRpLoginFrameVCL.WMApplyAvatar(var Message: TMessage);
var
  LPayload: TRpQueuedAvatarPayload;
  LUiStream: TBytesStream;
begin
  LPayload := TRpQueuedAvatarPayload(Message.WParam);
  try
    if LPayload = nil then
      Exit;
    if LPayload.RequestVersion <> FAvatarRequestVersion then
      Exit;

    LUiStream := TBytesStream.Create(LPayload.Bytes);
    try
      try
        ImageAvatar.Picture.LoadFromStream(LUiStream);
        TRpAuthManager.Instance.Log('DownloadAvatar: successfully loaded image.');
      except
        on E: Exception do
          TRpAuthManager.Instance.Log('DownloadAvatar: LoadFromStream error: ' + E.Message);
      end;
    finally
      LUiStream.Free;
    end;
  finally
    LPayload.Free;
  end;
end;

procedure TFRpLoginFrameVCL.BtnLoginClick(Sender: TObject);
begin
  ShowLoginDialog(Self);
end;

procedure TFRpLoginFrameVCL.MenuItemLoginClick(Sender: TObject);
begin
  ShowLoginDialog(Self);
end;

procedure TFRpLoginFrameVCL.ImageAvatarClick(Sender: TObject);
var
  LPoint: TPoint;
begin
  UpdateLanguageMenu;
  LPoint := PContainer.ClientToScreen(Point(PContainer.ClientWidth, PContainer.ClientHeight));
  PopupUser.Popup(LPoint.X, LPoint.Y);
end;

procedure TFRpLoginFrameVCL.MenuItemLanguageClick(Sender: TObject);
begin
  if Sender is TMenuItem then
  begin
    TRpAuthManager.Instance.AILanguage := TMenuItem(Sender).Hint;
    UpdateUI;
  end;
end;

procedure TFRpLoginFrameVCL.MenuItemLogoutClick(Sender: TObject);
begin
  TRpAuthManager.Instance.Logout;
end;

end.
