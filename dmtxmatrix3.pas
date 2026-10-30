unit dmtxmatrix3;
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
 * \file dmtxmatrix3.c
 * \brief 2D Matrix (3x3) math
 *)

interface

uses dmtx;

procedure dmtxMatrix3Identity(var m: tDmtxMatrix3);
procedure dmtxMatrix3Translate(var m: tDmtxMatrix3;  tx,ty: double);
procedure dmtxMatrix3Rotate(var m: tDmtxMatrix3;  angle: double);
procedure dmtxMatrix3Scale(var m: tDmtxMatrix3;  sx: double;  sy: double);
procedure dmtxMatrix3Shear(var m: tDmtxMatrix3;  shx, shy: double);
procedure dmtxMatrix3LineSkewTop(var m: tDmtxMatrix3;  b0, b1: double;  sz: double);
procedure dmtxMatrix3LineSkewTopInv(var m: tDmtxMatrix3;  b0, b1: double;  sz: double);
procedure dmtxMatrix3LineSkewSide(var m: tDmtxMatrix3;  b0, b1: double;  sz: double);
procedure dmtxMatrix3LineSkewSideInv(var m: tDmtxMatrix3;  b0, b1: double;  sz: double);
procedure dmtxMatrix3Multiply(var mOut: tDmtxMatrix3; var m0,m1: tDmtxMatrix3);
procedure dmtxMatrix3MultiplyBy(var m0, m1: tDmtxMatrix3);
function dmtxMatrix3VMultiply(vOut: pDmtxVector2;  vIn: pDmtxVector2; const m: tDmtxMatrix3): integer;
function dmtxMatrix3VMultiplyBy(v: pDmtxVector2;  var m: tDmtxMatrix3): integer;

implementation

(**
 * \brief  Copy matrix contents
 * \param  m0 Copy target
 * \param  m1 Copy source
 * \return void
 *)
procedure dmtxMatrix3Copy(var m0, m1: tDmtxMatrix3);
begin
  //cmemcpy(@m0,@m1,sizeof(tDmtxMatrix3));
  m0 := m1;
end;

