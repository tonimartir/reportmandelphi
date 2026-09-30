unit udataconfigtests;

{ Phase 8 (data access) tests of the LCL designer, without network:

  - Connections tab of TFRpDInfoLCL: drivers of the FPC build, a driver the
    build does not have kept for the connection that uses it, driver
    description, connections of the connections file offered by driver (New
    drop down) and added with their driver, Load params / Load driver params
    with Cancel, OK, undo and redo, and the Connect test in a worker thread
    (SQLite through the FireDAC shim, and a failing one).
  - Datasets tab: MyBase page instead of the SQL one, MyBase properties and
    client side unions saved into the working copy, Cancel discards them, OK
    records the unions in the undo cue (the MyBase properties mark the report
    modified: they are not undo properties), undo and redo; "Show data" opens
    a copy of the data in a worker (records of a text file read with its field
    definitions) and reports errors.
  - The records grid (rpmdfsampledatalcl) in batches, and the text file
    configuration dialog (rpmdfdatatextlcl): definitions read, added, saved,
    deleted and the sample file read with them.

  The dialogs run with Interactive = False (their messages are kept in
  LastMessage) and OnShowDataset: no modal window is shown. }

{$mode delphi}

interface

procedure RunDataConfigTests;

implementation

uses
  Classes, SysUtils, Variants, Forms, Controls, StdCtrls, Grids, DB, IniFiles,
  sqldb, sqlite3conn,
  rptypes, rpmdconsts, rpreport, rpdatainfo, rpdatatext, rpdataset,
  rpmdundocuelcl, rpaithreadslcl, rpmdfdinfolcl, rpdbxconfiglcl,
  rpmdfsampledatalcl, rpmdfdatatextlcl,
  umainform;

type
  { TDataConfigTests }

  TDataConfigTests = class
  private
    FDir: string;
    FFieldsFile: string;
    FDataFile: string;
    FSQLiteFile: string;
    FSQLiteAvailable: Boolean;
    FConnectionsFile: string;
    FShowCalls: Integer;
    FShowError: string;
    FShowRows: Integer;
    FShowFields: string;
    FShowAllLoaded: Boolean;
    FShowLastName: string;
    procedure PrepareFiles;
    procedure ShowDataset(Sender: TObject; ADataset: TDataset; const AError: string);
    function NewReport: TRpReport;
    procedure WaitWorkers(const AWhat: string);
    procedure TestConnectionsTab;
    procedure TestConnectionTest;
    procedure TestDatasetsTab;
    procedure TestShowData;
    procedure TestSampleGrid;
    procedure TestDataTextDialog;
    procedure TestTextDriver;
    procedure TestDialogSizes;
  public
    procedure Run;
  end;

{ Assertions }

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

procedure WriteText(const AFileName, AText: string);
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    LList.Text := AText;
    LList.SaveToFile(AFileName);
  finally
    LList.Free;
  end;
end;

function ItemsText(AList: TStrings): string;
begin
  Result := StringReplace(Trim(AList.Text), LineEnding, ',', [rfReplaceAll]);
end;

{ TDataConfigTests }

procedure TDataConfigTests.PrepareFiles;
var
  lfields: TStringList;
  fobj: TRpFieldObj;
  conn: TSQLite3Connection;
  tr: TSQLTransaction;
