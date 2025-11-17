{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       TRppdffile                                      }
{       PDF Generator                                   }
{                                                       }
{       Code Base From Nishita's PDF Creation (TNPDF)   }
{       info@nishita.com                                }
{                                                       }
{       Copyright (c) 1994-2021 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{       Converted to CLX (not Visual CLX)               }
{       and added lot functionality                     }
{       and bug fixes                                   }
{       Changed names to borland cFoding style           }
{       Added Canvas object                             }
{                                                       }
{       Added:                                          }
{               -Font Color                             }
{               -Text parsing                           }
{               -Filled Regions, pen color and b.color  }
{               -Pen Style                              }
{               -Resolution 1440 p.p.i                  }
{               -Exact position for text...             }
{               -Text clipping                          }
{               -Ellipse, true Rectangle                }
{               -Text alignment                         }
{               -Multiline and wordbreak                }
{               -Multiline alignment                    }
{               -Underline and strokeout                }
{               -Type1 Font selection bold/italic       }
{               -BMP and JPEG Image support             }
{               -Embedding True Type fonts              }
{               -Truetype Unicode support               }
{                                                       }
{                                                       }
{       Still Missing:                                  }
{               -Brush Patterns                         }
{               -RLE and monocrhome Bitmaps             }
{               -RoundRect                              }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace the functionality of this file    }
{       you must provide source code                    }
{                                                       }
{                                                       }
{*******************************************************}

unit rppdffile;

interface

{$I rpconf.inc}

uses Classes,Sysutils,rpinfoprovid,
{$IFDEF USEVARIANTS}
 Types,
{$ENDIF}
{$IFDEF USEZLIB}
{$IFDEF DELPHI2009UP}
 zlib,
{$ENDIF}
{$IFNDEF DELPHI2009UP}
 rpmzlib,
{$ENDIF}
{$ENDIF}
{$IFDEF MSWINDOWS}
{$IFNDEF FPC}
 rpinfoprovgdi,
{$ENDIF}
 Windows,
{$ENDIF}
{$IFDEF DOTNETD}
 Graphics,System.Runtime.InteropServices,
{$ENDIF}
{$IFDEF LINUX}
 rpinfoprovft,
{$ENDIF}

 rpmdconsts,rptypes,rpmunits,dateutils;


const
 PDF_HEADER_1_4:string='%PDF-1.4';
 PDF_HEADER_A3:string='%PDF-1.7';
 CONS_PDFRES=POINTS_PER_INCHESS;
 CONS_UNDERLINEWIDTH=0.1;
 CONS_SRIKEOUTWIDTH=0.05;
 CONS_UNDERLINEPOS=1.1;
 CONS_STRIKEOUTPOS=0.7;
 CONS_UNICODEPREDIX='';
type


 TRpPDFFile=class;



 TPDFAnnotation = class
  public
   StreamNumber: Integer;
   PosX:integer;
   PosY:integer;
   Width: integer;
   Height: integer;
   Page: integer;
   Annotation: string;
 end;



 TRpPageInfo=class(TObject)
  public
   APageWidth,APageHeight:integer;
   PageAnnotations: array of TPDFAnnotation;
 end;

 TRpPDFCanvas=class(TObject)
  private
   FInfoProvider:TRpInfoProvider;
   FDefInfoProvider:TRpInfoProvider;
   FFont:TRpPDFFont;
   FFile:TRpPDFFile;
   FResolution:integer;
   FLineInfoMaxItems:integer;
   FLineInfoCount:integer;
   FFontTTData:TStringList;
   FImageIndexes:TStringList;
{$IFDEF MSWINDOWS}
{$IFNDEF FPC}
   FGDIInfoProvider:TRpGDIInfoProvider;
{$ENDIF}
{$ENDIF}
{$IFDEF LINUX}
  FFtInfoProvider:TRpFtInfoProvider;
{$ENDIF}
   procedure NewLineInfo(info:TRpLineInfo);
   procedure SetDash;
   procedure SaveGraph;
   procedure RestoreGraph;
   procedure SetInfoProvider(aprov:TRpInfoProvider);
   function GetTTFontData:TRpTTFontData;
   function EncodeUnicode(astring:Widestring;adata:TRpTTFontData;pdffont:TRpPDFFont):string;
   procedure SWriteLine(Stream:TStream;astring:string);
  public
   PenColor:integer;
   PenStyle:integer;
   PenWidth:integer;
   BrushColor:integer;
   BrushStyle:integer;
   PDFConformance: TPDFConformanceType;
   procedure GetStdLineSpacing(var linespacing,leading:integer);
   property InfoProvider:TRpInfoProvider read FInfoProvider write SetInfoProvider;
   function UnitsToXPos(Value:double):double;
   function UnitsToTextX(Value:double):string;
   function UnitsToTextY(Value:double):string;
   function UnitsToTextText(Value:double;FontSize:integer):string;
   function UnitsToYPosFont(Value: double;FontSize: integer):double;
   procedure Line(x1,y1,x2,y2:Integer);
   procedure TextOut(X, Y: Integer; const Text: Widestring;LineWidth,
    Rotation:integer;RightToLeft:Boolean;lInfo: TRpLineInfo);
   procedure TextRect(ARect: TRect; Text: Widestring;
                       Alignment: integer; Clipping: boolean;
                       Wordbreak:boolean;Rotation:integer;RightToLeft:Boolean);
   procedure Rectangle(x1,y1,x2,y2:Integer);
   procedure DrawImage(rec:TRect;abitmap:TStream;dpires:integer;
    tile:boolean;clip:boolean;intimageindex:integer);
   procedure Ellipse(X1, Y1, X2, Y2: Integer);
   constructor Create(AFile:TRpPDFFile);
   destructor Destroy;override;
   function CalcCharWidth(charcode:Widechar;fontdata:TRpTTFontData):double;
   function UpdateFonts:TRpTTFontData;
   procedure FreeFonts;
   function PDFCompatibleTextWidthKerning(astring:WideString;adata:TRpTTFontData;pdffont:TRpPDFFont):String;
   {$IFDEF USETEXTSHAPING}
   function PDFCompatibleTextShaping(adata:TRpTTFontData;
    pdffont:TRpPDFFont;RightToLeft: boolean; posX, posY: Double;
    FontSize: integer;lInfo:TRpLineInfo):String;
   {$ENDIF}
   function TextExtentSimple(const Text:WideString;var Rect:TRect;
     wordbreak:boolean;singleline:boolean): TRpLineInfoArray;
  public
   LineInfo:TRpLineInfoArray;
   function TextExtent(const Text:WideString;var Rect:TRect;
     wordbreak:boolean;singleline:boolean;rightToLeft: boolean): TRpLineInfoArray;
   property LineInfoMaxItems:integer read FLineInfoMaxItems;
   property LineInfoCount:integer read FLineInfoCount;

   property Font:TRpPDFFont read FFOnt;
  end;



 TRpPDFFile=class(TComponent)
  private
   FPageInfos:TStringList;
   FCanvas:TRpPDFCanvas;
   FPrinting:Boolean;
   FCompressed:boolean;
   FFilename:string;
   FDocTitle:string;
   FDocAuthor:string;
   FDocCreator:string;
   FDocKeywords:string;
   FDocSubject:string;
   FDocProducer:string;
   FDocCreationDate: string;
   FDocModificationDate: string;
   FDocXMPContent: string;
   FMainPDF:TMemoryStream;
   FStreamValid:boolean;
   FTempStream:TMemoryStream;
   FTempStream2:TMemoryStream;
   FsTempStream:TMemoryStream;
   FPage:integer;
   FPages:TStringList;
   FObjectOffsets:TStringList;
   FObjectCount:integer;
   FObjectOffset:integer;
   FOutlinesNum:integer;
   FFontCount:integer;
   FFontList:TStringList;
   FParentNum:integer;
   FImageCount:integer;
   FResourceNum,FCatalogNum:integer;
   FCurrentSetPageObject:integer;
   FPDFConformance:TPDFConformanceType;
   FXMPMetadataObject: integer;
   FOutputIntentObject: integer;
   FColorSpaceObject: integer;
   FInternalFDocCreationDate: TDateTime;
   FModDate: string;
   PageObjNum: integer;
   FResolution:integer;
   FBitmapStreams:TList;
   EmbeddedFiles: array of TEmbeddedFile;
   NumberFormatSettings: TFormatSettings;

   // Minimum page size in 72 dpi 18x18
   // Maximum page size in 72 dpi 14.400x14.400
   FPageWidth,FPageHeight:integer;
   function GetStream:TMemoryStream;
   procedure CheckPrinting;
   procedure AddToOffset(offset:LongInt);
   procedure StartStream;
   procedure EndStream;
   procedure SetOutLine;
   procedure SetFontType;
   procedure CreateFont(Subtype,BaseFont,Encoding:string);
   procedure SetPages;
   procedure AddAnnotations;
   procedure SetPageObject(index:integer);
   procedure SetArray;
   procedure WriteEmbeddedFiles;
   procedure SetCatalog;
   procedure SetXref;
   function GetOffsetNumber(offset:string):string;
   procedure SetResolution(Newres:integer);
   procedure ClearBitmaps;
   procedure WriteBitmap(index:Integer);
   procedure FreePageInfos;
   procedure SetXMPMetadata;
   procedure SetColorSpace;
{$IFDEF USEZLIB}
   function CompressStream(stream: TStream): TMemoryStream;
{$ENDIF}
   procedure WriteStream(stream, dest: TMemoryStream);
   function DateToISO(date:TDateTime): string;
   procedure SWriteLine(Stream:TStream;astring:string);
 public
   DestStream:TStream;
   procedure BeginDoc;
   procedure NewPage(NPageWidth,NPageHeight:integer);
   procedure EndDoc;
   procedure AbortDoc;
   constructor Create(AOwner:TComponent);override;
   destructor Destroy;override;
   property Canvas:TRpPDFCanvas read FCanvas;
   property Printing:Boolean read FPrinting;
   property Stream:TMemoryStream read GetStream;
   property StreamValid:Boolean read FStreamValid;
   property MainPDF:TMemoryStream read FMainPDF;
   procedure NewEmbeddedFile(fileName,mimeType: string;AFRelationShip: TPDFAFRelationShip;
     description,creationDate,ModificationDate: string;  stream: TMemoryStream);
   procedure NewAnnotation(posx,posy,width,height: integer; annotation: string);
   function EndOfLine:string;
  published
   // General properties
   property Compressed:boolean read FCompressed write FCompressed default true;
   property Filename:string read FFilename write FFilename;
   // Doc Info Props
   property DocTitle:string read FDocTitle write FDocTitle;
   property DocAuthor:string read FDocAuthor write FDocAuthor;
   property DocCreator:string read FDocCreator write FDocCreator;
   property DocKeywords:string read FDocKeywords write FDocKeywords;
   property DocSubject:string read FDocSubject write FDocSubject;
   property DocProducer:string read FDocProducer write FDocProducer;
   property DocCreationDate:string read FDocCreationDate write FDocCreationDate;
   property DocModificationDate:string read FDocModificationDate write FDocModificationDate;
   property DocXMPContent:string read FDocXMPContent write FDocXMPContent;

   // Document physic
   property PageWidth:integer read FPageWidth write FPageWidth;
   property PageHeight:integer read FPageHeight write FPageHeight;
   property Resolution:integer read FResolution write SetResolution default TWIPS_PER_INCHESS;
   property PDFConformance: TPDFConformanceType read FPDFConformance write FPDFConformance default PDF_1_4;
  end;



function PDFCompatibleText (astring:Widestring;adata:TRpTTFontData;pdffont:TRpPDFFont):String;
function NumberToText (Value:double):string;
function EncodePDFText(const text: string): string;

procedure GetBitmapInfo (stream:TStream; var width, height, imagesize:integer;FMemBits:TMemoryStream;
 var indexed:boolean;var bitsperpixel,usedcolors:integer;var palette:string);
procedure GetJPegInfo(astream:TStream;var width,height:integer;var format:string);

implementation



function IntToHex(nvalue:integer):string;
begin
 Result:=Format('%2.2x',[nvalue]);
end;

const
 AlignmentFlags_SingleLine=64;
 AlignmentFlags_AlignHCenter = 4 { $4 };
 AlignmentFlags_AlignHJustify = 1024 { $400 };
 AlignmentFlags_AlignTop = 8 { $8 };
 AlignmentFlags_AlignBottom = 16 { $10 };
 AlignmentFlags_AlignVCenter = 32 { $20 };
 AlignmentFlags_AlignLeft = 1 { $1 };
 AlignmentFlags_AlignRight = 2 { $2 };

// Font sizes (point 10)


  Helvetica_Widths: TWinAnsiWidthsArray = (
    278,278,355,556,556,889,667,191,333,333,389,584,278,333,
    278,278,556,556,556,556,556,556,556,556,556,556,278,278,584,584,
    584,556,1015,667,667,722,722,667,611,778,722,278,500,667,556,833,
    722,778,667,778,722,667,611,722,667,944,667,667,611,278,278,278,
    469,556,333,556,556,500,556,556,278,556,556,222,222,500,222,833,
    556,556,556,556,333,500,278,556,500,722,500,500,500,334,260,334,
    584,0,556,0,222,556,333,1000,556,556,333,1000,667,333,1000,0,
    611,0,0,222,222,333,333,350,556,1000,333,1000,500,333,944,0,
    500,667,0,333,556,556,556,556,260,556,333,737,370,556,584,0,
    737,333,400,584,333,333,333,556,537,278,333,333,365,556,834,834,
    834,611,667,667,667,667,667,667,1000,722,667,667,667,667,278,278,
    278,278,722,722,778,778,778,778,778,584,778,722,722,722,722,667,
    667,611,556,556,556,556,556,556,889,500,556,556,556,556,278,278,
    278,278,556,556,556,556,556,556,556,584,611,556,556,556,556,500,
    556,500);

 Default_Font_Width:integer=600;

 Helvetica_Bold_Widths: TWinAnsiWidthsArray = (
    278,333,474,556,556,889,722,238,333,333,389,584,278,333,
    278,278,556,556,556,556,556,556,556,556,556,556,333,333,584,584,
    584,611,975,722,722,722,722,667,611,778,722,278,556,722,611,833,
    722,778,667,778,722,667,611,722,667,944,667,667,611,333,278,333,
    584,556,333,556,611,556,611,556,333,611,611,278,278,556,278,889,
    611,611,611,611,389,556,333,611,556,778,556,556,500,389,280,389,
    584,0,556,0,278,556,500,1000,556,556,333,1000,667,333,1000,0,
    611,0,0,278,278,500,500,350,556,1000,333,1000,556,333,944,0,
    500,667,0,333,556,556,556,556,280,556,333,737,370,556,584,0,
    737,333,400,584,333,333,333,611,556,278,333,333,365,556,834,834,
    834,611,722,722,722,722,722,722,1000,722,667,667,667,667,278,278,
    278,278,722,722,778,778,778,778,778,584,778,722,722,722,722,667,
    667,611,556,556,556,556,556,556,889,556,556,556,556,556,278,278,
    278,278,611,611,611,611,611,611,611,584,611,611,611,611,611,556,
    611,556);

 Helvetica_Italic_Widths: TWinAnsiWidthsArray = (
    278,278,355,556,556,889,667,191,333,333,389,584,278,333,
    278,278,556,556,556,556,556,556,556,556,556,556,278,278,584,584,
    584,556,1015,667,667,722,722,667,611,778,722,278,500,667,556,833,
    722,778,667,778,722,667,611,722,667,944,667,667,611,278,278,278,
    469,556,333,556,556,500,556,556,278,556,556,222,222,500,222,833,
    556,556,556,556,333,500,278,556,500,722,500,500,500,334,260,334,
    584,0,556,0,222,556,333,1000,556,556,333,1000,667,333,1000,0,
    611,0,0,222,222,333,333,350,556,1000,333,1000,500,333,944,0,
    500,667,0,333,556,556,556,556,260,556,333,737,370,556,584,0,
    737,333,400,584,333,333,333,556,537,278,333,333,365,556,834,834,
    834,611,667,667,667,667,667,667,1000,722,667,667,667,667,278,278,
    278,278,722,722,778,778,778,778,778,584,778,722,722,722,722,667,
    667,611,556,556,556,556,556,556,889,500,556,556,556,556,278,278,
    278,278,556,556,556,556,556,556,556,584,611,556,556,556,556,500,
    556,500);

  Helvetica_BoldItalic_Widths: TWinAnsiWidthsArray = (
    278,333,474,556,556,889,722,238,333,333,389,584,278,333,
    278,278,556,556,556,556,556,556,556,556,556,556,333,333,584,584,
    584,611,975,722,722,722,722,667,611,778,722,278,556,722,611,833,
    722,778,667,778,722,667,611,722,667,944,667,667,611,333,278,333,
    584,556,333,556,611,556,611,556,333,611,611,278,278,556,278,889,
    611,611,611,611,389,556,333,611,556,778,556,556,500,389,280,389,
    584,0,556,0,278,556,500,1000,556,556,333,1000,667,333,1000,0,
    611,0,0,278,278,500,500,350,556,1000,333,1000,556,333,944,0,
    500,667,0,333,556,556,556,556,280,556,333,737,370,556,584,0,
    737,333,400,584,333,333,333,611,556,278,333,333,365,556,834,834,
    834,611,722,722,722,722,722,722,1000,722,667,667,667,667,278,278,
    278,278,722,722,778,778,778,778,778,584,778,722,722,722,722,667,
    667,611,556,556,556,556,556,556,889,556,556,556,556,556,278,278,
    278,278,611,611,611,611,611,611,611,584,611,611,611,611,611,556,
    611,556);

  TimesRoman_Widths: TWinAnsiWidthsArray = (
    250,333,408,500,500,833,778,180,333,333,500,564,250,333,
    250,278,500,500,500,500,500,500,500,500,500,500,278,278,564,564,
    564,444,921,722,667,667,722,611,556,722,722,333,389,722,611,889,
    722,722,556,722,667,556,611,722,722,944,722,722,611,333,278,333,
    469,500,333,444,500,444,500,444,333,500,500,278,278,500,278,778,
    500,500,500,500,333,389,278,500,500,722,500,500,444,480,200,480,
    541,0,500,0,333,500,444,1000,500,500,333,1000,556,333,889,0,
    611,0,0,333,333,444,444,350,500,1000,333,980,389,333,722,0,
    444,722,0,333,500,500,500,500,200,500,333,760,276,500,564,0,
    760,333,400,564,300,300,333,500,453,250,333,300,310,500,750,750,
    750,444,722,722,722,722,722,722,889,667,611,611,611,611,333,333,
    333,333,722,722,722,722,722,722,722,564,722,722,722,722,722,722,
    556,500,444,444,444,444,444,444,667,444,444,444,444,444,278,278,
    278,278,500,500,500,500,500,500,500,564,500,500,500,500,500,500,
    500,500);

  TimesRoman_Italic_Widths: TWinAnsiWidthsArray = (
    250,333,420,500,500,833,778,214,333,333,500,675,250,333,
    250,278,500,500,500,500,500,500,500,500,500,500,333,333,675,675,
    675,500,920,611,611,667,722,611,611,722,722,333,444,667,556,833,
    667,722,611,722,611,500,556,722,611,833,611,556,556,389,278,389,
    422,500,333,500,500,444,500,444,278,500,500,278,278,444,278,722,
    500,500,500,500,389,389,278,500,444,667,444,444,389,400,275,400,
    541,0,500,0,333,500,556,889,500,500,333,1000,500,333,944,0,
    556,0,0,333,333,556,556,350,500,889,333,980,389,333,667,0,
    389,556,0,389,500,500,500,500,275,500,333,760,276,500,675,0,
    760,333,400,675,300,300,333,500,523,250,333,300,310,500,750,750,
    750,500,611,611,611,611,611,611,889,667,611,611,611,611,333,333,
    333,333,722,667,722,722,722,722,722,675,722,722,722,722,722,556,
    611,500,500,500,500,500,500,500,667,444,444,444,444,444,278,278,
    278,278,500,500,500,500,500,500,500,675,500,500,500,500,500,444,
    500,444);

  TimesRoman_Bold_Widths: TWinAnsiWidthsArray = (
    250,333,555,500,500,1000,833,278,333,333,500,570,250,333,
    250,278,500,500,500,500,500,500,500,500,500,500,333,333,570,570,
    570,500,930,722,667,722,722,667,611,778,778,389,500,778,667,944,
    722,778,611,778,722,556,667,722,722,1000,722,722,667,333,278,333,
    581,500,333,500,556,444,556,444,333,500,556,278,333,556,278,833,
    556,500,556,556,444,389,333,556,500,722,500,500,444,394,220,394,
    520,0,500,0,333,500,500,1000,500,500,333,1000,556,333,1000,0,
    667,0,0,333,333,500,500,350,500,1000,333,1000,389,333,722,0,
    444,722,0,333,500,500,500,500,220,500,333,747,300,500,570,0,
    747,333,400,570,300,300,333,556,540,250,333,300,330,500,750,750,
    750,500,722,722,722,722,722,722,1000,722,667,667,667,667,389,389,
    389,389,722,722,778,778,778,778,778,570,778,722,722,722,722,722,
    611,556,500,500,500,500,500,500,722,444,444,444,444,444,278,278,
    278,278,500,556,500,500,500,500,500,570,500,556,556,556,556,500,
    556,500);

  TimesRoman_BoldItalic_Widths: TWinAnsiWidthsArray = (
    250,389,555,500,500,833,778,278,333,333,500,570,250,333,
    250,278,500,500,500,500,500,500,500,500,500,500,333,333,570,570,
    570,500,832,667,667,667,722,667,667,722,778,389,500,667,611,889,
    722,722,611,722,667,556,611,722,667,889,667,611,611,333,278,333,
    570,500,333,500,500,444,500,444,333,500,556,278,278,500,278,778,
    556,500,500,500,389,389,278,556,444,667,500,444,389,348,220,348,
    570,0,500,0,333,500,500,1000,500,500,333,1000,556,333,944,0,
    611,0,0,333,333,500,500,350,500,1000,333,1000,389,333,722,0,
    389,611,0,389,500,500,500,500,220,500,333,747,266,500,606,0,
    747,333,400,570,300,300,333,576,500,250,333,300,300,500,750,750,
    750,500,667,667,667,667,667,667,944,667,667,667,667,667,389,389,
    389,389,722,722,722,722,722,722,722,570,722,722,722,722,722,611,
    611,500,500,500,500,500,500,500,722,444,444,444,444,444,278,278,
    278,278,500,556,500,500,500,500,500,570,500,556,556,556,556,444,
    500,444);


procedure TrpPDFCanvas.SWriteLine(Stream:TStream;astring:string);
begin
 FFile.SWriteLine(Stream,astring);
end;





constructor TrpPDFCanvas.Create(AFile:TRpPDFFile);
begin
 inherited Create;

 FImageIndexes:=TStringList.Create;
 FImageIndexes.Sorted:=true;
{$IFDEF MSWINDOWS}
{$IFNDEF FPC}
 FGDIInfoProvider:=TRpGDIInfoProvider.Create;
 FInfoProvider:=FGDIInfoProvider;
{$ENDIF}
{$ENDIF}
{$IFDEF LINUX}
 FFtInfoProvider:=TRpFtInfoProvider.Create;
 FInfoProvider:=FFtInfoProvider;
{$ENDIF}
 FDefInfoProvider:=FInfoProvider;
 FFont:=TRpPDFFont.Create;
 FFile:=AFile;
 FFontTTData:=TStringList.Create;
 FFontTTData.Sorted:=true;
 SetLength(LineInfo,CONS_MINLINEINFOITEMS);
 FLineInfoMaxItems:=CONS_MINLINEINFOITEMS;
end;


destructor TrpPDFCanvas.Destroy;
begin
 FImageIndexes.free;
 FreeFonts;
 FFont.free;
 FFontTTData.free;
{$IFDEF MSWINDOWS}
{$IFNDEF FPC}
 FGDIInfoProvider.free;
{$ENDIF}
{$ENDIF}
{$IFDEF LINUX}
 FFtInfoProvider.free;
{$ENDIF}
 FInfoProvider:=nil;
 FDefInfoProvider:=nil;
 FFont:=nil;
 inherited Destroy;
end;




constructor TRpPDFFile.Create(AOwner:TComponent);
begin
 inherited Create(AOwner);

 NumberFormatSettings:=TFormatSettings.Create;
 NumberFormatSettings.DecimalSeparator:='.';
 FInternalFDocCreationDate:=now;
 FPageInfos:=TStringList.create;
 FCanvas:=TRpPDFCanvas.Create(Self);
 FMainPDF:=TMemoryStream.Create;
 FTempStream:=TMemoryStream.Create;
 FTempStream2:=TMemoryStream.Create;
 FsTempStream:=TMemoryStream.Create;
 FObjectOffsets:=TStringList.Create;
 FFontList:=TStringList.Create;
 FPages:=TStringList.Create;
 FPageWidth:= 12048;
 FPageHeight:= 17039;
 FResolution:=TWIPS_PER_INCHESS;
 FCanvas.FResolution:=TWIPS_PER_INCHESS;
 FBitmapStreams:=TList.Create;
 FPdfConformance:=PDF_1_4;
 FDocProducer:='Reportman';
 FDocAuthor:='Unassigned';
 FDocTitle:='Unasssigned';
end;

destructor TRpPDFFile.Destroy;
begin
 FreePageInfos;
 FPageInfos.Free;
 FCanvas.free;
 FMainPDF.Free;
 FTempStream.Free;
 FTempStream2.Free;
 FsTempStream.Free;
 FObjectOffsets.free;
 FFOntList.Free;
 FPages.Free;
 FBitmapStreams.Free;

 inherited Destroy;
end;


function TRpPDFFile.EndOfLine:string;
var
 astring:string;
begin
 astring:='';
 if (FPDFConformance = TPDFConformanceType.PDF_1_4) then
   Result:=astring+#13+#10
 // Only EOL for better compatibility in PDF A3
 else
   Result:=astring+#10;
end;

// Writes a line into a Stream that is add #13+#10
procedure TRpPDFFile.SWriteLine(Stream:TStream;astring:string);
begin
 astring:=astring+EndOfLine;
 WriteStringToStream(astring,Stream);
end;

procedure TRpPDFFile.NewAnnotation(posx,posy,width,height: integer; annotation: string);
var
 ann: TPDFAnnotation;
 aobj:TRpPageInfo;
begin
 aobj:=TRpPageInfo(FPageInfos.Objects[FPage-1]);
 ann:=TPDFAnnotation.Create;
 ann.PosX:=posx;
 ann.PosY:=posy;
 ann.Width:=width;
 ann.Page:=FPage;
 ann.Height:=height;
 ann.Annotation:=annotation;
 SetLength(aobj.PageAnnotations,Length(aobj.PageAnnotations)+1);
 aobj.PageAnnotations[Length(aobj.PageAnnotations)-1]:=ann;
end;

procedure TRpPDFFile.NewEmbeddedFile(fileName,mimeType: string;AFRelationShip: TPDFAFRelationShip;
     description,creationDate,ModificationDate: string;  stream: TMemoryStream);
var embededFile: TEmbeddedFile;
begin
 embededFile:=TEmbeddedFile.Create;
 embededFile.FileName:=fileName;
 embededFile.Description:=description;
 embededFile.Stream:=stream;
 embededFile.MimeType:=mimeType;
 embededFile.AFRelationShip:=AFRelationShip;
 embededFile.CreationDate:=creationDate;
 embededFile.ModificationDate:=ModificationDate;
 SetLength(EmbeddedFiles,Length(EmbeddedFiles)+1);
 EmbeddedFiles[Length(EmbeddedFiles)-1]:=embededFile;
end;


procedure TRpPDFFile.SetResolution(Newres:integer);
begin
 FResolution:=NewRes;
 FCanvas.FResolution:=NewRes;
end;


function TrpPDFFile.GetStream:TMemoryStream;
begin
 if Not FStreamValid then
  Raise Exception.Create(SRpStreamNotValid);
 Result:=FMainPDF;
end;


function DateTimeToPDFString(date: TDateTime): string;
begin
 Result:=FormatDateTime('yyyyMMddHHmmss',date);
end;

function TRpPDFFile.DateToISO(date:TDateTime): string;
begin
 if (FPDFConformance = TPDFConformanceType.PDF_A_3)  then
 begin
  Result:=DateToISO8601(date);
 end
 else
 begin
  Result:=DateTimeToPDFString(date);
 end
end;


procedure TRpPDFFile.BeginDoc;
var
 aobj:TRpPageInfo;
begin
 FreePageInfos;

 FCanvas.FImageIndexes.Clear;
 FCanvas.PDFConformance:=PDFConformance;
 aobj:=TRpPageInfo.Create;
 aobj.APageWidth:=FPageWidth;
 aobj.APageHeight:=FPageHeight;
 FPageInfos.AddObject('',aobj);

 ClearBitmaps;
 FPrinting:=true;
 FStreamValid:=false;
 FMainPDF.Clear;
 FObjectOffsets.Clear;
 FObjectCount:=0;
 FObjectOffset:=0;
 FPages.Clear;
 FFontList.Clear;
 FFOntCount:=0;
 FCurrentSetPageObject:=0;
 FImageCount:=0;
 FPage:=1;
 // Writes the header
 if (FPDFConformance = PDF_A_3) then
 begin
   SWriteLine(FMainPDF,PDF_HEADER_A3);
   // AddToOffset(Length(PDF_HEADER_A3));
   //SWriteLine(FMainPDF,'%äüöß');
   FMainPDF.Write([37,228,252,246,223,13,10],7);
   AddToOffset(7+Length(PDF_HEADER_A3));
   //AddToOffset(Length('%äüöß'));
 end
 else
 begin
   SWriteLine(FMainPDF,PDF_HEADER_1_4);
   AddToOffset(Length(PDF_HEADER_1_4));
 end;
 // Writes Doc info
 FObjectCount:=FObjectCount+1;
 FTempStream.Clear;
 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 SWriteLine(FTempStream,'<<');
 SWriteLine(FTempStream,'/Producer '+EncodePDFText(FDocProducer));
 SWriteLine(FTempStream,'/Author '+EncodePDFText(FDocAuthor));
 if Length(FDocCreationDate) = 0 then
 begin
  SWriteLine(FTempStream,'/CreationDate (D:'+  DateToISO(FInternalFDocCreationDate)+')');
 end
 else
 begin
  SWriteLine(FTempStream,'/CreationDate (D:'+  FDocCreationDate+')');
 end;
 if (FPDFConformance <> PDF_A_3) then
   SWriteLine(FTempStream,'/Creator '+EncodePDFText(FDocCreator));
 if (Length(FDocKeywords)>0) then
  SWriteLine(FTempStream,'/Keywords '+EncodePdfText(FDocKeywords))
 else
 begin
  if (PDFConformance = TPDFConformanceType.PDF_1_4) then
    SWriteLine(FTempStream,'/Keywords ()');
 end;

 SWriteLine(FTempStream,'/Subject '+EncodePdfText(FDocSubject));
 SWriteLine(FTempStream,'/Title '+EncodePdfText(FDocTitle));
 if Length(FDocModificationDate) = 0 then
 begin
  if (PDFConformance = TPDFConformanceType.PDF_1_4) then
   SWriteLine(FTempStream,'/ModDate ()');
 end
 else
 begin
 // SWriteLine(FTempStream,'/ModDate (D:'+  FDocModificationDate+')');
 end;
 if (FPDFConformance = PDF_A_3) then
 begin
  SWriteLine(FTempStream,'/GTS_PDFXVersion (PDF/A-3B)');
 end;
 SWriteLine(FTempStream,'>>');
 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);

 if (FPDFConformance = PDF_A_3) then
 begin
  SetXMPMetadata;
  SetColorSpace;
 end;


 StartStream;
