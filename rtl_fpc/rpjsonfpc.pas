{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpjsonfpc                                       }
{       Delphi System.JSON compatible classes for       }
{       Free Pascal                                     }
{                                                       }
{       This file is under the MPL license              }
{       A copy of the license is in the license.txt     }
{       file included with this distribution            }
{                                                       }
{*******************************************************}

// FPC-only replacement for the part of Delphi's System.JSON used by the
// shared Report Manager units (AI contracts, Hub authentication and the
// rpdbHttp Agent driver). The shared units only switch
//   {$IFDEF FPC} rpjsonfpc {$ELSE} System.JSON {$ENDIF}
// so the class names, ownership rules and output format are Delphi's:
// - a container (TJSONObject, TJSONArray, TJSONPair) frees the children it
//   owns; AddPair/Add/AddElement take ownership, Remove/RemovePair give it
//   back to the caller;
// - ParseJSONValue returns nil on invalid input (or raises
//   EJSONParseException when asked to), with Delphi's parser rules and quirks;
// - ToJSON escapes control characters and everything above #127 as \uXXXX
//   (UTF-16 code units, upper-case hex), ToString keeps non-ASCII text as is;
// - numbers keep the text they were parsed from and are formatted like
//   Delphi's FloatToJson / CurrencyToJson when created from Pascal values.
// Strings follow the Lazarus convention: string values hold UTF-8.

unit rpjsonfpc;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Generics.Collections;

type
  EJSONException = class(Exception);

  EJSONParseException = class(EJSONException)
  private
    FOffset: Integer;
  public
    constructor Create(AOffset: Integer; const AMessage: string);
    property Offset: Integer read FOffset;
  end;

  TJSONValue = class;
  TJSONString = class;
  TJSONPair = class;
  TJSONObject = class;
  TJSONArray = class;

  TJSONAncestor = class abstract
  public type
    TJSONOutputOption = (EncodeBelow32, EncodeAbove127);
    TJSONOutputOptions = set of TJSONOutputOption;
  private
    FOwned: Boolean;
  protected
    function IsNull: Boolean; virtual;
    procedure AddDescendant(const Descendant: TJSONAncestor); virtual;
    procedure Format(Builder: TStringBuilder; const ParentIdent, Ident: string); overload; virtual;
  public
    constructor Create; overload; virtual;
    function Value: string; virtual;
    procedure ToChars(Builder: TStringBuilder; Options: TJSONOutputOptions); virtual; abstract;
    function ToJSON(Options: TJSONOutputOptions): string; overload;
    function ToJSON: string; overload;
    function ToString: string; override;
    function Format(Indentation: Integer = 4): string; overload;
    function Clone: TJSONAncestor; virtual; abstract;
    property Null: Boolean read IsNull;
    property Owned: Boolean read FOwned write FOwned;
  end;

  TJSONValue = class abstract(TJSONAncestor)
  public type
    TJSONParseOption = (IsUTF8, UseBool, RaiseExc, IsANSI);
    TJSONParseOptions = set of TJSONParseOption;
  private
    function GetValueP(const APath: string): TJSONValue;
  public
    class function ParseJSONValue(const Data: string; UseBool: Boolean = False;
      RaiseExc: Boolean = False): TJSONValue; overload; static;
    class function ParseJSONValue(const Data: TBytes; const Offset: Integer;
      IsUTF8: Boolean = True): TJSONValue; overload; static;
    class function ParseJSONValue(const Data: TBytes; const Offset: Integer;
      const ALength: Integer; IsUTF8: Boolean = True): TJSONValue; overload; static;
    class function ParseJSONValue(const Data: TBytes; const Offset: Integer;
      Options: TJSONParseOptions): TJSONValue; overload; static;
    class function ParseJSONValue(const Data: TBytes; const Offset: Integer;
      const ALength: Integer; Options: TJSONParseOptions): TJSONValue; overload; static;
    // Path lookup as in Delphi: 'name', 'a.b', 'list[2].name', '["a b"]'.
    // Returns nil when the path does not exist.
    function FindValue(const APath: string): TJSONValue;
    property P[const APath: string]: TJSONValue read GetValueP;
  end;

  TJSONString = class(TJSONValue)
  private
    FValue: string;
    FIsNull: Boolean;
  protected
    function IsNull: Boolean; override;
  public
    constructor Create; overload; override;
    constructor Create(const AValue: string); overload;
    procedure AddChar(const Ch: Char);
    function Equals(const AValue: string): Boolean; reintroduce;
    procedure ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions); override;
    function Value: string; override;
    function Clone: TJSONAncestor; override;
  end;

  TJSONNumber = class(TJSONValue)
  private
    FValue: string;
    FIsNull: Boolean;
  protected
    function IsNull: Boolean; override;
    function GetAsDouble: Double;
    function GetAsCurrency: Currency;
    function GetAsInt: Integer;
    function GetAsUInt: Cardinal;
    function GetAsInt64: Int64;
    function GetAsUInt64: UInt64;
  public
    // Keeps the text as is (no validation); used by the parser
    constructor InternalCreate(const AValue: string; Dummy: Integer);
    constructor Create; overload; override;
    constructor Create(const AValue: string); overload;
    constructor Create(const AValue: Double); overload;
{$IFDEF FPC_HAS_TYPE_EXTENDED}
    constructor Create(const AValue: Extended); overload;
{$ENDIF}
    constructor Create(const AValue: Currency); overload;
    constructor Create(const AValue: Integer); overload;
    constructor Create(const AValue: Cardinal); overload;
    constructor Create(const AValue: Int64); overload;
    constructor Create(const AValue: UInt64); overload;
    function Equals(const AValue: string): Boolean; reintroduce;
    procedure ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions); override;
    function Value: string; override;
    function Clone: TJSONAncestor; override;
    property AsDouble: Double read GetAsDouble;
    property AsCurrency: Currency read GetAsCurrency;
    property AsInt: Integer read GetAsInt;
    property AsUInt: Cardinal read GetAsUInt;
    property AsInt64: Int64 read GetAsInt64;
    property AsUInt64: UInt64 read GetAsUInt64;
  end;

  TJSONPair = class(TJSONAncestor)
  private
    FJsonString: TJSONString;
    FJsonValue: TJSONValue;
  protected
    procedure AddDescendant(const Descendant: TJSONAncestor); override;
    procedure SetJsonString(const Descendant: TJSONString);
    procedure SetJsonValue(const Val: TJSONValue);
    function HasName(const AName: string): Boolean;
  public
    constructor Create(const Str: TJSONString; const AValue: TJSONValue); overload;
    constructor Create(const Str: string; const AValue: TJSONValue); overload;
    constructor Create(const Str: string; const AValue: string); overload;
    constructor Create(const Str: string; const AValue: Int64); overload;
    constructor Create(const Str: string; const AValue: UInt64); overload;
    constructor Create(const Str: string; const AValue: Integer); overload;
    constructor Create(const Str: string; const AValue: Cardinal); overload;
    constructor Create(const Str: string; const AValue: Double); overload;
{$IFDEF FPC_HAS_TYPE_EXTENDED}
    constructor Create(const Str: string; const AValue: Extended); overload;
{$ENDIF}
    constructor Create(const Str: string; const AValue: Currency); overload;
    constructor Create(const Str: string; const AValue: Boolean); overload;
    constructor Create; overload; override;
    destructor Destroy; override;
    procedure ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions); override;
    function Clone: TJSONAncestor; override;
    property JsonString: TJSONString read FJsonString write SetJsonString;
    property JsonValue: TJSONValue read FJsonValue write SetJsonValue;
  end;

  TJSONObject = class(TJSONValue)
  public type
    TEnumerator = class
    private
      FIndex: Integer;
      FObject: TJSONObject;
    public
      constructor Create(const AObject: TJSONObject);
      function GetCurrent: TJSONPair;
      function MoveNext: Boolean;
      property Current: TJSONPair read GetCurrent;
    end;
  private
    FMembers: TList<TJSONPair>;
    function GetIsEmpty: Boolean;
  protected
    procedure AddDescendant(const Descendant: TJSONAncestor); override;
    function GetCount: Integer;
    function GetPair(const Index: Integer): TJSONPair;
    function GetPairByName(const PairName: string): TJSONPair;
    procedure Format(Builder: TStringBuilder; const ParentIdent, Ident: string); overload; override;
  public
    constructor Create; overload; override;
    constructor Create(const Pair: TJSONPair); overload;
    destructor Destroy; override;
    function GetEnumerator: TEnumerator;
    function GetValue(const Name: string): TJSONValue; overload;
    function AddPair(const Pair: TJSONPair): TJSONObject; overload;
    function AddPair(const Str: TJSONString; const Val: TJSONValue): TJSONObject; overload;
    function AddPair(const Str: string; const Val: TJSONValue): TJSONObject; overload;
    function AddPair(const Str: string; const Val: string): TJSONObject; overload;
    function AddPair(const Str: string; const Val: Int64): TJSONObject; overload;
    function AddPair(const Str: string; const Val: UInt64): TJSONObject; overload;
    function AddPair(const Str: string; const Val: Integer): TJSONObject; overload;
    function AddPair(const Str: string; const Val: Cardinal): TJSONObject; overload;
    function AddPair(const Str: string; const Val: Double): TJSONObject; overload;
{$IFDEF FPC_HAS_TYPE_EXTENDED}
    function AddPair(const Str: string; const Val: Extended): TJSONObject; overload;
{$ENDIF}
    function AddPair(const Str: string; const Val: Currency): TJSONObject; overload;
    function AddPair(const Str: string; const Val: Boolean): TJSONObject; overload;
    // Detaches the first pair with that name; the caller owns it
    function RemovePair(const PairName: string): TJSONPair;
    procedure ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions); override;
    function Clone: TJSONAncestor; override;
    function Size: Integer;
    function Get(const Index: Integer): TJSONPair; overload;
    function Get(const Name: string): TJSONPair; overload;
    property Count: Integer read GetCount;
    property IsEmpty: Boolean read GetIsEmpty;
    property Pairs[const Index: Integer]: TJSONPair read GetPair;
    property Values[const Name: string]: TJSONValue read GetValue;
  end;

  TJSONNull = class(TJSONValue)
  protected
    function IsNull: Boolean; override;
  public
    procedure ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions); override;
    function Value: string; override;
    function Clone: TJSONAncestor; override;
  end;

  // As in Delphi, TJSONBool.Create(Boolean) is a class function that returns
  // a TJSONTrue or a TJSONFalse; the parser creates plain TJSONBool values
  // with UseBool
  TJSONBool = class(TJSONValue)
  private
    FValue: Boolean;
  public
    constructor InternalCreate(AValue: Boolean);
    class function Create(AValue: Boolean): TJSONBool; overload; static;
    procedure ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions); override;
    function Value: string; override;
    function Clone: TJSONAncestor; override;
    property AsBoolean: Boolean read FValue;
  end;

  TJSONTrue = class(TJSONBool)
  public
    constructor Create; overload; override;
    function Clone: TJSONAncestor; override;
  end;

  TJSONFalse = class(TJSONBool)
  public
    constructor Create; overload; override;
    function Clone: TJSONAncestor; override;
  end;

  TJSONArray = class(TJSONValue)
  public type
    TEnumerator = class
    private
      FIndex: Integer;
      FArray: TJSONArray;
    public
      constructor Create(const AArray: TJSONArray);
      function GetCurrent: TJSONValue;
      function MoveNext: Boolean;
      property Current: TJSONValue read GetCurrent;
    end;
  private
    FElements: TList<TJSONValue>;
    function GetIsEmpty: Boolean;
  protected
    procedure AddDescendant(const Descendant: TJSONAncestor); override;
    function Pop: TJSONValue;
    function GetValue(const Index: Integer): TJSONValue; overload;
    function GetCount: Integer;
    procedure Format(Builder: TStringBuilder; const ParentIdent, Ident: string); overload; override;
  public
    constructor Create; overload; override;
    constructor Create(const FirstElem: TJSONValue); overload;
    constructor Create(const FirstElem: TJSONValue; const SecondElem: TJSONValue); overload;
    constructor Create(const FirstElem: string; const SecondElem: string); overload;
    destructor Destroy; override;
    // Detaches the element; the caller owns it
    function Remove(Index: Integer): TJSONValue;
    procedure AddElement(const Element: TJSONValue);
    function Add(const Element: string): TJSONArray; overload;
    function Add(const Element: Integer): TJSONArray; overload;
    function Add(const Element: Cardinal): TJSONArray; overload;
    function Add(const Element: Int64): TJSONArray; overload;
    function Add(const Element: UInt64): TJSONArray; overload;
    function Add(const Element: Double): TJSONArray; overload;
{$IFDEF FPC_HAS_TYPE_EXTENDED}
    function Add(const Element: Extended): TJSONArray; overload;
{$ENDIF}
    function Add(const Element: Currency): TJSONArray; overload;
    function Add(const Element: Boolean): TJSONArray; overload;
    function Add(const Element: TJSONObject): TJSONArray; overload;
    function Add(const Element: TJSONArray): TJSONArray; overload;
    procedure ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions); override;
    function Clone: TJSONAncestor; override;
    function GetEnumerator: TEnumerator;
    function Size: Integer;
    function Get(const Index: Integer): TJSONValue;
    property Count: Integer read GetCount;
    property IsEmpty: Boolean read GetIsEmpty;
    property Items[const Index: Integer]: TJSONValue read GetValue; default;
  end;

