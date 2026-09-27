{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       Rpgdidriver                                     }
{       TRpGDIDriver: Printer driver for  VCL Lib       }
{       can be used only for windows                    }
{       it includes printer and bitmap support          }
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

unit rplcldriver;

interface

{$I rpconf.inc}

// Outside Windows the text is painted from the runs the engine lays out (same
// shaper and metrics as the PDF driver). With the GTK2 widgetset the glyphs are
// drawn through Cairo with the very font files the engine measured.
{$IFNDEF MSWINDOWS}
 {$IFDEF LCLGTK2}
  {$DEFINE RPLCLCAIRO}
 {$ENDIF}
{$ENDIF}

uses
{$IFDEF MSWINDOWS}
 Windows,
{$ENDIF}
{$IFDEF RPLCLCAIRO}
 ctypes,gdk2,gtk2def,cairo,
 {$IFDEF UNIX}
 cairocanvas,
 {$ENDIF}
{$ENDIF}
{$IFNDEF MSWINDOWS}
 LCLType,rpfreetype2,rpinfoprovid,
{$ENDIF}
 Classes,sysutils,rpmetafile,rpmdconsts,Graphics,Forms,
 rpmunits,Dialogs, Controls,rplclfonts,Math,
 StdCtrls,ExtCtrls,rppdffile,rpgraphutilslcl,rpmdcharttypes,PrintersDlgs,Printers,
{$IFNDEF FORWEBAX}
 rpmdchart,
{$ENDIF}
{$IFDEF USEVARIANTS}
 types,Variants,
{$ENDIF}
 rptypes,
{$IFNDEF FORWEBAX}
 rpbasereport,rpreport,
{$IFDEF USETEECHART}
 {$IFDEF VCLNOTATION}
  VCLTee.Chart,VCLTee.Series,rpdrawitem,
  VCLTee.teEngine,VCLTee.ArrowCha,VCLTee.BubbleCh,VCLTee.GanttCh,
 {$ENDIF}
 {$IFNDEF VCLNOTATION}
  Chart,Series,rpdrawitem,
  teEngine,ArrowCha,BubbleCh,GanttCh,
  jpeg,
{$IFDEF DELPHI2009UP}
  pngimage,VCLTee.TeCanvas,System.UITypes,
{$ELSE}
 TeCanvas,
{$ENDIF}
 {$ENDIF}
{$ENDIF}
{$IFDEF EXTENDEDGRAPHICS}
 rpgraphicex,
{$ENDIF}
{$ENDIF}
 rppdfdriver,rptextdriver;


const
 METAPRINTPROGRESS_INTERVAL=20;
type
  TRpGDIDriver=class;
  TFRpVCLProgress = class(TForm)
    BCancel: TButton;
    LProcessing: TLabel;
    LRecordCount: TLabel;
    LTitle: TLabel;
    LTittle: TLabel;
    BOK: TButton;
    GPrintRange: TGroupBox;
    EFrom: TEdit;
    ETo: TEdit;
    LTo: TLabel;
    LFrom: TLabel;
    RadioAll: TRadioButton;
    RadioRange: TRadioButton;
    GBitmap: TGroupBox;
    LHorzRes: TLabel;
    LVertRes: TLabel;
    EHorzRes: TEdit;
    EVertRes: TEdit;
    CheckMono: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    allpages,collate:boolean;
    frompage,topage,copies:integer;
    devicefonts:boolean;
    printerindex:TRpPrinterSelect;
    dook:boolean;
    MetaBitmap:TBitmap;
    bitresx,bitresy:Integer;
    bitmono:Boolean;
    procedure AppIdle(Sender:TObject;var done:boolean);
    procedure AppIdleBitmap(Sender:TObject;var done:boolean);
{$IFNDEF FORWEBAX}
    procedure AppIdleReport(Sender:TObject;var done:boolean);
    procedure RepProgress(Sender:TRpBaseReport;var docancel:boolean);
    procedure AppIdlePrintPDF(Sender:TObject;var done:boolean);
    procedure AppIdlePrintRange(Sender:TObject;var done:boolean);
    procedure AppIdlePrintRangeText(Sender:TObject;var done:boolean);
{$ENDIF}
  public
    { Public declarations }
    noenddoc:boolean;
    pdfcompressed:boolean;
    cancelled:boolean;
    oldonidle:TIdleEvent;
    tittle:string;
    filename:string;
    errorproces:boolean;
    ErrorMessage:String;
    usepdfdriver:boolean;
    metafile:TRpMetafileReport;
{$IFNDEF FORWEBAX}
    report:TRpReport;
{$ENDIF}
    nobegindoc:boolean;
  end;


 TRpGDIDriver=class(TRpPrintDriver)
  private
    FReport:TRpMetafileReport;
    BackColor:integer;
   intdpix,intdpiy:integer;
   metacanvas:TCanvas;
   meta:TBitmap;
   pagecliprec:TRect;
   onlycalc:Boolean;
   selectedprinter:TRpPrinterSelect;
   DrawerBefore,DrawerAfter:Boolean;
   npdfdriver:TRpPDFDriver;
   FPageWidth,FPageHeight:integer;
   PageQt:Integer;
   FOrientation:TRpOrientation;
   procedure PrintObject(Canvas:TCanvas;page:TRpMetafilePage;obj:TRpMetaObject;dpix,dpiy:integer;toprinter:boolean;pagemargins:TRect;devicefonts:boolean;offset:TPoint;selected:boolean);
   procedure SendAfterPrintOperations;
   function DoNewPage(aorientation:TRpOrientation;apagesizeqt:TPageSizeQt):Boolean;
   procedure UpdateBitmapSize(report:TrpMetafileReport;apage:TrpMetafilePage);
   procedure EnsureTextPdfDriver;
   procedure ResolveTextDpi(adpix,adpiy:integer;out aintdpix,aintdpiy:integer);
{$IFNDEF MSWINDOWS}
  private
   // Font family the PDF driver would use for the object being drawn
   // (TRpPDFDriver.DrawObject takes the Linux font name outside Windows)
   FTextFamily:WideString;
   FTextType1Font:integer;
   FTextFamilySet:Boolean;
   FEngineFontCache:TStringList;
   function EngineForceShaping:boolean;
   procedure SyncTextPdfConformance;
   function EngineResolveFont(const Family:string;Bold,Italic:Boolean;
     out FileName:string;out FaceIndex:integer):Boolean;
   procedure EngineTextOut(APainter:TObject;X,Y:integer;const Text:WideString;
     const linfo:TRpLineInfo;LineWidth,Rotation:integer;RightToLeft,IsHtml:Boolean);
{$ENDIF}
  public
   offset:TPoint;
   showpagemargins:boolean;
//   CurrentPageSize:Tpoint;
   bitmap:TBitmap;
   dpi:integer;
   toprinter:boolean;
   scale:double;
   pagemargins:TRect;
   drawclippingregion:boolean;
   oldpagesize,pagesize:TGDIPageSize;
   oldorientation:TPrinterOrientation;
   orientationset:boolean;
   devicefonts:boolean;
   neverdevicefonts:boolean;
   UsePdfFonts: boolean;
   bitmapwidth,bitmapheight:integer;
   PreviewStyle:TRpPreviewStyle;
   clientwidth,clientheight:integer;
   FontDriver:TRpPrintDriver;
   noenddoc:boolean;
   procedure NewDocument(report:TrpMetafileReport;hardwarecopies:integer;
    hardwarecollate:boolean);override;
   procedure EndDocument;override;
   procedure AbortDocument;override;
   procedure NewPage(metafilepage:TRpMetafilePage);override;
   procedure EndPage;override;
   procedure DrawObject(page:TRpMetaFilePage;obj:TRpMetaObject);override;
   procedure IntDrawObject(page:TRpMetaFilePage;obj:TRpMetaObject;selected:boolean);
   procedure DrawChart(Series:TRpSeries;ametafile:TRpMetaFileReport;posx,posy:integer;achart:TObject);override;
{$IFNDEF FORWEBAX}
   procedure FilterImage(memstream:TMemoryStream);override;
{$ENDIF}
{$IFNDEF FORWEBAX}
{$IFDEF USETEECHART}
   procedure DoDrawChart(adriver:TRpPrintDriver;Series:TRpSeries;page:TRpMetaFilePage;
     aposx,aposy:integer;xchart:TObject);
{$ENDIF}
{$ENDIF}
   procedure DrawPage(apage:TRpMetaFilePage);override;
   function AllowCopies:boolean;override;
   function GetPageSize(var PageSizeQt:Integer):TPoint;override;
   function SetPagesize(PagesizeQt:TPageSizeQt):TPoint;override;
   procedure TextExtent(atext:TRpTextObject;var extent:TPoint);override;
  function TextExtentLineInfo(atext:TRpTextObject;var extent:TPoint):TRpLineInfoArray;override;
    function UseExactPdfText: boolean;
    procedure ComputeGlyphPixPositions(const linfo: TRpLineInfo; Alignment: Integer;
      ARect: TRect; aintdpix: Integer; out allPixPos, allDx: TIntegerDynArray);
    procedure DrawGlyphRuns(Canvas: TCanvas; const linfo: TRpLineInfo;
      const allPixPos, allDx: TIntegerDynArray; nposy: Integer; aintdpiy: Integer;
      BaseFontStyle: Integer; ptFontSize: Integer = 0);
    procedure TextRectJustifyGlyphs(Canvas: TCanvas; const ARect: TRect; Text: WideString;
      const larray: TRpLineInfoArray; Alignment: integer; posy: integer;
      aintdpix, aintdpiy: integer; RightToLeft: Boolean = False; ptFontSize: Integer = 0);
    procedure TextRectHtml(Canvas: TCanvas; ARect: TRect; Text: Widestring;
      Alignment: integer; Clipping: boolean; Wordbreak: boolean;
      Rotation: integer; BaseFontStyle: integer; drawbackground: boolean;
      BackColor: TColor; adpix: integer = 0; adpiy: integer = 0;
      IsHtml: Boolean = True; RightToLeft: Boolean = False; ptFontSize: Integer = 0);
    procedure TextRectJustify(Canvas:TCanvas;ARect: TRect; Text: Widestring;
                        Alignment: integer; Clipping: boolean;Wordbreak:boolean;
                        Rotation:integer;RightToLeft:Boolean;drawbackground:Boolean;backcolor:TColor;
                        adpix: integer = 0; adpiy: integer = 0; IsHtml: Boolean = False; ptFontSize: Integer = 0);
{$IFNDEF MSWINDOWS}
    // Lays the text out exactly as TRpPDFCanvas.TextRect does (same shaper,
    // line breaks, alignment, justification and clipping) and paints the
    // resulting runs, so the preview matches the PDF
    procedure EngineTextRect(Canvas: TCanvas; ARect: TRect; Text: WideString;
      Alignment: integer; Clipping, Wordbreak: boolean; Rotation: integer;
      RightToLeft, IsHtml, drawbackground: boolean; BackColor: TColor;
      adpix, adpiy, ptFontSize: integer);
{$ENDIF}
    procedure GraphicExtent(Stream:TMemoryStream;var extent:TPoint;dpi:integer);override;
    procedure SetOrientation(Orientation:TRpOrientation);  override;
    procedure RestoreOrientation;override;
    function GetOrientation():TRpOrientation;override;
    procedure SelectPrinter(printerindex:TRpPrinterSelect);override;
    function SupportsCopies(maxcopies:integer):boolean;override;
    function SupportsCollation:boolean;override;
    constructor Create;
    destructor Destroy;override;
    function GetFontDriver:TRpPrintDriver;override;
  end;

function PrintMetafile(metafile:TRpMetafileReport; tittle:string;
 showprogress,allpages:boolean; frompage,topage,copies:integer;
  collate:boolean; devicefonts:boolean; printerindex:TRpPrinterSelect=pRpDefaultPrinter;nobegindoc:boolean=false):boolean;
function MetafileToBitmap(metafile:TRpMetafileReport;ShowProgress:Boolean;
 Mono:Boolean;resx:integer=200;resy:integer=100):TBitmap;
function DoMetafileToBitmap(metafile:TRpMetafileReport;aform:TFRpVCLProgress;
 Mono:Boolean;resx:integer=200;resy:integer=100):TBitmap;
function SaveMetafileToPNG(metafile:TRpMetafileReport; const baseFilename:string;
 dpi:integer=0; alwaysNumberPages:boolean=false):integer;
function AskBitmapProps(var HorzRes,VertRes:Integer;var Mono:Boolean):Boolean;

{$IFNDEF FORWEBAX}
function CalcReportWidthProgress (report:TRpReport;noenddoc:boolean=false):boolean;
function CalcReportWidthProgressPDF(report:TRpReport;noenddoc:boolean=false):boolean;
function PrintReport (report:TRpReport; Caption:string; progress:boolean;
  allpages:boolean; frompage,topage,copies:integer; collate:boolean):Boolean;
function ExportReportToPDF (report:TRpReport; Caption:string; progress:boolean;
  allpages:boolean; frompage,topage,copies:integer;
  showprintdialog:boolean; filename:string; compressed:boolean;collate:boolean):Boolean;
function ExportReportToPDFMetaStream (report:TRpReport; Caption:string; progress:boolean;
  allpages:boolean; frompage,topage,copies:integer;
  showprintdialog:boolean; stream:TStream; compressed:boolean;collate:boolean;metafile:Boolean):Boolean;
{$ENDIF}
function DoShowPrintDialog (var allpages:boolean;
 var frompage,topage,copies:integer; var collate:boolean;disablecopies:boolean=false) :boolean;
function PrinterSelection(printerindex:TRpPrinterSelect;papersource,duplex:integer;var pconfig:TPrinterConfig) :TPoint;
procedure PageSizeSelection (rpPageSize:TPageSizeQt);
procedure OrientationSelection (neworientation:TRpOrientation);

{$IFNDEF FORWEBAX}
procedure ExFilterImage(memstream:TMemoryStream);
{$ENDIF}


implementation



{$R *.lfm}

const
 AlignmentFlags_SingleLine=64;
 AlignmentFlags_AlignHCenter = 4 { $4 };
 AlignmentFlags_AlignHJustify = 1024 { $400 };
 AlignmentFlags_AlignTop = 8 { $8 };
 AlignmentFlags_AlignBottom = 16 { $10 };
 AlignmentFlags_AlignVCenter = 32 { $20 };
 AlignmentFlags_AlignLeft = 1 { $1 };
 AlignmentFlags_AlignRight = 2 { $2 };
const
  DT_NOPREFIX = 2048;
  DT_CENTER = 1;
  DT_VCENTER = 4;
  DT_TOP = 0;
  DT_BOTTOM = 8;


function EqualsPageSizeQt(a,b:TPageSizeQt):Boolean;
begin
 Result:=true;
 if (a.Indexqt<>b.Indexqt) then
 begin
  Result:=false;
  exit;
 end;
 if (a.Custom<>b.Custom) then
 begin
  Result:=false;
  exit;
 end;
 if (a.CustomWidth<>b.CustomWidth) then
 begin
  Result:=false;
  exit;
 end;
 if (a.CustomHeight<>b.CustomHeight) then
 begin
  Result:=false;
  exit;
 end;
 if (a.PaperSource<>b.PaperSource) then
 begin
  Result:=false;
  exit;
 end;
{$IFNDEF DOTNETD}
 if (a.ForcePaperName<>b.ForcePaperName) then
{$ENDIF}
{$IFDEF DOTNETD}
 if (String(a.ForcePaperName)<>String(b.ForcePaperName)) then
{$ENDIF}
 begin
  Result:=false;
  exit;
 end;
 if (a.Duplex<>b.Duplex) then
 begin
  Result:=false;
  exit;
 end;
end;

function TRpGDIDriver.DoNewPage(aorientation:TRpOrientation;apagesizeqt:TPageSizeQt):Boolean;
begin
 Result:=true;
 Printer.NewPage;
 SetOrientation(aorientation);
end;


function DoShowPrintDialog(var allpages:boolean;
 var frompage,topage,copies:integer;var collate:boolean;disablecopies:boolean=false):boolean;
var
 dia:TPrintDialog;
 diarange:TFRpVCLProgress;
begin
 Result:=False;
 if disablecopies then
 begin
  diarange:=TFRpVCLProgress.Create(Application);
  try
   diarange.BOK.Visible:=true;
   diarange.GPrintRange.Visible:=true;
   diarange.RadioAll.Checked:=allpages;
   diarange.RadioRange.Checked:=not allpages;
   diarange.ActiveControl:=diarange.BOK;
   diarange.Frompage:=frompage;
   diarange.ToPage:=topage;
   diarange.showmodal;
   if diarange.dook then
   begin
    frompage:=diarange.frompage;
    topage:=diarange.topage;
    allpages:=diarange.Radioall.Checked;
    Result:=true;
   end
  finally
   diarange.free;
  end;
  exit;
 end;
// if (copies>0) then
//  SetPrinterCollation(collate);
 dia:=TPrintDialog.Create(Application);
 try
  dia.Options:=[poPageNums,poWarning,
        poPrintToFile];
  dia.MinPage:=1;
  dia.MaxPage:=65535;
  if copies=0 then
  begin
//   dia.copies:=GetPrinterCopies;
//   dia.collate:=GetPrinterCollation;
  end
  else
  begin
   dia.copies:=copies;
   dia.collate:=collate;
  end;
  dia.frompage:=frompage;
  dia.topage:=topage;
  if dia.execute then
  begin
   allpages:=false;
//   collate:=GetPrinterCollation;
   copies:=Printer.Copies;
   frompage:=dia.frompage;
   topage:=dia.topage;
   Result:=True;
  end;
 finally
  dia.free;
 end;
end;


constructor TRpGDIDriver.Create;
begin
 inherited Create;
 // By default 1:1 scale
 offset.X:=0;
 offset.Y:=0;
 dpi:=Screen.PixelsPerInch;
 drawclippingregion:=false;
 oldpagesize.PageIndex:=-1;
 scale:=1;
 FPageWidth:=0;
 FPageHeight:=0;
 PageQt:=0;
 FOrientation:=rpOrientationPortrait;
 UsePdfFonts:=false;
end;

destructor TRpGDIDriver.Destroy;
begin
 if assigned(metacanvas) then
 begin
//  metacanvas.free;
  metacanvas:=nil;
 end;
 if assigned(meta) then
 begin
  meta.free;
  meta:=nil;
 end;
 if assigned(bitmap) then
 begin
  bitmap.free;
  bitmap:=nil;
 end;
 if assigned(npdfdriver) then
  npdfdriver.free;
{$IFNDEF MSWINDOWS}
 FEngineFontCache.Free;
{$ENDIF}
 inherited Destroy;
end;

procedure TRpGDIDriver.EnsureTextPdfDriver;
begin
 if not assigned(npdfdriver) then
 begin
  npdfdriver:=TRpPDFDriver.Create;
  if Assigned(FReport) then
   npdfdriver.PDFConformance:=FReport.PDFConformance
  else
   npdfdriver.PDFConformance:=TPDFConformanceType.PDF_A_3;
 end;
end;

// Device resolution for the text routines: explicit, the printer one or the
// preview one (dpi*scale, the same the shapes and images are drawn with)
procedure TRpGDIDriver.ResolveTextDpi(adpix,adpiy:integer;out aintdpix,aintdpiy:integer);
begin
 if adpix>0 then
 begin
  aintdpix:=adpix;
  aintdpiy:=adpiy;
 end
 else if toprinter then
 begin
  if intdpix=0 then
  begin
   intdpix:=printer.XDPI;
   intdpiy:=printer.YDPI;
  end;
  aintdpix:=intdpix;
  aintdpiy:=intdpiy;
 end
 else
 begin
  aintdpix:=Round(dpi*scale);
  aintdpiy:=Round(dpi*scale);
  if aintdpix<1 then
   aintdpix:=1;
  if aintdpiy<1 then
   aintdpiy:=1;
 end;
end;

function TRpGDIDriver.UseExactPdfText: boolean;
begin
  Result := UsePdfFonts;
  if (not Result) and Assigned(FReport) then
    Result := (FReport.PrinterFonts = rppfontsrecalculate) or
              (FReport.PDFConformance = TPDFConformanceType.PDF_A_3);
end;

function TRpGDIDriver.SupportsCopies(maxcopies:integer):boolean;
begin
// Result:=PrinterSupportsCopies(maxcopies);
 Result:=false;
end;

function TRpGDIDriver.SupportsCollation:boolean;
begin
 //Result:=PrinterSupportsCollation;
 Result:=false;
end;

procedure TRpGDIDriver.UpdateBitmapSize(report:TrpMetafileReport;apage:TrpMetafilePage);
var
 asize:TPoint;
 qtsize:integer;
 awidth,aheight:integer;
 rec:TRect;
 scale2:double;
// aregion:HRGN;
 frompage:boolean;
begin
 // Offset is 0 in preview
 offset.X:=0;
 offset.Y:=0;
 // Sets Orientation
 if Assigned(report) then
  BackColor:=report.BackColor
 else
  BackColor:=$00FFFFFF;
 frompage:=false;
 if assigned(apage) then
  if apage.UpdatedPageSize then
   frompage:=true;
 if not frompage then
 begin
  if drawclippingregion and Assigned(report) then
  begin
   SetOrientation(report.Orientation);
   // Gets pagesize
   asize:=GetPageSize(qtsize);
   pagemargins:=GetPageMarginsTWIPS;
//   CurrentPageSize:=asize;
  end
  else
  begin
   if Assigned(report) then
   begin
    asize.X:=report.CustomX;
    asize.Y:=report.CustomY;
   end
   else if Assigned(apage) then
   begin
    asize.X:=apage.PageSizeqt.PhysicWidth;
    asize.Y:=apage.PageSizeqt.PhysicHeight;
    if (asize.X = 0) or (asize.Y = 0) then
    begin
     asize.X := 11906;
     asize.Y := 16838;
    end;
   end
   else
   begin
    asize.X := 11906;
    asize.Y := 16838;
   end;
  end;
 end
 else
 begin
  if drawclippingregion then
  begin
   SetOrientation(apage.Orientation);
   pagemargins:=GetPageMarginsTWIPS;
  end;
  asize.X:=apage.PageSizeqt.PhysicWidth;
  asize.Y:=apage.PageSizeqt.PhysicHeight;
 end;
 bitmapwidth:=Round((asize.x/TWIPS_PER_INCHESS)*dpi);
 bitmapheight:=Round((asize.y/TWIPS_PER_INCHESS)*dpi);


 awidth:=bitmapwidth;
 aheight:=bitmapheight;



  if clientwidth>0 then
  begin
   // Calculates the scale
   case PreviewStyle of
    spWide:
     begin
      // Adjust clientwidth to bitmap width
      //scale:=(clientwidth-GetSystemMetrics(SM_CYHSCROLL))/bitmapwidth;
      scale:=(clientwidth)/bitmapwidth;
     end;
    spNormal:
     begin
      scale:=1.0;
     end;
    spEntirePage:
     begin
      // Adjust client to bitmap with an height
      scale:=(clientwidth-1)/bitmapwidth;
      scale2:=(clientheight-1)/bitmapheight;
      if scale2<scale then
       scale:=scale2;
     end;
   end;
  end;
  if scale<0.01 then
   scale:=0.01;
  if scale>10 then
   scale:=10;
  if Not assigned(bitmap) then
  begin
   bitmap:=TBitmap.Create;
{$IFNDEF DOTNETDBUGS}
   bitmap.PixelFormat:=pf24bit;
   bitmap.HandleType:=bmDIB;
{$ENDIF}
  end;
