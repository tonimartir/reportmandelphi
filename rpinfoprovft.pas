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

uses Classes,SysUtils,rptruetype,rptypes,rpmunits,System.Math,
{$IFDEF USEVARIANTS}
    Types,
{$ENDIF}
{$IFDEF MSWINDOWS}
    Windows,rpmdshfolder,
{$ENDIF}
    rpinfoprovid,SyncObjs,
{$IFDEF USEFONTCONFIG}
    rpfontconfig,
{$ENDIF}
    rpmdconsts,rpfreetype2,System.Generics.Collections,rpHarfbuzz,rpICU, rphtmlparser;


type

 TRpLogFont=class(TObject)
  fixedpitch:boolean;
  postcriptname:string;
  familyname:String;
  stylename:string;
  italic:Boolean;
  bold:Boolean;
  filename:String;
  fontIndex:integer;
  ascent:integer;
  descent:integer;
  height:integer;
  weight:integer;
  MaxWidth:integer;
  avCharWidth:Integer;
  Capheight:integer;
  ItalicAngle:double;
  leading:integer;
  externalleading:integer;
  BBox:TRect;
  fullinfo:Boolean;
  scalable:Boolean;
  StemV:double;
  ftface:FT_Face;
  faceinit:boolean;
  havekerning:Boolean;
  type1:boolean;
  truetype:boolean;
  CFF:boolean;
  convfactor,widthmult:Double;
  LoadedFace:boolean;
  CustomImplementation:TObject;
  data: TRpTTFontData;
  constructor Create;
  destructor Destroy;override;
  procedure OpenFont;
 end;

 TRpLogFontCache = class(TDictionary<string, TRpLogFont>);

 TRpFTInfoProvider=class(TRpInfoProvider)
  currentname:String;
  currentstyle:integer;
  currentfont:TRpLogFont;
  crit:TCriticalSection;
  procedure InitLibrary;
  procedure SelectFont(pdffont:TRpPDFFOnt;content: string;ignoreFamily: boolean);
  procedure SelectFontPorNombre(pdffont:TRpPDFFOnt);
  function ReservaPorContenido(pdffont:TRpPDFFont;const texto:WideString;
    fuenteactual:TRpLogFont;var familia:string):boolean;
  function NFCNormalize(astring:WideString):WideString;override;

  function CalcGlyphPositions(astring:WideString;
    direction: TRpBiDiDirection;
    script: string;FontSize:double):TGlyphPosArray;
  procedure FillFontData(pdffont:TRpPDFFont;data:TRpTTFontData;content: string);override;
  procedure FillFontDataInt(data:TRpTTFontData);
  function GetCharWidth(pdffont:TRpPDFFont;data:TRpTTFontData;charcode:widechar):double;override;
  function GetKerning(pdffont:TRpPDFFont;data:TRpTTFontData;leftchar,rightchar:widechar):integer;override;
  function GetFontStream(data: TRpTTFontData): TMemoryStream;override;
  function GetFontStreamNative(data: TRpTTFontData): TMemoryStream;
  function GetFontStreamHarfBuzz(data: TRpTTFontData): TMemoryStream;
  function GetFullFontStream(data: TRpTTFontData): TMemoryStream;override;
  function GetGlyphWidth(pdffont:TRpPDFFont;data:TRpTTFontData;glyph:Integer;charC: widechar):double;override;
  function GetOrAddLogFont(const FileName: string; FontIndex: Integer): TRpLogFont;
  function TextExtent(
    const Text: WideString;
    var Rect: TRect;
    adata: TRpTTFontData;
    pdfFont: TRpPDFFont;
    wordwrap: Boolean;
    singleline: Boolean;
    FontSize: Double;
    IsHtml: Boolean
  ): TRpLineInfoArray;override;
  function TextExtentHtml(
    const Text: WideString;
    var Rect: TRect;
    adata: TRpTTFontData;
    pdfFont: TRpPDFFont;
    wordwrap: Boolean;
    singleline: Boolean;
    FontSize: Double;
    IsHtml: Boolean
  ): TRpLineInfoArray;
{$IFDEF USEFONTCONFIG}
  procedure SelectFontFontConfig(pdffont:TRpPDFFOnt;unicodeContent: string = '');
  procedure SelectFontFontConfigInt(pdffont: TRpPDFFont; unicodeContent: string;removeFamily: boolean);
{$ENDIF}
  constructor Create;
  destructor Destroy;override;
 end;

var
  // El diccionario global (una sola instancia)
  GlobalFontCache: TRpLogFontCache;
  critSection:TCriticalSection;



implementation

var
  fontlist:TStringList;
  // La reserva ya buscada, por juego de caracteres y estilo: el barrido por cobertura se
  // paga una vez por script, no una por linea de texto. Guarda referencias a fichas de
  // fontlist, no es duenya de ellas.
  reservaporcobertura:TDictionary<string,TRpLogFont>;
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


function GetFontCacheKey(const FileName: string; FontIndex: Integer): string;
begin
  // Usa un separador que no se espera en el nombre de archivo (ej. '|').
  Result := FileName + '|' + IntToStr(FontIndex);
end;

 // --- Inicialización y Finalización ---

procedure InitializeFontCache;
begin
  if not Assigned(GlobalFontCache) then
  begin
    GlobalFontCache := TRpLogFontCache.Create;
    critSection:=TCriticalSection.Create;
  end;
end;

procedure FinalizeFontCache;
begin
  if Assigned(GlobalFontCache) then
  begin
    // Importante: El diccionario es responsable de liberar los objetos TRpLogFont
    GlobalFontCache.Free;
    GlobalFontCache := nil;
  end;
end;

function FillLogFont(filename:string;fontIndex:integer): TRpLogFont;
var aobj: TRpLogFont;
 errorface:FT_Error;
 aface:FT_Face;
begin
   Result:=nil;
   errorface:=FT_New_Face(ftlibrary,PAnsiChar(UTF8Encode(filename)),fontIndex,aface);
   //errorface:=FT_New_Memory_Face(ftlibrary,bytes,Length(bytes),0,aface);
   if (errorface<>0) then
    raise Exception.Create('Error Code ' + IntToStr(errorface)+
     ' Opening font:' + filename);

   if (errorface = 0) then
   begin

   try
    // Add it only if it's a TrueType or OpenType font
    // Type1 fonts also supported
    // Some truetype do not set scalable, so add all
     aobj:=TRpLogFont.Create;
     if  (FT_FACE_FLAG_SCALABLE AND aface.face_flags)=0 then
      aobj.scalable:=false
     else
      aobj.scalable:=true;
     Result:=aobj;
      aobj.FullInfo:=false;
     aobj.CFF := ((aface.face_flags AND FT_FACE_FLAG_SFNT) <> 0)
            AND ((FT_Get_Sfnt_Table(aface, FT_SFNT_CFF) <> nil));

      // Fill font properties
      aobj.TrueType := ((aface.face_flags AND FT_FACE_FLAG_SFNT) <> 0)
                 AND ((aface.face_flags AND FT_FACE_FLAG_SCALABLE) <> 0)
                 AND (not aobj.CFF);

      aobj.Type1 := ((aface.face_flags AND FT_FACE_FLAG_SCALABLE) <> 0)
              AND (NOT aobj.TrueType) AND (NOT aobj.CFF);
      //aobj.Type1:=(FT_FACE_FLAG_SFNT AND aface.face_flags)=0;
      //aobj.TrueType:=((aface.face_flags and FT_FACE_FLAG_SFNT) <> 0)
      //      and (FT_Get_Sfnt_Table(aface, FT_SFNT_GLYF) <> nil);
      if aobj.Type1 then
      begin
       aobj.widthmult:=1;
       //aobj.convfactor:=1;
       if (aface.units_per_EM = 0) then
        aobj.convfactor:=1
       else
        aobj.convfactor:=1000/aface.units_per_EM;
      end
      else
      begin
       //aobj.convfactor:=1;
       if (aface.units_per_EM = 0) then
        aobj.convfactor:=1
       else
        aobj.convfactor:=1000/aface.units_per_EM;
       aobj.widthmult:=1;
      end;
      aobj.filename:=filename;
      // La cara de la que salen estos datos. El campo estaba declarado y no se rellenaba en
      // ningun sitio, asi que valia 0 siempre: en una coleccion (.ttc) la ficha decia una cara
      // y todo lo que despues usara este indice trabajaba sobre otra.
      aobj.fontIndex:=fontIndex;
      aobj.postcriptname:='';
      aobj.familyname:='';
      if (aface.family_name<>nil) then
      begin
       aobj.postcriptname:=StringReplace(String(aface.family_name),' ','',[rfReplaceAll]);
       aobj.familyname:=String(aface.family_name);
      end;
      if Pos('ARABIC',UpperCase(aobj.familyname))>0 then
      begin
      aobj.fixedpitch:=(aface.face_flags AND FT_FACE_FLAG_FIXED_WIDTH)<>0;
      end;

      aobj.fixedpitch:=(aface.face_flags AND FT_FACE_FLAG_FIXED_WIDTH)<>0;
      aobj.HaveKerning:=(aface.face_flags AND FT_FACE_FLAG_KERNING)<>0;
      aobj.BBox.Left:=Round(aobj.convfactor*aface.bbox.xMin);
      aobj.BBox.Right:=Round(aobj.convfactor*aface.bbox.xMax);
      aobj.BBox.Top:=Round(aobj.convfactor*aface.bbox.yMax);
      aobj.BBox.Bottom:=Round(aobj.convfactor*aface.bbox.yMin);
      aobj.ascent:=Round(aobj.convfactor*aface.ascender);
      aobj.descent:=Round(aobj.convfactor*aface.descender);
      aobj.height:=Round(aobj.convfactor*aface.height);
      // External leading, same as GDI OUTLINETEXTMETRICS, it's the line gap
      aobj.externalLeading := Round(aobj.convfactor*aface.height)-(aobj.ascent-aobj.descent);
      // Internal leading, same as GDI OUTLINETEXTMETRICS, it's the space inside the font
      // reserved for accent marks
      // internalLeading := Round((aobj.ascent - aobj.descent) - aobj.convfactor*aface.units_per_EM);
      aobj.leading := Round((aface.height-(aobj.ascent-aobj.descent))*aobj.convfactor);


      aobj.MaxWidth:=Round(aobj.convfactor*aface.max_advance_width);
      aobj.Capheight:=Round(aobj.convfactor*aface.ascender);
      aobj.stylename:='';
      aobj.bold:=(aface.style_flags AND FT_STYLE_FLAG_BOLD)<>0;
      aobj.italic:=(aface.style_flags AND FT_STYLE_FLAG_ITALIC)<>0;
      if (aface.style_name<>nil) then
      begin
       aobj.stylename:=String(aface.style_name);
       if not aobj.bold then
         aobj.bold :=
              (Pos('BOLD', UpperCase(aobj.stylename)) > 0)
           or (Pos('BOLD', UpperCase(aobj.postcriptname)) > 0)
           or (Pos('BOLD', UpperCase(aobj.filename)) > 0);
       if not aobj.italic then
         aobj.italic :=
             (Pos('ITALIC', UpperCase(aobj.stylename)) > 0)
           or (Pos('OBLIQUE', UpperCase(aobj.stylename)) > 0)
           or (Pos('ITALIC', UpperCase(aobj.postcriptname)) > 0)
           or (Pos('OBLIQUE', UpperCase(aobj.postcriptname)) > 0)
           or (Pos('ITALIC', UpperCase(aobj.filename)) > 0)
           or (Pos('OBLIQUE', UpperCase(aobj.filename)) > 0);
      end;
   finally
     FT_Done_Face(aface);
   end;
  end;
