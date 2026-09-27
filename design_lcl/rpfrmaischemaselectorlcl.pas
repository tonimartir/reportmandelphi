{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpfrmaischemaselectorlcl                        }
{       Account card and Hub schema selector            }
{       (LCL port of rpfrmaischemaselectorvcl)          }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpfrmaischemaselectorlcl;

{ The schemas are the ones the user defines on app.reportman.es and binds
  to a Hub database (GET api/agent/databases): the ones of the account plus
  the ones visible with the API key of the preferred connection, merged as
  in the VCL. The VCL loads them in the main thread (hourglass cursor); here
  LoadSchemas starts a TRpAsyncWorker and the combo is filled when the
  answer arrives (Loading, OnSchemasLoaded). The rest of the API is the one
  of TFRpAISchemaSelectorVCL. }

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  rpauthmanager, rpdatahttp, rpaithreadslcl, rpchatmodernstylelcl,
  rpfrmloginframelcl;

type
  TSchemaComboItem = class(TObject)
  public
    ApiKey: string;
    HubDatabaseId: Int64;
    HubSchemaId: Int64;
    constructor Create(AHubDatabaseId, AHubSchemaId: Int64; const AApiKey: string);
  end;

  TFRpAISchemaSelectorLCL = class(TCustomPanel)
  private
    FLoginFrame: TFRpLoginFrameLCL;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
    FPreferredHubDatabaseId: Int64;
    FSchemaApiKey: string;
    FPreferredApiKey: string;
    FLoadingSchemas: Boolean;
    FReloadVersion: Integer;
    FLastLoadOk: Boolean;
    FOnSchemaChanged: TNotifyEvent;
    FOnSchemasLoaded: TNotifyEvent;
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    procedure BuildControls;
    procedure LoginAuthChanged(Sender: TObject);
    procedure ComboSchemaChange(Sender: TObject);
    procedure RefreshSchemasClick(Sender: TObject);
    procedure ClearSchemaItems;
    procedure SelectCurrentSchema;
    procedure ApplyLoadedSchemas(ASchemas: TStrings);
    procedure HandleMessage(AMessage: TRpAsyncMessage);
    procedure UpdateButtons;
    procedure ApplyModernStyling;
  public
    PRoot: TPanel;
    PLoginHost: TPanel;
    PSchemaHost: TPanel;
    PSchemaRow: TPanel;
    LSchema: TLabel;
    ComboSchema: TComboBox;
    BRefreshSchemas: TButton;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Starts loading the schemas in the background
    procedure LoadSchemas;
    procedure SetPreferredConnection(AHubDatabaseId: Int64;
      const AApiKey: string = '');
    procedure SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
      const ASchemaApiKey: string = '');
    function GetHubDatabaseId: Int64;
    function GetHubSchemaId: Int64;
    function GetSchemaApiKey: string;
    property LoginFrame: TFRpLoginFrameLCL read FLoginFrame;
    property Loading: Boolean read FLoadingSchemas;
    // At least one of the requests of the last load answered
    property LastLoadOk: Boolean read FLastLoadOk;
    property OnSchemaChanged: TNotifyEvent read FOnSchemaChanged write FOnSchemaChanged;
    property OnSchemasLoaded: TNotifyEvent read FOnSchemasLoaded write FOnSchemasLoaded;
  end;

implementation

uses
  rpmdconsts, LazUTF8;

type
  TRpSelectorSchemasPayload = class(TRpAsyncMessage)
  public
    ReloadVersion: Integer;
    Ok: Boolean;
    Schemas: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  TRpSelectorSchemasWorker = class(TRpAsyncWorker)
  public
    ReloadVersion: Integer;
    Token: string;
    InstallId: string;
    PreferredApiKey: string;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
  end;

constructor TRpSelectorSchemasPayload.Create;
begin
  inherited Create;
  Schemas := TStringList.Create;
end;

destructor TRpSelectorSchemasPayload.Destroy;
begin
  Schemas.Free;
  inherited Destroy;
