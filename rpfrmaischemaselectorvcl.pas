unit rpfrmaischemaselectorvcl;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls,
  rpauthmanager, rpfrmloginframevcl, rpdatahttp, rpchatmodernstyle;

type
  TSchemaComboItem = class(TObject)
  public
    ApiKey: string;
    HubDatabaseId: Int64;
    HubSchemaId: Int64;
    constructor Create(AHubDatabaseId, AHubSchemaId: Int64;
      const AApiKey: string);
  end;

  TFRpAISchemaSelectorVCL = class(TFrame)
  private
    PRoot: TPanel;
    PLoginHost: TPanel;
    PSchemaHost: TPanel;
    PSchemaRow: TPanel;
    LSchema: TLabel;
    ComboSchema: TComboBox;
    BRefreshSchemas: TButton;
    FLoginFrame: TFRpLoginFrameVCL;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
    FPreferredHubDatabaseId: Int64;
    FSchemaApiKey: string;
    FPreferredApiKey: string;
    FLoadingSchemas: Boolean;
    FOnSchemaChanged: TNotifyEvent;
    procedure LoginAuthChanged(Sender: TObject);
    procedure ComboSchemaChange(Sender: TObject);
    procedure RefreshSchemasClick(Sender: TObject);
    procedure ClearSchemaItems;
    procedure SelectCurrentSchema;
    procedure ApplyLoadedSchemas(ASchemas: TStrings);
    function LoadUserSchemas(AList: TStrings): Boolean;
    function LoadApiKeySchemas(const AApiKey: string; AList: TStrings): Boolean;
    procedure AddMergedSchemas(ASource, ADest, ASeenKeys: TStrings;
      const ADefaultApiKey: string);
    procedure UpdateButtons;
    procedure ApplyModernStyling;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadSchemas;
    procedure SetPreferredConnection(AHubDatabaseId: Int64;
      const AApiKey: string = '');
    procedure SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
      const ASchemaApiKey: string = '');
    function GetHubDatabaseId: Int64;
    function GetHubSchemaId: Int64;
    function GetSchemaApiKey: string;
    property OnSchemaChanged: TNotifyEvent read FOnSchemaChanged write FOnSchemaChanged;
  end;

implementation

{$R *.dfm}

constructor TSchemaComboItem.Create(AHubDatabaseId, AHubSchemaId: Int64;
  const AApiKey: string);
begin
  inherited Create;
  HubDatabaseId := AHubDatabaseId;
  HubSchemaId := AHubSchemaId;
  ApiKey := AApiKey;
end;

constructor TFRpAISchemaSelectorVCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 400;
  Height := 110;
  FHubDatabaseId := 0;
  FHubSchemaId := 0;
  FPreferredHubDatabaseId := 0;
  FSchemaApiKey := '';
  FPreferredApiKey := '';
  FLoadingSchemas := False;

  PRoot := TPanel.Create(Self);
  PRoot.Parent := Self;
  PRoot.Align := alClient;
  PRoot.BevelOuter := bvNone;
  PRoot.ParentBackground := False;

  PLoginHost := TPanel.Create(Self);
  PLoginHost.Parent := PRoot;
  PLoginHost.Align := alTop;
  PLoginHost.Height := 48;
  PLoginHost.BevelOuter := bvNone;
  PLoginHost.ParentBackground := False;

  PSchemaHost := TPanel.Create(Self);
  PSchemaHost.Parent := PRoot;
  PSchemaHost.Align := alTop;
  PSchemaHost.Height := 54;
  PSchemaHost.BevelOuter := bvNone;
  PSchemaHost.ParentBackground := False;

  LSchema := TLabel.Create(Self);
  LSchema.Parent := PSchemaHost;
  LSchema.Align := alTop;
  LSchema.Height := 16;
  LSchema.Caption := 'SCHEMA';
  LSchema.Layout := tlBottom;

  PSchemaRow := TPanel.Create(Self);
  PSchemaRow.Parent := PSchemaHost;
  PSchemaRow.Align := alClient;
  PSchemaRow.BevelOuter := bvNone;
  PSchemaRow.ParentBackground := False;

  BRefreshSchemas := TButton.Create(Self);
  BRefreshSchemas.Parent := PSchemaRow;
  BRefreshSchemas.Align := alRight;
  BRefreshSchemas.Width := 78;
  BRefreshSchemas.Caption := 'Refresh';
  BRefreshSchemas.OnClick := RefreshSchemasClick;

  ComboSchema := TComboBox.Create(Self);
  ComboSchema.Parent := PSchemaRow;
  ComboSchema.Align := alClient;
  ComboSchema.Style := csDropDownList;
  ComboSchema.OnChange := ComboSchemaChange;

  FLoginFrame := TFRpLoginFrameVCL.Create(Self);
  FLoginFrame.Parent := PLoginHost;
  FLoginFrame.Align := alClient;
  FLoginFrame.OnAuthChanged := LoginAuthChanged;

  ApplyModernStyling;
