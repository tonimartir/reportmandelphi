unit rpfrmaischemaselectorvcl;

{ The schema list of the new report wizard: the account card and, as the
  selector of the copilot (docs/esquemas-locales-pantalla-plan.md 5.7.1
  A and B3), the local subschemas of the direct connection of the report
  (SetLocalSchemas) and the schemas in the cloud, each one with its icon,
  then "New local schema..." (OnNewLocalSchema) and "New cloud schema..."
  (the web). The first item is no schema: choosing one is optional. All the
  tables of a direct connection are never offered, only a subschema goes to
  the AI.

  TRpSchemaListController keeps that list in any combo box, with the menu of
  the gear (the local schemas of the connection, the schemas in the cloud,
  refresh): the new report wizard uses it through TFRpAISchemaSelectorVCL
  (with the account card), the SQL editor of the datasets in its own
  header. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Menus, System.Generics.Collections,
  rpauthmanager, rpfrmloginframevcl, rpdatahttp, rpchatmodernstyle;

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
    // before its name and a hint; it can still be chosen
    Offline: Boolean;
    constructor Create(AHubDatabaseId, AHubSchemaId: Int64;
      const AApiKey: string);
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

  // Cleared when the controller goes: a load still running drops its answer
  IRpSchemaListGuard = interface
    function IsCancelled: Boolean;
    procedure Invalidate;
  end;

  TRpSchemaListController = class(TComponent)
  private
    FCombo: TComboBox;
    // The objects of the list (the combo only points to them)
    FItems: TObjectList<TSchemaComboItem>;
    FMenu: TPopupMenu;
    FMenuLocal: TMenuItem;
    FMenuCloud: TMenuItem;
    FMenuRefresh: TMenuItem;
    // The actions run once the open list is closed
    FWindow: HWND;
    FGuard: IRpSchemaListGuard;
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
    procedure WindowProc(var Message: TMessage);
    procedure ComboSchemaChange(Sender: TObject);
    procedure ComboSchemaCloseUp(Sender: TObject);
    procedure ComboSchemaDropDown(Sender: TObject);
    procedure ComboSchemaDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure MenuLocalClick(Sender: TObject);
    procedure MenuCloudClick(Sender: TObject);
    procedure MenuRefreshClick(Sender: TObject);
    procedure ClearSchemaItems;
    procedure AddItem(const AText: string; AItem: TSchemaComboItem);
    procedure RebuildItems;
    procedure SelectCurrentSchema;
    procedure ApplySelectedItem;
    procedure RunAction(AKind: TRpSchemaSelectorItemKind);
    function SchemaItem(AIndex: Integer): TSchemaComboItem;
    procedure ApplyLoadedSchemas(ASchemas, ASizes: TStrings; AOk: Boolean);
    procedure SetLoading(AValue: Boolean);
    procedure DoSchemaChanged;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    // ACombo shows the list (owner drawn here: the red dot of the schemas
    // whose Agent is not connected)
    constructor Create(AOwner: TComponent; ACombo: TComboBox); reintroduce;
    destructor Destroy; override;
    // Loads the cloud schemas in the main thread (hourglass cursor)
    procedure LoadSchemas;
    // Loads them in the background: the list is filled when they arrive
    // (Loading, OnSchemasLoaded)
    procedure LoadSchemasAsync;
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
    FController: TRpSchemaListController;
    procedure LoginAuthChanged(Sender: TObject);
    procedure RefreshSchemasClick(Sender: TObject);
    procedure ControllerLoadingChanged(Sender: TObject);
    procedure UpdateButtons;
    procedure ApplyModernStyling;
    function GetCloudDatabaseFilter: Int64;
    procedure SetCloudDatabaseFilter(AValue: Int64);
    function GetOnSchemaChanged: TNotifyEvent;
    procedure SetOnSchemaChanged(AValue: TNotifyEvent);
    function GetOnNewLocalSchema: TNotifyEvent;
    procedure SetOnNewLocalSchema(AValue: TNotifyEvent);
  public
    constructor Create(AOwner: TComponent); override;
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
    // Only the cloud schemas of this Hub database (the Reportman AI Agent
    // connection of the report); 0 = all of them
    property CloudDatabaseFilter: Int64 read GetCloudDatabaseFilter
      write SetCloudDatabaseFilter;
    property OnSchemaChanged: TNotifyEvent read GetOnSchemaChanged write SetOnSchemaChanged;
    // "New local schema..." chosen: the host opens the local schema screen
    // of the connection and gives the list again (SetLocalSchemas)
    property OnNewLocalSchema: TNotifyEvent read GetOnNewLocalSchema
      write SetOnNewLocalSchema;
  end;

implementation

{$R *.dfm}

uses
  rpmdconsts;

const
  // The text of the list (UTF-16), as the selector of the copilot
  CSchemaSeparator = ' '#$00B7' ';
  CSchemaRule = #$2500#$2500;
  CSchemaLocalIcon = #$26C1' ';
  CSchemaCloudIcon = #$2601' ';
  CNewCloudSchemaUrl = 'https://app.reportman.es/database-config?new=1';
  CCloudSchemasUrl = 'https://app.reportman.es/database-config';
  WM_RP_SCHEMA_ACTION = WM_USER + 215;
  WM_RP_SCHEMA_LIST_CLOSED = WM_USER + 216;

type
  TRpSchemaListGuard = class(TInterfacedObject, IRpSchemaListGuard)
  private
    FCancelled: Boolean;
  public
    function IsCancelled: Boolean;
    procedure Invalidate;
  end;

function TRpSchemaListGuard.IsCancelled: Boolean;
begin
  Result := FCancelled;
end;

procedure TRpSchemaListGuard.Invalidate;
begin
  FCancelled := True;
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

// 'Name=db|schema|apikey' and the state of the Agent; a schema once, by its
// Hub database and schema
procedure AddMergedSchemas(ASource, ADest, ASeenKeys: TStrings;
  const ADefaultApiKey: string);
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

// The schemas of the account and the ones visible with the API key of the
// preferred connection, merged ('Name=db|schema|apikey'), and their sizes;
// False when no request answered
function LoadMergedSchemas(const AToken, AInstallId, APreferredApiKey: string;
  ASchemas, ASizes: TStrings): Boolean;
var
  LUserSchemas, LApiKeySchemas, LSeenKeys, LRawSizes: TStringList;
  LHttp: TRpDatabaseHttp;
begin
  Result := False;
  LUserSchemas := TStringList.Create;
  LApiKeySchemas := TStringList.Create;
  LSeenKeys := TStringList.Create;
  LRawSizes := TStringList.Create;
  try
    LSeenKeys.Sorted := True;
    LSeenKeys.Duplicates := dupIgnore;
    if Trim(APreferredApiKey) <> '' then
    begin
      LHttp := TRpDatabaseHttp.Create;
      try
        try
          LHttp.ApiKey := Trim(APreferredApiKey);
          LHttp.Token := AToken;
          LHttp.InstallId := AInstallId;
          Result := LHttp.GetUserSchemas(LApiKeySchemas, LRawSizes) or Result;
          ASizes.AddStrings(LRawSizes);
        except
          LApiKeySchemas.Clear;
        end;
      finally
        LHttp.Free;
      end;
    end;
    if Trim(AToken) <> '' then
    begin
      LHttp := TRpDatabaseHttp.Create;
      try
        try
          LHttp.Token := AToken;
          LHttp.InstallId := AInstallId;
          Result := LHttp.GetUserSchemas(LUserSchemas, LRawSizes) or Result;
          ASizes.AddStrings(LRawSizes);
        except
          LUserSchemas.Clear;
        end;
      finally
        LHttp.Free;
      end;
    end;
    AddMergedSchemas(LApiKeySchemas, ASchemas, LSeenKeys, APreferredApiKey);
    AddMergedSchemas(LUserSchemas, ASchemas, LSeenKeys, '');
  finally
    LRawSizes.Free;
    LSeenKeys.Free;
    LApiKeySchemas.Free;
    LUserSchemas.Free;
  end;
end;

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

constructor TRpSchemaListController.Create(AOwner: TComponent;
  ACombo: TComboBox);
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
  FNoSchemaCaption := string(TranslateStr(1994, 'No schema (design by hand)'));
  FGuard := TRpSchemaListGuard.Create;
  FWindow := AllocateHWnd(WindowProc);
  // The red dot of the schemas whose Agent is not connected
  TRpChatStyle.SetupDotCombo(FCombo, ComboSchemaDrawItem);
  // The rows as high as its font (a host may style it after, as the wizard)
  FCombo.ItemHeight := TRpChatStyle.ComboItemHeight(FCombo);
  FCombo.OnChange := ComboSchemaChange;
  FCombo.OnCloseUp := ComboSchemaCloseUp;
  FCombo.OnDropDown := ComboSchemaDropDown;

  FMenu := TPopupMenu.Create(Self);
  FMenuLocal := TMenuItem.Create(FMenu);
  FMenuLocal.Caption := string(TranslateStr(1840, 'Local schemas...'));
  FMenuLocal.OnClick := MenuLocalClick;
  FMenu.Items.Add(FMenuLocal);
  FMenuCloud := TMenuItem.Create(FMenu);
  FMenuCloud.Caption := string(TranslateStr(1841, 'Cloud schemas...'));
  FMenuCloud.OnClick := MenuCloudClick;
  FMenu.Items.Add(FMenuCloud);
  FMenu.Items.NewBottomLine;
  FMenuRefresh := TMenuItem.Create(FMenu);
  FMenuRefresh.Caption := string(TranslateStr(1149, 'Refresh'));
  FMenuRefresh.OnClick := MenuRefreshClick;
  FMenu.Items.Add(FMenuRefresh);
end;

destructor TRpSchemaListController.Destroy;
begin
  // A load still running drops its answer
  if FGuard <> nil then
    FGuard.Invalidate;
  FGuard := nil;
  if FWindow <> 0 then
    DeallocateHWnd(FWindow);
  FWindow := 0;
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

procedure TRpSchemaListController.WindowProc(var Message: TMessage);
begin
  case Message.Msg of
    WM_RP_SCHEMA_ACTION:
      RunAction(TRpSchemaSelectorItemKind(Message.WParam));
    WM_RP_SCHEMA_LIST_CLOSED:
      FListClosing := False;
  else
    Message.Result := DefWindowProc(FWindow, Message.Msg, Message.WParam,
      Message.LParam);
  end;
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
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  LItem: TSchemaComboItem;
  LDotAt: Integer;
begin
  LItem := SchemaItem(Index);
  LDotAt := -1;
  if (LItem <> nil) and LItem.Offline then
    LDotAt := Length(CSchemaCloudIcon);
  TRpChatStyle.DrawComboItem(FCombo.Canvas, Rect, State,
    FCombo.Items[Index], LDotAt);
end;

procedure TRpSchemaListController.ComboSchemaDropDown(Sender: TObject);
begin
  TRpChatStyle.FitComboDropDownWidth(FCombo);
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

procedure TRpSchemaListController.SetLoading(AValue: Boolean);
begin
  if FLoadingSchemas = AValue then
    Exit;
  FLoadingSchemas := AValue;
  if Assigned(FOnLoadingChanged) then
    FOnLoadingChanged(Self);
end;

procedure TRpSchemaListController.ApplyLoadedSchemas(ASchemas, ASizes: TStrings;
  AOk: Boolean);
begin
  FCloudLines.Assign(ASchemas);
  FCloudSizes.Assign(ASizes);
  FCloudLoaded := True;
  FLastLoadOk := AOk;
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
  if Assigned(FOnSchemasLoaded) then
    FOnSchemasLoaded(Self);
end;

procedure TRpSchemaListController.LoadSchemas;
var
  LSchemas, LSizes: TStringList;
  LOk: Boolean;
begin
  Inc(FReloadVersion);
  SetLoading(True);
  Screen.Cursor := crHourGlass;
  LSchemas := TStringList.Create;
  LSizes := TStringList.Create;
  try
    try
      LOk := LoadMergedSchemas(TRpAuthManager.Instance.Token,
        TRpAuthManager.Instance.InstallId, FPreferredApiKey, LSchemas, LSizes);
    except
      LOk := False;
      LSchemas.Clear;
      LSizes.Clear;
    end;
    Screen.Cursor := crDefault;
    ApplyLoadedSchemas(LSchemas, LSizes, LOk);
  finally
    Screen.Cursor := crDefault;
    SetLoading(False);
    LSizes.Free;
    LSchemas.Free;
  end;
end;

procedure TRpSchemaListController.LoadSchemasAsync;
var
  LGuard: IRpSchemaListGuard;
  LVersion: Integer;
  LToken, LInstallId, LApiKey: string;
  LWorker: TThread;
begin
  Inc(FReloadVersion);
  LVersion := FReloadVersion;
  SetLoading(True);
  LGuard := FGuard;
  LToken := TRpAuthManager.Instance.Token;
  LInstallId := TRpAuthManager.Instance.InstallId;
  LApiKey := FPreferredApiKey;
  LWorker := TThread.CreateAnonymousThread(
    procedure
    var
      LSchemas, LSizes: TStringList;
      LOk: Boolean;
    begin
      LSchemas := TStringList.Create;
      LSizes := TStringList.Create;
      try
        LOk := LoadMergedSchemas(LToken, LInstallId, LApiKey, LSchemas, LSizes);
      except
        LOk := False;
        LSchemas.Clear;
        LSizes.Clear;
      end;
      TThread.Queue(nil,
        procedure
        begin
          try
            // The controller went, or a newer load was asked for
            if (not LGuard.IsCancelled) and (LVersion = FReloadVersion) and
              (FCombo <> nil) then
              ApplyLoadedSchemas(LSchemas, LSizes, LOk);
          finally
            LSizes.Free;
            LSchemas.Free;
          end;
        end);
    end);
  LWorker.FreeOnTerminate := True;
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
    // The selection of the list just closed (Windows may send it after the
    // close): back to the schema chosen and the action runs
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
    // click are handled
    if not FListClosing then
    begin
      FListClosing := True;
      PostMessage(FWindow, WM_RP_SCHEMA_LIST_CLOSED, 0, 0);
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
    PostMessage(FWindow, WM_RP_SCHEMA_ACTION, WPARAM(Ord(LItem.Kind)), 0);
end;

procedure TRpSchemaListController.RunAction(AKind: TRpSchemaSelectorItemKind);
var
  LHubDatabaseId: Int64;
  LUrl: string;
begin
  case AKind of
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
  FMenu.Popup(LPoint.X, LPoint.Y);
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
  LoadSchemasAsync;
end;

procedure TRpSchemaListController.SetPreferredConnection(
  AHubDatabaseId: Int64; const AApiKey: string);
begin
  FPreferredHubDatabaseId := AHubDatabaseId;
  FPreferredApiKey := Trim(AApiKey);
end;

procedure TRpSchemaListController.SetHubContext(AHubDatabaseId,
  AHubSchemaId: Int64; const ASchemaApiKey: string);
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
    ApplyLoadedSchemas(ALines, LSizes, True);
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

{ TFRpAISchemaSelectorVCL }

constructor TFRpAISchemaSelectorVCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 400;
  Height := 0;
  AutoSize := True;

  PRoot := TPanel.Create(Self);
  PRoot.Parent := Self;
  PRoot.Align := alTop;
  PRoot.AutoSize := True;
  PRoot.BevelOuter := bvNone;
  PRoot.ParentBackground := False;
  PRoot.Padding.Top := 8;
  PRoot.Padding.Bottom := 8;

  PLoginHost := TPanel.Create(Self);
  PLoginHost.Parent := PRoot;
  PLoginHost.Align := alTop;
  PLoginHost.AutoSize := True;
  PLoginHost.BevelOuter := bvNone;
  PLoginHost.ParentBackground := False;

  PSchemaHost := TPanel.Create(Self);
  PSchemaHost.Parent := PRoot;
  PSchemaHost.Align := alTop;
  PSchemaHost.AutoSize := True;
  PSchemaHost.BevelOuter := bvNone;
  PSchemaHost.ParentBackground := False;
  PSchemaHost.Padding.Top := 4;

  LSchema := TLabel.Create(Self);
  LSchema.Parent := PSchemaHost;
  LSchema.Align := alTop;
  LSchema.AutoSize := True;
  LSchema.Caption := AnsiUpperCase(string(TranslateStr(1528, 'Schema')));
  LSchema.Layout := tlBottom;

  PSchemaRow := TPanel.Create(Self);
  PSchemaRow.Parent := PSchemaHost;
  PSchemaRow.Align := alTop;
  PSchemaRow.AutoSize := True;
  PSchemaRow.BevelOuter := bvNone;
  PSchemaRow.ParentBackground := False;

  BRefreshSchemas := TButton.Create(Self);
  BRefreshSchemas.Parent := PSchemaRow;
  BRefreshSchemas.Align := alRight;
  BRefreshSchemas.Width := Scale(60);
  BRefreshSchemas.Caption := string(TranslateStr(1149, 'Refresh'));
  BRefreshSchemas.OnClick := RefreshSchemasClick;

  ComboSchema := TComboBox.Create(Self);
  ComboSchema.Parent := PSchemaRow;
  ComboSchema.Align := alClient;
  FController := TRpSchemaListController.Create(Self, ComboSchema);
  FController.OnLoadingChanged := ControllerLoadingChanged;
  // Match row height to combo's font-driven natural height
  PSchemaRow.Height := ComboSchema.Height;
  BRefreshSchemas.Height := ComboSchema.Height;

  FLoginFrame := TFRpLoginFrameVCL.Create(Self);
  FLoginFrame.Parent := PLoginHost;
  FLoginFrame.Align := alTop;
  FLoginFrame.OnAuthChanged := LoginAuthChanged;

  ApplyModernStyling;
end;

procedure TFRpAISchemaSelectorVCL.ApplyModernStyling;
begin
  TRpChatStyle.StylePanelBg(PRoot);
  TRpChatStyle.StylePanelBg(PLoginHost);
  TRpChatStyle.StylePanelBg(PSchemaHost);
  TRpChatStyle.StylePanelBg(PSchemaRow);
  TRpChatStyle.StyleInputControl(ComboSchema);
  TRpChatStyle.StyleInputControl(BRefreshSchemas);
end;

procedure TFRpAISchemaSelectorVCL.UpdateButtons;
begin
  BRefreshSchemas.Enabled := not FController.Loading;
  if FController.Loading then
    BRefreshSchemas.Caption := '...'
  else
    BRefreshSchemas.Caption := string(TranslateStr(1149, 'Refresh'));
end;

procedure TFRpAISchemaSelectorVCL.ControllerLoadingChanged(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TFRpAISchemaSelectorVCL.LoadSchemas;
begin
  FController.LoadSchemas;
end;

procedure TFRpAISchemaSelectorVCL.LoginAuthChanged(Sender: TObject);
begin
  LoadSchemas;
end;

procedure TFRpAISchemaSelectorVCL.RefreshSchemasClick(Sender: TObject);
begin
  LoadSchemas;
end;

procedure TFRpAISchemaSelectorVCL.SetPreferredConnection(
  AHubDatabaseId: Int64; const AApiKey: string);
begin
  FController.SetPreferredConnection(AHubDatabaseId, AApiKey);
end;

procedure TFRpAISchemaSelectorVCL.SetHubContext(AHubDatabaseId,
  AHubSchemaId: Int64; const ASchemaApiKey: string);
begin
  FController.SetHubContext(AHubDatabaseId, AHubSchemaId, ASchemaApiKey);
end;

procedure TFRpAISchemaSelectorVCL.SetLocalSchemas(const AAlias: string;
  ANames, ASizes: TStrings);
begin
  FController.SetLocalSchemas(AAlias, ANames, ASizes);
end;

procedure TFRpAISchemaSelectorVCL.SelectLocalSchema(const AName: string);
begin
  FController.SelectLocalSchema(AName);
end;

function TFRpAISchemaSelectorVCL.GetHubDatabaseId: Int64;
begin
  Result := FController.GetHubDatabaseId;
end;

function TFRpAISchemaSelectorVCL.GetHubSchemaId: Int64;
begin
  Result := FController.GetHubSchemaId;
end;

function TFRpAISchemaSelectorVCL.GetSchemaApiKey: string;
begin
  Result := FController.GetSchemaApiKey;
end;

function TFRpAISchemaSelectorVCL.GetLocalSchemaName: string;
begin
  Result := FController.GetLocalSchemaName;
end;

function TFRpAISchemaSelectorVCL.GetCloudDatabaseFilter: Int64;
begin
  Result := FController.CloudDatabaseFilter;
end;

procedure TFRpAISchemaSelectorVCL.SetCloudDatabaseFilter(AValue: Int64);
begin
  FController.CloudDatabaseFilter := AValue;
end;

function TFRpAISchemaSelectorVCL.GetOnSchemaChanged: TNotifyEvent;
begin
  Result := FController.OnSchemaChanged;
end;

procedure TFRpAISchemaSelectorVCL.SetOnSchemaChanged(AValue: TNotifyEvent);
begin
  FController.OnSchemaChanged := AValue;
end;

function TFRpAISchemaSelectorVCL.GetOnNewLocalSchema: TNotifyEvent;
begin
  Result := FController.OnNewLocalSchema;
end;

procedure TFRpAISchemaSelectorVCL.SetOnNewLocalSchema(AValue: TNotifyEvent);
begin
  FController.OnNewLocalSchema := AValue;
end;

end.
