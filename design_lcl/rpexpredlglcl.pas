{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpexpredlglcl                                   }
{       Expression Builder and Evaluator Dialog for LCL }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpexpredlglcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, Buttons, Variants,
  rptypes, rpmdconsts, rpalias, rpeval, rptypeval;

const
  FMaxListHelp = 5;

type
  TRpRecHelp = class(TObject)
  public
    RFunction: string;
    Help: string;
    Model: string;
    Params: string;
  end;

  { TFRpExpreDialogLCL }

  TFRpExpreDialogLCL = class(TForm)
  private
    FMemoExpre: TMemo;
    FLCategory: TListBox;
    FLOperation: TListBox;
    FMemoHelp: TMemo;
    FLabelCategory: TLabel;
    FLOperationLabel: TLabel;
    FLabelHelp: TLabel;
    FPanelTop: TPanel;
    FPanelCenter: TPanel;
    FPanelBottom: TPanel;
    FBAdd: TButton;
    FBCheckSyn: TButton;
    FBShowResult: TButton;
    FBOK: TButton;
    FBCancel: TButton;
    FLists: array[0..FMaxListHelp - 1] of TStringList;
    FEvaluator: TRpCustomEvaluator;
    FDoOk: Boolean;
    FValidate: Boolean;
    FAResult: Variant;

    procedure SetEvaluator(const Value: TRpCustomEvaluator);
    procedure LCategoryClick(Sender: TObject);
    procedure LOperationClick(Sender: TObject);
    procedure LOperationDblClick(Sender: TObject);
    procedure BAddClick(Sender: TObject);
    procedure BCheckSynClick(Sender: TObject);
    procedure BShowResultClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure BuildControls;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property Evaluator: TRpCustomEvaluator read FEvaluator write SetEvaluator;
    property MemoExpre: TMemo read FMemoExpre;
    property DoOk: Boolean read FDoOk write FDoOk;
    property Validate: Boolean read FValidate write FValidate;
    property AResult: Variant read FAResult write FAResult;
  end;

  { TRpExpreDialogLCL }

  TRpExpreDialogLCL = class(TComponent)
  private
    FExpression: TStrings;
    FRpAlias: TRpAlias;
    FEvaluator: TRpEvaluator;
    procedure SetExpression(const Value: TStrings);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute: Boolean;

    property Expression: TStrings read FExpression write SetExpression;
    property RpAlias: TRpAlias read FRpAlias write FRpAlias;
    property Evaluator: TRpEvaluator read FEvaluator write FEvaluator;
  end;

function ChangeExpression(const formul: string; aval: TRpCustomEvaluator): string;
function ChangeExpressionW(const formul: WideString; aval: TRpCustomEvaluator): WideString;
function ExpressionCalculateW(const formul: WideString; aval: TRpCustomEvaluator): Variant;

implementation

function ChangeExpression(const formul: string; aval: TRpCustomEvaluator): string;
var
  dia: TFRpExpreDialogLCL;
  tempEval: TRpEvaluator;
begin
  Result := formul;
  tempEval := nil;
  dia := TFRpExpreDialogLCL.Create(Application);
  try
    if not Assigned(aval) then
    begin
      tempEval := TRpEvaluator.Create(dia);
      dia.Evaluator := tempEval;
    end
    else
      dia.Evaluator := aval;

    dia.MemoExpre.Text := formul;
    dia.ShowModal;
    if dia.DoOk then
      Result := dia.MemoExpre.Text;
  finally
    dia.Free;
  end;
end;

function ChangeExpressionW(const formul: WideString; aval: TRpCustomEvaluator): WideString;
var
  dia: TFRpExpreDialogLCL;
  tempEval: TRpEvaluator;
begin
  Result := formul;
  tempEval := nil;
  dia := TFRpExpreDialogLCL.Create(Application);
  try
    if not Assigned(aval) then
    begin
      tempEval := TRpEvaluator.Create(dia);
      dia.Evaluator := tempEval;
    end
    else
      dia.Evaluator := aval;

    dia.MemoExpre.Text := String(formul);
    dia.ShowModal;
    if dia.DoOk then
      Result := WideString(dia.MemoExpre.Text);
  finally
    dia.Free;
  end;
end;

function ExpressionCalculateW(const formul: WideString; aval: TRpCustomEvaluator): Variant;
var
  dia: TFRpExpreDialogLCL;
  tempEval: TRpEvaluator;
begin
  Result := Null;
  tempEval := nil;
  dia := TFRpExpreDialogLCL.Create(Application);
  try
    dia.Validate := True;
    dia.MemoExpre.WantReturns := False;
    if not Assigned(aval) then
    begin
      tempEval := TRpEvaluator.Create(dia);
      dia.Evaluator := tempEval;
    end
    else
      dia.Evaluator := aval;

    dia.MemoExpre.Text := String(formul);
    dia.ShowModal;
    if dia.DoOk then
      Result := dia.AResult;
  finally
    dia.Free;
  end;
