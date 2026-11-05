//unit dmtxencodescheme;
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
 * \file dmtxencodescheme.c
 * \brief Logic for encoding in single scheme
 *)

(**
 * In this file:
 *
 * A "word" refers to a full codeword byte to be appended to the encoded output.
 *
 * A "value" refers to any scheme value being appended to the output stream,
 * regardless of how many bytes are used to represent it. Examples:
 *
 *   ASCII:                   1 value  in  1 codeword
 *   ASCII (digits):          2 values in  1 codeword
 *   C40/Text/X12:            3 values in  2 codewords
 *   C40/Text/X12 (unlatch):  1 values in  1 codeword
 *   EDIFACT:                 4 values in  3 codewords
 *   Base 256:                1 value  in  1 codeword
 *
 *   * Shifts count as values, so outputChainValueCount will reflect these.
 *
 *   * Latches and unlatches are also counted as values, but always in the
 *     scheme being exited.
 *
 *   * Base256 header bytes are not included as values.
 *
 * A "chunk" refers to the minimum grouping of values in a schema that must be
 * encoded together.
 *
 *   ASCII:                   1 value  (1 codeword)  in 1 chunk
 *   ASCII (digits):          2 values (1 codeword)  in 1 chunk (optional)
 *   C40/Text/X12:            3 values (2 codewords) in 1 chunk
 *   C40/Text/X12 (unlatch):  1 value  (1 codeword)  in 1 chunk
 *   EDIFACT:                 1 value  (1 codeword* ) in 1 chunk
 *   Base 256:                1 value  (1 codeword)  in 1 chunk
 *
 *   * EDIFACT writes 6 bits at a time, but progress is tracked to the next byte
 *     boundary. If unlatch value finishes mid-byte, the remaining bits before
 *     the next boundary are set to zero.
 *
 * Each scheme implements 3 equivalent functions:
 *   * EncodeNextChunk[Scheme]
 *   * AppendValue[Scheme]
 *   * CompleteIfDone[Scheme]
 *
 * The function EncodeNextChunk() (no Scheme in the name) knows which scheme-
 * specific implementations to call based on the stream's current encodation
 * scheme.
 *
 * It's important that EncodeNextChunk[Scheme] not call CompleteIfDone[Scheme]
 * directly because some parts of the logic might want to encode a stream
 * without allowing the padding and other extra logic that can occur when an
 * end-of-symbol condition is triggered.
 *)

//interface

(* Verify stream is using expected scheme *)
(*
#define CHKSCHEME(s) { \
   if(stream->currentScheme != (s)) { StreamMarkFatal(stream, DmtxErrorUnexpectedScheme); return; } \
}
*)

(* CHKERR should follow any call that might alter stream status *)
(*
#define CHKERR { \
   if(stream->status != DmtxStatusEncoding) { return; } \
}
*)

(* CHKSIZE should follows typical calls to FindSymbolSize() *)
(*
#define CHKSIZE { \
   if(sizeIdx == DmtxUndefined) { StreamMarkInvalid(stream, DmtxErrorUnknown); return; } \
*)

//implementation

function GetRemainingSymbolCapacity(outputLength: integer;  sizeIdx: integer): integer;
var
  capacity: integer;
begin
  if sizeIdx=DmtxUndefined then
    Result := DmtxUndefined
  else begin
    capacity := dmtxGetSymbolAttribute(DmtxSymAttribSymbolDataWords,sizeIdx);
    Result := capacity-outputLength;
  end;
end;

// Forward declaration
procedure EncodeChangeScheme(stream: pDmtxEncodeStream;  targetScheme: DmtxScheme;  unlatchType: integer); forward;

{$I dmtxencodeascii.inc}
{$I dmtxencodebase256.inc}

