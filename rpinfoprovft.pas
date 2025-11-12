{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       TRpInfoProvider Fretype library                 }
{       Provides information about fonts in Linux       }
{       It uses freetype library version 2              }
{                                                       }
{       Copyright (c) 1994-2019 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{                                                       }
{*******************************************************}

unit rpinfoprovft;


interface

{$I rpconf.inc}

uses Classes,SysUtils,rptruetype,rptypes,
{$IFDEF USEVARIANTS}
    Types,
{$ENDIF}
{$IFDEF MSWINDOWS}
    Windows,
{$ENDIF}
    rpinfoprovid,SyncObjs,
    rpmdconsts,rpfreetype2,System.Generics.Collections,rpHarfbuzz,rpICU;


type

 TRpLogFont=class(TObject)
  fixedpitch:boolean;
  postcriptname:string;
  familyname:String;
  stylename:string;
  italic:Boolean;
  bold:Boolean;
  filename:String;
  ascent:integer;
  descent:integer;
  weight:integer;
  MaxWidth:integer;
  avCharWidth:Integer;
  Capheight:integer;
  ItalicAngle:double;
  leading:integer;
  BBox:TRect;
  fullinfo:Boolean;
  StemV:double;
  ftface:FT_Face;
  faceinit:boolean;
  havekerning:Boolean;
  type1:boolean;
  truetype:boolean;
  convfactor,widthmult:Double;
  constructor Create;
  destructor Destroy;override;
  procedure OpenFont;
 end;

 TRpFTInfoProvider=class(TRpInfoProvider)
  currentname:String;
  currentstyle:integer;
  currentfont:TRpLogFont;
  crit:TCriticalSection;
  procedure InitLibrary;
  procedure SelectFont(pdffont:TRpPDFFOnt);
  function NFCNormalize(astring:WideString):string;override;

  function CalcGlyphhPositions(astring:WideString;adata:TRpTTFontData;pdffont:TRpPDFFont;direction: TRpBiDiDirection;script: string):TGlyphPosArray;
  procedure FillFontData(pdffont:TRpPDFFont;data:TRpTTFontData);
  function GetCharWidth(pdffont:TRpPDFFont;data:TRpTTFontData;charcode:widechar):double;override;
  function GetKerning(pdffont:TRpPDFFont;data:TRpTTFontData;leftchar,rightchar:widechar):integer;override;
  function GetFontStream(data: TRpTTFontData): TMemoryStream;override;
  function GetFullFontStream(data: TRpTTFontData): TMemoryStream;override;
  function GetGlyphWidth(pdffont:TRpPDFFont;data:TRpTTFontData;glyph:Integer;charC: widechar):double;override;
  function TextExtent(const Text:WideString;
     var Rect:TRect;adata: TRpTTFontData;pdfFOnt:TRpPDFFont;
     wordbreak:boolean;singleline:boolean;FontSize:double): TRpLineInfoArray;override;

  constructor Create;
  destructor destroy;override;
 end;

type
  TShapingData=class
   public FreeTypeFace: TFTFace;
  end;


implementation

var
  fontlist:TStringList;
  fontpaths:TStringList;
  fontfiles:TStringList;
  ftlibrary:FT_Library;
  initialized:boolean;
  defaultfont:TRpLogFont;
  defaultfontb:TRpLogFont;
  defaultfontit:TRpLogFont;
  defaultfontbit:TRpLogFont;
  defaultfont_arabic:TRpLogFont;
  defaultfontb_arabic:TRpLogFont;
  defaultfontit_arabic:TRpLogFont;
  defaultfontbit_arabic:TRpLogFont;

const
 TTF_PRECISION=1000;

function TRpFTInfoProvider.NFCNormalize(astring:WideString):string;
begin
 InitIcu;
 Result:=NormalizeNFC(astring);
end;


function TRpFTInfoProvider.TextExtent(const Text:WideString;
     var Rect:TRect;adata: TRpTTFontData;pdfFOnt:TRpPDFFont;
     wordbreak:boolean;singleline:boolean;FontSize:double): TRpLineInfoArray;
var
  Bidi: TICUBidi;
  Runs: TList<TBidiRun>;
  r: TBidiRun;
  astring: string;
  i, runIndex: Integer;
  scale: Double;
  positions: TGlyphPosArray;
  posX,posY:double;
  gidHex: string;
  glyphIndex: Integer;
  absX, absY: Double;
  subText: string;
  cursorAdvance: Double;
begin
  posX:=0;
  posY:=0;
  scale:=FontSize/14/72;
  Runs := nil;
  astring:=Text;
  Bidi := TICUBidi.Create;
  try
    if Bidi.SetPara(astring, 2) then
      Runs := Bidi.GetVisualRuns(astring)
    else
      raise Exception.Create('VisualRuns error');
  finally
    Bidi.Free;
  end;
  for runIndex := 0 to Runs.Count - 1 do
  begin
    r := Runs[runIndex];
    subText := Copy(astring, r.LogicalStart + 1, r.Length);
    positions := CalcGlyphhPositions(subText, adata, pdffont,TRpBidiDirection(r.Direction),r.ScriptString);

    for i := 0 to High(positions) do
    begin
      glyphIndex := positions[i].GlyphIndex;
      gidHex := IntToHex4(glyphIndex);


      // Posición absoluta en PDF (posX/posY + cursor + offset)
      absX := posX + cursorAdvance + positions[i].XOffset * scale;
      absY := posY + positions[i].YOffset * scale;

      Result := Result + Format('q 1 0 0 1 %d %d Tm <%s> Tj Q ',
        [Round(absX), Round(absY), gidHex]);

      // Avanzar cursor por advanceX escalado
      cursorAdvance := cursorAdvance + positions[i].XAdvance * scale;
    end;
  end

end;

// add self directory and subdirectories to the lis
procedure Parsedir(alist:TStringList;adir:string);
var
 f:TSearchRec;
 retvalue:integer;
begin
 adir:=ExpandFileName(adir);
 alist.Add(adir);
 retvalue:=SysUtils.FindFirst(adir+C_DIRSEPARATOR+'*',faDirectory,F);
 if 0=retvalue then
 begin
  try
   while retvalue=0 do
   begin
    if ((F.Name<>'.') AND (F.Name<>'..')) then
    begin
     if (f.Attr AND faDirectory)<>0 then
      Parsedir(alist,adir+C_DIRSEPARATOR+F.Name);
    end;
    retvalue:=SysUtils.FindNext(F);
   end;
  finally
   SysUtils.FindClose(F);
  end;
 end;
end;

// Parses /etc/fonts/fonts.conf for font directories
// also includes subdirectories
procedure GetFontsDirectories(alist:TStringList);
var
{$IFDEF LINUX}
 afile:TStringList;
 astring:String;
 diderror:Boolean;
 apath:String;
 index:integer;
{$ENDIF}
{$IFDEF MSWINDOWS}
  abuf:pchar;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
 abuf:=AllocMem(255);
 try
  GetWindowsDirectory(abuf,255);
  alist.Add(StrPas(abuf)+'\fonts');
 finally
  FreeMem(abuf);
 end;
 exit;
{$ENDIF}
{$IFDEF LINUX}
 // Red hat linux fonts
 alist.Add('/usr/share/fonts');
 // Ubuntu fonts
 // alist.Add('/usr/share/fonts/truetype');
 // alist.Add('/usr/share/fonts/opentype');
 // alist.Add('/usr/share/fonts/type1');
 alist.Add('/usr/local/share/fonts');
(* diderror:=false;
 alist.clear;
 afile:=TStringList.create;
 try
  afile.LoadFromFile('/etc/fonts/fonts.conf');
 except
  afile.free;
  diderror:=true;
 end;
 if diderror then
 begin
  // Default font directories
  ParseDir(alist,'/usr/X11R6/lib/X11/fonts');
  ParseDir(alist,'~/fonts');
  exit;
 end;
 astring:=afile.Text;
 index:=Pos('<dir>',astring);
 while index>0 do
 begin
  astring:=Copy(astring,index+5,Length(astring));
  index:=Pos('</dir>',astring);
  if index>0 then
  begin
   apath:=Copy(astring,1,index-1);
   ParseDir(alist,apath);
   astring:=Copy(astring,index+6,Length(astring));
  end;
  index:=Pos('<dir>',astring);
 end;*)
{$ENDIF}
end;

function FileToBytes(const AName: string; var Bytes: TBytes): Boolean;
var
  Stream: TFileStream;
begin
  if not FileExists(AName) then
  begin
    Result := False;
    Exit;
  end;
  Stream := TFileStream.Create(AName, fmOpenRead);
  try
    SetLength(Bytes, Stream.Size);
    Stream.ReadBuffer(Pointer(Bytes)^, Stream.Size);
  finally
    Stream.Free;
  end;
  Result := True;
end;


procedure TRpFTInfoProvider.InitLibrary;
var
 i:integer;
 f:TSearchRec;
 retvalue:integer;
 aobj:TRpLogFont;
 afilename:string;
 errorface:FT_Error;
 aface:FT_Face;
// afaceRec:FT_FaceRec;
 fontpaths1:TStrings;
 direc:string;
 bytes: TBytes;
 afilename2: AnsiString;
 externalLeading: Integer;
 internalLeading: Integer;
begin
 if Assigned(fontlist) then
  exit;
 CheckFreeTypeLoaded;
 // reads font directory
 fontlist:=TStringList.Create;
 fontfiles:=TStringList.Create;
 fontfiles.Sorted:=true;
 fontpaths:=TStringList.Create;
 fontpaths1:=TStringList.Create;
 aface:=nil;

(* aface.num_faces:=0;
 aface.face_index:=0;
 aface.face_flags:=0;
 aface.style_flags:=0;
 aface.num_glyphs:=0;
 aface.family_name:=nil;
 aface.style_name:=nil;
 aface.num_fixed_sizes:=0;
 aface.available_sizes:=nil;
 aface.num_charmaps:=0;
 aface.charmaps:=nil;
 aface.generic.data:=nil;
 aface.generic.finalizer:=nil;
 aface.bbox.xMin:=0;
 aface.bbox.yMin:=0;
 aface.bbox.yMax:=0;
 aface.bbox.yMin:=0;
 aface.bbox.yMax:=0;
 aface.units_per_EM:=0;
 aface.ascender:=0;
 aface.descender:=0;
 aface.height:=0;
 aface.max_advance_width:=0;
 aface.max_advance_height:=0;
 aface.underline_position:=0;
 aface.underline_thickness:=0;
 aface.glyph:=nil;
 aface.size:=nil;
 aface.charmap:=nil;
 aface.driver.z:=nil;
 aface.memory.z:=nil;
 aface.sizes_list.z:=nil;
 aface.autohint.data:=nil;
 aface.autohint.finalizer:=nil;
 aface.extensions:=nil;
 aface.internal.z:=nil;    *)


 GetFontsDirectories(fontpaths);
 fontfiles.Clear;
  i:=0;
 while i<fontpaths.Count do
 begin
  direc:=fontpaths.strings[i]+C_DIRSEPARATOR+'*';
  retvalue:=SysUtils.FindFirst(direc,faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)<>0 then
      begin
        direc:=fontpaths.strings[i]+C_DIRSEPARATOR+F.Name;
        fontpaths.Add(direc);
        fontpaths1.Add(direc);
      end;
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  Inc(i);
 end;
  i:=0;
 while i<fontpaths1.Count do
 begin
  direc:=fontpaths1.strings[i]+C_DIRSEPARATOR+'*';
  retvalue:=SysUtils.FindFirst(direc,faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)<>0 then
      begin
        direc:=fontpaths1.strings[i]+C_DIRSEPARATOR+F.Name;
        fontpaths.Add(direc);
      end;
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  Inc(i);
 end;

 for i:=0 to fontpaths.Count-1 do
 begin
  retvalue:=SysUtils.FindFirst(fontpaths.strings[i]+C_DIRSEPARATOR+'*.pf*',faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
       fontfiles.Add(fontpaths.strings[i]+C_DIRSEPARATOR+F.Name);
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  retvalue:=SysUtils.FindFirst(fontpaths.strings[i]+C_DIRSEPARATOR+'*.ttf',faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
       fontfiles.Add(fontpaths.strings[i]+C_DIRSEPARATOR+F.Name);
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  retvalue:=SysUtils.FindFirst(fontpaths.strings[i]+C_DIRSEPARATOR+'*.otf',faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
       fontfiles.Add(fontpaths.strings[i]+C_DIRSEPARATOR+F.Name);
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  retvalue:=SysUtils.FindFirst(fontpaths.strings[i]+C_DIRSEPARATOR+'*.t1',faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
       fontfiles.Add(fontpaths.strings[i]+C_DIRSEPARATOR+F.Name);
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
{$IFDEF LINUX}
  direc:=fontpaths.strings[i]+C_DIRSEPARATOR+'*.TTF';
  retvalue:=SysUtils.FindFirst(direc,faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
      begin
       direc:=fontpaths.strings[i]+C_DIRSEPARATOR+F.Name;
       fontfiles.Add(direc);
      end;
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  direc:=fontpaths.strings[i]+C_DIRSEPARATOR+'*.OTF';
  retvalue:=SysUtils.FindFirst(direc,faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
      begin
       direc:=fontpaths.strings[i]+C_DIRSEPARATOR+F.Name;
       fontfiles.Add(direc);
      end;
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  direc:=fontpaths.strings[i]+C_DIRSEPARATOR+'*.T1';
  retvalue:=SysUtils.FindFirst(direc,faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
      begin
       direc:=fontpaths.strings[i]+C_DIRSEPARATOR+F.Name;
       fontfiles.Add(direc);
      end;
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
{$ENDIF}
 end;
 defaultfont:=nil;
 defaultfontb:=nil;
 defaultfontit:=nil;
 defaultfontbit:=nil;
 defaultfont_arabic:=nil;
 defaultfontb_arabic:=nil;
 defaultfontit_arabic:=nil;
 defaultfontbit_arabic:=nil;
 CheckFreeType(FT_Init_FreeType(ftlibrary));
 initialized:=true;

 // Now fill the font list with all font files
 for i:=0 to fontfiles.Count-1 do
 begin
  afilename:=fontfiles.strings[i];
  afilename2:=afilename;
//  FileToBytes(afileName,bytes);
  aface:=nil;
  errorface:=FT_New_Face(ftlibrary,PAnsichar(afilename2),-1,aface);
  if (aface.num_faces>1) then
  begin
    errorface:=FT_New_Face(ftlibrary,PAnsichar(afilename2),-1,aface);
  end;

//  if errorface=0 then
  begin

   errorface:=FT_New_Face(ftlibrary,PAnsichar(afilename2),0,aface);
   //errorface:=FT_New_Memory_Face(ftlibrary,bytes,Length(bytes),0,aface);

   if (errorface = 0) then
   begin

   try
    // Add it only if it's a TrueType or OpenType font
    // Type1 fonts also supported
    // Some truetype do not set scalable, so add all
    if  (FT_FACE_FLAG_SCALABLE AND aface.face_flags)<>0 then
    begin
     aobj:=TRpLogFont.Create;
     try
      aobj.FullInfo:=false;
      // Fill font properties
      aobj.Type1:=(FT_FACE_FLAG_SFNT AND aface.face_flags)=0;
      aobj.TrueType:=((aface.face_flags and FT_FACE_FLAG_SFNT) <> 0)
            and (FT_Get_Sfnt_Table(aface, FT_SFNT_GLYF) <> nil);
      if aobj.Type1 then
      begin
       aobj.widthmult:=1;
       //aobj.convfactor:=1;
       aobj.convfactor:=1000/aface.units_per_EM;
      end
      else
      begin
       //aobj.convfactor:=1;
       aobj.convfactor:=1000/aface.units_per_EM;
       aobj.widthmult:=1;
      end;
      aobj.filename:=fontfiles.strings[i];
      aobj.postcriptname:='';
      aobj.familyname:='';
      if (aface.family_name<>nil) then
      begin
       aobj.postcriptname:=StringReplace(StrPas(aface.family_name),' ','',[rfReplaceAll]);
       aobj.familyname:=StrPas(aface.family_name);
      end;
      aobj.fixedpitch:=(aface.face_flags AND FT_FACE_FLAG_FIXED_WIDTH)<>0;
      aobj.HaveKerning:=(aface.face_flags AND FT_FACE_FLAG_KERNING)<>0;
      aobj.BBox.Left:=Round(aobj.convfactor*aface.bbox.xMin);
      aobj.BBox.Right:=Round(aobj.convfactor*aface.bbox.xMax);
      aobj.BBox.Top:=Round(aobj.convfactor*aface.bbox.yMax);
      aobj.BBox.Bottom:=Round(aobj.convfactor*aface.bbox.yMin);
      aobj.ascent:=Round(aobj.convfactor*aface.ascender);
      aobj.descent:=Round(aobj.convfactor*aface.descender);
      // External leading, same as GDI OUTLINETEXTMETRICS, it's the line gap
      externalLeading := Round(aobj.convfactor*aface.height)-(aobj.ascent-aobj.descent);
      // Internal leading, same as GDI OUTLINETEXTMETRICS, it's the space inside the font
      // reserved for accent marks
      internalLeading := Round((aobj.ascent - aobj.descent) - aobj.convfactor*aface.units_per_EM);
      aobj.leading := internalLeading+externalLeading;


      aobj.MaxWidth:=Round(aobj.convfactor*aface.max_advance_width);
      aobj.Capheight:=Round(aobj.convfactor*aface.ascender);
      aobj.stylename:='';
      if (aface.style_name<>nil) then
            aobj.stylename:=StrPas(aface.style_name);
      aobj.bold:=(aface.style_flags AND FT_STYLE_FLAG_BOLD)<>0;
      aobj.italic:=(aface.style_flags AND FT_STYLE_FLAG_ITALIC)<>0;

      if (Pos('DROID',UpperCase(aobj.familyname))=0) then
      begin
      // Default font configuration, LUXI SANS is default
      if ((not aobj.italic) and (not aobj.bold)) then
      begin
       if not assigned(defaultfont) then
        defaultfont:=aobj
       else
       begin
        if (UpperCase(aobj.familyname)='LUXI SANS') then
        begin
         defaultfont:=aobj;
        end;
       end;
       if (not assigned(defaultfont_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0)) then
       begin
        defaultfont_arabic:=aobj;
       end;
      end
      else
      if ((not aobj.italic) and (aobj.bold)) then
      begin
       if not assigned(defaultfontb) then
        defaultfontb:=aobj
       else
       begin
        if (UpperCase(aobj.familyname)='LUXI SANS') then
        begin
         defaultfontb:=aobj;
        end;
       end;
       if (not assigned(defaultfontb_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0)) then
       begin
        defaultfontb_arabic:=aobj;
       end;
      end
      else
      if ((aobj.italic) and (not aobj.bold)) then
      begin
       if not assigned(defaultfontit) then
        defaultfontit:=aobj
       else
       begin
        if (UpperCase(aobj.familyname)='LUXI SANS') then
        begin
         defaultfontit:=aobj;
        end;
       end;
       if (not assigned(defaultfontit_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0)) then
       begin
        defaultfontit_arabic:=aobj;
       end;
      end
      else
      if ((aobj.italic) and (aobj.bold)) then
      begin
       if not assigned(defaultfontbit) then
        defaultfontbit:=aobj
       else
       begin
        if (UpperCase(aobj.familyname)='LUXI SANS') then
        begin
         defaultfontbit:=aobj;
        end;
       end;
       if (not assigned(defaultfontbit_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0)) then
       begin
        defaultfontbit_arabic:=aobj;
       end;
      end;
      end;

      fontlist.AddObject(UpperCase(aobj.familyname),aobj);
     except
      aobj.free;
     end;
    end;
   finally
    FT_Done_Face(aface);
   end;
   end;
  end;
 end;
end;

constructor TRpFTInfoProvider.Create;
begin
 currentname:='';
 currentstyle:=0;
 crit:=TCriticalSection.Create;
end;


procedure FreeFontList;
var
 i:integer;
begin
 if assigned(fontlist) then
 begin
  for i:=0 to fontlist.count-1 do
  begin
   fontlist.Objects[i].free;
  end;
  fontlist.clear;
  fontlist.free;
  fontlist:=nil;
  fontpaths.free;
  fontfiles.free;
 end;
end;

destructor TRpFTInfoProvider.destroy;
begin
 crit.free;

 inherited destroy;
end;

function isSameFont(fontName,pattern: string): boolean;
begin
 if (pattern=fontName) then
 begin
  Result:=true;
 end
 else
 if ((pattern='HELVETICA') or (pattern='ARIAL')) then
 begin
  if (fontName='NIMBUS SANS') then
  begin
   Result:=true;
  end
  else
  if (fontName='LIBERATION') then
  begin
   Result:=true;
  end
  else
  if (fontName='DEJAVU SANS') then
  begin
   Result:=true;
  end
  else
   Result:=false;
 end
 else
 Result:=false;

end;

procedure TRpFtInfoProvider.SelectFont(pdffont:TRpPDFFOnt);
var
 afontname:string;
 isbold:boolean;
 isitalic:boolean;
 i:integer;
 match:boolean;
 afont:TRpLogFont;
 currentFontName:string;
begin
 crit.Enter;
 try
  InitLibrary;
{$IFDEF MSWINDOWS}
 afontname:=UpperCase(pdffont.WFontName);
{$ENDIF}
{$IFDEF LINUX}
 afontname:=UpperCase(pdffont.LFontName);
 if (Length(afontname)=0) then
  afontname:='Helvetica';
{$ENDIF}
 if ((currentname=afontname) and (currentstyle=pdffont.Style)) then
  exit;
 currentname:=afontname;
 currentstyle:=pdffont.Style;
 // Selects de font by font matching
 // First exact coincidence of family and style
 isbold:=(pdffont.style and 1)>0;
 isitalic:=(pdffont.style and (1 shl 1))>0;
 match:=false;
 i:=0;
 while i<fontlist.Count do
 begin
  if isSameFont(fontlist.strings[i],afontname) then
  begin
   afont:=TRpLogFont(fontlist.Objects[i]);
   if isitalic=afont.italic then
    if isbold=afont.bold then
    begin
     match:=true;
     currentfont:=afont;
     break;
    end;
  end;
  inc(i);
 end;
 if match then
  exit;
 // If not matching search for similar font name
 i:=0;
 while i<fontlist.Count do
 begin
  currentFontName:=fontlist.strings[i];
  if Pos(afontname,currentFontName)>0 then
  begin
   afont:=TRpLogFont(currentFontName);
   if isitalic=afont.italic then
    if isbold=afont.bold then
    begin
     match:=true;
     currentfont:=afont;
     break;
    end;
  end;
  inc(i);
 end;
 if match then
  exit;
 // Ignoring styles
 match:=false;
 i:=0;
 while i<fontlist.Count do
 begin
  if fontlist.strings[i]=afontname then
  begin
   afont:=TRpLogFont(fontlist.Objects[i]);
   match:=true;
   currentfont:=afont;
   break;
  end;
  inc(i);
 end;
 if match then
  exit;
 // Ignoring styles partial match
 match:=false;
 i:=0;
 while i<fontlist.Count do
 begin
  if Pos(afontname,fontlist.strings[i])>0 then
  begin
   afont:=TRpLogFont(fontlist.Objects[i]);
   match:=true;
   currentfont:=afont;
   break;
  end;
  inc(i);
 end;
 if match then
  exit;
 if (Pos('ARABIC',UpperCase(afontname))>0) then
 begin
  if ((not isbold) and (not isitalic)) then
   currentfont:=defaultfont_arabic
  else
  if ((isbold) and (not isitalic)) then
   currentfont:=defaultfontb_arabic
  else
  if ((not isbold) and (isitalic)) then
   currentfont:=defaultfontit_arabic
  else
   currentfont:=defaultfontbit_arabic;
 end;
 if (currentfont <> nil) then
  exit;
 // Finally gets default font, but applying styles
 if ((not isbold) and (not isitalic)) then
  currentfont:=defaultfont
 else
 if ((isbold) and (not isitalic)) then
  currentfont:=defaultfontb
 else
 if ((not isbold) and (isitalic)) then
  currentfont:=defaultfontit
 else
  currentfont:=defaultfontbit;

 if not assigned(currentfont) then
  Raise Exception.Create('No active font');
 finally
  crit.Leave;
 end;
end;

function  TRpFTInfoProvider.GetFontStream(data: TRpTTFontData): TMemoryStream;
var
 subset:TTrueTypeFontSubSet;
 bytes:TBytes;
 GlyphsUsed: TDictionary<Integer, TArray<Integer>>;
 xchar: WideChar;
 ints: TArray<Integer>;
 intChar: Integer;
 glyph: Integer;
 glyphInfo: TGlyphInfo;
begin
 // For type1 font returns all font stream
 if (data.type1 or (not data.TrueType)) then
 begin
   Result:=GetFullFontStream(data);
   exit;
 end;
     SetLength(bytes, data.FontData.FontData.Size);
     crit.Enter;
     try
      data.FontData.Fontdata.Seek(0, soFromBeginning);
      data.fontdata.FontData.ReadBuffer(bytes[0],data.fontdata.FontData.Size);
     finally
      crit.Leave;
     end;
     GlyphsUsed:=TDictionary<Integer, TArray<Integer>>.Create;
     for glyphInfo in data.glyphsInfo.Values do
     begin
      intChar:=Integer(glyphInfo.Char);
      glyph:=glyphInfo.Glyph;
      if (not GlyphsUsed.ContainsKey(glyph)) then
      begin
       SetLength(ints, 3);
       ints[0]:=glyph;
       ints[1]:=Round(glyphInfo.Width);
       ints[2]:=intChar;
       GlyphsUsed.Add(glyph,ints)
      end;
     end;
     if (not data.type1) then
     begin
     // Create font subset in true type fonts
          subset := TTrueTypeFontSubSet.Create(data.PostcriptName, bytes,
                GlyphsUsed, data.FontData.DirectoryOffset);
     bytes := subset.Execute();
     end;
     Result:=TMemoryStream.Create;
     Result.SetSize(Int64(Length(bytes)));
     Result.Seek(0,soFromBeginning);
     Result.WriteBuffer(bytes[0],Length(bytes));
     Result.Seek(0,soFromBeginning);
end;

function  TRpFTInfoProvider.GetFullFontStream(data: TRpTTFontData): TMemoryStream;
begin
 Result:=data.FontData.Fontdata;
 Result.Position:=0;
end;


procedure TRpFTInfoProvider.FillFontData(pdffont:TRpPDFFont;data:TRpTTFontData);
begin
 crit.Enter;
 try
  InitLibrary;
  // See if data can be embedded
  SelectFont(pdffont);
  data.fontdata.FontData.Clear;
  data.filename:=currentfont.filename;
  //if not currentfont.type1 then
  data.fontdata.FontData.LoadFromFile(currentfont.filename);
  data.postcriptname:=currentfont.postcriptname;
  data.FamilyName:=currentfont.familyname;
  data.FaceName:=currentfont.familyname;
  data.Ascent:=currentfont.ascent;
  data.Descent:=currentfont.descent;
  data.Leading:=currentfont.leading;
  data.capHeight:=currentfont.Capheight;
  data.Encoding:='WinAnsiEncoding';
  data.FontWeight:=0;
  data.MaxWidth:=currentfont.MaxWidth;
  data.AvgWidth:=currentfont.avCharWidth;
  data.havekerning:=currentfont.havekerning;
  data.StemV:=0;
  data.FontStretch:='/Normal';
  data.fdata:=currentfont;
  data.FontBBox:=currentfont.BBox;

  if currentfont.italic then
   data.ItalicAngle:=-15
  else
   data.ItalicAngle:=0;
  data.StyleName:=currentfont.stylename;
  data.Flags:=32;
  if (currentfont.fixedpitch) then
   data.Flags:=data.Flags+1;
  if pdffont.Bold then
   data.postcriptname:=data.postcriptname+',Bold';
  if currentfont.italic then
    data.Flags:=data.Flags+64;
  if pdffont.Italic then
  begin
   if pdffont.Bold then
    data.postcriptname:=data.postcriptname+'Italic'
   else
     data.postcriptname:=data.postcriptname+',Italic';
  end;
  data.Type1:=currentfont.Type1;
  data.truetype:=currentfont.truetype;
 finally
   crit.Leave;
 end;
end;


function TRpFTInfoProvider.GetCharWidth(pdffont:TRpPDFFont;data:TRpTTFontData;charcode:widechar):double;
var
 awidth:double;
 aint:integer;
 width1,width2:word;
 cfont:TRpLogFont;
 dwidth:double;
 index:integer;
 ginfo: TGlyphInfo;
begin
 aint:=Ord(charcode);
 if aint>255 then
  data.isunicode:=true;
 if data.loaded[aint] then
 begin
  Result:=data.loadedwidths[aint];
 end
 else
 begin
  cfont:=TRpLogFont(data.fdata);
  cfont.OpenFont;
  data.UnitsPerEM:=currentFont.ftface.units_per_EM;
  if 0=FT_Load_Char(cfont.ftface,Cardinal(charcode),FT_LOAD_NO_SCALE) then
  begin
   width1:=word(cfont.ftface.glyph.linearHoriAdvance shr 16);
   width2:=word((cfont.ftface.glyph.linearHoriAdvance shl 16) shr 16);
   dwidth:=width1+width2/65535;
   awidth:=cfont.widthmult*dwidth;
  end
  else
   awidth:=0;
  data.loadedwidths[aint]:=awidth;
  data.loaded[aint]:=true;
  if data.firstloaded>aint then
   data.firstloaded:=aint;
  if data.lastloaded<aint then
   data.lastloaded:=aint;
  data.widths.Add(charcode,awidth);
  Result:=awidth;
  // Get glyph index
  index := FT_Get_Char_Index(cfont.ftface,Cardinal(charcode));
  data.glyphs.Add(charcode,index);
  if (not data.glyphsInfo.ContainsKey(index)) then
  begin
   ginfo.Glyph := index;
   ginfo.Width := awidth;
   ginfo.Char := charcode;
   data.glyphsInfo.Add(index,ginfo);
  end;
  data.loadedglyphs[aint]:=WideChar(index);
  data.loadedg[aint]:=true;
 end;
end;

function TRpFTInfoProvider.GetGlyphWidth(pdffont:TRpPDFFont;data:TRpTTFontData;glyph:Integer;charC: widechar):double;
var
 awidth:double;
 width1,width2:word;
 cfont:TRpLogFont;
 dwidth:double;
 ginfo: TGlyphInfo;
begin
 if data.glyphsInfo.ContainsKey(glyph) then
 begin
  Result:=data.glyphsInfo[glyph].Width;
 end
 else
 begin
  cfont:=TRpLogFont(data.fdata);
  cfont.OpenFont;
  if (0 = FT_Load_Glyph(cfont.ftface,glyph,FT_LOAD_NO_SCALE)) then
  begin
   width1:=word(cfont.ftface.glyph.linearHoriAdvance shr 16);
   width2:=word((cfont.ftface.glyph.linearHoriAdvance shl 16) shr 16);
   dwidth:=width1+width2/65535;
   awidth:=cfont.widthmult*dwidth;
  end
  else
   awidth:=0;
  Result:=awidth;
  // Get glyph index
  if (not data.glyphsInfo.ContainsKey(glyph)) then
  begin
   ginfo.Glyph := glyph;
   ginfo.Width := Result;
   ginfo.Char := charC;
   data.glyphsInfo.Add(glyph,ginfo);
  end;
 end;
end;


function TRpFTInfoProvider.GetKerning(pdffont:TRpPDFFont;data:TRpTTFontData;leftchar,rightchar:widechar):integer;
{$IFDEF USEKERNING}
var
 wl,wr:FT_UInt;
 akerning:FT_Vector;
 cfont:TRpLogFont;
{$ENDIF}
begin
{$IFNDEF USEKERNING}
  Result:=0;
  exit;
{$ENDIF}
{$IFDEF USEKERNING}
 REsult:=0;
 cfont:=TRpLogFont(data.fdata);
 if cfont.havekerning then
 begin
  cfont.OpenFont;
  wl:=FT_Get_Char_Index(cfont.ftface,Cardinal(leftchar));
  if wl>0 then
  begin
   wr:=FT_Get_Char_Index(cfont.ftface,Cardinal(rightchar));
   if wr>0 then
   begin
    CheckFreeType(FT_Get_Kerning(cfont.ftface,wl,wr,FT_KERNING_UNSCALED,akerning));
    result:=Round(cfont.widthmult*-akerning.x);
   end;
  end;
 end;
{$ENDIF}
end;

constructor TRpLogFont.Create;
begin
 faceinit:=false;
end;

destructor TRpLogFont.Destroy;
begin
 if faceinit then
  CheckFreeType(FT_Done_Face(ftface));
 inherited destroy;
end;

procedure TRpLogFont.OpenFont;
var
 kerningfile:string;
 filename2:AnsiString;
begin
 if faceinit then
  exit;
 filename2:=filename;
 CheckFreeType(FT_New_Face(ftlibrary,PAnsiChar(filename2),0,ftface));
 faceinit:=true;
 if type1 then
 begin
  // Check for kening file for type1 font
  kerningfile:=ChangeFileExt(filename,'.afm');
  if FileExists(kerningfile) then
  begin
   CheckFreeType(FT_Attach_File(ftface,PAnsichar(kerningfile)));
  end;
 end;
 // Don't need scale, but this is a scale that returns
 // exact width for pdf if you divide the result
 // of Get_Char_Width by 64
 CheckFreeType(FT_Set_Char_Size(ftface,0,64*100,720,720));
end;

function TRpFTInfoProvider.CalcGlyphhPositions(astring:WideString;
adata:TRpTTFontData;pdffont:TRpPDFFont;direction: TRpBiDiDirection;script: string):TGlyphPosArray;
var
  Font: THBFont;
  Buf: THBBuffer;
  GlyphInfo: TArray<THBGlyphInfo>;
  GlyphPos: TArray<THBGlyphPosition>;
  i: Integer;
  mem:Pointer;
  shapeData:TShapingData;
begin

  InitHarfBuzz;
  SetLength(Result, 0);
  if astring = '' then Exit;

  if not adata.LoadedFace then
  begin
    shapeData:=TShapingData.Create;
    adata.FontData.Fontdata.Position := 0;
    mem:=adata.FontData.Fontdata.Memory;
    FT_New_Memory_Face(ftlibrary,mem,adata.FontData.Fontdata.Size,0,shapedata.FreeTypeFace);
    CheckFreeType(FT_Set_Char_Size(shapedata.FreeTypeFace,0,64*100,720,720));
//    adata.FreeTypeFace := TFTFace.Create(adata.FontData.Fontdata.Memory, adata.FontData.Fontdata.Size, 0);
    adata.CustomImplementation:=shapedata;
    adata.LoadedFace := True;
  end
  else
  begin
    shapeData:=adata.CustomImplementation as TShapingData;
  end;


  Font := THBFont.CreateReferenced(shapeData.FreeTypeFace);
  try
    Font.FTFontSetFuncs;
    Buf := THBBuffer.Create;
    try
      if (direction = TRpBiDiDirection.RP_UBIDI_RTL) then
        Buf.Direction := hbdRTL
      else
       Buf.Direction:= hbdLTR;

      Buf.Script := THBScript.FromString(script);;
//      Buf.Language := hb_language_from_string('ar', -1);

      Buf.AddUTF16(astring);

      Buf.Shape(Font);

      GlyphInfo := Buf.GetGlyphInfos;
      GlyphPos := Buf.GetGlyphPositions;

      SetLength(Result, Length(GlyphInfo));

      for i := 0 to High(GlyphInfo) do
      begin
        Result[i].GlyphIndex := GlyphInfo[i].Codepoint;
        Result[i].XAdvance := Round(GlyphPos[i].XAdvance/64); // en font units
        Result[i].XOffset := Round(GlyphPos[i].XOffset/64);
        Result[i].YOffset := Round(GlyphPos[i].YOffset/64);
        Result[i].CharCode := astring[GlyphInfo[i].Cluster+1];
        Result[i].Cluster := GlyphInfo[i].Cluster;
      end;
    finally
      Buf.Destroy;
    end;
  finally
    Font.Destroy;
  end;
end;

initialization
 fontlist:=nil;
 initialized:=false;
finalization
 FreeFontList;
 if initialized then
  FT_Done_FreeType(ftlibrary);
end.