end;

{$IFDEF USEZLIB}
function TrpPDFFIle.CompressStream(stream: TStream): TMemoryStream;
var FCompressionStream: TCompressionStream;
  FMem: TMemoryStream;
begin
 FMem:=TMemoryStream.Create;
 FCompressionStream := TCompressionStream.Create(clDefault,FMem);
 try
  stream.Seek(0, soBeginning);
  CopyStreamContent(stream, FCompressionStream);
 finally
  FCompressionStream.Free;
 end;
 FMem.Position:=0;
 Result:= FMem;
end;
{$ENDIF}

procedure TrpPDFFIle.WriteStream(stream,dest: TMemoryStream);
var longitud: integer;
{$IFDEF USEZLIB}
 longitudOriginal: integer;
 Fmem: TMemoryStream;
{$ENDIF}
begin
{$IFDEF USEZLIB}
 if (FCompressed) then
 begin
  fmem:=CompressStream(stream);
  try
   SWriteLine(dest,' /Length ' + IntToStr(fmem.Size) + ' /Length1 ' +
     IntToStr(stream.Size));
   SWriteLine(dest,'/Filter [/FlateDecode]');
   SWriteLine(dest,'>>');
   SWriteLine(dest,'stream');
   fmem.Position:=0;
   fmem.SaveToStream(dest);
  finally
   fmem.free;
  end
 end
 else
{$ENDIF}
 begin
  SWriteLine(dest,' /Length ' + IntToStr(stream.Size));
  SWriteLine(dest,'>>');
  SWriteLine(dest,'stream');
  stream.SaveToStream(dest);
 end;
 SWriteLine(dest,'');
 SWriteLine(dest,'endstream');
end;

procedure TRpPDFFile.WriteEmbeddedFiles;
var i:integer;
  efile:TEmbeddedFile;
  ResourceStream: integer;
begin
 for i:=0 to Length(EmbeddedFiles)-1 do
 begin
  efile:=EmbeddedFiles[i];
  FObjectCount:=FObjectCount+1;
  ResourceStream:=FObjectCount;
  FTempStream.Clear;
  SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
  SWriteLine(FTempStream,'<< /Type /EmbeddedFile ');
  if Length(efile.MimeType)>0 then
  begin
   SWriteLine(FTempStream,'   /Subtype /'+StringReplace(efile.MimeType,'/','#2F',[rfreplaceAll]));
   SWriteLine(FTempStream,'   /MimeType ' + EncodePDFText(efile.MimeType));
  end;
  if (efile.ModificationDate.Length>0) then
  begin
    SWriteLine(FTempStream,'   /Params <<');
    SWriteLine(FTempStream,'   /ModDate (D:'+efile.ModificationDate+')');
    SWriteLine(FTempStream,'   >>');
  end;
  efile.Stream.Position:=0;
  WriteStream(efile.Stream, FTempStream);
  SWriteLine(FTempStream,'endobj');
  AddToOffset(FTempStream.Size);
  FTempStream.Position:=0;
  FTempStream.SaveToStream(FMainPDF);

  FObjectCount:=FObjectCount+1;
  efile.ResourceNumber:=FObjectCount;
  FTempStream.Clear;
  SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
  SWriteLine(FTempStream,'<< /Type /Filespec ');
  SWriteLine(FTempStream,'   /F ' + EncodePDFText(efile.FileName));

  SWriteLine(FTempStream,'   /Desc '+EncodePDFText(efile.Description));
  SWriteLine(FTempStream,'   /UF ' + EncodePDFText(efile.FileName));
  SWriteLine(FTempStream,'   /EF << /F ' + IntToStr(ResourceStream) + ' 0 R >>');

  SWriteLine(FTempStream,'   /AFRelationship /'+efile.AFRelationShipToString());
  SWriteLine(FTempStream,'/Params <<');
  SWriteLine(FTempStream,'  /Size '+IntToStr(efile.Stream.Size));
  if Length(efile.MimeType)>0 then
  begin
   SWriteLine(FTempStream,'  /MIMEType '+EncodePDFText(efile.MimeType));
  end;

  if Length(efile.CreationDate)>0 then
  begin
   SWriteLine(FTempStream,'  /CreationDate (D:'+efile.CreationDate+')');
  end;
  if Length(efile.ModificationDate)>0 then
  begin
   SWriteLine(FTempStream,'  /ModificationDate (D:'+efile.ModificationDate+')');
  end;

  SWriteLine(FTempStream,'  >>');
  SWriteLine(FTempStream,'>>');
  SWriteLine(FTempStream,'endobj');
  AddToOffset(FTempStream.Size);
  FTempStream.Position:=0;
  FTempStream.SaveToStream(FMainPDF);
 end;
end;

procedure TRpPDFFile.SetColorSpace;
var ColorProfileObject: integer;
ICCProfile: TMemoryStream;
ResStream:TResourceStream;
begin
  // Color Space Profile
  ICCProfile:=TMemoryStream.Create;
  try
    ResStream:=TResourceStream.Create(HInstance,'srgb',RT_RCDATA);
    try
      ICCProfile.CopyFrom(ResStream,ResStream.Size);
      ICCProfile.Position:=0;
    finally
      ResStream.Free;
    end;
    FObjectCount:=FObjectCount+1;
    ColorProfileObject:=FObjectCount;
    FTempStream.Clear;
    SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
    SWriteLine(FTempStream,'<< /N 3 /Alternate /DeviceRGB ');
    WriteStream(ICCProfile, FTempStream);
    SWriteLine(FTempStream,'endobj');
    AddToOffset(FTempStream.Size);
    FTempStream.Position:=0;
    FTempStream.SaveToStream(FMainPDF);
  finally
    ICCProfile.Free;
  end;

    // Output Intent
  FObjectCount:=FObjectCount+1;
  FOutputIntentObject:=FObjectCount;
  FTempStream.Clear;
  SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
  SWriteLine(FTempStream,'<< /Type /OutputIntent');
  SWriteLine(FTempStream,'  /S /GTS_PDFA1');
  SWriteLine(FTempStream,'  /OutputConditionIdentifier (sRGB IEC61966-2.1) ');
  SWriteLine(FTempStream,'  /Info (sRGB IEC61966-2.1) ');
  SWriteLine(FTempStream,'  /DestOutputProfile '+ IntToStr(ColorProfileObject) +' 0 R');
  SWriteLine(FTempStream,'>>');
  SWriteLine(FTempStream,'endobj');
  AddToOffset(FTempStream.Size);
  FTempStream.Position:=0;
  FTempStream.SaveToStream(FMainPDF);

  // Color Space
  FObjectCount:=FObjectCount+1;
  FColorSpaceObject:=FObjectCount;
  FTempStream.Clear;
  SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
  SWriteLine(FTempStream,'<<  /Type /ColorSpace');
  SWriteLine(FTempStream,'    /ColorSpace [/ICCBased '+IntToStr(ColorProfileObject)+' 0 R] >>');
  SWriteLine(FTempStream,'endobj');
  AddToOffset(FTempStream.Size);
  FTempStream.Position:=0;
  FTempStream.SaveToStream(FMainPDF);


end;


procedure TRpPDFFile.SetXMPMetadata;
var
 FXMPStream: TMemoryStream;
 i:integer;
 efile: TEmbeddedFile;
 keywords:TArray<string>;
 keyword: string;
