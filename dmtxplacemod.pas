unit dmtxplacemod;
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
 * \file dmtxplacemod.c
 * \brief Data Matrix module placement
 *)

interface

uses dmtx, dmtxsymbol;

function dmtxSymbolModuleStatus(message: pDmtxMessage;  sizeIdx: integer;  symbolRow, symbolCol: integer): integer;
function ModulePlacementEcc200(modules: pbyte;  codewords: pbyte;  sizeIdx: integer;  moduleOnColor: integer): integer;


implementation


(**
 * receives symbol row and col and returns status
 * DmtxModuleOn / !DmtxModuleOn (DmtxModuleOff)
 * DmtxModuleAssigned
 * DmtxModuleVisited
 * DmtxModuleData / !DmtxModuleData (DmtxModuleAlignment)
 * row and col are expressed in symbol coordinates, so (0,0) is the intersection of the "L"
 *)
function dmtxSymbolModuleStatus(message: pDmtxMessage;  sizeIdx: integer;  symbolRow, symbolCol: integer): integer;
var
  symbolRowReverse: integer;
  mappingRow: integer;
  mappingCol: integer;
  dataRegionRows: integer;
  dataRegionCols: integer;
  symbolRows: integer;
  mappingCols: integer;
begin
  dataRegionRows := dmtxGetSymbolAttribute(DmtxSymAttribDataRegionRows,sizeIdx);
  dataRegionCols := dmtxGetSymbolAttribute(DmtxSymAttribDataRegionCols,sizeIdx);
  symbolRows := dmtxGetSymbolAttribute(DmtxSymAttribSymbolRows,sizeIdx);
  mappingCols := dmtxGetSymbolAttribute(DmtxSymAttribMappingMatrixCols,sizeIdx);
  symbolRowReverse := symbolRows - symbolRow - 1;
  mappingRow := symbolRowReverse - 1 - 2*(symbolRowReverse div (dataRegionRows+2));
  mappingCol := symbolCol - 1 - 2*(symbolCol div (dataRegionCols+2));

  (* Solid portion of alignment patterns *)
  if (symbolRow mod (dataRegionRows+2)=0) or (symbolCol mod (dataRegionCols+2)=0) then
    Result := DmtxModuleOnRGB or (not DmtxModuleData)

  (* Horinzontal calibration bars *)
  else if (symbolRow+1) mod (dataRegionRows+2)=0 then begin
    if symbolCol and $01 <> 0 then
      Result := 0
    else
      Result := DmtxModuleOnRGB or (not DmtxModuleData);
  end

  (* Vertical calibration bars *)
  else if (symbolCol+1) mod (dataRegionCols+2)=0 then begin
    if (symbolRow and $01) <> 0 then
      Result := 0
    else
      Result := DmtxModuleOnRGB or (not DmtxModuleData);
  end

  (* Data modules *)
  else
    Result := message^.arr[mappingRow*mappingCols+mappingCol] or DmtxModuleData;
end;


(**
 * \brief  XXX
 * \param  modules
 * \param  mappingRows
 * \param  mappingCols
 * \param  row
 * \param  col
 * \param  codeword
 * \param  mask
 * \param  moduleOnColor
 * \return void
 *)
procedure PlaceModule(modules: pbyte;  mappingRows: integer;  mappingCols: integer;  row: integer;  col: integer;  codeword: pbyte;  mask: integer;  moduleOnColor: integer);
begin
  if row<0 then begin
    Inc(row, mappingRows);
    Inc(col, 4 - ((mappingRows+4) mod 8));
  end;

  if col<0 then begin
    Inc(col, mappingCols);
    Inc(row, 4 - ((mappingCols+4) mod 8));
  end;

  (* If module has already been assigned then we are decoding the pattern into codewords *)
  if (modules[row*mappingCols+col] and DmtxModuleAssigned)<>0 then begin
    if (modules[row*mappingCols+col] and moduleOnColor)<>0 then
      codeword^ := codeword^ or mask
    else
      codeword^ := codeword^ and ($FF xor mask);
  end
  (* Otherwise we are encoding the codewords into a pattern *)
  else begin
    if (codeword^ and mask)<>$00 then
      modules[row*mappingCols+col] := modules[row*mappingCols+col] or moduleOnColor;

    modules[row*mappingCols+col] := modules[row*mappingCols+col] or DmtxModuleAssigned;
  end;

  modules[row*mappingCols+col] := modules[row*mappingCols+col] or DmtxModuleVisited;
