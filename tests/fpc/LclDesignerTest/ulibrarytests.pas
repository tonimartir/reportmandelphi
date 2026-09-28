unit ulibrarytests;

{ Phase 8: report library (reports stored in a database) of the LCL designer,
  parity with the VCL designer: library connections editor (rpeditconnlcl,
  port of rpeditconnvcl), the editable library tree (rpmdftreelcl, port of
  rpmdftreevcl) in the library dialog (rpmdfopenliblcl) and File > Libraries
  of the designer (configure, open from, save to).

  Everything runs against SQLite libraries in a temporary folder (no
  server): the current directory is that folder during the tests, so the FPC
  data drivers read their connection parameters from its
  dbxconnections.ini, and the designer library connections are saved in a
  temporary repmandlib (RpDesignerLCLLibConfigFile).

  The modal dialogs (connections editor, library dialog, input and message
  boxes) are answered by a script: a queue of expected dialogs handled
  synchronously when they are shown. The handler is installed after the
  modal guard of uregressiontests, so it runs first; the answered forms get
  the tag of the guard, which then ignores them. }

{$mode delphi}

interface

procedure RunLibraryTests;

implementation

uses
  Classes, SysUtils, Variants, Types, Forms, Controls, StdCtrls, ComCtrls, Menus,
  Graphics, DB, sqldb, sqlite3conn, sqlite3dyn,
  rptypes, rpmdconsts, rpreport, rpparams, rpdatainfo, rpgraphutilslcl,
  rpmdfmainlcl, rpmdfopenliblcl, rpmdftreelcl, rpeditconnlcl, rpdbxconfiglcl,
  umainform, udialoglayouttests;

const
  // GUARD_HANDLED_TAG of uregressiontests
  SCRIPT_HANDLED_TAG = $5EC7;
  LIB_ALIAS = 'TESTLIB';
  ZEOS_ALIAS = 'ZEOSLIB';

type
  TLibFormAction = procedure(AForm: TCustomForm) of object;

  { TLibStep }

  // One expected modal dialog: a message/input box answered with a button
  // (and a text), or a form handled by an action (that closes it)
  TLibStep = class
  public
    FormClass: TClass;
    Answer: TMessageButton;
    InputText: string;
    Action: TLibFormAction;
  end;

  { TLibTests }

  TLibTests = class
  private
    FSteps: TList;
    FDir: string;
    FDbPath: string;
    FZeosDbPath: string;
    FOldDir: string;
    FExportDir: string;
    FLastMessage: string;
    FDialogsShown: Integer;
    FZeosAvailable: Boolean;
    procedure FormVisibleChanged(Sender: TObject; Form: TCustomForm);
    procedure ExpectBox(AAnswer: TMessageButton; const AInput: string = '');
    procedure ExpectForm(AClass: TClass; AAction: TLibFormAction);
    procedure CheckNoPendingDialogs(const AContext: string);
    // Scripted dialog actions
    procedure EditConnectionsAction(AForm: TCustomForm);
    procedure EditConnectionsCancelAction(AForm: TCustomForm);
    procedure BrowseCancelAction(AForm: TCustomForm);
    procedure DbxConfigCloseAction(AForm: TCustomForm);
    procedure SaveAsNewReportAction(AForm: TCustomForm);
    procedure OpenSavedReportAction(AForm: TCustomForm);
    // Helpers
    function DbQueryValue(const ADbPath, ASQL: string): string;
    function DbReportBlob(const ADbPath, AReportName: string): TMemoryStream;
    function DbReportParams(const ADbPath, AReportName: string): string;
    function FindMenuItem(AForm: TCustomForm; const ACaption: WideString): TMenuItem;
    function LibraryItem(AList: TRpDatabaseInfoList; const AAlias: string): TRpDatabaseInfoItem;
    // Saves a PNG of the control in the folder of RP_LIBTESTS_SHOTS (if set)
    procedure Shot(AControl: TWinControl; const AName: string);
  public
    constructor Create;
    destructor Destroy; override;
    function Setup: Boolean;
    procedure Teardown;
    procedure TestConnectionsEditor;
    procedure TestLibraryTreeActions;
    procedure TestSaveAndOpenFromLibrary;
    procedure TestZeosLibrary;
    procedure TestUnsupportedDriver;
  end;

procedure Fail(const Msg: string);
begin
  LogMsg('[TEST_FAILED] ' + Msg);
  Halt(1);
end;

procedure Check(Cond: Boolean; const Msg: string);
begin
  if not Cond then
    Fail(Msg);
end;

procedure CheckInt(Expected, Actual: Integer; const What: string);
begin
  if Expected <> Actual then
    Fail(Format('%s: expected %d, got %d', [What, Expected, Actual]));
end;

procedure CheckStr(const Expected, Actual: string; const What: string);
begin
  if Expected <> Actual then
    Fail(Format('%s: expected "%s", got "%s"', [What, Expected, Actual]));
end;

procedure WriteTextFile(const AFileName, AText: string);
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Text := AText;
    sl.SaveToFile(AFileName);
  finally
    sl.Free;
  end;
end;

procedure DeleteTree(const ADir: string);
var
  sr: TSearchRec;
begin
  if not DirectoryExists(ADir) then
    Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, sr) = 0 then
  begin
    repeat
      if (sr.Name = '.') or (sr.Name = '..') then
        Continue;
      if (sr.Attr and faDirectory) <> 0 then
        DeleteTree(IncludeTrailingPathDelimiter(ADir) + sr.Name)
      else
        DeleteFile(IncludeTrailingPathDelimiter(ADir) + sr.Name);
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
  RemoveDir(ADir);
end;

// Runs AProc and returns the message of the exception it raises ('' if none)
function RaisedMessage(AProc: TProcedure): string;
begin
  Result := '';
  try
    AProc;
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

var
  Tests: TLibTests = nil;
  // Context of the procedures passed to RaisedMessage
  CurTree: TFRpDBTreeLCL = nil;
  CurNode: TTreeNode = nil;
  CurName: string = '';
  CurEdit: TFRpEditConLCL = nil;

procedure DoDeleteNode;
begin
  CurTree.DeleteNode(CurNode);
end;

procedure DoNewReport;
begin
  CurTree.NewReport(CurName);
end;

procedure DoRenameNode;
begin
  CurTree.RenameNode(CurNode, CurName);
end;

procedure DoFindNext;
begin
  CurTree.FindNext(CurName);
end;

procedure DoDeleteClick;
begin
  CurTree.BDelete.Click;
end;

procedure DoNewConnClick;
begin
  CurEdit.BNewConn.Click;
end;

procedure DoRenameConnClick;
begin
  CurEdit.BRenameConn.Click;
end;

