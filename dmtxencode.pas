unit dmtxencode;
(**
 * libdmtx - Data Matrix Encoding/Decoding Library
 * Copyright 2008, 2009 Mike Laughton. All rights reserved.
 * Copyright 2012-2016 Vadim A. Misbakh-Soloviov. All rights reserved.
 *
 * See LICENSE file in the main project directory for full
 * terms of use and distribution.
 *
 * Contact:
 * Vadim A. Misbakh-Soloviov <dmtx@mva.name>
 * Mike Laughton <mike@dragonflylogic.com>
 *
 * C to Pascal translation by Ladislav Karrach (with help of c2pas32)
 *
 * \file dmtxencode.c
 * \brief Base encoding logic
 *)
{$POINTERMATH ON}

interface

uses
  dmtx, dmtxbytelist, dmtximage, dmtxmatrix3, dmtxmessage, dmtxsymbol, dmtxplacemod, dmtxreedsol;


function dmtxEncodeCreate(): pDmtxEncode;
function dmtxEncodeDestroy(var enc: pDmtxEncode): DmtxPassFail;
function dmtxEncodeSetProp(enc: pDmtxEncode;  prop: DmtxProperty;  value: integer): DmtxPassFail;
function dmtxEncodeDataMatrix(enc: pDmtxEncode;  inputSize: integer;  inputString: pAnsiChar): DmtxPassFail;
function dmtxEncodeDataMosaic(enc: pDmtxEncode;  inputSize: integer;  inputString: pAnsiChar): DmtxPassFail;


implementation

{ISDIGIT(n) (n > 47 && n < 58)}
function ISDIGIT(n: integer): boolean;
begin
  Result := (n>47) and (n<58);
end;

{$I dmtxencodestream.inc}
{$I dmtxencodescheme.inc}

(**
 * \brief  Initialize encode struct with default values
 * \return Initialized DmtxEncode struct
 *)
function dmtxEncodeCreate(): pDmtxEncode;
begin
  Result := ccalloc(1, sizeof(tDmtxEncode));
  if Result = nil then Exit;

  Result^.scheme := DmtxSchemeAscii;
  Result^.sizeIdxRequest := DmtxSymbolSquareAuto;
  Result^.marginSize := 10;
  Result^.moduleSize := 5;
  Result^.pixelPacking := DmtxPack24bppRGB;
  Result^.imageFlip := ord(DmtxFlipNone);
  Result^.rowPadBytes := 0;
  dmtxMatrix3Identity(Result^.xfrm);

  (* Initialize background color to white *)
  (* enc.region.gradient.ray.p.R = 255.0;
     enc.region.gradient.ray.p.G = 255.0;
     enc.region.gradient.ray.p.B = 255.0; *)

  (* Initialize foreground color to black *)
  (* enc.region.gradient.tMin = 0.0;
     enc.region.gradient.tMax = xyz; *)
end;

(**
 * \brief  Deinitialize encode struct
 * \param  enc
 * \return void
 *)
function dmtxEncodeDestroy(var enc: pDmtxEncode): DmtxPassFail;
begin
  if enc = nil then
    Result := DmtxFail
  else begin
    (* Free pixel array allocated in dmtxEncodeDataMatrix() *)
    if (enc^.image <> nil) and (enc^.image^.pxl <> nil) then begin
      cfree(enc^.image^.pxl);
      enc^.image^.pxl := nil;
    end;
    dmtxImageDestroy(enc^.image);
    dmtxMessageDestroy(enc^.message);
    cfree(enc);
    enc := nil;
    Result := DmtxPass;
  end;
end;

(**
 * \brief  Set encoding behavior property
 * \param  enc
 * \param  prop
 * \param  value
 * \return DmtxPass | DmtxFail
 *)
