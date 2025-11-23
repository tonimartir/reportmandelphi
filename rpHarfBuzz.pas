{$Z4}
Unit rpHarfBuzz;

Interface

Uses SysUtils{$IFNDEF VER230}, AnsiStrings{$ENDIF},
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
  rpfreetype2;

Const
{$IFDEF MSWINDOWS}
  HarfbuzzDLL = 'libharfbuzz-0.dll';
  HarfbuzzSubSetDLL = 'libharfbuzz-subset-0.dll';
{$ELSE}
  HarfbuzzDLL = 'libharfbuzz.so.0';
  HarfbuzzSubSetDLL = 'libharfbuzz.so.0';
{$ENDIF}

Type
  EHarfBuzz = Class(Exception)

  End;
   PHBPosition = ^THBPosition;
   THBPosition = Type Integer;

  THBBool = Type LongBool;
  PHBCodepoint = ^THBCodepoint;
  THBCodepoint = Type Cardinal;
  THBMask = Type Cardinal;
  THBGlyphFlag  = (hbgfUnsafeToBreak);
  THBGlyphFlags = Set Of THBGlyphFlag;
  THBVarInt = Packed Record
      Case Byte Of
         0:
            (u32: Cardinal);
         1:
            (i32: Integer);
         2:
            (u16: Packed Array [0 .. 1] Of Word);
         3:
            (i16: Packed Array [0 .. 1] Of SmallInt);
         4:
            (u8: Packed Array [0 .. 3] Of Byte);
         5:
            (i8: Packed Array [0 .. 3] Of ShortInt);
   End;




  PHBTag = ^THBTag;
  THBTag = Type Cardinal;
     THBTagHelper = Record Helper For THBTag
   Public Type
      THBTagString = String[4];
   Public Const
      None      = THBTag($00000000);
      Max       = THBTag($FFFFFFFF);
      MaxSigned = THBTag($7FFFFFFF);
   Public
      Class Function FromString(Const AStr: AnsiString): THBTag; Static; Inline;
      Function ToString: THBTagString; Inline;
   End;

  TFTFace = FT_Face;
  THBDirection = (hbdInvalid = 0, hbdLTR = 4, hbdRTL, hbdTTB, hbdBTT);
  Phb_subset_input_t = Pointer;
  Phb_face_t = Pointer;
  Phb_set_t = Pointer;
  Phb_blob_t = Pointer;
  Phb_tag_t = Pointer;

  THBFont = Record
  Strict Private
{$HINTS OFF}
    FValue: Pointer;
{$HINTS ON}
    // internal type
  Strict Private
   Procedure SetPTEM(Const APtEM: Single); Inline;
   Function GetPTEM: Single; Inline;
  Const
    sErrorUserData = 'Error setting font user data';
  public
   Class Function CreateReferenced(FTFace: TFTFace): THBFont; Static;
   Procedure SetScale(xScale: integer;yScale: integer);
   Procedure FTFontSetFuncs;
   Procedure Destroy; Inline;
   Property PTEM: Single Read GetPTEM Write SetPTEM;
  End;

  THBFace = Record
   Strict Private
{$HINTS OFF}
      FValue: Pointer;
{$HINTS ON}
      // internal type
   Strict Private
   Const
      sErrorAddBuilder = 'Error adding fact builder table';
   Strict Private
   Public
      Class Function CreateReferenced(FTFace: TFTFace): THBFace; Static; Inline;
      Procedure Destroy; Inline;
   End;
   PHBFeature = ^THBFeature;
   THBFeature = Record
   Strict Private
   Const
      sInvalidFeatureString = 'Invalid feature string: %s';
   Public
      Tag:                THBTag;
      Value, Start, &End: Cardinal;
   Public Const
      cGlobalStart = 0;
      cGlobalEnd   = Cardinal( -1);
   Public
      Class Function FromString(Const AStr: AnsiString): THBFeature; Static; Inline;
      Function ToString: AnsiString; Inline;
   End;
      THBLanguage = Record
   Strict Private
      FValue: Pointer;
      // internal type
   Public
      Class Function FromString(Const AStr: AnsiString): THBLanguage; Static; Inline;
      Function ToString: AnsiString; Inline;
      Class Function Default: THBLanguage; Static; Inline;
      Class Operator Implicit(Const AValue: AnsiString): THBLanguage; Inline;
      Class Operator Implicit(Const AValue: THBLanguage): AnsiString; Inline;
   End;
   THBLanguageHelper = Record Helper For THBLanguage
   Public Const
      Invalid: THBLanguage = (FValue: NIL);
   End;
   THBScript = (hbsCommon = $5A797979 { Zyyy } , // 1.1
      hbsInherited = $5A696E68 { Zinh } ,        // 1.1
      hbsUnknown = $5A7A7A7A { Zzzz } ,          // 5.0
      hbsArabic = $41726162 { Arab } ,     // 1.1
      hbsArmenian = $41726D6E { Armn } ,   // 1.1
      hbsBengali = $42656E67 { Beng } ,    // 1.1
      hbsCyrillic = $4379726C { Cyrl } ,   // 1.1
      hbsDevanagari = $44657661 { Deva } , // 1.1
      hbsGeorgian = $47656F72 { Geor } ,   // 1.1
      hbsGreek = $4772656B { Grek } ,      // 1.1
      hbsGujarati = $47756A72 { Gujr } ,   // 1.1
      hbsGurmukhi = $47757275 { Guru } ,   // 1.1
      hbsHangul = $48616E67 { Hang } ,     // 1.1
      hbsHan = $48616E69 { Hani } ,        // 1.1
      hbsHebrew = $48656272 { Hebr } ,     // 1.1
      hbsHiragana = $48697261 { Hira } ,   // 1.1
      hbsKannada = $4B6E6461 { Knda } ,    // 1.1
      hbsKatakana = $4B616E61 { Kana } ,   // 1.1
      hbsLao = $4C616F6F { Laoo } ,        // 1.1
      hbsLatin = $4C61746E { Latn } ,      // 1.1
      hbsMalayalam = $4D6C796D { Mlym } ,  // 1.1
      hbsOriya = $4F727961 { Orya } ,      // 1.1
      hbsTamil = $54616D6C { Taml } ,      // 1.1
      hbsTelugu = $54656C75 { Telu } ,     // 1.1
      hbsThai = $54686169 { Thai } ,       // 1.1
      hbsTibetan = $54696274 { Tibt } , // 2.0
      hbsBopomofo = $426F706F { Bopo } ,          // 3.0
      hbsBraille = $42726169 { Brai } ,           // 3.0
      hbsCanadianSyllabics = $43616E73 { Cans } , // 3.0
      hbsCherokee = $43686572 { Cher } ,          // 3.0
      hbsEthiopic = $45746869 { Ethi } ,          // 3.0
      hbsKhmer = $4B686D72 { Khmr } ,             // 3.0
      hbsMongolian = $4D6F6E67 { Mong } ,         // 3.0
      hbsMyanmar = $4D796D72 { Mymr } ,           // 3.0
      hbsOgham = $4F67616D { Ogam } ,             // 3.0
      hbsRunic = $52756E72 { Runr } ,             // 3.0
      hbsSinhala = $53696E68 { Sinh } ,           // 3.0
      hbsSyriac = $53797263 { Syrc } ,            // 3.0
      hbsThaana = $54686161 { Thaa } ,            // 3.0
      hbsYi = $59696969 { Yiii } ,                // 3.0
      hbsDeseret = $44737274 { Dsrt } ,   // 3.1
      hbsGothic = $476F7468 { Goth } ,    // 3.1
      hbsOldItalic = $4974616C { Ital } , // 3.1
      hbsBuhid = $42756864 { Buhd } ,    // 3.2
      hbsHanunoo = $48616E6F { Hano } ,  // 3.2
      hbsTagalog = $54676C67 { Tglg } ,  // 3.2
      hbsTagbanwa = $54616762 { Tagb } , // 3.2
      hbsCypriot = $43707274 { Cprt } ,  // 4.0
      hbsLimbu = $4C696D62 { Limb } ,    // 4.0
      hbsLinearB = $4C696E62 { Linb } ,  // 4.0
      hbsOsmanya = $4F736D61 { Osma } ,  // 4.0
      hbsShavian = $53686177 { Shaw } ,  // 4.0
      hbsTaiLe = $54616C65 { Tale } ,    // 4.0
      hbsUgaritic = $55676172 { Ugar } , // 4.0
      hbsBuginese = $42756769 { Bugi } ,    // 4.1
      hbsCoptic = $436F7074 { Copt } ,      // 4.1
      hbsGlagolitic = $476C6167 { Glag } ,  // 4.1
      hbsKharoshthi = $4B686172 { Khar } ,  // 4.1
      hbsNewTaiLue = $54616C75 { Talu } ,   // 4.1
      hbsOldPersian = $5870656F { Xpeo } ,  // 4.1
      hbsSylotiNagri = $53796C6F { Sylo } , // 4.1
      hbsTifinagh = $54666E67 { Tfng } ,    // 4.1
      hbsBalinese = $42616C69 { Bali } ,   // 5.0
      hbsCuneiform = $58737578 { Xsux } ,  // 5.0
      hbsNko = $4E6B6F6F { Nkoo } ,        // 5.0
      hbsPhagsPa = $50686167 { Phag } ,    // 5.0
      hbsPhoenician = $50686E78 { Phnx } , // 5.0
      hbsCarian = $43617269 { Cari } ,     // 5.1
      hbsCham = $4368616D { Cham } ,       // 5.1
      hbsKayahLi = $4B616C69 { Kali } ,    // 5.1
      hbsLepcha = $4C657063 { Lepc } ,     // 5.1
      hbsLycian = $4C796369 { Lyci } ,     // 5.1
      hbsLydian = $4C796469 { Lydi } ,     // 5.1
      hbsOlChiki = $4F6C636B { Olck } ,    // 5.1
      hbsRejang = $526A6E67 { Rjng } ,     // 5.1
      hbsSaurashtra = $53617572 { Saur } , // 5.1
      hbsSundanese = $53756E64 { Sund } ,  // 5.1
      hbsVai = $56616969 { Vaii } ,        // 5.1
      hbsAvestan = $41767374 { Avst } ,               // 5.2
      hbsBamum = $42616D75 { Bamu } ,                 // 5.2
      hbsEgyptianHieroglyphs = $45677970 { Egyp } ,   // 5.2
      hbsImperialAramaic = $41726D69 { Armi } ,       // 5.2
      hbsInscriptionalPahlavi = $50686C69 { Phli } ,  // 5.2
      hbsInscriptionalParthian = $50727469 { Prti } , // 5.2
      hbsJavanese = $4A617661 { Java } ,              // 5.2
      hbsKaithi = $4B746869 { Kthi } ,                // 5.2
      hbsLisu = $4C697375 { Lisu } ,                  // 5.2
      hbsMeeteiMayek = $4D746569 { Mtei } ,           // 5.2
      hbsOldSouthArabian = $53617262 { Sarb } ,       // 5.2
      hbsOldTurkic = $4F726B68 { Orkh } ,             // 5.2
      hbsSamaritan = $53616D72 { Samr } ,             // 5.2
      hbsTaiTham = $4C616E61 { Lana } ,               // 5.2
      hbsTaiViet = $54617674 { Tavt } ,               // 5.2
      hbsBatak = $4261746B { Batk } ,   // 6.0
      hbsBrahmi = $42726168 { Brah } ,  // 6.0
      hbsMandaic = $4D616E64 { Mand } , // 6.0
      hbsChakma = $43616B6D { Cakm } ,              // 6.1
      hbsMeroiticCursive = $4D657263 { Merc } ,     // 6.1
      hbsMeroiticHieroglyphs = $4D65726F { Mero } , // 6.1
      hbsMiao = $506C7264 { Plrd } ,                // 6.1
      hbsSharada = $53687264 { Shrd } ,             // 6.1
      hbsSoraSompeng = $536F7261 { Sora } ,         // 6.1
      hbsTakri = $54616B72 { Takr } ,               // 6.1
      // Since: 0.9.30
      hbsBassaVah = $42617373 { Bass } ,          // 7.0
      hbsCaucasianAlbanian = $41676862 { Aghb } , // 7.0
      hbsDuployan = $4475706C { Dupl } ,          // 7.0
      hbsElbasan = $456C6261 { Elba } ,           // 7.0
      hbsGrantha = $4772616E { Gran } ,           // 7.0
      hbsKhojki = $4B686F6A { Khoj } ,            // 7.0
      hbsKhudawadi = $53696E64 { Sind } ,         // 7.0
      hbsLinearA = $4C696E61 { Lina } ,           // 7.0
      hbsMahajani = $4D61686A { Mahj } ,          // 7.0
      hbsManichaean = $4D616E69 { Mani } ,        // 7.0
      hbsMendeKikakui = $4D656E64 { Mend } ,      // 7.0
      hbsModi = $4D6F6469 { Modi } ,              // 7.0
      hbsMro = $4D726F6F { Mroo } ,               // 7.0
      hbsNabataean = $4E626174 { Nbat } ,         // 7.0
      hbsOldNorthArabian = $4E617262 { Narb } ,   // 7.0
      hbsOldPermic = $5065726D { Perm } ,         // 7.0
      hbsPahawhHmong = $486D6E67 { Hmng } ,       // 7.0
      hbsPalmyrene = $50616C6D { Palm } ,         // 7.0
      hbsPauCinHau = $50617563 { Pauc } ,         // 7.0
      hbsPsalterPahlavi = $50686C70 { Phlp } ,    // 7.0
      hbsSiddham = $53696464 { Sidd } ,           // 7.0
      hbsTirhuta = $54697268 { Tirh } ,           // 7.0
      hbsWarangCiti = $57617261 { Wara } ,        // 7.0
      hbsAhom = $41686F6D { Ahom } ,                 // 8.0
      hbsAnatolianHieroglyphs = $486C7577 { Hluw } , // 8.0
      hbsHatran = $48617472 { Hatr } ,               // 8.0
      hbsMultani = $4D756C74 { Mult } ,              // 8.0
      hbsOldHungarian = $48756E67 { Hung } ,         // 8.0
      hbsSignwriting = $53676E77 { Sgnw } ,          // 8.0
      // Since 1.3.0
      hbsAdlam = $41646C6D { Adlm } ,     // 9.0
      hbsBhaiksuki = $42686B73 { Bhks } , // 9.0
      hbsMarchen = $4D617263 { Marc } ,   // 9.0
      hbsOsage = $4F736765 { Osge } ,     // 9.0
      hbsTangut = $54616E67 { Tang } ,    // 9.0
      hbsNewa = $4E657761 { Newa } ,      // 9.0
      // Since 1.6.0
      hbsMasaramGondi = $476F6E6D { Gonm } ,    // 10.0
      hbsNushu = $4E736875 { Nshu } ,           // 10.0
      hbsSoyombo = $536F796F { Soyo } ,         // 10.0
      hbsZanabazarSquare = $5A616E62 { Zanb } , // 10.0
      // Since 1.8.0
      hbsDogra = $446F6772 { Dogr } ,          // 11.0
      hbsGunjalaGondi = $476F6E67 { Gong } ,   // 11.0
      hbsHanifiRohingya = $526F6867 { Rohg } , // 11.0
      hbsMakasar = $4D616B61 { Maka } ,        // 11.0
      hbsMedefaidrin = $4D656466 { Medf } ,    // 11.0
      hbsOldSogdian = $536F676F { Sogo } ,     // 11.0
      hbsSogdian = $536F6764 { Sogd } ,        // 11.0
      // Since 2.4.0
      hbsElymaic = $456C796D { Elym } ,              // 12.0
      hbsNandinagari = $4E616E64 { Nand } ,          // 12.0
      hbsNyiakengPuachueHmong = $486D6E70 { Hmnp } , // 12.0
      hbsWancho = $5763686F { Wcho } ,               // 12.0
      // Since 2.6.7
      hbsChorasmian = $43687273 { Chrs } ,        // 13.0
      hbsDivesAkuru = $4469616B { Diak } ,        // 13.0
      hbsKhitanSmallScript = $4B697473 { Kits } , // 13.0
      hbsYezidi = $59657A69 { Yezi } ,            // 13.0
      // No script set.
      hbsInvalid = THBTag.None);


   THBScriptHelper = Record Helper For THBScript
   Public
      Class Function FromISO15924(Const ATag: THBTag): THBScript; Static; Inline;
      Class Function FromString(Const AStr: AnsiString): THBScript; Static;
      Function ToISO15924: THBTag; Inline;
      Function GetHorizontalDirection: THBDirection; Inline;
   End;

   PHBGlyphInfo = ^THBGlyphInfo;
   THBGlyphInfo = Record
   Public
      Codepoint: THBCodepoint;
   Strict Private
      FMask: THBMask;
      Function GetGlyphFlags: THBGlyphFlags; Inline;
   Public
      Property GlyphFlags: THBGlyphFlags Read GetGlyphFlags;
   Public
      Cluster: Cardinal;
   Strict Private
{$HINTS OFF}
      Var1, Var2: THBVarInt;
{$HINTS ON}
   End;
   PHBGlyphPosition = ^THBGlyphPosition;
   THBGlyphPosition = Record
   Public
      XAdvance, YAdvance, XOffset, YOffset: THBPosition;
   Strict Private
{$HINTS OFF}
      FVar: THBVarInt;
{$HINTS ON}
   End;

  THBBuffer = Record
  Strict Private
{$HINTS OFF}
    FValue: Pointer;
{$HINTS ON}
    // internal type
  Strict Private
  Const
    sErrorDeserializeGlyphs = 'Error deserializing glyphs';
    sErrorDeserializeUnicode = 'Error deserializing unicode';
    sErrorPreAllocate = 'Error preallocating buffer';
    sErrorSetLength = 'Error setting buffer length';
    sErrorUserData = 'Error setting buffer user data';
    sErrorShape = 'Error while shaping';
  Strict Private
    Procedure SetDirection(Const ADirection: THBDirection); Inline;
    Function GetDirection: THBDirection; Inline;
    Procedure SetScript(Const AScript: THBScript);
    Function GetScript: THBScript; Inline;
    Procedure SetLanguage(Const ALanguage: THBLanguage); Inline;
    Function GetLanguage: THBLanguage; Inline;
  Public Type
    THBBufferMessageFunc = Function(Const ABuffer: THBBuffer;
      Const AFont: THBFont; Const AMessage: PAnsiChar; Const AUserData: Pointer)
      : THBBool; Cdecl;
  Public Const
    BufferReplacementCodepointDefault = $FFFD;
  Public
    Class Function Create: THBBuffer; Static; Inline;
    Procedure Destroy; Inline;
    Procedure AddUTF16(Const AText: WideString; Const AItemOffset: Cardinal = 0;
      Const AItemLength: Integer = -1);
    Function GetGlyphInfos: TArray<THBGlyphInfo>;
    Function GetGlyphPositions: TArray<THBGlyphPosition>;
    Procedure Shape(Font: THBFont;
      Const AFeatures: TArray<THBFeature> = NIL); Inline;
    Property Direction: THBDirection Read GetDirection Write SetDirection;
    Property Script: THBScript Read GetScript Write SetScript;
    Property Language: THBLanguage Read GetLanguage Write SetLanguage;
  End;

  TShapingData=class
   public FreeTypeFace: TFTFace;
   public Font: THBFont;
  end;

  THBMemoryMode = (hbmmDuplicate, hbmmReadonly, hbmmWritable, hbmmReadonlyMayMakeWritable);
   THBDestroyFunc = Procedure(UserData: Pointer); Cdecl;