procedure DoReadOnlyNewReport;
begin
  CurTree.NewReport('NOPE');
end;

{ TLibTests }

constructor TLibTests.Create;
begin
  inherited Create;
  FSteps := TList.Create;
end;

destructor TLibTests.Destroy;
var
  i: Integer;
begin
  for i := 0 to FSteps.Count - 1 do
    TObject(FSteps[i]).Free;
  FSteps.Free;
  inherited Destroy;
end;

procedure TLibTests.FormVisibleChanged(Sender: TObject; Form: TCustomForm);
var
  step: TLibStep;
  dlg: TFRpMessageDlgVCL;
  btn: TButton;
begin
  if not Assigned(Form) or not Form.Visible or not (fsModal in Form.FormState) then
    Exit;
  if Form.Tag = SCRIPT_HANDLED_TAG then
    Exit;
  if FSteps.Count = 0 then
    Fail('Library tests: unexpected modal dialog ' + Form.ClassName + ' "' + Form.Caption + '"');
  step := TLibStep(FSteps[0]);
  FSteps.Delete(0);
  try
    if not (Form is step.FormClass) then
      Fail('Library tests: expected the dialog ' + step.FormClass.ClassName + ', shown ' +
        Form.ClassName + ' "' + Form.Caption + '"');
    Form.Tag := SCRIPT_HANDLED_TAG;
    Inc(FDialogsShown);
    if Form is TFRpMessageDlgVCL then
    begin
      dlg := TFRpMessageDlgVCL(Form);
      FLastMessage := dlg.LMessage.Caption;
      if dlg.EInput.Visible then
        dlg.EInput.Text := step.InputText;
      case step.Answer of
        smbYes: btn := dlg.BYes;
        smbNo: btn := dlg.BNo;
        smbCancel: btn := dlg.BCancel;
      else
        btn := dlg.BOk;
      end;
      if not btn.Visible then
        Fail('Library tests: the box "' + FLastMessage + '" has no button for the answer');
      LogMsg('LibraryTests: answering "' + FLastMessage + '" with ' + btn.Caption);
      dlg.BYesClick(btn);
    end
    else
    begin
      LogMsg('LibraryTests: handling the dialog ' + Form.ClassName);
      step.Action(Form);
      if Form.ModalResult = mrNone then
        Fail('Library tests: the action did not close ' + Form.ClassName);
    end;
  finally
    step.Free;
  end;
end;

procedure TLibTests.ExpectBox(AAnswer: TMessageButton; const AInput: string);
var
  step: TLibStep;
begin
  step := TLibStep.Create;
  step.FormClass := TFRpMessageDlgVCL;
  step.Answer := AAnswer;
  step.InputText := AInput;
  FSteps.Add(step);
end;

procedure TLibTests.ExpectForm(AClass: TClass; AAction: TLibFormAction);
var
  step: TLibStep;
begin
  step := TLibStep.Create;
  step.FormClass := AClass;
  step.Action := AAction;
  FSteps.Add(step);
end;

procedure TLibTests.CheckNoPendingDialogs(const AContext: string);
begin
  if FSteps.Count > 0 then
    Fail(AContext + ': expected dialogs that were never shown (' +
      TLibStep(FSteps[0]).FormClass.ClassName + ')');
end;

function TLibTests.DbQueryValue(const ADbPath, ASQL: string): string;
var
  conn: TSQLite3Connection;
  tr: TSQLTransaction;
  q: TSQLQuery;
begin
  // An independent connection: sees only what the designer committed
  Result := '';
  conn := TSQLite3Connection.Create(nil);
  tr := TSQLTransaction.Create(nil);
  q := TSQLQuery.Create(nil);
  try
    conn.DatabaseName := ADbPath;
    conn.Transaction := tr;
    tr.DataBase := conn;
    q.DataBase := conn;
    q.Transaction := tr;
    q.SQL.Text := ASQL;
    q.Open;
    if not q.Eof then
      Result := q.Fields[0].AsString;
    q.Close;
    tr.Commit;
    conn.Close;
  finally
    q.Free;
    tr.Free;
    conn.Free;
  end;
end;

function TLibTests.DbReportBlob(const ADbPath, AReportName: string): TMemoryStream;
var
  conn: TSQLite3Connection;
  tr: TSQLTransaction;
  q: TSQLQuery;
begin
  Result := TMemoryStream.Create;
  conn := TSQLite3Connection.Create(nil);
  tr := TSQLTransaction.Create(nil);
  q := TSQLQuery.Create(nil);
  try
    conn.DatabaseName := ADbPath;
    conn.Transaction := tr;
    tr.DataBase := conn;
    q.DataBase := conn;
    q.Transaction := tr;
    q.SQL.Text := 'SELECT REPORT FROM REPMAN_REPORTS WHERE REPORT_NAME=:N';
    q.ParamByName('N').AsString := AReportName;
    q.Open;
    Check(not q.Eof, 'Library report ' + AReportName + ' not found in ' + ADbPath);
    TBlobField(q.Fields[0]).SaveToStream(Result);
    Result.Position := 0;
    q.Close;
    tr.Commit;
    conn.Close;
  finally
    q.Free;
    tr.Free;
    conn.Free;
  end;
end;

// The parameter names of a library report, loaded as the designer does
function TLibTests.DbReportParams(const ADbPath, AReportName: string): string;
var
  ms: TMemoryStream;
  rep: TRpReport;
  i: Integer;
begin
  Result := '';
  ms := DbReportBlob(ADbPath, AReportName);
  rep := TRpReport.Create(nil);
  try
    try
      rep.LoadFromStream(ms);
    except
      on E: Exception do
        Fail('Library report ' + AReportName + ' (' + IntToStr(ms.Size) +
          ' bytes) does not load: ' + E.Message);
    end;
    for i := 0 to rep.Params.Count - 1 do
    begin
      if i > 0 then
        Result := Result + ',';
      Result := Result + rep.Params.Items[i].Name;
    end;
  finally
    rep.Free;
    ms.Free;
  end;
end;

function TLibTests.FindMenuItem(AForm: TCustomForm; const ACaption: WideString): TMenuItem;

  function Search(AItem: TMenuItem): TMenuItem;
  var
    i: Integer;
  begin
    Result := nil;
    for i := 0 to AItem.Count - 1 do
    begin
      if StringReplace(AItem.Items[i].Caption, '&', '', [rfReplaceAll]) =
        StringReplace(string(ACaption), '&', '', [rfReplaceAll]) then
      begin
        Result := AItem.Items[i];
        Exit;
      end;
      Result := Search(AItem.Items[i]);
      if Assigned(Result) then
        Exit;
    end;
  end;

var
  i: Integer;
