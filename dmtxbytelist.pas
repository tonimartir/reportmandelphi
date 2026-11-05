unit dmtxbytelist;
(**
 * libdmtx - Data Matrix Encoding/Decoding Library
 * Copyright 2010 Mike Laughton. All rights reserved.
 * Copyright 2012-2016 Vadim A. Misbakh-Soloviov. All rights reserved.
 *
 * See LICENSE file in the main project directory for full
 * terms of use and distribution.
 *
 * Contact:
 * Vadim A. Misbakh-Soloviov <dmtx@mva.name>
 * Mike Laughton <mike@dragonflylogic.com>
 *
 * \file file.c
 *)
{$POINTERMATH ON}


interface

uses dmtx;

function dmtxByteListBuild(storage: pDmtxByte;  capacity: integer): tDmtxByteList;
procedure dmtxByteListInit(list: pDmtxByteList;  length: integer;  value: DmtxByte;  out passFail: DmtxPassFail);
function dmtxByteListHasCapacity(list: pDmtxByteList): DmtxBoolean;
procedure dmtxByteListCopy(dst: pDmtxByteList;  src: pDmtxByteList; out passFail: DmtxPassFail);
procedure dmtxByteListPush(list: pDmtxByteList;  value: DmtxByte; out passFail: DmtxPassFail);
function dmtxByteListPop(list: pDmtxByteList; out passFail: DmtxPassFail): DmtxByte;


implementation


function dmtxByteListBuild(storage: pDmtxByte;  capacity: integer): tDmtxByteList;
begin
  Result.b := storage;
  Result.capacity := capacity;
  Result.length := 0;
end;

procedure dmtxByteListInit(list: pDmtxByteList;  length: integer;  value: DmtxByte;  out passFail: DmtxPassFail);
begin
  if length > list^.capacity then
    passFail := DmtxFail
  else begin
    list^.length := length;
    cmemset(list^.b, value, sizeof(DmtxByte)*list^.capacity);
    passFail := DmtxPass;
  end;
end;

procedure dmtxByteListClear(list: pDmtxByteList); 
begin
  cmemset(list^.b, 0, sizeof(DmtxByte)*list^.capacity);
  list^.length := 0;
end;

function dmtxByteListHasCapacity(list: pDmtxByteList): DmtxBoolean;
begin
  Result := list^.length < list^.capacity;
end;

procedure dmtxByteListCopy(dst: pDmtxByteList;  src: pDmtxByteList; out passFail: DmtxPassFail);
var
  length: integer;
begin
  if dst^.capacity < src^.length then
    (* dst must be large enough to hold src data *)
    passFail := DmtxFail
  else begin
    (* Copy as many bytes as dst can hold or src can provide (smaller of two) *)
    if dst^.capacity < src^.capacity then
      length := dst^.capacity
    else
      length := src^.capacity;
    dst^.length:= src^.length; 
    cmemcpy(dst^.b, src^.b, sizeof(DmtxByte)*length);
    passFail := DmtxPass;
  end;
end;

procedure dmtxByteListPush(list: pDmtxByteList;  value: DmtxByte; out passFail: DmtxPassFail);
begin
  if list^.length >= list^.capacity then
    passFail := DmtxFail
  else begin
    list^.b[list^.length{++}] := value;
    Inc(list^.length);
    passFail := DmtxPass;
  end;
end;

function dmtxByteListPop(list: pDmtxByteList; out passFail: DmtxPassFail): DmtxByte;
begin
  if list^.length > 0 then
    passFail := DmtxPass
  else
    passFail := DmtxFail;

  Dec(list^.length);
  Result := list^.b[list^.length];
end;

(*
procedure dmtxByteListPrint(list: pDmtxByteList;  prefix: pchar); 
var
  i: integer;
begin
  if prefix<>0{nil}
  then
  fprintf(stdout,'%s',prefix); 
  for{while} i:=0 to Pred(list.length) { i++}
  do
  fprintf(stdout,' %d',list.b[i]); 
  fputc(#13#10,stdout); 
end;
*)

end.
