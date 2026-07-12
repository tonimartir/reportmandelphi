{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       Rpexceldriver                                   }
{       Exports a metafile to a excel sheet             }
{       can be used only for windows                    }
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

unit rpexceldriver;

interface

{$I rpconf.inc}

uses
 mmsystem,windows,
 Classes,sysutils,rpmetafile,rpmdconsts,Graphics,Forms,
 rpmunits,Dialogs, Controls,
 StdCtrls,ExtCtrls,rppdffile,rpgraphutilsvcl,
{$IFDEF VCLNOTATION}
 Vcl.Imaging.jpeg,System.Win.Comobj,
{$ENDIF}
{$IFNDEF VCLNOTATION}
 jpeg,Comobj,
{$ENDIF}
{$IFDEF USEVARIANTS}
 types,Variants,
{$ENDIF}
 rptypes,rpvgraphutils;


const
 XLS_PRECISION=100;

const
  xlHAlignCenter = $FFFFEFF4;
  xlHAlignCenterAcrossSelection = $00000007;
  xlHAlignDistributed = $FFFFEFEB;
  xlHAlignFill = $00000005;
  xlHAlignGeneral = $00000001;
  xlHAlignJustify = $FFFFEFDE;
  xlHAlignLeft = $FFFFEFDD;
  xlHAlignRight = $FFFFEFC8;
  xlExclusive = $00000003;
  xlNoChange = $00000001;
  xlShared = $00000002;