(*  end
  else
  begin
   if ((bitmap.Width<>bitmapwidth) or (bitmap.height<>bitmapheight)) then
   begin
    bitmap.free;
    bitmap:=nil;
    bitmap:=TBitmap.Create;
 {$IFNDEF DOTNETDBUGS}
    bitmap.PixelFormat:=pf32bit;
    bitmap.HandleType:=bmDIB;
 {$ENDIF}
   end;
  end;
*)
  bitmap.Width:=Round(awidth*scale);
  bitmap.Height:=Round(aheight*scale);
  if bitmap.Width<1 then
   bitmap.Width:=1;
  if bitmap.Height<1 then
   bitmap.Height:=1;

  Bitmap.Canvas.Brush.Style:=bsSolid;
  Bitmap.Canvas.Brush.Color:=CLXColorToVCLColor(BackColor);
  rec.Top:=0;
  rec.Left:=0;
  rec.Right:=Bitmap.Width+1;
  rec.Bottom:=Bitmap.Height+1;
  bitmap.Canvas.FillRect(rec);
  // Define clipping region
  if drawclippingregion then
  begin
   rec.Left:=Round((pagemargins.Left/TWIPS_PER_INCHESS)*dpi*scale);
   rec.Top:=Round((pagemargins.Top/TWIPS_PER_INCHESS)*dpi*scale);
   rec.Right:=Round((pagemargins.Right/TWIPS_PER_INCHESS)*dpi*scale);
   rec.Bottom:=Round((pagemargins.Bottom/TWIPS_PER_INCHESS)*dpi*scale);
   pagecliprec:=rec;
  end;
{  if (Not drawclippingregion) then
  begin
   aregion:=CreateRectRgn(rec.Left,rec.Top,rec.Right,rec.Bottom);
   SelectClipRgn(bitmap.Canvas.handle,aregion);
  end;
}
end;

procedure TRpGDIDriver.NewDocument(report:TrpMetafileReport;hardwarecopies:integer;
   hardwarecollate:boolean);
var
 asize:TPoint;
 qtsize:integer;
 rpagesizeQt:TPageSizeQt;
begin
 FReport:=report;
{$IFNDEF FORWEBAX}
{$IFDEF USETEECHART}
 report.OnDrawChart:=Self.DoDrawChart;
{$ENDIF}
{$IFDEF EXTENDEDGRAPHICS}
 report.OnFilterImage:=Self.FilterImage;
 {$ENDIF}
{$ENDIF}
 DrawerBefore:=report.OpenDrawerBefore;
 DrawerAfter:=report.OpenDrawerAfter;
 if devicefonts then
 begin
  //UpdatePrinterFontList;
 end;
 if ToPrinter then
 begin
  SetOrientation(report.Orientation);
  // Gets pagesize
  asize:=GetPageSize(qtsize);
  pagemargins:=GetPageMarginsTWIPS;
  if not noenddoc then
  begin
   //SetPrinterCopies(hardwarecopies);
   //SetPrinterCollation(hardwarecollate);
  end;

 // if not noenddoc then
//   if DrawerBefore then
    //SendControlCodeToPrinter(GetPrinterRawOp(selectedprinter,rawopopendrawer));
  // Sets pagesize
  rpagesizeQt.papersource:=report.PaperSource;
  SetForcePaperName(rpagesizeqt,report.ForcePaperName);
  rpagesizeQt.duplex:=report.duplex;
  if report.PageSize<0 then
  begin
   rpagesizeqt.Custom:=True;
   rPageSizeQt.CustomWidth:=report.CustomX;
   rPageSizeQt.CustomHeight:=report.CustomY;
  end
  else
  begin
   rpagesizeqt.Indexqt:=report.PageSize;
   rpagesizeqt.Custom:=False;
  end;
  try
   SetPagesize(rpagesizeqt);
  except
   On E:Exception do
   begin
    rpgraphutilslcl.RpMessageBox(E.Message);
   end;
  end;
  printer.Title:=report.Title;
  if Length(printer.Title)<1 then
  begin
   printer.Title:=SRpUntitled;
   if Length(printer.Title)<1 then
   begin
    printer.Title:='Untitled';
   end;
  end;
  printer.BeginDoc;
  intdpix:=Printer.XDPI; //  printer.XDPI;
  intdpiy:=Printer.YDPI;
 end
 else
 begin
  UpdateBitmapSize(report,nil);
 end;
end;



procedure TRpGDIDriver.EndDocument;
begin
 if toprinter then
 begin
  if not noenddoc then
  begin
   printer.EndDoc;
//   if DrawerAfter then
    //SendControlCodeToPrinter(GetPrinterRawOp(selectedprinter,rawopopendrawer));
   // Send Especial operations
   SendAfterPrintOperations;
  end;
 end
 else
 begin
  // Does nothing because the last bitmap can be usefull
 end;
 if oldpagesize.PageIndex<>-1 then
 begin
//  SetCurrentPaper(oldpagesize);
  oldpagesize.PageIndex:=-1;
 end;
 if orientationset then
 begin
  if printer.printing then
   SetPrinterOrientation(oldorientation=poLandscape)
  else
   printer.orientation:=oldorientation;
  orientationset:=false;
 end;
end;

procedure TRpGDIDriver.AbortDocument;
begin
 if toprinter then
 begin
  printer.Abort;
 end
 else
 begin
  if assigned(bitmap) then
   bitmap.free;
  bitmap:=nil;
 end;
 if orientationset then
 begin
  SetPrinterOrientation(oldorientation=poLandscape);
  orientationset:=false;
 end;
 if oldpagesize.PageIndex<>-1 then
 begin
//  SetCurrentPaper(oldpagesize);
  oldpagesize.PageIndex:=-1;
 end;
end;

procedure TRpGDIDriver.NewPage(metafilepage:TRpMetafilePage);
begin
 if toprinter then
 begin
  if metafilepage.UpdatedPageSize then
   DoNewPage(metafilepage.orientation,metafilepage.pagesizeqt)
  else
   Printer.NewPage;
 end
 else
 begin
  UpdateBitmapSize(FReport,metafilepage);
 end;
end;

procedure TRpGDIDriver.EndPage;
var
 rec:TREct;
begin
 // If drawclippingregion then
 if not toprinter then
 begin
  if Not Assigned(bitmap) then
   exit;
  rec:=pagecliprec;
  if drawclippingregion then
  begin
   bitmap.Canvas.Pen.Style:=psSolid;
   bitmap.Canvas.Pen.Color:=clBlack;
   bitmap.Canvas.Brush.Style:=bsclear;
   bitmap.Canvas.rectangle(rec.Left,rec.Top,rec.Right,rec.Bottom);
  end
 end;
end;



procedure TRpGDIDriver.TextExtent(atext:TRpTextObject;var extent:TPoint);
var
 Canvas:TCanvas;
 dpix,dpiy:integer;
 aalign:Cardinal;
 aatext:widestring;
 aansitext:string;
 arec:TRect;
 maxextent:TPoint;
 textstyle:TTextStyle;
begin
 if atext.FontRotation<>0 then
  exit;
 // Allways use pdf driver
// if (atext.AlignMent AND AlignmentFlags_AlignHJustify)>0 then
// if true then
  begin
   if not assigned(npdfdriver) then
   begin
     npdfdriver:=TRpPDFDriver.Create;
     if assigned(FReport) then
       npdfdriver.PDFConformance := FReport.PDFConformance;
   end;
{$IFDEF MSWINDOWS}
   npdfdriver.PDFFile.Canvas.ForceComplexShaping := UseExactPdfText;
   atext.Type1Font:=integer(poLinked);
{$ELSE}
   // Measured exactly as TRpPDFDriver measures it (same font kind, shaping
   // mode and conformance): EngineTextRect draws it the way the PDF canvas does
   SyncTextPdfConformance;
   npdfdriver.PDFFile.Canvas.ForceComplexShaping := EngineForceShaping;
{$ENDIF}
   npdfdriver.TextExtent(atext,extent);
   exit;
  end;


 if atext.CutText then
 begin
  maxextent:=extent;
 end;
 if (toprinter) then
 begin
  if not printer.Printing then
   Raise Exception.Create(SRpGDIDriverNotInit);
  dpix:=intdpix;
  dpiy:=intdpiy;
  Canvas:=printer.canvas;
 end
 else
 begin
  if not Assigned(bitmap) then
   Raise Exception.Create(SRpGDIDriverNotInit);
  if not Assigned(metacanvas) then
  begin
   if assigned(meta) then
   begin
    meta.free;
    meta:=nil;
   end;
   meta:=TBitmap.Create;
   meta.Width:=bitmapwidth;
   meta.Height:=bitmapheight;
   metacanvas:=meta.Canvas;
  end;
  Canvas:=metacanvas;
  dpix:=Screen.PixelsPerInch;
  dpiy:=Screen.PixelsPerInch;
 end;
 Canvas.Font.Name:=atext.WFontName;
 Canvas.Font.Style:=CLXIntegerToFontStyle(atext.FontStyle);
 Canvas.Font.Size:=atext.FontSize;
 Canvas.Font.Color:=CLXColorToVCLColor(atext.FontColor);
 // Find device font
// if devicefonts then
//  FindDeviceFont(Canvas.Handle,Canvas.Font,FontSizeToStep(Canvas.Font.Size,atext.PrintStep));
 aatext:=atext.text;
 aansitext:=aatext;
 arec.Left:=0;
 arec.Top:=0;
 arec.Bottom:=0;
 arec.Right:=Round(extent.X*dpix/TWIPS_PER_INCHESS);
 // calculates the text extent
 // Win9x does not support drawing WideChars
 textstyle.Wordbreak:=atext.WordWrap;
 textstyle.ShowPrefix:=false;
 textstyle.Clipping:=atext.CutText;
 textstyle.Layout:=tlTop;
 if (atext.AlignMent AND AlignmentFlags_AlignVCenter)>0 then
    textstyle.Layout:=tlCenter
 else
  if (atext.AlignMent AND AlignmentFlags_AlignBottom)>0 then
    textstyle.Layout:=tlBottom;
 textstyle.Alignment:=taLeftJustify;
 if (atext.AlignMent AND AlignmentFlags_AlignHCenter)>0 then
  textstyle.Alignment:=taCenter;
 if (atext.AlignMent AND AlignmentFlags_AlignRight)>0 then
  textstyle.Alignment:=taRightJustify;
 textstyle.RightToLeft:=atext.RightToLeft;


 //Canvas.TextRect(arec,arec.Left,arec.Top,aatext,newstyle);
 //Canvas.TextExtent();

 // Transformates to twips
 extent.X:=Round(arec.Right/dpix*TWIPS_PER_INCHESS);
 extent.Y:=Round(arec.Bottom/dpiy*TWIPS_PER_INCHESS);
 if (atext.CutText) then
 begin
  if maxextent.Y<extent.Y then
   extent.Y:=maxextent.Y;
 end;

end;

function TRpGDIDriver.TextExtentLineInfo(atext:TRpTextObject;var extent:TPoint):TRpLineInfoArray;
begin
 if not assigned(npdfdriver) then
 begin
   npdfdriver:=TRpPDFDriver.Create;
   if assigned(FReport) then
     npdfdriver.PDFConformance := FReport.PDFConformance;
 end;
{$IFDEF MSWINDOWS}
 npdfdriver.PDFFile.Canvas.ForceComplexShaping := UseExactPdfText;
 atext.Type1Font:=integer(poLinked);
{$ELSE}
 SyncTextPdfConformance;
 npdfdriver.PDFFile.Canvas.ForceComplexShaping := EngineForceShaping;
{$ENDIF}
 Result:=npdfdriver.TextExtentLineInfo(atext,extent);
end;

{$IFNDEF MSWINDOWS}
// Shaping mode of TRpPDFDriver: forced only with UsePdfFonts (which the PDF
// driver also turns on for PrinterFonts=Recalculate). PDF/A-3 embeds the
// fonts but keeps the plain text pipeline.
function TRpGDIDriver.EngineForceShaping: boolean;
begin
  Result := UsePdfFonts;
  if (not Result) and Assigned(FReport) then
    Result := (FReport.PrinterFonts = rppfontsrecalculate);
end;

// The PDF canvas takes its conformance only in TRpPDFFile.BeginDoc, which the
// measuring driver never calls: without this a PDF/A-3 report was measured and
// drawn with the PDF 1.4 line spacing while its PDF uses the font height.
procedure TRpGDIDriver.SyncTextPdfConformance;
begin
  if not Assigned(npdfdriver) then
    exit;
  if Assigned(FReport) and (npdfdriver.PDFConformance <> FReport.PDFConformance) then
    npdfdriver.PDFConformance := FReport.PDFConformance;
  npdfdriver.PDFFile.Canvas.PDFConformance := npdfdriver.PDFConformance;
end;
{$ENDIF}

// The model pen style is the VCL TPenStyle ordinal (5 clear, 6 inside frame,
// as rpgdidriver and the PDF canvas read it). The LCL enumeration differs from
// 5 on (psinsideFrame=5, psPattern=6, psClear=7): a direct cast turned the
// clear pen into a solid inside-frame line.
function RpModelPenStyle(Value: Integer): TPenStyle;
begin
 case Value of
  1: Result:=psDash;
  2: Result:=psDot;
  3: Result:=psDashDot;
  4: Result:=psDashDotDot;
  5: Result:=psClear;
  6: Result:=psInsideFrame;
 else
  Result:=psSolid;
 end;
end;

function CleanGraphicStream(Src: TStream): TStream;
var
  buf: array[0..63] of Byte;
  readLen, i: Integer;
  foundPos: Int64;
  mem: TMemoryStream;
begin
  Result := Src;
  if (Src = nil) or (Src.Size < 4) then
    Exit;

  Src.Position := 0;
  readLen := Src.Read(buf[0], SizeOf(buf));
  Src.Position := 0;
  if readLen < 2 then
    Exit;

  // Direct match at 0: BMP, JPEG, PNG
  if ((buf[0] = $42) and (buf[1] = $4D)) or
     ((buf[0] = $FF) and (buf[1] = $D8)) or
     ((readLen >= 4) and (buf[0] = $89) and (buf[1] = $50) and (buf[2] = $4E) and (buf[3] = $47)) then
    Exit;

  // Search first 64 bytes for BM, JPEG, or PNG headers
  foundPos := -1;
  for i := 0 to readLen - 2 do
  begin
    if (buf[i] = $42) and (buf[i+1] = $4D) then
    begin
      foundPos := i;
      Break;
    end
    else if (buf[i] = $FF) and (buf[i+1] = $D8) then
    begin
      foundPos := i;
      Break;
    end
    else if (i + 3 < readLen) and (buf[i] = $89) and (buf[i+1] = $50) and (buf[i+2] = $4E) and (buf[i+3] = $47) then
    begin
      foundPos := i;
      Break;
    end;
  end;

  if foundPos > 0 then
  begin
    mem := TMemoryStream.Create;
    Src.Position := foundPos;
    mem.CopyFrom(Src, Src.Size - foundPos);
    mem.Position := 0;
    Src.Position := 0;
    Result := mem;
  end;
end;

procedure TRpGDIDriver.PrintObject(Canvas:TCanvas;page:TRpMetafilePage;obj:TRpMetaObject;dpix,dpiy:integer;toprinter:boolean;
 pagemargins:TRect;devicefonts:boolean;offset:TPoint;selected:boolean);
var
 posx,posy:integer;
 rec,recsrc:TRect;
 X, Y, W, H, S: Integer;
 Width,Height:integer;
 stream:TMemoryStream;
 cleanStream:TStream;
 bitmap:TBitmap;
 aalign:Cardinal;
 abrushstyle:integer;
 atext:widestring;
 aansitext:string;
 arec:TRect;
 calcrect:boolean;
 alvbottom,alvcenter:boolean;
 rotrad,fsize:double;
 aresult:integer;
{$IFNDEF DOTNETD}
 jpegimage:TJPegImage;
 pngimage:TPortableNetworkGraphic;
 gpicture:TPicture;
{$ENDIF}
 bitmapwidth,bitmapheight:integer;
 astring:WideString;
 drawbackground:boolean;
 abackcolor:TColor;
 oldhandle:THandle;
 format:string;
{$IFDEF DELPHI2009UP}
 npng:TPngImage;
{$ENDIF}
 propx,propy:double;
begin
 // Switch to device points
 oldhandle:=0;
 if toprinter then
 begin
  // If printer then must be displaced
  posx:=round((obj.Left-pagemargins.Left+offset.X)*dpix/TWIPS_PER_INCHESS);
  posy:=round((obj.Top-pagemargins.Top+offset.Y)*dpiy/TWIPS_PER_INCHESS);
 end
 else
 begin
  // The offset (twips) is also honoured here: the text rectangle below adds it,
  // so shapes and images must too (DoMetafileToBitmap stacks pages with it)
  posx:=round((obj.Left+offset.X)*dpix/TWIPS_PER_INCHESS);
  posy:=round((obj.Top+offset.Y)*dpiy/TWIPS_PER_INCHESS);
 end;
 case obj.Metatype of
  rpMetaText:
   begin
{$IFNDEF MSWINDOWS}
    // Same family the PDF driver takes on this platform
    FTextFamily:=page.GetLFontName(Obj);
    FTextType1Font:=obj.Type1Font;
    FTextFamilySet:=true;
{$ENDIF}
    Canvas.Font.Name:=page.GetWFontName(Obj);
    Canvas.Font.Color:=CLXColorToVCLColor(Obj.FontColor);
    Canvas.Font.Style:=CLXIntegerToFontStyle(obj.FontStyle);
    Canvas.Font.Size:=Obj.FontSize;
    Canvas.Font.Height:=-Round(Obj.FontSize * dpiy / 72);
    try
    if obj.FontRotation<>0 then
    begin
     oldhandle:=Canvas.Font.Handle;
     // Find rotated font
     rotrad:=obj.FontRotation/10*(2*PI/360);
     Canvas.Font.Orientation:=obj.FontRotation;
     //Canvas.Font.Handle:=FindRotatedFont(Canvas.Handle,Canvas.Font,obj.FontRotation);
     // Moves the print position
     fsize:=Obj.FontSize/72*dpiy;
     posx:=posx-Round(fsize*sin(rotrad));
     posy:=posy+Round(fsize-fsize*cos(rotrad));
    end
    else
    begin
     Canvas.Font.Orientation:=0;
     // Find device font
     //if devicefonts then
     // FindDeviceFont(Canvas.Handle,Canvas.Font,FontSizeToStep(Canvas.Font.Size,obj.PrintStep));
    end;
    // Allways use pdf driver
