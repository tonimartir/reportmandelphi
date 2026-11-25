{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       Rpxmlstream                                     }
{       Streams properties                              }
{       common components of Report manager             }
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

unit rpxmlstream;

{$I rpconf.inc}

interface

uses Classes,sysutils,rptypes,rpreport,rpdatainfo,rpsubreport,
 rpsection,rpparams,rpprintitem,rplabelitem,rpmdbarcode,rpmdchart,
{$IFDEF USEVARIANTS}
 Variants,
{$ENDIF}
 rpdrawitem,rpmdconsts,rpmdcharttypes,
{$IFNDEF FPC}
 rpmdundocue,
{$ENDIF}
 rpbasereport;


const
 C_MAXDATAWIDTH=40;
 CRLF:AnsiString=''+#13+#10;
type
 TRpPropertytypes=(rppropinteger,rppropdouble,rppropdatetime,rppropstring,
  rppropwidestring,rppropstream);



function StringToRpString(astring:AnsiString):AnsiString;
function RpStringToString(rpstring:Ansistring):AnsiString;
function WStringToRpString(astring:WideString):AnsiString;
function RpStringToWString(rpstring:Ansistring):WideString;

procedure WritePropertyI(propname:Ansistring;propvalue:integer;stream:TStream);
// An Int64 with the type of WritePropertyI (Integer): read with StrToInt64
procedure WritePropertyI64(propname:Ansistring;propvalue:Int64;stream:TStream);
procedure WritePropertyD(propname:Ansistring;propvalue:double;stream:TStream);
procedure WritePropertyBool(propname:Ansistring;propvalue:Boolean;stream:TStream);
procedure WritePropertyS(propname:Ansistring;propvalue:AnsiString;stream:TStream);
procedure WritePropertyW(propname:Ansistring;propvalue:WideString;stream:TStream);
// A text property: as WritePropertyS when the ANSI code page holds the text (the bytes older
// versions write and read), else as WritePropertyW, so that no character is lost
procedure WritePropertyT(propname:Ansistring;const propvalue:String;stream:TStream);
// The text of a property written by WritePropertyT, WritePropertyS or the .Net engine
function RpPropToString(const propvalue,proptype:AnsiString):String;
procedure WritePropertyB(propname:Ansistring;propvalue:TStream;stream:TStream);
procedure WriteReportXML(areport:TComponent;Stream:TStream);
procedure ReadReportXML(areport:TComponent;Stream:TStream);
procedure ReadSectionXML(areport:TComponent;Stream:TStream);
function GetUniqueReportItemName(report: TRpBaseReport; currentItem: TObject;
  const preferredName, basePrefix: string): string;
procedure EnsureDatabaseInfoItemName(report: TRpBaseReport;
  dbitem: TRpDatabaseInfoItem);
procedure EnsureDataInfoItemName(report: TRpBaseReport;
  ditem: TRpDataInfoItem);
procedure EnsureParamName(report: TRpBaseReport; param: TRpParam);
procedure EnsureReportItemNames(report: TRpBaseReport);

procedure WriteDatabaseInfoXML(dbinfo:TRpDatabaseInfoItem;Stream:TStream);
procedure WriteDataInfoXML(dinfo:TRpDataInfoItem;Stream:TStream);
procedure WriteReportPropsXML(report:TRpReport;Stream:TStream);
procedure WriteParamXML(aparam:TRpParam;Stream:TStream);
procedure WriteSubreportXML(subrep:TRpSubReport;Stream:TStream);
procedure WriteSectionXML(section:TRpSection;Stream:TStream);
procedure WriteComponentXML(comp:TRpCommonPosComponent;Stream:TStream);


function RpIsAlpha(achar:Ansichar):Boolean;
function RpIsAlphaW(achar:Widechar):Boolean;

{$IFDEF FPC}
type
 // The designer undo cue travels with the report as BINCUE (JSON), as in
 // Delphi: the AI design request sends it and the server returns it with the
 // operations of its changes. The engine package can not use the designer
 // unit (design_lcl/rpmdundocuelcl), which registers these hooks.
 // RpUndoCueToJson returns '' when there is nothing to save.
 TRpUndoCueToJsonFunc=function(AUndoCue:TObject):string;
 TRpUndoCueFromJsonProc=procedure(AReport:TComponent;const AJson:string);
var
 RpUndoCueToJson:TRpUndoCueToJsonFunc=nil;
 RpUndoCueFromJson:TRpUndoCueFromJsonProc=nil;
{$ENDIF}

implementation

// Implement it based on FindNextName procedure
procedure ReadSectionXML(areport:TComponent;Stream:TStream);
begin

end;

function RpIsAlpha(achar:Ansichar):Boolean;
begin
 Result:=achar in ['0'..'9','A'..'Z','a'..'z','_',' ','.','(',')',
  '=',';',':'];
end;

function RpIsAlphaW(achar:Widechar):Boolean;
begin
 Result:=CharInSet(achar,[WideChar('0')..WideChar('9'),WideChar('_'),WideChar(' '),
  WideChar('.'),WideChar('('),WideChar(')'),
  WideChar('='),WideChar(';'),WideChar(':'),
  WideChar('A')..WideChar('Z'),WideChar('a')..WideChar('z')]);
end;

procedure WriteDatabaseInfoXML(dbinfo:TRpDatabaseInfoItem;Stream:TStream);
begin
 WritePropertyT('ALIAS',dbinfo.Alias,Stream);
 WritePropertyT('NAME',dbinfo.Name,Stream);
 WritePropertyT('CONFIGFILE',dbinfo.Configfile,Stream);
 WritePropertyBool('LOADPARAMS',dbinfo.LoadParams,Stream);
 WritePropertyBool('LOADDRIVERPARAMS',dbinfo.LoadDriverParams,Stream);
 WritePropertyBool('LOGINPROMPT',dbinfo.LoginPrompt,Stream);
 WritePropertyI('DRIVER',Integer(dbinfo.Driver),Stream);
 WritePropertyT('REPORTTABLE',dbinfo.ReportTable,Stream);
 WritePropertyT('REPORTSEARCHFIELD',dbinfo.ReportSearchField,Stream);
 WritePropertyT('REPORTFIELD',dbinfo.ReportField,Stream);
 WritePropertyT('REPORTGROUPSTABLE',dbinfo.ReportGroupsTable,Stream);
 WritePropertyW('ADOCONNECTIONSTRING',dbinfo.ADOConnectionString,Stream);
 WritePropertyI('DOTNETDRIVER',dbinfo.DotNetDriver,Stream);
 WritePropertyT('PROVIDERFACTORY',dbinfo.ProviderFactory,Stream);

end;

procedure WriteDataInfoXML(dinfo:TRpDataInfoItem;Stream:TStream);
begin
 WritePropertyT('ALIAS',dinfo.Alias,Stream);
 WritePropertyT('NAME',dinfo.Name,Stream);
 WritePropertyT('DATABASEALIAS',dinfo.DatabaseAlias,Stream);
 WritePropertyW('SQL',dinfo.SQL,Stream);
 if Trim(dinfo.SQLExplanation)<>'' then
  WritePropertyW('SQLEXPLANATION',dinfo.SQLExplanation,Stream);
 if Trim(dinfo.SQLExplanationError)<>'' then
  WritePropertyW('SQLEXPLANATIONERROR',dinfo.SQLExplanationError,Stream);
 // Only with a value: a dataset without them is written as before
 if dinfo.HubSchemaId<>0 then
  WritePropertyI64('HUBSCHEMAID',dinfo.HubSchemaId,Stream);
 if dinfo.SchemaName<>'' then
  WritePropertyW('SCHEMANAME',dinfo.SchemaName,Stream);
 WritePropertyT('DATASOURCE',dinfo.DataSource,Stream);
 WritePropertyT('MYBASEFILENAME',dinfo.MyBaseFileName,Stream);
 WritePropertyT('MYBASEFIELDS',dinfo.MyBaseFields,Stream);
 WritePropertyT('MYBASEINDEXFIELDS',dinfo.MyBaseIndexFields,Stream);
 WritePropertyT('MYBASEMASTERFIELDS',dinfo.MyBaseMasterFields,Stream);
 WritePropertyT('BDEINDEXFIELDS',dinfo.BDEIndexFields,Stream);
 WritePropertyT('BDEINDEXNAME',dinfo.BDEIndexName,Stream);
 WritePropertyT('BDETABLE',dinfo.BDETable,Stream);
 WritePropertyI('BDETYPE',Integer(dinfo.BDEType),Stream);
 WritePropertyT('BDEFILTER',dinfo.BDEFilter,Stream);
 WritePropertyT('BDEMASTERFIELDS',dinfo.BDEMasterFields,Stream);
 WritePropertyT('BDEFIRSTRANGE',dinfo.BDEFirstRange,Stream);
 WritePropertyT('BDELASTRANGE',dinfo.BDELastRange,Stream);
 WritePropertyT('DATAUNIONS',dinfo.DataUnions.Text,Stream);
 WritePropertyBool('GROUPUNION',dinfo.GroupUnion,Stream);
 WritePropertyBool('OPENONSTART',dinfo.OpenOnStart,Stream);
 WritePropertyBool('PARALLELUNION',dinfo.ParallelUnion,Stream);
end;

procedure WriteReportPropsXML(report:TRpReport;Stream:TStream);
{$IFNDEF FPC}
var
 undocue:TUndoCue;
 memstream:TMemoryStream;
 jsonBytes:TBytes;
{$ELSE}
var
 cuejson:string;
 memstream:TMemoryStream;
{$ENDIF}
begin
{$IFDEF FPC}
 // Same BINCUE as Delphi (UTF-8 JSON bytes), through the designer hook
 if Assigned(report.UndoCue) and Assigned(RpUndoCueToJson) then
 begin
  cuejson:=RpUndoCueToJson(report.UndoCue);
  if Length(cuejson)>0 then
  begin
   memstream:=TMemoryStream.Create;
   try
    memstream.Write(cuejson[1],Length(cuejson));
    memstream.Position:=0;
    WritePropertyB('BINCUE',memstream,Stream);
   finally
    memstream.Free;
   end;
  end;
 end;
{$ENDIF}
{$IFNDEF FPC}
 // Write UndoCue if present (only for XML format)
 if Assigned(report.UndoCue) then
 begin
  undocue:=TUndoCue(report.UndoCue);
  if (undocue.UndoOperations.Count > 0) or (undocue.RedoOperations.Count > 0) then
  begin
   memstream:=TMemoryStream.Create;
   try
    jsonBytes:=TEncoding.UTF8.GetBytes(undocue.ToJSON);
    memstream.Write(jsonBytes[0], Length(jsonBytes));
    memstream.Position:=0;
    WritePropertyB('BINCUE',memstream,Stream);
   finally
    memstream.Free;
   end;
  end;
 end;
{$ENDIF}
 WritePropertyW('WFONTNAME',report.WFontName,Stream);
 WritePropertyW('LFONTNAME',report.LFontName,Stream);
 WritePropertyBool('GRIDVISIBLE',report.GridVisible,Stream);
 WritePropertyBool('GRIDLINES',report.GridLines,Stream);
 WritePropertyBool('GRIDENABLED',report.GridEnabled,Stream);
 WritePropertyI('GRIDCOLOR',report.GridColor,Stream);
 WritePropertyI('GRIDWIDTH',report.GridWidth,Stream);
 WritePropertyI('GRIDHEIGHT',report.GridHeight,Stream);
 WritePropertyI('PAGEORIENTATION',Integer(report.PageOrientation),Stream);
 WritePropertyI('PAGESIZE',Integer(report.PageSize),Stream);
 WritePropertyI('PAGESIZEQT',report.PageSizeQt,Stream);
 WritePropertyI('PAGEHEIGHT',report.PageHeight,Stream);
 WritePropertyI('PAGEWIDTH',report.PageWidth,Stream);
 WritePropertyI('CUSTOMPAGEHEIGHT',report.CustomPageHeight,Stream);
 WritePropertyI('CUSTOMPAGEWIDTH',report.CustomPageWidth,Stream);
 WritePropertyI('PAGEBACKCOLOR',Integer(report.PageBackColor),Stream);
 WritePropertyI('PREVIEWSTYLE',Integer(report.PreviewStyle),Stream);
 WritePropertyBool('PREVIEWMARGINS',report.PreviewMargins,Stream);
 WritePropertyI('PREVIEWWINDOW',Integer(report.PreviewWindow),Stream);
 WritePropertyI('LEFTMARGIN',report.LeftMargin,Stream);
 WritePropertyI('TOPMARGIN',report.TopMargin,Stream);
 WritePropertyI('RIGHTMARGIN',report.RightMargin,Stream);
 WritePropertyI('BOTTOMMARGIN',report.BottomMargin,Stream);
 WritePropertyI('PRINTERSELECT',Integer(report.PrinterSelect),Stream);
 WritePropertyI('LANGUAGE',report.Language,Stream);
 WritePropertyI('COPIES',report.Copies,Stream);
 WritePropertyBool('COLLATECOPIES',report.CollateCopies,Stream);
 WritePropertyBool('TWOPASS',report.TwoPass,Stream);
 WritePropertyI('PRINTERFONTS',Integer(report.PrinterFonts),Stream);
 WritePropertyBool('PRINTONLYIFDATAAVAILABLE',report.PrintOnlyIfDataAvailable,Stream);
 WritePropertyI('STREAMFORMAT',Integer(report.StreamFormat),Stream);
 WritePropertyBool('REPORTACTIONDRAWERBEFORE',rpDrawerBefore in report.ReportAction,Stream);
 WritePropertyBool('REPORTACTIONDRAWERAFTER',rpDrawerAfter in report.ReportAction,Stream);
 WritePropertyBool('PREVIEWABOUT',report.PreviewAbout,Stream);
 WritePropertyI('TYPE1FONT',Integer(report.Type1Font),Stream);
 WritePropertyI('FONTSIZE',report.FontSize,Stream);
 WritePropertyI('FONTROTATION',report.FontRotation,Stream);
 WritePropertyI('FONTSTYLE',report.FontStyle,Stream);
 WritePropertyI('FONTCOLOR',report.FontColor,Stream);
 WritePropertyI('BACKCOLOR',report.BackColor,Stream);
 WritePropertyBool('TRANSPARENT',report.Transparent,Stream);
 WritePropertyBool('CUTTEXT',report.CutText,Stream);
 WritePropertyI('ALIGNMENT',report.Alignment,Stream);
 WritePropertyI('VALIGNMENT',report.VAlignment,Stream);
 WritePropertyBool('WORDWRAP',report.WordWrap,Stream);
 WritePropertyBool('SINGLELINE',report.SingleLine,Stream);
 WritePropertyBool('MULTIPAGE',report.MultiPage,Stream);
 WritePropertyI('PRINTSTEP',Integer(report.PrintStep),Stream);
 WritePropertyI('PAPERSOURCE',report.PaperSource,Stream);
 WritePropertyI('DUPLEX',report.duplex,Stream);
 WritePropertyT('FORCEPAPERNAME',report.ForcePaperName,Stream);
 WritePropertyI('LINESPERINCH',report.LinesPerInch,Stream);
 WritePropertyI('PDFCONFORMANCE',Integer(report.PDFConformance),Stream);
 WritePropertyBool('PDFCOMPRESSED',report.PDFCompressed,Stream);
 WritePropertyT('DOCAUTHOR',report.DocAuthor,Stream);
 WritePropertyT('DOCCREATOR',report.DocCreator,Stream);
 WritePropertyT('DOCPRODUCER',report.DocProducer,Stream);
 WritePropertyT('DOCSUBJECT',report.DocSubject,Stream);
 WritePropertyT('DOCTITLE',report.DocTitle,Stream);
 WritePropertyT('DOCCREATIONDATE',report.DocCreationDate,Stream);
 WritePropertyT('DOCMODIFICATIONDATE',report.DocModificationDate,Stream);
 WritePropertyT('DOCKEYWORDS',report.DocKeywords,Stream);
 WritePropertyT('DOCXMPCONTENT',report.DocXMPContent,Stream);