type
  TFRpExcelProgress = class(TForm)
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
    procedure FormCreate(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    allpages:boolean;
    isvisible:boolean;
    frompage,topage:integer;
    onesheet:boolean;
    dook:boolean;
    procedure AppIdle(Sender:TObject;var done:boolean);
  public
    { Public declarations }
    cancelled:boolean;
    oldonidle:TIdleEvent;
    tittle:string;
    filename:string;
    metafile:TRpMetafileReport;
    isxml:boolean;
  end;

function ExportMetafileToExcel (metafile:TRpMetafileReport; filename:string;
 showprogress,visible,allpages:boolean; frompage,topage:integer;
 onesheet:Boolean=false):boolean;

function ExportMetafileToXMLSpreadsheet (metafile:TRpMetafileReport; filename:string;
 showprogress,allpages:boolean; frompage,topage:integer;
 onesheet:Boolean=false; openfile:Boolean=true):boolean;

implementation

uses ShellAPI;

{$R *.dfm}

type
  TXMLCell = class
  public
    RowIndex: Integer;
    ColIndex: Integer;
    Value: string;
    DataType: string;
    StyleID: string;
  end;

procedure DoExportMetafileXML(metafile:TRpMetafileReport;filename:string;
  aform:TFRpExcelProgress;allpages:boolean;frompage,topage:integer;
   onesheet:Boolean); forward;

const
 AlignmentFlags_SingleLine=64;
 AlignmentFlags_AlignHCenter = 4 { $4 };
 AlignmentFlags_AlignHJustify = 1024 { $400 };
 AlignmentFlags_AlignTop = 8 { $8 };
 AlignmentFlags_AlignBottom = 16 { $10 };
 AlignmentFlags_AlignVCenter = 32 { $20 };
 AlignmentFlags_AlignLeft = 1 { $1 };
 AlignmentFlags_AlignRight = 2 { $2 };


function IsValidNumberChar(achar:char):Boolean;
begin
 Result:=false;
{$IFDEF DELPHI2009UP}
 if (achar in ['-','+','e','E','0'..'9',' ',FormatSettings.DecimalSeparator]) then
{$ELSE}
 if (achar in ['-','+','e','E','0'..'9',' ',DecimalSeparator]) then
{$ENDIF}
  Result:=true;
end;




function VarTryStrToFloat(S: string; var Value: Double): Boolean;
var
 index,i:integer;
begin
{$IFDEF DELPHI2009UP}
  Result:=TryStrToFloat(S,Value);
  exit;
{$ENDIF}
 Result:=true;
 S:=Trim(S);
 // Remove thousand separators
 repeat
{$IFDEF DELPHI2009UP}
  index:=Pos(FormatSettings.ThousandSeparator,S);
{$ELSE}
  index:=Pos(ThousandSeparator,S);
{$ENDIF}
  if index>0 then
   S:=Copy(S,1,index-1)+Copy(S,index+1,Length(S));
 until index=0;
 for i:=1 to Length(S) do
 begin
  if Not IsValidNumberChar(S[i]) then
  begin
   result:=false;
   break;
  end;
 end;
 if not result then
  exit;
 try
  Value:=StrToFloat(S);
 except
  Result:=false;
 end;
end;

function VarTryStrToDate(S: string; var Value: TDateTime): Boolean;
begin
 Result:=TryStrToDate(S,Value);
end;


{$IFNDEF DOTNETD}
procedure PrintObject(sh:Variant;page:TRpMetafilePage;obj:TRpMetaObject;dpix,dpiy:integer;toprinter:boolean;
 rows,columns:TStringList;FontName:String;FontSize,rowinit:integer);
var
 aansitext:string;
 arow,acolumn:integer;
 leftstring,topstring:String;
 number:Double;
 isanumber:boolean;
 afontStyle:TFontStyles;
 acolor:TColor;
 isadate:boolean;
 adate:TDateTime;
begin
 topstring:=FormatCurr('0000000000',obj.Top/XLS_PRECISION);
 leftstring:=FormatCurr('0000000000',obj.Left/XLS_PRECISION);
 arow:=rows.IndexOf(topstring)+1+rowinit;
 acolumn:=columns.IndexOf(leftstring)+1;
 if acolumn<1 then
  acolumn:=1;
 if arow<1 then
  arow:=1;
 case obj.Metatype of
  rpMetaText:
   begin
    aansitext:=page.GetText(Obj);
    // If it's a number
    isanumber:=VarTryStrToFloat(aansitext,number);
    if isanumber then
     sh.Cells.item[arow,acolumn].Value:=number
    else
    begin

     isadate:=VarTryStrToDate(aansitext,adate);
     if isadate then
     begin
      sh.Cells.item[arow,acolumn].Value:=FormatDateTime('mm"/"dd"/"yyyy',adate);
     end
     else
     begin
      if Length(aansitext)>0 then
      begin
        if aansitext[1]='=' then
        aansitext:=''''+aansitext;
      end;
      sh.Cells.item[arow,acolumn].Value:=aansitext;
     end;
    end;
    if FontName<>page.GetWFontName(Obj) then
     sh.Cells.item[arow,acolumn].Font.Name:=page.GetWFontName(Obj);
    if obj.FontSize<>FontSize then
     sh.Cells.item[arow,acolumn].Font.Size:=Obj.FontSize;
    acolor:=CLXColorToVCLColor(Obj.FontColor);
    if acolor<>clBlack then
     sh.Cells.item[arow,acolumn].Font.Color:=acolor;
    afontstyle:=CLXIntegerToFontStyle(obj.FontStyle);
    if fsItalic in afontstyle then
     sh.Cells.item[arow,acolumn].Font.Italic:=true;
    if fsBold in afontstyle then
     sh.Cells.item[arow,acolumn].Font.Bold:=true;
    if fsUnderline in afontstyle then
    sh.Cells.item[arow,acolumn].Font.Underline:=true;
    if fsStrikeout in afontstyle then
     sh.Cells.item[arow,acolumn].Font.Strikethrough:=true;
    // Font rotation not implemented
    if (obj.AlignMent AND AlignmentFlags_AlignHCenter)>0 then
     sh.Cells.item[arow,acolumn].HorizontalAlignment:=-4108;
    //if (obj.AlignMent AND AlignmentFlags_SingleLine)=0 then
    // sh.Cells.item[arow,acolumn].Multiline:=true;
    if (obj.AlignMent AND AlignmentFlags_AlignLEFT)>0 then
     if isanumber then
       sh.Cells.item[arow,acolumn].HorizontalAlignment:=-4131;
    if (obj.AlignMent AND AlignmentFlags_AlignRight)>0 then
     if not isanumber then
     begin
      sh.Cells.item[arow,acolumn].HorizontalAlignment:=-4152;
     end;
    // Word wrap not supported
    if obj.WordWrap then
     sh.Cells.item[arow,acolumn].WrapText:=True;
//    if Not obj.CutText then
//     aalign:=aalign or DT_NOCLIP;
//    if obj.RightToLeft then
//     aalign:=aalign or DT_RTLREADING;
    // In word 97, not supported
//    if Not obj.Transparent then
//     sh.Cells.Item[arow,acolumn].Color:=CLXColorToVCLColor(obj.BackColor);
   end;
  rpMetaDraw:
   begin
{    Width:=round(obj.Width*dpix/TWIPS_PER_INCHESS);
    Height:=round(obj.Height*dpiy/TWIPS_PER_INCHESS);
    abrushstyle:=obj.BrushStyle;
    if obj.BrushStyle>integer(bsDiagCross) then
     abrushstyle:=integer(bsDiagCross);
    Canvas.Pen.Color:=CLXColorToVCLColor(obj.Pencolor);
    Canvas.Pen.Style:=TPenStyle(obj.PenStyle);
    Canvas.Brush.Color:=CLXColorToVCLColor(obj.BrushColor);
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
}   end;
  rpMetaImage:
   begin
    // Inserting images to excel is not supported for now
{    Width:=round(obj.Width*dpix/TWIPS_PER_INCHESS);
    Height:=round(obj.Height*dpiy/TWIPS_PER_INCHESS);
    rec.Top:=PosY;
    rec.Left:=PosX;
    rec.Bottom:=rec.Top+Height-1;
    rec.Right:=rec.Left+Width-1;

    stream:=page.GetStream(obj);
    bitmap:=TBitmap.Create;
    try
     bitmap.PixelFormat:=pf32bit;
     bitmap.HandleType:=bmDIB;
     if GetJPegInfo(stream,bitmapwidth,bitmapheight) then
     begin
      jpegimage:=TJPegImage.Create;
      try
       jpegimage.LoadFromStream(stream);
       bitmap.Assign(jpegimage);
      finally
       jpegimage.free;
      end;
     end
     else
     // Looks if it's a jpeg image
      bitmap.LoadFromStream(stream);
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
        recsrc.Left:=0;
        recsrc.Top:=0;
        recsrc.Right:=rec.Right-rec.Left;
        recsrc.Bottom:=rec.Bottom-rec.Top;
        DrawBitmap(Canvas,bitmap,rec,recsrc);
       end;
      rpDrawTile:
       begin
        // Set clip region
        oldrgn:=CreateRectRgn(0,0,2,2);
        aresult:=GetClipRgn(Canvas.Handle,oldrgn);
        newrgn:=CreateRectRgn(rec.Left,rec.Top,rec.Right,rec.Bottom);
        SelectClipRgn(Canvas.handle,newrgn);
        DrawBitmapMosaicSlow(Canvas,rec,bitmap);
        if aresult=0 then
         SelectClipRgn(Canvas.handle,0)
        else
         SelectClipRgn(Canvas.handle,oldrgn);
       end;
     end;
    finally
     bitmap.Free;
    end;}
   end;
 end;
end;
{$ENDIF}


procedure DoExportMetafile(metafile:TRpMetafileReport;filename:string;
 aform:TFRpExcelProgress;visible,allpages:boolean;frompage,topage:integer;
  onesheet:Boolean);
{$IFNDEF DOTNETD}
var
 i:integer;
 j:integer;
 apage:TRpMetafilePage;
 dpix,dpiy:integer;
 mmfirst,mmlast:DWORD;
 difmilis:int64;
 wb:Variant;
 sh:Variant;
 Excel:Variant;
 columns:TStringList;
 rows:TStringList;
 index:integer;
 topstring,leftstring:string;
 shcount:integer;
 FontName:String;
 FontSize:integer;
 rowinit:integer;
 version:string;
{$ENDIF}
begin
{$IFNDEF DOTNETD}
 dpix:=Screen.PixelsPerInch;
 dpiy:=dpix;
 // Get the time
 mmfirst:=TimeGetTime;
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
 // Distribute in rows and columns
 columns:=TStringList.Create;
 rows:=TStringList.Create;
 try
   rows.sorted:=true;
   columns.sorted:=true;
   // Creates the excel file
   Excel:=CreateOleObject('excel.application');
   Excel.Visible:=Visible;
   wb:=Excel.Workbooks.Add;
   shcount:=1;
   sh:=wb.Worksheets.item[shcount];
   FontName:=sh.Cells.Font.Name;
   FontSize:=sh.Cells.Font.Size;

   for i:=frompage to topage do
   begin
    apage:=metafile.Pages[i];
    for j:=0 to apage.ObjectCount-1 do
    begin
     if apage.Objects[j].Metatype in [rpMetaText,rpMetaImage] then
     begin
      leftstring:=FormatCurr('0000000000',apage.Objects[j].Left/XLS_PRECISION);
      index:=columns.IndexOf(leftstring);
      if index<0 then
       columns.Add(leftstring);
     end;
    end;
   end;
   rowinit:=0;
   for i:=frompage to topage do
   begin
    if not onesheet then
    begin
     rowinit:=0;
     if wb.Worksheets.Count<shcount then
      wb.Worksheets.Add(NULL,wb.Worksheets.Item[wb.Worksheets.Count],1,NULL);
     sh:=wb.Worksheets.item[shcount];
    end
    else
     rowinit:=rowinit+rows.count;
    inc(shcount);
    apage:=metafile.Pages[i];
    rows.clear;
    for j:=0 to apage.ObjectCount-1 do
    begin
     if apage.Objects[j].Metatype in [rpMetaText,rpMetaImage] then
     begin
      topstring:=FormatCurr('0000000000',apage.Objects[j].Top/XLS_PRECISION);
      index:=rows.IndexOf(topstring);
      if index<0 then
       rows.Add(topstring);
     end;
    end;

    for j:=0 to apage.ObjectCount-1 do
    begin
     PrintObject(sh,apage,apage.Objects[j],dpix,dpiy,true,
      rows,columns,FontName,FontSize,rowinit);
     if assigned(aform) then
     begin
      mmlast:=TimeGetTime;
      difmilis:=(mmlast-mmfirst);
      if difmilis>MILIS_PROGRESS then
      begin
       // Get the time
       mmfirst:=TimeGetTime;
       aform.LRecordCount.Caption:=SRpPage+':'+ IntToStr(i+1)+
         ' - '+SRpItem+':'+ IntToStr(j+1);
       Application.ProcessMessages;
       if aform.cancelled then
        Raise Exception.Create(SRpOperationAborted);
      end;
     end;
    end;
   end;
 finally
  columns.free;
  rows.free;
 end;
 if Length(Filename)>0 then
 begin
  if (UpperCase(ExtractFileExt(Filename))='.XLSX') then
   wb.SaveAs(Filename)
  else
  begin
   version:=Excel.Version;
   index:=Pos('.',version);
   if (index>=0) then
    version:=Copy(version,1,index-1);
   If StrToInt(version)<12 Then
    wb.SaveAs(Filename)
   else
    wb.SaveAs(Filename,56);
  end;
  wb.Close;
 end;
 if not visible then
  Excel.Quit;
 if assigned(aform) then
  aform.close;
{$ENDIF}
end;

function ExportMetafileToExcel (metafile:TRpMetafileReport; filename:string;
 showprogress,visible,allpages:boolean; frompage,topage:integer;
 onesheet:Boolean=false):boolean;
var
 dia:TFRpExcelProgress;
begin
 Result:=true;
 if Not ShowProgress then
 begin
  DoExportMetafile(metafile,filename,nil,visible,allpages,frompage,topage,onesheet);
  exit;
 end;
 dia:=TFRpExcelProgress.Create(Application);
 try
  dia.oldonidle:=Application.OnIdle;
  try
   dia.metafile:=metafile;
   dia.filename:=filename;
   dia.allpages:=allpages;
   dia.frompage:=frompage;
   dia.onesheet:=onesheet;
   dia.isvisible:=visible;
   dia.isxml:=false;
   dia.topage:=topage;
   Application.OnIdle:=dia.AppIdle;
   dia.ShowModal;
   Result:=Not dia.cancelled;
  finally
   Application.OnIdle:=dia.oldonidle;
  end;
 finally
  dia.free;
 end;
end;


procedure TFRpExcelProgress.FormCreate(Sender: TObject);
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

end;

procedure TFRpExcelProgress.AppIdle(Sender:TObject;var done:boolean);
begin
 cancelled:=false;
 Application.OnIdle:=nil;
 done:=false;
 LTittle.Caption:=tittle;
 LProcessing.Visible:=true;
 if isxml then
  DoExportMetafileXML(metafile,filename,self,allpages,frompage,topage,onesheet)
 else
  DoExportMetafile(metafile,filename,self,isvisible,allpages,frompage,topage,onesheet);
end;


procedure TFRpExcelProgress.BCancelClick(Sender: TObject);
begin
 cancelled:=true;
end;




procedure TFRpExcelProgress.BOKClick(Sender: TObject);
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

procedure TFRpExcelProgress.FormShow(Sender: TObject);
begin
 if BOK.Visible then
 begin
  EFrom.Text:=IntToStr(FromPage);
  ETo.Text:=IntToStr(ToPage);
 end;
end;

function FloatToStrXML(pValue: Double): string;
var
  sVal: string;
  i: integer;
begin
  sVal := FloatToStr(pValue);
  for i := 1 to Length(sVal) do
  begin
    {$IFDEF DELPHI2009UP}
    if sVal[i] = FormatSettings.DecimalSeparator then
    {$ELSE}
    if sVal[i] = DecimalSeparator then
    {$ENDIF}
      sVal[i] := '.';
  end;
  Result := sVal;
end;

function EscapeXML(const sText: string): string;
var
  i: integer;
  sChar: char;
begin
  Result := '';
  for i := 1 to Length(sText) do
  begin
    sChar := sText[i];
    case sChar of
      '&': Result := Result + '&amp;';
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '"': Result := Result + '&quot;';
      '''': Result := Result + '&apos;';
    else
      Result := Result + sChar;
    end;
  end;
end;

function GetDecimalPlaces(const S: string): Integer;
var
  SepPos, i: Integer;
  DecSep: Char;
begin
  Result := 0;
  {$IFDEF DELPHI2009UP}
  DecSep := FormatSettings.DecimalSeparator;
  {$ELSE}
  DecSep := DecimalSeparator;
  {$ENDIF}
  SepPos := Pos(DecSep, S);
  if SepPos > 0 then
  begin
    for i := SepPos + 1 to Length(S) do
    begin
      if S[i] in ['0'..'9'] then
        Inc(Result)
      else
        Break;
    end;
  end;
end;

function GetStyleXML(StyleID, FontName: string; FontSize: integer; FontColor: TColor; Bold, Italic, Underline, Strikeout: boolean; Alignment: integer; WordWrap: boolean; FormatType: integer): string;
var
  S: string;
  i: integer;
begin
  S := '  <Style ss:ID="' + StyleID + '">'#13#10;
  
  // Alignment
  S := S + '   <Alignment ss:Vertical="Bottom"';
  if WordWrap then
    S := S + ' ss:WrapText="1"';
  case Alignment of
    1: S := S + ' ss:Horizontal="Left"';
    2: S := S + ' ss:Horizontal="Center"';
    3: S := S + ' ss:Horizontal="Right"';
  end;
  S := S + '/>'#13#10;
  
  // Font
  S := S + '   <Font ss:FontName="' + FontName + '" ss:Size="' + IntToStr(FontSize) + '"';
  if FontColor <> clBlack then
    S := S + ' ss:Color="#' + Format('%.2x%.2x%.2x', [GetRValue(FontColor), GetGValue(FontColor), GetBValue(FontColor)]) + '"';
  if Bold then
    S := S + ' ss:Bold="1"';
  if Italic then
    S := S + ' ss:Italic="1"';
  if Underline then
    S := S + ' ss:Underline="Single"';
  if Strikeout then
    S := S + ' ss:StrikeThrough="1"';
  S := S + '/>'#13#10;
  
  // NumberFormat
  if (FormatType >= 1) and (FormatType <= 10) then
  begin
    S := S + '   <NumberFormat ss:Format="#,##0.';
    for i := 1 to FormatType do
      S := S + '0';
    S := S + '"/>'#13#10;
  end
  else if FormatType = 100 then
    S := S + '   <NumberFormat ss:Format="dd/mm/yyyy;@"/>'#13#10;
    
  S := S + '  </Style>';
  Result := S;
end;

function RegisterStyle(StylesList, StylesXML: TStringList; FontName: string; FontSize: integer; FontColor: TColor; Bold, Italic, Underline, Strikeout: boolean; Alignment: integer; WordWrap: boolean; FormatType: integer): string;
var
  Sig, StyleID: string;
begin
  Sig := FontName + '_' + IntToStr(FontSize) + '_' + IntToHex(FontColor, 8) + '_' +
    IntToStr(Ord(Bold)) + '_' + IntToStr(Ord(Italic)) + '_' + IntToStr(Ord(Underline)) + '_' +
    IntToStr(Ord(Strikeout)) + '_' + IntToStr(Alignment) + '_' + IntToStr(Ord(WordWrap)) + '_' +
    IntToStr(FormatType);
  StyleID := StylesList.Values[Sig];
  if StyleID = '' then
  begin
    StyleID := 'sStyle' + IntToStr(StylesList.Count + 1);
    StylesList.Add(Sig + '=' + StyleID);
    StylesXML.Add(GetStyleXML(StyleID, FontName, FontSize, FontColor, Bold, Italic, Underline, Strikeout, Alignment, WordWrap, FormatType));
  end;
  Result := StyleID;
end;

procedure DoExportMetafileXML(metafile:TRpMetafileReport;filename:string;
  aform:TFRpExcelProgress;allpages:boolean;frompage,topage:integer;
   onesheet:Boolean);
var
  XMLList: TStringList;
  StylesList: TStringList;
  StylesXML: TStringList;
  Grid: array of TXMLCell;
  RowCount, ColCount: Integer;
  Columns: TStringList;
  Rows: TStringList;
  i, j, r, c: Integer;
  apage: TRpMetafilePage;
  leftstring, topstring: string;
  index: Integer;
  arow, acolumn: Integer;
  aansitext: string;
  number: Double;
  isanumber: boolean;
  isadate: boolean;
  adate: TDateTime;
  FontName: string;
  FontSize: Integer;
  FontColor: TColor;
  afontstyle: TFontStyles;
  Bold, Italic, Underline, Strikeout: boolean;
  Alignment: Integer;
  WordWrap: boolean;
  FormatType: Integer;
  StyleID: string;
  cell: TXMLCell;
  idx: Integer;
  HasCells: boolean;
  mmfirst, mmlast: DWORD;
  difmilis: int64;
  DefaultFontName: string;
  DefaultFontSize: Integer;
begin
  DefaultFontName := 'Calibri';
  DefaultFontSize := 11;
  
  mmfirst := TimeGetTime;
  
  if allpages then
  begin
    metafile.RequestPage(MAX_PAGECOUNT);
    frompage := 0;
    topage := metafile.CurrentPageCount - 1;
  end
  else
  begin
    frompage := frompage - 1;
    topage := topage - 1;
    metafile.RequestPage(topage);
    if topage > metafile.CurrentPageCount - 1 then
      topage := metafile.CurrentPageCount - 1;
  end;

  Columns := TStringList.Create;
  Rows := TStringList.Create;
  StylesList := TStringList.Create;
  StylesXML := TStringList.Create;
  XMLList := TStringList.Create;
  try
    Columns.Sorted := True;
    Rows.Sorted := True;
    
    // Find all columns
    for i := frompage to topage do
    begin
      apage := metafile.Pages[i];
      for j := 0 to apage.ObjectCount - 1 do
      begin
        if apage.Objects[j].Metatype in [rpMetaText, rpMetaImage] then
        begin
          leftstring := FormatCurr('0000000000', apage.Objects[j].Left / XLS_PRECISION);
          index := Columns.IndexOf(leftstring);
          if index < 0 then
            Columns.Add(leftstring);
        end;
      end;
    end;
    
    ColCount := Columns.Count;
    if ColCount < 1 then
      ColCount := 1;

    // XML Headers
    XMLList.Add('<?xml version="1.0" encoding="Windows-1252"?>');
    XMLList.Add('<?mso-application progid="Excel.Sheet"?>');
    XMLList.Add('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"');
    XMLList.Add(' xmlns:o="urn:schemas-microsoft-com:office:office"');
    XMLList.Add(' xmlns:x="urn:schemas-microsoft-com:office:excel"');
    XMLList.Add(' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"');
    XMLList.Add(' xmlns:html="http://www.w3.org/TR/REC-html40">');
    XMLList.Add(' <DocumentProperties xmlns="urn:schemas-microsoft-com:office:office">');
    XMLList.Add('  <Author>GiroSII</Author>');
    XMLList.Add('  <Created>' + FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.000', Now) + '</Created>');
    XMLList.Add('  <Version>16.00</Version>');
    XMLList.Add(' </DocumentProperties>');
    
    // Pass 1: Style registration
    for i := frompage to topage do
    begin
      apage := metafile.Pages[i];
      for j := 0 to apage.ObjectCount - 1 do
      begin
        if apage.Objects[j].Metatype = rpMetaText then
        begin
          aansitext := apage.GetText(apage.Objects[j]);
          
          FontName := apage.GetWFontName(apage.Objects[j]);
          FontSize := apage.Objects[j].FontSize;
          FontColor := CLXColorToVCLColor(apage.Objects[j].FontColor);
          afontstyle := CLXIntegerToFontStyle(apage.Objects[j].FontStyle);
          Bold := fsBold in afontstyle;
          Italic := fsItalic in afontstyle;
          Underline := fsUnderline in afontstyle;
          Strikeout := fsStrikeout in afontstyle;
          
          Alignment := 0;
          if (apage.Objects[j].AlignMent and AlignmentFlags_AlignHCenter) > 0 then
            Alignment := 2
          else if (apage.Objects[j].AlignMent and AlignmentFlags_AlignLEFT) > 0 then
            Alignment := 1
          else if (apage.Objects[j].AlignMent and AlignmentFlags_AlignRight) > 0 then
            Alignment := 3;
            
          WordWrap := apage.Objects[j].WordWrap;
          
          FormatType := 0;
          isanumber := VarTryStrToFloat(aansitext, number);
          isadate := False;
          adate := 0;
          if isanumber then
            FormatType := GetDecimalPlaces(aansitext)
          else
          begin
            isadate := VarTryStrToDate(aansitext, adate);
            if isadate then
              FormatType := 100;
          end;
            
          RegisterStyle(StylesList, StylesXML, FontName, FontSize, FontColor, Bold, Italic, Underline, Strikeout, Alignment, WordWrap, FormatType);
        end;
      end;
    end;

    XMLList.Add(' <Styles>');
    XMLList.Add('  <Style ss:ID="Default" ss:Name="Normal">');
    XMLList.Add('   <Alignment ss:Vertical="Bottom"/>');
    XMLList.Add('   <Borders/>');
    XMLList.Add('   <Font ss:FontName="' + DefaultFontName + '" x:Family="Swiss" ss:Size="' + IntToStr(DefaultFontSize) + '" ss:Color="#000000"/>');
    XMLList.Add('   <Interior/>');
    XMLList.Add('   <NumberFormat/>');
    XMLList.Add('   <Protection/>');
    XMLList.Add('  </Style>');
    XMLList.Add(StylesXML.Text);
    XMLList.Add(' </Styles>');

    if onesheet then
    begin
      Rows.Clear;
      for i := frompage to topage do
      begin
        apage := metafile.Pages[i];
        for j := 0 to apage.ObjectCount - 1 do
        begin
          if apage.Objects[j].Metatype = rpMetaText then
          begin
            topstring := FormatCurr('0000000000', apage.Objects[j].Top / XLS_PRECISION);
            index := Rows.IndexOf(topstring);
            if index < 0 then
              Rows.Add(topstring);
          end;
        end;
      end;
      
      RowCount := Rows.Count;
      if RowCount < 1 then RowCount := 1;
      
      SetLength(Grid, RowCount * ColCount);
      for idx := 0 to RowCount * ColCount - 1 do
        Grid[idx] := nil;
        
      for i := frompage to topage do
      begin
        apage := metafile.Pages[i];
        for j := 0 to apage.ObjectCount - 1 do
        begin
          if apage.Objects[j].Metatype = rpMetaText then
          begin
            topstring := FormatCurr('0000000000', apage.Objects[j].Top / XLS_PRECISION);
            leftstring := FormatCurr('0000000000', apage.Objects[j].Left / XLS_PRECISION);
            arow := Rows.IndexOf(topstring) + 1;
            acolumn := Columns.IndexOf(leftstring) + 1;
            
            aansitext := apage.GetText(apage.Objects[j]);
            
            FontName := apage.GetWFontName(apage.Objects[j]);
            FontSize := apage.Objects[j].FontSize;
            FontColor := CLXColorToVCLColor(apage.Objects[j].FontColor);
            afontstyle := CLXIntegerToFontStyle(apage.Objects[j].FontStyle);
            Bold := fsBold in afontstyle;
            Italic := fsItalic in afontstyle;
            Underline := fsUnderline in afontstyle;
            Strikeout := fsStrikeout in afontstyle;
            
            Alignment := 0;
            if (apage.Objects[j].AlignMent and AlignmentFlags_AlignHCenter) > 0 then
              Alignment := 2
            else if (apage.Objects[j].AlignMent and AlignmentFlags_AlignLEFT) > 0 then
              Alignment := 1
            else if (apage.Objects[j].AlignMent and AlignmentFlags_AlignRight) > 0 then
              Alignment := 3;
              
            WordWrap := apage.Objects[j].WordWrap;
            
            FormatType := 0;
            isanumber := VarTryStrToFloat(aansitext, number);
            isadate := False;
            adate := 0;
            if isanumber then
              FormatType := GetDecimalPlaces(aansitext)
            else
            begin
              isadate := VarTryStrToDate(aansitext, adate);
              if isadate then
                FormatType := 100;
            end;
            
            StyleID := RegisterStyle(StylesList, StylesXML, FontName, FontSize, FontColor, Bold, Italic, Underline, Strikeout, Alignment, WordWrap, FormatType);
            
            cell := TXMLCell.Create;
            cell.RowIndex := arow;
            cell.ColIndex := acolumn;
            cell.StyleID := StyleID;
            if isanumber then
            begin
              cell.DataType := 'Number';
              cell.Value := FloatToStrXML(number);
            end
            else if isadate then
            begin
              cell.DataType := 'DateTime';
              cell.Value := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.000', adate);
            end
            else
            begin
              cell.DataType := 'String';
              cell.Value := EscapeXML(aansitext);
            end;
            
            idx := (arow - 1) * ColCount + (acolumn - 1);
            if Grid[idx] <> nil then
              Grid[idx].Free;
            Grid[idx] := cell;
          end;
        end;
      end;
      
      XMLList.Add(' <Worksheet ss:Name="Relatorio">');
      XMLList.Add('  <Table>');
      
      for r := 1 to RowCount do
      begin
        HasCells := False;
        for c := 1 to ColCount do
        begin
          if Grid[(r - 1) * ColCount + (c - 1)] <> nil then
          begin
            HasCells := True;
            break;
          end;
        end;
        
        if HasCells then
        begin
          XMLList.Add('   <Row ss:Index="' + IntToStr(r) + '">');
          for c := 1 to ColCount do
          begin
            cell := Grid[(r - 1) * ColCount + (c - 1)];
            if cell <> nil then
            begin
              XMLList.Add('    <Cell ss:Index="' + IntToStr(c) + '" ss:StyleID="' + cell.StyleID + '">');
              XMLList.Add('     <Data ss:Type="' + cell.DataType + '">' + cell.Value + '</Data>');
              XMLList.Add('    </Cell>');
            end;
          end;
          XMLList.Add('   </Row>');
        end;
      end;
      
      XMLList.Add('  </Table>');
      XMLList.Add(' </Worksheet>');
      
      for idx := 0 to RowCount * ColCount - 1 do
        if Grid[idx] <> nil then
          Grid[idx].Free;
      Grid := nil;
    end
    else
    begin
      for i := frompage to topage do
      begin
        apage := metafile.Pages[i];
        Rows.Clear;
        for j := 0 to apage.ObjectCount - 1 do
        begin
          if apage.Objects[j].Metatype = rpMetaText then
          begin
            topstring := FormatCurr('0000000000', apage.Objects[j].Top / XLS_PRECISION);
            index := Rows.IndexOf(topstring);
            if index < 0 then
              Rows.Add(topstring);
          end;
        end;
        
        RowCount := Rows.Count;
        if RowCount < 1 then RowCount := 1;
        
        SetLength(Grid, RowCount * ColCount);
        for idx := 0 to RowCount * ColCount - 1 do
          Grid[idx] := nil;
          
        for j := 0 to apage.ObjectCount - 1 do
        begin
          if apage.Objects[j].Metatype = rpMetaText then
          begin
            topstring := FormatCurr('0000000000', apage.Objects[j].Top / XLS_PRECISION);
            leftstring := FormatCurr('0000000000', apage.Objects[j].Left / XLS_PRECISION);
            arow := Rows.IndexOf(topstring) + 1;
            acolumn := Columns.IndexOf(leftstring) + 1;
            
            aansitext := apage.GetText(apage.Objects[j]);
            
            FontName := apage.GetWFontName(apage.Objects[j]);
            FontSize := apage.Objects[j].FontSize;
            FontColor := CLXColorToVCLColor(apage.Objects[j].FontColor);
            afontstyle := CLXIntegerToFontStyle(apage.Objects[j].FontStyle);
            Bold := fsBold in afontstyle;
            Italic := fsItalic in afontstyle;
            Underline := fsUnderline in afontstyle;
            Strikeout := fsStrikeout in afontstyle;
            
            Alignment := 0;
            if (apage.Objects[j].AlignMent and AlignmentFlags_AlignHCenter) > 0 then
              Alignment := 2
            else if (apage.Objects[j].AlignMent and AlignmentFlags_AlignLEFT) > 0 then
              Alignment := 1
            else if (apage.Objects[j].AlignMent and AlignmentFlags_AlignRight) > 0 then
              Alignment := 3;
              
            WordWrap := apage.Objects[j].WordWrap;
            
            FormatType := 0;
            isanumber := VarTryStrToFloat(aansitext, number);
            isadate := False;
            adate := 0;
            if isanumber then
              FormatType := GetDecimalPlaces(aansitext)
            else
            begin
              isadate := VarTryStrToDate(aansitext, adate);
              if isadate then
                FormatType := 100;
            end;
            
            StyleID := RegisterStyle(StylesList, StylesXML, FontName, FontSize, FontColor, Bold, Italic, Underline, Strikeout, Alignment, WordWrap, FormatType);
            
            cell := TXMLCell.Create;
            cell.RowIndex := arow;
            cell.ColIndex := acolumn;
            cell.StyleID := StyleID;
            if isanumber then
            begin
              cell.DataType := 'Number';
              cell.Value := FloatToStrXML(number);
            end
            else if isadate then
            begin
              cell.DataType := 'DateTime';
              cell.Value := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.000', adate);
            end
            else
            begin
              cell.DataType := 'String';
              cell.Value := EscapeXML(aansitext);
            end;
            
            idx := (arow - 1) * ColCount + (acolumn - 1);
            if Grid[idx] <> nil then
              Grid[idx].Free;
            Grid[idx] := cell;
          end;
        end;
        
        XMLList.Add(' <Worksheet ss:Name="Pagina_' + IntToStr(i + 1 - frompage) + '">');
        XMLList.Add('  <Table>');
        
        for r := 1 to RowCount do
        begin
          HasCells := False;
          for c := 1 to ColCount do
          begin
            if Grid[(r - 1) * ColCount + (c - 1)] <> nil then
            begin
              HasCells := True;
              break;
            end;
          end;
          
          if HasCells then
          begin
            XMLList.Add('   <Row ss:Index="' + IntToStr(r) + '">');
            for c := 1 to ColCount do
            begin
              cell := Grid[(r - 1) * ColCount + (c - 1)];
              if cell <> nil then
              begin
                XMLList.Add('    <Cell ss:Index="' + IntToStr(c) + '" ss:StyleID="' + cell.StyleID + '">');
                XMLList.Add('     <Data ss:Type="' + cell.DataType + '">' + cell.Value + '</Data>');
                XMLList.Add('    </Cell>');
              end;
            end;
            XMLList.Add('   </Row>');
          end;
        end;
        
        XMLList.Add('  </Table>');
        XMLList.Add(' </Worksheet>');
        
        for idx := 0 to RowCount * ColCount - 1 do
          if Grid[idx] <> nil then
            Grid[idx].Free;
        Grid := nil;
      end;
    end;
    XMLList.Add('</Workbook>');
    
    XMLList.SaveToFile(filename);
  finally
    Columns.Free;
    Rows.Free;
    StylesList.Free;
    StylesXML.Free;
    XMLList.Free;
  end;
  
  if Assigned(aform) then
    aform.Close;
end;

procedure AbrirPlanilha(pCaminho: String);
var
  ExcelApp: Variant;
  bAberto: Boolean;
begin
  bAberto := False;
  try
    ExcelApp := CreateOleObject('Excel.Application');
    ExcelApp.Workbooks.Open(pCaminho);
    ExcelApp.Visible := True;
    bAberto := True;
  except
    bAberto := False;
  end;

  if not bAberto then
  begin
    ShellExecute(0, 'open', PChar(pCaminho), nil, nil, SW_SHOWNORMAL);
  end;
end;

function ExportMetafileToXMLSpreadsheet (metafile:TRpMetafileReport; filename:string;
 showprogress,allpages:boolean; frompage,topage:integer;
 onesheet:Boolean=false; openfile:Boolean=true):boolean;
var
 dia:TFRpExcelProgress;
begin
 Result:=true;
 if Not ShowProgress then
 begin
  DoExportMetafileXML(metafile,filename,nil,allpages,frompage,topage,onesheet);
  if openfile then
    AbrirPlanilha(filename);
  exit;
 end;
 dia:=TFRpExcelProgress.Create(Application);
 try
  dia.oldonidle:=Application.OnIdle;
  try
   dia.metafile:=metafile;
   dia.filename:=filename;
   dia.allpages:=allpages;
   dia.frompage:=frompage;
   dia.onesheet:=onesheet;
   dia.isvisible:=false;
   dia.isxml:=true;
   dia.topage:=topage;
   Application.OnIdle:=dia.AppIdle;
   dia.ShowModal;
   Result:=Not dia.cancelled;
   if Result and openfile then
     AbrirPlanilha(filename);
  finally
   Application.OnIdle:=dia.oldonidle;
  end;
 finally
  dia.free;
 end;
end;

end.

