{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpmpagesetup                                    }
{       Page setup dialog for a report                  }
{       avaliable in runtime and design time            }
{                                                       }
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

unit rppagesetuplcl;

interface

{$I rpconf.inc}

uses
  SysUtils,
{$IFDEF USEVARIANTS}
  Types,
{$ENDIF}
  Classes,rpmunits,
  Graphics, Controls, Forms, Dialogs,
  StdCtrls,rpreport, ExtCtrls,Buttons,Printers,
  rptypes,rpbasereport,Contnrs,
  rpmetafile,rpmdconsts,ComCtrls, rpmaskedit,
  rpmdfembeddedfilelcl,rpmdprintconfiglcl;

type
  TFRpPageSetupVCL = class(TForm)
    PControl: TPageControl;
    TabPage: TTabSheet;
    TabPrint: TTabSheet;
    Panel1: TPanel;
    BOK: TButton;
    BCancel: TButton;
    SColor: TShape;
    RPageSize: TRadioGroup;
    GPageSize: TGroupBox;
    ComboPageSize: TComboBox;
    RPageOrientation: TRadioGroup;
    RCustomOrientation: TRadioGroup;
    BBackground: TButton;
    GPageMargins: TGroupBox;
    LLeft: TLabel;
    LTop: TLabel;
    LMetrics3: TLabel;
    LMetrics4: TLabel;
    LMetrics5: TLabel;
    LRight: TLabel;
    LBottom: TLabel;
    LMetrics6: TLabel;
    ELeftMargin: TRpMaskEdit;
    ETopMargin: TRpMaskEdit;
    ERightMargin: TRpMaskEdit;
    EBottomMargin: TRpMaskEdit;
    GUserDefined: TGroupBox;
    LMetrics7: TLabel;
    LMetrics8: TLabel;
    LWidth: TLabel;
    LHeight: TLabel;
    EPageheight: TRpMaskEdit;
    EPageWidth: TRpMaskEdit;
    ColorDialog1: TColorDialog;
    LSelectPrinter: TLabel;
    ComboSelPrinter: TComboBox;
    BConfigure: TButton;
    CheckPrintOnlyIfData: TCheckBox;
    CheckTwoPass: TCheckBox;
    LCopies: TLabel;
    ECopies: TRpMaskEdit;
    CheckCollate: TCheckBox;
    LPrinterFonts: TLabel;
    ComboPrinterFonts: TComboBox;
    LRLang: TLabel;
    ComboLanguage: TComboBox;
    LPreview: TLabel;
    ComboPreview: TComboBox;
    ComboStyle: TComboBox;
    TabOptions: TTabSheet;
    LPreferedFormat: TLabel;
    ComboFormat: TComboBox;
    CheckDrawerAfter: TCheckBox;
    CheckDrawerBefore: TCheckBox;
    CheckPreviewAbout: TCheckBox;
    CheckMargins: TCheckBox;
    ComboPaperSource: TComboBox;
    LPaperSource: TLabel;
    ComboDuplex: TComboBox;
    LDuplex: TLabel;
    EForceFormName: TRpMaskEdit;
    LForceFormName: TLabel;
    EPaperSource: TRpMaskEdit;
    LLinesperInch: TLabel;
    ELinesPerInch: TRpMaskEdit;
    CheckDefaultCopies: TCheckBox;
    GPDF: TGroupBox;
    LabelPDFConformance: TLabel;
    ComboBoxPDFConformance: TComboBox;
    LabelCompressed: TLabel;
    CheckBoxPDFCompressed: TCheckBox;
    GEmbedded: TGroupBox;
    PEmbeddedButtons: TPanel;
    BNewFile: TButton;
    BDeleteFile: TButton;
    BModifyFile: TButton;
    ListViewEmbedded: TListView;
    TabMetadata: TTabSheet;
    LabelDocAuthor: TLabel;
    textDocAuthor: TEdit;
    labelDocTitle: TLabel;
    textDocTitle: TEdit;
    labeldocSubject: TLabel;
    textDocSubject: TEdit;
    LabelDocKeywords: TLabel;
    textDocKeywords: TEdit;
    labelDocCreator: TLabel;
    textDocCreator: TEdit;
    LabelDocProducer: TLabel;
    textDocProducer: TEdit;
    labelCreationDate: TLabel;
    textDocCreationDate: TEdit;
    labelModifyDate: TLabel;
    textDocModDate: TEdit;
    LabelXmpContent: TLabel;
    TextXMPContent: TMemo;
    procedure BCancelClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure SColorMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure BBackgroundClick(Sender: TObject);
    procedure RPageSizeClick(Sender: TObject);
    procedure RPageOrientationClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure BConfigureClick(Sender: TObject);
    procedure EPaperSourceChange(Sender: TObject);
    procedure ComboPaperSourceClick(Sender: TObject);
    procedure CheckDefaultCopiesClick(Sender: TObject);
    procedure BNewFileClick(Sender: TObject);
    procedure BDeleteFileClick(Sender: TObject);
    procedure BModifyFileClick(Sender: TObject);
    procedure ListViewEmbeddedDblClick(Sender: TObject);
  private
    { Private declarations }
    FReport:TRpBaseReport;
    oldleftmargin,oldtopmargin,oldrightmargin,oldbottommargin:string;
    oldcustompagewidth,oldcustompageheight:string;
    dook:boolean;
    FOptionsRead:boolean;
    // Copies of the embedded files of the report: the report gets them on OK
    FEmbeddedFiles:TObjectList;
    procedure SaveOptions;
    procedure LayoutControls;
    procedure SetReport(AReport:TRpBaseReport);
    function GetEmbeddedFile(Index:Integer):TEmbeddedFile;
    function GetEmbeddedFileCount:Integer;
  public
    { Public declarations }
    // Shows the options of the report (ExecutePageSetup does it before
    // showing the dialog)
    procedure ReadOptions;
    procedure UpdateEmbeddedList;
    // Embedded files of the dialog (the report changes on OK). Adding one
    // loads AFileName and asks for its properties (AskEmbeddedFileData)
    function AddEmbeddedFile(const AFileName:string):boolean;
    function ModifyEmbeddedFile(AIndex:Integer):boolean;
    procedure DeleteEmbeddedFile(AIndex:Integer);
    property Report:TRpBaseReport read FReport write SetReport;
    property EmbeddedFileCount:Integer read GetEmbeddedFileCount;
    property EmbeddedFiles[Index:Integer]:TEmbeddedFile read GetEmbeddedFile;
    // True after OK: the options were saved to the report
    property Accepted:boolean read dook;
  end;


function ExecutePageSetup(report:TRpBaseReport):boolean;

// Mime type for a file to embed, from its extension
function RpMimeTypeFromFileName(const AFileName:string):string;

implementation

uses
 Math;

{$R *.lfm}

function ExecutePageSetup(report:TRpBaseReport):boolean;
var
 dia:TFRpPageSetupVCL;
begin
 dia:=TFRpPageSetupVCL.Create(Application);
 try
  dia.Report:=report;
  dia.ShowModal;
  Result:=dia.dook;
 finally
  dia.free;
 end;
end;

function RpMimeTypeFromFileName(const AFileName:string):string;
var
 aext:string;