begin
  Result := nil;
  for i := 0 to AForm.ComponentCount - 1 do
  begin
    if AForm.Components[i] is TMainMenu then
    begin
      Result := Search(TMainMenu(AForm.Components[i]).Items);
      if Assigned(Result) then
        Exit;
    end;
  end;
end;

function TLibTests.LibraryItem(AList: TRpDatabaseInfoList; const AAlias: string): TRpDatabaseInfoItem;
var
  i: Integer;
begin
  i := AList.IndexOf(AAlias);
  Check(i >= 0, 'Library connection ' + AAlias + ' not found');
  Result := AList.Items[i];
end;

procedure TLibTests.Shot(AControl: TWinControl; const AName: string);
var
  dir: string;
  bmp: TBitmap;
  png: TPortableNetworkGraphic;
  i: Integer;
begin
  dir := GetEnvironmentVariable('RP_LIBTESTS_SHOTS');
  if dir = '' then
    Exit;
  for i := 1 to 10 do
  begin
    Application.ProcessMessages;
    Sleep(15);
  end;
  bmp := TBitmap.Create;
  png := TPortableNetworkGraphic.Create;
  try
    bmp.SetSize(AControl.Width, AControl.Height);
    bmp.Canvas.Brush.Color := clWhite;
    bmp.Canvas.FillRect(Rect(0, 0, bmp.Width, bmp.Height));
    AControl.PaintTo(bmp.Canvas, 0, 0);
    png.Assign(bmp);
    ForceDirectories(dir);
    png.SaveToFile(IncludeTrailingPathDelimiter(dir) + AName + '.png');
    LogMsg('LibraryTests: screenshot ' + AName + '.png');
  finally
    png.Free;
    bmp.Free;
  end;
end;

function TLibTests.Setup: Boolean;
var
  conn: TSQLite3Connection;
begin
  Result := False;
  FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_libtests_' + IntToStr(GetProcessID);
  DeleteTree(FDir);
  ForceDirectories(FDir);
  FDbPath := IncludeTrailingPathDelimiter(FDir) + 'library.db';
  FZeosDbPath := IncludeTrailingPathDelimiter(FDir) + 'libraryz.db';
  FExportDir := IncludeTrailingPathDelimiter(FDir) + 'export';

  // The SQLite client library must be available. Without the development
  // link (libsqlite3.so) use the runtime one, as rpdatainfo does on Linux
  {$IFDEF UNIX}
  if not FileExists('/usr/lib/x86_64-linux-gnu/libsqlite3.so') and
    not FileExists('/usr/lib/libsqlite3.so') and
    (FileExists('/lib/x86_64-linux-gnu/libsqlite3.so.0') or
     FileExists('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0')) then
    sqlite3dyn.SQLiteDefaultLibrary := 'libsqlite3.so.0';
  {$ENDIF}
  conn := TSQLite3Connection.Create(nil);
  try
    conn.DatabaseName := IncludeTrailingPathDelimiter(FDir) + 'probe.db';
    try
      conn.Open;
      conn.Close;
    except
      on E: Exception do
      begin
        LogMsg('[TEST_SKIPPED] library tests: SQLite client library not available: ' + E.Message);
        Exit;
      end;
    end;
  finally
    conn.Free;
  end;

  // Connection parameters of the FPC drivers (FireDac -> SQLdb, Zeos)
  WriteTextFile(IncludeTrailingPathDelimiter(FDir) + 'dbxconnections.ini',
    '[' + LIB_ALIAS + ']' + LineEnding +
    'DriverName=SQLite' + LineEnding +
    'Database=' + FDbPath + LineEnding + LineEnding +
    '[' + ZEOS_ALIAS + ']' + LineEnding +
    'DriverName=sqlite' + LineEnding +
    'Database Protocol=sqlite' + LineEnding +
    'Database=' + FZeosDbPath + LineEnding);
  FOldDir := GetCurrentDir;
  SetCurrentDir(FDir);
  RpDesignerLCLLibConfigFile := IncludeTrailingPathDelimiter(FDir) + 'repmandlib.ini';
  Result := True;
end;

procedure TLibTests.Teardown;
begin
  RpDesignerLCLLibConfigFile := '';
  if FOldDir <> '' then
    SetCurrentDir(FOldDir);
  DeleteTree(FDir);
  if DirectoryExists(FDir) then
    LogMsg('Note: could not delete ' + FDir);
end;

{ Connections editor }

procedure TLibTests.DbxConfigCloseAction(AForm: TCustomForm);
begin
  // Configure: the connections file dialog (rpdbxconfiglcl), closed
  AForm.ModalResult := mrCancel;
end;

procedure TLibTests.BrowseCancelAction(AForm: TCustomForm);
var
  dia: TFRpOpenLibLCL;
begin
  // Browse library of the connections editor: the library tree of the
  // working copy
  dia := TFRpOpenLibLCL(AForm);
  CheckStr(LIB_ALIAS, dia.ComboLibrary.Text, 'Browse: library of the selected connection');
  Check(Assigned(dia.Tree.DbInfo), 'Browse: the tree reads the library');
  CheckInt(1, dia.ATree.Items.Count, 'Browse: empty library (only the root)');
  CheckStr(LIB_ALIAS, dia.ATree.Items.GetFirstNode.Text, 'Browse: root node');
  dia.BCancel.Click;
end;

procedure TLibTests.EditConnectionsAction(AForm: TCustomForm);
var
  dia: TFRpEditConLCL;
  item: TRpDatabaseInfoItem;
  msg: string;
