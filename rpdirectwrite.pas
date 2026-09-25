{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       DirectWrite COM Interfaces & Types              }
{       Compatibility unit for Free Pascal / Windows    }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpdirectwrite;

{$I rpconf.inc}

{$ALIGN ON}
{$MINENUMSIZE 4}
{$IFDEF FPC}
{$PACKRECORDS C}
{$ENDIF}

{$IFDEF MSWINDOWS}
interface

uses
  Windows, SysUtils;

const
  SID_IDWriteFontFileLoader       = '{727cad4e-d6af-4c9e-8a08-d695b11caa49}';
  SID_IDWriteLocalFontFileLoader  = '{b2d9f3ec-c9fe-4a11-a2ec-d86208f7c0a2}';
  SID_IDWriteFontFileStream       = '{6d4865fe-0ab8-4d91-8f62-5dd6be34a3e0}';
  SID_IDWriteFontFile             = '{739d886a-cef5-47dc-8769-1a8b41bebbb0}';
  SID_IDWriteRenderingParams      = '{2f0da53a-2add-47cd-82ee-d9ec34688e75}';
  SID_IDWriteFontFace             = '{5f49804d-7024-4d43-bfa9-d25984f53849}';
  SID_IDWriteFontCollectionLoader = '{cca920e4-52f0-492b-bfa8-29c72ee0a468}';
  SID_IDWriteFontFileEnumerator   = '{72755049-5ff7-435d-8348-4be97cfa6c7c}';
  SID_IDWriteLocalizedStrings     = '{08256209-099a-4b34-b86d-c22b110e7771}';
  SID_IDWriteFontCollection       = '{a84cee02-3eea-4eee-a827-87c1a02a0fcc}';
  SID_IDWriteFontList             = '{1a0d8438-1d97-4ec1-aef9-a2fb86ed6acb}';
  SID_IDWriteFontFamily           = '{da20d8ef-812a-4c43-9802-62ec4abd7add}';
  SID_IDWriteFont                 = '{acd16696-8c14-4f5d-877e-fe3fc1d32737}';
  SID_IDWriteTextFormat           = '{9c906818-31d7-4fd3-a151-7c5e225db55a}';
  SID_IDWriteTypography           = '{55f1112b-1dc2-4b3c-9541-f46894ed85b6}';
  SID_IDWriteNumberSubstitution   = '{14885CC9-BAB0-4f90-B6ED-5C366A2CD03D}';
  SID_IDWriteTextAnalysisSource   = '{688e1a58-5094-47c8-adc8-fbcea60ae92b}';
  SID_IDWriteTextAnalysisSink     = '{5810cd44-0ca0-4701-b3fa-bec5182ae4f6}';
  SID_IDWriteTextAnalyzer         = '{b7e6163e-7f46-43b4-84b3-e4e6249c365d}';
  SID_IDWriteInlineObject         = '{8339FDE3-106F-47ab-8373-1C6295EB10B3}';
  SID_IDWritePixelSnapping        = '{eaf3a2da-ecf4-4d24-b644-b34f6842024b}';
  SID_IDWriteTextRenderer         = '{ef8a8135-5cc6-45fe-8825-c5a0724eb819}';
  SID_IDWriteTextLayout           = '{53737037-6d14-410b-9bfe-0b182bb70961}';
  SID_IDWriteBitmapRenderTarget   = '{5e5a32a3-8dff-4773-9ff6-0696eab77267}';
  SID_IDWriteGdiInterop           = '{1edd9491-9853-4299-898f-6432983b6f3a}';
  SID_IDWriteGlyphRunAnalysis     = '{7d97dbf7-e085-42d4-81e3-6a883bded118}';
  SID_IDWriteFactory              = '{b859ee5a-d838-4b5b-a2e8-1adc7d93db48}';

  IID_IDWriteFontFileLoader       : TGUID = SID_IDWriteFontFileLoader;
  IID_IDWriteLocalFontFileLoader  : TGUID = SID_IDWriteLocalFontFileLoader;
  IID_IDWriteFontFileStream       : TGUID = SID_IDWriteFontFileStream;
  IID_IDWriteFontFile             : TGUID = SID_IDWriteFontFile;
  IID_IDWriteRenderingParams      : TGUID = SID_IDWriteRenderingParams;
  IID_IDWriteFontFace             : TGUID = SID_IDWriteFontFace;
  IID_IDWriteFontCollectionLoader : TGUID = SID_IDWriteFontCollectionLoader;
  IID_IDWriteFontFileEnumerator   : TGUID = SID_IDWriteFontFileEnumerator;
  IID_IDWriteLocalizedStrings     : TGUID = SID_IDWriteLocalizedStrings;
  IID_IDWriteFontCollection       : TGUID = SID_IDWriteFontCollection;
  IID_IDWriteFontList             : TGUID = SID_IDWriteFontList;
  IID_IDWriteFontFamily           : TGUID = SID_IDWriteFontFamily;
  IID_IDWriteFont                 : TGUID = SID_IDWriteFont;
  IID_IDWriteTextFormat           : TGUID = SID_IDWriteTextFormat;
  IID_IDWriteTypography           : TGUID = SID_IDWriteTypography;
  IID_IDWriteNumberSubstitution   : TGUID = SID_IDWriteNumberSubstitution;
  IID_IDWriteTextAnalysisSource   : TGUID = SID_IDWriteTextAnalysisSource;
  IID_IDWriteTextAnalysisSink     : TGUID = SID_IDWriteTextAnalysisSink;
  IID_IDWriteTextAnalyzer         : TGUID = SID_IDWriteTextAnalyzer;
  IID_IDWriteInlineObject         : TGUID = SID_IDWriteInlineObject;
  IID_IDWritePixelSnapping        : TGUID = SID_IDWritePixelSnapping;
  IID_IDWriteTextRenderer         : TGUID = SID_IDWriteTextRenderer;
  IID_IDWriteTextLayout           : TGUID = SID_IDWriteTextLayout;
  IID_IDWriteBitmapRenderTarget   : TGUID = SID_IDWriteBitmapRenderTarget;
  IID_IDWriteGdiInterop           : TGUID = SID_IDWriteGdiInterop;
  IID_IDWriteGlyphRunAnalysis     : TGUID = SID_IDWriteGlyphRunAnalysis;
  IID_IDWriteFactory              : TGUID = SID_IDWriteFactory;

  DWRITE_FONT_WEIGHT_THIN        = 100;
  DWRITE_FONT_WEIGHT_EXTRA_LIGHT = 200;
  DWRITE_FONT_WEIGHT_ULTRA_LIGHT = 200;
  DWRITE_FONT_WEIGHT_LIGHT       = 300;
  DWRITE_FONT_WEIGHT_SEMI_LIGHT  = 350;
  DWRITE_FONT_WEIGHT_NORMAL      = 400;
  DWRITE_FONT_WEIGHT_REGULAR     = 400;
  DWRITE_FONT_WEIGHT_MEDIUM      = 500;
  DWRITE_FONT_WEIGHT_DEMI_BOLD   = 600;
  DWRITE_FONT_WEIGHT_SEMI_BOLD   = 600;
  DWRITE_FONT_WEIGHT_BOLD        = 700;
  DWRITE_FONT_WEIGHT_EXTRA_BOLD  = 800;
  DWRITE_FONT_WEIGHT_HEAVY       = 900;
  DWRITE_FONT_WEIGHT_EXTRA_BLACK = 950;

  DWRITE_FONT_SIMULATIONS_NONE    = $0000;
  DWRITE_FONT_SIMULATIONS_BOLD    = $0001;
  DWRITE_FONT_SIMULATIONS_OBLIQUE = $0002;