type
  THbSubsetFlags = UInt32;

const
  HB_SUBSET_FLAGS_DEFAULT = 0; // valor por defecto, HarfBuzz define otros flags como bits individuales

  type

  T_hb_buffer_set_direction = procedure(Buffer: THBBuffer; ADirection: THBDirection); cdecl;

  T_hb_buffer_get_direction = function(ABuffer: THBBuffer): THBDirection; cdecl;

  T_hb_buffer_set_script = procedure(Buffer: THBBuffer; AScript: THBScript); cdecl;

  T_hb_buffer_get_script = function(ABuffer: THBBuffer): THBScript; cdecl;
    T_hb_buffer_destroy = procedure(Buffer: THBBuffer); cdecl;
      T_hb_buffer_set_language = procedure(Buffer: THBBuffer; ALanguage: THBLanguage); cdecl;
  T_hb_buffer_get_language = function(ABuffer: THBBuffer): THBLanguage; cdecl;
    T_hb_tag_from_string = function(AStr: PAnsiChar; ALen: Integer): THBTag; cdecl;
  T_hb_tag_to_string = procedure(ATag: THBTag; Buf: PAnsiChar); cdecl;
  T_hb_ft_face_create_referenced = function(FTFace: TFTFace): THBFace; cdecl;
    T_hb_face_destroy = procedure(Face: THBFace); cdecl;
     T_hb_feature_from_string = function(const AStr: PAnsiChar; const ALen: Integer; out OFeature: THBFeature): THBBool; cdecl;
  T_hb_feature_to_string = procedure(const AFeature: THBFeature; Buf: PAnsiChar; const ASize: Cardinal); cdecl;
    T_hb_language_from_string = function(const AStr: PAnsiChar; const ALen: Integer): THBLanguage; cdecl;
  T_hb_language_to_string = function(const ALanguage: THBLanguage): PAnsiChar; cdecl;
   T_hb_language_get_default = function: THBLanguage; cdecl;
   T_hb_script_from_iso15924_tag = function(const ATag: THBTag): THBScript; cdecl;
  T_hb_script_from_string = function(const AStr: PAnsiChar; const ALen: Integer): THBScript; cdecl;
  T_hb_script_to_iso15924_tag = function(const AScript: THBScript): THBTag; cdecl;
  T_hb_script_get_horizontal_direction = function(const AScript: THBScript): THBDirection; cdecl;
    T_hb_buffer_create = function: THBBuffer; cdecl;
      T_hb_buffer_add_utf16 = procedure(Buffer: THBBuffer;
                                    const AText: PWideChar;
                                    const ATextLength: Integer;
                                    const AItemOffset: Cardinal;
                                    const AItemLength: Integer); cdecl;
  T_hb_shape = procedure(Font: THBFont;
                         Buffer: THBBuffer;
                         const AFeatures: PHBFeature;
                         const ANumFeatures: Cardinal); cdecl;
  T_hb_ft_font_create_referenced = function(FTFace: TFTFace): THBFont; cdecl;
    T_hb_ft_font_set_funcs = procedure(font: THBFont); cdecl;
     T_hb_buffer_get_glyph_infos = function(const ABuffer: THBBuffer; out OLength: Cardinal): PHBGlyphInfo; cdecl;
  T_hb_buffer_get_glyph_positions = function(const ABuffer: THBBuffer; out OLength: Cardinal): PHBGlyphPosition; cdecl;
    T_hb_font_destroy = procedure(font: THBFont); cdecl;
    T_hb_font_set_ptem = procedure (Font: THBFont; Const APtEM: Single); cdecl;
    T_hb_font_get_ptem = function (Const AFont: THBFont): Single; Cdecl;
    T_hb_font_set_scale = Procedure (Font: THBFont; Const AXScale, AYScale: Integer); Cdecl;
    T_hb_font_get_scale = procedure (Const AFont: THBFont; Out OXScale, OYScale: Integer); Cdecl;

    T_hb_subset_input_create_or_fail = function : Phb_subset_input_t; cdecl;
    t_hb_subset_input_destroy = procedure (input: Phb_subset_input_t); cdecl;
    t_hb_subset_input_unicode_set = function (input: Phb_subset_input_t): Phb_set_t; cdecl;
    t_hb_subset_input_glyph_set= function (input: Phb_subset_input_t): Phb_set_t; cdecl;
    t_hb_subset = function (face: THBFace;
                   input: Phb_subset_input_t;
                   glyphs: Phb_set_t;
                   out size: Cardinal): Pointer;cdecl;
    t_hb_blob_create= Function (Const AData: PByte; Const ALength: Cardinal; Const AMode: THBMemoryMode; Const AUserData: Pointer; Const ADestroy: THBDestroyFunc): Phb_blob_t; Cdecl;
    t_hb_face_create = Function (Blob: Phb_blob_t; Const AIndex: Cardinal): THBFace; Cdecl;
    t_hb_blob_destroy = Procedure (Blob: Phb_blob_t); Cdecl;
    t_hb_set_add = function (set_: Phb_set_t; value: Cardinal): Boolean; cdecl;
    t_hb_face_get_table_tags = function (  face: THBFace;
        start_offset: Cardinal;var table_count: Cardinal;
          table_tags: Phb_tag_t
      ): Cardinal; cdecl;
    t_hb_subset_input_set_flags = procedure (subset_input: Phb_subset_input_t; flags: THbSubsetFlags); cdecl;
    t_hb_blob_get_data = function (blob: Phb_blob_t; out length: Cardinal): PByte; cdecl;
    t_hb_subset_or_fail = function (source: THBFace; input: Phb_subset_input_t): THBFace; cdecl;
    t_hb_face_reference_blob = function (face: THBFace): Phb_blob_t; cdecl;
    t_hb_blob_get_length = function (blob: Phb_blob_t): Cardinal; cdecl;