procedure EncodeChangeScheme(stream: pDmtxEncodeStream;  targetScheme: DmtxScheme;  unlatchType: integer);
begin
  (* Nothing to do *)
  if stream^.currentScheme=targetScheme then
    Exit;

  (* Every latch must go through ASCII *)
  case stream^.currentScheme of
    DmtxSchemeC40,
    DmtxSchemeText,
    DmtxSchemeX12:
      if unlatchType=DmtxUnlatchExplicit then
        begin
        //AppendUnlatchCTX(stream);
        if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
        end;

    DmtxSchemeEdifact:
      if unlatchType=DmtxUnlatchExplicit then
        begin
        //AppendValueEdifact(stream,DmtxValueEdifactUnlatch);
        if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
        end;

    else
      (* Nothing to do for ASCII or Base 256 *)
      assert((stream^.currentScheme=DmtxSchemeAscii) or (stream^.currentScheme=DmtxSchemeBase256));
  end;{case}

  stream^.currentScheme := DmtxSchemeAscii;

  (* Anything other than ASCII (the default) requires a latch *)
  case targetScheme of
    DmtxSchemeC40:
      begin
      AppendValueAscii(stream,DmtxValueC40Latch);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      end;
    DmtxSchemeText:
      begin
      AppendValueAscii(stream,DmtxValueTextLatch);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      end;
    DmtxSchemeX12:
      begin
      AppendValueAscii(stream,DmtxValueX12Latch);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      end;
    DmtxSchemeEdifact:
      begin
      AppendValueAscii(stream,DmtxValueEdifactLatch);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      end;
    DmtxSchemeBase256:
      begin
      AppendValueAscii(stream,DmtxValueBase256Latch);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      end;
    else
      (* Nothing to do for ASCII *)
      if stream^.currentScheme<>DmtxSchemeAscii then begin //CHKSCHEME(DmtxSchemeAscii);
        StreamMarkFatal(stream, DmtxErrorUnexpectedScheme);
        Exit;
      end;
  end;{case}

  stream^.currentScheme:= targetScheme;

  (* Reset new chain length to zero *)
  stream^.outputChainWordCount:= 0;
  stream^.outputChainValueCount:= 0;
  (* Insert header byte if just latched to Base256 *)
  if targetScheme=DmtxSchemeBase256 then begin
    UpdateBase256ChainHeader(stream, DmtxUndefined);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
  end;
end;

(**
 * This function distributes work to the equivalent scheme-specific
 * implementation.
 *
 * Each of these functions will encode the next symbol input word, and in some
 * cases this requires additional input words to be encoded as well.
 *)
procedure EncodeNextChunk(stream: pDmtxEncodeStream;  scheme: DmtxScheme;  option: DmtxEncodeOption;  sizeIdxRequest: DmtxSymbolSize);
begin
  (* Special case: Prevent X12 from entering state with no way to unlatch *)
  if (stream^.currentScheme<>DmtxSchemeX12) and (scheme=DmtxSchemeX12) then begin
{TODO: Translate from C "dmtxencodec40textx12.c"}
//    if PartialX12ChunkRemains(stream) then
//      scheme := DmtxSchemeAscii;
  end;

  (* Change to target scheme if necessary *)
  if stream^.currentScheme<>scheme then begin
    EncodeChangeScheme(stream, scheme, DmtxUnlatchExplicit);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
    if stream^.currentScheme<>scheme then begin StreamMarkFatal(stream, DmtxErrorUnexpectedScheme); Exit; end; //CHKSCHEME(scheme);
  end;

  (* Special case: Edifact may be done before writing first word *)
  if scheme=DmtxSchemeEdifact then begin
{TODO: Translate from C "dmtxencodeedifact.c"}
//  CompleteIfDoneEdifact(stream,sizeIdxRequest);
    if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
  end;

  case stream^.currentScheme of
    DmtxSchemeAscii:
      begin
      EncodeNextChunkAscii(stream,option);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      CompleteIfDoneAscii(stream,sizeIdxRequest);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      end;
    DmtxSchemeC40,
    DmtxSchemeText,
    DmtxSchemeX12:
      begin
{TODO: Translate from C "dmtxencodec40textx12.c"}
//      EncodeNextChunkCTX(stream,sizeIdxRequest);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
//      CompleteIfDoneCTX(stream,sizeIdxRequest);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      end;
    DmtxSchemeEdifact:
      begin
{TODO: Translate from C "dmtxencodeedifact.c"}
//      EncodeNextChunkEdifact(stream);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
//      CompleteIfDoneEdifact(stream,sizeIdxRequest);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      end;
    DmtxSchemeBase256:
      begin
      EncodeNextChunkBase256(stream);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      CompleteIfDoneBase256(stream,sizeIdxRequest);
      if stream^.status<>DmtxStatusEncoding then Exit; //CHKERR
      end;
    else
      StreamMarkFatal(stream,DmtxErrorUnknown);
  end;{case}
end;

function EncodeSingleScheme(input: pDmtxByteList;  output: pDmtxByteList;  sizeIdxRequest: DmtxSymbolSize;  scheme: DmtxScheme): integer;
var
  stream: tDmtxEncodeStream;
begin
  stream := StreamInit(input,output);

  (* Continue encoding until complete *)
  while stream.status=DmtxStatusEncoding do
    EncodeNextChunk(@stream, scheme, DmtxEncodeNormal, sizeIdxRequest);

  (* Verify encoding completed and all inputs were consumed *)
  if (stream.status<>DmtxStatusComplete) or StreamInputHasNext(@stream) then
    Result := DmtxUndefined
  else
    Result := stream.sizeIdx;
end;