end;

function TRpFTInfoProvider.GetOrAddLogFont(const FileName: string; FontIndex: Integer): TRpLogFont;
var
  Key: string;
  LogFont: TRpLogFont;
begin
  critSection.Enter;
  try
  if not Assigned(GlobalFontCache) then
    InitializeFontCache; // Asegura que el cache esté listo
  Key := GetFontCacheKey(FileName, FontIndex);

  // 1. Intentar obtener de la caché
  if GlobalFontCache.TryGetValue(Key, LogFont) then
  begin
    Result := LogFont;
    Exit;
  end;

  // 2. Si no está en caché, crearlo e inicializarlo

  // NOTA: Aquí es donde integrarías la lógica de Fontconfig/FreeType
  // para rellenar los datos del TRpLogFont (postcriptname, ascent, descent, ftface, etc.)

  LogFont := FillLogFont(filename,fontIndex);
  // 3. Añadir a la caché
  GlobalFontCache.Add(Key, LogFont);
  Result := LogFont;
  finally
    critSection.Leave;
  end;
end;


function TRpFTInfoProvider.NFCNormalize(astring:WideString):WideString;
begin
 InitIcu;
 InitHarfBuzz;
 // Normalize enabled again
 Result:=NormalizeNFC(astring);
end;

type
  TOS2Metrics = record
    Found: Boolean;
    sTypoAscender: SmallInt;
    sTypoDescender: SmallInt;
    sTypoLineGap: SmallInt;
    usWinAscent: Word;
    usWinDescent: Word;
    fsSelection: Word;
    function UseTypoMetrics: Boolean;
  end;

function TOS2Metrics.UseTypoMetrics: Boolean;
begin
  Result := (fsSelection and $0080) <> 0; // bit 7
end;

procedure ReadOS2Metrics(AStream: TMemoryStream; out AResult: TOS2Metrics);
var
  fontData: PByte;
  dataLen: Integer;
  numTables: Integer;
  i, recordOffset, off: Integer;
  tableOffset: Cardinal;
  tag: AnsiString;
begin
  AResult := Default(TOS2Metrics);
  if (AStream = nil) or (AStream.Size < 12) then Exit;

  fontData := AStream.Memory;
  dataLen := AStream.Size;

  // Read number of tables from TrueType/OpenType header
  numTables := (fontData[4] shl 8) or fontData[5];

  // Each table record is 16 bytes, starting at offset 12
  for i := 0 to numTables - 1 do
  begin
    recordOffset := 12 + i * 16;
    if recordOffset + 16 > dataLen then Break;

    // Table tag is 4 bytes ASCII
    SetLength(tag, 4);
    Move(fontData[recordOffset], tag[1], 4);

    if tag = 'OS/2' then
    begin
      tableOffset := (Cardinal(fontData[recordOffset + 8]) shl 24) or
                     (Cardinal(fontData[recordOffset + 9]) shl 16) or
                     (Cardinal(fontData[recordOffset + 10]) shl 8) or
                     Cardinal(fontData[recordOffset + 11]);

      if tableOffset + 78 > Cardinal(dataLen) then Exit;

      off := Integer(tableOffset);
      // fsSelection at offset 62
      AResult.fsSelection := (Word(fontData[off + 62]) shl 8) or Word(fontData[off + 63]);
      // sTypoAscender at offset 68
      AResult.sTypoAscender := SmallInt((Word(fontData[off + 68]) shl 8) or Word(fontData[off + 69]));
      // sTypoDescender at offset 70
      AResult.sTypoDescender := SmallInt((Word(fontData[off + 70]) shl 8) or Word(fontData[off + 71]));
      // sTypoLineGap at offset 72
      AResult.sTypoLineGap := SmallInt((Word(fontData[off + 72]) shl 8) or Word(fontData[off + 73]));
      // usWinAscent at offset 74
      AResult.usWinAscent := (Word(fontData[off + 74]) shl 8) or Word(fontData[off + 75]);
      // usWinDescent at offset 76
      AResult.usWinDescent := (Word(fontData[off + 76]) shl 8) or Word(fontData[off + 77]);
      AResult.Found := True;
      Exit;
    end;
  end;
end;

// Un tramo de un trozo que se dibuja con UNA fuente: la pedida o la de reserva.
type
 TTramo = record
  Inicio:integer;      // desplazamiento en base 0 dentro del trozo
  Longitud:integer;
  NecesitaReserva:boolean;
 end;
 TTramoArray = array of TTramo;

// Recorre los puntos de codigo de un texto, juntando los pares subrogados y dejando fuera
// blancos y controles: una fuente no se cambia por un espacio que si dibuja igual.
function CodigosDelTexto(const texto:WideString):TArray<Integer>;
var
 i,n,cp:integer;
begin
 SetLength(Result,Length(texto));
 n:=0;
 i:=1;
 while (i<=Length(texto)) do
 begin
  cp:=Ord(texto[i]);
  if ((cp>=$D800) and (cp<=$DBFF) and (i<Length(texto))
      and (Ord(texto[i+1])>=$DC00) and (Ord(texto[i+1])<=$DFFF)) then
  begin
   cp:=$10000+((cp-$D800) shl 10)+(Ord(texto[i+1])-$DC00);
   inc(i);
  end;
  if ((cp>32) and (cp<>$A0)) then
  begin
   Result[n]:=cp;
   inc(n);
  end;
  inc(i);
 end;
 SetLength(Result,n);
end;

// Cuantos de esos puntos de codigo tiene glifo esta fuente. La cara se abre aparte y se
// vuelve a cerrar si no estaba abierta: un barrido no puede dejar residentes todas las
// fuentes de la maquina porque una linea de texto llevara un script raro.
function CuantosCubre(afont:TRpLogFont;const cps:TArray<Integer>):integer;
var
 aface:FT_Face;
 prestada:boolean;
 filename2:AnsiString;
 j:integer;
begin
 Result:=0;
 if ((not Assigned(afont)) or (Length(cps)=0)) then
  exit;
 prestada:=afont.faceinit;
 if prestada then
  aface:=afont.ftface
 else
 begin
  aface:=nil;
  filename2:=AnsiString(afont.filename);
  if (FT_New_Face(ftlibrary,PAnsiChar(filename2),afont.fontIndex,aface)<>0) then
   exit;
 end;
 try
  for j:=0 to High(cps) do
   if (FT_Get_Char_Index(aface,FT_ULong(cps[j]))<>0) then
    inc(Result);
 finally
  if (not prestada) then
   FT_Done_Face(aface);
 end;
end;

// Los puntos de codigo distintos de un texto para los que esta fuente no tiene glifo.
function CodigosSinGlifo(afont:TRpLogFont;const content:WideString):TArray<Integer>;
var
 cps:TArray<Integer>;
 aface:FT_Face;
 prestada:boolean;
 filename2:AnsiString;
 j,k,n:integer;
 yaesta:boolean;
begin
 SetLength(Result,0);
 if ((not Assigned(afont)) or (Length(content)=0)) then
  exit;
 cps:=CodigosDelTexto(content);
 if (Length(cps)=0) then
  exit;
 prestada:=afont.faceinit;
 if prestada then
  aface:=afont.ftface
 else
 begin
  aface:=nil;
  filename2:=AnsiString(afont.filename);
  // Una fuente que no se deja abrir no es motivo para dejar de dibujar: se sigue con la
  // que se habia elegido, con sus huecos, que es lo que pasaba antes de esto.
  if (FT_New_Face(ftlibrary,PAnsiChar(filename2),afont.fontIndex,aface)<>0) then
   exit;
 end;
 try
  SetLength(Result,Length(cps));
  n:=0;
  for j:=0 to High(cps) do
  begin
   yaesta:=false;
   for k:=0 to n-1 do
    if (Result[k]=cps[j]) then
    begin
     yaesta:=true;
     break;
    end;
   if yaesta then
    continue;
   if (FT_Get_Char_Index(aface,FT_ULong(cps[j]))=0) then
   begin
    Result[n]:=cps[j];
    inc(n);
   end;
  end;
  SetLength(Result,n);
 finally
  if (not prestada) then
   FT_Done_Face(aface);
 end;
end;

// Bit de OS/2 ulCodePageRange1 que una fuente tiene que reclamar para ser la eleccion
// idiomatica de estos caracteres, o -1 cuando no dicen nada de ningun idioma. El Han se
// escribe igual en japones, chino y coreano, asi que una fuente que lo cubra no es por
// fuerza la que toca: lo que los distingue es la compania que lleva el Han -kana quiere
// decir japones, hangul quiere decir coreano- y la pagina de codigo que el propio fichero
// dice servir.
function PaginaDeCodigoQueTocaria(const cps:TArray<Integer>):integer;
var
 i,cp:integer;
 han:boolean;
begin
 han:=false;
 for i:=0 to High(cps) do
 begin
  cp:=cps[i];
  // Kana: solo el japones las usa.
  if (((cp>=$3040) and (cp<=$30FF)) or ((cp>=$31F0) and (cp<=$31FF))) then
  begin
   Result:=17;   // 932, JIS/Japon
   exit;
  end;
  // Hangul, en cualquiera de sus tres bloques.
  if (((cp>=$1100) and (cp<=$11FF)) or ((cp>=$A960) and (cp<=$A97F))
      or ((cp>=$AC00) and (cp<=$D7FF))) then
  begin
   Result:=19;   // 949, Wansung/Corea
   exit;
  end;
  if (((cp>=$4E00) and (cp<=$9FFF)) or ((cp>=$3400) and (cp<=$4DBF))
      or ((cp>=$F900) and (cp<=$FAFF))) then
   han:=true;
 end;
 // Han a secas, sin nada que lo acompañe: chino.
 if han then
  Result:=18    // 936, chino simplificado
 else
  Result:=-1;
end;

// Lee ulCodePageRange1 directamente de la tabla OS/2 de un fichero de fuente, abriendolo
// solo para llevarse esos cuatro bytes. Entiende las colecciones, asi que la cara que se
// pide es la cara que se lee. Devuelve cero cuando el fichero no tiene nada que decir.
function LeePaginasDeCodigo(const filename:string;nfaceindex:integer):Cardinal;
var
 st:TFileStream;
 cab:array[0..11] of Byte;
 dir:array[0..3] of Byte;
 reg:array[0..15] of Byte;
 ver:array[0..1] of Byte;
 cp1:array[0..3] of Byte;
 inicio,donde:Int64;
 ncaras,ntablas,i:integer;