begin
  dia := TFRpEditConLCL(AForm);
  CurEdit := dia;
  Check(dia.Width <= dia.Scale96ToScreen(800), 'Connections dialog fits a 800x720 screen (width)');
  Check(dia.Height <= dia.Scale96ToScreen(650), 'Connections dialog fits a 800x720 screen (height)');
  CheckInt(0, dia.LConnections.Items.Count, 'No library connections yet');
  Check(not dia.PCon2.Visible, 'No connection: no editors');

  // New connection (toolbar, name asked)
  ExpectBox(smbOK, 'testlib');
  dia.BNewConn.Click;
  CheckInt(1, dia.LConnections.Items.Count, 'New connection added');
  CheckStr(LIB_ALIAS, dia.LConnections.Items[0], 'Connection names are upper case');
  CheckInt(0, dia.LConnections.ItemIndex, 'The new connection is selected');
  Check(dia.PCon2.Visible, 'The editors are shown');
  CheckStr('REPMAN_REPORTS', dia.EReportTable.Text, 'Default reports table');
  CheckStr('REPORT', dia.EReportField.Text, 'Default report field');
  CheckStr('REPORT_NAME', dia.EReportSearchField.Text, 'Default search field');
  CheckStr('REPMAN_GROUPS', dia.EReportGroupsTable.Text, 'Default groups table');
  Check(dia.CheckLoadParams.Checked, 'Load params by default');
  // The user edits it
  item := dia.Connections.Items[0];
  dia.CheckLoadParams.Checked := False;
  Check(not item.LoadParams, 'Load params stored in the connection');
  dia.CheckLoginPrompt.Checked := True;
  Check(item.LoginPrompt, 'Login prompt stored');
  dia.CheckLoginPrompt.Checked := False;
  dia.ComboDriver.ItemIndex := Ord(rpfiredac);
  dia.EReportTableChange(dia.ComboDriver);
  Check(item.Driver = rpfiredac, 'Driver stored');
  dia.EReportTable.Text := 'REPMAN_REPORTSX';
  CheckStr('REPMAN_REPORTSX', item.ReportTable, 'Reports table stored');
  dia.EReportTable.Text := 'REPMAN_REPORTS';

  // Connect
  ExpectBox(smbOK);
  dia.BTest.Click;
  CheckStr(SRpConnectionOk, FLastMessage, 'Connection test message');
  // Create the library tables
  dia.BCreateLib.Click;
  CheckStr('2', DbQueryValue(FDbPath,
    'SELECT COUNT(*) FROM sqlite_master WHERE type=''table'' AND name IN (''REPMAN_REPORTS'',''REPMAN_GROUPS'')'),
    'Create library: tables committed');
  // Browse the library (the tree of the working copy)
  ExpectForm(TFRpOpenLibLCL, BrowseCancelAction);
  dia.BBrowse.Click;
  // DBX configuration: the connections file dialog
  ExpectForm(TFRpDBXConfigLCL, DbxConfigCloseAction);
  dia.BConfig.Click;
  CheckNoPendingDialogs('Configure (connections file)');

  // Existing name
  ExpectBox(smbOK, 'TestLib');
  msg := RaisedMessage(DoNewConnClick);
  Check(Pos(LIB_ALIAS, msg) > 0, 'A repeated connection name raises: ' + msg);
  CheckInt(1, dia.LConnections.Items.Count, 'No repeated connection');
  // Cancelled input: nothing
  ExpectBox(smbCancel, 'IGNORED');
  dia.BNewConn.Click;
  CheckInt(1, dia.LConnections.Items.Count, 'Cancelled new connection');

  // Rename and delete
  dia.NewConnection('tempconn');
  CheckInt(2, dia.LConnections.Items.Count, 'Second connection');
  ExpectBox(smbOK, 'other');
  dia.BRenameConn.Click;
  CheckStr('OTHER', dia.LConnections.Items[1], 'Renamed connection');
  CheckStr('OTHER', dia.Connections.Items[1].Alias, 'Renamed connection alias');
  ExpectBox(smbOK, LIB_ALIAS);
  msg := RaisedMessage(DoRenameConnClick);
  Check(msg <> '', 'Rename to an existing connection raises');
  CheckStr('OTHER', dia.Connections.Items[1].Alias, 'Failed rename keeps the name');
  dia.SelectConnection('OTHER');
  dia.BDeleteConn.Click;
  CheckInt(1, dia.LConnections.Items.Count, 'Deleted connection');
  CheckStr(LIB_ALIAS, dia.LConnections.Items[dia.LConnections.ItemIndex], 'Selection after delete');

  // The Zeos library (FPC driver, same SQLite engine)
  dia.NewConnection(ZEOS_ALIAS);
  dia.CheckLoadParams.Checked := False;
  dia.ComboDriver.ItemIndex := Ord(rpdatazeos);
  dia.EReportTableChange(dia.ComboDriver);
  try
    dia.CreateLibrary;
    FZeosAvailable := True;
  except
    on E: Exception do
      LogMsg('Note: Zeos library not available: ' + E.Message);
  end;

  dia.BOK.Click;
  CurEdit := nil;
end;

procedure TLibTests.EditConnectionsCancelAction(AForm: TCustomForm);
var
  dia: TFRpEditConLCL;
begin
  dia := TFRpEditConLCL(AForm);
  CheckInt(2, dia.LConnections.Items.Count, 'Saved connections loaded in the editor');
  dia.SelectConnection(LIB_ALIAS);
  Check(dia.Connections.Items[dia.LConnections.ItemIndex].Driver = rpfiredac, 'Editor shows the driver');
  CheckInt(Ord(rpfiredac), dia.ComboDriver.ItemIndex, 'Driver combo');
  Check(not dia.CheckLoadParams.Checked, 'Load params check');
  dia.BDeleteConn.Click;
  CheckInt(1, dia.LConnections.Items.Count, 'Deleted in the working copy');
  dia.BCancel.Click;
end;

procedure TLibTests.TestConnectionsEditor;
var
  mf: TFRpMainFLCL;
  mi: TMenuItem;
  list: TRpDatabaseInfoList;
  item: TRpDatabaseInfoItem;
  edit: TFRpEditConLCL;
begin
  LogMsg('8: library connections editor (File > Libraries > Configure libraries)');
  mf := TFRpMainFLCL.Create(nil);
  try
    // File > Libraries submenu, as the VCL designer
    mi := FindMenuItem(mf, TranslateStr(1080, 'Libraries...'));
    Check(Assigned(mi), 'File > Libraries submenu');
    CheckInt(3, mi.Count, 'Libraries submenu entries');
    CheckStr(SRpConfigLib, mi.Items[0].Caption, 'Configure libraries entry');
    CheckStr(SRpOpenFrom, mi.Items[1].Caption, 'Open from library entry');
    CheckStr(SRpSaveTo, mi.Items[2].Caption, 'Save to library entry');
    mf.HostedMode := True;
    Check(not mi.Visible, 'Hosted designer hides the libraries');
    mf.HostedMode := False;
    Check(mi.Visible, 'Libraries shown again');

    CheckInt(0, mf.LibraryConnections.Count, 'No library connections');
    ExpectForm(TFRpEditConLCL, EditConnectionsAction);
    // Through the menu item
    mi.Items[0].Click;
    CheckNoPendingDialogs('Configure libraries');
    CheckInt(2, mf.LibraryConnections.Count, 'Accepted connections in the designer');
    item := LibraryItem(mf.LibraryConnections, LIB_ALIAS);
    Check(item.Driver = rpfiredac, 'Accepted driver');
    Check(not item.LoadParams, 'Accepted load params');
    Check(FileExists(RpDesignerLCLLibConfigFile), 'repmandlib written');

    // Saved in the library configuration file (repmandlib)
    list := TRpDatabaseInfoList.Create(nil);
    try
      list.LoadFromFile(RpDesignerLCLLibConfigFile);
      CheckInt(2, list.Count, 'Connections in repmandlib');
      item := LibraryItem(list, LIB_ALIAS);
      Check(item.Driver = rpfiredac, 'repmandlib driver');
      Check(not item.LoadParams, 'repmandlib load params');
      CheckStr('REPMAN_REPORTS', item.ReportTable, 'repmandlib reports table');
      CheckStr('REPMAN_GROUPS', item.ReportGroupsTable, 'repmandlib groups table');
      Check(LibraryItem(list, ZEOS_ALIAS).Driver = rpdatazeos, 'repmandlib Zeos driver');
    finally
      list.Free;
    end;

    if GetEnvironmentVariable('RP_LIBTESTS_SHOTS') <> '' then
    begin
      edit := TFRpEditConLCL.Create(nil);
      try
        edit.LoadConnections(mf.LibraryConnections);
        edit.SelectConnection(LIB_ALIAS);
        edit.Show;
        Shot(edit, 'connections_dialog');
        edit.Hide;
      finally
        edit.Free;
      end;
    end;

    // Cancel keeps the connections and the file
    ExpectForm(TFRpEditConLCL, EditConnectionsCancelAction);
    mf.ConfigureLibraries;
    CheckNoPendingDialogs('Configure libraries (cancel)');
    CheckInt(2, mf.LibraryConnections.Count, 'Cancelled editor keeps the connections');
  finally
    mf.Free;
  end;
  // A new designer reads them
  mf := TFRpMainFLCL.Create(nil);
  try
    CheckInt(2, mf.LibraryConnections.Count, 'A new designer reads repmandlib');
  finally
    mf.Free;
  end;
  LogMsg('Library connections editor verified');