end;

procedure WriteParamXML(aparam:TRpParam;Stream:TStream);
begin
 WritePropertyT('NAME',aparam.Name,Stream);
 WritePropertyT('INTNAME',aparam.IntName,Stream);
 WritePropertyW('DESCRIPTION',aparam.Descriptions,Stream);
 WritePropertyW('HINT',aparam.Hints,Stream);
 // Every language, as DESCRIPTION and HINT (ErrorMessage is the one of the current language)
 WritePropertyW('ERRORMESSAGE',aparam.ErrorMessages,Stream);
 WritePropertyW('VALIDATION',aparam.Validation,Stream);
 WritePropertyW('SEARCH',aparam.Search,Stream);
 WritePropertyBool('VISIBLE',aparam.Visible,Stream);
 WritePropertyBool('ISREADONLY',aparam.IsReadOnly,Stream);
 WritePropertyBool('NEVERVISIBLE',aparam.NeverVisible,Stream);
 WritePropertyBool('ALLOWNULLS',aparam.AllowNulls,Stream);
 WritePropertyI('PARAMTYPE',Integer(aparam.ParamType),Stream);
 WritePropertyT('DATASETS',aparam.Datasets.Text,Stream);
 WritePropertyT('ITEMS',aparam.Items.Text,Stream);
 WritePropertyT('VALUES',aparam.Values.Text,Stream);
 WritePropertyT('SELECTED',aparam.Selected.Text,Stream);
 WritePropertyT('LOOKUPDATASET',aparam.LookupDataset,Stream);
 WritePropertyT('SEARCHDATASET',aparam.SearchDataset,Stream);
 WritePropertyT('SEARCHPARAM',aparam.Searchparam,Stream);

 if (aparam.Value<>Null) then
 begin
  case aparam.ParamType of
   rpParamString,rpParamExpreA,rpParamExpreB,rpParamSubst,rpParamSubstE,rpParamList,rpParamSubstList,
   rpParamInitialExpression,rpParamUnknown:
    WritePropertyT('VALUE',String(aparam.Value),Stream);
   rpParamInteger:
    begin
     WritePropertyI('VALUE',aparam.Value,Stream);
    end;
   rpParamDouble:
    begin
     WritePropertyD('VALUE',aparam.Value,Stream);
    end;
   rpParamCurrency:
    begin
     WritePropertyD('VALUE',aparam.Value,Stream);
    end;
   rpParamDate,rpParamTime,rpParamDateTime:
    WritePropertyD('VALUE',double(aparam.Value),Stream);
   rpParamBool:
    WritePropertyBool('VALUE',aparam.Value,Stream);
  end;
 end;
end;

procedure WriteSubreportXML(subrep:TRpSubReport;Stream:TStream);
begin
 WritePropertyT('NAME',subrep.Name,Stream);
 WritePropertyT('ALIAS',subrep.Alias,Stream);
 if assigned(subrep.ParentSubReport) then
 begin
  WritePropertyT('PARENTSUBREPORT',subrep.ParentSubReport.Name,Stream);
 end;
 if assigned(subrep.ParentSection) then
 begin
  WritePropertyT('PARENTSECTION',subrep.ParentSection.Name,Stream);
 end;
 WritePropertyBool('PRINTONLYIFDATAAVAILABLE',subrep.PrintOnlyIfDataAvailable,Stream);
 WritePropertyBool('REOPENONPRINT',subrep.ReOpenOnPrint,Stream);
end;

procedure WriteSectionXML(section:TRpSection;Stream:TStream);
var
 i:integer;
 aitem:TRpCommonPosComponent;
begin
 WriteStringToStream('<SECTION>'+CRLF,Stream);

 WritePropertyT('NAME',section.Name,Stream);
 WritePropertyI('WIDTH',section.Width,Stream);
 WritePropertyI('HEIGHT',section.height,Stream);
 WritePropertyW('PRINTCONDITION',section.PrintCondition,Stream);
 WritePropertyW('DOBEFOREPRINT',section.DoBeforePrint,Stream);
 WritePropertyW('DOAFTERPRINT',section.DoAfterPrint,Stream);
 if assigned(section.SubReport) then
 begin
  WritePropertyT('SUBREPORT',section.Subreport.Name,Stream);
 end;
 WritePropertyT('GROUPNAME',section.GroupName,Stream);
 WritePropertyW('CHANGEEXPRESSION',section.ChangeExpression,Stream);
 WritePropertyW('BEGINPAGEEXPRESSION',section.BeginPageExpression,Stream);
 // Kept by the DFM format, and written by the .Net writer the same way: only when it is true
 if section.BeginPage then
  WritePropertyBool('BEGINPAGE',section.BeginPage,Stream);
 WritePropertyW('SKIPEXPREV',section.SkipExpreV,Stream);
 WritePropertyW('SKIPEXPREH',section.SkipExpreH,Stream);
 WritePropertyW('SKIPTOPAGEEXPRE',section.SkipToPageExpre,Stream);
 WritePropertyW('BACKEXPRESSION',section.BackExpression,Stream);
 WritePropertyBool('CHANGEBOOL',section.ChangeBool,Stream);
 WritePropertyBool('PAGEREPEAT',section.PageRepeat,Stream);
 WritePropertyBool('FORCEPRINT',section.FooterAtReportEnd,Stream);
 WritePropertyBool('SKIPPAGE',section.SkipPage,Stream);
 WritePropertyBool('ALIGNBOTTOM',section.AlignBottom,Stream);
 WritePropertyI('SECTIONTYPE',Integer(section.SectionType),Stream);
 WritePropertyBool('AUTOEXPAND',section.AutoExpand,Stream);
 WritePropertyBool('AUTOCONTRACT',section.AutoContract,Stream);
 WritePropertyBool('HORZDESP',section.HorzDesp,Stream);
 WritePropertyBool('VERTDESP',section.VertDesp,Stream);
 WritePropertyT('EXTERNALFILENAME',section.ExternalFilename,Stream);
 WritePropertyT('EXTERNALCONNECTION',section.ExternalConnection,Stream);
 WritePropertyT('EXTERNALTABLE',section.ExternalTable,Stream);
 WritePropertyT('EXTERNALFIELD',section.ExternalField,Stream);
 WritePropertyT('EXTERNALSEARCHFIELD',section.ExternalSearchField,Stream);
 WritePropertyT('EXTERNALSEARCHVALUE',section.ExternalSearchValue,Stream);
 WritePropertyI('STREAMFORMAT',Integer(section.StreamFormat),Stream);
 if assigned(section.ChildSubReport) then
 begin
  WritePropertyT('CHILDSUBREPORT',section.ChildSubreport.Name,Stream);
 end;
 WritePropertyBool('SKIPRELATIVEH',section.SkipRelativeH,Stream);
 WritePropertyBool('SKIPRELATIVEV',section.SkipRelativeV,Stream);
 WritePropertyI('SKIPTYPE',Integer(section.SkipType),Stream);
 WritePropertyBool('ININUMPAGE',section.IniNumPage,Stream);
 WritePropertyBool('GLOBAL',section.Global,Stream);
 WritePropertyI('DPIRES',section.dpires,Stream);
 WritePropertyI('CACHEDIMAGE',Integer(section.CachedImage),Stream);
 WritePropertyI('BACKSTYLE',Integer(section.BackStyle),Stream);
 WritePropertyI('DRAWSTYLE',Integer(section.DrawStyle),Stream);
 if assigned(section.Stream) then
 begin
  if section.Stream.Size>0 then
  begin
   section.Stream.Seek(0,soFromBeginning);
   WritePropertyB('STREAM',section.Stream,Stream);
  end;
 end;


 for i:=0 to section.ReportComponents.Count-1 do
 begin
  aitem:=TRpCommonPosComponent(section.ReportComponents.Items[i].Component);
  WriteComponentXML(aitem,Stream);
 end;
 WriteStringToStream('</SECTION>'+CRLF,Stream);
end;

// BIDIMODE only says whether the current language is right to left: BIDIMODES, the mode of every
// language, is written when it holds more than that (BidiFull, other languages), as the .Net
// writer does. Its lines are joined with CR LF on every platform, as TStrings.Text on Windows
function NeedsBidiModes(compt:TRpGenTextComponent):Boolean;
var
 current,i:integer;
 implied:String;
begin
 Result:=false;
 // The index GetBidiMode reads
 current:=TRpReport(compt.Report).Language+1;
 if (current<0) or (current>256) then
  current:=0;
 for i:=0 to compt.BidiModes.Count-1 do
 begin
  if (i=current) and compt.RightToLeft then
   implied:='BidiPartial'
  else
   implied:='BidiNo';
  if compt.BidiModes.Strings[i]<>implied then
  begin
   Result:=true;
   exit;
  end;
 end;
end;

function BidiModesText(compt:TRpGenTextComponent):String;
var
 i:integer;
begin
 Result:='';
 for i:=0 to compt.BidiModes.Count-1 do
  Result:=Result+compt.BidiModes.Strings[i]+#13#10;
end;

// The colors of the Series collection of a chart (the DFM format keeps them, the XML one did not):
// integers separated by commas, as the .Net writer writes them
function SeriesColorsText(compc:TRpChart):String;
var
 i:integer;
begin
 Result:='';
 for i:=0 to compc.Series.Count-1 do
 begin
  if i>0 then
   Result:=Result+',';
  Result:=Result+IntToStr(compc.Series.Items[i].Color);
 end;
end;

procedure ReadSeriesColors(compc:TRpChart;const text:String);
var
 list:TStringList;
 i,color:integer;
begin
 compc.Series.Clear;
 list:=TStringList.Create;
 try
  // Separators of a CommaText: commas and blanks
  list.CommaText:=text;
  for i:=0 to list.Count-1 do
  begin
   if TryStrToInt(Trim(list.Strings[i]),color) then
    compc.Series.Add.Color:=color;
  end;
 finally
  list.Free;
 end;
end;

procedure WriteComponentXML(comp:TRpCommonPosComponent;Stream:TStream);
var
 compt:TRpGenTextComponent;
 compl:TRpLabel;
 comps:TRpShape;
 compi:TRpImage;
 compe:TRpExpression;
 compb:TRpBarCode;
 compc:TRpChart;