type
  // Enums
  DWRITE_FACTORY_TYPE = (
    DWRITE_FACTORY_TYPE_SHARED,
    DWRITE_FACTORY_TYPE_ISOLATED
  );
  TDWriteFactoryType = DWRITE_FACTORY_TYPE;

  DWRITE_FONT_WEIGHT = type Integer;

  DWRITE_FONT_STYLE = (
    DWRITE_FONT_STYLE_NORMAL,
    DWRITE_FONT_STYLE_OBLIQUE,
    DWRITE_FONT_STYLE_ITALIC
  );
  TDwriteFontStyle = DWRITE_FONT_STYLE;

  DWRITE_FONT_STRETCH = (
    DWRITE_FONT_STRETCH_UNDEFINED = 0,
    DWRITE_FONT_STRETCH_ULTRA_CONDENSED = 1,
    DWRITE_FONT_STRETCH_EXTRA_CONDENSED = 2,
    DWRITE_FONT_STRETCH_CONDENSED = 3,
    DWRITE_FONT_STRETCH_SEMI_CONDENSED = 4,
    DWRITE_FONT_STRETCH_NORMAL = 5,
    DWRITE_FONT_STRETCH_SEMI_EXPANDED = 6,
    DWRITE_FONT_STRETCH_EXPANDED = 7,
    DWRITE_FONT_STRETCH_EXTRA_EXPANDED = 8,
    DWRITE_FONT_STRETCH_ULTRA_EXPANDED = 9
  );
  TDwriteFontStretch = DWRITE_FONT_STRETCH;

const
  DWRITE_FONT_STRETCH_MEDIUM = DWRITE_FONT_STRETCH_NORMAL;

