{*******************************************************}
{                                                       }
{       Report Manager Designer - LCL                   }
{                                                       }
{       rpdbbrowserlcl                                  }
{       Database and Dataset browser frame              }
{                                                       }
{*******************************************************}

unit rpdbbrowserlcl;

{$I rpconf.inc}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs, ComCtrls, Menus,
  rpdatainfo, rpmdconsts, rpreport, rptypeval, rpparser, rptypes, rpgraphutilslcl,
  rpmdimageslcl;

type
  TRpDBFieldInfo = class(TObject)
    FieldSize: Integer;
    dbinfo: TRpDatabaseInfoItem;
    dinfo: TRpDataInfoItem;
  end;

  TFRpBrowserLCL = class(TFrame)
    ATree: TTreeView;
    ImageList1: TImageList;
    PopupMenu1: TPopupMenu;
    MRefresh: TMenuItem;
    procedure ATreeExpanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
    procedure ATreeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure MRefreshClick(Sender: TObject);
  private
    FShowDataTypes: Boolean;
    FReport: TRpReport;
    FShowDatasets: Boolean;
    FShowDatabases: Boolean;
    FShowEval: Boolean;
    procedure SetReport(Value: TRpReport);
    procedure InitTree;
    procedure SetShowDataTypes(Value: Boolean);
  public
    procedure FreeFieldsInfo;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Report: TRpReport read FReport write SetReport;
    property ShowEval: Boolean read FShowEval write FShowEval;
    property ShowDatasets: Boolean read FShowDatasets write FShowDatasets;
    property ShowDatabases: Boolean read FShowDatabases write FShowDatabases;
    property ShowDataTypes: Boolean read FShowDataTypes write SetShowDataTypes default True;
  end;

function NewTRpDBFieldInfo(fieldsize: Integer; dbinfo: TRpDatabaseInfoItem; dinfo: TRpDataInfoItem): TRpDBFieldInfo;

implementation

{$R *.lfm}

function NewTRpDBFieldInfo(fieldsize: Integer; dbinfo: TRpDatabaseInfoItem; dinfo: TRpDataInfoItem): TRpDBFieldInfo;
begin
  Result := TRpDBFieldInfo.Create;
  Result.FieldSize := fieldsize;
  Result.dbinfo := dbinfo;
  Result.dinfo := dinfo;
end;

procedure TFRpBrowserLCL.FreeFieldsInfo;
var
  i: Integer;
begin
  if not Assigned(ATree) then Exit;
  for i := 0 to ATree.Items.Count - 1 do
  begin
    if TObject(ATree.Items[i].Data) is TRpDBFieldInfo then
    begin
      TObject(ATree.Items[i].Data).Free;
      ATree.Items[i].Data := nil;
    end;
  end;
  ATree.Items.Clear;
end;

destructor TFRpBrowserLCL.Destroy;
begin
  FreeFieldsInfo;
  inherited Destroy;
end;

procedure TFRpBrowserLCL.SetReport(Value: TRpReport);
begin
  FReport := Value;
  if Assigned(FReport) then
    InitTree
  else
    FreeFieldsInfo;
end;

procedure TFRpBrowserLCL.InitTree;
var
  i: Integer;
  dbinfo: TRpDatabaseInfoList;
  dinfo: TRpDataInfoList;
  anode, nnode: TTreeNode;
  aiden: TRpIdentifier;
  alist: TStringList;
  astringiden: string;