end;

procedure AddMergedSchemas(ASource, ADest, ASeenKeys: TStrings; const ADefaultApiKey: string);
var
  I: Integer;
  LValue: string;
begin
  for I := 0 to ASource.Count - 1 do
  begin
    LValue := ASource.ValueFromIndex[I];
    if ASeenKeys.IndexOf(LValue) >= 0 then
      Continue;
    ASeenKeys.Add(LValue);
    ADest.Add(ASource.Names[I] + '=' + LValue + '|' + ADefaultApiKey);
  end;
end;

procedure TRpSelectorSchemasWorker.Run;
var
  LUserSchemas, LApiKeySchemas, LSeenKeys: TStringList;
  LPayload: TRpSelectorSchemasPayload;
  LHttp: TRpDatabaseHttp;
  LOk: Boolean;
begin
  LUserSchemas := TStringList.Create;
  LApiKeySchemas := TStringList.Create;
  LSeenKeys := TStringList.Create;
  LPayload := TRpSelectorSchemasPayload.Create;
  try
    LSeenKeys.Sorted := True;
    LSeenKeys.Duplicates := dupIgnore;
    LOk := False;
    // Schemas visible with the API key of the preferred connection
    if Trim(PreferredApiKey) <> '' then
    begin
      LHttp := TRpDatabaseHttp.Create;
      try
        try
          LHttp.ApiKey := Trim(PreferredApiKey);
          LHttp.Token := Token;
          LHttp.InstallId := InstallId;
          LOk := LHttp.GetUserSchemas(LApiKeySchemas) or LOk;
        except
          LApiKeySchemas.Clear;
        end;
      finally
        LHttp.Free;
      end;
    end;
    // Schemas of the account
    if Trim(Token) <> '' then
    begin
      LHttp := TRpDatabaseHttp.Create;
      try
        try
          LHttp.Token := Token;
          LHttp.InstallId := InstallId;
          LOk := LHttp.GetUserSchemas(LUserSchemas) or LOk;
        except
          LUserSchemas.Clear;
        end;
      finally
        LHttp.Free;
      end;
    end;
    AddMergedSchemas(LApiKeySchemas, LPayload.Schemas, LSeenKeys, PreferredApiKey);
    AddMergedSchemas(LUserSchemas, LPayload.Schemas, LSeenKeys, '');
    LPayload.ReloadVersion := ReloadVersion;
    LPayload.Ok := LOk;
    Post(LPayload);
    LPayload := nil;
  finally
    LPayload.Free;
    LSeenKeys.Free;
    LApiKeySchemas.Free;
    LUserSchemas.Free;
  end;
end;

procedure TRpSelectorSchemasWorker.HandleError(E: Exception);
var
  LPayload: TRpSelectorSchemasPayload;
begin
  LPayload := TRpSelectorSchemasPayload.Create;
  LPayload.ReloadVersion := ReloadVersion;
  Post(LPayload);
end;

{ TSchemaComboItem }

constructor TSchemaComboItem.Create(AHubDatabaseId, AHubSchemaId: Int64;
  const AApiKey: string);
begin
  inherited Create;
  HubDatabaseId := AHubDatabaseId;
  HubSchemaId := AHubSchemaId;
  ApiKey := AApiKey;
end;

{ TFRpAISchemaSelectorLCL }

constructor TFRpAISchemaSelectorLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  Width := Scale(400);
  AutoSize := True;
  FMailbox := TRpAsyncMailbox.Create(HandleMessage);
  FMailboxRef := FMailbox;
  BuildControls;
  ApplyModernStyling;
end;

destructor TFRpAISchemaSelectorLCL.Destroy;
begin
  FMailbox.Detach;
  FMailboxRef := nil;
  ClearSchemaItems;
  inherited Destroy;
end;

