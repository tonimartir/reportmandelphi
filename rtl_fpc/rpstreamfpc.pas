{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpstreamfpc                                     }
{       Streaming of components for FPC                 }
{                                                       }
{       This file is under the MPL license              }
{       A copy of the license is in the license.txt     }
{       file included with this distribution            }
{                                                       }
{*******************************************************}

// Fixes of the component streaming of FPC 3.2.2 used by the reports:
//
// - TBinaryObjectWriter.WriteCurrency writes qword(Value), that is the value
//   truncated to an integer, and ReadCurrency converts the integer back:
//   1234.5678 was saved as 1234 in every stream format, and the currency of
//   a report saved by Delphi (the Int64 of value * 10000, as the FPC driver
//   would too without the conversion) was read 10000 times bigger. TRpReader
//   and TRpWriter (and RpWriteComponent) use drivers that write and read the
//   Int64, as Delphi.
// - The text stream format of the reports (rpStreamText, the default) is the
//   text form of the streamed components. ObjectBinaryToText raises on Null,
//   Single, Currency and Date values (vaNull, vaSingle, vaCurrency, vaDate),
//   so a report with a parameter without value (every new parameter) could
//   not be saved, and writes the non ASCII characters of string properties
//   byte by byte (#195#177 for an n with tilde), so they came back wrong.
//   ObjectTextToBinary reads Null as an identifier and the typed floats
//   (1.5s, 12345678c, 45000d) as Extended. RpObjectBinaryToText and
//   RpObjectTextToBinary keep those values and write the characters as
//   Unicode codes, as Delphi does, so the files are read by both.
// - RpObjectBinaryToText breaks a long string every 64 characters (' +' and a
//   new line), as ObjectBinaryToText of Delphi does: TParser of Delphi reads
//   the text in a buffer of 4096 bytes and does not read a longer line ("Line
//   too long"), so a report with a long SQL or text saved by FPC could not be
//   opened by Delphi.
// - TBinaryObjectWriter.WriteString writes the bytes of a string property as
//   they are (vaString), which in an LCL program are UTF-8, and Delphi reads a
//   vaString with the ANSI code page: the characters of a report saved in the
//   binary or zlib formats came out wrong in Delphi. TRpBinaryObjectWriter
//   writes them as TWriter.WriteString of Delphi: ASCII as vaString, else
//   vaUTF8String when UTF-8 is shorter than UTF-16, vaWString otherwise; the
//   TReader of FPC reads the three.

unit rpstreamfpc;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils;

type
  TRpBinaryObjectReader = class(TBinaryObjectReader)
  public
    function ReadCurrency: Currency; override;
  end;

  TRpBinaryObjectWriter = class(TBinaryObjectWriter)
  public
    procedure WriteCurrency(const Value: Currency); override;
    // A string in the code page of the program, as Delphi writes a string
    procedure WriteString(const Value: String); override;
    // The bytes of a string as they are (vaString, vaLString)
    procedure WriteRawString(const Value: String);
  end;

  TRpReader = class(TReader)
  protected
    function CreateDriver(Stream: TStream; BufSize: Integer): TAbstractObjectReader; override;
  end;

  TRpWriter = class(TWriter)
  protected
    function CreateDriver(Stream: TStream; BufSize: Integer): TAbstractObjectWriter; override;
  end;

// TStream.WriteComponent with TRpBinaryObjectWriter
procedure RpWriteComponent(AStream: TStream; AComponent: TComponent);
procedure RpObjectBinaryToText(Input, Output: TStream);
procedure RpObjectTextToBinary(Input, Output: TStream);

implementation

{ TRpBinaryObjectReader }

function TRpBinaryObjectReader.ReadCurrency: Currency;
var
  q: Int64;
begin
  q := 0;
  Read(q, SizeOf(q));
  q := LEtoN(q);
  Result := PCurrency(@q)^;
end;

{ TRpBinaryObjectWriter }

procedure TRpBinaryObjectWriter.WriteCurrency(const Value: Currency);
var
  q: Int64;
begin
  WriteValue(vaCurrency);
  q := NtoLE(PInt64(@Value)^);
  Write(q, SizeOf(q));
