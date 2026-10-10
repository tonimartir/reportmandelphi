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
  of TFRpAISchemaSelectorVCL.

  The list of the new report wizard, as the selector of the copilot
  (docs/esquemas-locales-pantalla-plan.md 5.7.1 A and B3): no schema first
  (choosing one is optional), the local subschemas of the direct connection
  of the report (SetLocalSchemas), the schemas in the cloud, each one with
  its icon, then "New local schema..." (OnNewLocalSchema) and "New cloud
  schema..." (the web). All the tables of a direct connection are never
  offered: only a subschema goes to the AI. }

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  rpauthmanager, rpdatahttp, rpaithreadslcl, rpchatmodernstylelcl,
  rpfrmloginframelcl;

type
  TRpSchemaSelectorItemKind = (sikHub, sikLocal, sikHeader, sikNewLocal,
    sikNewCloud);

  TSchemaComboItem = class(TObject)
  public
    Kind: TRpSchemaSelectorItemKind;
    ApiKey: string;
    HubDatabaseId: Int64;
    HubSchemaId: Int64;
    // A subschema of the direct connection
    LocalName: string;
    constructor Create(AHubDatabaseId, AHubSchemaId: Int64; const AApiKey: string);
    constructor CreateKind(AKind: TRpSchemaSelectorItemKind);
    // A schema the AI can use, not a header or an action
    function IsSchema: Boolean;
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
    FOnNewLocalSchema: TNotifyEvent;
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    // The cloud schemas as loaded ('Name=db|schema|apikey') and their sizes
    // ('<schema>=<tables>,<widest>')
    FCloudLines: TStringList;
    FCloudSizes: TStringList;
    FCloudLoaded: Boolean;
    FCloudDatabaseFilter: Int64;
    // The direct connection and its subschemas (sizes '<tables>,<widest>')
    FLocalAlias: string;
    FLocalNames: TStringList;
    FLocalSizes: TStringList;
    FLocalName: string;
    // The list is being changed by code: no change of the user
    FSelecting: Boolean;
    FLastIndex: Integer;
    // The open list was just closed (ComboSchemaCloseUp)
    FListClosing: Boolean;
    procedure BuildControls;
    procedure LoginAuthChanged(Sender: TObject);
    procedure ComboSchemaChange(Sender: TObject);
    procedure ComboSchemaCloseUp(Sender: TObject);
    procedure RefreshSchemasClick(Sender: TObject);
    procedure ClearSchemaItems;
    procedure RebuildItems;
    procedure SelectCurrentSchema;
    procedure ApplySelectedItem;
    procedure RunAction(Data: PtrInt);
    procedure ListClosed(Data: PtrInt);
    function SchemaItem(AIndex: Integer): TSchemaComboItem;
    procedure ApplyLoadedSchemas(ASchemas, ASizes: TStrings);
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
    // The subschemas of the direct connection AAlias (ASizes, one per name,
    // '<tables>,<widest columns>' or ''), listed with "New local
    // schema..."; AAlias '' = no direct connection
    procedure SetLocalSchemas(const AAlias: string; ANames, ASizes: TStrings);
    // Chooses a subschema of the direct connection
    procedure SelectLocalSchema(const AName: string);
    // A cloud schema chosen: its Hub database, schema and API key (0, '' with
    // a subschema or none)
    function GetHubDatabaseId: Int64;
    function GetHubSchemaId: Int64;
    function GetSchemaApiKey: string;
    // The subschema chosen ('' = a cloud schema or none)
    function GetLocalSchemaName: string;
    property LoginFrame: TFRpLoginFrameLCL read FLoginFrame;
    property Loading: Boolean read FLoadingSchemas;
    // At least one of the requests of the last load answered
    property LastLoadOk: Boolean read FLastLoadOk;
    // Only the cloud schemas of this Hub database (the Reportman AI Agent
    // connection of the report); 0 = all of them
    property CloudDatabaseFilter: Int64 read FCloudDatabaseFilter
      write FCloudDatabaseFilter;
    property OnSchemaChanged: TNotifyEvent read FOnSchemaChanged write FOnSchemaChanged;
    property OnSchemasLoaded: TNotifyEvent read FOnSchemasLoaded write FOnSchemasLoaded;
    // "New local schema..." chosen: the host opens the local schema screen
    // of the connection and gives the list again (SetLocalSchemas)
    property OnNewLocalSchema: TNotifyEvent read FOnNewLocalSchema
      write FOnNewLocalSchema;
  end;

implementation

uses
  rpmdconsts, LazUTF8;