procedure TFRpAISchemaSelectorLCL.BuildControls;
begin
  PRoot := TPanel.Create(Self);
  PRoot.Parent := Self;
  PRoot.Align := alTop;
  PRoot.AutoSize := True;
  PRoot.BevelOuter := bvNone;
  PRoot.Caption := '';
  PRoot.BorderSpacing.Top := Scale(8);
  PRoot.BorderSpacing.Bottom := Scale(8);

  // alTop controls are stacked by their Top: login card, then the schema row
  PLoginHost := TPanel.Create(Self);
  PLoginHost.Parent := PRoot;
  PLoginHost.Align := alTop;
  PLoginHost.AutoSize := True;
  PLoginHost.BevelOuter := bvNone;
  PLoginHost.Caption := '';
  PLoginHost.Top := 0;

  PSchemaHost := TPanel.Create(Self);
  PSchemaHost.Parent := PRoot;
  PSchemaHost.Top := 1000;
  PSchemaHost.Align := alTop;
  PSchemaHost.AutoSize := True;
  PSchemaHost.BevelOuter := bvNone;
  PSchemaHost.Caption := '';
  PSchemaHost.BorderSpacing.Top := Scale(4);

  LSchema := TLabel.Create(Self);
  LSchema.Parent := PSchemaHost;
  LSchema.Top := 0;
  LSchema.Align := alTop;
  LSchema.Caption := UTF8UpperCase(TranslateStr(1528, 'Schema'));
  LSchema.Layout := tlBottom;

  PSchemaRow := TPanel.Create(Self);
  PSchemaRow.Parent := PSchemaHost;
  PSchemaRow.Top := 1000;
  PSchemaRow.Align := alTop;
  PSchemaRow.AutoSize := True;
  PSchemaRow.BevelOuter := bvNone;
  PSchemaRow.Caption := '';

  BRefreshSchemas := TButton.Create(Self);
  BRefreshSchemas.Parent := PSchemaRow;
  BRefreshSchemas.Align := alRight;
  BRefreshSchemas.Width := Scale(76);
  BRefreshSchemas.Caption := TranslateStr(1149, 'Refresh');
  BRefreshSchemas.OnClick := RefreshSchemasClick;

  ComboSchema := TComboBox.Create(Self);
  ComboSchema.Parent := PSchemaRow;
  ComboSchema.Align := alClient;
  ComboSchema.Style := csDropDownList;
  ComboSchema.OnChange := ComboSchemaChange;
  ComboSchema.BorderSpacing.Right := Scale(4);

  FLoginFrame := TFRpLoginFrameLCL.Create(Self);
  FLoginFrame.Parent := PLoginHost;
  FLoginFrame.Align := alTop;
  FLoginFrame.OnAuthChanged := LoginAuthChanged;
end;

procedure TFRpAISchemaSelectorLCL.ApplyModernStyling;
begin
  TRpChatStyle.StylePanelBg(PRoot);
  TRpChatStyle.StylePanelBg(PLoginHost);
  TRpChatStyle.StylePanelBg(PSchemaHost);
  TRpChatStyle.StylePanelBg(PSchemaRow);
  TRpChatStyle.StyleInputControl(ComboSchema);
  TRpChatStyle.StyleInputControl(BRefreshSchemas);
end;

procedure TFRpAISchemaSelectorLCL.UpdateButtons;
begin
  BRefreshSchemas.Enabled := not FLoadingSchemas;
  if FLoadingSchemas then
    BRefreshSchemas.Caption := '...'
  else
    BRefreshSchemas.Caption := TranslateStr(1149, 'Refresh');
end;

procedure TFRpAISchemaSelectorLCL.ClearSchemaItems;
var
  I: Integer;
begin
  for I := 0 to ComboSchema.Items.Count - 1 do
    ComboSchema.Items.Objects[I].Free;
  ComboSchema.Clear;
end;

procedure TFRpAISchemaSelectorLCL.SelectCurrentSchema;
var
  I: Integer;
  LItem: TSchemaComboItem;
  LFound: Boolean;
begin
  if ComboSchema.Items.Count = 0 then
    Exit;
  LFound := False;
  if FHubSchemaId <> 0 then
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
  if (not LFound) and (FHubDatabaseId <> 0) then
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
  if (not LFound) and (FPreferredHubDatabaseId <> 0) then
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