end;

{ Library tree }

procedure TLibTests.TestLibraryTreeActions;
var
  list: TRpDatabaseInfoList;
  layout: string;
  item: TRpDatabaseInfoItem;
  dia: TFRpOpenLibLCL;
  tree: TFRpDBTreeLCL;
  root, nSales, nMonthly, nHR, nR1, nR2, n: TTreeNode;
  msg: string;
  ms, blob: TMemoryStream;
  rep: TRpReport;
  fname: string;
  accept: Boolean;
  r: TRect;
  lastctrl: TControl;
begin
  LogMsg('8: library tree actions (groups, reports, rename, move, delete, find, export)');
  list := TRpDatabaseInfoList.Create(nil);
  try
    list.LoadFromFile(RpDesignerLCLLibConfigFile);
    item := LibraryItem(list, LIB_ALIAS);
    dia := TFRpOpenLibLCL.Create(nil);
    try
      Check(dia.Width <= dia.Scale96ToScreen(800), 'Library dialog fits a 800x720 screen (width)');
      Check(dia.Height <= dia.Scale96ToScreen(650), 'Library dialog fits a 800x720 screen (height)');
      dia.EditTree(item);
      tree := dia.Tree;
      CurTree := tree;
      CheckInt(1, dia.ATree.Items.Count, 'Empty library: the root');
      root := tree.RootNode;
      CheckStr(LIB_ALIAS, root.Text, 'Root caption');
      Check(tree.BNewReport.Enabled and tree.BNewGroup.Enabled, 'Editable tree');

      // New groups (toolbar, name asked)
      dia.ATree.Selected := root;
      Check(not tree.BDelete.Enabled, 'The root can not be deleted');
      ExpectBox(smbOK, 'Sales');
      tree.BNewGroup.Click;
      nSales := dia.ATree.Selected;
      CheckStr('Sales', nSales.Text, 'New group selected');
      Check(nSales.Parent = root, 'Top level group');
      CheckStr('1', DbQueryValue(FDbPath, 'SELECT GROUP_CODE FROM REPMAN_GROUPS WHERE GROUP_NAME=''Sales'''),
        'Group row committed');
      CheckStr('0', DbQueryValue(FDbPath, 'SELECT PARENT_GROUP FROM REPMAN_GROUPS WHERE GROUP_NAME=''Sales'''),
        'Top group parent');
      ExpectBox(smbOK, 'Monthly');
      tree.BNewGroup.Click;
      nMonthly := dia.ATree.Selected;
      Check(nMonthly.Parent = nSales, 'Nested group');
      CheckStr('1', DbQueryValue(FDbPath, 'SELECT PARENT_GROUP FROM REPMAN_GROUPS WHERE GROUP_NAME=''Monthly'''),
        'Nested group parent');
      // Cancelled: nothing
      ExpectBox(smbCancel, 'IGNORED');
      tree.BNewGroup.Click;
      CheckStr('2', DbQueryValue(FDbPath, 'SELECT COUNT(*) FROM REPMAN_GROUPS'), 'Cancelled new group');
      dia.ATree.Selected := root;
      nHR := tree.NewGroup('HR');
      CheckInt(3, TRpLibNodeInfo(nHR.Data).GroupCode, 'Next group code');

      // New reports
      dia.ATree.Selected := nSales;
      ExpectBox(smbOK, 'R1');
      tree.BNewReport.Click;
      nR1 := dia.ATree.Selected;
      CheckStr('R1', nR1.Text, 'New report selected');
      Check(nR1.Parent = nSales, 'Report in the selected group');
      Check(tree.BPreview.Enabled and tree.BPrint.Enabled and tree.BParams.Enabled,
        'Report actions enabled for a report');
      CheckStr('1', DbQueryValue(FDbPath, 'SELECT REPORT_GROUP FROM REPMAN_REPORTS WHERE REPORT_NAME=''R1'''),
        'Report row committed');
      // The new report is a valid empty report
      ms := DbReportBlob(FDbPath, 'R1');
      rep := TRpReport.Create(nil);
      try
        rep.LoadFromStream(ms);
        Check(rep.SubReports.Count > 0, 'New library report loads');
      finally
        rep.Free;
        ms.Free;
      end;
      // With a report selected the new one goes to its group (the VCL adds
      // it under the report node)
      ExpectBox(smbOK, 'R2');
      tree.BNewReport.Click;
      nR2 := dia.ATree.Selected;
      Check(nR2.Parent = nSales, 'New report in the group of the selected report');
      CurName := 'R1';
      msg := RaisedMessage(DoNewReport);
      Check(Pos('R1', msg) > 0, 'A repeated report name raises: ' + msg);
      CheckStr('2', DbQueryValue(FDbPath, 'SELECT COUNT(*) FROM REPMAN_REPORTS'), 'No repeated report');
      dia.ATree.Selected := nSales;
      Check(not tree.BPreview.Enabled, 'Report actions disabled for a group');

      // Rename (context menu, name asked)
      dia.ATree.Selected := nHR;
      Check(tree.MRename.Enabled, 'Rename enabled');
      ExpectBox(smbOK, 'People');
      tree.MRename.Click;
      CheckStr('People', nHR.Text, 'Renamed group node');
      CheckStr('People', DbQueryValue(FDbPath, 'SELECT GROUP_NAME FROM REPMAN_GROUPS WHERE GROUP_CODE=3'),
        'Renamed group row');
      tree.RenameNode(nR2, 'R_TWO');
      CheckStr('R_TWO', nR2.Text, 'Renamed report node');
      CheckStr('R_TWO', TRpLibNodeInfo(nR2.Data).ReportName, 'Renamed report data');
      CheckStr('1', DbQueryValue(FDbPath, 'SELECT COUNT(*) FROM REPMAN_REPORTS WHERE REPORT_NAME=''R_TWO'''),
        'Renamed report row');
      CurNode := nR2;
      CurName := 'R1';
      msg := RaisedMessage(DoRenameNode);
      Check(msg <> '', 'Rename to an existing report raises');
      CheckStr('R_TWO', nR2.Text, 'Failed rename keeps the name');

      // Delete: a group with reports, then with groups
      CurNode := nSales;
      msg := RaisedMessage(DoDeleteNode);
      CheckStr(SRpExistReportInThisGroup, msg, 'Group with reports');
      // Move the reports away (the second one through the drag events)
      Check(tree.CanMoveNode(nR1, nHR), 'Report to another group');
      Check(not tree.CanMoveNode(nR1, nSales), 'Report to its own group');
      Check(not tree.CanMoveNode(nR1, nR2), 'Report onto a report of its group');
      tree.MoveNode(nR1, nHR);
      Check(nR1.Parent = nHR, 'Moved report node');
      CheckInt(3, TRpLibNodeInfo(nR1.Data).GroupCode, 'Moved report data');
      CheckStr('3', DbQueryValue(FDbPath, 'SELECT REPORT_GROUP FROM REPMAN_REPORTS WHERE REPORT_NAME=''R1'''),
        'Moved report row');
      dia.Show;
      Application.ProcessMessages;
      nHR.Expand(False);
      nSales.Expand(False);
      Application.ProcessMessages;
      dia.ATree.Selected := nR1;
      Shot(dia, 'library_dialog');
      layout := DialogLayoutProblems(dia);
      Check(layout = '', 'Library dialog layout: ' + layout);
      r := nR1.DisplayRect(True);
      if (r.Bottom > r.Top) and (dia.ATree.GetNodeAt(r.Left + 2, (r.Top + r.Bottom) div 2) = nR1) then
      begin
        // R_TWO dropped on R1: to the group of R1
        dia.ATree.Selected := nR2;
        accept := False;
        dia.ATree.OnDragOver(dia.ATree, dia.ATree, r.Left + 2, (r.Top + r.Bottom) div 2,
          dsDragMove, accept);
        Check(accept, 'Drag over: a report onto a report of another group');
        dia.ATree.OnDragDrop(dia.ATree, dia.ATree, r.Left + 2, (r.Top + r.Bottom) div 2);
        dia.ATree.OnEndDrag(dia.ATree, nil, 0, 0);
      end
      else
      begin
        LogMsg('Note: drag events not checked (node not laid out)');
        tree.MoveNode(nR2, nR1);
      end;
      Check(nR2.Parent = nHR, 'Dropped report node');
      CheckStr('3', DbQueryValue(FDbPath, 'SELECT REPORT_GROUP FROM REPMAN_REPORTS WHERE REPORT_NAME=''R_TWO'''),
        'Dropped report row');
      // The toolbar fits the dialog in one row
      lastctrl := tree.BExport;
      Check(lastctrl.Left + lastctrl.Width <= tree.BToolBar.ClientWidth,
        Format('Library toolbar fits the dialog (%d > %d)', [lastctrl.Left + lastctrl.Width,
        tree.BToolBar.ClientWidth]));
      CheckInt(tree.BNewGroup.Top, lastctrl.Top, 'Library toolbar in one row');
      Check(tree.EFind.Left > tree.BDelete.Left, 'Find edit after the delete button');
      Check(tree.BFind.Left > tree.EFind.Left, 'Find button after the find edit');
      dia.Hide;

      CurNode := nSales;
      msg := RaisedMessage(DoDeleteNode);
      CheckStr(SRpGroupParent, msg, 'Group with groups');
      Check(not tree.CanMoveNode(nSales, nMonthly), 'A group into its own branch');
      Check(not tree.CanMoveNode(nMonthly, nSales), 'A group to its own parent');
      Check(not tree.CanMoveNode(root, nHR), 'The root does not move');
      Check(tree.CanMoveNode(nMonthly, root), 'A group to the root');
      tree.MoveNode(nMonthly, root);
      Check(nMonthly.Parent = root, 'Moved group node');
      CheckStr('0', DbQueryValue(FDbPath, 'SELECT PARENT_GROUP FROM REPMAN_GROUPS WHERE GROUP_NAME=''Monthly'''),
        'Moved group row');
      // Now it can be deleted (confirmation)
      dia.ATree.Selected := nSales;
      ExpectBox(smbYes);
      tree.BDelete.Click;
      Check(tree.FindGroupNode(1) = nil, 'Deleted group node');
      CheckStr('0', DbQueryValue(FDbPath, 'SELECT COUNT(*) FROM REPMAN_GROUPS WHERE GROUP_CODE=1'),
        'Deleted group row');
      // A group with reports, through the toolbar
      dia.ATree.Selected := nHR;
      ExpectBox(smbYes);
      msg := RaisedMessage(DoDeleteClick);
      CheckStr(SRpExistReportInThisGroup, msg, 'Toolbar delete of a group with reports');

      // Delete a report: cancelled, then confirmed
      dia.ATree.Selected := nR2;
      ExpectBox(smbCancel);
      tree.BDelete.Click;
      Check(Assigned(tree.FindReportNode('R_TWO')), 'Cancelled delete');
      ExpectBox(smbYes);
      tree.BDelete.Click;
      Check(tree.FindReportNode('R_TWO') = nil, 'Deleted report node');
      CheckStr('0', DbQueryValue(FDbPath, 'SELECT COUNT(*) FROM REPMAN_REPORTS WHERE REPORT_NAME=''R_TWO'''),
        'Deleted report row');
      nR2 := nil;

      // More content for find and export
      dia.ATree.Selected := nMonthly;
      tree.NewReport('Monthly sales');
      dia.ATree.Selected := root;
      tree.NewReport('Root report');

      // Find (from the node after the selection, case insensitive)
      dia.ATree.Selected := root;
      tree.EFind.Text := 'sales';
      tree.BFind.Click;
      CheckStr('Monthly sales', dia.ATree.Selected.Text, 'Find');
      CurName := 'sales';
      msg := RaisedMessage(DoFindNext);
      CheckStr(SRptReportnotfound, msg, 'Find next without more matches');
      dia.ATree.Selected := root;
      tree.FindNext('PEOP');
      Check(dia.ATree.Selected = nHR, 'Find a group');

      // Export to a folder tree
      ForceDirectories(FExportDir);
      tree.ExportToFolder(FExportDir);
      fname := IncludeTrailingPathDelimiter(FExportDir) + 'People' + PathDelim + 'R1.rep';
      Check(FileExists(fname), 'Exported report in its group folder');
      Check(FileExists(IncludeTrailingPathDelimiter(FExportDir) + 'Monthly' + PathDelim +
        'Monthly sales.rep'), 'Exported report of another group');
      Check(FileExists(IncludeTrailingPathDelimiter(FExportDir) + 'Root report.rep'),
        'Exported report of the root');
      ms := TMemoryStream.Create;
      blob := DbReportBlob(FDbPath, 'R1');
      try
        ms.LoadFromFile(fname);
        Check((ms.Size = blob.Size) and CompareMem(ms.Memory, blob.Memory, ms.Size),
          'Exported file is the library report');
      finally
        ms.Free;
        blob.Free;
      end;

      // Preview/Print/Params load the report in a TLCLReport
      dia.ATree.Selected := nR1;
      tree.LoadSelectedReport;
      Check(Assigned(tree.Report) and Assigned(tree.Report.Report), 'Selected report loaded');
      Check(tree.Report.Report.SubReports.Count > 0, 'Loaded report content');
      dia.ATree.Selected := nMonthly;
      msg := '';
      try
        tree.LoadSelectedReport;
      except
        on E: Exception do
          msg := E.Message;
      end;
      CheckStr(SRptReportnotfound, msg, 'A group is not a report');

      // Double click / OK accepts only a report
      dia.ATree.Selected := nR1;
      dia.AcceptSelection;
      CheckStr('R1', dia.SelectedReport, 'Accepted report');
      Check(dia.DoOk, 'Dialog accepted');
    finally
      dia.Free;
      CurTree := nil;
    end;

    // Read only tree (VCL EditTree(dbinfo,true))
    dia := TFRpOpenLibLCL.Create(nil);
    try
      dia.Tree.EditTree(item, True);
      CurTree := dia.Tree;
      Check(not dia.Tree.BNewReport.Enabled and not dia.Tree.BNewGroup.Enabled and
        not dia.Tree.BExport.Enabled, 'Read only tree: no maintenance');
      Check(dia.ATree.DragMode = dmManual, 'Read only tree: no drag');
      msg := RaisedMessage(DoReadOnlyNewReport);
      Check(msg <> '', 'Read only tree: NewReport raises');
    finally
      dia.Free;
      CurTree := nil;
    end;
  finally
    list.Free;
  end;

  // Everything was committed: a new connection reads the same library
  list := TRpDatabaseInfoList.Create(nil);
  dia := TFRpOpenLibLCL.Create(nil);
  try
    list.LoadFromFile(RpDesignerLCLLibConfigFile);
    dia.EditTree(LibraryItem(list, LIB_ALIAS));
    // root, People{R1}, Monthly{Monthly sales}, Root report
    CheckInt(6, dia.ATree.Items.Count, 'Library read again');
    root := dia.Tree.RootNode;
    nHR := dia.Tree.FindGroupNode(3);
    Check(Assigned(nHR) and (nHR.Text = 'People') and (nHR.Parent = root), 'People group read again');
    n := dia.Tree.FindReportNode('R1');
    Check(Assigned(n) and (n.Parent = nHR), 'R1 read again in People');
    n := dia.Tree.FindReportNode('Monthly sales');
    Check(Assigned(n) and (n.Parent.Text = 'Monthly') and (n.Parent.Parent = root),
      'Monthly sales read again');
    Check(Assigned(dia.Tree.FindReportNode('Root report')), 'Root report read again');
  finally
    dia.Free;
    list.Free;
  end;
  LogMsg('Library tree actions verified');
