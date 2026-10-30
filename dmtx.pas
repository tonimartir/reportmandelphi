unit dmtx;
(**
 * libdmtx - Data Matrix Encoding/Decoding Library
 * Copyright 2008, 2009 Mike Laughton. All rights reserved.
 * Copyright 2012-2016 Vadim A. Misbakh-Soloviov. All rights reserved.
 * Copyright 2016 Tim Zaman. All rights reserved.
 *
 * See LICENSE file in the main project directory for full
 * terms of use and distribution.
 *
 * Contact:
 * Vadim A. Misbakh-Soloviov <dmtx@mva.name>
 * Mike Laughton <mike@dragonflylogic.com>
 *
 * C to Pascal translation by Ladislav Karrach (with help of c2pas32)
 * (C source taken from https://github.com/dmtx/libdmtx on June 2017)
 *
 * \file dmtx.h
 * \brief Main libdmtx header
 *)
{$POINTERMATH ON}

interface

const
  M_PI = 3.14159265358979323846; 
  M_PI_2 = 1.57079632679489661923; 

  DmtxVersion = '0.7.5';
  DmtxUndefined = -1; 
  DmtxPass = 1;
  DmtxFail = 0;
  DmtxTrue = True;
  DmtxFalse = False;
  DmtxFormatMatrix = 0; 
  DmtxFormatMosaic = 1; 
  DmtxSymbolSquareCount = 24; 
  DmtxSymbolRectCount = 6; 
  DmtxModuleOff = $00; 
  DmtxModuleOnRed = $01; 
  DmtxModuleOnGreen = $02; 
  DmtxModuleOnBlue = $04; 
  DmtxModuleOnRGB = $07; (* OnRed | OnGreen | OnBlue *)
  DmtxModuleOn = $07; 
  DmtxModuleUnsure = $08; 
  DmtxModuleAssigned = $10; 
  DmtxModuleVisited = $20; 
  DmtxModuleData = $40; 

  CDmtxDirUp     = $01 shl 0;
  CDmtxDirLeft   = $01 shl 1;
  CDmtxDirDown   = $01 shl 2;
  CDmtxDirRight  = $01 shl 3;

type
  { The compiler has all integer types defined internally. Here
    we define only aliases }
  DWord    = LongWord;
//  Cardinal = LongWord;
//  Integer  = SmallInt;
//  UInt64   = QWord;

{$ifdef CPU64}
  THandle = QWord;
  ULONG_PTR = QWord;
{$else CPU64}
  THandle = DWord;
  ULONG_PTR = DWord;
{$endif CPU64}
  TThreadID = DWord;
  SIZE_T = ULONG_PTR;

type
  DmtxPassFail = DWord; //unsignedint;
  DmtxBoolean = Boolean; //unsignedint;

type
  DmtxStatus = (
     DmtxStatusEncoding, (* Encoding is currently underway *)
     DmtxStatusComplete, (* Encoding is done and everything went well *)
     DmtxStatusInvalid,  (* Something bad happened that sometimes happens *)
     DmtxStatusFatal     (* Something happened that should never happen *)
  );

  DmtxScheme = (
     DmtxSchemeAutoFast        = -2,
     DmtxSchemeAutoBest        = -1,
     DmtxSchemeAscii           =  0,
     DmtxSchemeC40,
     DmtxSchemeText,
     DmtxSchemeX12,
     DmtxSchemeEdifact,
     DmtxSchemeBase256
  );

  DmtxSymbolSize = (
     DmtxSymbolRectAuto        = -3,
     DmtxSymbolSquareAuto      = -2,
     DmtxSymbolShapeAuto       = -1,
     DmtxSymbol10x10           =  0,
     DmtxSymbol12x12,
     DmtxSymbol14x14,
     DmtxSymbol16x16,
     DmtxSymbol18x18,
     DmtxSymbol20x20,
     DmtxSymbol22x22,
     DmtxSymbol24x24,
     DmtxSymbol26x26,
     DmtxSymbol32x32,
     DmtxSymbol36x36,
     DmtxSymbol40x40,
     DmtxSymbol44x44,
     DmtxSymbol48x48,
     DmtxSymbol52x52,
     DmtxSymbol64x64,
     DmtxSymbol72x72,
     DmtxSymbol80x80,
     DmtxSymbol88x88,
     DmtxSymbol96x96,
     DmtxSymbol104x104,
     DmtxSymbol120x120,
     DmtxSymbol132x132,
     DmtxSymbol144x144,
     DmtxSymbol8x18,
     DmtxSymbol8x32,
     DmtxSymbol12x26,
     DmtxSymbol12x36,
     DmtxSymbol16x36,
     DmtxSymbol16x48
  );

  DmtxDirection = (
     DmtxDirNone               = $00,
     DmtxDirUp                 = CDmtxDirUp,
     DmtxDirLeft               = CDmtxDirLeft,
     DmtxDirDown               = CDmtxDirDown,
     DmtxDirVertical           = CDmtxDirUp    + CDmtxDirDown,
     DmtxDirLeftDown           = CDmtxDirLeft  + CDmtxDirDown,
     DmtxDirRight              = CDmtxDirRight,
     DmtxDirRightUp            = CDmtxDirRight + CDmtxDirUp,
     DmtxDirHorizontal         = CDmtxDirLeft  + CDmtxDirRight
  );

  DmtxSymAttribute = (
     DmtxSymAttribSymbolRows,
     DmtxSymAttribSymbolCols,
     DmtxSymAttribDataRegionRows,
     DmtxSymAttribDataRegionCols,
     DmtxSymAttribHorizDataRegions,
     DmtxSymAttribVertDataRegions,
     DmtxSymAttribMappingMatrixRows,
     DmtxSymAttribMappingMatrixCols,
     DmtxSymAttribInterleavedBlocks,
     DmtxSymAttribBlockErrorWords,
     DmtxSymAttribBlockMaxCorrectable,
     DmtxSymAttribSymbolDataWords,
     DmtxSymAttribSymbolErrorWords,
     DmtxSymAttribSymbolMaxCorrectable
  );

  DmtxCornerLoc = (
     DmtxCorner00              = $01 shl 0,
     DmtxCorner10              = $01 shl 1,
     DmtxCorner11              = $01 shl 2,
     DmtxCorner01              = $01 shl 3
  );

  DmtxProperty = (
     (* Encoding properties *)
     DmtxPropScheme            = 100,
     DmtxPropSizeRequest,
     DmtxPropMarginSize,
     DmtxPropModuleSize,
     (* Decoding properties *)
     DmtxPropEdgeMin           = 200,
     DmtxPropEdgeMax,
     DmtxPropScanGap,
     DmtxPropSquareDevn,
     DmtxPropSymbolSize,
     DmtxPropEdgeThresh,
     (* Image properties *)
     DmtxPropWidth             = 300,
     DmtxPropHeight,
     DmtxPropPixelPacking,
     DmtxPropBitsPerPixel,
     DmtxPropBytesPerPixel,
     DmtxPropRowPadBytes,
     DmtxPropRowSizeBytes,
     DmtxPropImageFlip,
     DmtxPropChannelCount,
     (* Image modifiers *)
     DmtxPropXmin              = 400,
     DmtxPropXmax,
     DmtxPropYmin,
     DmtxPropYmax,
     DmtxPropScale
  );

  DmtxPackOrder = (
     (* Custom format *)
     DmtxPackCustom            = 100,
     (* 1 bpp *)
     DmtxPack1bppK             = 200,
     (* 8 bpp grayscale *)
     DmtxPack8bppK             = 300,
     (* 16 bpp formats *)
     DmtxPack16bppRGB          = 400,
     DmtxPack16bppRGBX,
     DmtxPack16bppXRGB,
     DmtxPack16bppBGR,
     DmtxPack16bppBGRX,
     DmtxPack16bppXBGR,
     DmtxPack16bppYCbCr,
     (* 24 bpp formats *)
     DmtxPack24bppRGB          = 500,
     DmtxPack24bppBGR,
     DmtxPack24bppYCbCr,
     (* 32 bpp formats *)
     DmtxPack32bppRGBX         = 600,
     DmtxPack32bppXRGB,
     DmtxPack32bppBGRX,
     DmtxPack32bppXBGR,
     DmtxPack32bppCMYK
  );

  DmtxFlip = (
    DmtxFlipNone               = $00,
    DmtxFlipX                  = $01 shl 0,
    DmtxFlipY                  = $01 shl 1
  );

type
  tDmtxMatrix3 = array [0..2,0..2] of double;

  DmtxPixelLoc_struct = record
    X: integer;
    Y: integer;
  end;
  DmtxPixelLoc = DmtxPixelLoc_struct;
  pDmtxPixelLoc = ^DmtxPixelLoc;

  DmtxVector2_struct = record
    X: double;
    Y: double;
  end;
  tDmtxVector2 = DmtxVector2_struct;
  pDmtxVector2 = ^tDmtxVector2;

  DmtxRay2_struct = record
    tMin: double;
    tMax: double;
    p: tDmtxVector2;
    v: tDmtxVector2;
  end;
  DmtxRay2 = DmtxRay2_struct;
  pDmtxRay2 = ^DmtxRay2;

  DmtxByte = byte;
  pDmtxByte = ^DmtxByte;

  DmtxByteList_struct = record
    length: integer;
    capacity: integer;
    b: pDmtxByte;
  end;
  tDmtxByteList = DmtxByteList_struct;
  pDmtxByteList = ^tDmtxByteList;

  DmtxEncodeStream_struct = record
    currentScheme: DmtxScheme; (* Current encodation scheme *)
    inputNext: integer; (* Index of next unprocessed input word in queue *)
    outputChainValueCount: integer; (* Count of output values pushed within current scheme chain *)
    outputChainWordCount: integer; (* Count of output words pushed within current scheme chain *)
    reason: PAnsiChar; (* Reason for status *)
    sizeIdx: integer; (* Symbol size of completed stream *)
    status: DmtxStatus;
    input: pDmtxByteList;
    output: pDmtxByteList;
  end;
  tDmtxEncodeStream = DmtxEncodeStream_struct;
  pDmtxEncodeStream = ^tDmtxEncodeStream;

  DmtxImage_struct = record
    width: integer;
    height: integer;
    pixelPacking: DmtxPackOrder;
    bitsPerPixel: integer;
    bytesPerPixel: integer;
    rowPadBytes: integer;
    rowSizeBytes: integer;
    imageFlip: integer;
    channelCount: integer;
    channelStart: array [0..3] of integer;
    bitsPerChannel: array [0..3] of integer;
    pxl: pbyte;
  end;
  tDmtxImage = DmtxImage_struct;
  pDmtxImage = ^tDmtxImage;

  DmtxPointFlow_struct = record
    plane: integer;
    arrive: integer;
    depart: integer;
    mag: integer;
    loc: DmtxPixelLoc;
  end;
  DmtxPointFlow = DmtxPointFlow_struct;

  DmtxBestLine_struct = record
    angle: integer;
    hOffset: integer;
    mag: integer;
    stepBeg: integer;
    stepPos: integer;
    stepNeg: integer;
    distSq: integer;
    devn: double;
    locBeg: DmtxPixelLoc;
    locPos: DmtxPixelLoc;
    locNeg: DmtxPixelLoc;
  end;
  DmtxBestLine = DmtxBestLine_struct;
  pDmtxBestLine = ^DmtxBestLine;

  DmtxRegion_struct = record
    jumpToPos: integer; (* Trail blazing values *)
    (* *)
    jumpToNeg: integer; (* *)
    stepsTotal: integer; (* *)
    finalPos: DmtxPixelLoc; (* *)
    finalNeg: DmtxPixelLoc; (* *)
    boundMin: DmtxPixelLoc; (* *)
    boundMax: DmtxPixelLoc; (* *)
    flowBegin: DmtxPointFlow; (* *)
    (* Orientation values *)
    polarity: integer; (* *)
    stepR: integer;
    stepT: integer;
    locR: DmtxPixelLoc; (* remove if stepR works above *)
    locT: DmtxPixelLoc; (* remove if stepT works above *)
    (* Region fitting values *)
    leftKnown: integer; (* known == 1; unknown == 0 *)
    leftAngle: integer; (* hough angle of left edge *)
    leftLoc: DmtxPixelLoc; (* known (arbitrary) location on left edge *)
    leftLine: DmtxBestLine; (* *)
    bottomKnown: integer; (* known == 1; unknown == 0 *)
    bottomAngle: integer; (* hough angle of bottom edge *)
    bottomLoc: DmtxPixelLoc; (* known (arbitrary) location on bottom edge *)
    bottomLine: DmtxBestLine; (* *)
    topKnown: integer; (* known == 1; unknown == 0 *)
    topAngle: integer; (* hough angle of top edge *)
    topLoc: DmtxPixelLoc; (* known (arbitrary) location on top edge *)
    rightKnown: integer; (* known == 1; unknown == 0 *)
    rightAngle: integer; (* hough angle of right edge *)
    rightLoc: DmtxPixelLoc; (* known (arbitrary) location on right edge *)
    (* Region calibration values *)
    onColor: integer; (* *)
    offColor: integer; (* *)
    sizeIdx: integer; (* Index of arrays that store Data Matrix constants *)
    symbolRows: integer; (* Number of total rows in symbol including alignment patterns *)
    symbolCols: integer; (* Number of total columns in symbol including alignment patterns *)
    mappingRows: integer; (* Number of data rows in symbol *)
    mappingCols: integer; (* Number of data columns in symbol *)
    (* Transform values *)
    raw2fit: tDmtxMatrix3; (* 3x3 transformation from raw image to fitted barcode grid *)
    fit2raw: tDmtxMatrix3; (* 3x3 transformation from fitted barcode grid to raw image *)
  end;
  tDmtxRegion = DmtxRegion_struct;
  pDmtxRegion = ^tDmtxRegion;

  DmtxMessage_struct = record
    arraySize: size_t; (* mappingRows * mappingCols *)
    codeSize: size_t; (* Size of encoded data (data words + error words) *)
    outputSize: size_t; (* Size of buffer used to hold decoded data *)
    outputIdx: integer; (* Internal index used to store output progress *)
    padCount: integer;
    arr{ay}: pbyte; (* Pointer to internal representation of Data Matrix modules *)
    code: pbyte; (* Pointer to internal storage of code words (data and error) *)
    output: pAnsiChar; (* Pointer to internal storage of decoded output *)
  end;
  tDmtxMessage = DmtxMessage_struct;
  pDmtxMessage = ^tDmtxMessage;

  DmtxScanGrid_struct = record
    minExtent: integer; (* set once *)
    (* Smallest cross size used in scan *)
    maxExtent: integer; (* Size of bounding grid region (2^N - 1) *)
    xOffset: integer; (* Offset to obtain image X coordinate *)
    yOffset: integer; (* Offset to obtain image Y coordinate *)
    xMin: integer; (* Minimum X in image coordinate system *)
    xMax: integer; (* Maximum X in image coordinate system *)
    yMin: integer; (* Minimum Y in image coordinate system *)
    yMax: integer; (* Maximum Y in image coordinate system *)
    (* reset for each level *)
    total: integer; (* Total number of crosses at this size *)
    extent: integer; (* Length/width of cross in pixels *)
    jumpSize: integer; (* Distance in pixels between cross centers *)
    pixelTotal: integer; (* Total pixel count within an individual cross path *)
    startPos: integer; (* X and Y coordinate of first cross center in pattern *)
    (* reset for each cross *)
    pixelCount: integer; (* Progress (pixel count) within current cross pattern *)
    xCenter: integer; (* X center of current cross pattern *)
    yCenter: integer; (* Y center of current cross pattern *)
  end;
  tDmtxScanGrid = DmtxScanGrid_struct;
  pDmtxScanGrid = ^tDmtxScanGrid;

  DmtxTime_struct = record
    sec: Int64; //time_t;
    usec: DWord;
  end;
  tDmtxTime = DmtxTime_struct;
  pDmtxTime = ^tDmtxTime;

  DmtxDecode_struct = record
    edgeMin: integer; (* Options *)
    edgeMax: integer;
    scanGap: integer;
    squareDevn: double;
    sizeIdxExpected: DmtxSymbolSize;
    edgeThresh: integer; (* Image modifiers *)
    xMin: integer;
    xMax: integer;
    yMin: integer;
    yMax: integer;
    scale: integer; (* Internals *)
    (* int             cacheComplete; *)
    cache: pbyte;
    image: pDmtxImage;
    grid: tDmtxScanGrid;
  end;
  tDmtxDecode = DmtxDecode_struct;
  pDmtxDecode = ^tDmtxDecode;

  DmtxEncode_struct = record
    method: integer;
    scheme: DmtxScheme;
    sizeIdxRequest: DmtxSymbolSize;
    marginSize: integer;
    moduleSize: integer;
    pixelPacking: DmtxPackOrder;
    imageFlip: integer;
    rowPadBytes: integer;
    message: pDmtxMessage;
    image: pDmtxImage;
    region: tDmtxRegion;
    xfrm: tDmtxMatrix3; (* XXX still necessary? *)
    rxfrm: tDmtxMatrix3; (* XXX still necessary? *)
  end;
  tDmtxEncode = DmtxEncode_struct;
  pDmtxEncode = ^tDmtxEncode;

  DmtxChannel_struct = record
    encScheme: integer; (* current encodation scheme *)
    invalid: integer; (* channel status (invalid if non-zero) *)
    inputPtr: pAnsiChar; (* pointer to current input character *)
    inputStop: pAnsiChar; (* pointer to position after final input character *)
    encodedLength: integer; (* encoded length (units of 2/3 bits) *)
    currentLength: integer; (* current length (units of 2/3 bits) *)
    firstCodeWord: integer; (* *)
    encodedWords: array [0..Pred(1558)] of byte;
  end;
  DmtxChannel = DmtxChannel_struct;

  DmtxChannelGroup_struct = record
    channel: array [0..Pred(6)] of DmtxChannel;
  end;
  DmtxChannelGroup = DmtxChannelGroup_struct;

  DmtxTriplet_struct = record
    value: array [0..Pred(3)] of byte; // char
  end;
  DmtxTriplet = DmtxTriplet_struct;

  DmtxQuadruplet_struct = record
    value: array [0..Pred(4)] of byte; // char
  end;
  DmtxQuadruplet = DmtxQuadruplet_struct;

(*** dmtxstatic.h ***)
   DmtxEncodeOption = (
     DmtxEncodeNormal,  (* Use normal scheme behavior (e.g., ASCII auto) *)
     DmtxEncodeCompact, (* Use only compact format within scheme *)
     DmtxEncodeFull     (* Use only fully expanded format within scheme *)
  );

  DmtxRange = (
    DmtxRangeGood,
    DmtxRangeBad,
    DmtxRangeEnd
  );

  DmtxEdge = (
     DmtxEdgeTop    = $01 shl 0,
     DmtxEdgeBottom = $01 shl 1,
     DmtxEdgeLeft   = $01 shl 2,
     DmtxEdgeRight  = $01 shl 3
  );

  DmtxFollow_struct = record
    ptr: PByte;
    neighbor: Byte;
    step: integer;
    loc: DmtxPixelLoc;
  end;
  DmtxFollow = DmtxFollow_struct;

  DmtxBresLine_struct = record
    xStep: integer;
    yStep: integer;
    xDelta: integer;
    yDelta: integer;
    steep: boolean;
    xOut: integer;
    yOut: integer;
    travel: integer;
    outward: integer;
    error: integer;
    loc: DmtxPixelLoc;
    loc0: DmtxPixelLoc;
    loc1: DmtxPixelLoc;
  end;
  DmtxBresLine = DmtxBresLine_struct;
  pDmtxBresLine = ^DmtxBresLine;

  C40TextState_struct = record
    shift: integer;
    upperShift: DmtxBoolean;
  end;
  C40TextState = C40TextState_struct;
  pC40TextState = ^C40TextState;

  TDmtxErrorMessage = (
     DmtxErrorUnknown,
     DmtxErrorUnsupportedCharacter,
     DmtxErrorNotOnByteBoundary,
     DmtxErrorIllegalParameterValue,
     DmtxErrorEmptyList,
     DmtxErrorOutOfBounds,
     DmtxErrorMessageTooLarge,
     DmtxErrorCantCompactNonDigits,
     DmtxErrorUnexpectedScheme,
     DmtxErrorIncompleteValueList
  );

const
  DmtxMaskBit8  = $01 shl 0;
  DmtxMaskBit7  = $01 shl 1;
  DmtxMaskBit6  = $01 shl 2;
  DmtxMaskBit5  = $01 shl 3;
  DmtxMaskBit4  = $01 shl 4;
  DmtxMaskBit3  = $01 shl 5;
  DmtxMaskBit2  = $01 shl 6;
  DmtxMaskBit1  = $01 shl 7;

  DmtxAlmostZero          = 0.000001;
  DmtxAlmostInfinity      = -1;

  DmtxValueC40Latch       = 230;
  DmtxValueTextLatch      = 239;
  DmtxValueX12Latch       = 238;
  DmtxValueEdifactLatch   = 240;
  DmtxValueBase256Latch   = 231;

  DmtxValueCTXUnlatch      = 254;
  DmtxValueEdifactUnlatch  = 31;

  DmtxValueAsciiPad        = 129;
  DmtxValueAsciiUpperShift = 235;
  DmtxValueCTXShift1       = 0;
  DmtxValueCTXShift2       = 1;
  DmtxValueCTXShift3       = 2;
  DmtxValueFNC1             = 232;
  DmtxValueStructuredAppend = 233;
  DmtxValue05Macro          = 236;
  DmtxValue06Macro          = 237;
  DmtxValueECI              = 241;

  DmtxC40TextBasicSet       = 0;
  DmtxC40TextShift1         = 1;
  DmtxC40TextShift2         = 2;
  DmtxC40TextShift3         = 3;

  DmtxUnlatchExplicit = 0;
  DmtxUnlatchImplicit = 1;

  dmtxNeighborNone = 8;
  dmtxPatternX: array[0..7] of integer = ( -1,  0,  1,  1,  1,  0, -1, -1 );
  dmtxPatternY: array[0..7] of integer = ( -1, -1, -1,  0,  1,  1,  1,  0 );
  dmtxBlankEdge: DmtxPointFlow = ( plane:0; arrive:0; depart:0; mag:DmtxUndefined; loc:(X:-1;Y:-1) );

  rHvX: array[0..179] of integer =
      (  256,  256,  256,  256,  255,  255,  255,  254,  254,  253,  252,  251,  250,  249,  248,
         247,  246,  245,  243,  242,  241,  239,  237,  236,  234,  232,  230,  228,  226,  224,
         222,  219,  217,  215,  212,  210,  207,  204,  202,  199,  196,  193,  190,  187,  184,
         181,  178,  175,  171,  168,  165,  161,  158,  154,  150,  147,  143,  139,  136,  132,
         128,  124,  120,  116,  112,  108,  104,  100,   96,   92,   88,   83,   79,   75,   71,
          66,   62,   58,   53,   49,   44,   40,   36,   31,   27,   22,   18,   13,    9,    4,
           0,   -4,   -9,  -13,  -18,  -22,  -27,  -31,  -36,  -40,  -44,  -49,  -53,  -58,  -62,
         -66,  -71,  -75,  -79,  -83,  -88,  -92,  -96, -100, -104, -108, -112, -116, -120, -124,
        -128, -132, -136, -139, -143, -147, -150, -154, -158, -161, -165, -168, -171, -175, -178,
        -181, -184, -187, -190, -193, -196, -199, -202, -204, -207, -210, -212, -215, -217, -219,
        -222, -224, -226, -228, -230, -232, -234, -236, -237, -239, -241, -242, -243, -245, -246,
        -247, -248, -249, -250, -251, -252, -253, -254, -254, -255, -255, -255, -256, -256, -256 );

  rHvY: array[0..179] of integer =
      (    0,    4,    9,   13,   18,   22,   27,   31,   36,   40,   44,   49,   53,   58,   62,
          66,   71,   75,   79,   83,   88,   92,   96,  100,  104,  108,  112,  116,  120,  124,
         128,  132,  136,  139,  143,  147,  150,  154,  158,  161,  165,  168,  171,  175,  178,
         181,  184,  187,  190,  193,  196,  199,  202,  204,  207,  210,  212,  215,  217,  219,
         222,  224,  226,  228,  230,  232,  234,  236,  237,  239,  241,  242,  243,  245,  246,
         247,  248,  249,  250,  251,  252,  253,  254,  254,  255,  255,  255,  256,  256,  256,
         256,  256,  256,  256,  255,  255,  255,  254,  254,  253,  252,  251,  250,  249,  248,
         247,  246,  245,  243,  242,  241,  239,  237,  236,  234,  232,  230,  228,  226,  224,
         222,  219,  217,  215,  212,  210,  207,  204,  202,  199,  196,  193,  190,  187,  184,
         181,  178,  175,  171,  168,  165,  161,  158,  154,  150,  147,  143,  139,  136,  132,
         128,  124,  120,  116,  112,  108,  104,  100,   96,   92,   88,   83,   79,   75,   71,
          66,   62,   58,   53,   49,   44,   40,   36,   31,   27,   22,   18,   13,    9,    4 );

  dmtxErrorMessage: array [TDmtxErrorMessage] of PAnsiChar = (
     'Unknown error',
     'Unsupported character',
     'Not on byte boundary',
     'Illegal parameter value',
     'Encountered empty list',
     'Out of bounds',
     'Message too large',
     'Can''t compact non-digits',
     'Encountered unexpected scheme',
     'Encountered incomplete value list'
  );

(*** C standard functions ***)
function cmalloc(const size: integer): pointer; inline;
function ccalloc(const num, size: integer): pointer; inline;
procedure cfree(ptr: pointer); inline;
function cmemset(ptr: pointer; value: integer; num: integer): pointer; inline;
function cmemcpy(destination, source: pointer; num: integer): pointer; inline;

function max(i1,i2: integer): integer; inline;
function min(i1,i2: integer): integer; inline;

(*** dmtx ***)
procedure DMTX_CHECK_BOUNDS(l: pDmtxByteList; i: integer);


implementation

(*** C standard functions ***)

// Allocates a block of size bytes of memory, returning a pointer to the beginning of the block.
// The content of the newly allocated block of memory is not initialized, remaining with indeterminate values.
function cmalloc(const size: integer): pointer; inline;
begin
  Result := getmemory(size);
end;

function ccalloc(const num, size: integer): pointer; inline;
begin
  // getmem + zero initialisation
  Result := allocmem(num*size);
end;

// If ptr is a null pointer, the function does nothing.
procedure cfree(ptr: pointer); inline;
begin
  if ptr = nil then Exit;
  freememory(ptr);
end;

// Sets the first num bytes of the block of memory pointed by ptr to the specified value (interpreted as an unsigned char).
function cmemset(ptr: pointer; value: integer; num: integer): pointer; inline;
begin
  Result := ptr;
  FillChar(ptr^, num, byte(value));
end;

// Copies the values of num bytes from the location pointed by source directly to the memory block pointed by destination.
// destination is returned.
function cmemcpy(destination, source: pointer; num: integer): pointer; inline;
begin
  Result := destination;
  Move(source^, destination^, num);
end;

function max(i1, i2: integer): integer;
begin
  if i1>i2 then
    Result := i1
  else
    Result := i2;
end;

function min(i1, i2: integer): integer;
begin
  if i1<i2 then
    Result := i1
  else
    Result := i2;
end;

{DMTX_CHECK_BOUNDS(l,i) (assert((i) >= 0 && (i) < (l)->length && (l)->length <= (l)->capacity))}
procedure DMTX_CHECK_BOUNDS(l: pDmtxByteList; i: integer);
begin
  assert((i>=0) and (i<l^.length) and (l^.length<=l^.capacity));
end;

end.