begin
 FXMPStream:=TMemoryStream.Create();
 try
  SWriteLine(FXMPStream, '<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>');
  SWriteLine(FXMPStream, '<x:xmpmeta xmlns:x="adobe:ns:meta/">');
  SWriteLine(FXMPStream, '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"');
  SWriteLine(FXMPStream, '    xmlns:xmp="http://ns.adobe.com/xap/1.0/"');
  SWriteLine(FXMPStream, '    xmlns:pdf="http://ns.adobe.com/pdf/1.3/"');
  SWriteLine(FXMPStream, '    xmlns:dc="http://purl.org/dc/elements/1.1/"');
  SWriteLine(FXMPStream, '    xmlns:xmpMM="http://ns.adobe.com/xap/1.0/mm/"');
  //if Length(FDocXMPSchemas)>0 then
  //begin
  // SWriteLine(FXMPStream, FDocXMPSchemas);
  //end;
  SWriteLine(FXMPStream, '    xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/">');
  SWriteLine(FXMPStream, '  <rdf:Description rdf:about="">');
  SWriteLine(FXMPStream, '    <dc:creator>');
  SWriteLine(FXMPStream, '      <rdf:Seq>');
  SWriteLine(FXMPStream, '        <rdf:li>' + EscapeXML(FDocAuthor) +'</rdf:li>');
  SWriteLine(FXMPStream, '      </rdf:Seq>');
  SWriteLine(FXMPStream, '    </dc:creator>');
  SWriteLine(FXMPStream, '    <dc:title>');
  SWriteLine(FXMPStream, '      <rdf:Alt>');
  SWriteLine(FXMPStream, '        <rdf:li xml:lang="x-default">'+EscapeXML(FDocTitle)+'</rdf:li>');
  SWriteLine(FXMPStream, '      </rdf:Alt>');
  SWriteLine(FXMPStream, '    </dc:title>');
  if (Length(FDocKeywords)>0) then
  begin
   SWriteLine(FXMPStream, '    <dc:subject>');
   SWriteLine(FXMPStream, '     <rdf:Bag>');
   keywords:=FDocKeywords.Split([',']);
   for keyword in keywords do
   begin
    SWriteLine(FXMPStream, '      <rdf:li>'+EscapeXML(keyword)+'</rdf:li>');
   end;
   SWriteLine(FXMPStream, '     </rdf:Bag>');
   SWriteLine(FXMPStream, '    </dc:subject>');
//   SWriteLine(FXMPStream, '      <rdf:Alt>');
//   SWriteLine(FXMPStream, '        <rdf:li xml:lang="x-default">'+EscapeXML(FDocKeywords)+'</rdf:li>');
//   SWriteLine(FXMPStream, '      </rdf:Alt>');
  end;
  SWriteLine(FXMPStream, '    <dc:description>');
  SWriteLine(FXMPStream, '      <rdf:Alt>');
  SWriteLine(FXMPStream, '        <rdf:li xml:lang="x-default">'+EscapeXML(FDocSubject)+'</rdf:li>');
  SWriteLine(FXMPStream, '      </rdf:Alt>');
  SWriteLine(FXMPStream, '    </dc:description>');
  if Length(FDocCreationDate)= 0 then
   SWriteLine(FXMPStream, '    <xmp:CreateDate>'+DateToISO8601(FInternalFDocCreationDate) (* 2024-10-02T15:29:15+00:00 *)
     +'</xmp:CreateDate>')
  else
   SWriteLine(FXMPStream, '    <xmp:CreateDate>'+EscapeXML(FDocCreationDate) (* 2024-10-02T15:29:15+00:00 *)
     +'</xmp:CreateDate>');
//  if Length(FDocModificationDate) > 0 then
//  begin
 //  SWriteLine(FXMPStream, '    <xmp:ModifyDate>'+EscapeXML(FDocModificationDate)+'</xmp:ModifyDate>');
 // end;
  if Length(FDocProducer) > 0 then
  begin
   SWriteLine(FXMPStream, '    <xmp:CreatorTool>'+EscapeXML(FDocProducer)+'</xmp:CreatorTool>');
  end;
  // SWriteLine(FXMPStream, '    <xmp:ModifyDate>2024-10-02T15:29:15+00:00</xmp:ModifyDate>');
  //SWriteLine(FXMPStream, '    <xmpMM:DocumentID>uuid:12345678-1234-1234-1234-1234567890ab</xmpMM:DocumentID>');
  //SWriteLine(FXMPStream, '    <xmpMM:InstanceID>uuid:12345678-1234-1234-1234-1234567890ac</xmpMM:InstanceID>');
  SWriteLine(FXMPStream, '    <pdfaid:part>3</pdfaid:part>');
  SWriteLine(FXMPStream, '    <pdfaid:conformance>B</pdfaid:conformance>');
//  if Length(FDocXMPContent)>0 then
//  begin
//   SWriteLine(FXMPStream, /FDocXMPContent);
//  end;
  // SWriteLine(FXMPStream, '    <xmp:CreatorTool>My PDF Creator Tool</xmp:CreatorTool>');


(*  if Length(EmbeddedFiles)>0 then
  begin
   SWriteLine(FXMPStream, '    <xmpMM:EmbeddedFiles>');
   SWriteLine(FXMPStream, '     <rdf:Bag>');
   for i:=0 to Length(EmbeddedFiles)-1 do
   begin
    efile:=EmbeddedFiles[i];
    SWriteLine(FXMPStream, '       <rdf:li>');
    SWriteLine(FXMPStream, '        <rdf:Description>');
    SWriteLine(FXMPStream, '         <xmpMM:FileName>'+efile.FileName+'</xmpMM:FileName>');
    SWriteLine(FXMPStream, '         <xmpMM:Format>'+efile.MimeType+'</xmpMM:Format>');
    SWriteLine(FXMPStream, '        </rdf:Description>');
    SWriteLine(FXMPStream, '       </rdf:li>');
   end;
   SWriteLine(FXMPStream, '     </rdf:Bag>');
   SWriteLine(FXMPStream, '    </xmpMM:EmbeddedFiles>');
  end;*)

  SWriteLine(FXMPStream, '  </rdf:Description>');
  if Length(FDocXMPContent)>0 then
  begin
   SWriteLine(FXMPStream, FDocXMPContent);
  end;
  SWriteLine(FXMPStream, '</rdf:RDF>');
  SWriteLine(FXMPStream, '</x:xmpmeta>');
  SWriteLine(FXMPStream, '<?xpacket end="w"?>');
  FXMPStream.Seek(0,TSeekOrigin.soBeginning);

  FObjectCount:=FObjectCount+1;
  FXMPMetadataObject:=FObjectCount;
  FTempStream.Clear;
  SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
  SWriteLine(FTempStream,'<< /Type /Metadata');
  SWriteLine(FTempStream,'   /Subtype /XML');
  SWriteLine(FTempStream,'   /Length ' + IntToStr(FXMPStream.Size-1));
  SWriteLine(FTempStream,'>>');
  SWriteLine(FTempStream,'stream');
  FXMPStream.SaveToStream(FTempStream);
  SWriteLine(FTempStream,'endstream');
  SWriteLine(FTempStream,'endobj');
  AddToOffset(FTempStream.Size);
  FTempStream.SaveToStream(FMainPDF);
 finally
  FXMPStream.Free;
 end;
end;

procedure TRpPDFFile.StartStream;
begin
 // Starting of the stream
 FObjectCount:=FObjectCount+1;
 FTempStream.Clear;

 if (FPDFConformance = PDF_A_3) then
  PageObjNum:=FObjectCount
 else
  PageObjNum:=FObjectCount;


 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 SWriteLine(FTempStream,'<< /Length '+IntToStr(FObjectCount+1)+' 0 R');
{$IFDEF USEZLIB}
 if FCompressed then
  SWriteLine(FTempStream,'/Filter [/FlateDecode]');
{$ENDIF}
 SWriteLine(FTempStream,' >>');
 SWriteLine(FTempStream,'stream');
 FsTempStream.Clear;
end;

procedure TRpPDFFile.EndStream;
var TempSize: LongInt;
var StreamSize: Longint;
var CurrentSize: Longint;
{$IFDEF USEZLIB}
 FCompressionStream: TCompressionStream;
{$ENDIF}
begin
 StreamSize:=FsTempStream.Size;
 CurrentSize:=FTempStream.Size;
{$IFDEF USEZLIB}
 if FCompressed then
 begin
  FCompressionStream := TCompressionStream.Create(clDefault,FTempStream);
  try
   FsTempStream.Seek(0,soBeginning);
   CopyStreamContent(FsTempStream, FCompressionStream);
  finally
   FCompressionStream.Free;
  end;
  StreamSize:=FTempStream.Size-CurrentSize;
 end
 else
{$ENDIF}
  FsTempStream.SaveToStream(FTempStream);

 FsTempStream.Clear;

 SWriteLine(FTempStream,'');
 SWriteLine(FTempStream,'endstream');
 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);

 FObjectCount:=FObjectCount+1;
 FTempStream.Clear;
 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 SWriteLine(FTempStream,IntToStr(StreamSize));
 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);
end;


procedure TRpPDFFile.AddToOffset(offset:LongInt);
begin
 FObjectOffset:=FObjectOffset+offset;
 FObjectOffsets.Add(IntToStr(FObjectOffset));
end;


procedure TRpPDFFile.NewPage(NPageWidth,NPageHeight:integer);
var
// TempSize:LongInt;
 StreamSize: LongInt;
 CurrentSize: LongInt;
 aobj:TRpPageInfo;
{$IFDEF USEZLIB}
 FCompressionStream: TCompressionStream;
{$ENDIF}
begin
 CheckPrinting;

 FPageWidth:=NPageWidth;
 FPageHeight:=NPageHeight;
 aobj:=TRpPageInfo.Create;
 aobj.APageWidth:=NPageWidth;
 aobj.APageHeight:=NPageHeight;
 FPageInfos.AddObject('',aobj);

 FPage:=FPage+1;

 StreamSize:=FsTempStream.Size;
 CurrentSize:=FTempStream.Size;
{$IFDEF USEZLIB}
 if FCompressed then
 begin
  FCompressionStream := TCompressionStream.Create(clDefault,FTempStream);
  try
   FsTempStream.Seek(0, soBeginning);
   CopyStreamContent(FsTempStream, FCompressionStream);
   //FCompressionStream.CopyFrom(FsTempStream, FsTempStream.Size);
  finally
   FCompressionStream.Free;
  end;
  StreamSize:=FTempStream.Size-CurrentSize;
 end
 else
{$ENDIF}
  FsTempStream.SaveToStream(FTempStream);

 FsTempStream.Clear;
 SWriteLine(FTempStream,'');
 SWriteLine(FTempStream,'endstream');
 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);
 FObjectCount:=FObjectCount+1;
 FTempStream.Clear;
 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 SWriteLine(FTempStream,IntToStr(StreamSize));
 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);

 FObjectCount:=FObjectCount+1;
 FTempStream.Clear;
 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 SWriteLine(FTempStream,'<< /Length '+IntToStr(FObjectCount+1)+' 0 R');
{$IFDEF USEZLIB}
 if Compressed then
  SWriteLine(FTempStream,'/Filter [/FlateDecode]');
{$ENDIF}
 SWriteLine(FTempStream,' >>');

 SWriteLine(FTempStream,'stream');
end;


procedure TRpPDFFile.CheckPrinting;
begin
 if Not FPrinting then
  Raise Exception.Create(SRpNotPrintingPDF);
end;

procedure TRpPDFFile.SetOutLine;
begin
 FObjectCount:=FObjectCount+1;
 FOutLinesNum:=FObjectCount;
 FTempStream.Clear;
 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 SWriteLine(FTempStream,'<< /Type /Outlines');
 SWriteLine(FTempStream,'/Count 0');
 SWriteLine(FTempStream,'>>');
 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);
end;

procedure TrpPDFFile.CreateFont(Subtype,BaseFont,Encoding:string);
begin
 FFontCount:=FFontCount+1;
 FObjectCount:=FObjectCount+1;
 FFontList.Add(IntToStr(FObjectCount));
 FTempStream.Clear;
 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 SWriteLine(FTempStream,'<< /Type /Font');
 SWriteLine(FTempStream,'/Subtype /'+Subtype);
 SWriteLine(FTempStream,'/Name /F'+IntToStr(FFontCount));
 SWriteLine(FTempStream,'/BaseFont /'+BaseFont);
 SWriteLine(FTempStream,'/Encoding /'+Encoding);
 SWriteLine(FTempStream,'>>');
 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);
end;



procedure TrpPDFFile.SetPages;
var
 i:Integer;
begin
 FObjectCount:=FObjectCount+1;
 FParentNum:=FObjectCount;
 FTempStream.Clear;
 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 SWriteLine(FTempStream,'<< /Type /Pages');
 SWriteLine(FTempStream,'/Kids [');

 // if (FPDFConformance = PDF_A_3) then
 //  PageObjNum:=6
 // else
 //  PageObjNum:=2;

 for i:= 1 to FPage do
 begin
  SWriteLine(FTempStream,IntToStr(FObjectCount+i+1+FImageCount)+' 0 R');
  FPages.Add(IntToStr(PageObjNum));
  PageObjNum:=PageObjNum+2;
 end;
 SWriteLine(FTempStream,']');
 SWriteLine(FTempStream,'/Count '+IntToStr(FPage));
 SWriteLine(FTempStream,'>>');
 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);
end;


procedure TrpPDFFile.SetArray;
var
 i:Integer;
 adata:TRpTTFontData;
begin
 FObjectCount:=FObjectCount+1;
 FResourceNum:=FObjectCount;
 FTempStream.Clear;
 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 if (FPDFConformance = PDF_A_3) then
  SWriteLine(FTempStream,'<< /ProcSet [/PDF]')
 else
  SWriteLine(FTempStream,'<< /ProcSet [ /PDF /Text /ImageC]');
 if (FImageCount>0) then
 begin
  SWriteLine(FTempStream,'/XObject << ');
  for i:=1 to FImageCount do
   SWriteLine(FTempStream,'/Im'+IntToStr(i)+' '+IntToStr(FObjectCount+i)+' 0 R');
  SWriteLine(FTempStream,'>>');
 end;
 SWriteLine(FTempStream,'/Font << ');

 for i:=1 to FFontCount do
  SWriteLine(FTempStream,'/F'+IntToStr(i)+' '+FFontList.Strings[i-1]+' 0 R ');
 for i:=0 to Canvas.FFontTTData.Count-1 do
 begin
  adata:=TRpTTFontData(Canvas.FFontTTData.Objects[i]);
  SWriteLine(FTempStream,'/F'+Canvas.FFontTTData.Strings[i]+
   ' '+IntToStr(adata.ObjectIndexParent)+' 0 R ');
 end;
 SWriteLine(FTempStream,'>>');

 if (FPDFConformance = PDF_A_3) then
 begin
  SWriteLine(FTempStream,'/ColorSpace << ');
  SWriteLine(FTempStream,'     /CS1 ' + IntToStr(FColorSpaceObject) + ' 0 R');
  SWriteLine(FTempStream,'  >>');
 end;

 SWriteLine(FTempStream,'>>');


 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);
end;

procedure TRpPDFFile.AddAnnotations;
var
 i:integer;
 aobj:TRpPageInfo;
 anot,coords: string;
 annotation:TPDFAnnotation;
begin
 for i:=0 to FPageInfos.Count-1 do
 begin
  aobj:=TRpPageInfo(FPageInfos.Objects[i]);
  for annotation in aobj.PageAnnotations do
  begin
   FTempStream.Clear;
   FObjectCount := FObjectCount + 1;
   annotation.StreamNumber:=FObjectCount;
   SWriteLine(FTempStream, IntToStr(FObjectCount) + ' 0 obj');
   SWriteLine(FTempStream, '<< /Type /Annot');
  	anot := annotation.Annotation;
   if ( (Length(anot)>4) and (Uppercase(anot.Substring(0,4))='URL:') ) then
   begin
    SWriteLine(FTempStream, '  /Subtype /Link');
 	 anot := anot.Substring(4, anot.Length);
    coords := Canvas.UnitsToTextX(annotation.PosX) + ' ' + Canvas.UnitsToTextY(annotation.PosY+annotation.Height) +
                       ' ' + Canvas.UnitsToTextX(annotation.PosX+annotation.Width)
 					  + ' ' + Canvas.UnitsToTextY(annotation.PosY);
    SWriteLine(FTempStream, '   /Rect ['+coords+']');
    SWriteLine(FTempStream, '   /A << /Type /Action');
    SWriteLine(FTempStream, '        /S /URI');
    SWriteLine(FTempStream, '        /URI ' + EncodePDFText(anot));
    SWriteLine(FTempStream, '   >>');
   end
   else
   begin
    SWriteLine(FTempStream, '   /Subtype /Text');
    coords := Canvas.UnitsToTextX(annotation.PosX) + ' ' + Canvas.UnitsToTextY(annotation.PosY+annotation.Height) +
                       ' ' + Canvas.UnitsToTextX(annotation.PosX+annotation.Width)
 					  + ' ' + Canvas.UnitsToTextY(annotation.PosY);
    SWriteLine(FTempStream, '   /Border [0 0 2]');
    SWriteLine(FTempStream, '   /Rect [' + coords + ']');
    SWriteLine(FTempStream, '   /Contents ' + EncodePDFText(anot));
    SWriteLine(FTempStream, '   /Open false');
    SWriteLine(FTempStream, '   /C [1 1 0]');
   end;
   SWriteLine(FTempStream, '>>');
   AddToOffset(FTempStream.Size);
   FTempStream.SaveToStream(FMainPDF);
  end;
 end;
end;


procedure TrpPDFFile.SetPageObject(index:integer);
var
 aobj:TRpPageInfo;
 annotationsString, anot: string;
 annotation:TPDFAnnotation;
begin
 aobj:=TRpPageInfo(FPageInfos.Objects[index-1]);
 for annotation in aobj.PageAnnotations do
 begin
  if length(annotationsString)=0 then
  begin
   annotationsString:=annotationsString+'[';
  end
  else
  begin
   annotationsString:=annotationsString+' ';
  end;
  annotationsString:=annotationsString + IntToStr(annotation.StreamNumber) + ' 0 R';
 end;
 FObjectCount:=FObjectCount+1;
 FTempStream.Clear;
 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 SWriteLine(FTempStream,'<< /Type /Page');
 SWriteLine(FTempStream,'/Parent '+IntToStr(FParentNum)+' 0 R');
// SWriteLine(FTempStream,'/MediaBox [ 0 0 '+Canvas.UnitsToTextX(FPageWidth)+' '+Canvas.UnitsToTextX(FPageHEight)+']');
 SWriteLine(FTempStream,'/MediaBox [ 0 0 '+
  Canvas.UnitsToTextX(aobj.APageWidth)+' '+Canvas.UnitsToTextX(aobj.APageHEight)+']');
 SWriteLine(FTempStream,'/Contents '+FPages.Strings[FCurrentSetPageObject]+' 0 R');
 SWriteLine(FTempStream,'/Resources '+IntToStr(FResourceNum)+' 0 R');
 if Length(annotationsString) > 0 then
 begin
  annotationsString:= annotationsString +']';
  SWriteLine(FTempStream, '/Annots ' + annotationsString);
 end;
 SWriteLine(FTempStream,'>>');
 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);
 FCurrentSetPageObject:=FCurrentSetPageObject+1;
end;


function TRpPDFCanvas.UnitsToYPosFont(Value: double;FontSize: integer):double;
begin
 Result:=((Double(FFile.FPageHeight-Value)/FResolution)*CONS_PDFRES)-FontSize;
end;



function TRpPDFCanvas.UnitsToTextText(Value:double;FontSize:integer):string;
var
{$IFDEF DOTNETD}
 olddecimalseparator:String;
{$ENDIF}
{$IFNDEF DOTNETD}
 olddecimalseparator:char;
{$ENDIF}
begin
{$IFDEF DELPHI2009UP}
 olddecimalseparator:=FormatSettings.DecimalSeparator;

 FormatSettings.DecimalSeparator:='.';
 try
  Result:=FormatCurr('######0.00',(((FFile.FPageHeight-Value)/FResolution)*CONS_PDFRES)-FontSize);
 finally
  FormatSettings.DecimalSeparator:=olddecimalseparator;
 end;
{$ELSE}
 olddecimalseparator:=DecimalSeparator;

 DecimalSeparator:='.';
 try
  Result:=FormatCurr('######0.00',(((FFile.FPageHeight-Value)/FResolution)*CONS_PDFRES)-FontSize);
 finally
  DecimalSeparator:=olddecimalseparator;
 end;
{$ENDIF}
end;