(**
 * \brief  Generate identity transformation matrix
 * \param  m Generated matrix
 * \return void
 *
 *      | 1  0  0 |
 *  m = | 0  1  0 |
 *      | 0  0  1 |
 *
 *                  Transform "m"
 *            (doesn't change anything)
 *                       | *  (0,1)  x----o     +--+ \    (0,1)  x----o
 *         |    |     |     \          |    |
 *         |    |     |     /          |    |
 *         +----*     +--+ /           +----*
 *  (0,0)     (1,0)      |/     (0,0)     (1,0)
 *
 *)
procedure dmtxMatrix3Identity(var m: tDmtxMatrix3);
const
  identity3: tDmtxMatrix3 = ((1,0,0),(0,1,0),(0,0,1));
begin
  m := identity3;
end;

(**
 * \brief  Generate translate transformation matrix
 * \param  m Generated matrix
 * \param  tx
 * \param  ty
 * \return void
 *
 *      | 1  0  0 |
 *  m = | 0  1  0 |
 *      | tx ty 1 |
 *
 *                  Transform "m"
 *                      _____    (tx,1+ty)  x----o  (1+tx,1+ty)
 *                      \   |               |    |
 *  (0,1)  x----o       /   |      (0,1)  +-|--+ |
 *         |    |      /  /\|             | +----*  (1+tx,ty)
 *         |    |      \ /                |    |
 *         +----*       `                 +----+
 *  (0,0)     (1,0)                (0,0)     (1,0)
 *
 *)
procedure dmtxMatrix3Translate(var m: tDmtxMatrix3;  tx,ty: double);
begin
  dmtxMatrix3Identity(m); 
  m[2][0] := tx;
  m[2][1] := ty;
end;

(**
 * \brief  Generate rotate transformation
 * \param  m Generated matrix
 * \param  angle
 * \return void
 *
 *     |  cos(a)  sin(a)  0 |
 * m = | -sin(a)  cos(a)  0 |
 *     |  0       0       1 |
 *                                       o
 *                  Transform "m"      /   `
 *                       ___         /       `
 *  (0,1)  x----o      |/   \       x          *  (cos(a),sin(a))
 *         |    |      '--   |       `        /
 *         |    |        ___/          `    /  a
 *         +----*                        `+  - - - - - -
 *  (0,0)     (1,0)                     (0,0)
 *
 *)
procedure dmtxMatrix3Rotate(var m: tDmtxMatrix3;  angle: double);
var
  sinAngle: double;
  cosAngle: double;
begin
  sinAngle := sin(angle);
  cosAngle := cos(angle);
  dmtxMatrix3Identity(m); 
  m[0][0] := cosAngle;
  m[0][1] := sinAngle;
  m[1][0] := -sinAngle;
  m[1][1] := cosAngle;
end;

(**
 * \brief  Generate scale transformation matrix
 * \param  m Generated matrix
 * \param  sx
 * \param  sy
 * \return void
 *
 *     | sx 0  0 |
 * m = | 0  sy 0 |
 *     | 0  0  1 |
 *
 *                  Transform "m"
 *                      _____     (0,sy)  x-------o (sx,sy)
 *                      \   |             |       |
 *  (0,1)  x----o       /   |      (0,1)  +----+  |
 *         |    |      /  /\|             |    |  |
 *         |    |      \ /                |    |  |
 *         +----*       `                 +----+--*
 *  (0,0)     (1,0)                (0,0)            (sx,0)
 *
 *)
procedure dmtxMatrix3Scale(var m: tDmtxMatrix3;  sx: double;  sy: double);
begin
  dmtxMatrix3Identity(m); 
  m[0][0] := sx;
  m[1][1] := sy;
end;

(**
 * \brief  Generate shear transformation matrix
 * \param  m Generated matrix
 * \param  shx
 * \param  shy
 * \return void
 *
 *     | 0    shy  0 |
 * m = | shx  0    0 |
 *     | 0    0    1 |
 *)
procedure dmtxMatrix3Shear(var m: tDmtxMatrix3;  shx, shy: double);
begin
  dmtxMatrix3Identity(m); 
  m[1][0]:= shx; 
  m[0][1]:= shy; 
end;

(**
 * \brief  Generate top line skew transformation
 * \param  m
 * \param  b0
 * \param  b1
 * \param  sz
 * \return void
 *
 *     | b1/b0    0    (b1-b0)/(sz*b0) |
 * m = |   0    sz/b0         0        |
 *     |   0      0           1        |
 *
 *     (sz,b1)  o
 *             /|    Transform "m"
 *            / |
 *           /  |        +--+
 *          /   |        |  |
 * (0,b0)  x    |        |  |
 *         |    |      +-+  +-+
 * (0,sz)  +----+       \    /    (0,sz)  x----o
 *         |    |        \  /             |    |
 *         |    |         \/              |    |
 *         +----+                         +----+
 *  (0,0)    (sz,0)                (0,0)    (sz,0)
 *
 *)
procedure dmtxMatrix3LineSkewTop(var m: tDmtxMatrix3;  b0, b1: double;  sz: double);
begin
  assert(b0>=DmtxAlmostZero); 
  dmtxMatrix3Identity(m); 
  m[0][0] := b1 / b0;
  m[1][1] := sz / b0;
  m[0][2] := (b1-b0) / (sz*b0);
end;

(**
 * \brief  Generate top line skew transformation (inverse)
 * \param  m
 * \param  b0
 * \param  b1
 * \param  sz
 * \return void
 *)
procedure dmtxMatrix3LineSkewTopInv(var m: tDmtxMatrix3;  b0, b1: double;  sz: double);
begin
  assert(b1>=DmtxAlmostZero); 
  dmtxMatrix3Identity(m); 
  m[0][0] := b0 / b1;
  m[1][1] := b0 / sz;
  m[0][2] := (b0-b1) / (sz*b1);
end;

(**
 * \brief  Generate side line skew transformation
 * \param  m
 * \param  b0
 * \param  b1
 * \param  sz
 * \return void
 *)
procedure dmtxMatrix3LineSkewSide(var m: tDmtxMatrix3;  b0, b1: double;  sz: double);
begin
  assert(b0>=DmtxAlmostZero); 
  dmtxMatrix3Identity(m); 
  m[0][0] := sz / b0;
  m[1][1] := b1 / b0;
  m[1][2] := (b1-b0) / (sz*b0);
end;

(**
 * \brief  Generate side line skew transformation (inverse)
 * \param  m
 * \param  b0
 * \param  b1
 * \param  sz
 * \return void
 *)
procedure dmtxMatrix3LineSkewSideInv(var m: tDmtxMatrix3;  b0, b1: double;  sz: double);
begin
  assert(b1>=DmtxAlmostZero); 
  dmtxMatrix3Identity(m); 
  m[0][0] := b0 / sz;
  m[1][1] := b0 / b1;
  m[1][2] := (b0-b1) / (sz*b1);
end;

(**
 * \brief  Multiply two matrices to create a third
 * \param  mOut
 * \param  m0
 * \param  m1
 * \return void
 *)
procedure dmtxMatrix3Multiply(var mOut: tDmtxMatrix3; var m0,m1: tDmtxMatrix3);
var
  i: integer;
  j: integer;
  k: integer;
  val: double;
begin
  for i:=0 to 2 do
    for j:=0 to 2 do begin
      val := 0.0;
      for k:=0 to 2 do
        val := val + m0[i][k]*m1[k][j];
      mOut[i][j]:= val;
    end;
end;

(**
 * \brief  Multiply two matrices in place
 * \param  m0
 * \param  m1
 * \return void
 *)
procedure dmtxMatrix3MultiplyBy(var m0, m1: tDmtxMatrix3);
var
  mTmp: tDmtxMatrix3;
begin
  dmtxMatrix3Copy(mTmp, m0);
  dmtxMatrix3Multiply(m0, mTmp, m1);
end;

(**
 * \brief  Multiply vector and matrix
 * \param  vOut Vector (output)
 * \param  vIn Vector (input)
 * \param  m Matrix to be multiplied
 * \return DmtxPass | DmtxFail
 *)
function dmtxMatrix3VMultiply(vOut: pDmtxVector2;  vIn: pDmtxVector2; const m: tDmtxMatrix3): integer;
var
  w: double;
begin
  w := vIn^.X*m[0][2] + vIn^.Y*m[1][2] + m[2][2];
  if abs(w) <= DmtxAlmostZero then begin
    vOut^.X := 1.7e+308;
    vOut^.Y := 1.7e+308;
    Result := DmtxFail;
  end
  else begin
    vOut^.X := (vIn^.X*m[0][0] + vIn^.Y*m[1][0] + m[2][0]) / w;
    vOut^.Y := (vIn^.X*m[0][1] + vIn^.Y*m[1][1] + m[2][1]) / w;
    Result := DmtxPass;
  end;
end;

(**
 * \brief  Multiply vector and matrix in place
 * \param  v Vector (input and output)
 * \param  m Matrix to be multiplied
 * \return DmtxPass | DmtxFail
 *)
function dmtxMatrix3VMultiplyBy(v: pDmtxVector2;  var m: tDmtxMatrix3): integer;
var
  vOut: tDmtxVector2;
begin
  Result := dmtxMatrix3VMultiply(@vOut, v, m);
  v^ := vOut;
end;


(**
 * \brief  Print matrix contents to STDOUT
 * \param  m
 * \return void
 *)
(*
procedure dmtxMatrix3Print(m: DmtxMatrix3);
begin
  fprintf(stdout,'%8.8ft%8.8ft%8.8f'#13#10'',m[0][0],m[0][1],m[0][2]); 
  fprintf(stdout,'%8.8ft%8.8ft%8.8f'#13#10'',m[1][0],m[1][1],m[1][2]); 
  fprintf(stdout,'%8.8ft%8.8ft%8.8f'#13#10'',m[2][0],m[2][1],m[2][2]); 
  fprintf(stdout,''#13#10''); 
end;
*)

end.