begin
 aext:=LowerCase(ExtractFileExt(AFileName));
 if aext='.xml' then
  Result:='application/xml'
 else
 if aext='.pdf' then
  Result:='application/pdf'
 else
 if (aext='.jpg') or (aext='.jpeg') then
  Result:='image/jpeg'
 else
 if (aext='.png') or (aext='.bmp') or (aext='.gif') or (aext='.tiff') then
  Result:='image/'+Copy(aext,2,Length(aext))
 else
 if aext='.tif' then
  Result:='image/tiff'
 else
 if aext='.txt' then
  Result:='text/plain'
 else
 if aext='.csv' then
  Result:='text/csv'
 else
 if (aext='.htm') or (aext='.html') then
  Result:='text/html'
 else
 if aext='.json' then
  Result:='application/json'
 else
 if aext='.xlsx' then
  Result:='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
 else
 if aext='.docx' then
  Result:='application/vnd.openxmlformats-officedocument.wordprocessingml.document'
 else
 if aext='.pptx' then
  Result:='application/vnd.openxmlformats-officedocument.presentationml.presentation'
 else
  Result:='application/octet-stream';
end;

procedure TFRpPageSetupVCL.BCancelClick(Sender: TObject);
begin
 Close;
end;

procedure TFRpPageSetupVCL.FormCreate(Sender: TObject);
var
 astring:widestring;
 awidth:integer;
 aheight:integer;
 i:integer;
begin
 FEmbeddedFiles:=TObjectList.Create(true);
 PControl.ActivePage:=TabPage;
 CheckDefaultCopies.Caption:=SRpDefaultCopies;
 LMetrics3.Caption:=rpunitlabels[defaultunit];
 LMetrics4.Caption:=LMetrics3.Caption;
 LMetrics5.Caption:=LMetrics3.Caption;
 LMetrics6.Caption:=LMetrics3.Caption;
 LMetrics7.Caption:=LMetrics3.Caption;
 LMetrics8.Caption:=LMetrics3.Caption;
 GetLanguageDescriptions(ComboLanguage.Items);
 ComboLanguage.Items.Insert(0,TranslateStr(95,'Default'));
 for i:=0 to 148 do
 begin
  astring:=PageSizeNames[i];
  awidth:=Round(PageSizeArray[i].Width/1000*TWIPS_PER_INCHESS);
  aheight:=Round(PageSizeArray[i].Height/1000*TWIPS_PER_INCHESS);
  astring:=astring+' ('+gettextfromtwips(awidth)+'x'+
   gettextfromtwips(aheight)+') '+rpunitlabels[defaultunit];
  ComboPageSize.Items.Add(astring);
 end;
 BOK.Caption:=TranslateStr(93,BOK.Caption);
 BCancel.Caption:=TranslateStr(94,BCancel.Caption);
 RPageSize.Items.Strings[0]:=TranslateStr(95,RPageSize.Items.Strings[0]);
 RPageSize.Items.Strings[1]:=TranslateStr(96,RPageSize.Items.Strings[1]);
 RPageSize.Items.Strings[2]:=TranslateStr(732,RPageSize.Items.Strings[2]);
 RPageOrientation.Items.Strings[0]:=TranslateStr(95,RPageOrientation.Items.Strings[0]);
 RPageOrientation.Items.Strings[1]:=TranslateStr(96,RPageOrientation.Items.Strings[1]);
 RPageSize.Caption:=TranslateStr(97,RPageSize.Caption);
 GPageSize.Caption:=TranslateStr(104,GPageSize.Caption);
 GUserDefined.Caption:=TranslateStr(733,GPageSize.Caption);
 LWidth.Caption:=SRpSWidth;
 LHeight.Caption:=SRpSHeight;
 RPageOrientation.Caption:=TranslateStr(98,RPageOrientation.Caption);
 GPageMargins.Caption:=TranslateStr(99,GPagemargins.Caption);
 LLeft.Caption:=TranslateStr(100,LLeft.Caption);
 LRight.Caption:=TranslateStr(101,LRight.Caption);
 LTop.Caption:=TranslateStr(102,LTop.Caption);
 LBottom.Caption:=TranslateStr(103,LBottom.Caption);
 RCustomOrientation.Caption:=TranslateStr(105,RCustomOrientation.Caption);
 RCustomOrientation.Items.Strings[0]:=TranslateStr(106,RCustomOrientation.Items.Strings[0]);
 RCustomOrientation.Items.Strings[1]:=TranslateStr(107,RCustomOrientation.Items.Strings[1]);
 LCopies.Caption:=TranslateStr(108,LCopies.Caption);
 LLinesPerInch.Caption:=TranslateStr(1377,LLinesPerInch.Caption);
 CheckCollate.Caption:=TranslateStr(109,CheckCollate.Caption);
 Caption:=TranslateStr(110,Caption);
 CheckTwoPass.Caption:=TranslateStr(111,CheckTwoPass.Caption);
 CheckPrintOnlyIfData.Caption:=TranslateStr(800,CheckPrintOnlyIfData.Caption);
 LRLang.Caption:=TranslateStr(112,LRLang.Caption);
 LPrinterFonts.Caption:=TranslateStr(113,LPrinterFonts.Caption);
 ComboPrinterFonts.Items.Strings[0]:=TranslateStr(95,ComboPrinterFonts.Items.Strings[0]);
 ComboPrinterFonts.Items.Strings[1]:=TranslateStr(114,ComboPrinterFonts.Items.Strings[1]);
 ComboPrinterFonts.Items.Strings[2]:=TranslateStr(115,ComboPrinterFonts.Items.Strings[2]);
 ComboPrinterFonts.Items.Strings[3]:=TranslateStr(1433,ComboPrinterFonts.Items.Strings[3]);
 BBAckground.Caption:=TranslateStr(116,BBAckground.Caption);
 CheckPreviewAbout.Caption:=SRpAboutBoxPreview;
 with ComboSelPrinter.Items do
 begin
  Add(SRpDefaultPrinter);
  Add(SRpReportPrinter);
  Add(SRpTicketPrinter);
  Add(SRpGraphicprinter);
  Add(SRpCharacterprinter);
  Add(SRpReportPrinter2);
  Add(SRpTicketPrinter2);
  Add(SRpUserPrinter1);
  Add(SRpUserPrinter2);
  Add(SRpUserPrinter3);
  Add(SRpUserPrinter4);
  Add(SRpUserPrinter5);
  Add(SRpUserPrinter6);
  Add(SRpUserPrinter7);
  Add(SRpUserPrinter8);
  Add(SRpUserPrinter9);
  Add(SRpPlainPrinter);
  Add(SRpPlainFullPrinter);
 end;
 LSelectPrinter.Caption:=TranslateStr(741,LSelectPrinter.Caption);
 LPaperSOurce.Caption:=SRpPaperSource;
 LForceFormName.Caption:=SRpForceForm;
 LDuplex.Caption:=SRpDuplex;
 BConfigure.Caption:=TranslateStr(143,BConfigure.Caption);
 LPreview.Caption:=TranslateStr(840,LPreview.Caption);
 ComboPreview.Items.Strings[0]:=TranslateStr(841,ComboPreview.Items.Strings[0]);
 ComboPreview.Items.Strings[1]:=TranslateStr(842,ComboPreview.Items.Strings[1]);
 ComboStyle.Items.Strings[0]:=TranslateStr(843,ComboStyle.Items.Strings[0]);
 ComboStyle.Items.Strings[1]:=TranslateStr(844,ComboStyle.Items.Strings[1]);
 ComboStyle.Items.Strings[2]:=TranslateStr(845,ComboStyle.Items.Strings[2]);
 CheckMargins.Caption:=SRpPreviewMargins;
 TabPage.Caption:=TranslateStr(857,TabPage.Caption);
 TabPrint.Caption:=TranslateStr(858,TabPrint.Caption);
 TabOptions.Caption:=SRpSOptions;
 LPreferedFormat.Caption:=SRpPreferedFormat;
 ComboFormat.Items.Add(SRpStreamZLib);
 ComboFormat.Items.Add(SRpStreamText);
 ComboFormat.Items.Add(SRpStreamBinary);
 ComboFormat.Items.Add(SRpStreamXML);
 ComboFormat.Items.Add(SRpStreamXMLComp);
 CheckDrawerAfter.Caption:=SRpOpenDrawerAfter;
 CheckDrawerBefore.Caption:=SRpOpenDrawerBefore;
 GetPaperSourceDescriptions(ComboPaperSource.Items);
 GetDuplexDescriptions(ComboDuplex.Items);

 // PDF options, embedded files and metadata (as rppagesetupvcl)
 GPDF.Caption:=SRpPDFOptions;
 LabelCompressed.Caption:=SRpCompressed;
 BNewFile.Caption:=SRpAdd;
 BDeleteFile.Caption:=SRpDelete;
 BModifyFile.Caption:=SRpModify;
 GEmbedded.Caption:=SRpEmbeddedFiles;
 LabelPDFConformance.Caption:=SRpConformance;
 TabMetadata.Caption:=SRpMetadata;
 LabelDocAuthor.Caption:=SRpDocAuthor;
 LabelDocTitle.Caption:=SRpDocTitle;
 LabelDocSubject.Caption:=SRpDocSubject;
 LabelDocCreator.Caption:=SRpDocCreator;
 LabelDocProducer.Caption:=SRpDocProducer;
 labelCreationDate.Caption:=SRpDocCreationDate;
 labelModifyDate.Caption:=SRpDocModifyDate;
 LabelDocKeywords.Caption:=SRpDocKeywords;
 LabelXMPContent.Caption:=SRpXMPmetadata;

 ListViewEmbedded.Columns[0].Caption:=SRpFilename;
 ListViewEmbedded.Columns[1].Caption:=SRpMimetype;
 ListViewEmbedded.Columns[2].Caption:=SRpSize;
 ListViewEmbedded.Columns[3].Caption:=SRpRelationShip;
 ListViewEmbedded.Columns[4].Caption:=SRpDescription;
 ListViewEmbedded.Columns[5].Caption:=SRpCreationDateISO;
 ListViewEmbedded.Columns[6].Caption:=SRpModificationDateISO;
 // After the translations: the widths come from the texts
 LayoutControls;