//    if (obj.AlignMent AND AlignmentFlags_AlignHJustify)>0 then
//    if true then
    begin
     astring:=page.GetText(Obj);
     rec.Left:=obj.Left+offset.X;
     rec.Top:=obj.Top+offset.Y;
     if toprinter then
     begin
      rec.Left:=rec.Left-pagemargins.Left;
      rec.Top:=rec.Top-pagemargins.Top;
     end;
     rec.Right:=rec.Left+obj.Width;
     rec.Bottom:=rec.Top+obj.Height;
     if ((obj.Transparent) and (not selected)) then
     begin
      //SetBkMode(Canvas.Handle,TRANSPARENT);
      drawbackground:=false;
     end
     else
     begin
      //SetBkMode(Canvas.Handle,OPAQUE);
      drawbackground:=true ;
     end;
     abackcolor:=CLXColorToVCLColor(obj.BackColor);
     if selected then
     begin
      Canvas.Brush.Color:=clHighlight;
      Canvas.Font.Color:=clHighlightText;
      // The text routines paint the background with this color
      abackcolor:=clHighlight;
     end;
     if obj.IsHtml then
     begin
       TextRectHtml(Canvas, rec, astring, obj.AlignMent, obj.CutText, obj.WordWrap,
         obj.FontRotation, obj.FontStyle, drawbackground, abackcolor,
         dpix, dpiy, true, obj.RightToLeft, obj.FontSize);
     end
     else if (UseExactPdfText and (obj.FontRotation = 0) and
              ((obj.Alignment and AlignmentFlags_AlignHJustify) = 0)) then
     begin
       TextRectHtml(Canvas, rec, astring, obj.AlignMent, obj.CutText, obj.WordWrap,
         obj.FontRotation, obj.FontStyle, drawbackground, abackcolor,
         dpix, dpiy, false, obj.RightToLeft, obj.FontSize);
     end
     else
     begin
       // The VCL driver draws the remaining plain text with DrawTextW, but only
       // because its TextExtent measured it with GDI. This driver measures ALL
       // text with the PDF driver (TextExtent above), so the drawing has to use
       // the same layout: the former "native" branch was identical to this one.
       TextRectJustify(Canvas, rec, astring, obj.AlignMent, obj.CutText, obj.WordWrap,
         obj.FontRotation, obj.RightToLeft, drawbackground, abackcolor,
         dpix, dpiy, false, obj.FontSize);
     end;

    end;
    finally
      if (obj.FontRotation<>0) then
      begin
        Canvas.Font.Handle:=oldhandle;
      end;
{$IFNDEF MSWINDOWS}
      FTextFamilySet:=false;
{$ENDIF}
    end;
   end;
  rpMetaDraw:
   begin
    Width:=round(obj.Width*dpix/TWIPS_PER_INCHESS);
    Height:=round(obj.Height*dpiy/TWIPS_PER_INCHESS);
    abrushstyle:=obj.BrushStyle;
    if obj.BrushStyle>integer(bsDiagCross) then
     abrushstyle:=integer(bsDiagCross);
    Canvas.Pen.Color:=CLXColorToVCLColor(obj.Pencolor);
    Canvas.Pen.Style:=RpModelPenStyle(obj.PenStyle);
    Canvas.Brush.Color:=CLXColorToVCLColor(obj.BrushColor);
    // The brush ordinals match (TRpBrushStyle / VCL / LCL up to bsDiagCross)
    Canvas.Brush.Style:=TBrushStyle(abrushstyle);
    Canvas.Pen.Width:=Round(dpix*obj.PenWidth/TWIPS_PER_INCHESS);
    X := Canvas.Pen.Width div 2;
    Y := X;
    W := Width - Canvas.Pen.Width + 1;
    H := Height - Canvas.Pen.Width + 1;
    if Canvas.Pen.Width = 0 then
    begin
     Dec(W);
     Dec(H);
    end;
    if W < H then
     S := W
    else
     S := H;
    if TRpShapeType(obj.DrawStyle) in [rpsSquare, rpsRoundSquare, rpsCircle] then
    begin
     Inc(X, (W - S) div 2);
     Inc(Y, (H - S) div 2);
     W := S;
     H := S;
    end;
    case TRpShapeType(obj.DrawStyle) of
     rpsRectangle, rpsSquare:
      Canvas.Rectangle(X+PosX, Y+PosY, X+PosX + W, Y +PosY+ H);
     rpsRoundRect, rpsRoundSquare:
      Canvas.RoundRect(X+PosX, Y+PosY, X +PosX + W, Y + PosY+ H, S div 4, S div 4);
     rpsCircle, rpsEllipse:
      Canvas.Ellipse(X+PosX, Y+PosY, X+PosX + W, Y+PosY + H);
     rpsHorzLine:
      begin
       Canvas.MoveTo(X+PosX, Y+PosY);
       Canvas.LineTo(X+PosX+W, Y+PosY);
      end;
     rpsVertLine:
      begin
       Canvas.MoveTo(X+PosX, Y+PosY);
       Canvas.LineTo(X+PosX, Y+PosY+H);
      end;
     rpsOblique1:
      begin
       Canvas.MoveTo(X+PosX, Y+PosY);
       Canvas.LineTo(X+PosX+W, Y+PosY+H);
      end;
     rpsOblique2:
      begin
       Canvas.MoveTo(X+PosX, Y+PosY+H);
       Canvas.LineTo(X+PosX+W, Y+PosY);
      end;
    end;
    Canvas.Brush.Style := bsClear;
   end;
  rpMetaImage:
   begin
    if (Not (obj.PreviewOnly and toprinter)) then
    begin
    Width:=round(obj.Width*dpix/TWIPS_PER_INCHESS);
    Height:=round(obj.Height*dpiy/TWIPS_PER_INCHESS);
    rec.Top:=PosY;
    rec.Left:=PosX;
    rec.Bottom:=rec.Top+Height-1;
    rec.Right:=rec.Left+Width-1;

    stream:=page.GetStream(obj);
    bitmap:=TBitmap.Create;
    try
     bitmap.PixelFormat:=pf24bit;
     cleanStream:=CleanGraphicStream(stream);
     try
      format:='';
      GetJPegInfo(cleanStream,bitmapwidth,bitmapheight,format);
      cleanStream.Position:=0;
      try
       if (format='JPEG') then
       begin
        jpegimage:=TJPegImage.Create;
        try
         jpegimage.LoadFromStream(cleanStream);
         bitmap.Assign(jpegimage);
        finally
         jpegimage.free;
        end;
       end
       else if (format='PNG') then
       begin
        pngimage:=TPortableNetworkGraphic.Create;
        try
         pngimage.LoadFromStream(cleanStream);
         bitmap.Assign(pngimage);
        finally
         pngimage.Free;
        end;
       end
       else if (format='BMP') then
       begin
        bitmap.LoadFromStream(cleanStream);
        bitmap.PixelFormat:=pf24bit;
       end
       else
       begin
        gpicture:=TPicture.Create;
        try
         gpicture.LoadFromStream(cleanStream);
         bitmap.PixelFormat:=pf24bit;
         bitmap.Width:=gpicture.Width;
         bitmap.Height:=gpicture.Height;
         bitmap.Canvas.Draw(0,0,gpicture.Graphic);
        finally
         gpicture.Free;
        end;
       end;
      except
       // Keep rendering even if individual image blob is damaged
      end;
     finally
      if cleanStream<>stream then
       cleanStream.Free;
     end;
//     Copy mode does not work for StretDIBBits
//     Canvas.CopyMode:=CLXCopyModeToCopyMode(obj.CopyMode);

     case TRpImageDrawStyle(obj.DrawImageStyle) of
      rpDrawFull:
       begin
        rec.Bottom:=rec.Top+round(bitmap.height/obj.dpires*dpiy)-1;
        rec.Right:=rec.Left+round(bitmap.width/obj.dpires*dpix)-1;
        recsrc.Left:=0;
        recsrc.Top:=0;
        recsrc.Right:=bitmap.Width-1;
        recsrc.Bottom:=bitmap.Height-1;
        DrawBitmap(Canvas,bitmap,rec,recsrc);
       end;
      rpDrawStretch:
       begin
        recsrc.Left:=0;
        recsrc.Top:=0;
        recsrc.Right:=bitmap.Width-1;
        recsrc.Bottom:=bitmap.Height-1;
        DrawBitmap(Canvas,bitmap,rec,recsrc);
       end;
      rpDrawCrop:
       begin
        //recsrc.Left:=0;
        //recsrc.Top:=0;
        //recsrc.Right:=rec.Right-rec.Left;
        //recsrc.Bottom:=rec.Bottom-rec.Top;
        //DrawBitmap(Canvas,bitmap,rec,recsrc);
         recsrc.Left:=0;
         recsrc.Top:=0;
         recsrc.Right:=bitmap.Width-1;
         recsrc.Bottom:=bitmap.Height-1;
         propx:=(rec.Right-rec.Left)/bitmap.Width;
         propy:=(rec.Bottom-rec.Top)/bitmap.Height;
         if (propy>propx) then
         begin
          H:=Round((rec.Right-rec.Left)*propx/propy);
          rec.Top:=rec.Top+((rec.Bottom-rec.Top)-H) div 2;
          rec.Bottom:=rec.Top+H;
         end
         else
         begin
          W:=Round((rec.Right-rec.Left)*propy/propx);
          rec.Left:=rec.Left+((rec.Right-rec.Left)-W) div 2;
          rec.Right:=rec.Left+W;
         end;
         DrawBitmap(Canvas,bitmap,rec,recsrc);

       end;
      rpDrawTile,rpDrawTiledpi:
       begin
        // Set clip region
        //oldrgn:=CreateRectRgn(0,0,2,2);
        //aresult:=GetClipRgn(Canvas.Handle,oldrgn);
        //newrgn:=CreateRectRgn(rec.Left,rec.Top,rec.Right,rec.Bottom);
        //SelectClipRgn(Canvas.handle,newrgn);
        //if TRpImageDrawStyle(obj.DrawImageStyle)=rpDrawTile then
        // DrawBitmapMosaicSlow(Canvas,rec,bitmap,0)
        //else
        // DrawBitmapMosaicSlow(Canvas,rec,bitmap,obj.DPIres);
        //if aresult=0 then
        // SelectClipRgn(Canvas.handle,0)
        //else
        // SelectClipRgn(Canvas.handle,oldrgn);
       end;
     end;
    finally
     bitmap.Free;
    end;
   end;
   end;
 end;
end;

procedure TRpGDIDriver.ComputeGlyphPixPositions(const linfo: TRpLineInfo;
  Alignment: Integer; ARect: TRect; aintdpix: Integer;
  out allPixPos, allDx: TIntegerDynArray);
var
  glyphCount: Integer;
  k: Integer;
  pixRight, cumRight: Integer;
  pixLeft, totalTwips, totalPix, rectPix, cumLeft: Integer;
begin
  glyphCount := Length(linfo.Glyphs);
  SetLength(allPixPos, glyphCount);
  SetLength(allDx, glyphCount);
  if glyphCount = 0 then
    exit;
  if ((Alignment AND AlignmentFlags_AlignRight) > 0) then
  begin
    // Right-anchored: iterate backwards from right edge
    pixRight := Round(ARect.Right * aintdpix / 1440);
    cumRight := 0;
    for k := glyphCount - 1 downto 0 do
    begin
      cumRight := cumRight + linfo.Glyphs[k].XAdvance;
      allPixPos[k] := pixRight - Round(cumRight * aintdpix / 1440);
    end;
  end
  else
  begin
    // Left-anchored (left or center alignment)
    pixLeft := Round(ARect.Left * aintdpix / 1440);
    if (Alignment AND AlignmentFlags_AlignHCenter) > 0 then
    begin
      totalTwips := 0;
      for k := 0 to glyphCount - 1 do
        totalTwips := totalTwips + linfo.Glyphs[k].XAdvance;
      totalPix := Round(totalTwips * aintdpix / 1440);
      rectPix := Round(ARect.Right * aintdpix / 1440) - pixLeft;
      pixLeft := pixLeft + ((rectPix - totalPix) div 2);
    end;
    cumLeft := 0;
    for k := 0 to glyphCount - 1 do
    begin
      allPixPos[k] := pixLeft + Round(cumLeft * aintdpix / 1440);
      cumLeft := cumLeft + linfo.Glyphs[k].XAdvance;
    end;
  end;
  // Compute dx values from consecutive pixel positions
  for k := 0 to glyphCount - 2 do
    allDx[k] := allPixPos[k + 1] - allPixPos[k];
  // Last glyph dx (cell width)
  allDx[glyphCount - 1] := Round(linfo.Glyphs[glyphCount - 1].XAdvance * aintdpix / 1440);
end;

procedure TRpGDIDriver.DrawGlyphRuns(Canvas: TCanvas; const linfo: TRpLineInfo;
  const allPixPos, allDx: TIntegerDynArray; nposy: integer; aintdpiy: integer;
  BaseFontStyle: integer; ptFontSize: Integer = 0);
var
  k: integer;
  glyphCount: integer;
  runStyle, glyphStyle: Integer;
  baseBold, baseItalic, baseUnderline, baseStrikeOut: Boolean;
  runGlyphs: array of Word;
  runDx: array of Integer;
  runFontFamily: string;
  runFontSize: Single;
  runColor: Integer;
  runHasColor: Boolean;
  origFontName: string;
  origFontSize: Integer;
  origFontColor: TColor;
  origFontStyle: TFontStyles;
  runFirstGlyph: Integer;
{$IFDEF MSWINDOWS}
  baseTM, runTM: TTextMetric;
  baseAscent, baselineOffset: Integer;
  pixY: Integer;
{$ENDIF}
  gFontFamily: string;
  gFontSize: Single;
  gColor: Integer;
  gHasColor: Boolean;
begin
  glyphCount := Length(linfo.Glyphs);
  if glyphCount = 0 then
    exit;
  baseBold := (BaseFontStyle and 1) > 0;
  baseItalic := (BaseFontStyle and 2) > 0;
  baseUnderline := (BaseFontStyle and 4) > 0;
  baseStrikeOut := (BaseFontStyle and 8) > 0;

  runStyle := linfo.Glyphs[0].Style;
  runFontFamily := linfo.Glyphs[0].FontFamily;
  runFontSize := linfo.Glyphs[0].FontSize;
  runColor := linfo.Glyphs[0].Color;
  runHasColor := linfo.Glyphs[0].HasColor;
  origFontName := Canvas.Font.Name;
  if ptFontSize > 0 then
    origFontSize := ptFontSize
  else
    origFontSize := Canvas.Font.Size;
  origFontColor := Canvas.Font.Color;
  origFontStyle := Canvas.Font.Style;
  if not linfo.Glyphs[0].HasFontSize then
    runFontSize := origFontSize;

  runFirstGlyph := 0;
  SetLength(runGlyphs, 0);
  SetLength(runDx, 0);

{$IFDEF MSWINDOWS}
  Canvas.Font.Name := origFontName;
  Canvas.Font.Height := -Round(origFontSize * aintdpiy / 72);
  SelectObject(Canvas.Handle, Canvas.Font.Handle);
  SetTextColor(Canvas.Handle, ColorToRGB(Canvas.Font.Color));
  SetBkMode(Canvas.Handle, TRANSPARENT);
  GetTextMetrics(Canvas.Handle, baseTM);
  baseAscent := baseTM.tmAscent;
{$ENDIF}

  for k := 0 to glyphCount - 1 do
  begin
    glyphStyle := linfo.Glyphs[k].Style;
    gFontFamily := linfo.Glyphs[k].FontFamily;
    gFontSize := linfo.Glyphs[k].FontSize;
    if not linfo.Glyphs[k].HasFontSize then
      gFontSize := origFontSize;

    gColor := linfo.Glyphs[k].Color;
    gHasColor := linfo.Glyphs[k].HasColor;

    if ((glyphStyle <> runStyle) or (gFontFamily <> runFontFamily) or
        (gFontSize <> runFontSize) or (gColor <> runColor) or
        (gHasColor <> runHasColor)) and (Length(runGlyphs) > 0) then
    begin
      Canvas.Font.Style := [];
      if baseBold or ((runStyle and 1) > 0) then
        Canvas.Font.Style := Canvas.Font.Style + [fsBold];
      if baseItalic or ((runStyle and 2) > 0) then
        Canvas.Font.Style := Canvas.Font.Style + [fsItalic];
      if baseUnderline or ((runStyle and 4) > 0) then
        Canvas.Font.Style := Canvas.Font.Style + [fsUnderline];
      if baseStrikeOut or ((runStyle and 8) > 0) then
        Canvas.Font.Style := Canvas.Font.Style + [fsStrikeOut];
      if runFontFamily <> '' then
        Canvas.Font.Name := runFontFamily
      else
        Canvas.Font.Name := origFontName;
      Canvas.Font.Height := -Round(runFontSize * aintdpiy / 72);
      if runHasColor then
        Canvas.Font.Color := runColor
      else
        Canvas.Font.Color := origFontColor;

{$IFDEF MSWINDOWS}
      SelectObject(Canvas.Handle, Canvas.Font.Handle);
      SetTextColor(Canvas.Handle, ColorToRGB(Canvas.Font.Color));
      SetBkMode(Canvas.Handle, TRANSPARENT);
      GetTextMetrics(Canvas.Handle, runTM);
      baselineOffset := runTM.tmAscent - baseAscent;
      pixY := Round(nposy * aintdpiy / 1440) - baselineOffset;
      ExtTextOutW(Canvas.Handle, allPixPos[runFirstGlyph], pixY, $0010 {ETO_GLYPH_INDEX}, nil,
        PWideChar(@runGlyphs[0]), Length(runGlyphs), @runDx[0]);
{$ENDIF}

      SetLength(runGlyphs, 0);
      SetLength(runDx, 0);
      runStyle := glyphStyle;
      runFontFamily := gFontFamily;
      runFontSize := gFontSize;
      runColor := gColor;
      runHasColor := gHasColor;
      runFirstGlyph := k;
    end;

    SetLength(runGlyphs, Length(runGlyphs) + 1);
    runGlyphs[High(runGlyphs)] := Word(linfo.Glyphs[k].GlyphIndex);
    SetLength(runDx, Length(runDx) + 1);
    runDx[High(runDx)] := allDx[k];
  end;

  if Length(runGlyphs) > 0 then
  begin
    Canvas.Font.Style := [];
    if baseBold or ((runStyle and 1) > 0) then
      Canvas.Font.Style := Canvas.Font.Style + [fsBold];
    if baseItalic or ((runStyle and 2) > 0) then
      Canvas.Font.Style := Canvas.Font.Style + [fsItalic];
    if baseUnderline or ((runStyle and 4) > 0) then
      Canvas.Font.Style := Canvas.Font.Style + [fsUnderline];
    if baseStrikeOut or ((runStyle and 8) > 0) then
      Canvas.Font.Style := Canvas.Font.Style + [fsStrikeOut];
    if runFontFamily <> '' then
      Canvas.Font.Name := runFontFamily
    else
      Canvas.Font.Name := origFontName;
    Canvas.Font.Height := -Round(runFontSize * aintdpiy / 72);
    if runHasColor then
      Canvas.Font.Color := runColor
    else
      Canvas.Font.Color := origFontColor;

{$IFDEF MSWINDOWS}
    SelectObject(Canvas.Handle, Canvas.Font.Handle);
    SetTextColor(Canvas.Handle, ColorToRGB(Canvas.Font.Color));
    SetBkMode(Canvas.Handle, TRANSPARENT);
    GetTextMetrics(Canvas.Handle, runTM);
    baselineOffset := runTM.tmAscent - baseAscent;
    pixY := Round(nposy * aintdpiy / 1440) - baselineOffset;
    ExtTextOutW(Canvas.Handle, allPixPos[runFirstGlyph], pixY, $0010 {ETO_GLYPH_INDEX}, nil,
      PWideChar(@runGlyphs[0]), Length(runGlyphs), @runDx[0]);
{$ENDIF}
  end;

  Canvas.Font.Name := origFontName;
  Canvas.Font.Height := -Round(origFontSize * aintdpiy / 72);
  Canvas.Font.Color := origFontColor;
  Canvas.Font.Style := origFontStyle;
{$IFDEF MSWINDOWS}
  SelectObject(Canvas.Handle, Canvas.Font.Handle);
{$ENDIF}
end;

procedure TRpGDIDriver.TextRectJustifyGlyphs(Canvas: TCanvas; const ARect: TRect; Text: WideString;
  const larray: TRpLineInfoArray; Alignment: integer; posy: integer;
  aintdpix, aintdpiy: integer; RightToLeft: Boolean; ptFontSize: Integer = 0);
var
  i, index: integer;
  posx, currpos, alinedif, alinesize: integer;
  astring, aword: WideString;
  lwords: TRpWideStrings;
  lwidths: TStringList;
  lwordinfos: array of TRpLineInfo;
  winfos: TRpLineInfoArray;
  arec, wordrect: TRect;
  ascent, nposy: integer;
  basestyle: integer;
  allPixPos, allDx: TIntegerDynArray;
  dojustify: boolean;
begin
  basestyle := 0;
  if fsBold in Canvas.Font.Style then
    basestyle := basestyle or 1;
  if fsItalic in Canvas.Font.Style then
    basestyle := basestyle or 2;
  if fsUnderline in Canvas.Font.Style then
    basestyle := basestyle or 4;
  if fsStrikeOut in Canvas.Font.Style then
    basestyle := basestyle or 8;
  ascent := 0;
  for i := 0 to Length(larray) - 1 do
  begin
    if (i = 0) then
      ascent := larray[0].TopPos;
    if Length(larray[i].Glyphs) = 0 then
      continue;
    astring := Copy(Text, larray[i].Position, larray[i].Size);
    nposy := posy + larray[i].TopPos - ascent;
    // Line start with horizontal alignment, same expressions as the PDF canvas
    posx := ARect.Left;
    if ((Alignment AND AlignmentFlags_AlignRight) > 0) then
      posx := ARect.Right - larray[i].Width;
    if (Alignment AND AlignmentFlags_AlignHCenter) > 0 then
      posx := ARect.Left + (((ARect.Right - ARect.Left) - larray[i].Width) div 2);
    dojustify := ((Alignment AND AlignmentFlags_AlignHJustify) > 0) and
      (not larray[i].LastLine) and (not RightToLeft);
    if dojustify then
    begin
      // Word splitting, same criteria the PDF canvas uses (ASCII space)
      lwords := TRpWideStrings.Create;
      try
        aword := '';
        index := 1;
        while index <= Length(astring) do
        begin
          if astring[index] <> ' ' then
            aword := aword + astring[index]
          else
          begin
            if Length(aword) > 0 then
              lwords.Add(aword);
            aword := '';
          end;
          Inc(index);
        end;
        if Length(aword) > 0 then
          lwords.Add(aword);
        // Measure every word with the shaper, keeping its glyphs
        alinesize := 0;
        lwidths := TStringList.Create;
        try
          if ptFontSize > 0 then
            npdfdriver.PDFFile.Canvas.Font.Size := ptFontSize;
          SetLength(lwordinfos, lwords.Count);
          for index := 0 to lwords.Count - 1 do
          begin
            arec := ARect;
            winfos := npdfdriver.PDFFile.Canvas.TextExtent(lwords.Strings[index], arec,
              false, true, RightToLeft);
            if Length(winfos) > 0 then
              lwordinfos[index] := winfos[0]
            else
              lwordinfos[index] := larray[i];
            if RightToLeft then
              lwidths.Add(IntToStr(-(arec.Right - arec.Left)))
            else
              lwidths.Add(IntToStr(arec.Right - arec.Left));
            alinesize := alinesize + arec.Right - arec.Left;
          end;
          // Same integer space-distribution arithmetic as TRpPDFCanvas.TextRect
          alinedif := ARect.Right - ARect.Left - alinesize;
          if alinedif > 0 then
          begin
            if lwords.Count > 1 then
              alinedif := alinedif div (lwords.Count - 1);
            if RightToLeft then
            begin
              currpos := ARect.Right;
              alinedif := -alinedif;
            end
            else
              currpos := posx;
            for index := 0 to lwords.Count - 1 do
            begin
              if Length(lwordinfos[index].Glyphs) > 0 then
              begin
                wordrect.Left := currpos;
                wordrect.Top := 0;
                wordrect.Right := currpos;
                wordrect.Bottom := 0;
                ComputeGlyphPixPositions(lwordinfos[index], 0, wordrect, aintdpix,
                  allPixPos, allDx);
                DrawGlyphRuns(Canvas, lwordinfos[index], allPixPos, allDx, nposy,
                  aintdpiy, basestyle, ptFontSize);
              end;
              currpos := currpos + StrToInt(lwidths.Strings[index]) + alinedif;
            end;
          end
          else
            dojustify := false;
        finally
          lwidths.Free;
        end;
      finally
        lwords.Free;
      end;
    end;
    if not dojustify then
    begin
      // Whole line at its aligned position (last paragraph line or lines where
      // the space cannot be distributed)
      ComputeGlyphPixPositions(larray[i], Alignment, ARect, aintdpix, allPixPos, allDx);
      DrawGlyphRuns(Canvas, larray[i], allPixPos, allDx, nposy, aintdpiy, basestyle, ptFontSize);
    end;
  end;
end;

procedure TRpGDIDriver.TextRectHtml(Canvas: TCanvas; ARect: TRect; Text: Widestring;
  Alignment: integer; Clipping: boolean; Wordbreak: boolean;
  Rotation: integer; BaseFontStyle: integer; drawbackground: boolean;
  BackColor: TColor; adpix: integer = 0; adpiy: integer = 0;
  IsHtml: Boolean = True; RightToLeft: Boolean = False; ptFontSize: Integer = 0);
var
  recsize: TRect;
  i: integer;
  posx, posy: integer;
  singleline: boolean;
  larray: TRpLineInfoArray;
  ascent: Integer;
{$IFDEF MSWINDOWS}
  clipRgn: HRGN;
  clipRect: TRect;
  savedDC: Integer;
{$ENDIF}
  aintdpix, aintdpiy: integer;
  nposx, nposy: integer;
  arec2: TRect;
  runText: WideString;
  origFontStyle: TFontStyles;
  allPixPos: TIntegerDynArray;
  allDx: TIntegerDynArray;
  textstyle: TTextStyle;