end;

destructor TFRpAISchemaSelectorVCL.Destroy;
begin
  ClearSchemaItems;
  inherited Destroy;
end;

procedure TFRpAISchemaSelectorVCL.ApplyModernStyling;
begin
  TRpChatStyle.StylePanelBg(PRoot);
  TRpChatStyle.StylePanelBg(PLoginHost);
  TRpChatStyle.StylePanelBg(PSchemaHost);
  TRpChatStyle.StylePanelBg(PSchemaRow);

  LSchema.ParentFont := False;
  LSchema.Font.Name := FontNameUi;
  LSchema.Font.Size := FontSizeMicro;
  LSchema.Font.Style := [fsBold];
  LSchema.Font.Color := ClrSubText;

  ComboSchema.ParentFont := False;
  ComboSchema.Font.Name := FontNameUi;
  ComboSchema.Font.Size := FontSizeUi;
  ComboSchema.Font.Color := ClrText;

  BRefreshSchemas.ParentFont := False;
  BRefreshSchemas.Font.Name := FontNameUi;
  BRefreshSchemas.Font.Size := FontSizeUi;
end;

procedure TFRpAISchemaSelectorVCL.UpdateButtons;
begin
  BRefreshSchemas.Enabled := not FLoadingSchemas;
  if FLoadingSchemas then
    BRefreshSchemas.Caption := '...'
  else
    BRefreshSchemas.Caption := 'Refresh';
end;

procedure TFRpAISchemaSelectorVCL.ClearSchemaItems;
var
  I: Integer;
begin
  for I := 0 to ComboSchema.Items.Count - 1 do
    if Assigned(ComboSchema.Items.Objects[I]) then
      ComboSchema.Items.Objects[I].Free;
  ComboSchema.Clear;
end;

function TFRpAISchemaSelectorVCL.LoadUserSchemas(AList: TStrings): Boolean;
var
  LHttp: TRpDatabaseHttp;
begin
  Result := False;
  AList.Clear;
  if Trim(TRpAuthManager.Instance.Token) = '' then
    Exit;

  LHttp := TRpDatabaseHttp.Create;
  try
    LHttp.Token := TRpAuthManager.Instance.Token;
    LHttp.InstallId := TRpAuthManager.Instance.InstallId;
    Result := LHttp.GetUserSchemas(AList);
  finally
    LHttp.Free;
  end;
end;

function TFRpAISchemaSelectorVCL.LoadApiKeySchemas(const AApiKey: string;
  AList: TStrings): Boolean;
var
  LHttp: TRpDatabaseHttp;
begin
  Result := False;
  AList.Clear;
  if Trim(AApiKey) = '' then
    Exit;

  LHttp := TRpDatabaseHttp.Create;
  try
    LHttp.ApiKey := Trim(AApiKey);
    LHttp.Token := TRpAuthManager.Instance.Token;
    LHttp.InstallId := TRpAuthManager.Instance.InstallId;
    Result := LHttp.GetUserSchemas(AList);
  finally
    LHttp.Free;
  end;
end;

procedure TFRpAISchemaSelectorVCL.AddMergedSchemas(ASource, ADest,
  ASeenKeys: TStrings; const ADefaultApiKey: string);
var
  I: Integer;
  LDisplayName: string;
  LValue: string;
  LSchemaKey: string;
begin
  for I := 0 to ASource.Count - 1 do
  begin
    LDisplayName := ASource.Names[I];
    LValue := ASource.ValueFromIndex[I];
    LSchemaKey := LValue;
    if ASeenKeys.IndexOf(LSchemaKey) >= 0 then
      Continue;
    ASeenKeys.Add(LSchemaKey);
    ADest.Add(LDisplayName + '=' + LValue + '|' + ADefaultApiKey);
  end;
end;

procedure TFRpAISchemaSelectorVCL.SelectCurrentSchema;
var
  I: Integer;
  LItem: TSchemaComboItem;
  LFound: Boolean;