end;

// The positions of the lfm were made for the fonts of other widgetsets: the
// margins, the custom size and the user defined size did not fit in their
// groups (worse with GTK2, Qt and the translated texts). The controls are
// anchored one below the other, so the real heights of this widgetset place
// them (Qt gives the final ones only after showing the form), the columns
// come from the widths of the texts and the groups take the height of their
// content. The form grows when the estimated content of a page needs it.
procedure TFRpPageSetupVCL.LayoutControls;
var
 LBitmap:TBitmap;
 M,S,G,th:integer;
 edith,comboh,checkh,buttonh,radioh,rowh:integer;
 groupw,grouph,checkw,radiow:integer;
 pw,ph,dw,dh,dp:integer;
 col1,x,x2,lw,lw2,uw,ew,bw,h,i,w:integer;
 PRow1,PRow2:TPanel;
 LLabels:array[0..7] of TLabel;
 LEdits:array[0..7] of TEdit;
 LChecks:array[0..4] of TCheckBox;

 function TW(const AText:string):integer;
 begin
  Result:=LBitmap.Canvas.TextWidth(AText);
 end;

 function MaxTW(const ATexts:array of string):integer;
 var
  j:integer;
 begin
  Result:=0;
  for j:=0 to High(ATexts) do
   Result:=Max(Result,TW(ATexts[j]));
 end;

 // Height and width of a kind of control as the widgetset gives them before
 // showing the form (Qt gives smaller ones), not less than AMin
 function Probe(AControl:TWinControl;AMin:integer;out AWidth:integer):integer;
 var
  pwidth,pheight:integer;
 begin
  try
   AControl.Visible:=false;
   AControl.Parent:=Self;
   AControl.HandleNeeded;
   pwidth:=0;
   pheight:=0;
   AControl.GetPreferredSize(pwidth,pheight,true,false);
   AWidth:=pwidth;
   Result:=Max(pheight,AMin);
  finally
   AControl.Free;
  end;
 end;

 // The controls of a page are placed in its current client area
 procedure UsePage(APage:TTabSheet);
 begin
  pw:=APage.ClientWidth;
  ph:=APage.ClientHeight;
 end;

 // The form grows when the content of a page needs more room (dp is what
 // the bottom panel takes from the pages)
 procedure Need(AWidth,AHeight:integer);
 begin
  dw:=Max(dw,AWidth-pw);
  dh:=Max(dh,AHeight-(ph-dp));
 end;

 // Forgets the anchors of the lfm
 procedure Reset(AControl:TControl);
 var
  k:TAnchorKind;
 begin
  for k:=Low(TAnchorKind) to High(TAnchorKind) do
   AControl.AnchorSide[k].Control:=nil;
  AControl.Anchors:=[akLeft,akTop];
  AControl.BorderSpacing.Around:=0;
 end;

 // Left and top: at ALeft of the left side of the parent and below ABelow
 // (the top of the parent when nil)
 procedure PlaceAt(AControl:TControl;ALeft:integer;ABelow:TControl;ASpace:integer);
 begin
  Reset(AControl);
  AControl.AnchorParallel(akLeft,ALeft,AControl.Parent);
  if ABelow=nil then
   AControl.AnchorParallel(akTop,ASpace,AControl.Parent)
  else
   AControl.AnchorToNeighbour(akTop,ASpace,ABelow);
 end;

 // The right side at ASpace of the right side of the parent
 procedure ToRight(AControl:TControl;ASpace:integer);
 begin
  AControl.AnchorParallel(akRight,ASpace,AControl.Parent);
 end;

 // A label at ALeft, centered on the height of its editor
 procedure LabelFor(ALabel:TLabel;ALeft:integer;AEditor:TControl);
 begin
  Reset(ALabel);
  ALabel.AutoSize:=true;
  ALabel.AnchorParallel(akLeft,ALeft,ALabel.Parent);
  ALabel.AnchorVerticalCenterTo(AEditor);
 end;

 // A label (units) after its editor
 procedure UnitsFor(ALabel:TLabel;AEditor:TControl);
 begin
  Reset(ALabel);
  ALabel.AutoSize:=true;
  ALabel.AnchorToNeighbour(akLeft,Scale96ToScreen(4),AEditor);
  ALabel.AnchorVerticalCenterTo(AEditor);
 end;

 // A group that takes the height of its content (the width comes from its
 // anchors)
 procedure AutoHeight(AGroup:TWinControl);
 begin
  AGroup.ChildSizing.TopBottomSpacing:=S;
  AGroup.AutoSize:=true;
 end;

 function ButtonWidth(const ACaptions:array of string;AMin:integer):integer;
 begin
  Result:=Max(Scale96ToScreen(AMin),MaxTW(ACaptions)+Scale96ToScreen(24));
 end;

 function NewRow(ABelow:TControl;const AName:string):TPanel;
 begin
  Result:=TPanel.Create(Self);
  Result.Name:=AName;
  Result.BevelOuter:=bvNone;
  Result.Caption:='';
  Result.Parent:=TabPage;
  PlaceAt(Result,M,ABelow,M);
  ToRight(Result,M);
  Result.AutoSize:=true;
 end;

 // A group or radio group in a row, as high as the row
 procedure InRow(AControl:TWinControl;ARow:TPanel;ALeft:TControl;AWidth:integer);
 begin
  AControl.Parent:=ARow;
  Reset(AControl);
  if ALeft=nil then
   AControl.AnchorParallel(akLeft,0,ARow)
  else
   AControl.AnchorToNeighbour(akLeft,S,ALeft);
  AControl.AnchorParallel(akTop,0,ARow);
  AControl.AnchorParallel(akBottom,0,ARow);
  if AWidth>0 then
   AControl.Width:=AWidth
  else
   ToRight(AControl,0);
 end;