// Number <-> text as Delphi's System.JSON does it
function GetJSONFormat: TFormatSettings;
function FloatToJson(const AValue: Double): string;
function CurrencyToJson(const AValue: Currency): string;

implementation

uses
  Math;

const
  MaximumNestingLevel = 512;
  DecimalToHexMap: array[0..15] of Char = '0123456789ABCDEF';

var
  JSONFormatSettings: TFormatSettings;

function GetJSONFormat: TFormatSettings;
begin
  Result := JSONFormatSettings;
end;

// Delphi: FloatToText(ffGeneral, 15 digits, 17 for values that would round
// to infinity), then ".0" when there is neither a decimal point nor an
// exponent. FPC's FloatToStrF(ffGeneral) uses fixed notation for small
// exponents where Delphi already switches to scientific notation, so the
// general format is rebuilt here from the exponent format.
function FloatToJson(const AValue: Double): string;
var
  LPrecision, LExp, LPos, LDigitsLen: Integer;
  LMantissa, LDigits, LExpText: string;
  LNeg: Boolean;
begin
  if IsNan(AValue) then
    Exit('NAN');
  if IsInfinite(AValue) then
  begin
    if AValue > 0 then
      Exit('INF')
    else
      Exit('-INF');
  end;
  if AValue = 0 then
    Exit('0.0');
  if (AValue < 1.7976931348623152E308) and (AValue > -1.7976931348623152E308) then
    LPrecision := 15
  else
    LPrecision := 17;
  // d.dddddE+xxx (FPC 3.2.2 drops or shortens the exponent with Digits < 3)
  LMantissa := FloatToStrF(AValue, ffExponent, LPrecision, 3, JSONFormatSettings);
  LNeg := (LMantissa <> '') and (LMantissa[1] = '-');
  if LNeg then
    Delete(LMantissa, 1, 1);
  LPos := Pos('E', LMantissa);
  LExpText := Copy(LMantissa, LPos + 1, MaxInt);
  LMantissa := Copy(LMantissa, 1, LPos - 1);
  LExp := StrToInt(LExpText);
  LDigits := StringReplace(LMantissa, '.', '', []);
  // Remove trailing zeros of the significant digits
  LDigitsLen := Length(LDigits);
  while (LDigitsLen > 1) and (LDigits[LDigitsLen] = '0') do
    Dec(LDigitsLen);
  SetLength(LDigits, LDigitsLen);
  if (LExp >= LPrecision) or (LExp < -4) then
  begin
    // Scientific: d[.ddd]E[-]x
    Result := LDigits[1];
    if LDigitsLen > 1 then
      Result := Result + '.' + Copy(LDigits, 2, MaxInt);
    Result := Result + 'E' + IntToStr(LExp);
  end
  else if LExp < 0 then
    Result := '0.' + StringOfChar('0', -LExp - 1) + LDigits
  else if LDigitsLen <= LExp + 1 then
    Result := LDigits + StringOfChar('0', LExp + 1 - LDigitsLen)
  else
    Result := Copy(LDigits, 1, LExp + 1) + '.' + Copy(LDigits, LExp + 2, MaxInt);
  if LNeg then
    Result := '-' + Result;
  if (Pos('.', Result) = 0) and (Pos('E', Result) = 0) then
    Result := Result + '.0';