end;

procedure TRpBinaryObjectWriter.WriteString(const Value: String);
var
  i: Integer;
  w: UnicodeString;
  u: RawByteString;
begin
  i := 1;
  while (i <= Length(Value)) and (Ord(Value[i]) < 128) do
    Inc(i);
  if i > Length(Value) then
  begin
    // ASCII: vaString or vaLString
    inherited WriteString(Value);
    Exit;
  end;
  // From the code page of the string (the one of the program: UTF-8 in the
  // LCL), as Delphi: UTF-8 when it is shorter than UTF-16
  w := UnicodeString(Value);
  u := UTF8Encode(w);
  if Length(u) < Length(w) * 2 then
  begin
    WriteValue(vaUTF8String);
    WriteDWord(LongWord(Length(u)));
    Write(u[1], Length(u));
  end
  else
    WriteWideString(w);
end;

procedure TRpBinaryObjectWriter.WriteRawString(const Value: String);
begin
  inherited WriteString(Value);
end;

{ TRpReader }

function TRpReader.CreateDriver(Stream: TStream; BufSize: Integer): TAbstractObjectReader;
begin
  Result := TRpBinaryObjectReader.Create(Stream, BufSize);
end;

{ TRpWriter }

function TRpWriter.CreateDriver(Stream: TStream; BufSize: Integer): TAbstractObjectWriter;
begin
  Result := TRpBinaryObjectWriter.Create(Stream, BufSize);
end;

procedure RpWriteComponent(AStream: TStream; AComponent: TComponent);
var
  driver: TAbstractObjectWriter;
  writer: TWriter;
begin
  // As TStream.WriteDescendent(AComponent, nil)
  driver := TRpBinaryObjectWriter.Create(AStream, 4096);
  try
    writer := TWriter.Create(driver);
    try
      writer.WriteDescendent(AComponent, nil);
    finally
      writer.Free;
    end;
  finally
    driver.Free;
  end;
end;

var
  InvariantFormat: TFormatSettings;