begin
 M:=Scale96ToScreen(8);
 S:=Scale96ToScreen(6);
 G:=Scale96ToScreen(8);
 HandleNeeded;
 LBitmap:=TBitmap.Create;
 try
  LBitmap.Canvas.Font:=Font;
  th:=LBitmap.Canvas.TextHeight('Xj');
  // Heights to estimate the size of the form: the anchors use the real ones
  edith:=Probe(TEdit.Create(nil),th+Scale96ToScreen(10),w);
  comboh:=Probe(TComboBox.Create(nil),th+Scale96ToScreen(10),w);
  checkh:=Probe(TCheckBox.Create(nil),th+Scale96ToScreen(6),checkw);
  // Width of the box and its space
  checkw:=Max(Scale96ToScreen(20),checkw);
  buttonh:=Probe(TButton.Create(nil),Max(Scale96ToScreen(25),th+Scale96ToScreen(12)),w);
  radioh:=Probe(TRadioButton.Create(nil),checkh,radiow);
  radiow:=Max(Scale96ToScreen(20),radiow);
  with TGroupBox.Create(nil) do
  begin
   try
    Visible:=false;
    Parent:=Self;
    Caption:='X';
    SetBounds(0,0,Scale96ToScreen(200),Scale96ToScreen(100));
    HandleNeeded;
    groupw:=Width-ClientWidth;
    grouph:=Height-ClientHeight;
   finally
    Free;
   end;
  end;
  groupw:=Max(Scale96ToScreen(4),Min(groupw,Scale96ToScreen(40)));
  grouph:=Max(th+Scale96ToScreen(10),Min(grouph,Scale96ToScreen(60)));
  rowh:=Max(edith,comboh);
  dw:=0;
  dh:=0;

  // OK and Cancel
  bw:=ButtonWidth([BOK.Caption,BCancel.Caption],101);
  dp:=buttonh+2*M-Panel1.Height;
  Panel1.Height:=buttonh+2*M;
  PlaceAt(BOK,M,nil,M);
  BOK.SetBounds(BOK.Left,BOK.Top,bw,buttonh);
  PlaceAt(BCancel,M+bw+S,nil,M);
  BCancel.SetBounds(BCancel.Left,BCancel.Top,bw,buttonh);

  // Page setup. Rows: page size (with the custom size or the user defined
  // one), orientation, margins, lines per inch and background color
  UsePage(TabPage);
  col1:=Max(Scale96ToScreen(177),
   MaxTW([RPageSize.Items[0],RPageSize.Items[1],RPageSize.Items[2],
    RPageOrientation.Items[0],RPageOrientation.Items[1]])+radiow+
   Scale96ToScreen(16)+groupw);
  col1:=Max(col1,MaxTW([RPageSize.Caption,RPageOrientation.Caption])+
   Scale96ToScreen(20)+groupw);
  PRow1:=NewRow(nil,'PSizeRow');
  // As high as the user defined size (estimated) from the start: the rows
  // below do not move when it is shown
  h:=Max(grouph+3*(radioh+Scale96ToScreen(4))+Scale96ToScreen(6),
   grouph+S+3*edith+2*S+S);
  PRow1.Constraints.MinHeight:=h;
  InRow(RPageSize,PRow1,nil,col1);
  InRow(GUserDefined,PRow1,RPageSize,0);
  InRow(GPageSize,PRow1,RPageSize,0);
  // User defined size: width, height and form name
  lw:=MaxTW([LWidth.Caption,LHeight.Caption,LForceFormName.Caption])+G;
  uw:=TW(LMetrics7.Caption);
  PlaceAt(EPageWidth,M+lw,nil,0);
  EPageWidth.AnchorToNeighbour(akRight,Scale96ToScreen(4),LMetrics7);
  Reset(LMetrics7);
  LMetrics7.AutoSize:=true;
  LMetrics7.AnchorParallel(akRight,M,GUserDefined);
  LMetrics7.AnchorVerticalCenterTo(EPageWidth);
  LMetrics7.Anchors:=[akTop,akRight];
  LabelFor(LWidth,M,EPageWidth);
  PlaceAt(EPageheight,M+lw,EPageWidth,S);
  EPageheight.AnchorToNeighbour(akRight,Scale96ToScreen(4),LMetrics8);
  Reset(LMetrics8);
  LMetrics8.AutoSize:=true;
  LMetrics8.AnchorParallel(akRight,M,GUserDefined);
  LMetrics8.AnchorVerticalCenterTo(EPageheight);
  LMetrics8.Anchors:=[akTop,akRight];
  LabelFor(LHeight,M,EPageheight);
  PlaceAt(EForceFormName,M+lw,EPageheight,S);
  EForceFormName.AnchorParallel(akRight,0,EPageheight);
  LabelFor(LForceFormName,M,EForceFormName);
  AutoHeight(GUserDefined);
  // The editors keep at least 80 pixels
  Need(M+col1+S+groupw+M+lw+Scale96ToScreen(80)+Scale96ToScreen(4)+uw+M+M,0);
  PlaceAt(ComboPageSize,M,nil,0);
  ToRight(ComboPageSize,M);
  AutoHeight(GPageSize);
  // Orientation
  PRow2:=NewRow(PRow1,'POrientationRow');
  PRow2.BorderSpacing.Top:=S;
  InRow(RPageOrientation,PRow2,nil,col1);
  InRow(RCustomOrientation,PRow2,RPageOrientation,0);
  // Margins, in two columns
  GPageMargins.Parent:=TabPage;
  PlaceAt(GPageMargins,M,PRow2,S);
  ToRight(GPageMargins,M);
  lw:=MaxTW([LLeft.Caption,LTop.Caption])+G;
  lw2:=MaxTW([LRight.Caption,LBottom.Caption])+G;
  uw:=TW(LMetrics3.Caption);
  ew:=Scale96ToScreen(90);
  x2:=M+lw+ew+Scale96ToScreen(4)+uw+3*G;
  PlaceAt(ELeftMargin,M+lw,nil,0);
  ELeftMargin.Width:=ew;
  LabelFor(LLeft,M,ELeftMargin);
  UnitsFor(LMetrics3,ELeftMargin);
  PlaceAt(ERightMargin,x2+lw2,nil,0);
  ERightMargin.Width:=ew;
  LabelFor(LRight,x2,ERightMargin);
  UnitsFor(LMetrics5,ERightMargin);
  PlaceAt(ETopMargin,M+lw,ELeftMargin,S);
  ETopMargin.Width:=ew;
  LabelFor(LTop,M,ETopMargin);
  UnitsFor(LMetrics4,ETopMargin);
  PlaceAt(EBottomMargin,x2+lw2,ELeftMargin,S);
  EBottomMargin.Width:=ew;
  LabelFor(LBottom,x2,EBottomMargin);
  UnitsFor(LMetrics6,EBottomMargin);
  AutoHeight(GPageMargins);
  Need(M+groupw+x2+lw2+ew+Scale96ToScreen(4)+uw+M+M,0);
  // Lines per inch
  lw:=TW(LLinesperInch.Caption)+G;
  PlaceAt(ELinesPerInch,M+lw,GPageMargins,S);
  ELinesPerInch.Width:=ew;
  LabelFor(LLinesperInch,M,ELinesPerInch);
  // Background color
  bw:=ButtonWidth([BBackground.Caption],149);
  PlaceAt(BBackground,M,ELinesPerInch,S);
  BBackground.SetBounds(BBackground.Left,BBackground.Top,bw,buttonh);
  Reset(SColor);
  SColor.AnchorToNeighbour(akLeft,S,BBackground);
  SColor.AnchorParallel(akTop,0,BBackground);
  SColor.SetBounds(SColor.Left,SColor.Top,buttonh,buttonh);
  PRow1.TabOrder:=0;
  PRow2.TabOrder:=1;
  GPageMargins.TabOrder:=2;
  ELinesPerInch.TabOrder:=3;
  BBackground.TabOrder:=4;
  Need(0,M+h+S+(grouph+2*(radioh+Scale96ToScreen(4))+Scale96ToScreen(6))+
   S+(grouph+S+2*edith+S+S)+S+edith+S+buttonh+M);

  // Print setup: a label and its combo boxes in each row
  UsePage(TabPrint);
  lw:=MaxTW([LPrinterFonts.Caption,LRLang.Caption,LPreview.Caption,
   LSelectPrinter.Caption,LPaperSource.Caption,LDuplex.Caption])+G;
  x:=M+lw;
  w:=Max(Scale96ToScreen(118),MaxTW([ComboPreview.Items[0],
   ComboPreview.Items[1]])+Scale96ToScreen(40));
  Need(x+w+S+Scale96ToScreen(120)+M,0);
  PlaceAt(ComboPrinterFonts,x,nil,M);
  ToRight(ComboPrinterFonts,M);
  LabelFor(LPrinterFonts,M,ComboPrinterFonts);
  PlaceAt(ComboLanguage,x,ComboPrinterFonts,S);
  ToRight(ComboLanguage,M);
  LabelFor(LRLang,M,ComboLanguage);
  PlaceAt(ComboPreview,x,ComboLanguage,S);
  ComboPreview.Width:=w;
  LabelFor(LPreview,M,ComboPreview);
  Reset(ComboStyle);
  ComboStyle.AnchorToNeighbour(akLeft,S,ComboPreview);
  ComboStyle.AnchorParallel(akTop,0,ComboPreview);
  ToRight(ComboStyle,M);
  PlaceAt(ComboSelPrinter,x,ComboPreview,S);
  ToRight(ComboSelPrinter,M);
  LabelFor(LSelectPrinter,M,ComboSelPrinter);
  // Paper source: its number and its name
  Reset(EPaperSource);
  EPaperSource.AnchorParallel(akLeft,x,TabPrint);
  EPaperSource.Width:=Scale96ToScreen(45);
  Reset(ComboPaperSource);
  ComboPaperSource.AnchorToNeighbour(akLeft,S,EPaperSource);
  ComboPaperSource.AnchorToNeighbour(akTop,S,ComboSelPrinter);
  ToRight(ComboPaperSource,M);
  EPaperSource.AnchorVerticalCenterTo(ComboPaperSource);
  LabelFor(LPaperSource,M,ComboPaperSource);
  PlaceAt(ComboDuplex,x,ComboPaperSource,S);
  ToRight(ComboDuplex,M);
  LabelFor(LDuplex,M,ComboDuplex);
  bw:=ButtonWidth([BConfigure.Caption],213);
  PlaceAt(BConfigure,M,ComboDuplex,S);
  BConfigure.SetBounds(BConfigure.Left,BConfigure.Top,bw,buttonh);
  // Copies and options: two columns
  LChecks[0]:=CheckCollate;
  LChecks[1]:=CheckTwoPass;
  LChecks[2]:=CheckPrintOnlyIfData;
  LChecks[3]:=CheckDrawerBefore;
  LChecks[4]:=CheckDrawerAfter;
  lw:=TW(LCopies.Caption)+G;
  w:=Max(bw,lw+Scale96ToScreen(69));
  for i:=0 to High(LChecks) do
   w:=Max(w,TW(LChecks[i].Caption)+checkw+Scale96ToScreen(8));
  x2:=M+w+Scale96ToScreen(16);
  Need(x2+MaxTW([CheckDefaultCopies.Caption,CheckPreviewAbout.Caption,
   CheckMargins.Caption])+checkw+Scale96ToScreen(8)+M,0);
  PlaceAt(ECopies,M+lw,BConfigure,S);
  ECopies.Width:=Scale96ToScreen(69);
  LabelFor(LCopies,M,ECopies);
  for i:=0 to High(LChecks) do
  begin
   if i=0 then
    PlaceAt(LChecks[i],M,ECopies,S)
   else
    PlaceAt(LChecks[i],M,LChecks[i-1],Scale96ToScreen(2));
   LChecks[i].AutoSize:=true;
  end;
  Reset(CheckDefaultCopies);
  CheckDefaultCopies.AutoSize:=true;
  CheckDefaultCopies.AnchorParallel(akLeft,x2,TabPrint);
  CheckDefaultCopies.AnchorVerticalCenterTo(ECopies);
  Reset(CheckPreviewAbout);
  CheckPreviewAbout.AutoSize:=true;
  CheckPreviewAbout.AnchorParallel(akLeft,x2,TabPrint);
  CheckPreviewAbout.AnchorParallel(akTop,0,CheckCollate);
  Reset(CheckMargins);
  CheckMargins.AutoSize:=true;
  CheckMargins.AnchorParallel(akLeft,x2,TabPrint);
  CheckMargins.AnchorParallel(akTop,0,CheckTwoPass);
  Need(0,M+6*(rowh+S)+buttonh+S+edith+S+5*(checkh+Scale96ToScreen(2))+M);

  // Options: save format, PDF options and embedded files
  UsePage(TabOptions);
  lw:=TW(LPreferedFormat.Caption)+G;
  PlaceAt(ComboFormat,M+lw,nil,M);
  ToRight(ComboFormat,M);
  LabelFor(LPreferedFormat,M,ComboFormat);
  PlaceAt(GPDF,M,ComboFormat,S);
  ToRight(GPDF,M);
  lw:=MaxTW([LabelPDFConformance.Caption,LabelCompressed.Caption])+G;
  PlaceAt(ComboBoxPDFConformance,M+lw,nil,0);
  ComboBoxPDFConformance.Width:=Scale96ToScreen(200);
  LabelFor(LabelPDFConformance,M,ComboBoxPDFConformance);
  PlaceAt(CheckBoxPDFCompressed,M+lw,ComboBoxPDFConformance,S);
  CheckBoxPDFCompressed.AutoSize:=true;
  LabelFor(LabelCompressed,M,CheckBoxPDFCompressed);
  AutoHeight(GPDF);
  // The list of files fills the rest of the page
  PlaceAt(GEmbedded,M,GPDF,S);
  ToRight(GEmbedded,M);
  GEmbedded.AnchorParallel(akBottom,M,TabOptions);
  bw:=ButtonWidth([BNewFile.Caption,BDeleteFile.Caption,BModifyFile.Caption],104);
  PEmbeddedButtons.Height:=buttonh+2*Scale96ToScreen(4);
  PlaceAt(BNewFile,Scale96ToScreen(4),nil,Scale96ToScreen(4));
  BNewFile.SetBounds(BNewFile.Left,BNewFile.Top,bw,buttonh);
  PlaceAt(BDeleteFile,Scale96ToScreen(4)+bw+S,nil,Scale96ToScreen(4));
  BDeleteFile.SetBounds(BDeleteFile.Left,BDeleteFile.Top,bw,buttonh);
  PlaceAt(BModifyFile,Scale96ToScreen(4)+2*(bw+S),nil,Scale96ToScreen(4));
  BModifyFile.SetBounds(BModifyFile.Left,BModifyFile.Top,bw,buttonh);
  Need(M+groupw+Scale96ToScreen(4)+3*(bw+S)+M,
   M+comboh+S+(grouph+S+comboh+S+checkh+S)+S+grouph+PEmbeddedButtons.Height+
   Scale96ToScreen(100)+M);

  // Metadata: a label and its text in each row, the XMP content fills the
  // rest of the page
  UsePage(TabMetadata);
  LLabels[0]:=LabelDocAuthor;
  LLabels[1]:=labelDocTitle;
  LLabels[2]:=labeldocSubject;
  LLabels[3]:=LabelDocKeywords;
  LLabels[4]:=labelDocCreator;
  LLabels[5]:=LabelDocProducer;
  LLabels[6]:=labelCreationDate;
  LLabels[7]:=labelModifyDate;
  LEdits[0]:=textDocAuthor;
  LEdits[1]:=textDocTitle;
  LEdits[2]:=textDocSubject;
  LEdits[3]:=textDocKeywords;
  LEdits[4]:=textDocCreator;
  LEdits[5]:=textDocProducer;
  LEdits[6]:=textDocCreationDate;
  LEdits[7]:=textDocModDate;
  lw:=TW(LabelXmpContent.Caption);
  for i:=0 to High(LLabels) do
   lw:=Max(lw,TW(LLabels[i].Caption));
  Inc(lw,G);
  for i:=0 to High(LEdits) do
  begin
   if i=0 then
    PlaceAt(LEdits[i],M+lw,nil,M)
   else
    PlaceAt(LEdits[i],M+lw,LEdits[i-1],S);
   ToRight(LEdits[i],M);
   LabelFor(LLabels[i],M,LEdits[i]);
  end;
  PlaceAt(TextXMPContent,M+lw,textDocModDate,S);
  ToRight(TextXMPContent,M);
  TextXMPContent.AnchorParallel(akBottom,M,TabMetadata);
  Reset(LabelXmpContent);
  LabelXmpContent.AnchorParallel(akLeft,M,TabMetadata);
  LabelXmpContent.AnchorParallel(akTop,Scale96ToScreen(4),TextXMPContent);
  Need(0,M+8*(edith+S)+Scale96ToScreen(100)+M);
 finally
  LBitmap.Free;
 end;
 // Never smaller than the lfm: the lists and texts keep their room
 if dw>0 then
  ClientWidth:=ClientWidth+dw;
 if dh>0 then
  ClientHeight:=ClientHeight+dh;
