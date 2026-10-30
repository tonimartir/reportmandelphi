unit dmtxmessage;
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
 * \file dmtxmessage.c
 * \brief Data message handling
 *)

interface

uses dmtx, dmtxsymbol;

function dmtxMessageCreate(sizeIdx: integer;  symbolFormat: integer): pDmtxMessage;
function dmtxMessageDestroy(var msg: pDmtxMessage): DmtxPassFail;

implementation

(**
 * \brief  Free memory previously allocated for message
 * \param  message
 * \return void
 *)
function dmtxMessageDestroy(var msg: pDmtxMessage): DmtxPassFail;
begin
  if msg = nil then
    Result := DmtxFail
  else begin
    if msg^.arr <> nil then
      cfree(msg^.arr);
    if msg^.code <> nil then
      cfree(msg^.code);
    if msg^.output <> nil then
      cfree(msg^.output);
    cfree(msg);
    msg := nil;
    Result := DmtxPass;
  end;
end;

(**
 * \brief  Allocate memory for message
 * \param  sizeIdx
 * \param  symbolFormat DmtxFormatMatrix | DmtxFormatMosaic
 * \return Address of allocated memory
 *)
function dmtxMessageCreate(sizeIdx: integer;  symbolFormat: integer): pDmtxMessage;
var
  mappingRows: integer;
  mappingCols: integer;
begin
  assert((symbolFormat=DmtxFormatMatrix) or (symbolFormat=DmtxFormatMosaic));

  mappingRows := dmtxGetSymbolAttribute(DmtxSymAttribMappingMatrixRows,sizeIdx);
  mappingCols := dmtxGetSymbolAttribute(DmtxSymAttribMappingMatrixCols,sizeIdx);

  Result := ccalloc(1, sizeof(TDmtxMessage));
  if Result = nil then Exit;

  Result^.arraySize := SizeOf(byte{unsigned char}) * mappingRows * mappingCols;
  Result^.arr := ccalloc(1, Result^.arraySize);
  if Result^.arr = nil then begin
    //perror('Calloc failed'); 
    dmtxMessageDestroy(Result);
  end
  else begin
    Result^.codeSize := sizeof(byte{unsignedchar}) * dmtxGetSymbolAttribute(DmtxSymAttribSymbolDataWords,sizeIdx) + dmtxGetSymbolAttribute(DmtxSymAttribSymbolErrorWords,sizeIdx);

    if symbolFormat=DmtxFormatMosaic then
      Result^.codeSize := Result^.codeSize * 3;

    Result^.code := ccalloc(Result^.codeSize, sizeof(byte{unsignedchar}));
    if Result^.code = nil then begin
      //perror('Calloc failed');
      dmtxMessageDestroy(Result);
    end
    else begin
      (* XXX not sure if this is the right place or even the right approach.
         Trying to allocate memory for the decoded data stream and will
         initially assume that decoded data will not be larger than 2x encoded data *)
      Result^.outputSize := sizeof(byte{unsignedchar}) * Result^.codeSize * 10;
      Result^.output := ccalloc(Result^.outputSize, sizeof(byte{unsignedchar}));
      if Result^.output = nil then begin
        //perror('Calloc failed');
        dmtxMessageDestroy(Result);
      end;
    end;
  end;
end;

end.