begin
  FreeFieldsInfo;
  if not Assigned(FReport) then Exit;
  ATree.Items.BeginUpdate;
  try
    if FShowDatabases then
    begin
      dbinfo := FReport.DatabaseInfo;
      for i := 0 to dbinfo.Count - 1 do
      begin
        anode := ATree.Items.AddChild(nil, dbinfo.Items[i].Alias);
        anode.Data := NewTRpDBFieldInfo(0, dbinfo.Items[i], nil);
        anode.ImageIndex := 0;
        anode.SelectedIndex := 0;
        ATree.Items.AddChild(anode, '');
      end;
    end;
    if FShowDatasets then
    begin
      dinfo := FReport.DataInfo;
      for i := 0 to dinfo.Count - 1 do
      begin
        anode := ATree.Items.AddChild(nil, dinfo.Items[i].Alias);
        anode.Data := NewTRpDBFieldInfo(0, nil, dinfo.Items[i]);
        anode.ImageIndex := 1;
        anode.SelectedIndex := 1;
        ATree.Items.AddChild(anode, '');
      end;
    end;
    if FShowEval then
    begin
      anode := ATree.Items.AddChild(nil, SRpVariables);
      anode.ImageIndex := 1;
      anode.SelectedIndex := 1;
      FReport.InitEvaluator;
      FReport.AddReportItemsToEvaluator(FReport.Evaluator);
      alist := TStringList.Create;
      try
        alist.Sorted := True;
        for i := 0 to FReport.Evaluator.Identifiers.Count - 1 do
        begin
          aiden := TRpIdentifier(FReport.Evaluator.Identifiers.Objects[i]);
          astringiden := FReport.Evaluator.Identifiers.Strings[i];
          if Length(aiden.IdenName) > 0 then
          begin
            if (astringiden <> 'CIERTO') and (astringiden <> 'M.PAGINA') and (astringiden <> 'M.NUMPAGINA') then
            begin
              if alist.IndexOf(aiden.IdenName) < 0 then
              begin
                if (aiden is TIdenConstant) or (aiden is TIdenVariable) or
                   ((aiden is TIdenFunction) and (TIdenFunction(aiden).ParamCount = 0)) then
                begin
                  alist.Add(astringiden);
                  nnode := ATree.Items.AddChild(anode, astringiden);
                  nnode.ImageIndex := 2;
                  nnode.SelectedIndex := 2;
                end;
              end;
            end;
          end;
        end;
        nnode := ATree.Items.AddChild(anode, 'PAGECOUNT');
        nnode.ImageIndex := 2;
        nnode.SelectedIndex := 2;
        nnode := ATree.Items.AddChild(anode, 'GROUPPAGECOUNT');
        nnode.ImageIndex := 2;
        nnode.SelectedIndex := 2;
      finally
        alist.Free;
      end;
    end;
  finally
    ATree.Items.EndUpdate;
  end;
end;

procedure TFRpBrowserLCL.ATreeExpanding(Sender: TObject; Node: TTreeNode;
  var AllowExpansion: Boolean);
var
  dbitem: TRpDatabaseInfoItem;
  ditem: TRpDataInfoItem;
  achild: TTreeNode;
  ainfo: TRpDBFieldInfo;
  alist, fieldtypes, fieldsizes: TStringList;
  usebrackets: Boolean;
  i, j: Integer;
  aname: string;