procedure TFRpAISchemaSelectorLCL.ApplyLoadedSchemas(ASchemas: TStrings);
var
  I: Integer;
  LParts, LPreferred, LOther, LTarget: TStringList;
  LHubDatabaseId: Int64;

  procedure AppendSchemaLines(ALines: TStrings);
  var
    J: Integer;
    LDbId, LSchemaId: Int64;
    LApiKey: string;
  begin
    for J := 0 to ALines.Count - 1 do
    begin
      LParts.DelimitedText := ALines.ValueFromIndex[J];
      if LParts.Count >= 2 then
      begin
        LDbId := StrToInt64Def(LParts[0], 0);
        LSchemaId := StrToInt64Def(LParts[1], 0);
      end
      else
      begin
        LDbId := 0;
        LSchemaId := 0;
      end;
      if LParts.Count >= 3 then
        LApiKey := LParts[2]
      else
        LApiKey := '';
      ComboSchema.Items.AddObject(ALines.Names[J],
        TSchemaComboItem.Create(LDbId, LSchemaId, LApiKey));
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
    // Schemas of the preferred database first
    for I := 0 to ASchemas.Count - 1 do
    begin
      LParts.DelimitedText := ASchemas.ValueFromIndex[I];
      if LParts.Count >= 2 then
        LHubDatabaseId := StrToInt64Def(LParts[0], 0)
      else
        LHubDatabaseId := 0;
      if (FPreferredHubDatabaseId <> 0) and (LHubDatabaseId = FPreferredHubDatabaseId) then
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

procedure TFRpAISchemaSelectorLCL.HandleMessage(AMessage: TRpAsyncMessage);
var
  LPayload: TRpSelectorSchemasPayload;
begin
  if not (AMessage is TRpSelectorSchemasPayload) then
    Exit;
  LPayload := TRpSelectorSchemasPayload(AMessage);
  if LPayload.ReloadVersion <> FReloadVersion then
    Exit;
  FLastLoadOk := LPayload.Ok;
  ApplyLoadedSchemas(LPayload.Schemas);
  if Assigned(FOnSchemasLoaded) then
    FOnSchemasLoaded(Self);
end;

procedure TFRpAISchemaSelectorLCL.LoadSchemas;
var
  LWorker: TRpSelectorSchemasWorker;
begin
  Inc(FReloadVersion);
  FLoadingSchemas := True;
  UpdateButtons;
  LWorker := TRpSelectorSchemasWorker.Create(FMailboxRef);
  LWorker.ReloadVersion := FReloadVersion;
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.PreferredApiKey := FPreferredApiKey;
  LWorker.Start;
end;

procedure TFRpAISchemaSelectorLCL.LoginAuthChanged(Sender: TObject);
begin
  LoadSchemas;
end;

procedure TFRpAISchemaSelectorLCL.ComboSchemaChange(Sender: TObject);
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

procedure TFRpAISchemaSelectorLCL.RefreshSchemasClick(Sender: TObject);
begin
  LoadSchemas;
end;

procedure TFRpAISchemaSelectorLCL.SetPreferredConnection(AHubDatabaseId: Int64;
  const AApiKey: string);
begin
  FPreferredHubDatabaseId := AHubDatabaseId;
  FPreferredApiKey := Trim(AApiKey);
end;

procedure TFRpAISchemaSelectorLCL.SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
  const ASchemaApiKey: string);
begin
  FHubDatabaseId := AHubDatabaseId;
  FHubSchemaId := AHubSchemaId;
  FSchemaApiKey := Trim(ASchemaApiKey);
  SelectCurrentSchema;
end;

function TFRpAISchemaSelectorLCL.GetHubDatabaseId: Int64;
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

function TFRpAISchemaSelectorLCL.GetHubSchemaId: Int64;
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

function TFRpAISchemaSelectorLCL.GetSchemaApiKey: string;
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