const
  // The text of the list (UTF-8, the encoding of the LCL strings), as the
  // selector of the copilot
  CSchemaSeparator = ' '#$C2#$B7' ';
  CSchemaRule = #$E2#$94#$80#$E2#$94#$80;
  CSchemaLocalIcon = #$E2#$9B#$81' ';
  CSchemaCloudIcon = #$E2#$98#$81' ';
  CNewCloudSchemaUrl = 'https://app.reportman.es/database-config?new=1';

type
  TRpSelectorSchemasPayload = class(TRpAsyncMessage)
  public
    ReloadVersion: Integer;
    Ok: Boolean;
    Schemas: TStringList;
    // '<hubSchemaId>=<tables>,<widest columns>'
    Sizes: TStringList;
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

// ' (N)': the tables that would travel, when known
function SizeSuffix(const ASize: string): string;
var
  LPos, LTables: Integer;
begin
  Result := '';
  LPos := Pos(',', ASize);
  if LPos <= 0 then
    Exit;
  LTables := StrToIntDef(Copy(ASize, 1, LPos - 1), -1);
  if LTables >= 0 then
    Result := ' (' + IntToStr(LTables) + ')';
end;

constructor TRpSelectorSchemasPayload.Create;
begin
  inherited Create;
  Schemas := TStringList.Create;
  Sizes := TStringList.Create;
end;

destructor TRpSelectorSchemasPayload.Destroy;
begin
  Sizes.Free;
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
  LUserSchemas, LApiKeySchemas, LSeenKeys, LRawSizes: TStringList;
  LPayload: TRpSelectorSchemasPayload;
  LHttp: TRpDatabaseHttp;
  LOk: Boolean;
begin
  LUserSchemas := TStringList.Create;
  LApiKeySchemas := TStringList.Create;
  LSeenKeys := TStringList.Create;
  LRawSizes := TStringList.Create;
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
          LOk := LHttp.GetUserSchemas(LApiKeySchemas, LRawSizes) or LOk;
          LPayload.Sizes.AddStrings(LRawSizes);
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
          LOk := LHttp.GetUserSchemas(LUserSchemas, LRawSizes) or LOk;
          LPayload.Sizes.AddStrings(LRawSizes);
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
    LRawSizes.Free;
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
  Kind := sikHub;
  HubDatabaseId := AHubDatabaseId;
  HubSchemaId := AHubSchemaId;
  ApiKey := AApiKey;
end;

constructor TSchemaComboItem.CreateKind(AKind: TRpSchemaSelectorItemKind);
begin
  inherited Create;
  Kind := AKind;
end;

function TSchemaComboItem.IsSchema: Boolean;
begin
  Result := Kind in [sikHub, sikLocal];
end;

{ TFRpAISchemaSelectorLCL }

constructor TFRpAISchemaSelectorLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  Width := Scale(400);
  AutoSize := True;
  FCloudLines := TStringList.Create;
  FCloudSizes := TStringList.Create;
  FLocalNames := TStringList.Create;
  FLocalSizes := TStringList.Create;
  FLastIndex := -1;
  FMailbox := TRpAsyncMailbox.Create(HandleMessage);
  FMailboxRef := FMailbox;
  BuildControls;
  ApplyModernStyling;
end;

destructor TFRpAISchemaSelectorLCL.Destroy;
begin
  // An action or a closed list still queued
  Application.RemoveAsyncCalls(Self);
  FMailbox.Detach;
  FMailboxRef := nil;
  ClearSchemaItems;
  FCloudLines.Free;
  FCloudSizes.Free;
  FLocalNames.Free;
  FLocalSizes.Free;
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
  ComboSchema.OnCloseUp := ComboSchemaCloseUp;
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

function TFRpAISchemaSelectorLCL.SchemaItem(AIndex: Integer): TSchemaComboItem;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex < ComboSchema.Items.Count) then
    Result := TSchemaComboItem(ComboSchema.Items.Objects[AIndex]);
end;

