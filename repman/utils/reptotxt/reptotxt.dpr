{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       reptotxt                                        }
{                                                       }
{       Converts a report definition to text,           }
{       or to XML with -xml                             }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{                                                       }
{*******************************************************}

// JCL_DEBUG_EXPERT_INSERTJDBG OFF
program reptotxt;

{$APPTYPE CONSOLE}

{$I rpconf.inc}

// Without -xml the program converts a report to a plain (DFM text) file, as it always did.
// With -xml it loads the report (DFM binary, text or compressed) as the designer does and saves it
// in XML, the format the .Net and TypeScript engines read: a file, the standard input, or every
// .rep of a folder (its subfolders too) into another folder. A report that is already XML (plain or
// zlib compressed) is copied as it is, and the source is never written.

uses
  SysUtils,
  Classes,
{$IFDEF USEZLIB}
{$IFDEF DELPHI2009UP}
  zlib,
{$ENDIF}
{$IFNDEF DELPHI2009UP}
  rpmzlib,
{$ENDIF}
{$ENDIF}
{$IFDEF MSWINDOWS}
{$IFDEF USEVARIANTS}
{$IFNDEF MIDASOUT}
  midaslib,
{$ENDIF}
  types,
{$ENDIF}
{$ENDIF}
  rpwriter in '..\..\..\rpwriter.pas',
  rpreport in '..\..\..\rpreport.pas',
  rpparams in '..\..\..\rpparams.pas',
  rpmdconsts in '..\..\..\rpmdconsts.pas',
  rptypes in '..\..\..\rptypes.pas',
  rpsubreport in '..\..\..\rpsubreport.pas',
  rpsection in '..\..\..\rpsection.pas',
  rpsecutil in '..\..\..\rpsecutil.pas',
  rppdffile in '..\..\..\rppdffile.pas',
  rpbasereport in '..\..\..\rpbasereport.pas',
  rpmdshfolder in '..\..\..\rpmdshfolder.pas',
  rptranslator in '..\..\..\rptranslator.pas',
  rpmunits in '..\..\..\rpmunits.pas',
  rpprintitem in '..\..\..\rpprintitem.pas',
  rpeval in '..\..\..\rpeval.pas',
  rpevalfunc in '..\..\..\rpevalfunc.pas',
  rptypeval in '..\..\..\rptypeval.pas',
  rpparser in '..\..\..\rpparser.pas',
  rpstringhash in '..\..\..\rpstringhash.pas',
  rphashtable in '..\..\..\rphashtable.pas',
  rpcomparable in '..\..\..\rpcomparable.pas',
  rpalias in '..\..\..\rpalias.pas',
  rpdatainfo in '..\..\..\rpdatainfo.pas',
  rpdataset in '..\..\..\rpdataset.pas',
  rpdatatext in '..\..\..\rpdatatext.pas',
  rpmdcharttypes in '..\..\..\rpmdcharttypes.pas',
  rpmetafile in '..\..\..\rpmetafile.pas',
  rplabelitem in '..\..\..\rplabelitem.pas',
  rpmdbarcode in '..\..\..\rpmdbarcode.pas',
  rpbarcodecons in '..\..\..\rpbarcodecons.pas',
  rpDelphiZXIngQRCode in '..\..\..\rpDelphiZXIngQRCode.pas',
  rpxmlstream in '..\..\..\rpxmlstream.pas',
  rpdrawitem in '..\..\..\rpdrawitem.pas',
  rpmdchart in '..\..\..\rpmdchart.pas',
  rpinfoprovid in '..\..\..\rpinfoprovid.pas',
  rpfreetype2 in '..\..\..\rpfreetype2.pas',
  rplinuxexceptionhandler in '..\..\..\rplinuxexceptionhandler.pas';

const
 XML_OPTION='-xml';
 STDIN_OPTION='-stdin';

procedure PrintHelp;
begin
 Writeln(SRpRepToTxt1+' '+RM_VERSION);
 Writeln(SRpRepToTxt2);
 Writeln(SRpRepToTxt3);
 Writeln(SRpRepToTxt4);
 Writeln(SRpRepToTxt5);
 Writeln(SRpCommandLineStdIN);
end;

