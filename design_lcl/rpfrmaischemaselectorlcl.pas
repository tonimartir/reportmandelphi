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

  The list, as the selector of the copilot (docs/esquemas-locales-pantalla-
  plan.md 5.7.1 A and B3): no schema first (choosing one is optional), the
  local subschemas of the direct connection (SetLocalSchemas), the schemas in
  the cloud, each one with its icon, then "New local schema..." and "New
  cloud schema..." (the web). All the tables of a direct connection are
  never offered: only a subschema goes to the AI.

  TRpSchemaListController keeps that list in any combo box, with the menu of
  the gear (the local schemas of the connection, the schemas in the cloud,
  refresh): the new report wizard uses it through TFRpAISchemaSelectorLCL
  (with the account card), the SQL editor of the datasets in its own
  header. }

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, Menus,
  Generics.Collections,
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
    // A cloud schema whose Agent the cloud says is not connected: a red dot
    // before its name (the text "(not connected)" where it can not be
    // drawn) and a hint; it can still be chosen
    Offline: Boolean;
    constructor Create(AHubDatabaseId, AHubSchemaId: Int64; const AApiKey: string);
    constructor CreateKind(AKind: TRpSchemaSelectorItemKind);
    // A schema the AI can use, not a header or an action
    function IsSchema: Boolean;
  end;

  // The local schema utility of the direct connection: AAddNew starts adding
  // a subschema ("New local schema..."), AName is the subschema to show. The
  // host gives the list again (SetLocalSchemas) and chooses the subschema
  // saved (SelectLocalSchema)
  TRpConfigureLocalSchemasEvent = procedure(Sender: TObject;
    const AAlias, AName: string; AAddNew: Boolean) of object;

  { TRpSchemaListController }

  TRpSchemaListController = class(TComponent)
  private
    FCombo: TComboBox;
    // The objects of the list (the combo only points to them)
    FItems: TObjectList<TSchemaComboItem>;
    FMenu: TPopupMenu;
    FMenuLocal: TMenuItem;
    FMenuCloud: TMenuItem;
    FMenuRefresh: TMenuItem;
    FNoSchemaCaption: string;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
    FPreferredHubDatabaseId: Int64;
    FSchemaApiKey: string;
    FPreferredApiKey: string;
    FLoadingSchemas: Boolean;
    FReloadVersion: Integer;
    FLastLoadOk: Boolean;
    FChangeFromLoad: Boolean;
    FOnSchemaChanged: TNotifyEvent;
    FOnSchemasLoaded: TNotifyEvent;
    FOnNewLocalSchema: TNotifyEvent;
    FOnConfigureLocalSchemas: TRpConfigureLocalSchemasEvent;
    FOnLoadingChanged: TNotifyEvent;
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
    procedure ComboSchemaChange(Sender: TObject);
    procedure ComboSchemaCloseUp(Sender: TObject);
    procedure ComboSchemaDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure MenuLocalClick(Sender: TObject);
    procedure MenuCloudClick(Sender: TObject);
    procedure MenuRefreshClick(Sender: TObject);
    procedure ClearSchemaItems;
    procedure AddItem(const AText: string; AItem: TSchemaComboItem);
    procedure RebuildItems;
    procedure SelectCurrentSchema;
    procedure ApplySelectedItem;
    procedure RunAction(Data: PtrInt);
    procedure ListClosed(Data: PtrInt);
    function SchemaItem(AIndex: Integer): TSchemaComboItem;
    procedure ApplyLoadedSchemas(ASchemas, ASizes: TStrings);
    procedure HandleMessage(AMessage: TRpAsyncMessage);
    procedure SetLoading(AValue: Boolean);
    procedure DoSchemaChanged;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    // ACombo shows the list (owner drawn here: the red dot of the schemas
    // whose Agent is not connected)
    constructor Create(AOwner: TComponent; ACombo: TComboBox); reintroduce;
    destructor Destroy; override;
    // Starts loading the cloud schemas in the background
    procedure LoadSchemas;
    procedure SetPreferredConnection(AHubDatabaseId: Int64;
      const AApiKey: string = '');
    procedure SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
      const ASchemaApiKey: string = '');
    // The subschemas of the direct connection AAlias (ASizes, one per name,
    // '<tables>,<widest columns>' or ''), listed with "New local
    // schema..."; AAlias '' = no direct connection
    procedure SetLocalSchemas(const AAlias: string; ANames, ASizes: TStrings);
    // Chooses a subschema of the direct connection ('' = its first one)
    procedure SelectLocalSchema(const AName: string);
    // The cloud schemas loaded by the host ('Name=db|schema|apikey' lines;
    // ASizes '<schema>=<tables>,<widest>' or nil) instead of LoadSchemas
    procedure SetCloudSchemas(ALines, ASizes: TStrings);
    // No cloud schemas (signed out): the list waits for them again
    procedure ClearCloudSchemas;
    // The menu of the gear, under AControl
    procedure PopupConfigMenu(AControl: TControl);
    // A cloud schema chosen: its Hub database, schema and API key (0, '' with
    // a subschema or none)
    function GetHubDatabaseId: Int64;
    function GetHubSchemaId: Int64;
    function GetSchemaApiKey: string;
    // The subschema chosen ('' = a cloud schema or none)
    function GetLocalSchemaName: string;
    // A schema chosen (a subschema or a cloud one), not none
    function HasSchema: Boolean;
    property Combo: TComboBox read FCombo;
    property Menu: TPopupMenu read FMenu;
    // The direct connection of the subschemas ('' = none)
    property LocalAlias: string read FLocalAlias;
    property Loading: Boolean read FLoadingSchemas;
    property CloudLoaded: Boolean read FCloudLoaded;
    // At least one of the requests of the last load answered
    property LastLoadOk: Boolean read FLastLoadOk;
    // OnSchemaChanged comes from a load of the list, not from the user
    property ChangeFromLoad: Boolean read FChangeFromLoad;
    // The text of the first item (none)
    property NoSchemaCaption: string read FNoSchemaCaption write FNoSchemaCaption;
    // Only the cloud schemas of this Hub database (the Reportman AI Agent
    // connection of the report); 0 = all of them
    property CloudDatabaseFilter: Int64 read FCloudDatabaseFilter
      write FCloudDatabaseFilter;
    property OnSchemaChanged: TNotifyEvent read FOnSchemaChanged write FOnSchemaChanged;
    property OnSchemasLoaded: TNotifyEvent read FOnSchemasLoaded write FOnSchemasLoaded;
    // "New local schema..." without OnConfigureLocalSchemas: the host opens
    // the local schema screen of the connection and gives the list again
    // (SetLocalSchemas)
    property OnNewLocalSchema: TNotifyEvent read FOnNewLocalSchema
      write FOnNewLocalSchema;
    // "Local schemas..." of the gear and "New local schema..."
    property OnConfigureLocalSchemas: TRpConfigureLocalSchemasEvent
      read FOnConfigureLocalSchemas write FOnConfigureLocalSchemas;
    property OnLoadingChanged: TNotifyEvent read FOnLoadingChanged
      write FOnLoadingChanged;
  end;

  { TFRpAISchemaSelectorLCL }

  TFRpAISchemaSelectorLCL = class(TCustomPanel)
  private
    FLoginFrame: TFRpLoginFrameLCL;
    FController: TRpSchemaListController;
    procedure BuildControls;
    procedure LoginAuthChanged(Sender: TObject);
    procedure RefreshSchemasClick(Sender: TObject);
    procedure ControllerLoadingChanged(Sender: TObject);
    procedure UpdateButtons;
    procedure ApplyModernStyling;
    function GetLoading: Boolean;
    function GetLastLoadOk: Boolean;
    function GetCloudDatabaseFilter: Int64;
    procedure SetCloudDatabaseFilter(AValue: Int64);
    function GetOnSchemaChanged: TNotifyEvent;
    procedure SetOnSchemaChanged(AValue: TNotifyEvent);
    function GetOnSchemasLoaded: TNotifyEvent;
    procedure SetOnSchemasLoaded(AValue: TNotifyEvent);
    function GetOnNewLocalSchema: TNotifyEvent;
    procedure SetOnNewLocalSchema(AValue: TNotifyEvent);
  public
    PRoot: TPanel;
    PLoginHost: TPanel;
    PSchemaHost: TPanel;
    PSchemaRow: TPanel;
    LSchema: TLabel;
    ComboSchema: TComboBox;
    BRefreshSchemas: TButton;
    constructor Create(AOwner: TComponent); override;
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
    property Controller: TRpSchemaListController read FController;
    property LoginFrame: TFRpLoginFrameLCL read FLoginFrame;
    property Loading: Boolean read GetLoading;
    // At least one of the requests of the last load answered
    property LastLoadOk: Boolean read GetLastLoadOk;
    // Only the cloud schemas of this Hub database (the Reportman AI Agent
    // connection of the report); 0 = all of them
    property CloudDatabaseFilter: Int64 read GetCloudDatabaseFilter
      write SetCloudDatabaseFilter;
    property OnSchemaChanged: TNotifyEvent read GetOnSchemaChanged write SetOnSchemaChanged;
    property OnSchemasLoaded: TNotifyEvent read GetOnSchemasLoaded write SetOnSchemasLoaded;
    // "New local schema..." chosen: the host opens the local schema screen
    // of the connection and gives the list again (SetLocalSchemas)
    property OnNewLocalSchema: TNotifyEvent read GetOnNewLocalSchema
      write SetOnNewLocalSchema;
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
  CCloudSchemasUrl = 'https://app.reportman.es/database-config';

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