// The list: none, the subschemas, the schemas in the cloud (the preferred
// database first) and the two actions
procedure TFRpAISchemaSelectorLCL.RebuildItems;
var
  I: Integer;
  LParts, LPreferred, LOther: TStringList;
  LHubDatabaseId: Int64;
  LItem: TSchemaComboItem;

  procedure AddHeader(const AText: string);
  begin
    LItem := TSchemaComboItem.CreateKind(sikHeader);
    ComboSchema.Items.AddObject(AText, LItem);
  end;

  procedure AppendCloudLines(ALines: TStrings);
  var
    J: Integer;
    LDbId, LSchemaId: Int64;
    LApiKey: string;
  begin
    for J := 0 to ALines.Count - 1 do
    begin
      LParts.DelimitedText := ALines.ValueFromIndex[J];
      LDbId := 0;
      LSchemaId := 0;
      LApiKey := '';
      if LParts.Count >= 2 then
      begin
        LDbId := StrToInt64Def(LParts[0], 0);
        LSchemaId := StrToInt64Def(LParts[1], 0);
      end;
      if LParts.Count >= 3 then
        LApiKey := LParts[2];
      ComboSchema.Items.AddObject(CSchemaCloudIcon + ALines.Names[J] +
        SizeSuffix(FCloudSizes.Values[IntToStr(LSchemaId)]),
        TSchemaComboItem.Create(LDbId, LSchemaId, LApiKey));
    end;
  end;

begin
  ComboSchema.Items.BeginUpdate;
  LParts := TStringList.Create;
  LPreferred := TStringList.Create;
  LOther := TStringList.Create;
  FSelecting := True;
  try
    LParts.Delimiter := '|';
    LParts.StrictDelimiter := True;
    ClearSchemaItems;
    // No schema: the report is designed by hand
    ComboSchema.Items.Add(TranslateStr(1994, 'No schema (design by hand)'));
    if (FLocalAlias <> '') and (FLocalNames.Count > 0) then
    begin
      AddHeader(CSchemaRule + ' ' + string(TranslateStr(1836, 'Local')) + ' ' +
        CSchemaRule);
      for I := 0 to FLocalNames.Count - 1 do
      begin
        LItem := TSchemaComboItem.CreateKind(sikLocal);
        LItem.LocalName := FLocalNames[I];
        if I < FLocalSizes.Count then
          ComboSchema.Items.AddObject(CSchemaLocalIcon + FLocalAlias +
            CSchemaSeparator + FLocalNames[I] + SizeSuffix(FLocalSizes[I]), LItem)
        else
          ComboSchema.Items.AddObject(CSchemaLocalIcon + FLocalAlias +
            CSchemaSeparator + FLocalNames[I], LItem);
      end;
    end;
    for I := 0 to FCloudLines.Count - 1 do
    begin
      LParts.DelimitedText := FCloudLines.ValueFromIndex[I];
      LHubDatabaseId := 0;
      if LParts.Count >= 2 then
        LHubDatabaseId := StrToInt64Def(LParts[0], 0);
      // The Agent route: the schemas of its Hub database only
      if (FCloudDatabaseFilter <> 0) and (LHubDatabaseId <> FCloudDatabaseFilter) then
        Continue;
      if (FPreferredHubDatabaseId <> 0) and
        (LHubDatabaseId = FPreferredHubDatabaseId) then
        LPreferred.Add(FCloudLines[I])
      else
        LOther.Add(FCloudLines[I]);
    end;
    if LPreferred.Count + LOther.Count > 0 then
    begin
      AddHeader(CSchemaRule + ' ' + string(TranslateStr(1837, 'In the cloud')) +
        ' ' + CSchemaRule);
      AppendCloudLines(LPreferred);
      AppendCloudLines(LOther);
    end;
    AddHeader(CSchemaRule + CSchemaRule + CSchemaRule + CSchemaRule + CSchemaRule);
    // Without a direct connection there is no local schema to make
    if FLocalAlias <> '' then
    begin
      LItem := TSchemaComboItem.CreateKind(sikNewLocal);
      ComboSchema.Items.AddObject(string(TranslateStr(1838,
        'New local schema...')), LItem);
    end;
    LItem := TSchemaComboItem.CreateKind(sikNewCloud);
    ComboSchema.Items.AddObject(string(TranslateStr(1839,
      'New cloud schema...')), LItem);
  finally
    FSelecting := False;
    LOther.Free;
    LPreferred.Free;
    LParts.Free;
    ComboSchema.Items.EndUpdate;
  end;
  SelectCurrentSchema;
end;

// The subschema chosen, else the cloud schema of the context, else the
// first subschema; the first cloud schema without a direct connection;
// none otherwise
procedure TFRpAISchemaSelectorLCL.SelectCurrentSchema;
var
  LIndex: Integer;

  function Find(AKind: TRpSchemaSelectorItemKind; const ALocalName: string;
    AHubDatabaseId, AHubSchemaId: Int64): Integer;
  var
    I: Integer;
    LItem: TSchemaComboItem;
  begin
    for I := 0 to ComboSchema.Items.Count - 1 do
    begin
      LItem := SchemaItem(I);
      if (LItem = nil) or (LItem.Kind <> AKind) then
        Continue;
      if (AKind = sikLocal) and ((ALocalName = '') or
        SameText(LItem.LocalName, ALocalName)) then
        Exit(I);
      if (AKind = sikHub) and
        ((AHubSchemaId = 0) or (LItem.HubSchemaId = AHubSchemaId)) and
        ((AHubDatabaseId = 0) or (LItem.HubDatabaseId = AHubDatabaseId)) then
        Exit(I);
    end;
    Result := -1;
  end;