var
  HarfBuzzlib: THandle;
  HarfBuzzlibSubSet: THandle;
  hb_buffer_set_direction: T_hb_buffer_set_direction = nil;
  hb_buffer_get_direction: T_hb_buffer_get_direction = nil;
  hb_buffer_set_script: T_hb_buffer_set_script = nil;
  hb_buffer_get_script: T_hb_buffer_get_script = nil;
  hb_buffer_destroy: T_hb_buffer_destroy = nil;
  hb_buffer_set_language: T_hb_buffer_set_language = nil;
  hb_buffer_get_language: T_hb_buffer_get_language = nil;
  hb_tag_from_string: T_hb_tag_from_string = nil;
  hb_tag_to_string: T_hb_tag_to_string = nil;
  hb_ft_face_create_referenced: T_hb_ft_face_create_referenced = nil;
  hb_face_destroy: T_hb_face_destroy = nil;
    hb_feature_from_string: T_hb_feature_from_string = nil;
  hb_feature_to_string: T_hb_feature_to_string = nil;
    hb_language_from_string: T_hb_language_from_string = nil;
  hb_language_to_string:   T_hb_language_to_string   = nil;
    hb_language_get_default: T_hb_language_get_default = nil;
      hb_script_from_iso15924_tag: T_hb_script_from_iso15924_tag = nil;
  hb_script_from_string: T_hb_script_from_string = nil;
  hb_script_to_iso15924_tag: T_hb_script_to_iso15924_tag = nil;
  hb_script_get_horizontal_direction: T_hb_script_get_horizontal_direction = nil;
    hb_buffer_create: T_hb_buffer_create = nil;
      hb_buffer_add_utf16: T_hb_buffer_add_utf16 = nil;
        hb_shape: T_hb_shape = nil;
    hb_ft_font_create_referenced: T_hb_ft_font_create_referenced = nil;
      hb_ft_font_set_funcs: T_hb_ft_font_set_funcs = nil;
        hb_buffer_get_glyph_infos: T_hb_buffer_get_glyph_infos = nil;
  hb_buffer_get_glyph_positions: T_hb_buffer_get_glyph_positions = nil;
    hb_font_destroy: T_hb_font_destroy = nil;
    hb_font_set_ptem: T_hb_font_set_ptem = nil;
    hb_font_get_ptem: T_hb_font_get_ptem = nil;
    hb_font_set_scale: T_hb_font_set_scale = nil;
    hb_font_get_scale: T_hb_font_get_scale = nil;
    hb_subset_input_create_or_fail: t_hb_subset_input_create_or_fail = nil;
    hb_subset_input_destroy: t_hb_subset_input_destroy = nil;
    hb_subset_input_unicode_set: t_hb_subset_input_unicode_set = nil;
    hb_subset_input_glyph_set: t_hb_subset_input_glyph_set = nil;
    hb_subset: t_hb_subset = nil;
    hb_blob_create:t_hb_blob_create= nil;
    hb_face_create:t_hb_face_create = nil;
    hb_blob_destroy:t_hb_blob_destroy = nil;
    hb_set_add: t_hb_set_add = nil;
    hb_face_get_table_tags: t_hb_face_get_table_tags = nil;
    hb_subset_input_set_flags: t_hb_subset_input_set_flags = nil;
    hb_blob_get_data: t_hb_blob_get_data = nil;
    hb_subset_or_fail:t_hb_subset_or_fail = nil;
    hb_face_reference_blob: t_hb_face_reference_blob= nil;
    hb_blob_get_length: t_hb_blob_get_length = nil;