end;

procedure TFRpPageSetupVCL.FormDestroy(Sender: TObject);
begin
 // The copies not given to the report (Cancel, or deleted in the dialog)
 FEmbeddedFiles.Free;
 FEmbeddedFiles:=nil;
end;

procedure TFRpPageSetupVCL.SetReport(AReport:TRpBaseReport);
begin
 FReport:=AReport;
 FOptionsRead:=false;
 if Assigned(FReport) then
  ReadOptions;
end;

procedure TFRpPageSetupVCL.BOKClick(Sender: TObject);
begin
 SaveOptions;
 close;
end;

procedure TFRpPageSetupVCL.SaveOptions;
var
 acopies:integer;
 FReportAction:TRpReportActions;
 linch:integer;
 apapersource:integer;
 acustomwidth,acustomheight:integer;
 aleft,aright,atop,abottom:integer;
 i:integer;
begin
 if CheckDefaultCopies.Checked then
  acopies:=0
 else
 begin
  acopies:=StrToInt(ECopies.Text);
 end;
 if acopies<0 then
  acopies:=1;
 linch:=Round(ELinesPerInch.AsFloat*100);
 if ((linch<100) OR (linch>3000)) then
  Raise Exception.Create(SRpSLinesInchError);
 // Validate every typed value before touching the report: an invalid value
 // must not leave the report half modified
 apapersource:=StrToInt(EPaperSource.Text);
 acustomwidth:=FReport.CustomPageWidth;
 if EPageWidth.Text<>oldcustompagewidth then
  acustomwidth:=gettwipsfromtext(EPageWidth.Text);
 acustomheight:=FReport.CustomPageHeight;
 if EPageHeight.Text<>oldcustompageheight then
  acustomheight:=gettwipsfromtext(EPageHeight.Text);
 aleft:=FReport.LeftMargin;
 if ELeftMargin.Text<>oldleftmargin then
  aleft:=gettwipsfromtext(ELeftMargin.Text);
 aright:=FReport.RightMargin;
 if ERightMargin.Text<>oldrightmargin then
  aright:=gettwipsfromtext(ERightMargin.Text);
 atop:=FReport.TopMargin;
 if ETopMargin.Text<>oldtopmargin then
  atop:=gettwipsfromtext(ETopMargin.Text);
 abottom:=FReport.BottomMargin;
 if EBottomMargin.Text<>oldbottommargin then
  abottom:=gettwipsfromtext(EBottomMargin.Text);
 FReport.LinesPerInch:=linch;
 FReport.Copies:=acopies;
 FReport.CollateCopies:=CheckCollate.Checked;
 FReport.TwoPass:=CheckTwoPass.Checked;
 FReport.PreviewAbout:=CheckPreviewAbout.Checked;
 FReport.PrintOnlyIfDataAvailable:=CheckPrintOnlyIfData.Checked;
 FReportAction:=[];
 if CheckDrawerAfter.Checked then
  include(FreportAction,rpDrawerAfter);
 if CheckDrawerBefore.Checked then
  include(FreportAction,rpDrawerBefore);
 FReport.ReportAction:=FReportAction;
 // Saves the options to report
 FReport.Pagesize:=TRpPageSize(RPageSize.ItemIndex);
  // Assigns the with and height in twips
 FReport.PagesizeQt:=ComboPageSize.ItemIndex;
 FReport.PageHeight:=Round(PageSizeArray[FReport.PageSizeQt].Height*1000/TWIPS_PER_INCHESS);
 FReport.PageWidth:=Round(PageSizeArray[FReport.PageSizeQt].Width*1000/TWIPS_PER_INCHESS);
 FReport.CustomPageWidth:=acustomwidth;
 FReport.CustomPageHeight:=acustomheight;
 FReport.LeftMargin:=aleft;
 FReport.RightMargin:=aright;
 FReport.TopMargin:=atop;
 FReport.BottomMargin:=abottom;
 FReport.PageOrientation:=rpOrientationDefault;
 FReport.PrinterSelect:=TRpPrinterSelect(ComboSelPrinter.ItemIndex);
 if RPageOrientation.itemindex=1 then
 begin
  if RCustomOrientation.itemindex=0 then
   FReport.PageOrientation:=rpOrientationPortrait
  else
   FReport.PageOrientation:=rpOrientationLandscape;
 end;
 FReport.PageBackColor:=SColor.Brush.Color;
 // Language
 FReport.Language:=ComboLanguage.ItemIndex-1;
 // Other
 FReport.PrinterFonts:=TRpPrinterFontsOption(ComboPrinterFonts.ItemIndex);
 FReport.PreviewStyle:=TRpPreviewStyle(ComboStyle.ItemIndex);
 FReport.PreviewMargins:=CheckMargins.Checked;
 FReport.PreviewWindow:=TRpPreviewWindowStyle(ComboPreview.ItemIndex);
 FReport.StreamFormat:=TRpStreamFormat(ComboFormat.ItemIndex);
 FReport.PaperSOurce:=apapersource;
 FReport.Duplex:=ComboDuplex.ItemIndex;
 FReport.ForcePaperName:=EForceFormName.Text;
 // PDF options and document metadata
 FReport.PDFConformance:=TPDFConformanceType(ComboBoxPDFConformance.ItemIndex);
 FReport.PDFCompressed:=CheckBoxPDFCompressed.Checked;
 FReport.DocAuthor:=textDocAuthor.Text;
 FReport.DocCreator:=textDocCreator.Text;
 FReport.DocProducer:=textDocProducer.Text;
 FReport.DocTitle:=textDocTitle.Text;
 FReport.DocSubject:=textDocSubject.Text;
 FReport.DocCreationDate:=textDocCreationDate.Text;
 FReport.DocModificationDate:=textDocModDate.Text;
 FReport.DocKeywords:=textDocKeywords.Text;
 FReport.DocXMPContent:=TextXMPContent.Text;
 // Embedded files: the report owns the copies of the dialog from now on
 for i:=0 to Length(FReport.EmbeddedFiles)-1 do
  FReport.EmbeddedFiles[i].Free;
 SetLength(FReport.EmbeddedFiles,0);
 SetLength(FReport.EmbeddedFiles,FEmbeddedFiles.Count);
 FEmbeddedFiles.OwnsObjects:=false;
 try
  for i:=0 to FEmbeddedFiles.Count-1 do
   FReport.EmbeddedFiles[i]:=TEmbeddedFile(FEmbeddedFiles[i]);
  FEmbeddedFiles.Clear;
 finally
  FEmbeddedFiles.OwnsObjects:=true;
 end;

 dook:=true;