// 'Name=db|schema|apikey' and the state of the Agent; a schema once, by its
// Hub database and schema
procedure AddMergedSchemas(ASource, ADest, ASeenKeys: TStrings; const ADefaultApiKey: string);
var
  I: Integer;
  LSchemaKey: string;
begin
  for I := 0 to ASource.Count - 1 do
  begin
    LSchemaKey := RpHubSchemaKey(ASource.ValueFromIndex[I]);
    if ASeenKeys.IndexOf(LSchemaKey) >= 0 then
      Continue;
    ASeenKeys.Add(LSchemaKey);
    ADest.Add(RpHubSchemaLineWithApiKey(ASource[I], ADefaultApiKey));
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

{ TRpSchemaListController }

constructor TRpSchemaListController.Create(AOwner: TComponent; ACombo: TComboBox);
begin
  inherited Create(AOwner);
  FCombo := ACombo;
  FCombo.FreeNotification(Self);
  FItems := TObjectList<TSchemaComboItem>.Create(True);
  FCloudLines := TStringList.Create;
  FCloudSizes := TStringList.Create;
  FLocalNames := TStringList.Create;
  FLocalSizes := TStringList.Create;
  FLastIndex := -1;
  FNoSchemaCaption := TranslateStr(1994, 'No schema (design by hand)');
  FMailbox := TRpAsyncMailbox.Create(HandleMessage);
  FMailboxRef := FMailbox;
  // The red dot of the schemas whose Agent is not connected
  TRpChatStyle.SetupDotCombo(FCombo, ComboSchemaDrawItem);
  FCombo.OnChange := ComboSchemaChange;
  FCombo.OnCloseUp := ComboSchemaCloseUp;

  FMenu := TPopupMenu.Create(Self);
  FMenuLocal := TMenuItem.Create(FMenu);
  FMenuLocal.Caption := TranslateStr(1840, 'Local schemas...');
  FMenuLocal.OnClick := MenuLocalClick;
  FMenu.Items.Add(FMenuLocal);
  FMenuCloud := TMenuItem.Create(FMenu);
  FMenuCloud.Caption := TranslateStr(1841, 'Cloud schemas...');
  FMenuCloud.OnClick := MenuCloudClick;
  FMenu.Items.Add(FMenuCloud);
  FMenu.Items.AddSeparator;
  FMenuRefresh := TMenuItem.Create(FMenu);
  FMenuRefresh.Caption := TranslateStr(1149, 'Refresh');
  FMenuRefresh.OnClick := MenuRefreshClick;
  FMenu.Items.Add(FMenuRefresh);
