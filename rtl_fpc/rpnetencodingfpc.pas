{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpnetencodingfpc                                }
{       Delphi System.NetEncoding compatible classes    }
{       for Free Pascal                                 }
{                                                       }
{       This file is under the MPL license              }
{       A copy of the license is in the license.txt     }
{       file included with this distribution            }
{                                                       }
{*******************************************************}

// FPC-only replacement for Delphi's System.NetEncoding in the shared Hub
// units. FPC 3.2.2's own System.NetEncoding (package vcl-compat) turns every
// byte >= $80 into '?' in Base64 (see rpbase64fpc) and does not follow
// Delphi's URL rules, so these classes reproduce Delphi's output:
// - Base64: 76-character lines separated by sLineBreak (Base64String: no
//   line breaks); decoding ignores line breaks and anything not Base64.
// - URL: A-Z a-z 0-9 * @ . _ - $ ! ' ( ) are kept, space becomes '+',
//   everything else is %XX (upper case) of its UTF-8 bytes; decoding turns
//   '+' into a space and raises EConvertError on a bad escape.
// - HTML: & < > " become entities.
// Strings are UTF-8 (Lazarus convention).

unit rpnetencodingfpc;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes;

type
  TNetEncoding = class
  private
    class var FBase64: TNetEncoding;
    class var FBase64String: TNetEncoding;
    class var FURL: TNetEncoding;
    class var FHTML: TNetEncoding;
    class function GetBase64: TNetEncoding; static;
    class function GetBase64String: TNetEncoding; static;
    class function GetURL: TNetEncoding; static;
    class function GetHTML: TNetEncoding; static;
  protected
    function DoEncodeBytes(const AInput: TBytes): TBytes; virtual;
    function DoDecodeBytes(const AInput: TBytes): TBytes; virtual;
    function DoEncode(const AInput: string): string; virtual;
    function DoDecode(const AInput: string): string; virtual;
  public
    class destructor Destroy;
    function Encode(const AInput: string): string; overload;
    function Decode(const AInput: string): string; overload;
    function Encode(const AInput: TBytes): TBytes; overload;
    function Decode(const AInput: TBytes): TBytes; overload;
    function EncodeBytesToString(const AInput: TBytes): string;
    function DecodeStringToBytes(const AInput: string): TBytes;
    class property Base64: TNetEncoding read GetBase64;
    class property Base64String: TNetEncoding read GetBase64String;
    class property URL: TNetEncoding read GetURL;
    class property HTML: TNetEncoding read GetHTML;
  end;

  TBase64Encoding = class(TNetEncoding)
  private
    FCharsPerLine: Integer;
    FLineSeparator: string;
  protected
    function DoEncodeBytes(const AInput: TBytes): TBytes; override;
    function DoDecodeBytes(const AInput: TBytes): TBytes; override;
    function DoEncode(const AInput: string): string; override;
    function DoDecode(const AInput: string): string; override;
  public
    constructor Create; overload;
    constructor Create(ACharsPerLine: Integer); overload;
    constructor Create(ACharsPerLine: Integer; const ALineSeparator: string); overload;
  end;

  TBase64StringEncoding = class(TBase64Encoding)
  public
    constructor Create; overload;
  end;

  TURLEncoding = class(TNetEncoding)
  protected
    function DoEncode(const AInput: string): string; override;
    function DoDecode(const AInput: string): string; override;
    function DoEncodeBytes(const AInput: TBytes): TBytes; override;
    function DoDecodeBytes(const AInput: TBytes): TBytes; override;
  end;

  THTMLEncoding = class(TNetEncoding)
  protected
    function DoEncode(const AInput: string): string; override;
    function DoDecode(const AInput: string): string; override;
    function DoEncodeBytes(const AInput: TBytes): TBytes; override;
    function DoDecodeBytes(const AInput: TBytes): TBytes; override;
  end;

implementation

uses
  rpbase64fpc;

function StringToBytes(const S: string): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

function BytesToString(const B: TBytes): string;
begin
  SetLength(Result, Length(B));
  if Length(B) > 0 then
    Move(B[0], Result[1], Length(B));
end;

{ TNetEncoding }

class function TNetEncoding.GetBase64: TNetEncoding;
begin
  if FBase64 = nil then
    FBase64 := TBase64Encoding.Create;
  Result := FBase64;
end;

class function TNetEncoding.GetBase64String: TNetEncoding;
begin
  if FBase64String = nil then
    FBase64String := TBase64StringEncoding.Create;
  Result := FBase64String;
end;

class function TNetEncoding.GetURL: TNetEncoding;
begin
  if FURL = nil then
    FURL := TURLEncoding.Create;
  Result := FURL;
end;

class function TNetEncoding.GetHTML: TNetEncoding;
begin
  if FHTML = nil then
    FHTML := THTMLEncoding.Create;
  Result := FHTML;
end;

class destructor TNetEncoding.Destroy;
begin
  FreeAndNil(FBase64);
  FreeAndNil(FBase64String);
  FreeAndNil(FURL);
  FreeAndNil(FHTML);
end;

function TNetEncoding.DoEncodeBytes(const AInput: TBytes): TBytes;
begin
  Result := StringToBytes(DoEncode(BytesToString(AInput)));
end;

function TNetEncoding.DoDecodeBytes(const AInput: TBytes): TBytes;
begin
  Result := StringToBytes(DoDecode(BytesToString(AInput)));
end;

function TNetEncoding.DoEncode(const AInput: string): string;
begin
  Result := BytesToString(DoEncodeBytes(StringToBytes(AInput)));
end;

function TNetEncoding.DoDecode(const AInput: string): string;
begin
  Result := BytesToString(DoDecodeBytes(StringToBytes(AInput)));