function dmtxEncodeSetProp(enc: pDmtxEncode;  prop: DmtxProperty;  value: integer): DmtxPassFail;
begin
  case prop of
    (* Encoding details *)
    DmtxPropScheme:
      enc^.scheme := DmtxScheme(value);
    DmtxPropSizeRequest:
      begin
      if value = ord(DmtxSymbolShapeAuto) then Exit(DmtxFail);
      enc^.sizeIdxRequest := DmtxSymbolSize(value);
      end;

    (* Presentation details *)
    DmtxPropMarginSize:
      enc^.marginSize := value;
    DmtxPropModuleSize:
      enc^.moduleSize := value;

    (* Image properties *)
    DmtxPropPixelPacking:
      enc^.pixelPacking := DmtxPackOrder(value);
    DmtxPropImageFlip:
      enc^.imageFlip := value;
    DmtxPropRowPadBytes:
      enc^.rowPadBytes := value;
  end;{case}
  Result := DmtxPass;
end;

(**
 * \brief  Get encoding behavior property
 * \param  enc
 * \param  prop
 * \return value
 *)
function dmtxEncodeGetProp(enc: pDmtxEncode;  prop: DmtxProperty): integer;
begin
  case prop of
    DmtxPropMarginSize:
      Result := enc^.marginSize;
    DmtxPropModuleSize:
      Result := enc^.moduleSize;
    DmtxPropScheme:
      Result := ord(enc^.scheme);
    else
      Result := DmtxUndefined;
  end;{case}
end;

(**
 * \brief  Convert input into message using specific encodation scheme
 * \param  buf
 * \param  inputString
 * \param  inputSize
 * \param  scheme
 * \param  sizeIdx
 * \return Count of encoded data words
 *
 * Future: pass DmtxEncode to this function with an error reason field, which
 *         goes to EncodeSingle... too
 *)
function EncodeDataCodewords(input: pDmtxByteList;  output: pDmtxByteList;  sizeIdxRequest: DmtxSymbolSize;  scheme: DmtxScheme): integer;
begin
  (* Encode input string into data codewords *)
  case scheme of
    DmtxSchemeAutoBest:
{TODO: Translate from C "dmtxencodeoptimize.c"}
      //Result := EncodeOptimizeBest(input,output,sizeIdxRequest);
      ;
    DmtxSchemeAutoFast:
      Result := DmtxUndefined; (* EncodeAutoFast(input, output, sizeIdxRequest, passFail); *)
    else
      Result := EncodeSingleScheme(input, output, sizeIdxRequest, scheme);
  end;{case}
end;

(**
 * \brief  Write encoded message to image
 * \param  enc
 * \return void
 *)
procedure PrintPattern(enc: pDmtxEncode);
var
  i, j: integer;
  symbolRow, symbolCol: integer;
  pixelRow, pixelCol: integer;
  moduleStatus: integer;
  rowSize: size_t;
  height: size_t;
  bitsPerPixel: integer;
  rgb: array [0..2] of integer;
  sxy: double;
  txy: double;
  m1: tDmtxMatrix3;
  m2: tDmtxMatrix3;
  vIn: tDmtxVector2;
  vOut: tDmtxVector2;