end;

destructor TRpSchemaListController.Destroy;
begin
  // An action or a closed list still queued
  Application.RemoveAsyncCalls(Self);
  FMailbox.Detach;
  FMailboxRef := nil;
  ClearSchemaItems;
  FItems.Free;
  FCloudLines.Free;
  FCloudSizes.Free;
  FLocalNames.Free;
  FLocalSizes.Free;
  inherited Destroy;
end;

procedure TRpSchemaListController.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FCombo) then
    FCombo := nil;
end;

procedure TRpSchemaListController.ClearSchemaItems;
begin
  if (FCombo <> nil) and not (csDestroying in FCombo.ComponentState) then
    FCombo.Clear;
  FItems.Clear;
end;

procedure TRpSchemaListController.AddItem(const AText: string;
  AItem: TSchemaComboItem);
begin
  if AItem <> nil then
    FItems.Add(AItem);
  FCombo.Items.AddObject(AText, AItem);
end;

function TRpSchemaListController.SchemaItem(AIndex: Integer): TSchemaComboItem;
begin
  Result := nil;
  if (FCombo <> nil) and (AIndex >= 0) and (AIndex < FCombo.Items.Count) then
    Result := TSchemaComboItem(FCombo.Items.Objects[AIndex]);
end;

// The list: none, the subschemas, the schemas in the cloud (the preferred
// database first) and the two actions
procedure TRpSchemaListController.RebuildItems;
var
  I: Integer;
  LParts, LPreferred, LOther: TStringList;
  LHubDatabaseId: Int64;
  LItem: TSchemaComboItem;

  procedure AddHeader(const AText: string);
  begin
    AddItem(AText, TSchemaComboItem.CreateKind(sikHeader));
  end;

  procedure AppendCloudLines(ALines: TStrings);
  var
    J: Integer;
    LDbId, LSchemaId: Int64;
    LApiKey: string;
    LCloudItem: TSchemaComboItem;
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
      LCloudItem := TSchemaComboItem.Create(LDbId, LSchemaId, LApiKey);
      // The state of its Agent after the API key (RpHubSchemaLineWithApiKey)
      LCloudItem.Offline := RpHubOnlineState(
        RpHubLineField(ALines.ValueFromIndex[J], 3)) = hosOffline;
      AddItem(CSchemaCloudIcon + ALines.Names[J] +
        TRpChatStyle.OfflineText(LCloudItem.Offline) +
        SizeSuffix(FCloudSizes.Values[IntToStr(LSchemaId)]), LCloudItem);
    end;
  end;