end;

{ Save to / open from library }

procedure TLibTests.SaveAsNewReportAction(AForm: TCustomForm);
var
  dia: TFRpOpenLibLCL;
begin
  // VCL Save to library: a new report is created in the dialog and selected
  dia := TFRpOpenLibLCL(AForm);
  dia.SelectLibrary(LIB_ALIAS);
  dia.ATree.Selected := dia.Tree.FindGroupNode(3);
  ExpectBox(smbOK, 'SAVED1');
  dia.Tree.BNewReport.Click;
  CheckStr('SAVED1', dia.SelectedNodeReportName, 'New report selected in the dialog');
  dia.BOK.Click;
end;

procedure TLibTests.OpenSavedReportAction(AForm: TCustomForm);
var
  dia: TFRpOpenLibLCL;
begin
  dia := TFRpOpenLibLCL(AForm);
  CheckStr(LIB_ALIAS, dia.ComboLibrary.Text, 'Open from: library');
  dia.ATree.Selected := dia.Tree.FindReportNode('SAVED1');
  Check(Assigned(dia.ATree.Selected), 'Open from: the saved report is in the tree');
  // Double click accepts it
  dia.ATree.OnDblClick(dia.ATree);
end;

procedure TLibTests.TestSaveAndOpenFromLibrary;
var
  mf, mf2: TFRpMainFLCL;
  mi: TMenuItem;
  msg: string;