begin
  txy := enc^.marginSize;
  sxy := 1.0 / enc^.moduleSize;

  dmtxMatrix3Translate(m1, -txy, -txy);
  dmtxMatrix3Scale(m2, sxy, -sxy);
  dmtxMatrix3Multiply(enc^.xfrm, m1, m2);

  dmtxMatrix3Translate(m1, txy, txy);
  dmtxMatrix3Scale(m2, enc^.moduleSize, enc^.moduleSize);
  dmtxMatrix3Multiply(enc^.rxfrm, m2, m1);

  rowSize := dmtxImageGetProp(enc^.image, DmtxPropRowSizeBytes);
  height := dmtxImageGetProp(enc^.image, DmtxPropHeight);
  bitsPerPixel := dmtxImageGetProp(enc^.image, DmtxPropBitsPerPixel);

  cmemset(enc^.image^.pxl, $FF, rowSize * height);

  for symbolRow:=0 to Pred(enc^.region.symbolRows) do begin
    for symbolCol:=0 to Pred(enc^.region.symbolCols) do begin
      vIn.X := symbolCol;
      vIn.Y := symbolRow;
      dmtxMatrix3VMultiply(@vOut, @vIn, enc^.rxfrm);
      pixelCol := Trunc{integer}(vOut.X);
      pixelRow := Trunc{integer}(vOut.Y);

      moduleStatus := dmtxSymbolModuleStatus(enc^.message, enc^.region.sizeIdx, symbolRow, symbolCol);

      for i:=pixelRow to Pred(pixelRow+enc^.moduleSize) do
        for j:=pixelCol to Pred(pixelCol+enc^.moduleSize) do begin

          if moduleStatus and DmtxModuleOnRed <> $00 then
            rgb[0] := 0
          else
            rgb[0] := $FF;

          if moduleStatus and DmtxModuleOnGreen <> $00 then
            rgb[1] := 0
          else
            rgb[1] := $FF;

          if moduleStatus and DmtxModuleOnBlue <> $00 then
            rgb[2] := 0
          else
            rgb[2] := $FF;

          (* dmtxImageSetRgb(enc->image, j, i, rgb); *)
          dmtxImageSetPixelValue(enc^.image, j, i, 0, rgb[0]);
          if bitsPerPixel > 8 then begin
            dmtxImageSetPixelValue(enc^.image, j, i, 1, rgb[1]);
            dmtxImageSetPixelValue(enc^.image, j, i, 2, rgb[2]);
          end;
        end;
    end;
  end;
end;

(**
 * \brief  Convert message into Data Matrix image
 * \param  enc
 * \param  inputSize
 * \param  inputString
 * \param  sizeIdxRequest
 * \return DmtxPass | DmtxFail
 *)
function dmtxEncodeDataMatrix(enc: pDmtxEncode;  inputSize: integer;  inputString: pAnsiChar): DmtxPassFail;
var
  sizeIdx: integer;
  width: integer;
  height: integer;
  bitsPerPixel: integer;
  pxl: pbyte;
  outputStorage: array [0..4095] of DmtxByte;
  output: tDmtxByteList;
  input: tDmtxByteList;
begin
  Result := DmtxFail;

  output := dmtxByteListBuild(pDmtxByte(@outputStorage), sizeof(outputStorage));
  input := dmtxByteListBuild(pDmtxByte(inputString), inputSize);

  input.length := inputSize;

  (* Future: stream = StreamInit() ... *)
  (* Future: EncodeDataCodewords(&stream) ... *)

  (* Encode input string into data codewords *)
  sizeIdx := EncodeDataCodewords(@input, @output, enc^.sizeIdxRequest, enc^.scheme);
  if (sizeIdx=DmtxUndefined) or (output.length<=0) then Exit;

  (* EncodeDataCodewords() should have updated any auto sizeIdx to a real one *)
  assert((sizeIdx<>ord(DmtxSymbolSquareAuto)) and (sizeIdx<>ord(DmtxSymbolRectAuto)));
  (* XXX we can remove a lot of this redundant data *)
  enc^.region.sizeIdx := sizeIdx;
  enc^.region.symbolRows := dmtxGetSymbolAttribute(DmtxSymAttribSymbolRows,sizeIdx);
  enc^.region.symbolCols := dmtxGetSymbolAttribute(DmtxSymAttribSymbolCols,sizeIdx);
  enc^.region.mappingRows := dmtxGetSymbolAttribute(DmtxSymAttribMappingMatrixRows,sizeIdx);
  enc^.region.mappingCols := dmtxGetSymbolAttribute(DmtxSymAttribMappingMatrixCols,sizeIdx);

  (* Allocate memory for message and array *)
  enc^.message := dmtxMessageCreate(sizeIdx,DmtxFormatMatrix);
  enc^.message^.padCount := 0;  (* XXX this needs to be added back *)
  cmemcpy(enc^.message^.code, output.b, output.length);

  (* Generate error correction codewords *)
  RsEncode(enc^.message, enc^.region.sizeIdx);

  (* Module placement in region *)
  ModulePlacementEcc200(enc^.message^.arr, enc^.message^.code, enc^.region.sizeIdx, DmtxModuleOnRGB);

  width := 2*enc^.marginSize + (enc^.region.symbolCols*enc^.moduleSize);
  height := 2*enc^.marginSize + (enc^.region.symbolRows*enc^.moduleSize);
  bitsPerPixel := GetBitsPerPixel(enc^.pixelPacking);
  if bitsPerPixel=DmtxUndefined then Exit;
  assert(bitsPerPixel mod 8=0);

  (* Allocate memory for the image to be generated *)
  pxl := cmalloc(width*height*(bitsPerPixel div 8) + enc^.rowPadBytes);
  if pxl=nil then begin
    //perror('pixel malloc error'); 
    Exit;
  end;

  enc^.image := dmtxImageCreate(pxl, width, height, enc^.pixelPacking);
  if enc^.image = nil then begin
    //perror('image malloc error'); 
    Exit;
  end;

  dmtxImageSetProp(enc^.image, DmtxPropImageFlip, enc^.imageFlip);
  dmtxImageSetProp(enc^.image, DmtxPropRowPadBytes, enc^.rowPadBytes);

  (* Insert finder and aligment pattern modules *)
  PrintPattern(enc);

  Result := DmtxPass;