function NumberToText(Value:double):string;
var
{$IFDEF DOTNETD}
 olddecimalseparator:String;
{$ENDIF}
{$IFNDEF DOTNETD}
 olddecimalseparator:char;
{$ENDIF}
begin
{$IFDEF DELPHI2009UP}
 olddecimalseparator:=FormatSettings.decimalseparator;
 FormatSettings.decimalseparator:='.';
 try
  Result:=FormatCurr('######0.00',Value);
 finally
  FormatSettings.decimalseparator:=olddecimalseparator;
 end;
{$ELSE}
 olddecimalseparator:=decimalseparator;
 decimalseparator:='.';
 try
  Result:=FormatCurr('######0.00',Value);
 finally
  decimalseparator:=olddecimalseparator;
 end;
{$ENDIF}
end;


function TRpPDFCanvas.UnitsToXPos(Value:double):double;
begin
 Result:=(Double(Value)/FResolution)*CONS_PDFRES;
end;

function TRpPDFCanvas.UnitsToTextX(Value:double):string;
var
{$IFDEF DOTNETD}
 olddecimalseparator:String;
{$ENDIF}
{$IFNDEF DOTNETD}
 olddecimalseparator:char;
{$ENDIF}
begin
{$IFDEF DELPHI2009UP}
 olddecimalseparator:=FormatSettings.decimalseparator;
 FormatSettings.decimalseparator:='.';
 try
  Result:=FormatCurr('######0.00',(Value/FResolution)*CONS_PDFRES);
 finally
  FormatSettings.decimalseparator:=olddecimalseparator;
 end;
{$ELSE}
 olddecimalseparator:=decimalseparator;
 decimalseparator:='.';
 try
  Result:=FormatCurr('######0.00',(Value/FResolution)*CONS_PDFRES);
 finally
  decimalseparator:=olddecimalseparator;
 end;
{$ENDIF}
end;

function TRpPDFCanvas.UnitsToTextY(Value:double):string;
var
{$IFDEF DOTNETD}
 olddecimalseparator:String;
{$ENDIF}
{$IFNDEF DOTNETD}
 olddecimalseparator:char;
{$ENDIF}
begin
{$IFDEF DELPHI2009UP}
 olddecimalseparator:=FormatSettings.decimalseparator;
 FormatSettings.decimalseparator:='.';
 try
  Result:=FormatCurr('######0.00',((FFile.FPageHeight-Value)/FResolution)*CONS_PDFRES);
 finally
  FormatSettings.decimalseparator:=olddecimalseparator;
 end;
{$ELSE}
 olddecimalseparator:=decimalseparator;
 decimalseparator:='.';
 try
  Result:=FormatCurr('######0.00',((FFile.FPageHeight-Value)/FResolution)*CONS_PDFRES);
 finally
  decimalseparator:=olddecimalseparator;
 end;
{$ENDIF}
end;


procedure TrpPDFFile.SetCatalog;
var
 files:string;
 efile:TEmbeddedFile;
 i:integer;
 resources:string;
begin
 FObjectCount:=FObjectCount+1;
 FCatalogNum:=FObjectCount;
 FTempStream.Clear;
 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 SWriteLine(FTempStream,'<< /Type /Catalog');
 SWriteLine(FTempStream,'/Pages '+IntToStr(FParentNum)+' 0 R');
 SWriteLine(FTempStream,'/Outlines '+IntToStr(FOutlinesNum)+' 0 R');
 if (FPDFConformance = PDF_A_3) then
 begin
  SWriteLine(FTempStream,'/Metadata '+IntToStr(FXMPMetadataObject)+' 0 R');
  SWriteLine(FTempStream,'/OutputIntents ['+IntToStr(FOutputIntentObject)+' 0 R]');
  if Length(EmbeddedFiles)>0 then
  begin
   files:='[';
   resources:='[';
   for i:=0 to Length(EmbeddedFiles)-1 do
   begin
    efile:=EmbeddedFiles[i];
    files:=files + EncodePDFText(efile.FileName) + ' ' + IntToStr(efile.ResourceNumber)
      + ' 0 R' ;
    resources:=resources + ' ' + IntToStr(efile.ResourceNumber) + ' 0 R' ;
   end;
   files:=files + ']';
   resources:=resources + ']';
   SWriteLine(FTempStream,'/Names <<');
   SWriteLine(FTempStream,'  /EmbeddedFiles << /Names '+ files + ' >>');
   SWriteLine(FTempStream,'>>');
   // /AF << /Names [ (pdfa_validation1.xml) 18 0 R (cajass.png) 20 0 R] >>
   //    SWriteLine(FTempStream,'/AF << /Names '+ files + ' >> ');
   SWriteLine(FTempStream,'/AF '+resources);
  end;
 end;

 SWriteLine(FTempStream,'>>');
 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);
end;


function TrpPDFFile.GetOffsetNumber(offset:string):string;
var
 x,y:LongInt;
begin
 x:=Length(offset);
 result:='';
 for y:= 1 to 10-x do
  result:=result+'0';
 result:=result+offset;
end;

procedure TrpPDFFile.SetXref;
var i:Integer;
var guid: TGuid;
var guidstring: string;
begin
 FObjectCount:=FObjectCount+1;
 FTempStream.Clear;
 SWriteLine(FTempStream,'xref');
 SWriteLine(FTempStream,'0 '+IntToStr(FObjectCount));
 SWriteLine(FTempStream,'0000000000 65535 f');

 for i:=0 to FObjectCount-2 do
  SWriteLine(FTempStream,GetOffsetNumber(trim(FObjectOffsets.Strings[i]))+' 00000 n');

 SWriteLine(FTempStream,'trailer');
 SWriteLine(FTempStream,'<< /Size '+IntToStr(FObjectCount));
 SWriteLine(FTempStream,'/Root '+IntToStr(FCatalogNum)+' 0 R');
 SWriteLine(FTempStream,'/Info 1 0 R');
 if (PDFConformance = PDF_A_3) then
 begin
  System.SysUtils.CreateGUID(guid);
  guidString:=System.SysUtils.GUIDToString(guid);
  guidString:=guidstring.Replace('-','');
  guidString:=guidstring.Replace('{','');
  guidString:=guidstring.Replace('}','');
  SWriteLine(FTempStream,'/ID [<'+guidstring+'> <1234567890abcdef1234567890abcdef>]');
 end;
 SWriteLine(FTempStream,'>>');
 SWriteLine(FTempStream,'startxref');
 SWriteLine(FTempStream,IntToStr(FMainPDF.Size));
// SWriteLine(FTempStream,trim(FObjectOffsets.Strings[FObjectCount-1]));
 FTempStream.SaveToStream(FmainPDF);
end;

procedure TRpPDFFile.ClearBitmaps;
begin
 while FBitmapStreams.Count>0 do
 begin
  TObject(FBitmapStreams.Items[0]).Free;
  FBitmapStreams.Delete(0);
 end;
end;

