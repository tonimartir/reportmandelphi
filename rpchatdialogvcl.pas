{*******************************************************}
{                                                       }
{       Rpchatdialogvcl                                 }
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

unit rpchatdialogvcl;

interface

{$I rpconf.inc}
{$R rpexpredlg.dcr}

uses
  Winapi.Windows,
  SysUtils, Classes,
  DB,
  Graphics,Controls, Forms, Dialogs, Messages,
  StdCtrls, ExtCtrls,Buttons,
  System.JSON, System.Threading,
  rpalias,rpeval, rptypeval,rpgraphutilsvcl,
{$IFDEF USEEVALHASH}
  rphashtable,rpstringhash,
{$ENDIF}
{$IFDEF USEVARIANTS}
  Variants,
{$ENDIF}
  rpmdconsts, rpfrmchatvcl, rpdatahttp, rpreport, rpmetafile;

const
 FMaxlisthelp=5;
 SExpressionChatInitialMessage='Ask for help rewriting, simplifying or validating the current expression.';
 SDesignChatInitialMessage='Use this chat to describe report design changes. Design backend wiring will be added in a later phase.';
type
  TRpChatMode = (rcmExpression, rcmDesign);

  TRpQueuedExpressionChatPayloadKind = (
    rpqecUpdateStreamingResponse,
    rpqecBeginRetry,
    rpqecGenerationStopped,
    rpqecAddAssistantMessage,
    rpqecSetSuggestedExpression,
    rpqecUpdateUserProfile
  );

  TRpQueuedExpressionChatPayload = class(TObject)
  public
    Kind: TRpQueuedExpressionChatPayloadKind;
    Text1: string;
    Text2: string;
    PrefillPercent: Integer;
    UserProfile: TJSONObject;
    destructor Destroy; override;
  end;

  TRpQueuedExpressionRefreshPayload = class(TObject)
  public
    RequestVersion: Integer;
    ErrorMessage: string;
  end;

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
    FReport: TRpReport;
    FPrintDriver: TRpPrintDriver;
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
    property Report: TRpReport read FReport write FReport;
    property PrintDriver: TRpPrintDriver read FPrintDriver write FPrintDriver;
  published
    { Published declarations }
    property Expresion:TStrings read FExpresion write setexpresion;
    property Rpalias:TRpalias read FRpalias
     write SetRpalias;
    property evaluator:TRpEvaluator read Fevaluator write Fevaluator;
  end;

  TRpChatDialogComponent = TRpExpreDialogVCL;

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
    BRefresh: TButton;
    BShowResult: TButton;
    BCheckSyn: TButton;
    BAdd: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure LCategoryClick(Sender: TObject);
    procedure LItemsClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure BCheckSynClick(Sender: TObject);
    procedure BShowResultClick(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure LItemsDblClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure MemoExpreChange(Sender: TObject);
    procedure BRefreshClick(Sender: TObject);
  private
    { Private declarations }
    validate:Boolean;
    dook:boolean;
    AResult:Variant;
    Fevaluator:TRpCustomEvaluator;
    FOwnsEvaluator: Boolean;
    FChatMode: TRpChatMode;
    FCancelExpressionRequest: Boolean;
    FChat: TFRpChatFrame;
    FExpressionCursorPosition: Integer;
    FExpressionStreamError: string;
    FExpressionStreamResult: TJSONObject;
    FRefreshReport: TRpReport;
    FRefreshPrintDriver: TRpPrintDriver;
    FRefreshAlias: TRpAlias;
    FEmptyAlias: TRpAlias;
    FRefreshVersion: Integer;
    FRefreshRunning: Boolean;
    FAliasReady: Boolean;
    llistes:array[0..FMaxlisthelp-1] of TStringlist;
    procedure ClearHelpLists;
    procedure ConfigureReportRefresh(AReport: TRpReport;
      APrintDriver: TRpPrintDriver; ATargetAlias: TRpAlias);
    procedure InitializeDialog(const AExpression: string;
      AEvaluator: TRpCustomEvaluator; AOwnsEvaluator, AValidate,
      AWantReturns: Boolean; AChatMode: TRpChatMode = rcmExpression);
    function BuildRefreshSnapshotEvaluator: TRpEvaluator;
    function CloneAlias(AOwner: TComponent; ASource: TRpAlias): TRpAlias;
    procedure ReleaseOwnedEvaluator;
    procedure AssignEmptyAlias;
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
    procedure UpdateExpressionCursorPosition;
    procedure ChatApplySuggestion(Sender: TObject; const AExpression: string);
    procedure ChatSendPrompt(Sender: TObject; const APrompt, AExpression: string);
    procedure SendExpressionPrompt(const APrompt, AExpression: string);
    procedure SendDesignPrompt(const APrompt, AExpression: string);
    procedure MemoExpreClick(Sender: TObject);
    procedure MemoExpreKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MemoExpreMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure WMHandleExpressionChatPayload(var Message: TMessage); message WM_USER + 204;
    procedure WMHandleExpressionRefresh(var Message: TMessage); message WM_USER + 205;
    procedure WMStartOnlineInitialization(var Message: TMessage); message WM_USER + 201;
    procedure PopulateAliasFromReport(ATargetAlias: TRpAlias);
    procedure PostExpressionChatPayload(APayload: TRpQueuedExpressionChatPayload);
    procedure StartReportRefresh;
    procedure SetChatMode(AMode: TRpChatMode);
    procedure UpdateRefreshUIState;
    procedure Setevaluator(aval:TRpCustomEvaluator);
  public
    { Public declarations }
    property evaluator:TRpCustomEvaluator read fevaluator write setevaluator;
    property ChatMode: TRpChatMode read FChatMode write SetChatMode;
  end;

  TFRpChatDialogVCL = TFRpExpredialogVCL;

function ChangeExpression(formul:string;aval:TRpCustomEvaluator):string;
function ChangeExpressionW(formul:Widestring;aval:TRpCustomEvaluator):Widestring;
function ExpressionCalculateW(formul:Widestring;aval:TRpCustomEvaluator):Variant;



implementation

{$R *.dfm}
uses rplabelitem, rpauthmanager;

var
 GSharedExpreDialogVCL: TFRpExpredialogVCL = nil;

destructor TRpQueuedExpressionChatPayload.Destroy;
begin
 if UserProfile <> nil then
  UserProfile.Free;
 inherited Destroy;
end;

function GetSharedExpreDialogVCL: TFRpExpredialogVCL;
begin
 if GSharedExpreDialogVCL=nil then
  GSharedExpreDialogVCL:=TFRpExpredialogVCL.Create(Application);
 Result:=GSharedExpreDialogVCL;
end;

function GetSemanticFieldDataType(AFieldType: TFieldType): string;
begin
 case AFieldType of
  ftString, ftWideString, ftFixedChar:
    Result := 'string';
  ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint:
    Result := 'integer';
  ftFloat, ftBCD, ftFMTBcd, ftSingle, ftExtended:
    Result := 'float';
  ftCurrency:
    Result := 'currency';
  ftDate:
    Result := 'date';
  ftTime:
    Result := 'time';
  ftDateTime:
    Result := 'datetime';
  ftBoolean:
    Result := 'boolean';
  ftMemo, ftWideMemo:
    Result := 'memo';
  ftBlob, ftGraphic, ftBytes, ftVarBytes:
    Result := 'blob';
 else
  Result := 'unknown';
 end;
end;



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
 MemoExpre.OnClick := MemoExpreClick;
 MemoExpre.OnKeyUp := MemoExpreKeyUp;
 MemoExpre.OnMouseUp := MemoExpreMouseUp;
 FCancelExpressionRequest := False;
 FChatMode := rcmExpression;
 FExpressionCursorPosition := MemoExpre.SelStart;
 FExpressionStreamError := '';
 FExpressionStreamResult := nil;
 FOwnsEvaluator := False;
 FRefreshReport := nil;
 FRefreshPrintDriver := nil;
 FRefreshAlias := nil;
 FRefreshVersion := 0;
 FRefreshRunning := False;
 FAliasReady := True;
 FEmptyAlias := TRpAlias.Create(Self);
 FChat := TFRpChatFrame.Create(Self);
 FChat.Parent := PChatHost;
 FChat.Align := alClient;
 FChat.OnSendPrompt := ChatSendPrompt;
 FChat.OnApplySuggestion := ChatApplySuggestion;
 FChat.OnStopRequest := StopExpressionRequest;
 FChat.Initialize(MemoExpre.Text, SExpressionChatInitialMessage);
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
 BRefresh.Caption:='Refresh';
 BCheckSyn.Caption:=TranslateStr(244,BCheckSyn.Caption);
 BShowResult.Caption:=TranslateStr(246,BShowResult.Caption);
 LCategory.Items.Strings[0]:=TranslateStr(247,LCategory.Items.Strings[0]);
 LCategory.Items.Strings[1]:=TranslateStr(248,LCategory.Items.Strings[1]);
 LCategory.Items.Strings[2]:=TranslateStr(249,LCategory.Items.Strings[2]);
 LCategory.Items.Strings[3]:=TranslateStr(250,LCategory.Items.Strings[3]);
 LCategory.Items.Strings[4]:=TranslateStr(251,LCategory.Items.Strings[4]);
 
end;

procedure TFRpExpredialogVCL.ConfigureReportRefresh(AReport: TRpReport;
  APrintDriver: TRpPrintDriver; ATargetAlias: TRpAlias);
begin
 FRefreshReport := AReport;
 FRefreshPrintDriver := APrintDriver;
 FRefreshAlias := ATargetAlias;
 FRefreshVersion := 0;
 FRefreshRunning := False;
 if FRefreshReport <> nil then
 begin
  FAliasReady := False;
  AssignEmptyAlias;
 end
 else
  FAliasReady := evaluator <> nil;
 UpdateRefreshUIState;
end;

procedure TFRpExpredialogVCL.ReleaseOwnedEvaluator;
begin
 if FOwnsEvaluator and (Fevaluator<>nil) then
 begin
  Fevaluator.Free;
  Fevaluator:=nil;
 end;
 FOwnsEvaluator:=False;
end;

procedure TFRpExpredialogVCL.ClearHelpLists;
var
 i,j:integer;
begin
 for i:=0 to FMaxlisthelp-1 do
 begin
  if llistes[i]=nil then
   continue;
  for j:=0 to llistes[i].count-1 do
   llistes[i].objects[j].free;
  llistes[i].clear;
 end;
end;

procedure TFRpExpredialogVCL.InitializeDialog(const AExpression: string;
  AEvaluator: TRpCustomEvaluator; AOwnsEvaluator, AValidate,
  AWantReturns: Boolean; AChatMode: TRpChatMode = rcmExpression);
begin
 dook:=False;
 AResult:=Null;
 validate:=AValidate;
 SetChatMode(AChatMode);
 MemoExpre.WantReturns:=AWantReturns;
 FCancelExpressionRequest:=False;
 ResetExpressionStreamState;
 if (Fevaluator<>AEvaluator) and FOwnsEvaluator then
  ReleaseOwnedEvaluator;
 FOwnsEvaluator:=AOwnsEvaluator;
 Setevaluator(AEvaluator);
 MemoExpre.Text:=AExpression;
 if FChat<>nil then
 begin
  if FChatMode = rcmDesign then
   FChat.Initialize(MemoExpre.Text, SDesignChatInitialMessage)
  else
   FChat.Initialize(MemoExpre.Text, SExpressionChatInitialMessage);
 end;
 MemoExpre.SelStart:=Length(MemoExpre.Text);
 MemoExpre.SelLength:=0;
 UpdateExpressionCursorPosition;
   FAliasReady := evaluator <> nil;
   UpdateRefreshUIState;
end;

function TFRpExpredialogVCL.CloneAlias(AOwner: TComponent;
  ASource: TRpAlias): TRpAlias;
var
 I: Integer;
 LNewItem: TRpAliasListItem;
begin
 Result := TRpAlias.Create(AOwner);
 if ASource = nil then
  Exit;

 for I := 0 to ASource.List.Count - 1 do
 begin
  LNewItem := Result.List.Add;
  LNewItem.Alias := ASource.List.Items[I].Alias;
  LNewItem.Dataset := ASource.List.Items[I].Dataset;
 end;
end;

function TFRpExpredialogVCL.BuildRefreshSnapshotEvaluator: TRpEvaluator;
var
 LAliasSnapshot: TRpAlias;
begin
 Result := TRpEvaluator.Create(nil);
 if FRefreshReport <> nil then
  FRefreshReport.AddReportItemsToEvaluator(Result);

 if FAliasReady and (FRefreshAlias <> nil) then
  LAliasSnapshot := CloneAlias(Result, FRefreshAlias)
 else
  LAliasSnapshot := CloneAlias(Result, nil);

 Result.Rpalias := LAliasSnapshot;
end;

  procedure TFRpExpredialogVCL.AssignEmptyAlias;
  begin
   if FEmptyAlias <> nil then
    FEmptyAlias.List.Clear;
   if evaluator <> nil then
    evaluator.Rpalias := FEmptyAlias;
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
 ClearHelpLists;
 if aval=nil then
 begin
  UpdateRefreshUIState;
  exit;
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
 UpdateRefreshUIState;
end;

procedure TFRpExpredialogVCL.FormDestroy(Sender: TObject);
var
 i:integer;
begin
  inherited;
 ReleaseOwnedEvaluator;
 if FExpressionStreamResult <> nil then
  FExpressionStreamResult.Free;
 ClearHelpLists;
 for i:=0 to FMaxlisthelp-1 do
  llistes[i].free;
 if GSharedExpreDialogVCL=Self then
  GSharedExpreDialogVCL:=nil;
end;

procedure TFRpExpredialogVCL.FormShow(Sender: TObject);
begin
  inherited;
  ActiveControl:=MemoExpre;
  if MemoExpre.CanFocus then
    MemoExpre.SetFocus;
  MemoExpre.SelStart:=Length(MemoExpre.Text);
  MemoExpre.SelLength:=0;
  UpdateExpressionCursorPosition;
  if HandleAllocated then
    PostMessage(Handle, WM_USER + 201, 0, 0);
  if FChat <> nil then
    TThread.Queue(nil,
      procedure
      begin
        if (FChat <> nil) and Visible then
          FChat.Resize;
      end);
  if FRefreshReport <> nil then
    StartReportRefresh;
end;

procedure TFRpExpredialogVCL.WMStartOnlineInitialization(var Message: TMessage);
begin
  if (FChat<>nil) and Visible then
    FChat.StartOnlineInitialization;
end;

procedure TFRpExpredialogVCL.PostExpressionChatPayload(
  APayload: TRpQueuedExpressionChatPayload);
begin
  if APayload = nil then
    Exit;
  if HandleAllocated then
    PostMessage(Handle, WM_USER + 204, WPARAM(APayload), 0)
  else
    APayload.Free;
end;

procedure TFRpExpredialogVCL.WMHandleExpressionChatPayload(var Message: TMessage);
var
  LPayload: TRpQueuedExpressionChatPayload;
begin
  LPayload := TRpQueuedExpressionChatPayload(Message.WParam);
  try
    if (LPayload = nil) or (FChat = nil) then
      Exit;

    case LPayload.Kind of
      rpqecUpdateStreamingResponse:
        FChat.UpdateStreamingResponse(LPayload.Text1, LPayload.PrefillPercent);
      rpqecBeginRetry:
        begin
          FChat.AddAssistantMessage('Local validation failed. Running one automatic fix.');
          FChat.BeginStreamingResponse;
        end;
      rpqecGenerationStopped:
        begin
          FChat.FinishStreamingResponse;
          FChat.AddAssistantMessage('Generation stopped.');
        end;
      rpqecAddAssistantMessage:
        begin
          FChat.FinishStreamingResponse;
          FChat.AddAssistantMessage(LPayload.Text1);
        end;
      rpqecSetSuggestedExpression:
        FChat.SetSuggestedExpression(LPayload.Text1, LPayload.Text2);
      rpqecUpdateUserProfile:
        begin
          if LPayload.UserProfile <> nil then
          begin
            FChat.UpdateUserProfile(LPayload.UserProfile);
            LPayload.UserProfile := nil;
          end;
        end;
    end;
  finally
    LPayload.Free;
  end;
end;

procedure TFRpExpredialogVCL.UpdateRefreshUIState;
begin
 PBottom.Visible := FChatMode = rcmExpression;
 BCheckSyn.Visible := FChatMode = rcmExpression;
 BShowResult.Visible := FChatMode = rcmExpression;
 BRefresh.Visible := (FChatMode = rcmExpression) and (FRefreshReport <> nil);
 if FRefreshRunning then
  BRefresh.Caption := 'Refreshing...'
 else
  BRefresh.Caption := 'Refresh';
end;

procedure TFRpExpredialogVCL.SetChatMode(AMode: TRpChatMode);
begin
 if FChatMode = AMode then
 begin
  UpdateRefreshUIState;
  Exit;
 end;

 FChatMode := AMode;
 if FChatMode = rcmDesign then
  validate := False;
 UpdateRefreshUIState;
end;

procedure TFRpExpredialogVCL.PopulateAliasFromReport(ATargetAlias: TRpAlias);
var
 I: Integer;
 LItem: TRpAliasListItem;
begin
 if (ATargetAlias = nil) or (FRefreshReport = nil) then
  Exit;

 ATargetAlias.List.Clear;
 for I := 0 to FRefreshReport.DataInfo.Count - 1 do
 begin
  LItem := ATargetAlias.List.Add;
  LItem.Alias := FRefreshReport.DataInfo.Items[I].Alias;
{$IFDEF USERPDATASET}
  if FRefreshReport.DataInfo.Items[I].Cached then
   LItem.Dataset := FRefreshReport.DataInfo.Items[I].CachedDataset
  else
{$ENDIF}
   LItem.Dataset := FRefreshReport.DataInfo.Items[I].Dataset;
 end;
end;

procedure TFRpExpredialogVCL.StartReportRefresh;
var
 LWorker: TThread;
 LRequestVersion: Integer;
 LReport: TRpReport;
 LPrintDriver: TRpPrintDriver;
begin
 if FRefreshRunning then
  Exit;
 if (FRefreshReport = nil) or (FRefreshPrintDriver = nil) then
  Exit;

 Inc(FRefreshVersion);
 LRequestVersion := FRefreshVersion;
 LReport := FRefreshReport;
 LPrintDriver := FRefreshPrintDriver;
 if not FOwnsEvaluator then
 begin
  Setevaluator(BuildRefreshSnapshotEvaluator);
  FOwnsEvaluator := True;
 end;
 FRefreshRunning := True;
 UpdateRefreshUIState;

 LWorker := TThread.CreateAnonymousThread(
   procedure
   var
    LPayload: TRpQueuedExpressionRefreshPayload;
   begin
    LPayload := TRpQueuedExpressionRefreshPayload.Create;
    try
      LPayload.RequestVersion := LRequestVersion;
      try
        LReport.BeginPrint(LPrintDriver);
      except
        on E: Exception do
          LPayload.ErrorMessage := E.Message;
      end;

      if HandleAllocated then
        PostMessage(Handle, WM_USER + 205, WPARAM(LPayload), 0)
      else
        LPayload.Free;
      LPayload := nil;
    finally
      LPayload.Free;
    end;
   end);
 LWorker.FreeOnTerminate := True;
 LWorker.Start;
end;

procedure TFRpExpredialogVCL.WMHandleExpressionRefresh(var Message: TMessage);
var
 LPayload: TRpQueuedExpressionRefreshPayload;
begin
 LPayload := TRpQueuedExpressionRefreshPayload(Message.WParam);
 try
  if LPayload = nil then
    Exit;
  if LPayload.RequestVersion <> FRefreshVersion then
    Exit;

  FRefreshRunning := False;
  if LPayload.ErrorMessage <> '' then
  begin
    FAliasReady := False;
    UpdateRefreshUIState;
    RpShowMessage(LPayload.ErrorMessage);
    Exit;
  end;

  PopulateAliasFromReport(FRefreshAlias);
  if FRefreshReport <> nil then
  begin
    if FOwnsEvaluator then
      ReleaseOwnedEvaluator;
    FOwnsEvaluator := False;
    if FRefreshReport.Evaluator <> nil then
      FRefreshReport.Evaluator.Rpalias := FRefreshAlias;
    Setevaluator(FRefreshReport.Evaluator);
  end;
  FAliasReady := True;
  UpdateRefreshUIState;
 finally
  LPayload.Free;
 end;
end;
procedure TFRpExpredialogVCL.MemoExpreChange(Sender: TObject);
begin
 UpdateExpressionCursorPosition;
 if FChat <> nil then
  FChat.SetCurrentExpression(MemoExpre.Text);
end;

procedure TFRpExpredialogVCL.UpdateExpressionCursorPosition;
begin
 if MemoExpre <> nil then
  FExpressionCursorPosition := MemoExpre.SelStart;
end;

procedure TFRpExpredialogVCL.MemoExpreClick(Sender: TObject);
begin
 UpdateExpressionCursorPosition;
end;

procedure TFRpExpredialogVCL.MemoExpreKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
 UpdateExpressionCursorPosition;
end;

procedure TFRpExpredialogVCL.MemoExpreMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
 UpdateExpressionCursorPosition;
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
 LPayload: TRpQueuedExpressionChatPayload;
 LPrefill: Integer;
begin
 LChunk := '';
 if SameText(AStage, 'ReceivingResponse') and SameText(AChunkType, 'Partial') then
  LChunk := AChunk;
 LPrefill := GetExpressionPrefillPercent(AStage, AChunkType);
 LPayload := TRpQueuedExpressionChatPayload.Create;
 LPayload.Kind := rpqecUpdateStreamingResponse;
 LPayload.Text1 := LChunk;
 LPayload.PrefillPercent := LPrefill;
 PostExpressionChatPayload(LPayload);
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
  if Trim(AExplanation) <> '' then
    AErrorMessage := AExplanation
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
 AErrorMessage := '';
 if FChatMode = rcmDesign then
 begin
  Result := Trim(AExpression) <> '';
  if not Result then
    AErrorMessage := 'Empty design content returned';
  Exit;
 end;

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
 LAlias: string;
 LAliasItem: TRpAliasListItem;
 LDataset: TDataSet;
 LField: TField;
 LRoot: TJSONObject;
 LFields: TJSONArray;
 LIdentifiers: TJSONArray;
 LFunctions: TJSONArray;
 LVariables: TJSONArray;
 LConstants: TJSONArray;
 LFieldObj: TJSONObject;
 I: Integer;
 J: Integer;
 LIdentifier: TRpIdentifier;
{$IFDEF USEEVALHASH}
 LIterator: TstrHashIterator;
{$ENDIF}
  function CreateIdentifierObject(const AName: string;
    AIdentifier: TRpIdentifier): TJSONObject;
  begin
    Result := TJSONObject.Create;
    Result.AddPair('name', AName);
    Result.AddPair('kind', IntToStr(Integer(AIdentifier.RType)));
    Result.AddPair('help', AIdentifier.Help);
    Result.AddPair('model', AIdentifier.Model);
    Result.AddPair('params', AIdentifier.aparams);
  end;

  procedure AddIdentifierToCategories(const AName: string;
    AIdentifier: TRpIdentifier);
  begin
    LIdentifiers.AddElement(CreateIdentifierObject(AName, AIdentifier));

    if AIdentifier is TIdenRpExpression then
    begin
      LVariables.AddElement(CreateIdentifierObject(AName, AIdentifier));
      Exit;
    end;

    case AIdentifier.RType of
      RTypeidenfunction:
        LFunctions.AddElement(CreateIdentifierObject(AName, AIdentifier));
      RTypeidenvariable:
        LVariables.AddElement(CreateIdentifierObject(AName, AIdentifier));
      RTypeidenconstant:
        LConstants.AddElement(CreateIdentifierObject(AName, AIdentifier));
    end;
  end;
begin
 if FChatMode = rcmDesign then
 begin
  Result := '{}';
  Exit;
 end;

 LRoot := TJSONObject.Create;
 try
  LFields := TJSONArray.Create;
  LIdentifiers := TJSONArray.Create;
  LFunctions := TJSONArray.Create;
  LVariables := TJSONArray.Create;
  LConstants := TJSONArray.Create;
  LRoot.AddPair('fields', LFields);
  LRoot.AddPair('identifiers', LIdentifiers);
  LRoot.AddPair('functions', LFunctions);
  LRoot.AddPair('variables', LVariables);
  LRoot.AddPair('constants', LConstants);

  if (evaluator <> nil) and (evaluator.Rpalias <> nil) then
  begin
    for I := 0 to evaluator.Rpalias.List.Count - 1 do
    begin
      LAliasItem := evaluator.Rpalias.List.Items[I];
      if LAliasItem = nil then
        Continue;
      LDataset := LAliasItem.Dataset;
      if LDataset = nil then
        Continue;

      LAlias := LAliasItem.Alias;
      for J := 0 to LDataset.FieldCount - 1 do
      begin
        LField := LDataset.Fields[J];
        LFieldObj := TJSONObject.Create;
        LFieldObj.AddPair('name', LAlias + '.' + LField.FieldName);
        LFieldObj.AddPair('dataset', LAlias);
        LFieldObj.AddPair('field', LField.FieldName);
        LFieldObj.AddPair('dataType', GetSemanticFieldDataType(LField.DataType));
        LFields.AddElement(LFieldObj);
      end;
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
   AddIdentifierToCategories(LIterator.GetKey, LIdentifier);
   end;
{$ENDIF}
{$IFNDEF USEEVALHASH}
   for I := 0 to evaluator.Identifiers.Count - 1 do
   begin
    LIdentifier := TRpIdentifier(evaluator.Identifiers.Objects[I]);
   AddIdentifierToCategories(evaluator.Identifiers[I], LIdentifier);
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
   On E:TRpEvalException do
  begin
   MemoExpre.SetFocus;
   MemoExpre.SelStart:=E.ErrorPosition;
   MemoExpre.SelLength:=0;
   raise Exception.Create(E.MEssage + ' at position ' + IntToStr(E.ErrorPosition));
  end;
  On E:Exception do
  begin
   MemoExpre.SetFocus;
   MemoExpre.SelStart:=evaluator.PosError;
   MemoExpre.SelLength:=0;
   raise Exception.Create(E.MEssage);
  end;

 end;
 RpShowmessage(TRpValueToString(evaluator.EvalResult));
end;

procedure TFRpExpredialogVCL.BRefreshClick(Sender: TObject);
begin
 StartReportRefresh;
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

procedure TFRpExpredialogVCL.ChatSendPrompt(Sender: TObject; const APrompt,
  AExpression: string);
begin
 case FChatMode of
  rcmDesign:
   SendDesignPrompt(APrompt, AExpression);
 else
   SendExpressionPrompt(APrompt, AExpression);
 end;
end;

procedure TFRpExpredialogVCL.SendExpressionPrompt(const APrompt,
  AExpression: string);
var
 LAITier: string;
 LAIMode: string;
 LAgentSecret: string;
 LAgentAiId: Int64;
 LCursorPosition: Integer;
 LPrompt: string;
 LSemanticContext: string;
 LWorker: TThread;
begin
 if FChat = nil then
  Exit;

 LPrompt := Trim(APrompt);
 if LPrompt = '' then
  Exit;

 LAITier := FChat.GetAITier;
 LAIMode := FChat.GetAIMode;
 LAgentSecret := FChat.GetAgentSecret;
 LAgentAiId := FChat.GetAgentAiId;
 UpdateExpressionCursorPosition;
 LCursorPosition := FExpressionCursorPosition;
 LSemanticContext := BuildExpressionSemanticContextJson;

 FCancelExpressionRequest := False;
 ResetExpressionStreamState;
 FChat.BeginStreamingResponse;

 LWorker := TThread.CreateAnonymousThread(
   procedure
   var
    LCurrentExpression: string;
    LErrorMessage: string;
    LExpression: string;
      LExplanation: string;
      LChatPayload: TRpQueuedExpressionChatPayload;
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
              LChatPayload := TRpQueuedExpressionChatPayload.Create;
              LChatPayload.Kind := rpqecBeginRetry;
              PostExpressionChatPayload(LChatPayload);
            end;

            LHttp.SuggestExpressionStream(LPrompt, LCurrentExpression, LCursorPosition,
              LAIMode, LNeedRetry, LSemanticContext, Self, ExpressionStreamProgress,
              ExpressionStreamResult, ExpressionStreamCancelRequested);

            if FCancelExpressionRequest then
            begin
              LChatPayload := TRpQueuedExpressionChatPayload.Create;
              LChatPayload.Kind := rpqecGenerationStopped;
              PostExpressionChatPayload(LChatPayload);
              Exit;
            end;

            if not ExtractExpressionFromApiResult(FExpressionStreamResult,
              LExpression, LExplanation, LErrorMessage) then
            begin
              LChatPayload := TRpQueuedExpressionChatPayload.Create;
              LChatPayload.Kind := rpqecAddAssistantMessage;
              LChatPayload.Text1 := LErrorMessage;
              PostExpressionChatPayload(LChatPayload);
              Exit;
            end;

            LUserProfile := nil;
            if (FExpressionStreamResult <> nil) and (FExpressionStreamResult.Values['userProfile'] is TJSONObject) then
              LUserProfile := TJSONObject((FExpressionStreamResult.Values['userProfile'] as TJSONObject).Clone);
            if LUserProfile <> nil then
            begin
              LChatPayload := TRpQueuedExpressionChatPayload.Create;
              LChatPayload.Kind := rpqecUpdateUserProfile;
              LChatPayload.UserProfile := LUserProfile;
              LUserProfile := nil;
              PostExpressionChatPayload(LChatPayload);
            end;

            if (not LNeedRetry) and (not ValidateExpressionText(LExpression, LErrorMessage)) then
            begin
              LCurrentExpression := LExpression;
              LNeedRetry := True;
              Continue;
            end;

            if LNeedRetry and (not ValidateExpressionText(LExpression, LErrorMessage)) then
            begin
              if Trim(LExplanation) <> '' then
                LRetryMessage := 'Generated expression is still invalid after one automatic fix: ' +
                  LErrorMessage + sLineBreak + sLineBreak + LExplanation +
                  sLineBreak + sLineBreak + 'You can still apply it and edit it manually.'
              else
                LRetryMessage := 'Generated expression is still invalid after one automatic fix: ' +
                  LErrorMessage + sLineBreak + sLineBreak +
                  'You can still apply it and edit it manually.';

              LChatPayload := TRpQueuedExpressionChatPayload.Create;
              LChatPayload.Kind := rpqecSetSuggestedExpression;
              LChatPayload.Text1 := LExpression;
              LChatPayload.Text2 := LRetryMessage;
              PostExpressionChatPayload(LChatPayload);
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

            LChatPayload := TRpQueuedExpressionChatPayload.Create;
            LChatPayload.Kind := rpqecSetSuggestedExpression;
            LChatPayload.Text1 := LExpression;
            LChatPayload.Text2 := LRetryMessage;
            PostExpressionChatPayload(LChatPayload);
            Break;
          until False;
        except
          on E: Exception do
          begin
            LChatPayload := TRpQueuedExpressionChatPayload.Create;
            LChatPayload.Kind := rpqecAddAssistantMessage;
            LChatPayload.Text1 := E.Message;
            PostExpressionChatPayload(LChatPayload);
          end;
        end;
    finally
      LHttp.Free;
    end;
  end);
 LWorker.FreeOnTerminate := True;
 LWorker.Start;
end;

procedure TFRpExpredialogVCL.SendDesignPrompt(const APrompt,
  AExpression: string);
var
 LChatPayload: TRpQueuedExpressionChatPayload;
begin
 if Trim(APrompt) = '' then
  Exit;

 if FChat <> nil then
  FChat.SetBusy(False);

 LChatPayload := TRpQueuedExpressionChatPayload.Create;
 LChatPayload.Kind := rpqecAddAssistantMessage;
 LChatPayload.Text1 := 'Design mode has been separated from expression mode. Backend request wiring is pending in this phase.';
 PostExpressionChatPayload(LChatPayload);
end;

procedure TFRpExpredialogVCL.ChatApplySuggestion(Sender: TObject;
  const AExpression: string);
begin
 MemoExpre.Text := AExpression;
 MemoExpre.SetFocus;
 MemoExpre.SelStart := Length(MemoExpre.Text);
 MemoExpre.SelLength := 0;
 UpdateExpressionCursorPosition;
end;


function ChangeExpression(formul:string;aval:TRpCustomEvaluator):string;
var
 dia:TFRpExpredialogVCL;
begin
  dia:=GetSharedExpreDialogVCL;
  if not assigned(aval) then
   dia.InitializeDialog(formul,TRpEvaluator.Create(nil),True,False,True)
  else
   dia.InitializeDialog(formul,aval,False,False,True);
  result:=formul;
  dia.showmodal;
  if dia.dook then
   result:=dia.MemoExpre.text;
end;

function ChangeExpressionW(formul:Widestring;aval:TRpCustomEvaluator):Widestring;
var
 dia:TFRpExpredialogVCL;
begin
  dia:=GetSharedExpreDialogVCL;
  if not assigned(aval) then
   dia.InitializeDialog(formul,TRpEvaluator.Create(nil),True,False,True)
  else
   dia.InitializeDialog(formul,aval,False,False,True);
  result:=formul;
  dia.showmodal;
  if dia.dook then
   result:=dia.MemoExpre.text;
end;

function ExpressionCalculateW(formul:Widestring;aval:TRpCustomEvaluator):Variant;
var
 dia:TFRpExpredialogVCL;
begin
  Result:=Null;
  dia:=GetSharedExpreDialogVCL;
  if not assigned(aval) then
   dia.InitializeDialog(formul,TRpEvaluator.Create(nil),True,True,False)
  else
   dia.InitializeDialog(formul,aval,False,True,False);
  result:=dia.AResult;
  dia.showmodal;
  if dia.dook then
   result:=dia.AResult;
end;


function TRpExpreDialogVCL.Execute:Boolean;
var
 dia:TFRpExpredialogVCL;
begin
  dia:=GetSharedExpreDialogVCL;
  if FReport <> nil then
  begin
   dia.InitializeDialog(Expresion.text,TRpEvaluator.Create(nil),True,False,True);
   dia.ConfigureReportRefresh(FReport, FPrintDriver, FRpalias);
  end
  else
  begin
   Fevaluator.Rpalias:=FRpalias;
   dia.InitializeDialog(Expresion.text,Fevaluator,False,False,True);
   dia.ConfigureReportRefresh(nil, nil, nil);
  end;
  dia.ShowModal;
  result:=dia.dook;
  if result then
   Expresion.text:=dia.MemoExpre.text;
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

initialization

finalization
 if GSharedExpreDialogVCL<>nil then
  GSharedExpreDialogVCL.Free;

end.