end;

{ TFRpExpreDialogLCL }

constructor TFRpExpreDialogLCL.Create(AOwner: TComponent);
var
  i: Integer;
begin
  inherited CreateNew(AOwner);
  Caption := TranslateStr(240, 'Expression Builder');
  Width := 680;
  Height := 480;
  Position := poScreenCenter;
  BorderStyle := bsDialog;

  for i := 0 to FMaxListHelp - 1 do
    FLists[i] := TStringList.Create;

  BuildControls;
end;

destructor TFRpExpreDialogLCL.Destroy;
var
  i, j: Integer;
begin
  for i := 0 to FMaxListHelp - 1 do
  begin
    for j := 0 to FLists[i].Count - 1 do
      FLists[i].Objects[j].Free;
    FLists[i].Free;
  end;
  inherited Destroy;
end;

procedure TFRpExpreDialogLCL.BuildControls;
begin
  // Panel Top (Expression Memo)
  FPanelTop := TPanel.Create(Self);
  FPanelTop.Parent := Self;
  FPanelTop.Align := alTop;
  FPanelTop.Height := 110;
  FPanelTop.BevelOuter := bvNone;
  FPanelTop.BorderSpacing.Around := 6;

  FMemoExpre := TMemo.Create(Self);
  FMemoExpre.Parent := FPanelTop;
  FMemoExpre.Align := alClient;
  FMemoExpre.ScrollBars := ssVertical;
  FMemoExpre.Font.Name := 'Courier New';
  FMemoExpre.Font.Size := 10;

  // Panel Bottom (Buttons)
  FPanelBottom := TPanel.Create(Self);
  FPanelBottom.Parent := Self;
  FPanelBottom.Align := alBottom;
  FPanelBottom.Height := 42;
  FPanelBottom.BevelOuter := bvNone;
  FPanelBottom.BorderSpacing.Around := 6;

  FBOK := TButton.Create(Self);
  FBOK.Parent := FPanelBottom;
  FBOK.Caption := TranslateStr(93, 'OK');
  FBOK.Left := FPanelBottom.Width - 170;
  FBOK.Top := 8;
  FBOK.Width := 75;
  FBOK.Height := 28;
  FBOK.Anchors := [akTop, akRight];
  FBOK.Default := True;
  FBOK.OnClick := BOKClick;

  FBCancel := TButton.Create(Self);
  FBCancel.Parent := FPanelBottom;
  FBCancel.Caption := TranslateStr(94, 'Cancel');
  FBCancel.Left := FPanelBottom.Width - 85;
  FBCancel.Top := 8;
  FBCancel.Width := 75;
  FBCancel.Height := 28;
  FBCancel.Anchors := [akTop, akRight];
  FBCancel.Cancel := True;
  FBCancel.OnClick := BCancelClick;

  FBAdd := TButton.Create(Self);
  FBAdd.Parent := FPanelBottom;
  FBAdd.Caption := TranslateStr(243, 'Add');
  FBAdd.Left := 8;
  FBAdd.Top := 8;
  FBAdd.Width := 75;
  FBAdd.Height := 28;
  FBAdd.OnClick := BAddClick;

  FBCheckSyn := TButton.Create(Self);
  FBCheckSyn.Parent := FPanelBottom;
  FBCheckSyn.Caption := TranslateStr(244, 'Check Syntax');
  FBCheckSyn.Left := 90;
  FBCheckSyn.Top := 8;
  FBCheckSyn.Width := 110;
  FBCheckSyn.Height := 28;
  FBCheckSyn.OnClick := BCheckSynClick;

  FBShowResult := TButton.Create(Self);
  FBShowResult.Parent := FPanelBottom;
  FBShowResult.Caption := TranslateStr(246, 'Evaluate');
  FBShowResult.Left := 208;
  FBShowResult.Top := 8;
  FBShowResult.Width := 95;
  FBShowResult.Height := 28;
  FBShowResult.OnClick := BShowResultClick;

  // Panel Center (Category, Operations, Help)
  FPanelCenter := TPanel.Create(Self);
  FPanelCenter.Parent := Self;
  FPanelCenter.Align := alClient;
  FPanelCenter.BevelOuter := bvNone;
  FPanelCenter.BorderSpacing.Around := 6;

  FLabelCategory := TLabel.Create(Self);
  FLabelCategory.Parent := FPanelCenter;
  FLabelCategory.Caption := TranslateStr(241, 'Category:');
  FLabelCategory.Left := 0;
  FLabelCategory.Top := 0;

  FLCategory := TListBox.Create(Self);
  FLCategory.Parent := FPanelCenter;
  FLCategory.Left := 0;
  FLCategory.Top := 20;
  FLCategory.Width := 150;
  FLCategory.Height := FPanelCenter.Height - 20;
  FLCategory.Anchors := [akLeft, akTop, akBottom];
  FLCategory.Items.Add(TranslateStr(247, 'Fields'));
  FLCategory.Items.Add(TranslateStr(248, 'Functions'));
  FLCategory.Items.Add(TranslateStr(249, 'Variables'));
  FLCategory.Items.Add(TranslateStr(250, 'Constants'));
  FLCategory.Items.Add(TranslateStr(251, 'Operators'));
  FLCategory.OnClick := LCategoryClick;

  FLOperationLabel := TLabel.Create(Self);
  FLOperationLabel.Parent := FPanelCenter;
  FLOperationLabel.Caption := TranslateStr(242, 'Element:');
  FLOperationLabel.Left := 160;
  FLOperationLabel.Top := 0;

  FLOperation := TListBox.Create(Self);
  FLOperation.Parent := FPanelCenter;
  FLOperation.Left := 160;
  FLOperation.Top := 20;
  FLOperation.Width := 200;
  FLOperation.Height := FPanelCenter.Height - 20;
  FLOperation.Anchors := [akLeft, akTop, akBottom];
  FLOperation.Sorted := True;
  FLOperation.OnClick := LOperationClick;
  FLOperation.OnDblClick := LOperationDblClick;

  FLabelHelp := TLabel.Create(Self);
  FLabelHelp.Parent := FPanelCenter;
  FLabelHelp.Caption := TranslateStr(245, 'Description:');
  FLabelHelp.Left := 370;
  FLabelHelp.Top := 0;

  FMemoHelp := TMemo.Create(Self);
  FMemoHelp.Parent := FPanelCenter;
  FMemoHelp.Left := 370;
  FMemoHelp.Top := 20;
  FMemoHelp.Width := FPanelCenter.Width - 370;
  FMemoHelp.Height := FPanelCenter.Height - 20;
  FMemoHelp.Anchors := [akLeft, akTop, akRight, akBottom];
  FMemoHelp.ReadOnly := True;
  FMemoHelp.ScrollBars := ssVertical;
  FMemoHelp.Color := clBtnFace;
