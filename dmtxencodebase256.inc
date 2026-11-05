//unit dmtxencodebase256;

(**
 * libdmtx - Data Matrix Encoding/Decoding Library
 * Copyright 2011 Mike Laughton. All rights reserved.
 * Copyright 2012-2016 Vadim A. Misbakh-Soloviov. All rights reserved.
 *
 * See LICENSE file in the main project directory for full
 * terms of use and distribution.
 *
 * Contact:
 * Vadim A. Misbakh-Soloviov <dmtx@mva.name>
 * Mike Laughton <mike@dragonflylogic.com>
 *
 * \file dmtxencodebase256.c
 * \brief Base 256 encoding rules
 *)
(**
 *
 *
 *)

//interface

//implementation

(**
 * \brief  Randomize 255 state
 * \param  value
 * \param  position
 * \return Randomized value
 *)
function Randomize255State(value: DmtxByte;  position: integer): DmtxByte;
var
  pseudoRandom: integer;
  tmp: integer;
begin
  pseudoRandom := (149*position) mod 255 + 1;
  tmp := value+pseudoRandom;
  if tmp<=255 then
    Result := tmp
  else
    Result := tmp-256;
end;

(**
 * \brief  Unrandomize 255 state
 * \param  value
 * \param  idx
 * \return Unrandomized value
 *)
function UnRandomize255State(value: byte;  idx: integer): byte;
var
  pseudoRandom: integer;
  tmp: integer;
begin
  pseudoRandom := (149*idx) mod 255 + 1;
  tmp := value-pseudoRandom;
  if tmp<0 then
    Inc(tmp, 256);
  assert((tmp>=0) and (tmp<256));
  Result := Byte(tmp);
end;

(**
 * insert element at beginning of chain, shifting all following elements forward by one
 * used for binary length changes
 *)
procedure Base256OutputChainInsertFirst(stream: pDmtxEncodeStream);
var
  value: DmtxByte;
  passFail: DmtxPassFail;
  i: integer;
  chainStart: integer;
begin
  chainStart := stream^.output^.length - stream^.outputChainWordCount;

  dmtxByteListPush(stream^.output,0,passFail);
  if passFail=DmtxPass then begin
    for i:=stream^.output^.length-1 downto chainStart+1 do begin
      value := UnRandomize255State(stream^.output^.b[i-1], i);
      stream^.output^.b[i] := Randomize255State(value, i+1);
    end;
    Inc(stream^.outputChainWordCount);
  end
  else
    StreamMarkFatal(stream, DmtxErrorUnknown);
end;

(**
 * remove first element from chain, shifting all following elements back by one
 * used for binary length changes end condition
 *)
procedure Base256OutputChainRemoveFirst(stream: pDmtxEncodeStream);
var
  value: DmtxByte;
  passFail: DmtxPassFail;
  i: integer;
  chainStart: integer;
begin
  chainStart := stream^.output^.length - stream^.outputChainWordCount;

  for i:=chainStart to Pred(stream^.output^.length-1) do begin
    value := UnRandomize255State(stream^.output^.b[i+1], i+2);
    stream^.output^.b[i] := Randomize255State(value, i+1);
  end;

  dmtxByteListPop(stream^.output, passFail);
  if passFail=DmtxPass then
    Dec(stream^.outputChainWordCount)
  else
    StreamMarkFatal(stream, DmtxErrorUnknown);
end;

procedure UpdateBase256ChainHeader(stream: pDmtxEncodeStream;  perfectSizeIdx: integer);
var
  headerIndex: integer;
  outputLength: integer;
  headerByteCount: integer;
  symbolDataWords: integer;
  perfectFit: Boolean;
  headerValue0: DmtxByte;
  headerValue1: DmtxByte;