end;

function CurrencyToJson(const AValue: Currency): string;
begin
  Result := CurrToStr(AValue, JSONFormatSettings);
  if Pos('.', Result) = 0 then
    Result := Result + '.0';
end;

{ UTF-8 helpers }

// Decodes the UTF-8 sequence at S[I]; returns the code point and the number
// of bytes. Invalid bytes are taken as Latin-1 characters (1 byte), which
// keeps texts that are not UTF-8 readable instead of dropping them.
function DecodeUtf8At(const S: string; I: Integer; out ALen: Integer): Cardinal;
var
  B0, B1, B2, B3: Byte;
  LLen: Integer;
begin
  LLen := Length(S);
  B0 := Byte(S[I]);
  ALen := 1;
  Result := B0;
  if B0 < $80 then
    Exit;
  if (B0 and $E0 = $C0) and (I + 1 <= LLen) then
  begin
    B1 := Byte(S[I + 1]);
    if B1 and $C0 = $80 then
    begin
      Result := (Cardinal(B0 and $1F) shl 6) or (B1 and $3F);
      if Result >= $80 then
      begin
        ALen := 2;
        Exit;
      end;
    end;
  end
  else if (B0 and $F0 = $E0) and (I + 2 <= LLen) then
  begin
    B1 := Byte(S[I + 1]);
    B2 := Byte(S[I + 2]);
    if (B1 and $C0 = $80) and (B2 and $C0 = $80) then
    begin
      Result := (Cardinal(B0 and $0F) shl 12) or (Cardinal(B1 and $3F) shl 6) or (B2 and $3F);
      if Result >= $800 then
      begin
        ALen := 3;
        Exit;
      end;
    end;
  end
  else if (B0 and $F8 = $F0) and (I + 3 <= LLen) then
  begin
    B1 := Byte(S[I + 1]);
    B2 := Byte(S[I + 2]);
    B3 := Byte(S[I + 3]);
    if (B1 and $C0 = $80) and (B2 and $C0 = $80) and (B3 and $C0 = $80) then
    begin
      Result := (Cardinal(B0 and $07) shl 18) or (Cardinal(B1 and $3F) shl 12) or
        (Cardinal(B2 and $3F) shl 6) or (B3 and $3F);
      if (Result >= $10000) and (Result <= $10FFFF) then
      begin
        ALen := 4;
        Exit;
      end;
    end;
  end;
  // Invalid sequence: Latin-1 fallback
  ALen := 1;
  Result := B0;
end;

procedure AppendCodePointUtf8(var S: string; var ALen: Integer; ACodePoint: Cardinal);

  procedure Put(B: Byte);
  begin
    if ALen >= Length(S) then
      SetLength(S, Length(S) * 2 + 16);
    Inc(ALen);
    S[ALen] := Char(B);
  end;

begin
  if ACodePoint < $80 then
    Put(ACodePoint)
  else if ACodePoint < $800 then
  begin
    Put($C0 or (ACodePoint shr 6));
    Put($80 or (ACodePoint and $3F));
  end
  else if ACodePoint < $10000 then
  begin
    Put($E0 or (ACodePoint shr 12));
    Put($80 or ((ACodePoint shr 6) and $3F));
    Put($80 or (ACodePoint and $3F));
  end
  else
  begin
    Put($F0 or (ACodePoint shr 18));
    Put($80 or ((ACodePoint shr 12) and $3F));
    Put($80 or ((ACodePoint shr 6) and $3F));
    Put($80 or (ACodePoint and $3F));
  end;
end;

procedure AppendUnicodeEscape(Builder: TStringBuilder; AUnit: Cardinal);
var
  LBuf: string;
begin
  LBuf := '\u0000';
  LBuf[3] := DecimalToHexMap[(AUnit shr 12) and $F];
  LBuf[4] := DecimalToHexMap[(AUnit shr 8) and $F];
  LBuf[5] := DecimalToHexMap[(AUnit shr 4) and $F];
  LBuf[6] := DecimalToHexMap[AUnit and $F];
  Builder.Append(LBuf);
end;

procedure AppendJsonString(Builder: TStringBuilder; const S: string;
  Options: TJSONAncestor.TJSONOutputOptions);
var
  I, LLen, LSeqLen, LStart: Integer;
  C: Char;
  LCodePoint: Cardinal;