end;

function TNetEncoding.Encode(const AInput: string): string;
begin
  Result := DoEncode(AInput);
end;

function TNetEncoding.Decode(const AInput: string): string;
begin
  Result := DoDecode(AInput);
end;

function TNetEncoding.Encode(const AInput: TBytes): TBytes;
begin
  Result := DoEncodeBytes(AInput);
end;

function TNetEncoding.Decode(const AInput: TBytes): TBytes;
begin
  Result := DoDecodeBytes(AInput);
end;

function TNetEncoding.EncodeBytesToString(const AInput: TBytes): string;
begin
  Result := BytesToString(DoEncodeBytes(AInput));
end;

function TNetEncoding.DecodeStringToBytes(const AInput: string): TBytes;
begin
  Result := DoDecodeBytes(StringToBytes(AInput));
end;

{ TBase64Encoding }

constructor TBase64Encoding.Create;
begin
  Create(76, sLineBreak);
end;

constructor TBase64Encoding.Create(ACharsPerLine: Integer);
begin
  Create(ACharsPerLine, sLineBreak);
end;

constructor TBase64Encoding.Create(ACharsPerLine: Integer; const ALineSeparator: string);
begin
  inherited Create;
  FCharsPerLine := ACharsPerLine;
  FLineSeparator := ALineSeparator;
end;

function TBase64Encoding.DoEncodeBytes(const AInput: TBytes): TBytes;
begin
  Result := StringToBytes(DoEncode(BytesToString(AInput)));
end;

function TBase64Encoding.DoDecodeBytes(const AInput: TBytes): TBytes;
begin
  Result := RpBase64DecodeBytes(BytesToString(AInput));
end;

function TBase64Encoding.DoEncode(const AInput: string): string;
var
  LPlain: string;
  I: Integer;
begin
  LPlain := RpBase64EncodeBytes(StringToBytes(AInput));
  if (FCharsPerLine <= 0) or (Length(LPlain) <= FCharsPerLine) then
    Exit(LPlain);
  Result := '';
  I := 1;
  while I <= Length(LPlain) do
  begin
    if I > 1 then
      Result := Result + FLineSeparator;
    Result := Result + Copy(LPlain, I, FCharsPerLine);
    Inc(I, FCharsPerLine);
  end;
end;

function TBase64Encoding.DoDecode(const AInput: string): string;
begin
  Result := BytesToString(RpBase64DecodeBytes(AInput));
end;

{ TBase64StringEncoding }

constructor TBase64StringEncoding.Create;
begin
  inherited Create(0, '');
end;

{ TURLEncoding }

function TURLEncoding.DoEncode(const AInput: string): string;
const
  HexDigits: array[0..15] of Char = '0123456789ABCDEF';
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(AInput) do
  begin
    C := AInput[I];
    case C of
      'A'..'Z', 'a'..'z', '0'..'9', '*', '@', '.', '_', '-', '$', '!', '''', '(', ')':
        Result := Result + C;
      ' ':
        Result := Result + '+';
    else
      Result := Result + '%' + HexDigits[Ord(C) shr 4] + HexDigits[Ord(C) and $F];
    end;
  end;
end;

function TURLEncoding.DoDecode(const AInput: string): string;
var
  I, LLen, H1, H2: Integer;

  function Hex(C: Char): Integer;
  begin
    case C of
      '0'..'9': Result := Ord(C) - Ord('0');
      'a'..'f': Result := Ord(C) - Ord('a') + 10;
      'A'..'F': Result := Ord(C) - Ord('A') + 10;
    else
      Result := -1;
    end;
  end;

begin
  Result := '';
  LLen := Length(AInput);
  I := 1;
  while I <= LLen do
  begin
    case AInput[I] of
      '+':
        Result := Result + ' ';
      '%':
        begin
          if (I < LLen) and (AInput[I + 1] = '%') then
          begin
            Result := Result + '%';
            Inc(I);
          end
          else
          begin
            if I + 2 > LLen then
              raise EConvertError.CreateFmt('Error decoding URL style (%%XX) encoded string at position %d', [I - 1]);
            H1 := Hex(AInput[I + 1]);
            H2 := Hex(AInput[I + 2]);
            if (H1 < 0) or (H2 < 0) then
              raise EConvertError.CreateFmt('Invalid URL encoded character (%s) at position %d',
                [Copy(AInput, I, 3), I - 1]);
            Result := Result + Chr(H1 * 16 + H2);
            Inc(I, 2);
          end;
        end;
    else
      Result := Result + AInput[I];
    end;
    Inc(I);
  end;
end;

function TURLEncoding.DoEncodeBytes(const AInput: TBytes): TBytes;
begin
  Result := StringToBytes(DoEncode(BytesToString(AInput)));
end;

function TURLEncoding.DoDecodeBytes(const AInput: TBytes): TBytes;
begin
  Result := StringToBytes(DoDecode(BytesToString(AInput)));
end;

{ THTMLEncoding }

function THTMLEncoding.DoEncode(const AInput: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AInput) do
    case AInput[I] of
      '&': Result := Result + '&amp;';
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '"': Result := Result + '&quot;';
    else
      Result := Result + AInput[I];
    end;
end;

function THTMLEncoding.DoDecode(const AInput: string): string;
begin
  Result := StringReplace(AInput, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&#39;', '''', [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
end;

function THTMLEncoding.DoEncodeBytes(const AInput: TBytes): TBytes;
begin
  Result := StringToBytes(DoEncode(BytesToString(AInput)));
end;

function THTMLEncoding.DoDecodeBytes(const AInput: TBytes): TBytes;
begin
  Result := StringToBytes(DoDecode(BytesToString(AInput)));
end;

end.