end;

procedure TFRpExpreDialogLCL.SetEvaluator(const Value: TRpCustomEvaluator);
var
  list: TStringList;
  i: Integer;
  iden: TRpIdentifier;
  rec: TRpRecHelp;
  operators: array[0..14] of string = (
    '+', '-', '*', '/', 'AND', 'OR', 'NOT', '=', '<>', '<', '>', '<=', '>=', '(', ')'
  );
begin
  FEvaluator := Value;

  for i := 0 to FMaxListHelp - 1 do
    FLists[i].Clear;

  if not Assigned(FEvaluator) then
    Exit;

  // Category 0: Database fields
  list := FLists[0];
  if FEvaluator.RpAlias <> nil then
  begin
    FEvaluator.RpAlias.FillWithFields(list);
    for i := 0 to list.Count - 1 do
    begin
      rec := TRpRecHelp.Create;
      rec.RFunction := list.Strings[i];
      rec.Help := 'Database field: ' + list.Strings[i];
      rec.Model := list.Strings[i];
      list.Objects[i] := rec;
    end;
  end;

  // Category 1, 2, 3: Identifiers (Functions, Variables, Constants)
  for i := 0 to FEvaluator.Identifiers.Count - 1 do
  begin
    iden := TRpIdentifier(FEvaluator.Identifiers.Objects[i]);
    case iden.RType of
      RTypeIdenFunction: list := FLists[1];
      RTypeIdenVariable: list := FLists[2];
      RTypeIdenConstant: list := FLists[3];
    else
      list := FLists[1];
    end;

    rec := TRpRecHelp.Create;
    rec.RFunction := FEvaluator.Identifiers.Strings[i];
    rec.Help := iden.Help;
    rec.Model := iden.Model;
    rec.Params := iden.AParams;
    list.AddObject(rec.RFunction, rec);
  end;

  // Category 4: Operators
  list := FLists[4];
  for i := Low(operators) to High(operators) do
  begin
    rec := TRpRecHelp.Create;
    rec.RFunction := operators[i];
    rec.Help := 'Operator: ' + operators[i];
    rec.Model := operators[i];
    list.AddObject(rec.RFunction, rec);
  end;

  // Select default category
  if FLCategory.Items.Count > 0 then
  begin
    FLCategory.ItemIndex := 1; // Functions default
    LCategoryClick(nil);
  end;
end;

