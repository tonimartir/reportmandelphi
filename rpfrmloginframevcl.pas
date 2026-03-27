unit rpfrmloginframevcl;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Menus, rpauthmanager, rpfrmloginvcl, System.Net.HttpClient, System.Net.HttpClientComponent;

type
  TFRpLoginFrameVCL = class(TFrame)
    PContainer: TPanel;
    ImageAvatar: TImage;
    LabelUser: TLabel;
    BtnLogin: TButton;
    PopupUser: TPopupMenu;
    MenuItemProfile: TMenuItem;
    MenuItemLogout: TMenuItem;
    N1: TMenuItem;
    procedure BtnLoginClick(Sender: TObject);
    procedure MenuItemLogoutClick(Sender: TObject);
    procedure MenuItemProfileClick(Sender: TObject);
    procedure ImageAvatarClick(Sender: TObject);
  private
    FOnAuthChanged: TNotifyEvent;
    procedure UpdateUI;
    procedure AuthChanged(ASuccess: Boolean);
    procedure DownloadAvatar(const AUrl: string);
  protected
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    property OnAuthChanged: TNotifyEvent read FOnAuthChanged write FOnAuthChanged;
  end;

implementation

{$R *.dfm}

constructor TFRpLoginFrameVCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  TRpAuthManager.Instance.OnAuthChanged := AuthChanged;
end;

procedure TFRpLoginFrameVCL.AfterConstruction;
begin
  inherited;
  UpdateUI;
end;

destructor TFRpLoginFrameVCL.Destroy;
var
  LMethod: TMethod;
begin
  LMethod := TMethod(TRpAuthManager.Instance.OnAuthChanged);
  if (LMethod.Code = @TFRpLoginFrameVCL.AuthChanged) and (LMethod.Data = Self) then
    TRpAuthManager.Instance.OnAuthChanged := nil;
  inherited;
end;

procedure TFRpLoginFrameVCL.AuthChanged(ASuccess: Boolean);
begin
  UpdateUI;
  if Assigned(FOnAuthChanged) then
    FOnAuthChanged(Self);
end;

procedure TFRpLoginFrameVCL.UpdateUI;
var
  LProfile: TRpUserProfile;
begin
  if TRpAuthManager.Instance.IsLoggedIn then
  begin
    BtnLogin.Visible := False;
    ImageAvatar.Visible := True;
    LabelUser.Visible := True;
    LProfile := TRpAuthManager.Instance.Profile;
    LabelUser.Caption := LProfile.UserName;
    if LProfile.AvatarUrl <> '' then
      DownloadAvatar(LProfile.AvatarUrl);
  end
  else
  begin
    BtnLogin.Visible := True;
    ImageAvatar.Visible := False;
    LabelUser.Visible := False;
  end;
end;

procedure TFRpLoginFrameVCL.DownloadAvatar(const AUrl: string);
var
  LHttpClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LStream: TMemoryStream;
begin
  // Simple async-ish download (but blocking for now to avoid complexity, 
  // though better done in a thread if it impacts UI)
  LHttpClient := TNetHTTPClient.Create(nil);
  LStream := TMemoryStream.Create;
  try
    try
      LResponse := LHttpClient.Get(AUrl, LStream);
      if LResponse.StatusCode = 200 then
      begin
        LStream.Position := 0;
        ImageAvatar.Picture.LoadFromStream(LStream);
      end;
    except
      // Ignore avatar download errors
    end;
  finally
    LStream.Free;
    LHttpClient.Free;
  end;
end;

procedure TFRpLoginFrameVCL.BtnLoginClick(Sender: TObject);
begin
  ShowLoginDialog(Self);
end;

procedure TFRpLoginFrameVCL.ImageAvatarClick(Sender: TObject);
var
  LPoint: TPoint;
begin
  LPoint := PContainer.ClientToScreen(Point(ImageAvatar.Left, ImageAvatar.Top + ImageAvatar.Height));
  PopupUser.Popup(LPoint.X, LPoint.Y);
end;

procedure TFRpLoginFrameVCL.MenuItemLogoutClick(Sender: TObject);
begin
  TRpAuthManager.Instance.Logout;
end;

procedure TFRpLoginFrameVCL.MenuItemProfileClick(Sender: TObject);
begin
  // Could show another dialog or just open portal
  TRpAuthManager.Instance.OpenUrl(TRpAuthManager.Instance.GetPortalUrl);
end;

end.