begin
 WriteStringToStream('<COMPONENT>'+CRLF,Stream);

 WritePropertyT('NAME',comp.Name,Stream);
 WritePropertyT('CLASSNAME',UpperCase(comp.ClassName),Stream);
 WritePropertyI('WIDTH',comp.Width,Stream);
 WritePropertyI('HEIGHT',comp.height,Stream);
 WritePropertyW('PRINTCONDITION',comp.PrintCondition,Stream);
 WritePropertyW('DOBEFOREPRINT',comp.DoBeforePrint,Stream);
 WritePropertyW('DOAFTERPRINT',comp.DoAfterPrint,Stream);
 WritePropertyT('ANNOTATION',comp.AnnotationExpression,Stream);
 // CommonPos
 WritePropertyI('POSX',comp.PosX,Stream);
 WritePropertyI('POSY',comp.PosY,Stream);
 WritePropertyI('ALIGN',Integer(comp.Align),Stream);
 // Common text component
 if comp is TRpGenTextComponent then
 begin
  compt:=TRpGenTextComponent(comp);
  WritePropertyW('WFONTNAME',compt.WFontName,Stream);
  WritePropertyW('LFONTNAME',compt.LFontName,Stream);
  if compt.RightToLeft then
   WritePropertyI('BIDIMODE',Integer(rpBidiPartial),Stream)
  else
   WritePropertyI('BIDIMODE',Integer(rpBidiNo),Stream);
  WritePropertyI('TYPE1FONT',Integer(compt.Type1Font),Stream);
  WritePropertyI('FONTSIZE',compt.FontSize,Stream);
  WritePropertyI('FONTROTATION',compt.FontRotation,Stream);
  WritePropertyI('FONTSTYLE',compt.FontStyle,Stream);
  WritePropertyI('FONTCOLOR',compt.FontColor,Stream);
  WritePropertyI('BACKCOLOR',compt.BackColor,Stream);
  WritePropertyBool('TRANSPARENT',compt.Transparent,Stream);
  WritePropertyBool('CUTTEXT',compt.CutText,Stream);
  WritePropertyI('ALIGNMENT',compt.Alignment,Stream);
  WritePropertyI('VALIGNMENT',compt.VAlignment,Stream);
  WritePropertyI('INTERLINE',compt.InterLine,Stream);
  WritePropertyBool('WORDWRAP',compt.WordWrap,Stream);
  WritePropertyBool('WORDBREAK',compt.WordBreak,Stream);
  WritePropertyBool('SINGLELINE',compt.SingleLine,Stream);
  // After BIDIMODE: the reader reads it later, so it wins
  if NeedsBidiModes(compt) then
   WritePropertyT('BIDIMODES',BidiModesText(compt),Stream);
  WritePropertyBool('MULTIPAGE',compt.Multipage,Stream);
  WritePropertyI('PRINTSTEP',Integer(compt.PrintStep),Stream);
  if compt.IsHtml then
   WritePropertyBool('ISHTML',compt.IsHtml,Stream);
 end;
 // TRpLabel
 if comp is TRpLabel then
 begin
  compl:=TRpLabel(comp);
  compl.UpdateWideText;
  WritePropertyW('WIDETEXT',compl.WideText,Stream);
 end
 else
 // TRpExpression
 if comp is TRpExpression then
 begin
  compe:=TRpExpression(comp);

  WritePropertyW('EXPRESSION',compe.Expression,Stream);
  WritePropertyW('AGINIVALUE',compe.AgIniValue,Stream);
  WritePropertyW('EXPORTEXPRESSION',compe.ExportExpression,Stream);
  WritePropertyI('DATATYPE',Integer(compe.DataType),Stream);
  WritePropertyW('DISPLAYFORMAT',compe.DisplayFormat,Stream);
  WritePropertyT('IDENTIFIER',compe.Identifier,Stream);
  WritePropertyI('AGGREGATE',Integer(compe.Aggregate),Stream);
  WritePropertyT('GROUPNAME',compe.GroupName,Stream);
  WritePropertyI('AGTYPE',Integer(compe.AgType),Stream);
  WritePropertyBool('AUTOEXPAND',compe.AutoExpand,Stream);
  WritePropertyBool('AUTOCONTRACT',compe.AutoContract,Stream);
  WritePropertyBool('PRINTONLYONE',compe.PrintOnlyOne,Stream);
  WritePropertyBool('PRINTNULLS',compe.PrintNulls,Stream);
  WritePropertyW('EXPORTDISPLAYFORMAT',compe.ExportDisplayFormat,Stream);
  WritePropertyI('EXPORTLINE',compe.ExportLine,Stream);
  WritePropertyI('EXPORTPOSITION',compe.ExportPosition,Stream);
  WritePropertyI('EXPORTSIZE',compe.ExportSize,Stream);
  WritePropertyBool('EXPORTDONEWLINE',compe.ExportDoNewLine,Stream);
 end
 else
 // TRpShape
 if comp is TRpShape then
 begin
  comps:=TRpShape(comp);
  WritePropertyI('SHAPE',Integer(comps.Shape),Stream);
  WritePropertyI('BRUSHSTYLE',comps.BrushStyle,Stream);
  WritePropertyI('BRUSHCOLOR',comps.BrushColor,Stream);
  WritePropertyI('PENSTYLE',comps.PenStyle,Stream);
  WritePropertyI('PENCOLOR',comps.PenColor,Stream);
  WritePropertyI('PENWIDTH',comps.PenWidth,Stream);
 end
 else
 // TRpImage
 if comp is TRpImage then
 begin
  compi:=TRpImage(comp);
  WritePropertyW('EXPRESSION',compi.Expression,Stream);
  if assigned(compi.Stream) then
  begin
   if compi.Stream.Size>0 then
   begin
    compi.Stream.Seek(0,soFromBeginning);
    WritePropertyB('STREAM',compi.Stream,Stream);
   end;
  end;
  WritePropertyI('ROTATION',compi.Rotation,Stream);
  WritePropertyI('DRAWSTYLE',Integer(compi.DrawStyle),Stream);
  WritePropertyI('DPIRES',compi.dpires,Stream);
  WritePropertyI('COPYMODE',compi.CopyMode,Stream);
  WritePropertyI('CACHEDIMAGE',Integer(compi.CachedImage),Stream);
 end
 else
 // TRpChart
 if comp is TRpChart then
 begin
  compc:=TRpChart(comp);
  WritePropertyW('VALUEEXPRESSION',compc.ValueExpression,Stream);
  WritePropertyW('VALUEXEXPRESSION',compc.ValueXExpression,Stream);
  WritePropertyW('GETVALUECONDITION',compc.GetValueCondition,Stream);
  WritePropertyW('CHANGESERIEEXPRESSION',compc.ChangeSerieExpression,Stream);
  WritePropertyW('CAPTIONEXPRESSION',compc.CaptionExpression,Stream);
  WritePropertyW('COLOREXPRESSION',compc.ColorExpression,Stream);
  WritePropertyW('SERIECOLOREXPRESSION',compc.SerieColorExpression,Stream);
  WritePropertyW('SERIECAPTION',compc.SerieCaption,Stream);
  WritePropertyW('CLEAREXPRESSION',compc.ClearExpression,Stream);
//  WritePropertyI('SERIES',Integer(compc.Series),Stream);
  if compc.Series.Count>0 then
   WritePropertyT('SERIESCOLORS',SeriesColorsText(compc),Stream);
  WritePropertyBool('CHANGESERIEBOOL',compc.ChangeSerieBool,Stream);
  WritePropertyI('CHARTTYPE',Integer(compc.ChartType),Stream);
  WritePropertyW('IDENTIFIER',compc.Identifier,Stream);
  WritePropertyBool('CLEAREXPRESSIONBOOL',compc.ClearExpressionBool,Stream);
  WritePropertyI('DRIVER',Integer(compc.Driver),Stream);
  WritePropertyBool('VIEW3D',compc.View3d,Stream);
  WritePropertyBool('VIEW3DWALLS',compc.View3dWalls,Stream);
  WritePropertyI('PERSPECTIVE',compc.Perspective,Stream);
  WritePropertyI('ELEVATION',compc.Elevation,Stream);
  WritePropertyI('ROTATION',compc.Rotation,Stream);
  WritePropertyI('ZOOM',compc.Zoom,Stream);
  WritePropertyI('HORZOFFSET',compc.HorzOffset,Stream);
  WritePropertyI('VERTOFFSET',compc.VertOffset,Stream);
  WritePropertyI('TILT',compc.Tilt,Stream);
  WritePropertyBool('ORTHOGONAL',compc.Orthogonal,Stream);
  WritePropertyI('MULTIBAR',Integer(compc.Multibar),Stream);
  WritePropertyI('RESOLUTION',compc.Resolution,Stream);
  WritePropertyBool('SHOWLEGEND',compc.ShowLegend,Stream);
  WritePropertyBool('SHOWHINT',compc.ShowHint,Stream);
  WritePropertyI('MARKSTYLE',compc.MarkStyle,Stream);
  WritePropertyI('HORZFONTSIZE',compc.HorzFontSize,Stream);
  WritePropertyI('VERTFONTSIZE',compc.VertFontSize,Stream);
  WritePropertyI('HORZFONTROTATION',compc.HorzFontRotation,Stream);
  WritePropertyI('VERTFONTROTATION',compc.VertFontRotation,Stream);
  WritePropertyI('AUTORANGE', Integer(compc.AutoRange), Stream);
  WritePropertyD('YMIN', compc.YMin, Stream);
  WritePropertyD('YMAX', compc.YMax, Stream);
 end
 else
 // TRpBarcode
 if comp is TRpBarcode then
 begin
  compb:=TRpBarcode(comp);
  WritePropertyW('EXPRESSION',compb.Expression,Stream);
  WritePropertyI('MODUL',compb.Modul,Stream);
  WritePropertyD('RATIO',compb.Ratio,Stream);
  WritePropertyI('TYP',Integer(compb.Typ),Stream);
  WritePropertyBool('CHECKSUM',compb.CheckSum,Stream);
  WritePropertyW('DISPLAYFORMAT',compb.DisplayFormat,Stream);
  WritePropertyI('ROTATION',compb.Rotation,Stream);
  WritePropertyI('BCOLOR',compb.BColor,Stream);
  WritePropertyI('BACKCOLOR',compb.BackColor,Stream);
  WritePropertyBool('TRANSPARENT',compb.Transparent,Stream);
  WritePropertyI('NUMCOLUMNS',compb.NumCOlumns,Stream);
  WritePropertyI('NUMROWS',compb.NumRows,Stream);
  WritePropertyI('ECCLEVEL',compb.ECCLevel,Stream);
  WritePropertyBool('TRUNCATED',compb.Truncated,Stream);
 end;
 WriteStringToStream('</COMPONENT>'+CRLF,Stream);
end;


function StringToRpString(astring:AnsiString):AnsiString;
var
 i:integer;
 alen:integer;
 asubs:AnsiString;
begin
 Result:='';
 alen:=0;
 for i:=1 to Length(astring) do
 begin
  if RpIsAlpha(astring[i]) then
  begin
   Result:=Result+astring[i];
   inc(alen);
   if (alen > C_MAXDATAWIDTH) then
   begin
    alen:=0;
    Result:=Result+CRLF;
   end;
  end
  else
  begin
   asubs:=AnsiString('#'+IntToStr(Ord(astring[i]))+'#');
   Result:=Result+asubs;
   alen:=alen+Length(asubs);
   if (alen > C_MAXDATAWIDTH) then
   begin
    alen:=0;
    Result:=Result+CRLF;
   end;
  end;
 end;
end;

function WStringToRpString(astring:WideString):AnsiString;
var
 i,alen:integer;
 subs:AnsiString;
begin
 Result:='';
 alen:=0;
 for i:=1 to Length(astring) do
 begin
  if RpIsAlphaW(astring[i]) then
  begin
   Result:=AnsiString(String(Result)+astring[i]);
   inc(alen);
   if (alen >C_MAXDATAWIDTH) then
   begin
    alen:=0;
    Result:=Result+CRLF;
   end;
  end
  else
  begin
   subs:=AnsiString('#'+IntToStr(Ord(astring[i]))+'#');
   Result:=Result+subs;
   alen:=alen+Length(subs);
   if (alen > C_MAXDATAWIDTH) then
   begin
    alen:=0;
    Result:=Result+CRLF;
   end;
  end;
 end;
end;

function RpStringToString(rpstring:Ansistring):AnsiString;
var
 anumber:Integer;
 i,outindex,rplen:integer;
begin
 rplen:=Length(rpstring);
 SetLength(Result,rplen);
 i:=1;
 outindex:=0;
 while (i<=rplen) do
 begin
  if ((RpIsAlpha(rpstring[i])) or (rpstring[i]='#')) then
  begin
    if rpstring[i]='#' then
    begin
     anumber:=0;
     inc(i);
     while (i<=rplen) do
     begin
      if rpstring[i]='#' then
      begin
       inc(i);
       break;
      end
      else
      begin
       anumber:=(anumber*10)+(Ord(rpstring[i])-Ord('0'));
       inc(i);
      end;
     end;
     inc(outindex);
     Result[outindex]:=AnsiChar(Chr(anumber mod 256));
    end
    else
    begin
     inc(outindex);
     Result[outindex]:=rpstring[i];
     inc(i);
    end;
  end
  else
   inc(i);
 end;
 SetLength(Result,outindex);
end;

function RpStringToWString(rpstring:Ansistring):WideString;
var
 anumber:Integer;
 i,outindex,rplen:integer;
