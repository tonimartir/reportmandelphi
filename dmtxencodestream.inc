//unit dmtxencodestream;
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
 * \file dmtxencodestream.c
 * \brief DmtxEncodeStream implementation
 *)

//interface

//implementation

function StreamInit(input: pDmtxByteList;  output: pDmtxByteList): tDmtxEncodeStream; 
begin
  Result.input := input;
  Result.output := output;
  Result.currentScheme := DmtxSchemeAscii;
  Result.inputNext := 0;
  Result.outputChainValueCount := 0;
  Result.outputChainWordCount := 0;
  Result.reason := nil;
  Result.sizeIdx := DmtxUndefined;
  Result.status := DmtxStatusEncoding;
end;

procedure StreamCopy(dst: pDmtxEncodeStream;  src: pDmtxEncodeStream); 
var
  passFail: DmtxPassFail;
begin
  dst^.currentScheme := src^.currentScheme;
  dst^.inputNext:= src^.inputNext; 
  dst^.outputChainValueCount:= src^.outputChainValueCount; 
  dst^.outputChainWordCount:= src^.outputChainWordCount; 
  dst^.reason:= src^.reason; 
  dst^.sizeIdx:= src^.sizeIdx; 
  dst^.status:= src^.status; 
  dst^.input:= src^.input; 
  dmtxByteListCopy(dst^.output, src^.output, passFail);
end;

procedure StreamMarkComplete(stream: pDmtxEncodeStream;  sizeIdx: integer); 
begin
  if stream^.status = DmtxStatusEncoding then begin
    stream^.sizeIdx := sizeIdx;
    stream^.status := DmtxStatusComplete;
    assert(stream^.reason = nil);
  end;
end;

procedure StreamMarkInvalid(stream: pDmtxEncodeStream;  reasonIdx: TDmtxErrorMessage);
begin
  stream^.status := DmtxStatusInvalid;
  stream^.reason := dmtxErrorMessage[reasonIdx];
end;

procedure StreamMarkFatal(stream: pDmtxEncodeStream;  reasonIdx: TDmtxErrorMessage);
begin
  stream^.status := DmtxStatusFatal;
  stream^.reason := dmtxErrorMessage[reasonIdx];
end;

(**
 * push on newest/last append
 * used for encoding each output cw
 *)
procedure StreamOutputChainAppend(stream: pDmtxEncodeStream;  value: DmtxByte); 
var
  passFail: DmtxPassFail;
begin
  dmtxByteListPush(stream^.output, value, passFail);
  if passFail=DmtxPass then
    Inc(stream^.outputChainWordCount)
  else
    StreamMarkFatal(stream, DmtxErrorOutOfBounds);
end;

(**
 * pop off newest/last
 * used for edifact
 *)
function StreamOutputChainRemoveLast(stream: pDmtxEncodeStream): DmtxByte;
var
  passFail: DmtxPassFail;
begin
  if stream^.outputChainWordCount > 0 then begin
    Result := dmtxByteListPop(stream^.output, passFail);
    Dec(stream^.outputChainWordCount);
  end
  else begin
    Result := 0;
    StreamMarkFatal(stream, DmtxErrorEmptyList);
  end;
end;

(**
 * overwrite arbitrary element
 * used for binary length changes
 *)
procedure StreamOutputSet(stream: pDmtxEncodeStream;  index: integer;  value: DmtxByte); 
begin
  if (index<0) or (index>=stream^.output^.length) then
    StreamMarkFatal(stream, DmtxErrorOutOfBounds)
  else
    stream^.output^.b[index] := value;
end;

function StreamInputHasNext(stream: pDmtxEncodeStream): DmtxBoolean;
begin
  Result := stream^.inputNext < stream^.input^.length;
end;

(**
 * peek at first/oldest
 * used for ascii double digit
 *)
function StreamInputPeekNext(stream: pDmtxEncodeStream): DmtxByte; 
begin
  if StreamInputHasNext(stream) then
    Result := stream^.input^.b[stream^.inputNext]
  else begin
    Result := 0;
    StreamMarkFatal(stream, DmtxErrorOutOfBounds);
  end;
end;

(**
 * used as each input cw is processed
 *
 * \param value Value to populate, can be null (for blind dequeues)
 * \param stream
 *)
function StreamInputAdvanceNext(stream: pDmtxEncodeStream): DmtxByte; 
begin
  Result := StreamInputPeekNext(stream);
  if stream^.status = DmtxStatusEncoding then
    Inc(stream^.inputNext); (* XXX is this what we really mean here? *)
end;

(**
 * used as each input cw is processed
 *
 * \param value Value to populate, can be null (for blind dequeues)
 * \param stream
 *)
procedure StreamInputAdvancePrev(stream: pDmtxEncodeStream);
begin
  if stream^.inputNext>0 then
    Dec(stream^.inputNext)
  else
    StreamMarkFatal(stream, DmtxErrorOutOfBounds);
end;