begin
  if ComboSchema.Items.Count = 0 then
    Exit;
  LIndex := -1;
  if FLocalName <> '' then
    LIndex := Find(sikLocal, FLocalName, 0, 0);
  // The cloud schema of the context waits for the cloud list
  if (LIndex < 0) and (not FCloudLoaded) and
    ((FHubSchemaId <> 0) or (FHubDatabaseId <> 0)) then
  begin
    FSelecting := True;
    try
      ComboSchema.ItemIndex := -1;
    finally
      FSelecting := False;
    end;
    Exit;
  end;
  if (LIndex < 0) and (FHubSchemaId <> 0) then
    LIndex := Find(sikHub, '', 0, FHubSchemaId);
  if (LIndex < 0) and (FHubDatabaseId <> 0) then
    LIndex := Find(sikHub, '', FHubDatabaseId, 0);
  if (LIndex < 0) and (FPreferredHubDatabaseId <> 0) then
    LIndex := Find(sikHub, '', FPreferredHubDatabaseId, 0);
  if LIndex < 0 then
    LIndex := Find(sikLocal, '', 0, 0);
  if (LIndex < 0) and (FLocalAlias = '') then
    LIndex := Find(sikHub, '', 0, 0);
  if LIndex < 0 then
    LIndex := 0;
  FSelecting := True;
  try
    ComboSchema.ItemIndex := LIndex;
  finally
    FSelecting := False;
  end;
  ApplySelectedItem;
end;

// The schema of the item selected (none: no schema)
procedure TFRpAISchemaSelectorLCL.ApplySelectedItem;
var
  LItem: TSchemaComboItem;
begin
  LItem := SchemaItem(ComboSchema.ItemIndex);
  FHubDatabaseId := 0;
  FHubSchemaId := 0;
  FSchemaApiKey := '';
  FLocalName := '';
  if LItem <> nil then
  begin
    if LItem.Kind = sikHub then
    begin
      FHubDatabaseId := LItem.HubDatabaseId;
      FHubSchemaId := LItem.HubSchemaId;
      FSchemaApiKey := LItem.ApiKey;
    end
    else if LItem.Kind = sikLocal then
      FLocalName := LItem.LocalName;
  end;
  FLastIndex := ComboSchema.ItemIndex;
end;

procedure TFRpAISchemaSelectorLCL.ApplyLoadedSchemas(ASchemas, ASizes: TStrings);
begin
  FCloudLines.Assign(ASchemas);
  FCloudSizes.Assign(ASizes);
  FCloudLoaded := True;
  try
    RebuildItems;
  finally
    FLoadingSchemas := False;
    UpdateButtons;
  end;
  if Assigned(FOnSchemaChanged) then
    FOnSchemaChanged(Self);
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
  ApplyLoadedSchemas(LPayload.Schemas, LPayload.Sizes);
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
  LIndex, LStep: Integer;
begin
  if FLoadingSchemas or FSelecting then
    Exit;
  LItem := SchemaItem(ComboSchema.ItemIndex);
  if (LItem <> nil) and not LItem.IsSchema then
  begin
    // In the open list the click decides (ComboSchemaCloseUp)
    if ComboSchema.DroppedDown then
      Exit;
    // The selection of the list just closed (it may come after the close):
    // back to the schema chosen and the action runs
    if FListClosing then
    begin
      ComboSchemaCloseUp(ComboSchema);
      Exit;
    end;
    // The keys of the closed list skip a header and do not run an action
    LIndex := -1;
    if LItem.Kind = sikHeader then
    begin
      if ComboSchema.ItemIndex > FLastIndex then
        LStep := 1
      else
        LStep := -1;
      LIndex := ComboSchema.ItemIndex;
      while (LIndex >= 0) and (LIndex < ComboSchema.Items.Count) and
        (SchemaItem(LIndex) <> nil) and not SchemaItem(LIndex).IsSchema do
        Inc(LIndex, LStep);
      if (LIndex < 0) or (LIndex >= ComboSchema.Items.Count) then
        LIndex := -1;
    end;
    if LIndex < 0 then
      LIndex := FLastIndex;
    FSelecting := True;
    try
      ComboSchema.ItemIndex := LIndex;
    finally
      FSelecting := False;
    end;
  end;
  ApplySelectedItem;
  if Assigned(FOnSchemaChanged) then
    FOnSchemaChanged(Self);