begin
 Result:=0;
 try
  st:=TFileStream.Create(filename,fmOpenRead or fmShareDenyNone);
  try
   if (st.Read(cab[0],12)<12) then
    exit;
   inicio:=0;
   if ((cab[0]=Ord('t')) and (cab[1]=Ord('t')) and (cab[2]=Ord('c'))
       and (cab[3]=Ord('f'))) then
   begin
    ncaras:=Integer((Cardinal(cab[8]) shl 24) or (Cardinal(cab[9]) shl 16)
                    or (Cardinal(cab[10]) shl 8) or Cardinal(cab[11]));
    if ((nfaceindex<0) or (nfaceindex>=ncaras)) then
     exit;
    st.Position:=12+4*nfaceindex;
    if (st.Read(dir[0],4)<4) then
     exit;
    inicio:=(Cardinal(dir[0]) shl 24) or (Cardinal(dir[1]) shl 16)
            or (Cardinal(dir[2]) shl 8) or Cardinal(dir[3]);
    st.Position:=inicio;
    if (st.Read(cab[0],12)<12) then
     exit;
   end;
   ntablas:=(Integer(cab[4]) shl 8) or Integer(cab[5]);
   for i:=0 to ntablas-1 do
   begin
    st.Position:=inicio+12+i*16;
    if (st.Read(reg[0],16)<16) then
     exit;
    if ((reg[0]<>Ord('O')) or (reg[1]<>Ord('S')) or (reg[2]<>Ord('/'))
        or (reg[3]<>Ord('2'))) then
     continue;
    donde:=(Cardinal(reg[8]) shl 24) or (Cardinal(reg[9]) shl 16)
           or (Cardinal(reg[10]) shl 8) or Cardinal(reg[11]);
    // ulCodePageRange1 esta en el byte 78 de la tabla, y solo existe a partir de la
    // version 1 de OS/2; la version son los dos primeros bytes.
    st.Position:=donde;
    if (st.Read(ver[0],2)<2) then
     exit;
    if (((Integer(ver[0]) shl 8) or Integer(ver[1]))<1) then
     exit;
    st.Position:=donde+78;
    if (st.Read(cp1[0],4)<4) then
     exit;
    Result:=(Cardinal(cp1[0]) shl 24) or (Cardinal(cp1[1]) shl 16)
            or (Cardinal(cp1[2]) shl 8) or Cardinal(cp1[3]);
    exit;
   end;
  finally
   st.Free;
  end;
 except
  // Un fichero que no se deja leer no decide nada; se queda sin voto.
  Result:=0;
 end;
end;

// Si este motor sabe meter esta cara dentro del PDF.
//
// Con hb-subset vale cualquiera: recorta CFF, colecciones y variables. Sin el, el subsetter
// propio recorta TrueType llano y de un fichero CFF suelto entrega el fichero entero, que
// tambien es una fuente valida; pero de una COLECCION no sabe sacar una cara CFF, y lo que
// escribiria seria el .ttc completo, que no es ninguna fuente. Una candidata asi no se
// elige: mas vale el hueco que un PDF con una fuente que no lo es.
function SePuedeIncrustar(const filename:string;nfaceindex:integer):boolean;
var
 st:TFileStream;
 cab:array[0..11] of Byte;
 dir:array[0..3] of Byte;
 inicio:Int64;
 ncaras:integer;
begin
 Result:=true;
{$IFDEF LINUX_USEHARFBUZZ_SUBSETFONT}
 if HarfBuzzSubSetImplementation then
  exit;
{$ENDIF}
{$IFDEF WINDOWS_USEHARFBUZZ_SUBSETFONT}
 if HarfBuzzSubSetImplementation then
  exit;
{$ENDIF}
 try
  st:=TFileStream.Create(filename,fmOpenRead or fmShareDenyNone);
  try
   if (st.Read(cab[0],12)<12) then
    exit;
   // Un fichero suelto -no coleccion- lo sabe tratar entero.
   if ((cab[0]<>Ord('t')) or (cab[1]<>Ord('t')) or (cab[2]<>Ord('c'))
       or (cab[3]<>Ord('f'))) then
    exit;
   ncaras:=Integer((Cardinal(cab[8]) shl 24) or (Cardinal(cab[9]) shl 16)
                   or (Cardinal(cab[10]) shl 8) or Cardinal(cab[11]));
   if ((nfaceindex<0) or (nfaceindex>=ncaras)) then
   begin
    Result:=false;
    exit;
   end;
   st.Position:=12+4*nfaceindex;
   if (st.Read(dir[0],4)<4) then
    exit;
   inicio:=(Cardinal(dir[0]) shl 24) or (Cardinal(dir[1]) shl 16)
           or (Cardinal(dir[2]) shl 8) or Cardinal(dir[3]);
   st.Position:=inicio;
   if (st.Read(cab[0],4)<4) then
    exit;
   // Dentro de una coleccion, solo la cara TrueType llana (version sfnt 1.0).
   Result:=(cab[0]=0) and (cab[1]=1) and (cab[2]=0) and (cab[3]=0);
  finally
   st.Free;
  end;
 except
  // Un fichero que no se deja leer no se propone como reserva.
  Result:=false;
 end;
end;

// Busca en la lista enumerada una fuente que sepa dibujar los puntos de codigo que le
// faltan a la elegida, primero entre las del mismo estilo. La respuesta se recuerda por
// juego de caracteres y estilo, para que el barrido pase una vez por script y no una vez
// por linea de texto. Devuelve nil cuando no hay ninguna que cubra ni uno.
//
function BuscaPorCobertura(const faltan:TArray<Integer>;bold,italic:boolean):TRpLogFont;
var
 ordenados:TArray<Integer>;
 i,j,tmp,vuelta:integer;
 nkey:string;
 bitquetoca,cubre,mejorcubre:integer;
 mejor,candidata:TRpLogFont;
 mejoridiomatica,idiomatica,mismoestilo,ganamejor:boolean;
begin
 Result:=nil;
 if ((not Assigned(fontlist)) or (Length(faltan)=0)) then
  exit;
 ordenados:=Copy(faltan);
 for i:=0 to High(ordenados)-1 do
  for j:=i+1 to High(ordenados) do
   if (ordenados[j]<ordenados[i]) then
   begin
    tmp:=ordenados[i];
    ordenados[i]:=ordenados[j];
    ordenados[j]:=tmp;
   end;
 nkey:='';
 for i:=0 to High(ordenados) do
  nkey:=nkey+IntToStr(ordenados[i])+',';
 if bold then
  nkey:=nkey+'B1'
 else
  nkey:=nkey+'B0';
 if italic then
  nkey:=nkey+'I1'
 else
  nkey:=nkey+'I0';
 critSection.Enter;
 try
  if (not Assigned(reservaporcobertura)) then
   reservaporcobertura:=TDictionary<string,TRpLogFont>.Create;
  if (reservaporcobertura.TryGetValue(nkey,mejor)) then
  begin
   Result:=mejor;
   exit;
  end;
  bitquetoca:=PaginaDeCodigoQueTocaria(faltan);
  mejor:=nil;
  mejorcubre:=0;
  mejoridiomatica:=false;
  // Dos vueltas: primero las del mismo estilo, para que un texto en negrita no acabe en
  // redonda solo porque la redonda va antes en la lista.
  for vuelta:=0 to 1 do
  begin
   for i:=0 to fontlist.Count-1 do
   begin
    candidata:=TRpLogFont(fontlist.Objects[i]);
    if (not Assigned(candidata)) then
     continue;
    mismoestilo:=(candidata.bold=bold) and (candidata.italic=italic);
    if ((vuelta=0)<>mismoestilo) then
     continue;
    if ((not candidata.scalable) or candidata.type1) then
     continue;
    if (not SePuedeIncrustar(candidata.filename,candidata.fontIndex)) then
     continue;
    cubre:=CuantosCubre(candidata,faltan);
    if (cubre=0) then
     continue;
    // Solo se pregunta por el idioma a las que ya cubren todo: leer la OS/2 de las que no
    // sirven de nada seria pagar por una respuesta que no se usa.
    idiomatica:=(bitquetoca>=0) and (cubre=Length(faltan))
      and ((LeePaginasDeCodigo(candidata.filename,candidata.fontIndex)
            and (Cardinal(1) shl bitquetoca))<>0);
    if (idiomatica<>mejoridiomatica) then
     ganamejor:=idiomatica
    else
     ganamejor:=cubre>mejorcubre;
    if ganamejor then
    begin
     mejorcubre:=cubre;
     mejor:=candidata;
     mejoridiomatica:=idiomatica;
     // Cubre todo y ademas dice servir a ese idioma: no hay nada mejor que buscar. Si
     // nadie lo dice, se sigue mirando por si aparece.
     if ((cubre=Length(faltan)) and ((bitquetoca<0) or idiomatica)) then
      break;
    end;
   end;
   if ((mejorcubre=Length(faltan)) and ((bitquetoca<0) or mejoridiomatica)) then
    break;
  end;
  reservaporcobertura.AddOrSetValue(nkey,mejor);
  Result:=mejor;
 finally
  critSection.Leave;
 end;
end;

// Trocea un trozo por cobertura, para que la reserva sustituya a la fuente solo donde
// faltan de verdad los glifos y el texto vuelva a la pedida en cuanto los haya.
//
// Mezclar arabe con español nunca necesito esto: caen en tramos bidi distintos, asi que
// cada uno ya pedia su fuente. El japones y el español son los dos de izquierda a derecha
// y comparten tramo, y cambiar la fuente del tramo entero dibujaba "Gracias" con una
// japonesa monoespaciada, todas las letras del mismo ancho.
//
// Los blancos no cortan nunca un tramo: los dibujan igual las dos fuentes, y cortar por
// ellos partiria una frase en trozos y conformaria cada uno aparte para nada.
//
// Un tramo de derecha a izquierda no se trocea a proposito: sus glifos vuelven en orden
// visual y coser tramos en orden logico los dejaria del reves.
function TroceaPorCobertura(const texto:WideString;fuente:TRpLogFont;
  rToL:boolean):TTramoArray;
var
 i,largo,cp,inicio,n:integer;
 reservaactual,empezado,falta:boolean;
 uno:TArray<Integer>;

 procedure Anade(ini,lon:integer;reserva:boolean);
 begin
  SetLength(Result,n+1);
  Result[n].Inicio:=ini;
  Result[n].Longitud:=lon;
  Result[n].NecesitaReserva:=reserva;
  inc(n);
 end;

begin
 SetLength(Result,0);
 n:=0;
 if (rToL or (not Assigned(fuente)) or (Length(texto)=0)) then
 begin
  Anade(0,Length(texto),true);
  exit;
 end;
 // Se abre una vez la cara de la fuente elegida: si no, se abriria y cerraria por letra.
 try
  fuente.OpenFont;
 except
 end;
 SetLength(uno,1);
 reservaactual:=false;
 empezado:=false;
 inicio:=0;
 i:=0;
 while (i<Length(texto)) do
 begin
  largo:=1;
  cp:=Ord(texto[i+1]);
  if ((cp>=$D800) and (cp<=$DBFF) and ((i+1)<Length(texto))
      and (Ord(texto[i+2])>=$DC00) and (Ord(texto[i+2])<=$DFFF)) then
  begin
   cp:=$10000+((cp-$D800) shl 10)+(Ord(texto[i+2])-$DC00);
   largo:=2;
  end;
  if ((cp>32) and (cp<>$A0)) then
  begin
   uno[0]:=cp;
   falta:=CuantosCubre(fuente,uno)=0;
   if (not empezado) then
   begin
    reservaactual:=falta;
    empezado:=true;
   end
   else
   if (falta<>reservaactual) then
   begin
    Anade(inicio,i-inicio,reservaactual);
    inicio:=i;
    reservaactual:=falta;
   end;
  end;
  inc(i,largo);
 end;
 Anade(inicio,Length(texto)-inicio,reservaactual);
end;

// El script de un tramo. El del run lo da ICU mirando el trozo ENTERO, y de una mezcla de
// japones y latino contesta 'Zyyy' (comun); un tramo, en cambio, es de un solo script por
// construccion, asi que se mira el suyo. Mismos rangos que el port .NET, para que los dos
// motores conformen cada tramo con la misma etiqueta.
function DetectaScript(const texto:WideString):string;
var
 i,cp:integer;