procedure InitHarfBuzz;

implementation

Procedure THBBuffer.Destroy;
Begin
   hb_buffer_destroy(Self);
End;

Function THBBuffer.GetScript: THBScript;
Begin
   Result := hb_buffer_get_script(Self);
End;
Procedure THBBuffer.Shape(Font: THBFont; Const AFeatures: TArray<THBFeature>);
Begin
   hb_shape(Font, Self, PHBFeature(AFeatures), System.Length(AFeatures));
End;


Procedure THBBuffer.AddUTF16(Const AText: WideString; Const AItemOffset: Cardinal; Const AItemLength: Integer);
Begin
   hb_buffer_add_utf16(Self, PWideChar(AText), System.Length(AText), AItemOffset, AItemLength);
End;

Procedure THBBuffer.SetScript(Const AScript: THBScript);
Begin
   hb_buffer_set_script(Self, AScript);
End;

Function THBBuffer.GetDirection: THBDirection;
Begin
   Result := hb_buffer_get_direction(Self);
End;

Procedure THBBuffer.SetDirection(Const ADirection: THBDirection);
Begin
   hb_buffer_set_direction(Self, ADirection);
End;

Class Function THBBuffer.Create: THBBuffer;
Begin
   Result := hb_buffer_create;
End;

Procedure THBBuffer.SetLanguage(Const ALanguage: THBLanguage);
Begin
   hb_buffer_set_language(Self, ALanguage);