end;

(**
 * \brief  Convert message into Data Mosaic image
 *
 *  1) count how many codewords it would take to encode the whole thing
 *  2) take ceiling N of codeword count divided by 3
 *  3) using minimum symbol size that can accomodate N codewords:
 *  4) create several barcodes over iterations of increasing numbers of
 *     input codewords until you go one too
 *  5) if codewords remain after filling R, G, and B barcodes then go back
 *     to 3 and try with next larger size
 *  6) take the 3 different images you created and write out a new barcode
 *
 * \param  enc
 * \param  inputSize
 * \param  inputString
 * \param  sizeIdxRequest
 * \return DmtxPass | DmtxFail
 *)
function dmtxEncodeDataMosaic(enc: pDmtxEncode;  inputSize: integer;  inputString: pAnsiChar): DmtxPassFail;
var
  inputStringR, inputStringG, inputStringB: pAnsiChar;
  tmpInputSize: integer;
  inputSizeR, inputSizeG, inputSizeB: integer;
  sizeIdxAttempt: integer;
  sizeIdxFirst: integer;
  sizeIdxLast: integer;
  row, col: integer;
  mappingRows, mappingCols: integer;
  encR, encG, encB: pDmtxEncode;
begin
  Result := DmtxFail;

  (* Use 1/3 (ceiling) of inputSize establish input size target *)
  tmpInputSize := (inputSize+2) div 3;
  inputSizeR := tmpInputSize;
  inputSizeG := tmpInputSize;
  inputSizeB := inputSize - (inputSizeR+inputSizeG);

  inputStringR := inputString;
  inputStringG := inputStringR+inputSizeR;
  inputStringB := inputStringG+inputSizeG;

  (* Use 1/3 (floor) of dataWordCount establish first symbol size attempt *)
  sizeIdxFirst := FindSymbolSize(tmpInputSize, enc^.sizeIdxRequest);
  if sizeIdxFirst=DmtxUndefined then Exit;

  (* Set the last possible symbol size for this symbol shape or specific size request *)
  if enc^.sizeIdxRequest=DmtxSymbolSquareAuto then
    sizeIdxLast := DmtxSymbolSquareCount-1
  else if enc^.sizeIdxRequest=DmtxSymbolRectAuto then
    sizeIdxLast := DmtxSymbolSquareCount+DmtxSymbolRectCount-1
  else
    sizeIdxLast := sizeIdxFirst;

  encR := nil; encG := nil; encB := nil;
  (* Try increasing symbol sizes until 3 of them can hold all input values *)
  for sizeIdxAttempt:=sizeIdxFirst to sizeIdxLast do begin
    dmtxEncodeDestroy(encR);
    dmtxEncodeDestroy(encG);
    dmtxEncodeDestroy(encB);
    encR := dmtxEncodeCreate();
    encG := dmtxEncodeCreate();
    encB := dmtxEncodeCreate();

    (* Copy all settings from master DmtxEncode, including pointer to image
       and message, which is initially null *)
    encR^ := enc^;
    encG^ := enc^;
    encB^ := enc^;

    dmtxEncodeSetProp(encR,DmtxPropSizeRequest,sizeIdxAttempt);
    dmtxEncodeSetProp(encG,DmtxPropSizeRequest,sizeIdxAttempt);
    dmtxEncodeSetProp(encB,DmtxPropSizeRequest,sizeIdxAttempt);

    (* RED LAYER - Holds temporary copy *)
    dmtxEncodeDataMatrix(encR,inputSizeR,inputStringR);
    if encR^.region.sizeIdx<>sizeIdxAttempt then continue;

    (* GREEN LAYER - Holds temporary copy *)
    dmtxEncodeDataMatrix(encG,inputSizeG,inputStringG);
    if encG^.region.sizeIdx<>sizeIdxAttempt then continue;

    (* BLUE LAYER - Holds temporary copy *)
    dmtxEncodeDataMatrix(encB,inputSizeB,inputStringB);
    if encB^.region.sizeIdx<>sizeIdxAttempt then continue;

    (* If we get this  we found a fit *)
    break;
  end;

  if (encR=nil) or (encG=nil) or (encB=nil) then begin
    dmtxEncodeDestroy(encR);
    dmtxEncodeDestroy(encG);
    dmtxEncodeDestroy(encB);
    Exit;
  end;

  (* Now we have the correct sizeIdxAttempt, and they all fit into the desired size *)

  (* Perform the red portion of the final encode to set internals correctly *)
  dmtxEncodeSetProp(enc,DmtxPropSizeRequest,sizeIdxAttempt);
  dmtxEncodeDataMatrix(enc,inputSizeR,inputStringR);

  (* Zero out the array and overwrite the bits in 3 passes *)
  mappingRows := dmtxGetSymbolAttribute(DmtxSymAttribMappingMatrixRows,sizeIdxAttempt);
  mappingCols := dmtxGetSymbolAttribute(DmtxSymAttribMappingMatrixCols,sizeIdxAttempt);
  assert(assigned(enc^.message));
  cmemset(enc^.message^.arr, $00, SizeOf(Byte) * enc^.region.mappingRows * enc^.region.mappingCols);

  ModulePlacementEcc200(enc^.message^.arr, encR^.message^.code, sizeIdxAttempt, DmtxModuleOnRed);

  (* Reset DmtxModuleAssigned and DMX_MODULE_VISITED bits *)
  for row:=0 to Pred(mappingRows) do
    for col:=0 to Pred(mappingCols) do
      enc^.message^.arr[row*mappingCols+col] := enc^.message^.arr[row*mappingCols+col] and (($FF xor (DmtxModuleAssigned or DmtxModuleVisited)));

  ModulePlacementEcc200(enc^.message^.arr, encG^.message^.code, sizeIdxAttempt, DmtxModuleOnGreen);

  (* Reset DmtxModuleAssigned and DMX_MODULE_VISITED bits *)
  for row:=0 to Pred(mappingRows) do
    for col:=0 to Pred(mappingCols) do
      enc^.message^.arr[row*mappingCols+col] := enc^.message^.arr[row*mappingCols+col] and (($FF xor (DmtxModuleAssigned or DmtxModuleVisited)));

  ModulePlacementEcc200(enc^.message^.arr, encB^.message^.code, sizeIdxAttempt, DmtxModuleOnBlue);

  (* Destroy encR, encG, and encB *)
  dmtxEncodeDestroy(encR);
  dmtxEncodeDestroy(encG);
  dmtxEncodeDestroy(encB);

  PrintPattern(enc);

  Result:= DmtxPass;
end;

end.
