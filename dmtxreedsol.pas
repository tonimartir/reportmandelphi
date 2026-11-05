unit dmtxreedsol;
(**
 * libdmtx - Data Matrix Encoding/Decoding Library
 * Copyright 2011 Mike Laughton. All rights reserved.
 * Copyright 2012-2016 Vadim A. Misbakh-Soloviov. All rights reserved.
 *
 * See LICENSE file in the main project directory for full
 * terms of use and distribution.
 *
 * ---------------------------------------------------------
 * Portions of this file were derived from the Reed-Solomon
 * encoder/decoder released by Simon Rockliff in June 1991.
 * ---------------------------------------------------------
 *
 * Contact:
 * Vadim A. Misbakh-Soloviov <dmtx@mva.name>
 * Mike Laughton <mike@dragonflylogic.com>
 *
 * \file dmtxreedsol.c
 *)

(**
 * TODO:
 *   o try doxygen using using the JavaDoc style and JAVADOC_AUTOBRIEF = YES
 *   o switch doxygen to simplified syntax, and using "\file" instead of "@file"
 *)
{$POINTERMATH ON}


interface

uses dmtx, dmtxbytelist, dmtxsymbol;

function RsEncode(message: pDmtxMessage;  sizeIdx: integer): DmtxPassFail;
function RsDecode(code: pbyte;  sizeIdx: integer;  fix: integer): DmtxPassFail;


implementation

const
  NN = 255;
  MAX_ERROR_WORD_COUNT = 68;

var
  (* GF(256) log values using primitive polynomial 301 *)
  log301: array [0..255] of DmtxByte = (255,0,1,240,2,225,241,53,3,38,226,133,242,43,54,210,4,195,39,114,227,106,134,28,243,140,44,23,55,118,211,234,5,219,196,96,40,222,115,103,228,78,107,125,135,8,29,162,244,186,141,180,45,99,24,49,56,13,119,153,212,199,235,91,6,76,220,217,197,11,97,184,41,36,223,253,116,138,104,193,229,86,79,171,108,165,126,145,136,34,9,74,30,32,163,84,245,173,187,204,142,81,181,190,46,88,100,159,25,231,50,207,57,147,14,67,120,128,154,248,213,167,200,63,236,110,92,176,7,161,77,124,221,102,218,95,198,90,12,152,98,48,185,179,42,209,37,132,224,52,254,239,117,233,139,22,105,27,194,113,230,206,87,158,80,189,172,203,109,175,166,62,127,247,146,66,137,192,35,252,10,183,75,216,31,83,33,73,164,144,85,170,246,65,174,61,188,202,205,157,143,169,82,72,182,215,191,251,47,178,89,151,101,94,160,123,26,112,232,21,51,238,208,131,58,69,148,18,15,16,68,17,121,149,129,19,155,59,249,70,214,250,168,71,201,156,64,60,237,130,111,20,93,122,177,150);
  (* GF(256) antilog values using primitive polynomial 301 *)
  antilog301: array [0..255] of DmtxByte = (1,2,4,8,16,32,64,128,45,90,180,69,138,57,114,228,229,231,227,235,251,219,155,27,54,108,216,157,23,46,92,184,93,186,89,178,73,146,9,18,36,72,144,13,26,52,104,208,141,55,110,220,149,7,14,28,56,112,224,237,247,195,171,123,246,193,175,115,230,225,239,243,203,187,91,182,65,130,41,82,164,101,202,185,95,190,81,162,105,210,137,63,126,252,213,135,35,70,140,53,106,212,133,39,78,156,21,42,84,168,125,250,217,159,19,38,76,152,29,58,116,232,253,215,131,43,86,172,117,234,249,223,147,11,22,44,88,176,77,154,25,50,100,200,189,87,174,113,226,233,255,211,139,59,118,236,245,199,163,107,214,129,47,94,188,85,170,121,242,201,191,83,166,97,194,169,127,254,209,143,51,102,204,181,71,142,49,98,196,165,103,206,177,79,158,17,34,68,136,61,122,244,197,167,99,198,161,111,222,145,15,30,60,120,240,205,183,67,134,33,66,132,37,74,148,5,10,20,40,80,160,109,218,153,31,62,124,248,221,151,3,6,12,24,48,96,192,173,119,238,241,207,179,75,150,0);