begin
 rplen:=Length(rpstring);
 SetLength(Result,rplen);
 i:=1;
 outindex:=0;
 while (i<=rplen) do
 begin
  if ((RpIsAlpha(rpstring[i])) or (rpstring[i]='#')) then
  begin
    if rpstring[i]='#' then
    begin
     anumber:=0;
     inc(i);
     while (i<=rplen) do
     begin
      if rpstring[i]='#' then
      begin
       inc(i);
       break;
      end
      else
      begin
       anumber:=(anumber*10)+(Ord(rpstring[i])-Ord('0'));
       inc(i);
      end;
     end;
     inc(outindex);
     // A UTF-16 code unit: U+FFFF is 65535 (mod 65535 read it as U+0000)
     Result[outindex]:=WideChar(anumber mod 65536);
    end
    else
    begin
     inc(outindex);
     Result[outindex]:=WideChar(rpstring[i]);
     inc(i);
    end;
  end
  else
   inc(i);
 end;
 SetLength(Result,outindex);
end;

procedure WritePropertyI(propname:Ansistring;propvalue:integer;stream:TStream);
var
 astring:Ansistring;
begin
 astring:='<'+propname+' type="Integer">'+AnsiString(IntToStr(propvalue))+'</'+propname+'>'+CRLF;
 WriteStringToStream(astring,stream);
end;

procedure WritePropertyI64(propname:Ansistring;propvalue:Int64;stream:TStream);
var
 astring:Ansistring;
begin
 astring:='<'+propname+' type="Integer">'+AnsiString(IntToStr(propvalue))+'</'+propname+'>'+CRLF;
 WriteStringToStream(astring,stream);
end;

{$IFDEF FPC}
// FloatToStrF of FPC 3.2 gives at most 15 digits of a double; Str gives up to 17, in the
// exponent form (" 3.0000000000000004E-001"): the same text as ffGeneral with that precision
function RpDoubleToGeneral(avalue:double;precision:integer):string;
var
 s,digits:string;
 epos,exponent:integer;
 negative:boolean;
begin
 Str(avalue:precision+7,s);
 s:=Trim(s);
 epos:=Pos('E',s);
 if (epos<3) or (not (s[Length(s)] in ['0'..'9'])) then
 begin
  // NaN or infinity
  Result:=FloatToStrF(avalue,ffGeneral,15,0);
  exit;
 end;
 negative:=s[1]='-';
 if negative then
 begin
  Delete(s,1,1);
  dec(epos);
 end;
 exponent:=StrToInt(Copy(s,epos+1,Length(s)));
 digits:=s[1]+Copy(s,3,epos-3);
 while (Length(digits)>1) and (digits[Length(digits)]='0') do
  Delete(digits,Length(digits),1);
 if (exponent<-5) or (exponent>=precision) then
 begin
  Result:=digits[1];
  if Length(digits)>1 then
   Result:=Result+'.'+Copy(digits,2,Length(digits));
  Result:=Result+'E'+IntToStr(exponent);
 end
 else
 if exponent<0 then
  Result:='0.'+StringOfChar('0',-exponent-1)+digits
 else
 begin
  while Length(digits)<exponent+1 do
   digits:=digits+'0';
  Result:=Copy(digits,1,exponent+1);
  if Length(digits)>exponent+1 then
   Result:=Result+'.'+Copy(digits,exponent+2,Length(digits));
 end;
 if negative then
  Result:='-'+Result;
end;
{$ENDIF}

// The shortest text that reads back as the same double, as the .Net engine writes it: with 15
// digits (FloatToStr) the last ones were lost, 0.30000000000000004 was written 0.3
function RpDoubleToStr(avalue:double):Ansistring;
var
 fs:TFormatSettings;
 precision:integer;
 atext:string;
 back:double;
begin
{$IFDEF FPC}
 fs:=DefaultFormatSettings;
{$ELSE}
 fs:=FormatSettings;
{$ENDIF}
 fs.DecimalSeparator:='.';
 fs.ThousandSeparator:=',';
 atext:='';
 for precision:=15 to 17 do
 begin
{$IFDEF FPC}
  if precision>15 then
   atext:=RpDoubleToGeneral(avalue,precision)
  else
{$ENDIF}
  atext:=FloatToStrF(avalue,ffGeneral,precision,0,fs);
  if not SysUtils.TryStrToFloat(atext,back,fs) then
   break;
  if back=avalue then
   break;
 end;
 Result:=AnsiString(atext);
end;


function RpStrToDouble(avalue:Ansistring):double;
var
 olddec:char;
begin
{$IFDEF DELPHI2009UP}
 olddec:=FormatSettings.DecimalSeparator;
 try
  FormatSettings.DecimalSeparator:='.';
  Result:=StrToFloat(String(avalue));
 finally
  FormatSettings.DecimalSeparator:=olddec;
 end;
{$ELSE}
 olddec:=DecimalSeparator;
 try
  DecimalSeparator:='.';
  Result:=StrToFloat(avalue);
 finally
  DecimalSeparator:=olddec;
 end;
{$ENDIF}
end;

procedure WritePropertyD(propname:Ansistring;propvalue:double;stream:TStream);
var
 astring:Ansistring;
begin
 astring:='<'+propname+' type="Double">'+RpDoubleToStr(propvalue)+'</'+propname+'>'+CRLF;
 WriteStringToStream(astring,stream);
end;


function RpBoolToStr(avalue:Boolean):AnsiString;
begin
 if avalue then
  Result:='True'
 else
  Result:='False';
end;

function RpStrToBool(avalue:AnsiString):Boolean;
begin
 if avalue='True' then
  Result:=True
 else
  Result:=False;
end;


procedure WritePropertyBool(propname:Ansistring;propvalue:Boolean;stream:TStream);
var
 astring:Ansistring;
begin
 astring:='<'+propname+' type="Boolean">'+RpBoolToStr(propvalue)+'</'+propname+'>'+CRLF;
 WriteStringToStream(astring,stream);
end;

procedure WritePropertyS(propname:Ansistring;propvalue:AnsiString;stream:TStream);
var
 astring:Ansistring;
begin
 astring:='<'+propname+' type="String">'+StringToRpString(propvalue)+'</'+propname+'>'+CRLF;
 WriteStringToStream(astring,stream);
end;

procedure WritePropertyW(propname:Ansistring;propvalue:WideString;stream:TStream);
var
 astring:Ansistring;
begin
 astring:='<'+propname+' type="WideString">'+WStringToRpString(propvalue)+'</'+propname+'>'+CRLF;
 WriteStringToStream(astring,stream);
end;

procedure WritePropertyT(propname:Ansistring;const propvalue:String;stream:TStream);
{$IFDEF FPC}
var
 i:integer;
{$ENDIF}
begin
{$IFDEF FPC}
 // The strings of FPC are UTF-8: ASCII is written as before, the rest as UTF-16 (the UTF-8 bytes
 // written as a String were read as ANSI by Delphi and as Latin-1 by .Net)
 for i:=1 to Length(propvalue) do
 begin
  if Ord(propvalue[i])>127 then
  begin
   WritePropertyW(propname,WideString(UnicodeString(propvalue)),stream);
   exit;
  end;
 end;
 WritePropertyS(propname,AnsiString(propvalue),stream);
{$ELSE}
 if String(AnsiString(propvalue))=propvalue then
  WritePropertyS(propname,AnsiString(propvalue),stream)
 else
  WritePropertyW(propname,propvalue,stream);
{$ENDIF}
end;

// Whether a value holds a character code above 255: the .Net engine writes the UTF-16 code units
// of every text with the type String, Delphi the bytes of the ANSI code page
function RpHasWideCode(const rpstring:AnsiString):Boolean;
var
 i,anumber:integer;
begin
 Result:=false;
 i:=1;
 while i<=Length(rpstring) do
 begin
  if rpstring[i]='#' then
  begin
   anumber:=0;
   inc(i);
   while (i<=Length(rpstring)) and (rpstring[i]<>'#') do
   begin
    if anumber<=65535 then
     anumber:=(anumber*10)+(Ord(rpstring[i])-Ord('0'));
    inc(i);
   end;
   if anumber>255 then
   begin
    Result:=true;
    exit;
   end;
  end;
  inc(i);
 end;
end;

{$IFDEF FPC}
// The bytes of a String value written by older versions: UTF-8 when FPC wrote them, else the
// Windows-1252 of a Delphi engine (Latin-1 for the .Net one, the same but for 128 to 159)
function RpLegacyBytesToString(const bytes:AnsiString):String;
const
 Cp1252:array[$80..$9F] of Word=($20AC,$0081,$201A,$0192,$201E,$2026,$2020,$2021,
  $02C6,$2030,$0160,$2039,$0152,$008D,$017D,$008F,$0090,$2018,$2019,$201C,$201D,$2022,
  $2013,$2014,$02DC,$2122,$0161,$203A,$0153,$009D,$017E,$0178);
var
 i,j,follow:integer;
 b:Byte;
 isutf8:boolean;
 wide:UnicodeString;
begin
 wide:='';
 isutf8:=true;
 i:=1;
 while i<=Length(bytes) do
 begin
  b:=Ord(bytes[i]);
  if b<$80 then
   follow:=0
  else if (b>=$C2) and (b<=$DF) then
   follow:=1
  else if (b>=$E0) and (b<=$EF) then
   follow:=2
  else if (b>=$F0) and (b<=$F4) then
   follow:=3
  else
  begin
   isutf8:=false;
   break;
  end;
  for j:=1 to follow do
  begin
   if (i+j>Length(bytes)) or ((Ord(bytes[i+j]) and $C0)<>$80) then
   begin
    isutf8:=false;
    break;
   end;
  end;
  if not isutf8 then
   break;
  inc(i,follow+1);
 end;
 if isutf8 then
 begin
  Result:=bytes;
  exit;
 end;
 SetLength(wide,Length(bytes));
 for i:=1 to Length(bytes) do
 begin
  b:=Ord(bytes[i]);
  if (b>=$80) and (b<=$9F) then
   wide[i]:=WideChar(Cp1252[b])
  else
   wide[i]:=WideChar(b);
 end;
 Result:=String(wide);
end;
{$ENDIF}

function RpPropToString(const propvalue,proptype:AnsiString):String;
begin
{$IFDEF FPC}
 if (proptype='WideString') or RpHasWideCode(propvalue) then
  Result:=String(UnicodeString(RpStringToWString(propvalue)))
 else
  Result:=RpLegacyBytesToString(RpStringToString(propvalue));
{$ELSE}
 if (proptype='WideString') or RpHasWideCode(propvalue) then
  Result:=RpStringToWString(propvalue)
 else
  Result:=String(RpStringToString(propvalue));
{$ENDIF}
end;


function StreamToBin(astream:TStream):AnsiString;
var
 abufsource,abufdest:PAnsiChar;
begin
 abufsource:=AllocMem(astream.Size);
 try
  astream.Read(abufsource^,astream.size);
  abufdest:=AllocMem(astream.size*2+1);
  try
   BinToHex(abufsource,abufdest,astream.size);
   Result:=AnsiString(abufdest);
  finally
   FreeMem(abufdest);
  end;
 finally
  FreeMem(abufsource);
 end;
{ Result:='';
 alen:=0;
 while astream.Read(achar,1)>0 do
 begin
  Result:=Result+NibbleToHex(achar shr 4)+NibbleToHex(achar AND $0F);
  inc(alen);
  if (alen mod C_MAXDATAWIDTH)=0 then
  begin
   Result:=Result+CRLF;
   alen:=0;
  end;
 end;
}end;

procedure BinToStream(astream:TStream;bin2:Ansistring;propsize:Ansistring);
var
 alen:integer;
 abufdest:PAnsiCHar;
 readed:integer;
begin
 alen:=StrToInt(String(propsize));
 if alen=0 then
  exit;
 abufdest:=AllocMem(alen+1);
 try
  readed:=HexToBin(PAnsiChar(bin2),abufdest,alen);
  if readed<>alen then
   Raise Exception.Create('Expected: '+IntToStr(alen)+' Found: '
    +INtToStr(readed));
  astream.Write(abufdest^,alen);
  astream.Seek(0,soFromBeginning);
 finally
  FreeMem(abufdest);
 end;
end;

{$IFDEF FPC}
// BINCUE (UTF-8 JSON bytes, the same as Delphi writes) -> the designer undo
// cue, through RpUndoCueFromJson
procedure ReadBinCueFPC(report:TComponent;const propvalue,propsize:AnsiString);
var
 memstream:TMemoryStream;
 cuejson:string;
begin
 memstream:=TMemoryStream.Create;
 try
  BinToStream(memstream,RpStringToString(propvalue),propsize);
  if memstream.Size>0 then
  begin
   SetLength(cuejson,memstream.Size);
   memstream.Position:=0;
   memstream.Read(cuejson[1],memstream.Size);
   RpUndoCueFromJson(report,cuejson);
  end;
 finally
  memstream.Free;
 end;
end;
{$ENDIF}


procedure WritePropertyB(propname:Ansistring;propvalue:TStream;stream:TStream);
var
 astring:Ansistring;
begin
 astring:='<'+propname+' type="Binary" size="'+AnsiString(IntTostr(propvalue.size))+'">'+StringToRpString(StreamToBin(propvalue))+'</'+propname+'>'+CRLF;
 WriteStringToStream(astring,stream);
end;

procedure WriteReportXML(areport:TComponent;Stream:TStream);
var
 report:TRpReport;
 i,j:integer;
 astring:Ansistring;
 asubrep:TRpSubReport;
 asec:TRpSection;
 efile:TEmbeddedFile;
 emptystream:TMemoryStream;