End;


Function THBBuffer.GetGlyphInfos: TArray<THBGlyphInfo>;
Var
   Buf: PHBGlyphInfo;
   Len: Cardinal;
Begin
   Buf := hb_buffer_get_glyph_infos(Self, Len);
   System.SetLength(Result, Len);
   Move(Buf^, Result[0], Len * SizeOf(THBGlyphInfo));
End;
Function THBBuffer.GetGlyphPositions: TArray<THBGlyphPosition>;
Var
   Buf: PHBGlyphPosition;
   Len: Cardinal;
Begin
   Buf := hb_buffer_get_glyph_positions(Self, Len);
   System.SetLength(Result, Len);
   Move(Buf^, Result[0], Len * SizeOf(THBGlyphPosition));
End;


Function THBBuffer.GetLanguage: THBLanguage;
Begin
   Result := hb_buffer_get_language(Self);
End;

Class Function THBTagHelper.FromString(Const AStr: AnsiString): THBTag;
Begin
   Result := hb_tag_from_string(PAnsiChar(AStr), Length(AStr));
End;
Function THBTagHelper.ToString: THBTagString;
Begin
   hb_tag_to_string(Self, @Result[1]);
   SetLength(Result, {$IFNDEF VER230}AnsiStrings.{$ENDIF}StrLen(PAnsiChar(@Result[1])));