end;

(**
 * \brief  XXX
 * \param  modules
 * \param  mappingRows
 * \param  mappingCols
 * \param  row
 * \param  col
 * \param  codeword
 * \param  moduleOnColor
 * \return void
 *)
procedure PatternShapeStandard(modules: pbyte;  mappingRows: integer;  mappingCols: integer;  row: integer;  col: integer;  codeword: pbyte;  moduleOnColor: integer);
begin
  PlaceModule(modules,mappingRows,mappingCols,row-2,col-2,codeword,DmtxMaskBit1,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,row-2,col-1,codeword,DmtxMaskBit2,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,row-1,col-2,codeword,DmtxMaskBit3,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,row-1,col-1,codeword,DmtxMaskBit4,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,row-1,col,codeword,DmtxMaskBit5,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,row,col-2,codeword,DmtxMaskBit6,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,row,col-1,codeword,DmtxMaskBit7,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,row,col,codeword,DmtxMaskBit8,moduleOnColor); 
end;

(**
 * \brief  XXX
 * \param  modules
 * \param  mappingRows
 * \param  mappingCols
 * \param  codeword
 * \param  moduleOnColor
 * \return void
 *)
procedure PatternShapeSpecial1(modules: pbyte;  mappingRows: integer;  mappingCols: integer;  codeword: pbyte;  moduleOnColor: integer);
begin
  PlaceModule(modules,mappingRows,mappingCols,mappingRows-1,0,codeword,DmtxMaskBit1,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,mappingRows-1,1,codeword,DmtxMaskBit2,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,mappingRows-1,2,codeword,DmtxMaskBit3,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,0,mappingCols-2,codeword,DmtxMaskBit4,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,0,mappingCols-1,codeword,DmtxMaskBit5,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,1,mappingCols-1,codeword,DmtxMaskBit6,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,2,mappingCols-1,codeword,DmtxMaskBit7,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,3,mappingCols-1,codeword,DmtxMaskBit8,moduleOnColor); 
end;

(**
 * \brief  XXX
 * \param  modules
 * \param  mappingRows
 * \param  mappingCols
 * \param  codeword
 * \param  moduleOnColor
 * \return void
 *)
procedure PatternShapeSpecial2(modules: pbyte;  mappingRows: integer;  mappingCols: integer;  codeword: pbyte;  moduleOnColor: integer);
begin
  PlaceModule(modules,mappingRows,mappingCols,mappingRows-3,0,codeword,DmtxMaskBit1,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,mappingRows-2,0,codeword,DmtxMaskBit2,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,mappingRows-1,0,codeword,DmtxMaskBit3,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,0,mappingCols-4,codeword,DmtxMaskBit4,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,0,mappingCols-3,codeword,DmtxMaskBit5,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,0,mappingCols-2,codeword,DmtxMaskBit6,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,0,mappingCols-1,codeword,DmtxMaskBit7,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,1,mappingCols-1,codeword,DmtxMaskBit8,moduleOnColor); 
end;

(**
 * \brief  XXX
 * \param  modules
 * \param  mappingRows
 * \param  mappingCols
 * \param  codeword
 * \param  moduleOnColor
 * \return void
 *)
procedure PatternShapeSpecial3(modules: pbyte;  mappingRows: integer;  mappingCols: integer;  codeword: pbyte;  moduleOnColor: integer);
begin
  PlaceModule(modules,mappingRows,mappingCols,mappingRows-3,0,codeword,DmtxMaskBit1,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,mappingRows-2,0,codeword,DmtxMaskBit2,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,mappingRows-1,0,codeword,DmtxMaskBit3,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,0,mappingCols-2,codeword,DmtxMaskBit4,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,0,mappingCols-1,codeword,DmtxMaskBit5,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,1,mappingCols-1,codeword,DmtxMaskBit6,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,2,mappingCols-1,codeword,DmtxMaskBit7,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,3,mappingCols-1,codeword,DmtxMaskBit8,moduleOnColor); 
end;

(**
 * \brief  XXX
 * \param  modules
 * \param  mappingRows
 * \param  mappingCols
 * \param  codeword
 * \param  moduleOnColor
 * \return void
 *)
