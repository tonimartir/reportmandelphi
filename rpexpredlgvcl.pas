{*******************************************************}
{                                                       }
{       Rpexpredlgvcl                                   }
{       A Helper for building expresions with help      }
{       Report Manager                                  }
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

unit rpexpredlgvcl;

interface

{$I rpconf.inc}
{$R rpexpredlg.dcr}

uses
  SysUtils, Classes,
  Graphics,Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Buttons,
  System.JSON, System.Threading,
  rpalias,rpeval, rptypeval,rpgraphutilsvcl,
{$IFDEF USEEVALHASH}
  rphashtable,rpstringhash,
{$ENDIF}
{$IFDEF USEVARIANTS}
  Variants,
{$ENDIF}
  rpmdconsts, rpfrmexpressionchatvcl, rpdatahttp;

const
 FMaxlisthelp=5;
type
  TRpRecHelp=class(TObject)
  public
    rfunction:string;
    help:string;
    model:string;
    params:string;
  end;

  TRpExpreDialogVCL = class(TComponent)
  private
    { Private declarations }
    FExpresion:TStrings;
    FRpalias:TRpalias;
    Fevaluator:TRpEvaluator;
    procedure setexpresion(valor:TStrings);
    procedure SetRpalias(Rpalias1:TRpalias);
  protected
    { Protected declarations }
    procedure Notification(AComponent:TComponent;Operation:TOperation);override;
  public
    { Public declarations }
    constructor Create(AOwner:TComponent);override;
    destructor Destroy;override;
    function Execute:Boolean;
  published
    { Published declarations }
    property Expresion:TStrings read FExpresion write setexpresion;
    property Rpalias:TRpalias read FRpalias
     write SetRpalias;
    property evaluator:TRpEvaluator read Fevaluator write Fevaluator;
  end;

  TFRpExpredialogVCL = class(TForm)
    PLeftHost: TPanel;
    PBottom: TPanel;
    LabelCategory: TLabel;
    LOperation: TLabel;
    LModel: TLabel;
    LHelp: TLabel;
    LParams: TLabel;
    LItems: TListBox;
    BCancel: TButton;
    BOK: TButton;
    LCategory: TListBox;
    PAlClient: TPanel;
    SplitterChat: TSplitter;
    PChatHost: TPanel;
    PExpressionHost: TPanel;
    MemoExpre: TMemo;
    Panel1: TPanel;
    BShowResult: TButton;
    BCheckSyn: TButton;
    BAdd: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure LCategoryClick(Sender: TObject);
    procedure LItemsClick(Sender: TObject);
    procedure BCheckSynClick(Sender: TObject);
    procedure BShowResultClick(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure LItemsDblClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure MemoExpreChange(Sender: TObject);
  private
    { Private declarations }
    validate:Boolean;
    dook:boolean;
    AResult:Variant;
    Fevaluator:TRpCustomEvaluator;
    FCancelExpressionRequest: Boolean;
    FExpressionChat: TFRpExpressionChatFrame;
    FExpressionStreamError: string;
    FExpressionStreamResult: TJSONObject;
    llistes:array[0..FMaxlisthelp-1] of TStringlist;
    function BuildExpressionSemanticContextJson: string;
    function ExpressionStreamCancelRequested(Sender: TObject): Boolean;
    procedure ExpressionStreamProgress(Sender: TObject; const AStage,
      AChunkType, AChunk: string; AOutputTokens: Integer);
    procedure ExpressionStreamResult(Sender: TObject; AResultJson: TJSONObject;
      const AErrorMessage: string);
    function ExtractExpressionFromApiResult(AResultJson: TJSONObject;
      out AExpression, AExplanation, AErrorMessage: string): Boolean;
    function GetExpressionPrefillPercent(const AStage, AChunkType: string): Integer;
    procedure ResetExpressionStreamState;
    procedure StopExpressionRequest(Sender: TObject);
    function ValidateExpressionText(const AExpression: string;
      out AErrorMessage: string): Boolean;
    procedure ExpressionChatApplySuggestion(Sender: TObject; const AExpression: string);
    procedure ExpressionChatSendPrompt(Sender: TObject; const APrompt, AExpression: string);
    procedure Setevaluator(aval:TRpCustomEvaluator);
  public
    { Public declarations }
    property evaluator:TRpCustomEvaluator read fevaluator write setevaluator;
  end;

function ChangeExpression(formul:string;aval:TRpCustomEvaluator):string;
function ChangeExpressionW(formul:Widestring;aval:TRpCustomEvaluator):Widestring;
function ExpressionCalculateW(formul:Widestring;aval:TRpCustomEvaluator):Variant;



implementation

{$R *.dfm}
uses rplabelitem, rpauthmanager;

constructor TRpExpreDialogVCL.create(AOwner:TComponent);
begin
 inherited create(AOwner);
 Fevaluator:=TRpEvaluator.Create(Self);
 FExpresion:=TStringList.Create;
end;

destructor TRpExpreDialogVCL.destroy;
begin
 FExpresion.free;

 inherited destroy;
end;

procedure TRpExpreDialogVCL.SetRpalias(Rpalias1:TRpalias);
begin
 FRpalias:=Rpalias1;
end;

procedure TRpExpreDialogVCL.setexpresion(valor:TStrings);
begin
 FExpresion.assign(valor);
end;

procedure TRpExpreDialogVCL.Notification(AComponent:TComponent;Operation:TOperation);
begin
 inherited Notification(AComponent,Operation);
 if Operation=opRemove then
 begin
  if AComponent=FRpalias then
   Rpalias:=nil
  else
   if AComponent=Fevaluator then
    Fevaluator:=nil;
 end;
end;


procedure TFRpExpredialogVCL.FormCreate(Sender: TObject);
var
 i:integer;
begin
 inherited;
 ActiveControl:=MemoExpre;
 MemoExpre.OnChange := MemoExpreChange;
 FCancelExpressionRequest := False;
 FExpressionStreamError := '';
 FExpressionStreamResult := nil;
 FExpressionChat := TFRpExpressionChatFrame.Create(Self);
 FExpressionChat.Parent := PChatHost;
 FExpressionChat.Align := alClient;
 FExpressionChat.OnSendPrompt := ExpressionChatSendPrompt;
 FExpressionChat.OnApplySuggestion := ExpressionChatApplySuggestion;
 FExpressionChat.OnStopRequest := StopExpressionRequest;
 FExpressionChat.SetCurrentExpression(MemoExpre.Text);
 FExpressionChat.AddAssistantMessage('Ask for help rewriting, simplifying or validating the current expression.');
 for i:=0 to FMaxlisthelp-1 do
 begin
  llistes[i]:=TStringList.create;
 end;

 BOK.Caption:=TranslateStr(93,BOK.Caption);
 BCancel.Caption:=TranslateStr(94,BCancel.Caption);
// LExpression.Caption:=TranslateStr(239,LExpression.Caption);
 Caption:=TranslateStr(240,Caption);
 LabelCategory.Caption:=TranslateStr(241,LabelCategory.Caption);
 LOperation.Caption:=TranslateStr(242,LOperation.Caption);
 BAdd.Caption:=TranslateStr(243,BAdd.Caption);
 BCheckSyn.Caption:=TranslateStr(244,BCheckSyn.Caption);
 BShowResult.Caption:=TranslateStr(246,BShowResult.Caption);
 LCategory.Items.Strings[0]:=TranslateStr(247,LCategory.Items.Strings[0]);
 LCategory.Items.Strings[1]:=TranslateStr(248,LCategory.Items.Strings[1]);
 LCategory.Items.Strings[2]:=TranslateStr(249,LCategory.Items.Strings[2]);
 LCategory.Items.Strings[3]:=TranslateStr(250,LCategory.Items.Strings[3]);
 LCategory.Items.Strings[4]:=TranslateStr(251,LCategory.Items.Strings[4]);
 
end;

procedure TFRpExpredialogVCL.Setevaluator(aval:TRpCustomEvaluator);
var
 lista1:Tstringlist;
 i:integer;
 iden:TRpIdentifier;
 rec:TRpRecHelp;
{$IFDEF USEEVALHASH}
 ait:TstrHashIterator;
{$ENDIF}
begin
 Fevaluator:=Aval;
 for i:=0 to FMaxlisthelp-1 do
 begin
  llistes[i].clear;
 end;
 lista1:=llistes[0];
 if aval.Rpalias<>nil then
 begin
  aval.Rpalias.fillwithfields(lista1);
  for i:=0 to lista1.count -1 do
  begin
   rec:=TRpRecHelp.Create;
   rec.rfunction:=lista1.strings[i];
   lista1.Objects[i]:=rec;
  end;
 end;
{$IFDEF USEEVALHASH}
 ait:=aval.identifiers.getiterator;
 while ait.hasnext do
 begin
  ait.next;
  iden:=TRpIdentifier(ait.GetValue);
{$ENDIF}
{$IFNDEF USEEVALHASH}
 for i:=0 to aval.identifiers.Count-1 do
 begin
  iden:=TRpIdentifier(aval.identifiers.Objects[i]);
{$ENDIF}

  if iden is TIdenRpExpression then
  begin
   lista1:=llistes[2];
  end
  else
  begin
   case iden.RType of
    RTypeidenfunction:
     begin
     lista1:=llistes[1];
     end;
    RTypeidenvariable:
     begin
      lista1:=llistes[2];
     end;
    RTypeidenconstant:
     begin
      lista1:=llistes[3];
     end;
   end;
  end;
  rec:=TRpRecHelp.Create;
{$IFDEF USEEVALHASH}
  rec.rfunction:=ait.GetKey;
{$ENDIF}
{$IFNDEF USEEVALHASH}
  rec.rfunction:=aval.identifiers.Strings[i];
{$ENDIF}
  rec.help:=iden.Help;
  rec.model:=iden.model;
  rec.params:=iden.aparams;
  lista1.addobject(rec.rfunction,rec);
 end;
 lista1:=llistes[4];
 // +
 rec:=TRpRecHelp.create;
 rec.rfunction:='+';
 rec.help:=SRpOperatorSum;
 lista1.addobject(rec.rfunction,rec);
 // -
 rec:=TRpRecHelp.create;
 rec.rfunction:='-';
 rec.help:=SRpOperatorDif;
 lista1.addobject(rec.rfunction,rec);
 // *
 rec:=TRpRecHelp.create;
 rec.rfunction:='*';
 rec.help:=SRpOperatorMul;
 lista1.addobject(rec.rfunction,rec);
 // /
 rec:=TRpRecHelp.create;
 rec.rfunction:='/';
 rec.help:=SRpOperatorDiv;
 lista1.addobject(rec.rfunction,rec);
 // =
 rec:=TRpRecHelp.create;
 rec.rfunction:='=';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // ==
 rec:=TRpRecHelp.create;
 rec.rfunction:='==';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // >=
 rec:=TRpRecHelp.create;
 rec.rfunction:='>=';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // <=
 rec:=TRpRecHelp.create;
 rec.rfunction:='<=';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // >
 rec:=TRpRecHelp.create;
 rec.rfunction:='>';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // <
 rec:=TRpRecHelp.create;
 rec.rfunction:='<';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // <>
 rec:=TRpRecHelp.create;
 rec.rfunction:='<>';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // AND
 rec:=TRpRecHelp.create;
 rec.rfunction:='AND';
 rec.help:=SRpOperatorLog;
 lista1.addobject(rec.rfunction,rec);
 // OR
 rec:=TRpRecHelp.create;
 rec.rfunction:='OR';
 rec.help:=SRpOperatorLog;
 lista1.addobject(rec.rfunction,rec);
 // NOT
 rec:=TRpRecHelp.create;
 rec.rfunction:='NOT';
 rec.help:=SRpOperatorLog;
 lista1.addobject(rec.rfunction,rec);
 // ;
 rec:=TRpRecHelp.create;
 rec.rfunction:=';';
 rec.help:=SRpOperatorSep;
 rec.params:=SRpOperatorSepP;
 lista1.addobject(rec.rfunction,rec);
 // IIF
 rec:=TRpRecHelp.create;
 rec.rfunction:='IIF';
 rec.help:=SRpOperatorDec;
 rec.Model:=SRpOperatorDecM;
 rec.params:=SRpOperatorDecP;
 lista1.addobject(rec.rfunction,rec);

 LCategory.Itemindex:=0;
 LCategoryClick(self);
end;

procedure TFRpExpredialogVCL.FormDestroy(Sender: TObject);
var
 i,j:integer;
begin
  inherited;
 if FExpressionStreamResult <> nil then
  FExpressionStreamResult.Free;
 for i:=0 to FMaxlisthelp-1 do
 begin
  for j:=0 to llistes[i].count-1 do
  begin
   llistes[i].objects[j].freE;
  end;
  llistes[i].free;
 end;
end;

procedure TFRpExpredialogVCL.MemoExpreChange(Sender: TObject);
begin
 if FExpressionChat <> nil then
  FExpressionChat.SetCurrentExpression(MemoExpre.Text);
end;

procedure TFRpExpredialogVCL.ResetExpressionStreamState;
begin
 if FExpressionStreamResult <> nil then
 begin
  FExpressionStreamResult.Free;
  FExpressionStreamResult := nil;
 end;
 FExpressionStreamError := '';
end;

function TFRpExpredialogVCL.ExpressionStreamCancelRequested(Sender: TObject): Boolean;
begin
 Result := FCancelExpressionRequest;
end;

function TFRpExpredialogVCL.GetExpressionPrefillPercent(const AStage,
  AChunkType: string): Integer;
begin
 if SameText(AStage, 'PreparingContext') then
  Result := 10
 else if SameText(AStage, 'SendingRequest') then
  Result := 45
 else if SameText(AStage, 'ReceivingResponse') then
 begin
  if SameText(AChunkType, 'Start') then
   Result := 70
  else
   Result := 100;
 end
 else
  Result := 100;
end;

procedure TFRpExpredialogVCL.ExpressionStreamProgress(Sender: TObject;
  const AStage, AChunkType, AChunk: string; AOutputTokens: Integer);
var
 LChunk: string;
 LPrefill: Integer;
begin
 LChunk := '';
 if SameText(AStage, 'ReceivingResponse') and SameText(AChunkType, 'Partial') then
  LChunk := AChunk;
 LPrefill := GetExpressionPrefillPercent(AStage, AChunkType);
 TThread.Queue(nil,
  procedure
  begin
   if FExpressionChat <> nil then
    FExpressionChat.UpdateStreamingResponse(LChunk, LPrefill);
  end);
end;

procedure TFRpExpredialogVCL.ExpressionStreamResult(Sender: TObject;
  AResultJson: TJSONObject; const AErrorMessage: string);
begin
 if AErrorMessage <> '' then
  FExpressionStreamError := AErrorMessage;
 if AResultJson <> nil then
 begin
  if FExpressionStreamResult <> nil then
   FExpressionStreamResult.Free;
  FExpressionStreamResult := AResultJson;
 end;
end;

function TFRpExpredialogVCL.ExtractExpressionFromApiResult(
  AResultJson: TJSONObject; out AExpression, AExplanation,
  AErrorMessage: string): Boolean;
var
 LResultObj: TJSONObject;
begin
 Result := False;
 AExpression := '';
 AExplanation := '';
 AErrorMessage := FExpressionStreamError;
 if AErrorMessage <> '' then
  Exit;
 if AResultJson = nil then
 begin
  AErrorMessage := 'No final response received';
  Exit;
 end;

 if (AResultJson.Values['errorMessage'] <> nil) and
   (AResultJson.Values['errorMessage'].Value <> '') then
 begin
  AErrorMessage := AResultJson.Values['errorMessage'].Value;
  Exit;
 end;

 LResultObj := AResultJson.Values['result'] as TJSONObject;
 if LResultObj = nil then
 begin
  AErrorMessage := 'Response without result';
  Exit;
 end;

 if LResultObj.Values['expression'] <> nil then
  AExpression := LResultObj.Values['expression'].Value;
 if LResultObj.Values['explanation'] <> nil then
  AExplanation := LResultObj.Values['explanation'].Value;

 if AExpression = '' then
 begin
  if (LResultObj.Values['errorMessage'] <> nil) and
    (LResultObj.Values['errorMessage'].Value <> '') then
    AErrorMessage := LResultObj.Values['errorMessage'].Value
  else
    AErrorMessage := 'Empty expression returned';
  Exit;
 end;

 Result := True;
end;

function TFRpExpredialogVCL.ValidateExpressionText(const AExpression: string;
  out AErrorMessage: string): Boolean;
var
 LOldExpression: string;
begin
 Result := False;
 AErrorMessage := '';
 if evaluator = nil then
 begin
  Result := Trim(AExpression) <> '';
  if not Result then
    AErrorMessage := 'Empty expression returned';
  Exit;
 end;

 LOldExpression := evaluator.Expression;
 try
  evaluator.Expression := AExpression;
  evaluator.CheckSyntax;
  Result := True;
 except
  on E: Exception do
  begin
   AErrorMessage := E.Message;
   Result := False;
  end;
 end;
 evaluator.Expression := LOldExpression;
end;

procedure TFRpExpredialogVCL.StopExpressionRequest(Sender: TObject);
begin
 FCancelExpressionRequest := True;
end;

function TFRpExpredialogVCL.BuildExpressionSemanticContextJson: string;
var
 LRoot: TJSONObject;
 LFields: TJSONArray;
 LIdentifiers: TJSONArray;
 LFieldList: TStringList;
 LFieldObj: TJSONObject;
 LIdentifierObj: TJSONObject;
 I: Integer;
 LIdentifier: TRpIdentifier;
{$IFDEF USEEVALHASH}
 LIterator: TstrHashIterator;
{$ENDIF}
begin
 LRoot := TJSONObject.Create;
 try
  LFields := TJSONArray.Create;
  LIdentifiers := TJSONArray.Create;
  LRoot.AddPair('fields', LFields);
  LRoot.AddPair('identifiers', LIdentifiers);

  if (evaluator <> nil) and (evaluator.Rpalias <> nil) then
  begin
   LFieldList := TStringList.Create;
   try
    evaluator.Rpalias.FillWithFields(LFieldList);
    for I := 0 to LFieldList.Count - 1 do
    begin
      LFieldObj := TJSONObject.Create;
      LFieldObj.AddPair('name', LFieldList[I]);
      LFields.AddElement(LFieldObj);
    end;
   finally
    LFieldList.Free;
   end;
  end;

  if evaluator <> nil then
  begin
{$IFDEF USEEVALHASH}
   LIterator := evaluator.Identifiers.GetIterator;
   while LIterator.HasNext do
   begin
    LIterator.Next;
    LIdentifier := TRpIdentifier(LIterator.GetValue);
    LIdentifierObj := TJSONObject.Create;
    LIdentifierObj.AddPair('name', LIterator.GetKey);
    LIdentifierObj.AddPair('kind', IntToStr(Integer(LIdentifier.RType)));
    LIdentifierObj.AddPair('help', LIdentifier.Help);
    LIdentifierObj.AddPair('model', LIdentifier.Model);
    LIdentifierObj.AddPair('params', LIdentifier.aparams);
    LIdentifiers.AddElement(LIdentifierObj);
   end;
{$ENDIF}
{$IFNDEF USEEVALHASH}
   for I := 0 to evaluator.Identifiers.Count - 1 do
   begin
    LIdentifier := TRpIdentifier(evaluator.Identifiers.Objects[I]);
    LIdentifierObj := TJSONObject.Create;
    LIdentifierObj.AddPair('name', evaluator.Identifiers[I]);
    LIdentifierObj.AddPair('kind', IntToStr(Integer(LIdentifier.RType)));
    LIdentifierObj.AddPair('help', LIdentifier.Help);
    LIdentifierObj.AddPair('model', LIdentifier.Model);
    LIdentifierObj.AddPair('params', LIdentifier.aparams);
    LIdentifiers.AddElement(LIdentifierObj);
   end;
{$ENDIF}
  end;

  Result := LRoot.ToJSON;
 finally
  LRoot.Free;
 end;
end;

procedure TFRpExpredialogVCL.LCategoryClick(Sender: TObject);
begin
  inherited;
 Litems.items.Assign(llistes[lcategory.itemindex]);
 Lhelp.Caption:='';
 Lparams.caption:='';
 Lmodel.caption:='';
end;

procedure TFRpExpredialogVCL.LItemsClick(Sender: TObject);
begin
  inherited;
 if litems.itemindex>-1 then
 begin
  Lhelp.caption:=(llistes[lcategory.itemindex].objects[litems.itemindex]
      As TRpRecHelp).help;
  Lparams.caption:=(llistes[lcategory.itemindex].objects[litems.itemindex]
      As TRpRecHelp).params;
  Lmodel.caption:=(llistes[lcategory.itemindex].objects[litems.itemindex]
      As TRpRecHelp).model;
 end
 else
 begin
  Lhelp.Caption:='';
  Lparams.caption:='';
  Lmodel.caption:='';
 end;
end;

procedure TFRpExpredialogVCL.BCheckSynClick(Sender: TObject);
begin
  inherited;
 evaluator.Expression:=Memoexpre.text;
 try
  evaluator.CheckSyntax;
 except
  on E:Exception do
  begin
   MemoExpre.SetFocus;
   MemoExpre.SelStart:=evaluator.PosError;
   MemoExpre.SelLength:=0;
   raise Exception.Create(E.Message);
  end;
 end;
end;

procedure TFRpExpredialogVCL.BShowResultClick(Sender: TObject);
begin
 evaluator.Expression:=Memoexpre.text;
 try
  evaluator.evaluate;
 except
  On E:Exception do
  begin
   MemoExpre.SetFocus;
   MemoExpre.SelStart:=evaluator.PosError;
   MemoExpre.SelLength:=0;
   raise Exception.Create(E.MEssage);
  end;
  On E:TRpEvalException do
  begin
   MemoExpre.SetFocus;
   MemoExpre.SelStart:=E.ErrorPosition;
   MemoExpre.SelLength:=0;
   raise Exception.Create(E.MEssage + ' at position ' + IntToStr(E.ErrorPosition));
  end;
 end;
 RpShowmessage(TRpValueToString(evaluator.EvalResult));
end;

procedure TFRpExpredialogVCL.BitBtn1Click(Sender: TObject);
begin
  inherited;
 if litems.itemindex>-1 then
  memoexpre.text:=memoexpre.text+litems.Items.strings[litems.itemindex];
end;

procedure TFRpExpredialogVCL.LItemsDblClick(Sender: TObject);
begin
  inherited;
 if litems.itemindex>-1 then
  memoexpre.text:=memoexpre.text+litems.Items.strings[litems.itemindex];
end;

procedure TFRpExpredialogVCL.ExpressionChatSendPrompt(Sender: TObject; const APrompt,
  AExpression: string);
var
 LAITier: string;
 LAIMode: string;
 LAgentSecret: string;
 LAgentAiId: Int64;
 LCursorPosition: Integer;
 LPrompt: string;
 LSemanticContext: string;
begin
 if FExpressionChat = nil then
  Exit;

 LPrompt := Trim(APrompt);
 if LPrompt = '' then
  Exit;

 LAITier := FExpressionChat.GetAITier;
 LAIMode := FExpressionChat.GetAIMode;
 LAgentSecret := FExpressionChat.GetAgentSecret;
 LAgentAiId := FExpressionChat.GetAgentAiId;
 LCursorPosition := MemoExpre.SelStart;
 LSemanticContext := BuildExpressionSemanticContextJson;

 FCancelExpressionRequest := False;
 ResetExpressionStreamState;
 FExpressionChat.BeginStreamingResponse;

 TTask.Run(
   procedure
   var
    LCurrentExpression: string;
    LErrorMessage: string;
    LExpression: string;
      LExplanation: string;
    LHttp: TRpDatabaseHttp;
    LNeedRetry: Boolean;
    LRetryMessage: string;
    LUserProfile: TJSONObject;
   begin
    LCurrentExpression := AExpression;
    LNeedRetry := False;
    LRetryMessage := '';
    LHttp := TRpDatabaseHttp.Create;
    try
        try
          LHttp.Token := TRpAuthManager.Instance.Token;
          LHttp.InstallId := TRpAuthManager.Instance.InstallId;
          LHttp.AITier := LAITier;
          LHttp.AgentSecret := LAgentSecret;
          LHttp.AgentAiId := LAgentAiId;

          repeat
            ResetExpressionStreamState;
            if LNeedRetry then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  if FExpressionChat <> nil then
                  begin
                    FExpressionChat.AddAssistantMessage('Local validation failed. Running one automatic fix.');
                    FExpressionChat.BeginStreamingResponse;
                  end;
                end);
            end;

            LHttp.SuggestExpressionStream(LPrompt, LCurrentExpression, LCursorPosition,
              LAIMode, LNeedRetry, LSemanticContext, Self, ExpressionStreamProgress,
              ExpressionStreamResult, ExpressionStreamCancelRequested);

            if FCancelExpressionRequest then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  if FExpressionChat <> nil then
                  begin
                    FExpressionChat.FinishStreamingResponse;
                    FExpressionChat.AddAssistantMessage('Generation stopped.');
                  end;
                end);
              Exit;
            end;

            if not ExtractExpressionFromApiResult(FExpressionStreamResult,
              LExpression, LExplanation, LErrorMessage) then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  if FExpressionChat <> nil then
                  begin
                    FExpressionChat.FinishStreamingResponse;
                    FExpressionChat.AddAssistantMessage(LErrorMessage);
                  end;
                end);
              Exit;
            end;

            LUserProfile := nil;
            if (FExpressionStreamResult <> nil) and (FExpressionStreamResult.Values['userProfile'] is TJSONObject) then
              LUserProfile := TJSONObject((FExpressionStreamResult.Values['userProfile'] as TJSONObject).Clone);
            if LUserProfile <> nil then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  try
                    if FExpressionChat <> nil then
                      FExpressionChat.UpdateUserProfile(LUserProfile);
                  finally
                    LUserProfile.Free;
                  end;
                end);
            end;

            if (not LNeedRetry) and (not ValidateExpressionText(LExpression, LErrorMessage)) then
            begin
              LCurrentExpression := LExpression;
              LNeedRetry := True;
              Continue;
            end;

            if LNeedRetry and (not ValidateExpressionText(LExpression, LErrorMessage)) then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  if FExpressionChat <> nil then
                  begin
                    FExpressionChat.FinishStreamingResponse;
                    FExpressionChat.AddAssistantMessage('Generated expression is still invalid after one automatic fix: ' + LErrorMessage);
                  end;
                end);
              Exit;
            end;

            if LNeedRetry then
          begin
            if Trim(LExplanation) <> '' then
              LRetryMessage := 'Expression fixed after local validation.' +
                sLineBreak + sLineBreak + LExplanation
            else
              LRetryMessage := 'Expression fixed after local validation.';
          end
            else
          begin
            if Trim(LExplanation) <> '' then
              LRetryMessage := LExplanation
            else
              LRetryMessage := 'Expression generated.';
          end;

            TThread.Queue(nil,
              procedure
              begin
                if FExpressionChat <> nil then
                  FExpressionChat.SetSuggestedExpression(LExpression, LRetryMessage);
              end);
            Break;
          until False;
        except
          on E: Exception do
          begin
            TThread.Queue(nil,
              procedure
              begin
                if FExpressionChat <> nil then
                begin
                  FExpressionChat.FinishStreamingResponse;
                  FExpressionChat.AddAssistantMessage(E.Message);
                end;
              end);
          end;
        end;
    finally
      LHttp.Free;
    end;
   end);