end;

procedure TFRpPageSetupVCL.ReadOptions;
var
 i:integer;
begin
 FOptionsRead:=true;
 // ReadOptions
 ELinesPerInch.Text:=FloatToStr(FReport.LinesPerInch/100);
 if FReport.copies=0 then
 begin
  CheckDefaultCopies.Checked:=true;
  ECopies.Text:='1';
  CheckDefaultCopiesClick(Self);
 end
 else
  ECopies.Text:=IntToStr(FReport.Copies);

 CheckCollate.Checked:=FReport.CollateCopies;
 CheckTwoPass.Checked:=FReport.TwoPass;
 CheckPrintOnlyIfData.Checked:=FReport.PrintOnlyIfDataAvailable;
 CheckDrawerBefore.Checked:=rpDrawerBefore in FReport.ReportAction;
 CheckDrawerAfter.Checked:=rpDrawerAfter in FReport.ReportAction;
 CheckPreviewAbout.Checked:=FReport.PreviewAbout;

 // Size
 ComboPageSize.ItemIndex:=FReport.PagesizeQt;
 GPageSize.Visible:=false;
 RPageSize.ItemIndex:=0;
 ELeftMargin.Text:=gettextfromtwips(FReport.LeftMargin);
 ERightMargin.Text:=gettextfromtwips(FReport.RightMargin);
 ETopMargin.Text:=gettextfromtwips(FReport.TopMargin);
 EBottomMargin.Text:=gettextfromtwips(FReport.BottomMargin);
 EPageWidth.Text:=gettextfromtwips(FReport.CustomPageWidth);
 EPageHeight.Text:=gettextfromtwips(FReport.CustomPageheight);
 oldcustompagewidth:=EPageWidth.Text;
 oldcustompageheight:=EPageheight.Text;
 oldleftmargin:=ELeftMargin.Text;
 oldrightmargin:=ERightMargin.Text;
 oldTopmargin:=ETopMargin.Text;
 oldBottommargin:=EBottomMargin.Text;

 RPageSize.ItemIndex:=integer(FReport.Pagesize);
 RPageSizeClick(Self);
 // Orientation
 RPageOrientation.Itemindex:=0;
 RCustomOrientation.Itemindex:=0;
 RCustomOrientation.Visible:=false;
 if FReport.PageOrientation>rpOrientationdefault then
 begin
  RCustomOrientation.Visible:=true;
  RPageOrientation.itemindex:=1;
 end;
 if FReport.PageOrientation=rpOrientationPortrait then
  RCustomOrientation.Itemindex:=0;
 if FReport.PageOrientation=rpOrientationLandscape then
  RCustomOrientation.Itemindex:=1;
 ComboSelPrinter.ItemIndex:=integer(FReport.PrinterSelect);
 // Color
 SColor.Brush.Color:=TColor(FReport.PageBackColor);
 // Language
 ComboLanguage.ItemIndex:=0;
 ComboPrinterFonts.ItemIndex:=integer(FReport.PrinterFonts);
 if (FReport.Language+1)<ComboLanguage.Items.Count then
  ComboLanguage.ItemIndex:=FReport.Language+1;
 ComboStyle.ItemIndex:=integer(FReport.PreviewStyle);
 ComboPreview.ItemIndex:=integer(FReport.PreviewWindow);
 ComboFormat.ItemIndex:=integer(FReport.StreamFormat);
 CheckMargins.Checked:=FReport.PreviewMargins;
 EPaperSource.Text:=IntToStr(FReport.PaperSource);
 EPaperSourceChange(Self);
 ComboDuplex.ItemIndex:=FReport.Duplex;
 EForceFormName.Text:=FReport.ForcePaperName;
 // PDF options
 if (FReport.PDFConformance=PDF_1_4) then
  ComboBoxPDFConformance.ItemIndex:=0
 else
  ComboBoxPDFConformance.ItemIndex:=1;
 CheckBoxPDFCompressed.Checked:=FReport.PDFCompressed;
 // Metadata
 textDocAuthor.Text:=FReport.DocAuthor;
 textDocCreator.Text:=FReport.DocCreator;
 textDocProducer.Text:=FReport.DocProducer;
 textDocTitle.Text:=FReport.DocTitle;
 textDocSubject.Text:=FReport.DocSubject;
 textDocCreationDate.Text:=FReport.DocCreationDate;
 textDocModDate.Text:=FReport.DocModificationDate;
 textDocKeywords.Text:=FReport.DocKeywords;
 TextXMPContent.Text:=FReport.DocXMPContent;
 // Embedded files: the dialog works on copies (Cancel keeps the report)
 FEmbeddedFiles.Clear;
 for i:=0 to Length(FReport.EmbeddedFiles)-1 do
  FEmbeddedFiles.Add(FReport.EmbeddedFiles[i].Clone());
 UpdateEmbeddedList;