begin
 for i:=1 to Length(texto) do
 begin
  cp:=Ord(texto[i]);
  if (cp<=32) then
   continue;
  if (((cp>=$0600) and (cp<=$06FF)) or ((cp>=$0750) and (cp<=$077F))
      or ((cp>=$08A0) and (cp<=$08FF)) or ((cp>=$FB50) and (cp<=$FDFF))
      or ((cp>=$FE70) and (cp<=$FEFF))) then
   exit('Arab');
  if (((cp>=$0590) and (cp<=$05FF)) or ((cp>=$FB1D) and (cp<=$FB4F))) then
   exit('Hebr');
  if ((cp>=$0E00) and (cp<=$0E7F)) then
   exit('Thai');
  if ((cp>=$0900) and (cp<=$097F)) then
   exit('Deva');
  if (((cp>=$4E00) and (cp<=$9FFF)) or ((cp>=$3400) and (cp<=$4DBF))
      or ((cp>=$3000) and (cp<=$303F))) then
   exit('Hani');
  if (((cp>=$AC00) and (cp<=$D7AF)) or ((cp>=$1100) and (cp<=$11FF))) then
   exit('Hang');
  if ((cp>=$0020) and (cp<=$024F)) then
   exit('Latn');
 end;
 Result:='Latn';
end;

function TRpFTInfoProvider.TextExtent(
  const Text: WideString;
  var Rect: TRect;
  adata: TRpTTFontData;
  pdfFont: TRpPDFFont;
  wordwrap: Boolean;
  singleline: Boolean;
  FontSize: Double;
  IsHtml: Boolean
): TRpLineInfoArray;
begin
  Result := TextExtentHtml(Text, Rect, adata, pdfFont, wordwrap, singleline, FontSize, IsHtml);
end;

function TRpFTInfoProvider.TextExtentHtml(
  const Text: WideString;
  var Rect: TRect;
  adata: TRpTTFontData;
  pdfFont: TRpPDFFont;
  wordwrap: Boolean;
  singleline: Boolean;
  FontSize: Double;
  IsHtml: Boolean
): TRpLineInfoArray;
var
  lineSubTexts: TList<TLineSubText>;
  lineSubText: TLineSubText;
  line: string;
  Bidi: TICUBidi;
  logicalRuns: TList<TBidiRun>;
  logicalRun, vRun: TBidiRun;
  direction: TRpBidiDirection;
  positions: TGlyphPosArray;
  lineWidthLimit, rectTop, maxWidth: Double;
  chunks:TList<TGlyphPosArray>;
  chunk: TGlyphPosArray;
  calculatedLines: TList<TLineGlyphs>;
  calculatedLine:TLineGlyphs;
  j, k: Integer;
  visualRuns: TList<TBidiRun>;
  LineInfo: TRpLineInfo;
  possibleBreaksCharIdx: TDictionary<Integer,Integer>;
  remaining:double;
  g:TGlyphPos;
  runWidth:double;
  currentChunk: TLineGlyphs;
  visualGlyphs:TList<TGlyphPos>;
  runOffset:integer;
  originalFont: TRpLogFont;
  fuenteDelTramo: TRpLogFont;
  Segments: THtmlSegmentList;
  PlainText: WideString;
  TempFont: TRpPDFFont;
  RunAbsStart: Integer;
  RunLen: Integer;
  CurrentRunOffset: Integer;
  SegStartAbs: Integer;
  Seg: THtmlSegment;
  SegLen: Integer;
  SegEndAbs: Integer;
  IntStart: Integer;
  IntEnd: Integer;
  ChunkText: WideString;
  activeSize: Double;
  minCluster: Integer;
  maxCluster: Integer;
  lst: TList<Integer>;
  // Per-line spacing (matching C# FontInfoFt / GDI DirectWrite)
  fontDataCache: TDictionary<string, TRpTTFontData>;
  fontCacheKey: string;
  cachedData: TRpTTFontData;
  maxBaselineTwips, maxLineHeight: double;
  gFontSize, gAscentTwips, gHeightTwips, gBaselineTwips: double;
  currentLineSpacing, lineBaseline: integer;
  lw: double;