end;

procedure TFRpExpredialogVCL.ExpressionChatApplySuggestion(Sender: TObject;
  const AExpression: string);
begin
 MemoExpre.Text := AExpression;
 MemoExpre.SetFocus;
 MemoExpre.SelStart := Length(MemoExpre.Text);
 MemoExpre.SelLength := 0;
end;


function ChangeExpression(formul:string;aval:TRpCustomEvaluator):string;
var
 dia:TFRpExpredialogVCL;
begin
  dia:=TFRpExpredialogVCL.create(Application);
  try
   if not assigned(aval) then
    dia.evaluator:=TRpEvaluator.Create(dia)
   else
    dia.evaluator:=aval;
   dia.MemoExpre.text:=formul;
   result:=formul;
   dia.showmodal;
   if dia.dook then
    result:=dia.MemoExpre.text;
  finally
   dia.freE;
  end;
end;

function ChangeExpressionW(formul:Widestring;aval:TRpCustomEvaluator):Widestring;
var
 dia:TFRpExpredialogVCL;
begin
  dia:=TFRpExpredialogVCL.create(Application);
  try
   if not assigned(aval) then
    dia.evaluator:=TRpEvaluator.Create(dia)
   else
    dia.evaluator:=aval;
   dia.MemoExpre.text:=formul;
   result:=formul;
   dia.showmodal;
   if dia.dook then
    result:=dia.MemoExpre.text;
  finally
   dia.freE;
  end;
