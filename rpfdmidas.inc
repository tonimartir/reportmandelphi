{*******************************************************}
{                                                       }
{   rpfdmidas.inc                                       }
{                                                       }
{   Read / write the MIDAS - MyBase "DATAPACKET 2.0"    }
{   XML format into a FireDAC TFDMemTable, so a         }
{   FireDAC-based build (Linux/Delphi, no libmidas)     }
{   can interchange the same .xml/.cds data files that  }
{   TClientDataSet produces/consumes on Windows.        }
{                                                       }
{   Only the XML DataPacket variant is supported;       }
{   binary MIDAS packets raise a clear exception.       }
{                                                       }
{   This file is meant to be include-directive-included }
{   inside the implementation section of a unit that    }
{   already has in scope: Classes, SysUtils, Variants,  }
{   DB, FireDAC.Comp.DataSet/Client, Generics.Colls,    }
{   Data.FmtBcd, DateUtils, StrUtils, NetEncoding.      }
{*******************************************************}

resourcestring
  SRpMidasNotXML =
    'MyBase data file is not in XML DataPacket format (binary MIDAS packets ' +
    'are not supported on this platform - re-save the source as XML)';
  SRpMidasBadPacket =
    'Not a valid MyBase DataPacket (DATAPACKET/FIELDS not found)';

function RpMidasInv: TFormatSettings;
begin
  Result := TFormatSettings.Invariant;
end;

// ---------- base64 (no line breaks, matching TClientDataSet) --------------
function RpMidasB64Encode(const B: TBytes): string;
var
  enc: TBase64Encoding;
begin
  if Length(B) = 0 then Exit('');
  enc := TBase64Encoding.Create(0); // 0 chars-per-line = no wrapping
  try
    Result := enc.EncodeBytesToString(B);
  finally
    enc.Free;
  end;
end;

function RpMidasB64Decode(const S: string): TBytes;
var
  enc: TBase64Encoding;
begin
  if S = '' then Exit(nil);
  enc := TBase64Encoding.Create(0);
  try
    Result := enc.DecodeStringToBytes(S);
  finally
    enc.Free;
  end;
end;

// ---------- stream -> string (BOM / encoding aware) ----------------------
// Lenient UTF-8 decode: valid sequences decode normally; any byte that is not
// part of a well-formed UTF-8 sequence is taken as ISO-8859-1 (Latin-1), i.e.
// codepoint = byte value. Real-world MyBase exports are frequently declared
// UTF-8 yet carry stray CP1252/Latin-1 bytes (e.g. 0xB0 for the degree sign in
// "5° DITO", 0xA3 for the pound sign). Strict decoding would replace those with
// U+FFFD and silently corrupt the data (on every platform); the Latin-1 fallback
// recovers the intended character instead.
function RpMidasUtf8Lenient(const b: TBytes; AStart, ACount: Integer): string;
var
  sb: TStringBuilder;
  i, last, need, cp, j: Integer;
  ok: Boolean;
begin
  sb := TStringBuilder.Create(ACount);
  try
    i := AStart;
    last := AStart + ACount;
    while i < last do
    begin
      if b[i] < $80 then
      begin
        sb.Append(Char(b[i])); Inc(i);
        Continue;
      end;
      if (b[i] and $E0) = $C0 then begin need := 1; cp := b[i] and $1F; end
      else if (b[i] and $F0) = $E0 then begin need := 2; cp := b[i] and $0F; end
      else if (b[i] and $F8) = $F0 then begin need := 3; cp := b[i] and $07; end
      else begin need := -1; cp := 0; end;
      ok := need > 0;
      if ok then
        for j := 1 to need do
          if (i + j >= last) or ((b[i + j] and $C0) <> $80) then
          begin ok := False; Break; end;
      if ok then
      begin
        for j := 1 to need do
          cp := (cp shl 6) or (b[i + j] and $3F);
        if (cp < $80) or ((cp >= $D800) and (cp <= $DFFF)) or (cp > $10FFFF) then
          ok := False;               // overlong / surrogate / out of range
      end;
      if ok then
      begin
        if cp <= $FFFF then
          sb.Append(Char(cp))
        else
        begin
          Dec(cp, $10000);
          sb.Append(Char($D800 or (cp shr 10)));
          sb.Append(Char($DC00 or (cp and $3FF)));
        end;
        Inc(i, need + 1);
      end
      else
      begin
        sb.Append(Char(b[i]));       // Latin-1 fallback for the offending byte
        Inc(i);
      end;
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function RpMidasStreamToStr(Stream: TStream): string;
var
  b: TBytes;
  n: Integer;