begin
{$IFNDEF MSWINDOWS}
  // Glyph runs, clipping and HTML styles are painted by the engine renderer
  EngineTextRect(Canvas, ARect, Text, Alignment, Clipping, Wordbreak, Rotation,
    RightToLeft, IsHtml, drawbackground, BackColor, adpix, adpiy, ptFontSize);
  exit;
{$ENDIF}
{$IFDEF MSWINDOWS}
  savedDC := 0;
  clipRgn := 0;
{$ENDIF}
  try
    textstyle := Canvas.TextStyle;
    textstyle.Opaque := drawbackground;
    textstyle.ShowPrefix := false;
    textstyle.Clipping := false;
    textstyle.Alignment := taLeftJustify;

    if drawbackground then
    begin
      Canvas.Pen.Color := BackColor;
      Canvas.Brush.Color := BackColor;
      Canvas.Brush.Style := bsSolid;
    end
    else
    begin
      Canvas.Brush.Style := bsClear;
    end;
    singleline := (Alignment AND AlignmentFlags_SingleLine) > 0;
    if singleline then
      Wordbreak := false;

    if adpix > 0 then
    begin
      aintdpix := adpix;
      aintdpiy := adpiy;
    end
    else if toprinter then
    begin
      if intdpix = 0 then
      begin
        intdpix := printer.XDPI;
        intdpiy := printer.YDPI;
      end;
      aintdpix := intdpix;
      aintdpiy := intdpiy;
    end
    else
    begin
      aintdpix := dpi;
      aintdpiy := dpi;
    end;

    if Clipping then
    begin
{$IFDEF MSWINDOWS}
      clipRect.Left   := Round(ARect.Left   * aintdpix / 1440);
      clipRect.Right  := Round(ARect.Right  * aintdpix / 1440);
      clipRect.Top    := Round(ARect.Top    * aintdpiy / 1440);
      clipRect.Bottom := Round(ARect.Bottom * aintdpiy / 1440);
      savedDC := SaveDC(Canvas.Handle);
      clipRgn := CreateRectRgn(clipRect.Left, clipRect.Top, clipRect.Right, clipRect.Bottom);
      SelectClipRgn(Canvas.Handle, clipRgn);
{$ENDIF}
    end;

    recsize := ARect;
    if not assigned(npdfdriver) then
    begin
      npdfdriver := TRpPDFDriver.Create;
      if Assigned(FReport) then
        npdfdriver.PDFConformance := FReport.PDFConformance
      else
        npdfdriver.PDFConformance := TPDFConformanceType.PDF_A_3;
    end;
    if ptFontSize > 0 then
      npdfdriver.PDFFile.Canvas.Font.Size := ptFontSize
    else
      npdfdriver.PDFFile.Canvas.Font.Size := Canvas.Font.Size;
    npdfdriver.PDFFile.Canvas.Font.WFontName := Canvas.Font.Name;
    npdfdriver.PDFFile.Canvas.Font.Name := poLinked;
    npdfdriver.PDFFile.Canvas.Font.Color := Canvas.Font.Color;
    npdfdriver.PDFFile.Canvas.Font.Italic := fsItalic in Canvas.Font.Style;
    npdfdriver.PDFFile.Canvas.Font.Bold := fsBold in Canvas.Font.Style;
    npdfdriver.PDFFile.Canvas.Font.Underline := fsUnderline in Canvas.Font.Style;
    npdfdriver.PDFFile.Canvas.Font.StrikeOut := fsStrikeOut in Canvas.Font.Style;

    npdfdriver.PDFFile.Canvas.ForceComplexShaping := True;

    if RightToLeft and Assigned(npdfdriver.PDFFile.Canvas.InfoProvider) then
      Text := npdfdriver.PDFFile.Canvas.InfoProvider.NFCNormalize(Text);

    larray := npdfdriver.PDFFile.Canvas.TextExtent(Text, recsize, Wordbreak, singleline,
      RightToLeft, IsHtml);

    origFontStyle := Canvas.Font.Style;

    posy := ARect.Top;
    if (Alignment AND AlignmentFlags_AlignBottom) > 0 then
      posy := ARect.Bottom - recsize.Bottom;
    if (Alignment AND AlignmentFlags_AlignVCenter) > 0 then
      posy := ARect.Top + (((ARect.Bottom - ARect.Top) - recsize.Bottom) div 2);

    ascent := 0;
    for i := 0 to Length(larray) - 1 do
    begin
      if (i = 0) then
        ascent := larray[0].TopPos;
      posx := ARect.Left;

      if ((Alignment AND AlignmentFlags_AlignRight) > 0) then
        posx := ARect.Right - larray[i].Width
      else if (Alignment AND AlignmentFlags_AlignHCenter) > 0 then
        posx := ARect.Left + (((ARect.Right - ARect.Left) - larray[i].Width) div 2);

{$IFDEF MSWINDOWS}
      if Length(larray[i].Glyphs) > 0 then
      begin
        ComputeGlyphPixPositions(larray[i], Alignment, ARect, aintdpix, allPixPos, allDx);
        nposy := posy + larray[i].TopPos - ascent;
        DrawGlyphRuns(Canvas, larray[i], allPixPos, allDx, nposy, aintdpiy, BaseFontStyle, ptFontSize);
      end
      else
{$ENDIF}
      begin
        nposx := posx;
        nposy := posy + larray[i].TopPos - ascent;
        nposx := Round(nposx * aintdpix / 1440);
        nposy := Round(nposy * aintdpiy / 1440);
        arec2.Left := nposx;
        arec2.Top := nposy;
        arec2.Bottom := arec2.Top + Round(larray[i].Height * aintdpiy / 1440);
        arec2.Right := Round(ARect.Right * aintdpix / 1440);
        runText := larray[i].Text;
        Canvas.TextRect(arec2, arec2.Left, arec2.Top, runText, textstyle);
      end;
    end;

    Canvas.Font.Style := origFontStyle;
  finally
{$IFDEF MSWINDOWS}
    if Clipping then
    begin
      RestoreDC(Canvas.Handle, savedDC);
      DeleteObject(clipRgn);
    end;
{$ENDIF}
  end;
end;

procedure TRpGDIDriver.TextRectJustify(Canvas:TCanvas;ARect: TRect; Text: Widestring;
                       Alignment: integer; Clipping: boolean;Wordbreak:boolean;
                       Rotation:integer;RightToLeft:Boolean;drawbackground:Boolean;backcolor:TColor;
                        adpix: integer = 0; adpiy: integer = 0; IsHtml: Boolean = False; ptFontSize: Integer = 0);
var
 recsize:TRect;
 i,index:integer;
 posx,posY,currpos,alinedif:integer;
 singleline:boolean;
 astring:WideString;
 alinesize:integer;
 lwords:TRpWideStrings;
 lwidths:TStringList;
 arec,arec2:TRect;
 aword:WideString;
 nposx,nposy:integer;
 aatext:WideString;
 aansitext:string;
 aalign:Cardinal;
 aintdpix,aintdpiy:integer;
 lastword:boolean;
 textstyle:TTextStyle;
 larray:TRpLineInfoArray;
 ascent:integer;
{$IFDEF MSWINDOWS}
 clipRgn: HRGN;
 clipRect: TRect;
 savedDC: Integer;
{$ENDIF}
begin
{$IFNDEF MSWINDOWS}
 // Same text layout as the PDF driver, painted from the engine runs
 EngineTextRect(Canvas, ARect, Text, Alignment, Clipping, Wordbreak, Rotation,
   RightToLeft, IsHtml, drawbackground, backcolor, adpix, adpiy, ptFontSize);
 exit;
{$ENDIF}
{$IFDEF MSWINDOWS}
 savedDC := 0;
 clipRgn := 0;
{$ENDIF}
 try
  textstyle := Canvas.TextStyle;
  textstyle.Opaque := drawbackground;
  textstyle.Clipping := false;
  textstyle.ShowPrefix := false;
  if drawbackground then
  begin
   Canvas.Brush.Style := bsSolid;
   Canvas.Pen.Color := backcolor;
   Canvas.Brush.Color := backcolor;
  end
  else
  begin
   Canvas.Brush.Style := bsClear;
  end;
  singleline:=(Alignment AND AlignmentFlags_SingleLine)>0;
  if singleline then
   wordbreak:=false;
  if adpix > 0 then
  begin
   aintdpix := adpix;
   aintdpiy := adpiy;
  end
  else if toprinter then
  begin
   if intdpix=0 then
   begin
    intdpix:=printer.XDPI;
    intdpiy:=printer.YDPI;
   end;
   aintdpix:=intdpix;
   aintdpiy:=intdpiy;
  end
  else
  begin
   aintdpix:=dpi;
   aintdpiy:=dpi;
  end;
{$IFDEF MSWINDOWS}
  if Clipping then
  begin
    clipRect.Left   := Round(ARect.Left   * aintdpix / 1440);
    clipRect.Right  := Round(ARect.Right  * aintdpix / 1440);
    clipRect.Top    := Round(ARect.Top    * aintdpiy / 1440);
    clipRect.Bottom := Round(ARect.Bottom * aintdpiy / 1440);
    savedDC := SaveDC(Canvas.Handle);
    clipRgn := CreateRectRgn(clipRect.Left, clipRect.Top, clipRect.Right, clipRect.Bottom);
    SelectClipRgn(Canvas.Handle, clipRgn);
  end;
{$ENDIF}
  // Calculates text extent and apply alignment
  recsize:=ARect;
  if not assigned(npdfdriver) then
  begin
    npdfdriver:=TRpPDFDriver.Create;
    if Assigned(FReport) then
      npdfdriver.PDFConformance := FReport.PDFConformance
    else
      npdfdriver.PDFConformance := TPDFConformanceType.PDF_A_3;
  end;
  if ptFontSize > 0 then
    npdfdriver.PDFFile.Canvas.Font.Size := ptFontSize
  else
    npdfdriver.PDFFile.Canvas.Font.Size := Canvas.Font.Size;
  npdfdriver.PDFFile.Canvas.Font.WFontName:=Canvas.Font.Name;
  npdfdriver.PDFFile.Canvas.Font.Name:=poLinked;
  npdfdriver.PDFFile.Canvas.Font.Color:=Canvas.Font.Color;
  npdfdriver.PDFFile.Canvas.Font.Italic:=fsItalic in Canvas.Font.Style;
  npdfdriver.PDFFile.Canvas.Font.Bold:=fsBold in Canvas.Font.Style;
  npdfdriver.PDFFile.Canvas.Font.Underline:=fsUnderline in Canvas.Font.Style;
  npdfdriver.PDFFile.Canvas.Font.StrikeOut:=fsStrikeOut in Canvas.Font.Style;

  npdfdriver.PDFFile.Canvas.ForceComplexShaping := UseExactPdfText;
  if RightToLeft and UseExactPdfText and Assigned(npdfdriver.PDFFile.Canvas.InfoProvider) then
    Text := npdfdriver.PDFFile.Canvas.InfoProvider.NFCNormalize(Text);

  larray:=npdfdriver.PDFFile.Canvas.TextExtent(Text,recsize,wordbreak,singleline,RightToLeft,IsHtml);
  // Align bottom or center
  PosY:=ARect.Top;
  if (AlignMent AND AlignmentFlags_AlignBottom)>0 then
  begin
   PosY:=ARect.Bottom-recsize.bottom;
  end;
  if (AlignMent AND AlignmentFlags_AlignVCenter)>0 then
  begin
   PosY:=ARect.Top+(((ARect.Bottom-ARect.Top)-recsize.Bottom) div 2);
  end;

{$IFDEF MSWINDOWS}
  if UseExactPdfText and (Rotation = 0) then
  begin
    TextRectJustifyGlyphs(Canvas, ARect, Text, larray, Alignment, posy,
      aintdpix, aintdpiy, RightToLeft, ptFontSize);
    exit;
  end;
{$ENDIF}

  ascent := 0;
  for i:=0 to Length(larray)-1 do
  begin
   if i = 0 then
    ascent := larray[0].TopPos;
   posX:=ARect.Left;
   // Aligns horz.
   if  ((Alignment AND AlignmentFlags_AlignRight)>0) then
   begin
    // recsize.right contains the width of the full text
    PosX:=ARect.Right-larray[i].Width;
   end;
   // Aligns horz.
   if (Alignment AND AlignmentFlags_AlignHCenter)>0 then
   begin
    PosX:=ARect.Left+(((Arect.Right-Arect.Left)-larray[i].Width) div 2);
   end;
   astring:=Copy(Text,larray[i].Position,larray[i].Size);
   if  (((Alignment AND AlignmentFlags_AlignHJustify)>0) AND (NOT larray[i].LastLine)) then
   begin
    // Calculate the sizes of the words, then
    // share space between words
    lwords:=TRpWideStrings.Create;
    try
     aword:='';
     index:=1;
     while index<=Length(astring) do
     begin
      if astring[index]<>' ' then
      begin
       aword:=aword+astring[index];
      end
      else
      begin
       if Length(aword)>0 then
        lwords.Add(aword);
       aword:='';
      end;
      inc(index);
     end;
     if Length(aword)>0 then
       lwords.Add(aword);
     // Calculate all words size
     alinesize:=0;
     lwidths:=TStringList.Create;
     try
      for index:=0 to lwords.Count-1 do
      begin
       arec:=ARect;
       npdfdriver.pdffile.Canvas.TextExtent(lwords.Strings[index],arec,false,true,RightToLeft);
       if RightToLeft then
        lwidths.Add(IntToStr(-(arec.Right-arec.Left)))
       else
        lwidths.Add(IntToStr(arec.Right-arec.Left));
       alinesize:=alinesize+arec.Right-arec.Left;
      end;
      alinedif:=ARect.Right-ARect.Left-alinesize;
      if alinedif<0 then
       alinedif:=0;
      if lwords.count>1 then
       alinedif:=alinedif div (lwords.count-1);
      if RightToLeft then
      begin
       currpos:=ARect.Right;
       alinedif:=-alinedif;
      end
      else
       currpos:=PosX;
      for index:=0 to lwords.Count-1 do
      begin
       nposx:=currpos;
       nposy:=PosY+larray[i].TopPos-ascent;
       nposx:=Round(nposx*aintdpix/1440);
       nposy:=Round(nposy*aintdpiy/1440);
       arec2.Left:=nposx;
       arec2.Top:=nposy;
       arec2.Right:=Round(ARect.Right*aintdpix/1440);
       arec2.Bottom:=arec2.Top+Round(larray[i].Height*aintdpiy/1440);
       textstyle.Opaque:=drawbackground;
       textstyle.ShowPrefix:=false;
       textstyle.Clipping:=false;
       lastword:=((index=lwords.Count-1) AND (lwords.count>1));
       if lastword then
        textstyle.Alignment:=taRightJustify
       else
        textstyle.Alignment:=taLeftJustify;
       aatext:=lwords.strings[index];
       Canvas.TextRect(arec2,arec2.Left,arec2.Top,aatext,textstyle);
       currpos:=currpos+StrToInt(lwidths.Strings[index])+alinedif;
      end;
     finally
      lwidths.Free;
     end;
    finally
     lwords.free;
    end;
   end
   else
   begin
    textstyle.Opaque:=drawbackground;
    textstyle.Clipping:=false;
    textstyle.ShowPrefix:=false;
    textstyle.Alignment:=taLeftJustify;
    nposx:=Posx;
    nposy:=PosY+larray[i].TopPos-ascent;
    nposx:=Round(nposx*aintdpix/1440);
    nposy:=Round(nposy*aintdpiy/1440);
    arec2.Left:=nposx;
    arec2.Top:=nposy;
    arec2.Right:=Round(ARect.Right*aintdpix/1440);
    arec2.Bottom:=arec2.Top+Round(larray[i].Height*aintdpiy/1440);
    Canvas.TextRect(arec2,arec2.Left,arec2.Top,astring,textstyle);
   end;
  end;
  finally
{$IFDEF MSWINDOWS}
    if Clipping then
    begin
      RestoreDC(Canvas.Handle, savedDC);
      DeleteObject(clipRgn);
    end;
{$ENDIF}
  end;
end;

{$IFNDEF MSWINDOWS}
{ ---------------------------------------------------------------------------
  Engine text renderer (Linux / Unix)

  The text is laid out by the PDF canvas of the embedded PDF driver (the very
  code TRpPDFCanvas.TextRect runs) and every glyph is painted at the position
  that layout gives it: shaped runs (HTML, right to left, complex scripts,
  forced shaping) with their own glyph ids and advances, plain text with the
  font widths the PDF writes. With GTK2 the glyphs go through Cairo using the
  font files the engine's FreeType provider resolved, so line breaks,
  positions, clipping and HTML styles match the PDF. Other widgetsets fall back
  to the LCL canvas, still at the engine positions.
  --------------------------------------------------------------------------- }

type
  TRpPaintGlyph = record
    Index: Cardinal;   // glyph id in the run font
    X, Y: Double;      // twips: absolute, or relative to the rotation origin
    Ch: WideChar;      // character, only for the LCL fallback
  end;
  TRpPaintGlyphArray = array of TRpPaintGlyph;

  TRpPaintFont = record
    Family: string;
    Bold, Italic: Boolean;
    SizePt: Integer;
    FileName: string;
    FaceIndex: Integer;
  end;

  TRpCanvasAccess = class(TCanvas);

  TRpTextPainter = class(TObject)
  private
    FCanvas: TCanvas;
    FDpiX, FDpiY: Integer;
    FUseCairo: Boolean;
    FRotated: Boolean;
    FRotOX, FRotOY: Double;
    FRotAngle: Double;
    FClipped: Boolean;
    FOldClipping: Boolean;
    FOldClipRect: TRect;
{$IFDEF RPLCLCAIRO}
    FCr: Pcairo_t;
    FOwnCr: Boolean;
    FDC: TGtkDeviceContext;
    FSX, FSY, FOX, FOY: Double;
    function BeginCairo: Boolean;
    procedure EndCairo;
    function UX(tw: Double): Double;
    function UY(tw: Double): Double;
    procedure CairoColor(AColor: TColor);
{$ENDIF}
    function DevX(tw: Double): Double;
    function DevY(tw: Double): Double;
    procedure FrameToDev(fx, fy: Double; out dx, dy: Double);
    procedure DrawRunLCL(const AFont: TRpPaintFont; AColor: TColor;
      const Glyphs: TRpPaintGlyphArray; Count: Integer);
  public
    constructor Create(ACanvas: TCanvas; ADpiX, ADpiY: Integer);
    destructor Destroy; override;
    procedure ClipTo(const R: TRect);
    procedure FillRectTw(x1, y1, x2, y2: Double; AColor: TColor);
    procedure LineTw(x1, y1, x2, y2, WidthTw: Double; AColor: TColor);
    procedure SetRotation(OX, OY: Double; Angle10: Integer);
    procedure ClearRotation;
    function GlyphForChar(const AFont: TRpPaintFont; Ch: WideChar): Cardinal;
    procedure DrawRun(const AFont: TRpPaintFont; AColor: TColor;
      const Glyphs: TRpPaintGlyphArray; Count: Integer);
  end;

{$IFDEF RPLCLCAIRO}
type
  // cairo_glyph_t: "unsigned long index" is 64 bit on LP64 (the record of the
  // FPC cairo unit declares it as LongWord)
  TRpCairoGlyph = record
    index: culong;
    x, y: Double;
  end;
  PRpCairoGlyph = ^TRpCairoGlyph;

  TRpCairoFaceEntry = class(TObject)
  public
    FTFace: FT_Face;
    CairoFace: Pcairo_font_face_t;
  end;

{$IFDEF UNIX}
  // Printer canvas of the CUPS printers: exposes its cairo context
  TRpCairoPrinterAccess = class(TCairoPrinterCanvas);
{$ENDIF}

const
  RP_FT_LOAD_NO_HINTING = 2;

function rp_cairo_ft_font_face_create_for_ft_face(face: Pointer;
  load_flags: cint): Pcairo_font_face_t; cdecl;
  external LIB_CAIRO name 'cairo_ft_font_face_create_for_ft_face';
procedure rp_cairo_show_glyphs(cr: Pcairo_t; glyphs: PRpCairoGlyph;
  num_glyphs: cint); cdecl; external LIB_CAIRO name 'cairo_show_glyphs';

var
  RpFTLibrary: FT_Library;
  RpFTLibraryReady: Boolean = False;
  // 'file|face' -> TRpCairoFaceEntry. The FreeType faces and the cairo font
  // faces live until the process ends (cairo keeps them in its own caches)
  RpCairoFaceCache: TStringList = nil;
  RpCairoFontOptions: Pcairo_font_options_t = nil;

function RpGetCairoFace(const FileName: string; FaceIndex: Integer): TRpCairoFaceEntry;
var
  key: string;
  idx: Integer;
  aface: FT_Face;
begin
  Result := nil;
  if (FileName = '') or (FaceIndex < 0) then
    exit;
  if RpCairoFaceCache = nil then
  begin
    RpCairoFaceCache := TStringList.Create;
    RpCairoFaceCache.Sorted := True;
    RpCairoFaceCache.OwnsObjects := True;
  end;
  key := FileName + '|' + IntToStr(FaceIndex);
  idx := RpCairoFaceCache.IndexOf(key);
  if idx >= 0 then
  begin
    Result := TRpCairoFaceEntry(RpCairoFaceCache.Objects[idx]);
    exit;
  end;
  // A failure is cached too (entry without faces)
  Result := TRpCairoFaceEntry.Create;
  RpCairoFaceCache.AddObject(key, Result);
  try
    CheckFreeTypeLoaded;
    if not RpFTLibraryReady then
    begin
      if FT_Init_FreeType(RpFTLibrary) <> 0 then
        exit;
      RpFTLibraryReady := True;
    end;
    aface := nil;
    if FT_New_Face(RpFTLibrary, PAnsiChar(UTF8Encode(FileName)), FaceIndex, aface) <> 0 then
      exit;
    Result.FTFace := aface;
    Result.CairoFace := rp_cairo_ft_font_face_create_for_ft_face(aface, RP_FT_LOAD_NO_HINTING);
    if (Result.CairoFace <> nil) and
       (cairo_font_face_status(Result.CairoFace) <> CAIRO_STATUS_SUCCESS) then
      Result.CairoFace := nil;
  except
    Result.CairoFace := nil;
  end;
end;