begin
 report:=TRpReport(areport);
 // Write header
 astring:='<?xml version="1.0" standalone="no"?>'+CRLF;
 WriteStringToStream(astring,stream);
 astring:='<!DOCTYPE REPORT_MANAGER_2>'+CRLF;
 WriteStringToStream(astring,stream);
 // Write XML Report properties
 astring:='<REPORT>'+CRLF;
 WriteStringToStream(astring,stream);
 WriteReportPropsXML(report,Stream);

 // Write database info list
 for i:=0 to report.databaseinfo.count-1 do
 begin
  astring:='<DATABASEINFO>'+CRLF;
  WriteStringToStream(astring,stream);
  WriteDatabaseInfoXML(report.databaseinfo.Items[i],Stream);
  astring:='</DATABASEINFO>'+CRLF;
  WriteStringToStream(astring,stream);
 end;
 // Write data info list
 for i:=0 to report.datainfo.count-1 do
 begin
  astring:='<DATAINFO>'+CRLF;
  WriteStringToStream(astring,stream);
  WriteDataInfoXML(report.datainfo.Items[i],Stream);
  astring:='</DATAINFO>'+CRLF;
  WriteStringToStream(astring,stream);
 end;
 // Write parameter list
 for i:=0 to report.Params.count-1 do
 begin
  astring:='<PARAMETER>'+CRLF;
  WriteStringToStream(astring,stream);
  WriteParamXML(report.params.Items[i],Stream);
  astring:='</PARAMETER>'+CRLF;
  WriteStringToStream(astring,stream);
 end;
 // Write SubReports
 for i:=0 to report.SubReports.Count-1 do
 begin
  asubrep:=report.SubReports.Items[i].SubReport;
  astring:='<SUBREPORT>'+CRLF;
  WriteStringToStream(astring,stream);
  WriteSubReportXML(asubrep,Stream);
  for j:=0 to asubrep.Sections.Count-1 do
  begin
   asec:=asubrep.Sections.Items[j].Section;
   WriteSectionXML(asec,Stream);
  end;
  astring:='</SUBREPORT>'+CRLF;
  WriteStringToStream(astring,stream);
 end;
  // Write Embedded files
 for i:=0 to Length(report.EmbeddedFiles)-1 do
 begin
  efile:=report.EmbeddedFiles[i];
  astring:='<EMBEDDEDFILE>'+CRLF;
  WriteStringToStream(astring,stream);
  WritePropertyT('FILENAME',efile.FileName,Stream);
  WritePropertyT('MIMETYPE',efile.MimeType,Stream);
  WritePropertyT('DESCRIPTION',efile.Description,Stream);
  WritePropertyT('CREATIONDATE',efile.CreationDate,Stream);
  WritePropertyT('MODIFICATIONDATE',efile.ModificationDate,Stream);
  WritePropertyI('RELATIONSHIP', Integer(efile.AFRelationShip), Stream);
  // A file without contents (made by code) is written empty
  if efile.Stream=nil then
  begin
   emptystream:=TMemoryStream.Create;
   try
    WritePropertyB('STREAM', emptystream, Stream);
   finally
    emptystream.Free;
   end;
  end
  else
  begin
   efile.Stream.Position:=0;
   WritePropertyB('STREAM', efile.Stream, Stream);
  end;
  astring:='</EMBEDDEDFILE>'+CRLF;
  WriteStringToStream(astring,stream);
 end;



 astring:='</REPORT>'+CRLF;
 WriteStringToStream(astring,stream);
end;

procedure ReadPropDBInfo(dbitem:TRpDatabaseInfoItem;
 propname,propvalue,proptype,propsize:Ansistring);
begin
 if propname='NAME' then
  dbitem.Name:=RpPropToString(propvalue,proptype)
 else
 if propname='CONFIGFILE' then
  dbitem.Configfile:=RpPropToString(propvalue,proptype)
 else
 if propname='LOADPARAMS' then
  dbitem.LoadParams:=RpStrToBool(propvalue)
 else
 if propname='LOADDRIVERPARAMS' then
  dbitem.LoadDriverParams:=RpStrToBool(propvalue)
 else
 if propname='LOGINPROMPT' then
  dbitem.LoginPrompt:=RpStrToBool(propvalue)
 else
 if propname='DRIVER' then
  dbitem.Driver:=TRpDBDriver(StrToInt(String(propvalue)))
 else
 if propname='DOTNETDRIVER' then
  dbitem.DotNetDriver:=StrToInt(String(propvalue))
 else
 if propname='PROVIDERFACTORY' then
  dbitem.ProviderFactory:=RpPropToString(propvalue,proptype)
 else
 if propname='REPORTTABLE' then
  dbitem.ReportTable:=RpPropToString(propvalue,proptype)
 else
 if propname='REPORTSEARCHFIELD' then
  dbitem.ReportSearchField:=RpPropToString(propvalue,proptype)
 else
 if propname='REPORTFIELD' then
  dbitem.ReportField:=RpPropToString(propvalue,proptype)
 else
 if propname='REPORTGROUPSTABLE' then
  dbitem.ReportGroupsTable:=RpPropToString(propvalue,proptype)
 else
 if propname='ADOCONNECTIONSTRING' then
  dbitem.ADOConnectionString:=RpStringToWString(propvalue);
end;

procedure ReadPropSubReport(subrep:TRpSubReport;
 propname,propvalue,proptype,propsize:Ansistring);
begin
 if propname='ALIAS' then
  subrep.Alias:=RpPropToString(propvalue,proptype)
 else
 if propname='PARENTSUBREPORT' then
  subrep.ParentSub:=RpPropToString(propvalue,proptype)
 else
 if propname='PARENTSECTION' then
  subrep.ParentSec:=RpPropToString(propvalue,proptype)
 else
 if propname='PRINTONLYIFDATAAVAILABLE' then
  subrep.PrintOnlyIfDataAvailable:=RpStrToBool(propvalue)
 else
 if propname='REOPENONPRINT' then
  subrep.ReOpenOnPrint:=RpStrToBool(propvalue);
end;

procedure ReadPropSection(sec:TRpSection;
 propname,propvalue,proptype,propsize:Ansistring);
var
  memstream:TMemoryStream;
begin
 if propname='CHANGEEXPRESSION' then
  sec.ChangeExpression:=RpStringToWString(propvalue)
 else
 if propname='BEGINPAGEEXPRESSION' then
  sec.BeginPageExpression:=RpStringToWString(propvalue)
 else
 if propname='BEGINPAGE' then
  sec.BeginPage:=RpStrToBool(propvalue)
 else
 if propname='SKIPEXPREV' then
  sec.SkipExpreV:=RpStringToWString(propvalue)
 else
 if propname='SKIPEXPREH' then
  sec.SkipExpreH:=RpStringToWString(propvalue)
 else
 if propname='SKIPTOPAGEEXPRE' then
  sec.SkipToPageExpre:=RpStringToWString(propvalue)
 else
 if propname='BACKEXPRESSION' then
  sec.BackExpression:=RpStringToWString(propvalue)
 else
 if propname='PRINTCONDITION' then
  sec.PrintCondition:=RpStringToWString(propvalue)
 else
 if propname='DOAFTERPRINT' then
  sec.DoAfterPrint:=RpStringToWString(propvalue)
 else
 if propname='DOBEFOREPRINT' then
  sec.DoBeforePrint:=RpStringToWString(propvalue)
 else
 if propname='WIDTH' then
  sec.Width:=StrToInt(String(propvalue))
 else
 if propname='HEIGHT' then
  sec.Height:=StrToInt(String(propvalue))
 else
 if propname='SUBREPORT' then
  sec.SubReportName:=RpPropToString(propvalue,proptype)
 else
 if propname='GROUPNAME' then
  sec.GroupName:=RpPropToString(propvalue,proptype)
 else
 if propname='CHANGEBOOL' then
  sec.ChangeBool:=RPStrToBool(propvalue)
 else
 if propname='PAGEREPEAT' then
  sec.PageRepeat:=RPStrToBool(propvalue)
 else
 if propname='FORCEPRINT' then
  sec.FooterAtReportEnd:=RPStrToBool(propvalue)
 else
 if propname='SKIPPAGE' then
  sec.SkipPage:=RPStrToBool(propvalue)
 else
 if propname='ALIGNBOTTOM' then
  sec.AlignBottom:=RPStrToBool(propvalue)
 else
 if propname='SECTIONTYPE' then
  sec.SectionType:=TRpSectionType(StrToInt(String(propvalue)))
 else
 if propname='AUTOEXPAND' then
  sec.AutoExpand:=RPStrToBool(propvalue)
 else
 if propname='AUTOCONTRACT' then
  sec.AutoContract:=RPStrToBool(propvalue)
 else
 if propname='HORZDESP' then
  sec.HorzDesp:=RPStrToBool(propvalue)
 else
 if propname='VERTDESP' then
  sec.VertDesp:=RPStrToBool(propvalue)
 else
 if propname='EXTERNALFILENAME' then
  sec.ExternalFileName:=RpPropToString(propvalue,proptype)
 else
 if propname='EXTERNALCONNECTION' then
  sec.ExternalConnection:=RpPropToString(propvalue,proptype)
 else
 if propname='EXTERNALTABLE' then
  sec.ExternalTable:=RpPropToString(propvalue,proptype)
 else
 if propname='EXTERNALFIELD' then
  sec.ExternalField:=RpPropToString(propvalue,proptype)
 else
 if propname='EXTERNALSEARCHFIELD' then
  sec.ExternalSearchField:=RpPropToString(propvalue,proptype)
 else
 if propname='EXTERNALSEARCHVALUE' then
  sec.ExternalSearchValue:=RpPropToString(propvalue,proptype)
 else
 if propname='STREAMFORMAT' then
  sec.StreamFormat:=TRpStreamFormat(StrToInt(String(propvalue)))
 else
 if propname='CHILDSUBREPORT' then
  sec.ChildSubReportName:=RpPropToString(propvalue,proptype)
 else
 if propname='SKIPRELATIVEH' then
  sec.SkipRelativeH:=RPStrToBool(propvalue)
 else
 if propname='SKIPRELATIVEV' then
  sec.SkipRelativeV:=RPStrToBool(propvalue)
 else
 if propname='SKIPTYPE' then
  sec.SkipType:=TRpSkipType(StrToInt(String(propvalue)))
 else
 if propname='ININUMPAGE' then
  sec.IniNumPage:=RPStrToBool(propvalue)
 else
 if propname='GLOBAL' then
  sec.Global:=RPStrToBool(propvalue)
 else
 if propname='DPIRES' then
  sec.DPIRes:=StrToInt(String(propvalue))
 else
 if propname='CACHEDIMAGE' then
 begin
  if (propvalue<>'False') then
   sec.CachedImage:=TrpCachedImage(StrToInt(String(propvalue)));
 end
 else
 if propname='BACKSTYLE' then
  sec.BackStyle:=TRpBackStyle(StrToInt(String(propvalue)))
 else
 if propname='DRAWSTYLE' then
  sec.DrawStyle:=TRpImageDrawStyle(StrToInt(String(propvalue)))
 else
 if propname='STREAM' then
 begin
  memstream:=TMemoryStream.Create;
  try
   BinToStream(memstream,RpStringToString(propvalue),propsize);
//    BinToStream(memstream,propvalue,propsize);
   memstream.Seek(0,soFromBeginning);
   sec.SetStream(memstream);
  finally
   memstream.free;
  end;
 end;
end;

procedure ReadPropDataInfo(ditem:TRpDataInfoItem;
 propname,propvalue,proptype,propsize:Ansistring);
begin
 if propname='NAME' then
  ditem.Name:=RpPropToString(propvalue,proptype)
 else
 if propname='DATABASEALIAS' then
  ditem.DataBaseAlias:=RpPropToString(propvalue,proptype)
 else
 if propname='SQL' then
  ditem.SQL:=RpStringToWString(propvalue)
   else
   if propname='SQLEXPLANATION' then
    ditem.SQLExplanation:=RpStringToWString(propvalue)
   else
   if propname='SQLEXPLANATIONERROR' then
    ditem.SQLExplanationError:=RpStringToWString(propvalue)
  else
  if propname='HUBSCHEMAID' then
   ditem.HubSchemaId:=StrToInt64Def(String(propvalue),0)
  else
  if propname='SCHEMANAME' then
   ditem.SchemaName:=RpStringToWString(propvalue)
 else
 if propname='DATASOURCE' then
  ditem.DataSource:=RpPropToString(propvalue,proptype)
 else
 if propname='MYBASEFILENAME' then
  ditem.MyBaseFileName:=RpPropToString(propvalue,proptype)
 else
 if propname='MYBASEFIELDS' then
  ditem.MyBaseFields:=RpPropToString(propvalue,proptype)
 else
 if propname='MYBASEINDEXFIELDS' then
  ditem.MyBaseIndexFields:=RpPropToString(propvalue,proptype)
 else
 if propname='MYBASEINDEXFIELDS' then
  ditem.MyBaseIndexFields:=RpPropToString(propvalue,proptype)
 else
 if propname='MYBASEMASTERFIELDS' then
  ditem.MyBaseMasterFields:=RpPropToString(propvalue,proptype)
 else
 if propname='BDEINDEXFIELDS' then
  ditem.BDEIndexFields:=RpPropToString(propvalue,proptype)
 else
 if propname='BDEINDEXNAME' then
  ditem.BDEIndexName:=RpPropToString(propvalue,proptype)
 else
 if propname='BDETABLE' then
  ditem.BDETable:=RpPropToString(propvalue,proptype)
 else
 if propname='BDETYPE' then
  ditem.BDEType:=TRpDatasetType(StrToInt(String(propvalue)))
 else
 if propname='BDEFILTER' then
  ditem.BDEFilter:=RpPropToString(propvalue,proptype)
 else
 if propname='BDEMASTERFIELDS' then
  ditem.BDEMasterFields:=RpPropToString(propvalue,proptype)
 else
 if propname='BDEFIRSTRANGE' then
  ditem.BDEFirstRange:=RpPropToString(propvalue,proptype)
 else
 if propname='BDELASTRANGE' then
  ditem.BDELastRange:=RpPropToString(propvalue,proptype)
 else
 if propname='DATAUNIONS' then
  ditem.DataUnions.Text:=RpPropToString(propvalue,proptype)
 else
 if propname='GROUPUNION' then
  ditem.GroupUnion:=RpStrToBool(propvalue)
 else
 if propname='OPENONSTART' then
  ditem.OpenOnStart:=RpStrToBool(propvalue)
 else
 if propname='PARALLELUNION' then
  ditem.ParallelUnion:=RpStrToBool(propvalue);
