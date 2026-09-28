{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdftreelcl                                    }
{       Report library tree: groups and reports of a    }
{       library table, with maintenance actions         }
{                                                       }
{       Port of rpmdftreevcl (TFRpDBTreeVCL)            }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdftreelcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  Menus, Dialogs, DB, sqldb, LazUTF8,
  rpmdconsts, rpdatainfo, rptypes, rpreport, rpgraphutilslcl, rplclreport;

const
  // Time between two progress updates of the long operations (ms)
  PROGRESS_INTERVAL = 500;

  // Images of the library tree, same indexes as the VCL frame
  IMG_LIB_NEWREPORT = 0;
  IMG_LIB_DELETE = 1;
  IMG_LIB_PREVIEW = 4;
  IMG_LIB_PRINT = 5;
  IMG_LIB_PARAMS = 6;
  IMG_LIB_PRINTSETUP = 7;
  IMG_LIB_NEWGROUP = 8;
  IMG_LIB_GROUP = 9;
  IMG_LIB_REPORT = 10;
  IMG_LIB_FIND = 11;
  IMG_LIB_EXPORT = 12;

type
  { TRpLibNodeInfo }

  // Data attached to every node of the library tree (VCL TRpNodeInfo).
  // Report nodes have a ReportName and the GroupCode of their group; group
  // nodes have no ReportName, their GroupCode and their ParentGroup. The
  // root node is the group 0.
  TRpLibNodeInfo = class(TObject)
  public
    ReportName: WideString;
    GroupCode: Integer;
    ParentGroup: Integer;
    Node: TTreeNode;
  end;

  { TFRpDBTreeLCL }

  // Port of TFRpDBTreeVCL (a frame in the VCL, a panel here, built in code).
  // EditTree reads the library of a connection; the actions change the
  // library tables at once, as in the VCL. The operations have methods
  // without questions (NewReport, NewGroup, DeleteNode, RenameNode, MoveNode,
  // FindNext, ExportToFolder); the toolbar and menu handlers ask the user and
  // call them. Errors are raised.
  TFRpDBTreeLCL = class(TPanel)
  private
    FDbInfo: TRpDatabaseInfoItem;
    FReadOnlyTree: Boolean;
    FNodeInfos: TList;
    FReport: TLCLReport;
    FCurrentLoaded: WideString;
    FDoCancel: Boolean;
    FLastProgress: QWord;
    FCounter: Integer;
    FExpandCount: Integer;
    FExpandTarget: TTreeNode;
    // Library contents read by EditTree
    FGroupCodes: array of Integer;
    FGroupNames: array of string;
    FGroupParents: array of Integer;
    FGroupVisited: array of Boolean;
    FReportNames: array of string;
    FReportGroups: array of Integer;

    procedure BuildControls;
    procedure ClearTree;
    function NewNodeInfo(ANode: TTreeNode; const AReportName: WideString;
      AGroupCode, AParentGroup: Integer): TRpLibNodeInfo;
    procedure FreeNodeInfos(ANode: TTreeNode);
    function IndexOfGroup(ACode: Integer): Integer;
    procedure AddReportNodes(AParentNode: TTreeNode; AGroupCode: Integer);
    procedure AddGroupNodes(AParentNode: TTreeNode; AParentCode: Integer);
    procedure GenerateTree(const ARootCaption: string);
    procedure CheckCancel(ACount: Integer);
    procedure BeginProgress;
    procedure EndProgress;
    procedure CheckEditable;
    function HasGroups: Boolean;
    function IsGInforme: Boolean;
    function GroupCodeField: string;
    function GroupNameField: string;
    function GroupParentField: string;
    function ReportGroupField: string;
    procedure ExecLibrarySQL(const ASQL: string; AParams: TStringList);
    function ReportExists(const AReportName: WideString): Boolean;
    procedure SaveGroupDir(const ADir: string; ANode: TTreeNode);
    procedure SaveReportFile(const ADir: string; AInfo: TRpLibNodeInfo);
    function GetRootNode: TTreeNode;

    // Toolbar, menu and tree handlers
    procedure ANewExecute(Sender: TObject);
    procedure ANewFolderExecute(Sender: TObject);
    procedure ADeleteExecute(Sender: TObject);
    procedure ARenameExecute(Sender: TObject);
    procedure AFindExecute(Sender: TObject);
    procedure APreviewExecute(Sender: TObject);
    procedure APrintExecute(Sender: TObject);
    procedure AUserParamsExecute(Sender: TObject);
    procedure APrintSetupExecute(Sender: TObject);
    procedure AExportFolderExecute(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure EFindKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ATreeSelectionChanged(Sender: TObject);
    procedure ATreeDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure ATreeDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure ATreeEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure TimerExpandTimer(Sender: TObject);
  public
    ImageList: TImageList;
    BToolBar: TToolBar;
    BNewGroup: TToolButton;
    BNewReport: TToolButton;
    BDelete: TToolButton;
    EFind: TEdit;
    BFind: TToolButton;
    BPreview: TToolButton;
    BParams: TToolButton;
    BPrint: TToolButton;
    BPrintSetup: TToolButton;
    BExport: TToolButton;
    BCancel: TButton;
    ATree: TTreeView;
    MPopup: TPopupMenu;
    MRename: TMenuItem;
    TimerExpand: TTimer;
    SelectDirDialog: TSelectDirectoryDialog;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Reads the report library (ReportTable / ReportSearchField /
    // ReportGroupsTable) of the connection and builds the group hierarchy
    // with its reports. AReadOnly disables the maintenance actions (VCL
    // EditTree(adbinfo,readonly)).
    procedure EditTree(adbinfo: TRpDatabaseInfoItem; AReadOnly: Boolean);
    function NodeInfo(ANode: TTreeNode): TRpLibNodeInfo;
    // Report name of the selected node, '' for a group node
    function SelectedReportName: WideString;
    // Group node of a node: itself for a group, its parent for a report
    function GroupNodeOf(ANode: TTreeNode): TTreeNode;
    function FindGroupNode(AGroupCode: Integer): TTreeNode;
    function FindReportNode(const AReportName: WideString): TTreeNode;
    // Updates the enabled state of the actions for the selected node
    procedure UpdateActions;

    // Library operations (no questions). New reports and groups go to the
    // group of the selected node (the root without selection) and are
    // selected; the database is changed and committed at once.
    function NewReport(const AReportName: WideString): TTreeNode;
    function NewGroup(const AGroupName: WideString): TTreeNode;
    procedure DeleteNode(ANode: TTreeNode);
    procedure RenameNode(ANode: TTreeNode; const ANewName: WideString);
    // Drag and drop rules: a report goes to the group of the target, a group
    // becomes a child of the target group (of the group of a target report);
    // never into itself or its own branch
    function CanMoveNode(ASource, ADest: TTreeNode): Boolean;
    procedure MoveNode(ASource, ADest: TTreeNode);
    // Selects the next node after the selected one containing AText (case
    // insensitive); raises SRptReportnotfound when there is none
    procedure FindNext(const AText: string);
    // Writes every report as <name>.rep in a folder tree like the groups
    procedure ExportToFolder(const ADir: string);
    // Loads the selected report in Report (VCL CheckLoaded)
    procedure LoadSelectedReport;

    property DbInfo: TRpDatabaseInfoItem read FDbInfo;
    property ReadOnlyTree: Boolean read FReadOnlyTree;
    property RootNode: TTreeNode read GetRootNode;
    // Runtime report of Preview, Print and Params (TLCLReport)
    property Report: TLCLReport read FReport;
  end;

// Ends the transaction of a library connection: commits the changes and
// releases the locks of the reads. The SQLdb connections of the FPC build
// (FireDac driver) keep a transaction open since Connect that
// TRpDatabaseInfoItem.DoCommit does not commit, and that is rolled back
// when the connection is freed.
procedure RpLibraryCommit(dbitem: TRpDatabaseInfoItem);
// Raises when the library functions of rpdatainfo can not use the driver
// of the connection (Reportman AI Agent: OpenDatasetFromSQL has no query
// for it)
procedure RpCheckLibraryDriver(dbitem: TRpDatabaseInfoItem);
// A name usable as a file or folder name on Windows and Linux
function RpLibraryFileName(const AName: string): string;
procedure LoadLibraryTreeImageList(AImageList: TImageList);

implementation

uses
  Variants, rpmdimageslcl;

const
  // Id 1820: new text of the LCL library (docs/i18n/fase8_libreria_ids.txt)
  SLibReportExistsDefault = 'The report already exists in the library';

  LIB_ICON_COUNT = 13;
  // Icons of the VCL frame (ImageCollection1 of rpmdftreevcl.dfm), 19x19
  LIB_ICON_HEX: array[0..LIB_ICON_COUNT - 1] of string = (
    // 0 : Item1, new report
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000002874944415478DAAD542D73DB' +
    '40145CB12726311F14B499CD1C28E8B294B530B430D0330D082CE94C49679ABF6168E8308B45F0A0C274EC8EA9FB9E64' +
    '2B9D7EA04A9E91CE77B76F77DF9E320003FED39529581C063CEE137CDBA17439965581F71F81FD3EE0CB37E0FE4ED005' +
    'C0B974DDF8F4E4461A44B8BBEBF0E3699119D810235AEF91420B1405C08D220ECBCD327B3EB583084192706E06DBAC36' +
    '57B0F3CB19EBD53A9B984534C7996E1F121CD9A53ED97BBD2310C4E6F23C9B174E60BFCA24B3FDFE11BBFA1D42EA0C04' +
    'B9B22BD09171BDAB71388CD5EEEF3FFDD9E5EC0D582083AEEFE857855373C26A5121A61CB9AA2B0BF8CEDB9ED56AF56F' +
    '66EA5998ECB8B8222A4B07F42BD928D9F8EBF7DCE61F1E66307DFFFC306457665443C034C22599CB45654628CE25BE6F' +
    'EB6264A15BFF06D636B0C55226F39AD64DA61B3D44D51BD98C5A66B0E9FA1DAC0D34DE9388A0D48EF2D62EE404D96E2B' +
    '1C0F671B974ED0F73D5C2A51D56B5C4A722ABB8616C933B40C2255241A28D3D3150B14551AB3A70A6941482C7C6E216E' +
    '0154CE1C950B18D14CCCF1A8558275B660CE42C7A7086E6AA0E311700D837DB324ED1E9E80E21C8B15C64C72994F40D3' +
    '0474F185CDA3D1ECA04A8DB902BE32673B13A3DB4208D6DD183D495564CF99859A2817CF9459C0F928A3F90A68478AFE' +
    '51F9760B9356F01E1B3DC5258DCDB1DF5B305DF34A59DA4D4DBEC8257763F22CB379421E055E6DD01D85905D185399CB' +
    'DC4D65763A79CAF0F870ABB2C84253A2A14DEA67B24E6A93851EF42C5C2D05AE9C1A7365C6832EE4FFDCE8221ACD4DBE' +
    '9F72CFC2F52D2C878823504720A74126CBF566CCE59B068C9E797FF1CC12624749FFA0CF381DA852D406B10F81859B73' +
    'CBF578EC0C6CF87F1F5AFC048E966801C6023E7F0000000049454E44AE426082',
    // 1 : Item2, delete
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000000734944415478DAD594E10AC0' +
    '200884F3FD1FFA5641309A775A1B83FC67E897DE518682F255D819306B690D003D918D4EAD0B1BC1A0ECD2C79A11504D' +
    '4F35BB4347633B53124803E629233D4337BD0969ED2F9331CD14D085A9D596DCCC68C45CDD8231205D33F3A4D206A49A' +
    'A74B0FF982DEC605CC3079EE93AD14300000000049454E44AE426082',
    // 2 : Item3, not used (same image as Item5)
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000000BF4944415478DAB594010EC2' +
    '200C457F8FB023E02DF4FED15BE8113C02FEC2984C082D0936591A3AFAFB563A24226295C97231516718F7895B6CB4B9' +
    '14B304CF626F2E3634BEBC378BCE90599FEC22ABBD6CE214FB379992007706AE92857596FA7443B24CF4647AC844A287' +
    'F1622CA02738243B4E91EBA8F19D4CD17A0026599340B288E010EB90A57663A7CA71DA83CF0D5364DFBE5582A9671768' +
    '2F95707ACEDA7F97879204CF63E29AB35E1FEB0225D77D6BD47624FF5C00EBEFB355F601F0D1C4EE9DB7422D00000000' +
    '49454E44AE426082',
    // 3 : Item4, not used (same image as Item6)
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000000A34944415478DACD93410E85' +
    '30084499A5B7D073BAF69C7A0B973835A9A916526ACCCF674353869781A65051F92AF0331852B911EC47139640BAB336' +
    'F0B85364E45313865168B9CBF725C8855D42C751CA182071D8AA820955CDBACFD00AD6B3AB2A97B0C8EB3D77967B6E30' +
    '6BA15E349D455D99BBB2609E33C842D1CCD342F57C07147DB13195B28D793C3B2E98FB9A6FC7349DF53C82356205EB75' +
    '18FA016FE37F61072109ABEE2DE8DE5E0000000049454E44AE426082',
    // 4 : Item5, preview
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000000BF4944415478DAB594010EC2' +
    '200C457F8FB023E02DF4FED15BE8113C02FEC2984C082D0936591A3AFAFB563A24226295C97231516718F7895B6CB4B9' +
    '14B304CF626F2E3634BEBC378BCE90599FEC22ABBD6CE214FB379992007706AE92857596FA7443B24CF4647AC844A287' +
    'F1622CA02738243B4E91EBA8F19D4CD17A0026599340B288E010EB90A57663A7CA71DA83CF0D5364DFBE5582A9671768' +
    '2F95707ACEDA7F97879204CF63E29AB35E1FEB0225D77D6BD47624FF5C00EBEFB355F601F0D1C4EE9DB7422D00000000' +
    '49454E44AE426082',
    // 5 : Item6, print
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000000A34944415478DACD93410E85' +
    '30084499A5B7D073BAF69C7A0B973835A9A916526ACCCF674353869781A65051F92AF0331852B911EC47139640BAB336' +
    'F0B85364E45313865168B9CBF725C8855D42C751CA182071D8AA820955CDBACFD00AD6B3AB2A97B0C8EB3D77967B6E30' +
    '6BA15E349D455D99BBB2609E33C842D1CCD342F57C07147DB13195B28D793C3B2E98FB9A6FC7349DF53C82356205EB75' +
    '18FA016FE37F61072109ABEE2DE8DE5E0000000049454E44AE426082',
    // 6 : Item7, parameters and rename
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000000A74944415478DAADD3511280' +
    '2008045038B97672B2C6C862179D26BE1AB5A720AA89C95FA10C535338D18675197364237F94277AACBFBF07EC841842' +
    'D0737DAD4D29EA5880DA8210684C66589F0C3591CD203A622B505A8A80E9BD1BC3684DDF69AE86A7FA8A4F58BA91A749' +
    '226B528C55D2EDD578ED408D29C620C7C0EDF393159C226AEE39D6C110048AD8D5D9ECD908879ED878DCA39792773816' +
    '3D60B0C84973F28BF9B16977349B94EEF92952890000000049454E44AE426082',
    // 7 : Item8, print setup
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000000B74944415478DAC5944B0E83' +
    '300C443DF768973925DD724ABA2BF730E30AA789089F04502D2407277E1EC506A8A8D41AC4929044BE14A00D66697C46' +
    'AE1F1680E172D8B2E28A19E8CD93C1CF1694794541CFFD2E56CEFC93FE932B8AF9B729BBF4CEFED2CDD5228B06349837' +
    'A100B3777653BA83FEB5053BA90CD2AB55F0AD5A659E37C3A03A1012B81C1868F0C6F8C16C4EE4786B751E0DC414E4CA' +
    '105A6E4C0AB04A659BB0339A22CE472305A67F825D2D49CEA59FD304877998F3A69F09180000000049454E44AE426082',
    // 8 : Item9, new group
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC0000008E4944415478DAEDD4D10EC0' +
    '100C05D0DE2FD77EB90D635A1363C9B287F54994439B004F9E660384B269DF8F32BF8CF93878091386921D570B49E732' +
    'A60EC958809CD3EB4550408C8AC0819D90392AE424CD3137A9EB9B25AC7764D5861A3EB0302EB7B79848BF92DC060063' +
    '2C40B66FB687B6E40146B72357F1630FB198304F69261A6C1554EF77E5D7E8C577B10D008B96F13CE618740000000049' +
    '454E44AE426082',
    // 9 : Item10, group node
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000000704944415478DAEDD34B0AC0' +
    '200C045073F29893A71890363F68AC8B163A5BF11907056EDC7605BE81510725636758C20684A8A724821228D809D97D' +
    '2C6094E8900B969DE73BCD26761851A973852A6C40B6B7A41D55C10403ECFE54F3163FF6109305F3952A71D82AE8DED9' +
    'AEBC173B00B0557FEE121A390F0000000049454E44AE426082',
    // 10 : Item11, report node
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000002AE4944415478DAAD542D78A3' +
    '40141CDCC381CBCA95D4252E91C89CCBB9565656B632B2F2E4C9B3AD3C19894C5D70875C491DEB58C7CDDB252DF5857C' +
    '1F902CF3E66F930198F00DC78429CBF43A4E139E8F01AEEB519A1C952DF0F30E381E3D7EFD069EEE05BD078C09B8BDBF' +
    'A0BB7894025CDE076C0E356EAD05724960D338A2730EC1774051007C51C4A0DA54D9DBB99B440210F8761130B880D7BF' +
    '2F58591319DD1D0EB0958564726536A26D3E290F3EC0905D1842BCAFF70482F00C383567749D2378C0E3F121EB2EED64' +
    'AB3524C70C4666C7E333F6F50FF8D04710E4CAAE404FC6F5BEC6E9D4E0F1E9217BFDF33A0D18B1B9B158AF771F04E42A' +
    '53C13C19F4434FBF2CCEED19372B8B31E4B482EACA02AE770417E4790E5D1FC8ACE433F292CEC827987A46AC7884EB24' +
    '9EF1817E855922966B661F493E0E916C21936A0818D25235FB7A8CCA4C2293C0FB48355EF93D6F0D838C80D94266D722' +
    '2E96322092EA13BF991EC608C2601862AF0111C9B32FEB5D01558B2F609DA7F18E4305A526CA53C7E704D96E2D9AD325' +
    '3E9746300C034C2861EB35AE23F191264B8BE0585A8E25E5C0C9325F4DB1426143EA5E8168810F1C7CE9206605B06FEA' +
    'E847358816C5348D4EF131D9823DF33DAFD4B0AB298D924CCB62EF2AD21EE00828D46C5872595643D36C5B8F7EFCC790' +
    '68349352A963AE80EFECD93E8AD1D7BCF731DD71742465C99EBFACBE78A6CC3C2E8D24F315D0A7C84B2ADF6E11A5153C' +
    '53D0735D420A277E9660BAE69DB2344D6DBEC8B553A95CEC2C4D0EC84781531BF40D266A8D4FAD5CEE0065763E3BCA70' +
    'B83DA8AC42B71F7493EBB569424C5243167A3070B0AD04A69C83596E7421FFB75617D168BEE486B9F71C5C1F107B8831' +
    '01F504325A64B25C6F522F170124CF9CBB7A161B92B60CBFD0969F4F5A7EB541E21F412C377FABD669DB45B0E97BFE68' +
    'E3F11F190881FD197751D30000000049454E44AE426082',
    // 11 : Item12, find
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000000714944415478DAE591510EC0' +
    '200843E9CD383A37732E198922AE59A2FEAC9FC53E0450A4C82A613B0CB7FDA8D6C17C0AAB1200032CF3CFFCAC0DB4C1' +
    '994F613E4A8465FE14967567EAD6E03007C5EE6626AA2A592D02CFC2BAD057D86C2FAC3EC0D8B5D8BB7DB0B7B3B7303A' +
    'E60AFD0476010AA497EE4011A9820000000049454E44AE426082',
    // 12 : Item13, export to folder
    '89504E470D0A1A0A0000000D4948445200000013000000130806000000725036CC000000704944415478DAEDD34B0AC0' +
    '200C045073F29893A71890363F68AC8B163A5BF11907056EDC7605BE81510725636758C20684A8A724821228D809D97D' +
    '2C6094E8900B969DE73BCD26761851A973852A6C40B6B7A41D55C10403ECFE54F3163FF6109305F3952A71D82AE8DED9' +
    'AEBC173B00B0557FEE121A390F0000000049454E44AE426082'
  );

function HexToStream(const AHex: string): TMemoryStream;
var
  i, n: Integer;
  b: Byte;
begin
  Result := TMemoryStream.Create;
  n := Length(AHex) div 2;
  for i := 0 to n - 1 do
  begin
    b := StrToInt('$' + Copy(AHex, i * 2 + 1, 2));
    Result.WriteBuffer(b, 1);
  end;
  Result.Position := 0;
end;

procedure LoadLibraryTreeImageList(AImageList: TImageList);
var
  i: Integer;
  ms: TMemoryStream;
  png: TPortableNetworkGraphic;
begin
  if not Assigned(AImageList) then
    Exit;
  AImageList.Clear;
  // 19x19 at 96 dpi, as the other designer icons (rpmdimageslcl)
  if (AImageList.Width <= 0) or (AImageList.Height <= 0) then
  begin
    AImageList.Width := 19;
    AImageList.Height := 19;
  end;
  ScaleImageListToScreen(AImageList);
  png := TPortableNetworkGraphic.Create;
  try
    for i := 0 to LIB_ICON_COUNT - 1 do
    begin
      ms := HexToStream(LIB_ICON_HEX[i]);
      try
        png.LoadFromStream(ms);
        AddPngToImageList(AImageList, png);
      finally
        ms.Free;
      end;
    end;
  finally
    png.Free;
  end;
end;

procedure RpLibraryCommit(dbitem: TRpDatabaseInfoItem);
begin
  if not Assigned(dbitem) then
    Exit;
  if (dbitem.Driver = rpfiredac) and Assigned(dbitem.SQLDBTransaction) and
    dbitem.SQLDBTransaction.Active then
    dbitem.SQLDBTransaction.Commit;
end;

procedure RpCheckLibraryDriver(dbitem: TRpDatabaseInfoItem);
var
  drivers: TStringList;
  drivername: string;
begin
  if not Assigned(dbitem) then
    Exit;
  if dbitem.Driver <> rpdbHttp then
    Exit;
  drivers := TStringList.Create;
  try
    GetRpDatabaseDrivers(drivers);
    drivername := '';
    if Integer(dbitem.Driver) < drivers.Count then
      drivername := drivers[Integer(dbitem.Driver)];
  finally
    drivers.Free;
  end;
  Raise Exception.Create(SRpDriverNotSupported + ' - ' + drivername);
end;

function RpLibraryFileName(const AName: string): string;
var
  i: Integer;
begin
  // VCL: / \ * -> '-' and '.' -> ' '; also the other characters Windows
  // does not accept in file names
  Result := AName;
  for i := 1 to Length(Result) do
  begin
    case Result[i] of
      '/', '\', '*', ':', '?', '"', '<', '>', '|':
        Result[i] := '-';
      '.':
        Result[i] := ' ';
    end;
  end;
  Result := Trim(Result);
  if Result = '' then
    Result := '-';
end;

// The parameters of OpenDatasetFromSQL: TRpParamObject objects
procedure AddParamValue(AParams: TStringList; const AName: string; const AValue: Variant);
var
  aparam: TRpParamObject;
begin
  aparam := TRpParamObject.Create;
  aparam.Value := AValue;
  AParams.AddObject(AName, aparam);
end;

procedure FreeParams(AParams: TStringList);
var
  i: Integer;
begin
  if not Assigned(AParams) then
    Exit;
  for i := 0 to AParams.Count - 1 do
    AParams.Objects[i].Free;
  AParams.Free;
end;

{ TFRpDBTreeLCL }

constructor TFRpDBTreeLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  FNodeInfos := TList.Create;
  BuildControls;
end;

destructor TFRpDBTreeLCL.Destroy;
begin
  TimerExpand.Enabled := False;
  ClearTree;
  FNodeInfos.Free;
  inherited Destroy;
end;

procedure TFRpDBTreeLCL.BuildControls;
var
  nextLeft: Integer;

  // Toolbar controls are laid out by their Left
  function NextPosition: Integer;
  begin
    Inc(nextLeft, 100);
    Result := nextLeft;
  end;

  function NewButton(AImage: Integer; const AHint: string; AClick: TNotifyEvent): TToolButton;
  begin
    Result := TToolButton.Create(Self);
    Result.Parent := BToolBar;
    Result.Left := NextPosition;
    Result.ImageIndex := AImage;
    Result.Hint := AHint;
    Result.ShowHint := True;
    Result.OnClick := AClick;
  end;

begin
  nextLeft := 0;
  ImageList := TImageList.Create(Self);
  ImageList.Width := 19;
  ImageList.Height := 19;
  LoadLibraryTreeImageList(ImageList);

  BToolBar := TToolBar.Create(Self);
  BToolBar.Parent := Self;
  BToolBar.Align := alTop;
  BToolBar.Height := Scale96ToScreen(30);
  BToolBar.ButtonWidth := Scale96ToScreen(26);
  BToolBar.ButtonHeight := Scale96ToScreen(26);
  BToolBar.Images := ImageList;
  BToolBar.Flat := True;
  BToolBar.ShowHint := True;

  // Same order as the VCL toolbar
  BNewGroup := NewButton(IMG_LIB_NEWGROUP, SRpNewFolder, ANewFolderExecute);
  BNewReport := NewButton(IMG_LIB_NEWREPORT, SRpNewReport, ANewExecute);
  BDelete := NewButton(IMG_LIB_DELETE, SRpDeleteSelection, ADeleteExecute);

  EFind := TEdit.Create(Self);
  EFind.Parent := BToolBar;
  EFind.Left := NextPosition;
  EFind.Width := Scale96ToScreen(93);
  EFind.Hint := SRpSearchReport;
  EFind.ShowHint := True;
  EFind.OnKeyDown := EFindKeyDown;

  BFind := NewButton(IMG_LIB_FIND, SRpSearchReport, AFindExecute);
  BPreview := NewButton(IMG_LIB_PREVIEW, TranslateStr(55, 'Preview the report in the screen'),
    APreviewExecute);
  BParams := NewButton(IMG_LIB_PARAMS, TranslateStr(136, 'Shows user parameter window'),
    AUserParamsExecute);
  BPrint := NewButton(IMG_LIB_PRINT, TranslateStr(53, 'Print the report, you can select pages to print'),
    APrintExecute);
  BPrintSetup := NewButton(IMG_LIB_PRINTSETUP, TranslateStr(57, 'Displays printer setup dialog'),
    APrintSetupExecute);
  BExport := NewButton(IMG_LIB_EXPORT, SRpExportFolderH, AExportFolderExecute);

  // Progress and cancel of the long operations (fixed width, it shows a
  // counter)
  BCancel := TButton.Create(Self);
  BCancel.Parent := BToolBar;
  BCancel.Left := NextPosition;
  BCancel.Width := Scale96ToScreen(90);
  BCancel.Height := Scale96ToScreen(26);
  BCancel.Caption := SRpCancel;
  BCancel.Visible := False;
  BCancel.OnClick := BCancelClick;

  MPopup := TPopupMenu.Create(Self);
  MPopup.Images := ImageList;
  MRename := TMenuItem.Create(MPopup);
  MRename.Caption := SRpRename;
  MRename.ImageIndex := IMG_LIB_PARAMS;
  MRename.OnClick := ARenameExecute;
  MPopup.Items.Add(MRename);

  ATree := TTreeView.Create(Self);
  ATree.Parent := Self;
  ATree.Align := alClient;
  ATree.ReadOnly := True;
  ATree.HideSelection := False;
  ATree.RightClickSelect := True;
  ATree.Images := ImageList;
  ATree.Indent := Scale96ToScreen(22);
  ATree.PopupMenu := MPopup;
  ATree.DragMode := dmAutomatic;
  // The LCL OnChange comes later from a timer; OnSelectionChanged at once
  ATree.OnSelectionChanged := ATreeSelectionChanged;
  ATree.OnDragOver := ATreeDragOver;
  ATree.OnDragDrop := ATreeDragDrop;
  ATree.OnEndDrag := ATreeEndDrag;

  // Expands a collapsed group after holding a dragged node over it
  TimerExpand := TTimer.Create(Self);
  TimerExpand.Enabled := False;
  TimerExpand.Interval := 100;
  TimerExpand.OnTimer := TimerExpandTimer;

  SelectDirDialog := TSelectDirectoryDialog.Create(Self);
  SelectDirDialog.Title := SRpExportFolder;
  SelectDirDialog.Options := SelectDirDialog.Options + [ofPathMustExist];

  UpdateActions;
end;

procedure TFRpDBTreeLCL.ClearTree;
var
  i: Integer;
begin
  ATree.Items.Clear;
  for i := 0 to FNodeInfos.Count - 1 do
    TObject(FNodeInfos[i]).Free;
  FNodeInfos.Clear;
  FCurrentLoaded := '';
end;

function TFRpDBTreeLCL.NewNodeInfo(ANode: TTreeNode; const AReportName: WideString;
  AGroupCode, AParentGroup: Integer): TRpLibNodeInfo;
begin
  Result := TRpLibNodeInfo.Create;
  FNodeInfos.Add(Result);
  Result.ReportName := AReportName;
  Result.GroupCode := AGroupCode;
  Result.ParentGroup := AParentGroup;
  Result.Node := ANode;
  ANode.Data := Result;
  if Length(AReportName) > 0 then
  begin
    ANode.ImageIndex := IMG_LIB_REPORT;
    ANode.SelectedIndex := IMG_LIB_REPORT;
  end
  else
  begin
    ANode.ImageIndex := IMG_LIB_GROUP;
    ANode.SelectedIndex := IMG_LIB_GROUP;
  end;
end;

procedure TFRpDBTreeLCL.FreeNodeInfos(ANode: TTreeNode);
var
  i: Integer;
begin
  // The data of a node and its branch, before freeing the node
  for i := 0 to ANode.Count - 1 do
    FreeNodeInfos(ANode.Items[i]);
  if Assigned(ANode.Data) then
  begin
    FNodeInfos.Remove(ANode.Data);
    TObject(ANode.Data).Free;
    ANode.Data := nil;
  end;
end;

function TFRpDBTreeLCL.NodeInfo(ANode: TTreeNode): TRpLibNodeInfo;
begin
  Result := nil;
  if Assigned(ANode) then
    Result := TRpLibNodeInfo(ANode.Data);
end;

function TFRpDBTreeLCL.GetRootNode: TTreeNode;
begin
  Result := ATree.Items.GetFirstNode;
end;

function TFRpDBTreeLCL.IndexOfGroup(ACode: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FGroupCodes) do
  begin
    if FGroupCodes[i] = ACode then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

procedure TFRpDBTreeLCL.AddReportNodes(AParentNode: TTreeNode; AGroupCode: Integer);
var
  names: TStringList;
  i: Integer;
  node: TTreeNode;
begin
  names := TStringList.Create;
  try
    for i := 0 to High(FReportNames) do
    begin
      if FReportGroups[i] = AGroupCode then
        names.Add(FReportNames[i]);
    end;
    names.Sort;
    for i := 0 to names.Count - 1 do
    begin
      node := ATree.Items.AddChild(AParentNode, names[i]);
      NewNodeInfo(node, names[i], AGroupCode, 0);
      CheckCancel(0);
    end;
  finally
    names.Free;
  end;
end;

procedure TFRpDBTreeLCL.AddGroupNodes(AParentNode: TTreeNode; AParentCode: Integer);
var
  i: Integer;
  node: TTreeNode;
begin
  for i := 0 to High(FGroupCodes) do
  begin
    if FGroupVisited[i] then
      Continue;
    if (FGroupParents[i] <> AParentCode) or (FGroupCodes[i] = AParentCode) then
      Continue;
    // A malformed hierarchy (cycles) must not recurse forever
    FGroupVisited[i] := True;
    node := ATree.Items.AddChild(AParentNode, FGroupNames[i]);
    NewNodeInfo(node, '', FGroupCodes[i], FGroupParents[i]);
    AddGroupNodes(node, FGroupCodes[i]);
    AddReportNodes(node, FGroupCodes[i]);
  end;
end;

procedure TFRpDBTreeLCL.GenerateTree(const ARootCaption: string);
var
  rootNode: TTreeNode;
  i: Integer;
begin
  SetLength(FGroupVisited, Length(FGroupCodes));
  for i := 0 to High(FGroupVisited) do
    FGroupVisited[i] := False;
  ATree.Items.BeginUpdate;
  try
    rootNode := ATree.Items.AddChild(nil, ARootCaption);
    NewNodeInfo(rootNode, '', 0, 0);
    // Top level groups (PARENT_GROUP=0) and reports without group
    AddGroupNodes(rootNode, 0);
    AddReportNodes(rootNode, 0);
  finally
    ATree.Items.EndUpdate;
  end;
  rootNode.Expand(False);
end;

procedure TFRpDBTreeLCL.BeginProgress;
begin
  FLastProgress := GetTickCount64;
  FDoCancel := False;
  FCounter := 0;
  BCancel.Caption := SRpCancel;
  BCancel.Visible := True;
end;

procedure TFRpDBTreeLCL.EndProgress;
begin
  BCancel.Visible := False;
end;

procedure TFRpDBTreeLCL.CheckCancel(ACount: Integer);
var
  nowTick: QWord;
begin
  nowTick := GetTickCount64;
  if nowTick - FLastProgress > PROGRESS_INTERVAL then
  begin
    FLastProgress := nowTick;
    FDoCancel := False;
    BCancel.Caption := FormatFloat('###,####', ACount) + '-' + SRpCancel;
    Application.ProcessMessages;
    if FDoCancel then
      Raise Exception.Create(SRpOperationAborted);
  end;
end;

procedure TFRpDBTreeLCL.EditTree(adbinfo: TRpDatabaseInfoItem; AReadOnly: Boolean);
var
  sqltext: string;
  adatareports, adatagroups: TDataSet;
  hasGroupTable: Boolean;
  groupField, nameField: TField;
  n, groupCode: Integer;
begin
  ClearTree;
  FDbInfo := adbinfo;
  FReadOnlyTree := AReadOnly;
  SetLength(FGroupCodes, 0);
  SetLength(FGroupNames, 0);
  SetLength(FGroupParents, 0);
  SetLength(FReportNames, 0);
  SetLength(FReportGroups, 0);
  UpdateActions;
  if not Assigned(adbinfo) then
    Exit;

  RpCheckLibraryDriver(adbinfo);
  adbinfo.Connect(nil);
  BeginProgress;
  try
    try
      hasGroupTable := HasGroups;
      sqltext := 'SELECT ' + adbinfo.ReportSearchField;
      // Do not read the report blobs
      if hasGroupTable then
        sqltext := sqltext + ',' + ReportGroupField + ' AS REPORT_GROUP';
      sqltext := sqltext + ' FROM ' + adbinfo.ReportTable;
      adatareports := adbinfo.OpenDatasetFromSQL(sqltext, nil, False, nil);
      try
        if hasGroupTable then
        begin
          adatagroups := adbinfo.OpenDatasetFromSQL('SELECT ' + GroupCodeField +
            ' AS GROUP_CODE,' + GroupNameField + ' AS GROUP_NAME,' + GroupParentField +
            ' AS PARENT_GROUP FROM ' + adbinfo.ReportGroupsTable, nil, False, nil);
          try
            n := 0;
            while not adatagroups.Eof do
            begin
              SetLength(FGroupCodes, n + 1);
              SetLength(FGroupNames, n + 1);
              SetLength(FGroupParents, n + 1);
              FGroupCodes[n] := adatagroups.FieldByName('GROUP_CODE').AsInteger;
              FGroupNames[n] := adatagroups.FieldByName('GROUP_NAME').AsString;
              FGroupParents[n] := adatagroups.FieldByName('PARENT_GROUP').AsInteger;
              if FGroupParents[n] < 0 then
                FGroupParents[n] := 0;
              Inc(n);
              CheckCancel(n);
              adatagroups.Next;
            end;
          finally
            adatagroups.Free;
          end;
        end;

        nameField := adatareports.FieldByName(adbinfo.ReportSearchField);
        groupField := nil;
        if hasGroupTable then
          groupField := adatareports.FindField('REPORT_GROUP');
        n := 0;
        while not adatareports.Eof do
        begin
          groupCode := 0;
          if Assigned(groupField) and (not groupField.IsNull) then
          begin
            groupCode := groupField.AsInteger;
            // Reports of unknown groups go to the root (VCL behaviour)
            if IndexOfGroup(groupCode) < 0 then
              groupCode := 0;
          end;
          SetLength(FReportNames, n + 1);
          SetLength(FReportGroups, n + 1);
          FReportNames[n] := nameField.AsString;
          FReportGroups[n] := groupCode;
          Inc(n);
          CheckCancel(n);
          adatareports.Next;
        end;
      finally
        adatareports.Free;
      end;
    finally
      // Releases the locks of the reads
      RpLibraryCommit(adbinfo);
    end;

    GenerateTree(adbinfo.Alias);
  finally
    EndProgress;
  end;
  UpdateActions;
end;

function TFRpDBTreeLCL.SelectedReportName: WideString;
var
  info: TRpLibNodeInfo;
begin
  Result := '';
  info := NodeInfo(ATree.Selected);
  if Assigned(info) then
    Result := info.ReportName;
end;

function TFRpDBTreeLCL.GroupNodeOf(ANode: TTreeNode): TTreeNode;
begin
  Result := ANode;
  if Assigned(Result) and Assigned(Result.Data) and
    (Length(TRpLibNodeInfo(Result.Data).ReportName) > 0) then
    Result := Result.Parent;
  if not Assigned(Result) then
    Result := GetRootNode;
end;

function TFRpDBTreeLCL.FindGroupNode(AGroupCode: Integer): TTreeNode;
var
  i: Integer;
  info: TRpLibNodeInfo;
begin
  Result := nil;
  for i := 0 to FNodeInfos.Count - 1 do
  begin
    info := TRpLibNodeInfo(FNodeInfos[i]);
    if (Length(info.ReportName) = 0) and (info.GroupCode = AGroupCode) then
    begin
      Result := info.Node;
      Exit;
    end;
  end;
end;

function TFRpDBTreeLCL.FindReportNode(const AReportName: WideString): TTreeNode;
var
  i: Integer;
  info: TRpLibNodeInfo;
begin
  Result := nil;
  for i := 0 to FNodeInfos.Count - 1 do
  begin
    info := TRpLibNodeInfo(FNodeInfos[i]);
    if (Length(info.ReportName) > 0) and (info.ReportName = AReportName) then
    begin
      Result := info.Node;
      Exit;
    end;
  end;
end;

procedure TFRpDBTreeLCL.UpdateActions;
var
  info: TRpLibNodeInfo;
  editable, isReport, isRoot: Boolean;
begin
  info := NodeInfo(ATree.Selected);
  editable := Assigned(FDbInfo) and (not FReadOnlyTree);
  isReport := Assigned(info) and (Length(info.ReportName) > 0);
  isRoot := Assigned(ATree.Selected) and (ATree.Selected = GetRootNode);
  BNewReport.Enabled := editable;
  // A library without groups table has no groups
  BNewGroup.Enabled := editable and HasGroups;
  BDelete.Enabled := editable and Assigned(info) and (not isRoot);
  MRename.Enabled := editable and Assigned(info) and (not isRoot);
  BExport.Enabled := editable;
  BPreview.Enabled := isReport;
  BPrint.Enabled := isReport;
  BParams.Enabled := isReport;
  BFind.Enabled := Assigned(FDbInfo);
  if editable then
    ATree.DragMode := dmAutomatic
  else
    ATree.DragMode := dmManual;
end;

procedure TFRpDBTreeLCL.CheckEditable;
begin
  if not Assigned(FDbInfo) then
    Raise Exception.Create(SRPDabaseAliasNotFound);
  if FReadOnlyTree then
    Raise Exception.Create(SRpSFeaturenotsup);
end;

function TFRpDBTreeLCL.HasGroups: Boolean;
begin
  Result := Assigned(FDbInfo) and (Length(FDbInfo.ReportGroupsTable) > 0);
end;

// The GINFORME groups table has Spanish column names (VCL)
function TFRpDBTreeLCL.IsGInforme: Boolean;
begin
  Result := Assigned(FDbInfo) and (FDbInfo.ReportGroupsTable = 'GINFORME');
end;

function TFRpDBTreeLCL.GroupCodeField: string;
begin
  if IsGInforme then
    Result := 'CODIGO'
  else
    Result := 'GROUP_CODE';
end;

function TFRpDBTreeLCL.GroupNameField: string;
begin
  if IsGInforme then
    Result := 'NOMBRE'
  else
    Result := 'GROUP_NAME';
end;

function TFRpDBTreeLCL.GroupParentField: string;
begin
  if IsGInforme then
    Result := 'GRUPO'
  else
    Result := 'PARENT_GROUP';
end;

function TFRpDBTreeLCL.ReportGroupField: string;
begin
  if IsGInforme then
    Result := 'GRUPO'
  else
    Result := 'REPORT_GROUP';
end;

procedure TFRpDBTreeLCL.ExecLibrarySQL(const ASQL: string; AParams: TStringList);
begin
  FDbInfo.OpenDatasetFromSQL(ASQL, AParams, True, nil);
  RpLibraryCommit(FDbInfo);
end;

function TFRpDBTreeLCL.ReportExists(const AReportName: WideString): Boolean;
var
  params: TStringList;
  adata: TDataSet;
begin
  params := TStringList.Create;
  try
    AddParamValue(params, 'REPNAME', String(AReportName));
    adata := FDbInfo.OpenDatasetFromSQL('SELECT ' + FDbInfo.ReportSearchField +
      ' FROM ' + FDbInfo.ReportTable + ' WHERE ' + FDbInfo.ReportSearchField + '=:REPNAME',
      params, False, nil);
    try
      Result := not (adata.Eof and adata.Bof);
    finally
      adata.Free;
    end;
  finally
    FreeParams(params);
    RpLibraryCommit(FDbInfo);
  end;
end;

function TFRpDBTreeLCL.NewReport(const AReportName: WideString): TTreeNode;
var
  groupNode: TTreeNode;
  groupcode: Integer;
  astring: string;
  params: TStringList;
  areport: TRpReport;
  aparam: TRpParamObject;
  blob: TMemoryStream;
begin
  Result := nil;
  CheckEditable;
  if Length(AReportName) < 1 then
    Exit;
  // Inside the selected group, or the group of the selected report (the VCL
  // adds the node under the report node)
  groupNode := GroupNodeOf(ATree.Selected);
  groupcode := NodeInfo(groupNode).GroupCode;
  if ReportExists(AReportName) then
    Raise Exception.Create(TranslateStr(1820, SLibReportExistsDefault) + ': ' + AReportName);

  astring := 'INSERT INTO ' + FDbInfo.ReportTable + ' (' +
    FDbInfo.ReportSearchField + ',' + FDbInfo.ReportField;
  if HasGroups then
  begin
    if IsGInforme then
      astring := astring + ',GRUPO,DEF_USUARIO'
    else
      astring := astring + ',REPORT_GROUP';
  end;
  astring := astring + ') VALUES (:REPNAME,:REPORT';
  if HasGroups then
  begin
    if IsGInforme then
      astring := astring + ',' + IntToStr(groupcode) + ',0'
    else
      astring := astring + ',' + IntToStr(groupcode);
  end;
  astring := astring + ')';

  params := TStringList.Create;
  blob := TMemoryStream.Create;
  areport := TRpReport.Create(nil);
  try
    AddParamValue(params, 'REPNAME', String(AReportName));
    // A new empty report
    areport.CreateNew;
    areport.SaveToStream(blob);
    blob.Seek(0, soFromBeginning);
    aparam := TRpParamObject.Create;
    aparam.Value := Null;
    aparam.Stream := blob;
    params.AddObject('REPORT', aparam);
    ExecLibrarySQL(astring, params);
  finally
    areport.Free;
    blob.Free;
    FreeParams(params);
  end;

  Result := ATree.Items.AddChild(groupNode, AReportName);
  NewNodeInfo(Result, AReportName, groupcode, 0);
  groupNode.Expand(False);
  ATree.Selected := Result;
  UpdateActions;
end;

function TFRpDBTreeLCL.NewGroup(const AGroupName: WideString): TTreeNode;
var
  groupNode: TTreeNode;
  groupcode, newgroup: Integer;
  astring: string;
  adata: TDataSet;
  params: TStringList;
begin
  Result := nil;
  CheckEditable;
  if Length(AGroupName) < 1 then
    Exit;
  if not HasGroups then
    Raise Exception.Create(SRpSFeaturenotsup);
  groupNode := GroupNodeOf(ATree.Selected);
  groupcode := NodeInfo(groupNode).GroupCode;

  // The next group code
  adata := FDbInfo.OpenDatasetFromSQL('SELECT MAX(' + GroupCodeField + ') AS GCODE FROM ' +
    FDbInfo.ReportGroupsTable, nil, False, nil);
  try
    if (adata.Eof and adata.Bof) or adata.FieldByName('GCODE').IsNull then
      newgroup := 1
    else
      newgroup := adata.FieldByName('GCODE').AsInteger + 1;
  finally
    adata.Free;
  end;

  params := TStringList.Create;
  try
    AddParamValue(params, 'GROUPNAME', String(AGroupName));
    astring := 'INSERT INTO ' + FDbInfo.ReportGroupsTable + ' (' + GroupCodeField + ',' +
      GroupNameField + ',' + GroupParentField + ') VALUES (' + IntToStr(newgroup) +
      ',:GROUPNAME,' + IntToStr(groupcode) + ')';
    ExecLibrarySQL(astring, params);
  finally
    FreeParams(params);
  end;

  Result := ATree.Items.AddChild(groupNode, AGroupName);
  NewNodeInfo(Result, '', newgroup, groupcode);
  groupNode.Expand(False);
  ATree.Selected := Result;
  UpdateActions;
end;

procedure TFRpDBTreeLCL.DeleteNode(ANode: TTreeNode);
var
  info: TRpLibNodeInfo;
  params: TStringList;
  adata: TDataSet;
begin
  CheckEditable;
  info := NodeInfo(ANode);
  // The root is the library itself
  if not Assigned(info) or (ANode = GetRootNode) then
    Exit;
  if Length(info.ReportName) > 0 then
  begin
    // A report can always be deleted
    params := TStringList.Create;
    try
      AddParamValue(params, 'REPNAME', String(info.ReportName));
      ExecLibrarySQL('DELETE FROM ' + FDbInfo.ReportTable + ' WHERE ' +
        FDbInfo.ReportSearchField + '=:REPNAME', params);
    finally
      FreeParams(params);
    end;
    if info.ReportName = FCurrentLoaded then
      FCurrentLoaded := '';
  end
  else
  begin
    // A group can not have reports or groups inside
    adata := FDbInfo.OpenDatasetFromSQL('SELECT COUNT(' + ReportGroupField + ') AS COUNTG FROM ' +
      FDbInfo.ReportTable + ' WHERE ' + ReportGroupField + '=' + IntToStr(info.GroupCode),
      nil, False, nil);
    try
      if adata.FieldByName('COUNTG').AsInteger > 0 then
        Raise Exception.Create(SRpExistReportInThisGroup);
    finally
      adata.Free;
      RpLibraryCommit(FDbInfo);
    end;
    adata := FDbInfo.OpenDatasetFromSQL('SELECT COUNT(' + GroupCodeField + ') AS COUNTG FROM ' +
      FDbInfo.ReportGroupsTable + ' WHERE ' + GroupParentField + '=' + IntToStr(info.GroupCode),
      nil, False, nil);
    try
      if adata.FieldByName('COUNTG').AsInteger > 0 then
        Raise Exception.Create(SRpGroupParent);
    finally
      adata.Free;
      RpLibraryCommit(FDbInfo);
    end;
    ExecLibrarySQL('DELETE FROM ' + FDbInfo.ReportGroupsTable + ' WHERE ' + GroupCodeField +
      '=' + IntToStr(info.GroupCode), nil);
  end;
  FreeNodeInfos(ANode);
  ANode.Free;
  UpdateActions;
end;

procedure TFRpDBTreeLCL.RenameNode(ANode: TTreeNode; const ANewName: WideString);
var
  info: TRpLibNodeInfo;
  params: TStringList;
begin
  CheckEditable;
  info := NodeInfo(ANode);
  if not Assigned(info) or (ANode = GetRootNode) then
    Exit;
  if Length(ANewName) < 1 then
    Exit;
  params := TStringList.Create;
  try
    if Length(info.ReportName) < 1 then
    begin
      // Rename group
      if ANode.Text = ANewName then
        Exit;
      AddParamValue(params, 'GROUPNAME', String(ANewName));
      AddParamValue(params, 'GROUPCODE', info.GroupCode);
      ExecLibrarySQL('UPDATE ' + FDbInfo.ReportGroupsTable + ' SET ' + GroupNameField +
        '=:GROUPNAME WHERE ' + GroupCodeField + '=:GROUPCODE', params);
      ANode.Text := ANewName;
    end
    else
    begin
      // Rename report
      if info.ReportName = ANewName then
        Exit;
      if ReportExists(ANewName) then
        Raise Exception.Create(TranslateStr(1820, SLibReportExistsDefault) + ': ' + ANewName);
      AddParamValue(params, 'REPNAME', String(ANewName));
      AddParamValue(params, 'OLDREPNAME', String(info.ReportName));
      ExecLibrarySQL('UPDATE ' + FDbInfo.ReportTable + ' SET ' +
        FDbInfo.ReportSearchField + '=:REPNAME WHERE ' +
        FDbInfo.ReportSearchField + '=:OLDREPNAME', params);
      if info.ReportName = FCurrentLoaded then
        FCurrentLoaded := '';
      ANode.Text := ANewName;
      info.ReportName := ANewName;
    end;
  finally
    FreeParams(params);
  end;
end;

function TFRpDBTreeLCL.CanMoveNode(ASource, ADest: TTreeNode): Boolean;
var
  infosource: TRpLibNodeInfo;
  target: TTreeNode;
begin
  Result := False;
  if FReadOnlyTree or not Assigned(FDbInfo) then
    Exit;
  if not Assigned(ASource) or not Assigned(ADest) or (ASource = ADest) then
    Exit;
  if (ASource = GetRootNode) or not Assigned(ASource.Data) or not Assigned(ADest.Data) then
    Exit;
  infosource := NodeInfo(ASource);
  target := GroupNodeOf(ADest);
  if not Assigned(target) then
    Exit;
  if Length(infosource.ReportName) > 0 then
    // A report to another group
    Result := NodeInfo(target).GroupCode <> infosource.GroupCode
  else
  begin
    // A group to another parent, never inside itself or its branch
    if (target = ASource) or target.HasAsParent(ASource) then
      Exit;
    Result := NodeInfo(target).GroupCode <> infosource.ParentGroup;
  end;
end;

procedure TFRpDBTreeLCL.MoveNode(ASource, ADest: TTreeNode);
var
  infosource: TRpLibNodeInfo;
  target: TTreeNode;
  targetcode: Integer;
  params: TStringList;
begin
  CheckEditable;
  if not CanMoveNode(ASource, ADest) then
    Exit;
  infosource := NodeInfo(ASource);
  target := GroupNodeOf(ADest);
  targetcode := NodeInfo(target).GroupCode;
  params := TStringList.Create;
  try
    AddParamValue(params, 'GROUP', targetcode);
    if Length(infosource.ReportName) < 1 then
    begin
      AddParamValue(params, 'GROUPCODE', infosource.GroupCode);
      ExecLibrarySQL('UPDATE ' + FDbInfo.ReportGroupsTable + ' SET ' + GroupParentField +
        '=:GROUP WHERE ' + GroupCodeField + '=:GROUPCODE', params);
      infosource.ParentGroup := targetcode;
      ASource.MoveTo(target, naAddChildFirst);
    end
    else
    begin
      // The VCL uses REPORT_NAME (NOMBRE) instead of the search field
      AddParamValue(params, 'REPNAME', String(infosource.ReportName));
      ExecLibrarySQL('UPDATE ' + FDbInfo.ReportTable + ' SET ' + ReportGroupField +
        '=:GROUP WHERE ' + FDbInfo.ReportSearchField + '=:REPNAME', params);
      infosource.GroupCode := targetcode;
      ASource.MoveTo(target, naAddChild);
    end;
  finally
    FreeParams(params);
  end;
  ATree.Selected := ASource;
end;

procedure TFRpDBTreeLCL.FindNext(const AText: string);
var
  curnode: TTreeNode;
  i: Integer;
  dofirst: Boolean;
  utext: string;
begin
  // Port of FindDialog1Find: from the node after the selected one
  dofirst := False;
  curnode := ATree.Selected;
  if not Assigned(curnode) then
  begin
    dofirst := True;
    curnode := ATree.Items.GetFirstNode;
  end;
  if not Assigned(curnode) then
    Raise Exception.Create(SRptReportnotfound);
  i := 0;
  if not dofirst then
  begin
    while i < ATree.Items.Count do
    begin
      if ATree.Items[i] = curnode then
      begin
        Inc(i);
        Break;
      end;
      Inc(i);
    end;
  end;
  utext := UTF8UpperCase(AText);
  while i < ATree.Items.Count do
  begin
    if Pos(utext, UTF8UpperCase(ATree.Items[i].Text)) > 0 then
    begin
      ATree.Selected := ATree.Items[i];
      ATree.Selected.MakeVisible;
      Exit;
    end;
    Inc(i);
  end;
  Raise Exception.Create(SRptReportnotfound);
end;

procedure TFRpDBTreeLCL.SaveReportFile(const ADir: string; AInfo: TRpLibNodeInfo);
var
  memstream: TStream;
  fstream: TFileStream;
begin
  memstream := FDbInfo.GetReportStream(AInfo.ReportName, nil);
  try
    RpLibraryCommit(FDbInfo);
    memstream.Seek(0, soFromBeginning);
    fstream := TFileStream.Create(IncludeTrailingPathDelimiter(ADir) +
      RpLibraryFileName(AInfo.ReportName) + '.rep', fmCreate);
    try
      fstream.CopyFrom(memstream, memstream.Size);
    finally
      fstream.Free;
    end;
  finally
    memstream.Free;
  end;
end;

procedure TFRpDBTreeLCL.SaveGroupDir(const ADir: string; ANode: TTreeNode);
var
  i: Integer;
  child: TTreeNode;
  info: TRpLibNodeInfo;
  newdir: string;
begin
  // Port of SaveDir: a folder for every group, a file for every report
  for i := 0 to ANode.Count - 1 do
  begin
    child := ANode.Items[i];
    info := NodeInfo(child);
    if not Assigned(info) then
      Continue;
    if Length(info.ReportName) < 1 then
    begin
      newdir := IncludeTrailingPathDelimiter(ADir) + RpLibraryFileName(child.Text);
      if not DirectoryExists(newdir) then
        if not CreateDir(newdir) then
          Raise Exception.Create(SRpDirCantBeCreated + ': ' + newdir);
      SaveGroupDir(newdir, child);
    end
    else
      SaveReportFile(ADir, info);
    Inc(FCounter);
    CheckCancel(FCounter);
  end;
end;

procedure TFRpDBTreeLCL.ExportToFolder(const ADir: string);
var
  root: TTreeNode;
begin
  if not Assigned(FDbInfo) then
    Raise Exception.Create(SRPDabaseAliasNotFound);
  if not DirectoryExists(ADir) then
    Raise Exception.Create(SrpDirectoryNotExists + ' ' + ADir);
  root := GetRootNode;
  if not Assigned(root) then
    Exit;
  BeginProgress;
  try
    // The groups and reports of the root go to the folder itself (in the
    // VCL the root caption is empty)
    SaveGroupDir(ExcludeTrailingPathDelimiter(ADir), root);
  finally
    EndProgress;
  end;
end;

procedure TFRpDBTreeLCL.LoadSelectedReport;
var
  info: TRpLibNodeInfo;
  memstream: TStream;
begin
  if not Assigned(FReport) then
    FReport := TLCLReport.Create(Self);
  info := NodeInfo(ATree.Selected);
  if not Assigned(info) or (Length(info.ReportName) < 1) or not Assigned(FDbInfo) then
    Raise Exception.Create(SRptReportnotfound);
  if (FCurrentLoaded = info.ReportName) and Assigned(FReport.Report) then
    Exit;
  FCurrentLoaded := '';
  memstream := FDbInfo.GetReportStream(info.ReportName, nil);
  try
    RpLibraryCommit(FDbInfo);
    memstream.Seek(0, soFromBeginning);
    FReport.LoadFromStream(memstream);
    FCurrentLoaded := info.ReportName;
  finally
    memstream.Free;
  end;
end;

{ Handlers }

procedure TFRpDBTreeLCL.ANewExecute(Sender: TObject);
var
  reportname: WideString;
begin
  CheckEditable;
  // Ask the user for the new report name
  reportname := RpInputBox(SRpNewReport, SRpReportName, '');
  if Length(reportname) < 1 then
    Exit;
  NewReport(reportname);
end;

procedure TFRpDBTreeLCL.ANewFolderExecute(Sender: TObject);
var
  groupname: WideString;
begin
  CheckEditable;
  // Ask for the new group name
  groupname := RpInputBox(SRpNewGroup, SRpSGroupName, '');
  if Length(groupname) < 1 then
    Exit;
  NewGroup(groupname);
end;

procedure TFRpDBTreeLCL.ADeleteExecute(Sender: TObject);
begin
  CheckEditable;
  if not Assigned(ATree.Selected) or (ATree.Selected = GetRootNode) then
    Exit;
  if smbYes <> RpMessageBox(SRpSureDeleteSection, SRpWarning, [smbYes, smbCancel],
    smsWarning, smbYes) then
    Exit;
  DeleteNode(ATree.Selected);
end;

procedure TFRpDBTreeLCL.ARenameExecute(Sender: TObject);
var
  node: TTreeNode;
  info: TRpLibNodeInfo;
  newname: WideString;
begin
  CheckEditable;
  node := ATree.Selected;
  info := NodeInfo(node);
  if not Assigned(info) or (node = GetRootNode) then
    Exit;
  if Length(info.ReportName) < 1 then
    newname := RpInputBox(SRpRename, SRpSGroupName, node.Text)
  else
    newname := RpInputBox(SRpRename, SRpReportName, info.ReportName);
  if Length(newname) < 1 then
    Exit;
  RenameNode(node, newname);
end;

procedure TFRpDBTreeLCL.AFindExecute(Sender: TObject);
begin
  FindNext(EFind.Text);
end;

procedure TFRpDBTreeLCL.EFindKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  // Enter searches the next one
  if Key = 13 then
  begin
    Key := 0;
    FindNext(EFind.Text);
  end;
end;

procedure TFRpDBTreeLCL.APreviewExecute(Sender: TObject);
begin
  LoadSelectedReport;
  FReport.Preview := True;
  FReport.Execute;
end;

procedure TFRpDBTreeLCL.APrintExecute(Sender: TObject);
begin
  LoadSelectedReport;
  FReport.Preview := False;
  FReport.Execute;
end;

procedure TFRpDBTreeLCL.AUserParamsExecute(Sender: TObject);
begin
  LoadSelectedReport;
  FReport.ShowParams;
end;

procedure TFRpDBTreeLCL.APrintSetupExecute(Sender: TObject);
begin
  if not Assigned(FReport) then
    FReport := TLCLReport.Create(Self);
  FReport.PrinterSetup;
end;

procedure TFRpDBTreeLCL.AExportFolderExecute(Sender: TObject);
begin
  CheckEditable;
  // Exports the library reports to files and folders
  if not SelectDirDialog.Execute then
    Exit;
  if Length(SelectDirDialog.FileName) < 1 then
    Exit;
  ExportToFolder(SelectDirDialog.FileName);
end;

procedure TFRpDBTreeLCL.BCancelClick(Sender: TObject);
begin
  FDoCancel := True;
end;

procedure TFRpDBTreeLCL.ATreeSelectionChanged(Sender: TObject);
begin
  UpdateActions;
end;

function TreeDragSource(ATree: TTreeView; Source: TObject): Boolean;
begin
  // The LCL passes the control of the automatic drag objects
  Result := (Source = ATree) or ((Source is TDragControlObject) and
    (TDragControlObject(Source).Control = ATree));
end;

procedure TFRpDBTreeLCL.ATreeDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
var
  nodedest: TTreeNode;
begin
  Accept := False;
  if not TreeDragSource(ATree, Source) then
    Exit;
  nodedest := ATree.GetNodeAt(X, Y);
  if not Assigned(nodedest) then
    Exit;
  // Holding the node over a collapsed group expands it
  if (not nodedest.Expanded) and (nodedest.Count > 0) and (nodedest <> FExpandTarget) then
  begin
    FExpandCount := 10;
    FExpandTarget := nodedest;
    TimerExpand.Enabled := True;
  end;
  Accept := CanMoveNode(ATree.Selected, nodedest);
end;

procedure TFRpDBTreeLCL.ATreeDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  nodedest: TTreeNode;
begin
  TimerExpand.Enabled := False;
  FExpandTarget := nil;
  if not TreeDragSource(ATree, Source) then
    Exit;
  nodedest := ATree.GetNodeAt(X, Y);
  if not Assigned(nodedest) then
    Exit;
  MoveNode(ATree.Selected, nodedest);
end;

procedure TFRpDBTreeLCL.ATreeEndDrag(Sender, Target: TObject; X, Y: Integer);
begin
  TimerExpand.Enabled := False;
  FExpandTarget := nil;
end;

procedure TFRpDBTreeLCL.TimerExpandTimer(Sender: TObject);
var
  p: TPoint;
  target: TTreeNode;
begin
  p := ATree.ScreenToClient(Mouse.CursorPos);
  target := ATree.GetNodeAt(p.X, p.Y);
  if (target = nil) or (target <> FExpandTarget) then
  begin
    TimerExpand.Enabled := False;
    FExpandTarget := nil;
    Exit;
  end;
  Dec(FExpandCount);
  if FExpandCount < 0 then
  begin
    target.Expand(False);
    TimerExpand.Enabled := False;
  end;
end;

end.