(* GF add (a + b) *)
{GfAdd(a,b)    ((a) ^ (b))}
function GfAdd(a,b: DmtxByte): DmtxByte; inline;
begin
  //assert((a>=0) and (a<=255) and (b>=0) and (b<=255));
  Result := a xor b;
end;

(* GF multiply (a * b) *)
{GfMult(a,b)    (((a) == 0 || (b) == 0) ? 0 : antilog301[(log301[(a)] + log301[(b)]) % NN])}
function GfMult(a, b: DmtxByte): DmtxByte;
begin
  //assert((a>=0) and (a<=255) and (b>=0) and (b<=255));
  if (a=0) or (b=0) then
    Result := 0
  else
    Result := antilog301[(log301[a]+log301[b]) mod NN];
end;


(* GF multiply by antilog (a * alpha**b) *)
{GfMultAntilog(a,b)    (((a) == 0) ? 0 : antilog301[(log301[(a)] + (b)) % NN])}
function GfMultAntilog(a: DmtxByte; b: integer): DmtxByte;
begin
  if a=0 then
    Result := 0
  else
    Result := antilog301[(log301[a]+b) mod NN];
end;


(**
 * Populate generator polynomial.
 * More detailed description.
 * \param gen
 * \param errorWordCount
 * \return Function success (DmtxPass|DmtxFail)
 *)
function RsGenPoly(gen: pDmtxByteList;  errorWordCount: integer): DmtxPassFail;
var
  i: integer;
  j: integer;
begin
  (* Initialize all coefficients to 1 *)
  dmtxByteListInit(gen, errorWordCount, 1, Result);

  if Result=DmtxFail then Exit; //CHKPASS

  (* Generate polynomial *)
  for i:=0 to Pred(gen^.length) do
    for j:=i downto 0 do begin
      gen^.b[j] := GfMultAntilog(gen^.b[j], i+1);
      if j>0 then
        gen^.b[j] := GfAdd(gen^.b[j], gen^.b[j-1]);
    end;
end;

(**
 * Encode xyz.
 * More detailed description.
 * \param message
 * \param sizeIdx
 * \return Function success (DmtxPass|DmtxFail)
 *)
function RsEncode(message: pDmtxMessage;  sizeIdx: integer): DmtxPassFail;
var
  i: integer;
  j: integer;
  blockStride: integer;
  blockIdx: integer;
  blockErrorWords: integer;
  symbolDataWords: integer;
  symbolErrorWords: integer;
  symbolTotalWords: integer;
  val: DmtxByte;
  eccPtr: pDmtxByte;
  genStorage: array [0..Pred(MAX_ERROR_WORD_COUNT)] of DmtxByte;
  eccStorage: array [0..Pred(MAX_ERROR_WORD_COUNT)] of DmtxByte;
  gen: tDmtxByteList;
  ecc: tDmtxByteList;