begin
  Stream.Position := 0;
  n := Stream.Size;
  SetLength(b, n);
  if n > 0 then
    Stream.ReadBuffer(b[0], n);
  if (n >= 3) and (b[0] = $EF) and (b[1] = $BB) and (b[2] = $BF) then
    Result := RpMidasUtf8Lenient(b, 3, n - 3)
  else if (n >= 2) and (b[0] = $FF) and (b[1] = $FE) then
    Result := TEncoding.Unicode.GetString(b, 2, n - 2)
  else if (n >= 2) and (b[0] = $FE) and (b[1] = $FF) then
    Result := TEncoding.BigEndianUnicode.GetString(b, 2, n - 2)
  else
    Result := RpMidasUtf8Lenient(b, 0, n);
end;

// ---------- XML entity decode --------------------------------------------
function RpMidasDecode(const S: string): string;
var
  sb: TStringBuilder;
  i, semi, code: Integer;
  ent: string;
begin
  if Pos('&', S) = 0 then
    Exit(S);
  sb := TStringBuilder.Create(Length(S));
  try
    i := 1;
    while i <= Length(S) do
    begin
      if S[i] = '&' then
      begin
        semi := i + 1;
        while (semi <= Length(S)) and (S[semi] <> ';') and (semi - i <= 12) do
          Inc(semi);
        if (semi <= Length(S)) and (S[semi] = ';') then
        begin
          ent := Copy(S, i + 1, semi - i - 1);
          if ent = 'amp' then sb.Append('&')
          else if ent = 'lt' then sb.Append('<')
          else if ent = 'gt' then sb.Append('>')
          else if ent = 'quot' then sb.Append('"')
          else if ent = 'apos' then sb.Append('''')
          else if (Length(ent) >= 2) and (ent[1] = '#') then
          begin
            if (ent[2] = 'x') or (ent[2] = 'X') then
              code := StrToIntDef('$' + Copy(ent, 3, MaxInt), -1)
            else
              code := StrToIntDef(Copy(ent, 2, MaxInt), -1);
            if code >= 0 then sb.Append(Char(code))
            else sb.Append('&').Append(ent).Append(';');
          end
          else
            sb.Append('&').Append(ent).Append(';');
          i := semi + 1;
          Continue;
        end;
      end;
      sb.Append(S[i]);
      Inc(i);
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

// ---------- attribute parser ---------------------------------------------
procedure RpMidasParseAttrs(const AInner: string; ANames, AValues: TStringList);
var
  i, L: Integer;
  nm: string;
  vsb: TStringBuilder;
  q: Char;
begin
  i := 1;
  L := Length(AInner);
  while i <= L do
  begin
    while (i <= L) and (AInner[i] <= ' ') do Inc(i);
    if (i > L) or (AInner[i] = '/') or (AInner[i] = '>') then Break;
    nm := '';
    while (i <= L) and (AInner[i] > ' ') and (AInner[i] <> '=') do
    begin nm := nm + AInner[i]; Inc(i); end;
    while (i <= L) and (AInner[i] <> '=') do Inc(i);
    Inc(i); // '='
    while (i <= L) and (AInner[i] <= ' ') do Inc(i);
    if i > L then Break;
    q := AInner[i];
    Inc(i);
    vsb := TStringBuilder.Create;
    try
      while (i <= L) and (AInner[i] <> q) do
      begin vsb.Append(AInner[i]); Inc(i); end;
      Inc(i); // closing quote
      ANames.Add(nm);
      AValues.Add(RpMidasDecode(vsb.ToString));
    finally
      vsb.Free;
    end;
  end;
end;

// ---------- type mapping (read) ------------------------------------------
// Returns the TFieldType; ASize gets the char size for string/memo types.
function RpMidasTypeToField(const AType, ASubType: string; AWidth: Integer;
  out ASize: Integer): TFieldType;
var
  t: string;
begin
  ASize := 0;
  // MIDAS field types are case-insensitive. Delphi's own TClientDataSet emits
  // them lower-case (r8, i4, fixed) but other producers (e.g. several ERPs)
  // emit them upper-case (R8, I4) -- normalise before matching, otherwise the
  // numeric types silently fall through to ftString.
  t := LowerCase(Trim(AType));
  if (t = 'i1') or (t = 'i2') then Result := ftSmallint
  else if t = 'i4' then Result := ftInteger
  else if t = 'i8' then Result := ftLargeint
  else if t = 'ui1' then Result := ftWord
  else if t = 'ui2' then Result := ftWord
  else if t = 'ui4' then Result := ftLongWord
  else if t = 'r4' then Result := ftSingle
  else if t = 'r8' then
  begin
    if SameText(ASubType, 'Money') then Result := ftCurrency
    else Result := ftFloat;
  end
  else if t = 'fixed' then Result := ftBCD
  else if t = 'fixedfmt' then Result := ftFMTBcd
  else if t = 'boolean' then Result := ftBoolean
  else if t = 'date' then Result := ftDate
  else if t = 'time' then Result := ftTime
  else if t = 'datetime' then Result := ftDateTime
  else if t = 'sqldatetime' then Result := ftTimeStamp
  else if t = 'string' then
  begin Result := ftString; ASize := AWidth; if ASize <= 0 then ASize := 255; end
  else if t = 'string.uni' then
  begin Result := ftWideString; ASize := AWidth div 2; if ASize <= 0 then ASize := 255; end
  else if t = 'bin.hex' then
  begin
    if SameText(ASubType, 'Text') then begin Result := ftMemo; ASize := AWidth; end
    // CDS emits SUBTYPE="WideText" for ftWideMemo; "Text.uni" kept for other producers.
    else if SameText(ASubType, 'WideText') or SameText(ASubType, 'Text.uni') then
      begin Result := ftWideMemo; ASize := AWidth div 2; end
    else if SameText(ASubType, 'Graphics') then Result := ftGraphic
    else Result := ftBlob;
  end
  else
  begin Result := ftString; ASize := AWidth; if ASize <= 0 then ASize := 255; end;
end;

// ---------- value parsing (read) -----------------------------------------
function RpMidasParseDate(const S: string): TDateTime;
begin
  Result := EncodeDate(StrToIntDef(Copy(S, 1, 4), 1),
    StrToIntDef(Copy(S, 5, 2), 1), StrToIntDef(Copy(S, 7, 2), 1));
end;

function RpMidasParseTime(const S: string): TDateTime;
var
  parts: TArray<string>;
  hh, mm, ss, ms: Word;
  sp: string;
begin
  parts := S.Split([':']);
  hh := 0; mm := 0; ss := 0; ms := 0;
  if Length(parts) > 0 then hh := StrToIntDef(parts[0], 0);
  if Length(parts) > 1 then mm := StrToIntDef(parts[1], 0);
  if Length(parts) > 2 then
  begin
    sp := parts[2];
    ss := StrToIntDef(Copy(sp, 1, 2), 0);
    if Length(sp) > 2 then ms := StrToIntDef(Copy(sp, 3, MaxInt), 0);
  end;
  Result := EncodeTime(hh, mm, ss, ms);
end;

function RpMidasParseDateTime(const S: string): TDateTime;
var
  tp: Integer;
begin
  tp := Pos('T', S);
  if tp = 0 then
    Result := RpMidasParseDate(S)
  else
    Result := RpMidasParseDate(Copy(S, 1, tp - 1)) +
      RpMidasParseTime(Copy(S, tp + 1, MaxInt));
end;

procedure RpMidasSetValue(F: TField; const S: string);
var
  i64: Int64;
begin
  case F.DataType of
    ftShortint, ftSmallint, ftInteger, ftAutoInc:
      F.AsInteger := StrToInt(S);
    ftByte:
      F.AsInteger := Byte(StrToInt(S));   // unsigned reinterpret (ui1)
    ftWord:
      F.AsInteger := Word(StrToInt(S));   // unsigned reinterpret (ui2)
    ftLongWord:
      begin i64 := StrToInt64(S); F.AsLargeInt := Cardinal(i64); end; // ui4
    ftLargeint:
      F.AsLargeInt := StrToInt64(S);
    ftSingle, ftFloat:
      F.AsFloat := StrToFloat(S, RpMidasInv);
    ftCurrency:
      F.AsCurrency := StrToFloat(S, RpMidasInv);
    ftBCD, ftFMTBcd:
      F.AsBCD := StrToBcd(S, RpMidasInv);
    ftBoolean:
      F.AsBoolean := SameText(S, 'TRUE') or (S = '1');
    ftDate:
      F.AsDateTime := RpMidasParseDate(S);
    ftTime:
      F.AsDateTime := RpMidasParseTime(S);
    ftDateTime, ftTimeStamp:
      F.AsDateTime := RpMidasParseDateTime(S);
    ftBlob, ftGraphic, ftVarBytes, ftBytes:
      F.AsBytes := RpMidasB64Decode(S);
  else
    F.AsString := S; // string, wide string, memo, wide memo, guid, ...
  end;
end;

// ---------- type mapping (write) -----------------------------------------
// Returns fieldtype; sets ASub (SUBTYPE), AWidth (WIDTH), ADec (DECIMALS, -1 = none).
function RpMidasFieldToType(F: TField; out ASub: string; out AWidth, ADec: Integer): string;
begin
  ASub := '';
  AWidth := 0;
  ADec := -1;
  case F.DataType of
    ftShortint, ftSmallint: Result := 'i2';
    ftByte: Result := 'ui1';
    ftWord: Result := 'ui2';
    ftInteger, ftAutoInc: Result := 'i4';
    ftLongWord: Result := 'ui4';
    ftLargeint: Result := 'i8';
    ftSingle: Result := 'r4';
    ftFloat: Result := 'r8';
    ftCurrency: begin Result := 'r8'; ASub := 'Money'; end;
    ftBCD:
      begin
        Result := 'fixed'; ADec := F.Size;
        if F is TBCDField then AWidth := TBCDField(F).Precision;
      end;
    ftFMTBcd:
      begin
        Result := 'fixedFMT'; ADec := F.Size;
        if F is TFMTBCDField then AWidth := TFMTBCDField(F).Precision;
      end;
    ftBoolean: Result := 'boolean';
    ftDate: Result := 'date';
    ftTime: Result := 'time';
    ftDateTime: Result := 'dateTime';
    ftTimeStamp: begin Result := 'SQLdateTime'; ASub := 'Formatted'; end;
    ftWideString, ftFixedWideChar: begin Result := 'string.uni'; AWidth := F.Size * 2; end;
    ftString, ftFixedChar, ftGuid: begin Result := 'string'; AWidth := F.Size; end;
    ftMemo, ftFmtMemo: begin Result := 'bin.hex'; ASub := 'Text'; AWidth := F.Size; end;
    ftWideMemo: begin Result := 'bin.hex'; ASub := 'WideText'; end;  // CDS uses "WideText"
    ftGraphic: begin Result := 'bin.hex'; ASub := 'Graphics'; end;
    ftBlob: begin Result := 'bin.hex'; ASub := 'Binary'; end;
    ftBytes, ftVarBytes: begin Result := 'bin.hex'; AWidth := F.Size; end;
  else
    begin Result := 'string'; AWidth := F.Size; if AWidth <= 0 then AWidth := 255; end;
  end;
end;

function RpMidasFieldValue(F: TField): string;
begin
  case F.DataType of
    ftBoolean:
      if F.AsBoolean then Result := 'TRUE' else Result := 'FALSE';
    ftDate:
      Result := FormatDateTime('yyyymmdd', F.AsDateTime);
    ftTime:
      Result := FormatDateTime('hh":"nn":"sszzz', F.AsDateTime);
    ftDateTime, ftTimeStamp:
      Result := FormatDateTime('yyyymmdd"T"hh":"nn":"sszzz', F.AsDateTime);
    ftSingle:
      Result := FloatToStrF(F.AsFloat, ffGeneral, 9, 0, RpMidasInv);
    ftFloat:
      Result := FloatToStrF(F.AsFloat, ffGeneral, 17, 0, RpMidasInv);
    ftCurrency:
      Result := FloatToStr(F.AsCurrency, RpMidasInv);
    ftBCD, ftFMTBcd:
      Result := BcdToStr(F.AsBcd, RpMidasInv);
    ftShortint, ftSmallint, ftInteger, ftAutoInc:
      Result := IntToStr(F.AsInteger);
    ftByte:
      Result := IntToStr(ShortInt(F.AsInteger));   // CDS stores ui1 as a signed pattern
    ftWord:
      Result := IntToStr(SmallInt(F.AsInteger));    // ui2 as a signed pattern
    ftLongWord:
      Result := IntToStr(Integer(F.AsLargeInt));    // ui4 as a signed pattern
    ftLargeint:
      Result := IntToStr(F.AsLargeInt);
    ftBlob, ftGraphic, ftVarBytes, ftBytes:
      Result := RpMidasB64Encode(F.AsBytes);
  else
    Result := F.AsString;
  end;
end;

function RpMidasSanitize(const AName: string): string;
var
  i: Integer;
begin
  Result := AName;
  for i := 1 to Length(Result) do
    if not CharInSet(Result[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Result[i] := '_';
  if Result = '' then
    Result := '_';
end;

function RpMidasEscape(const S: string): string;
var
  sb: TStringBuilder;
  i: Integer;
  c: Char;
begin
  sb := TStringBuilder.Create(Length(S));
  try
    for i := 1 to Length(S) do
    begin
      c := S[i];
      case c of
        '&': sb.Append('&amp;');
        '<': sb.Append('&lt;');
        '>': sb.Append('&gt;');
        '"': sb.Append('&quot;');
        #13: sb.Append('&#013;');
        #10: sb.Append('&#010;');
        #9:  sb.Append('&#009;');
      else
        // Encode every non-ASCII UTF-16 code unit as a decimal entity, exactly
        // like TClientDataSet does for string.uni/WideText fields: CDS reads a
        // .uni value as ANSI/entities, so raw UTF-8 bytes there are mis-decoded
        // (n~ -> A±). Entities are also valid inside plain "string" fields, so a
        // single rule keeps every field type readable by CDS. Surrogate pairs
        // emit one entity per half (&#55357;&#56832;), matching CDS.
        if c < ' ' then
          sb.Append('&#').Append(Format('%.3d', [Ord(c)])).Append(';')
        else if c >= #$80 then
          sb.Append('&#').Append(IntToStr(Ord(c))).Append(';')
        else
          sb.Append(c);
      end;
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

// ======================= public procedures ===============================

procedure FDMemLoadFromMidasStream(mem: TFDMemTable; Stream: TStream);
var
  xml, inner, attrName, fieldName, ftype, fsub, realName: string;
  p, tagEnd, fieldsB, fieldsE, rowsB, rowsE, fwidth, fdec, fsize, k: Integer;
  names, values: TStringList;
  attrToReal: TDictionary<string, string>;
  ft: TFieldType;
  fd: TFieldDef;
  F: TField;
begin
  xml := RpMidasStreamToStr(Stream);
  p := 1;
  while (p <= Length(xml)) and (xml[p] <= ' ') do Inc(p);
  if (p > Length(xml)) or (xml[p] <> '<') then
    raise Exception.Create(SRpMidasNotXML);
  fieldsB := Pos('<FIELDS>', xml);
  fieldsE := Pos('</FIELDS>', xml);
  if (Pos('<DATAPACKET', xml) = 0) or (fieldsB = 0) or (fieldsE <= fieldsB) then
    raise Exception.Create(SRpMidasBadPacket);

  names := TStringList.Create;
  values := TStringList.Create;
  attrToReal := TDictionary<string, string>.Create;
  try
    if mem.Active then mem.Close;
    mem.FieldDefs.Clear;
    // ---- FIELDS ----
    p := fieldsB + Length('<FIELDS>');
    while True do
    begin
      p := PosEx('<FIELD', xml, p);
      if (p = 0) or (p >= fieldsE) then Break;
      tagEnd := PosEx('>', xml, p);
      if tagEnd = 0 then Break;
      inner := Copy(xml, p + Length('<FIELD'), tagEnd - (p + Length('<FIELD')));
      names.Clear; values.Clear;
      RpMidasParseAttrs(inner, names, values);
      attrName := ''; fieldName := ''; ftype := ''; fsub := ''; fwidth := 0; fdec := -1;
      for k := 0 to names.Count - 1 do
      begin
        if SameText(names[k], 'attrname') then attrName := values[k]
        else if SameText(names[k], 'fieldname') then fieldName := values[k]
        else if SameText(names[k], 'fieldtype') then ftype := values[k]
        else if SameText(names[k], 'SUBTYPE') then fsub := values[k]
        else if SameText(names[k], 'WIDTH') then fwidth := StrToIntDef(values[k], 0)
        else if SameText(names[k], 'DECIMALS') then fdec := StrToIntDef(values[k], 0);
      end;
      p := tagEnd + 1;
      if attrName = '' then Continue;
      if fieldName = '' then realName := attrName else realName := fieldName;
      ft := RpMidasTypeToField(ftype, fsub, fwidth, fsize);
      fd := mem.FieldDefs.AddFieldDef;
      fd.Name := realName;
      fd.DataType := ft;
      if ft in [ftBCD, ftFMTBcd] then
      begin
        if fwidth > 0 then fd.Precision := fwidth;
        if fdec >= 0 then fd.Size := fdec;
      end
      else if fsize > 0 then
        fd.Size := fsize;
      attrToReal.AddOrSetValue(attrName, realName);
    end;
    if mem.FieldDefs.Count = 0 then
      raise Exception.Create(SRpMidasBadPacket);
    mem.CreateDataSet;
    // ---- ROWDATA ----
    rowsB := Pos('<ROWDATA', xml);
    rowsE := Pos('</ROWDATA>', xml);
    if rowsB > 0 then
    begin
      if rowsE = 0 then rowsE := Length(xml);
      p := rowsB + 1;
      while True do
      begin
        p := PosEx('<ROW', xml, p);
        if (p = 0) or (p >= rowsE) then Break;
        tagEnd := PosEx('>', xml, p);
        if tagEnd = 0 then Break;
        inner := Copy(xml, p + Length('<ROW'), tagEnd - (p + Length('<ROW')));
        names.Clear; values.Clear;
        RpMidasParseAttrs(inner, names, values);
        mem.Append;
        try
          for k := 0 to names.Count - 1 do
          begin
            if SameText(names[k], 'RowState') then Continue;
            if not attrToReal.TryGetValue(names[k], realName) then
              realName := names[k];
            F := mem.FindField(realName);
            if F <> nil then
              RpMidasSetValue(F, values[k]);
          end;
          mem.Post;
        except
          mem.Cancel;
          raise;
        end;
        p := tagEnd + 1;
      end;
    end;
    if mem.Active then mem.First;
  finally
    attrToReal.Free;
    values.Free;
    names.Free;
  end;
end;

procedure FDMemSaveToMidasStream(mem: TFDMemTable; Stream: TStream);
var
  sb: TStringBuilder;
  i: Integer;
  F: TField;
  t, sub: string;
  w, dec: Integer;
  attrs: TArray<string>;
  bm: TBookmark;
  bytes: TBytes;
begin
  sb := TStringBuilder.Create;
  try
    sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>  ');
    sb.Append('<DATAPACKET Version="2.0"><METADATA><FIELDS>');
    SetLength(attrs, mem.Fields.Count);
    for i := 0 to mem.Fields.Count - 1 do
    begin
      F := mem.Fields[i];
      t := RpMidasFieldToType(F, sub, w, dec);
      attrs[i] := RpMidasSanitize(F.FieldName);
      sb.Append('<FIELD');
      if attrs[i] <> F.FieldName then
        sb.Append(' fieldname="').Append(RpMidasEscape(F.FieldName)).Append('"');
      sb.Append(' attrname="').Append(attrs[i]).Append('" fieldtype="').Append(t).Append('"');
      if sub <> '' then
        sb.Append(' SUBTYPE="').Append(sub).Append('"');
      if dec >= 0 then
        sb.Append(' DECIMALS="').Append(dec).Append('"');
      if w > 0 then
        sb.Append(' WIDTH="').Append(w).Append('"');
      sb.Append('/>');
    end;
    sb.Append('</FIELDS><PARAMS/></METADATA><ROWDATA>');
    mem.DisableControls;
    bm := mem.GetBookmark;
    try
      mem.First;
      while not mem.Eof do
      begin
        sb.Append('<ROW');
        for i := 0 to mem.Fields.Count - 1 do
        begin
          F := mem.Fields[i];
          if not F.IsNull then
            sb.Append(' ').Append(attrs[i]).Append('="')
              .Append(RpMidasEscape(RpMidasFieldValue(F))).Append('"');
        end;
        sb.Append('/>');
        mem.Next;
      end;
    finally
      if mem.BookmarkValid(bm) then mem.GotoBookmark(bm);
      mem.FreeBookmark(bm);
      mem.EnableControls;
    end;
    sb.Append('</ROWDATA></DATAPACKET>');
    bytes := TEncoding.UTF8.GetBytes(sb.ToString);
    if Length(bytes) > 0 then
      Stream.WriteBuffer(bytes[0], Length(bytes));
  finally
    sb.Free;
  end;
end;

procedure FDMemLoadFromMidasFile(mem: TFDMemTable; const FileName: string);
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    FDMemLoadFromMidasStream(mem, fs);
  finally
    fs.Free;
  end;
end;

procedure FDMemSaveToMidasFile(mem: TFDMemTable; const FileName: string);
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(FileName, fmCreate);
  try
    FDMemSaveToMidasStream(mem, fs);
  finally
    fs.Free;
  end;
end;