end;

// A header or an action clicked in the open list: back to the schema chosen,
// and the action runs once the list is closed
procedure TFRpAISchemaSelectorLCL.ComboSchemaCloseUp(Sender: TObject);
var
  LItem: TSchemaComboItem;
begin
  LItem := SchemaItem(ComboSchema.ItemIndex);
  if (LItem = nil) or LItem.IsSchema then
  begin
    // The selection may come after the close: until the messages of this
    // click are handled (ListClosed)
    if not FListClosing then
    begin
      FListClosing := True;
      Application.QueueAsyncCall(ListClosed, 0);
    end;
    Exit;
  end;
  FListClosing := False;
  FSelecting := True;
  try
    ComboSchema.ItemIndex := FLastIndex;
  finally
    FSelecting := False;
  end;
  if LItem.Kind in [sikNewLocal, sikNewCloud] then
    Application.QueueAsyncCall(RunAction, PtrInt(Ord(LItem.Kind)));
end;

procedure TFRpAISchemaSelectorLCL.ListClosed(Data: PtrInt);
begin
  FListClosing := False;
end;

procedure TFRpAISchemaSelectorLCL.RunAction(Data: PtrInt);
var
  LHubDatabaseId: Int64;
  LUrl: string;
begin
  if csDestroying in ComponentState then
    Exit;
  case TRpSchemaSelectorItemKind(Data) of
    sikNewLocal:
      if Assigned(FOnNewLocalSchema) then
        FOnNewLocalSchema(Self);
    sikNewCloud:
      begin
        // On the Hub database of the connection, when there is one
        LHubDatabaseId := FCloudDatabaseFilter;
        if LHubDatabaseId = 0 then
          LHubDatabaseId := FPreferredHubDatabaseId;
        LUrl := CNewCloudSchemaUrl;
        if LHubDatabaseId > 0 then
          LUrl := LUrl + '&hubDatabaseId=' + IntToStr(LHubDatabaseId);
        TRpAuthManager.Instance.OpenUrl(LUrl);
      end;
  end;
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

procedure TFRpAISchemaSelectorLCL.SetLocalSchemas(const AAlias: string;
  ANames, ASizes: TStrings);
begin
  FLocalAlias := AAlias;
  FLocalNames.Clear;
  FLocalSizes.Clear;
  if ANames <> nil then
    FLocalNames.Assign(ANames);
  if ASizes <> nil then
    FLocalSizes.Assign(ASizes);
  if FLocalNames.IndexOf(FLocalName) < 0 then
    FLocalName := '';
  RebuildItems;
end;

procedure TFRpAISchemaSelectorLCL.SelectLocalSchema(const AName: string);
begin
  FLocalName := AName;
  FHubDatabaseId := 0;
  FHubSchemaId := 0;
  FSchemaApiKey := '';
  SelectCurrentSchema;
  if Assigned(FOnSchemaChanged) then
    FOnSchemaChanged(Self);
end;

function TFRpAISchemaSelectorLCL.GetHubDatabaseId: Int64;
var
  LItem: TSchemaComboItem;
begin
  LItem := SchemaItem(ComboSchema.ItemIndex);
  if LItem <> nil then
  begin
    if LItem.Kind = sikHub then
      Exit(LItem.HubDatabaseId);
    Exit(0);
  end;
  Result := FHubDatabaseId;
end;

function TFRpAISchemaSelectorLCL.GetHubSchemaId: Int64;
var
  LItem: TSchemaComboItem;
begin
  LItem := SchemaItem(ComboSchema.ItemIndex);
  if LItem <> nil then
  begin
    if LItem.Kind = sikHub then
      Exit(LItem.HubSchemaId);
    Exit(0);
  end;
  Result := FHubSchemaId;
end;

function TFRpAISchemaSelectorLCL.GetSchemaApiKey: string;
var
  LItem: TSchemaComboItem;
begin
  LItem := SchemaItem(ComboSchema.ItemIndex);
  if LItem <> nil then
  begin
    if LItem.Kind = sikHub then
      Exit(LItem.ApiKey);
    Exit('');
  end;
  Result := FSchemaApiKey;
end;

function TFRpAISchemaSelectorLCL.GetLocalSchemaName: string;
var
  LItem: TSchemaComboItem;
begin
  Result := '';
  LItem := SchemaItem(ComboSchema.ItemIndex);
  if (LItem <> nil) and (LItem.Kind = sikLocal) then
    Result := LItem.LocalName;
end;

end.
