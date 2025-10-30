{*******************************************************}
{                                                      }
{       Report Manager                                  }
{                                                       }
{       TRpInfoProvider  Base class                     }
{       Provides information about fonts and bitmaps    }
{                                                       }
{       Copyright (c) 1994-2019 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{                                                       }
{*******************************************************}

unit rpinfoprovid;


interface

{$I rpconf.inc}

uses Classes,SysUtils,
{$IFDEF USEVARIANTS}
 Types,
{$ENDIF}
{$IFNDEF USEVARIANTS}
 Windows,
{$ENDIF}
{$IFDEF USETEXTSHAPING}
 uFreeType,uHarfBuzz,
{$ENDIF}
 rptypes, System.Generics.Collections;

type
 TWinAnsiWidthsArray=array [32..255] of integer;
 PWinAnsiWidthsArray= ^TWinAnsiWidthsArray;

 TRpPDFFont=class(TObject)
  public
   Name:TRpType1Font;
   WFontName:WideString;
   LFontName:WideString;
   fontname:String;
   Size:integer;
   Color:integer;
   Style:Integer;
   Italic:Boolean;
   Underline:boolean;
   Bold:boolean;
   StrikeOut:boolean;
   Transparent:boolean;
   BackColor:Integer;
   constructor Create;
  end;


 TAdvFontData=class(TObject)
  public Fontdata:TMemoryStream;
	public DirectoryOffset: integer;
  constructor Create;
  destructor Destroy;
 end;
  TGlyphInfo=record
   Glyph: Integer;
   Char:char;
   Width: double;
 end;

 TRpTTFontData=class(TObject)
  embedded:Boolean;
  postcriptname:String;
  Encoding:String;
  Ascent,Descent,Leading,CapHeight,Flags,FontWeight:integer;
  MaxWidth:integer;
  AvgWidth:integer;
  StemV:double;
  FontFamily:String;
  FontStretch:String;
  ItalicAngle:double;
  FontBBox:TRect;
  FamilyName:String;
  FullName:String;
  FaceName:String;
  StyleName:String;
  type1:boolean;
  havekerning:Boolean;
  ObjectName:String;
  ObjectIndex:integer;
  ObjectIndexParent:integer;
  DescriptorIndex:Integer;
  ToUnicodeIndex:Integer;
//CIDToGIDMapIndex: Integer;
  loadedkernings:array [0..65535] of TStringList;
  loadedglyphs:array [0..65535] of WideChar;
  loadedg:array [0..65535] of boolean;
  loadedk:array [0..65535] of boolean;
  loadedwidths:array [0..65535] of double;
  loaded:array [0..65535] of boolean;
	glyphs:TDictionary<char, integer>;
	glyphsInfo:TDictionary<integer, TGlyphInfo>;
	widths:TDictionary<char, double>;
  fdata:TObject;
  firstloaded,lastloaded:integer;
  kerningsadded:TStringList;
  IsUnicode:boolean;
  FontData: TAdvFontData;
  filename: string;
  UnitsPerEM: double;
  FontIndex: Integer;
{$IFDEF USETEXTSHAPING}
  LoadedFace:boolean;
  FreeTypeFace: TFTFace;
  HBFont: THBFont;
{$ENDIF}
  constructor Create;
  destructor Destroy;override;
 end;


 TRpInfoProvider=class(TObject)
  procedure FillFontData(pdffont:TRpPDFFont;data:TRpTTFontData);virtual;abstract;
  function GetCharWidth(pdffont:TRpPDFFont;data:TRpTTFontData;charcode:widechar):double;virtual;abstract;
  function GetGlyphWidth(pdffont:TRpPDFFont;data:TRpTTFontData;glyph:Integer;charC: widechar):double;virtual;abstract;
  function GetKerning(pdffont:TRpPDFFont;data:TRpTTFontData;leftchar,rightchar:widechar):integer;virtual;abstract;
  function GetFontStream(data: TRpTTFontData): TMemoryStream;virtual;abstract;
  function GetFullFontStream(data: TRpTTFontData): TMemoryStream;virtual;abstract;
 end;


implementation

constructor TRpTTFontData.Create;
begin
 inherited Create;

 kerningsadded:=TStringList.Create;
 kerningsadded.sorted:=true;
 firstloaded:=65536;
 lastloaded:=-1;
 glyphs:=TDictionary<char, integer>.Create;
 widths:=TDictionary<char, double>.Create;
 glyphsInfo:=TDictionary<integer, TGlyphInfo>.Create;
end;

destructor TRpTTFontData.Destroy;
var
 i:integer;
begin
 for i:=0 to kerningsadded.count-1 do
 begin
  loadedkernings[StrToInt(kerningsadded.Strings[i])].Free;
 end;
 kerningsadded.free;

 if Assigned(fontData) then
 begin
  // fontData.Free;
 end;
 
 inherited;
end;

constructor TrpPdfFont.Create;
begin
 inherited Create;

 Name:=poCourier;
 Size:=10;
end;

constructor TAdvFontData.Create;
begin
 Fontdata:=TMemoryStream.Create;
end;

destructor TAdvFontData.Destroy;
begin
 Fontdata.free;
end;



end.