begin
  if not Assigned(Node.Data) then Exit;
  if Node.Count < 1 then Exit;
  achild := Node.Items[0];
  if achild.Text <> '' then Exit; // already loaded

  try
    ainfo := TRpDBFieldInfo(Node.Data);
    if Assigned(ainfo.dbinfo) then
    begin
      dbitem := ainfo.dbinfo;
      alist := TStringList.Create;
      fieldtypes := TStringList.Create;
      fieldsizes := TStringList.Create;
      try
        ATree.Items.Delete(achild);
        if Node.Parent = nil then
        begin
          dbitem.GetTableNames(alist, FReport.Params);
          if alist.Count < 1 then
            AllowExpansion := False
          else
          begin
            for i := 0 to alist.Count - 1 do
            begin
              aname := alist.Strings[i];
              if (i < fieldtypes.Count) and FShowDataTypes then
              begin
                aname := aname + '-' + fieldtypes.Strings[i];
                if (i < fieldsizes.Count) and (Length(fieldsizes.Strings[i]) > 0) then
                  aname := aname + '(' + fieldsizes.Strings[i] + ')';
              end;
              achild := ATree.Items.AddChild(Node, aname);
              achild.Data := NewTRpDBFieldInfo(0, dbitem, nil);
              ATree.Items.AddChild(achild, '');
            end;
          end;
        end
        else
        begin
          dbitem.GetFieldNames(Node.Text, alist, fieldtypes, fieldsizes, FReport.Params);
          if alist.Count < 1 then
            AllowExpansion := False
          else
          begin
            for i := 0 to alist.Count - 1 do
            begin
              aname := alist.Strings[i];
              if (i < fieldtypes.Count) and FShowDataTypes then
              begin
                aname := aname + ' ' + fieldtypes.Strings[i];
                if (i < fieldsizes.Count) and (Length(fieldsizes.Strings[i]) > 0) then
                  aname := aname + '(' + fieldsizes.Strings[i] + ')';
              end;
              achild := ATree.Items.AddChild(Node, aname);
              achild.ImageIndex := 2;
              achild.SelectedIndex := 2;
              if (i < fieldsizes.Count) and (Length(fieldsizes.Strings[i]) > 0) then
                achild.Data := NewTRpDBFieldInfo(StrToIntDef(fieldsizes.Strings[i], 10), nil, nil)
              else
                achild.Data := NewTRpDBFieldInfo(10, nil, nil);
            end;
          end;
        end;
      finally
        alist.Free;
        fieldtypes.Free;
        fieldsizes.Free;
      end;
    end
    else if Assigned(ainfo.dinfo) then
    begin
      ditem := ainfo.dinfo;
      alist := TStringList.Create;
      fieldtypes := TStringList.Create;
      fieldsizes := TStringList.Create;
      try
        ATree.Items.Delete(achild);
        ditem.GetFieldNames(alist, fieldtypes, fieldsizes);
        if alist.Count < 1 then
          AllowExpansion := False
        else
        begin
          for i := 0 to alist.Count - 1 do
          begin
            aname := alist.Strings[i];
            usebrackets := False;
            for j := 1 to Length(aname) do
            begin
              if Pos(aname[j], ParserSetChars) = 0 then
              begin
                usebrackets := True;
                break;
              end;
            end;
            if usebrackets then
              aname := '[' + ditem.Alias + '.' + aname + ']'
            else
              aname := ditem.Alias + '.' + aname;

            if (i < fieldtypes.Count) and FShowDataTypes then
            begin
              aname := aname + ' ' + fieldtypes.Strings[i];
              if (i < fieldsizes.Count) and (Length(fieldsizes.Strings[i]) > 0) then
                aname := aname + '(' + fieldsizes.Strings[i] + ')';
            end;
            achild := ATree.Items.AddChild(Node, aname);
            achild.ImageIndex := 2;
            achild.SelectedIndex := 2;
            if (i < fieldsizes.Count) and (Length(fieldsizes.Strings[i]) > 0) then
              achild.Data := NewTRpDBFieldInfo(StrToIntDef(fieldsizes.Strings[i], 10), nil, nil)
            else
              achild.Data := NewTRpDBFieldInfo(10, nil, nil);
          end;
        end;
      finally
        alist.Free;
        fieldtypes.Free;
        fieldsizes.Free;
      end;
    end;
  except
    on E: Exception do
    begin
      RpShowMessage(E.Message);
      AllowExpansion := False;
    end;
  end;
end;

constructor TFRpBrowserLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FShowDatasets := True;
  FShowEval := True;
  FShowDatabases := True;
  FShowDataTypes := True;

  ImageList1 := TImageList.Create(Self);
  LoadDBBrowserImageList(ImageList1);

  PopupMenu1 := TPopupMenu.Create(Self);
  MRefresh := TMenuItem.Create(PopupMenu1);
  MRefresh.Caption := SRpRefresh;
  MRefresh.OnClick := MRefreshClick;
  PopupMenu1.Items.Add(MRefresh);

  ATree := TTreeView.Create(Self);
  ATree.Align := alClient;
  ATree.Images := ImageList1;
  ATree.ReadOnly := True;
  ATree.PopupMenu := PopupMenu1;
  ATree.Parent := Self;
  ATree.OnExpanding := ATreeExpanding;
  ATree.OnMouseDown := ATreeMouseDown;
end;

procedure TFRpBrowserLCL.ATreeMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  anode: TTreeNode;
begin
  if not Assigned(ATree.Selected) then Exit;
  anode := ATree.Selected;
  if not Assigned(anode.Parent) then Exit;
  if anode.ImageIndex = 2 then
  begin
    // Could initiate drag
  end;
end;

procedure TFRpBrowserLCL.MRefreshClick(Sender: TObject);
begin
  SetReport(FReport);
end;

procedure TFRpBrowserLCL.SetShowDataTypes(Value: Boolean);
begin
  if Value <> FShowDataTypes then
  begin
    FShowDataTypes := Value;
    SetReport(FReport);
  end;
end;

end.