function RpCairoOptions: Pcairo_font_options_t;
begin
  if RpCairoFontOptions = nil then
  begin
    // Unhinted outlines at the exact positions, like a PDF rasterizer
    RpCairoFontOptions := cairo_font_options_create;
    cairo_font_options_set_antialias(RpCairoFontOptions, CAIRO_ANTIALIAS_GRAY);
    cairo_font_options_set_hint_style(RpCairoFontOptions, CAIRO_HINT_STYLE_NONE);
    cairo_font_options_set_hint_metrics(RpCairoFontOptions, CAIRO_HINT_METRICS_OFF);
  end;
  Result := RpCairoFontOptions;
end;
{$ENDIF}

constructor TRpTextPainter.Create(ACanvas: TCanvas; ADpiX, ADpiY: Integer);
begin
  inherited Create;
  FCanvas := ACanvas;
  FDpiX := ADpiX;
  FDpiY := ADpiY;
  if FDpiX < 1 then
    FDpiX := 1;
  if FDpiY < 1 then
    FDpiY := 1;
{$IFDEF RPLCLCAIRO}
  FUseCairo := BeginCairo;
{$ENDIF}
end;

destructor TRpTextPainter.Destroy;
begin
{$IFDEF RPLCLCAIRO}
  if FUseCairo then
    EndCairo;
{$ENDIF}
  if FClipped then
  begin
    if FOldClipping then
      FCanvas.ClipRect := FOldClipRect
    else
      FCanvas.Clipping := False;
  end;
  inherited Destroy;
end;

{$IFDEF RPLCLCAIRO}
function TRpTextPainter.BeginCairo: Boolean;
var
  h: HDC;
begin
  Result := False;
  FCr := nil;
  FOwnCr := False;
  FDC := nil;
  FSX := 1;
  FSY := 1;
  FOX := 0;
  FOY := 0;
{$IFDEF UNIX}
  if FCanvas is TCairoPrinterCanvas then
  begin
    // Printing through CUPS: draw on the canvas' own cairo context, whose
    // user space is the printer page in points (device pixel * Scale)
    h := FCanvas.Handle;
    if h = 0 then
      exit;
    FCr := TRpCairoPrinterAccess(FCanvas).cr;
    if FCr = nil then
      exit;
    FSX := TRpCairoPrinterAccess(FCanvas).ScaleX;
    FSY := TRpCairoPrinterAccess(FCanvas).ScaleY;
    cairo_save(FCr);
    Result := True;
    exit;
  end;
{$ENDIF}
  if FCanvas is TPrinterCanvas then
    exit;
  h := FCanvas.Handle;
  if h = 0 then
    exit;
  if not (TObject(h) is TGtkDeviceContext) then
    exit;
  FDC := TGtkDeviceContext(h);
  if FDC.Drawable = nil then
    exit;
  FCr := gdk_cairo_create(FDC.Drawable);
  if FCr = nil then
    exit;
  if cairo_status(FCr) <> CAIRO_STATUS_SUCCESS then
  begin
    cairo_destroy(FCr);
    FCr := nil;
    exit;
  end;
  FOwnCr := True;
  FOX := FDC.Offset.X;
  FOY := FDC.Offset.Y;
  Result := True;
end;

procedure TRpTextPainter.EndCairo;
begin
  if FCr = nil then
    exit;
  if FOwnCr then
  begin
    cairo_destroy(FCr);
    // The pixmap changed behind the LCL: drop the cached pixbuf and notify
    if Assigned(FDC) then
      FDC.RemovePixbuf;
    TRpCanvasAccess(FCanvas).Changed;
  end
  else
    cairo_restore(FCr);
  FCr := nil;
end;

function TRpTextPainter.UX(tw: Double): Double;
begin
  Result := DevX(tw) * FSX;
  if not FRotated then
    Result := Result + FOX;
end;

function TRpTextPainter.UY(tw: Double): Double;
begin
  Result := DevY(tw) * FSY;
  if not FRotated then
    Result := Result + FOY;
end;

procedure TRpTextPainter.CairoColor(AColor: TColor);
var
  c: Longint;
begin
  c := ColorToRGB(AColor);
  cairo_set_source_rgb(FCr, (c and $FF) / 255, ((c shr 8) and $FF) / 255,
    ((c shr 16) and $FF) / 255);
end;
{$ENDIF}

function TRpTextPainter.DevX(tw: Double): Double;
begin
  Result := tw * FDpiX / TWIPS_PER_INCHESS;
end;

function TRpTextPainter.DevY(tw: Double): Double;
begin
  Result := tw * FDpiY / TWIPS_PER_INCHESS;
end;

// Rotated frame (twips, origin at the rotation origin) to device pixels
procedure TRpTextPainter.FrameToDev(fx, fy: Double; out dx, dy: Double);
var
  s, c: Double;
begin
  if not FRotated then
  begin
    dx := DevX(fx);
    dy := DevY(fy);
    exit;
  end;
  s := Sin(FRotAngle);
  c := Cos(FRotAngle);
  dx := DevX(FRotOX) + DevX(fx) * c + DevY(fy) * s;
  dy := DevY(FRotOY) - DevX(fx) * s + DevY(fy) * c;
end;

procedure TRpTextPainter.ClipTo(const R: TRect);
begin
{$IFDEF RPLCLCAIRO}
  if FUseCairo then
  begin
    cairo_new_path(FCr);
    cairo_rectangle(FCr, UX(R.Left), UY(R.Top), UX(R.Right) - UX(R.Left),
      UY(R.Bottom) - UY(R.Top));
    cairo_clip(FCr);
    exit;
  end;
{$ENDIF}
  if not FClipped then
  begin
    FOldClipping := FCanvas.Clipping;
    FOldClipRect := FCanvas.ClipRect;
  end;
  FCanvas.ClipRect := Rect(Round(DevX(R.Left)), Round(DevY(R.Top)),
    Round(DevX(R.Right)), Round(DevY(R.Bottom)));
  FCanvas.Clipping := True;
  FClipped := True;
end;

procedure TRpTextPainter.FillRectTw(x1, y1, x2, y2: Double; AColor: TColor);
begin
{$IFDEF RPLCLCAIRO}
  if FUseCairo then
  begin
    CairoColor(AColor);
    cairo_new_path(FCr);
    cairo_rectangle(FCr, UX(x1), UY(y1), UX(x2) - UX(x1), UY(y2) - UY(y1));
    cairo_fill(FCr);
    exit;
  end;
{$ENDIF}
  FCanvas.Brush.Style := bsSolid;
  FCanvas.Brush.Color := AColor;
  FCanvas.FillRect(Rect(Round(DevX(x1)), Round(DevY(y1)), Round(DevX(x2)),
    Round(DevY(y2))));
end;

procedure TRpTextPainter.LineTw(x1, y1, x2, y2, WidthTw: Double; AColor: TColor);
var
  w, ax, ay, bx, by: Double;
begin
{$IFDEF RPLCLCAIRO}
  if FUseCairo then
  begin
    w := DevY(WidthTw) * FSY;
    if w < FSY then
      w := FSY;
    CairoColor(AColor);
    cairo_set_line_width(FCr, w);
    cairo_new_path(FCr);
    cairo_move_to(FCr, UX(x1), UY(y1));
    cairo_line_to(FCr, UX(x2), UY(y2));
    cairo_stroke(FCr);
    exit;
  end;
{$ENDIF}
  w := DevY(WidthTw);
  if w < 1 then
    w := 1;
  FrameToDev(x1, y1, ax, ay);
  FrameToDev(x2, y2, bx, by);
  FCanvas.Pen.Style := psSolid;
  FCanvas.Pen.Color := AColor;
  FCanvas.Pen.Width := Round(w);
  FCanvas.Line(Round(ax), Round(ay), Round(bx), Round(by));
end;

// Angle10: tenths of degree, counterclockwise (as the PDF "cm" rotation)
procedure TRpTextPainter.SetRotation(OX, OY: Double; Angle10: Integer);
begin
  FRotOX := OX;
  FRotOY := OY;
  FRotAngle := Angle10 / 10 * PI / 180;
{$IFDEF RPLCLCAIRO}
  if FUseCairo then
  begin
    cairo_save(FCr);
    cairo_translate(FCr, UX(OX), UY(OY));
    cairo_rotate(FCr, -FRotAngle);
  end;
{$ENDIF}
  FRotated := True;
end;

procedure TRpTextPainter.ClearRotation;
begin
  if not FRotated then
    exit;
{$IFDEF RPLCLCAIRO}
  if FUseCairo then
    cairo_restore(FCr);
{$ENDIF}
  FRotated := False;
end;

function TRpTextPainter.GlyphForChar(const AFont: TRpPaintFont; Ch: WideChar): Cardinal;
{$IFDEF RPLCLCAIRO}
var
  entry: TRpCairoFaceEntry;
{$ENDIF}
begin
  Result := 0;
{$IFDEF RPLCLCAIRO}
  if not FUseCairo then
    exit;
  entry := RpGetCairoFace(AFont.FileName, AFont.FaceIndex);
  if Assigned(entry) and Assigned(entry.FTFace) then
    Result := FT_Get_Char_Index(entry.FTFace, Ord(Ch));
{$ENDIF}
end;

procedure TRpTextPainter.DrawRun(const AFont: TRpPaintFont; AColor: TColor;
  const Glyphs: TRpPaintGlyphArray; Count: Integer);
{$IFDEF RPLCLCAIRO}
var
  entry: TRpCairoFaceEntry;
  m: cairo_matrix_t;
  cg: array of TRpCairoGlyph;
  i, n: Integer;
{$ENDIF}
begin
  if Count <= 0 then
    exit;
{$IFDEF RPLCLCAIRO}
  if FUseCairo then
  begin
    entry := RpGetCairoFace(AFont.FileName, AFont.FaceIndex);
    if Assigned(entry) and Assigned(entry.CairoFace) then
    begin
      cairo_set_font_face(FCr, entry.CairoFace);
      cairo_matrix_init_scale(@m, AFont.SizePt * FDpiX / 72 * FSX,
        AFont.SizePt * FDpiY / 72 * FSY);
      cairo_set_font_matrix(FCr, @m);
      cairo_set_font_options(FCr, RpCairoOptions);
      CairoColor(AColor);
      SetLength(cg, Count);
      n := 0;
      for i := 0 to Count - 1 do
      begin
        // Glyph 0 (.notdef: control characters, missing glyphs) leaves a blank
        // in the PDF too, instead of the box the font draws for it
        if Glyphs[i].Index = 0 then
          continue;
        cg[n].index := Glyphs[i].Index;
        cg[n].x := UX(Glyphs[i].X);
        cg[n].y := UY(Glyphs[i].Y);
        Inc(n);
      end;
      if n > 0 then
        rp_cairo_show_glyphs(FCr, @cg[0], n);
      exit;
    end;
  end;
{$ENDIF}
  DrawRunLCL(AFont, AColor, Glyphs, Count);
end;

// Without Cairo: each character at its engine position with the LCL canvas
// (no complex shaping, but the layout, the styles and the clipping are kept)
procedure TRpTextPainter.DrawRunLCL(const AFont: TRpPaintFont; AColor: TColor;
  const Glyphs: TRpPaintGlyphArray; Count: Integer);
var
  i: Integer;
  st: TFontStyles;
  tm: TLCLTextMetric;
  asc, dx, dy, ax, ay: Double;
begin
  FCanvas.Font.Name := AFont.Family;
  st := [];
  if AFont.Bold then
    Include(st, fsBold);
  if AFont.Italic then
    Include(st, fsItalic);
  FCanvas.Font.Style := st;
  FCanvas.Font.Height := -Round(AFont.SizePt * FDpiY / 72);
  FCanvas.Font.Color := AColor;
  if FRotated then
    FCanvas.Font.Orientation := Round(FRotAngle * 1800 / PI)
  else
    FCanvas.Font.Orientation := 0;
  FCanvas.Brush.Style := bsClear;
  asc := 0;
  if FCanvas.GetTextMetrics(tm) then
    asc := tm.Ascender;
  for i := 0 to Count - 1 do
  begin
    if Ord(Glyphs[i].Ch) < 32 then
      continue;
    FrameToDev(Glyphs[i].X, Glyphs[i].Y, dx, dy);
    // TextOut places the top of the cell: go up the ascent along the baseline normal
    if FRotated then
    begin
      ax := dx - asc * Sin(FRotAngle);
      ay := dy - asc * Cos(FRotAngle);
    end
    else
    begin
      ax := dx;
      ay := dy - asc;
    end;
    FCanvas.TextOut(Round(ax), Round(ay), UTF8Encode(WideString(Glyphs[i].Ch)));
  end;
  FCanvas.Font.Orientation := 0;
end;

function TRpGDIDriver.EngineResolveFont(const Family: string; Bold, Italic: Boolean;
  out FileName: string; out FaceIndex: integer): Boolean;
var
  key, value: string;
  p: Integer;
  pc: TRpPDFCanvas;
  oW, oL: WideString;
  oBold, oItalic: Boolean;
  oName: TRpType1Font;
  data: TRpTTFontData;
begin
  FileName := '';
  FaceIndex := -1;
  if FEngineFontCache = nil then
    FEngineFontCache := TStringList.Create;
  key := UpperCase(Family) + '/' + IntToStr(Ord(Bold)) + IntToStr(Ord(Italic));
  value := FEngineFontCache.Values[key];
  if value = '' then
  begin
    // The same request the PDF canvas makes (UpdateFonts -> provider SelectFont)
    // when it switches to this family and style
    // (for a PDF standard font it is the TrueType face the provider picks for
    // that family: the glyph shapes, the advances stay the standard ones)
    pc := npdfdriver.PDFFile.Canvas;
    oW := pc.Font.WFontName;
    oL := pc.Font.LFontName;
    oBold := pc.Font.Bold;
    oItalic := pc.Font.Italic;
    oName := pc.Font.Name;
    try
      pc.Font.WFontName := Family;
      pc.Font.LFontName := Family;
      pc.Font.Bold := Bold;
      pc.Font.Italic := Italic;
      if not (pc.Font.Name in [poLinked, poEmbedded]) then
        pc.Font.Name := poLinked;
      data := nil;
      try
        data := pc.UpdateFonts;
      except
        data := nil;
      end;
      if Assigned(data) and (data.filename <> '') then
        value := IntToStr(data.FontIndex) + '|' + data.filename
      else
        value := '-1|';
    finally
      pc.Font.WFontName := oW;
      pc.Font.LFontName := oL;
      pc.Font.Bold := oBold;
      pc.Font.Italic := oItalic;
      pc.Font.Name := oName;
    end;
    FEngineFontCache.Values[key] := value;
  end;
  p := Pos('|', value);
  FaceIndex := StrToIntDef(Copy(value, 1, p - 1), -1);
  FileName := Copy(value, p + 1, MaxInt);
  Result := (FaceIndex >= 0) and (FileName <> '');
end;

// Mirrors TRpPDFCanvas.TextOut: X is the line start, Y the line top (plain
// text) or the baseline (shaped text: TopPos includes the ascent)
procedure TRpGDIDriver.EngineTextOut(APainter: TObject; X, Y: integer; const Text: WideString;
  const linfo: TRpLineInfo; LineWidth, Rotation: integer; RightToLeft, IsHtml: Boolean);
var
  painter: TRpTextPainter;
  pc: TRpPDFCanvas;
  adata: TRpTTFontData;
  shaped: Boolean;
  ascent, linespacing, leading: integer;
  baseFamily: string;
  baseSize: integer;
  baseColor: TColor;
  baseBold, baseItalic: Boolean;
  ox, baseline, cursor, w: Double;
  i, n: integer;
  g: TGlyphPos;
  runFont, gFont: TRpPaintFont;
  runColor, gColor: TColor;
  run: TRpPaintGlyphArray;
  runCount: integer;
  ch: WideChar;
  penw: Double;
  posline, fontSizeOffset: integer;
  decCursor, ulStartX, soStartX, ulEndX, soEndX: Double;
  inUnderline, inStrikeOut, isLast, gUnderline, gStrikeOut: Boolean;
  ulFontSz, soFontSz, gFontSz: Single;
  lineY: Double;

  procedure FlushRun;
  begin
    if runCount > 0 then
      painter.DrawRun(runFont, runColor, run, runCount);
    runCount := 0;
  end;

  procedure AddGlyph(AIndex: Cardinal; AX, AY: Double; ACh: WideChar);
  begin
    if runCount >= Length(run) then
      SetLength(run, runCount * 2 + 16);
    run[runCount].Index := AIndex;
    run[runCount].X := AX;
    run[runCount].Y := AY;
    run[runCount].Ch := ACh;
    Inc(runCount);
  end;

begin
  painter := TRpTextPainter(APainter);
  pc := npdfdriver.PDFFile.Canvas;
  adata := nil;
  try
    adata := pc.UpdateFonts;
  except
    adata := nil;
  end;
  baseFamily := pc.Font.GetFontFamily;
  baseSize := pc.Font.Size;
  baseColor := TColor(pc.Font.Color);
  baseBold := pc.Font.Bold;
  baseItalic := pc.Font.Italic;
  shaped := RightToLeft or IsHtml or
    (pc.ForceComplexShaping and (Rotation = 0) and (Length(linfo.Glyphs) > 0));
  if Assigned(adata) then
    ascent := Round(adata.Ascent * baseSize * 20 / 1000)
  else
  begin
    pc.GetStdLineSpacing(linespacing, leading, ascent);
    if pc.PDFConformance > PDF_1_4 then
      ascent := Round(ascent * baseSize * 20 * 1.1 / 1000)
    else
      ascent := baseSize * 20;
  end;
  if Rotation <> 0 then
  begin
    // PDF: translate to (X, top + font size), rotate, text from the origin
    painter.SetRotation(X, Y + baseSize * 20, Rotation);
    ox := 0;
    baseline := 0;
  end
  else
  begin
    ox := X;
    if shaped then
      baseline := Y
    else
      baseline := Y + ascent;
  end;
  try
    runCount := 0;
    SetLength(run, 0);
    runFont.Family := baseFamily;
    runFont.Bold := baseBold;
    runFont.Italic := baseItalic;
    runFont.SizePt := baseSize;
    runFont.FileName := '';
    runFont.FaceIndex := -1;
    runColor := baseColor;
    if shaped then
    begin
      cursor := 0;
      for i := 0 to High(linfo.Glyphs) do
      begin
        g := linfo.Glyphs[i];
        // The font the shaper used for this glyph (TRpFTInfoProvider.TextExtentHtml)
        gFont.Family := g.FontFamily;
        if gFont.Family = '' then
          gFont.Family := baseFamily;
        gFont.Bold := baseBold or ((g.Style and 1) > 0);
        gFont.Italic := baseItalic or ((g.Style and 2) > 0);
        if g.HasFontSize then
          gFont.SizePt := Round(g.FontSize)
        else
          gFont.SizePt := baseSize;
        if g.HasColor then
          gColor := TColor(g.Color)
        else
          gColor := baseColor;
        if (runCount > 0) and ((gFont.Family <> runFont.Family) or
           (gFont.Bold <> runFont.Bold) or (gFont.Italic <> runFont.Italic) or
           (gFont.SizePt <> runFont.SizePt) or (gColor <> runColor)) then
          FlushRun;
        if runCount = 0 then
        begin
          runFont := gFont;
          EngineResolveFont(runFont.Family, runFont.Bold, runFont.Italic,
            runFont.FileName, runFont.FaceIndex);
          runColor := gColor;
        end;
        AddGlyph(Cardinal(g.GlyphIndex), ox + cursor + g.XOffset, baseline - g.YOffset,
          g.CharCode);
        cursor := cursor + g.XAdvance;
      end;
      FlushRun;
    end
    else
    begin
      // Plain text: the advances of the Tj/TJ the PDF writes (font widths and
      // kerning, TRpPDFCanvas.TextExtentSimple). A PDF standard font (no font
      // data) keeps its standard widths, drawn with the provider's face.
      if Assigned(adata) and (adata.filename <> '') then
      begin
        runFont.FileName := adata.filename;
        runFont.FaceIndex := adata.FontIndex;
      end
      else
      begin
        // The PDF names the standard font itself (/BaseFont), not the report
        // family: a viewer substitutes that one
        case pc.Font.Name of
          poHelvetica: runFont.Family := 'Helvetica';
          poCourier: runFont.Family := 'Courier';
          poTimesRoman: runFont.Family := 'Times';
          poSymbol: runFont.Family := 'Symbol';
          poZapfDingbats: runFont.Family := 'ZapfDingbats';
        end;
        EngineResolveFont(runFont.Family, runFont.Bold, runFont.Italic,
          runFont.FileName, runFont.FaceIndex);
      end;
      runColor := baseColor;
      cursor := 0;
      n := Length(Text);
      // TrueType without font data: no provider to measure with
      if (adata = nil) and (pc.Font.Name in [poLinked, poEmbedded]) then
        n := 0;
      for i := 1 to n do
      begin
        ch := Text[i];
        w := pc.CalcCharWidth(ch, adata);
        if Assigned(adata) and adata.havekerning and (i < n) then
          w := w - pc.InfoProvider.GetKerning(pc.Font, adata, ch, Text[i + 1]) * baseSize / 1000;
        if Ord(ch) >= 32 then
          AddGlyph(painter.GlyphForChar(runFont, ch), ox + cursor, baseline, ch);
        cursor := cursor + w * 20;
      end;
      FlushRun;
    end;

    // Underline and strikeout, as TRpPDFCanvas.TextOut draws them
    if IsHtml and (Length(linfo.Glyphs) > 0) then
    begin
      // Per glyph segments of the HTML styles
      if Rotation <> 0 then
        lineY := 0
      else
        lineY := Y;
      decCursor := 0;
      inUnderline := False;
      inStrikeOut := False;
      ulStartX := 0;
      soStartX := 0;
      ulFontSz := baseSize;
      soFontSz := baseSize;
      fontSizeOffset := Round(baseSize * 20);
      n := Length(linfo.Glyphs);
      for i := 0 to n do
      begin
        isLast := (i = n);
        gUnderline := False;
        gStrikeOut := False;
        gFontSz := baseSize;
        if not isLast then
        begin
          gUnderline := (linfo.Glyphs[i].Style and 4) > 0;
          gStrikeOut := (linfo.Glyphs[i].Style and 8) > 0;
          if linfo.Glyphs[i].HasFontSize then
            gFontSz := linfo.Glyphs[i].FontSize;
        end;
        if gUnderline and (not inUnderline) then
        begin
          inUnderline := True;
          ulStartX := ox + decCursor;
          ulFontSz := gFontSz;
        end
        else if ((not gUnderline) or isLast) and inUnderline then
        begin
          ulEndX := ox + decCursor;
          if gUnderline and isLast then
            ulEndX := ox + decCursor + linfo.Glyphs[i - 1].XAdvance;
          penw := Round(ulFontSz * 20 * CONS_UNDERLINEWIDTH);
          posline := Round(CONS_UNDERLINEPOS * (ulFontSz * 20));
          painter.LineTw(Round(ulStartX), lineY - fontSizeOffset + posline, Round(ulEndX),
            lineY - fontSizeOffset + posline, penw, baseColor);
          inUnderline := gUnderline;
          if gUnderline then
          begin
            ulStartX := ox + decCursor;
            ulFontSz := gFontSz;
          end;
        end;
        if gStrikeOut and (not inStrikeOut) then
        begin
          inStrikeOut := True;
          soStartX := ox + decCursor;
          soFontSz := gFontSz;
        end
        else if ((not gStrikeOut) or isLast) and inStrikeOut then
        begin
          soEndX := ox + decCursor;
          if gStrikeOut and isLast then
            soEndX := ox + decCursor + linfo.Glyphs[i - 1].XAdvance;
          penw := Round(soFontSz * 20 * CONS_UNDERLINEWIDTH);
          posline := Round(CONS_STRIKEOUTPOS * (soFontSz * 20));
          painter.LineTw(Round(soStartX), lineY - fontSizeOffset + posline, Round(soEndX),
            lineY - fontSizeOffset + posline, penw, baseColor);
          inStrikeOut := gStrikeOut;
          if gStrikeOut then
          begin
            soStartX := ox + decCursor;
            soFontSz := gFontSz;
          end;
        end;
        if not isLast then
          decCursor := decCursor + linfo.Glyphs[i].XAdvance;
      end;
    end
    else
    begin
      penw := Round(baseSize * 20 * CONS_UNDERLINEWIDTH);
      if pc.Font.Underline then
      begin
        posline := Round(CONS_UNDERLINEPOS * (baseSize * 20));
        if Rotation <> 0 then
          lineY := posline - baseSize * 20
        else
        begin
          lineY := Y + posline;
          // Shaped output gets the baseline in Y: back to the line top
          if shaped then
            lineY := lineY - Round(baseSize * 20);
        end;
        painter.LineTw(ox, lineY, ox + LineWidth, lineY, penw, baseColor);
      end;
      if pc.Font.StrikeOut then
      begin
        posline := Round(CONS_STRIKEOUTPOS * (baseSize * 20));
        if Rotation <> 0 then
          lineY := posline - baseSize * 20
        else
        begin
          lineY := Y + posline;
          if shaped then
            lineY := lineY - Round(baseSize * 20);
        end;
        painter.LineTw(ox, lineY, ox + LineWidth, lineY, penw, baseColor);
      end;
    end;
  finally
    if Rotation <> 0 then
      painter.ClearRotation;
  end;