begin
  outputLength := stream^.outputChainValueCount;
  headerIndex := stream^.output^.length-stream^.outputChainWordCount;
  headerByteCount := stream^.outputChainWordCount-stream^.outputChainValueCount;
  perfectFit := perfectSizeIdx<>DmtxUndefined;

  (*
   * If requested perfect fit verify symbol capacity against final length
   *)
  if perfectFit then begin
    symbolDataWords := dmtxGetSymbolAttribute(DmtxSymAttribSymbolDataWords, perfectSizeIdx);
    if symbolDataWords<>stream^.output^.length-1 then begin
      StreamMarkFatal(stream,DmtxErrorUnknown);
      exit;
    end;
  end;

  (*
   * Adjust header to hold correct number of bytes, not worrying about the
   * values held there until below. Note: Header bytes are not considered
   * scheme "values" so we can insert or remove them without updating the
   * outputChainValueCount.
   *)
  if (headerByteCount=0) and (stream^.outputChainWordCount=0) then begin
    (* No output words written yet -- insert single header byte *)
    StreamOutputChainAppend(stream,0);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
    Inc(headerByteCount);
  end
  else if not perfectFit and (headerByteCount=1) and (outputLength>249) then begin
    (* Beyond 249 bytes requires a second header byte *)
    Base256OutputChainInsertFirst(stream);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
    Inc(headerByteCount);
  end
  else if perfectFit and (headerByteCount=2) then begin
    (* Encoding to exact end of symbol only requires single byte *)
    Base256OutputChainRemoveFirst(stream);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
    Dec(headerByteCount);
  end;

  (*
   * Encode header byte(s) with current length
   *)
  if not perfectFit and (headerByteCount=1) and (outputLength<=249) then begin
    (* Normal condition for chain length < 250 bytes *)
    headerValue0 := Randomize255State(outputLength,headerIndex+1);
    StreamOutputSet(stream, headerIndex, headerValue0);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
  end
  else if not perfectFit and (headerByteCount=2) and (outputLength>249) then begin
    (* Normal condition for chain length >= 250 bytes *)
    headerValue0 := Randomize255State(outputLength div 250+249, headerIndex+1);
    StreamOutputSet(stream,headerIndex,headerValue0);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
    headerValue1 := Randomize255State(outputLength mod 250,headerIndex+2);
    StreamOutputSet(stream, headerIndex+1, headerValue1);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
  end
  else if perfectFit and (headerByteCount=1) then begin
    (* Special condition when Base 256 stays in effect to end of symbol *)
    headerValue0 := Randomize255State(0,headerIndex+1); (* XXX replace magic value 0? *)
    StreamOutputSet(stream, headerIndex, headerValue0);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
  end
  else begin
    StreamMarkFatal(stream,DmtxErrorUnknown);
    exit;
  end;
end;


procedure AppendValueBase256(stream: pDmtxEncodeStream;  value: DmtxByte);
begin
  if stream^.currentScheme<>DmtxSchemeBase256 then begin StreamMarkFatal(stream, DmtxErrorUnexpectedScheme); Exit; end; //CHKSCHEME(DmtxSchemeBase256);
  StreamOutputChainAppend(stream, Randomize255State(value, stream^.output^.length+1));
  if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
  Inc(stream^.outputChainValueCount);
  UpdateBase256ChainHeader(stream,DmtxUndefined);
  if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
end;

procedure EncodeNextChunkBase256(stream: pDmtxEncodeStream); 
var
  value: DmtxByte;
begin
  if StreamInputHasNext(stream) then begin
    value := StreamInputAdvanceNext(stream);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
    AppendValueBase256(stream,value);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
  end;
end;

(**
 * check remaining symbol capacity and remaining codewords
 * if the chain can finish perfectly at the end of symbol data words there is a
 * special one-byte length header value that can be used (i think ... read the
 * spec again before commiting to anything)
 *)
procedure CompleteIfDoneBase256(stream: pDmtxEncodeStream;  sizeIdxRequest: DmtxSymbolSize);
var
  sizeIdx: integer;
  headerByteCount: integer;
  outputLength: integer;
  symbolRemaining: integer;
begin
  if stream^.status=DmtxStatusComplete then Exit;

  if not StreamInputHasNext(stream) then begin
    headerByteCount := stream^.outputChainWordCount - stream^.outputChainValueCount;
    assert((headerByteCount=1)or(headerByteCount=2)); 

    (* Check for special case where every last symbol word is used *)
    if headerByteCount=2 then begin
      (* Find symbol size as if headerByteCount was only 1 *)
      outputLength := stream^.output^.length-1;
      sizeIdx := FindSymbolSize(outputLength,sizeIdxRequest); (* No CHKSIZE *)
      if sizeIdx<>DmtxUndefined then begin
        symbolRemaining := GetRemainingSymbolCapacity(outputLength,sizeIdx);
        if symbolRemaining=0 then begin
          (* Perfect fit -- complete encoding *)
          UpdateBase256ChainHeader(stream,sizeIdx); 
          if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
          StreamMarkComplete(stream,sizeIdx);
          Exit;
        end;
      end;
    end;

    (* Normal case *)
    sizeIdx := FindSymbolSize(stream^.output^.length, sizeIdxRequest);
    if sizeIdx=DmtxUndefined then begin StreamMarkInvalid(stream, DmtxErrorUnknown); Exit; end; //CHKSIZE
    EncodeChangeScheme(stream, DmtxSchemeAscii, DmtxUnlatchImplicit);
    PadRemainingInAscii(stream,sizeIdx); 
    StreamMarkComplete(stream,sizeIdx); 
  end;
end;