begin
  if FCombo = nil then
    Exit;
  FCombo.Items.BeginUpdate;
  LParts := TStringList.Create;
  LPreferred := TStringList.Create;
  LOther := TStringList.Create;
  FSelecting := True;
  try
    LParts.Delimiter := '|';
    LParts.StrictDelimiter := True;
    ClearSchemaItems;
    // No schema: the report is designed by hand, the SQL written without
    // the AI knowing the tables
    AddItem(FNoSchemaCaption, nil);
    if (FLocalAlias <> '') and (FLocalNames.Count > 0) then
    begin
      AddHeader(CSchemaRule + ' ' + string(TranslateStr(1836, 'Local')) + ' ' +
        CSchemaRule);
      for I := 0 to FLocalNames.Count - 1 do
      begin
        LItem := TSchemaComboItem.CreateKind(sikLocal);
        LItem.LocalName := FLocalNames[I];
        if I < FLocalSizes.Count then
          AddItem(CSchemaLocalIcon + FLocalAlias +
            CSchemaSeparator + FLocalNames[I] + SizeSuffix(FLocalSizes[I]), LItem)
        else
          AddItem(CSchemaLocalIcon + FLocalAlias +
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
      AddItem(string(TranslateStr(1838, 'New local schema...')),
        TSchemaComboItem.CreateKind(sikNewLocal));
    // A direct connection is not in the Hub: no cloud schema to make for it
    if FLocalAlias <> '' then
      AddItem(string(TranslateStr(1839, 'New cloud schema...')) + ' (' +
        string(TranslateStr(1842, 'This connection is not in the Hub')) + ')',
        TSchemaComboItem.CreateKind(sikNewCloud))
    else
      AddItem(string(TranslateStr(1839, 'New cloud schema...')),
        TSchemaComboItem.CreateKind(sikNewCloud));
  finally
    FSelecting := False;
    LOther.Free;
    LPreferred.Free;
    LParts.Free;
    FCombo.Items.EndUpdate;
  end;
  TRpChatStyle.FitComboDropDownWidth(FCombo);
  SelectCurrentSchema;
end;

// The red dot of a cloud schema whose Agent is not connected, after its icon
procedure TRpSchemaListController.ComboSchemaDrawItem(Control: TWinControl;
  Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  LItem: TSchemaComboItem;
  LText: string;
  LDotAt: Integer;
begin
  // -1: the edit field without a selection
  LText := '';
  if (Index >= 0) and (Index < FCombo.Items.Count) then
    LText := FCombo.Items[Index];
  LItem := SchemaItem(Index);
  LDotAt := -1;
  if (LItem <> nil) and LItem.Offline then
    LDotAt := Length(CSchemaCloudIcon);
  TRpChatStyle.DrawComboItem(FCombo.Canvas, ARect, State, LText, LDotAt);
end;

// The subschema chosen, else the cloud schema of the context, else the
// first subschema; the first cloud schema without a direct connection;
// none otherwise
procedure TRpSchemaListController.SelectCurrentSchema;
var
  LIndex: Integer;

  function Find(AKind: TRpSchemaSelectorItemKind; const ALocalName: string;
    AHubDatabaseId, AHubSchemaId: Int64): Integer;
  var
    I: Integer;
    LItem: TSchemaComboItem;
  begin
    for I := 0 to FCombo.Items.Count - 1 do
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
  if (FCombo = nil) or (FCombo.Items.Count = 0) then
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
      FCombo.ItemIndex := -1;
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
    FCombo.ItemIndex := LIndex;
  finally
    FSelecting := False;
  end;
  ApplySelectedItem;
end;

// The schema of the item selected (none: no schema)
procedure TRpSchemaListController.ApplySelectedItem;
var
  LItem: TSchemaComboItem;
begin
  LItem := SchemaItem(FCombo.ItemIndex);
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
  FLastIndex := FCombo.ItemIndex;
  if (LItem <> nil) and LItem.Offline then
    FCombo.Hint := string(TranslateStr(2004, 'The Agent of this ' +
      'database is not connected: the AI can design with its schema, but the ' +
      'data cannot be opened until it comes back.'))
  else
    FCombo.Hint := '';
end;

procedure TRpSchemaListController.DoSchemaChanged;
begin
  if Assigned(FOnSchemaChanged) then
    FOnSchemaChanged(Self);
end;

procedure TRpSchemaListController.ApplyLoadedSchemas(ASchemas, ASizes: TStrings);
begin
  FCloudLines.Assign(ASchemas);
  FCloudSizes.Assign(ASizes);
  FCloudLoaded := True;
  try
    RebuildItems;
  finally
    SetLoading(False);
  end;
  FChangeFromLoad := True;
  try
    DoSchemaChanged;
  finally
    FChangeFromLoad := False;
  end;
end;

procedure TRpSchemaListController.HandleMessage(AMessage: TRpAsyncMessage);
var
  LPayload: TRpSelectorSchemasPayload;
begin
  if not (AMessage is TRpSelectorSchemasPayload) then
    Exit;
  LPayload := TRpSelectorSchemasPayload(AMessage);
  if LPayload.ReloadVersion <> FReloadVersion then
    Exit;
  if FCombo = nil then
    Exit;
  FLastLoadOk := LPayload.Ok;
  ApplyLoadedSchemas(LPayload.Schemas, LPayload.Sizes);
  if Assigned(FOnSchemasLoaded) then
    FOnSchemasLoaded(Self);
end;

procedure TRpSchemaListController.SetLoading(AValue: Boolean);
begin
  if FLoadingSchemas = AValue then
    Exit;
  FLoadingSchemas := AValue;
  if Assigned(FOnLoadingChanged) then
    FOnLoadingChanged(Self);
end;

procedure TRpSchemaListController.LoadSchemas;
var
  LWorker: TRpSelectorSchemasWorker;
begin
  Inc(FReloadVersion);
  SetLoading(True);
  LWorker := TRpSelectorSchemasWorker.Create(FMailboxRef);
  LWorker.ReloadVersion := FReloadVersion;
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.PreferredApiKey := FPreferredApiKey;
  LWorker.Start;
end;

procedure TRpSchemaListController.ComboSchemaChange(Sender: TObject);
var
  LItem: TSchemaComboItem;
  LIndex, LStep: Integer;
begin
  if FLoadingSchemas or FSelecting then
    Exit;
  LItem := SchemaItem(FCombo.ItemIndex);
  if (LItem <> nil) and not LItem.IsSchema then
  begin
    // In the open list the click decides (ComboSchemaCloseUp)
    if FCombo.DroppedDown then
      Exit;
    // The selection of the list just closed (it may come after the close):
    // back to the schema chosen and the action runs
    if FListClosing then
    begin
      ComboSchemaCloseUp(FCombo);
      Exit;
    end;
    // The keys of the closed list skip a header and do not run an action
    LIndex := -1;
    if LItem.Kind = sikHeader then
    begin
      if FCombo.ItemIndex > FLastIndex then
        LStep := 1
      else
        LStep := -1;
      LIndex := FCombo.ItemIndex;
      while (LIndex >= 0) and (LIndex < FCombo.Items.Count) and
        (SchemaItem(LIndex) <> nil) and not SchemaItem(LIndex).IsSchema do
        Inc(LIndex, LStep);
      if (LIndex < 0) or (LIndex >= FCombo.Items.Count) then
        LIndex := -1;
    end;
    if LIndex < 0 then
      LIndex := FLastIndex;
    FSelecting := True;
    try
      FCombo.ItemIndex := LIndex;
    finally
      FSelecting := False;
    end;
  end;
  ApplySelectedItem;
  DoSchemaChanged;
end;

// A header or an action clicked in the open list: back to the schema chosen,
// and the action runs once the list is closed
procedure TRpSchemaListController.ComboSchemaCloseUp(Sender: TObject);
var
  LItem: TSchemaComboItem;
begin
  LItem := SchemaItem(FCombo.ItemIndex);
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
    FCombo.ItemIndex := FLastIndex;
  finally
    FSelecting := False;
  end;
  if LItem.Kind in [sikNewLocal, sikNewCloud] then
    Application.QueueAsyncCall(RunAction, PtrInt(Ord(LItem.Kind)));
end;

procedure TRpSchemaListController.ListClosed(Data: PtrInt);
begin
  FListClosing := False;
end;

procedure TRpSchemaListController.RunAction(Data: PtrInt);
var
  LHubDatabaseId: Int64;
  LUrl: string;
begin
  if csDestroying in ComponentState then
    Exit;
  case TRpSchemaSelectorItemKind(Data) of
    sikNewLocal:
      if Assigned(FOnConfigureLocalSchemas) then
        FOnConfigureLocalSchemas(Self, FLocalAlias, '', True)
      else if Assigned(FOnNewLocalSchema) then
        FOnNewLocalSchema(Self);
    sikNewCloud:
      begin
        if FLocalAlias <> '' then
          Exit;
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

procedure TRpSchemaListController.PopupConfigMenu(AControl: TControl);
var
  LPoint: TPoint;
begin
  // The local schema utility only for a direct connection
  FMenuLocal.Enabled := (FLocalAlias <> '') and
    (Assigned(FOnConfigureLocalSchemas) or Assigned(FOnNewLocalSchema));
  FMenuRefresh.Enabled := not FLoadingSchemas;
  LPoint := AControl.ClientToScreen(Point(0, AControl.Height));
  FMenu.PopUp(LPoint.X, LPoint.Y);
end;

procedure TRpSchemaListController.MenuLocalClick(Sender: TObject);
begin
  if FLocalAlias = '' then
    Exit;
  if Assigned(FOnConfigureLocalSchemas) then
    FOnConfigureLocalSchemas(Self, FLocalAlias, GetLocalSchemaName, False)
  else if Assigned(FOnNewLocalSchema) then
    FOnNewLocalSchema(Self);
end;

procedure TRpSchemaListController.MenuCloudClick(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenUrl(CCloudSchemasUrl);
end;

procedure TRpSchemaListController.MenuRefreshClick(Sender: TObject);
begin
  LoadSchemas;
end;

procedure TRpSchemaListController.SetPreferredConnection(AHubDatabaseId: Int64;
  const AApiKey: string);
begin
  FPreferredHubDatabaseId := AHubDatabaseId;
  FPreferredApiKey := Trim(AApiKey);
end;

procedure TRpSchemaListController.SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
  const ASchemaApiKey: string);
begin
  FHubDatabaseId := AHubDatabaseId;
  FHubSchemaId := AHubSchemaId;
  FSchemaApiKey := Trim(ASchemaApiKey);
  SelectCurrentSchema;
end;

procedure TRpSchemaListController.SetLocalSchemas(const AAlias: string;
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

procedure TRpSchemaListController.SelectLocalSchema(const AName: string);
begin
  FLocalName := AName;
  FHubDatabaseId := 0;
  FHubSchemaId := 0;
  FSchemaApiKey := '';
  SelectCurrentSchema;
  DoSchemaChanged;
end;

procedure TRpSchemaListController.SetCloudSchemas(ALines, ASizes: TStrings);
var
  LSizes: TStringList;
begin
  LSizes := TStringList.Create;
  try
    if ASizes <> nil then
      LSizes.Assign(ASizes);
    FLastLoadOk := True;
    ApplyLoadedSchemas(ALines, LSizes);
  finally
    LSizes.Free;
  end;
end;

procedure TRpSchemaListController.ClearCloudSchemas;
begin
  FCloudLines.Clear;
  FCloudSizes.Clear;
  FCloudLoaded := False;
  RebuildItems;
end;

function TRpSchemaListController.GetHubDatabaseId: Int64;
var
  LItem: TSchemaComboItem;
begin
  LItem := SchemaItem(FCombo.ItemIndex);
  if LItem <> nil then
  begin
    if LItem.Kind = sikHub then
      Exit(LItem.HubDatabaseId);
    Exit(0);
  end;
  Result := FHubDatabaseId;
end;

function TRpSchemaListController.GetHubSchemaId: Int64;
var
  LItem: TSchemaComboItem;
begin
  LItem := SchemaItem(FCombo.ItemIndex);
  if LItem <> nil then
  begin
    if LItem.Kind = sikHub then
      Exit(LItem.HubSchemaId);
    Exit(0);
  end;
  Result := FHubSchemaId;
end;

function TRpSchemaListController.GetSchemaApiKey: string;
var
  LItem: TSchemaComboItem;
begin
  LItem := SchemaItem(FCombo.ItemIndex);
  if LItem <> nil then
  begin
    if LItem.Kind = sikHub then
      Exit(LItem.ApiKey);
    Exit('');
  end;
  Result := FSchemaApiKey;
end;

function TRpSchemaListController.GetLocalSchemaName: string;
var
  LItem: TSchemaComboItem;
begin
  Result := '';
  LItem := SchemaItem(FCombo.ItemIndex);
  if (LItem <> nil) and (LItem.Kind = sikLocal) then
    Result := LItem.LocalName;
end;

function TRpSchemaListController.HasSchema: Boolean;
var
  LItem: TSchemaComboItem;
begin
  LItem := SchemaItem(FCombo.ItemIndex);
  Result := (LItem <> nil) and LItem.IsSchema;
end;

{ TFRpAISchemaSelectorLCL }

constructor TFRpAISchemaSelectorLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  Width := Scale(400);
  AutoSize := True;
  BuildControls;
  FController := TRpSchemaListController.Create(Self, ComboSchema);
  FController.OnLoadingChanged := ControllerLoadingChanged;
  ApplyModernStyling;
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
  BRefreshSchemas.Enabled := not FController.Loading;
  if FController.Loading then
    BRefreshSchemas.Caption := '...'
  else
    BRefreshSchemas.Caption := TranslateStr(1149, 'Refresh');
end;

procedure TFRpAISchemaSelectorLCL.ControllerLoadingChanged(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TFRpAISchemaSelectorLCL.LoginAuthChanged(Sender: TObject);
begin
  LoadSchemas;
end;

procedure TFRpAISchemaSelectorLCL.RefreshSchemasClick(Sender: TObject);
begin
  LoadSchemas;
end;

procedure TFRpAISchemaSelectorLCL.LoadSchemas;
begin
  FController.LoadSchemas;
end;

procedure TFRpAISchemaSelectorLCL.SetPreferredConnection(AHubDatabaseId: Int64;
  const AApiKey: string);
begin
  FController.SetPreferredConnection(AHubDatabaseId, AApiKey);
end;

procedure TFRpAISchemaSelectorLCL.SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
  const ASchemaApiKey: string);
begin
  FController.SetHubContext(AHubDatabaseId, AHubSchemaId, ASchemaApiKey);
end;

procedure TFRpAISchemaSelectorLCL.SetLocalSchemas(const AAlias: string;
  ANames, ASizes: TStrings);
begin
  FController.SetLocalSchemas(AAlias, ANames, ASizes);
end;

procedure TFRpAISchemaSelectorLCL.SelectLocalSchema(const AName: string);
begin
  FController.SelectLocalSchema(AName);
end;

function TFRpAISchemaSelectorLCL.GetHubDatabaseId: Int64;
begin
  Result := FController.GetHubDatabaseId;
end;

function TFRpAISchemaSelectorLCL.GetHubSchemaId: Int64;
begin
  Result := FController.GetHubSchemaId;
end;

function TFRpAISchemaSelectorLCL.GetSchemaApiKey: string;
begin
  Result := FController.GetSchemaApiKey;
end;

function TFRpAISchemaSelectorLCL.GetLocalSchemaName: string;
begin
  Result := FController.GetLocalSchemaName;
end;

function TFRpAISchemaSelectorLCL.GetLoading: Boolean;
begin
  Result := FController.Loading;
end;

function TFRpAISchemaSelectorLCL.GetLastLoadOk: Boolean;
begin
  Result := FController.LastLoadOk;
end;

function TFRpAISchemaSelectorLCL.GetCloudDatabaseFilter: Int64;
begin
  Result := FController.CloudDatabaseFilter;
end;

procedure TFRpAISchemaSelectorLCL.SetCloudDatabaseFilter(AValue: Int64);
begin
  FController.CloudDatabaseFilter := AValue;
end;

function TFRpAISchemaSelectorLCL.GetOnSchemaChanged: TNotifyEvent;
begin
  Result := FController.OnSchemaChanged;
end;

procedure TFRpAISchemaSelectorLCL.SetOnSchemaChanged(AValue: TNotifyEvent);
begin
  FController.OnSchemaChanged := AValue;
end;

function TFRpAISchemaSelectorLCL.GetOnSchemasLoaded: TNotifyEvent;
begin
  Result := FController.OnSchemasLoaded;
end;

procedure TFRpAISchemaSelectorLCL.SetOnSchemasLoaded(AValue: TNotifyEvent);
begin
  FController.OnSchemasLoaded := AValue;
end;

function TFRpAISchemaSelectorLCL.GetOnNewLocalSchema: TNotifyEvent;
begin
  Result := FController.OnNewLocalSchema;
end;

procedure TFRpAISchemaSelectorLCL.SetOnNewLocalSchema(AValue: TNotifyEvent);
begin
  FController.OnNewLocalSchema := AValue;
end;

end.