begin
  LLen := Length(S);
  I := 1;
  LStart := 1;
  while I <= LLen do
  begin
    C := S[I];
    if (C >= #32) and (C <= #127) and (C <> '"') and (C <> '\') then
    begin
      Inc(I);
      Continue;
    end;
    // Flush the plain run
    if I > LStart then
      Builder.Append(Copy(S, LStart, I - LStart));
    case C of
      '"': Builder.Append('\"');
      '\': Builder.Append('\\');
      #8: Builder.Append('\b');
      #9: Builder.Append('\t');
      #10: Builder.Append('\n');
      #12: Builder.Append('\f');
      #13: Builder.Append('\r');
      #0..#7, #11, #14..#31:
        if TJSONAncestor.TJSONOutputOption.EncodeBelow32 in Options then
          AppendUnicodeEscape(Builder, Ord(C))
        else
          Builder.Append(C);
    else
      begin
        // Non-ASCII: one UTF-8 sequence
        LCodePoint := DecodeUtf8At(S, I, LSeqLen);
        if TJSONAncestor.TJSONOutputOption.EncodeAbove127 in Options then
        begin
          if LCodePoint >= $10000 then
          begin
            Dec(LCodePoint, $10000);
            AppendUnicodeEscape(Builder, $D800 or (LCodePoint shr 10));
            AppendUnicodeEscape(Builder, $DC00 or (LCodePoint and $3FF));
          end
          else
            AppendUnicodeEscape(Builder, LCodePoint);
        end
        else
          Builder.Append(Copy(S, I, LSeqLen));
        Inc(I, LSeqLen);
        LStart := I;
        Continue;
      end;
    end;
    Inc(I);
    LStart := I;
  end;
  if LLen >= LStart then
  begin
    if LStart = 1 then
      Builder.Append(S)
    else
      Builder.Append(Copy(S, LStart, LLen - LStart + 1));
  end;
end;

{ Parser (Delphi's rules: objects and arrays consume the whitespace that
  follows them, scalars do not; the whole input must be consumed) }

type
  TRpJsonParser = class
  private
    FData: PAnsiChar;
    FPos: Integer;
    FLen: Integer;
    FLevel: Integer;
    FUseBool: Boolean;
    FErrorPos: Integer;
    function IsEof: Boolean; inline;
    function Peek: Char; inline;
    procedure SkipWhitespaces;
    function Fail: TJSONValue;
    function ParseValue: TJSONValue;
    function ParseString: TJSONString;
    function ParseNumber: TJSONNumber;
    function ParseObject: TJSONObject;
    function ParseArray: TJSONArray;
    function ParseLiteral(const AText: string): Boolean;
  public
    constructor Create(AData: PAnsiChar; ALen: Integer; AUseBool: Boolean);
    function Parse: TJSONValue;
    property ErrorPos: Integer read FErrorPos;
  end;

constructor TRpJsonParser.Create(AData: PAnsiChar; ALen: Integer; AUseBool: Boolean);
begin
  inherited Create;
  FData := AData;
  FLen := ALen;
  FPos := 0;
  FUseBool := AUseBool;
  FErrorPos := -1;
end;

function TRpJsonParser.IsEof: Boolean;
begin
  Result := FPos >= FLen;
end;

function TRpJsonParser.Peek: Char;
begin
  if FPos < FLen then
    Result := FData[FPos]
  else
    Result := #0;
end;

procedure TRpJsonParser.SkipWhitespaces;
begin
  while (FPos < FLen) and (FData[FPos] in [#32, #9, #10, #13]) do
    Inc(FPos);
end;

function TRpJsonParser.Fail: TJSONValue;
begin
  if FErrorPos < 0 then
    FErrorPos := FPos;
  Result := nil;
end;

function TRpJsonParser.ParseLiteral(const AText: string): Boolean;
var
  I: Integer;
begin
  // Delphi needs the whole literal to be present
  Result := False;
  if FPos + Length(AText) > FLen then
    Exit;
  for I := 1 to Length(AText) do
    if FData[FPos + I - 1] <> AText[I] then
      Exit;
  Inc(FPos, Length(AText));
  Result := True;
end;

function TRpJsonParser.ParseValue: TJSONValue;
begin
  if IsEof then
    Exit(Fail);
  case Peek of
    '"':
      Result := ParseString;
    '-', '0'..'9':
      Result := ParseNumber;
    '{':
      Result := ParseObject;
    '[':
      Result := ParseArray;
    't':
      begin
        if not ParseLiteral('true') then
          Exit(Fail);
        if FUseBool then
          Result := TJSONBool.InternalCreate(True)
        else
          Result := TJSONTrue.Create;
      end;
    'f':
      begin
        if not ParseLiteral('false') then
          Exit(Fail);
        if FUseBool then
          Result := TJSONBool.InternalCreate(False)
        else
          Result := TJSONFalse.Create;
      end;
    'n':
      begin
        if not ParseLiteral('null') then
          Exit(Fail);
        Result := TJSONNull.Create;
      end;
  else
    Result := Fail;
  end;
end;

function HexValue(C: Char): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function TRpJsonParser.ParseString: TJSONString;
var
  LBuf: string;
  LBufLen: Integer;
  C: Char;
  H: Integer;
  LUnit, LLow: Cardinal;
  LSavePos: Integer;

  procedure PutByte(B: Char);
  begin
    if LBufLen >= Length(LBuf) then
      SetLength(LBuf, Length(LBuf) * 2 + 16);
    Inc(LBufLen);
    LBuf[LBufLen] := B;
  end;

  function ReadHex4(out AValue: Cardinal): Boolean;
  var
    K: Integer;
  begin
    Result := False;
    AValue := 0;
    if FPos + 4 > FLen then
      Exit;
    for K := 0 to 3 do
    begin
      H := HexValue(FData[FPos + K]);
      if H < 0 then
      begin
        Inc(FPos, K);
        Exit;
      end;
      AValue := (AValue shl 4) or Cardinal(H);
    end;
    Inc(FPos, 4);
    Result := True;
  end;

begin
  Result := nil;
  if Peek <> '"' then
  begin
    Fail;
    Exit;
  end;
  Inc(FPos);
  if IsEof then
  begin
    Fail;
    Exit;
  end;
  LBuf := '';
  LBufLen := 0;
  while True do
  begin
    C := FData[FPos];
    if C = '"' then
      Break;
    if C = '\' then
    begin
      Inc(FPos);
      if IsEof then
      begin
        Fail;
        Exit;
      end;
      C := FData[FPos];
      case C of
        '"', '\', '/':
          begin
            PutByte(C);
            Inc(FPos);
          end;
        'b':
          begin
            PutByte(#8);
            Inc(FPos);
          end;
        'f':
          begin
            PutByte(#12);
            Inc(FPos);
          end;
        'n':
          begin
            PutByte(#10);
            Inc(FPos);
          end;
        'r':
          begin
            PutByte(#13);
            Inc(FPos);
          end;
        't':
          begin
            PutByte(#9);
            Inc(FPos);
          end;
        'u':
          begin
            Inc(FPos);
            // Delphi needs the 4 digits and at least one more character
            if FPos + 4 >= FLen then
            begin
              Fail;
              Exit;
            end;
            if not ReadHex4(LUnit) then
            begin
              Fail;
              Exit;
            end;
            // Combine a surrogate pair written as two escapes
            if (LUnit >= $D800) and (LUnit <= $DBFF) and (FPos + 6 < FLen) and
              (FData[FPos] = '\') and (FData[FPos + 1] = 'u') then
            begin
              LSavePos := FPos;
              Inc(FPos, 2);
              if ReadHex4(LLow) and (LLow >= $DC00) and (LLow <= $DFFF) then
                LUnit := $10000 + ((LUnit - $D800) shl 10) + (LLow - $DC00)
              else
                FPos := LSavePos;
            end;
            // A lone surrogate cannot be stored as UTF-8: U+FFFD, as Delphi
            // ends up with
            if (LUnit >= $D800) and (LUnit <= $DFFF) then
              LUnit := $FFFD;
            AppendCodePointUtf8(LBuf, LBufLen, LUnit);
          end;
      else
        Fail;
        Exit;
      end;
    end
    else
    begin
      PutByte(C);
      Inc(FPos);
    end;
    if IsEof then
    begin
      Fail;
      Exit;
    end;
  end;
  Inc(FPos);
  SetLength(LBuf, LBufLen);
  Result := TJSONString.Create(LBuf);
end;

function TRpJsonParser.ParseNumber: TJSONNumber;
var
  LStart: Integer;
  LExponent, LOneAdded: Boolean;

  function Done: TJSONNumber;
  var
    S: string;
  begin
    SetString(S, FData + LStart, FPos - LStart);
    Result := TJSONNumber.InternalCreate(S, 0);
  end;

  function IsDigit: Boolean; inline;
  begin
    Result := (FPos < FLen) and (FData[FPos] in ['0'..'9']);
  end;

begin
  Result := nil;
  LStart := FPos;
  if Peek = '-' then
  begin
    Inc(FPos);
    if IsEof or not (FData[FPos] in ['0'..'9', 'e', 'E']) then
    begin
      Fail;
      Exit;
    end;
  end;
  if Peek = '0' then
  begin
    Inc(FPos);
    if IsEof then
      Exit(Done);
    if FData[FPos] in ['0'..'9'] then
    begin
      Fail;
      Exit;
    end;
  end;
  while IsDigit do
  begin
    Inc(FPos);
    if IsEof then
      Exit(Done);
  end;
  LExponent := False;
  if Peek = '.' then
  begin
    Inc(FPos);
    if IsEof then
    begin
      Fail;
      Exit;
    end;
  end
  else if Peek in ['e', 'E'] then
  begin
    Inc(FPos);
    LExponent := True;
    if IsEof then
    begin
      Fail;
      Exit;
    end;
    if Peek in ['-', '+'] then
    begin
      Inc(FPos);
      if IsEof then
      begin
        Fail;
        Exit;
      end;
    end;
  end
  else
    Exit(Done);
  LOneAdded := False;
  while IsDigit do
  begin
    Inc(FPos);
    LOneAdded := True;
    if IsEof then
      Exit(Done);
  end;
  if not LOneAdded then
  begin
    Fail;
    Exit;
  end;
  if (not LExponent) and (Peek in ['e', 'E']) then
  begin
    Inc(FPos);
    if IsEof then
    begin
      Fail;
      Exit;
    end;
    if Peek in ['-', '+'] then
    begin
      Inc(FPos);
      if IsEof then
      begin
        Fail;
        Exit;
      end;
    end;
    LOneAdded := False;
    while IsDigit do
    begin
      Inc(FPos);
      LOneAdded := True;
      if IsEof then
        Exit(Done);
    end;
    if not LOneAdded then
    begin
      Fail;
      Exit;
    end;
  end;
  Result := Done;
end;

function TRpJsonParser.ParseObject: TJSONObject;
var
  LPairExpected: Boolean;
  LName: TJSONString;
  LValue: TJSONValue;
begin
  Result := nil;
  if FLevel >= MaximumNestingLevel then
  begin
    Fail;
    Exit;
  end;
  Inc(FLevel);
  Inc(FPos); // '{'
  SkipWhitespaces;
  if IsEof then
  begin
    Fail;
    Exit;
  end;
  Result := TJSONObject.Create;
  try
    LPairExpected := False;
    while LPairExpected or (Peek <> '}') do
    begin
      LName := ParseString;
      if LName = nil then
        Abort;
      Result.AddDescendant(TJSONPair.Create(LName, nil));
      SkipWhitespaces;
      if IsEof or (Peek <> ':') then
      begin
        Fail;
        Abort;
      end;
      Inc(FPos);
      SkipWhitespaces;
      LValue := ParseValue;
      if LValue = nil then
        Abort;
      Result.Pairs[Result.Count - 1].FJsonValue := LValue;
      SkipWhitespaces;
      if IsEof then
      begin
        Fail;
        Abort;
      end;
      LPairExpected := False;
      if Peek = ',' then
      begin
        Inc(FPos);
        SkipWhitespaces;
        LPairExpected := True;
        if Peek = '}' then
        begin
          Fail;
          Abort;
        end;
      end
      else if Peek <> '}' then
      begin
        Fail;
        Abort;
      end;
    end;
    Inc(FPos); // '}'
    SkipWhitespaces;
    Dec(FLevel);
  except
    on EAbort do
    begin
      FreeAndNil(Result);
    end;
  end;
end;

function TRpJsonParser.ParseArray: TJSONArray;
var
  LValueExpected: Boolean;
  LValue: TJSONValue;
begin
  Result := nil;
  if FLevel >= MaximumNestingLevel then
  begin
    Fail;
    Exit;
  end;
  Inc(FLevel);
  Inc(FPos); // '['
  Result := TJSONArray.Create;
  try
    LValueExpected := False;
    SkipWhitespaces;
    while LValueExpected or (Peek <> ']') do
    begin
      SkipWhitespaces;
      LValue := ParseValue;
      if LValue = nil then
        Abort;
      Result.AddDescendant(LValue);
      SkipWhitespaces;
      if IsEof then
      begin
        Fail;
        Abort;
      end;
      LValueExpected := False;
      if Peek = ',' then
      begin
        Inc(FPos);
        LValueExpected := True;
      end
      else if Peek <> ']' then
      begin
        Fail;
        Abort;
      end;
    end;
    Inc(FPos); // ']'
    SkipWhitespaces;
    Dec(FLevel);
  except
    on EAbort do
      FreeAndNil(Result);
  end;
end;

function TRpJsonParser.Parse: TJSONValue;
begin
  // UTF-8 byte order mark
  if (FLen >= 3) and (FData[0] = #$EF) and (FData[1] = #$BB) and (FData[2] = #$BF) then
    FPos := 3;
  SkipWhitespaces;
  Result := ParseValue;
  if (Result <> nil) and (FPos <> FLen) then
  begin
    if FErrorPos < 0 then
      FErrorPos := FPos;
    FreeAndNil(Result);
  end;
end;

function DoParse(AData: PAnsiChar; ALen: Integer; AUseBool, ARaiseExc: Boolean): TJSONValue;
var
  LParser: TRpJsonParser;
begin
  LParser := TRpJsonParser.Create(AData, ALen, AUseBool);
  try
    Result := LParser.Parse;
    if (Result = nil) and ARaiseExc then
      raise EJSONParseException.Create(LParser.ErrorPos,
        SysUtils.Format('Invalid JSON at offset %d', [LParser.ErrorPos]));
  finally
    LParser.Free;
  end;
end;

{ EJSONParseException }

constructor EJSONParseException.Create(AOffset: Integer; const AMessage: string);
begin
  inherited Create(AMessage);
  FOffset := AOffset;
end;

{ TJSONAncestor }

constructor TJSONAncestor.Create;
begin
  inherited Create;
  FOwned := True;
end;

function TJSONAncestor.IsNull: Boolean;
begin
  Result := False;
end;

procedure TJSONAncestor.AddDescendant(const Descendant: TJSONAncestor);
begin
  raise EJSONException.CreateFmt('Cannot add a %s to a %s',
    [Descendant.ClassName, ClassName]);
end;

procedure TJSONAncestor.Format(Builder: TStringBuilder; const ParentIdent, Ident: string);
begin
  ToChars(Builder, []);
end;

function TJSONAncestor.Value: string;
begin
  Result := '';
end;

function TJSONAncestor.ToJSON(Options: TJSONOutputOptions): string;
var
  LBuilder: TStringBuilder;
begin
  LBuilder := TStringBuilder.Create(256);
  try
    ToChars(LBuilder, Options);
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function TJSONAncestor.ToJSON: string;
begin
  Result := ToJSON([TJSONOutputOption.EncodeBelow32, TJSONOutputOption.EncodeAbove127]);
end;

function TJSONAncestor.ToString: string;
begin
  Result := ToJSON([]);
end;

function TJSONAncestor.Format(Indentation: Integer): string;
var
  LBuilder: TStringBuilder;
begin
  LBuilder := TStringBuilder.Create(256);
  try
    Format(LBuilder, '', StringOfChar(' ', Indentation));
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

{ TJSONValue }

class function TJSONValue.ParseJSONValue(const Data: string; UseBool: Boolean;
  RaiseExc: Boolean): TJSONValue;
begin
  Result := DoParse(PAnsiChar(Data), Length(Data), UseBool, RaiseExc);
end;

class function TJSONValue.ParseJSONValue(const Data: TBytes; const Offset: Integer;
  IsUTF8: Boolean): TJSONValue;
begin
  Result := ParseJSONValue(Data, Offset, Length(Data), IsUTF8);
end;

class function TJSONValue.ParseJSONValue(const Data: TBytes; const Offset: Integer;
  const ALength: Integer; IsUTF8: Boolean): TJSONValue;
var
  LOptions: TJSONParseOptions;
begin
  LOptions := [];
  if IsUTF8 then
    Include(LOptions, TJSONParseOption.IsUTF8);
  Result := ParseJSONValue(Data, Offset, ALength, LOptions);
end;

class function TJSONValue.ParseJSONValue(const Data: TBytes; const Offset: Integer;
  Options: TJSONParseOptions): TJSONValue;
begin
  Result := ParseJSONValue(Data, Offset, Length(Data), Options);
end;

class function TJSONValue.ParseJSONValue(const Data: TBytes; const Offset: Integer;
  const ALength: Integer; Options: TJSONParseOptions): TJSONValue;
begin
  // ALength is the end of the data (as in Delphi), not a count from Offset
  if (Offset < 0) or (Offset >= ALength) or (ALength > Length(Data)) then
  begin
    Result := nil;
    if TJSONParseOption.RaiseExc in Options then
      raise EJSONParseException.Create(Offset, 'Invalid JSON: no data');
    Exit;
  end;
  Result := DoParse(PAnsiChar(@Data[Offset]), ALength - Offset,
    TJSONParseOption.UseBool in Options, TJSONParseOption.RaiseExc in Options);
end;

function TJSONValue.GetValueP(const APath: string): TJSONValue;
begin
  Result := FindValue(APath);
  if Result = nil then
    raise EJSONException.CreateFmt('Value ''%s'' not found', [APath]);
end;

function TJSONValue.FindValue(const APath: string): TJSONValue;
var
  I, LLen, LStart, LIndex: Integer;
  LName: string;
  LQuote: Char;
begin
  Result := Self;
  LLen := Length(APath);
  I := 1;
  while (Result <> nil) and (I <= LLen) do
  begin
    case APath[I] of
      '.':
        Inc(I);
      '[':
        begin
          Inc(I);
          while (I <= LLen) and (APath[I] = ' ') do
            Inc(I);
          if (I <= LLen) and (APath[I] in ['''', '"']) then
          begin
            // ['name'] or ["name"]
            LQuote := APath[I];
            Inc(I);
            LStart := I;
            while (I <= LLen) and (APath[I] <> LQuote) do
              Inc(I);
            LName := Copy(APath, LStart, I - LStart);
            Inc(I);
            while (I <= LLen) and (APath[I] <> ']') do
              Inc(I);
            Inc(I);
            if Result is TJSONObject then
              Result := TJSONObject(Result).GetValue(LName)
            else
              Result := nil;
          end
          else
          begin
            LStart := I;
            while (I <= LLen) and (APath[I] <> ']') do
              Inc(I);
            LIndex := StrToIntDef(Trim(Copy(APath, LStart, I - LStart)), -1);
            Inc(I);
            if (Result is TJSONArray) and (LIndex >= 0) and
              (LIndex < TJSONArray(Result).Count) then
              Result := TJSONArray(Result).Items[LIndex]
            else
              Result := nil;
          end;
        end;
    else
      begin
        LStart := I;
        while (I <= LLen) and not (APath[I] in ['.', '[']) do
          Inc(I);
        LName := Copy(APath, LStart, I - LStart);
        if Result is TJSONObject then
          Result := TJSONObject(Result).GetValue(LName)
        else
          Result := nil;
      end;
    end;
  end;
end;

{ TJSONString }

constructor TJSONString.Create;
begin
  inherited Create;
  FIsNull := True;
end;

constructor TJSONString.Create(const AValue: string);
begin
  inherited Create;
  FValue := AValue;
  FIsNull := False;
end;

function TJSONString.IsNull: Boolean;
begin
  Result := FIsNull;
end;

procedure TJSONString.AddChar(const Ch: Char);
begin
  FValue := FValue + Ch;
  FIsNull := False;
end;

function TJSONString.Equals(const AValue: string): Boolean;
begin
  Result := FValue = AValue;
end;

procedure TJSONString.ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions);
begin
  if FIsNull then
    Builder.Append('null')
  else
  begin
    Builder.Append('"');
    AppendJsonString(Builder, FValue, Options);
    Builder.Append('"');
  end;
end;

function TJSONString.Value: string;
begin
  Result := FValue;
end;

function TJSONString.Clone: TJSONAncestor;
begin
  if FIsNull then
    Result := TJSONString.Create
  else
    Result := TJSONString.Create(FValue);
end;

{ TJSONNumber }

constructor TJSONNumber.Create;
begin
  inherited Create;
  FIsNull := True;
end;

constructor TJSONNumber.InternalCreate(const AValue: string; Dummy: Integer);
begin
  inherited Create;
  FValue := AValue;
  FIsNull := False;
end;

constructor TJSONNumber.Create(const AValue: string);
begin
  // Delphi validates the text as a number
  if Trim(AValue) <> '' then
    StrToFloat(AValue, JSONFormatSettings);
  InternalCreate(AValue, 0);
end;

constructor TJSONNumber.Create(const AValue: Double);
begin
  InternalCreate(FloatToJson(AValue), 0);
end;

{$IFDEF FPC_HAS_TYPE_EXTENDED}
constructor TJSONNumber.Create(const AValue: Extended);
begin
  InternalCreate(FloatToJson(AValue), 0);
end;
{$ENDIF}

constructor TJSONNumber.Create(const AValue: Currency);
begin
  InternalCreate(CurrencyToJson(AValue), 0);
end;

constructor TJSONNumber.Create(const AValue: Integer);
begin
  InternalCreate(IntToStr(AValue), 0);
end;

constructor TJSONNumber.Create(const AValue: Cardinal);
begin
  InternalCreate(IntToStr(AValue), 0);
end;

constructor TJSONNumber.Create(const AValue: Int64);
begin
  InternalCreate(IntToStr(AValue), 0);
end;

constructor TJSONNumber.Create(const AValue: UInt64);
begin
  InternalCreate(IntToStr(AValue), 0);
end;

function TJSONNumber.IsNull: Boolean;
begin
  Result := FIsNull;
end;

function TJSONNumber.GetAsDouble: Double;
begin
  Result := StrToFloat(FValue, JSONFormatSettings);
end;

function TJSONNumber.GetAsCurrency: Currency;
begin
  Result := StrToCurr(FValue, JSONFormatSettings);
end;

function TJSONNumber.GetAsInt: Integer;
begin
  Result := StrToInt(FValue);
end;

function TJSONNumber.GetAsUInt: Cardinal;
var
  LValue: QWord;
begin
  LValue := StrToQWord(FValue);
  if LValue > High(Cardinal) then
    raise EConvertError.CreateFmt('"%s" is not a valid integer value', [FValue]);
  Result := Cardinal(LValue);
end;

function TJSONNumber.GetAsInt64: Int64;
begin
  Result := StrToInt64(FValue);
end;

function TJSONNumber.GetAsUInt64: UInt64;
begin
  Result := StrToQWord(FValue);
end;

function TJSONNumber.Equals(const AValue: string): Boolean;
begin
  Result := FValue = AValue;
end;

procedure TJSONNumber.ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions);
begin
  Builder.Append(FValue);
end;

function TJSONNumber.Value: string;
begin
  Result := FValue;
end;

function TJSONNumber.Clone: TJSONAncestor;
begin
  if FIsNull then
    Result := TJSONNumber.Create
  else
    Result := TJSONNumber.InternalCreate(FValue, 0);
end;

{ TJSONPair }

constructor TJSONPair.Create(const Str: TJSONString; const AValue: TJSONValue);
begin
  inherited Create;
  FJsonString := Str;
  FJsonValue := AValue;
end;

constructor TJSONPair.Create(const Str: string; const AValue: TJSONValue);
begin
  Create(TJSONString.Create(Str), AValue);
end;

constructor TJSONPair.Create(const Str: string; const AValue: string);
begin
  Create(TJSONString.Create(Str), TJSONString.Create(AValue));
end;

constructor TJSONPair.Create(const Str: string; const AValue: Int64);
begin
  Create(TJSONString.Create(Str), TJSONNumber.Create(AValue));
end;

constructor TJSONPair.Create(const Str: string; const AValue: UInt64);
begin
  Create(TJSONString.Create(Str), TJSONNumber.Create(AValue));
end;

constructor TJSONPair.Create(const Str: string; const AValue: Integer);
begin
  Create(TJSONString.Create(Str), TJSONNumber.Create(AValue));
end;

constructor TJSONPair.Create(const Str: string; const AValue: Cardinal);
begin
  Create(TJSONString.Create(Str), TJSONNumber.Create(AValue));
end;

constructor TJSONPair.Create(const Str: string; const AValue: Double);
begin
  Create(TJSONString.Create(Str), TJSONNumber.Create(AValue));
end;

{$IFDEF FPC_HAS_TYPE_EXTENDED}
constructor TJSONPair.Create(const Str: string; const AValue: Extended);
begin
  Create(TJSONString.Create(Str), TJSONNumber.Create(AValue));
end;
{$ENDIF}

constructor TJSONPair.Create(const Str: string; const AValue: Currency);
begin
  Create(TJSONString.Create(Str), TJSONNumber.Create(AValue));
end;

constructor TJSONPair.Create(const Str: string; const AValue: Boolean);
begin
  Create(TJSONString.Create(Str), TJSONBool.Create(AValue));
end;

constructor TJSONPair.Create;
begin
  Create(TJSONString(nil), TJSONValue(nil));
end;

destructor TJSONPair.Destroy;
begin
  if (FJsonString <> nil) and FJsonString.Owned then
    FreeAndNil(FJsonString);
  if (FJsonValue <> nil) and FJsonValue.Owned then
    FreeAndNil(FJsonValue);
  inherited Destroy;
end;

procedure TJSONPair.AddDescendant(const Descendant: TJSONAncestor);
begin
  if FJsonString = nil then
    FJsonString := TJSONString(Descendant)
  else if FJsonValue = nil then
    FJsonValue := TJSONValue(Descendant)
  else
    inherited AddDescendant(Descendant);
end;

procedure TJSONPair.SetJsonString(const Descendant: TJSONString);
begin
  if (Descendant <> nil) and (Descendant <> FJsonString) then
  begin
    if (FJsonString <> nil) and FJsonString.Owned then
      FJsonString.Free;
    FJsonString := Descendant;
  end;
end;

procedure TJSONPair.SetJsonValue(const Val: TJSONValue);
begin
  if (Val <> nil) and (Val <> FJsonValue) then
  begin
    if (FJsonValue <> nil) and FJsonValue.Owned then
      FJsonValue.Free;
    FJsonValue := Val;
  end;
end;

function TJSONPair.HasName(const AName: string): Boolean;
begin
  Result := (FJsonString <> nil) and (FJsonString.FValue = AName);
end;

procedure TJSONPair.ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions);
begin
  if (FJsonString <> nil) and (FJsonValue <> nil) then
  begin
    FJsonString.ToChars(Builder, Options);
    Builder.Append(':');
    FJsonValue.ToChars(Builder, Options);
  end;
end;

function TJSONPair.Clone: TJSONAncestor;
begin
  Result := TJSONPair.Create(TJSONString(FJsonString.Clone), TJSONValue(FJsonValue.Clone));
end;

{ TJSONObject.TEnumerator }

constructor TJSONObject.TEnumerator.Create(const AObject: TJSONObject);
begin
  inherited Create;
  FIndex := -1;
  FObject := AObject;
end;

function TJSONObject.TEnumerator.GetCurrent: TJSONPair;
begin
  Result := FObject.Pairs[FIndex];
end;

function TJSONObject.TEnumerator.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < FObject.Count;
end;

{ TJSONObject }

constructor TJSONObject.Create;
begin
  inherited Create;
  FMembers := TList<TJSONPair>.Create;
end;

constructor TJSONObject.Create(const Pair: TJSONPair);
begin
  Create;
  AddPair(Pair);
end;

destructor TJSONObject.Destroy;
var
  I: Integer;
  LMember: TJSONPair;
begin
  if FMembers <> nil then
  begin
    for I := 0 to FMembers.Count - 1 do
    begin
      LMember := FMembers[I];
      if (LMember <> nil) and LMember.Owned then
        LMember.Free;
    end;
    FreeAndNil(FMembers);
  end;
  inherited Destroy;
end;

procedure TJSONObject.AddDescendant(const Descendant: TJSONAncestor);
begin
  if Descendant is TJSONPair then
    FMembers.Add(TJSONPair(Descendant))
  else
    inherited AddDescendant(Descendant);
end;

function TJSONObject.GetEnumerator: TEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

function TJSONObject.GetCount: Integer;
begin
  Result := FMembers.Count;
end;

function TJSONObject.GetIsEmpty: Boolean;
begin
  Result := FMembers.Count = 0;
end;

function TJSONObject.GetPair(const Index: Integer): TJSONPair;
begin
  Result := FMembers[Index];
end;

function TJSONObject.GetPairByName(const PairName: string): TJSONPair;
var
  I: Integer;
begin
  for I := 0 to FMembers.Count - 1 do
    if FMembers[I].HasName(PairName) then
      Exit(FMembers[I]);
  Result := nil;
end;

function TJSONObject.GetValue(const Name: string): TJSONValue;
var
  LPair: TJSONPair;
begin
  LPair := GetPairByName(Name);
  if LPair <> nil then
    Result := LPair.JsonValue
  else
    Result := nil;
end;

function TJSONObject.AddPair(const Pair: TJSONPair): TJSONObject;
begin
  if Pair <> nil then
    try
      AddDescendant(Pair);
    except
      if Pair.Owned then
        Pair.Free;
      raise;
    end;
  Result := Self;
end;

function TJSONObject.AddPair(const Str: TJSONString; const Val: TJSONValue): TJSONObject;
begin
  if (Str <> nil) and (Val <> nil) then
    AddPair(TJSONPair.Create(Str, Val))
  else
  begin
    if (Str <> nil) and Str.Owned then
      Str.Free;
    if (Val <> nil) and Val.Owned then
      Val.Free;
  end;
  Result := Self;
end;

function TJSONObject.AddPair(const Str: string; const Val: TJSONValue): TJSONObject;
var
  LValue: TJSONValue;
begin
  if Val <> nil then
    LValue := Val
  else
    LValue := TJSONNull.Create;
  Result := AddPair(TJSONPair.Create(Str, LValue));
end;

function TJSONObject.AddPair(const Str: string; const Val: string): TJSONObject;
begin
  Result := AddPair(TJSONPair.Create(Str, Val));
end;

function TJSONObject.AddPair(const Str: string; const Val: Int64): TJSONObject;
begin
  Result := AddPair(TJSONPair.Create(Str, Val));
end;

function TJSONObject.AddPair(const Str: string; const Val: UInt64): TJSONObject;
begin
  Result := AddPair(TJSONPair.Create(Str, Val));
end;

function TJSONObject.AddPair(const Str: string; const Val: Integer): TJSONObject;
begin
  Result := AddPair(TJSONPair.Create(Str, Val));
end;

function TJSONObject.AddPair(const Str: string; const Val: Cardinal): TJSONObject;
begin
  Result := AddPair(TJSONPair.Create(Str, Val));
end;

function TJSONObject.AddPair(const Str: string; const Val: Double): TJSONObject;
begin
  Result := AddPair(TJSONPair.Create(Str, Val));
end;

{$IFDEF FPC_HAS_TYPE_EXTENDED}
function TJSONObject.AddPair(const Str: string; const Val: Extended): TJSONObject;
begin
  Result := AddPair(TJSONPair.Create(Str, Val));
end;
{$ENDIF}

function TJSONObject.AddPair(const Str: string; const Val: Currency): TJSONObject;
begin
  Result := AddPair(TJSONPair.Create(Str, Val));
end;

function TJSONObject.AddPair(const Str: string; const Val: Boolean): TJSONObject;
begin
  Result := AddPair(TJSONPair.Create(Str, Val));
end;

function TJSONObject.RemovePair(const PairName: string): TJSONPair;
var
  I: Integer;
begin
  for I := 0 to FMembers.Count - 1 do
    if FMembers[I].HasName(PairName) then
    begin
      Result := FMembers[I];
      FMembers.Delete(I);
      Exit;
    end;
  Result := nil;
end;

procedure TJSONObject.ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions);
var
  I: Integer;
begin
  Builder.Append('{');
  for I := 0 to FMembers.Count - 1 do
  begin
    if I > 0 then
      Builder.Append(',');
    FMembers[I].ToChars(Builder, Options);
  end;
  Builder.Append('}');
end;

procedure TJSONObject.Format(Builder: TStringBuilder; const ParentIdent, Ident: string);
var
  LIdent: string;
  I: Integer;
begin
  Builder.Append('{').Append(sLineBreak);
  LIdent := ParentIdent + Ident;
  for I := 0 to Count - 1 do
  begin
    Builder.Append(LIdent);
    Pairs[I].JsonString.Format(Builder, '', Ident);
    Builder.Append(': ');
    Pairs[I].JsonValue.Format(Builder, LIdent, Ident);
    if I < Count - 1 then
      Builder.Append(',');
    Builder.Append(sLineBreak);
  end;
  Builder.Append(ParentIdent).Append('}');
end;

function TJSONObject.Clone: TJSONAncestor;
var
  LData: TJSONObject;
  I: Integer;
begin
  LData := TJSONObject.Create;
  for I := 0 to FMembers.Count - 1 do
    LData.AddPair(TJSONPair(FMembers[I].Clone));
  Result := LData;
end;

function TJSONObject.Size: Integer;
begin
  Result := FMembers.Count;
end;

function TJSONObject.Get(const Index: Integer): TJSONPair;
begin
  Result := FMembers[Index];
end;

function TJSONObject.Get(const Name: string): TJSONPair;
begin
  Result := GetPairByName(Name);
end;

{ TJSONNull }

function TJSONNull.IsNull: Boolean;
begin
  Result := True;
end;

procedure TJSONNull.ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions);
begin
  Builder.Append('null');
end;

function TJSONNull.Value: string;
begin
  Result := 'null';
end;

function TJSONNull.Clone: TJSONAncestor;
begin
  Result := TJSONNull.Create;
end;

{ TJSONBool }

constructor TJSONBool.InternalCreate(AValue: Boolean);
begin
  inherited Create;
  FValue := AValue;
end;

class function TJSONBool.Create(AValue: Boolean): TJSONBool;
begin
  if AValue then
    Result := TJSONTrue.Create
  else
    Result := TJSONFalse.Create;
end;

procedure TJSONBool.ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions);
begin
  if FValue then
    Builder.Append('true')
  else
    Builder.Append('false');
end;

function TJSONBool.Value: string;
begin
  if FValue then
    Result := 'true'
  else
    Result := 'false';
end;

function TJSONBool.Clone: TJSONAncestor;
begin
  Result := TJSONBool.InternalCreate(FValue);
end;

{ TJSONTrue }

constructor TJSONTrue.Create;
begin
  inherited Create;
  FValue := True;
end;

function TJSONTrue.Clone: TJSONAncestor;
begin
  Result := TJSONTrue.Create;
end;

{ TJSONFalse }

constructor TJSONFalse.Create;
begin
  inherited Create;
  FValue := False;
end;

function TJSONFalse.Clone: TJSONAncestor;
begin
  Result := TJSONFalse.Create;
end;

{ TJSONArray.TEnumerator }

constructor TJSONArray.TEnumerator.Create(const AArray: TJSONArray);
begin
  inherited Create;
  FIndex := -1;
  FArray := AArray;
end;

function TJSONArray.TEnumerator.GetCurrent: TJSONValue;
begin
  Result := FArray.Items[FIndex];
end;

function TJSONArray.TEnumerator.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < FArray.Count;
end;

{ TJSONArray }

constructor TJSONArray.Create;
begin
  inherited Create;
  FElements := TList<TJSONValue>.Create;
end;

constructor TJSONArray.Create(const FirstElem: TJSONValue);
begin
  Create;
  AddElement(FirstElem);
end;

constructor TJSONArray.Create(const FirstElem: TJSONValue; const SecondElem: TJSONValue);
begin
  Create;
  AddElement(FirstElem);
  AddElement(SecondElem);
end;

constructor TJSONArray.Create(const FirstElem: string; const SecondElem: string);
begin
  Create;
  AddElement(TJSONString.Create(FirstElem));
  AddElement(TJSONString.Create(SecondElem));
end;

destructor TJSONArray.Destroy;
var
  I: Integer;
  LElement: TJSONValue;
begin
  if FElements <> nil then
  begin
    for I := 0 to FElements.Count - 1 do
    begin
      LElement := FElements[I];
      if (LElement <> nil) and LElement.Owned then
        LElement.Free;
    end;
    FreeAndNil(FElements);
  end;
  inherited Destroy;
end;

procedure TJSONArray.AddDescendant(const Descendant: TJSONAncestor);
begin
  if (Descendant = nil) or (Descendant is TJSONValue) then
    FElements.Add(TJSONValue(Descendant))
  else
    inherited AddDescendant(Descendant);
end;

function TJSONArray.Pop: TJSONValue;
begin
  Result := FElements[0];
  FElements.Delete(0);
end;

function TJSONArray.GetValue(const Index: Integer): TJSONValue;
begin
  Result := FElements[Index];
end;

function TJSONArray.GetCount: Integer;
begin
  Result := FElements.Count;
end;

function TJSONArray.GetIsEmpty: Boolean;
begin
  Result := FElements.Count = 0;
end;

function TJSONArray.Remove(Index: Integer): TJSONValue;
begin
  if (Index >= 0) and (Index < FElements.Count) then
  begin
    Result := FElements[Index];
    FElements.Delete(Index);
  end
  else
    Result := nil;
end;

procedure TJSONArray.AddElement(const Element: TJSONValue);
begin
  AddDescendant(Element);
end;

function TJSONArray.Add(const Element: string): TJSONArray;
begin
  AddElement(TJSONString.Create(Element));
  Result := Self;
end;

function TJSONArray.Add(const Element: Integer): TJSONArray;
begin
  AddElement(TJSONNumber.Create(Element));
  Result := Self;
end;

function TJSONArray.Add(const Element: Cardinal): TJSONArray;
begin
  AddElement(TJSONNumber.Create(Element));
  Result := Self;
end;

function TJSONArray.Add(const Element: Int64): TJSONArray;
begin
  AddElement(TJSONNumber.Create(Element));
  Result := Self;
end;

function TJSONArray.Add(const Element: UInt64): TJSONArray;
begin
  AddElement(TJSONNumber.Create(Element));
  Result := Self;
end;

function TJSONArray.Add(const Element: Double): TJSONArray;
begin
  AddElement(TJSONNumber.Create(Element));
  Result := Self;
end;

{$IFDEF FPC_HAS_TYPE_EXTENDED}
function TJSONArray.Add(const Element: Extended): TJSONArray;
begin
  AddElement(TJSONNumber.Create(Element));
  Result := Self;
end;
{$ENDIF}

function TJSONArray.Add(const Element: Currency): TJSONArray;
begin
  AddElement(TJSONNumber.Create(Element));
  Result := Self;
end;

function TJSONArray.Add(const Element: Boolean): TJSONArray;
begin
  AddElement(TJSONBool.Create(Element));
  Result := Self;
end;

function TJSONArray.Add(const Element: TJSONObject): TJSONArray;
begin
  if Element <> nil then
    AddElement(Element)
  else
    AddElement(TJSONNull.Create);
  Result := Self;
end;

function TJSONArray.Add(const Element: TJSONArray): TJSONArray;
begin
  if Element <> nil then
    AddElement(Element)
  else
    AddElement(TJSONNull.Create);
  Result := Self;
end;

procedure TJSONArray.ToChars(Builder: TStringBuilder; Options: TJSONAncestor.TJSONOutputOptions);
var
  I: Integer;
begin
  Builder.Append('[');
  for I := 0 to FElements.Count - 1 do
  begin
    if I > 0 then
      Builder.Append(',');
    FElements[I].ToChars(Builder, Options);
  end;
  Builder.Append(']');
end;

procedure TJSONArray.Format(Builder: TStringBuilder; const ParentIdent, Ident: string);
var
  LIdent: string;
  I: Integer;
begin
  Builder.Append('[').Append(sLineBreak);
  LIdent := ParentIdent + Ident;
  for I := 0 to Count - 1 do
  begin
    Builder.Append(LIdent);
    Items[I].Format(Builder, LIdent, Ident);
    if I < Count - 1 then
      Builder.Append(',');
    Builder.Append(sLineBreak);
  end;
  Builder.Append(ParentIdent).Append(']');
end;

function TJSONArray.Clone: TJSONAncestor;
var
  LData: TJSONArray;
  I: Integer;
begin
  LData := TJSONArray.Create;
  for I := 0 to Count - 1 do
    LData.AddDescendant(Items[I].Clone);
  Result := LData;
end;

function TJSONArray.GetEnumerator: TEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

function TJSONArray.Size: Integer;
begin
  Result := FElements.Count;
end;

function TJSONArray.Get(const Index: Integer): TJSONValue;
begin
  Result := FElements[Index];
end;

initialization
  JSONFormatSettings := DefaultFormatSettings;
  JSONFormatSettings.DecimalSeparator := '.';
  JSONFormatSettings.ThousandSeparator := ',';
  JSONFormatSettings.CurrencyString := '';
end.
