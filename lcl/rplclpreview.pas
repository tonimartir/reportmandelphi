{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpvpreview                                      }
{       VCL Preview the report                          }
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


unit rplclpreview;

interface

{$I rpconf.inc}


uses
  SysUtils,
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
{$IFDEF USEVARIANTS}
  Types,
{$ENDIF}
{$IFDEF DELPHI2009UP}
 System.Actions, System.ImageList,
{$ELSE}
{$ENDIF}
  Classes, Graphics, Controls, Forms, Dialogs,LCLType,LCLIntf,
  StdCtrls,rpmetafile, ComCtrls,rphtmldriver,rppreviewcontrol,
  rplcldriver, ExtCtrls,Menus,rptypes,rptextdriver,rpsvgdriver,
  rpcsvdriver,rpgraphutilslcl,rppreviewmetalcl,rpbasereport,rpreport,rppagesetuplcl,
  ActnList, ImgList,Printers,rpmdconsts, ToolWin, rpmaskedit,rpmunits;

type
  TFRpVPreview = class(TForm)
    BToolBar: TToolBar;
    ImageList1: TImageList;
    ActionList1: TActionList;
    AFirst: TAction;
    APrevious: TAction;
    ANext: TAction;
    ALast: TAction;
    ToolButton1: TToolButton;
    ToolButton2: TToolButton;
    EPageNum: TRpMaskEdit;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    APrint: TAction;
    ToolButton6: TToolButton;
    ASave: TAction;
    SaveDialog1: TSaveDialog;
    ToolButton7: TToolButton;
    ACancel: TAction;
    BCancel: TButton;
    AExit: TAction;
    BExit: TToolButton;
    ToolButton8: TToolButton;
    AParams: TAction;
    AScale100: TAction;
    AScaleWide: TAction;
    AScaleFull: TAction;
    ToolButton11: TToolButton;
    ToolButton12: TToolButton;
    ToolButton14: TToolButton;
    AScaleLess: TAction;
    AScaleMore: TAction;
    ToolButton15: TToolButton;
    ToolButton5: TToolButton;
    AMailTo: TAction;
    ToolButton9: TToolButton;
    APageSetup: TAction;
    ToolButton10: TToolButton;
    ToolButton16: TToolButton;
    ToolButton17: TToolButton;
    ToolButton18: TToolButton;
    ToolButton13: TToolButton;
    MEntireMenu: TPopupMenu;
    MEntire1: TMenuItem;
    MEntire2: TMenuItem;
    MEntire3: TMenuItem;
    MEntire4: TMenuItem;
    MEntire6: TMenuItem;
    MEntire8: TMenuItem;
    MEntire9: TMenuItem;
    MEntire10: TMenuItem;
    MEntire12: TMenuItem;
    MEntire15: TMenuItem;
    MEntire18: TMenuItem;
    MEntire16: TMenuItem;
    MEntire20: TMenuItem;
    MEntire24: TMenuItem;
    MEntire30: TMenuItem;
    MEntire48: TMenuItem;
    MLeftRight: TMenuItem;
    ToolButton19: TToolButton;
    ToolButton20: TToolButton;
    ESearch: TRpMaskEdit;
    AFind: TAction;
    procedure FormCreate(Sender: TObject);
    procedure AFirstExecute(Sender: TObject);
    procedure ANextExecute(Sender: TObject);
    procedure APreviousExecute(Sender: TObject);
    procedure ALastExecute(Sender: TObject);
    procedure APrintExecute(Sender: TObject);
    procedure ASaveExecute(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure ACancelExecute(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure AExitExecute(Sender: TObject);
    procedure AParamsExecute(Sender: TObject);
    procedure AScale100Execute(Sender: TObject);
    procedure AScaleWideExecute(Sender: TObject);
    procedure AScaleLessExecute(Sender: TObject);
    procedure AScaleMoreExecute(Sender: TObject);
    procedure FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure EPageNumKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure AMailToExecute(Sender: TObject);
    procedure APageSetupExecute(Sender: TObject);
    procedure MEntire1Click(Sender: TObject);
    procedure AScaleFullExecute(Sender: TObject);
    procedure MEntirePagePopup(Sender: TObject);
    procedure MLeftRightClick(Sender: TObject);
    procedure MEntireMenuPopup(Sender: TObject);
    procedure ESearchKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure AFindExecute(Sender: TObject);
    procedure ESearchChange(Sender: TObject);
  private
    { Private declarations }
    printed:boolean;
    fpreviewcontrol:TRpPreviewMeta;
    cancelled:boolean;
    textchanged:boolean;
    procedure AppIdle(Sender:TObject;var done:boolean);
    procedure RepProgress(Sender:TObject;records,pagecount:integer;var docancel:boolean);
    procedure DisableControls(enablebar:boolean);
    procedure EnableControls;
    procedure SetPreviewControl(avalue:TRpPreviewMeta);
    procedure OnPageDrawn(prm:TRpPreviewMeta);
    procedure FindNext;
  public
    { Public declarations }
    property PreviewControl:TRpPreviewmeta read fpreviewcontrol write SetPreviewControl;
  end;


function ShowPreview(previewcontrol:TRpPreviewMeta;
 caption:string):boolean;

implementation

uses rprflclparams, rppdfdriver
{$IFDEF MSWINDOWS}
 ,LazUTF8
{$ELSE}
 ,process, FileUtil
{$ENDIF}
 ;

{$R *.lfm}

const
 MAIL_TEMP_FOLDER='reportman-mail';

// Folder for the attachments of the mails sent from the preview. On Linux
// the mail client reads the attachment after the preview has returned, so
// the files can't be deleted right away: the ones older than a day are
// removed here, on the next mail
function MailTempDir:string;
var
 sr:TSearchRec;
begin
 Result:=IncludeTrailingPathDelimiter(GetTempDir(false))+MAIL_TEMP_FOLDER;
 ForceDirectories(Result);
 Result:=IncludeTrailingPathDelimiter(Result);
 if FindFirst(Result+'*',faAnyFile,sr)=0 then
 try
  repeat
   if ((sr.Attr and faDirectory)=0) and
    (Now-FileDateToDateTime(sr.Time)>1) then
    SysUtils.DeleteFile(Result+sr.Name);
  until FindNext(sr)<>0;
 finally
  SysUtils.FindClose(sr);
 end;
end;

{$IFDEF MSWINDOWS}
// Simple MAPI, as rptypes.SendMail in the VCL (its Mapi unit does not exist
// in FPC). The string fields are PWideChar for MAPISendMailW and PAnsiChar
// (ANSI code page) for MAPISendMail
type
 PRpMapiRecipDesc=^TRpMapiRecipDesc;
 TRpMapiRecipDesc=record
  ulReserved:Cardinal;
  ulRecipClass:Cardinal;
  lpszName:Pointer;
  lpszAddress:Pointer;
  ulEIDSize:Cardinal;
  lpEntryID:Pointer;
 end;
 PRpMapiFileDesc=^TRpMapiFileDesc;
 TRpMapiFileDesc=record
  ulReserved:Cardinal;
  flFlags:Cardinal;
  nPosition:Cardinal;
  lpszPathName:Pointer;
  lpszFileName:Pointer;
  lpFileType:Pointer;
 end;
 TRpMapiMessage=record
  ulReserved:Cardinal;
  lpszSubject:Pointer;
  lpszNoteText:Pointer;
  lpszMessageType:Pointer;
  lpszDateReceived:Pointer;
  lpszConversationID:Pointer;
  flFlags:Cardinal;
  lpOriginator:PRpMapiRecipDesc;
  nRecipCount:Cardinal;
  lpRecips:PRpMapiRecipDesc;
  nFileCount:Cardinal;
  lpFiles:PRpMapiFileDesc;
 end;
 TRpMapiSendMail=function(lhSession:PtrUInt;ulUIParam:PtrUInt;
  var lpMessage:TRpMapiMessage;flFlags:Cardinal;ulReserved:Cardinal):Cardinal;stdcall;

const
 RP_MAPI_TO=1;
 RP_MAPI_DIALOG=8;
 RP_MAPI_USER_ABORT=1;

var
 MapiModule:HMODULE=0;

function MapiError(const detail:string):string;
begin
 Result:=string(TranslateStr(1236,
  'One or more unspecified errors occurred; no message was sent.'))+detail;
end;

procedure RpSendMail(const destination,subject,body,filename,attachname:string);
var
 sendw,senda:TRpMapiSendMail;
 amessage:TRpMapiMessage;
 recip:TRpMapiRecipDesc;
 afile:TRpMapiFileDesc;
 wdest,waddress,wsubject,wbody,wfile,wname:UnicodeString;
 adest,aaddress,asubject,abody,afilen,aname:string;
 res:Cardinal;
begin
 // Kept loaded, as the VCL does: some MAPI providers fail when unloaded
 if MapiModule=0 then
  MapiModule:=LoadLibrary('mapi32.dll');
 if MapiModule=0 then
  Raise Exception.Create(MapiError(' (mapi32.dll)'));
 sendw:=TRpMapiSendMail(GetProcAddress(MapiModule,'MAPISendMailW'));
 senda:=TRpMapiSendMail(GetProcAddress(MapiModule,'MAPISendMail'));
 if (not Assigned(sendw)) and (not Assigned(senda)) then
  Raise Exception.Create(MapiError(' (MAPISendMail)'));
 amessage:=Default(TRpMapiMessage);
 recip:=Default(TRpMapiRecipDesc);
 afile:=Default(TRpMapiFileDesc);
 recip.ulRecipClass:=RP_MAPI_TO;
 afile.nPosition:=$FFFFFFFF;
 if Assigned(sendw) then
 begin
  wdest:=UTF8Decode(destination);
  waddress:=UTF8Decode('SMTP:'+destination);
  wsubject:=UTF8Decode(subject);
  wbody:=UTF8Decode(body);
  if Length(wbody)<1 then
   wbody:=' ';
  wfile:=UTF8Decode(filename);
  wname:=UTF8Decode(attachname);
  if Length(wsubject)>0 then
   amessage.lpszSubject:=PWideChar(wsubject);
  amessage.lpszNoteText:=PWideChar(wbody);
  recip.lpszName:=PWideChar(wdest);
  recip.lpszAddress:=PWideChar(waddress);
  afile.lpszPathName:=PWideChar(wfile);
  afile.lpszFileName:=PWideChar(wname);
 end
 else
 begin
  adest:=UTF8ToWinCP(destination);
  aaddress:=UTF8ToWinCP('SMTP:'+destination);
  asubject:=UTF8ToWinCP(subject);
  abody:=UTF8ToWinCP(body);
  if Length(abody)<1 then
   abody:=' ';
  afilen:=UTF8ToWinCP(filename);
  aname:=UTF8ToWinCP(attachname);
  if Length(asubject)>0 then
   amessage.lpszSubject:=PAnsiChar(asubject);
  amessage.lpszNoteText:=PAnsiChar(abody);
  recip.lpszName:=PAnsiChar(adest);
  recip.lpszAddress:=PAnsiChar(aaddress);
  afile.lpszPathName:=PAnsiChar(afilen);
  afile.lpszFileName:=PAnsiChar(aname);
 end;
 if Length(destination)>0 then
 begin
  amessage.nRecipCount:=1;
  amessage.lpRecips:=@recip;
 end;
 amessage.nFileCount:=1;
 amessage.lpFiles:=@afile;
 if Assigned(sendw) then
  res:=sendw(0,0,amessage,RP_MAPI_DIALOG,0)
 else
  res:=senda(0,0,amessage,RP_MAPI_DIALOG,0);
 if (res<>0) and (res<>RP_MAPI_USER_ABORT) then
  Raise Exception.Create(MapiError(' Error: '+IntToStr(res)));
end;
{$ELSE}
// xdg-email opens a new message in the user's mail client. It may not
// return until the client is closed (Thunderbird not running yet), so it
// runs in a thread
type
 TRpMailClientThread=class(TThread)
 private
  FExecutable:string;
  FParams:TStringList;
  FExitCode:integer;
  procedure ShowError;
 protected
  procedure Execute;override;
 public
  constructor Create(const AExecutable:string;AParams:TStrings);
  destructor Destroy;override;
 end;

constructor TRpMailClientThread.Create(const AExecutable:string;AParams:TStrings);
begin
 FExecutable:=AExecutable;
 FParams:=TStringList.Create;
 FParams.Assign(AParams);
 FreeOnTerminate:=true;
 inherited Create(false);
end;

destructor TRpMailClientThread.Destroy;
begin
 FParams.Free;
 inherited Destroy;
end;

procedure TRpMailClientThread.Execute;
var
 aprocess:TProcess;
begin
 aprocess:=TProcess.Create(nil);
 try
  aprocess.Executable:=FExecutable;
  aprocess.Parameters.Assign(FParams);
  aprocess.Options:=[poWaitOnExit];
  try
   aprocess.Execute;
   FExitCode:=aprocess.ExitStatus;
  except
   FExitCode:=-1;
  end;
 finally
  aprocess.Free;
 end;
 if FExitCode<>0 then
  Synchronize(ShowError);
end;

procedure TRpMailClientThread.ShowError;
begin
 RpShowMessage(WideFormat(TranslateStr(1652,
  'The mail client could not be opened (xdg-email exit code %d).'),[FExitCode]));
end;

procedure RpSendMail(const destination,subject,body,filename,attachname:string);
var
 aexe:string;
 aparams:TStringList;
begin
 // The attachment name is the name of the file
 aexe:=FindDefaultExecutablePath('xdg-email');
 if Length(aexe)<1 then
  Raise Exception.Create(string(TranslateStr(1653,
   'xdg-email was not found: install xdg-utils to send the report by mail.')));
 aparams:=TStringList.Create;
 try
  aparams.Add('--utf8');
  if Length(subject)>0 then
  begin
   aparams.Add('--subject');
   aparams.Add(subject);
  end;
  if Length(body)>0 then
  begin
   aparams.Add('--body');
   aparams.Add(body);
  end;
  aparams.Add('--attach');
  aparams.Add(filename);
  if Length(destination)>0 then
   aparams.Add(destination);
  TRpMailClientThread.Create(aexe,aparams);
 finally
  aparams.Free;
 end;
end;
{$ENDIF}

procedure TFRpVPreview.SetPreviewControl(avalue:TRpPreviewMeta);
begin
 fpreviewcontrol:=avalue;
 fpreviewcontrol.Width:=0;
 fpreviewcontrol.Height:=0;
 Fpreviewcontrol.Align:=alClient;
end;

function ShowPreview(previewcontrol:TRpPreviewMeta;
 caption:string):boolean;
var
 dia:TFRpVPreview;
  OldIdleHandler : TIdleEvent;
begin
 OldIdleHandler := Application.OnIdle;
 dia:=TFRpVPreview.Create(Application);
 try
  previewcontrol.OnWorkProgress:=dia.RepProgress;
  previewcontrol.OnPageDrawn:=dia.OnPageDrawn;
  dia.caption:=caption;
  dia.PreviewControl:=PreviewControl;
  dia.AParams.Enabled:=previewcontrol is TRpPreviewControl;
  dia.APageSetup.Enabled:=previewcontrol is TRpPreviewControl;
  if (previewcontrol is TRpPreviewControl) then
  begin
   previewcontrol.ShowPageMargins:=TRpPreviewControl(previewcontrol).Report.PreviewMargins;
  end;
  if previewcontrol.metafile.PreviewWindow=spwMaximized then
    dia.WindowState:=wsMaximized;
  // Never bigger than the screen (the lfm is 774x606 at 96 ppi)
  if dia.Width>Screen.WorkAreaWidth then
   dia.Width:=Screen.WorkAreaWidth;
  if dia.Height>Screen.WorkAreaHeight then
   dia.Height:=Screen.WorkAreaHeight;
  previewcontrol.OnWorkProgress:=dia.RepProgress;
  Application.OnIdle:=dia.AppIdle;
  dia.ShowModal;
  Result:=dia.printed;
 finally
    Application.OnIdle := OldIdleHandler;
  previewcontrol.OnWorkProgress:=nil;
  previewcontrol.OnPageDrawn:=nil;
  previewcontrol.Parent:=nil;
  dia.Free;
 end;
end;


procedure TFRpVPreview.AppIdle(Sender:TObject;var done:boolean);
begin
 Application.OnIdle:=nil;
 done:=false;
 try
  if Assigned(FPreviewControl) then
  begin
   DisableControls(true);
   try
    FPreviewControl.Parent:=self;
   finally
    EnableControls;
   end;
  end;
 finally
  if TRpPreviewControl(PreviewControl).Report.ErrorProcessing then
   Close;
 end;
{ except
  on E:Exception do
  begin
   Close;
   Raise;
  end;
 end;
}
end;

procedure TFRpVPreview.FormCreate(Sender: TObject);
begin
 // No ScaleToolBar: the LCL scales the buttons of the lfm after OnCreate
 // (they were twice as big at 192 ppi); the images of the list are made for
 // the ppi of the toolbar
 ImageList1.Scaled:=true;
  SaveDialog1.Filter:=SRpRepMetafile+'|*.rpmf|'+
   SRpPDFFile+'|*.pdf|'+
   SRpPDFFileUn+'|*.pdf|'+
   SRpPDFFile+' A/3|*.pdf|'+
   SRpPDFFileUn+' A/3|*.pdf|'+
   TranslateStr(881,'PNG Images')+'|*.png|'+
   // No Excel export nor self-executable metafile: both need the VCL
   SRpPlainFile+'|*.txt|'+
   SRpBitmapFile+'|*.bmp|'+
   SRpHtmlFile+'|*.html|'+
   SRpHtmlFileSingle+'|*.html|'+
   SRpSVGFile+'|*.svg|'+
   SRpCSVFile+'|*.csv|'+
   SRpTXTProFile+'|*.txt|'+
   SRpRepMetafileUn+'|*.rpmf';
 APrevious.ShortCut:=ShortCut(VK_PRIOR, []);
 ANext.ShortCut:=ShortCut(VK_NEXT, []);
 AFirst.ShortCut:=ShortCut(VK_HOME, []);
 ALast.ShortCut:=ShortCut(VK_END, []);

 APrint.ShortCut:=ShortCut(Ord('P'), [ssCtrl]);
 ASave.ShortCut:=ShortCut(Ord('S'), [ssCtrl]);
 AMailTo.ShortCut:=ShortCut(Ord('E'), [ssCtrl]);
 AFind.ShortCut:=ShortCut(VK_F3, []);

 APageSetup.ShortCut:=ShortCut(VK_F11, []);
 AParams.ShortCut:=ShortCut(VK_F12, []);

 AScale100.ShortCut:=ShortCut(VK_F6, []);
 AScaleWide.ShortCut:=ShortCut(VK_F7, []);
 AScaleFull.ShortCut:=ShortCut(VK_F8, []);
 AScaleLess.ShortCut:=ShortCut(VK_SUBTRACT, []);
 AScaleMore.ShortCut:=ShortCut(VK_ADD, []);


 Caption:=TranslateStr(215,Caption);
 SaveDialog1.Title:=TranslateStr(216,SaveDialog1.Title);
 ACancel.Caption:=TranslateStr(94,ACancel.Caption);
 ACancel.Hint:=TranslateStr(218,ACancel.Hint);
 APrint.Caption:=TranslateStr(52,APrint.Caption);
 APrint.Hint:=TranslateStr(53,APrint.Hint);
 ASave.Caption:=TranslateStr(46,ASave.Caption);
 ASave.Hint:=TranslateStr(217,ASave.Hint);
 AMailTo.Caption:=TranslateStr(1230,AMailTo.Caption);
 AMailTo.Hint:=TranslateStr(1231,AMailTo.Hint);
 AExit.Caption:=TranslateStr(44,AExit.Caption);
 AExit.Hint:=TranslateStr(219,AExit.Hint);
 AParams.Caption:=TranslateStr(135,Aparams.Caption);
 AParams.Hint:=TranslateStr(136,Aparams.Hint);
 AFirst.Caption:=TranslateStr(220,AFirst.Caption);
 AFirst.Hint:=TranslateStr(221,AFirst.Hint);
 APrevious.Caption:=TranslateStr(222,APrevious.Caption);
 APrevious.Hint:=TranslateStr(223,APrevious.Hint);
 ANext.Caption:=TranslateStr(224,ANext.Caption);
 ANext.Hint:=TranslateStr(225,ANext.Hint);
 ALast.Caption:=TranslateStr(226,ALast.Caption);
 ALast.Hint:=TranslateStr(227,ALast.Hint);
 AScale100.Caption:=TranslateStr(228,AScale100.Caption);
 AScale100.Hint:=TranslateStr(229,AScale100.Hint);
 AScaleWide.Caption:=TranslateStr(230,AScaleWide.Caption);
 AScaleWide.Hint:=TranslateStr(231,AScaleWide.Hint);
 AScaleFull.Caption:=TranslateStr(232,AScaleFull.Caption);
 AScaleFull.Hint:=TranslateStr(233,AScaleFull.Hint);
 AScaleLess.Caption:=TranslateStr(234,AScaleLess.Caption);
 AScaleLess.Hint:=TranslateStr(235,AScaleLess.Hint);
 AScaleMore.Caption:=TranslateStr(236,AScaleMore.Caption);
 AScaleMore.Hint:=TranslateStr(237,AScaleMore.Hint);
 APageSetup.Caption:=TranslateStr(50,APageSetup.Caption);
 APageSetup.Hint:=TranslateStr(51,APageSetup.Hint);
 AFind.Caption:=TranslateStr(1434,AFind.Caption);
 AFind.Hint:=TranslateStr(1435,AFind.Hint);


{$IFDEF BUILDER4}
 APageSetup.Enabled:=false;
{$ENDIF}

 SaveDialog1.FilterIndex:=2;
end;

procedure TFRpVPreview.AFirstExecute(Sender: TObject);
begin
 PreviewControl.FirstPage;
end;

procedure TFRpVPreview.ANextExecute(Sender: TObject);
var
 disable:boolean;
begin
 disable:=true;
 if PreviewControl.Metafile.Finished then
  disable:=false;
 if disable then
  DisableControls(true);
 try
  PreviewControl.NextPage;
 finally
  if disable then
   EnableControls;
 end;
end;

procedure TFRpVPreview.APreviousExecute(Sender: TObject);
begin
 PreviewControl.PriorPage;
end;

procedure TFRpVPreview.ALastExecute(Sender: TObject);
begin
 DisableControls(true);
 try
  PreviewControl.LastPage;
 finally
  EnableControls;
 end;
end;


procedure TFRpVPreview.APrintExecute(Sender: TObject);
var
 adone:boolean;
 allpages,collate:boolean;
 frompage,topage,copies:integer;
 areport:TRpReport;
 recalcreport:boolean;
begin
 if not assigned(previewcontrol) then
  exit;
 allpages:=true;
 collate:=PreviewControl.metafile.CollateCopies;
 frompage:=1; topage:=MAX_PAGECOUNT;
 if (PreviewControl.Metafile.Finished) then
  topage:=PreviewControl.Metafile.CurrentPageCount;
 copies:=PreviewControl.metafile.Copies;
 if Not DoShowPrintDialog(allpages,frompage,topage,copies,collate) then
  exit;

 areport:=nil;
 // If use printerfonts is enabled recalculate full report
 recalcreport:=false;
 if (previewcontrol is TRpPreviewControl) then
 begin
  areport:=TRpReport(TRpPreviewControl(previewcontrol).Report);
  areport.Metafile.BlockPrinterSelection:=true;
  if (TRpPreviewControl(previewcontrol).Report.PrinterFonts in [rppfontsalways,rppfontsrecalculate]) then
  begin
   recalcreport:=true;
  end;
 end;
 try


 if recalcreport then
 begin
  areport:=TRpReport(TRpPreviewControl(previewcontrol).Report);
  TRpPreviewControl(previewcontrol).Report:=nil;
  previewcontrol.Parent:=nil;
  rplcldriver.PrintReport(areport,Caption,true,allpages,frompage,topage,copies,collate);

  TRpPreviewControl(previewcontrol).Report:=areport;
  AppIdle(Self,adone);
 end
 else
 begin
  if not allpages then
  begin
   PreviewControl.Page:=topage+1;
  end
  else
   ALastExecute(Self);
  PrintMetafile(PreviewControl.Metafile,Caption,true,allpages,frompage,topage,copies,
  collate,false,PreviewControl.Metafile.PrinterSelect);
  AppIdle(Self,adone);
 end;
  finally
  if (areport<>nil) then
    areport.Metafile.BlockPrinterSelection:=false;
  end;
end;

procedure TFRpVPreview.ASaveExecute(Sender: TObject);
var
 adone:boolean;
 abitmap:TBitmap;
 mono:boolean;
 horzres,vertres:integer;
 recalcreport:boolean;
 areport:TRpReport;
 meta:TRpMetafileReport;
 pdfdriver:TRpPDfDriveR;
 oldpagesize:TRpPageSize;
 oldheight:integer;
 oldwidth:integer;
 compressed: boolean;
 pdfA3: boolean;
begin
 areport:=nil;
 abitmap:=nil;
 if not Assigned(PreviewControl) then
  exit;
 // Saves the metafile
 if SaveDialog1.Execute then
 begin
   DisableControls(true);
   try
    case SaveDialog1.FilterIndex of
     1:
     begin
      ALastExecute(Self);
      PreviewControl.Metafile.SaveToFile(SaveDialog1.Filename)
     end;
     2,3,4,5:
      begin
        compressed:=(SaveDialog1.FilterIndex=2) or (SaveDialog1.FilterIndex=4);
        pdfA3:=(SaveDialog1.FilterIndex=4) or (SaveDialog1.FilterIndex=5);
        recalcreport:=false;
        if (previewcontrol is TRpPreviewControl) then
        begin
          if (TRpPreviewControl(previewcontrol).Report.PrinterFonts in [rppfontsalways,rppfontsrecalculate]) then
          begin
           recalcreport:=true;
           areport:=TRpReport(TRpPreviewControl(previewcontrol).Report);
          end;
        end;
        if recalcreport then
        begin
          areport:=TRpReport(TRpPreviewControl(previewcontrol).Report);
          TRpPreviewControl(previewcontrol).Report:=nil;
          previewcontrol.Parent:=nil;
          rppdfdriver.PrintReportPDF(areport,Caption,true,true,1,99999,1,SaveDialog1.FileName,compressed,false,pdfA3);
          TRpPreviewControl(previewcontrol).Report:=areport;
          AppIdle(Self,adone);
        end
        else
        begin
          ALastExecute(Self);
          SaveMetafileToPDF(PreviewControl.Metafile,SaveDialog1.FileName,compressed,pdfA3);
        end;
      end;
     6:
      begin
        ALastExecute(Self);
        SaveMetafileToPNG(PreviewControl.Metafile,SaveDialog1.FileName);
        AppIdle(Self,adone);
      end;
     8:
      begin
       horzres:=100;
       vertres:=100;
       mono:=true;
       if AskBitmapProps(horzres,vertres,mono) then
       begin
        ALastExecute(Self);
        // abitmap was freed without ever being assigned (access violation)
        abitmap:=MetafileToBitmap(PreviewControl.Metafile,true,mono,horzres,vertres);
        try
         if assigned(abitmap) then
          abitmap.SaveToFile(SaveDialog1.FileName);
        finally
         abitmap.free;
        end;
       end;
      end;
     9:
      begin
       recalcreport:=false;
       if (previewcontrol is TRpPreviewControl) then
       begin
         if (TRpPreviewControl(previewcontrol).Report.PrinterFonts in [rppfontsalways,rppfontsrecalculate]) then
         begin
          recalcreport:=true;
          areport:=TRpReport(TRpPreviewControl(previewcontrol).Report);
         end;
       end;
       if recalcreport then
       begin
         areport:=TRpReport(TRpPreviewControl(previewcontrol).Report);
         TRpPreviewControl(previewcontrol).Report:=nil;
         previewcontrol.Parent:=nil;
         pdfdriver:=TRpPdfDriver.Create;
         try
          pdfdriver.filename:='';
          oldpagesize:=areport.Pagesize;
          oldwidth:=areport.CustomPageWidth;
          oldheight:=areport.CustomPageHeight;
          try
           areport.Pagesize:=rpPageSizeUser;
           // Maximum of aprox 25000 A4 pages
           if (aReport.PrinterFonts=rppfontsrecalculate) then
            areport.CustomPageHeight:=TWIPS_PER_INCHESS*100000;
           areport.PrintAll(pdfdriver);
           if (areport.PrinterFonts=rppfontsrecalculate) then
           begin
            areport.Metafile.CustomY:=areport.maximum_height;
            areport.Metafile.CustomX:=areport.maximum_width;
           end;
          finally
           areport.Pagesize:=oldpagesize;
           areport.CustomPageWidth:=oldwidth;
           areport.CustomPageHeight:=oldheight;
          end;
          meta:=areport.Metafile;
         finally
          pdfdriver.free;
          TRpPreviewControl(previewcontrol).Report:=areport;
         end;
       end
       else
       begin
        ALastExecute(Self);
        meta:=PreviewControl.Metafile;
       end;
       ExportMetafileToHtml(meta,Caption,SaveDialog1.FileName,
        true,true,1,9999);
       if recalcreport then
        TRpPreviewControl(previewcontrol).Report:=areport;
       AppIdle(Self,adone);
//       ALastExecute(Self);
//       ExportMetafileToHtml(PreviewControl.Metafile,Caption,SaveDialog1.FileName,
//        true,true,1,9999);
//       AppIdle(Self,adone);
      end;
     10:
      begin
       recalcreport:=false;
       if (previewcontrol is TRpPreviewControl) then
       begin
         if (TRpPreviewControl(previewcontrol).Report.PrinterFonts in [rppfontsalways,rppfontsrecalculate]) then
         begin
          recalcreport:=true;
          areport:=TRpReport(TRpPreviewControl(previewcontrol).Report);
         end;
       end;
       if recalcreport then
       begin
         areport:=TRpReport(TRpPreviewControl(previewcontrol).Report);
         TRpPreviewControl(previewcontrol).Report:=nil;
         previewcontrol.Parent:=nil;
         pdfdriver:=TRpPdfDriver.Create;
         try
          pdfdriver.filename:='';
          oldpagesize:=areport.Pagesize;
          oldwidth:=areport.CustomPageWidth;
          oldheight:=areport.CustomPageHeight;
          try
           areport.Pagesize:=rpPageSizeUser;
           // Maximum of aprox 25000 A4 pages
           if (areport.PrinterFonts=rppfontsrecalculate) then
            areport.CustomPageHeight:=TWIPS_PER_INCHESS*100000;
           areport.PrintAll(pdfdriver);
           if (areport.Metafile.CurrentPageCount=1) then
           begin
            // For only one page shorts the page to maximum printed
            // area
            areport.Metafile.CustomY:=areport.maximum_height;
            areport.Metafile.CustomX:=areport.maximum_width;
           end;
          finally
           areport.Pagesize:=oldpagesize;
           areport.CustomPageWidth:=oldwidth;
           areport.CustomPageHeight:=oldheight;
          end;
          meta:=areport.Metafile;
         finally
          pdfdriver.free;
          TRpPreviewControl(previewcontrol).Report:=areport;
         end;
       end
       else
       begin
        ALastExecute(Self);
        meta:=PreviewControl.Metafile;
       end;
       ExportMetafileToHtmlSingle(meta,Caption,SaveDialog1.FileName);
       if recalcreport then
        TRpPreviewControl(previewcontrol).Report:=areport;
       AppIdle(Self,adone);
      end;
     11:
      begin
       ALastExecute(Self);
       ExportMetafileToSVG(PreviewControl.Metafile,Caption,SaveDialog1.FileName,
        true,true,1,9999);
       AppIdle(Self,adone);
      end;
     12:
      begin
       ALastExecute(Self);
       ExportMetafileToCSV(PreviewControl.metafile,SaveDialog1.Filename,true,true,
        1,9999,',');
       AppIdle(Self,adone);
      end;
     13:
      begin
       ALastExecute(Self);
       ExportMetafileToTextPro(PreviewControl.metafile,SaveDialog1.Filename,true,true,
        1,9999);
       AppIdle(Self,adone);
      end;
     14:
     begin
      ALastExecute(Self);
      PreviewControl.Metafile.SaveToFile(SaveDialog1.Filename,false);
     end;
     else
     begin
      ALastExecute(Self);
      SaveMetafileToTextFile(PreviewControl.Metafile,SaveDialog1.FileName);
      AppIdle(Self,adone);
     end;
    end;
   finally
    EnableControls;
   end;
 end;
end;

procedure TFRpVPreview.RepProgress(Sender:TObject;records,pagecount:integer;var docancel:boolean);
begin
 BCancel.Caption:=SRpPage+':'+
  FormatFloat('####,####',pagecount)+':'
  +FormatFloat('####,####',records)+'-'+SRpCancel;
{$IFDEF MSWINDOWS}
 if ((GetAsyncKeyState(VK_ESCAPE) AND $8000)<>0) then
  docancel:=true;
{$ENDIF}
 if cancelled then
  docancel:=true;
 Application.ProcessMessages;
end;

procedure TFRpVPreview.BCancelClick(Sender: TObject);
begin
 cancelled:=true;
end;

procedure TFRpVPreview.ACancelExecute(Sender: TObject);
begin
 cancelled:=true;
end;

procedure TFRpVPreview.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
 if Not ANext.Enabled then
 begin
  cancelled:=true;
 end;
end;

procedure TFRpVPreview.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
 increment:integer;
begin
 if not Assigned(fpreviewcontrol) then
  exit;
 if (ssShift in Shift) then
  increment:=REP_C_WHEELINC
 else
  increment:=REP_C_WHEELINC*REP_C_WHEELSCALE;
 if Key=VK_DOWN then
  fpreviewcontrol.Scroll(true,increment);
 if Key=VK_UP then
  fpreviewcontrol.Scroll(true,-increment);
 if Key=VK_RIGHT then
  fpreviewcontrol.Scroll(false,increment);
 if Key=VK_LEFT then
  fpreviewcontrol.Scroll(false,-increment);
 if Key=VK_SPACE then
 begin
  if fpreviewcontrol.AutoScale=AScaleEntirePage then
   fpreviewcontrol.AutoScale:=AScaleReal
  else
   fpreviewcontrol.AutoScale:=AScaleEntirePage;
  Key:=0;
 end;
 if Key=VK_F5 then
 begin
  fpreviewControl.ShowPageMargins:=not fPreviewControl.ShowPageMargins;
 end;
end;

procedure TFRpVPreview.DisableControls(enablebar:boolean);
begin
 BCancel.Left:=BExit.Left+BExit.Width;
 BCancel.Visible:=true;
 AScale100.Enabled:=false;
 AScaleFull.Enabled:=false;
 AScaleWide.Enabled:=false;
 AScaleLess.Enabled:=False;
 AScaleMore.Enabled:=False;
 AFirst.Enabled:=false;
 ALast.Enabled:=false;
 APrint.Enabled:=false;
 ANext.Enabled:=false;
 APrevious.Enabled:=false;
 EPageNum.Enabled:=false;
 ASave.Enabled:=false;
 AMailTo.Enabled:=false;
 APageSetup.Enabled:=false;
 AParams.Enabled:=false;
 AExit.Enabled:=false;
end;

procedure TFRpVPreview.EnableControls;
begin
 BCancel.Visible:=false;
 AScale100.Enabled:=true;
 AScaleFull.Enabled:=true;
 AScaleWide.Enabled:=true;
 AScaleLess.Enabled:=true;
 AScaleMore.Enabled:=true;
 AFirst.Enabled:=true;
 ALast.Enabled:=true;
 APrint.Enabled:=true;
 ANext.Enabled:=true;
 APrevious.Enabled:=true;
 EPageNum.Enabled:=true;
 ASave.Enabled:=true;
 AMailTo.Enabled:=true;
 APageSetup.Enabled:=true;
 AParams.Enabled:=true;
 AExit.Enabled:=true;
end;

procedure TFRpVPreview.AExitExecute(Sender: TObject);
begin
 Close;
end;

procedure TFRpVPreview.AParamsExecute(Sender: TObject);
begin
 if ShowUserParams(TRpPreviewControl(fpreviewcontrol).Report.Params) then
 begin
  DisableControls(true);
  try
   fpreviewcontrol.RefreshMetafile;
  finally
   EnableControls;
  end;
 end;
end;

procedure TFRpVPreview.AScale100Execute(Sender: TObject);
begin
 PreviewControl.AutoScale:=AScaleReal;
end;

procedure TFRpVPreview.AScaleWideExecute(Sender: TObject);
begin
 PreviewControl.AutoScale:=rppreviewmetalcl.AScaleWide;
end;

procedure TFRpVPreview.AScaleLessExecute(Sender: TObject);
begin
 PreviewControl.PreviewScale:=PreviewControl.PreviewScale-0.1;
end;

procedure TFRpVPreview.AScaleMoreExecute(Sender: TObject);
begin
 PreviewControl.PreviewScale:=PreviewControl.PreviewScale+0.1;
end;


procedure TFRpVPreview.FormMouseWheelDown(Sender: TObject;
  Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
var
 increment:integer;
begin
 increment:=REP_C_WHEELINC;
 if Not (ssShift in Shift) then
  increment:=increment*REP_C_WHEELSCALE;
 fpreviewcontrol.Scroll(not (ssCtrl in Shift),increment);
 Handled:=false;
end;

procedure TFRpVPreview.FormMouseWheelUp(Sender: TObject;
  Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
var
 increment:integer;
begin
 increment:=REP_C_WHEELINC;
 if Not (ssShift in Shift) then
  increment:=increment*REP_C_WHEELSCALE;
 fpreviewcontrol.Scroll(not (ssCtrl in Shift),-increment);
 Handled:=false;
end;

procedure TFRpVPreview.EPageNumKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
 if Key=VK_RETURN then
 begin
  PreviewControl.Page:=StrToInt(EPageNum.Text)-1;
 end;
end;

procedure TFRpVPreview.AMailToExecute(Sender: TObject);
var
 afilename:String;
 destination,subject,body:string;
 report:TRpBasereport;
begin
 destination:='';
 body:='';
 subject:='';
 afilename:='';
 if (fpreviewcontrol is TRpPreviewControl) then
 begin
  report:=TRpPreviewControl(fpreviewcontrol).Report;
  if report.Params.IndexOf('MAIL_DESTINATION')>=0 then
   destination:=report.Params.ParamByName('MAIL_DESTINATION').AsString;
  if report.Params.IndexOf('MAIL_SUBJECT')>=0 then
   subject:=report.Params.ParamByName('MAIL_SUBJECT').AsString;
  if report.Params.IndexOf('MAIL_BODY')>=0 then
   body:=report.Params.ParamByName('MAIL_BODY').AsString;
  if report.Params.IndexOf('MAIL_FILE')>=0 then
   afilename:=report.Params.ParamByName('MAIL_FILE').AsString;
 end;
 // The PDF goes to a folder of its own unless MAIL_FILE has a path; the
 // file name is also the attachment name
 if Length(ExtractFileName(afilename))<1 then
  afilename:='report-'+FormatDateTime('yyyymmdd-hhnnsszzz',Now);
 if Length(ExtractFilePath(afilename))<1 then
  afilename:=MailTempDir+afilename;
 afilename:=ChangeFileExt(afilename,'.pdf');

 // PDF/A-3, as the VCL
 SaveMetafileToPDF(fpreviewcontrol.Metafile,afilename,true,true);
{$IFDEF MSWINDOWS}
 // Simple MAPI shows its dialog modally: the file can be deleted after it
 try
{$ENDIF}
  if Length(subject)<1 then
   subject:=ExtractFileName(afilename);
  RpSendMail(destination,subject,body,afilename,ExtractFileName(afilename));
{$IFDEF MSWINDOWS}
 finally
  sysutils.DeleteFile(afilename);
 end;
{$ENDIF}
end;

procedure TFRpVPreview.APageSetupExecute(Sender: TObject);
begin
 if ExecutePageSetup(TRpPreviewControl(fpreviewcontrol).Report) then
 begin
  DisableControls(true);
  try
   fpreviewcontrol.RefreshMetafile;
  finally
   EnableControls;
  end;
 end;
end;

procedure TFRpVPreview.OnPageDrawn(prm:TRpPreviewMeta);
begin
 EPageNum.Text:=IntToStr(prm.Page+1);
end;


procedure TFRpVPreview.MEntire1Click(Sender: TObject);
begin
 // Adjust to entirepage
 PreviewControl.EntirePageCount:=TMenuItem(Sender).Tag;
 PreviewControl.AutoScale:=AScaleEntirePage;
end;

procedure TFRpVPreview.AScaleFullExecute(Sender: TObject);
begin
 PreviewControl.AutoScale:=AScaleEntirePage;
end;

procedure TFRpVPreview.MEntirePagePopup(Sender: TObject);
begin
 MleftRight.Checked:=Not PreviewControl.EntireTopDown;
end;

procedure TFRpVPreview.MLeftRightClick(Sender: TObject);
begin
 MleftRight.Checked:=Not MLeftRight.Checked;
 PreviewControl.EntireTopDown:=Not MLeftRight.Checked;
end;





procedure TFRpVPreview.MEntireMenuPopup(Sender: TObject);
begin
 MleftRight.Checked:=Not PreviewControl.EntireTopDown;
end;

procedure TFRpVPreview.FindNext;
var
 pageindex:integer;
begin
 if (textchanged) then
 begin
  PreviewControl.Metafile.DoSearch(Trim(ESearch.Text));
  pageindex:=PreviewControl.Metafile.NextPageFound(-1);
  textchanged:=false;
 end
 else
  pageindex:=PreviewControl.Metafile.NextPageFound(PreviewControl.Page+PreviewControl.PagesDrawn-1);
 if PreviewControl.Page=pageindex then
  PreviewControl.RefreshPage
 else
  PreviewControl.Page:=pageindex;
end;


procedure TFRpVPreview.ESearchKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
 if Key=VK_RETURN then
 begin
  FindNext;
 end;
end;

procedure TFRpVPreview.AFindExecute(Sender: TObject);
begin
 FindNext;
end;

procedure TFRpVPreview.ESearchChange(Sender: TObject);
begin
 textchanged:=true;
end;

end.