end;

procedure TRpGDIDriver.EngineTextRect(Canvas: TCanvas; ARect: TRect; Text: WideString;
  Alignment: integer; Clipping, Wordbreak: boolean; Rotation: integer;
  RightToLeft, IsHtml, drawbackground: boolean; BackColor: TColor;
  adpix, adpiy, ptFontSize: integer);
var
  pc: TRpPDFCanvas;
  painter: TRpTextPainter;
  aintdpix, aintdpiy: integer;
  family: WideString;
  recsize, arec: TRect;
  larray, winfos, lwordinfos: TRpLineInfoArray;
  lwidths: array of integer;
  lwords: TRpWideStrings;
  singleline, dojustify: boolean;
  i, index, posx, posy, linetop, currpos, alinedif, alinesize, decowidth: integer;
  astring, aword: WideString;
begin
  ResolveTextDpi(adpix, adpiy, aintdpix, aintdpiy);
  EnsureTextPdfDriver;
  SyncTextPdfConformance;
  pc := npdfdriver.PDFFile.Canvas;
  // Font as TRpPDFDriver.DrawObject sets it (TextExtent measured it the same way)
  pc.ForceComplexShaping := EngineForceShaping and (Rotation = 0);
  if FTextFamilySet then
  begin
    family := FTextFamily;
    pc.Font.Name := TRpType1Font(FTextType1Font);
  end
  else
  begin
    family := Canvas.Font.Name;
    pc.Font.Name := poLinked;
  end;
  if npdfdriver.PDFConformance = TPDFConformanceType.PDF_A_3 then
    pc.Font.Name := poEmbedded;
  if EngineForceShaping and (not (pc.Font.Name in [poLinked, poEmbedded])) then
    pc.Font.Name := poLinked;
  pc.Font.WFontName := family;
  pc.Font.LFontName := family;
  if ptFontSize > 0 then
    pc.Font.Size := ptFontSize
  else
    pc.Font.Size := Canvas.Font.Size;
  pc.Font.Color := ColorToRGB(Canvas.Font.Color);
  pc.Font.Bold := fsBold in Canvas.Font.Style;
  pc.Font.Italic := fsItalic in Canvas.Font.Style;
  pc.Font.Underline := fsUnderline in Canvas.Font.Style;
  pc.Font.StrikeOut := fsStrikeOut in Canvas.Font.Style;
  // (the shaping mode is the measurement one; rotated text keeps the legacy
  // pipeline in the PDF canvas too)
  if (RightToLeft or IsHtml) and Assigned(pc.InfoProvider) then
    Text := pc.InfoProvider.NFCNormalize(Text);
  singleline := (Alignment and AlignmentFlags_SingleLine) > 0;
  if singleline then
    Wordbreak := false;
  recsize := ARect;
  larray := pc.TextExtent(Text, recsize, Wordbreak, singleline, RightToLeft, IsHtml);
  posy := ARect.Top;
  if (Alignment and AlignmentFlags_AlignBottom) > 0 then
    posy := ARect.Bottom - recsize.Bottom;
  if (Alignment and AlignmentFlags_AlignVCenter) > 0 then
    posy := ARect.Top + (((ARect.Bottom - ARect.Top) - recsize.Bottom) div 2);

  painter := TRpTextPainter.Create(Canvas, aintdpix, aintdpiy);
  try
    if Clipping then
      painter.ClipTo(ARect);
    linetop := posy;
    for i := 0 to Length(larray) - 1 do
    begin
      posx := ARect.Left;
      if (Alignment and AlignmentFlags_AlignRight) > 0 then
        posx := ARect.Right - larray[i].Width;
      if (Alignment and AlignmentFlags_AlignHCenter) > 0 then
        posx := ARect.Left + (((ARect.Right - ARect.Left) - larray[i].Width) div 2);
      astring := Copy(Text, larray[i].Position, larray[i].Size);
      dojustify := ((Alignment and AlignmentFlags_AlignHJustify) > 0) and
        (not larray[i].LastLine) and (not RightToLeft);
      if dojustify then
      begin
        // Space shared between the words, same arithmetic as the PDF canvas
        lwords := TRpWideStrings.Create;
        try
          aword := '';
          index := 1;
          while index <= Length(astring) do
          begin
            if astring[index] <> ' ' then
              aword := aword + astring[index]
            else
            begin
              if Length(aword) > 0 then
                lwords.Add(aword);
              aword := '';
            end;
            Inc(index);
          end;
          if Length(aword) > 0 then
            lwords.Add(aword);
          SetLength(lwordinfos, lwords.Count);
          SetLength(lwidths, lwords.Count);
          alinesize := 0;
          for index := 0 to lwords.Count - 1 do
          begin
            arec := ARect;
            winfos := pc.TextExtent(lwords.Strings[index], arec, false, true,
              RightToLeft, IsHtml);
            if Length(winfos) > 0 then
              lwordinfos[index] := winfos[0]
            else
              lwordinfos[index] := larray[i];
            lwidths[index] := arec.Right - arec.Left;
            alinesize := alinesize + lwidths[index];
          end;
          alinedif := ARect.Right - ARect.Left - alinesize;
          if alinedif > 0 then
          begin
            if lwords.Count > 1 then
              alinedif := alinedif div (lwords.Count - 1);
            currpos := posx;
            if drawbackground then
              painter.FillRectTw(posx, linetop, ARect.Right, linetop + larray[i].Height,
                BackColor);
            for index := 0 to lwords.Count - 1 do
            begin
              // Decorations run on to the next word, so an underline stays continuous
              decowidth := lwidths[index];
              if index < lwords.Count - 1 then
                decowidth := decowidth + alinedif;
              EngineTextOut(painter, currpos, posy + larray[i].TopPos,
                lwords.Strings[index], lwordinfos[index], decowidth, Rotation,
                RightToLeft, IsHtml);
              currpos := currpos + lwidths[index] + alinedif;
            end;
          end
          else
            // Overflowing line: drawn unjustified, as the PDF canvas does
            dojustify := false;
        finally
          lwords.Free;
        end;
      end;
      if not dojustify then
      begin
        if drawbackground then
          painter.FillRectTw(posx, linetop, posx + larray[i].Width,
            linetop + larray[i].Height, BackColor);
        EngineTextOut(painter, posx, posy + larray[i].TopPos, astring, larray[i],
          larray[i].Width, Rotation, RightToLeft, IsHtml);
      end;
      linetop := linetop + larray[i].Height;
    end;
  finally
    painter.Free;
  end;
end;
{$ENDIF}


procedure TRpGDIDriver.DrawPage(apage:TRpMetaFilePage);
var
 j:integer;
 rec:TRect;
 dpix,dpiy:integer;
 selected:boolean;
 pmargins:TRect;
begin
 if toprinter then
 begin
  for j:=0 to apage.ObjectCount-1 do
  begin
   IntDrawObject(apage,apage.Objects[j],false);
  end;
 end
 else
 begin
  UpdateBitmapSize(FReport,apage);
  if not Assigned(bitmap) then
    exit;

  rec.Top:=0;
  rec.Left:=0;
  rec.Right:=bitmap.Width;
  rec.Bottom:=bitmap.Height;

  bitmap.Canvas.Brush.Style:=bsSolid;
  bitmap.Canvas.Brush.Color:=CLXColorToVCLColor(BackColor);
  bitmap.Canvas.FillRect(rec);

  // Same resolution the page bitmap was sized with (UpdateBitmapSize):
  // dpi defaults to the screen one, SaveMetafileToPNG sets the requested one
  dpix := Round(dpi * scale);
  dpiy := Round(dpi * scale);
  if dpix < 1 then dpix := 1;
  if dpiy < 1 then dpiy := 1;

  pmargins.Left := 0;
  pmargins.Top := 0;
  pmargins.Right := 0;
  pmargins.Bottom := 0;

  for j:=0 to apage.ObjectCount-1 do
  begin
   if Assigned(FReport) then
     selected:=FReport.IsFound(apage,j)
   else
     selected:=false;
   PrintObject(bitmap.Canvas, apage, apage.Objects[j], dpix, dpiy, false, pmargins, false, offset, selected);
  end;

  // Draw page margins
  if (showpagemargins) then
  begin
   rec:=GetPageMarginsTWIPS;
   rec.Left:=Round(rec.Left*dpix/TWIPS_PER_INCHESS);
   rec.Top:=Round(rec.Top*dpiy/TWIPS_PER_INCHESS);
   rec.Right:=Round(rec.Right*dpix/TWIPS_PER_INCHESS);
   rec.Bottom:=Round(rec.Bottom*dpiy/TWIPS_PER_INCHESS);
   bitmap.Canvas.Brush.Style:=bsClear;
   bitmap.Canvas.Pen.Color:=clBlack;
   bitmap.Canvas.Pen.Style:=psSolid;
   bitmap.Canvas.Rectangle(rec);
  end;
 end;
end;

procedure TRpGDIDriver.DrawObject(page:TRpMetaFilePage;obj:TRpMetaObject);
begin
 IntDrawObject(page,obj,false);
end;

procedure TRpGDIDriver.IntDrawObject(page:TRpMetaFilePage;obj:TRpMetaObject;selected:boolean);
var
 dpix,dpiy:integer;
 Canvas:TCanvas;
begin
 if onlycalc then
  exit;
 if (toprinter) then
 begin
  if not printer.Printing then
   Raise Exception.Create(SRpGDIDriverNotInit);
  dpix:=intdpix;
  dpiy:=intdpiy;
  Canvas:=printer.canvas;
 end
 else
 begin
  if not Assigned(bitmap) then
   Raise Exception.Create(SRpGDIDriverNotInit);
  Canvas:=bitmap.Canvas;
  dpix:=Round(dpi * scale);
  dpiy:=Round(dpi * scale);
  if dpix < 1 then dpix := 1;
  if dpiy < 1 then dpiy := 1;
 end;
 PrintObject(Canvas,page,obj,dpix,dpiy,toprinter,pagemargins,devicefonts,offset,selected);
end;

function TRpGDIDriver.AllowCopies:boolean;
begin
 Result:=false;
end;

function TRpGDIDriver.GetPageSize(var PageSizeQt:Integer):TPoint;
var
  prect: TPaperRect;
  physW, physH: Integer;
begin
 PageSizeQt:=PageQt;
 if (FPageWidth = 0) or (FPageHeight = 0) then
 begin
  if (Printer.Printers.Count > 0) and (Printer.XDPI > 0) and (Printer.YDPI > 0) then
  begin
   prect := Printer.PaperSize.PaperRect;
   physW := prect.PhysicalRect.Right - prect.PhysicalRect.Left;
   physH := prect.PhysicalRect.Bottom - prect.PhysicalRect.Top;
   if (physW > 0) and (physH > 0) then
   begin
    if Printer.Orientation = poLandscape then
    begin
     Result.X := Round(physH * TWIPS_PER_INCHESS / Printer.YDPI);
     Result.Y := Round(physW * TWIPS_PER_INCHESS / Printer.XDPI);
    end
    else
    begin
     Result.X := Round(physW * TWIPS_PER_INCHESS / Printer.XDPI);
     Result.Y := Round(physH * TWIPS_PER_INCHESS / Printer.YDPI);
    end;
   end
   else
   begin
    Result.X := Round(PageSizeArray[0].Width / 1000 * TWIPS_PER_INCHESS);
    Result.Y := Round(PageSizeArray[0].Height / 1000 * TWIPS_PER_INCHESS);
   end;
  end
  else
  begin
   // Default to A4: 11906 x 16838 twips
   Result.X := Round(PageSizeArray[0].Width / 1000 * TWIPS_PER_INCHESS);
   Result.Y := Round(PageSizeArray[0].Height / 1000 * TWIPS_PER_INCHESS);
  end;
  FPageWidth := Result.X;
  FPageHeight := Result.Y;
 end
 else
 begin
  Result.X := FPageWidth;
  Result.Y := FPageHeight;
 end;
end;

function TRpGDIDriver.SetPagesize(PagesizeQt:TPageSizeQt):TPoint;
var
 newwidth,newheight:integer;
begin
 PageQt:=PagesizeQt.Indexqt;
 if PagesizeQt.Custom then
 begin
  PageQt:=-1;
  newwidth:=PagesizeQt.CustomWidth;
  newheight:=PagesizeQt.CustomHeight;
 end
 else
 begin
  if (PagesizeQt.Indexqt >= 0) and (PagesizeQt.Indexqt <= High(PageSizeArray)) then
  begin
   newWidth:=Round(PageSizeArray[PagesizeQt.Indexqt].Width/1000*TWIPS_PER_INCHESS);
   newheight:=Round(PageSizeArray[PagesizeQt.Indexqt].Height/1000*TWIPS_PER_INCHESS);
  end
  else
  begin
   newWidth:=Round(PageSizeArray[0].Width/1000*TWIPS_PER_INCHESS);
   newheight:=Round(PageSizeArray[0].Height/1000*TWIPS_PER_INCHESS);
  end;
 end;
 if FOrientation=rpOrientationLandscape then
 begin
  FPageWidth:=NewHeight;
  FPageHeight:=NewWidth;
 end
 else
 begin
  FPageWidth:=NewWidth;
  FPageHeight:=NewHeight;
 end;
 Result.X:=FPageWidth;
 Result.Y:=FPageHeight;
end;

procedure TRpGDIDriver.SetOrientation(Orientation:TRpOrientation);
var
 atemp:integer;
begin
 if Orientation<>FOrientation then
 begin
  if Orientation<>rpOrientationDefault then
  begin
   if (Orientation=rpOrientationLandscape) and (FOrientation<>rpOrientationLandscape) then
   begin
    atemp:=FPageWidth;
    FPageWidth:=FPageHeight;
    FPageHeight:=atemp;
    FOrientation:=Orientation;
   end
   else if (Orientation=rpOrientationPortrait) and (FOrientation<>rpOrientationPortrait) then
   begin
    atemp:=FPageWidth;
    FPageWidth:=FPageHeight;
    FPageHeight:=atemp;
    FOrientation:=Orientation;
   end;
  end;
 end;
 if Orientation=rpOrientationLandscape then
 begin
  if Printer.Orientation<>poLandscape then
  begin
   if not orientationset then
   begin
    orientationset:=true;
    oldorientation:=Printer.Orientation;
   end;
   if not Printer.Printing then
    Printer.Orientation:=poLandscape;
  end;
 end
 else if Orientation=rpOrientationPortrait then
 begin
  if Printer.Orientation<>poPortrait then
  begin
   if not orientationset then
   begin
    orientationset:=true;
    oldorientation:=Printer.Orientation;
   end;
   if not Printer.Printing then
    Printer.Orientation:=poPortrait;
  end;
 end;
end;

procedure TRpGDIDriver.RestoreOrientation;
begin
 if orientationset then
 begin
  if not Printer.Printing then
   Printer.Orientation := oldorientation;
  orientationset := false;
 end;
end;

function TRpGDIDriver.GetOrientation():TRpOrientation;
begin
 if FOrientation <> rpOrientationDefault then
  Result := FOrientation
 else if (Printer.Orientation = poPortrait) then
  Result := rpOrientationPortrait
 else
  Result := rpOrientationLandscape;
end;

procedure DoPrintMetafile(metafile:TRpMetafileReport;tittle:string;
 aform:TFRpVCLProgress;allpages:boolean;frompage,topage,copies:integer;
 collate:boolean;devicefonts:boolean;printerindex:TRpPrinterSelect=pRpDefaultPrinter;nobegindoc:boolean=false);
var
 i:integer;
 j:integer;
 apage:TRpMetafilePage;
 pagecopies:integer;
 reportcopies:integer;
 dpix,dpiy:integer;
 count1,count2:integer;
 mmfirst,mmlast:DWORD;
 difmilis:int64;
 totalcount:integer;
 pagemargins:TRect;
 offset:TPoint;
 istextonly:boolean;
 drivername,S:String;
 memstream:TMemoryStream;
 rPageSizeQt:TPageSizeQt;
 gdidriver:TRpGDIDriver;
 currentorientation:TPrinterOrientation;
 pconfig:TPrinterConfig;
begin
 pconfig.Changed:=false;
 gdidriver:=nil;
 try
 if copies=0 then
  copies:=1;
 drivername:=Trim(GetPrinterEscapeStyleDriver(printerindex));
 istextonly:=Length(drivername)>0;
 if istextonly then
 begin
  memstream:=TMemoryStream.Create;
  try
   rptextdriver.SaveMetafileRangeToText(metafile,allpages,frompage,topage,
    copies,memstream);
   memstream.Seek(0,soFromBeginning);
   SetLength(S,MemStream.Size);
{$IFNDEF DOTNETD}
   MemStream.Read(S[1],MemStream.Size);
{$ENDIF}
{$IFDEF DOTNETD}
   s:=MemStream.ToString;
{$ENDIF}
  finally
   memstream.free;
  end;
  // Now Prints to selected printer the stream
  if (not metafile.BlockPrinterSelection) then
   PrinterSelection(metafile.PrinterSelect,metafile.papersource,metafile.duplex,pconfig);
  //SendControlCodeToPrinter(S);
 end
 else
 begin
  if (not metafile.BlockPrinterSelection) then
  begin
   if printerindex<>pRpDefaultPrinter then
    offset:=PrinterSelection(printerindex,metafile.papersource,metafile.duplex,pconfig)
   else
    offset:=PrinterSelection(metafile.PrinterSelect,metafile.papersource,metafile.duplex,pconfig);
  end;
  //UpdatePrinterFontList;
  pagemargins:=GetPageMarginsTWIPS;
  // Get the time
  mmfirst:=GetTickCount;
  gdidriver:=TRpGDIDriver.Create;
  try
   currentorientation:=Printer.Orientation;
   // Sets page size and orientation
   if metafile.Orientation<>rpOrientationDefault then
   begin
    if metafile.Orientation=rpOrientationPortrait then
    begin
     if currentorientation<>poPortrait then
     begin
      gdidriver.orientationset:=true;
      gdidriver.oldorientation:=currentorientation;
      if printer.Printing then
       SetPrinterOrientation(false)
      else
       printer.Orientation:=poPortrait;
     end;
    end
    else
    begin
     if currentorientation<>poLandscape then
     begin
      gdidriver.orientationset:=true;
      gdidriver.oldorientation:=currentorientation;
      if printer.Printing then
       SetPrinterOrientation(true)
      else
       printer.Orientation:=poLandscape;
     end;
    end;
   end;
   // Sets pagesize
   rpagesizeQt.papersource:=metafile.PaperSource;
   rpagesizeQt.duplex:=metafile.duplex;
   if Metafile.PageSize<0 then
   begin
    rpagesizeqt.Custom:=True;
    rPageSizeQt.CustomWidth:=metafile.CustomX;
    rPageSizeQt.CustomHeight:=metafile.CustomY;
   end
   else
   begin
    rpagesizeqt.Indexqt:=metafile.PageSize;
    rpagesizeqt.Custom:=False;
   end;
    gdidriver.toprinter:=True;
    gdidriver.selectedprinter:=printerindex;
    gdidriver.SetPagesize(rpagesizeqt);
   except
    On E:Exception do
    begin
     rpgraphutilslcl.RpMessageBox(E.Message);
    end;
   end;
   pagecopies:=1;
   reportcopies:=1;

   if allpages then
   begin
    metafile.RequestPage(MAX_PAGECOUNT);
    frompage:=0;
    topage:=metafile.CurrentPageCount-1;
   end
   else
   begin
    frompage:=frompage-1;
    topage:=topage-1;
    metafile.RequestPage(topage);
    if topage>metafile.CurrentPageCount-1 then
     topage:=metafile.CurrentPageCount-1;
   end;
   //if metafile.OpenDrawerBefore then
     //SendControlCodeToPrinter(GetPrinterRawOp(printerindex,rawopopendrawer));
   if ((not nobegindoc) OR (not printer.Printing)) then
   begin
    printer.Title:=Tittle;
    printer.Begindoc;
   end;
   try
    dpix:=Printer.XDPI;
    dpiy:=Printer.YDPI;
    totalcount:=0;
    for count1:=0 to reportcopies-1 do
    begin
     for i:=frompage to topage do
     begin
      for count2:=0 to pagecopies-1 do
      begin
       apage:=metafile.Pages[i];
       if totalcount>0 then
        gdidriver.NewPage(apage);
       inc(totalcount);
       for j:=0 to apage.ObjectCount-1 do
       begin
        gdidriver.PrintObject(Printer.Canvas,apage,apage.Objects[j],dpix,dpiy,true,pagemargins,devicefonts,offset,false);
        if assigned(aform) then
        begin
         mmlast:=GetTickCount;
         difmilis:=(mmlast-mmfirst);
         if difmilis>MILIS_PROGRESS then
         begin
          // Get the time
          mmfirst:=GetTickCount;
          aform.LRecordCount.Caption:=SRpPage+':'+ IntToStr(i+1)+
            ' - '+SRpItem+':'+ IntToStr(j+1);
          Application.ProcessMessages;
          if aform.cancelled then
           Raise Exception.Create(SRpOperationAborted);
         end;
        end;
       end;
       if assigned(aform) then
       begin
         Application.ProcessMessages;
         if aform.cancelled then
          Raise Exception.Create(SRpOperationAborted);
       end;
      end;
     end;
    end;
    Printer.EndDoc;
   except
    printer.Abort;
    raise;
   end;
  end;
  //if metafile.OpenDrawerAfter then
   //SendControlCodeToPrinter(GetPrinterRawOp(printerindex,rawopopendrawer));
  if Assigned(gdidriver) then
  begin
   gdidriver.SendAfterPrintOperations;
   if gdidriver.orientationset then
   begin
    Printer.Orientation:=gdidriver.oldorientation;
   end;
  end;
 finally
  if assigned(gdidriver) then
   gdidriver.free;
  //SetPrinterConfig(pconfig);
 end;
 // Send Especial operations
 if assigned(aform) then
  aform.close;
