{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpbase64fpc                                     }
{       Byte-safe Base64 for Free Pascal                }
{                                                       }
{       This file is under the MPL license              }
{       A copy of the license is in the license.txt     }
{       file included with this distribution            }
{                                                       }
{*******************************************************}

// FPC 3.2.2's System.NetEncoding (package vcl-compat) routes
// TNetEncoding.Base64 through UTF-8 strings, so every byte >= $80 is turned
// into '?' both when encoding and when decoding binary data. Report Manager
// keeps images, section backgrounds and binary values as Base64, so the FPC
// build uses these functions instead; Delphi keeps TNetEncoding.Base64.

unit rpbase64fpc;

{$mode delphi}{$H+}

interface

uses
  SysUtils;

// Plain Base64 without line breaks (Delphi's decoder accepts it)
function RpBase64EncodeBytes(const bytes: TBytes): string;
// Line breaks, spaces and padding are ignored, so texts encoded by Delphi
// (76-character lines) decode as well
function RpBase64DecodeBytes(const value: string): TBytes;

implementation

const
  RpBase64Chars: array[0..63] of Char =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function RpBase64EncodeBytes(const bytes: TBytes): string;
var
  i, n, outpos: Integer;
  b: Cardinal;
begin
  n := Length(bytes);
  SetLength(Result, ((n + 2) div 3) * 4);
  outpos := 1;
  i := 0;
  while i < n do
  begin
    b := Cardinal(bytes[i]) shl 16;
    if i + 1 < n then
      b := b or (Cardinal(bytes[i + 1]) shl 8);
    if i + 2 < n then
      b := b or Cardinal(bytes[i + 2]);
    Result[outpos] := RpBase64Chars[(b shr 18) and 63];
    Result[outpos + 1] := RpBase64Chars[(b shr 12) and 63];
    if i + 1 < n then
      Result[outpos + 2] := RpBase64Chars[(b shr 6) and 63]
    else
      Result[outpos + 2] := '=';
    if i + 2 < n then
      Result[outpos + 3] := RpBase64Chars[b and 63]
    else
      Result[outpos + 3] := '=';
    Inc(outpos, 4);
    Inc(i, 3);
  end;
end;

function RpBase64DecodeBytes(const value: string): TBytes;
var
  i, count, len: Integer;
  v, acc: Cardinal;
begin
  Result := nil;
  SetLength(Result, (Length(value) * 3) div 4 + 3);
  len := 0;
  acc := 0;
  count := 0;
  for i := 1 to Length(value) do
  begin
    case value[i] of
      'A'..'Z': v := Ord(value[i]) - Ord('A');
      'a'..'z': v := Ord(value[i]) - Ord('a') + 26;
      '0'..'9': v := Ord(value[i]) - Ord('0') + 52;
      '+': v := 62;
      '/': v := 63;
    else
      Continue;
    end;
    acc := (acc shl 6) or v;
    Inc(count);
    if count = 4 then
    begin
      Result[len] := Byte(acc shr 16);
      Result[len + 1] := Byte(acc shr 8);
      Result[len + 2] := Byte(acc);
      Inc(len, 3);
      acc := 0;
      count := 0;
    end;
  end;
  if count = 3 then
  begin
    Result[len] := Byte(acc shr 10);
    Result[len + 1] := Byte(acc shr 2);
    Inc(len, 2);
  end
  else if count = 2 then
  begin
    Result[len] := Byte(acc shr 4);
    Inc(len);
  end;
  SetLength(Result, len);
end;

end.