end;

procedure ReadPropParam(aparam:TRpParam;
 propname,propvalue,proptype,propsize:Ansistring);
begin
 if propname='INTNAME' then
  aparam.IntName:=RpPropToString(propvalue,proptype)
 else
 if propname='DESCRIPTION' then
  aparam.Descriptions:=RpStringToWString(propvalue)
 else
 if propname='HINT' then
  aparam.Hints:=RpStringToWString(propvalue)
 else
 if propname='ERRORMESSAGE' then
  aparam.ErrorMessages:=RpStringToWString(propvalue)
 else
 if propname='VALIDATION' then
  aparam.Validation:=RpStringToWString(propvalue)
 else
 if propname='SEARCH' then
  aparam.Search:=RpStringToWString(propvalue)
 else
 if propname='VISIBLE' then
  aparam.Visible:=RpStrToBool(propvalue)
 else
 if propname='ISREADONLY' then
  aparam.IsReadOnly:=RpStrToBool(propvalue)
 else
 if propname='NEVERVISIBLE' then
  aparam.NeverVisible:=RpStrToBool(propvalue)
 else
 if propname='ALLOWNULLS' then
  aparam.AllowNulls:=RpStrToBool(propvalue)
 else
 if propname='PARAMTYPE' then
  aparam.ParamType:=TrpPAramType(StrToInt(String(propvalue)))
 else
 if propname='DATASETS' then
  aparam.Datasets.Text:=RpPropToString(propvalue,proptype)
 else
 if propname='ITEMS' then
  aparam.Items.Text:=RpPropToString(propvalue,proptype)
 else
 if propname='VALUES' then
  aparam.Values.Text:=RpPropToString(propvalue,proptype)
 else
 if propname='SELECTED' then
  aparam.Selected.Text:=RpPropToString(propvalue,proptype)
 else
 if propname='LOOKUPDATASET' then
  aparam.LookupDataset:=RpPropToString(propvalue,proptype)
 else
 if propname='SEARCHDATASET' then
  aparam.SearchDataset:=RpPropToString(propvalue,proptype)
 else
 if propname='SEARCHPARAM' then
  aparam.SearchParam:=RpPropToString(propvalue,proptype)
 else
 if propname='VALUE' then
 begin
  aparam.Value:=Null;
  case aparam.ParamType of
   // The text types the writer saves (substitution lists and initial expressions were written
   // but not read back: their value was lost; the .Net and TypeScript readers read them)
   rpParamString,rpParamExpreA,rpParamExpreB,rpParamSubst,rpParamSubstE,rpParamList,rpParamSubstList,
   rpParamInitialExpression,rpParamUnknown:
    aparam.Value:=WideString(RpPropToString(propvalue,proptype));
   rpParamInteger:
    begin
     aparam.Value:=StrToInt(String(propvalue));
    end;
   rpParamDouble:
    begin
     aparam.Value:=RpStrToDouble(propvalue);
    end;
   rpParamCurrency:
    begin
     aparam.Value:=RpStrToDouble(propvalue);
    end;
   rpParamDate,rpParamTime,rpParamDateTime:
    aparam.Value:=TDateTime(RpStrToDouble(propvalue));
   rpParamBool:
    aparam.Value:=RpStrToBool(propvalue);
  end;
 end;
end;

procedure ReadPropReport(report:TRpReport;
 propname,propvalue,proptype,propsize:string);
var
 actions:TRpReportActions;
begin
 if propname='WFONTNAME' then
  report.WFontName:=RpStringToWString(AnsiString(propvalue))
 else
 if propname='LFONTNAME' then
  report.LFontName:=RpStringToWString(AnsiString(propvalue))
 else
 if propname='GRIDVISIBLE' then
  report.GridVisible:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='GRIDLINES' then
  report.GridLines:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='GRIDENABLED' then
  report.GridEnabled:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='GRIDCOLOR' then
  report.GridColor:=StrToInt(propvalue)
 else
 if propname='GRIDWIDTH' then
  report.GridWidth:=StrToInt(propvalue)
 else
 if propname='GRIDHEIGHT' then
  report.GridHeight:=StrToInt(propvalue)
 else
 if propname='PAGEORIENTATION' then
  report.PageOrientation:=TrpOrientation(StrToInt(propvalue))
 else
 if propname='PAGESIZE' then
  report.PageSize:=TrpPageSize(StrToInt(propvalue))
 else
 if propname='PAGESIZEQT' then
  report.PageSizeQt:=StrToInt(propvalue)
 else
 if propname='PAGEHEIGHT' then
  report.PageHeight:=StrToInt(propvalue)
 else
 if propname='PAGEWIDTH' then
  report.PageWidth:=StrToInt(propvalue)
 else
 if propname='CUSTOMPAGEWIDTH' then
  report.CustomPageWidth:=StrToInt(propvalue)
 else
 if propname='CUSTOMPAGEHEIGHT' then
  report.CustomPageHeight:=StrToInt(propvalue)
 else
 if propname='PAGEBACKCOLOR' then
  report.PageBackColor:=StrToInt(propvalue)
 else
 if propname='PREVIEWSTYLE' then
  report.PreviewStyle:=TrpPreviewStyle(StrToInt(propvalue))
 else
 if propname='PREVIEWMARGINS' then
  report.PreviewMargins:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='PREVIEWWINDOW' then
  report.PreviewWindow:=TrpPreviewWindowStyle(StrToInt(propvalue))
 else
 if propname='LEFTMARGIN' then
  report.LeftMargin:=StrToInt(propvalue)
 else
 if propname='TOPMARGIN' then
  report.TopMargin:=StrToInt(propvalue)
 else
 if propname='RIGHTMARGIN' then
  report.RightMargin:=StrToInt(propvalue)
 else
 if propname='BOTTOMMARGIN' then
  report.BottomMargin:=StrToInt(propvalue)
 else
 if propname='PRINTERSELECT' then
  report.PrinterSelect:=TrpPrinterSelect(StrToInt(propvalue))
 else
 if propname='LANGUAGE' then
  report.Language:=StrToInt(propvalue)
 else
 if propname='COPIES' then
  report.Copies:=StrToInt(propvalue)
 else
 if propname='COLLATECOPIES' then
  report.CollateCopies:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='TWOPASS' then
  report.TwoPass:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='PRINTERFONTS' then
  report.PrinterFonts:=TRpPrinterFontsOption(StrToInt(propvalue))
 else
 if propname='PRINTONLYIFDATAAVAILABLE' then
  report.PrintOnlyIfDataAvailable:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='STREAMFORMAT' then
  report.StreamFormat:=TrpStreamFormat(StrToInt(propvalue))
 else
 if propname='REPORTACTIONDRAWERBEFORE' then
 begin
  // On the report: every property read set it to the actions of that property only, so the
  // drawer actions were always lost
  actions:=report.ReportAction;
  if RpStrToBool(AnsiString(propvalue)) then
   include(actions,rpDrawerBefore)
  else
   exclude(actions,rpDrawerBefore);
  report.ReportAction:=actions;
 end
 else
 if propname='REPORTACTIONDRAWERAFTER' then
 begin
  actions:=report.ReportAction;
  if RpStrToBool(AnsiString(propvalue)) then
   include(actions,rpDrawerAfter)
  else
   exclude(actions,rpDrawerAfter);
  report.ReportAction:=actions;
 end
 else
 if propname='PREVIEWABOUT' then
  report.PreviewAbout:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='TYPE1FONT' then
  report.Type1Font:=TRpType1Font(StrToInt(propvalue))
 else
 if propname='FONTSIZE' then
  report.FontSize:=StrToInt(propvalue)
 else
 if propname='FONTROTATION' then
  report.FontRotation:=StrToInt(propvalue)
 else
 if propname='FONTSTYLE' then
  report.FontStyle:=StrToInt(propvalue)
 else
 if propname='FONTCOLOR' then
  report.FontColor:=StrToInt(propvalue)
 else
 if propname='BACKCOLOR' then
  report.BackColor:=StrToInt(propvalue)
 else
 if propname='TRANSPARENT' then
  report.Transparent:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='CUTTEXT' then
  report.CutText:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='ALIGNMENT' then
  report.AlignMent:=StrToInt(propvalue)
 else
 if propname='VALIGNMENT' then
  report.VAlignMent:=StrToInt(propvalue)
 else
 if propname='WORDWRAP' then
  report.WordWrap:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='SINGLELINE' then
  report.SingleLine:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='BIDIMODES' then
  report.BidiModes.Text:=RpPropToString(AnsiString(propvalue),AnsiString(proptype))
 else
 if propname='MULTIPAGE' then
  report.MultiPage:=RpStrToBool(AnsiString(propvalue))
 else
 if propname='PRINTSTEP' then
  report.PrintStep:=TrpSelectFontStep(StrToInt(propvalue))
 else
 if propname='PAPERSOURCE' then
  report.PaperSource:=StrToInt(propvalue)
 else
 if propname='DUPLEX' then
  report.Duplex:=StrToInt(propvalue)
 else
 if propname='FORCEPAPERNAME' then
  report.ForcePaperName:=RpPropToString(AnsiString(propvalue),AnsiString(proptype))
 else
 if propname='LINESPERINCH' then
  report.LinesPerInch:=StrToInt(propvalue)
 else
 if propname='PDFCONFORMANCE' then
  report.PDFConformance:=TPDFConformanceType(StrToInt(propvalue))
 else
 if propname='PDFCOMPRESSED' then
  report.PDFCompressed:=RpStrToBool(AnsiString(propValue))
 else
 if propname='DOCAUTHOR' then
  report.DocAuthor:=RpPropToString(AnsiString(propValue),AnsiString(proptype))
 else
 if propname='DOCCREATOR' then
  report.DocCreator:=RpPropToString(AnsiString(propValue),AnsiString(proptype))
 else
 if propname='DOCPRODUCER' then
  report.DocProducer:=RpPropToString(AnsiString(propValue),AnsiString(proptype))
 else
 if propname='DOCSUBJECT' then
  report.DocSubject:=RpPropToString(AnsiString(propValue),AnsiString(proptype))
 else
 if propname='DOCTITLE' then
  report.DocTitle:=RpPropToString(AnsiString(propValue),AnsiString(proptype))
 else
 if propname='DOCCREATIONDATE' then
  report.DocCreationDate:=RpPropToString(AnsiString(propValue),AnsiString(proptype))
 else
 if propname='DOCMODIFICATIONDATE' then
  report.DocModificationDate:=RpPropToString(AnsiString(propValue),AnsiString(proptype))
 else
 if propname='DOCKEYWORDS' then
  report.DocKeywords:=RpPropToString(AnsiString(propValue),AnsiString(proptype))
 else
 if propname='DOCXMPCONTENT' then
  report.DocXMPContent:=RpPropToString(AnsiString(propValue),AnsiString(proptype))
 else
 if propname='BINCUE' then
 begin
{$IFNDEF FPC}
  // Read undo cue from binary JSON
  if not Assigned(report.UndoCue) then
   report.UndoCue:=TUndoCue.Create(TRpReport(report));
  begin
   var memstream:=TMemoryStream.Create;
   try
    BinToStream(memstream,RpStringToString(AnsiString(propvalue)),AnsiString(propsize));
    memstream.Position:=0;
    var jsonBytes:TBytes;
    SetLength(jsonBytes, memstream.Size);
    if memstream.Size > 0 then
    begin
     memstream.Read(jsonBytes[0], memstream.Size);
     TUndoCue(report.UndoCue).FromJSON(TEncoding.UTF8.GetString(jsonBytes));
    end;
   finally
    memstream.Free;
   end;
  end;
{$ELSE}
  // The designer restores its undo cue (the hook creates it if needed)
  if Assigned(RpUndoCueFromJson) then
  begin
   ReadBinCueFPC(TComponent(report),AnsiString(propvalue),AnsiString(propsize));
  end;
{$ENDIF}
 end;
end;

procedure ReadCompProp(comp:TRpCommonPosComponent;
 propname,propvalue,proptype,propsize:Ansistring);
var
 compt:TRpGenTextComponent;
 compl:TRpLabel;
 comps:TRpShape;
 compi:TRpImage;
 compe:TRpExpression;
 compb:TRpBarCode;
 compc:TRpChart;
 memstream:TMemoryStream;