end;

function PrintMetafile(metafile:TRpMetafileReport;tittle:string;
 showprogress,allpages:boolean;frompage,topage,copies:integer;
  collate:boolean;devicefonts:boolean;printerindex:TRpPrinterSelect=pRpDefaultPrinter;nobegindoc:boolean=false):boolean;
var
 dia:TFRpVCLProgress;
begin
 Result:=true;
 if Not ShowProgress then
 begin
  DoPrintMetafile(metafile,tittle,nil,allpages,frompage,topage,copies,collate,devicefonts,printerindex,nobegindoc);
  exit;
 end;
 dia:=TFRpVCLProgress.Create(Application);
 try
  dia.oldonidle:=Application.OnIdle;
  try
   dia.metafile:=metafile;
   dia.tittle:=tittle;
   dia.allpages:=allpages;
   dia.frompage:=frompage;
   dia.topage:=topage;
   dia.copies:=copies;
   dia.collate:=collate;
   dia.devicefonts:=devicefonts;
   dia.printerindex:=printerindex;
   dia.nobegindoc:=nobegindoc;
   Application.OnIdle:=dia.AppIdle;
   dia.ShowModal;
   if dia.errorproces then
    Raise Exception.Create(dia.ErrorMessage);
   Result:=Not dia.cancelled;
  finally
   Application.OnIdle:=dia.oldonidle;
  end;
 finally
  dia.free;
 end;
end;


const
 MAX_RES_BITMAP=5760;


procedure TFRpVCLProgress.FormCreate(Sender: TObject);
begin
 LRecordCount.Font.Style:=[fsBold];
 LTittle.Font.Style:=[fsBold];

 BOK.Caption:=TranslateStr(93,BOK.Caption);
 BCancel.Caption:=TranslateStr(94,BCancel.Caption);
 LTitle.Caption:=TranslateStr(252,LTitle.Caption);
 LProcessing.Caption:=TranslateStr(253,LProcessing.Caption);
 GPrintRange.Caption:=TranslateStr(254,GPrintRange.Caption);
 LFrom.Caption:=TranslateStr(255,LFrom.Caption);
 LTo.Caption:=TranslateStr(256,LTo.Caption);
 RadioAll.Caption:=TranslateStr(257,RadioAll.Caption);
 RadioRange.Caption:=TranslateStr(258,RadioRange.Caption);
 Caption:=TranslateStr(259,Caption);

 LHorzRes.Caption:=SRpHorzRes;
 LVertRes.Caption:=SRpVertRes;
 CheckMono.Caption:=SRpMonochrome;
end;

procedure TFRpVCLProgress.AppIdle(Sender:TObject;var done:boolean);
begin
 errorproces:=false;
 cancelled:=false;
 Application.OnIdle:=nil;
 done:=false;
 try
  LTittle.Caption:=tittle;
  LProcessing.Visible:=true;
  DoPrintMetafile(metafile,tittle,self,allpages,frompage,topage,copies,collate,devicefonts,printerindex,nobegindoc);
 except
  On E:Exception do
  begin
   ErrorMessage:=E.Message;
   errorproces:=true;
  end;
 end;
 Close;
end;

function DoMetafileToBitmap(metafile:TRpMetafileReport;aform:TFRpVCLProgress;
 Mono:Boolean;resx:integer=200;resy:integer=100):TBitmap;
var
  gdidriver: TRpGDIDriver;
  apage: TRpMetafilePage;
  i, j: integer;
  offset: TPoint;
  pagemargins: TRect;
  pageheight, pagewidth: integer;
  arec: TRect;
  aobj: TRpMetaObject;
  rgbintensity: integer;
  mmfirst, mmlast: DWORD;
  difmilis: int64;
begin
  if resx > MAX_RES_BITMAP then resx := MAX_RES_BITMAP;
  if resy > MAX_RES_BITMAP then resy := MAX_RES_BITMAP;
  if resx < 1 then resx := 1;
  if resy < 1 then resy := 1;

  offset.X := 0;
  offset.Y := 0;
  pagemargins.Left := 0;
  pagemargins.Top := 0;
  pagemargins.Right := 0;
  pagemargins.Bottom := 0;
  mmfirst := GetTickCount;

  Result := TBitmap.Create;
  try
    Result.HandleType := bmDIB;
    if Mono then
      Result.PixelFormat := pf1bit
    else
      Result.PixelFormat := pf24bit;

    pagewidth := (metafile.CustomX * resx) div TWIPS_PER_INCHESS;
    pageheight := (metafile.CustomY * resy) div TWIPS_PER_INCHESS;
    metafile.RequestPage(MAX_PAGECOUNT);

    Result.Width := pagewidth;
    Result.Height := pageheight * metafile.CurrentPageCount;

    arec.Top := 0;
    arec.Left := 0;
    arec.Right := Result.Width;
    arec.Bottom := Result.Height;
    Result.Canvas.Brush.Style := bsSolid;
    Result.Canvas.Brush.Color := CLXColorToVCLColor(metafile.BackColor);
    Result.Canvas.FillRect(arec);

    gdidriver := TRpGDIDriver.Create;
    try
      for i := 0 to metafile.CurrentPageCount - 1 do
      begin
        apage := metafile.Pages[i];
        // PrintObject takes the offset in twips (text, shapes and images):
        // page i starts exactly at pixel row pageheight*i
        offset.X := 0;
        offset.Y := Round(Int64(pageheight) * i * TWIPS_PER_INCHESS / resy);
        for j := 0 to apage.ObjectCount - 1 do
        begin
          aobj := apage.Objects[j];
          if Mono and (aobj.Metatype = rpMetaText) then
          begin
            rgbintensity := (aobj.FontColor and $FF) +
              ((aobj.FontColor and $FF00) shr 8) +
              ((aobj.FontColor and $FF0000) shr 16);
            if rgbintensity > 128 * 3 then
              aobj.FontColor := clWhite
            else
              aobj.FontColor := clBlack;
          end;
          gdidriver.PrintObject(Result.Canvas, apage, aobj, resx, resy,
            false, pagemargins, false, offset, false);
          if Assigned(aform) then
          begin
            mmlast := GetTickCount;
            difmilis := (mmlast - mmfirst);
            if difmilis > 50 then
            begin
              mmfirst := GetTickCount;
              aform.LRecordCount.Caption := SRpPage + ':' + IntToStr(i + 1)
                + ' - ' + SRpItem + ':' + IntToStr(j + 1);
              Application.ProcessMessages;
              if aform.cancelled then
                raise Exception.Create(SRpOperationAborted);
            end;
          end;
        end;
      end;
    finally
      gdidriver.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function MetafileToBitmap(metafile:TRpMetafileReport;ShowProgress:Boolean;
 Mono:Boolean;resx:integer=200;resy:integer=100):TBitmap;
var
  dia: TFRpVCLProgress;
begin
  if not ShowProgress then
  begin
    Result := DoMetafileToBitmap(metafile, nil, Mono, resx, resy);
    exit;
  end;
  dia := TFRpVCLProgress.Create(Application);
  try
    dia.oldonidle := Application.OnIdle;
    try
      dia.metafile := metafile;
      dia.tittle := 'Bitmap';
      dia.bitmono := Mono;
      dia.bitresx := resx;
      dia.bitresy := resy;
      Application.OnIdle := dia.AppIdleBitmap;
      dia.ShowModal;
      if dia.errorproces then
        raise Exception.Create(dia.ErrorMessage);
      Result := dia.MetaBitmap;
    finally
      Application.OnIdle := dia.oldonidle;
    end;
  finally
    dia.Free;
  end;
end;

procedure TFRpVCLProgress.AppIdleBitmap(Sender:TObject;var done:boolean);
begin
 cancelled:=false;
 Application.OnIdle:=nil;
 done:=false;
 errorproces:=false;
 try
  LTittle.Caption:=tittle;
  LProcessing.Visible:=true;
  MetaBitmap:=DoMetafileToBitmap(metafile,self,bitmono,bitresx,bitresy);
 except
  on E:Exception do
  begin
   errorproces:=true;
   ErrorMessage:=E.Message;
  end;
 end;
 Close;
end;


procedure TFRpVCLProgress.BCancelClick(Sender: TObject);
begin
 cancelled:=true;
end;


{$IFNDEF FORWEBAX}
function ExportReportToPDF(report:TRpReport;Caption:string;progress:boolean;
  allpages:boolean;frompage,topage,copies:integer;
  showprintdialog:boolean;filename:string;compressed:boolean;collate:Boolean):Boolean;
var
 dia:TFRpVCLProgress;
 oldonidle:TIdleEvent;
 pdfdriver:TRpPDFDriver;
 gdidriver:TRpGDIDriver;
begin
 Result:=false;
 allpages:=true;
 collate:=false;
 if showprintdialog then
 begin
  if Not DoShowPrintDialog(allpages,frompage,topage,copies,collate,true) then
   exit;
 end;
 if progress then
 begin
  // Assign appidle frompage to page...
  dia:=TFRpVCLProgress.Create(Application);
  try
   dia.allpages:=allpages;
   dia.frompage:=frompage;
   dia.topage:=topage;
   dia.copies:=copies;
   dia.report:=report;
   dia.filename:=filename;
   dia.pdfcompressed:=compressed;
   dia.collate:=collate;
   oldonidle:=Application.Onidle;
   try
    Application.OnIdle:=dia.AppIdlePrintPdf;
    dia.ShowModal;
    if dia.errorproces then
     Raise Exception.Create(dia.ErrorMessage);
   finally
    Application.OnIdle:=oldonidle;
   end;
  finally
   dia.Free;
  end;
 end
 else
 begin
  gdidriver:=TRpGDIDriver.create;
  pdfdriver:=TRpPDFDriver.Create;
  try
   pdfdriver.filename:=filename;
   pdfdriver.compressed:=compressed;
 {$IFDEF USETEECHART}
   report.Metafile.OnDrawChart:=gdidriver.DoDrawChart;
 {$ENDIF}
 {$IFDEF EXTENDEDGRAPHICS}
  report.Metafile.OnFilterImage:=gdidriver.FilterImage;
 {$ENDIF}
   report.PrintRange(pdfdriver,allpages,frompage,topage,copies,collate);
  finally
   gdidriver.free;
   pdfdriver.free;
  end;
  Result:=True;
 end;
end;

function ExportReportToPDFMetaStream (report:TRpReport; Caption:string; progress:boolean;
  allpages:boolean; frompage,topage,copies:integer;
  showprintdialog:boolean; stream:TStream;compressed:boolean;collate:boolean;metafile:Boolean):Boolean;
var
 pdfdriver:TRpPDFDriver;
 gdidriver:TRpGDIDriver;
 oldtwopass:Boolean;
 onprog:TRpProgressEvent;
begin
 oldtwopass:=report.TwoPass;
 onprog:=report.OnPRogress;
 try
  if metafile then
   report.TwoPass:=true;
  gdidriver:=TRpGDIDriver.create;
  pdfdriver:=TRpPDFDriver.Create;
  try
   if not metafile then
    pdfdriver.DestStream:=stream;
   pdfdriver.compressed:=compressed;
   if progress then
    report.OnProgress:=pdfdriver.RepProgress;
{$IFDEF USETEECHART}
   report.Metafile.OnDrawChart:=gdidriver.DoDrawChart;
{$ENDIF}
{$IFDEF EXTENDEDGRAPHICS}
  report.Metafile.OnFilterImage:=gdidriver.FilterImage;
{$ENDIF}
   if metafile then
   begin
    report.PrintRange(pdfdriver,allpages,frompage,topage,copies,collate);
   end
   else
    report.PrintRange(pdfdriver,allpages,frompage,topage,copies,collate);
   if metafile then
    report.Metafile.SaveToStream(stream);
  finally
   pdfdriver.free;
   gdidriver.Free;
  end;
 finally
  report.TwoPass:=oldtwopass;
  report.OnPRogress:=onprog;
 end;
 Result:=True;
end;

procedure TFRpVCLProgress.RepProgress(Sender:TRpBaseReport;var docancel:boolean);
var
 astring:WideString;
begin
 if Not Assigned(LRecordCount) then
  exit;
 if Sender.ProgressToStdOut then
 begin
  astring:=SRpRecordCount+' '+IntToStr(Sender.CurrentSubReportIndex)
   +':'+SRpPage+':'+FormatFloat('#########,####',Sender.PageNum)+'-'+
   FormatFloat('#########,####',Sender.RecordCount);
{$I-}
 {$IFDEF USEVARIANTS}
  WriteLn(astring);
 {$ELSE}
  WriteLn(String(astring));
 {$ENDIF}
{$I+}
  // If it's the last page prints additional info
  if Sender.LastPage then
  begin
   astring:=Format('%-20.20s',[SRpPage])+FormatFloat('0000000000',Sender.PageNum+1);
{$I-}
 {$IFDEF USEVARIANTS}
  WriteLn(astring);
 {$ELSE}
   WriteLn(String(astring));
 {$ENDIF}
{$I+}
  end;
 end;
 LRecordCount.Caption:=IntToStr(Sender.CurrentSubReportIndex)+':'+SRpPage+':'+
 FormatFloat('#########,####',Sender.PageNum+1)+'-'+FormatFloat('#########,####',Sender.RecordCount+1);
 if Sender.LastPage then
  LRecordCount.Caption:=Format('%-20.20s',[SRpPage])+FormatFloat('0000000000',Sender.PageNum+1);
 Application.ProcessMessages;
 if cancelled then
  docancel:=true;
end;


procedure TFRpVCLProgress.AppIdleReport(Sender:TObject;var done:boolean);
var
 oldprogres:TRpProgressEvent;
 istextonly:Boolean;
 drivername:String;
 TextDriver:TRpTextDriver;
 pdfdriver:TRpPdfDriver;
 GDIDriver:TRpGDIDriver;
begin
 Application.Onidle:=nil;
 done:=false;
 errorproces:=false;
 try
  drivername:=Trim(GetPrinterEscapeStyleDriver(report.PrinterSelect));
  istextonly:=Length(drivername)>0;

  if istextonly then
  begin
   TextDriver:=TRpTextDriver.Create;
   try
    if (not report.metafile.BlockPrinterSelection) then
     TextDriver.SelectPrinter(report.PrinterSelect);
    oldprogres:=report.OnProgress;
    try
     report.OnProgress:=RepProgress;
     report.PrintAll(TextDriver);
    finally
     report.OnProgress:=oldprogres;
    end;
   finally
    TextDriver.Free;
   end;
  end
  else
  begin
   if usepdfdriver then
   begin
    pdfdriver:=TRpPdfDriver.Create;
    try
     oldprogres:=report.OnProgress;
     try
      report.OnProgress:=RepProgress;
      report.PrintAll(PDFDriver);
     finally
      report.OnProgress:=oldprogres;
     end;
    finally
     pdfdriver.Free;
    end;
   end
   else
   begin
    GDIDriver:=TRpGDIDriver.Create;
    try
     gdidriver.noenddoc:=noenddoc;
     if noenddoc then
      gdidriver.ToPrinter:=true;
     if report.PrinterFonts=rppfontsalways then
      gdidriver.devicefonts:=true
     else
      gdidriver.devicefonts:=false;
     gdidriver.neverdevicefonts:=report.PrinterFonts=rppfontsnever;
     oldprogres:=report.OnProgress;
     try
      report.OnProgress:=RepProgress;
      report.PrintAll(GDIDriver);
     finally
      report.OnProgress:=oldprogres;
     end;
    finally
     gdidriver.free;
    end;
   end;
  end;
 except
  On E:Exception do
  begin
   ErrorMessage:=E.Message;
   errorproces:=true;
  end;
 end;
 Close;
end;

function CalcReportWidthProgress(report:TRpReport;noenddoc:boolean=false):boolean;
var
 dia:TFRpVCLProgress;
begin
 Result:=false;
 dia:=TFRpVCLProgress.Create(Application);
 try
  dia.oldonidle:=Application.OnIdle;
  try
   dia.report:=report;
   Application.OnIdle:=dia.AppIdleReport;
   dia.noenddoc:=noenddoc;
   dia.ShowModal;
   if dia.errorproces then
    Raise Exception.Create(dia.ErrorMessage);
   Result:=Not dia.cancelled;
  finally
   Application.onidle:=dia.oldonidle;
  end;
 finally
  dia.free;
 end;
end;

function CalcReportWidthProgressPDF(report:TRpReport;noenddoc:boolean=false):boolean;
var
 dia:TFRpVCLProgress;
begin
 Result:=false;
 dia:=TFRpVCLProgress.Create(Application);
 try
  dia.oldonidle:=Application.OnIdle;
  try
   dia.report:=report;
   Application.OnIdle:=dia.AppIdleReport;
   dia.usepdfdriver:=True;
   dia.noenddoc:=noenddoc;
   dia.ShowModal;
   if dia.errorproces then
    Raise Exception.Create(dia.ErrorMessage);
   Result:=Not dia.cancelled;
  finally
   Application.onidle:=dia.oldonidle;
  end;
 finally
  dia.free;
 end;
end;


procedure TFRpVCLProgress.AppIdlePrintRange(Sender:TObject;var done:boolean);
var
 oldprogres:TRpProgressEvent;
 GDIDriver:TRpGDIDriver;
begin
 Application.Onidle:=nil;
 done:=false;
 errorproces:=false;
 try
  GDIDriver:=TRpGDIDriver.Create;
  try
   GDIDriver.toprinter:=true;
   if report.PrinterFonts=rppfontsalways then
    gdidriver.devicefonts:=true
   else
    gdidriver.devicefonts:=false;
   gdidriver.neverdevicefonts:=report.PrinterFonts=rppfontsnever;
   oldprogres:=report.OnProgress;
   try
    report.OnProgress:=RepProgress;
    report.PrintRange(GDIDriver,allpages,frompage,topage,copies,collate);
   finally
    report.OnProgress:=oldprogres;
   end;
  finally
   gdidriver.free;
  end;
 except
  On E:Exception do
  begin
   ErrorMessage:=E.Message;
   errorproces:=true;
  end;
 end;
 Close;
end;

procedure TFRpVCLProgress.AppIdlePrintRangeText(Sender:TObject;var done:boolean);
var
 oldprogres:TRpProgressEvent;
 S:String;
 TextDriver:TRpTextDriver;
 pconfig:TPrinterConfig;
begin
 pconfig.changed:=false;
 Application.Onidle:=nil;
 done:=false;
 try
 errorproces:=false;
 try
  TextDriver:=TRpTextDriver.Create;
  try
  oldprogres:=report.OnProgress;
  try
   if (not report.Metafile.BlockPrinterSelection) then
    TextDriver.SelectPrinter(report.PrinterSelect);
   report.OnProgress:=RepProgress;
   report.PrintRange(TextDriver,allpages,frompage,topage,copies,collate);
   // Now Prints to selected printer the stream
   SetLength(S,TextDriver.MemStream.Size);
{$IFNDEF DOTNETD}
   TextDriver.MemStream.Read(S[1],TextDriver.MemStream.Size);
{$ENDIF}
{$IFDEF DOTNETD}
    s:=TextDriver.MemStream.ToString;
{$ENDIF}
   if (not report.metafile.BlockPrinterSelection) then
    PrinterSelection(report.PrinterSelect,report.papersource,report.duplex,pconfig);
   //SendControlCodeToPrinter(S);
  finally
   report.OnProgress:=oldprogres;
  end;
  finally
   TextDriver.free;
  end;
 except
  On E:Exception do
  begin
   ErrorMessage:=E.Message;
   errorproces:=true;
  end;
 end;
 finally
  //SetPrinterConfig(pconfig);
 end;
 Close;
end;



procedure TFRpVCLProgress.AppIdlePrintPDF(Sender:TObject;var done:boolean);
var
 oldprogres:TRpProgressEvent;
 gdidriver:TRpGDIDriver;
 pdfdriver:TRpPDFDriver;
begin
 Application.Onidle:=nil;
 done:=false;
 errorproces:=false;
 try
  pdfdriver:=TRpPDFDriver.Create;
  gdidriver:=TRpGDIDriver.Create;
  try

   pdfdriver.filename:=filename;
   pdfdriver.compressed:=pdfcompressed;
 {$IFDEF USETEECHART}
   report.Metafile.OnDrawChart:=gdidriver.DoDrawChart;
 {$ENDIF}
 {$IFDEF EXTENDEDGRAPHICS}
  report.Metafile.OnFilterImage:=gdidriver.FilterImage;
 {$ENDIF}
   oldprogres:=report.OnProgress;
   try
    report.OnProgress:=RepProgress;
    report.PrintRange(pdfdriver,allpages,frompage,topage,copies,collate);
   finally
    report.OnProgress:=oldprogres;
   end;
  finally
   pdfdriver.free;
   gdidriver.free;
  end;
 except
  On E:Exception do
  begin
   ErrorMessage:=E.Message;
   errorproces:=true;
  end;
 end;
 Close;
end;



function PrintReport(report:TRpReport;Caption:string;progress:boolean;
  allpages:boolean;frompage,topage,copies:integer;collate:boolean):Boolean;