begin
  InitICU;
  InitHarfBuzz;
  SelectFont(pdfFont,'',false);
  originalFont:=currentfont;

  rectTop:=0;

  if IsHtml then
    Segments := ParseHtml(Text)
  else
  begin
    Segments := THtmlSegmentList.Create(True);
    Segments.Add(THtmlSegment.Create(Text, []));
  end;
  try
    PlainText := '';
    for Seg in Segments do
      PlainText := PlainText + Seg.Text;

    lineSubTexts := DividesIntoLines(PlainText);
    SetLength(Result, 0);
    maxWidth := 0;
    lineWidthLimit := Rect.Right - Rect.Left;
    // The rectangle comes back RELATIVE, like TextExtentSimple and the DirectWrite
    // provider (rpinfoprovgdi.pas TextExtent) return it: Left/Top at 0, Right/Bottom the
    // measured width and height. The caller (rppdffile.pas TextRect) reads recsize.Bottom
    // as the height when it centres or bottom-aligns; with the item's absolute Top left in
    // here, every vertically centred shaped text landed Top/2 twips too high (a 10 pt line
    // in a box 782 twips down the page came out 168 twips above its own clip and vanished)
    // and a bottom-aligned one a whole Top too high. Only this provider did it, which is
    // why the same .rep was right on Windows (GDI) and wrong on Linux.
    Rect.Left := 0;
    Rect.Top := 0;
    TempFont := TRpPDFFont.Create;
    fontDataCache := nil;
    try
      TempFont.Name := pdfFont.Name;
      TempFont.Size := pdfFont.Size;
      TempFont.Color := pdfFont.Color;
      TempFont.WFontName := pdfFont.WFontName;
      TempFont.LFontName := pdfFont.LFontName;
      fontDataCache := TDictionary<string, TRpTTFontData>.Create;
      // Cache the base font data
      fontCacheKey := UpperCase(pdfFont.WFontName);
      fontDataCache.AddOrSetValue(fontCacheKey, adata);

      for lineSubText in lineSubTexts do
      begin
        line := Copy(PlainText, lineSubText.Position, lineSubText.Length);
        possibleBreaksCharIdx := FillPossibleLineBreaksString(line);
        calculatedLines := TList<TLineGlyphs>.Create;

        Bidi := TICUBidi.Create;
        logicalRuns := nil;
        try
          if not Bidi.SetPara(line, $FF) then
            raise Exception.Create('Bidi error');
          logicalRuns := Bidi.GetLogicalRuns(line);
        finally
          Bidi.Free;
        end;

        remaining:=lineWidthLimit;
        var textOffset:=lineSubtext.Position-1;
        currentChunk:=TLineGlyphs.Create(textOffset);

        for logicalRun in logicalRuns do
        begin
          RunAbsStart := lineSubText.Position + logicalRun.LogicalStart;
          RunLen := logicalRun.Length;
          CurrentRunOffset := 0;
          SegStartAbs := 1;

          for Seg in Segments do
          begin
             SegLen := Length(Seg.Text);
             SegEndAbs := SegStartAbs + SegLen;
             IntStart := Max(RunAbsStart, SegStartAbs);
             IntEnd := Min(RunAbsStart + RunLen, SegEndAbs);

             if IntStart < IntEnd then
             begin
               TempFont.Bold := pdfFont.Bold or (hsBold in Seg.Styles);
               TempFont.Italic := pdfFont.Italic or (hsItalic in Seg.Styles);
               if Seg.FontFamily <> '' then
               begin
                 TempFont.WFontName := Seg.FontFamily;
                 TempFont.LFontName := Seg.FontFamily;
               end
               else
               begin
                 TempFont.WFontName := pdfFont.WFontName;
                 TempFont.LFontName := pdfFont.LFontName;
               end;
               if Seg.HasFontSize then
                 activeSize := Seg.FontSize
               else
                 activeSize := FontSize;
               TempFont.Size := Round(activeSize);
               SelectFont(TempFont, '', false);
               // Con QUE fuente se ha quedado la pedida: es contra ella contra la que se
               // mide la cobertura para trocear, y es la que dice si una reserva es de
               // verdad otra fuente o el mismo fichero con otro nombre.
               fuenteDelTramo := currentfont;

               // Cache font data for per-line spacing calculation (key by family name only)
               fontCacheKey := UpperCase(TempFont.WFontName);
               if not fontDataCache.ContainsKey(fontCacheKey) then
               begin
                 cachedData := TRpTTFontData.Create;
                 // Start with hhea-based metrics from currentfont
                 cachedData.Ascent := currentfont.ascent;
                 cachedData.Descent := currentfont.descent;
                 cachedData.Leading := currentfont.leading;
                 if currentfont.height > 0 then
                   cachedData.Height := currentfont.height
                 else
                   cachedData.Height := currentfont.ascent - currentfont.descent + currentfont.leading;
                 // Override with OS/2 table (matching C# FontInfoFt / DirectWrite)
                 if FileExists(currentfont.filename) then
                 begin
                   var fontStream := TMemoryStream.Create;
                   try
                     fontStream.LoadFromFile(currentfont.filename);
                     var os2: TOS2Metrics;
                     ReadOS2Metrics(fontStream, os2);
                     if os2.Found then
                     begin
                       var cf := currentfont.convfactor;
                       if os2.UseTypoMetrics then
                       begin
                         var dwA := os2.sTypoAscender;
                         var dwD := -os2.sTypoDescender;
                         var dwG := os2.sTypoLineGap;
                         cachedData.Ascent := Round(cf * dwA);
                         cachedData.Descent := -Round(cf * dwD);
                         cachedData.Height := Round(cf * (dwA + dwD + dwG));
                         cachedData.Leading := cachedData.Height - cachedData.Ascent + cachedData.Descent;
                       end
                       else
                       begin
                         cachedData.Ascent := Round(cf * os2.usWinAscent);
                         cachedData.Descent := -Round(cf * os2.usWinDescent);
                         cachedData.Leading := cachedData.Height - cachedData.Ascent + cachedData.Descent;
                       end;
                     end;
                   finally
                     fontStream.Free;
                   end;
                 end;
                 fontDataCache.Add(fontCacheKey, cachedData);
               end;

               if logicalRun.Direction = UBIDI_RTL then
                 direction := RP_UBIDI_RTL
               else
                 direction := RP_BIDI_LTR;

               ChunkText := Copy(PlainText, IntStart, IntEnd - IntStart);
               positions := CalcGlyphPositions(ChunkText, direction, String(logicalRun.ScriptString), activeSize);

               // Font fallback: if any glyph has GlyphIndex=0, the current font
               // doesn't support these characters. Try re-selecting with content.
               // This matches the old TextExtent fallback logic.
               var doFallback := false;
               for k:=0 to Length(positions)-1 do
               begin
                 if (positions[k].GlyphIndex = 0) then
                 begin
                   doFallback := true;
                   break;
                 end;
               end;
               if (doFallback) then
               begin
                 // POR TRAMOS, no por trozo entero: la reserva entra donde faltan los
                 // glifos y el texto vuelve a la fuente pedida en cuanto vuelve a haberlos.
                 var acumuladas := TList<TGlyphPos>.Create;
                 try
                  var tramos := TroceaPorCobertura(ChunkText,fuenteDelTramo,
                    direction = RP_UBIDI_RTL);
                  for var t:=0 to High(tramos) do
                  begin
                   if (tramos[t].Longitud<=0) then
                    continue;
                   var textoTramo := Copy(ChunkText,tramos[t].Inicio+1,tramos[t].Longitud);
                   var familiaTramo: string := TempFont.WFontName;
                   var hayReserva := false;
                   if (tramos[t].NecesitaReserva) then
                    hayReserva := ReservaPorContenido(TempFont,textoTramo,fuenteDelTramo,
                      familiaTramo);
                   if (not hayReserva) then
                   begin
                    // Sin reserva que valga se dibuja con la pedida, con sus huecos, que es
                    // lo que pasaba antes de todo esto.
                    SelectFont(TempFont,'',false);
                    familiaTramo := TempFont.WFontName;
                   end;
                   var posTramo := CalcGlyphPositions(textoTramo, direction,
                     DetectaScript(textoTramo), activeSize);
                   for k:=0 to Length(posTramo)-1 do
                   begin
                    posTramo[k].Cluster := posTramo[k].Cluster + Cardinal(tramos[t].Inicio);
                    posTramo[k].FontFamily := familiaTramo;
                    acumuladas.Add(posTramo[k]);
                   end;
                  end;
                  if (acumuladas.Count>0) then
                   positions := TGlyphPosArray(acumuladas.ToArray);
                 finally
                  acumuladas.Free;
                 end;
               end;

               runWidth:=0;
               for k:=0 to Length(positions)-1 do
               begin
                 runWidth:=runWidth+positions[k].XAdvance;
                 positions[k].LineCluster:=positions[k].Cluster + Cardinal(IntStart - lineSubText.Position);
                 positions[k].Style := 0;
                 if hsBold in Seg.Styles then positions[k].Style := positions[k].Style or 1;
                 if hsItalic in Seg.Styles then positions[k].Style := positions[k].Style or 2;
                 if hsUnderline in Seg.Styles then positions[k].Style := positions[k].Style or 4;
                 if hsStrikeOut in Seg.Styles then positions[k].Style := positions[k].Style or 8;
                 // Cuando se ha troceado, cada posicion ya trae la familia con la que se
                 // dibujo su tramo, y esa manda: es el nombre que hace que el escritor de
                 // PDF cambie de recurso al llegar a esos glifos.
                 if (Length(positions[k].FontFamily)=0) then
                  positions[k].FontFamily := TempFont.WFontName;
                 positions[k].FontSize := activeSize;
                 positions[k].HasFontSize := Seg.HasFontSize;
                 positions[k].Color := Seg.Color;
                 positions[k].HasColor := Seg.HasColor;
               end;

               if ((runWidth<=remaining) or (not WordWrap)) then
               begin
                 for g in positions do
                   currentChunk.AddGlyph(g, logicalRun.LogicalStart);
                 remaining:=remaining-runWidth;
               end
               else
               begin
                 if direction = RP_UBIDI_RTL then
                   chunks := BreakChunksRTL(positions, remaining, lineWidthLimit ,possibleBreaksCharIdx,line)
                 else
                   chunks := BreakChunksLTR(positions, remaining, lineWidthLimit ,possibleBreaksCharIdx,line);

                 for j:=0 to chunks.Count-1 do
                 begin
                   chunk:=chunks[j];
                   if (j=0) then
                   begin
                     for g in chunk do currentChunk.AddGlyph(g, logicalRun.LogicalStart);
                     calculatedLines.Add(currentChunk);
                     currentChunk:=TLineGlyphs.Create(textOffset);
                     remaining:=lineWidthLimit;
                   end
                   else if (j=chunks.Count-1) then
                   begin
                     remaining:=lineWidthLimit;
                     for g in chunk do
                     begin
                       currentChunk.AddGlyph(g, logicalRun.LogicalStart);
                       remaining:=remaining-g.XAdvance;
                     end;
                   end
                   else
                   begin
                     for g in chunk do currentChunk.AddGlyph(g, logicalRun.LogicalStart);
                     remaining:=lineWidthLimit;
                     calculatedLines.Add(currentChunk);
                     currentChunk:=TLineGlyphs.Create(textOffset);
                   end;
                 end;
               end;
             end;
             SegStartAbs := SegEndAbs;
          end;
        end;
        if (currentChunk.Glyphs.Count>0) then calculatedLines.Add(currentChunk);

        Bidi := TICUBidi.Create;
        visualRuns := nil;
        try
          if not Bidi.SetPara(line, $FF) then raise Exception.Create('VisualRuns error');
          visualRuns := Bidi.GetVisualRuns(line);
        finally
          Bidi.Free;
        end;

        var lineIdx := 0;
        for calculatedLine in calculatedLines do
        begin
          minCluster:=calculatedline.MinClusterText;
          maxCluster:=calculatedline.MaxClusterText;
          visualGlyphs:=TList<TGlyphPos>.Create;
          for vRun in visualRuns do
          begin
           if vRun.Direction = UBIDI_RTL then
           begin
            for k:=vRun.LogicalStart+vRun.Length downto vRun.LogicalStart+1  do
            begin
             if (calculatedLine.ClusterMap.ContainsKey(k)) then
             begin
              lst := calculatedLine.ClusterMap[k];
              for j:=0 to lst.Count-1 do visualGlyphs.Add(calculatedline.Glyphs[lst[j]]);
             end;
            end;
           end
           else
           begin
            for k:=vRun.LogicalStart+1 to vRun.LogicalStart+vRun.Length do
            begin
             if (calculatedLine.ClusterMap.ContainsKey(k)) then
             begin
              lst := calculatedLine.ClusterMap[k];
              for j:=0 to lst.Count-1 do visualGlyphs.Add(calculatedline.Glyphs[lst[j]]);
             end;
            end;
           end;
          end;

          // Trim whitespace at word-wrap boundaries (matching C# FontInfoFt / DirectWrite AdjustLineSpaces)
          var isParaRTL := (visualRuns.Count > 0) and (visualRuns[0].Direction = UBIDI_RTL);
          if not isParaRTL then
          begin
            // LTR: remove trailing whitespace from END of list (visual right)
            while visualGlyphs.Count > 0 do
            begin
              var ch := visualGlyphs[visualGlyphs.Count - 1].CharCode;
              if (ch = ' ') or (ch = #9) or (ch = #10) or (ch = #13) then
                visualGlyphs.Delete(visualGlyphs.Count - 1)
              else
                break;
            end;
            // Remove leading whitespace from continuation lines (word-wrapped)
            if lineIdx > 0 then
            begin
              while visualGlyphs.Count > 0 do
              begin
                var ch := visualGlyphs[0].CharCode;
                if (ch = ' ') or (ch = #9) then
                  visualGlyphs.Delete(0)
                else
                  break;
              end;
            end;
          end
          else
          begin
            // RTL: remove trailing whitespace from BEGINNING of list (visual left)
            while visualGlyphs.Count > 0 do
            begin
              var ch := visualGlyphs[0].CharCode;
              if (ch = ' ') or (ch = #9) or (ch = #10) or (ch = #13) then
                visualGlyphs.Delete(0)
              else
                break;
            end;
            // Remove leading whitespace from continuation lines (visual right for RTL)
            if lineIdx > 0 then
            begin
              while visualGlyphs.Count > 0 do
              begin
                var ch := visualGlyphs[visualGlyphs.Count - 1].CharCode;
                if (ch = ' ') or (ch = #9) then
                  visualGlyphs.Delete(visualGlyphs.Count - 1)
                else
                  break;
              end;
            end;
          end;

          // Recompute min/max cluster after trimming
          if visualGlyphs.Count > 0 then
          begin
            minCluster := MaxInt;
            maxCluster := -1;
            for k := 0 to visualGlyphs.Count - 1 do
            begin
              if Int64(visualGlyphs[k].LineCluster) < minCluster then
                minCluster := visualGlyphs[k].LineCluster;
              if Int64(visualGlyphs[k].LineCluster) > maxCluster then
                maxCluster := visualGlyphs[k].LineCluster;
            end;
          end;

          LineInfo.Glyphs:=TGlyphPosArray(visualGlyphs.ToArray());
          LineInfo.Position := minCluster;
          LineInfo.Size := maxCluster - minCluster + 1;
          LineInfo.Text :=Copy(PlainText, minCluster, maxCluster - minCluster + 1);

          // Per-line width and max font size
          lw := 0;
          for k := 0 to High(LineInfo.Glyphs) do
            lw := lw + LineInfo.Glyphs[k].XAdvance;
          LineInfo.Width := Round(lw);

          // Compute per-line baseline and height matching C# FontInfoFt / GDI DirectWrite
          maxBaselineTwips := (adata.Ascent + Max(0, adata.Leading)) / 1000.0 * FontSize * 20.0;
          maxLineHeight := adata.Height / 1000.0 * FontSize * 20.0;
          for k := 0 to High(LineInfo.Glyphs) do
          begin
            if LineInfo.Glyphs[k].HasFontSize then
              gFontSize := LineInfo.Glyphs[k].FontSize
            else
              gFontSize := FontSize;
            fontCacheKey := UpperCase(LineInfo.Glyphs[k].FontFamily);
            if fontDataCache.TryGetValue(fontCacheKey, cachedData) then
            begin
              gBaselineTwips := (cachedData.Ascent + Max(0, cachedData.Leading)) / 1000.0 * gFontSize * 20.0;
              gHeightTwips := cachedData.Height / 1000.0 * gFontSize * 20.0;
            end
            else
            begin
              gBaselineTwips := (adata.Ascent + Max(0, adata.Leading)) / 1000.0 * gFontSize * 20.0;
              gHeightTwips := adata.Height / 1000.0 * gFontSize * 20.0;
            end;
            if gBaselineTwips > maxBaselineTwips then
              maxBaselineTwips := gBaselineTwips;
            if gHeightTwips > maxLineHeight then
              maxLineHeight := gHeightTwips;
          end;
          currentLineSpacing := Round(maxLineHeight);
          lineBaseline := Round(maxBaselineTwips);

          LineInfo.TopPos := Round(rectTop) + lineBaseline;
          LineInfo.Height := currentLineSpacing;
          LineInfo.LineHeight := currentLineSpacing;
          LineInfo.lastline := False;
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)] := LineInfo;
          if LineInfo.Width > maxWidth then maxWidth := LineInfo.Width;
          rectTop := rectTop + currentLineSpacing;
          Inc(lineIdx);
        end;
        calculatedLines.Free;
        possibleBreaksCharIdx.Free;
      end;
    finally
      TempFont.Free;
      // Free cached font data objects (except adata which is not owned)
      if Assigned(fontDataCache) then
      begin
        for cachedData in fontDataCache.Values do
        begin
          if cachedData <> adata then
            cachedData.Free;
        end;
        fontDataCache.Free;
      end;
    end;
    if Length(Result) > 0 then Result[High(Result)].lastline := True;
  finally
    Segments.Free;
    lineSubTexts.Free;
    currentfont:=originalfont;
  end;
  Rect.Right := Rect.Left + Round(maxWidth);
  Rect.Bottom := Rect.Top + Round(rectTop);
end;

function TRpFTInfoProvider.CalcGlyphPositions(
  astring: WideString;
  direction: TRpBiDiDirection;
  script: string;
  FontSize: double): TGlyphPosArray;

var
  Font: THBFont;
  Buf: THBBuffer;
  GlyphInfo: TArray<THBGlyphInfo>;
  GlyphPos: TArray<THBGlyphPosition>;
  i: Integer;
  mem: Pointer;
  shapeData: TShapingData;
  scale:double;
  fontScaleValue: Int32;
begin
  InitHarfBuzz;
  SetLength(Result, 0);
  if astring = '' then Exit;

  if not currentfont.LoadedFace then
  begin
    shapeData := TShapingData.Create;
    if not Assigned(currentfont.data) then
    begin
     currentFont.data:=TRpTTFontData.Create;
     currentFont.data.FontData:=TAdvFontData.Create;
     FillFontDataInt(currentFont.data);
    end;
    currentfont.data.FontData.Fontdata.Position := 0;
    mem := currentfont.data.FontData.Fontdata.Memory;
    CheckFreeType(FT_New_Memory_Face(ftlibrary, mem, currentfont.data.FontData.Fontdata.Size, 0, shapedata.FreeTypeFace));

    currentfont.CustomImplementation := shapedata;
    currentfont.LoadedFace := True;
    shapedata.Font := THBFont.CreateReferenced(shapeData.FreeTypeFace);
    Font := shapedata.Font;

    // Configuramos FreeType con el tamaño en points y DPI 1440
    CheckFreeType(FT_Set_Char_Size(shapedata.FreeTypeFace, 0, 64 * 100, 720, 720));
  end
  else
    shapeData := currentfont.CustomImplementation as TShapingData;


  Font := shapedata.Font;

  try

    // --- Comentadas las líneas de escala personalizada
    fontScaleValue := Round(FontSize * 20.0);
    Font.PTEM := FontSize;
    Font.SetScale(fontScaleValue, fontScaleValue);
    Font.FTFontSetFuncs;

    // scale:=FontSize*20/adata.UnitsPerEM;
    // scale := 14/72;
    scale:=1;
    Buf := THBBuffer.Create;
    try
      if direction = TRpBiDiDirection.RP_UBIDI_RTL then
        Buf.Direction := hbdRTL
      else
        Buf.Direction := hbdLTR;

      Buf.Script := THBScript.FromString(AnsiString(script));
      if script = 'Arab' then
        Buf.Language := hb_language_from_string('ar', -1);

      Buf.AddUTF16(astring);
      Buf.Shape(Font);

      GlyphInfo := Buf.GetGlyphInfos;
      GlyphPos := Buf.GetGlyphPositions;
      SetLength(Result, Length(GlyphInfo));

      for i := 0 to High(GlyphInfo) do
      begin
        Result[i].GlyphIndex := GlyphInfo[i].Codepoint;
        // ahora devuelve la posición en la escala por defecto de HarfBuzz
        Result[i].XAdvance := Round(GlyphPos[i].XAdvance*scale);
        Result[i].XOffset  := Round(GlyphPos[i].XOffset*scale);
        Result[i].YOffset  := Round(GlyphPos[i].YOffset*scale);
        Result[i].CharCode := astring[GlyphInfo[i].Cluster + 1];
        Result[i].Cluster  := GlyphInfo[i].Cluster+1;
      end;
    finally
      Buf.Destroy;
    end;
  finally
    // Font.Destroy; // si lo necesitas
  end;
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
{$IFDEF MSWINDOWS}
var
  abuf:pchar;
  szAppDataW:array [0..MAX_PATH] of WideChar;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
 abuf:=AllocMem(255);
 try
  GetWindowsDirectory(abuf,255);
  alist.Add(StrPas(abuf)+'\fonts');
  SHGetFolderPathW(0, CSIDL_LOCAL_APPDATA or CSIDL_FLAG_CREATE, 0, 0, szAppDataW);
  PathAppendW(szAppdataW,PWidechar('Microsoft'));
  PathAppendW(szAppdataW,PWidechar('Windows'));
  PathAppendW(szAppdataW,PWidechar('Fonts'));
  alist.Add(StrPas(szAppDataW));

  finally
  FreeMem(abuf);
 end;
 exit;
{$ELSE}
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
 aface:FT_Face;
 ncara,ncaras:integer;
// afaceRec:FT_FaceRec;
 fontpaths1:TStrings;
 direc:string;
 afilename2: AnsiString;
begin
 CheckFreeTypeLoaded;
 CheckFreeType(FT_Init_FreeType(ftlibrary));
  if Assigned(fontlist) then
  exit;
{$IFDEF USEFONTCONFIG}
 if (FontConfigAvailable) then
  exit;
 InitFontConfig;

 if (FontConfigAvailable) then
 begin
  exit;
 end;
{$ENDIF}



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
  // Las colecciones. Sin esto, en Windows no habia ni una fuente japonesa en la lista:
  // YuGothR.ttc, msgothic.ttc, meiryo.ttc... todas vienen en coleccion.
  retvalue:=SysUtils.FindFirst(fontpaths.strings[i]+C_DIRSEPARATOR+'*.ttc',faAnyFile,F);
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
  direc:=fontpaths.strings[i]+C_DIRSEPARATOR+'*.TTC';
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
 initialized:=true;

 // Now fill the font list with all font files
 for i:=0 to fontfiles.Count-1 do
 begin
  afilename:=fontfiles.strings[i];
  afilename2:=AnsiString(afilename);
//  FileToBytes(afileName,bytes);
  // Cuantas caras trae el fichero. Con indice -1 FreeType no abre ninguna: solo cuenta.
  ncaras:=1;
  aface:=nil;
  if (FT_New_Face(ftlibrary,PAnsichar(afilename2),-1,aface)=0) then
  begin
   ncaras:=aface.num_faces;
   FT_Done_Face(aface);
   aface:=nil;
  end;
  if (ncaras<1) then
   ncaras:=1;
  // CARA POR CARA, no solo la primera. Una coleccion lleva varias fuentes distintas en un
  // mismo fichero y hasta aqui la lista se quedaba con la primera de cada una.
  for ncara:=0 to ncaras-1 do
  begin
   aobj:=nil;
   try
    // Add it only if it's a TrueType or OpenType font
    // Type1 fonts also supported
    // Some truetype do not set scalable, so add all
    aobj:=FillLogFont(afilename,ncara);
   except
    // Un fichero que no se deja abrir no es motivo para dejar de enumerar los demas.
    aobj:=nil;
   end;
   if (not Assigned(aobj)) then
    continue;
   // NOn scalable fonts not supported
   if (not aobj.scalable) then
   begin
    aobj.Free;
    continue;
   end;

    if  Assigned(aobj) then
    begin
{$IFDEF MSWINDOWS}
      if ('ARIAL'=UpperCase(aobj.familyname)) then
{$ELSE}
      if (Pos('CANTARELL',UpperCase(aobj.familyname))>0) then
{$ENDIF}
      begin
        if ((not aobj.italic) and (not aobj.bold)) then
        begin
         defaultfont:=aobj;
        end
        else
        if ((not aobj.italic) and (aobj.bold)) then
        begin
         defaultfontb:=aobj;
        end
        else
        if ((aobj.italic) and (not aobj.bold)) then
        begin
          defaultfontit:=aobj;
        end
        else
        if ((aobj.italic) and (aobj.bold)) then
        begin
          defaultfontbit:=aobj;
        end;
      end;
      if (Pos('DROID',UpperCase(aobj.familyname))=0) then
      begin
      // Default font configuration, LUXI SANS is default
      if ((not aobj.italic) and (not aobj.bold)) then
      begin
       if (not assigned(defaultfont_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0) and (defaultfont_arabic=nil)) then
       begin
        defaultfont_arabic:=aobj;
       end;
{$IFDEF MSWINDOWS}
{$ELSE}
       if not assigned(defaultfont) then
        defaultfont:=aobj
{$ENDIF}
      end
      else
      if ((not aobj.italic) and (aobj.bold)) then
      begin
       if (not assigned(defaultfontb_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0) and (defaultfontb_arabic=nil)) then
       begin
        defaultfontb_arabic:=aobj;
       end;
{$IFDEF MSWINDOWS}
{$ELSE}
       if not assigned(defaultfontb) then
        defaultfontb:=aobj
{$ENDIF}
      end
      else
      if ((aobj.italic) and (not aobj.bold)) then
      begin
       if (not assigned(defaultfontit_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0) and (defaultfontit_arabic=nil)) then
       begin
        defaultfontit_arabic:=aobj;
       end;
{$IFDEF MSWINDOWS}
{$ELSE}
       if not assigned(defaultfontit) then
        defaultfontit:=aobj
{$ENDIF}
      end
      else
      if ((aobj.italic) and (aobj.bold)) then
      begin
       if (not assigned(defaultfontbit_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0) and (defaultfontbit_arabic=nil)) then
       begin
        defaultfontbit_arabic:=aobj;
       end;
{$IFDEF MSWINDOWS}
{$ELSE}
       if not assigned(defaultfontbit) then
        defaultfontbit:=aobj
{$ENDIF}
      end;

      end;
      fontlist.AddObject(UpperCase(aobj.familyname),aobj);
    end;
  end;
 end;
 if (defaultfontb=nil) then
  defaultfontb:=defaultfont;
 if (defaultfontit=nil) then
  defaultfontit:=defaultfont;
 if (defaultfontbit=nil) then
  defaultfontbit:=defaultfont;
 if (defaultfontb_arabic = nil) then
 begin
  if (defaultfont_arabic = nil) then
  begin
   defaultfontb_arabic:=defaultfontb;
  end
  else
  begin
   defaultfontb_arabic:=defaultfont_arabic;
  end;
 end;
 if (defaultfontit_arabic = nil) then
 begin
  if (defaultfont_arabic = nil) then
  begin
   defaultfontit_arabic:=defaultfontit;
  end
  else
  begin
   defaultfontit_arabic:=defaultfont_arabic;
  end;
 end;
 if (defaultfontbit_arabic = nil) then
 begin
  if (defaultfont_arabic = nil) then
  begin
   defaultfontbit_arabic:=defaultfontbit;
  end
  else
  begin
   defaultfontbit_arabic:=defaultfont_arabic;
  end;
 end;
 if (defaultfontb_arabic = nil) then
 begin
   defaultfont_arabic:=defaultfont;
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
 // El diccionario solo guarda referencias a fichas de fontlist: se suelta antes de que
 // esas fichas dejen de existir, y no libera nada el mismo.
 if assigned(reservaporcobertura) then
 begin
  reservaporcobertura.Free;
  reservaporcobertura:=nil;
 end;
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

destructor TRpFTInfoProvider.Destroy;
begin
 crit.free;

 inherited destroy;
end;

function isSameFont(fontName,pattern: string): boolean;
begin
 Result:=false;
 if (UpperCase(pattern)=UpperCase(fontName)) then
 begin
  Result:=true;
 end
 else
 if ((pattern='HELVETICA') or (pattern='ARIAL')) then
 begin
  if (fontName='CANTARELL') then
  begin
   Result:=true;
  end
 end;
end;


function isSameFont2(fontName,pattern: string): boolean;
begin
 if (UpperCase(pattern)=UpperCase(fontName)) then
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

{$IFDEF USEFONTCONFIG}
procedure TRpFtInfoProvider.SelectFontFontConfig(pdffont: TRpPDFFont; unicodeContent: string = '');
begin
 SelectFontFontConfigInt(pdffont,unicodeContent,false);
 if (not currentFont.scalable) then
  SelectFontFontConfigInt(pdffont,unicodeContent,true)
end;


procedure TRpFtInfoProvider.SelectFontFontConfigInt(pdffont: TRpPDFFont; unicodeContent: string;removeFamily: boolean);
var
  Config: PFcConfig;
  Pattern: PFcPattern;
  Match: PFcPattern;
  FileNamePtr: PChar;
  filename: string;
  MatchKind: Integer;
  familyname:string;
  FontIndex:integer;
begin
  filename := '';

  // 1. Verificar si Fontconfig está disponible
  if not FontConfigAvailable then
    raise Exception.Create('No fontconfig installed');

  // 2. Obtener la configuración
  Config := FcConfigGetCurrent();

  // 3. Obtener el patrón de búsqueda
// 2. Crear el patrón de fuente usando el wrapper (FcCreatePattern)
  //    Esto construye el patrón con Family, Weight e Slant.
  familyName:=pdfFont.LFontName;
  if (familyName='Helvetica') then
  begin
    familyName:='Cantarell';
  end;
  if (removeFamily) then
    familyName:='';

(*  WriteToStdError('Ask for font: '+familyName);
  if (pdffont.Bold) then
  begin
   WriteToStdError(' Bold ' +chr(10));
  end
  else
  begin
   WriteToStdError(' Regular ' +chr(10));
  end;*)
  Pattern := rpfontconfig.FcCreatePattern(
    familyName,
    pdffont.Bold,
    pdffont.Italic,
    unicodeContent
  );
  if Pattern = nil then
    Exit; // No se pudo crear el patrón

  try
    // Este paso analiza FC_TEXT y sustituye FC_FAMILY (Helvetica) si no soporta el script.
    //if unicodeContent = '' then
      // Si NO hay contenido, solo sustituir a nivel de FUENTE (evita reemplazar Helvetica)
    //  MatchKind := FC_MATCH_FONT
    //else
      // Si hay contenido, sustituir a nivel de PATRÓN (para forzar el fallback de script/familia)
    MatchKind := FC_MATCH_PATTERN;
    // a) Sustitución predeterminada    FcDefaultSubstitute(Pattern);
     FcDefaultSubstitute(Pattern);
    // b) Sustitución de configuración (aplica reglas de idioma/script)
     FcConfigSubstitute(Config, Pattern, MatchKind); // FC_MATCH_PATTERN = 0
    // 4. Buscar la mejor fuente coincidente
    // La función devuelve el Match en el tercer parámetro (por referencia),
    // pero también lo devuelve como valor de la función si es exitoso.
    Match := FcFontMatch(Config, Pattern, Match);

    if Assigned(Match) then
    begin
      // 5. Extraer el nombre del archivo de la fuente seleccionada
      // El nombre del archivo es la propiedad FC_FILE (índice 0)
      FcPatternGetString(Match, PChar(FC_FILE), 0, FileNamePtr);
      // Verifica si el puntero de salida (la dirección de la cadena) es válido
      if Assigned(FileNamePtr) then
      begin
       // Asignación de la ruta de archivo solo si el puntero no es nil
       filename := UTF8ToString(RawByteString(string(FileNamePtr)));
       FontIndex:=0;
       FcPatternGetInteger(Match, PChar(FC_INDEX), 0, FontIndex);
       currentfont:=GetOrAddLogFont(filename,FontIndex);
      // WriteToStdError('CurrentFont is: '+filename+chr(10));
       if not assigned(currentFont.data) then
       begin
        currentfont.OpenFont;
        if not assigned(currentfont.data) then
        begin
          currentfont.data:=TRpTTFontData.Create;
          currentfont.data.fontdata:=TAdvFontData.Create;
          FillFontDataInt(currentfont.data);
        end;
        // La cara que dijo fontconfig, hasta el subsetter. data.FontIndex estaba declarado
        // y no se asignaba en ningun sitio, asi que hb_face_create(blob, data.FontIndex)
        // trabajaba SIEMPRE sobre la cara 0: en una coleccion (.ttc) se media una cara y se
        // subseteaba otra. El LogFont ya esta cacheado por fichero|indice, asi que el indice
        // de esta ficha es el de esta cara.
        currentfont.data.FontIndex:=FontIndex;
       end;
      end;
   end;
  finally
    // 6. Limpiar: Liberar el patrón creado (el Match no se libera aquí)
    FcPatternDestroy(Pattern);
  end;
end;
{$ENDIF}

procedure TRpFtInfoProvider.SelectFont(pdffont:TRpPDFFOnt;content: string;ignoreFamily: boolean);
var
 faltan:TArray<Integer>;
 cubre:TRpLogFont;
begin
 crit.Enter;
 try
  InitLibrary;
{$IFDEF USEFONTCONFIG}
  if (FontConfigAvailable) then
  begin
   if (ignoreFamily) then
   begin
     SelectFontFontConfigInt(pdffont,content,true);
   end
   else
     SelectFontFontConfig(pdffont,content);

   exit;
  end;
{$ENDIF}
  SelectFontPorNombre(pdffont);
  // LA MISMA RESERVA QUE HACE FONTCONFIG, PERO A MANO. Donde hay fontconfig se le manda el
  // texto y contesta con una fuente que lo cubre; donde no lo hay -Windows- no existe base
  // de datos de fuentes que sepa de scripts, y hasta aqui el `content` se tiraba a la
  // basura: un informe con japones acababa pidiendo glifos que Arial no tiene y el PDF
  // salia con huecos. Se busca a mano sobre la lista ya enumerada, que es barata de
  // recorrer porque el escaneo inicial ya abrio todos los ficheros una vez.
  if (Length(content)>0) then
  begin
   faltan:=CodigosSinGlifo(currentfont,content);
   if (Length(faltan)>0) then
   begin
    cubre:=BuscaPorCobertura(faltan,pdffont.bold,pdffont.italic);
    if (Assigned(cubre) and (cubre<>currentfont)) then
    begin
     currentfont:=cubre;
     // El atajo de SelectFontPorNombre se acuerda de la ULTIMA familia pedida y sale sin
     // tocar currentfont. Si se deja puesto, la siguiente peticion de esa misma familia
     // -el tramo latino que viene detras del japones- se quedaria con la reserva.
     currentname:='';
     currentstyle:=-1;
    end;
   end;
  end;
 finally
  crit.Leave;
 end;
end;

// Busca la fuente de reserva para un texto y deja currentfont puesta en ella. Devuelve
// false cuando no hay reserva que valga y hay que dibujar con la pedida, con sus huecos.
//
// Se le manda el TEXTO a fontconfig -o, donde no lo hay, se barre la lista enumerada-: eso
// es lo que hace que conteste con una fuente que si lleva el script. Pero el escritor de
// PDF no recibe ficheros, recibe NOMBRES: elige el recurso con g.FontFamily (TrpPDFCanvas,
// WriteGlyphs) y vuelve a pedir esa familia. Asi que antes de fiarse se COMPRUEBA que
// pedir ese nombre cae en el mismo fichero y la misma cara. Si no cae, no se usa la
// reserva: se dibuja como antes -con sus huecos- en vez de escribir los glifos de una
// fuente bajo el recurso de otra, que es basura silenciosa y peor que un hueco.
function TRpFtInfoProvider.ReservaPorContenido(pdffont:TRpPDFFont;
  const texto:WideString;fuenteactual:TRpLogFont;var familia:string):boolean;
var
 encontrada:TRpLogFont;
 porNombre:TRpPDFFont;
 faltan:TArray<Integer>;
begin
 Result:=false;
 SetLength(faltan,0);
 if Assigned(fuenteactual) then
  faltan:=CodigosSinGlifo(fuenteactual,texto);
 SelectFont(pdffont,texto,false);
 encontrada:=currentfont;
 // Segundo intento sin familia, el que ya hacia el camino de antes: si la que ha salido no
 // aporta ni uno de los glifos que faltaban, se pide cualquiera que si los lleve.
 if (Assigned(encontrada) and (Length(faltan)>0)
     and (CuantosCubre(encontrada,faltan)=0)) then
 begin
  SelectFont(pdffont,texto,true);
  encontrada:=currentfont;
 end;
 if ((not Assigned(encontrada)) or (Length(encontrada.familyname)=0)) then
  exit;
 // Si la reserva es el MISMO fichero que ya se tenia, no hay reserva ninguna: los glifos
 // van a seguir faltando igual, y renombrarla mete en el PDF un segundo recurso con la
 // misma fuente dentro. Pasa cuando en la maquina no hay ninguna que lleve ese script.
 if (Assigned(fuenteactual) and (encontrada.filename=fuenteactual.filename)
     and (encontrada.fontIndex=fuenteactual.fontIndex)) then
  exit;
 // Y si no aporta NI UN glifo de los que faltaban tampoco es reserva: renombrar el tramo
 // a una fuente que tampoco lo dibuja deja los mismos huecos y ademas incrusta otra fuente
 // entera para nada. Es lo que pasa con el arabe en una maquina que no tiene ninguna
 // arabe: fontconfig contesta lo que sea, y lo que sea no vale.
 if ((Length(faltan)>0) and (CuantosCubre(encontrada,faltan)=0)) then
  exit;
 // Y tiene que caber en el PDF: fontconfig no sabe nada de lo que este motor sabe
 // incrustar, asi que puede contestar una cara CFF de una coleccion.
 if (not SePuedeIncrustar(encontrada.filename,encontrada.fontIndex)) then
  exit;
 porNombre:=TRpPDFFont.Create;
 try
  porNombre.Name:=pdffont.Name;
  porNombre.Size:=pdffont.Size;
  porNombre.Color:=pdffont.Color;
  porNombre.Bold:=pdffont.Bold;
  porNombre.Italic:=pdffont.Italic;
  porNombre.WFontName:=encontrada.familyname;
  porNombre.LFontName:=encontrada.familyname;
  SelectFont(porNombre,'',false);
  if ((not Assigned(currentfont)) or (currentfont.filename<>encontrada.filename)
      or (currentfont.fontIndex<>encontrada.fontIndex)) then
   exit;
 finally
  porNombre.Free;
 end;
 familia:=encontrada.familyname;
 Result:=true;
end;

// Elige la fuente de una peticion en la lista enumerada, por familia y estilo, tal como
// este motor lo ha hecho siempre cuando no hay fontconfig a quien preguntar.
procedure TRpFtInfoProvider.SelectFontPorNombre(pdffont:TRpPDFFOnt);
var
 afontname:string;
 isbold:boolean;
 isitalic:boolean;
 i:integer;
 match:boolean;
 afont:TRpLogFont;
 currentFontName:string;
 stylestring:string;
begin
(*{$IFDEF MSWINDOWS}
 afontname:=UpperCase(pdffont.WFontName);
{$ENDIF}
{$IFDEF LINUX}
 afontname:=UpperCase(pdffont.LFontName);
 if (Length(afontname)=0) then
  afontname:='Helvetica';
{$ENDIF}
*)
 afontname:=pdffont.GetFontFamily;
{$IFDEF LINUX}
 if (Length(afontname)=0) then
  afontname:='Helvetica';
{$ENDIF}
 if (pdffont.bold and not pdffont.italic) then
 begin
  stylestring:=' bold ';
 end
 else
  if (pdffont.bold and pdffont.italic) then
  begin
   stylestring:=' bold italic ';
  end
  else
  if (pdffont.italic and not pdffont.bold) then
  begin
   stylestring:=' italic ';
  end
  else
   stylestring:=' regular ';
// WriteToStdError('Ask for font family: '+ afontName+ ' style: ' + stylestring+ chr(10));
 if ((currentname=afontname) and (currentstyle=pdffont.GetPDFStyleKey)) then
  exit;
 currentname:=afontname;
 currentstyle:=pdffont.GetPDFStyleKey;
 // Selects de font by font matching
 // First exact coincidence of family and style
 isbold:=(pdffont.bold);
 isitalic:=(pdffont.Italic);
 match:=false;
 i:=0;
 while i<fontlist.Count do
 begin
  currentFontName:=fontlist.strings[i];
  if isSameFont(currentFontName,afontname) then
  begin
   afont:=TRpLogFont(fontlist.Objects[i]);
   if isitalic=afont.italic then
    if isbold=afont.bold then
    begin
     match:=true;
     currentfont:=afont;
     //WriteToStdError('Step 1: SameFont: FamilyName: '+fontlist.strings[i]+chr(10));
     break;
    end;
  end;
  inc(i);
 end;
 if match then
  exit;
 i:=0;
 while i<fontlist.Count do
 begin
  currentFontName:=fontlist.strings[i];
  if isSameFont2(currentFontName,afontname) then
  begin
   afont:=TRpLogFont(fontlist.Objects[i]);
   if isitalic=afont.italic then
    if isbold=afont.bold then
    begin
     match:=true;
     currentfont:=afont;
//     WriteToStdError('Step 2: SameFont: FamilyName: '+fontlist.strings[i]+chr(10));
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
   afont:=TRpLogFont(fontlist.Objects[i]);
   if isitalic=afont.italic then
    if isbold=afont.bold then
    begin
     match:=true;
     currentfont:=afont;
//     WriteToStdError('Step 3: SimilarFont: FamilyName: '+fontlist.strings[i]+chr(10));
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
  currentFontName:=fontlist.strings[i];
  if currentFontName=afontname then
  begin
   afont:=TRpLogFont(fontlist.Objects[i]);
   match:=true;
   currentfont:=afont;
//   WriteToStdError('Step 4: SameFont ignoring styles: FamilyName: '+fontlist.strings[i]+chr(10));
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
//   WriteToStdError('Step 5: Partial ignoring styles: FamilyName: '+fontlist.strings[i]+chr(10));
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
  begin
   currentfont:=defaultfont_arabic;
//   WriteToStdError('Default arabic regular '+currentfont.familyname+chr(10));
  end
  else
  if ((isbold) and (not isitalic)) then
  begin
   currentfont:=defaultfontb_arabic;
//   WriteToStdError('Default arabic bold '+currentfont.familyname+chr(10));
  end
  else
  if ((not isbold) and (isitalic)) then
  begin
   currentfont:=defaultfontit_arabic;
   //WriteToStdError('Default arabic italic '+currentfont.familyname+chr(10));
  end
  else
  begin
   currentfont:=defaultfontbit_arabic;
//   WriteToStdError('Default arabic italic bold '+currentfont.familyname+chr(10));
  end;
 end;
 if (currentfont <> nil) then
  exit;
 // Finally gets default font, but applying styles
 if ((not isbold) and (not isitalic)) then
 begin
  currentfont:=defaultfont;
//  WriteToStdError('Default regular '+currentfont.familyname+chr(10));
 end
 else
 if ((isbold) and (not isitalic)) then
 begin
  currentfont:=defaultfontb;
//  WriteToStdError('Default bold '+currentfont.familyname+chr(10));
 end
 else
 if ((not isbold) and (isitalic)) then
 begin
  currentfont:=defaultfontit;
//  WriteToStdError('Default italic '+currentfont.familyname+chr(10));
 end
 else
 begin
  currentfont:=defaultfontbit;
//  WriteToStdError('Default bold italic '+currentfont.familyname+chr(10));
 end;

 if not assigned(currentfont) then
  Raise Exception.Create('No active font');
end;


function FontHasCFF2OrFVAR(face: THBFace): Boolean;
var
  i: Cardinal;
  tableCount: Cardinal;
  tags: array of Cardinal;

  function TAG(a, b, c, d: Char): Cardinal;
  begin
    Result := (Ord(a) shl 24) or (Ord(b) shl 16) or (Ord(c) shl 8) or Ord(d);
  end;
var
  cff2tag, fvartag: Cardinal;
begin
  Result := False;
  cff2tag := TAG('C','F','F','2');
  fvartag := TAG('f','v','a','r');
  setLength(tags,1000);
  tableCount:=1000;
  hb_face_get_table_tags(face, 0, tableCount, @tags[0]);
  if tableCount = 0 then Exit(False);



  // Paso 4: buscar CFF2 o fvar
  for i := 0 to tableCount - 1 do
    if (tags[i] = cff2tag) or (tags[i] = fvartag) then
      Exit(True);
end;

function TRpFtInfoProvider.GetFontStream(data: TRpTTFontData): TMemoryStream;
begin
{$IFDEF LINUX_USEHARFBUZZ_SUBSETFONT}
 if HarfBuzzSubSetImplementation then
 begin
  Result:=GetFontStreamHarfBuzz(data);
 end
 else
 begin
  result:=GetFontStreamNative(data);
 end
{$ELSE}
  result:=GetFontStreamNative(data);
{$ENDIF}
end;

function TRpFtInfoProvider.GetFontStreamHarfBuzz(data: TRpTTFontData): TMemoryStream;
var
  face, newFace: THBFace;
  blob: Phb_blob_t;
  subsetInput: Phb_subset_input_t;
  glyphsSet: Phb_set_t;
  glyphInfo: TGlyphInfo;
  outBlob: Phb_blob_t;
  outData: PByte;
  outSize: Cardinal;
  isVariable: boolean;
  HasCCF2: boolean;
begin

  HasCCF2 := False;

  // --- Crear blob desde la fuente ---
  blob := hb_blob_create(@data.FontData.FontData.Memory^, data.FontData.FontData.Size,
                         hbmmReadonly, nil, nil);
  if blob = nil then
    raise Exception.Create('No se pudo crear el blob de la fuente');

  try
    // --- Crear face ---
    subsetInput := hb_subset_input_create_or_fail;
    if subsetInput = nil then
      raise Exception.Create('No se pudo crear el input de subsetting');
    face := hb_face_create(blob, data.FontIndex);
    // --- Crear input de subsetting ---
     try
     isVariable := FontHasCFF2OrFVAR(face);
     if  (isVariable or HasCCF2) then
     begin
      //Result := TMemoryStream.Create;
      //Result.SetSize(data.FontData.FontData.Size);
      //Move(data.FontData.Fontdata.Memory^, Result.Memory^, data.FontData.FontData.Size);
      //Result.Position := 0;
      Result:=GetFontStreamNative(data);
     end
     else
     begin
       hb_subset_input_set_flags(subsetInput, HB_SUBSET_FLAGS_RETAIN_GIDS);

       // --- Obtener set de glifos y añadirlos ---
       glyphsSet := hb_subset_input_glyph_set(subsetInput);
       for glyphInfo in data.glyphsInfo.Values do
         hb_set_add(glyphsSet, glyphInfo.Glyph);

       // --- Crear fuente subset ---
       newFace := hb_subset_or_fail(face, subsetInput);
       try
         // --- Obtener puntero a los datos de la fuente subset ---
         // hb_face_reference_blob devuelve el BLOB, no los bytes: lo que se copiaba antes
         // era la estructura interna de harfbuzz, del tamaño correcto y con basura dentro,
         // asi que toda fuente incrustada por este camino salia invalida. Ademas se pedia
         // la referencia dos veces y no se soltaba ninguna.
         outBlob := hb_face_reference_blob(newFace);
         try
           outData := hb_blob_get_data(outBlob, outSize);
           Result := TMemoryStream.Create;
           if (Assigned(outData) and (outSize > 0)) then
           begin
             Result.SetSize(LongInt(outSize));
             Move(outData^, Result.Memory^, outSize);
           end;
           Result.Position := 0;
         finally
           hb_blob_destroy(outBlob);
         end;

       finally
         hb_face_destroy(newFace);
       end;
      end;
    finally
      hb_subset_input_destroy(subsetInput);
      hb_face_destroy(face);
    end;

  finally
    hb_blob_destroy(blob);
  end;
end;

function  TRpFTInfoProvider.GetFontStreamNative(data: TRpTTFontData): TMemoryStream;
var
 subset:TTrueTypeFontSubSet;
 bytes:TBytes;
 GlyphsUsed: TDictionary<Integer, TArray<Integer>>;
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
     if (not data.type1 and not data.CFF) then
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


procedure TRpFTInfoProvider.FillFontDataInt(data:TRpTTFontData);
var
  os2: TOS2Metrics;
  cf: Double;
  dwAscent, dwDescent, dwLineGap: Integer;
begin
 crit.Enter;
 try
  InitLibrary;
  // See if data can be embedded
  data.fontdata.FontData.Clear;
  data.filename:=currentfont.filename;
  // Que cara del fichero es esta, para el subsetter. Por el camino de fontconfig ya lo ponia
  // SelectFontFontConfigInt; por el de la lista enumerada no lo ponia nadie.
  data.FontIndex:=currentfont.fontIndex;
  //if not currentfont.type1 then
  data.fontdata.FontData.LoadFromFile(currentfont.filename);
  data.postcriptname:=currentfont.postcriptname;
  data.FamilyName:=currentfont.familyname;
  data.FaceName:=currentfont.familyname;
  data.Ascent:=currentfont.ascent;
  data.Descent:=currentfont.descent;
  data.Leading:=currentfont.leading;
  if currentfont.height > 0 then
    data.Height:=currentfont.height
  else
    data.Height:=currentfont.ascent - currentfont.descent + currentfont.leading;

  // Override with OS/2 table metrics to match DirectWrite/GDI
  if data.fontdata.FontData.Size > 0 then
  begin
    ReadOS2Metrics(data.fontdata.FontData, os2);
    if os2.Found then
    begin
      cf := currentfont.convfactor;

      // DirectWrite checks fsSelection bit 7 (USE_TYPO_METRICS):
      //   When set: uses sTypoAscender/sTypoDescender/sTypoLineGap
      //   When not set: Ascent/Descent from usWinAscent/usWinDescent,
      //                 but Height from hhea (already set above)
      if os2.UseTypoMetrics then
      begin
        // USE_TYPO_METRICS: use sTypo* values directly
        dwAscent := os2.sTypoAscender;
        dwDescent := -os2.sTypoDescender; // sTypoDescender is negative
        dwLineGap := os2.sTypoLineGap;
        data.Ascent := Round(cf * dwAscent);
        data.Descent := -Round(cf * dwDescent);
        data.Height := Round(cf * (dwAscent + dwDescent + dwLineGap));
        data.Leading := data.Height - data.Ascent + data.Descent;
      end
      else
      begin
        // Non-USE_TYPO_METRICS:
        //   Ascent/Descent from OS/2 usWinAscent/usWinDescent (matches GDI)
        //   Height from hhea table (already set above)
        data.Ascent := Round(cf * os2.usWinAscent);
        data.Descent := -Round(cf * os2.usWinDescent);
        // data.Height stays as hhea-based (already set above)
        data.Leading := data.Height - data.Ascent + data.Descent;
      end;
    end;
  end;

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
  if currentfont.Bold then
   data.postcriptname:=data.postcriptname+',Bold';
  if currentfont.italic then
    data.Flags:=data.Flags+64;
  if currentfont.Italic then
  begin
   if currentfont.Bold then
    data.postcriptname:=data.postcriptname+'Italic'
   else
     data.postcriptname:=data.postcriptname+',Italic';
  end;
  data.Type1:=currentfont.Type1;
  data.CFF:=currentfont.CFF;
  data.truetype:=currentfont.truetype;
 finally
   crit.Leave;
 end;
end;



procedure TRpFTInfoProvider.FillFontData(pdffont:TRpPDFFont;data:TRpTTFontData;content: string);
begin
 crit.Enter;
 try
  InitLibrary;
 finally
   crit.Leave;
 end;
  // See if data can be embedded
 SelectFont(pdffont, content,false);
 FillFontDataInt(data);
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
  if (data.UnitsPerEM = 0) then
   data.UnitsPerEM := 1000;
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
 filename2:=AnsiString(filename);
 // La cara de esta ficha, no la primera del fichero: en una coleccion pedir la 0 devuelve
 // otra fuente distinta, y de esta cara salen los anchos y el kerning.
 CheckFreeType(FT_New_Face(ftlibrary,PAnsiChar(filename2),fontIndex,ftface));
 faceinit:=true;
 if type1 then
 begin
  // Check for kening file for type1 font
  kerningfile:=ChangeFileExt(filename,'.afm');
  if FileExists(kerningfile) then
  begin
   CheckFreeType(FT_Attach_File(ftface,PAnsichar(AnsiString(kerningfile))));
  end;
 end;
 // Don't need scale, but this is a scale that returns
 // exact width for pdf if you divide the result
 // of Get_Char_Width by 64
 if (scalable) then
   CheckFreeType(FT_Set_Char_Size(ftface,0,64*100,720,720));
end;


initialization
 fontlist:=nil;
 initialized:=false;
 InitializeFontCache;
finalization
 FinalizeFontCache;
 FreeFontList;
 if initialized then
  FT_Done_FreeType(ftlibrary);
end.