end;

procedure TFRpPageSetupVCL.SColorMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
 BBackgroundClick(Self);
end;

procedure TFRpPageSetupVCL.BBackgroundClick(Sender: TObject);
begin
 if ColorDialog1.Execute then
  SColor.Brush.Color:=ColorDialog1.Color;
end;

procedure TFRpPageSetupVCL.RPageSizeClick(Sender: TObject);
begin
 GPageSize.Visible:=RPageSize.Itemindex=1;
 GUserDefined.Visible:=RPageSize.Itemindex=2;
end;

procedure TFRpPageSetupVCL.RPageOrientationClick(Sender: TObject);
begin
 RCustomOrientation.Visible:=RPageOrientation.Itemindex=1;
end;

procedure TFRpPageSetupVCL.FormShow(Sender: TObject);
begin
 // Report assigned without reading the options
 if (not FOptionsRead) and Assigned(FReport) then
  ReadOptions;
end;

procedure TFRpPageSetupVCL.BConfigureClick(Sender: TObject);
begin
 ShowPrintersConfiguration;
end;

procedure TFRpPageSetupVCL.EPaperSourceChange(Sender: TObject);
var
 index:integer;
begin
 try
  index:=StrToInt(EPaperSource.Text);
 except
  index:=-1;
 end;
 if index<0 then
  index:=-1;
 if (index<ComboPaperSource.Items.Count) then
 begin
  CombopaperSource.ItemIndex:=index;
 end;