var
 GDIDriver:TRpGDIDriver;
 TextDriver:TRpTextDriver;
 forcecalculation:boolean;
 dia:TFRpVCLProgress;
 oldonidle:TIdleEvent;
 devicefonts:boolean;
 istextonly:boolean;
 drivername:String;
 S:String;
 pconfig:TPrinterConfig;
begin
 pconfig.Changed:=false;
 try
 report.metafile.Title:=Caption;
 drivername:=Trim(GetPrinterEscapeStyleDriver(report.PrinterSelect));
 istextonly:=Length(drivername)>0;
 if report.PrinterFonts=rppfontsalways then
  devicefonts:=true
 else
  devicefonts:=false;
 Result:=true;
 forcecalculation:=false;
 if ((report.copies>1) and (collate)) then
 begin
  forcecalculation:=true;
 end;
 if report.TwoPass then
  forcecalculation:=true;
 if forcecalculation then
 begin
  if progress then
  begin
   try
    if Not CalcReportWidthProgress(report,true) then
     Result:=false
    else
     PrintMetafile(report.Metafile,Caption,progress,allpages,frompage,topage,copies,collate,devicefonts,report.PrinterSelect,true);
   finally
    if Printer.Printing then
     Printer.Abort;
   end
  end
  else
  begin
   try
    if istextonly then
    begin
     TextDriver:=TRpTextDriver.Create;
     try
      if (not report.Metafile.BlockPrinterSelection) then
       TextDriver.SelectPrinter(report.PrinterSelect);
      report.PrintAll(TextDriver);
     finally
      TextDriver.free;
     end;
    end
    else
    begin
     GDIDriver:=TRpGDIDriver.Create;
     try
      if report.PrinterFonts=rppfontsalways then
       gdidriver.devicefonts:=true
      else
       gdidriver.devicefonts:=false;
      gdidriver.toprinter:=true;
      gdidriver.neverdevicefonts:=report.PrinterFonts=rppfontsnever;
      gdidriver.noenddoc:=true;
      report.PrintAll(GDIDriver);
     finally
      gdidriver.free;
     end;
    end;
    PrintMetafile(report.Metafile,Caption,progress,allpages,frompage,topage,copies,collate,devicefonts,report.PrinterSelect,true);
   finally
    if Printer.Printing then
     Printer.Abort;
   end
  end;
  exit;
 end;
 if progress then
 begin
  // Assign appidle frompage to page...
  dia:=TFRpVCLProgress.Create(Application);
  try
   dia.allpages:=allpages;
   dia.frompage:=frompage;
   dia.topage:=topage;
   dia.copies:=copies;
   dia.report:=report;
   dia.collate:=collate;
   oldonidle:=Application.Onidle;
   try
    if istextonly then
     Application.OnIdle:=dia.AppIdlePrintRangeText
    else
     Application.OnIdle:=dia.AppIdlePrintRange;
    dia.ShowModal;
    if dia.errorproces then
     Raise Exception.Create(dia.ErrorMessage);
   finally
    Application.OnIdle:=oldonidle;
   end;
  finally
   dia.Free;
  end;
 end
 else
 begin
  if istextonly then
  begin
   TextDriver:=TRpTextDriver.Create;
   try
    if (not report.Metafile.BlockPrinterSelection) then
     TextDriver.SelectPrinter(report.PrinterSelect);
    report.PrintRange(TextDriver,allpages,frompage,topage,copies,collate);
    SetLength(S,TextDriver.MemStream.Size);
    TextDriver.MemStream.Read(S[1],TextDriver.MemStream.Size);
    if (not report.metafile.BlockPrinterSelection) then
      PrinterSelection(report.PrinterSelect,report.papersource,report.duplex,pconfig);
    //SendControlCodeToPrinter(S);
   finally
    TextDriver.free;
   end;
  end
  else
  begin
   GDIDriver:=TRpGDIDriver.Create;
   try
    GDIDriver.toprinter:=true;
    if report.PrinterFonts=rppfontsalways then
     gdidriver.devicefonts:=true
    else
     gdidriver.devicefonts:=false;
    gdidriver.neverdevicefonts:=report.PrinterFonts=rppfontsnever;
    report.PrintRange(GDIDriver,allpages,frompage,topage,copies,collate);
   finally
    gdidriver.free;
   end;
  end;
 end;
 finally
  //SetPrinterConfig(pconfig);
 end;
end;
{$ENDIF}

procedure TFRpVCLProgress.BOKClick(Sender: TObject);
begin
 FromPage:=StrToInt(EFrom.Text);
 ToPage:=StrToInt(ETo.Text);
 if FromPage<1 then
  FromPage:=1;
 if ToPage<FromPage then
  ToPage:=FromPage;
 Close;
 dook:=true;
end;

procedure TFRpVCLProgress.FormShow(Sender: TObject);
begin
 if BOK.Visible then
 begin
  EFrom.Text:=IntToStr(FromPage);
  ETo.Text:=IntToStr(ToPage);
 end;
end;

procedure TRpGDIDriver.GraphicExtent(Stream:TMemoryStream;var extent:TPoint;dpi:integer);
var
 graphic:TBitmap;
{$IFNDEF DOTNETD}
 jpegimage:TJpegImage;
{$ENDIF}
 bitmapwidth,bitmapheight:integer;
 format:string;
begin
 if dpi<=0 then
  exit;
 graphic:=TBitmap.Create;
 try
  format:='';
  GetJPegInfo(Stream,bitmapwidth,bitmapheight,format);
  if (format='JPEG') then
  begin
{$IFNDEF DOTNETD}
   jpegimage:=TJpegImage.Create;
   try
    jpegimage.LoadFromStream(Stream);
    graphic.Assign(jpegimage);
   finally
    jpegimage.free;
   end;
{$ENDIF}
{$IFDEF DOTNETD}
   graphic.LoadFromStream(stream);
{$ENDIF}
  end
  else
  begin
   if (format='BMP') then
   begin
     Graphic.LoadFromStream(Stream);
   end
   else
   begin
    // All other formats
{$IFDEF EXTENDEDGRAPHICS}
       FilterImage(stream);
       jpegimage:=TJPegImage.Create;
       try
        jpegimage.LoadFromStream(stream);
        bitmap.Assign(jpegimage);
       finally
        jpegimage.free;
       end;
{$ENDIF}
   end;
  end;
  extent.X:=Round(graphic.width/dpi*TWIPS_PER_INCHESS);
  extent.Y:=Round(graphic.height/dpi*TWIPS_PER_INCHESS);
 finally
  graphic.Free;
 end;
end;

function PrinterSelection(printerindex:TRpPrinterSelect;papersource,duplex:integer;var pconfig:TPrinterConfig):TPoint;
var
 printername:String;
 index:integer;
 offset:TPoint;
 apage:TGDIPageSize;
begin
 printername:=GetPrinterConfigName(printerindex);
 offset:=GetPrinterOffset(printerindex);
 if length(printername)>0 then
 begin
  index:=Printer.Printers.IndexOf(printername);
  if index>=0 then
  begin
   if Printer.PrinterIndex<>Index then
   begin
    // Fixes problem, this reads default
    // document properties after printer selection
    //pconfig:=GetPrinterConfig;
    //pconfig.Changed:=true;
    //rpvgraphutils.SwitchToPrinterIndex(index);
    Printer.PrinterIndex:=index;
   end;
  end;
 end;
 if ((papersource>0) or (duplex>0)) then
 begin
  //apage:=GetCurrentPaper;
  if papersource>0 then
   apage.papersource:=papersource;
  if duplex>0 then
   apage.duplex:=duplex;
  //SetCurrentPaper(apage);
 end;
 Result:=offset;
end;

procedure TRpGDIDriver.SelectPrinter(printerindex:TRpPrinterSelect);
var
 pconfig:TPrinterConfig;
begin
 offset:=PrinterSelection(printerindex,0,0,pconfig);
 selectedprinter:=printerindex;
 if neverdevicefonts then
  exit;
 if devicefonts then
  exit;
 devicefonts:=GetDeviceFontsOption(printerindex);
 //if devicefonts then
 // UpdatePrinterFontList;
end;

procedure TRpGDIDriver.SendAfterPrintOperations;
var
 Operation:String;
 i:TPrinterRawOp;
begin
 for i:=Low(TPrinterRawOp) to High(TPrinterRawOp) do
 begin
  if PrinterRawOpEnabled(selectedprinter,i) then
  begin
   Operation:=GetPrinterRawOp(selectedprinter,i);
   //if Length(Operation)>0 then
    //SendControlCodeToPrinter(Operation);
  end;
 end;
end;

procedure PageSizeSelection(rpPageSize:TPageSizeQt);
var
 pagesize:TGDIPageSize;
begin
 if Printer.Printers.Count<1 then
  exit;
 //pagesize:=QtPageSizeToGDIPageSize(rppagesize);
 //SetCurrentPaper(pagesize);
end;


procedure OrientationSelection(neworientation:TRpOrientation);
begin
 if Printer.Printers.Count<1 then
  exit;
 SetPrinterOrientation(neworientation=rpOrientationLandscape);
// if neworientation=rpOrientationDefault then
//  exit;
// if neworientation=rpOrientationPortrait then
//  Printer.Orientation:=poPortrait
// else
//  Printer.Orientation:=poLandscape;
end;


{$IFNDEF FORWEBAX}
procedure TRpGDIDriver.FilterImage(memstream:TMemoryStream);
begin
 inherited FilterImage(memstream);
 ExFilterImage(memstream);
end;
{$ENDIF}



{$IFDEF USETEECHART}
procedure TRpGDIDriver.DoDrawChart(adriver:TRpPrintDriver;Series:TRpSeries;page:TRpMetaFilePage;
  aposx,aposy:integer;xchart:TObject);
var
 nchart:TRpChart;
 achart:TChart;
 aserie:TChartSeries;
 i,j,afontsize:integer;
 rec:TRect;
 intserie:TRpSeriesItem;
 abitmap:TBitmap;
 FMStream:TMemoryStream;
 acolor:integer;
{$IFDEF DELPHI2009UP}
 nform:TForm;
{$ENDIF}
begin
 nchart:=TRpChart(xchart);
 if nchart.Driver=rpchartdriverengine then
 begin
  rppdfdriver.DoDrawChart(adriver,Series,page,aposx,aposy,xchart);
  exit;
 end;
 achart:=TChart.Create(nil);
 try
  // In delphi 7 there is no need for parent
{$IFDEF DELPHI2009UP}
  nform:=TForm.Create(nil);
  achart.Parent:=nform;
{$ENDIF}

  achart.BevelOuter:=bvNone;
  afontsize:=Round(nchart.FontSize*nchart.Resolution/100);
  achart.View3D:=nchart.View3d;
  achart.View3DOptions.Rotation:=nchart.Rotation;
{$IFNDEF BUILDER4}
  achart.View3DOptions.Perspective:=nchart.Perspective;
{$ENDIF}
  achart.View3DOptions.Elevation:=nchart.Elevation;
  achart.View3DOptions.Orthogonal:=nchart.Orthogonal;
  achart.View3DOptions.Zoom:=nchart.Zoom;
  achart.View3DOptions.Tilt:=nchart.Tilt;
  achart.View3DOptions.HorizOffset:=nchart.HorzOffset;
  achart.View3DOptions.VertOffset:=nchart.VertOffset;
  achart.View3DWalls:=nchart.View3DWalls;
  achart.BackColor:=clTeeColor;
  achart.BackWall.Brush.Style:=bsClear;
  achart.Gradient.Visible:=false;
  achart.Color:=clWhite;
  achart.LeftAxis.LabelsFont.Name:=nchart.WFontName;
  achart.BottomAxis.LabelsFont.Name:=nchart.WFontName;
  achart.Legend.Font.Name:=nchart.WFontName;
  achart.LeftAxis.LabelsFont.Style:=CLXIntegerToFontStyle(nchart.FontStyle);
  achart.BottomAxis.LabelsFont.Style:=CLXIntegerToFontStyle(nchart.FontStyle);
  achart.Legend.Font.Size:=aFontSize;
  achart.Legend.Font.Style:=CLXIntegerToFontStyle(nchart.FontStyle);
  achart.Legend.Visible:=nchart.ShowLegend;
  // autorange and other ranges
  achart.LeftAxis.Maximum:=Series.HighValue;
  achart.LeftAxis.Minimum:=Series.LowValue;
  achart.LeftAxis.Automatic:=false;
  achart.LeftAxis.AutomaticMaximum:=Series.AutoRangeH;
  achart.LeftAxis.AutomaticMinimum:=Series.AutoRangeL;
  achart.LeftAxis.LabelsAngle:=nchart.VertFontRotation mod 360;
  achart.LeftAxis.LabelsFont.Size:=Round(nchart.VertFontSize*nchart.Resolution/100);
  achart.BottomAxis.LabelsAngle:=nchart.HorzFontRotation mod 360;
  achart.BottomAxis.LabelsFont.Size:=Round(nchart.HorzFontSize*nchart.Resolution/100);
{$IFDEF USEVARIANTS}
  achart.LeftAxis.Logarithmic:=Series.Logaritmic;
  if achart.LeftAxis.Logarithmic then
    achart.LeftAxis.LogarithmicBase:=Round(Series.LogBase);
{$ENDIF}
  achart.LeftAxis.Inverted:=Series.Inverted;
  acolor:=0;
  for i:=0 to Series.Count-1 do
  begin
   intserie:=Series.Items[i];
   aserie:=nil;
   case intserie.ChartType of
    rpchartline:
     begin
      aserie:=TLineSeries.Create(nil);
     end;
    rpchartbar:
     begin
      aserie:=TBarSeries.Create(nil);
      case nchart.MultiBar of
       rpMultiNone:
        TBarSeries(aserie).MultiBar:=mbNone;
       rpMultiside:
        TBarSeries(aserie).MultiBar:=mbSide;
       rpMultiStacked:
        TBarSeries(aserie).MultiBar:=mbStacked;
       rpMultiStacked100:
        TBarSeries(aserie).MultiBar:=mbStacked100;
      end;
    end;
    rpchartpoint:
     aserie:=TPointSeries.Create(nil);
    rpcharthorzbar:
     aserie:=THorizBarSeries.Create(nil);
    rpchartarea:
     aserie:=TAreaSeries.Create(nil);
    rpchartpie:
     begin
      aserie:=TPieSeries.Create(nil);
     end;
    rpchartarrow:
     aserie:=TArrowSeries.Create(nil);
    rpchartbubble:
     aserie:=TBubbleSeries.Create(nil);
    rpchartgantt:
     aserie:=TGanttSeries.Create(nil);
   end;
   if not assigned(aserie) then
    exit;
   if Length(intserie.Caption)>0 then
    aserie.Title:=intserie.Caption;
   aserie.Marks.Font.Name:=nchart.WFontName;
   aserie.Marks.Font.Size:=aFontSize;
   aserie.Marks.Font.Style:=CLXIntegerToFontStyle(nchart.FontStyle);
   aserie.Marks.Visible:=nchart.ShowHint;
   aserie.Marks.Style:=TSeriesMarksStyle(nchart.MarkStyle);
   aserie.ParentChart:=achart;
   if intserie.Color>=0 then
    aserie.SeriesColor:=intserie.Color
   else
    aserie.SeriesColor:=SeriesColors[aColor];
   // Assigns the color for this serie
   for j:=0 to intserie.ValueCount-1 do
   begin
    if series.count<2 then
    begin
     if intserie.Colors[j]>=0 then
      aserie.Add(intserie.Values[j],
       intSerie.ValueCaptions[j],intSerie.Colors[j])
     else
      aserie.Add(intserie.Values[j],
       intSerie.ValueCaptions[j],SeriesColors[aColor]);
     if (nchart.ChartType in [rpchartpie]) or nchart.ShowLegend then
      acolor:=((acolor+1) mod (MAX_SERIECOLORS));
    end
    else
    begin
     if intserie.Colors[j]>=0 then
      aserie.Add(intserie.Values[j],
       intSerie.ValueCaptions[j],intserie.Colors[j])
     else
      aserie.Add(intserie.Values[j],
       intSerie.ValueCaptions[j],SeriesColors[aColor]);
    end;
    //achart.AddSeries(aserie);
   end;
   acolor:=((acolor+1) mod (MAX_SERIECOLORS));
   abitmap:=TBitmap.Create;
   try
{$IFNDEF DOTNETDBUGS}
    abitmap.HandleType:=bmDIB;
    abitmap.PixelFormat:=pf32bit;
{$ENDIF}
    // Chart resolution to default screen
    abitmap.Width:=Round(twipstoinchess(nchart.PrintWidth)*nchart.Resolution);
    abitmap.Height:=Round(twipstoinchess(nchart.PrintHeight)*nchart.Resolution);
    rec.Top:=0;
    rec.Left:=0;
    rec.Bottom:=abitmap.Height-1;
    rec.Right:=abitmap.Width-1;
    achart.Draw(abitmap.Canvas,rec);
    // Finally print it
    FMStream:=TMemoryStream.Create;
    try
     abitmap.SaveToStream(FMStream);
     page.NewImageObject(aposy,aposx,
      nchart.PrintWidth,nchart.PrintHeight,DEF_COPYMODE,Integer(rpDrawStretch),
      nchart.Resolution,FMStream,false);
    finally
     FMStream.Free;
    end;
   finally
    abitmap.free;
   end;
   acolor:=((acolor+1) mod MAX_SERIECOLORS);
  end;
 finally
  while achart.SeriesList.Count>0 do
  begin
   TObject(achart.SeriesList.Items[0]).free;
  end;
  achart.Free;
{$IFDEF DELPHI2009UP}
  nform.free;
{$ENDIF}
 end;
end;
{$ENDIF}

procedure TRpGDIDriver.DrawChart(Series:TRpSeries;ametafile:TRpMetaFileReport;posx,posy:integer;achart:TObject);
begin
{$IFNDEF FORWEBAX}
{$IFDEF USETEECHART}
 DoDrawChart(Self,Series,ametafile.Pages[ametafile.CurrentPage],posx,posy,achart);
{$ENDIF}
{$IFNDEF USETEECHART}
 rppdfdriver.DoDrawChart(Self,Series,ametafile.Pages[ametafile.CurrentPage],
  posx,posy,achart);
{$ENDIF}
{$ENDIF}
end;

function SaveMetafileToPNG(metafile: TRpMetafileReport; const baseFilename: string;
  dpi: integer = 0; alwaysNumberPages: boolean = false): integer;
var
  driver: TRpGDIDriver;
  png: TPortableNetworkGraphic;
  i, totalPages: integer;
  dir, nameNoExt, ext, pageFilename: string;
begin
  Result := 0;
  if not Assigned(metafile) then
    Exit;
  metafile.RequestPage(MAX_PAGECOUNT);
  totalPages := metafile.CurrentPageCount;
  if totalPages < 1 then
    Exit;

  dir := ExtractFilePath(baseFilename);
  ext := ExtractFileExt(baseFilename);
  if SameText(ext, '.png') then
    nameNoExt := ChangeFileExt(ExtractFileName(baseFilename), '')
  else
    nameNoExt := ExtractFileName(baseFilename);

  driver := TRpGDIDriver.Create;
  try
    if dpi > 0 then
      driver.dpi := dpi;
    driver.scale := 1.0;
    driver.NewDocument(metafile, 1, false);
    for i := 0 to totalPages - 1 do
    begin
      if (totalPages > 1) or alwaysNumberPages then
        pageFilename := dir + nameNoExt + '_' + IntToStr(i + 1) + '.png'
      else
        pageFilename := dir + nameNoExt + '.png';

      driver.DrawPage(metafile.Pages[i]);
      if Assigned(driver.bitmap) then
      begin
        png := TPortableNetworkGraphic.Create;
        try
          png.Assign(driver.bitmap);
          png.SaveToFile(pageFilename);
          Inc(Result);
        finally
          png.Free;
        end;
      end;
    end;
  finally
    driver.Free;
  end;
end;

function AskBitmapProps(var HorzRes,VertRes:Integer;var Mono:Boolean):Boolean;
var
 diarange:TFRpVCLProgress;
begin
 Result:=false;
 diarange:=TFRpVCLProgress.Create(Application);
 try
  diarange.Caption:=SRpBitmapProps;
  diarange.BOK.Visible:=true;
  diarange.GBitmap.Visible:=true;
  diarange.EHorzRes.Text:=IntToStr(HorzRes);
  diarange.EVertRes.Text:=IntToStr(HorzRes);
  diarange.CheckMono.Checked:=Mono;
  diarange.ActiveControl:=diarange.BOK;
  diarange.showmodal;
  if diarange.dook then
  begin
   try
    HorzRes:=StrToInt(diarange.EHorzRes.Text);
    VertRes:=StrToInt(diarange.EVertRes.Text);
   except
   end;
   if HorzRes<1 then
    HorzREs:=1;
   if VertRes<1 then
    VertRes:=1;
   Mono:=diarange.CheckMono.Checked;
   Result:=true;
  end
 finally
  diarange.free;
 end;
end;

function TRpGdiDriver.GetFontDriver:TRpPrintDriver;
begin
 if Assigned(FontDriver) then
  Result:=FontDriver
 else
  Result:=Self;
end;

{$IFNDEF FORWEBAX}
procedure ExFilterImage(memstream:TMemoryStream);
var
 format:string;
 w,h:integer;
 pic:TPicture;
 bmp:TBitmap;
 jpg:TJpegImage;
 cleanMem:TStream;
begin
 if (memstream=nil) or (memstream.Size<4) then
  exit;

 cleanMem:=CleanGraphicStream(memstream);
 try
  if cleanMem<>memstream then
  begin
   memstream.Clear;
   cleanMem.Position:=0;
   memstream.CopyFrom(cleanMem,cleanMem.Size);
   memstream.Position:=0;
  end;
 finally
  if cleanMem<>memstream then
   cleanMem.Free;
 end;

 memstream.Position:=0;
 format:='';
 GetJPegInfo(memstream,w,h,format);
 memstream.Position:=0;

 if (format='JPEG') or (format='BMP') or (format='PNG') then
  exit;

 try
  pic:=TPicture.Create;
  try
   pic.LoadFromStream(memstream);
   bmp:=TBitmap.Create;
   try
    bmp.PixelFormat:=pf24bit;
    bmp.Width:=pic.Width;
    bmp.Height:=pic.Height;
    bmp.Canvas.Draw(0,0,pic.Graphic);

    jpg:=TJpegImage.Create;
    try
     jpg.CompressionQuality:=90;
     jpg.Assign(bmp);
     memstream.Clear;
     jpg.SaveToStream(memstream);
     memstream.Position:=0;
    finally
     jpg.Free;
    end;
   finally
    bmp.Free;
   end;
  finally
   pic.Free;
  end;
 except
  memstream.Position:=0;
 end;
end;
{$ENDIF}


end.