type
  DWRITE_MEASURING_MODE = (
    DWRITE_MEASURING_MODE_NATURAL,
    DWRITE_MEASURING_MODE_GDI_CLASSIC,
    DWRITE_MEASURING_MODE_GDI_NATURAL
  );
  TDWriteMeasuringMode = DWRITE_MEASURING_MODE;

  DWRITE_READING_DIRECTION = (
    DWRITE_READING_DIRECTION_LEFT_TO_RIGHT,
    DWRITE_READING_DIRECTION_RIGHT_TO_LEFT,
    DWRITE_READING_DIRECTION_TOP_TO_BOTTOM,
    DWRITE_READING_DIRECTION_BOTTOM_TO_TOP
  );

  DWRITE_FLOW_DIRECTION = (
    DWRITE_FLOW_DIRECTION_TOP_TO_BOTTOM,
    DWRITE_FLOW_DIRECTION_BOTTOM_TO_TOP,
    DWRITE_FLOW_DIRECTION_LEFT_TO_RIGHT,
    DWRITE_FLOW_DIRECTION_RIGHT_TO_LEFT
  );

  DWRITE_TEXT_ALIGNMENT = (
    DWRITE_TEXT_ALIGNMENT_LEADING,
    DWRITE_TEXT_ALIGNMENT_TRAILING,
    DWRITE_TEXT_ALIGNMENT_CENTER,
    DWRITE_TEXT_ALIGNMENT_JUSTIFIED
  );

  DWRITE_PARAGRAPH_ALIGNMENT = (
    DWRITE_PARAGRAPH_ALIGNMENT_NEAR,
    DWRITE_PARAGRAPH_ALIGNMENT_FAR,
    DWRITE_PARAGRAPH_ALIGNMENT_CENTER
  );

  DWRITE_WORD_WRAPPING = (
    DWRITE_WORD_WRAPPING_WRAP,
    DWRITE_WORD_WRAPPING_NO_WRAP,
    DWRITE_WORD_WRAPPING_EMERGENCY_BREAK,
    DWRITE_WORD_WRAPPING_WHOLE_WORD,
    DWRITE_WORD_WRAPPING_CHARACTER
  );

  DWRITE_LINE_SPACING_METHOD = (
    DWRITE_LINE_SPACING_METHOD_DEFAULT,
    DWRITE_LINE_SPACING_METHOD_UNIFORM,
    DWRITE_LINE_SPACING_METHOD_PROPORTIONAL
  );

  DWRITE_TRIMMING_GRANULARITY = (
    DWRITE_TRIMMING_GRANULARITY_NONE,
    DWRITE_TRIMMING_GRANULARITY_CHARACTER,
    DWRITE_TRIMMING_GRANULARITY_WORD
  );

  DWRITE_BREAK_CONDITION = (
    DWRITE_BREAK_CONDITION_NEUTRAL,
    DWRITE_BREAK_CONDITION_CAN_BREAK,
    DWRITE_BREAK_CONDITION_MAY_NOT_BREAK,
    DWRITE_BREAK_CONDITION_MUST_BREAK
  );

  DWRITE_FONT_FACE_TYPE = (
    DWRITE_FONT_FACE_TYPE_CFF,
    DWRITE_FONT_FACE_TYPE_TRUETYPE,
    DWRITE_FONT_FACE_TYPE_OPENTYPE_COLLECTION,
    DWRITE_FONT_FACE_TYPE_TYPE1,
    DWRITE_FONT_FACE_TYPE_VECTOR,
    DWRITE_FONT_FACE_TYPE_BITMAP,
    DWRITE_FONT_FACE_TYPE_UNKNOWN,
    DWRITE_FONT_FACE_TYPE_RAW_TRUETYPE,
    DWRITE_FONT_FACE_TYPE_TRUETYPE_COLLECTION
  );

  DWRITE_FONT_SIMULATIONS = type Integer;

  // Structs
  DWRITE_FONT_METRICS = record
    designUnitsPerEm: Word;
    ascent: Word;
    descent: Word;
    lineGap: SmallInt;
    capHeight: Word;
    xHeight: Word;
    underlinePosition: SmallInt;
    underlineThickness: Word;
    strikethroughPosition: SmallInt;
    strikethroughThickness: Word;
  end;
  TDwriteFontMetrics = DWRITE_FONT_METRICS;
  PDwriteFontMetrics = ^TDwriteFontMetrics;

  DWRITE_GLYPH_OFFSET = record
    advanceOffset: Single;
    ascenderOffset: Single;
  end;
  TDwriteGlyphOffset = DWRITE_GLYPH_OFFSET;
  PDwriteGlyphOffset = ^TDwriteGlyphOffset;
  PDWRITE_GLYPH_OFFSET = ^DWRITE_GLYPH_OFFSET;

  DWRITE_MATRIX = record
    m11: Single;
    m12: Single;
    m21: Single;
    m22: Single;
    dx: Single;
    dy: Single;
  end;
  TDwriteMatrix = DWRITE_MATRIX;
  PDwriteMatrix = ^TDwriteMatrix;

  DWRITE_TEXT_RANGE = record
    startPosition: Cardinal;
    length: Cardinal;
  end;
  TDwriteTextRange = DWRITE_TEXT_RANGE;
  PDwriteTextRange = ^TDwriteTextRange;

  DWRITE_LINE_METRICS = record
    length: Cardinal;
    trailingWhitespaceLength: Cardinal;
    newlineLength: Cardinal;
    height: Single;
    baseline: Single;
    isTrimmed: BOOL;
  end;
  TDwriteLineMetrics = DWRITE_LINE_METRICS;
  PDwriteLineMetrics = ^TDwriteLineMetrics;

  DWRITE_TEXT_METRICS = record
    left: Single;
    top: Single;
    width: Single;
    widthIncludingTrailingWhitespace: Single;
    height: Single;
    layoutWidth: Single;
    layoutHeight: Single;
    maxBidiReorderingDepth: Cardinal;
    lineCount: Cardinal;
  end;
  TDwriteTextMetrics = DWRITE_TEXT_METRICS;
  PDwriteTextMetrics = ^TDwriteTextMetrics;

  DWRITE_OVERHANG_METRICS = record
    left: Single;
    top: Single;
    right: Single;
    bottom: Single;
  end;
  TDwriteOverhangMetrics = DWRITE_OVERHANG_METRICS;
  PDwriteOverhangMetrics = ^TDwriteOverhangMetrics;

  DWRITE_HIT_TEST_METRICS = record
    textPosition: Cardinal;
    length: Cardinal;
    left: Single;
    top: Single;
    width: Single;
    height: Single;
    bidiLevel: Cardinal;
    isText: BOOL;
    isTrimmed: BOOL;
  end;
  TDwriteHitTestMetrics = DWRITE_HIT_TEST_METRICS;
  PDwriteHitTestMetrics = ^TDwriteHitTestMetrics;

  DWRITE_INLINE_OBJECT_METRICS = record
    width: Single;
    height: Single;
    baseline: Single;
    supportsSideways: BOOL;
  end;
  TDwriteInlineObjectMetrics = DWRITE_INLINE_OBJECT_METRICS;

  DWRITE_TRIMMING = record
    granularity: DWRITE_TRIMMING_GRANULARITY;
    delimiter: Cardinal;
    delimiterCount: Cardinal;
  end;
  TDwriteTrimming = DWRITE_TRIMMING;

  DWRITE_GLYPH_METRICS = record
    leftSideBearing: Integer;
    advanceWidth: Cardinal;
    rightSideBearing: Integer;
    topSideBearing: Integer;
    advanceHeight: Cardinal;
    bottomSideBearing: Integer;
    verticalOriginY: Integer;
  end;
  PDwriteGlyphMetrics = ^DWRITE_GLYPH_METRICS;

  // Forward declarations of interfaces in the same type block
  IDWriteFontFileStream = interface;
  IDWriteFontFileLoader = interface;
  IDWriteFontFile = interface;
  IDWriteFontFace = interface;
  IDWriteFont = interface;
  IDWriteFontList = interface;
  IDWriteFontFamily = interface;
  IDWriteFontCollection = interface;
  IDWriteLocalizedStrings = interface;
  IDWriteRenderingParams = interface;
  IDWriteTextFormat = interface;
  IDWriteTypography = interface;
  IDWriteInlineObject = interface;
  IDWritePixelSnapping = interface;
  IDWriteTextRenderer = interface;
  IDWriteTextLayout = interface;
  IDWriteFactory = interface;

  PIDWriteFontFile = ^IDWriteFontFile;

  DWRITE_GLYPH_RUN = record
    fontFace: IDWriteFontFace;
    fontEmSize: Single;
    glyphCount: Cardinal;
    glyphIndices: PWord;
    glyphAdvances: PSingle;
    glyphOffsets: PDwriteGlyphOffset;
    isSideways: BOOL;
    bidiLevel: Cardinal;
  end;
  TDwriteGlyphRun = DWRITE_GLYPH_RUN;
  PDwriteGlyphRun = ^TDwriteGlyphRun;

  DWRITE_GLYPH_RUN_DESCRIPTION = record
    localeName: PWCHAR;
    _string: PWCHAR;
    stringLength: Cardinal;
    clusterMap: PWord;
    textPosition: Cardinal;
  end;
  TDwriteGlyphRunDescription = DWRITE_GLYPH_RUN_DESCRIPTION;
  PDwriteGlyphRunDescription = ^TDwriteGlyphRunDescription;

  DWRITE_UNDERLINE = record
    width: Single;
    thickness: Single;
    offset: Single;
    runHeight: Single;
    readingDirection: DWRITE_READING_DIRECTION;
    flowDirection: DWRITE_FLOW_DIRECTION;
    localeName: PWCHAR;
    measuringMode: DWRITE_MEASURING_MODE;
  end;
  TDwriteUnderline = DWRITE_UNDERLINE;
  PDwriteUnderline = ^TDwriteUnderline;

  DWRITE_STRIKETHROUGH = record
    width: Single;
    thickness: Single;
    offset: Single;
    readingDirection: DWRITE_READING_DIRECTION;
    flowDirection: DWRITE_FLOW_DIRECTION;
    localeName: PWCHAR;
    measuringMode: DWRITE_MEASURING_MODE;
  end;
  TDwriteStrikethrough = DWRITE_STRIKETHROUGH;
  PDwriteStrikethrough = ^TDwriteStrikethrough;

  // COM Interfaces
  IDWriteFontFileStream = interface(IUnknown)
    [SID_IDWriteFontFileStream]
    function ReadFileFragment(var fragmentStart: Pointer; fileOffset: UInt64;
      fragmentSize: UInt64; out fragmentContext: Pointer): HResult; stdcall;
    procedure ReleaseFileFragment(fragmentContext: Pointer); stdcall;
    function GetFileSize(out fileSize: UInt64): HResult; stdcall;
    function GetLastWriteTime(out lastWriteTime: UInt64): HResult; stdcall;
  end;

  IDWriteFontFileLoader = interface(IUnknown)
    [SID_IDWriteFontFileLoader]
    function CreateStreamFromKey(fontFileReferenceKey: Pointer;
      fontFileReferenceKeySize: Cardinal;
      out fontFileStream: IDWriteFontFileStream): HResult; stdcall;
  end;

  IDWriteFontFile = interface(IUnknown)
    [SID_IDWriteFontFile]
    function GetReferenceKey(var fontFileReferenceKey: Pointer;
      out fontFileReferenceKeySize: Cardinal): HResult; stdcall;
    function GetLoader(out fontFileLoader: IDWriteFontFileLoader): HResult; stdcall;
    function Analyze(var isSupportedFontType: BOOL;
      var fontFaceType: DWRITE_FONT_FACE_TYPE;
      var numberOfFaces: Cardinal): HResult; stdcall;
  end;

  IDWriteFontFace = interface(IUnknown)
    [SID_IDWriteFontFace]
    function GetType: DWRITE_FONT_FACE_TYPE; stdcall;
    function GetFiles(var numberOfFiles: Cardinal;
      out fontFiles: IDWriteFontFile): HResult; stdcall;
    function GetIndex: Cardinal; stdcall;
    function GetSimulations: DWRITE_FONT_SIMULATIONS; stdcall;
    function IsSymbolFont: BOOL; stdcall;
    procedure GetMetrics(var fontFaceMetrics: TDwriteFontMetrics); stdcall;
    function GetGlyphCount: Word; stdcall;
    function GetDesignGlyphMetrics(glyphIndices: PWord; glyphCount: Cardinal;
      glyphMetrics: PDwriteGlyphMetrics; isSideways: BOOL = False): HResult; stdcall;
    function GetGlyphIndices(var codePoints: Cardinal; codePointCount: Cardinal;
      var glyphIndices: Word): HResult; stdcall;
    function TryGetFontTable(openTypeTableTag: Cardinal; var tableData: Pointer;
      var tableSize: Cardinal; var tableContext: Pointer;
      var exists: BOOL): HResult; stdcall;
    procedure ReleaseFontTable(tableContext: Pointer); stdcall;
    function GetGlyphRunOutline(emSize: Single; const glyphIndices: PWord;
      const glyphAdvances: PSingle; const glyphOffsets: PDwriteGlyphOffset;
      glyphCount: Cardinal; isSideways: BOOL; isRightToLeft: BOOL;
      geometrySink: IUnknown): HResult; stdcall;
    function GetRecommendedRenderingMode(emSize: Single; pixelsPerDip: Single;
      measuringMode: TDWriteMeasuringMode;
      renderingParams: IDWriteRenderingParams;
      out renderingMode: Cardinal): HResult; stdcall;
    function GetGdiCompatibleMetrics(emSize: Single; pixelsPerDip: Single;
      transform: PDwriteMatrix;
      var fontFaceMetrics: TDwriteFontMetrics): HResult; stdcall;
    function GetGdiCompatibleGlyphMetrics(emSize: Single; pixelsPerDip: Single;
      transform: PDwriteMatrix; useGdiNatural: BOOL;
      const glyphIndices: PWord; glyphCount: Cardinal;
      glyphMetrics: PDwriteGlyphMetrics; isSideways: BOOL = False): HResult; stdcall;
  end;

  IDWriteLocalizedStrings = interface(IUnknown)
    [SID_IDWriteLocalizedStrings]
    function GetCount: Cardinal; stdcall;
    function FindLocaleName(localeName: PWCHAR; var index: Cardinal;
      var exists: BOOL): HResult; stdcall;
    function GetLocaleNameLength(index: Cardinal;
      out length: Cardinal): HResult; stdcall;
    function GetLocaleName(index: Cardinal; localeName: PWCHAR;
      size: Cardinal): HResult; stdcall;
    function GetStringLength(index: Cardinal;
      out length: Cardinal): HResult; stdcall;
    function GetString(index: Cardinal; stringBuffer: PWCHAR;
      size: Cardinal): HResult; stdcall;
  end;

  IDWriteFont = interface(IUnknown)
    [SID_IDWriteFont]
    function GetFontFamily(out fontFamily: IDWriteFontFamily): HResult; stdcall;
    function GetWeight: DWRITE_FONT_WEIGHT; stdcall;
    function GetStretch: DWRITE_FONT_STRETCH; stdcall;
    function GetStyle: DWRITE_FONT_STYLE; stdcall;
    function IsSymbolFont: BOOL; stdcall;
    function GetFaceNames(out names: IDWriteLocalizedStrings): HResult; stdcall;
    function GetInformationalStrings(informationalStringID: Cardinal;
      out informationalStrings: IDWriteLocalizedStrings;
      var exists: BOOL): HResult; stdcall;
    function GetSimulations: DWRITE_FONT_SIMULATIONS; stdcall;
    procedure GetMetrics(var fontMetrics: TDwriteFontMetrics); stdcall;
    function HasCharacter(unicodeValue: Cardinal;
      out exists: BOOL): HResult; stdcall;
    function CreateFontFace(out fontFace: IDWriteFontFace): HResult; stdcall;
  end;

  IDWriteFontList = interface(IUnknown)
    [SID_IDWriteFontList]
    function GetFontCollection(out fontCollection: IDWriteFontCollection): HResult; stdcall;
    function GetFontCount: Cardinal; stdcall;
    function GetFont(index: Cardinal; out font: IDWriteFont): HResult; stdcall;
  end;

  IDWriteFontFamily = interface(IDWriteFontList)
    [SID_IDWriteFontFamily]
    function GetFamilyNames(out names: IDWriteLocalizedStrings): HResult; stdcall;
    function GetFirstMatchingFont(weight: DWRITE_FONT_WEIGHT;
      stretch: DWRITE_FONT_STRETCH; style: DWRITE_FONT_STYLE;
      out matchingFont: IDWriteFont): HResult; stdcall;
    function GetMatchingFonts(weight: DWRITE_FONT_WEIGHT;
      stretch: DWRITE_FONT_STRETCH; style: DWRITE_FONT_STYLE;
      out matchingFonts: IDWriteFontList): HResult; stdcall;
  end;

  IDWriteFontCollection = interface(IUnknown)
    [SID_IDWriteFontCollection]
    function GetFontFamilyCount: Cardinal; stdcall;
    function GetFontFamily(index: Cardinal;
      out fontFamily: IDWriteFontFamily): HResult; stdcall;
    function FindFamilyName(familyName: PWCHAR; var index: Cardinal;
      var exists: BOOL): HResult; stdcall;
    function GetFontFromFontFace(var fontFace: IDWriteFontFace;
      out font: IDWriteFont): HResult; stdcall;
  end;

  IDWriteRenderingParams = interface(IUnknown)
    [SID_IDWriteRenderingParams]
    function GetGamma: Single; stdcall;
    function GetEnhancedContrast: Single; stdcall;
    function GetClearTypeLevel: Single; stdcall;
    function GetPixelGeometry: Cardinal; stdcall;
    function GetRenderingMode: Cardinal; stdcall;
  end;

  IDWriteInlineObject = interface(IUnknown)
    [SID_IDWriteInlineObject]
    function Draw(clientDrawingContext: Pointer; const renderer: IDWriteTextRenderer;
      originX: Single; originY: Single; isSideways: BOOL; isRightToLeft: BOOL;
      const clientDrawingEffect: IUnknown): HResult; stdcall;
    function GetMetrics(var metrics: TDwriteInlineObjectMetrics): HResult; stdcall;
    function GetOverhangMetrics(var overhangs: TDwriteOverhangMetrics): HResult; stdcall;
    function GetBreakConditions(var breakConditionBefore: DWRITE_BREAK_CONDITION;
      var breakConditionAfter: DWRITE_BREAK_CONDITION): HResult; stdcall;
  end;

  IDWritePixelSnapping = interface(IUnknown)
    [SID_IDWritePixelSnapping]
    function IsPixelSnappingDisabled(clientDrawingContext: Pointer;
      var isDisabled: BOOL): HResult; stdcall;
    function GetCurrentTransform(clientDrawingContext: Pointer;
      var transform: TDwriteMatrix): HResult; stdcall;
    function GetPixelsPerDip(clientDrawingContext: Pointer;
      var pixelsPerDip: Single): HResult; stdcall;
  end;

  IDWriteTextRenderer = interface(IDWritePixelSnapping)
    [SID_IDWriteTextRenderer]
    function DrawGlyphRun(clientDrawingContext: Pointer; baselineOriginX: Single;
      baselineOriginY: Single; measuringMode: TDWriteMeasuringMode;
      var glyphRun: TDwriteGlyphRun;
      var glyphRunDescription: TDwriteGlyphRunDescription;
      const clientDrawingEffect: IUnknown): HResult; stdcall;
    function DrawUnderline(clientDrawingContext: Pointer; baselineOriginX: Single;
      baselineOriginY: Single; var underline: TDwriteUnderline;
      const clientDrawingEffect: IUnknown): HResult; stdcall;
    function DrawStrikethrough(clientDrawingContext: Pointer;
      baselineOriginX: Single; baselineOriginY: Single;
      var strikethrough: TDwriteStrikethrough;
      const clientDrawingEffect: IUnknown): HResult; stdcall;
    function DrawInlineObject(clientDrawingContext: Pointer; originX: Single;
      originY: Single; const inlineObject: IDWriteInlineObject; isSideways: BOOL;
      isRightToLeft: BOOL; const clientDrawingEffect: IUnknown): HResult; stdcall;
  end;

  IDWriteTextFormat = interface(IUnknown)
    [SID_IDWriteTextFormat]
    function SetTextAlignment(textAlignment: DWRITE_TEXT_ALIGNMENT): HResult; stdcall;
    function SetParagraphAlignment(paragraphAlignment: DWRITE_PARAGRAPH_ALIGNMENT): HResult; stdcall;
    function SetWordWrapping(wordWrapping: DWRITE_WORD_WRAPPING): HResult; stdcall;
    function SetReadingDirection(readingDirection: DWRITE_READING_DIRECTION): HResult; stdcall;
    function SetFlowDirection(flowDirection: DWRITE_FLOW_DIRECTION): HResult; stdcall;
    function SetIncrementalTabStop(incrementalTabStop: Single): HResult; stdcall;
    function SetTrimming(var trimmingOptions: TDwriteTrimming;
      trimmingSign: IDWriteInlineObject): HResult; stdcall;
    function SetLineSpacing(lineSpacingMethod: DWRITE_LINE_SPACING_METHOD;
      lineSpacing: Single; baseline: Single): HResult; stdcall;
    function GetTextAlignment: DWRITE_TEXT_ALIGNMENT; stdcall;
    function GetParagraphAlignment: DWRITE_PARAGRAPH_ALIGNMENT; stdcall;
    function GetWordWrapping: DWRITE_WORD_WRAPPING; stdcall;
    function GetReadingDirection: DWRITE_READING_DIRECTION; stdcall;
    function GetFlowDirection: DWRITE_FLOW_DIRECTION; stdcall;
    function GetIncrementalTabStop: Single; stdcall;
    function GetTrimming(var trimmingOptions: TDwriteTrimming;
      out trimmingSign: IDWriteInlineObject): HResult; stdcall;
    function GetLineSpacing(var lineSpacingMethod: DWRITE_LINE_SPACING_METHOD;
      var lineSpacing: Single; var baseline: Single): HResult; stdcall;
    function GetFontCollection(out fontCollection: IDWriteFontCollection): HResult; stdcall;
    function GetFontFamilyNameLength: Cardinal; stdcall;
    function GetFontFamilyName(fontFamilyName: PWCHAR; nameSize: Cardinal): HResult; stdcall;
    function GetFontWeight: DWRITE_FONT_WEIGHT; stdcall;
    function GetFontStyle: DWRITE_FONT_STYLE; stdcall;
    function GetFontStretch: DWRITE_FONT_STRETCH; stdcall;
    function GetFontSize: Single; stdcall;
    function GetLocaleNameLength: Cardinal; stdcall;
    function GetLocaleName(localeName: PWCHAR; nameSize: Cardinal): HResult; stdcall;
  end;

  IDWriteTypography = interface(IUnknown)
    [SID_IDWriteTypography]
  end;

  IDWriteTextLayout = interface(IDWriteTextFormat)
    [SID_IDWriteTextLayout]
    function SetMaxWidth(maxWidth: Single): HResult; stdcall;
    function SetMaxHeight(maxHeight: Single): HResult; stdcall;
    function SetFontCollection(const fontCollection: IDWriteFontCollection;
      textRange: TDwriteTextRange): HResult; stdcall;
    function SetFontFamilyName(fontFamilyName: PWCHAR;
      textRange: TDwriteTextRange): HResult; stdcall;
    function SetFontWeight(fontWeight: DWRITE_FONT_WEIGHT;
      textRange: TDwriteTextRange): HResult; stdcall;
    function SetFontStyle(fontStyle: DWRITE_FONT_STYLE;
      textRange: TDwriteTextRange): HResult; stdcall;
    function SetFontStretch(fontStretch: DWRITE_FONT_STRETCH;
      textRange: TDwriteTextRange): HResult; stdcall;
    function SetFontSize(fontSize: Single;
      textRange: TDwriteTextRange): HResult; stdcall;
    function SetUnderline(hasUnderline: BOOL;
      textRange: TDwriteTextRange): HResult; stdcall;
    function SetStrikethrough(hasStrikethrough: BOOL;
      textRange: TDwriteTextRange): HResult; stdcall;
    function SetDrawingEffect(const drawingEffect: IUnknown;
      textRange: TDwriteTextRange): HResult; stdcall;
    function SetInlineObject(const inlineObject: IDWriteInlineObject;
      textRange: TDwriteTextRange): HResult; stdcall;
    function SetTypography(const typography: IDWriteTypography;
      textRange: TDwriteTextRange): HResult; stdcall;
    function SetLocaleName(localeName: PWCHAR;
      textRange: TDwriteTextRange): HResult; stdcall;
    function GetMaxWidth: Single; stdcall;
    function GetMaxHeight: Single; stdcall;
    function GetFontCollection(currentPosition: Cardinal;
      out fontCollection: IDWriteFontCollection;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetFontFamilyNameLength(currentPosition: Cardinal;
      var nameLength: Cardinal;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetFontFamilyName(currentPosition: Cardinal; fontFamilyName: PWCHAR;
      nameSize: Cardinal; var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetFontWeight(currentPosition: Cardinal;
      var fontWeight: DWRITE_FONT_WEIGHT;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetFontStyle(currentPosition: Cardinal;
      var fontStyle: DWRITE_FONT_STYLE;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetFontStretch(currentPosition: Cardinal;
      var fontStretch: DWRITE_FONT_STRETCH;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetFontSize(currentPosition: Cardinal; var fontSize: Single;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetUnderline(currentPosition: Cardinal; var hasUnderline: BOOL;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetStrikethrough(currentPosition: Cardinal; var hasStrikethrough: BOOL;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetDrawingEffect(currentPosition: Cardinal;
      out drawingEffect: IUnknown;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetInlineObject(currentPosition: Cardinal;
      out inlineObject: IDWriteInlineObject;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetTypography(currentPosition: Cardinal;
      out typography: IDWriteTypography;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetLocaleNameLength(currentPosition: Cardinal;
      var nameLength: Cardinal;
      var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function GetLocaleName(currentPosition: Cardinal; localeName: PWCHAR;
      nameSize: Cardinal; var textRange: DWRITE_TEXT_RANGE): HResult; stdcall;
    function Draw(clientDrawingContext: Pointer; renderer: IDWriteTextRenderer;
      originX: Single; originY: Single): HResult; stdcall;
    function GetLineMetrics(lineMetrics: PDwriteLineMetrics;
      maxLineCount: Cardinal; var actualLineCount: Cardinal): HResult; stdcall;
    function GetMetrics(var textMetrics: TDwriteTextMetrics): HResult; stdcall;
    function GetOverhangMetrics(var overhangs: TDwriteOverhangMetrics): HResult; stdcall;
    function GetClusterMetrics(clusterMetrics: Pointer;
      maxClusterCount: Cardinal; var actualClusterCount: Cardinal): HResult; stdcall;
    function DetermineMinWidth(out minWidth: Single): HResult; stdcall;
    function HitTestPoint(pointX: Single; pointY: Single;
      var isTrailingHit: BOOL; var isInside: BOOL;
      var hitTestMetrics: TDwriteHitTestMetrics): HResult; stdcall;
    function HitTestTextPosition(textPosition: Cardinal; isTrailingHit: BOOL;
      out pointX: Single; out pointY: Single;
      var hitTestMetrics: TDwriteHitTestMetrics): HResult; stdcall;
    function HitTestTextRange(textPosition: Cardinal; textLength: Cardinal;
      originX: Single; originY: Single; hitTestMetrics: PDwriteHitTestMetrics;
      maxHitTestMetricsCount: Cardinal;
      out actualHitTestMetricsCount: Cardinal): HResult; stdcall;
  end;

  IDWriteFactory = interface(IUnknown)
    [SID_IDWriteFactory]
    function GetSystemFontCollection(out fontCollection: IDWriteFontCollection;
      checkForUpdates: BOOL = False): HResult; stdcall;
    function CreateCustomFontCollection(
      const collectionLoader: IUnknown; collectionKey: Pointer;
      collectionKeySize: Cardinal;
      out fontCollection: IDWriteFontCollection): HResult; stdcall;
    function RegisterFontCollectionLoader(
      const fontCollectionLoader: IUnknown): HResult; stdcall;
    function UnregisterFontCollectionLoader(
      const fontCollectionLoader: IUnknown): HResult; stdcall;
    function CreateFontFileReference(const filePath: PWCHAR;
      lpLastWriteTime: Pointer;
      out fontFile: IDWriteFontFile): HResult; stdcall;
    function CreateCustomFontFileReference(fontFileReferenceKey: Pointer;
      fontFileReferenceKeySize: Cardinal; const fontFileLoader: IDWriteFontFileLoader;
      out fontFile: IDWriteFontFile): HResult; stdcall;
    function CreateFontFace(fontFaceType: DWRITE_FONT_FACE_TYPE;
      numberOfFiles: Cardinal; fontFiles: PIDWriteFontFile;
      faceIndex: Cardinal; fontFaceSimulationFlags: DWRITE_FONT_SIMULATIONS;
      out fontFace: IDWriteFontFace): HResult; stdcall;
    function CreateRenderingParams(
      out renderingParams: IDWriteRenderingParams): HResult; stdcall;
    function CreateMonitorRenderingParams(monitor: HMONITOR;
      out renderingParams: IDWriteRenderingParams): HResult; stdcall;
    function CreateCustomRenderingParams(gamma: Single; enhancedContrast: Single;
      clearTypeLevel: Single; pixelGeometry: Cardinal;
      renderingMode: Cardinal;
      out renderingParams: IDWriteRenderingParams): HResult; stdcall;
    function RegisterFontFileLoader(
      const fontFileLoader: IDWriteFontFileLoader): HResult; stdcall;
    function UnregisterFontFileLoader(
      const fontFileLoader: IDWriteFontFileLoader): HResult; stdcall;
    function CreateTextFormat(const fontFamilyName: PWideChar;
      const fontCollection: IDWriteFontCollection; fontWeight: DWRITE_FONT_WEIGHT;
      fontStyle: DWRITE_FONT_STYLE; fontStretch: DWRITE_FONT_STRETCH;
      fontSize: Single; const localeName: PWideChar;
      out textFormat: IDWriteTextFormat): HResult; stdcall;
    function CreateTypography(out typography: IDWriteTypography): HResult; stdcall;
    function GetGdiInterop(out gdiInterop: IUnknown): HResult; stdcall;
    function CreateTextLayout(_string: PWCHAR; stringLength: Cardinal;
      const textFormat: IDWriteTextFormat; maxWidth: Single; maxHeight: Single;
      out textLayout: IDWriteTextLayout): HResult; stdcall;
    function CreateGdiCompatibleTextLayout(_string: PWCHAR; stringLength: Cardinal;
      const textFormat: IDWriteTextFormat; layoutWidth: Single; layoutHeight: Single;
      pixelsPerDip: Single; transform: PDwriteMatrix; useGdiNatural: BOOL;
      out textLayout: IDWriteTextLayout): HResult; stdcall;
    function CreateEllipsisTrimmingSign(const textFormat: IDWriteTextFormat;
      out trimmingSign: IDWriteInlineObject): HResult; stdcall;
    function CreateTextAnalyzer(out textAnalyzer: IUnknown): HResult; stdcall;
    function CreateNumberSubstitution(substitutionMethod: Cardinal;
      localeName: PWCHAR; ignoreUserOverride: BOOL;
      out numberSubstitution: IUnknown): HResult; stdcall;
    function CreateGlyphRunAnalysis(const glyphRun: TDwriteGlyphRun;
      pixelsPerDip: Single; transform: PDwriteMatrix;
      renderingMode: Cardinal; measuringMode: TDWriteMeasuringMode;
      baselineOriginX: Single; baselineOriginY: Single;
      out glyphRunAnalysis: IUnknown): HResult; stdcall;
  end;

function DWriteCreateFactory(factoryType: DWRITE_FACTORY_TYPE; const iid: TGUID;
  out factory: IUnknown): HRESULT; stdcall;

implementation

type
  TDWriteCreateFactoryFunc = function(factoryType: DWRITE_FACTORY_TYPE;
    const iid: TGUID; out factory: IUnknown): HRESULT; stdcall;

var
  hDWriteDll: HMODULE = 0;
  _DWriteCreateFactory: TDWriteCreateFactoryFunc = nil;
  DWriteInitialized: Boolean = False;

procedure InitDWrite;
begin
  if not DWriteInitialized then
  begin
    hDWriteDll := LoadLibrary('dwrite.dll');
    if hDWriteDll <> 0 then
      _DWriteCreateFactory := TDWriteCreateFactoryFunc(GetProcAddress(hDWriteDll, 'DWriteCreateFactory'));
    DWriteInitialized := True;
  end;
end;

function DWriteCreateFactory(factoryType: DWRITE_FACTORY_TYPE; const iid: TGUID;
  out factory: IUnknown): HRESULT;
begin
  if not DWriteInitialized then
    InitDWrite;
  if Assigned(_DWriteCreateFactory) then
    Result := _DWriteCreateFactory(factoryType, iid, factory)
  else
    Result := HRESULT(E_NOTIMPL);
end;

initialization

finalization
  if hDWriteDll <> 0 then
  begin
    FreeLibrary(hDWriteDll);
    hDWriteDll := 0;
  end;
{$ELSE}
interface

implementation

{$ENDIF}
end.