begin
  FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_dataconfigtest_' +
    IntToStr(GetProcessID) + PathDelim;
  ForceDirectories(FDir);
  // A text file with fixed width fields and its field definitions
  FFieldsFile := FDir + 'fields.ini';
  FDataFile := FDir + 'data.txt';
  lfields := TStringList.Create;
  try
    fobj := TRpFieldObj.Create;
    fobj.fieldname := 'ID';
    fobj.fieldtype := ftInteger;
    fobj.posbegin := 1;
    fobj.fieldsize := 3;
    fobj.fieldtrim := True;
    lfields.AddObject(fobj.fieldname, fobj);
    fobj := TRpFieldObj.Create;
    fobj.fieldname := 'NAME';
    fobj.fieldtype := ftString;
    fobj.posbegin := 4;
    fobj.fieldsize := 10;
    fobj.fieldtrim := True;
    lfields.AddObject(fobj.fieldname, fobj);
    SaveFieldObjListToFile(lfields, FFieldsFile, #10, #13);
  finally
    FreeFieldObjList(lfields);
    lfields.Free;
  end;
  // Lines separated by LF (the record separator), without a CR
  with TStringList.Create do
  try
    LineBreak := #10;
    Add('001Alice     Paris ');
    Add('002Bob       Rome  ');
    Add('003Carol     Oslo  ');
    SaveToFile(FDataFile);
  finally
    Free;
  end;

  // SQLite database for the connection test (the FireDAC shim of FPC)
  FSQLiteFile := FDir + 'test.db';
  FSQLiteAvailable := False;
  conn := TSQLite3Connection.Create(nil);
  tr := TSQLTransaction.Create(nil);
  try
    conn.DatabaseName := FSQLiteFile;
    conn.Transaction := tr;
    tr.DataBase := conn;
    try
      conn.Open;
      conn.ExecuteDirect('CREATE TABLE T1 (ID INTEGER, NAME VARCHAR(20))');
      tr.Commit;
      conn.Close;
      FSQLiteAvailable := True;
    except
      on E: Exception do
        LogMsg('[TEST_SKIPPED] SQLite connection test: client library not available: ' + E.Message);
    end;
  finally
    tr.Free;
    conn.Free;
  end;

  // Connections file offered by the New drop down
  FConnectionsFile := FDir + 'dbxconnections_test.ini';
  WriteText(FConnectionsFile,
    '[SQLITECONN]' + LineEnding +
    'DriverName=SQLite' + LineEnding +
    'Database=' + FSQLiteFile + LineEnding +
    '[FDCONN]' + LineEnding +
    'DriverName=FireDac' + LineEnding +
    'DriverID=SQLite' + LineEnding +
    'Database=' + FSQLiteFile + LineEnding +
    '[ZEOSCONN]' + LineEnding +
    'DriverName=ZeosLib' + LineEnding +
    'Database Protocol=sqlite' + LineEnding +
    '[MYSQLCONN]' + LineEnding +
    'DriverName=MySQL' + LineEnding +
    '[HUBCONN]' + LineEnding +
    'DriverName=Reportman AI Agent' + LineEnding +
    'ApiKey=x' + LineEnding +
    'HubDatabaseId=5' + LineEnding +
    '[PLAIN]' + LineEnding +
    'Database=' + FDir + LineEnding);
end;

function TDataConfigTests.NewReport: TRpReport;
begin
  Result := TRpReport.Create(nil);
  Result.AddSubReport;
  Result.UndoCue := TUndoCue.Create(Result);
end;

procedure TDataConfigTests.WaitWorkers(const AWhat: string);
begin
  if not RpAsyncWaitIdle(20000) then
    Fail('timeout waiting for ' + AWhat);
  Application.ProcessMessages;
end;

procedure TDataConfigTests.ShowDataset(Sender: TObject; ADataset: TDataset;
  const AError: string);
var
  LForm: TFRpShowSampleDataLCL;
  i: Integer;
begin
  Inc(FShowCalls);
  FShowError := AError;
  FShowRows := -1;
  FShowFields := '';
  if ADataset = nil then
    Exit;
  Check(ADataset.Active, 'Show data: the dataset is open during the call');
  for i := 0 to ADataset.FieldCount - 1 do
  begin
    if i > 0 then
      FShowFields := FShowFields + ',';
    FShowFields := FShowFields + ADataset.Fields[i].FieldName;
  end;
  // The records grid (not modal)
  LForm := TFRpShowSampleDataLCL.Create(nil);
  try
    LForm.BatchSize := 2;
    LForm.SetDataset(ADataset);
    CheckInt(2, LForm.RecordCount, 'Show data: first batch of records');
    Check(not LForm.AllLoaded, 'Show data: more records to read');
    Check(LForm.MoreButton.Enabled, 'Show data: More records enabled');
    LForm.LoadMore;
    FShowRows := LForm.RecordCount;
    FShowAllLoaded := LForm.AllLoaded;
    FShowLastName := LForm.Grid.Cells[LForm.Grid.ColCount - 1, LForm.Grid.RowCount - 1];
    Check(not LForm.MoreButton.Enabled, 'Show data: More records disabled at the end');
  finally
    LForm.Free;
  end;
end;

procedure TDataConfigTests.TestConnectionsTab;
var
  rep: TRpReport;
  cue: TUndoCue;
  dlg: TFRpDInfoLCL;
  oldOverride: string;
  nOps, i: Integer;
  raised: Boolean;
begin
  LogMsg('Phase 8: connections tab (drivers, connections file, load params, undo)');
  rep := NewReport;
  oldOverride := DBXConnectionsFileOverride;
  DBXConnectionsFileOverride := FConnectionsFile;
  try
    cue := TUndoCue(rep.UndoCue);
    rep.DatabaseInfo.Add('ZCONN').Driver := rpdatazeos;
    rep.DatabaseInfo.Add('ADOCONN').Driver := rpdataado;
    rep.DatabaseInfo.Add('DOTNETCONN').Driver := rpdatadriver;
    cue.MarkClean;

    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Interactive := False;
      dlg.Report := rep;
      // Drivers of the FPC build
      CheckInt(4, dlg.DriverList.Items.Count, 'Driver list: drivers of the FPC build');
      for i := 0 to dlg.DriverList.Items.Count - 1 do
        Check(IsFpcDriverAvailable(TRpDbDriver(PtrInt(dlg.DriverList.Items.Objects[i]))),
          'Driver list: only available drivers');
      CheckStr(FpcDriverName(rpdatazeos), dlg.DriverList.Items[dlg.DriverList.ItemIndex],
        'Driver list: Zeos selected by default');
      CheckStr(Trim(string(SrpDriverZeosDesc)), Trim(dlg.DriverHelp.Text),
        'Driver description of Zeos');
      // The first connection: its driver selected among the FPC ones
      CheckInt(4, dlg.DriverCombo.Items.Count, 'Driver combo: drivers of the FPC build');
      CheckStr(FpcDriverName(rpdatazeos), dlg.DriverCombo.Text, 'Driver combo: Zeos connection');
      // A driver the FPC build does not have is kept
      dlg.ConnectionList.ItemIndex := 1;
      dlg.ConnectionList.OnClick(dlg.ConnectionList);
      CheckInt(5, dlg.DriverCombo.Items.Count, 'Driver combo: the ADO driver listed for its connection');
      Check(Pos(FpcDriverName(rpdataado), dlg.DriverCombo.Text) = 1,
        'Driver combo: ADO connection shows its driver (' + dlg.DriverCombo.Text + ')');
      Check(Pos(string(TranslateStr(1036, 'Not available')), dlg.DriverCombo.Text) > 0,
        'Driver combo: marked as not available');
      dlg.ConnectionList.ItemIndex := 2;
      dlg.ConnectionList.OnClick(dlg.ConnectionList);
      Check(Pos(FpcDriverName(rpdatadriver), dlg.DriverCombo.Text) = 1,
        'Driver combo: .Net connection shows its driver');
      dlg.ConnectionList.ItemIndex := 0;
      dlg.ConnectionList.OnClick(dlg.ConnectionList);
      CheckInt(4, dlg.DriverCombo.Items.Count, 'Driver combo: back to the FPC drivers');
      nOps := cue.UndoOperations.Count;
      Check(dlg.ApplyChanges, 'OK without changes');
      Check(not dlg.Applied, 'Opening a report with unavailable drivers changes nothing');
      Check(rep.DatabaseInfo[1].Driver = rpdataado, 'ADO driver kept');
      Check(rep.DatabaseInfo[2].Driver = rpdatadriver, '.Net driver kept');
      CheckInt(nOps, cue.UndoOperations.Count, 'Nothing recorded');

      // Connections of the connections file by driver
      dlg.SelectListDriver(rpfiredac);
      CheckStr('SQLITECONN,FDCONN', ItemsText(dlg.AvailableConnections),
        'Available connections of the FireDAC / SQLdb driver');
      Check(Pos(string(SRpFireDacDesc), dlg.DriverHelp.Text) = 1, 'Driver description of FireDAC');
      dlg.SelectListDriver(rpdatazeos);
      CheckStr('ZEOSCONN,MYSQLCONN', ItemsText(dlg.AvailableConnections),
        'Available connections of Zeos (dbExpress entries too)');
      dlg.SelectListDriver(rpdbHttp);
      CheckStr('HUBCONN', ItemsText(dlg.AvailableConnections),
        'Available connections of the Reportman AI Agent driver');
      // In the language of the test machine (id 1670)
      Check(Pos(string(TranslateStr(1670, 'Executes SQL remotely via Reportman AI Agent bridge. ' +
        'Supports secure, non-interactive queries with API Keys.')), dlg.DriverHelp.Text) > 0,
        'Driver description of the Agent');
      dlg.SelectListDriver(rpdatamybase);
      CheckInt(0, dlg.AvailableConnections.Count, 'No available connection for MyBase (VCL)');
      Check(Pos(string(SRpMyBaseDesc), dlg.DriverHelp.Text) = 1, 'Driver description of MyBase');

      // New drop down: New + the available connections
      dlg.SelectListDriver(rpfiredac);
      dlg.AddConnectionMenu.OnPopup(dlg.AddConnectionMenu);
      CheckInt(3, dlg.AddConnectionMenu.Items.Count, 'New drop down: New and two connections');
      CheckStr('FDCONN', dlg.AddConnectionMenu.Items[2].Hint, 'New drop down: connection name');
      dlg.AddConnectionMenu.OnPopup(dlg.AddConnectionMenu);
      CheckInt(3, dlg.AddConnectionMenu.Items.Count, 'New drop down: filled again, not appended');

      // Adding a connection of the file: its driver from DriverName
      dlg.SelectListDriver(rpdatamybase);
      dlg.AddAvailableConnection('sqliteconn');
      CheckInt(4, dlg.WorkReport.DatabaseInfo.Count, 'Connection added to the working copy');
      CheckStr('SQLITECONN', dlg.WorkReport.DatabaseInfo[3].Alias, 'Added connection alias');
      Check(dlg.WorkReport.DatabaseInfo[3].Driver = rpfiredac,
        'Added connection: SQLite entries use the FireDAC shim');
      CheckInt(3, dlg.ConnectionList.ItemIndex, 'Added connection selected');
      CheckStr(FpcDriverName(rpfiredac), dlg.DriverCombo.Text, 'Added connection driver shown');
      dlg.AddAvailableConnection('MYSQLCONN');
      Check(dlg.WorkReport.DatabaseInfo[4].Driver = rpdatazeos,
        'Added connection: other dbExpress entries use Zeos');
      raised := False;
      try
        dlg.AddAvailableConnection('SQLITECONN');
      except
        raised := True;
      end;
      Check(raised, 'A connection is not added twice');
      CheckInt(3, rep.DatabaseInfo.Count, 'Report untouched until OK');

      // New: the driver of the driver list (the LCL used the .Net one)
      dlg.SelectListDriver(rpdatamybase);
      dlg.BNewConn.OnClick(dlg.BNewConn);
      CheckInt(6, dlg.WorkReport.DatabaseInfo.Count, 'New connection');
      Check(dlg.WorkReport.DatabaseInfo[5].Driver = rpdatamybase, 'New connection: driver of the list');

      // Load params / Load driver params
      dlg.ConnectionList.ItemIndex := 0;
      dlg.ConnectionList.OnClick(dlg.ConnectionList);
      Check(dlg.LoadParamsCheck.Checked and dlg.LoadDriverParamsCheck.Checked,
        'Load params checks read from the connection');
      dlg.LoadParamsCheck.Checked := False;
      dlg.LoadDriverParamsCheck.Checked := False;
      dlg.ConnectionList.ItemIndex := 1;
      dlg.ConnectionList.OnClick(dlg.ConnectionList);
      Check(not dlg.WorkReport.DatabaseInfo[0].LoadParams, 'Load params saved into the working copy');
      Check(not dlg.WorkReport.DatabaseInfo[0].LoadDriverParams,
        'Load driver params saved into the working copy');
      Check(rep.DatabaseInfo[0].LoadParams, 'Report untouched until OK (load params)');
      nOps := cue.UndoOperations.Count;
      Check(dlg.ApplyChanges, 'OK applies the connections');
    finally
      dlg.Free;
    end;
    CheckInt(6, rep.DatabaseInfo.Count, 'OK: connections added to the report');
    Check(rep.DatabaseInfo[3].Driver = rpfiredac, 'OK: driver of the added connection');
    Check(not rep.DatabaseInfo[0].LoadParams, 'OK: load params applied');
    Check(rep.DatabaseInfo[1].Driver = rpdataado, 'OK: ADO driver still kept');
    CheckInt(nOps + 4, cue.UndoOperations.Count, 'OK: three adds and one modify recorded');
    cue.Undo.Free;
    CheckInt(3, rep.DatabaseInfo.Count, 'Undo removes the added connections');
    Check(rep.DatabaseInfo[0].LoadParams and rep.DatabaseInfo[0].LoadDriverParams,
      'Undo restores load params');
    cue.Redo.Free;
    CheckInt(6, rep.DatabaseInfo.Count, 'Redo adds them again');
    Check(rep.DatabaseInfo.Items[rep.DatabaseInfo.IndexOf('SQLITECONN')].Driver = rpfiredac,
      'Redo restores the driver');
    Check(not rep.DatabaseInfo[0].LoadParams, 'Redo restores load params');

    // Cancel
    cue.MarkClean;
    nOps := cue.UndoOperations.Count;
    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Interactive := False;
      dlg.Report := rep;
      dlg.LoadParamsCheck.Checked := True;
      dlg.SaveControls;
      Check(dlg.WorkReport.DatabaseInfo[0].LoadParams, 'Cancel test: edited in the working copy');
    finally
      dlg.Free;
    end;
    Check(not rep.DatabaseInfo[0].LoadParams, 'Cancel discards load params');
    CheckInt(nOps, cue.UndoOperations.Count, 'Cancel records nothing');
    Check(not cue.IsDirty, 'Cancel leaves the report clean');
  finally
    DBXConnectionsFileOverride := oldOverride;
    rep.Free;
  end;
  LogMsg('Connections tab verified');
end;

procedure TDataConfigTests.TestConnectionTest;
var
  rep: TRpReport;
  dlg: TFRpDInfoLCL;
  oldOverride: string;
  nMessages: Integer;
begin
  LogMsg('Phase 8: Connect test of the connections tab (worker thread)');
  rep := NewReport;
  oldOverride := DBXConnectionsFileOverride;
  DBXConnectionsFileOverride := FConnectionsFile;
  try
    rep.DatabaseInfo.Add('NOSUCHCONN').Driver := rpdatazeos;
    rep.DatabaseInfo.Add('SQLITECONN').Driver := rpfiredac;
    rep.DatabaseInfo.Add('FDCONN').Driver := rpfiredac;
    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Interactive := False;
      dlg.Report := rep;
      // A connection without entry: the error of the driver
      dlg.StartConnectionTest;
      Check(dlg.ConnectionTestRunning, 'Connect test running');
      Check(not dlg.TestConnectionButton.Enabled, 'Connect disabled while testing');
      WaitWorkers('the failing connection test');
      Check(not dlg.ConnectionTestRunning, 'Connect test finished');
      Check(dlg.TestConnectionButton.Enabled, 'Connect enabled again');
      CheckInt(1, dlg.MessageCount, 'One message for the failing test');
      Check((dlg.LastMessage <> '') and (dlg.LastMessage <> string(SRpConnectionOk)),
        'The error of the failing test: ' + dlg.LastMessage);
      if FSQLiteAvailable then
      begin
        dlg.ConnectionList.ItemIndex := 1;
        dlg.ConnectionList.OnClick(dlg.ConnectionList);
        dlg.StartConnectionTest;
        WaitWorkers('the SQLite connection test');
        CheckStr(SRpConnectionOk, dlg.LastMessage, 'SQLite connection test passed');
        // DriverName=FireDac, DriverID=SQLite, as the connections dialog
        // writes it (the FPC FireDAC shim read DriverName first)
        dlg.ConnectionList.ItemIndex := 2;
        dlg.ConnectionList.OnClick(dlg.ConnectionList);
        dlg.StartConnectionTest;
        WaitWorkers('the FireDac/SQLite connection test');
        CheckStr(SRpConnectionOk, dlg.LastMessage, 'FireDac/SQLite connection test passed');
      end;
      // Answers of an earlier session are dropped
      nMessages := dlg.MessageCount;
      dlg.StartConnectionTest;
      dlg.Report := rep;
      WaitWorkers('a connection test of an earlier session');
      Check(dlg.TestConnectionButton.Enabled, 'New session: Connect enabled');
      Check(not dlg.ConnectionTestRunning, 'New session: no test running');
      CheckInt(nMessages, dlg.MessageCount, 'Answer of an earlier session dropped');
    finally
      dlg.Free;
    end;
    // Destroyed while testing: the answer is dropped
    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Interactive := False;
      dlg.Report := rep;
      dlg.StartConnectionTest;
    finally
      dlg.Free;
    end;
    WaitWorkers('a connection test of a destroyed dialog');
  finally
    DBXConnectionsFileOverride := oldOverride;
    rep.Free;
  end;
  LogMsg('Connect test verified');
end;

procedure TDataConfigTests.TestDatasetsTab;
var
  rep: TRpReport;
  cue: TUndoCue;
  dlg: TFRpDInfoLCL;
  ds: TRpDataInfoItem;
  nOps: Integer;

  procedure EditDS1(ADlg: TFRpDInfoLCL);
  begin
    CheckInt(0, ADlg.ActiveDatasetIndex, 'DS1 active');
    Check(ADlg.MyBaseArea.Visible, 'MyBase page shown for a MyBase connection');
    Check(not ADlg.SQLArea.Visible, 'SQL page hidden for a MyBase connection');
    CheckStr('DS2,DS3', ItemsText(ADlg.UnionsCombo.Items), 'Unions combo: the other datasets');
    ADlg.MyBaseFileEdit.Text := 'data.txt';
    ADlg.MyBaseFieldsEdit.Text := 'fields.ini';
    ADlg.IndexFieldsEdit.Text := 'ID';
    ADlg.MasterFieldsEdit.Text := 'ID';
    ADlg.AddUnion('DS2', '');
    CheckStr('DS2', ItemsText(ADlg.UnionsList.Items), 'Union added');
    CheckStr('DS2', ItemsText(ADlg.WorkReport.DataInfo[0].DataUnions),
      'Union saved into the working copy');
    ADlg.AddUnion('DS2', '');
    CheckInt(1, ADlg.UnionsList.Items.Count, 'A union is not added twice');
    // Parallel union: with the common fields
    ADlg.AddUnion('DS3', 'ID;NAME');
    CheckStr('DS2,DS3-ID;NAME', ItemsText(ADlg.WorkReport.DataInfo[0].DataUnions),
      'Parallel union with its common fields');
    ADlg.UnionsList.ItemIndex := 1;
    ADlg.DeleteUnion;
    CheckStr('DS2', ItemsText(ADlg.WorkReport.DataInfo[0].DataUnions), 'Union removed');
    ADlg.GroupUnionCheck.Checked := True;
    ADlg.ParallelUnionCheck.Checked := True;
    // Another dataset: DS1 saved, SQL page for a Zeos connection
    ADlg.DatasetList.ItemIndex := 2;
    ADlg.DatasetList.OnClick(ADlg.DatasetList);
    CheckInt(2, ADlg.ActiveDatasetIndex, 'DS3 active');
    Check(ADlg.SQLArea.Visible and not ADlg.MyBaseArea.Visible,
      'SQL page shown for a Zeos connection');
    ds := ADlg.WorkReport.DataInfo[0];
    CheckStr('data.txt', ds.MyBaseFilename, 'MyBase file saved into the working copy');
    CheckStr('fields.ini', ds.MyBaseFields, 'Field defs file saved into the working copy');
    CheckStr('ID', ds.MyBaseIndexFields, 'Index fields saved into the working copy');
    CheckStr('ID', ds.MyBaseMasterFields, 'Master fields saved into the working copy');
    Check(ds.GroupUnion and ds.ParallelUnion, 'Union options saved into the working copy');
    // Back to DS1: read again from the working copy
    ADlg.DatasetList.ItemIndex := 0;
    ADlg.DatasetList.OnClick(ADlg.DatasetList);
    CheckStr('data.txt', ADlg.MyBaseFileEdit.Text, 'MyBase file shown again');
    CheckStr('DS2', ItemsText(ADlg.UnionsList.Items), 'Unions shown again');
    Check(ADlg.GroupUnionCheck.Checked, 'Group union shown again');
    // The connection of a dataset changed to a MyBase one
    ADlg.DatasetList.ItemIndex := 2;
    ADlg.DatasetList.OnClick(ADlg.DatasetList);
    ADlg.ConnectionCombo.ItemIndex := ADlg.ConnectionCombo.Items.IndexOf('MYB');
    ADlg.ConnectionCombo.OnChange(ADlg.ConnectionCombo);
    Check(ADlg.MyBaseArea.Visible, 'MyBase page after choosing a MyBase connection');
    ADlg.ConnectionCombo.ItemIndex := ADlg.ConnectionCombo.Items.IndexOf('ZCONN');
    ADlg.ConnectionCombo.OnChange(ADlg.ConnectionCombo);
    Check(ADlg.SQLArea.Visible, 'SQL page after choosing a Zeos connection');
  end;

begin
  LogMsg('Phase 8: datasets tab (MyBase page, unions, undo)');
  rep := NewReport;
  try
    cue := TUndoCue(rep.UndoCue);
    rep.DatabaseInfo.Add('MYB').Driver := rpdatamybase;
    rep.DatabaseInfo.Add('ZCONN').Driver := rpdatazeos;
    ds := rep.DataInfo.Add('DS1');
    ds.DatabaseAlias := 'MYB';
    ds := rep.DataInfo.Add('DS2');
    ds.DatabaseAlias := 'MYB';
    ds := rep.DataInfo.Add('DS3');
    ds.DatabaseAlias := 'ZCONN';
    ds.SQL := 'SELECT 1';
    cue.MarkClean;

    // Cancel: the working copy is discarded
    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Interactive := False;
      dlg.Report := rep;
      EditDS1(dlg);
      Check(not dlg.Applied, 'Cancel: nothing applied');
    finally
      dlg.Free;
    end;
    CheckStr('', rep.DataInfo[0].MyBaseFilename, 'Cancel: MyBase file not in the report');
    CheckInt(0, rep.DataInfo[0].DataUnions.Count, 'Cancel: unions not in the report');
    Check(not rep.DataInfo[0].GroupUnion, 'Cancel: group union not in the report');
    CheckInt(0, cue.UndoOperations.Count, 'Cancel: nothing recorded');
    Check(not cue.IsDirty, 'Cancel: report clean');

    // OK
    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Interactive := False;
      dlg.Report := rep;
      EditDS1(dlg);
      nOps := cue.UndoOperations.Count;
      Check(dlg.ApplyChanges, 'OK applies the datasets');
    finally
      dlg.Free;
    end;
    ds := rep.DataInfo[0];
    CheckStr('data.txt', ds.MyBaseFilename, 'OK: MyBase file');
    CheckStr('fields.ini', ds.MyBaseFields, 'OK: field defs file');
    CheckStr('ID', ds.MyBaseIndexFields, 'OK: index fields');
    CheckStr('ID', ds.MyBaseMasterFields, 'OK: master fields');
    CheckStr('DS2', ItemsText(ds.DataUnions), 'OK: unions');
    Check(ds.GroupUnion and ds.ParallelUnion, 'OK: union options');
    CheckInt(nOps + 1, cue.UndoOperations.Count, 'OK: one modify operation (DS1)');
    Check(cue.UndoOperations.Last.operation = otModify, 'OK: otModify');
    Check(cue.IsDirty and rep.Modified, 'OK: report modified');
    cue.Undo.Free;
    CheckInt(0, rep.DataInfo[0].DataUnions.Count, 'Undo restores the unions');
    Check(not rep.DataInfo[0].GroupUnion and not rep.DataInfo[0].ParallelUnion,
      'Undo restores the union options');
    // Not undo properties (neither in the Delphi cue): the report stays modified
    CheckStr('data.txt', rep.DataInfo[0].MyBaseFilename, 'Undo keeps the MyBase file');
    Check(cue.IsDirty, 'The MyBase change keeps the report modified after undo');
    cue.Redo.Free;
    CheckStr('DS2', ItemsText(rep.DataInfo[0].DataUnions), 'Redo restores the unions');
    Check(rep.DataInfo[0].GroupUnion, 'Redo restores the group union');

    // Removing a dataset with unions: undo recreates it with them
    cue.MarkClean;
    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Interactive := False;
      dlg.Report := rep;
      dlg.BDelDS.OnClick(dlg.BDelDS);
      CheckInt(2, dlg.WorkReport.DataInfo.Count, 'Dataset removed from the working copy');
      Check(dlg.ApplyChanges, 'OK applies the removal');
    finally
      dlg.Free;
    end;
    CheckInt(2, rep.DataInfo.Count, 'Dataset removed');
    cue.Undo.Free;
    CheckInt(3, rep.DataInfo.Count, 'Undo restores the removed dataset');
    CheckStr('DS2', ItemsText(rep.DataInfo.Items[rep.DataInfo.IndexOf('DS1')].DataUnions),
      'Undo restores the unions of the removed dataset');
  finally
    rep.Free;
  end;
  LogMsg('Datasets tab verified');
end;

procedure TDataConfigTests.TestShowData;
var
  rep: TRpReport;
  dlg: TFRpDInfoLCL;
  ds: TRpDataInfoItem;
  db: TRpDatabaseInfoItem;
begin
  LogMsg('Phase 8: Show data (worker thread, records grid)');
  rep := NewReport;
  try
    db := rep.DatabaseInfo.Add('MYB');
    db.Driver := rpdatamybase;
    // No connections file entry: the MyBase path is empty, the files are
    // given with their full path
    db.LoadParams := False;
    ds := rep.DataInfo.Add('TEXTDATA');
    ds.DatabaseAlias := 'MYB';
    ds.MyBaseFilename := FDataFile;
    ds.MyBaseFields := FFieldsFile;
    ds := rep.DataInfo.Add('MISSING');
    ds.DatabaseAlias := 'MYB';
    ds.MyBaseFilename := FDir + 'missing.txt';
    ds.MyBaseFields := FFieldsFile;
    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Interactive := False;
      dlg.OnShowDataset := ShowDataset;
      dlg.Report := rep;
      Check(dlg.BShowData.Enabled, 'Show data enabled for a dataset with a connection');
      FShowCalls := 0;
      dlg.StartShowData;
      Check(dlg.ShowDataRunning, 'Show data running');
      Check(not dlg.BShowData.Enabled, 'Show data disabled while opening');
      WaitWorkers('the dataset opened by Show data');
      CheckInt(1, FShowCalls, 'Show data: the records were shown');
      CheckStr('', FShowError, 'Show data: no error');
      CheckStr('LNUMBER,ID,NAME', FShowFields, 'Show data: fields of the text file');
      CheckInt(3, FShowRows, 'Show data: all the records in the grid');
      Check(FShowAllLoaded, 'Show data: all read');
      CheckStr('Carol', FShowLastName, 'Show data: last record in the grid');
      Check(dlg.BShowData.Enabled, 'Show data enabled again');
      // The working copy is not opened (a copy is)
      Check(dlg.WorkReport.DataInfo[0].Dataset = nil, 'Show data opens a copy of the data');
      // An error
      dlg.DatasetList.ItemIndex := 1;
      dlg.DatasetList.OnClick(dlg.DatasetList);
      dlg.StartShowData;
      WaitWorkers('the failing Show data');
      CheckInt(2, FShowCalls, 'Show data: the error was reported');
      Check(FShowError <> '', 'Show data: error message');
      // Without the hook the error is a message (not interactive here)
      dlg.OnShowDataset := nil;
      dlg.StartShowData;
      WaitWorkers('the failing Show data (message)');
      Check(dlg.LastMessage <> '', 'Show data: error message shown');
      // Dropped when the dialog is destroyed meanwhile
      dlg.DatasetList.ItemIndex := 0;
      dlg.DatasetList.OnClick(dlg.DatasetList);
      dlg.OnShowDataset := ShowDataset;
      dlg.StartShowData;
    finally
      dlg.Free;
    end;
    WaitWorkers('a Show data of a destroyed dialog');
    CheckInt(2, FShowCalls, 'Show data of a destroyed dialog: nothing shown');
  finally
    rep.Free;
  end;
  LogMsg('Show data verified');
end;

procedure TDataConfigTests.TestSampleGrid;
var
  data: TRpMemDataSet;
  form: TFRpShowSampleDataLCL;
  i: Integer;
begin
  LogMsg('Phase 8: records grid in batches');
  data := TRpMemDataSet.Create(nil);
  form := TFRpShowSampleDataLCL.Create(nil);
  try
    data.FieldDefs.Add('N', ftInteger);
    data.FieldDefs.Add('S', ftString, 20);
    data.FieldDefs.Add('M', ftMemo);
    data.CreateDataset;
    for i := 1 to 2500 do
    begin
      data.Append;
      data.Fields[0].AsInteger := i;
      data.Fields[1].AsString := 'Row ' + IntToStr(i);
      if i = 1 then
        data.Fields[2].AsString := 'first line' + LineEnding + 'second line';
      data.Post;
    end;
    data.First;
    form.SetDataset(data);
    CheckInt(4, form.Grid.ColCount, 'Grid: record number and three fields');
    CheckStr('S', form.Grid.Cells[2, 0], 'Grid: field names in the title row');
    CheckInt(RP_SAMPLE_DATA_BATCH, form.RecordCount, 'Grid: first batch');
    CheckStr('Row 1', form.Grid.Cells[2, 1], 'Grid: first record');
    CheckStr('first line...', form.Grid.Cells[3, 1], 'Grid: first line of a memo');
    form.LoadMore;
    CheckInt(2 * RP_SAMPLE_DATA_BATCH, form.RecordCount, 'Grid: second batch');
    form.LoadMore;
    CheckInt(2500, form.RecordCount, 'Grid: all the records');
    Check(form.AllLoaded and not form.MoreButton.Enabled, 'Grid: end of the dataset');
    CheckStr('Row 2500', form.Grid.Cells[2, 2500], 'Grid: last record');
    CheckStr('2500', form.Grid.Cells[0, 2500], 'Grid: record number');
    form.LoadMore;
    CheckInt(2500, form.RecordCount, 'Grid: nothing more to read');
    // A closed dataset: no fields, no records
    data.Close;
    form.SetDataset(data);
    CheckInt(0, form.RecordCount, 'Grid: closed dataset');
  finally
    form.Free;
    data.Free;
  end;
  LogMsg('Records grid verified');
end;

// rpdatatext (shared with Delphi): the decimal digits of a currency field
// (PRECISION) are saved with the field definitions, and time fields read
// the hour, minute and second positions
procedure TDataConfigTests.TestTextDriver;
var
  lfields: TStringList;
  fobj: TRpFieldObj;
  fieldsfile, datafile: string;
  rs, irs: Char;
  data: TRpMemDataSet;
begin
  LogMsg('Phase 8: text driver precision and time fields (rpdatatext)');
  fieldsfile := FDir + 'fields_prec.ini';
  datafile := FDir + 'data_prec.txt';
  lfields := TStringList.Create;
  try
    fobj := TRpFieldObj.Create;
    fobj.fieldname := 'AMOUNT';
    fobj.fieldtype := ftCurrency;
    fobj.posbegin := 1;
    fobj.fieldsize := 3;
    fobj.fieldtrim := True;
    fobj.posbeginprecision := 4;
    fobj.precision := 2;
    lfields.AddObject(fobj.fieldname, fobj);
    fobj := TRpFieldObj.Create;
    fobj.fieldname := 'TIMEF';
    fobj.fieldtype := ftTime;
    fobj.posbegin := 6;
    fobj.hourpos := 6;
    fobj.hoursize := 2;
    fobj.minpos := 8;
    fobj.minsize := 2;
    fobj.secpos := 10;
    fobj.secsize := 2;
    lfields.AddObject(fobj.fieldname, fobj);
    SaveFieldObjListToFile(lfields, fieldsfile, #10, #13);
  finally
    FreeFieldObjList(lfields);
    lfields.Free;
  end;
  lfields := TStringList.Create;
  try
    FillFieldObjList(fieldsfile, lfields, rs, irs);
    CheckInt(2, TRpFieldObj(lfields.Objects[0]).precision, 'PRECISION saved and read');
    CheckInt(8, TRpFieldObj(lfields.Objects[1]).minpos, 'Minute position read');
  finally
    FreeFieldObjList(lfields);
    lfields.Free;
  end;
  with TStringList.Create do
  try
    LineBreak := #10;
    Add('01234102030');
    SaveToFile(datafile);
  finally
    Free;
  end;
  data := TRpMemDataSet.Create(nil);
  try
    FillClientDatasetFromFile(data, fieldsfile, datafile, '');
    data.First;
    Check(not data.Eof, 'Text driver: one record');
    Check(Abs(data.FieldByName('AMOUNT').AsFloat - 12.34) < 0.0001,
      'Currency with its decimal digits: ' + data.FieldByName('AMOUNT').AsString);
    CheckStr('10:20:30', FormatDateTime('hh:nn:ss', data.FieldByName('TIMEF').AsDateTime),
      'Time field from the hour, minute and second positions');
  finally
    data.Free;
  end;
end;

procedure TDataConfigTests.TestDataTextDialog;
var
  f: TFRpDataTextLCL;
  lfields: TStringList;
  rs, irs: Char;
  row: Integer;
begin
  LogMsg('Phase 8: text file configuration dialog');
  f := TFRpDataTextLCL.Create(nil);
  try
    f.LoadFiles(FFieldsFile, FDataFile);
    CheckStr(FFieldsFile, f.EFileName.Text, 'Fields file shown');
    Check(f.BTest.Visible, 'Open visible with a sample file');
    CheckInt(3, f.MSource.Lines.Count, 'Sample file shown');
    CheckInt(3, f.GridFields.RowCount, 'Two definitions read');
    CheckStr('ID', f.GridFields.Cells[DTCOL_FIELDNAME, 1], 'First definition name');
    CheckStr(SRpSInteger, f.GridFields.Cells[DTCOL_FIELDTYPE, 1], 'First definition type');
    CheckStr('3', f.GridFields.Cells[DTCOL_FIELDSIZE, 1], 'First definition size');
    CheckStr('4', f.GridFields.Cells[DTCOL_POSBEGIN, 2], 'Second definition position');
    CheckStr(SRpYes, f.GridFields.Cells[DTCOL_TRIM, 2], 'Second definition trim');
    CheckStr('10', f.ERecordSeparator.Text, 'Record separator');
    // A new definition after the selected one
    f.GridFields.Row := 2;
    f.AddField;
    CheckInt(4, f.GridFields.RowCount, 'Definition added');
    row := f.GridFields.Row;
    CheckInt(3, row, 'New definition after the selected one');
    CheckStr('1', f.GridFields.Cells[DTCOL_POSBEGIN, row], 'New definition defaults (position)');
    f.GridFields.Cells[DTCOL_FIELDNAME, row] := 'CITY';
    f.GridFields.Cells[DTCOL_FIELDTYPE, row] := SRpSString;
    f.GridFields.Cells[DTCOL_FIELDSIZE, row] := '6';
    f.GridFields.Cells[DTCOL_POSBEGIN, row] := '14';
    f.Save;
    lfields := TStringList.Create;
    try
      FillFieldObjList(FFieldsFile, lfields, rs, irs);
      CheckInt(3, lfields.Count, 'Saved: three definitions');
      CheckStr('CITY', TRpFieldObj(lfields.Objects[2]).fieldname, 'Saved: new definition');
      Check(TRpFieldObj(lfields.Objects[2]).fieldtype = ftString, 'Saved: new definition type');
      CheckInt(14, TRpFieldObj(lfields.Objects[2]).posbegin, 'Saved: new definition position');
      CheckInt(6, TRpFieldObj(lfields.Objects[2]).fieldsize, 'Saved: new definition size');
      Check(TRpFieldObj(lfields.Objects[0]).fieldtype = ftInteger, 'Saved: type kept');
      CheckInt(10, Ord(rs), 'Saved: record separator');
    finally
      FreeFieldObjList(lfields);
      lfields.Free;
    end;
    // Open: the sample file read with the definitions
    f.TestData;
    Check(f.PControl.ActivePage = f.TabData, 'Open shows the data page');
    CheckInt(4, f.GridData.RowCount, 'Open: three records');
    CheckStr('CITY', f.GridData.Cells[4, 0], 'Open: new field');
    CheckStr('Oslo', f.GridData.Cells[4, 3], 'Open: value of the new field');
    CheckStr('Bob', f.GridData.Cells[3, 2], 'Open: value of a field');
    // Delete the new definition
    f.GridFields.Row := 3;
    f.DeleteField;
    CheckInt(3, f.GridFields.RowCount, 'Definition deleted');
    f.Save;
    lfields := TStringList.Create;
    try
      FillFieldObjList(FFieldsFile, lfields, rs, irs);
      CheckInt(2, lfields.Count, 'Saved after delete: two definitions');
    finally
      FreeFieldObjList(lfields);
      lfields.Free;
    end;
    // Types that are not in the list are kept by number
    CheckStr(IntToStr(Ord(ftFloat)), DataTextTypeName(ftFloat), 'Other types by number');
    Check(DataTextTypeFromName(IntToStr(Ord(ftFloat))) = ftFloat, 'Other types read back');
  finally
    f.Free;
  end;
  LogMsg('Text file configuration dialog verified');
end;

procedure TDataConfigTests.TestDialogSizes;
var
  dlg: TFRpDInfoLCL;
  dbx: TFRpDBXConfigLCL;
  f: TFRpDataTextLCL;
  s: TFRpShowSampleDataLCL;
begin
  LogMsg('Phase 8: dialogs fit the screen');
  dlg := TFRpDInfoLCL.Create(nil);
  dbx := TFRpDBXConfigLCL.Create(nil);
  f := TFRpDataTextLCL.Create(nil);
  s := TFRpShowSampleDataLCL.Create(nil);
  try
    Check(dlg.Width <= Screen.WorkAreaWidth, 'Data dialog width fits the screen');
    Check(dlg.Height <= Screen.WorkAreaHeight, 'Data dialog height fits the screen');
    Check(dbx.Width <= Screen.WorkAreaWidth, 'DBX dialog width fits the screen');
    Check(dbx.Height <= Screen.WorkAreaHeight, 'DBX dialog height fits the screen');
    Check(f.Height <= Screen.WorkAreaHeight, 'Text file dialog fits the screen');
    Check(s.Height <= Screen.WorkAreaHeight, 'Records dialog fits the screen');
  finally
    s.Free;
    f.Free;
    dbx.Free;
    dlg.Free;
  end;
end;

procedure TDataConfigTests.Run;
begin
  PrepareFiles;
  TestDialogSizes;
  TestConnectionsTab;
  TestConnectionTest;
  TestDatasetsTab;
  TestShowData;
  TestSampleGrid;
  TestDataTextDialog;
  TestTextDriver;
  Check(RpAsyncWaitIdle(10000), 'All the data configuration workers finished');
end;

procedure RunDataConfigTests;
var
  t: TDataConfigTests;
begin
  LogMsg('Testing Phase 8: data access configuration (connections, datasets, MyBase)');
  t := TDataConfigTests.Create;
  try
    t.Run;
  finally
    t.Free;
  end;
  LogMsg('Phase 8 data access tests completed successfully');
end;

end.