procedure RpObjectBinaryToText(Input, Output: TStream);
var
  reader: TRpBinaryObjectReader;

  procedure OutStr(const s: string);
  begin
    if Length(s) > 0 then
      Output.WriteBuffer(s[1], Length(s));
  end;

  procedure OutLn(const s: string);
  begin
    OutStr(s + LineEnding);
  end;

  // As ObjectBinaryToText of Delphi writes a string: the printable ASCII
  // quoted, every other UTF-16 code unit (the quote too) as #code, and a
  // line break (' +') every 64 code units, on lines indented one level more
  // than the property; a string longer than that starts on a new line
  procedure OutText(const w: UnicodeString; const Indent: string);
  const
    LineLength = 64;
  var
    res, newline: string;
    i, j, k, len: Integer;
    linebreak: Boolean;
  begin
    len := Length(w);
    if len = 0 then
    begin
      OutStr('''''');
      Exit;
    end;
    newline := LineEnding + Indent + '  ';
    res := '';
    if len > LineLength then
      res := newline;
    i := 1;
    k := 1;
    repeat
      linebreak := False;
      if (Ord(w[i]) >= 32) and (w[i] <> '''') and (Ord(w[i]) <= 127) then
      begin
        j := i;
        repeat
          Inc(i);
        until (i > len) or (Ord(w[i]) < 32) or (w[i] = '''') or
          (i - k >= LineLength) or (Ord(w[i]) > 127);
        if i - k >= LineLength then
          linebreak := True;
        res := res + '''';
        while j < i do
        begin
          res := res + Char(Ord(w[j]));
          Inc(j);
        end;
        res := res + '''';
      end
      else
      begin
        res := res + '#' + IntToStr(Ord(w[i]));
        Inc(i);
        if i - k >= LineLength then
          linebreak := True;
      end;
      if linebreak and (i <= len) then
      begin
        res := res + ' +' + newline;
        k := i;
      end;
    until i > len;
    OutStr(res);
  end;

  // An AnsiString value holds text in the code page of the program (UTF-8
  // in the LCL applications)
  procedure OutAnsiText(const s: RawByteString; ACodePage: TSystemCodePage;
    const Indent: string);
  var
    raw: RawByteString;
  begin
    raw := s;
    SetCodePage(raw, ACodePage, False);
    OutText(UnicodeString(raw), Indent);
  end;

  function FloatText(const AValue: Extended): string;
  begin
    Result := FloatToStrF(AValue, ffGeneral, 18, 0, InvariantFormat);
  end;

  procedure ReadPropList(const Indent: string); forward;

  procedure ProcessValue(ValueType: TValueType; const Indent: string);
  var
    first: Boolean;
    s: string;
    ext: Extended;
    cur: Currency;
    data: TMemoryStream;
    buf: PByte;
    i, j: Integer;
  begin
    case ValueType of
      vaList:
        begin
          OutStr('(');
          first := True;
          while reader.NextValue <> vaNull do
          begin
            if first then
            begin
              OutLn('');
              first := False;
            end;
            OutStr(Indent + '  ');
            ProcessValue(reader.ReadValue, Indent + '  ');
          end;
          reader.ReadValue;
          OutLn(Indent + ')');
        end;
      vaInt8: OutLn(IntToStr(reader.ReadInt8));
      vaInt16: OutLn(IntToStr(reader.ReadInt16));
      vaInt32: OutLn(IntToStr(reader.ReadInt32));
      vaInt64: OutLn(IntToStr(reader.ReadInt64));
      vaQWord: OutLn(UIntToStr(QWord(reader.ReadInt64)));
      vaExtended:
        begin
          // As the FPC conversion, so that the files do not change
          ext := reader.ReadFloat;
          Str(ext, s);
          OutLn(s);
        end;
      vaSingle: OutLn(FloatText(reader.ReadSingle) + 's');
      vaDate: OutLn(FloatText(reader.ReadDate) + 'd');
      vaCurrency:
        begin
          // The value in 1/10000 units, read back divided by 10000 (Delphi)
          cur := reader.ReadCurrency;
          OutLn(IntToStr(PInt64(@cur)^) + 'c');
        end;
      vaString, vaLString:
        begin
          OutAnsiText(reader.ReadString(ValueType), DefaultSystemCodePage, Indent);
          OutLn('');
        end;
      vaUTF8String:
        begin
          OutAnsiText(reader.ReadString(ValueType), CP_UTF8, Indent);
          OutLn('');
        end;
      vaWString:
        begin
          OutText(reader.ReadWideString, Indent);
          OutLn('');
        end;
      vaUString:
        begin
          OutText(reader.ReadUnicodeString, Indent);
          OutLn('');
        end;
      vaIdent: OutLn(reader.ReadStr);
      vaFalse: OutLn('False');
      vaTrue: OutLn('True');
      vaNil: OutLn('nil');
      vaNull: OutLn('Null');
      vaBinary:
        begin
          data := TMemoryStream.Create;
          try
            reader.ReadBinary(data);
            OutLn('{');
            buf := data.Memory;
            i := 0;
            while i < data.Size do
            begin
              s := Indent + '  ';
              j := 0;
              while (j < 32) and (i < data.Size) do
              begin
                s := s + IntToHex(buf[i], 2);
                Inc(i);
                Inc(j);
              end;
              OutLn(s);
            end;
            OutLn(Indent + '}');
          finally
            data.Free;
          end;
        end;
      vaSet:
        begin
          OutStr('[');
          first := True;
          while True do
          begin
            s := reader.ReadStr;
            if Length(s) = 0 then
              Break;
            if not first then
              OutStr(', ');
            first := False;
            OutStr(s);
          end;
          OutLn(']');
        end;
      vaCollection:
        begin
          OutStr('<');
          while reader.NextValue <> vaNull do
          begin
            OutLn(Indent);
            OutStr(Indent + '  item');
            // The order of the item, when written
            case reader.NextValue of
              vaInt8: begin reader.ReadValue; OutStr('[' + IntToStr(reader.ReadInt8) + ']'); end;
              vaInt16: begin reader.ReadValue; OutStr('[' + IntToStr(reader.ReadInt16) + ']'); end;
              vaInt32: begin reader.ReadValue; OutStr('[' + IntToStr(reader.ReadInt32) + ']'); end;
            end;
            // vaList of the item properties
            reader.ReadValue;
            OutLn('');
            ReadPropList(Indent + '    ');
            OutStr(Indent + '  end');
          end;
          reader.ReadValue;
          OutLn('>');
        end;
    else
      raise EReadError.CreateFmt('Invalid property type from streamed property: %d',
        [Ord(ValueType)]);
    end;
  end;

  // The properties until the end of the list, and the end of the list
  procedure ReadPropList(const Indent: string);
  begin
    while reader.NextValue <> vaNull do
    begin
      OutStr(Indent + reader.BeginProperty + ' = ');
      ProcessValue(reader.ReadValue, Indent);
    end;
    reader.ReadValue;
  end;

  procedure ReadObject(const Indent: string);
  var
    flags: TFilerFlags;
    childpos: Integer;
    aclassname, aname: string;
  begin
    flags := [];
    childpos := 0;
    aclassname := '';
    aname := '';
    reader.BeginComponent(flags, childpos, aclassname, aname);
    OutStr(Indent);
    if ffInherited in flags then
      OutStr('inherited')
    else if ffInline in flags then
      OutStr('inline')
    else
      OutStr('object');
    OutStr(' ');
    if aname <> '' then
      OutStr(aname + ': ');
    OutStr(aclassname);
    if ffChildPos in flags then
      OutStr('[' + IntToStr(childpos) + ']');
    OutLn('');
    ReadPropList(Indent + '  ');
    while reader.NextValue <> vaNull do
      ReadObject(Indent + '  ');
    reader.ReadValue;
    OutLn(Indent + 'end');
  end;

begin
  reader := TRpBinaryObjectReader.Create(Input, 4096);
  try
    reader.BeginRootComponent;
    ReadObject('');
  finally
    reader.Free;
  end;
end;

procedure RpObjectTextToBinary(Input, Output: TStream);
var
  parser: TParser;
  writer: TRpBinaryObjectWriter;

  procedure WriteByte(AValue: Byte);
  begin
    writer.Write(AValue, 1);
  end;

  procedure ProcessProperty; forward;

  // A string and the fragments joined with '+'; a fragment with non ASCII
  // characters makes it a WideString
  procedure ProcessString;
  var
    s: string;
    ws: UnicodeString;
    wide: Boolean;
  begin
    wide := parser.Token = toWString;
    if wide then
      ws := parser.TokenWideString
    else
      s := parser.TokenString;
    while parser.NextToken = '+' do
    begin
      parser.NextToken;
      if not (parser.Token in [toString, toWString]) then
        parser.CheckToken(toString);
      if (parser.Token = toWString) and not wide then
      begin
        ws := UnicodeString(s);
        wide := True;
      end;
      if wide then
        ws := ws + parser.TokenWideString
      else
        s := s + parser.TokenString;
    end;
    // Without codes above 127 the bytes go as they are, as before (ASCII, or
    // the raw bytes of the files of old versions)
    if wide then
      writer.WriteWideString(ws)
    else
      writer.WriteRawString(s);
  end;

  procedure ProcessValue;
  var
    flt: Extended;
    cur: Currency;
    stream: TMemoryStream;
  begin
    case parser.Token of
      toInteger:
        begin
          writer.WriteInteger(parser.TokenInt);
          parser.NextToken;
        end;
      toFloat:
        begin
          flt := parser.TokenFloat;
          case parser.FloatType of
            's', 'S': writer.WriteSingle(flt);
            'c', 'C':
              begin
                // The Int64 of the currency (value * 10000), exact
                PInt64(@cur)^ := Round(flt);
                writer.WriteCurrency(cur);
              end;
            'd', 'D': writer.WriteDate(flt);
          else
            writer.WriteFloat(flt);
          end;
          parser.NextToken;
        end;
      toString, toWString:
        ProcessString;
      toSymbol:
        begin
          // True, False, nil and Null are their value types
          writer.WriteIdent(parser.TokenComponentIdent);
          parser.NextToken;
        end;
      '[':
        begin
          parser.NextToken;
          WriteByte(Ord(vaSet));
          if parser.Token <> ']' then
            while True do
            begin
              parser.CheckToken(toSymbol);
              writer.WriteStr(parser.TokenString);
              parser.NextToken;
              if parser.Token = ']' then
                Break;
              parser.CheckToken(',');
              parser.NextToken;
            end;
          writer.WriteStr('');
          parser.NextToken;
        end;
      '(':
        begin
          parser.NextToken;
          writer.BeginList;
          while parser.Token <> ')' do
            ProcessValue;
          writer.EndList;
          parser.NextToken;
        end;
      '<':
        begin
          parser.NextToken;
          writer.BeginCollection;
          while parser.Token <> '>' do
          begin
            parser.CheckTokenSymbol('item');
            parser.NextToken;
            if parser.Token = '[' then
            begin
              parser.NextToken;
              parser.CheckToken(toInteger);
              writer.WriteInteger(parser.TokenInt);
              parser.NextToken;
              parser.CheckToken(']');
              parser.NextToken;
            end;
            writer.BeginList;
            while not parser.TokenSymbolIs('end') do
              ProcessProperty;
            parser.NextToken;
            writer.EndList;
          end;
          writer.EndList;
          parser.NextToken;
        end;
      '{':
        begin
          stream := TMemoryStream.Create;
          try
            parser.HexToBinary(stream);
            writer.WriteBinary(stream.Memory^, stream.Size);
          finally
            stream.Free;
          end;
          parser.NextToken;
        end;
    else
      parser.Error('Invalid property value');
    end;
  end;

  procedure ProcessProperty;
  var
    aname: string;
  begin
    parser.CheckToken(toSymbol);
    aname := parser.TokenString;
    while parser.NextToken = '.' do
    begin
      parser.NextToken;
      parser.CheckToken(toSymbol);
      aname := aname + '.' + parser.TokenString;
    end;
    writer.BeginProperty(aname);
    parser.CheckToken('=');
    parser.NextToken;
    ProcessValue;
  end;

  procedure ProcessObject;
  var
    flags: Byte;
    childpos: Integer;
    aname, aclassname: string;
  begin
    flags := 0;
    childpos := 0;
    if parser.TokenSymbolIs('object') then
      flags := 0
    else if parser.TokenSymbolIs('inherited') then
      flags := 1
    else
    begin
      parser.CheckTokenSymbol('inline');
      flags := 4;
    end;
    parser.NextToken;
    parser.CheckToken(toSymbol);
    aname := '';
    aclassname := parser.TokenString;
    if parser.NextToken = ':' then
    begin
      parser.NextToken;
      parser.CheckToken(toSymbol);
      aname := aclassname;
      aclassname := parser.TokenString;
      parser.NextToken;
    end;
    if parser.Token = '[' then
    begin
      parser.NextToken;
      parser.CheckToken(toInteger);
      childpos := parser.TokenInt;
      flags := flags or 2;
      parser.NextToken;
      parser.CheckToken(']');
      parser.NextToken;
    end;
    // Filer flags prefix, as TBinaryObjectWriter.BeginComponent
    if flags <> 0 then
    begin
      WriteByte($F0 or flags);
      if (flags and 2) <> 0 then
        writer.WriteInteger(childpos);
    end;
    writer.WriteStr(aclassname);
    writer.WriteStr(aname);
    while not (parser.TokenSymbolIs('end') or parser.TokenSymbolIs('object') or
      parser.TokenSymbolIs('inherited') or parser.TokenSymbolIs('inline')) do
      ProcessProperty;
    writer.EndList;
    while not parser.TokenSymbolIs('end') do
      ProcessObject;
    parser.NextToken;
    writer.EndList;
  end;

begin
  parser := TParser.Create(Input);
  try
    writer := TRpBinaryObjectWriter.Create(Output, 4096);
    try
      writer.WriteSignature;
      ProcessObject;
    finally
      writer.Free;
    end;
  finally
    parser.Free;
  end;
end;

initialization
  InvariantFormat := DefaultFormatSettings;
  InvariantFormat.DecimalSeparator := '.';
  InvariantFormat.ThousandSeparator := #0;
end.