End;

Class Function THBFace.CreateReferenced(FTFace: TFTFace): THBFace;
Begin
   Result := hb_ft_face_create_referenced(FTFace);
End;


Procedure THBFace.Destroy;
Begin
   hb_face_destroy(Self);
End;

Class Function THBFeature.FromString(Const AStr: AnsiString): THBFeature;
Begin
   If Not hb_feature_from_string(PAnsiChar(AStr), Length(AStr), Result) Then
      Raise EHarfBuzz.CreateFmt(sInvalidFeatureString, [AStr]);
End;
Function THBFeature.ToString: AnsiString;
Var
   Buf: Packed Array [0 .. 127] Of AnsiChar; // doc says 128 bytes are more than enough
Begin
   hb_feature_to_string(Self, @Buf[0], 128);
   SetLength(Result, {$IFNDEF VER230}AnsiStrings.{$ENDIF}StrLen(PAnsiChar(@Buf[0])));
   Move(Buf, Result[1], Length(Result));
End;

Class Function THBLanguage.Default: THBLanguage;
Begin
   Result := hb_language_get_default;
End;
Class Function THBLanguage.FromString(Const AStr: AnsiString): THBLanguage;
Begin
   Result := hb_language_from_string(PAnsiChar(AStr), Length(AStr));
End;
Class Operator THBLanguage.Implicit(Const AValue: AnsiString): THBLanguage;
Begin
   Result := THBLanguage.FromString(AValue);