end;

procedure TFRpPageSetupVCL.ComboPaperSourceClick(Sender: TObject);
begin
 EPaperSource.Text:=IntToStr(ComboPaperSource.ItemIndex);
end;

procedure TFRpPageSetupVCL.CheckDefaultCopiesClick(Sender: TObject);
begin
 ECopies.Enabled:=not CheckDefaultCopies.Checked;
end;

function TFRpPageSetupVCL.GetEmbeddedFile(Index:Integer):TEmbeddedFile;
begin
 Result:=TEmbeddedFile(FEmbeddedFiles[Index]);
end;

function TFRpPageSetupVCL.GetEmbeddedFileCount:Integer;
begin
 Result:=FEmbeddedFiles.Count;
end;

procedure TFRpPageSetupVCL.UpdateEmbeddedList;
var
 i:integer;
 embedded:TEmbeddedFile;
 listItem:TListItem;
 asize:Double;
begin
 ListViewEmbedded.Items.BeginUpdate;
 try
  ListViewEmbedded.Items.Clear;
  for i:=0 to FEmbeddedFiles.Count-1 do
  begin
   embedded:=TEmbeddedFile(FEmbeddedFiles[i]);
   listItem:=ListViewEmbedded.Items.Add;
   listItem.Caption:=embedded.FileName;
   listItem.SubItems.Add(embedded.MimeType);
   asize:=0;
   if Assigned(embedded.Stream) then
    asize:=embedded.Stream.Size;
   listItem.SubItems.Add(FormatFloat('##,##0.00',asize/1024)+' '+SRpKbytes);
   listItem.SubItems.Add(RpAFRelationShipName(embedded.AFRelationShip));
   listItem.SubItems.Add(embedded.Description);
   listItem.SubItems.Add(embedded.CreationDate);
   listItem.SubItems.Add(embedded.ModificationDate);
  end;
 finally
  ListViewEmbedded.Items.EndUpdate;
 end;
 if (ListViewEmbedded.Items.Count>0) then
  ListViewEmbedded.ItemIndex:=0;
 BDeleteFile.Enabled:=ListViewEmbedded.Items.Count>0;
 BModifyFile.Enabled:=BDeleteFile.Enabled;
end;

function TFRpPageSetupVCL.AddEmbeddedFile(const AFileName:string):boolean;
var
 embedded:TEmbeddedFile;
begin
 Result:=false;
 embedded:=TEmbeddedFile.Create;
 try
  embedded.FileName:=ExtractFileName(AFileName);
  embedded.MimeType:=RpMimeTypeFromFileName(AFileName);
  embedded.Stream:=TMemoryStream.Create;
  embedded.Stream.LoadFromFile(AFileName);
  embedded.Stream.Position:=0;
  if AskEmbeddedFileData(embedded) then
  begin
   FEmbeddedFiles.Add(embedded);
   embedded:=nil;
   UpdateEmbeddedList;
   ListViewEmbedded.ItemIndex:=ListViewEmbedded.Items.Count-1;
   Result:=true;
  end;
 finally
  embedded.Free;
 end;
end;

function TFRpPageSetupVCL.ModifyEmbeddedFile(AIndex:Integer):boolean;
begin
 Result:=false;
 if (AIndex<0) or (AIndex>=FEmbeddedFiles.Count) then
  exit;
 if AskEmbeddedFileData(TEmbeddedFile(FEmbeddedFiles[AIndex])) then
 begin
  UpdateEmbeddedList;
  ListViewEmbedded.ItemIndex:=AIndex;
  Result:=true;
 end;
end;

procedure TFRpPageSetupVCL.DeleteEmbeddedFile(AIndex:Integer);
begin
 if (AIndex<0) or (AIndex>=FEmbeddedFiles.Count) then
  exit;
 // Owned by the list: freed here (the report still has its own copy
 // until OK)
 FEmbeddedFiles.Delete(AIndex);
 UpdateEmbeddedList;
 if AIndex<ListViewEmbedded.Items.Count then
  ListViewEmbedded.ItemIndex:=AIndex;
end;

procedure TFRpPageSetupVCL.BNewFileClick(Sender: TObject);
var
 dia:TOpenDialog;
begin
 dia:=TOpenDialog.Create(nil);
 try
  dia.Filter:=TranslateStr(1800,'XML file')+'|*.xml;*.XML|'+
   TranslateStr(1801,'PDF file')+'|*.pdf;*.PDF|'+
   TranslateStr(1802,'Image file')+'|*.png;*.PNG;*.jpg;*.JPG;*.jpeg;*.JPEG;*.bmp;*.BMP|'+
   TranslateStr(1803,'Other file')+'|*.*;*';
  dia.FilterIndex:=1;
  dia.Options:=[ofFileMustExist,ofEnableSizing];
  if not dia.Execute then
   exit;
  AddEmbeddedFile(dia.FileName);
 finally
  dia.Free;
 end;
end;

procedure TFRpPageSetupVCL.BDeleteFileClick(Sender: TObject);
begin
 DeleteEmbeddedFile(ListViewEmbedded.ItemIndex);
end;

procedure TFRpPageSetupVCL.BModifyFileClick(Sender: TObject);
begin
 ModifyEmbeddedFile(ListViewEmbedded.ItemIndex);
end;

procedure TFRpPageSetupVCL.ListViewEmbeddedDblClick(Sender: TObject);
begin
 ModifyEmbeddedFile(ListViewEmbedded.ItemIndex);
end;

end.