begin
 if propname='PRINTCONDITION' then
  comp.PrintCondition:=RpStringToWString(propvalue)
 else
 if propname='DOAFTERPRINT' then
  comp.DoAfterPrint:=RpStringToWString(propvalue)
 else
 if propname='DOBEFOREPRINT' then
  comp.DoBeforePrint:=RpStringToWString(propvalue)
 else
 if propname='ANNOTATION' then
  // Written as a String (the ANSI bytes), it was read as UTF-16 code units
  comp.AnnotationExpression:=RpPropToString(propvalue,proptype)
 else
 if propname='WIDTH' then
  comp.Width:=StrToInt(String(propvalue))
 else
 if propname='HEIGHT' then
  comp.Height:=StrToInt(String(propvalue))
 else
 if propname='POSX' then
  comp.PosX:=StrToInt(String(propvalue))
 else
 if propname='POSY' then
  comp.PosY:=StrToInt(String(propvalue))
 else
 if propname='ALIGN' then
  comp.Align:=TRpPosAlign(StrToInt(String(propvalue)));
 if comp is TRpGenTextComponent then
 begin
  compt:=TRpGenTextComponent(comp);
  if propname='WFONTNAME' then
   compt.WFontName:=RPStringToWString(propvalue)
  else
  if propname='LFONTNAME' then
   compt.LFontName:=RPStringToWString(propvalue)
  else
  if propname='BIDIMODE' then
   compt.BidiMode:=TRpBidiMode(StrToInt(String(propvalue)))
  else
  if propname='TYPE1FONT' then
   compt.Type1Font:=TRpType1Font(StrToInt(String(propvalue)))
  else
  if propname='FONTSIZE' then
   compt.FontSize:=StrToInt(String(propvalue))
  else
  if propname='FONTROTATION' then
   compt.FontRotation:=StrToInt(String(propvalue))
  else
  if propname='FONTSTYLE' then
   compt.FontSTyle:=StrToInt(String(propvalue))
  else
  if propname='FONTCOLOR' then
   compt.FontColor:=StrToInt(String(propvalue))
  else
  if propname='BACKCOLOR' then
   compt.BackColor:=StrToInt(String(propvalue))
  else
  if propname='TRANSPARENT' then
   compt.Transparent:=RpStrToBool(propvalue)
  else
  if propname='CUTTEXT' then
   compt.CutText:=RpStrToBool(propvalue)
  else
  if propname='ALIGNMENT' then
   compt.AlignMent:=StrToInt(String(propvalue))
  else
  if propname='VALIGNMENT' then
   compt.VAlignMent:=StrToInt(String(propvalue))
  else
  if propname='INTERLINE' then
   compt.InterLine:=StrToInt(String(propvalue))
  else
  if propname='WORDWRAP' then
   compt.WordWrap:=RpStrToBool(propvalue)
  else
  if propname='WORDBREAK' then
   compt.WordBreak:=RpStrToBool(propvalue)
  else
  if propname='SINGLELINE' then
   compt.SingleLine:=RpStrToBool(propvalue)
  else
  if propname='BIDIMODES' then
   compt.BidiModes.Text:=RpPropToString(propvalue,proptype)
  else
  if propname='MULTIPAGE' then
   compt.MultiPage:=RpStrToBool(propvalue)
  else
  if propname='PRINTSTEP' then
   compt.PrintStep:=TRpSelectFontStep(StrToInt(String(propvalue)))
  else
  if propname='ISHTML' then
   compt.IsHtml:=RpStrToBool(propvalue);
 end;
 // TRpLabel
 if comp is TRpLabel then
 begin
  compl:=TRpLabel(comp);
  if propname='WIDETEXT' then
  begin
   compl.WideText:=RpStringToWString(propvalue);
   compl.UpdateAllStrings;
  end;
 end
 else
 // TRpExpression
 if comp is TRpExpression then
 begin
  compe:=TRpExpression(comp);
  if propname='EXPRESSION' then
   compe.Expression:=RpStringToWString(propvalue)
  else
  if propname='AGINIVALUE' then
   compe.AgIniValue:=RpStringToWString(propvalue)
  else
  if propname='EXPORTEXPRESSION' then
   compe.ExportExpression:=RpStringToWString(propvalue)
  else
  if propname='DATATYPE' then
   compe.DataType:=TRpParamType(StrToInt(String(propvalue)))
  else
  if propname='DISPLAYFORMAT' then
   compe.DisplayFormat:=RpStringToWString(propvalue)
  else
  if propname='IDENTIFIER' then
   compe.Identifier:=RpPropToString(propvalue,proptype)
  else
  if propname='AGGREGATE' then
   compe.Aggregate:=TRpAggregate(StrToInt(String(propvalue)))
  else
  if propname='GROUPNAME' then
   compe.GroupName:=RpPropToString(propvalue,proptype)
  else
  if propname='AGTYPE' then
   compe.AgType:=TRpAggregateType(StrToInt(String(propvalue)))
  else
  if propname='AUTOEXPAND' then
   compe.AutoExpand:=RpStrToBool(propvalue)
  else
  if propname='AUTOCONTRACT' then
   compe.AutoContract:=RpStrToBool(propvalue)
  else
  if propname='PRINTONLYONE' then
   compe.PrintOnlyOne:=RpStrToBool(propvalue)
  else
  if propname='PRINTNULLS' then
   compe.PrintNulls:=RpStrToBool(propvalue)
  else
  if propname='EXPORTDISPLAYFORMAT' then
   compe.ExportDisplayFormat:=RpStringToWString(propvalue)
  else
  if propname='EXPORTLINE' then
   compe.ExportLine:=StrToInt(String(propvalue))
  else
  if propname='EXPORTPOSITION' then
   compe.ExportPosition:=StrToInt(String(propvalue))
  else
  if propname='EXPORTSIZE' then
   compe.ExportSize:=StrToInt(String(propvalue))
  else
  if propname='EXPORTDONEWLINE' then
   compe.ExportDoNewLine:=RpStrToBool(propvalue);
 end
 else
 // TRpShape
 if comp is TRpShape then
 begin
  comps:=TRpShape(comp);
  if propname='SHAPE' then
   comps.Shape:=TrpShapeType(StrToInt(String(propvalue)))
  else
  if propname='BRUSHSTYLE' then
   comps.BrushStyle:=StrToInt(String(propvalue))
  else
  if propname='BRUSHCOLOR' then
   comps.BrushColor:=StrToInt(String(propvalue))
  else
  if propname='PENSTYLE' then
   comps.PenStyle:=StrToInt(String(propvalue))
  else
  if propname='PENCOLOR' then
   comps.PenColor:=StrToInt(String(propvalue))
  else
  if propname='PENWIDTH' then
   comps.PenWidth:=StrToInt(String(propvalue));
 end
 else
 // TRpImage
 if comp is TRpImage then
 begin
  compi:=TRpImage(comp);
  if propname='EXPRESSION' then
   compi.Expression:=RpStringToWString(propvalue)
  else
  if propname='STREAM' then
  begin
   memstream:=TMemoryStream.Create;
   try
    BinToStream(memstream,RpStringToString(propvalue),propsize);
//    BinToStream(memstream,propvalue,propsize);
    memstream.Seek(0,soFromBeginning);
    compi.SetStream(memstream);
   finally
    memstream.free;
   end;
  end
  else
  if propname='ROTATION' then
   compi.Rotation:=StrToInt(String(propvalue))
  else
  if propname='DRAWSTYLE' then
   compi.DrawStyle:=TRpImageDrawStyle(StrToInt(String(propvalue)))
  else
  if propname='DPIRES' then
   compi.DPIRes:=StrToInt(String(propvalue))
  else
  if propname='CACHEDIMAGE' then
  begin
   if (propvalue<>'False') then
    compi.CachedImage:=TrpCachedImage(StrToInt(String(propvalue)));
  end
  else
  if propname='COPYMODE' then
   compi.CopyMode:=StrToInt(String(propvalue));
 end
 else
 // TRpChart
 if comp is TRpChart then
 begin
  compc:=TRpChart(comp);

  if propname='VALUEEXPRESSION' then
   compc.ValueExpression:=RpStringToWString(propvalue)
  else
  if propname='VALUEXEXPRESSION' then
   compc.ValueXExpression:=RpStringToWString(propvalue)
  else
  if propname='GETVALUECONDITION' then
   compc.GetValueCondition:=RpStringToWString(propvalue)
  else
  if propname='CHANGESERIEEXPRESSION' then
   compc.ChangeSerieExpression:=RpStringToWString(propvalue)
  else
  if propname='CAPTIONEXPRESSION' then
   compc.CaptionExpression:=RpStringToWString(propvalue)
  else
  if propname='COLOREXPRESSION' then
   compc.ColorExpression:=RpStringToWString(propvalue)
  else
  if propname='SERIECOLOREXPRESSION' then
   compc.SerieColorExpression:=RpStringToWString(propvalue)
  else
  if propname='SERIECAPTION' then
   compc.SerieCaption:=RpStringToWString(propvalue)
  else
  if propname='CLEAREXPRESSION' then
   compc.ClearExpression:=RpStringToWString(propvalue)
  else
  if propname='SERIESCOLORS' then
   ReadSeriesColors(compc,RpPropToString(propvalue,proptype))
  else
  if propname='CHANGESERIEBOOL' then
   compc.ChangeSerieBool:=RpStrToBool(propvalue)
  else
  if propname='CHARTTYPE' then
   compc.ChartType:=TRpChartType(StrToInt(String(propvalue)))
  else
  if propname='IDENTIFIER' then
   compc.Identifier:=RpPropToString(propvalue,proptype)
  else
  if propname='CLEAREXPRESSIONBOOL' then
   compc.ClearExpressionBool:=RpStrToBool(propvalue)
  else
  if propname='DRIVER' then
   compc.Driver:=TRpChartDriver(StrToInt(String(propvalue)))
  else
  if propname='VIEW3D' then
   compc.View3D:=RpStrToBool(propvalue)
  else
  if propname='VIEW3DWALLS' then
   compc.View3DWalls:=RpStrToBool(propvalue)
  else
  if propname='PERSPECTIVE' then
   compc.Perspective:=StrToInt(String(propvalue))
  else
  if propname='ELEVATION' then
   compc.Elevation:=StrToInt(String(propvalue))
  else
  if propname='ROTATION' then
   compc.Rotation:=StrToInt(String(propvalue))
  else
  if propname='ZOOM' then
   compc.Zoom:=StrToInt(String(propvalue))
  else
  if propname='HORZOFFSET' then
   compc.HorzOffset:=StrToInt(String(propvalue))
  else
  if propname='VERTOFFSET' then
   compc.VertOffset:=StrToInt(String(propvalue))
  else
  if propname='TILT' then
   compc.Tilt:=StrToInt(String(propvalue))
  else
  if propname='ORTHOGONAL' then
   compc.Orthogonal:=RpStrToBool(propvalue)
  else
  if propname='MULTIBAR' then
   compc.MultiBar:=TRpMultiBar(StrToInt(String(propvalue)))
  else
  if propname='RESOLUTION' then
   compc.Resolution:=StrToInt(String(propvalue))
  else
  if propname='SHOWLEGEND' then
   compc.ShowLegend:=RpStrToBool(propvalue)
  else
  if propname='SHOWHINT' then
   compc.ShowHint:=RpStrToBool(propvalue)
  else
  if propname='MARKSTYLE' then
   compc.MarkStyle:=StrToInt(String(propvalue))
  else
  if propname='HORZFONTSIZE' then
   compc.HorzFontSize:=StrToInt(String(propvalue))
  else
  if propname='VERTFONTSIZE' then
   compc.VertFontSize:=StrToInt(String(propvalue))
  else
  if propname='HORZFONTROTATION' then
   compc.HorzFontRotation:=StrToInt(String(propvalue))
  else
  if propname='VERTFONTROTATION' then
   compc.VertFontRotation:=StrToInt(String(propvalue))
  else
  if propname='AUTORANGE' then
   compc.AutoRange:=TRpAutoRangeAxis(StrToInt(String(propvalue)))
  else
  if propname='YMIN' then
   compc.YMin:=RpStrToDouble(propvalue)
  else
  if propname='YMAX' then
   compc.YMax:=RpStrToDouble(propvalue);
 end
 else
 // TRpBarcode
 if comp is TRpBarcode then
 begin
  compb:=TRpBarcode(comp);
  if propname='EXPRESSION' then
   compb.Expression:=RpStringToWString(propvalue)
  else
  if propname='MODUL' then
   compb.Modul:=StrToInt(String(propvalue))
  else
  if propname='RATIO' then
   compb.Ratio:=RpStrToDouble(propvalue)
  else
  if propname='TYP' then
   compb.Typ:=TrpBarcodeType(StrToInt(String(propvalue)))
  else
  if propname='CHECKSUM' then
   compb.CheckSum:=RpStrToBool(propvalue)
  else
  if propname='DISPLAYFORMAT' then
   compb.DisplayFormat:=RpStringToWString(propvalue)
  else
  if propname='ROTATION' then
   compb.Rotation:=StrToInt(String(propvalue))
  else
  if propname='BCOLOR' then
   compb.BColor:=StrToInt(String(propvalue))
  else
  if propname='BACKCOLOR' then
   compb.BackColor:=StrToInt(String(propvalue))
  else
  if propname='TRANSPARENT' then
   compb.Transparent:=RpStrToBool(propvalue)
  else
  if propname='NUMCOLUMNS' then
   compb.NumColumns:=StrToInt(String(propvalue))
  else
  if propname='NUMROWS' then
   compb.NumRows:=StrToInt(String(propvalue))
  else
  if propname='ECCLEVEL' then
   compb.ECCLevel:=StrToInt(String(propvalue))
  else
  if propname='TRUNCATED' then
   compb.Truncated:=RpStrToBool(propvalue)
 end;