begin
  if ComboSchema.Items.Count = 0 then
    Exit;

  LFound := False;
  if FHubSchemaId <> 0 then
  begin
    for I := 1 to ComboSchema.Items.Count - 1 do
    begin
      LItem := TSchemaComboItem(ComboSchema.Items.Objects[I]);
      if (LItem <> nil) and (LItem.HubSchemaId = FHubSchemaId) then
      begin
        ComboSchema.ItemIndex := I;
        FHubDatabaseId := LItem.HubDatabaseId;
        FSchemaApiKey := LItem.ApiKey;
        LFound := True;
        Break;
      end;
    end;
  end;

  if (not LFound) and (FHubDatabaseId <> 0) then
  begin
    for I := 1 to ComboSchema.Items.Count - 1 do
    begin
      LItem := TSchemaComboItem(ComboSchema.Items.Objects[I]);
      if (LItem <> nil) and (LItem.HubDatabaseId = FHubDatabaseId) then
      begin
        ComboSchema.ItemIndex := I;
        FHubSchemaId := LItem.HubSchemaId;
        FSchemaApiKey := LItem.ApiKey;
        LFound := True;
        Break;
      end;
    end;
  end;

  if (not LFound) and (FPreferredHubDatabaseId <> 0) then
  begin
    for I := 1 to ComboSchema.Items.Count - 1 do
    begin
      LItem := TSchemaComboItem(ComboSchema.Items.Objects[I]);
      if (LItem <> nil) and (LItem.HubDatabaseId = FPreferredHubDatabaseId) then
      begin
        ComboSchema.ItemIndex := I;
        FHubDatabaseId := LItem.HubDatabaseId;
        FHubSchemaId := LItem.HubSchemaId;
        FSchemaApiKey := LItem.ApiKey;
        LFound := True;
        Break;
      end;
    end;
  end;

  if not LFound then
  begin
    if ComboSchema.Items.Count > 1 then
    begin
      ComboSchema.ItemIndex := 1;
      LItem := TSchemaComboItem(ComboSchema.Items.Objects[1]);
      if LItem <> nil then
      begin
        FHubDatabaseId := LItem.HubDatabaseId;
        FHubSchemaId := LItem.HubSchemaId;
        FSchemaApiKey := LItem.ApiKey;
      end;
    end
    else
    begin
      ComboSchema.ItemIndex := 0;
      FHubDatabaseId := 0;
      FHubSchemaId := 0;
      FSchemaApiKey := '';
    end;
  end;
end;

procedure TFRpAISchemaSelectorVCL.ApplyLoadedSchemas(ASchemas: TStrings);
var
  I: Integer;
  LDisplayName: string;
  LValue: string;
  LParts: TStringList;
  LPreferred: TStringList;
  LOther: TStringList;
  LTarget: TStringList;
  LHubDatabaseId: Int64;
  LHubSchemaId: Int64;
  LApiKey: string;

  procedure AppendSchemaLines(ALines: TStrings);
  var
    J: Integer;
  begin
    for J := 0 to ALines.Count - 1 do
    begin
      LDisplayName := ALines.Names[J];
      LValue := ALines.ValueFromIndex[J];
      LParts.DelimitedText := LValue;
      if LParts.Count >= 2 then
      begin
        LHubDatabaseId := StrToInt64Def(LParts[0], 0);
        LHubSchemaId := StrToInt64Def(LParts[1], 0);
      end
      else
      begin
        LHubDatabaseId := 0;
        LHubSchemaId := 0;
      end;
      if LParts.Count >= 3 then
        LApiKey := LParts[2]
      else
        LApiKey := '';
      ComboSchema.Items.AddObject(LDisplayName,
        TSchemaComboItem.Create(LHubDatabaseId, LHubSchemaId, LApiKey));
    end;
  end;
begin
  ComboSchema.Items.BeginUpdate;
  LParts := TStringList.Create;
  LPreferred := TStringList.Create;
  LOther := TStringList.Create;
  try
    LParts.Delimiter := '|';
    LParts.StrictDelimiter := True;
    ClearSchemaItems;
    ComboSchema.Items.Add('');

    for I := 0 to ASchemas.Count - 1 do
    begin
      LValue := ASchemas.ValueFromIndex[I];
      LParts.DelimitedText := LValue;
      if LParts.Count >= 2 then
        LHubDatabaseId := StrToInt64Def(LParts[0], 0)
      else
        LHubDatabaseId := 0;
      if (FPreferredHubDatabaseId <> 0) and
        (LHubDatabaseId = FPreferredHubDatabaseId) then
        LTarget := LPreferred
      else
        LTarget := LOther;
      LTarget.Add(ASchemas[I]);
    end;

    AppendSchemaLines(LPreferred);
    AppendSchemaLines(LOther);
    SelectCurrentSchema;
  finally
    LOther.Free;
    LPreferred.Free;
    LParts.Free;
    ComboSchema.Items.EndUpdate;
    FLoadingSchemas := False;
    ComboSchemaChange(ComboSchema);
    UpdateButtons;
  end;