begin
  gen := dmtxByteListBuild(pDmtxByte(@genStorage),sizeof(genStorage));
  ecc := dmtxByteListBuild(pDmtxByte(@eccStorage),sizeof(eccStorage));

  blockStride := dmtxGetSymbolAttribute(DmtxSymAttribInterleavedBlocks,sizeIdx);
  blockErrorWords := dmtxGetSymbolAttribute(DmtxSymAttribBlockErrorWords,sizeIdx);
  symbolDataWords := dmtxGetSymbolAttribute(DmtxSymAttribSymbolDataWords,sizeIdx);
  symbolErrorWords := dmtxGetSymbolAttribute(DmtxSymAttribSymbolErrorWords,sizeIdx);
  symbolTotalWords := symbolDataWords+symbolErrorWords;

  (* Populate generator polynomial *)
  RsGenPoly(@gen, blockErrorWords);

  (* For each interleaved block... *)
  for blockIdx:=0 to Pred(blockStride) do begin
    (* Generate error codewords *)
    dmtxByteListInit(@ecc, blockErrorWords, 0, Result);
    if Result=DmtxFail then Exit; //CHKPASS

    i:= blockIdx;
    while i<symbolDataWords do begin
      val := GfAdd(ecc.b[blockErrorWords-1], message^.code[i]);
      for j:=blockErrorWords-1 downto Succ(0) do begin
        DMTX_CHECK_BOUNDS(@ecc, j);
        DMTX_CHECK_BOUNDS(@ecc, j-1);
        DMTX_CHECK_BOUNDS(@gen, j);
        ecc.b[j] := GfAdd(ecc.b[j-1],GfMult(gen.b[j],val));
      end;
      ecc.b[0] := GfMult(gen.b[0],val);

      Inc(i, blockStride);
    end;

    (* Copy to output message *)
    eccPtr := ecc.b+blockErrorWords;
    i:= symbolDataWords+blockIdx;
    while i<symbolTotalWords do begin
      Dec(eccPtr);
      message^.code[i] := eccPtr^;
      Inc(i, blockStride);
    end;

    assert(ecc.b=eccPtr);
  end;
end;


(**
 * Populate generator polynomial.
 * Assume we have received bits grouped into mm-bit symbols in rec[i],
 * i=0..(nn-1),  and rec[i] is index form (ie as powers of alpha). We first
 * compute the 2*tt syndromes by substituting alpha**i into rec(X) and
 * evaluating, storing the syndromes in syn[i], i=1..2tt (leave syn[0] zero).
 * \param syn
 * \param rec
 * \param blockErrorWords
 * \return Are error(s) present? (DmtxPass|DmtxFail)
 *)