end;


procedure ReadReportXML(areport:TComponent;Stream:TStream);
var
 astring:Ansistring;
 position:integer;
 propname:AnsiString;
 proptype:AnsiString;
 propvalue:ansiString;
 dbitem:TRpDatabaseInfoItem;
 ditem:TRpDataInfoItem;
 comp:TRpCommonPosComponent;
 compname:String;
 compclass:AnsiString;
 aclass:TPersistentClass;
 aparam:TRpParam;
 report:TRpReport;
 propsize:Ansistring;
 subrep:TRpSubReport;
 sec:TRpSection;
 compitem:TRpCommonListItem;
 i,j:integer;
 efile:TEmbeddedFile;
 oldprop:string;
 memstream: TMemoryStream;

 procedure FindNextName;
 var
  abegin,aend:integer;
  typepos:integer;
  props:Ansistring;
 begin
  propname:='';
  proptype:='';
  propsize:='';
  abegin:=0;
  aend:=0;
  while position<=Length(astring) do
  begin
   if astring[position]='<' then
   begin
    if abegin>0 then
     Raise Exception.Create(SRpStreamFormat);
    abegin:=position+1;
   end
   else
   if astring[position]='>' then
   begin
    if abegin=0 then
     Raise Exception.Create(SRpStreamFormat);
    aend:=position;
    inc(position);
    break;
   end;
   inc(position);
  end;
  if aend=0 then
   Raise Exception.Create(SRpStreamFormat);
  propname:=AnsiString(Trim(String(Copy(astring,abegin,aend-abegin))));
  typepos:=Pos(' ',String(propname));
  props:='';
  if typepos>0 then
  begin
   props:=Copy(propname,typepos+1,Length(propname));
   propname:=Copy(propname,1,typepos-1);
  end;
  typepos:=Pos('size',String(props));
  if typepos>0 then
  begin
   propsize:=Copy(props,typepos+6,Length(props));
   propsize:=Copy(propsize,1,Length(propsize)-1);
   props:=AnsiString(Trim(String(Copy(props,1,typepos-1))));
  end;
  typepos:=Pos('type',String(props));
  if typepos>0 then
  begin
   proptype:=Copy(props,typepos+7,Length(props));
   proptype:=Copy(proptype,1,Length(proptype)-1);
   props:=AnsiString(Trim(String(Copy(props,1,typepos-1))));
  end;
  propvalue:='';
  while position<=Length(astring) do
  begin
   if astring[position]='<' then
   begin
    break;
   end
   else
   begin
    propvalue:=propvalue+astring[position];
    inc(position);
   end;
  end;
  if propname='' then
   Raise Exception.Create(SRpStreamFormat);
 end;

begin
 report:=TRpReport(areport);
 // Find the <report label>
{$IFNDEF DOTNETD}
 SetLength(astring,Stream.Size);
 Stream.Read(astring[1],Stream.size);
{$ENDIF}
{$IFDEF DOTNETD}
 astring:='';
{$ENDIF}
 position:=Pos('<REPORT',String(astring));
 if position<1 then
  Raise Exception.Create(SRpStreamFormat);
 // Next name must be
 FindNextName;
 FindNextName;
 while Length(propname)>0 do
 begin
  if propname='/REPORT' then
   break;
  if propname='DATABASEINFO' then
  begin
   FindNextName;
   if propname<>'ALIAS' then
    Raise Exception.Create(SRpStreamFormat);
   dbitem:=report.DatabaseInfo.Add(RpPropToString(propvalue,proptype));
   while propname<>'/DATABASEINFO' do
   begin
    ReadPropDBInfo(dbitem,propname,propvalue,proptype,propsize);
    FindNextName;
   end;
  end
  else
  if propname='DATAINFO' then
  begin
   FindNextName;
   if propname<>'ALIAS' then
    Raise Exception.Create(SRpStreamFormat);
   ditem:=report.DataInfo.Add(RpPropToString(propvalue,proptype));
   while propname<>'/DATAINFO' do
   begin
    ReadPropDataInfo(ditem,propname,propvalue,proptype,propsize);

    FindNextName;
   end;
  end
  else
  if propname='PARAMETER' then
  begin
   FindNextName;
   if propname<>'NAME' then
    Raise Exception.Create(SRpStreamFormat);
   aparam:=report.Params.Add(RpPropToString(propvalue,proptype));
   while propname<>'/PARAMETER' do
   begin
    ReadPropParam(aparam,propname,propvalue,proptype,propsize);

    FindNextName;
   end;
  end
  else
  if propname='EMBEDDEDFILE' then
  begin
   efile:=TEmbeddedFile.Create;
   FindNextName;
   while (propname<>'/EMBEDDEDFILE') do
   begin
    if propname='FILENAME' then
      efile.FileName:=RpPropToString(propvalue,proptype)
    else
     if propname='MIMETYPE' then
      efile.MimeType:=RpPropToString(propvalue,proptype)
     else
      if propname='DESCRIPTION' then
       efile.Description:=RpPropToString(propvalue,proptype)
      else
       if propname='CREATIONDATE' then
        efile.CreationDate:=RpPropToString(propvalue,proptype)
       else
        if propname='MODIFICATIONDATE' then
         efile.ModificationDate:=RpPropToString(propvalue,proptype)
        else
         if propname='RELATIONSHIP' then
           efile.AFRelationShip:=TPDFAFRelationShip(StrToInt(String(propvalue)))
         else
          if propname='STREAM' then
          begin
           memstream:=TMemoryStream.Create;
           BinToStream(memstream,RpStringToString(propvalue),propsize);
           memstream.Seek(0,soFromBeginning);
           efile.Stream:=memstream;
          end
          else
            Raise Exception.Create(SRpStreamFormat);
    oldprop := String(propname);
    FindNextName;
    if (String(propname)<>('/'+oldprop)) then
      Raise Exception.Create(SRpStreamFormat);
    FindNextName;
   end;
   if propname<>'/EMBEDDEDFILE' then
    Raise Exception.Create(SRpStreamFormat);
   // Without STREAM (other writers, a hand edit) the file is empty: the writers and the PDF
   // driver read its stream
   if efile.Stream=nil then
    efile.Stream:=TMemoryStream.Create;
   SetLength(Report.EmbeddedFiles, Length(Report.EmbeddedFiles)+1);
   Report.EmbeddedFiles[Length(Report.EmbeddedFiles)-1]:=efile;
  end
  else
  if propname='SUBREPORT' then
  begin
   FindNextName;
   if propname<>'NAME' then
    Raise Exception.Create(SRpStreamFormat);
   subrep:=TRpSubReport.Create(report);
   report.SubReports.Add.SubReport:=subrep;
   subrep.Name:=RpPropToString(propvalue,proptype);
   FindNextName;

   while propname<>'/SUBREPORT' do
   begin
    // Read subreport props
    if propname='SECTION' then
    begin
     FindNextName;
     if propname<>'NAME' then
      Raise Exception.Create(SRpStreamFormat);
     sec:=TRpSection.Create(report);
     subrep.Sections.Add.Section:=sec;;
     sec.Name:=RpPropToString(propvalue,proptype);
     FindNextName;
     while propname<>'/SECTION' do
     begin
      // Read Section props
      if propname='COMPONENT' then
      begin
       FindNextName;
       if propname<>'NAME' then
        Raise Exception.Create(SRpStreamFormat);
       compname:=RpPropToString(propvalue,proptype);
       FindNextName;
       FindNextName;
       if propname<>'CLASSNAME' then
        Raise Exception.Create(SRpStreamFormat);
       compclass:=propvalue;

       aclass:=FindClass(String(compclass));
       comp:=TRpCommonPosComponent(
        TComponentClass(aclass).Create(report));

       compitem:=sec.Components.Add;
       compitem.Component:=comp;
       comp.Name:=compname;
       while propname<>'/COMPONENT' do
       begin
        // Read component props
        ReadCompProp(comp,propname,propvalue,proptype,propsize);

        FindNextName;
       end;
      end
      else
      begin
       // As the .Net reader: a section property that can not be read keeps its default (a value
       // that is not a number aborted the whole report)
       try
        ReadPropSection(sec,propname,propvalue,proptype,propsize);
       except
        // The default stays
       end;
      end;
      FindNextName;
     end;
    end
    else
     ReadPropSubReport(subrep,propname,propvalue,proptype,propsize);
    FindNextName;
   end;
  end
  else
   ReadPropReport(report,String(propname),String(propvalue),String(proptype),String(propsize));
  FindNextName;
 end;
 // Reload links
 for i:=0 to report.SubReports.Count-1 do
 begin
  subrep:=report.SubReports.Items[i].SubReport;
  if Length(subrep.ParentSub)>0 then
  begin
   subrep.ParentSubReport:=TRpSubReport(report.FindComponent(subrep.ParentSub));
  end;
  if Length(subrep.ParentSec)>0 then
  begin
   subrep.ParentSection:=TRpSection(report.FindComponent(subrep.ParentSec));
  end;
  for j:=0 to subrep.Sections.Count-1 do
  begin
   sec:=subrep.Sections.Items[j].Section;
   if Length(sec.ChildSubReportName)>0 then
   begin
    sec.ChildSubReport:=TRpSubReport(report.FindComponent(sec.ChildSubReportName));
   end;
   if Length(sec.SubReportName)>0 then
   begin
    sec.SubReport:=TRpSubReport(report.FindComponent(sec.SubReportName));
   end;
  end;
 end;
 EnsureReportItemNames(report);
end;

function GetUniqueReportItemName(report: TRpBaseReport; currentItem: TObject;
  const preferredName, basePrefix: string): string;
var
  n: Integer;
  candidate: string;
  existing: TObject;
begin
  if not Assigned(report) then
    Exit(preferredName);

  candidate := Trim(preferredName);
  if candidate <> '' then
  begin
    existing := report.FindReporItemByName(candidate);
    if (existing = nil) or (existing = currentItem) then
      Exit(candidate);

    n := 1;
    repeat
      candidate := Trim(preferredName) + IntToStr(n);
      Inc(n);
      existing := report.FindReporItemByName(candidate);
    until (existing = nil) or (existing = currentItem);
    Exit(candidate);
  end;

  n := 1;
  repeat
    candidate := basePrefix + IntToStr(n);
    Inc(n);
    existing := report.FindReporItemByName(candidate);
  until (existing = nil) or (existing = currentItem);
  Result := candidate;
end;

procedure EnsureDatabaseInfoItemName(report: TRpBaseReport;
  dbitem: TRpDatabaseInfoItem);
begin
  if not Assigned(report) or not Assigned(dbitem) then
    Exit;
  if Trim(dbitem.Name) = '' then
    dbitem.Name := GetUniqueReportItemName(report, dbitem,
      '', 'TRPDATABASEINFOITEM');
end;

procedure EnsureDataInfoItemName(report: TRpBaseReport;
  ditem: TRpDataInfoItem);
begin
  if not Assigned(report) or not Assigned(ditem) then
    Exit;
  if Trim(ditem.Name) = '' then
    ditem.Name := GetUniqueReportItemName(report, ditem,
      '', 'TRPDATAINFOITEM');
end;

procedure EnsureParamName(report: TRpBaseReport; param: TRpParam);
begin
  if not Assigned(report) or not Assigned(param) then
    Exit;
  if Trim(param.IntName) = '' then
    param.IntName := GetUniqueReportItemName(report, param, '', 'TRPPARAM');
end;

procedure EnsureReportItemNames(report: TRpBaseReport);
var
  i, j, k: Integer;
  subrep: TRpSubReport;
  sec: TRpSection;
  dbitem: TRpDatabaseInfoItem;
  ditem: TRpDataInfoItem;
  param: TRpParam;
  comp: TRpCommonComponent;
begin
  for i := 0 to report.DatabaseInfo.Count - 1 do
  begin
    dbitem := report.DatabaseInfo.Items[i];
    EnsureDatabaseInfoItemName(report, dbitem);
  end;
  for i := 0 to report.DataInfo.Count - 1 do
  begin
    ditem := report.DataInfo.Items[i];
    EnsureDataInfoItemName(report, ditem);
  end;
  for i := 0 to report.Params.Count - 1 do
  begin
    param := report.Params.Items[i];
    EnsureParamName(report, param);
  end;
  for i := 0 to report.SubReports.Count - 1 do
  begin
    subrep := report.SubReports.Items[i].SubReport;
    if subrep.Name = '' then
      Generatenewname(subrep);
    for j := 0 to subrep.Sections.Count - 1 do
    begin
      sec := subrep.Sections.Items[j].Section;
      if sec.Name = '' then
        Generatenewname(sec);
      // Components already have names from XML, but ensure just in case
      for k := 0 to sec.ReportComponents.Count - 1 do
      begin
        comp := sec.ReportComponents.Items[k].Component;
        if comp.Name = '' then
          Generatenewname(comp);
      end;
    end;
  end;
end;

end.