begin
  LogMsg('8: save to library (File > Libraries > Save to library) and open from library');
  mf := TFRpMainFLCL.Create(nil);
  try
    mf.Report.Params.Add('LIBPARAM').Value := 'A';
    // A parameter without value (Null): FPC's ObjectBinaryToText could not
    // write it in the text format (rpstreamfpc does)
    mf.Report.Params.Add('NULLPARAM');
    mf.MarkExternalChange;
    Check(mf.Report.Modified, 'Modified report');
    ExpectForm(TFRpOpenLibLCL, SaveAsNewReportAction);
    mi := FindMenuItem(mf, SRpSaveTo);
    Check(Assigned(mi), 'Save to library menu entry');
    mi.Click;
    CheckNoPendingDialogs('Save to library');
    CheckStr(LIB_ALIAS, mf.LibraryName, 'Saved: library of the document');
    CheckStr('SAVED1', mf.LibraryReportName, 'Saved: report of the document');
    CheckStr('', mf.FileName, 'Saved: no file');
    Check(not mf.Report.Modified, 'Saved: not modified');
    Check(Pos(LIB_ALIAS + '->SAVED1', mf.Caption) > 0, 'Saved: title ' + mf.Caption);
    CheckStr('LIBPARAM,NULLPARAM', DbReportParams(FDbPath, 'SAVED1'), 'Saved report content committed');
    CheckStr('3', DbQueryValue(FDbPath, 'SELECT REPORT_GROUP FROM REPMAN_REPORTS WHERE REPORT_NAME=''SAVED1'''),
      'Saved report in the selected group');

    // File > Save saves it again to the library
    mf.Report.Params.Add('LIBPARAM2').Value := 'B';
    mf.MarkExternalChange;
    mi := FindMenuItem(mf, TranslateStr(46, 'Save'));
    Check(Assigned(mi), 'Save menu entry');
    mi.Click;
    Check(not mf.Report.Modified, 'Save: not modified');
    CheckStr('LIBPARAM,NULLPARAM,LIBPARAM2', DbReportParams(FDbPath, 'SAVED1'), 'Save to the library committed');

    // A failed save keeps the document
    msg := '';
    try
      mf.SaveReportToLibrary(LIB_ALIAS, 'NOT_IN_LIBRARY');
    except
      on E: Exception do
        msg := E.Message;
    end;
    Check(Pos(SRptReportnotfound, msg) > 0, 'Save to a missing report raises: ' + msg);
    CheckStr('SAVED1', mf.LibraryReportName, 'Failed save keeps the report name');
    CheckStr(LIB_ALIAS, mf.LibraryName, 'Failed save keeps the library');
  finally
    // Frees the designer library connections: what was saved stays
    mf.Free;
  end;
  CheckStr('LIBPARAM,NULLPARAM,LIBPARAM2', DbReportParams(FDbPath, 'SAVED1'),
    'Saved report after closing the designer');

  // Open from library (menu), in a new designer
  mf2 := TFRpMainFLCL.Create(nil);
  try
    ExpectForm(TFRpOpenLibLCL, OpenSavedReportAction);
    mi := FindMenuItem(mf2, SRpOpenFrom);
    Check(Assigned(mi), 'Open from library menu entry');
    mi.Click;
    CheckNoPendingDialogs('Open from library');
    CheckStr('SAVED1', mf2.LibraryReportName, 'Opened library report');
    Check(mf2.Report.Params.IndexOf('LIBPARAM2') >= 0, 'Opened report content');
    Check(not mf2.Report.Modified, 'Opened unmodified');
    // The read does not keep the library locked: another connection writes
    CheckStr('1', DbQueryValue(FDbPath, 'SELECT COUNT(*) FROM REPMAN_REPORTS WHERE REPORT_NAME=''SAVED1'''),
      'Library readable');
  finally
    mf2.Free;
  end;
  LogMsg('Save to and open from library verified');