procedure TRpPDFFile.WriteBitmap(index:Integer);
begin
 FObjectCount:=FObjectCount+1;
 FTempStream.Clear;
 SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
 TMemoryStream(FBitmapStreams.Items[index-1]).SaveToStream(FTempStream);
 SWriteLine(FTempStream,#13#10+'endstream');
 SWriteLine(FTempStream,'endobj');
 AddToOffset(FTempStream.Size);
 FTempStream.SaveToStream(FMainPDF);
end;


procedure TRpPDFFile.EndDoc;
var
 i:integer;
begin
 CheckPrinting;
 FPrinting:=false;
 // Writes the trailing zone
 EndStream;
 SetOutLine;
 SetFontType;
 AddAnnotations;
 SetPages;
 SetArray;
 for i:= 1 to FImageCount do
  WriteBitmap(i);
 for i:= 1 to FPage do
 begin
  SetPageObject(i);
 end;
 WriteEmbeddedFiles;
 SetCatalog;
 SetXref;
 SWriteLine(FMainPDF,'%%EOF');


 // Save to disk if filename assigned
 FStreamValid:=True;
 FMainPDF.Seek(0,soFromBeginning);
 if Length(Trim(FFilename))>0 then
 begin
  FMainPDF.SaveToFile(FFilename);
  FMainPDF.Seek(0,soFromBeginning);
 end;
 if Assigned(DestStream) then
 begin
  FMainPDF.SaveToStream(DestStream);
  FMainPDF.Seek(0,soFromBeginning);
 end;
 ClearBitmaps;
end;

procedure TRpPDFFile.AbortDoc;
begin
 FMainPDF.Clear;
 FStreamValid:=false;
 FPrinting:=false;
end;


function RGBToFloats(color:integer):string;
var
 r,g,b:byte;
 acolor:LongWord;
{$IFDEF DOTNETD}
 olddecimal:String;
{$ENDIF}
{$IFNDEF DOTNETD}
 olddecimal:char;
{$ENDIF}
begin
{$IFDEF DELPHI2009UP}
 olddecimal:=FormatSettings.decimalseparator;
 try
  FormatSettings.decimalseparator:='.';
  acolor:=LongWord(color);
  r:=byte(acolor);
  Result:=FormatCurr('0.00',r/256);
  g:=byte(acolor shr 8);
  Result:=Result+' '+FormatCurr('0.00',g/256);
  b:=byte(acolor shr 16);
  Result:=Result+' '+FormatCurr('0.00',b/256);
 finally
  FormatSettings.decimalseparator:=olddecimal;
 end;
{$ELSE}
 olddecimal:=decimalseparator;
 try
  decimalseparator:='.';
  acolor:=LongWord(color);
  r:=byte(acolor);
  Result:=FormatCurr('0.00',r/256);
  g:=byte(acolor shr 8);
  Result:=Result+' '+FormatCurr('0.00',g/256);
  b:=byte(acolor shr 16);
  Result:=Result+' '+FormatCurr('0.00',b/256);
 finally
  decimalseparator:=olddecimal;
 end;
{$ENDIF}
end;


procedure TRpPDFCanvas.SetDash;
begin
 case PenStyle of
  // Dash
  1:
   begin
    SWriteLine(FFile.FsTempStream,'[16 8] 0 d');
   end;
  // Dot
  2:
   begin
    SWriteLine(FFile.FsTempStream,'[3] 0 d');
   end;
  // Dash dot
  3:
   begin
    SWriteLine(FFile.FsTempStream,'[8 7 2 7] 0 d');
   end;
  // Dash dot dot
  4:
   begin
    SWriteLine(FFile.FsTempStream,'[8 4 2 4 2 4] 0 d');
   end;
  // Clear
  5:
   begin
   end;
  else
   begin
    SWriteLine(FFile.FsTempStream,'[] 0 d');
   end;
 end;
end;

procedure TRpPDFCanvas.Line(x1,y1,x2,y2:Integer);
var
 LineWidth:integer;

procedure DoWriteLine;
begin
 SWriteLine(FFile.FsTempStream,RGBToFloats(PenColor)+' RG');
 SWriteLine(FFile.FsTempStream,RGBToFloats(PenColor)+' rg');
 SWriteLine(FFile.FsTempStream,UnitsToTextX(x1)+' '+UnitsToTextY(y1)+' m');
 SWriteLine(FFile.FsTempStream,UnitsToTextX(x2)+' '+UnitsToTextY(y2)+' l');
 // S-Solid,  D-Dashed, B-Beveled, I-Inset, U-Underline
 SWriteLine(FFile.FsTempStream,'S');
end;

begin
 if PenStyle=5 then
  exit;
 SetDash;
 LineWidth:=1;
 If (PenWidth>0) then
  LineWidth:=PenWidth;
 // Line cap
 SWriteLine(FFile.FsTempStream,'1 J');
 SWriteLine(FFile.FsTempStream,UnitsToTextX(LineWidth)+' w');
 DoWriteLine;
end;

procedure TRpPDFCanvas.Ellipse(X1, Y1, X2, Y2: Integer);
var
 LineWidth:integer;
 W,H:integer;
 opfill:string;
begin
 if ((PenStyle=5) and (BrushStyle=1)) then
  exit;
 SetDash;
 W:=X2-X1;
 H:=Y2-Y1;
 LineWidth:=1;
 If (PenWidth>0) then
  LineWidth:=PenWidth;
 SWriteLine(FFile.FsTempStream,UnitsToTextX(LineWidth)+' w');
 SWriteLine(FFile.FsTempStream,RGBToFloats(PenColor)+' RG');
 SWriteLine(FFile.FsTempStream,RGBToFloats(BrushColor)+' rg');
 // Draws a ellipse in 4 pass
 SWriteLine(FFile.FsTempStream,UnitsToTextX(X1)+' '+
  UnitsToTextY(y1+(H div 2))+' m');
 SWriteLine(FFile.FsTempStream,
  UnitsToTextX(X1)+' '+UnitsToTextY(y1+(H div 2)-Round(H/2*11/20))+' '+
  UnitsToTextX(X1+(W div 2)-Round(W/2*11/20))+' '+UnitsToTextY(y1)+' '+
  UnitsToTextX(X1+(W div 2))+' '+UnitsToTextY(y1)+
  ' c');
 SWriteLine(FFile.FsTempStream,
  UnitsToTextX(X1+(W div 2)+Round(W/2*11/20))+' '+UnitsToTextY(y1)+' '+
  UnitsToTextX(X1+W)+' '+UnitsToTextY(y1+(H div 2)-Round(H/2*11/20))+' '+
  UnitsToTextX(X1+W)+' '+UnitsToTextY(y1+(H div 2))+
  ' c');
 SWriteLine(FFile.FsTempStream,
  UnitsToTextX(X1+W)+' '+UnitsToTextY(y1+(H div 2)+Round(H/2*11/20))+' '+
  UnitsToTextX(X1+(W div 2)+Round(W/2*11/20))+' '+UnitsToTextY(y1+H)+' '+
  UnitsToTextX(X1+(W div 2))+' '+UnitsToTextY(y1+H)+
  ' c');
 SWriteLine(FFile.FsTempStream,
  UnitsToTextX(X1+(W div 2)-Round(W/2*11/20))+' '+UnitsToTextY(y1+H)+' '+
  UnitsToTextX(X1)+' '+UnitsToTextY(y1+(H div 2)+Round(H/2*11/20))+' '+
  UnitsToTextX(X1)+' '+UnitsToTextY(y1+(H div 2))+
  ' c');

 opfill:='B';
 if PenStyle=5 then
 begin
  opfill:='f';
 end;
 // Bsclear
 if BrushStyle=1 then
  SWriteLine(FFile.FsTempStream,'S')
 else
 // BsSolid
  SWriteLine(FFile.FsTempStream,opfill);
end;

procedure TRpPDFCanvas.Rectangle(x1,y1,x2,y2:Integer);
var
 LineWidth:integer;
 opfill:string;
begin
 if ((PenStyle=5) and (BrushStyle=1)) then
  exit;
 SetDash;
 LineWidth:=1;
 If (PenWidth>0) then
  LineWidth:=PenWidth;
 SWriteLine(FFile.FsTempStream,UnitsToTextX(LineWidth)+' w');
 SWriteLine(FFile.FsTempStream,RGBToFloats(PenColor)+' RG');
 SWriteLine(FFile.FsTempStream,RGBToFloats(BrushColor)+' rg');
 SWriteLine(FFile.FsTempStream,UnitsToTextX(x1)+' '+UnitsToTextY(y1)+
  ' '+UnitsToTextX(x2-x1)+' '+UnitsToTextX(-(y2-y1))+' re');
 opfill:='B';
 if PenStyle=5 then
 begin
  opfill:='f';
 end;
 // Bsclear
 if BrushStyle=1 then
  SWriteLine(FFile.FsTempStream,'S')
 else
 // BsSolid
  SWriteLine(FFile.FsTempStream,opfill);
end;


procedure TRpPDFCanvas.SaveGraph;
begin
 SWriteLine(FFile.FsTempStream,'q');
end;

procedure TRpPDFCanvas.RestoreGraph;
begin
 SWriteLine(FFile.FsTempStream,'Q');
end;

procedure TRpPDFCanvas.TextRect(ARect: TRect; Text: Widestring;
                       Alignment: integer; Clipping: boolean;Wordbreak:boolean;
                       Rotation:integer;RightToLeft:Boolean);
var
 recsize:TRect;
 i,index:integer;
 posx,posY,currpos,alinedif:integer;
 singleline:boolean;
 astring:WideString;
 alinesize:integer;
 lwords:TRpWideStrings;
 lwidths:TStringList;
 arec:TRect;
 aword:WideString;
 oldPenStyle:integer;
begin
 FFile.CheckPrinting;


 if (RightToLeft) then
 begin
  Text:=InfoProvider.NFCNormalize(Text);
 end;

 if (Clipping or (Rotation<>0)) then
 begin
  SaveGraph;
 end;
 try
  if Clipping then
  begin
   // Clipping rectangle
   SWriteLine(FFile.FsTempStream,UnitsToTextX(ARect.Left)+' '+UnitsToTextY(ARect.Top)+
   ' '+UnitsToTextX(ARect.Right-ARect.Left)+' '+UnitsToTextX(-(ARect.Bottom-ARect.Top))+' re');
   SWriteLine(FFile.FsTempStream,'h'); // ClosePath
   SWriteLine(FFile.FsTempStream,'W'); // Clip
   SWriteLine(FFile.FsTempStream,'n'); // NewPath
  end;
  singleline:=(Alignment AND AlignmentFlags_SingleLine)>0;
  if singleline then
   wordbreak:=false;
  // Calculates text extent and apply alignment
  recsize:=ARect;
  LineInfo:=TextExtent(Text,recsize,wordbreak,singleline, rightToLeft);
  FLineInfoCount:=Length(LineInfo);
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

  for i:=0 to FLineInfoCount-1 do
  begin
   posX:=ARect.Left;
   // Aligns horz.
   if  ((Alignment AND AlignmentFlags_AlignRight)>0) then
   begin
    // recsize.right contains the width of the full text
    PosX:=ARect.Right-LineInfo[i].Width;
   end;
   // Aligns horz.
   if (Alignment AND AlignmentFlags_AlignHCenter)>0 then
   begin
    PosX:=ARect.Left+(((Arect.Right-Arect.Left)-LineInfo[i].Width) div 2);
   end;


   astring:=Copy(Text,LineInfo[i].Position,LineInfo[i].Size);
   if  (((Alignment AND AlignmentFlags_AlignHJustify)>0) AND (NOT LineInfo[i].LastLine) AND (NOT RightToLeft)) then
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
       TextExtent(lwords.Strings[index],arec,false,true, RightToLeft);
       if RightToLeft then
        lwidths.Add(IntToStr(-(arec.Right-arec.Left)))
       else
        lwidths.Add(IntToStr(arec.Right-arec.Left));
       alinesize:=alinesize+arec.Right-arec.Left;
      end;
      alinedif:=ARect.Right-ARect.Left-alinesize;
      if alinedif>0 then
      begin
       if lwords.count>1 then
        alinedif:=alinedif div (lwords.count-1);
       if RightToLeft then
       begin
        currpos:=ARect.Right;
        alinedif:=-alinedif;
       end
       else
        currpos:=PosX;
       if ((not Font.Transparent) AND (lwords.Count>0)) then
       begin
        BrushColor:=Font.BackColor;
        BrushStyle:=0;
        oldPenStyle:=PenStyle;
        PenStyle:=5;
        Rectangle(currpos, PosY+LineInfo[i].TopPos, currpos+LineInfo[i].Width,PosY+LineInfo[i].TopPos+LineInfo[i].height);
        PenStyle:=oldPenStyle;
       end;

       for index:=0 to lwords.Count-1 do
       begin
        TextOut(currpos,PosY+LineInfo[i].TopPos,lwords.strings[index],LineInfo[i].Width,Rotation,RightToLeft,LineInfo[i]);
        currpos:=currpos+StrToInt(lwidths.Strings[index])+alinedif;
       end;
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
    if (not Font.Transparent) then
    begin
     BrushColor:=Font.BackColor;
     BrushStyle:=0;
     oldPenStyle:=PenStyle;
     PenStyle:=5;
     Rectangle(PosX, PosY+LineInfo[i].TopPos, PosX+LineInfo[i].Width,PosY+LineInfo[i].TopPos+LineInfo[i].height);
     PenStyle:=oldPenStyle;
    end;

    TextOut(PosX,PosY+LineInfo[i].TopPos,astring,LineInfo[i].Width,Rotation,RightToLeft,LineInfo[i]);
   end
  end;
 finally
  if (Clipping or (Rotation<>0)) then
  begin
   RestoreGraph;
  end;
 end;
end;

function Type1FontTopdfFontName(Type1Font:TRpType1Font;oblique,bold:boolean;WFontName:WideString;FontStyle:integer):String;
var
 avalue:Integer;
 searchname:String;
begin
 if (Type1Font in [poLinked,poEmbedded]) then
 begin
  searchname:=WFontName+IntToStr(FontStyle);
  Result:=searchname;
 end
 else
 begin
  avalue:=0;
  case Type1Font of
  poHelvetica:
   begin
    avalue:=0;
   end;
  poCourier:
   begin
    avalue:=4;
   end;
  poTimesRoman:
   begin
    avalue:=8;
   end;
  poSymbol:
   begin
    avalue:=12;
   end;
  poZapfDingbats:
   begin
    avalue:=13;
   end;
  end;
  if (Type1Font in [poHelvetica..poTimesRoman]) then
  begin
  if bold then
   avalue:=avalue+1;
  if oblique then
   avalue:=avalue+2;
  end;
  Result:=IntToStr(avalue+1);
 end;
end;




procedure TRpPDFCanvas.TextOut(X, Y: Integer; const Text: Widestring;LineWidth,
 Rotation:integer;RightToLeft:Boolean;lInfo: TRpLineInfo);
var
 rotrad,fsize:double;
 rotstring:string;
 PosLine,PosLineX1,PosLineY1,PosLineX2,PosLineY2:integer;
 astring:WideString;
 adata:TRpTTFontData;
 havekerning:boolean;
 leading:integer;
 linespacing:integer;
 stringResult:string;
begin
 /// Add Font leading
 adata:=GetTTFontData;
 if assigned(adata) then
 begin
  leading:=adata.Leading;
 end
 else
 begin
  GetStdLineSpacing(linespacing,leading);
 end;
 leading:=Round((leading/100000)*FResolution*FFont.Size*1.25);
 Y:=Y+leading;



 FFile.CheckPrinting;
 if (Rotation<>0) then
 begin
  SaveGraph;
 end;
 try
  SWriteLine(FFile.FsTempStream,RGBToFloats(Font.Color)+' RG');
  SWriteLine(FFile.FsTempStream,RGBToFloats(Font.Color)+' rg');

  SWriteLine(FFile.FsTempStream,'BT');
  SWriteLine(FFile.FsTempStream,'/F'+
  Type1FontTopdfFontName(Font.Name,Font.Italic,Font.Bold,Font.fontname,Font.Style)+' '+
   IntToStr(Font.Size)+ ' Tf');
  if (RighttoLeft) then
  begin
   SWriteLine(FFile.FsTempStream,'/Span << /ActualText '+
    EncodePdfText(Text) + ' >> BDC');
  end;
  // Rotates
  if Rotation<>0 then
  begin
   rotstring:='1 0 0 1 '+
    UnitsToTextX(X)+' '+
    UnitsToTextText(Y,Font.Size);
   SWriteLine(FFile.FsTempStream,rotstring+' cm');
   rotrad:=Rotation/10*(2*PI/360);
   rotstring:=NumberToText(cos(rotrad))+' '+
    NumberToText(sin(rotrad))+' '+
    NumberToText(-sin(rotrad))+' '+
    NumberToText(cos(rotrad))+' 0 0';
   SWriteLine(FFile.FsTempStream,rotstring+' cm');
  end
  else
  begin
   if (not RightToLeft) then
    SWriteLine(FFile.FsTempStream,UnitsToTextX(X)+' '+UnitsToTextText(Y,Font.Size)+' Td');
  end;
  astring:=Text;

  havekerning:=false;
  if assigned(adata) then
  begin
   if adata.havekerning then
    havekerning:=true;
  end;
  if (RightToLeft) then
  begin
   stringResult:=PDFCompatibleTextShaping(adata,Font,RightToLeft, X,Y,Font.Size,lInfo);
   SWriteLine(FFile.FsTempStream,stringResult);
  end
  else
  begin
   if havekerning then
   begin
    SWriteLine(FFile.FsTempStream,PDFCompatibleTextWidthKerning(astring,adata,Font)+' TJ');
   end
   else
    SWriteLine(FFile.FsTempStream,PDFCompatibleText(astring,adata,Font)+' Tj');
  end;
  if (RightToLeft) then
  begin
   SWriteLine(FFile.FsTempStream,'EMC');
  end;
  SWriteLine(FFile.FsTempStream,' ET');

 finally
  if (Rotation<>0) then
  begin
   RestoreGraph;
  end;
 end;
 // Underline and strikeout
 if FFont.Underline then
 begin
  PenStyle:=0;
  PenWidth:=Round((Font.Size/CONS_PDFRES*FResolution)*CONS_UNDERLINEWIDTH);
  PenColor:=FFont.Color;
  if Rotation=0 then
  begin
   Posline:=Round(CONS_UNDERLINEPOS*(Font.Size/CONS_PDFRES*FResolution));
   Line(X,Y+Posline,X+LineWidth,Y+Posline);
  end
  else
  begin
   Y:=Y+Round(CONS_UNDERLINEPOS*(Font.Size/CONS_PDFRES*FResolution));
   rotrad:=Rotation/10*(2*PI/360);
   fsize:=CONS_UNDERLINEPOS*Font.Size/CONS_PDFRES*FResolution-Font.Size/CONS_PDFRES*FResolution;
   PosLineX1:=-Round(fsize*cos(rotrad));
   PosLineY1:=-Round(fsize*sin(rotrad));
   PosLineX2:=Round(LineWidth*cos(rotrad));
   PoslineY2:=-Round(LineWidth*sin(rotrad));
   Line(X+PosLineX1,Y+PosLineY1,X+PosLineX2,Y+PosLineY2);
   Y:=Y-Round(CONS_UNDERLINEPOS*(Font.Size/CONS_PDFRES*FResolution));
  end;
 end;
 if FFont.StrikeOut then
 begin
  PenStyle:=0;
  PenWidth:=Round((Font.Size/CONS_PDFRES*FResolution)*CONS_UNDERLINEWIDTH);
  PenColor:=FFont.Color;
  if Rotation=0 then
  begin
   Posline:=Round(CONS_STRIKEOUTPOS*(Font.Size/CONS_PDFRES*FResolution));
   Line(X,Y+Posline,X+LineWidth,Y+Posline);
  end
  else
  begin
   Y:=Y+Round(CONS_UNDERLINEPOS*(Font.Size/CONS_PDFRES*FResolution));
   rotrad:=Rotation/10*(2*PI/360);
   fsize:=CONS_UNDERLINEPOS*Font.Size/CONS_PDFRES*FResolution-Font.Size/CONS_PDFRES*FResolution;
   PosLineX1:=-Round(fsize*cos(rotrad));
   PosLineY1:=-Round(fsize*sin(rotrad));
   PosLineX2:=Round(LineWidth*cos(rotrad));
   PoslineY2:=-Round(LineWidth*sin(rotrad));
   fsize:=(1-CONS_STRIKEOUTPOS)*Font.Size/CONS_PDFRES*FResolution;
   PosLineX1:=X+PosLineX1;
   PosLineY1:=Y+PosLineY1;
   PosLineX2:=X+PosLineX2;
   PosLineY2:=Y+PosLineY2;
   PoslineX1:=PosLineX1-Round(fsize*sin(rotrad));
   PoslineY1:=PosLineY1-Round(fsize*cos(rotrad));
   PoslineX2:=PosLineX2-Round(fsize*sin(rotrad));
   PoslineY2:=PosLineY2-Round(fsize*cos(rotrad));
   Line(PoslineX1,PosLineY1,PosLineX2,PosLineY2);
  end;
 end;
end;

procedure TRpPDFCanvas.DrawImage(rec:TRect;abitmap:TStream;dpires:integer;
 tile:boolean;clip:boolean;intimageindex:integer);
var
 astream:TMemoryStream;
 // imagesize,infosize:DWORD;
 imagesize:integer;
 bitmapwidth,bitmapheight:integer;
{$IFDEF USEZLIB}
 FCompressionStream:TCompressionStream;
{$ENDIF}
 fimagestream:TMemoryStream;
 // tmpBitmap:TBitmap;
 // y: integer;
  aheight,awidth:integer;
 // pb: PByteArray;
  arect:TRect;
  isjpeg:Boolean;
  indexed:boolean;
  bitsperpixel,numcolors:integer;
  palette:string;
  imageindex:integer;
  format:string;
  newstream:boolean;
  propx,propy:double;
  W,H:integer;
begin
 arect:=rec;
 FFile.CheckPrinting;
 FImageStream:=TMemoryStream.Create;
 try
  format:='';
  indexed:=false;
  GetJPegInfo(abitmap,bitmapwidth,bitmapheight,format);
  isjpeg:=(format='JPEG');
  if isjpeg then
  begin
   // Read image dimensions
   fimagestream.SetSize(abitmap.size);
   fimagestream.LoadFromStream(abitmap);
   fimagestream.Seek(0,soFromBeginning);
   imagesize:=fimagestream.size;
  end
  else
  begin
   abitmap.Seek(0,soFromBeginning);
   if (format='BMP') then
   begin
    GetBitmapInfo(abitmap,bitmapwidth,bitmapheight,imagesize,FImageStream,indexed,bitsperpixel,numcolors,palette);
   end
   else
   begin

   end;
  end;
  if (dpires = -1) then
  begin
    propx:=(rec.Right-rec.Left)/bitmapwidth;
    propy:=(rec.Bottom-rec.Top)/bitmapheight;
    if (propy>propx) then
    begin
     H:=Round((rec.Bottom-rec.Top)*propx/propy);
     rec.Top:=rec.Top+((rec.Bottom-rec.Top)-H) div 2;
     rec.Bottom:=rec.Top+H;
    end
    else
    begin
     W:=Round((rec.Right-rec.Left)*propy/propx);
     rec.Left:=rec.Left+((rec.Right-rec.Left)-W) div 2;
     rec.Right:=rec.Left+W;
    end;
    arect:=rec;
  end
  else
  if dpires>0 then
  begin
   rec.Right:=rec.Left+Round(bitmapwidth/dpires*FResolution);
   rec.Bottom:=rec.Top+Round(bitmapheight/dpires*FResolution);
  end;
  newstream:=true;
  if intimageindex>=0 then
  begin
   imageindex:=FImageIndexes.IndexOf(IntToStr(intimageindex));
   if imageindex>=0 then
   begin
    imageindex:=integer(FImageIndexes.Objects[imageindex]);
    newstream:=false;
   end
   else
   begin
    FFile.FImageCount:=FFile.FImageCount+1;
    imageindex:=FFile.FImageCount;
    FimageIndexes.AddObject(IntToStr(intimageindex),TObject(imageindex));
   end;
  end
  else
  begin
   FFile.FImageCount:=FFile.FImageCount+1;
   imageindex:=FFile.FImageCount;
  end;
  SWriteLine(FFile.FsTempStream,'q');
  if clip then
  begin
   // Clipping rectangle
   SWriteLine(FFile.FsTempStream,UnitsToTextX(ARect.Left)+' '+UnitsToTextY(ARect.Top)+
   ' '+UnitsToTextX(ARect.Right-ARect.Left)+' '+UnitsToTextX(-(ARect.Bottom-ARect.Top))+' re');
   SWriteLine(FFile.FsTempStream,'h'); // ClosePath
   SWriteLine(FFile.FsTempStream,'W'); // Clip
   SWriteLine(FFile.FsTempStream,'n'); // NewPath
  end;
  awidth:=rec.Right-rec.Left;
  aheight:=rec.Bottom-rec.Top;
  if awidth<=0 then
   tile:=false;
  if aheight<=0 then
   tile:=false;
  repeat
   rec.Left:=ARect.Left;
   rec.Right:=ARect.Left+awidth;
   repeat
    SWriteLine(FFile.FsTempStream,'q');
    // Translate
    SWriteLine(FFile.FsTempStream,'1 0 0 1 '
     +UnitsToTextX(rec.Left)+
     ' '+UnitsToTextY(rec.Bottom)+' cm');
    // Scale
    SWriteLine(FFile.FsTempStream,UnitsToTextX(rec.Right-rec.Left)+
     ' 0 0  '+UnitsToTextX(rec.Bottom-rec.Top)+' 0 0 cm');
    SWriteLine(FFile.FsTempStream,'/Im'+IntToStr(imageindex)+' Do');
    SWriteLine(FFile.FsTempStream,'Q');
    if not tile then
     break;
    rec.Left:=rec.Left+awidth;
    rec.Right:=rec.Left+awidth;
    if (Rec.Right>ARect.Right+awidth) then
     break;
   until false;
   if not tile then
    break;
   rec.Top:=rec.Top+aheight;
   rec.Bottom:=rec.Top+aheight;
   if (Rec.Bottom>ARect.Bottom+aheight) then
    break;
  until false;
  SWriteLine(FFile.FsTempStream,'Q');
  // Saves the bitmap to temp bitmaps
  if newstream then
  begin
   astream:=TMemoryStream.Create;
   FFile.FBitmapStreams.Add(astream);
   SWriteLine(astream,'<< /Type /XObject');
   SWriteLine(astream,'/Subtype /Image');
   SWriteLine(astream,'/Width '+IntToStr(bitmapwidth));
   SWriteLine(astream,'/Height '+IntToStr(bitmapheight));
   if indexed then
   begin
    SWriteLine(astream,'/ColorSpace');
    SWriteLine(astream,'[/Indexed');
    SWriteLine(astream,'/DeviceRGB '+IntToStr(numcolors));
    SWriteLine(astream,palette);
    SWriteLine(astream,']');
    SWriteLine(astream,'/BitsPerComponent '+IntToStr(bitsperpixel))
   end
   else
   begin
    SWriteLine(astream,'/ColorSpace /DeviceRGB');
    SWriteLine(astream,'/BitsPerComponent 8');
   end;
   SWriteLine(astream,'/Length '+IntToStr(imagesize));
   SWriteLine(astream,'/Name /Im'+IntToStr(imageindex));
   if isjpeg then
   begin
    SWriteLine(astream,'/Filter [/DCTDecode]');
   end
   else
   begin
 {$IFDEF USEZLIB}
    if FFile.FCompressed then
     SWriteLine(astream,'/Filter [/FlateDecode]');
 {$ENDIF}
   end;
   SWriteLine(astream,'>>');
   SWriteLine(astream,'stream');
   FImageStream.Seek(0,soFrombeginning);
 {$IFDEF USEZLIB}
   if ((FFile.FCompressed) and (not isjpeg)) then
   begin
    FCompressionStream := TCompressionStream.Create(clDefault,astream);
    try
     FImageStream.Seek(0, soBeginning);
     CopyStreamContent(FImageStream, FCompressionStream);
     // FCompressionStream.CopyFrom(FImageStream, FImageStream.Size);
    finally
     FCompressionStream.Free;
    end;
   end
   else
 {$ENDIF}
    FImageStream.SaveToStream(astream);
  end;
 finally
  FImageStream.Free;
 end;
end;



{$IFDEF DOTNETD}
function TRpPDFCanvas.CalcCharWidth(charcode:Widechar;fontdata:TRpTTFontData):double;
var
 intvalue:Byte;
 defaultwidth:integer;
 aarray:TWinAnsiWidthsArray;
 isdefault:boolean;
begin
 defaultwidth:=Default_Font_Width;
 isdefault:=true;
 if charcode in [#0,#13,#10] then
 begin
  Result:=0;
  exit;
 end;
 if (FFont.Name in [poLinked,poEmbedded]) then
 begin
  // Ask for font size
  Result:=InfoProvider.GetCharWidth(Font,fontdata,charcode);
  Result:=Result*FFont.Size/1000;
  exit;
 end
 else
 if (FFont.Name=poHelvetica) then
 begin
  isdefault:=false;
  if FFont.Bold then
  begin
   if FFont.Italic then
    aarray:=Helvetica_BoldItalic_Widths
   else
    aarray:=Helvetica_Bold_Widths;
  end
  else
   if FFont.Italic then
    aarray:=Helvetica_Italic_Widths
   else
    aarray:=Helvetica_Widths;
 end
 else
 if (FFont.Name=poTimesRoman) then
 begin
  isdefault:=false;
  if FFont.Bold then
  begin
   if FFont.Italic then
    aarray:=TimesRoman_BoldItalic_Widths
   else
    aarray:=TimesRoman_Bold_Widths;
  end
  else
   if FFont.Italic then
    aarray:=TimesRoman_Italic_Widths
   else
    aarray:=TimesRoman_Widths;
 end;
 intvalue:=Byte(charcode);
 if (isdefault or (intvalue<32)) then
  Result:=defaultwidth
 else
  Result:=aarray[intvalue];
 Result:=Result*FFont.Size/1000;
end;
{$ENDIF}


{$IFNDEF DOTNETD}
function TRpPDFCanvas.CalcCharWidth(charcode:Widechar;fontdata:TRpTTFontData):double;
var
 intvalue:Byte;
 defaultwidth:integer;
 aarray:PWinAnsiWidthsArray;
 isdefault:boolean;
begin
  aarray:=nil;
  defaultwidth:=Default_Font_Width;
  isdefault:=true;
  if charcode in [WideChar(#0),WideChar(#13),WideChar(#10)] then
  begin
   Result:=0;
   exit;
  end;
  if (FFont.Name in [poLinked,poEmbedded]) then
  begin
   // Ask for font size
   Result:=InfoProvider.GetCharWidth(Font,fontdata,charcode);
   Result:=Result*FFont.Size/1000;
   exit;
  end
  else
  if (FFont.Name=poHelvetica) then
  begin
   aarray:=@Helvetica_Widths;
   isdefault:=false;
   if FFont.Bold then
   begin
    if FFont.Italic then
     aarray:=@Helvetica_BoldItalic_Widths
    else
     aarray:=@Helvetica_Bold_Widths
   end
   else
    if FFont.Italic then
     aarray:=@Helvetica_Italic_Widths;
  end
  else
  if (FFont.Name=poTimesRoman) then
  begin
   aarray:=@TimesRoman_Widths;
   isdefault:=false;
   if FFont.Bold then
   begin
    if FFont.Italic then
     aarray:=@TimesRoman_BoldItalic_Widths
    else
     aarray:=@TimesRoman_Bold_Widths
   end
   else
    if FFont.Italic then
     aarray:=@TimesRoman_Italic_Widths;
  end;
  intvalue:=Byte(charcode);
  if (isdefault or (intvalue<32)) then
   Result:=defaultwidth
  else
   Result:=aarray^[intvalue];
  Result:=Result*FFont.Size/1000;
end;
{$ENDIF}

procedure TRpPDFCanvas.GetStdLineSpacing(var linespacing,leading:integer);
begin
 case FFont.Name of
  poHelvetica:
   begin
    linespacing:=1270;
    leading:=150;
   end;
  poCourier:
   begin
    linespacing:=1265;
    leading:=133;
   end;
  poTimesRoman:
   begin
    linespacing:=1257;
    leading:=150;
   end;
  poSymbol:
   begin
    linespacing:=1450;
    leading:=255;
   end;
  poZapfDingbats:
   begin
    linespacing:=1200;
   end;
   else
   begin
    linespacing:=1270;
    leading:=200;
   end;
 end;

end;


function TRpPDFCanvas.TextExtent(const Text:WideString;var Rect:TRect;
 wordbreak:boolean;singleline:boolean;rightToLeft: boolean): TRpLineInfoArray;
begin
 if (rightToLeft) then
 begin
  LineInfo:=InfoProvider.TextExtent(Text,rect,Self.GetTTFontData,Font,wordbreak,singleline,Font.Size);
  FLineInfoCount:=Length(LineInfo);
 end
 else
 begin
  LineInfo:=TextExtentSimple(Text,Rect,wordbreak,singleline);
 end;
 Result:=LineInfo;
end;


function TRpPDFCanvas.TextExtentSimple(const Text:WideString;var Rect:TRect;
 wordbreak:boolean;singleline:boolean): TRpLineInfoArray;
var
 astring:widestring;
 i:integer;
 asize:double;
 arec:TRect;
 position:integer;
 info:TRpLineInfo;
 maxwidth:double;
 newsize:double;
 recwidth:double;
 linebreakpos:integer;
 nextline:boolean;
 alastsize:double;
 lockspace:boolean;
 createsnewline:boolean;
 havekerning:boolean;
 adata:TRpTTFontData;
 kerningamount:integer;
 linespacing:integer;
 leading:integer;
 offset:integer;
 incomplete:boolean;
 charsProcessed: integer;
begin
 havekerning:=false;
 adata:=GetTTFontData;
 if assigned(adata) then
 begin
  if adata.havekerning then
   havekerning:=true;
  linespacing:=adata.Ascent-adata.Descent+adata.Leading;
  leading:=adata.Leading;
 end
 else
 begin
  GetStdLineSpacing(linespacing,leading);
 end;
 leading:=Round((leading/100000)*FResolution*FFont.Size*1.25);
 linespacing:=Round(((linespacing)/100000)*FResolution*FFont.Size*1.25);
// leading:=Round((leading/10000)*FResolution);
// linespacing:=Round((linespacing/10000)*FResolution);

 createsnewline:=false;
 astring:=Text;
 arec:=Rect;
 arec.Left:=0;
 arec.Top:=0;
 arec.Bottom:=0;
 asize:=0;
 FLineInfoCount:=0;
 position:=1;
 offset:=0;
 linebreakpos:=0;
 maxwidth:=0;
 recwidth:=(rect.Right-rect.Left)/FResolution*CONS_PDFRES;
 nextline:=false;
 i:=1;
 alastsize:=0;
 lockspace:=false;
 charsprocessed := 0;
 while i<=Length(astring) do
 begin
  incomplete:=false;
  newsize:=CalcCharWidth(astring[i],adata);
  if havekerning then
  begin
   if i<Length(astring) then
   begin
    kerningamount:=infoprovider.GetKerning(Font,adata,astring[i],astring[i+1]);
    newsize:=newsize-(kerningamount*FFont.Size/1000);
   end;
  end;
  if (Not (astring[i] in [WideChar(' '),WideChar(#10),WideChar(#13)])) then
   lockspace:=false;
  if wordbreak then
  begin
   if asize+newsize>recwidth then
   begin
    if linebreakpos>0 then
    begin
     i:=linebreakpos;
     nextline:=true;
     asize:=alastsize;
     linebreakpos:=0;
    end
    else
    begin
     nextline := true;
     if length(astring)>1 then
     begin
     incomplete:=true;
     end;
     linebreakpos := 0;
    end;
   end
   else
   begin
    if astring[i] in [WideChar('-'),WideChar(' ')] then
    begin
     linebreakpos:=i;
     if astring[i]=' ' then
     begin
      if not lockspace then
      begin
       alastsize:=asize;
       lockspace:=true;
      end;
      asize:=asize+newsize;
     end
     else
     begin
      asize:=asize+newsize;
      alastsize:=asize;
     end;
    end
    else
     asize:=asize+newsize;
   end;
  end
  else
  begin
   asize:=asize+newsize;
  end;
  if not singleline then
  begin
   if (astring[i]=#10) then
   begin
    if (i>1) then
     if (astring[i-1]=#13) then
      offset:=1
     else
      offset:=0;
    nextline:=true;
    createsnewline:=true;
   end
   else
   if (astring[i]=#13) then
   begin
    if (i<Length(astring)) then
    begin
     if (astring[i+1]=#10) then
     begin
      offset:=1;
      Inc(i);
      nextline:=true;
      createsnewline:=true;
     end;
    end;
   end
  end;
  if asize>maxwidth then
   maxwidth:=asize;
  if nextline then
  begin
   nextline:=false;
   info.Position:=position;
   info.Size:=i-position-offset;
   info.Width:=Round((asize)/CONS_PDFRES*FResolution);
//   info.height:=Round((Font.Size)/CONS_PDFRES*FResolution);
   info.height:=linespacing;
   info.TopPos:=arec.Bottom-leading;
   info.lastline:=createsnewline;
   arec.Bottom:=arec.Bottom+info.height;
   asize:=0;
   offset:=0;
   if (incomplete) then
    i:=i-1;
   position:=i+1;
   NewLineInfo(info);
   createsnewline:=false;
   // Skip only one blank char
   if (incomplete) then
     if i<Length(astring) then
      if astring[i+1]=WideChar(' ') then
      begin
      inc(i);
      position:=i+1;
      end;
  end;
  inc(i);
 end;
 arec.Right:=Round((maxwidth+1)/CONS_PDFRES*FResolution);
 if Position<=Length(astring) then
 begin
  info.Position:=position;
  info.Size:=Length(astring)-position+1-offset;
  info.Width:=Round((asize+1)/CONS_PDFRES*FResolution);
  info.height:=linespacing;
  info.TopPos:=arec.Bottom-leading;
  arec.Bottom:=arec.Bottom+info.height;
  info.lastline:=true;
  NewLineInfo(info);
 end;
 if (charsprocessed>0) then
   arec.Bottom:=arec.Bottom+leading;
 rect:=arec;
 Result:=LineInfo;
end;

procedure TRpPDFCanvas.NewLineInfo(info:TRpLineInfo);
begin
 if FLineInfoMaxItems<FLineInfoCount+1 then
 begin
  SetLength(LineInfo,FLineInfoMaxItems*2);
  FLineInfoMaxItems:=FLineInfoMaxItems*2;
 end;
 LineInfo[FLineInfoCount]:=info;
 inc(FLineInfoCount);
end;

const
  BI_RGB = 0;
  BI_RLE8 = 1;
  BI_RLE4 = 2;
  BI_BITFIELDS = 3;

  MAX_BITMAPHEADERSIZE=32000;



type
 TBitmapInfoHeader = packed record
   biSize: DWORD;
   biWidth: Longint;
   biHeight: Longint;
   biPlanes: Word;
   biBitCount: Word;
   biCompression: DWORD;
   biSizeImage: DWORD;
   biXPelsPerMeter: Longint;
   biYPelsPerMeter: Longint;
   biClrUsed: DWORD;
   biClrImportant: DWORD;
 end;
 PBitmapInfoHeader = ^TBitmapInfoHeader;


 TBitmapFileHeader = packed record
  bfType: Word;
  bfSize: DWORD;
  bfReserved1: Word;
  bfReserved2: Word;
  bfOffBits: DWORD;
 end;
 PBitmapFileHeader = ^TBitmapFileHeader;

 TRGBTriple = packed record
  rgbtBlue: Byte;
  rgbtGreen: Byte;
  rgbtRed: Byte;
 end;
 PRGBTriple = ^TRGBTriple;
 TRGBQuad = packed record
  rgbBlue: Byte;
  rgbGreen: Byte;
  rgbRed: Byte;
  rgbReserved: Byte;
 end;
 PRGBQuad = ^TRGBQuad;

 TBitmapCoreHeader = packed record
    bcSize: DWORD;
    bcWidth: Word;
    bcHeight: Word;
    bcPlanes: Word;
    bcBitCount: Word;
  end;
 PBitmapCoreHeader = ^TBitmapCoreHeader;



{$IFDEF DOTNETD}
procedure GetBitmapInfo(stream:TStream;var width,height,imagesize:integer;FMemBits:TMemoryStream;;var mono:boolean);
var
 fileheader:TBitmapFileHeader;
 bitmapinfo:TBitmapInfoHeader;
 coreheader:TBitmapCoreHeader;
 bsize:DWORD;
 readed:longint;
 numcolors:integer;
 bitcount:integer;
 iscoreheader:boolean;
 qcolors:array of TRGBQuad;
 tcolors:array of TRGBTriple;
 values:array of TRGBTriple;
 qvalues:array of TRGBQuad;
 indexvalues:array of Byte;
 acolors:array of Byte;
 avalues:array of Byte;
// orgvalues:array of TRGBQuad;
procedure GetDIBBitsNet;
var
 bitmap:TBitmap;
 bits:TBytes;
 bitmapinfoptr,abits:Intptr;
 abitmapinfo:tagBitmapinfo;
begin
 bitmap:=TBitmap.Create;
 try
  bitmap.HandleType:=bmDIB;
  bitmap.PixelFormat:=pf32bit;
//  bitmapinfoptr:=nil;
  bitmapinfoptr:=Marshal.AllocHGlobal(sizeof(BitmapInfo));
  Marshal.StructureToPtr(BitmapInfo,BitmapinfoPtr,true);
  stream.Seek(0,soFromBeginning);
  bitmap.LoadFromStream(stream);
  SetLength(bits,bitmap.width*bitmap.Height*3);
//  if not GetDIB(bitmap.Handle,bitmap.Palette,bitmapinfoptr,bits) then
//   RaiseLastOsError;
  abitmapinfo.bmiHeader.biSize:=sizeof(abitmapinfo.bmiHeader);
  abitmapinfo.bmiheader.biWidth:=bitmapinfo.biWidth;
  abitmapinfo.bmiheader.biHeight:=bitmapinfo.biHeight;
  abitmapinfo.bmiheader.biPlanes:=bitmapinfo.biPlanes;
  abitmapinfo.bmiheader.biBitCount:=bitmapinfo.biBitCount;
  abitmapinfo.bmiHeader.biCompression:=bitmapinfo.biCompression;
  abitmapinfo.bmiHeader.biSizeImage:=bitmapinfo.biSizeImage;
  abitmapinfo.bmiHeader.biXPelsPerMeter:=bitmapinfo.biXPelsPerMeter;
  abitmapinfo.bmiHeader.biYPelsPerMeter:=bitmapinfo.biYPelsPerMeter;
  abitmapinfo.bmiHeader.biClrUsed:=bitmapinfo.biClrUsed;
  abitmapinfo.bmiHeader.biClrImportant:=bitmapinfo.biClrImportant;


  if GetDIBits(CreateCompatibleDC(0),bitmap.handle,0,bitmap.height,abits,abitmapinfo,DIB_RGB_COLORS)=0 then
   RaiseLastOsError;
  FMemBits.Write(bits,Length(bits));
 finally
  bitmap.Free;
 end;
end;

function bytestofileheader(const abytes:TBytes):TBitmapFileHeader;
begin
 Result.bfType := System.BitConverter.ToUInt16(ABytes, 0);
 Result.bfSize := System.BitConverter.ToUInt32(ABytes, sizeof(Result.bfType));
 Result.bfReserved1 := System.BitConverter.ToUInt16(ABytes,
  sizeof(Result.bfType)+sizeof(Result.bfSize));
 Result.bfReserved2 := System.BitConverter.ToUInt16(ABytes,
  sizeof(Result.bfType)+sizeof(Result.bfSize)+sizeof(Result.bfReserved1));
 Result.bfOffBits := System.BitConverter.ToUInt16(ABytes,
  sizeof(Result.bfType)+sizeof(Result.bfSize)+sizeof(Result.bfReserved1)+
  sizeof(Result.bfReserved2));
end;


function bytestocoreheader(const abytes:TBytes):TBitmapCoreheader;
begin
 Result.bcSize := System.BitConverter.ToUInt32(ABytes, 0);
 Result.bcWidth := System.BitConverter.ToUInt16(ABytes, sizeof(Result.bcSize));
 Result.bcHeight:= System.BitConverter.ToUInt16(ABytes,
  sizeof(Result.bcSize)+sizeof(Result.bcWidth));
 Result.bcPlanes:=System.BitConverter.ToUInt16(ABytes,
  sizeof(Result.bcSize)+sizeof(Result.bcWidth)+sizeof(Result.bcHeight));
 Result.bcBitCount:=System.BitConverter.ToUInt16(ABytes,
  sizeof(Result.bcSize)+sizeof(Result.bcWidth)+sizeof(Result.bcHeight)+
   sizeof(Result.bcPlanes));
end;

function bytestobitmapinfo(const abytes:TBytes):TBitmapInfoHeader;
var
 currindex:integer;
begin
 currindex:=0;
 Result.biSize:=System.BitConverter.ToUInt32(ABytes, 0);
 currindex:=sizeof(Result.biSize);
 Result.biWidth:=System.BitConverter.ToUInt32(ABytes, currindex);
 currindex:=currindex+sizeof(Result.biWidth);
 Result.biHeight:=System.BitConverter.ToUInt32(ABytes, currindex);
 currindex:=currindex+sizeof(Result.biHeight);
 Result.biPlanes:=System.BitConverter.ToUInt16(ABytes, currindex);
 currindex:=currindex+sizeof(Result.biPlanes);
 Result.biBitCount:=System.BitConverter.ToUInt16(ABytes, currindex);
 currindex:=currindex+sizeof(Result.biBitCount);
 Result.biCompression:=System.BitConverter.ToUInt32(ABytes, currindex);
 currindex:=currindex+sizeof(Result.biCompression);
 Result.biSizeImage:=System.BitConverter.ToUInt32(ABytes, currindex);
 currindex:=currindex+sizeof(Result.biSizeImage);
 Result.biXPelsPerMeter:=System.BitConverter.ToUInt32(ABytes, currindex);
 currindex:=currindex+sizeof(Result.biXPelsPerMeter);
 Result.biYPelsPerMeter:=System.BitConverter.ToUInt32(ABytes, currindex);
 currindex:=currindex+sizeof(Result.biYPelsPerMeter);
 Result.biClrUsed:=System.BitConverter.ToUInt32(ABytes, currindex);
 currindex:=currindex+sizeof(Result.biClrUsed);
 Result.biClrImportant:=System.BitConverter.ToUInt32(ABytes, currindex);
end;


begin
 SetLength(avalues,sizeof(fileheader));
 readed:=stream.Read(avalues,sizeof(fileheader));
 if readed<>sizeof(fileheader) then
  Raise Exception.Create(SRpBadBitmapFileHeader);
 fileheader:=bytestofileheader(avalues);
 // The header must contain 'BM'
 if fileheader.bfType<>19778 then
  Raise Exception.Create(SRpBadBitmapFileHeader);

 // read de size of bitmapinfo
 readed:=stream.Read(bsize,sizeof(bsize));
 if readed<>sizeof(bsize) then
  Raise Exception.Create(SRpBadBitmapFileHeader);
 if ((bsize<2) or (bsize>MAX_BITMAPHEADERSIZE)) then
  Raise Exception.Create(SRpInvalidBitmapHeaderSize);
 iscoreheader:=false;
 if bsize<15 then
  iscoreheader:=true;
 readed:=stream.Seek(sizeof(fileheader),soFromBeginning);
 // Allocates memory
 if iscoreheader then
 begin
  SetLength(avalues,bsize);
  // Reads the pbitmapinfo
  readed:=stream.Read(avalues,bsize);
  if DWORD(readed)<>bsize then
   Raise Exception.Create(SRpBadBitmapStream);
  coreheader:=bytestocoreheader(avalues);
  width:=coreheader.bcWidth;
  height:=coreheader.bcheight;
  imagesize:=width*height*3;
  bitcount:=coreheader.bcBitCount;
  if Assigned(FMemBits) then
   GetDIBBitsNet;
 end
 else
 begin
  SetLength(avalues,bsize);
  // Reads the pbitmapinfo
  readed:=stream.Read(avalues,bsize);
  if DWORD(readed)<>bsize then
   Raise Exception.Create(SRpBadBitmapStream);
  bitmapinfo:=bytestobitmapinfo(avalues);

  width:=bitmapinfo.biWidth;
  height:=bitmapinfo.biheight;
  bitcount:=bitmapinfo.biBitCount;
   // Check support for BI_RGB
   if (Not (bitmapinfo.biCompression in [BI_BITFIELDS,BI_RGB])) then
   begin
    // this are BI_RLE4 or BI_RLE8
    Raise Exception.Create(SRpRLECompBitmapPDF);
   end
   else
   begin
    imagesize:=width*height*3;
    if (bitcount=1) then
     Raise Exception.Create(SRpMonochromeBitmapPDF);
    if Assigned(FMemBits) then
     GetDIBBitsNet;
   end;
 end;
end;
{$ENDIF}

{$IFNDEF DOTNETD}
procedure GetBitmapInfo(stream:TStream;var width,height,imagesize:integer;FMemBits:TMemoryStream;
  var indexed:boolean;var bitsperpixel,usedcolors:integer;var palette:string);
var
 fileheader:TBitmapFileHeader;
 pbitmapinfo:PBitmapInfoHeader;
 pcoreheader:PBitmapCoreHeader;
 bsize:DWORD;
 readed:longint;
 numcolors:integer;
 bitcount:integer;
 coreheader:boolean;
 qcolors:array of TRGBQuad;
 tcolors:array of TRGBTriple;
 values:array of TRGBTriple;
 qvalues:array of TRGBQuad;
// orgvalues:array of TRGBQuad;
 module:integer;
procedure GetDIBBits;
var
 y,scanwidth:integer;
// dc:HDC;
 toread:integer;
 buffer:array of Byte;
 divider:byte;
 origwidth:integer;
 acolor:integer;
 bufdest:array of Byte;
 linewidth:integer;
 bcolor,rcolor,gcolor:Byte;
 num,num2:Word;
 h:integer;

{
 position:integer;
 index:Byte;
 pixvalue:byte;
 HDC:integer;
 aqcolor:TRGBQuad;
 desp:byte;
 atcolor:TRGBTriple;
 abyte,amask:byte;
 abyteindex:integer;
}
begin
 palette:='';
 if numcolors>0 then
 begin
  if coreheader then
  begin
   SetLength(tcolors,numcolors);
   readed:=stream.Read(tcolors[0],sizeof(TRGBTriple)*numcolors);
   if readed<>sizeof(TRGBTriple)*numcolors then
    Raise Exception.Create(SRpInvalidBitmapPalette);
   palette:='';
   for y:=0 to numcolors-1 do
   begin
    acolor:=(tcolors[y].rgbtRed shl 16)+(tcolors[y].rgbtGreen shl 8)+tcolors[y].rgbtBlue;
    if length(palette)=0 then
     palette:='<'+Format('%6.6x',[acolor])
    else
     palette:=palette+' '+Format('%6.6x',[acolor]);
   end;
   palette:=palette+'>';
  end
  else
  begin
   SetLength(qcolors,usedcolors);
   readed:=stream.Read(qcolors[0],sizeof(TRGBQuad)*usedcolors);
   if readed<>sizeof(TRGBQuad)*usedcolors then
    Raise Exception.Create(SRpInvalidBitmapPalette);
   palette:='';
   for y:=0 to usedcolors-1 do
   begin
    acolor:=(qcolors[y].rgbRed shl 16)+(qcolors[y].rgbGreen shl 8)+qcolors[y].rgbBlue;
    if length(palette)=0 then
     palette:='<'+Format('%6.6x',[acolor])
    else
     palette:=palette+' '+Format('%6.6x',[acolor]);
   end;
   palette:=palette+'>';
  end;
 end;
 // Go to position bits
 stream.Seek({sizeof(fileheader)+}fileheader.bfOffBits,soFromBeginning);
 if numcolors=0 then
 begin
  // read the values
  FMemBits.Clear;
  FMemBits.SetSize(Int64(imagesize));
  if bitcount=32 then
  begin
   SetLength(qvalues,imagesize);
   scanwidth:=width*4;
   toread:=0;
   module:=4;
  end
  else
  begin
   if bitcount=24 then
   begin
    SetLength(values,imagesize);
    scanwidth:=width*3;
    // Alignment to 32bit
    // Align to 32bit
    toread:=4-(scanwidth mod 4);
    if toread=4 then
     toread:=0;
    module:=3;
   end
   else
   begin
    SetLength(values,imagesize);
    scanwidth:=width*2;
    // Alignment to 32bit
    // Align to 32bit
    toread:=4-(scanwidth mod 4);
    if toread=4 then
     toread:=0;
    module:=2;
   end;
  end;
  scanwidth:=scanwidth+toread;
(*  if (bitcount>16) then
  begin
   for y:=height-1 downto 0 do
   begin
    if bitcount=32 then
    begin
     readed:=stream.Read(qvalues[y*width],scanwidth);
     if readed<>scanwidth then
      Raise Exception.Create(SRpBadBitmapStream);
    end
    else
    begin
     readed:=stream.Read(values[y*width],scanwidth);
     if readed<>scanwidth then
      Raise Exception.Create(SRpBadBitmapStream);
    end;
   end;
   for y:=0 to height-1 do
   begin
    for x:=0 to width-1 do
    begin
     if bitcount=32 then
     begin
      FMemBits.Write(qvalues[y*width+x].rgbRed,1);
      FMemBits.Write(qvalues[y*width+x].rgbGreen,1);
      FMemBits.Write(qvalues[y*width+x].rgbBlue,1);
     end
     else
     begin
      FMemBits.Write(values[y*width+x].rgbtRed,1);
      FMemBits.Write(values[y*width+x].rgbtGreen,1);
      FMemBits.Write(values[y*width+x].rgbtBlue,1);
     end;
    end;
   end;
  end
  else*)
  begin
   FMemBits.SetSize(Int64(width*height*3));
   linewidth:=width*3;
   SetLength(buffer,scanwidth);
	 SetLength(bufdest,linewidth);
	 for y := height - 1 downto 0 do
   begin
		readed := stream.Read(buffer[0],scanwidth);
    if readed<>scanwidth then
     Raise Exception.Create(SRpBadBitmapStream);
    FMemBits.Seek((width * 3) * y, soFromBeginning);
    if (bitcount>16) then
    begin
     for h:=0 to  width-1 do
     begin
			bufdest[h * 3] := buffer[module * h + 2];
			bufdest[h * 3 + 1] := buffer[module * h + 1];
			bufdest[h * 3 + 2] := buffer[module * h];
     end;
    end
    else
		if (bitsperpixel=15) then
		begin
		 // 5-5-5
		 for  h := 0 to width-1 do
     begin
			num:=Word(buffer[2*h]);
 		  num2:=Word(Word(buffer[2*h+1]) shl 8);
			num:=Word(num or num2);
			rcolor:=byte(num and $1F);
      gcolor := byte((num and $3FF) shr 5);
      bcolor := byte((num and $7FFF) shr 10);
			rcolor:=byte(Round(rcolor/31.0*255));
			gcolor:=byte(Round(gcolor/31.0*255));
			bcolor:=byte(Round(bcolor/31.0*255));
			bufdest[h * 3] := bcolor;
			bufdest[h * 3 + 1] :=  gcolor;
			bufdest[h * 3 + 2] := rcolor;
		 end
    end
    else
 	  begin
		 for  h := 0 to width-1 do
     begin
     	// 5-6-5
			num:=Word(buffer[2*h]);
 		  num2:=Word(Word(buffer[2*h+1]) shl 8);
			num:=Word(num or num2);
			rcolor:=byte(num and $1F);
      gcolor := byte((num and $7FF) shr 5);
      bcolor := byte((num) shr 11);
			rcolor:=byte(Round(rcolor/31.0*255));
			gcolor:=byte(Round(gcolor/63.0*255));
			bcolor:=byte(Round(bcolor/31.0*255));
			bufdest[h * 3] := bcolor;
			bufdest[h * 3 + 1] :=  gcolor;
			bufdest[h * 3 + 2] := rcolor;
     end;
    end;
 		FMemBits.Write(bufdest[0],linewidth);
   end;
  end;
  FMemBits.Seek(0, soFromBeginning);
  exit;
 end;
 case numcolors of
  2:
   divider:=8;
  16:
   divider:=2;
  256:
   divider:=1;
  else
   divider:=1;
 end;
 scanwidth:=width div divider;
 bitsperpixel:=bitcount;
 indexed:=true;
 if (width mod divider)>0 then
  scanwidth:=scanwidth+1;
 // bitmap file format is aligned on double word
 // the alignment must be removed from datafile
 origwidth:=scanwidth;
 while (scanwidth mod 4)>0 do
  scanwidth:=scanwidth+1;
 SetLength(buffer,scanwidth);
 FMemBits.Clear;
 FMemBits.SetSize(Int64(height*origwidth));
{ if numcolors=2 then
 begin
  amask:=$80;
  desp:=1;
 end
 else
 if numcolors=16 then
 begin
  amask:=$F0;
  desp:=4;
 end
 else
 begin
  amask:=$FF;
  desp:=0;
 end;
 hdc:=GetDC(0);
} for y:=height-1 downto 0 do
 begin
  stream.read(buffer[0],scanwidth);
  FMemBits.Seek(y*origwidth,soFromBeginning);
  FMemBits.Write(buffer[0],origwidth);
{  for x:=0 to width-1 do
  begin
   abyteindex:=(x div divider);
   abyte:=buffer[abyteindex] shl ((x mod divider)*desp);
   abyte:=abyte and amask;
   pixvalue:=abyte shr desp;
   if coreheader then
   begin
    atcolor:=tcolors[pixvalue];
    SetPixel(hdc,x,y,atcolor.rgbtBlue shl 16+atcolor.rgbtGreen shl 8+atcolor.rgbtRed);
   end
   else
   begin
    aqcolor:=qcolors[pixvalue];
    SetPixel(hdc,x,y,aqcolor.rgbBlue shl 16+aqcolor.rgbGreen shl 8+aqcolor.rgbRed);
   end;
  end;
}
 end;
 FMemBits.Seek(0,soFromBeginning);
 imagesize:=FMemBits.Size;
end;

begin
 indexed:=false;
 bitsperpixel:=8;
 usedcolors:=0;
 readed:=stream.Read(fileheader,sizeof(fileheader));
 if readed<>sizeof(fileheader) then
  Raise Exception.Create(SRpBadBitmapFileHeader);
 // The header must contain 'BM'
 if fileheader.bfType<>19778 then
  Raise Exception.Create(SRpBadBitmapFileHeader);

 // read de size of bitmapinfo
 readed:=stream.Read(bsize,sizeof(bsize));
 if readed<>sizeof(bsize) then
  Raise Exception.Create(SRpBadBitmapFileHeader);
 if ((bsize<2) or (bsize>MAX_BITMAPHEADERSIZE)) then
  Raise Exception.Create(SRpInvalidBitmapHeaderSize);
 coreheader:=false;
 if bsize<15 then
  coreheader:=true;
 readed:=stream.Seek(sizeof(fileheader),soFromBeginning);
 // Allocates memory
 if coreheader then
 begin
  pcoreheader:=AllocMem(bsize);
  try
   FillChar(pcoreheader^,bsize,0);
   // Reads the pbitmapinfo
   readed:=stream.Read(pcoreheader^,bsize);
   if DWORD(readed)<>bsize then
    Raise Exception.Create(SRpBadBitmapStream);
   width:=pcoreheader^.bcWidth;
   height:=pcoreheader^.bcheight;
   imagesize:=width*height*3;
   bitcount:=pcoreheader.bcBitCount;
   // Read color entries
   case bitcount of
    1:
     numcolors:=2;
    4:
     numcolors:=16;
    8:
     numcolors:=256;
    24:
     numcolors:=0;
    32:
     numcolors:=0;
    else
     Raise Exception.Create(SRpBitMapInfoHeaderBitCount+
      IntToStr(pcoreheader^.bcBitCount));
   end;
   if bitcount<24 then
    usedcolors:=numcolors;
   if Assigned(FMemBits) then
    GetDIBBits;
  finally
   FreeMem(pcoreheader);
  end;
 end
 else
 begin
  pbitmapinfo:=AllocMem(bsize);
  try
   FillChar(pbitmapinfo^,bsize,0);
   // Reads the pbitmapinfo
   readed:=stream.Read(pbitmapinfo^,bsize);
   if DWORD(readed)<>bsize then
    Raise Exception.Create(SRpBadBitmapStream);
   width:=pbitmapinfo^.biWidth;
   height:=pbitmapinfo^.biheight;
   bitcount:=pbitmapinfo^.biBitCount;
   // Check support for BI_RGB
   if (Not (pbitmapinfo^.biCompression in [BI_BITFIELDS,BI_RGB])) then
   begin
    // this are BI_RLE4 or BI_RLE8
    Raise Exception.Create(SRpRLECompBitmapPDF);
   end
   else
   begin
    imagesize:=width*height*3;
    // Read color entries
    case bitcount of
     1:
      numcolors:=2;
     4:
      numcolors:=16;
     8:
      numcolors:=256;
     24,16,15:
      numcolors:=0;
     32:
      numcolors:=0;
     else
      Raise Exception.Create(SRpBitMapInfoHeaderBitCount+
       IntToStr(pbitmapinfo^.biBitCount));
    end;
    if bitcount<15 then
    begin
     usedcolors:=pbitmapinfo^.biClrUsed;
     if usedcolors=0 then
      usedcolors:=numcolors;
    end;
    if Assigned(FMemBits) then
     GetDIBBits;
   end;
  finally
   FreeMem(pbitmapinfo);
  end;
 end;
 if (usedcolors>0) then
  usedcolors:=usedcolors-1;
end;
{$ENDIF}

const
  M_SOF0  = $C0;        { Start Of Frame N }
  M_SOF1  = $C1;        { N indicates which compression process }
  M_SOF2  = $C2;        { Only SOF0-SOF2 are now in common use }
  M_SOF3  = $C3;
  M_SOF5  = $C5;        { NB: codes C4 and CC are NOT SOF markers }
  M_SOF6  = $C6;
  M_SOF7  = $C7;
  M_SOF9  = $C9;
  M_SOF10 = $CA;
  M_SOF11 = $CB;
  M_SOF13 = $CD;
  M_SOF14 = $CE;
  M_SOF15 = $CF;
  M_SOI   = $D8;        { Start Of Image (beginning of datastream) }
  M_EOI   = $D9;        { End Of Image (end of datastream) }
  M_SOS   = $DA;        { Start Of Scan (begins compressed data) }
  M_COM   = $FE;        { COMment }



// Returns false if it's not a jpeg
procedure GetJPegInfo(astream:TStream;var width,height:integer;var format:string);
var
 c1, c2 : Byte;
 i1,i2:integer;
 readed:integer;
 marker:integer;

 function NextMarker:integer;
 var
   c:integer;
 begin
  { Find 0xFF byte; count and skip any non-FFs. }
  readed:=astream.Read(c1,1);
  if readed<1 then
   Raise Exception.Create(SRpSInvalidJPEG);
  c:=c1;
  while (c <> $FF) do
  begin
   readed:=astream.Read(c1,1);
   if readed<1 then
    Raise Exception.Create(SRpSInvalidJPEG);
   c := c1;
  end;
  { Get marker code byte, swallowing any duplicate FF bytes.  Extra FFs
    are legal as pad bytes, so don't count them in discarded_bytes. }
  repeat
   readed:=astream.Read(c1,1);
   if readed<1 then
    Raise Exception.Create(SRpSInvalidJPEG);
   c:=c1;
  until (c <> $FF);
  Result := c;
 end;

 procedure skip_variable;
 { Skip over an unknown or uninteresting variable-length marker }
 var
  alength:Integer;
  w:Word;
 begin
  { Get the marker parameter length count }
  readed:=astream.Read(w,2);
  if readed<2 then
   Raise Exception.Create(SRpSInvalidJPEG);
  alength:=Hi(w)+(Lo(w) shl 8);
  { Length includes itself, so must be at least 2 }
  if (alength < 2) then
   Raise Exception.Create(SRpSInvalidJPEG);
  Dec(alength, 2);
  { Skip over the remaining bytes }
  while (alength > 0) do
  begin
   readed:=astream.Read(c1,1);
   if readed<1 then
    Raise Exception.Create(SRpSInvalidJPEG);
   Dec(alength);
  end;
 end;

 procedure process_COM;
 var
  alength:Integer;
  comment:string;
  w:Word;
 begin
  { Get the marker parameter length count }
  readed:=astream.Read(w,2);
  if readed<2 then
   Raise Exception.Create(SRpSInvalidJPEG);
  alength:=Hi(w)+(Lo(w) shl 8);

   { Length includes itself, so must be at least 2 }
  if (alength < 2) then
   Raise Exception.Create(SRpSInvalidJPEG);
  Dec(alength, 2);
  comment := '';
  while (alength > 0) do
  begin
   readed:=astream.Read(c1,1);
   if readed<1 then
    Raise Exception.Create(SRpSInvalidJPEG);
   comment := comment + char(c1);
   Dec(alength);
  end;
 end;

 procedure process_SOFn;
 var
  alength:Integer;
  w:Word;
 begin
  readed:=astream.Read(w,2);
  if readed<2 then
   Raise Exception.Create(SRpSInvalidJPEG);
  // Skip length
 // alength:=Hi(w)+(Lo(w) shl 8);

  // data_precission skiped
  readed:=astream.Read(c1,1);
  if readed<1 then
   Raise Exception.Create(SRpSInvalidJPEG);
  // Height
  readed:=astream.Read(w,2);
  if readed<2 then
   Raise Exception.Create(SRpSInvalidJPEG);
  alength:=Hi(w)+(Lo(w) shl 8);
  Height:=alength;
  // Width
  readed:=astream.Read(w,2);
  if readed<2 then
   Raise Exception.Create(SRpSInvalidJPEG);
  alength:=Hi(w)+(Lo(w) shl 8);
  Width:=alength;
 end;


begin
 format:='JPEG'; 
 // Checks it's a jpeg image
 readed:=astream.Read(c1,1);
 if readed<1 then
 begin
  astream.seek(0,soFromBeginning);
  format:='';
  exit;
 end;
 i1:=c1;
 if i1<>$FF then
 begin
  format:='';
 end;
 readed:=astream.Read(c2,1);
 if readed<1 then
 begin
  astream.seek(0,soFromBeginning);
  format:='';
  exit;
 end;
 i2:=c2;
 if i2<>M_SOI then
 begin
  format:='';
  if ((c1=Ord('B')) AND (c2=Ord('M'))) then
  begin
   astream.seek(0,soFromBeginning);
   format:='BMP';
   exit;
  end;
  if ((c1=Ord('G')) AND (c2=Ord('I'))) then
  begin
   format:='GIF';
   astream.seek(0,soFromBeginning);
   exit;
  end;
  if ((c1=137) AND (c2=Ord('P'))) then
  begin
   format:='PNG';
   astream.seek(0,soFromBeginning);
   exit;
  end;
 end;
 if (not (format='JPEG')) then
 begin
  astream.seek(0,soFromBeginning);
  exit;
 end;
 width:=0;
 height:=0;
 // Read segments until M_SOS
 repeat
  marker := NextMarker;
  case marker of
   M_SOF0,		{ Baseline }
   M_SOF1,		{ Extended sequential, Huffman }
   M_SOF2,		{ Progressive, Huffman }
   M_SOF3,		{ Lossless, Huffman }
   M_SOF5,		{ Differential sequential, Huffman }
   M_SOF6,		{ Differential progressive, Huffman }
   M_SOF7,		{ Differential lossless, Huffman }
   M_SOF9,		{ Extended sequential, arithmetic }
   M_SOF10,		{ Progressive, arithmetic }
   M_SOF11,		{ Lossless, arithmetic }
   M_SOF13,		{ Differential sequential, arithmetic }
   M_SOF14,		{ Differential progressive, arithmetic }
   M_SOF15:		{ Differential lossless, arithmetic }
    begin
     process_SOFn;
     // Exit, no more info need
     marker:=M_SOS;
    end;
   M_SOS:			{ stop before hitting compressed data }
    begin
    end;
   M_EOI:			{ in case it's a tables-only JPEG stream }
    begin
    end;
   M_COM:
    process_COM;
   else			{ Anything else just gets skipped }
     skip_variable;		{ we assume it has a parameter count... }
  end;
 until ((marker=M_SOS) or (marker=M_EOI));
 astream.seek(0,soFromBeginning);
end;


procedure TRpPDFCanvas.FreeFonts;
var
 i:integer;
begin
 for i:=0 to FFontTTData.Count-1 do
 begin
  TRpTTFontData(FFontTTData.Objects[i]).fontdata.free;
  FFontTTData.Objects[i].Free;
 end;
 FFontTTData.Clear;
end;


function TRpPDFCanvas.UpdateFonts:TRpTTFontData;
var
 searchname:string;
 adata:TRpTTFontData;
 index:integer;
begin
 Result:=nil;
 if (PDFConformance = PDF_1_4) then
 begin
   if Not (Font.Name in [poLinked,poEmbedded]) then
    exit;
 end;
 if Not Assigned(InfoProvider) then
  exit;
 searchname:=Font.fontname+IntToStr(Font.Style);
 index:=FFontTTData.IndexOf(searchname);
 if index<0 then
 begin
  adata:=TRpTTFontData.Create;
  adata.fontdata:=TAdvFontData.Create;
  adata.embedded:=false;
  adata.Objectname:=searchname;
  FFontTTData.AddObject(searchname,adata);
  InfoProvider.FillFontData(Font,adata);
  if adata.fontdata.FontData.size>0 then
  begin
    // In PDF_A_3 all fonts must be embedded
    if (PDFConformance = PDF_A_3) then
    begin
      adata.embedded := true;
      Font.Name:=poEmbedded;
    end
    else
      adata.embedded:=Font.Name=poEmbedded;
    adata.IsUnicode:=true;
  end
  else
  begin
    if (PDFConformance = PDF_A_3) then
     raise Exception.Create('Font data empty, font can not be embeded');
    if (Font.Name in [poEmbedded,poLinked]) then
     adata.isunicode:=true;
  end;
  Result:=adata;
 end
 else
  Result:=TRpTTFontData(FFontTTData.Objects[index]);
end;

procedure TRpPDFFile.SetFontType;
var
 i:integer;
 index2: Word;
 adata:TRpTTFontData;
 aunicodecount,index,acount:integer;
 currentindex,nextindex:integer;
 awidths:string;
 cmaphead,fromTo:AnsiString;
 FCMapStream:TMemoryStream;
 FontStream:TMemoryStream;
begin
 if (FPDFConformance=PDF_1_4) then
 begin
   CreateFont('Type1','Helvetica','WinAnsiEncoding');
   CreateFont('Type1','Helvetica-Bold','WinAnsiEncoding');
   CreateFont('Type1','Helvetica-Oblique','WinAnsiEncoding');
   CreateFont('Type1','Helvetica-BoldOblique','WinAnsiEncoding');
   CreateFont('Type1','Courier','WinAnsiEncoding');
   CreateFont('Type1','Courier-Bold','WinAnsiEncoding');
   CreateFont('Type1','Courier-Oblique','WinAnsiEncoding');
   CreateFont('Type1','Courier-BoldOblique','WinAnsiEncoding');
   CreateFont('Type1','Times-Roman','WinAnsiEncoding');
   CreateFont('Type1','Times-Bold','WinAnsiEncoding');
   CreateFont('Type1','Times-Italic','WinAnsiEncoding');
   CreateFont('Type1','Times-BoldItalic','WinAnsiEncoding');
   CreateFont('Type1','Symbol','WinAnsiEncoding');
   CreateFont('Type1','ZapfDingbats','WinAnsiEncoding');
   end;
 // Writes font files
 for i:=0 to Canvas.FFontTTData.Count-1 do
 begin
  adata:=TRpTTFontData(Canvas.FFontTTData.Objects[i]);

  if (adata.embedded) then
  begin
   // Writes font resource data
   FObjectCount:=FObjectCount+1;
   FTempStream.Clear;
   SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
   if (FPDFConformance = PDF_A_3) then
   begin
    SWriteLine(FTempStream,'<< /Type /FontFile2');
   end
   else
   begin
     SWriteLine(FTempStream,'<< ');
   end;
    FontStream:=Canvas.InfoProvider.GetFontStream(adata);
    //FontStream:=Canvas.InfoProvider.GetFullFontStream(adata);
   try
    WriteStream(FontStream,FTempStream);
   finally
    FontStream.Free;
   end;
   adata.ObjectIndex:=FObjectCount;
   SWriteLine(FTempStream,'endobj');
   AddToOffset(FTempStream.Size);
   FTempStream.SaveToStream(FMainPDF);
  end
  else
  begin
   adata.ObjectIndex:=0;
  end;
  // Writes font descriptor
  FObjectCount:=FObjectCount+1;
  FTempStream.Clear;
  SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
  adata.DescriptorIndex:=FObjectCount;
  SWriteLine(FTempStream,'<< /Type /FontDescriptor');
  if adata.isunicode then
  begin
   SWriteLine(FTempStream,'/FontName /'+adata.postcriptname);
   SWriteLine(FTempStream,'/FontFamily('+adata.familyname+')');
  end
  else
   SWriteLine(FTempStream,'/FontName /'+adata.postcriptname);
  SWriteLine(FTempStream,'/Flags '+IntToStr(adata.Flags));
  SWriteLine(FTempStream,'/FontBBox ['+
   IntToStr(adata.FontBBox.Left)+' '+
   IntToStr(adata.FontBBox.Bottom)+' '+
   IntToStr(adata.FontBBox.Right)+' '+
   IntToStr(adata.FontBBox.Top)+']'
   );
  SWriteLine(FTempStream,'/ItalicAngle '+IntToStr(Round(adata.ItalicAngle)));
  SWriteLine(FTempStream,'/Ascent '+IntToStr(adata.Ascent));
  SWriteLine(FTempStream,'/Descent '+IntToStr(adata.Descent));
  SWriteLine(FTempStream,'/Leading '+IntToStr(adata.Leading));
  SWriteLine(FTempStream,'/CapHeight '+IntToStr(adata.CapHeight));
  SWriteLine(FTempStream,'/StemV '+IntToStr(Round(adata.StemV)));
  if (adata.AvgWidth)<>0 then
   SWriteLine(FTempStream,'/AvgWidth '+IntToStr(adata.AvgWidth));
  SWriteLine(FTempStream,'/MaxWidth '+IntToStr(adata.MaxWidth));
  SWriteLine(FTempStream,'/FontStretch /Normal');
  if adata.FontWeight>0 then
   SWriteLine(FTempStream,'/FontWeight '+IntToStr(adata.FontWeight));
  if adata.embedded then
  begin
   if adata.Type1 then
    SWriteLine(FTempStream,'/FontFile '+
     IntToStr(adata.ObjectIndex)+' 0 R')
   else
    SWriteLine(FTempStream,'/FontFile2 '+
     IntToStr(adata.ObjectIndex)+' 0 R');
  end;
  SWriteLine(FTempStream,'>>');
  SWriteLine(FTempStream,'endobj');
  AddToOffset(FTempStream.Size);
  FTempStream.SaveToStream(FMainPDF);

  // To unicode stream
  if (adata.IsUnicode) then
  begin
   // First Build the string
   cmaphead:='/CIDInit /ProcSet findresource begin' +LINE_FEED+
                '12 dict begin ' +LINE_FEED+
                'begincmap' +LINE_FEED+
                '/CIDSystemInfo' +LINE_FEED+
                '<< /Registry (TTX+0)' +LINE_FEED+
                '/Ordering (T42UV)' +LINE_FEED+
                '/Supplement 0' +LINE_FEED+
                '>> def' +LINE_FEED+
                '/CMapName /TTX+0 def' +LINE_FEED+
                '/CMapType 2 def' +LINE_FEED+
                '1 begincodespacerange' +LINE_FEED+
                '<0000><FFFF>' +LINE_FEED+
                'endcodespacerange'+LINE_FEED;
   currentindex:=adata.firstloaded;
   nextindex:=adata.firstloaded;
   while (currentindex<=adata.lastloaded) do
   begin
    aunicodecount := 0;
    index:=currentindex;
    while (index<=adata.lastloaded) do
    begin
     nextindex:=index;
     if adata.loaded[index] then
     begin
      Inc(aunicodecount);
      if (aunicodecount>=100) then
       break;
     end;
     inc(index);
    end;
    if (aunicodecount>0) then
    begin
     cmaphead:= cmaphead+IntToStr(aunicodecount)+
      ' beginbfchar'+LINE_FEED;
     for index := currentindex to nextindex do
     begin
      if adata.loaded[index] then
      begin
       fromTo:='<'+ IntToHex4(Integer(adata.loadedglyphs[index]))+'> ';
       cmaphead:=cmaphead+fromTo+' <'+IntToHex4(index)+'>'+LINE_FEED;
      end;
     end;
     cmaphead:=cmaphead+'endbfchar' +LINE_FEED;
    end;
    currentindex:=nextindex+1;
   end;
   cmaphead:= cmaphead+'endcmap' +LINE_FEED+
               'CMapName currentdict /CMap defineresource pop'+LINE_FEED+
               'end end'+LINE_FEED;

   FObjectCount:= FObjectCount + 1;
   adata.ToUnicodeIndex := FObjectCount;

   FTempStream.Clear;
   SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
   FCMapStream:=TMemoryStream.Create;
   try
    WriteStringToStream(cmaphead,FCMapStream);
    FCmapStream.Position:=0;
    SWriteLine(FTempStream,'<< ');
    WriteStream(FCMapStream, FTempStream);
   finally
    FCMapStream.free;
   end;
   SWriteLine(FTempStream,'endobj');
   AddToOffset(FTempStream.Size);
   FTempStream.SaveToStream(FMainPDF);
  end;
 end;

 // Creates the fonts of the font list
 for i:=0 to Canvas.FFontTTData.Count-1 do
 begin
  adata:=TRpTTFontData(Canvas.FFontTTData.Objects[i]);
  if adata.isunicode then
  begin
   FObjectCount:=FObjectCount+1;
   FTempStream.Clear;
   adata.ObjectIndexParent:=FObjectCount;
   SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
   SWriteLine(FTempStream,'<< /Type /Font');
   SWriteLine(FTempStream,'/Subtype /Type0');
   SWriteLine(FTempStream,'/Name /F'+adata.ObjectName);
   SWriteLine(FTempStream,'/BaseFont /'+CONS_UNICODEPREDIX+adata.postcriptname);
   SWriteLine(FTempStream,'/Encoding /Identity-H');
   //SWriteLine(FTempStream,'/Encoding /PDFDocEncoding');
   SWriteLine(FTempStream,'/DescendantFonts [ '+IntToStr(FObjectCount+1)+' 0 R ]');
   SWriteLine(FTempStream,'/ToUnicode '+IntToStr(adata.ToUnicodeIndex) + ' 0 R');

   SWriteLine(FTempStream,'>>');
   SWriteLine(FTempStream,'endobj');
   AddToOffset(FTempStream.Size);
   FTempStream.SaveToStream(FMainPDF);

   FObjectCount:=FObjectCount+1;
   FTempStream.Clear;
   SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
   SWriteLine(FTempStream,'<< /Type /Font');
   if adata.Type1 then
   begin
    SWriteLine(FTempStream,'/Subtype /CIDFontType1');
   end
   else
   begin
    SWriteLine(FTempStream,'/Subtype /CIDFontType2');
   end;
   SWriteLine(FTempStream,'/BaseFont /'+CONS_UNICODEPREDIX+adata.postcriptname);

   SWriteLine(FTempStream,'/FontDescriptor '+
    IntToStr(adata.DescriptorIndex)+' 0 R');
   SWriteLine(FTempStream,'/FontFamily('+adata.familyname+')');
   SWriteLine(FTempStream,'/CIDSystemInfo<</Ordering(Identity)/Registry(Adobe)/Supplement 0>>');
   SWriteLine(FTempStream,'/DW 1000');
   if (adata.firstloaded <>65536) then
   begin
    SWriteLine(FTempStream,'/W [');
    awidths:='';
    index:=adata.firstloaded;
    acount:=0;

   repeat
    if adata.loaded[index] then
     begin
      awidths:=awidths+IntToStr(Integer(adata.loadedglyphs[index]))+'['+FormatFloat('0.0',adata.loadedwidths[index], NumberFormatSettings)+'] ';
 //     awidths:=awidths+IntToStr(index)+'['+IntToStr(adata.loadedwidths[index])+'] ';
      acount:=acount+1;
      if (acount mod 8)=7 then
       awidths:=awidths+LINE_FEED;
     end;
     inc(index);
    until ((index>adata.lastloaded) or (index>60000));
    SWriteLine(FTempStream,awidths);
    SWriteLine(FTempStream,']');
   end;
(*
   // To unicode cmap
   SWriteLine(FTempStream,'/ToUnicode [');

   awidths:='';
   index:=adata.firstloaded;
   acount:=0;
   repeat
    if adata.loaded[index] then
    begin
     awidths:=awidths+'<'+IntToHex(Integer(adata.loadedglyphs[index]))+'> <'+IntToHex(index)+'> ';
//     awidths:=awidths+IntToStr(index)+'['+IntToStr(adata.loadedwidths[index])+'] ';
     acount:=acount+1;
     if (acount mod 8)=7 then
      awidths:=awidths+LINE_FEED;
    end;
    inc(index);
   until index>adata.lastloaded;
   SWriteLine(FTempStream,awidths);
   SWriteLine(FTempStream,']');*)

   if (PDFConformance = PDF_A_3) then
   begin
    SWriteLine(FTempStream,'/CIDToGIDMap /Identity');
    // SWriteLine(FTempStream,'/CDIToGDIMap ' + IntToStr(adata.CIDToGIDMapIndex)+' 0 R');
   end
   else
   begin
    SWriteLine(FTempStream,'/CDIToGDIMap /Identity');
   end;


   SWriteLine(FTempStream,'>>');
   SWriteLine(FTempStream,'endobj');
   AddToOffset(FTempStream.Size);
   FTempStream.SaveToStream(FMainPDF);
  end
  else
  begin
   FObjectCount:=FObjectCount+1;
   FTempStream.Clear;
   adata.ObjectIndexParent:=FObjectCount;
   SWriteLine(FTempStream,IntToStr(FObjectCount)+' 0 obj');
   SWriteLine(FTempStream,'<< /Type /Font');
   if adata.Type1 then
   begin
    SWriteLine(FTempStream,'/Subtype /Type1');
   end
   else
   begin
    SWriteLine(FTempStream,'/Subtype /TrueType');
   end;
   SWriteLine(FTempStream,'/Name /F'+adata.ObjectName);
   SWriteLine(FTempStream,'/BaseFont /'+adata.postcriptname);
   SWriteLine(FTempStream,'/FirstChar '+IntToStr(adata.firstloaded));
   SWriteLine(FTempStream,'/LastChar '+IntToStr(adata.lastloaded));
   awidths:='[';
   if adata.lastloaded>0 then
   begin
    index:=adata.firstloaded;
    repeat
     awidths:=awidths+FormatFloat('0.0', adata.loadedwidths[index], NumberFormatSettings)+' ';
     inc(index);
     if (index mod 8)=7 then
      awidths:=awidths+LINE_FEED;
    until index>adata.lastloaded;
    awidths:=awidths+']';
    SWriteLine(FTempStream,'/Widths '+awidths);
   end;
   SWriteLine(FTempStream,'/FontDescriptor '+
    IntToStr(adata.DescriptorIndex)+' 0 R');
   if (PDFConformance = PDF_A_3) then
   begin
    SWriteLine(FTempStream,'/Encoding /Identity-H');
    // SWriteLine(FTempStream,'/Encoding /'+adata.Encoding);
   end
   else
   begin
    SWriteLine(FTempStream,'/Encoding /'+adata.Encoding);
   end;
   SWriteLine(FTempStream,'>>');
   SWriteLine(FTempStream,'endobj');
   AddToOffset(FTempStream.Size);
   FTempStream.SaveToStream(FMainPDF);
  end;
 end;
end;

procedure TRpPDFCanvas.SetInfoProvider(aprov:TRpInfoProvider);
begin
 if Not assigned(aprov) then
  FInfoProvider:=FDefInfoProvider
 else
 begin
  FInfoProvider:=aprov;
 end;
end;

function TRpPDFCanvas.GetTTFontData:TRpTTFontData;
begin
 Result:=nil;
 if (PDFConformance = PDF_1_4) then
 begin
   if Not (Font.Name in [poLinked,poEmbedded]) then
    exit;
 end;
 if Not Assigned(InfoProvider) then
 begin
  if (PDFConformance = PDF_A_3) then
    raise Exception.Create('No info provider for fonts, fonts must be embedded in A_3 Conformance');  
  exit;
 end;
 Result:=UpdateFonts;
end;


function WideCharToHex(achar:Widechar):string;
var
 aint:Integer;
begin
 aint:=Integer(achar);
 Result:=Format('%4.4x',[aint]);
end;



function TRpPDFCanvas.EncodeUnicode(astring:Widestring;adata:TRpTTFontData;pdffont:TRpPDFFont):string;
var
 aresult:string;
 i:integer;
 kerningvalue:integer;
begin
 aresult:= aresult+'[(';
 aresult := aresult + char(254);
 aresult := aresult + char(254);
// aresult := aresult + char(255);
  for i:=1 to Length(astring) do
  begin
   if astring[i] in [WideChar('('),WideChar(')'),WideChar('\')] then
    aresult:=aresult+'\';
   // Euro exception
//   if astring[i]=widechar(8364) then
//    Result:=Result+chr(128)
//   else
   aresult:=aresult+chr(Word(astring[i]) shr 8);
   aresult:=aresult+chr(Word(astring[i]) AND $F0);
   if (i<Length(astring)) then
   begin
    kerningvalue:=infoprovider.GetKerning(pdffont,adata,WideChar(astring[i]),WideChar(astring[i+1]));
    if kerningvalue<>0 then
    begin
     aresult:=aresult+')'+' '+IntToStr(kerningvalue);
     aresult:=aresult+' (';
    end;
   end;
  end;
  aresult:=aresult+')]';
  Result:=aresult;
end;

{$IFDEF USETEXTSHAPING}
function TRpPDFCanvas.PDFCompatibleTextShaping(
  adata: TRpTTFontData;
  pdffont: TRpPDFFont;
  RightToLeft: boolean;
  posX, posY: Double;
  FontSize: integer;
  lInfo: TRpLineInfo): String;
var
  i: Integer;
  g: TGlyphPos;
  gidHex: string;
  cursor: Double;
  absX, absY: Double;
  EOL: string;
begin
  EOL := FFile.EndOfLine;
  Result := '';
  cursor := 0.0;

  for i := 0 to High(lInfo.Glyphs) do
  begin
    g := lInfo.Glyphs[i];
    // glyph id hex (tu helper)
    gidHex := IntToHex4(g.GlyphIndex);

    // llamadas auxiliares que tenías para compatibilidad
    InfoProvider.GetGlyphWidth(pdffont, adata, g.GlyphIndex, g.CharCode);
    InfoProvider.GetCharWidth(pdffont, adata, g.CharCode);

    // calcular posiciones PDF como hacías
    absX := posX + cursor + g.XOffset;
    absY := posY - g.YOffset;

    // Emitir la instrucción Tm y Tj SIN q/Q
    // Matriz: 1 0 0 1 tx ty Tm   seguido de <gid> Tj
    Result := Result + Format('1 0 0 1 %s %s Tm <%s> Tj' + EOL,
      [UnitsToTextX(absX), UnitsToTextY(absY), gidHex], TFormatSettings.Invariant);

    // avanzar cursor
    cursor := cursor + g.XAdvance;
  end;
end;

{$ENDIF}

function TRpPDFCanvas.PDFCompatibleTextWidthKerning(astring:WideString;adata:TRpTTFontData;pdffont:TRpPDFFont):String;
var
 i:integer;
 kerningvalue:integer;
begin
 if Length(astring)<1 then
 begin
  Result:='[]';
  exit;
 end;
 if adata.isunicode then
 begin
  //Result:=EncodeUnicode(astring,adata,pdffont);

  Result:='[<';
  for i:=1 to Length(astring) do
  begin
//   Result:=Result+WideCharToHex(astring[i]);
   Result:=Result+WideCharToHex(adata.loadedglyphs[Integer(astring[i])]);
   if (i<Length(astring)) then
   begin
    kerningvalue:=infoprovider.GetKerning(pdffont,adata,WideChar(astring[i]),WideChar(astring[i+1]));
    if kerningvalue<>0 then
    begin
     Result:=Result+'>'+' '+IntToStr(kerningvalue);
     Result:=Result+' <';
    end;
   end;
  end;
  Result:=Result+'>]';
 end
 else
 begin
  Result:='[(';
  for i:=1 to Length(astring) do
  begin
   if astring[i] in [WideChar('('),WideChar(')'),WideChar('\')] then
    Result:=Result+'\';
   // Euro exception
   if (Ord(astring[i])=8364) then
    Result:=Result+AnsiChar(128)
   else
    Result:=Result+astring[i];
   if (i<Length(astring)) then
   begin
    kerningvalue:=infoprovider.GetKerning(pdffont,adata,WideChar(astring[i]),WideChar(astring[i+1]));
    if kerningvalue<>0 then
    begin
     Result:=Result+')'+' '+IntToStr(kerningvalue);
     Result:=Result+' (';
    end;
   end;
  end;
  Result:=Result+')]';
 end;
end;

function PDFCompatibleText(astring:Widestring;adata:TRpTTFontData;pdffont:TRpPDFFont):String;
var
 i:integer;
 isunicode:boolean;
 nchar:Widechar;
begin
 isunicode:=false;
 if Assigned(adata) then
 begin
  isunicode:=adata.isunicode;
 end;
 if isunicode then
 begin
  Result:='<';
  for i:=1 to Length(astring) do
  begin
//   Result:=Result+WideCharToHex(astring[i]);

   Result:=Result+WideCharToHex(adata.loadedglyphs[Integer(astring[i])]);
  end;
  Result:=Result+'>';
 end
 else
 begin
  Result:='(';
  for i:=1 to Length(astring) do
  begin
   nchar:=astring[i];
   if nchar in [WideChar('('),WideChar(')'),WideChar('\')] then
    Result:=Result+'\';
   // Euro character exception
   if (Ord(nchar)=8364) then
    Result:=Result+AnsiChar(128)
   else
    Result:=Result+nchar;
  end;
  Result:=Result+')';
 end;
end;

function EncodePDFText(const text: string): string;
var
  UTF16BEBytes: TBytes;
  i: Integer;
  HexString: string;
  IsASCII: Boolean;
begin
  // Verificar si todos los caracteres son ASCII
  IsASCII := True;
  for i := 1 to Length(text) do
  begin
    if Ord(text[i]) > 127 then
    begin
      IsASCII := False;
      Break;
    end;
  end;
  // Si todos los caracteres son ASCII, usar formato de cadena normal con paréntesis
  if IsASCII then
  begin
    Result := '(';
    for i := 1 to Length(text) do
    begin
      // Escape special chars
      case text[i] of
        '(', ')', '\':
          Result := Result + '\' + text[i];
      else
        Result := Result + text[i];
      end;
    end;
    Result := Result + ')';
  end
  else
  begin
    // Convert to UTF-16BE
    UTF16BEBytes := TEncoding.BigEndianUnicode.GetBytes(text);
    // Crear el resultado en formato hexadecimal PDF: Comienza con el BOM UTF-16BE 0xFEFF
    Result := '<FEFF';
    // Convertir cada byte a su representación hexadecimal
    for i := 0 to Length(UTF16BEBytes) - 1 do
    begin
      // Formatear cada byte como hexadecimal de dos dígitos
      HexString := IntToHex(UTF16BEBytes[i]);
      Result := Result + HexString;
    end;
    // Cerrar la cadena en formato hexadecimal PDF
    Result := Result + '>';
  end;
end;

procedure TRpPDFFile.FreePageInfos;
var
 i:integer;
begin
 for i:=0 to FPageInfos.Count-1 do
 begin
  FPageInfos.Objects[i].free;
 end;
 FPageInfos.Clear;
end;


end.