// Whether the bytes of a report are XML already: plain (they start with '<') or zlib compressed
// XML (zlib, and the first decompressed character is '<')
function IsXmlReport(stream:TMemoryStream):Boolean;
var
 first:Byte;
{$IFDEF USEZLIB}
 zlibs:TDeCompressionStream;
 c:Byte;
{$ENDIF}
begin
 Result:=false;
 if stream.Size<1 then
  exit;
 first:=PByte(stream.Memory)^;
 if first=Ord('<') then
  Result:=true
 else
 if first=Ord('x') then
 begin
{$IFDEF USEZLIB}
  stream.Seek(0,soFromBeginning);
  zlibs:=TDeCompressionStream.Create(stream);
  try
   c:=0;
   try
    if zlibs.Read(c,1)=1 then
     Result:=c=Ord('<');
   except
    Result:=false;
   end;
  finally
   zlibs.Free;
  end;
{$ENDIF}
 end;
 stream.Seek(0,soFromBeginning);
end;

function WithoutPlainBidiModes(const text:string):string; forward;

// The properties of a report in memory, as DFM text (written directly, not with SaveToStream, which
// would choose XML for some connections): two reports with the same text have the same properties
function ReportText(report:TRpReport):string;
var
 binary,text:TMemoryStream;
 ansi:AnsiString;
begin
 binary:=TMemoryStream.Create;
 text:=TMemoryStream.Create;
 try
  binary.WriteComponent(report);
  binary.Seek(0,soFromBeginning);
  ObjectBinaryToText(binary,text);
  SetLength(ansi,text.Size);
  if text.Size>0 then
   Move(text.Memory^,ansi[1],text.Size);
  Result:=WithoutPlainBidiModes(string(ansi));
  // The name of the report itself is not kept by the XML (the designers save a report without
  // it, and nothing refers to it): "object _1: TRpReport" is "object TRpReport"
  if (Copy(Result,1,7)='object ') and (Pos(': ',Result)>0) and (Pos(': ',Result)<Pos(LINE_FEED,Result)) then
   Result:='object '+Copy(Result,Pos(': ',Result)+2,MaxInt);
 finally
  text.Free;
  binary.Free;
 end;
end;

// A BidiModes with only BidiNo lines is no BidiModes (GetBidiMode gives BidiNo for a missing line):
// the XML reader assigns BIDIMODE, which fills the lines up to the language of the report
function WithoutPlainBidiModes(const text:string):string;
var
 lines,kept:TStringList;
 i,j:integer;
 plain:Boolean;
 item:string;
begin
 lines:=TStringList.Create;
 kept:=TStringList.Create;
 try
  lines.Text:=text;
  i:=0;
  while i<lines.Count do
  begin
   if Trim(lines[i])='BidiModes.Strings = (' then
   begin
    plain:=true;
    j:=i+1;
    while j<lines.Count do
    begin
     item:=Trim(lines[j]);
     if (Length(item)>0) and (item[Length(item)]=')') then
      item:=Copy(item,1,Length(item)-1);
     if item<>'''BidiNo''' then
      plain:=false;
     if (Length(Trim(lines[j]))>0) and (Trim(lines[j])[Length(Trim(lines[j]))]=')') then
      break;
     inc(j);
    end;
    if plain then
    begin
     i:=j+1;
     continue;
    end;
   end;
   kept.Add(lines[i]);
   inc(i);
  end;
  Result:=kept.Text;
 finally
  kept.Free;
  lines.Free;
 end;
end;

// The first line where two texts differ, for the message of a conversion that lost something
function FirstDifference(const a,b:string):string;
var
 la,lb:TStringList;
 i:integer;
 sa,sb:string;
begin
 Result:='';
 la:=TStringList.Create;
 lb:=TStringList.Create;
 try
  la.Text:=a;
  lb.Text:=b;
  for i:=0 to la.Count-1 do
  begin
   if i<lb.Count then
    sb:=Trim(lb[i])
   else
    sb:='(nothing)';
   sa:=Trim(la[i]);
   if sa<>sb then
   begin
    Result:=Format('line %d: "%s" became "%s"',[i+1,sa,sb]);
    exit;
   end;
  end;
  if lb.Count>la.Count then
   Result:=Format('line %d: "%s" was added',[la.Count+1,Trim(lb[la.Count])]);
 finally
  lb.Free;
  la.Free;
 end;
end;

// The DFM text of a report split in its own lines and one entry per component it owns (name, #1,
// its text): sorted, so the order in which the components were created is not a difference
procedure SplitReportText(const text:string;own,blocks:TStringList);
var
 lines:TStringList;
 i,p:integer;
 line,name,block:string;