end;

{ Zeos }

procedure TLibTests.TestZeosLibrary;
var
  list: TRpDatabaseInfoList;
  dia: TFRpOpenLibLCL;
  mf: TFRpMainFLCL;
  msg: string;
begin
  LogMsg('8: report library with the Zeos driver (SQLite)');
  if not FZeosAvailable then
  begin
    LogMsg('[TEST_SKIPPED] Zeos library: the library could not be created');
    Exit;
  end;
  list := TRpDatabaseInfoList.Create(nil);
  dia := TFRpOpenLibLCL.Create(nil);
  try
    list.LoadFromFile(RpDesignerLCLLibConfigFile);
    dia.EditTree(LibraryItem(list, ZEOS_ALIAS));
    dia.ATree.Selected := dia.Tree.RootNode;
    dia.Tree.NewGroup('ZGroup');
    dia.Tree.NewReport('Z1');
    CheckStr('1', DbQueryValue(FZeosDbPath, 'SELECT REPORT_GROUP FROM REPMAN_REPORTS WHERE REPORT_NAME=''Z1'''),
      'Zeos: report row');
    dia.Tree.RenameNode(dia.Tree.FindReportNode('Z1'), 'Z2');
    CheckStr('1', DbQueryValue(FZeosDbPath, 'SELECT COUNT(*) FROM REPMAN_REPORTS WHERE REPORT_NAME=''Z2'''),
      'Zeos: renamed report');
  finally
    dia.Free;
    list.Free;
  end;
  mf := TFRpMainFLCL.Create(nil);
  try
    mf.Report.Params.Add('ZPARAM').Value := 'Z';
    mf.MarkExternalChange;
    msg := '';
    try
      mf.SaveReportToLibrary(ZEOS_ALIAS, 'Z2');
    except
      on E: Exception do
        msg := E.Message;
    end;
    // rpdatainfo DoCommit called TZConnection.Commit, that raises in
    // AutoCommit mode (the default) after the UPDATE succeeded
    CheckStr('', msg, 'Zeos: save to library without an error');
    CheckStr('ZPARAM', DbReportParams(FZeosDbPath, 'Z2'), 'Zeos: saved report');
  finally
    mf.Free;
  end;
  LogMsg('Zeos report library verified');
end;

procedure TLibTests.TestUnsupportedDriver;
var
  list: TRpDatabaseInfoList;
  item: TRpDatabaseInfoItem;
  dia: TFRpOpenLibLCL;
  msg: string;
begin
  LogMsg('8: a library on the Reportman AI Agent driver is reported, not an access violation');
  list := TRpDatabaseInfoList.Create(nil);
  dia := TFRpOpenLibLCL.Create(nil);
  try
    item := list.Add('AGENTLIB');
    item.Driver := rpdbHttp;
    item.LoadParams := False;
    msg := '';
    try
      dia.EditTree(item);
    except
      on E: Exception do
        msg := E.Message;
    end;
    Check(Pos(SRpDriverNotSupported, msg) = 1, 'Agent library: driver not supported: ' + msg);
  finally
    dia.Free;
    list.Free;
  end;
  LogMsg('Unsupported library driver verified');
end;

procedure RunLibraryTests;
begin
  LogMsg('Testing Phase 8: report library (connections, tree, save to / open from)');
  Tests := TLibTests.Create;
  try
    // After the modal guard of uregressiontests: this handler runs first
    Screen.AddHandlerFormVisibleChanged(Tests.FormVisibleChanged);
    try
      if Tests.Setup then
      begin
        try
          Tests.TestConnectionsEditor;
          Tests.TestLibraryTreeActions;
          Tests.TestSaveAndOpenFromLibrary;
          Tests.TestZeosLibrary;
          Tests.TestUnsupportedDriver;
          Tests.CheckNoPendingDialogs('Library tests');
        finally
          Tests.Teardown;
        end;
      end;
    finally
      Screen.RemoveHandlerFormVisibleChanged(Tests.FormVisibleChanged);
    end;
  finally
    FreeAndNil(Tests);
  end;
  LogMsg('Phase 8 report library tests completed successfully');
end;

end.
