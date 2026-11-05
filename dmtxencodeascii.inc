//unit dmtxencodeascii;
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
 * \file dmtxencodeascii.c
 * \brief ASCII encoding rules
 *)
(**
 * Simple single scheme encoding uses "Normal"
 * The optimizer needs to track "Expanded" and "Compact" streams separately, so they
 * are called explicitly.
 *
 *   Normal:   Automatically collapses 2 consecutive digits into one codeword
 *   Expanded: Uses a whole codeword to represent a digit (never collapses)
 *   Compact:  Collapses 2 digits into a single codeword or marks the stream
 *             invalid if either values are not digits
 *
 * \param stream
 * \param option [Expanded|Compact|Normal]
 *)

//interface

//implementation

(**
 * this code is separated from EncodeNextChunkAscii() because it needs to be
 * called directly elsewhere
 *)
procedure AppendValueAscii(stream: pDmtxEncodeStream;  value: DmtxByte);
begin
  if stream^.currentScheme<>DmtxSchemeAscii then begin //CHKSCHEME(DmtxSchemeAscii);
    StreamMarkFatal(stream, DmtxErrorUnexpectedScheme);
    Exit;
  end;
  StreamOutputChainAppend(stream, value);
  if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
  Inc(stream^.outputChainValueCount);
end;

procedure EncodeNextChunkAscii(stream: pDmtxEncodeStream;  option: DmtxEncodeOption);
var
  v0: DmtxByte;
  v1: DmtxByte;
  compactDigits: Boolean;
begin
  if StreamInputHasNext(stream) then begin
    v0 := StreamInputAdvanceNext(stream);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
    if ((option=DmtxEncodeCompact) or (option=DmtxEncodeNormal)) and StreamInputHasNext(stream) then begin
      v1 := StreamInputPeekNext(stream);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      compactDigits := ISDIGIT(v0) and ISDIGIT(v1);
    end
    else begin(* option == DmtxEncodeFull *)
      v1 := 0;
      compactDigits := False;
    end;

    if compactDigits then begin
      (* Two adjacent digit chars: Make peek progress official and encode *)
      StreamInputAdvanceNext(stream); 
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      AppendValueAscii(stream, 10*(v0-ord('0')) + (v1-ord('0')) + 130);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
    end
    else if option=DmtxEncodeCompact then begin
      (* Can't compact non-digits *)
      StreamMarkInvalid(stream, DmtxErrorCantCompactNonDigits);
    end
    else begin
      (* Encode single ASCII value *)
      if v0<128 then begin
        (* Regular ASCII *)
        AppendValueAscii(stream, v0+1);
        if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      end
      else begin
        (* Extended ASCII *)
        AppendValueAscii(stream, DmtxValueAsciiUpperShift);
        if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
        AppendValueAscii(stream, v0-127);
        if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      end;
    end;
  end;
end;

(**
 * \brief  Randomize 253 state
 * \param  codewordValue
 * \param  codewordPosition
 * \return Randomized value
 *)
function Randomize253State(cwValue: DmtxByte;  cwPosition: integer): DmtxByte;
var
  pseudoRandom: integer;
  tmp: integer;
begin
  pseudoRandom := (149*cwPosition) mod 253 + 1;
  tmp := cwValue+pseudoRandom;
  if tmp>254 then
    Dec(tmp, 254);

  assert((tmp>=0) and (tmp<256));

  Result := DmtxByte(tmp);
end;

(**
 * Can we just receive a length to pad here? I don't like receiving
 * sizeIdxRequest (or sizeIdx) this late in the game
 *)
procedure PadRemainingInAscii(stream: pDmtxEncodeStream;  sizeIdx: integer);
var
  symbolRemaining: integer;
  padValue: DmtxByte;
begin
  if stream^.currentScheme<>DmtxSchemeAscii then begin StreamMarkFatal(stream, DmtxErrorUnexpectedScheme); Exit; end; //CHKSCHEME(DmtxSchemeAscii);

  if sizeIdx=DmtxUndefined then begin StreamMarkInvalid(stream, DmtxErrorUnknown); Exit; end; //CHKSIZE

  symbolRemaining := GetRemainingSymbolCapacity(stream^.output^.length, sizeIdx);
  (* First pad character is not randomized *)
  if symbolRemaining>0 then begin
    padValue := DmtxValueAsciiPad;
    StreamOutputChainAppend(stream,padValue);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
    dec(symbolRemaining);
  end;

  (* All remaining pad characters are randomized based on character position *)
  while symbolRemaining>0 do begin
    padValue := Randomize253State(DmtxValueAsciiPad, stream^.output^.length+1);
    StreamOutputChainAppend(stream, padValue);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
    Dec(symbolRemaining);
  end;
end;

procedure CompleteIfDoneAscii(stream: pDmtxEncodeStream;  sizeIdxRequest: DmtxSymbolSize);
var
  sizeIdx: integer;
begin
  if stream^.status=DmtxStatusComplete then Exit;

  if not StreamInputHasNext(stream) then begin
    sizeIdx := FindSymbolSize(stream^.output^.length, sizeIdxRequest);
    if sizeIdx=DmtxUndefined then begin StreamMarkInvalid(stream, DmtxErrorUnknown); Exit; end; //CHKSIZE
    PadRemainingInAscii(stream,sizeIdx); 
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
    StreamMarkComplete(stream,sizeIdx);
  end;
end;

(**
 * consider receiving instantiated DmtxByteList instead of the output components
 *)
function EncodeTmpRemainingInAscii(stream: pDmtxEncodeStream;  storage: pDmtxByte;  capacity: integer; var passFail: DmtxPassFail): tDmtxByteList;
var
  streamAscii: tDmtxEncodeStream;
begin
  Result := dmtxByteListBuild(storage,capacity); (* Create temporary copy of stream that writes to storage *)

  streamAscii := stream^;
  streamAscii.currentScheme := DmtxSchemeAscii;
  streamAscii.outputChainValueCount := 0;
  streamAscii.outputChainWordCount := 0;
  streamAscii.reason := nil;
  streamAscii.sizeIdx := DmtxUndefined;
  streamAscii.status := DmtxStatusEncoding;
  streamAscii.output := @Result;

  while dmtxByteListHasCapacity(streamAscii.output) do
    if StreamInputHasNext(@streamAscii) then
      EncodeNextChunkAscii(@streamAscii,DmtxEncodeNormal) (* No CHKERR *)
    else
      break;

  (*
   * We stopped encoding before attempting to write beyond output boundary so
   * any stream errors are truly unexpected. The passFail status indicates
   * whether output.length can be trusted by the calling function.
   *)
  if (streamAscii.status=DmtxStatusInvalid) or (streamAscii.status=DmtxStatusFatal) then
    passFail := DmtxFail
  else
    passFail := DmtxPass;
end;

