{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpfastserializer                                }
{                                                       }
{       Pascal port of Reportman.Core/Serializer/       }
{       FastSerializer.cs (C#). The binary format is    }
{       byte-for-byte compatible: a stream produced by  }
{       the C# library is read back here and vice versa.}
{                                                       }
{       Used by the Direct Channel client (Reportman    }
{       Designer + ActiveX) to consume the binary       }
{       DataSet stream sent by the Agent over WebRTC.   }
{                                                       }
{       Layout reminder (little-endian throughout):     }
{                                                       }
{         signature  10 11 12 13      (4 bytes)         }
{         int32      table count                        }
{         per table:                                    }
{            string   name            (len4 + utf8)     }
{            int32    column count                      }
{            per column:                                }
{               int32    type code   (TRpFastTypeData)  }
{               string   name                           }
{            int32    pk column count                   }
{            per pk col: string name                    }
{            int32    row count                         }
{            per row:                                   }
{               per column: WriteValue()                }
{                                                       }
{       WriteValue:                                     }
{         For fixed/length-prefixed types (Int32, Int64,}
{         String, Boolean, Double, Single, Decimal,     }
{         TimeSpan, ByteArray) the first byte is a null }
{         flag: 0 = DBNull, 1 = follows value in the    }
{         BinaryWriter native format.                   }
{                                                       }
{         For encoded-length types (Char, Byte, DateTime}
{         ) the first byte is the length of the payload }
{         that follows (0 = null, else 1..9 bytes).     }
{                                                       }
{       DateTime payload:                               }
{         4 bytes  Year(2) Month(1) Day(1)              }
{         7 bytes  +Hour(1) Min(1) Sec(1)               }
{         9 bytes  +Millisecond(2)                      }
{       Trailing zero bytes are trimmed.                }
{                                                       }
{       Decimal: 16 bytes in .NET native layout: 4 LE   }
{       int32 = lo, mid, hi, flags.                     }
{         flags bits 16..23 = scale (0..28)             }
{         flags bit 31      = sign (negative if set)    }
{       In this Pascal port we represent decimals as    }
{       Currency (Int64 * 10000). Values that overflow  }
{       Currency raise an exception on read.            }
{                                                       }
{       TimeSpan: 8 bytes Int64 ticks (100-ns units),   }
{       same as the .NET TimeSpan.Ticks raw value.      }
{                                                       }
{       KNOWN LIMITATIONS:                              }
{                                                       }
{       1) Empty string vs NULL: Delphi's TStringField  }
{       and TBlobField conflate "NULL" with "empty      }
{       value". A round-trip of an EMPTY (but not NULL) }
{       string or byte array comes back as NULL on the  }
{       Pascal side. SQL queries normally return NULL   }
{       or non-empty, so this rarely matters.           }
{                                                       }
{       2) Currency precision: TClientDataSet stores    }
{       ftCurrency values with limited precision and    }
{       may lose the last few ULPs for very large       }
{       values (>14 significant digits). Decimals       }
{       within the normal SQL NUMERIC range (~14 total  }
{       digits with 4 fractional) round-trip exactly.   }
{       Currency.MaxValue/MinValue (922337203685477.58) }
{       fail because they exceed this practical limit.  }
{                                                       }
{       3) Trailing spaces: TWideStringField trims      }
{       trailing whitespace on Get. SQL data rarely     }
{       relies on trailing space being significant, so  }
{       this usually does not matter.                   }
{                                                       }
{       Copyright (c) 2026 Toni Martir                  }
{       toni@reportman.es                               }
{                                                       }
{       MPL license.                                    }
{                                                       }
{*******************************************************}

unit rpfastserializer;

interface

{$I rpconf.inc}

uses
  SysUtils, Classes, DB, DBClient;

type
  // Wire-level type codes. Order MUST match the C# enum TypeData.
  TRpFastTypeData = (
    fdtChar      = 0,
    fdtString    = 1,
    fdtInt32     = 2,
    fdtInt16     = 3,
    fdtByte      = 4,
    fdtDouble    = 5,
    fdtFloat     = 6,   // C# alias of Single
    fdtDecimal   = 7,
    fdtSingle    = 8,
    fdtByteArray = 9,
    fdtDateTime  = 10,
    fdtInt64     = 11,
    fdtBoolean   = 12,
    fdtObject    = 13,  // not supported in this Pascal port
    fdtTimeSpan  = 14
  );

  ERpFastSerializer = class(Exception);

const
  RP_FAST_SIGNATURE: array[0..3] of Byte = (10, 11, 12, 13);

// ------------------------------------------------------------
// Public entry points
// ------------------------------------------------------------

// Serialize a single TClientDataSet as a DataSet with one table.
// The dataset must have its FieldDefs set and be open (or at least
// have CreateDataSet called).
// The 3-arg overload lets you pass the .NET DataTable.TableName that
// the C# side expects. The 2-arg overload uses ADs.Name (Pascal
// component name) which works when the dataset's component name is
// already what you want on the wire.
procedure FastSerializeDataSet(ADs: TClientDataSet;
                               AStream: TStream); overload;
procedure FastSerializeDataSet(ADs: TClientDataSet; AStream: TStream;
                               const ATableName: string); overload;

// Deserialize a stream produced by C# FastSerializer.SerializeDataSet or
// by this unit's FastSerializeDataSet. Repopulates ADs with all columns +
// rows. ADs is closed and re-created internally.
// The overload with out param returns the table name from the wire,
// which is needed for byte-exact reserialization.
procedure FastDeserializeDataSet(ADs: TClientDataSet;
                                 AStream: TStream); overload;
procedure FastDeserializeDataSet(ADs: TClientDataSet; AStream: TStream;
                                 out ATableName: string); overload;

// Returns True if the first 4 bytes look like a FastSerializer header.
function IsFastSerialized(const ABytes: TBytes): Boolean;

// Map a TFieldType to the wire type code. Exposed so tests can build
// fixtures.
function FieldTypeToFastType(AFieldType: TFieldType): TRpFastTypeData;

// Inverse mapping used while deserializing.
function FastTypeToFieldType(AType: TRpFastTypeData): TFieldType;

implementation

uses
  Variants, DateUtils;

// ------------------------------------------------------------
// Low-level primitive readers/writers (all little-endian).
// .NET BinaryReader/BinaryWriter on x86/x64 use LE, which matches
// Delphi's native layout, but we never trust struct alignment - we
// always emit/consume byte-by-byte to stay bit-exact.
// ------------------------------------------------------------

procedure WriteByteRaw(AStream: TStream; AValue: Byte);
begin
  AStream.WriteBuffer(AValue, 1);
end;

function ReadByteRaw(AStream: TStream): Byte;
begin
  AStream.ReadBuffer(Result, 1);
end;

procedure WriteInt16LE(AStream: TStream; AValue: SmallInt);
var
  b: array[0..1] of Byte;
begin
  b[0] := Byte(AValue);
  b[1] := Byte(AValue shr 8);
  AStream.WriteBuffer(b, 2);
end;

function ReadInt16LE(AStream: TStream): SmallInt;
var
  b: array[0..1] of Byte;
begin
  AStream.ReadBuffer(b, 2);
  Result := SmallInt(Word(b[0]) or (Word(b[1]) shl 8));
end;

procedure WriteInt32LE(AStream: TStream; AValue: Integer);
var
  b: array[0..3] of Byte;
begin
  b[0] := Byte(AValue);
  b[1] := Byte(AValue shr 8);
  b[2] := Byte(AValue shr 16);
  b[3] := Byte(AValue shr 24);
  AStream.WriteBuffer(b, 4);
end;

function ReadInt32LE(AStream: TStream): Integer;
var
  b: array[0..3] of Byte;
begin
  AStream.ReadBuffer(b, 4);
  Result := Integer(Cardinal(b[0]) or
                    (Cardinal(b[1]) shl 8) or
                    (Cardinal(b[2]) shl 16) or
                    (Cardinal(b[3]) shl 24));
end;

procedure WriteInt64LE(AStream: TStream; AValue: Int64);
var
  b: array[0..7] of Byte;
  i: Integer;
  v: UInt64;
begin
  v := UInt64(AValue);
  for i := 0 to 7 do
  begin
    b[i] := Byte(v);
    v := v shr 8;
  end;
  AStream.WriteBuffer(b, 8);
end;

function ReadInt64LE(AStream: TStream): Int64;
var
  b: array[0..7] of Byte;
  v: UInt64;
  i: Integer;
begin
  AStream.ReadBuffer(b, 8);
  v := 0;
  for i := 7 downto 0 do
    v := (v shl 8) or Cardinal(b[i]);
  Result := Int64(v);
end;

procedure WriteDoubleLE(AStream: TStream; AValue: Double);
begin
  // Delphi Double matches IEEE 754 binary64 on x86/x64 little-endian.
  // Write raw bytes - same wire format as .NET BinaryWriter.Write(double).
  AStream.WriteBuffer(AValue, SizeOf(Double));
end;

function ReadDoubleLE(AStream: TStream): Double;
begin
  AStream.ReadBuffer(Result, SizeOf(Double));
end;

procedure WriteSingleLE(AStream: TStream; AValue: Single);
begin
  AStream.WriteBuffer(AValue, SizeOf(Single));
end;

function ReadSingleLE(AStream: TStream): Single;
begin
  AStream.ReadBuffer(Result, SizeOf(Single));
end;

// ------------------------------------------------------------
// String (UTF-8, length-prefixed int32).
// ------------------------------------------------------------

procedure WriteFastString(AStream: TStream; const AValue: string);
var
  utf8: TBytes;
begin
  utf8 := TEncoding.UTF8.GetBytes(AValue);
  WriteInt32LE(AStream, Length(utf8));
  if Length(utf8) > 0 then
    AStream.WriteBuffer(utf8[0], Length(utf8));
end;

function ReadFastString(AStream: TStream): string;
var
  len: Integer;
  utf8: TBytes;
begin
  len := ReadInt32LE(AStream);
  if len < 0 then
    raise ERpFastSerializer.CreateFmt(
      'Negative string length %d', [len]);
  if len = 0 then
  begin
    Result := '';
    Exit;
  end;
  SetLength(utf8, len);
  AStream.ReadBuffer(utf8[0], len);
  Result := TEncoding.UTF8.GetString(utf8);
end;

// ------------------------------------------------------------
// .NET Decimal (16 bytes: lo, mid, hi, flags) <-> Currency.
//
// .NET layout:
//   value = sign * (hi:mid:lo) * 10^(-scale)
//   flags bit 31     = sign (negative if set)
//   flags bits 16-23 = scale (0..28)
//
// Currency is Int64 with 4 implicit decimal places. We scale the
// mantissa to 4 decimals before fitting into the Int64.
// ------------------------------------------------------------

procedure WriteDotnetDecimalAsCurrency(AStream: TStream; AValue: Currency);
var
  raw: Int64;       // currency raw = value * 10000
  mantissa: UInt64; // absolute value of raw
  flags: Cardinal;
begin
  raw := PInt64(@AValue)^;
  if raw = 0 then
  begin
    // Match C# `0m` literal which uses scale=0 (all 16 bytes zero).
    // C# `0.0000m` would use scale=4, but Currency does not preserve
    // the original scale - we always read back as scale 4 - so we
    // pick the most common form here.
    WriteInt32LE(AStream, 0); // lo
    WriteInt32LE(AStream, 0); // mid
    WriteInt32LE(AStream, 0); // hi
    WriteInt32LE(AStream, 0); // flags (scale=0, no sign)
    Exit;
  end;

  if raw < 0 then
  begin
    mantissa := UInt64(-raw);
    flags := $80000000 or (Cardinal(4) shl 16); // sign + scale=4
  end
  else
  begin
    mantissa := UInt64(raw);
    flags := Cardinal(4) shl 16;                 // scale=4
  end;

  // lo + mid + hi=0 + flags
  WriteInt32LE(AStream, Integer(Cardinal(mantissa and $FFFFFFFF)));
  WriteInt32LE(AStream, Integer(Cardinal((mantissa shr 32) and $FFFFFFFF)));
  WriteInt32LE(AStream, 0);  // hi (Currency can't reach beyond 64-bit)
  WriteInt32LE(AStream, Integer(flags));
end;

function ReadDotnetDecimalAsCurrency(AStream: TStream): Currency;
var
  lo, mid, hi, flags: Cardinal;
  mantissa: UInt64;
  scale: Integer;
  isNegative: Boolean;
  divisor, multiplier: Int64;
  i: Integer;
  raw: Int64;
begin
  lo    := Cardinal(ReadInt32LE(AStream));
  mid   := Cardinal(ReadInt32LE(AStream));
  hi    := Cardinal(ReadInt32LE(AStream));
  flags := Cardinal(ReadInt32LE(AStream));

  if hi <> 0 then
    raise ERpFastSerializer.Create(
      'Decimal value exceeds 64-bit mantissa, cannot fit in Currency');

  mantissa   := UInt64(lo) or (UInt64(mid) shl 32);
  scale      := (flags shr 16) and $1F;
  isNegative := (flags and $80000000) <> 0;

  if scale > 28 then
    raise ERpFastSerializer.CreateFmt('Invalid decimal scale %d', [scale]);

  // Bring mantissa to scale=4 (Currency convention).
  if scale > 4 then
  begin
    // Too many decimals: divide. We lose precision beyond 4 places.
    divisor := 1;
    for i := 1 to scale - 4 do
      divisor := divisor * 10;
    mantissa := mantissa div UInt64(divisor);
  end
  else if scale < 4 then
  begin
    // Fewer decimals: multiply.
    multiplier := 1;
    for i := 1 to 4 - scale do
      multiplier := multiplier * 10;
    mantissa := mantissa * UInt64(multiplier);
  end;

  if mantissa > UInt64(High(Int64)) then
    raise ERpFastSerializer.Create(
      'Decimal value too large to fit in Currency');

  raw := Int64(mantissa);
  if isNegative then
    raw := -raw;

  PInt64(@Result)^ := raw;
end;

// ------------------------------------------------------------
// DateTime <-> TDateTime
//
// Payload of N bytes (1..9 after stripping the leading null/length byte):
//   1..3   not used (DateTime always has at least year+month+day = 4)
//   4      year(2 LE) + month(1) + day(1)
//   5..6   + hour(1) [+ min(1)]
//   7      + sec(1) -> full HH:MM:SS
//   8      + millisecond_low(1)  (uncommon C# path)
//   9      + millisecond(2 LE)
// ------------------------------------------------------------

function EncodeDateTimePayload(AValue: TDateTime; out APayload: TBytes): Integer;
var
  Y, M, D, H, N, S, MS: Word;
  ax: array[0..1] of Byte;
begin
  DecodeDate(AValue, Y, M, D);
  DecodeTime(AValue, H, N, S, MS);

  if (H = 0) and (N = 0) and (S = 0) and (MS = 0) then
    SetLength(APayload, 4)
  else if MS = 0 then
    SetLength(APayload, 7)
  else
    SetLength(APayload, 9);

  ax[0] := Byte(Y);
  ax[1] := Byte(Y shr 8);
  APayload[0] := ax[0];
  APayload[1] := ax[1];
  APayload[2] := Byte(M);
  APayload[3] := Byte(D);

  if Length(APayload) > 4 then
  begin
    APayload[4] := Byte(H);
    APayload[5] := Byte(N);
    APayload[6] := Byte(S);
  end;

  if Length(APayload) > 7 then
  begin
    APayload[7] := Byte(MS);
    APayload[8] := Byte(MS shr 8);
  end;

  // The C# writer further trims trailing zero bytes (so a midnight
  // DateTime where day is high-byte-zero would be shorter). Mirror
  // that exactly.
  Result := Length(APayload);
  while (Result > 1) and (APayload[Result - 1] = 0) do
    Dec(Result);
end;

function DecodeDateTimePayload(const APayload: TBytes; ALen: Integer): TDateTime;
var
  Y, M, D, H, N, S, MS: Word;
begin
  if ALen < 4 then
    raise ERpFastSerializer.CreateFmt(
      'DateTime payload too short (%d bytes)', [ALen]);

  Y := Word(APayload[0]) or (Word(APayload[1]) shl 8);
  M := APayload[2];
  D := APayload[3];
  H := 0; N := 0; S := 0; MS := 0;

  if ALen > 4 then H := APayload[4];
  if ALen > 5 then N := APayload[5];
  if ALen > 6 then S := APayload[6];
  if ALen = 8 then
    MS := APayload[7]
  else if ALen > 8 then
    MS := Word(APayload[7]) or (Word(APayload[8]) shl 8);

  Result := EncodeDate(Y, M, D);
  if (H <> 0) or (N <> 0) or (S <> 0) or (MS <> 0) then
    Result := Result + EncodeTime(H, N, S, MS);
end;

// ------------------------------------------------------------
// Field type mapping
// ------------------------------------------------------------

function FieldTypeToFastType(AFieldType: TFieldType): TRpFastTypeData;
begin
  case AFieldType of
    ftSmallint:                       Result := fdtInt16;
    ftInteger, ftAutoInc:             Result := fdtInt32;
    ftLargeint:                       Result := fdtInt64;
    ftWord:                           Result := fdtInt16;
    ftBoolean:                        Result := fdtBoolean;
    ftFloat, ftFMTBcd:                Result := fdtDouble;
    ftSingle:                         Result := fdtSingle;
    ftCurrency, ftBCD:                Result := fdtDecimal;
    ftDate, ftTime, ftDateTime,
    ftTimeStamp:                      Result := fdtDateTime;
    ftString, ftWideString,
    ftFixedChar, ftFixedWideChar,
    ftMemo, ftWideMemo,
    ftFmtMemo:                        Result := fdtString;
    ftBytes, ftVarBytes, ftBlob,
    ftGraphic, ftStream:              Result := fdtByteArray;
    ftByte:                           Result := fdtByte;
  else
    raise ERpFastSerializer.CreateFmt(
      'Unsupported TFieldType %d for FastSerializer', [Ord(AFieldType)]);
  end;
end;

function FastTypeToFieldType(AType: TRpFastTypeData): TFieldType;
begin
  case AType of
    fdtChar:      Result := ftFixedChar;
    fdtString:    Result := ftWideString;
    fdtInt32:     Result := ftInteger;
    fdtInt16:     Result := ftSmallint;
    fdtByte:      Result := ftByte;
    fdtDouble:    Result := ftFloat;
    fdtFloat:     Result := ftSingle;
    fdtDecimal:   Result := ftCurrency;
    fdtSingle:    Result := ftSingle;
    fdtByteArray: Result := ftBlob;
    fdtDateTime:  Result := ftDateTime;
    fdtInt64:     Result := ftLargeint;
    fdtBoolean:   Result := ftBoolean;
    fdtTimeSpan:  Result := ftLargeint;  // wire: 8-byte ticks
  else
    raise ERpFastSerializer.CreateFmt(
      'Unsupported FastSerializer type code %d', [Ord(AType)]);
  end;
end;

// ------------------------------------------------------------
// WriteValue / ReadValue
// ------------------------------------------------------------

procedure WriteValue(AStream: TStream; AField: TField;
                    AType: TRpFastTypeData);
var
  payload: TBytes;
  payloadLen: Integer;
  s: string;
  blob: TBytes;
  ch: Char;
  blobStream: TStream;
begin
  // NULL flag handling. For fixed-prefix types, '0' = null and we stop.
  // For encoded-length types (Char/Byte/DateTime), the leading byte IS
  // the length and the same value of 0 means null (length-zero payload).
  if AField.IsNull then
  begin
    WriteByteRaw(AStream, 0);
    Exit;
  end;

  case AType of
    fdtInt32:
      begin
        WriteByteRaw(AStream, 1);
        WriteInt32LE(AStream, AField.AsInteger);
      end;
    fdtInt64:
      begin
        WriteByteRaw(AStream, 1);
        WriteInt64LE(AStream, AField.AsLargeInt);
      end;
    fdtInt16:
      begin
        WriteByteRaw(AStream, 1);
        WriteInt16LE(AStream, SmallInt(AField.AsInteger));
      end;
    fdtBoolean:
      begin
        WriteByteRaw(AStream, 1);
        if AField.AsBoolean then
          WriteByteRaw(AStream, 1)
        else
          WriteByteRaw(AStream, 0);
      end;
    fdtDouble:
      begin
        WriteByteRaw(AStream, 1);
        WriteDoubleLE(AStream, AField.AsFloat);
      end;
    fdtFloat, fdtSingle:
      begin
        WriteByteRaw(AStream, 1);
        WriteSingleLE(AStream, Single(AField.AsFloat));
      end;
    fdtDecimal:
      begin
        WriteByteRaw(AStream, 1);
        WriteDotnetDecimalAsCurrency(AStream, AField.AsCurrency);
      end;
    fdtTimeSpan:
      begin
        WriteByteRaw(AStream, 1);
        // Wire format: 8 bytes Int64 ticks (100ns). For our Pascal
        // representation as ftLargeint, the AsLargeInt IS the tick value.
        WriteInt64LE(AStream, AField.AsLargeInt);
      end;
    fdtString:
      begin
        WriteByteRaw(AStream, 1);
        s := AField.AsString;
        WriteFastString(AStream, s);
      end;
    fdtByteArray:
      begin
        WriteByteRaw(AStream, 1);
        if AField is TBlobField then
        begin
          blobStream := TBlobField(AField).DataSet.CreateBlobStream(
            AField, bmRead);
          try
            SetLength(blob, blobStream.Size);
            if blobStream.Size > 0 then
              blobStream.ReadBuffer(blob[0], blobStream.Size);
          finally
            blobStream.Free;
          end;
        end
        else
          blob := AField.AsBytes;
        WriteInt32LE(AStream, Length(blob));
        if Length(blob) > 0 then
          AStream.WriteBuffer(blob[0], Length(blob));
      end;
    fdtChar:
      begin
        // 1 byte length + 1..2 bytes UTF-16 codepoint (low byte first).
        // Trim trailing zero.
        SetLength(payload, 2);
        s := AField.AsString;
        if s = '' then
          ch := #0
        else
          ch := s[1];
        payload[0] := Byte(Word(ch));
        payload[1] := Byte(Word(ch) shr 8);
        payloadLen := 2;
        while (payloadLen > 1) and (payload[payloadLen - 1] = 0) do
          Dec(payloadLen);
        WriteByteRaw(AStream, payloadLen);
        AStream.WriteBuffer(payload[0], payloadLen);
      end;
    fdtByte:
      begin
        WriteByteRaw(AStream, 1);  // payload length
        WriteByteRaw(AStream, Byte(AField.AsInteger));
      end;
    fdtDateTime:
      begin
        payloadLen := EncodeDateTimePayload(AField.AsDateTime, payload);
        WriteByteRaw(AStream, payloadLen);
        AStream.WriteBuffer(payload[0], payloadLen);
      end;
  else
    raise ERpFastSerializer.CreateFmt(
      'WriteValue: unsupported type %d', [Ord(AType)]);
  end;
end;

procedure ReadValue(AStream: TStream; AField: TField; AType: TRpFastTypeData);
var
  nlen: Byte;
  payload: TBytes;
  blob: TBytes;
  blobStream: TStream;
  dt: TDateTime;
  ch: WideChar;
  shortBytes: array[0..1] of Byte;
begin
  nlen := ReadByteRaw(AStream);
  if nlen = 0 then
  begin
    AField.Clear;
    Exit;
  end;

  case AType of
    fdtInt32:
      AField.AsInteger := ReadInt32LE(AStream);
    fdtInt64:
      AField.AsLargeInt := ReadInt64LE(AStream);
    fdtInt16:
      AField.AsInteger := ReadInt16LE(AStream);
    fdtBoolean:
      AField.AsBoolean := ReadByteRaw(AStream) <> 0;
    fdtDouble:
      AField.AsFloat := ReadDoubleLE(AStream);
    fdtFloat, fdtSingle:
      AField.AsFloat := ReadSingleLE(AStream);
    fdtDecimal:
      AField.AsCurrency := ReadDotnetDecimalAsCurrency(AStream);
    fdtTimeSpan:
      AField.AsLargeInt := ReadInt64LE(AStream);
    fdtString:
      AField.AsString := ReadFastString(AStream);
    fdtByteArray:
      begin
        SetLength(blob, ReadInt32LE(AStream));
        if Length(blob) > 0 then
          AStream.ReadBuffer(blob[0], Length(blob));
        if AField is TBlobField then
        begin
          blobStream := TBlobField(AField).DataSet.CreateBlobStream(
            AField, bmWrite);
          try
            if Length(blob) > 0 then
              blobStream.WriteBuffer(blob[0], Length(blob));
          finally
            blobStream.Free;
          end;
        end
        else
          AField.AsBytes := blob;
      end;
    fdtChar:
      begin
        shortBytes[0] := 0; shortBytes[1] := 0;
        AStream.ReadBuffer(shortBytes[0], nlen);
        ch := WideChar(Word(shortBytes[0]) or (Word(shortBytes[1]) shl 8));
        AField.AsString := string(ch);
      end;
    fdtByte:
      AField.AsInteger := ReadByteRaw(AStream);
    fdtDateTime:
      begin
        SetLength(payload, nlen);
        AStream.ReadBuffer(payload[0], nlen);
        dt := DecodeDateTimePayload(payload, nlen);
        AField.AsDateTime := dt;
      end;
  else
    raise ERpFastSerializer.CreateFmt(
      'ReadValue: unsupported type %d', [Ord(AType)]);
  end;
end;

// ------------------------------------------------------------
// Public API
// ------------------------------------------------------------

function IsFastSerialized(const ABytes: TBytes): Boolean;
begin
  Result := (Length(ABytes) >= 8) and
            (ABytes[0] = RP_FAST_SIGNATURE[0]) and
            (ABytes[1] = RP_FAST_SIGNATURE[1]) and
            (ABytes[2] = RP_FAST_SIGNATURE[2]) and
            (ABytes[3] = RP_FAST_SIGNATURE[3]);
end;

procedure FastSerializeDataSet(ADs: TClientDataSet; AStream: TStream);
begin
  FastSerializeDataSet(ADs, AStream, ADs.Name);
end;

procedure FastSerializeDataSet(ADs: TClientDataSet; AStream: TStream;
                               const ATableName: string);
var
  i, colCount: Integer;
  colTypes: array of TRpFastTypeData;
  rowCount: Integer;
  bookmark: TBookmark;
begin
  if ADs = nil then
    raise ERpFastSerializer.Create('Dataset is nil');
  if not ADs.Active then
    raise ERpFastSerializer.Create(
      'Dataset must be open before serializing');

  // Header.
  AStream.WriteBuffer(RP_FAST_SIGNATURE[0], 4);
  WriteInt32LE(AStream, 1);  // exactly one table per dataset for our use

  WriteFastString(AStream, ATableName);

  // Columns. If the field was originally deserialized by this unit, its
  // Tag holds the exact wire type code (encoded as Ord+1 so the default
  // value 0 means "unknown"). That recovers the C# TypeData that gets
  // mapped to an ambiguous Pascal TFieldType - e.g. fdtTimeSpan and
  // fdtInt64 both become ftLargeint, and fdtFloat / fdtSingle both
  // become ftSingle.
  colCount := ADs.FieldCount;
  WriteInt32LE(AStream, colCount);
  SetLength(colTypes, colCount);
  for i := 0 to colCount - 1 do
  begin
    if ADs.Fields[i].Tag > 0 then
      colTypes[i] := TRpFastTypeData(ADs.Fields[i].Tag - 1)
    else
      colTypes[i] := FieldTypeToFastType(ADs.Fields[i].DataType);
    WriteInt32LE(AStream, Ord(colTypes[i]));
    WriteFastString(AStream, ADs.Fields[i].FieldName);
  end;

  // No primary-key handling on the Pascal side - emit 0 columns.
  WriteInt32LE(AStream, 0);

  // Row count + rows. We have to walk the dataset; remember the cursor.
  rowCount := ADs.RecordCount;
  WriteInt32LE(AStream, rowCount);

  bookmark := ADs.GetBookmark;
  try
    ADs.DisableControls;
    try
      ADs.First;
      while not ADs.Eof do
      begin
        for i := 0 to colCount - 1 do
          WriteValue(AStream, ADs.Fields[i], colTypes[i]);
        ADs.Next;
      end;
    finally
      ADs.EnableControls;
    end;
  finally
    if Assigned(bookmark) then
    begin
      if ADs.BookmarkValid(bookmark) then
        ADs.GotoBookmark(bookmark);
      ADs.FreeBookmark(bookmark);
    end;
  end;
end;

procedure FastDeserializeDataSet(ADs: TClientDataSet; AStream: TStream);
var
  dummyName: string;
begin
  FastDeserializeDataSet(ADs, AStream, dummyName);
end;

procedure FastDeserializeDataSet(ADs: TClientDataSet; AStream: TStream;
                                 out ATableName: string);
var
  sig: array[0..3] of Byte;
  tableCount, colCount, rowCount, primCount: Integer;
  versionFormat: Integer;
  i, j: Integer;
  colTypes: array of TRpFastTypeData;
  colNames: array of string;
  rawType: Integer;
  pkName: string;
begin
  if ADs = nil then
    raise ERpFastSerializer.Create('Dataset is nil');

  // Header.
  AStream.ReadBuffer(sig[0], 4);
  if (sig[0] <> RP_FAST_SIGNATURE[0]) or
     (sig[1] <> RP_FAST_SIGNATURE[1]) or
     (sig[2] <> RP_FAST_SIGNATURE[2]) then
    raise ERpFastSerializer.Create('Bad FastSerializer signature');
  versionFormat := sig[3] - RP_FAST_SIGNATURE[3];
  if versionFormat < 0 then
    raise ERpFastSerializer.Create('Unsupported FastSerializer version');

  tableCount := ReadInt32LE(AStream);
  if tableCount <> 1 then
    raise ERpFastSerializer.CreateFmt(
      'Only one-table datasets supported, got %d', [tableCount]);

  ATableName := ReadFastString(AStream);

  // Columns.
  colCount := ReadInt32LE(AStream);
  if colCount < 0 then
    raise ERpFastSerializer.CreateFmt(
      'Negative column count %d', [colCount]);
  SetLength(colTypes, colCount);
  SetLength(colNames, colCount);

  ADs.Close;
  ADs.FieldDefs.Clear;

  for i := 0 to colCount - 1 do
  begin
    rawType := ReadInt32LE(AStream);
    if (rawType < 0) or (rawType > Ord(High(TRpFastTypeData))) then
      raise ERpFastSerializer.CreateFmt(
        'Unknown column type code %d at column %d', [rawType, i]);
    colTypes[i] := TRpFastTypeData(rawType);
    colNames[i] := ReadFastString(AStream);
    with ADs.FieldDefs.AddFieldDef do
    begin
      Name := colNames[i];
      DataType := FastTypeToFieldType(colTypes[i]);
      // Strings need an explicit size or TClientDataSet rejects them.
      if DataType in [ftString, ftWideString, ftFixedChar, ftFixedWideChar] then
        Size := 1024;
    end;
  end;

  // Primary key columns - we read and ignore (TClientDataSet would need
  // an explicit IndexDef, out of scope for this codec).
  primCount := ReadInt32LE(AStream);
  if primCount < 0 then
    raise ERpFastSerializer.Create('Negative primary key count');
  for i := 0 to primCount - 1 do
    pkName := ReadFastString(AStream);  // unused

  ADs.CreateDataSet;

  // Stash the original wire type into each Field.Tag so a subsequent
  // re-serialization can emit the exact same type code (see comment in
  // FastSerializeDataSet). Tag uses Ord+1 to keep 0 as "unset".
  for i := 0 to colCount - 1 do
    ADs.Fields[i].Tag := Ord(colTypes[i]) + 1;

  ADs.DisableControls;
  try
    rowCount := ReadInt32LE(AStream);
    if rowCount < 0 then
      raise ERpFastSerializer.CreateFmt(
        'Negative row count %d', [rowCount]);

    for i := 0 to rowCount - 1 do
    begin
      ADs.Append;
      for j := 0 to colCount - 1 do
        ReadValue(AStream, ADs.Fields[j], colTypes[j]);
      ADs.Post;
      // If a future version of the wire format added a per-row state
      // byte (versionFormat > 0), consume it here. The C# code does
      // ReadValue(.., TypeData.Byte) and ignores the value.
      if versionFormat > 0 then
        ReadByteRaw(AStream);
    end;
  finally
    ADs.EnableControls;
  end;
  ADs.First;
end;

end.