end;

function ExpressionCalculateW(formul:Widestring;aval:TRpCustomEvaluator):Variant;
var
 dia:TFRpExpredialogVCL;
begin
  Result:=Null;
  dia:=TFRpExpredialogVCL.create(Application);
  try
   dia.validate:=true;
   dia.MEmoExpre.WantReturns:=false;
   if not assigned(aval) then
    dia.evaluator:=TRpEvaluator.Create(dia)
   else
    dia.evaluator:=aval;
   dia.MemoExpre.text:=formul;
   result:=dia.AResult;
   dia.showmodal;
   if dia.dook then
    result:=dia.AResult;
  finally
   dia.freE;
  end;
end;


function TRpExpreDialogVCL.Execute:Boolean;
var
 dia:TFRpExpredialogVCL;
begin
  Fevaluator.Rpalias:=FRpalias;
  dia:=TFRpExpredialogVCL.create(Application);
  try
   dia.evaluator:=Fevaluator;
   dia.MemoExpre.text:=Expresion.text;
   dia.ShowModal;
   result:=dia.dook;
   if result then
    Expresion.text:=dia.MemoExpre.text;
  finally
   dia.freE;
  end;
end;

procedure TFRpExpredialogVCL.BOKClick(Sender: TObject);
begin
 if validate then
 begin
  evaluator.Expression:=Memoexpre.text;
  try
   evaluator.evaluate;
   AResult:=evaluator.EvalResult;
  except
   on E:Exception do
   begin
    MemoExpre.SetFocus;
    MemoExpre.SelStart:=evaluator.PosError;
    MemoExpre.SelLength:=0;
    Raise Exception.Create(E.MEssage);
   end;
  end;
 end;
 dook:=true;
 Close;
end;

end.
