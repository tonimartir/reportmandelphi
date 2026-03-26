{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       Rpmdfdinfovcl                                   }
{                                                       }
{       Copyright (c) 1994-2019 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{                                                       }
{*******************************************************}
unit rpmdfdinfovcl;

interface

{$I rpconf.inc}

uses
 windows,Classes,sysutils,Dialogs,Controls,Graphics,Forms,rpmdconsts,
 types,variants,
 rptypes,rpdatainfo,rpreport,rpmdundocue,
 rpmdfdatasetsvcl,rpmdfconnectionvcl,
 StdCtrls, ExtCtrls, ComCtrls;

type
  TFRpDInfoVCL = class(TForm)
    PBottom: TPanel;
    BOk: TButton;
    BCancel: TButton;
    PControl: TPageControl;
    TabConnections: TTabSheet;
    TabDatasets: TTabSheet;
    procedure FormCreate(Sender: TObject);
    procedure PControlChange(Sender: TObject);
    procedure BOkClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    freport:TRpReport;
    fdatasets:TFRpDatasetsVCL;
    fconnections:TFRpConnectionVCL;
    origDatabaseInfo:TRpDatabaseInfoList;
    origDataInfo:TRpDataInfoList;
    procedure SetReport(value:TRpReport);
    procedure RecordUndoChanges;
  public
    { Public declarations }
    property report:TRpReport read FReport write SetReport;
  end;


procedure ShowDataConfig(report:TRpReport);


implementation

uses rpdbxconfigvcl, rpbasereport, rpxmlstream;


{$R *.dfm}

procedure TFRpDInfoVCL.SetReport(value:TRpReport);
begin
 freport:=value;
 // Snapshot originals for undo comparison
 origDatabaseInfo:=TRpDatabaseInfoList.Create(nil);
 origDatabaseInfo.Assign(value.DatabaseInfo);
 origDataInfo:=TRpDataInfoList.Create(nil);
 origDataInfo.Assign(value.DataInfo);
 fconnections:=TFRpConnectionVCL.Create(Self);
 fconnections.Parent:=TabConnections;
 fdatasets:=TFRpDatasetsVCL.Create(Self);
 fdatasets.Parent:=TabDatasets;
 fdatasets.Datainfo:=report.DataInfo;
 fdatasets.Databaseinfo:=report.DatabaseInfo;
 fconnections.Databaseinfo:=report.DatabaseInfo;
 fconnections.Params:=report.Params;
 fdatasets.params:=report.params;
 if report.DatabaseInfo.Count>0 then
  PControl.ActivePage:=TabDatasets
 else
  PControl.ActivePage:=TabConnections;
 //fconnections.Align := alClient;
 fdatasets.Align := alClient;
end;

procedure ShowDataConfig(report:TRpReport);
var
 dia:TFRpDInfoVCL;
begin
// UpdateConAdmin;

 dia:=TFRpDInfoVCL.Create(Application);
 try
  dia.report:=report;
  dia.showmodal;
 finally
  dia.free;
 end;
end;



procedure TFRpDInfoVCL.FormCreate(Sender: TObject);
begin
 BOK.Caption:=TranslateStr(93,BOK.Caption);
 BCancel.Caption:=TranslateStr(94,BCancel.Caption);
 Caption:=TranslateStr(1097,Caption);
 TabConnections.Caption:=TranslateStr(142,TabConnections.Caption);
 TabDatasets.Caption:=TranslateStr(148,TabDatasets.Caption);
end;

procedure TFRpDInfoVCL.FormDestroy(Sender: TObject);
begin
 FreeAndNil(origDatabaseInfo);
 FreeAndNil(origDataInfo);
end;

procedure TFRpDInfoVCL.PControlChange(Sender: TObject);
begin
 fdatasets.Databaseinfo:=fconnections.DatabaseInfo;
 fconnections.Params:=fdatasets.Params;
end;

procedure TFRpDInfoVCL.RecordUndoChanges;
var
 undoCue:TUndoCue;
 groupId:integer;
 i:integer;
 origDB,newDB:TRpDatabaseInfoItem;
 origDS,newDS:TRpDataInfoItem;
 newDBInfo:TRpDatabaseInfoList;
 newDataInfo:TRpDataInfoList;
 op:TChangeObjectOperation;
begin
 if not Assigned(freport) or not Assigned(freport.UndoCue) then
  exit;
 undoCue:=TUndoCue(freport.UndoCue);
 groupId:=undoCue.GetGroupId;
 newDBInfo:=fconnections.DatabaseInfo;
 newDataInfo:=fdatasets.DataInfo;
 // DatabaseInfo changes
 for i:=0 to origDatabaseInfo.Count-1 do
 begin
  origDB:=origDatabaseInfo.Items[i];
  if newDBInfo.ItemByName(origDB.Name)=nil then
  begin
   op:=TChangeObjectOperation.Create(otRemove,groupId);
   op.componentName:=origDB.Name;
   op.componentClass:='TRPDATABASEINFOITEM';
   op.oldItemIndex:=i;
  op.AddProperty('alias',ptString,origDB.Alias,Null);
  op.AddProperty('driver',ptInteger,Integer(origDB.Driver),Null);
  op.AddProperty('configFile',ptString,origDB.ConfigFile,Null);
  op.AddProperty('loginPrompt',ptBoolean,origDB.LoginPrompt,Null);
  op.AddProperty('loadParams',ptBoolean,origDB.LoadParams,Null);
  op.AddProperty('loadDriverParams',ptBoolean,origDB.LoadDriverParams,Null);
  op.AddProperty('connectionString',ptString,origDB.ADOConnectionString,Null);
  op.AddProperty('providerFactory',ptString,origDB.ProviderFactory,Null);
  op.AddProperty('dotNetDriver',ptInteger,origDB.DotNetDriver,Null);
   undoCue.AddOperation(op);
  end;
 end;
 for i:=0 to newDBInfo.Count-1 do
 begin
  newDB:=newDBInfo.Items[i];
  if origDatabaseInfo.ItemByName(newDB.Name)=nil then
  begin
   op:=TChangeObjectOperation.Create(otAdd,groupId);
   op.componentName:=newDB.Name;
   op.componentClass:='TRPDATABASEINFOITEM';
   op.oldItemIndex:=i;
  op.AddProperty('alias',ptString,Null,newDB.Alias);
  op.AddProperty('driver',ptInteger,Null,Integer(newDB.Driver));
  op.AddProperty('configFile',ptString,Null,newDB.ConfigFile);
  op.AddProperty('loginPrompt',ptBoolean,Null,newDB.LoginPrompt);
  op.AddProperty('loadParams',ptBoolean,Null,newDB.LoadParams);
  op.AddProperty('loadDriverParams',ptBoolean,Null,newDB.LoadDriverParams);
  op.AddProperty('connectionString',ptString,Null,newDB.ADOConnectionString);
  op.AddProperty('providerFactory',ptString,Null,newDB.ProviderFactory);
  op.AddProperty('dotNetDriver',ptInteger,Null,newDB.DotNetDriver);
   undoCue.AddOperation(op);
  end;
 end;
 for i:=0 to newDBInfo.Count-1 do
 begin
  newDB:=newDBInfo.Items[i];
  origDB:=origDatabaseInfo.ItemByName(newDB.Name);
  if Assigned(origDB) then
  begin
   op:=TChangeObjectOperation.Create(otModify,groupId);
   op.componentName:=newDB.Name;
   op.componentClass:='TRPDATABASEINFOITEM';
   if origDB.Alias<>newDB.Alias then
    op.AddProperty('alias',ptString,origDB.Alias,newDB.Alias);
   if Integer(origDB.Driver)<>Integer(newDB.Driver) then
    op.AddProperty('driver',ptInteger,Integer(origDB.Driver),Integer(newDB.Driver));
   if origDB.ConfigFile<>newDB.ConfigFile then
    op.AddProperty('configFile',ptString,origDB.ConfigFile,newDB.ConfigFile);
   if origDB.LoginPrompt<>newDB.LoginPrompt then
    op.AddProperty('loginPrompt',ptBoolean,origDB.LoginPrompt,newDB.LoginPrompt);
   if origDB.LoadParams<>newDB.LoadParams then
    op.AddProperty('loadParams',ptBoolean,origDB.LoadParams,newDB.LoadParams);
   if origDB.LoadDriverParams<>newDB.LoadDriverParams then
    op.AddProperty('loadDriverParams',ptBoolean,origDB.LoadDriverParams,newDB.LoadDriverParams);
   if origDB.ADOConnectionString<>newDB.ADOConnectionString then
    op.AddProperty('connectionString',ptString,origDB.ADOConnectionString,newDB.ADOConnectionString);
   if origDB.ProviderFactory<>newDB.ProviderFactory then
    op.AddProperty('providerFactory',ptString,origDB.ProviderFactory,newDB.ProviderFactory);
   if origDB.DotNetDriver<>newDB.DotNetDriver then
    op.AddProperty('dotNetDriver',ptInteger,origDB.DotNetDriver,newDB.DotNetDriver);
   if op.properties.Count>0 then
    undoCue.AddOperation(op)
   else
    op.Free;
  end;
 end;
 // DataInfo changes
 for i:=0 to origDataInfo.Count-1 do
 begin
  origDS:=origDataInfo.Items[i];
  if newDataInfo.ItemByName(origDS.Name)=nil then
  begin
   op:=TChangeObjectOperation.Create(otRemove,groupId);
   op.componentName:=origDS.Name;
   op.componentClass:='TRPDATAINFOITEM';
   op.oldItemIndex:=i;
  op.AddProperty('alias',ptString,origDS.Alias,Null);
  op.AddProperty('databaseAlias',ptString,origDS.DatabaseAlias,Null);
  op.AddProperty('sql',ptString,origDS.SQL,Null);
  op.AddProperty('dataSource',ptString,origDS.DataSource,Null);
  op.AddProperty('groupUnion',ptBoolean,origDS.GroupUnion,Null);
  op.AddProperty('openOnStart',ptBoolean,origDS.OpenOnStart,Null);
  op.AddProperty('parallelUnion',ptBoolean,origDS.ParallelUnion,Null);
   undoCue.AddOperation(op);
  end;
 end;
 for i:=0 to newDataInfo.Count-1 do
 begin
  newDS:=newDataInfo.Items[i];
  if origDataInfo.ItemByName(newDS.Name)=nil then
  begin
   op:=TChangeObjectOperation.Create(otAdd,groupId);
   op.componentName:=newDS.Name;
   op.componentClass:='TRPDATAINFOITEM';
   op.oldItemIndex:=i;
  op.AddProperty('alias',ptString,Null,newDS.Alias);
  op.AddProperty('databaseAlias',ptString,Null,newDS.DatabaseAlias);
  op.AddProperty('sql',ptString,Null,newDS.SQL);
  op.AddProperty('dataSource',ptString,Null,newDS.DataSource);
  op.AddProperty('groupUnion',ptBoolean,Null,newDS.GroupUnion);
  op.AddProperty('openOnStart',ptBoolean,Null,newDS.OpenOnStart);
  op.AddProperty('parallelUnion',ptBoolean,Null,newDS.ParallelUnion);
   undoCue.AddOperation(op);
  end;
 end;
 for i:=0 to newDataInfo.Count-1 do
 begin
  newDS:=newDataInfo.Items[i];
  origDS:=origDataInfo.ItemByName(newDS.Name);
  if Assigned(origDS) then
  begin
   op:=TChangeObjectOperation.Create(otModify,groupId);
   op.componentName:=newDS.Name;
   op.componentClass:='TRPDATAINFOITEM';
   if origDS.Alias<>newDS.Alias then
    op.AddProperty('alias',ptString,origDS.Alias,newDS.Alias);
   if origDS.DatabaseAlias<>newDS.DatabaseAlias then
    op.AddProperty('databaseAlias',ptString,origDS.DatabaseAlias,newDS.DatabaseAlias);
   if origDS.SQL<>newDS.SQL then
    op.AddProperty('sql',ptString,origDS.SQL,newDS.SQL);
   if origDS.DataSource<>newDS.DataSource then
    op.AddProperty('dataSource',ptString,origDS.DataSource,newDS.DataSource);
   if origDS.GroupUnion<>newDS.GroupUnion then
    op.AddProperty('groupUnion',ptBoolean,origDS.GroupUnion,newDS.GroupUnion);
   if origDS.OpenOnStart<>newDS.OpenOnStart then
    op.AddProperty('openOnStart',ptBoolean,origDS.OpenOnStart,newDS.OpenOnStart);
   if origDS.ParallelUnion<>newDS.ParallelUnion then
    op.AddProperty('parallelUnion',ptBoolean,origDS.ParallelUnion,newDS.ParallelUnion);
   if op.properties.Count>0 then
    undoCue.AddOperation(op)
   else
    op.Free;
  end;
 end;
end;

procedure TFRpDInfoVCL.BOkClick(Sender: TObject);
begin
 fdatasets.Databaseinfo:=fconnections.Databaseinfo;
 // RecordUndoChanges;
 freport.DatabaseInfo.Assign(fdatasets.Databaseinfo);
 freport.DataInfo.Assign(fdatasets.Datainfo);
 freport.Params.Assign(fdatasets.Params);
 Close;
end;

procedure TFRpDInfoVCL.BCancelClick(Sender: TObject);
begin
 Close;
end;

end.

