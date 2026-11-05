unit dmtxsymbol;
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
 * \file dmtxsymbol.c
 * \brief Data Matrix symbol attributes
 *)

interface

uses dmtx;

function dmtxGetSymbolAttribute(attribute: DmtxSymAttribute;  sizeIdx: integer): integer;
function dmtxGetBlockDataSize(sizeIdx: integer;  blockIdx: integer): integer;
function FindSymbolSize(dataWords: integer;  sizeIdxRequest: DmtxSymbolSize): integer;


implementation

(**
 * \brief  Retrieve property based on symbol size
 * \param  attribute
 * \param  sizeIdx
 * \return Attribute value
 *)
function dmtxGetSymbolAttribute(attribute: DmtxSymAttribute;  sizeIdx: integer): integer;
const
  symbolRows: array [0..29] of integer = (10,12,14,16,18,20,22,24,26,32,36,40,44,48,52,64,72,80,88,96,104,120,132,144,8,8,12,12,16,16);
  symbolCols: array [0..29] of integer = (10,12,14,16,18,20,22,24,26,32,36,40,44,48,52,64,72,80,88,96,104,120,132,144,18,32,26,36,36,48);
  dataRegionRows: array [0..29] of integer = (8,10,12,14,16,18,20,22,24,14,16,18,20,22,24,14,16,18,20,22,24,18,20,22,6,6,10,10,14,14);
  dataRegionCols: array [0..29] of integer = (8,10,12,14,16,18,20,22,24,14,16,18,20,22,24,14,16,18,20,22,24,18,20,22,16,14,24,16,16,22);
  horizDataRegions: array [0..29] of integer = (1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,4,4,4,4,4,4,6,6,6,1,2,1,2,2,2);
  interleavedBlocks: array [0..29] of integer = (1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,4,4,4,4,6,6,8,10,1,1,1,1,1,1);
  symbolDataWords: array [0..29] of integer = (3,5,8,12,18,22,30,36,44,62,86,114,144,174,204,280,368,456,576,696,816,1050,1304,1558,5,10,16,22,32,49);
  blockErrorWords: array [0..29] of integer = (5,7,10,12,14,18,20,24,28,36,42,48,56,68,42,56,36,48,56,68,56,68,62,62,7,11,14,18,24,28);
  blockMaxCorrectable: array [0..29] of integer = (2,3,5,6,7,9,10,12,14,18,21,24,28,34,21,28,18,24,28,34,28,34,31,31,3,5,7,9,12,14);
begin
  if (sizeIdx < 0) or (sizeIdx >= DmtxSymbolSquareCount+DmtxSymbolRectCount) then
    Result := DmtxUndefined
  else
    case attribute of
      DmtxSymAttribSymbolRows:
        Result := symbolRows[sizeIdx];
      DmtxSymAttribSymbolCols:
        Result := symbolCols[sizeIdx];
      DmtxSymAttribDataRegionRows:
        Result := dataRegionRows[sizeIdx];
      DmtxSymAttribDataRegionCols:
        Result := dataRegionCols[sizeIdx];
      DmtxSymAttribHorizDataRegions:
        Result := horizDataRegions[sizeIdx];
      DmtxSymAttribVertDataRegions:
        if sizeIdx < DmtxSymbolSquareCount then
          Result := horizDataRegions[sizeIdx]
        else
          Result := 1;
      DmtxSymAttribMappingMatrixRows:
        Result := dataRegionRows[sizeIdx]*dmtxGetSymbolAttribute(DmtxSymAttribVertDataRegions,sizeIdx);
      DmtxSymAttribMappingMatrixCols:
        Result := dataRegionCols[sizeIdx]*horizDataRegions[sizeIdx];
      DmtxSymAttribInterleavedBlocks:
        Result := interleavedBlocks[sizeIdx];
      DmtxSymAttribBlockErrorWords:
        Result := blockErrorWords[sizeIdx];
      DmtxSymAttribBlockMaxCorrectable:
        Result := blockMaxCorrectable[sizeIdx];
      DmtxSymAttribSymbolDataWords:
        Result := symbolDataWords[sizeIdx];
      DmtxSymAttribSymbolErrorWords:
        Result := blockErrorWords[sizeIdx]*interleavedBlocks[sizeIdx];
      DmtxSymAttribSymbolMaxCorrectable:
        Result := blockMaxCorrectable[sizeIdx]*interleavedBlocks[sizeIdx];
      else
        Result := DmtxUndefined;
    end;{case}
end;

(**
 * \brief  Retrieve symbol index from rows and columns
 * \param  rows
 * \param  cols
 * \return sizeIdx value
 *)
function getSizeIdxFromSymbolDimension(rows, cols: integer): integer;
var
  i: integer;
  symbolRows, symbolCols: integer;
begin
  for i:=0 to 29 do begin
    symbolRows := dmtxGetSymbolAttribute(DmtxSymAttribSymbolRows,i);
    symbolCols := dmtxGetSymbolAttribute(DmtxSymAttribSymbolCols,i);
    if (rows=symbolRows) and (cols=symbolCols) then begin
      Result := i;
      Exit;
    end;
  end;
  Result := -1;
end;

(**
 * \brief  Retrieve data size for a specific symbol size and block number
 * \param  sizeIdx
 * \param  blockIdx
 * \return Attribute value
 *)
function dmtxGetBlockDataSize(sizeIdx: integer;  blockIdx: integer): integer;
var
  symbolDataWords: integer;
  interleavedBlocks: integer;
  count: integer;
begin
  symbolDataWords := dmtxGetSymbolAttribute(DmtxSymAttribSymbolDataWords,sizeIdx);
  interleavedBlocks := dmtxGetSymbolAttribute(DmtxSymAttribInterleavedBlocks,sizeIdx);
  if (symbolDataWords<1) or (interleavedBlocks<1) then
    Result := DmtxUndefined
  else begin
    //(int)(symbolDataWords/interleavedBlocks);
    count := symbolDataWords div interleavedBlocks;
    if (sizeIdx=ord(DmtxSymbol144x144)) and (blockIdx<8) then
      Result := count+1
    else
      Result := count;
  end;
end;

(**
 * \brief  Determine symbol size based on data size and requested properties
 * \param  dataWords
 * \param  sizeIdxRequest
 * \return Symbol size index (or DmtxUndefined if none)
 *)
function FindSymbolSize(dataWords: integer;  sizeIdxRequest: DmtxSymbolSize): integer;
var
  idxBeg, idxEnd: integer;
begin
  if dataWords <= 0 then
    Result := DmtxUndefined
  else if (sizeIdxRequest=DmtxSymbolSquareAuto) or (sizeIdxRequest=DmtxSymbolRectAuto) then begin
    if sizeIdxRequest=DmtxSymbolSquareAuto then begin
      idxBeg := 0;
      idxEnd := DmtxSymbolSquareCount;
    end
    else begin
      idxBeg := DmtxSymbolSquareCount;
      idxEnd := DmtxSymbolSquareCount+DmtxSymbolRectCount;
    end;

    Result := idxBeg;
    while Result < idxEnd do begin
      if dmtxGetSymbolAttribute(DmtxSymAttribSymbolDataWords, Result) >= dataWords then
        break;
      Inc(Result);
    end;

    if Result = idxEnd then
      Result := DmtxUndefined;
  end
  else
    Result := ord(sizeIdxRequest);

  if dataWords > dmtxGetSymbolAttribute(DmtxSymAttribSymbolDataWords, Result) then
    Result := DmtxUndefined;
end;

end.