End;
Class Operator THBLanguage.Implicit(Const AValue: THBLanguage): AnsiString;
Begin
   Result := AValue.ToString;
End;
Function THBLanguage.ToString: AnsiString;
Begin
   Result := AnsiString(hb_language_to_string(Self));
End;

Class Function THBScriptHelper.FromISO15924(Const ATag: THBTag): THBScript;
Begin
   Result := hb_script_from_iso15924_tag(ATag);
End;
Class Function THBScriptHelper.FromString(Const AStr: AnsiString): THBScript;
Begin
   Result := hb_script_from_string(PAnsiChar(AStr), Length(AStr));
End;
Function THBScriptHelper.GetHorizontalDirection: THBDirection;
Begin
   Result := hb_script_get_horizontal_direction(Self);
End;
Function THBScriptHelper.ToISO15924: THBTag;
Begin
   Result := hb_script_to_iso15924_tag(Self);
End;

Function THBGlyphInfo.GetGlyphFlags: THBGlyphFlags;
Var
   RMask: THBMask Absolute Result;
Begin
   RMask := FMask And ((2 Shl Ord(High(THBGlyphFlag))) - 1);
End;

Class Function THBFont.CreateReferenced(FTFace: TFTFace): THBFont;
Begin
   Result := hb_ft_font_create_referenced(FTFace);
End;

Procedure THBFont.FTFontSetFuncs;
Begin
   hb_ft_font_set_funcs(Self);
End;


Procedure THBFont.Destroy;
Begin
   hb_font_destroy(Self);
End;

Procedure THBFont.SetPTEM(Const APtEM: Single);
Begin
   hb_font_set_ptem(Self, APtEM);
End;

Procedure THBFont.SetScale(xScale: integer;yScale: integer);
var
 newXScale,newYScale: integer;
Begin
   hb_font_set_scale(Self,xScale,yScale);
   hb_font_get_scale(Self,newXScale,newYScale);
End;

Function THBFont.GetPTEM: Single;
Begin
   Result := hb_font_get_ptem(Self);
End;

procedure InitHarfBuzz;
var
  libName: string;
  ProcName: string;

  function GetProcAddr(ProcName: string): Pointer;
  begin
{$IFDEF MSWINDOWS}
    Result := GetProcAddress(HarfBuzzlib, PWideChar(ProcName));
    if not Assigned(Result) then
      RaiseLastOSError;
{$ENDIF}
{$IFDEF LINUX}
{$IFDEF FPC}
    Result := Dynlibs.GetProcAddress(HarfBuzzlib, ProcName);
    if Result = nil then
      raise Exception.CreateFmt('Error loading %s', [ProcName]);
{$ELSE}
    Result := SysUtils.GetProcAddress(HarfBuzzlib, PWideChar(ProcName));
    if Result = nil then
      RaiseLastOSError;
{$ENDIF}
{$ENDIF}
  end;
  function GetProcAddrSubset(ProcName: string): Pointer;
  begin
{$IFDEF MSWINDOWS}
    Result := GetProcAddress(HarfBuzzlibSubset, PWideChar(ProcName));
    if not Assigned(Result) then
      RaiseLastOSError;
{$ENDIF}
{$IFDEF LINUX}
{$IFDEF FPC}
    Result := Dynlibs.GetProcAddress(HarfBuzzlibSubset, ProcName);
    if Result = nil then
      raise Exception.CreateFmt('Error loading %s', [ProcName]);
{$ELSE}
    Result := SysUtils.GetProcAddress(HarfBuzzlibSubset, PWideChar(ProcName));
    if Result = nil then
      RaiseLastOSError;
{$ENDIF}
{$ENDIF}
  end;