procedure PatternShapeSpecial4(modules: pbyte;  mappingRows: integer;  mappingCols: integer;  codeword: pbyte;  moduleOnColor: integer);
begin
  PlaceModule(modules,mappingRows,mappingCols,mappingRows-1,0,codeword,DmtxMaskBit1,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,mappingRows-1,mappingCols-1,codeword,DmtxMaskBit2,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,0,mappingCols-3,codeword,DmtxMaskBit3,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,0,mappingCols-2,codeword,DmtxMaskBit4,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,0,mappingCols-1,codeword,DmtxMaskBit5,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,1,mappingCols-3,codeword,DmtxMaskBit6,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,1,mappingCols-2,codeword,DmtxMaskBit7,moduleOnColor); 
  PlaceModule(modules,mappingRows,mappingCols,1,mappingCols-1,codeword,DmtxMaskBit8,moduleOnColor); 
end;

(**
 * \brief  Logical relationship between bit and module locations
 * \param  modules
 * \param  codewords
 * \param  sizeIdx
 * \param  moduleOnColor
 * \return Number of codewords read
 *)
function ModulePlacementEcc200(modules: pbyte;  codewords: pbyte;  sizeIdx: integer;  moduleOnColor: integer): integer;
var
  row, col: integer;
  mappingRows, mappingCols: integer;
begin
  assert((moduleOnColor and (DmtxModuleOnRed or DmtxModuleOnGreen or DmtxModuleOnBlue)) <> 0);

  mappingRows := dmtxGetSymbolAttribute(DmtxSymAttribMappingMatrixRows,sizeIdx);
  mappingCols := dmtxGetSymbolAttribute(DmtxSymAttribMappingMatrixCols,sizeIdx);

  (* Start in the nominal location for the 8th bit of the first character *)
  Result := 0;
  row := 4;
  col := 0;

  repeat
    (* Repeatedly first check for one of the special corner cases *)
    if (row=mappingRows) and (col=0) then begin
      PatternShapeSpecial1(modules, mappingRows, mappingCols, @codewords[Result{++}], moduleOnColor);
      Inc(Result);
    end
    else if (row=mappingRows-2) and (col=0) and (mappingCols mod 4<>0) then begin
      PatternShapeSpecial2(modules, mappingRows, mappingCols, @codewords[Result{++}], moduleOnColor);
      Inc(Result);
    end
    else if (row=mappingRows-2) and (col=0) and (mappingCols mod 8=4) then begin
      PatternShapeSpecial3(modules, mappingRows, mappingCols, @codewords[Result{++}], moduleOnColor);
      Inc(Result);
    end
    else if (row=mappingRows+4) and (col=2) and (mappingCols mod 8=0) then begin
      PatternShapeSpecial4(modules, mappingRows, mappingCols, @codewords[Result{++}], moduleOnColor);
      Inc(Result);
    end;

    (* Sweep upward diagonally, inserting successive characters *)
    repeat
      if (row<mappingRows) and (col>=0) and ((modules[row*mappingCols+col] and DmtxModuleVisited) = 0) then begin
        PatternShapeStandard(modules, mappingRows, mappingCols, row, col, @codewords[Result{++}], moduleOnColor);
        Inc(Result);
      end;
      Dec(row, 2);
      Inc(col, 2);
    until not((row>=0) and (col<mappingCols));

    Inc(row, 1);
    Inc(col, 3);

    (* Sweep downward diagonally, inserting successive characters *)
    repeat
      if (row>=0) and (col<mappingCols) and ((modules[row*mappingCols+col] and DmtxModuleVisited) = 0) then begin
        PatternShapeStandard(modules, mappingRows, mappingCols, row, col, @codewords[Result{++}], moduleOnColor);
        Inc(Result);
      end;
      Inc(row, 2);
      Dec(col, 2);
    until not((row<mappingRows) and (col>=0));

    Inc(row, 3);
    Inc(col, 1);

    (* ... until the entire modules array is scanned *)
  until not((row<mappingRows) or (col<mappingCols));

  (* If lower righthand corner is untouched then fill in the fixed pattern *)
  if (modules[mappingRows*mappingCols-1] and DmtxModuleVisited = 0) then begin
    modules[mappingRows*mappingCols-1] := modules[mappingRows*mappingCols-1] or moduleOnColor;
    modules[mappingRows*mappingCols-mappingCols-2] := modules[mappingRows*mappingCols-mappingCols-2] or moduleOnColor;
  end; (* XXX should this fixed pattern also be used in reading somehow? *)

  (* XXX compare that Result == region->dataSize here *)
  (* XXX number of codewords read off *)
end;

end.