begin
 lines:=TStringList.Create;
 try
  lines.Text:=text;
  i:=0;
  while i<lines.Count do
  begin
   line:=lines[i];
   if Copy(line,1,9)='  object ' then
   begin
    p:=Pos(':',line);
    name:=Copy(line,10,p-10);
    block:=line;
    inc(i);
    while (i<lines.Count) and (lines[i]<>'  end') do
    begin
     block:=block+LINE_FEED+lines[i];
     inc(i);
    end;
    blocks.Add(name+#1+block+LINE_FEED+'  end');
   end
   else
    own.Add(line);
   inc(i);
  end;
  blocks.CaseSensitive:=true;
  blocks.Sort;
 finally
  lines.Free;
 end;
end;

// The first difference between the properties of two reports (empty when they are the same)
function ReportDifference(const a,b:string):string;
var
 owna,ownb,blocksa,blocksb:TStringList;
 i:integer;

 function NameOf(const entry:string):string;
 begin
  Result:=Copy(entry,1,Pos(#1,entry)-1);
 end;

 function TextOf(const entry:string):string;
 begin
  Result:=Copy(entry,Pos(#1,entry)+1,MaxInt);
 end;

begin
 owna:=TStringList.Create;
 ownb:=TStringList.Create;
 blocksa:=TStringList.Create;
 blocksb:=TStringList.Create;
 try
  SplitReportText(a,owna,blocksa);
  SplitReportText(b,ownb,blocksb);
  Result:=FirstDifference(owna.Text,ownb.Text);
  if Length(Result)>0 then
   exit;
  for i:=0 to blocksa.Count-1 do
  begin
   if i>=blocksb.Count then
   begin
    Result:='the component '+NameOf(blocksa[i])+' was lost';
    exit;
   end;
   if NameOf(blocksa[i])<>NameOf(blocksb[i]) then
   begin
    Result:='the component '+NameOf(blocksa[i])+' became '+NameOf(blocksb[i]);
    exit;
   end;
   Result:=FirstDifference(TextOf(blocksa[i]),TextOf(blocksb[i]));
   if Length(Result)>0 then
   begin
    Result:=NameOf(blocksa[i])+', '+Result;
    exit;
   end;
  end;
  if blocksb.Count>blocksa.Count then
   Result:='the component '+NameOf(blocksb[blocksa.Count])+' was added';
 finally
  blocksb.Free;
  blocksa.Free;
  ownb.Free;
  owna.Free;
 end;
end;

// The XML of a report: loaded as the designer loads it and saved with the XML stream format. The
// XML is read again and must give the same properties as the report it comes from; if not, the
// conversion fails (nothing is written)
procedure ReportToXml(source:TMemoryStream;destination:TStream);
var
 report,check:TRpReport;
 xml:TMemoryStream;
 difference:string;
begin
 report:=TRpReport.Create(nil);
 check:=TRpReport.Create(nil);
 xml:=TMemoryStream.Create;
 try
  source.Seek(0,soFromBeginning);
  report.LoadFromStream(source);
  report.StreamFormat:=rpStreamXML;
  report.SaveToStream(xml);
  xml.Seek(0,soFromBeginning);
  check.LoadFromStream(xml);
  // After SaveToStream: it restores the initial values of the parameters, as the XML has them
  difference:=ReportDifference(ReportText(report),ReportText(check));
  if Length(difference)>0 then
   Raise Exception.Create('The XML does not keep the whole report, '+difference);
  xml.Seek(0,soFromBeginning);
  destination.CopyFrom(xml,xml.Size);
 finally
  xml.Free;
  check.Free;
  report.Free;
 end;
end;

// Converts one report (or copies it when it is XML already); an empty destination is the
// standard output. Returns true when it was copied.
function ConvertStream(source:TMemoryStream;const destinationfile:string):Boolean;
var
 output:TMemoryStream;
begin
 Result:=IsXmlReport(source);
 output:=TMemoryStream.Create;
 try
  if Result then
   output.CopyFrom(source,source.Size)
  else
   ReportToXml(source,output);
  output.Seek(0,soFromBeginning);
  if Length(destinationfile)>0 then
   output.SaveToFile(destinationfile)
  else
   WriteStreamToStdOutput(output);
 finally
  output.Free;
 end;
end;

procedure CheckNotSource(const sourcefile,destinationfile:string);
begin
 if (Length(sourcefile)>0) and (Length(destinationfile)>0) and
  SameFileName(ExpandFileName(sourcefile),ExpandFileName(destinationfile)) then
  Raise Exception.Create('The destination is the source file: '+sourcefile);
end;

procedure ConvertFileToXml(const sourcefile,destinationfile:string);
var
 source:TMemoryStream;
begin
 CheckNotSource(sourcefile,destinationfile);
 if Length(sourcefile)>0 then
 begin
  source:=TMemoryStream.Create;
  try
   source.LoadFromFile(sourcefile);
   ConvertStream(source,destinationfile);
  finally
   source.Free;
  end;
 end
 else
 begin
  source:=ReadFromStdInputStream;
  try
   ConvertStream(source,destinationfile);
  finally
   source.Free;
  end;
 end;
end;

// Every .rep of sourcedir and its subfolders into destdir, keeping their relative paths
procedure ConvertFolderToXml(const sourcedir,destdir:string);
var
 sourceroot,destroot:string;
 converted,copied,failed:integer;

 procedure Walk(const dir:string);
 var
  sr:TSearchRec;
  sourcefile,destinationfile,relative:string;
  source:TMemoryStream;
 begin
  if FindFirst(dir+'*',faAnyFile,sr)=0 then
  try
   repeat
    if (sr.Name='.') or (sr.Name='..') then
     continue;
    sourcefile:=dir+sr.Name;
    if (sr.Attr and faDirectory)<>0 then
    begin
     // The destination folder may be inside the source one: it is not walked
     if not SameFileName(IncludeTrailingPathDelimiter(sourcefile),destroot) then
      Walk(IncludeTrailingPathDelimiter(sourcefile));
     continue;
    end;
    if LowerCase(ExtractFileExt(sr.Name))<>'.rep' then
     continue;
    relative:=Copy(sourcefile,Length(sourceroot)+1,MaxInt);
    destinationfile:=destroot+relative;
    try
     CheckNotSource(sourcefile,destinationfile);
     ForceDirectories(ExtractFileDir(destinationfile));
     source:=TMemoryStream.Create;
     try
      source.LoadFromFile(sourcefile);
      if ConvertStream(source,destinationfile) then
      begin
       inc(copied);
       Writeln('copied (XML already): '+relative);
      end
      else
      begin
       inc(converted);
       Writeln('converted: '+relative);
      end;
     finally
      source.Free;
     end;
    except
     on E:Exception do
     begin
      inc(failed);
      WriteToStdError(relative+': '+E.Message+LINE_FEED);
     end;
    end;
   until FindNext(sr)<>0;
  finally
   FindClose(sr);
  end;
 end;

begin
 sourceroot:=IncludeTrailingPathDelimiter(ExpandFileName(sourcedir));
 destroot:=IncludeTrailingPathDelimiter(ExpandFileName(destdir));
 if SameFileName(sourceroot,destroot) then
  Raise Exception.Create('The destination folder is the source folder: '+sourcedir);
 converted:=0;
 copied:=0;
 failed:=0;
 Walk(sourceroot);
 Writeln(Format('%d converted, %d copied (XML already), %d failed',[converted,copied,failed]));
 if failed>0 then
  ExitCode:=1;
end;

var
 xml:Boolean;
 args:TStringList;
 i:integer;
 sourcefile,destinationfile:String;

begin
 try
  xml:=false;
  args:=TStringList.Create;
  try
   for i:=1 to ParamCount do
   begin
    if LowerCase(ParamStr(i))=XML_OPTION then
     xml:=true
    else
     args.Add(ParamStr(i));
   end;
   if args.Count<1 then
    PrintHelp
   else
   begin
    sourcefile:='';
    destinationfile:='';
    if args[0]=STDIN_OPTION then
    begin
     if args.Count>1 then
      destinationfile:=args[1];
    end
    else
    begin
     sourcefile:=args[0];
     if args.Count>1 then
      destinationfile:=args[1];
    end;
    if not xml then
     FileReportToPlainText(sourcefile,destinationfile)
    else
    if (Length(sourcefile)>0) and DirectoryExists(sourcefile) then
    begin
     if Length(destinationfile)<1 then
      Raise Exception.Create('A destination folder is needed to convert a folder');
     ConvertFolderToXml(sourcefile,destinationfile);
    end
    else
     ConvertFileToXml(sourcefile,destinationfile);
   end;
  finally
   args.Free;
  end;
 except
  On E:Exception do
  begin
   WriteToStdError(E.Message+LINE_FEED);
   ExitCode:=1;
  end;
 end;
end.