(* XXX this CHKPASS isn't doing what we want ... really need a error reporting strategy *)
function RsComputeSyndromes(syn, rec: pDmtxByteList;  blockErrorWords: integer): DmtxBoolean;
var
  i, j: integer;
  passFail: DmtxPassFail;
begin
  Result := DmtxFalse;

  (* Initialize all coefficients to 0 *)
  dmtxByteListInit(syn, blockErrorWords+1, 0, passFail);
  {CHKPASS}if passFail=DmtxFail then Exit(DmtxTrue);

  for i:=1 to Pred(syn^.length) do begin
    (* Calculate syndrome at i *)
    for j:=0 to Pred(rec^.length) do (* alternatively: j < blockTotalWords *)
      syn^.b[i] := GfAdd(syn^.b[i], GfMultAntilog(rec^.b[j], i*j));

    (* Non-zero syndrome indicates presence of error(s) *)
    if syn^.b[i]<>0 then
      Result := DmtxTrue;
  end;
end;

(**
 * Find the error location polynomial using Berlekamp-Massey.
 * More detailed description.
 * \param elpOut
 * \param syn
 * \param errorWordCount
 * \param maxCorrectable
 * \return Is block repairable? (DmtxTrue|DmtxFalse)
 *)
(* XXX this CHKPASS isn't doing what we want ... really need a error reporting strategy *)
function RsFindErrorLocatorPoly(elpOut: pDmtxByteList;  syn: pDmtxByteList;  errorWordCount: integer;  maxCorrectable: integer): DmtxBoolean;
var
  i, iNext, j, m: integer;
  mCmp: integer;
  lambda: integer;
  disTmp: DmtxByte;
  disStorage: array [0..Pred(MAX_ERROR_WORD_COUNT+1)] of DmtxByte;
  elpStorage: array [0..Pred(MAX_ERROR_WORD_COUNT+2), 0..Pred(MAX_ERROR_WORD_COUNT)] of DmtxByte;
  dis: tDmtxByteList;
  elp: array [0..Pred(MAX_ERROR_WORD_COUNT+2)] of tDmtxByteList;
  passFail: DmtxPassFail;
begin
  dis := dmtxByteListBuild(pDmtxByte(@disStorage),sizeof(disStorage));
  dmtxByteListInit(@dis, 0, 0, passFail);
  {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);

  for i:=0 to Pred(MAX_ERROR_WORD_COUNT+2) do begin
    elp[i] := dmtxByteListBuild(pDmtxByte(@elpStorage[i, 0]), sizeof(elpStorage[i]));
    dmtxByteListInit(@elp[i], 0, 0, passFail);
    {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);
  end;

  (* iNext = 0 *)
  dmtxByteListPush(@elp[0], 1, passFail);
  {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);
  dmtxByteListPush(@dis, 1, passFail);
  {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);

  (* iNext = 1 *)
  dmtxByteListPush(@elp[1], 1, passFail);
  {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);
  dmtxByteListPush(@dis, syn^.b[1], passFail);
  {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);

  iNext := 2;
  i := 1;
  while True do begin (* explicit break *)
    if dis.b[i]=0 then begin
      (* Simple case: Copy directly from previous iteration *)
      dmtxByteListCopy(@elp[iNext], @elp[i], passFail);
      {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);
    end
    else begin
      (* Find earlier iteration (m) that provides maximal (m - lambda) *)
      m := 0;
      for mCmp:=1 to Pred(i) do
        if (dis.b[mCmp]<>0) and ((mCmp-elp[mCmp].length) >= (m-elp[m].length)) then
          m := mCmp;

      (* Calculate error location polynomial elp[i] (set 1st term) *)
      lambda := elp[m].length-1;
      for j:=0 to lambda do
        elp[iNext].b[j+i-m] := antilog301[(NN-log301[dis.b[m]]+log301[dis.b[i]]+log301[elp[m].b[j]]) mod NN];

      (* Calculate error location polynomial elp[i] (add 2nd term) *)
      lambda := elp[i].length-1;
      for j:=0 to lambda do
        elp[iNext].b[j] := GfAdd(elp[iNext].b[j], elp[i].b[j]);

      elp[iNext].length := max(elp[i].length, elp[m].length+i-m);
    end;

    lambda := elp[iNext].length-1;
    if (i=errorWordCount) or (i>=lambda+maxCorrectable) then
      break;

    (* Calculate discrepancy dis.b[i] *)
    disTmp := syn^.b[iNext];
    for j:=1 to lambda do
      disTmp := GfAdd(disTmp, GfMult(syn^.b[iNext-j], elp[iNext].b[j]));

    assert(dis.length=iNext);
    dmtxByteListPush(@dis, disTmp, passFail);
    {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);

    i := iNext{++};
    Inc(iNext);
  end;

  dmtxByteListCopy(elpOut, @elp[iNext], passFail);
  {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);

  Result := (lambda<=maxCorrectable);
end;

(**
 * Find roots of the error locator polynomial (Chien Search).
 * If the degree of elp is <= tt, we substitute alpha**i, i=1..n into the elp
 * to get the roots, hence the inverse roots, the error location numbers.
 * If the number of errors located does not equal the degree of the elp, we
 * have more than tt errors and cannot correct them.
 * \param loc
 * \param elp
 * \return Is block repairable? (DmtxTrue|DmtxFalse)
 *)
function RsFindErrorLocations(loc: pDmtxByteList;  elp: pDmtxByteList): DmtxBoolean;
var
  i, j, lambda: integer;
  passFail: DmtxPassFail;
  q: DmtxByte;
  regStorage: array [0..Pred(MAX_ERROR_WORD_COUNT)] of DmtxByte;
  reg: tDmtxByteList;
begin
  lambda := elp^.length-1;
  reg := dmtxByteListBuild(pDmtxByte(@regStorage), sizeof(regStorage));

  dmtxByteListCopy(@reg, elp, passFail);
  {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);
  dmtxByteListInit(loc, 0, 0, passFail);
  {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);

  for i:=1 to NN do begin
    q:=1;
    for j:=1 to lambda do begin
      reg.b[j] := GfMultAntilog(reg.b[j], j);
      q := GfAdd(q, reg.b[j]);
    end;

    if q=0 then begin
      dmtxByteListPush(loc, NN-i, passFail);
      {CHKPASS}if passFail=DmtxFail then Exit(DmtxFalse);
    end;
  end;

  Result := loc^.length=lambda;
end;

(**
 * Find the error values and repair.
 * Solve for the error value at the error location and correct the error. The
 * procedure is that found in Lin and Costello.
 * For the cases where the number of errors is known to be too large to
 * correct, the information symbols as received are output (the advantage of
 * systematic encoding is that hopefully some of the information symbols will
 * be okay and that if we are in luck, the errors are in the parity part of
 * the transmitted codeword).
 * \param rec
 * \param loc
 * \param elp
 * \param syn
 *)
function RsRepairErrors(rec, loc, elp, syn: pDmtxByteList): DmtxPassFail;
var
  i, j, q: integer;
  lambda: integer;
  zVal, root, err: DmtxByte;
  zStorage: array [0..Pred(MAX_ERROR_WORD_COUNT+1)] of DmtxByte;
  z: tDmtxByteList;
begin
  lambda := elp^.length-1;
  z := dmtxByteListBuild(pDmtxByte(@zStorage),sizeof(zStorage));

  (* Form polynomial z(x) *)
  dmtxByteListPush(@z, 1, Result);
  {CHKPASS}if Result=DmtxFail then Exit;
  for i:=1 to lambda do begin
    zVal := GfAdd(syn^.b[i], elp^.b[i]);
    for j:=1 to Pred(i) do
      zVal := GfAdd(zVal, GfMult(elp^.b[i-j], syn^.b[j]));

    dmtxByteListPush(@z, zVal, Result);
    {CHKPASS}if Result=DmtxFail then Exit;
  end;

  for i:=0 to Pred(lambda) do begin
    (* Calculate numerator of error term *)
    root := NN - loc^.b[i];

    err := 1;
    for j:=1 to lambda do
      err := GfAdd(err, GfMultAntilog(z.b[j], j*root));

    if err=0 then
      continue;

    (* Calculate denominator of error term *)
    q:=0;
    for j:=0 to Pred(lambda) do begin
      if j<>i then
        q := q + log301[1 xor antilog301[(loc^.b[j]+root) mod NN]];
    end;
    q := q mod NN;

    err := GfMultAntilog(err, NN-q);
    rec^.b[loc^.b[i]] := GfAdd(rec^.b[loc^.b[i]], err);
  end;

  Result := DmtxPass;
end;

(**
 * Decode xyz.
 * More detailed description.
 * \param code
 * \param sizeIdx
 * \param fix
 * \return Function success (DmtxPass|DmtxFail)
 *)
function RsDecode(code: pbyte;  sizeIdx: integer;  fix: integer): DmtxPassFail;
var
  i: integer;
  blockStride, blockIdx: integer;
  blockDataWords, blockErrorWords, blockMaxCorrectable: integer;
  (* int blockDataWords, blockErrorWords, blockTotalWords, blockMaxCorrectable;*)
  symbolDataWords, symbolErrorWords, symbolTotalWords: integer;
  error, repairable: DmtxBoolean;
  word: pbyte;
  elpStorage: array [0..Pred(MAX_ERROR_WORD_COUNT)] of DmtxByte;
  synStorage: array [0..Pred(MAX_ERROR_WORD_COUNT+1)] of DmtxByte;
  recStorage: array [0..Pred(NN)] of DmtxByte;
  locStorage: array [0..Pred(NN)] of DmtxByte;
  elp: tDmtxByteList;
  syn: tDmtxByteList;
  rec: tDmtxByteList;
  loc: tDmtxByteList;
begin
  elp := dmtxByteListBuild(pDmtxByte(@elpStorage),sizeof(elpStorage));
  syn := dmtxByteListBuild(pDmtxByte(@synStorage),sizeof(synStorage));
  rec := dmtxByteListBuild(pDmtxByte(@recStorage),sizeof(recStorage));
  loc := dmtxByteListBuild(pDmtxByte(@locStorage),sizeof(locStorage));

  blockStride := dmtxGetSymbolAttribute(DmtxSymAttribInterleavedBlocks,sizeIdx);
  blockErrorWords := dmtxGetSymbolAttribute(DmtxSymAttribBlockErrorWords,sizeIdx);
  blockMaxCorrectable := dmtxGetSymbolAttribute(DmtxSymAttribBlockMaxCorrectable,sizeIdx);
  symbolDataWords := dmtxGetSymbolAttribute(DmtxSymAttribSymbolDataWords,sizeIdx);
  symbolErrorWords := dmtxGetSymbolAttribute(DmtxSymAttribSymbolErrorWords,sizeIdx);
  symbolTotalWords := symbolDataWords+symbolErrorWords;

  (* For each interleaved block *)
  for blockIdx:=0 to Pred(blockStride) do begin
    (* Data word count depends on blockIdx due to special case at 144x144 *)
    blockDataWords := dmtxGetBlockDataSize(sizeIdx,blockIdx);
    //blockTotalWords = blockErrorWords + blockDataWords;

    (* Populate received list (rec) with data and error codewords *)
    dmtxByteListInit(@rec, 0, 0, Result);
    {CHKPASS}if Result=DmtxFail then Exit;

    (* Start with final error word and work backward *)
    word := code + symbolTotalWords + blockIdx - blockStride;
    for i:=0 to Pred(blockErrorWords) do begin
      dmtxByteListPush(@rec, word^, Result);
      {CHKPASS}if Result=DmtxFail then Exit;
      Dec(word, blockStride);
    end;

    (* Start with final data word and work backward *)
    word := code + blockIdx + (blockStride*(blockDataWords-1));
    for i:=0 to Pred(blockDataWords) do begin
      dmtxByteListPush(@rec, word^, Result);
      {CHKPASS}if Result=DmtxFail then Exit;
      Dec(word, blockStride);
    end;

    (* Compute syndromes (syn) *)
    error := RsComputeSyndromes(@syn, @rec, blockErrorWords);

    (* Error(s) detected: Attempt repair *)
    if error then begin
      (* Find error locator polynomial (elp) *)
      repairable := RsFindErrorLocatorPoly(@elp, @syn, blockErrorWords, blockMaxCorrectable);
      if not repairable then begin
        Result := DmtxFail;
        Exit;
      end;

      (* Find error positions (loc) *)
      repairable := RsFindErrorLocations(@loc, @elp);
      if not repairable then begin
        Result := DmtxFail;
        Exit;
      end;

      (* Find error values and repair *)
      RsRepairErrors(@rec, @loc, @elp, @syn);
    end;

    (* Overwrite output with correct/corrected values *)
    (* Start with first data word and work forward *)
    word := code+blockIdx;

    for i:=0 to Pred(blockDataWords) do begin
      word^ := dmtxByteListPop(@rec, Result);
      {CHKPASS}if Result=DmtxFail then Exit;
      Inc(word, blockStride);
    end;

    (* Start with first error word and work forward *)
    word := code+symbolDataWords+blockIdx;
    for i:=0 to Pred(blockErrorWords) do begin
      word^ := dmtxByteListPop(@rec, Result);
      {CHKPASS}if Result=DmtxFail then Exit;
      Inc(word, blockStride);
    end;
  end;

  Result := DmtxPass;
end;

end.