begin
  if (HarfBuzzlib <> 0) then
    exit;
  HarfBuzzlib := 0;

  HarfBuzzlib :=
  {$IFDEF MSWINDOWS}LoadLibrary(PChar(HarfbuzzDLL)
    ){$ELSE}SysUtils.SafeLoadLibrary(HarfbuzzDLL){$ENDIF};

  if HarfBuzzlib = 0 then
    raise Exception.Create('No harfbuzz library found ' + HarfbuzzDLL);
  HarfBuzzLibSubset :=
  {$IFDEF MSWINDOWS}LoadLibrary(PChar(HarfbuzzSubsetDLL)
    ){$ELSE}SysUtils.SafeLoadLibrary(HarfbuzzSubsetDLL){$ENDIF};

  ProcName:='hb_buffer_set_direction';
  hb_buffer_set_direction:= GetProcAddr(ProcName);
  if not Assigned(hb_buffer_set_direction) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_buffer_get_direction';
  hb_buffer_get_direction:= GetProcAddr(ProcName);
  if not Assigned(hb_buffer_get_direction) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_buffer_set_script';
  hb_buffer_set_script:= GetProcAddr(ProcName);
  if not Assigned(hb_buffer_set_script) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_buffer_get_script';
  hb_buffer_get_script:= GetProcAddr(ProcName);
  if not Assigned(hb_buffer_get_script) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_buffer_destroy';
  hb_buffer_destroy:= GetProcAddr(ProcName);
  if not Assigned(hb_buffer_destroy) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_buffer_set_language';
  hb_buffer_set_language:= GetProcAddr(ProcName);
  if not Assigned(hb_buffer_set_language) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_buffer_get_language';
  hb_buffer_get_language:= GetProcAddr(ProcName);
  if not Assigned(hb_buffer_get_language) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_tag_from_string';
  hb_tag_from_string:= GetProcAddr(ProcName);
  if not Assigned(hb_tag_from_string) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_tag_to_string';
  hb_tag_to_string:= GetProcAddr(ProcName);
  if not Assigned(hb_tag_to_string) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_ft_face_create_referenced';
  hb_ft_face_create_referenced:= GetProcAddr(ProcName);
  if not Assigned(hb_ft_face_create_referenced) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_face_destroy';
  hb_face_destroy:= GetProcAddr(ProcName);
  if not Assigned(hb_face_destroy) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_feature_from_string';
  hb_feature_from_string:= GetProcAddr(ProcName);
  if not Assigned(hb_feature_from_string) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_feature_to_string';
  hb_feature_to_string:= GetProcAddr(ProcName);
  if not Assigned(hb_feature_to_string) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_language_from_string';
  hb_language_from_string:= GetProcAddr(ProcName);
  if not Assigned(hb_language_from_string) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_language_to_string';
  hb_language_to_string:= GetProcAddr(ProcName);
  if not Assigned(hb_language_to_string) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_language_get_default';
  hb_language_get_default:= GetProcAddr(ProcName);
  if not Assigned(hb_language_get_default) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_script_from_iso15924_tag';
  hb_script_from_iso15924_tag:= GetProcAddr(ProcName);
  if not Assigned(hb_script_from_iso15924_tag) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_script_from_string';
  hb_script_from_string:= GetProcAddr(ProcName);
  if not Assigned(hb_script_from_string) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_script_to_iso15924_tag';
  hb_script_to_iso15924_tag:= GetProcAddr(ProcName);
  if not Assigned(hb_script_to_iso15924_tag) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_script_get_horizontal_direction';
  hb_script_get_horizontal_direction:= GetProcAddr(ProcName);
  if not Assigned(hb_script_get_horizontal_direction) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_buffer_create';
  hb_buffer_create:= GetProcAddr(ProcName);
  if not Assigned(hb_buffer_create) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_buffer_add_utf16';
  hb_buffer_add_utf16:= GetProcAddr(ProcName);
  if not Assigned(hb_buffer_add_utf16) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_shape';
  hb_shape:= GetProcAddr(ProcName);
  if not Assigned(hb_shape) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_ft_font_create_referenced';
  hb_ft_font_create_referenced:= GetProcAddr(ProcName);
  if not Assigned(hb_ft_font_create_referenced) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_ft_font_set_funcs';
  hb_ft_font_set_funcs:= GetProcAddr(ProcName);
  if not Assigned(hb_ft_font_set_funcs) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_buffer_get_glyph_infos';
  hb_buffer_get_glyph_infos:= GetProcAddr(ProcName);
  if not Assigned(hb_buffer_get_glyph_infos) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_buffer_get_glyph_positions';
  hb_buffer_get_glyph_positions:= GetProcAddr(ProcName);
  if not Assigned(hb_buffer_get_glyph_positions) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_font_set_ptem';
  hb_font_set_ptem:= GetProcAddr(ProcName);
  if not Assigned(hb_font_set_ptem) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_font_get_ptem';
  hb_font_get_ptem:= GetProcAddr(ProcName);
  if not Assigned(hb_font_get_ptem) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_font_set_scale';
  hb_font_set_scale:= GetProcAddr(ProcName);
  if not Assigned(hb_font_set_scale) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName:='hb_font_get_scale';
  hb_font_get_scale:= GetProcAddr(ProcName);
  if not Assigned(hb_font_get_scale) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_subset_input_create_or_fail';
  hb_subset_input_create_or_fail:= GetProcAddrSubSet(ProcName);
  if not Assigned(hb_subset_input_create_or_fail) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_subset_input_destroy';
  hb_subset_input_destroy:= GetProcAddrSubset(ProcName);
  if not Assigned(hb_subset_input_destroy) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_subset_input_unicode_set';
  hb_subset_input_unicode_set:= GetProcAddrSubset(ProcName);
  if not Assigned(hb_subset_input_unicode_set) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_subset_input_glyph_set';
  hb_subset_input_glyph_set:= GetProcAddrSubset(ProcName);
  if not Assigned(hb_subset_input_glyph_set) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_subset';
  hb_subset:= GetProcAddrSubset(ProcName);
  if not Assigned(hb_subset) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_blob_create';
  hb_blob_create:= GetProcAddr(ProcName);
  if not Assigned(hb_blob_create) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_face_create';
  hb_face_create:= GetProcAddr(ProcName);
  if not Assigned(hb_face_create) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_blob_destroy';
  hb_blob_destroy:= GetProcAddr(ProcName);
  if not Assigned(hb_blob_destroy) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_set_add';
  hb_set_add:= GetProcAddr(ProcName);
  if not Assigned(hb_set_add) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_face_get_table_tags';
  hb_face_get_table_tags:= GetProcAddr(ProcName);
  if not Assigned(hb_face_get_table_tags) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_subset_input_set_flags';
  hb_subset_input_set_flags:= GetProcAddrSubset(ProcName);
  if not Assigned(hb_subset_input_set_flags) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_blob_get_data';
  hb_blob_get_data:= GetProcAddr(ProcName);
  if not Assigned(hb_blob_get_data) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_subset_or_fail';
  hb_subset_or_fail:= GetProcAddrSubSet(ProcName);
  if not Assigned(hb_subset_or_fail) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_face_reference_blob';
  hb_face_reference_blob:= GetProcAddr(ProcName);
  if not Assigned(hb_face_reference_blob) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName:='hb_blob_get_length';
  hb_blob_get_length:= GetProcAddr(ProcName);
  if not Assigned(hb_blob_get_length) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

end;

End.