procedure TFRpExpreDialogLCL.LCategoryClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := FLCategory.ItemIndex;
  FLOperation.Clear;
  FMemoHelp.Clear;
  if (idx >= 0) and (idx < FMaxListHelp) then
  begin
    FLOperation.Items.Assign(FLists[idx]);
    if FLOperation.Items.Count > 0 then
    begin
      FLOperation.ItemIndex := 0;
      LOperationClick(nil);
    end;
  end;
end;

procedure TFRpExpreDialogLCL.LOperationClick(Sender: TObject);
var
  idx: Integer;
  rec: TRpRecHelp;
begin
  idx := FLOperation.ItemIndex;
  if idx >= 0 then
  begin
    rec := TRpRecHelp(FLOperation.Items.Objects[idx]);
    if Assigned(rec) then
    begin
      FMemoHelp.Lines.Clear;
      if rec.Model <> '' then
        FMemoHelp.Lines.Add('Syntax: ' + rec.Model);
      if rec.Params <> '' then
        FMemoHelp.Lines.Add('Parameters: ' + rec.Params);
      if rec.Help <> '' then
      begin
        FMemoHelp.Lines.Add('');
        FMemoHelp.Lines.Add(rec.Help);
      end;
    end;
  end;
end;

procedure TFRpExpreDialogLCL.LOperationDblClick(Sender: TObject);
begin
  BAddClick(Sender);
end;

procedure TFRpExpreDialogLCL.BAddClick(Sender: TObject);
var
  idx: Integer;
  rec: TRpRecHelp;
  insertText: string;
begin
  idx := FLOperation.ItemIndex;
  if idx >= 0 then
  begin
    rec := TRpRecHelp(FLOperation.Items.Objects[idx]);
    if Assigned(rec) then
    begin
      if rec.Model <> '' then
        insertText := rec.Model
      else
        insertText := rec.RFunction;

      FMemoExpre.SelText := insertText;
      FMemoExpre.SetFocus;
    end;
  end;
end;

procedure TFRpExpreDialogLCL.BCheckSynClick(Sender: TObject);
var
  expr: string;
begin
  expr := Trim(FMemoExpre.Text);
  if expr = '' then
  begin
    ShowMessage(TranslateStr(252, 'Expression is empty.'));
    Exit;
  end;

  try
    if Assigned(FEvaluator) then
    begin
      FEvaluator.Expression := expr;
      ShowMessage(TranslateStr(253, 'Syntax is OK.'));
    end;
  except
    on E: Exception do
      ShowMessage(TranslateStr(254, 'Syntax Error: ') + E.Message);
  end;
end;

procedure TFRpExpreDialogLCL.BShowResultClick(Sender: TObject);
var
  expr: string;
  val: Variant;
begin
  expr := Trim(FMemoExpre.Text);
  if expr = '' then
  begin
    ShowMessage(TranslateStr(252, 'Expression is empty.'));
    Exit;
  end;

  try
    if Assigned(FEvaluator) then
    begin
      FEvaluator.Expression := expr;
      FEvaluator.Evaluate;
      FAResult := FEvaluator.EvalResult;
      ShowMessage(TranslateStr(255, 'Result: ') + FEvaluator.EvalResultString);
    end;
  except
    on E: Exception do
      ShowMessage(TranslateStr(256, 'Evaluation Error: ') + E.Message);
  end;
end;

procedure TFRpExpreDialogLCL.BOKClick(Sender: TObject);
begin
  FDoOk := True;
  ModalResult := mrOk;
end;

procedure TFRpExpreDialogLCL.BCancelClick(Sender: TObject);
begin
  FDoOk := False;
  ModalResult := mrCancel;
end;

{ TRpExpreDialogLCL }

constructor TRpExpreDialogLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEvaluator := TRpEvaluator.Create(Self);
  FExpression := TStringList.Create;
end;

destructor TRpExpreDialogLCL.Destroy;
begin
  FExpression.Free;
  inherited Destroy;
end;

procedure TRpExpreDialogLCL.SetExpression(const Value: TStrings);
begin
  FExpression.Assign(Value);
end;

procedure TRpExpreDialogLCL.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FRpAlias then
      FRpAlias := nil
    else if AComponent = FEvaluator then
      FEvaluator := nil;
  end;
end;

function TRpExpreDialogLCL.Execute: Boolean;
var
  dia: TFRpExpreDialogLCL;
begin
  FEvaluator.RpAlias := FRpAlias;
  dia := TFRpExpreDialogLCL.Create(Application);
  try
    dia.Evaluator := FEvaluator;
    dia.MemoExpre.Text := FExpression.Text;
    dia.ShowModal;
    Result := dia.DoOk;
    if Result then
      FExpression.Text := dia.MemoExpre.Text;
  finally
    dia.Free;
  end;
end;

end.