end;

procedure TFRpAISchemaSelectorVCL.LoadSchemas;
var
  LUserSchemas: TStringList;
  LApiKeySchemas: TStringList;
  LMergedSchemas: TStringList;
  LSeenKeys: TStringList;
begin
  FLoadingSchemas := True;
  UpdateButtons;
  Screen.Cursor := crHourGlass;
  LUserSchemas := TStringList.Create;
  LApiKeySchemas := TStringList.Create;
  LMergedSchemas := TStringList.Create;
  LSeenKeys := TStringList.Create;
  try
    LSeenKeys.Sorted := True;
    LSeenKeys.Duplicates := dupIgnore;
    try
      LoadApiKeySchemas(FPreferredApiKey, LApiKeySchemas);
    except
      LApiKeySchemas.Clear;
    end;
    try
      LoadUserSchemas(LUserSchemas);
    except
      LUserSchemas.Clear;
    end;

    AddMergedSchemas(LApiKeySchemas, LMergedSchemas, LSeenKeys, FPreferredApiKey);
    AddMergedSchemas(LUserSchemas, LMergedSchemas, LSeenKeys, '');
    ApplyLoadedSchemas(LMergedSchemas);
  finally
    LSeenKeys.Free;
    LMergedSchemas.Free;
    LApiKeySchemas.Free;
    LUserSchemas.Free;
    Screen.Cursor := crDefault;
  end;
end;

procedure TFRpAISchemaSelectorVCL.LoginAuthChanged(Sender: TObject);
begin
  LoadSchemas;
end;

procedure TFRpAISchemaSelectorVCL.ComboSchemaChange(Sender: TObject);
var
  LItem: TSchemaComboItem;
begin
  if FLoadingSchemas then
    Exit;

  if ComboSchema.ItemIndex > 0 then
  begin
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[ComboSchema.ItemIndex]);
    if LItem <> nil then
    begin
      FHubDatabaseId := LItem.HubDatabaseId;
      FHubSchemaId := LItem.HubSchemaId;
      FSchemaApiKey := LItem.ApiKey;
    end;
  end
  else
  begin
    FHubDatabaseId := 0;
    FHubSchemaId := 0;
    FSchemaApiKey := '';
  end;

  if Assigned(FOnSchemaChanged) then
    FOnSchemaChanged(Self);
end;

procedure TFRpAISchemaSelectorVCL.RefreshSchemasClick(Sender: TObject);
begin
  LoadSchemas;
end;

procedure TFRpAISchemaSelectorVCL.SetPreferredConnection(
  AHubDatabaseId: Int64; const AApiKey: string);
begin
  FPreferredHubDatabaseId := AHubDatabaseId;
  FPreferredApiKey := Trim(AApiKey);
end;

procedure TFRpAISchemaSelectorVCL.SetHubContext(AHubDatabaseId,
  AHubSchemaId: Int64; const ASchemaApiKey: string);
begin
  FHubDatabaseId := AHubDatabaseId;
  FHubSchemaId := AHubSchemaId;
  FSchemaApiKey := Trim(ASchemaApiKey);
  SelectCurrentSchema;
end;

function TFRpAISchemaSelectorVCL.GetHubDatabaseId: Int64;
var
  LItem: TSchemaComboItem;
begin
  if ComboSchema.ItemIndex > 0 then
  begin
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[ComboSchema.ItemIndex]);
    if LItem <> nil then
      Exit(LItem.HubDatabaseId);
  end;
  Result := FHubDatabaseId;
end;

function TFRpAISchemaSelectorVCL.GetHubSchemaId: Int64;
var
  LItem: TSchemaComboItem;
begin
  if ComboSchema.ItemIndex > 0 then
  begin
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[ComboSchema.ItemIndex]);
    if LItem <> nil then
      Exit(LItem.HubSchemaId);
  end;
  Result := FHubSchemaId;
end;

function TFRpAISchemaSelectorVCL.GetSchemaApiKey: string;
var
  LItem: TSchemaComboItem;
begin
  if ComboSchema.ItemIndex > 0 then
  begin
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[ComboSchema.ItemIndex]);
    if LItem <> nil then
      Exit(LItem.ApiKey);
  end;
  Result := FSchemaApiKey;
end;

end.