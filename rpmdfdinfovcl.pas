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
 rptypes,rpdatainfo,rpreport,rpmdundocue,rpparams,
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
    origParams:TRpParamList;
    procedure EnsureDatasetsFrame;
    procedure SetReport(value:TRpReport);
    procedure RecordUndoChanges;
  public
    { Public declarations }
    property report:TRpReport read FReport write SetReport;
  end;


procedure ShowDataConfig(report:TRpReport);


implementation

uses rpdbxconfigvcl, rpbasereport, rpxmlstream, rpfparamsvcl;


var
 GDataConfigDialog: TFRpDInfoVCL = nil;

procedure ShowDataConfig(report:TRpReport);
begin
 if GDataConfigDialog = nil then
  GDataConfigDialog := TFRpDInfoVCL.Create(nil);
 GDataConfigDialog.report := report;
 GDataConfigDialog.ShowModal;
end;


{$R *.dfm}

procedure TFRpDInfoVCL.EnsureDatasetsFrame;
begin
 if fdatasets=nil then
 begin
  fdatasets:=TFRpDatasetsVCL.Create(Self);
  fdatasets.Parent:=TabDatasets;
  fdatasets.Align := alClient;
 end;

 if Assigned(freport) then
 begin
  fdatasets.Datainfo:=freport.DataInfo;
  fdatasets.Databaseinfo:=freport.DatabaseInfo;
  fdatasets.Params:=freport.Params;
 end;
end;

procedure TFRpDInfoVCL.SetReport(value:TRpReport);
begin
 freport:=value;
 EnsureReportItemNames(value);
 // Snapshot originals for undo comparison
 if Assigned(origDatabaseInfo) then FreeAndNil(origDatabaseInfo);
 origDatabaseInfo:=TRpDatabaseInfoList.Create(nil);
 origDatabaseInfo.Assign(value.DatabaseInfo);
 if Assigned(origDataInfo) then FreeAndNil(origDataInfo);
 origDataInfo:=TRpDataInfoList.Create(nil);
 origDataInfo.Assign(value.DataInfo);
 if Assigned(origParams) then FreeAndNil(origParams);
 origParams:=TRpParamList.Create(nil);
 origParams.Assign(value.Params);

 if fconnections=nil then
 begin
  fconnections:=TFRpConnectionVCL.Create(Self);
  fconnections.Parent:=TabConnections;
  fconnections.Align := alClient;
 end;
 fconnections.Databaseinfo:=report.DatabaseInfo;
 fconnections.Params:=report.Params;
 if report.DatabaseInfo.Count>0 then
   begin
    EnsureDatasetsFrame;
  PControl.ActivePage:=TabDatasets
   end
 else
  PControl.ActivePage:=TabConnections;
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
 FreeAndNil(origParams);
end;

procedure TFRpDInfoVCL.PControlChange(Sender: TObject);
begin
 if PControl.ActivePage = TabDatasets then
 begin
  EnsureDatasetsFrame;
  fdatasets.Databaseinfo:=fconnections.DatabaseInfo;
  fconnections.Params:=fdatasets.Params;
 end;
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
 newParams:TRpParamList;
 op:TChangeObjectOperation;
  function FindDatabaseInfoByComponentName(infoList: TRpDatabaseInfoList;
    const componentName: string): TRpDatabaseInfoItem;
  var
    itemIndex: Integer;
  begin
    Result:=nil;
    for itemIndex:=0 to infoList.Count-1 do
    begin
      if SameText(infoList.Items[itemIndex].Name, componentName) then
      begin
        Result:=infoList.Items[itemIndex];
        Exit;
      end;
    end;
  end;
  function FindDataInfoByComponentName(infoList: TRpDataInfoList;
    const componentName: string): TRpDataInfoItem;
  var
    itemIndex: Integer;
  begin
    Result:=nil;
    for itemIndex:=0 to infoList.Count-1 do
    begin
      if SameText(infoList.Items[itemIndex].Name, componentName) then
      begin
        Result:=infoList.Items[itemIndex];
        Exit;
      end;
    end;
  end;
begin
 if not Assigned(freport) then
  exit;
 if not Assigned(freport.UndoCue) then
  freport.UndoCue:=TUndoCue.Create(freport);
 undoCue:=TUndoCue(freport.UndoCue);
 groupId:=undoCue.GetGroupId;
 newDBInfo:=fconnections.DatabaseInfo;
 if fdatasets<>nil then
 begin
  newDataInfo:=fdatasets.DataInfo;
  newParams:=fdatasets.Params;
 end
 else
 begin
  newDataInfo:=freport.DataInfo;
  newParams:=freport.Params;
 end;
 // DatabaseInfo changes
 for i:=0 to origDatabaseInfo.Count-1 do
 begin
  origDB:=origDatabaseInfo.Items[i];
  if FindDatabaseInfoByComponentName(newDBInfo, origDB.Name)=nil then
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
  if FindDatabaseInfoByComponentName(origDatabaseInfo, newDB.Name)=nil then
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
  origDB:=FindDatabaseInfoByComponentName(origDatabaseInfo, newDB.Name);
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
  if FindDataInfoByComponentName(newDataInfo, origDS.Name)=nil then
  begin
   op:=TChangeObjectOperation.Create(otRemove,groupId);
   op.componentName:=origDS.Name;
   op.componentClass:='TRPDATAINFOITEM';
   op.oldItemIndex:=i;
  op.AddProperty('alias',ptString,origDS.Alias,Null);
  op.AddProperty('databaseAlias',ptString,origDS.DatabaseAlias,Null);
  op.AddProperty('sql',ptString,origDS.SQL,Null);
  op.AddProperty('hubSchemaId',ptInteger,origDS.HubSchemaId,Null);
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
  if FindDataInfoByComponentName(origDataInfo, newDS.Name)=nil then
  begin
   op:=TChangeObjectOperation.Create(otAdd,groupId);
   op.componentName:=newDS.Name;
   op.componentClass:='TRPDATAINFOITEM';
   op.oldItemIndex:=i;
  op.AddProperty('alias',ptString,Null,newDS.Alias);
  op.AddProperty('databaseAlias',ptString,Null,newDS.DatabaseAlias);
  op.AddProperty('sql',ptString,Null,newDS.SQL);
  op.AddProperty('hubSchemaId',ptInteger,Null,newDS.HubSchemaId);
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
  origDS:=FindDataInfoByComponentName(origDataInfo, newDS.Name);
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
  if origDS.HubSchemaId<>newDS.HubSchemaId then
   op.AddProperty('hubSchemaId',ptInteger,origDS.HubSchemaId,newDS.HubSchemaId);
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
   RecordParamUndoChanges(origParams,newParams,freport,groupId);
end;

procedure TFRpDInfoVCL.BOkClick(Sender: TObject);
begin
 EnsureReportItemNames(freport);
 RecordUndoChanges;
 freport.DatabaseInfo.Assign(fconnections.Databaseinfo);
 if fdatasets<>nil then
 begin
  fdatasets.Databaseinfo:=fconnections.Databaseinfo;
  freport.DataInfo.Assign(fdatasets.Datainfo);
  freport.Params.Assign(fdatasets.Params);
 end;
 Close;
end;

procedure TFRpDInfoVCL.BCancelClick(Sender: TObject);
begin
 Close;
end;

end.

