{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmarkdownlcl                                   }
{       Markdown to HTML for the native chat viewer     }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmarkdownlcl;

{ Converts the Markdown of the AI answers to the HTML subset of the
  TurboPower IPro viewer (TIpHtmlPanel), which renders the chat when there is
  no WebView2 (Linux, or Windows without the WebView2 runtime). It covers
  what markdown-it renders in WebMarkdown/index.html with the options used
  there (breaks: true, linkify: true) for the answers of the assistants:
  ATX and setext headings, paragraphs with line breaks, fenced code, block
  quotes, nested bullet and numbered lists, pipe tables, rules, emphasis,
  strong, strike, code spans, links, autolinks and bare URLs, backslash
  escapes and the <think> blocks of the reasoning models. Raw HTML is shown
  as text (the viewer runs no scripts, but the answer is never trusted as
  markup). Colors follow the dark theme of index.html; attributes (bgcolor,
  font color) are used where IPro ignores CSS. }

{$mode delphi}

interface

uses
  SysUtils, Classes;

const
  // WebMarkdown/index.html palette
  MdClrBody = '#1e1e2e';
  MdClrText = '#cdd6f4';
  MdClrSubtle = '#a6adc8';
  MdClrMuted = '#6c7086';
  MdClrSurface = '#313244';
  MdClrDeep = '#181825';
  MdClrBorder = '#45475a';
  MdClrHeading = '#cba6f7';
  MdClrCode = '#f9e2af';
  MdClrLink = '#89b4fa';
  MdClrUser = '#89b4fa';
  MdClrAssistant = '#a6e3a1';
  MdClrSystem = '#fab387';

// Markdown (UTF-8) to an HTML fragment
function RpMarkdownToHtml(const AMarkdown: string): string;
// Escapes & < > " for HTML text and attributes
function RpHtmlEscape(const AText: string): string;
// The <style> block used by the fragments
function RpMarkdownStyleSheet: string;

implementation

function RpHtmlEscape(const AText: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(AText) do
  begin
    C := AText[I];
    case C of
      '&': Result := Result + '&amp;';
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '"': Result := Result + '&quot;';
      #13: ;
    else
      Result := Result + C;
    end;
  end;
end;

function RpMarkdownStyleSheet: string;
begin
  Result :=
    '<style type="text/css">' +
    'body { background-color: ' + MdClrBody + '; color: ' + MdClrText + '; }' +
    'h1 { color: ' + MdClrHeading + '; font-size: 14pt; }' +
    'h2 { color: ' + MdClrHeading + '; font-size: 12pt; }' +
    'h3 { color: ' + MdClrHeading + '; font-size: 11pt; }' +
    'h4 { color: ' + MdClrHeading + '; }' +
    'h5 { color: ' + MdClrHeading + '; }' +
    'h6 { color: ' + MdClrHeading + '; }' +
    'code { color: ' + MdClrCode + '; }' +
    'pre { color: ' + MdClrText + '; }' +
    'a { color: ' + MdClrLink + '; }' +
    'th { color: ' + MdClrHeading + '; }' +
    'blockquote { color: ' + MdClrSubtle + '; }' +
    '</style>';
end;

type
  TMdRenderer = class
  private
    FLines: TStringList;
    function RenderBlocks(AStart, AEnd: Integer): string;
    function RenderList(var AIndex: Integer; AEnd: Integer): string;
    function RenderTable(var AIndex: Integer; AEnd: Integer): string;
  public
    constructor Create(const AText: string);
    destructor Destroy; override;
    function Render: string;
  end;

function IsAsciiPunct(C: Char): Boolean;
begin
  Result := C in ['!', '"', '#', '$', '%', '&', '''', '(', ')', '*', '+', ',',
    '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\', ']', '^', '_',
    '`', '{', '|', '}', '~'];
end;

function IsWordChar(C: Char): Boolean;
begin
  // UTF-8 lead and continuation bytes count as letters
  Result := (C in ['0'..'9', 'A'..'Z', 'a'..'z']) or (Ord(C) >= $80);
end;

function LeadingSpaces(const S: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) do
  begin
    if S[I] = ' ' then
      Inc(Result)
    else if S[I] = #9 then
      Inc(Result, 4)
    else
      Break;
  end;
end;

function IsBlank(const S: string): Boolean;
begin
  Result := Trim(S) = '';
end;

function IsFence(const S: string; out AChar: Char; out ALen: Integer): Boolean;
var
  T: string;
  I: Integer;
begin
  Result := False;
  ALen := 0;
  AChar := #0;
  if LeadingSpaces(S) > 3 then
    Exit;
  T := TrimLeft(S);
  if Length(T) < 3 then
    Exit;
  if not (T[1] in ['`', '~']) then
    Exit;
  AChar := T[1];
  I := 1;
  while (I <= Length(T)) and (T[I] = AChar) do
    Inc(I);
  ALen := I - 1;
  Result := ALen >= 3;
  // A backtick fence has no backticks in its info string
  if Result and (AChar = '`') and (Pos('`', Copy(T, I, MaxInt)) > 0) then
    Result := False;
end;

function IsClosingFence(const S: string; AChar: Char; ALen: Integer): Boolean;
var
  T: string;
  I: Integer;
begin
  Result := False;
  if LeadingSpaces(S) > 3 then
    Exit;
  T := Trim(S);
  if Length(T) < ALen then
    Exit;
  for I := 1 to Length(T) do
    if T[I] <> AChar then
      Exit;
  Result := True;
end;

function HeadingLevel(const S: string; out AText: string): Integer;
var
  T: string;
  I: Integer;
begin
  Result := 0;
  AText := '';
  if LeadingSpaces(S) > 3 then
    Exit;
  T := TrimLeft(S);
  I := 1;
  while (I <= Length(T)) and (T[I] = '#') do
    Inc(I);
  if (I = 1) or (I > 7) then
    Exit;
  if (I <= Length(T)) and not (T[I] in [' ', #9]) then
    Exit;
  Result := I - 1;
  AText := Trim(Copy(T, I, MaxInt));
  // Closing sequence of #
  I := Length(AText);
  while (I > 0) and (AText[I] = '#') do
    Dec(I);
  if (I = 0) or (AText[I] in [' ', #9]) then
    AText := Trim(Copy(AText, 1, I));
end;

function IsRule(const S: string): Boolean;
var
  T: string;
  I, N: Integer;
  C: Char;
begin
  Result := False;
  if LeadingSpaces(S) > 3 then
    Exit;
  T := Trim(S);
  if T = '' then
    Exit;
  C := T[1];
  if not (C in ['-', '*', '_']) then
    Exit;
  N := 0;
  for I := 1 to Length(T) do
  begin
    if T[I] = C then
      Inc(N)
    else if not (T[I] in [' ', #9]) then
      Exit;
  end;
  Result := N >= 3;
end;

function SetextLevel(const S: string): Integer;
var
  T: string;
  I: Integer;
begin
  Result := 0;
  if LeadingSpaces(S) > 3 then
    Exit;
  T := Trim(S);
  if T = '' then
    Exit;
  for I := 1 to Length(T) do
    if T[I] <> T[1] then
      Exit;
  if T[1] = '=' then
    Result := 1
  else if T[1] = '-' then
    Result := 2;
end;

function ListItemInfo(const S: string; out AIndent: Integer; out AOrdered: Boolean;
  out AStart: Integer; out AContent: string): Boolean;
var
  T: string;
  I: Integer;
begin
  Result := False;
  AOrdered := False;
  AStart := 1;
  AContent := '';
  AIndent := LeadingSpaces(S);
  T := TrimLeft(S);
  if T = '' then
    Exit;
  if (T[1] in ['-', '*', '+']) then
  begin
    if (Length(T) = 1) or (T[2] in [' ', #9]) then
    begin
      AContent := Trim(Copy(T, 2, MaxInt));
      Result := True;
    end;
    Exit;
  end;
  I := 1;
  while (I <= Length(T)) and (T[I] in ['0'..'9']) and (I <= 9) do
    Inc(I);
  if (I = 1) or (I > Length(T)) then
    Exit;
  if not (T[I] in ['.', ')']) then
    Exit;
  if (I < Length(T)) and not (T[I + 1] in [' ', #9]) then
    Exit;
  AOrdered := True;
  AStart := StrToIntDef(Copy(T, 1, I - 1), 1);
  AContent := Trim(Copy(T, I + 1, MaxInt));
  Result := True;
end;

function QuoteContent(const S: string; out AContent: string): Boolean;
var
  T: string;
begin
  Result := False;
  AContent := '';
  if LeadingSpaces(S) > 3 then
    Exit;
  T := TrimLeft(S);
  if (T = '') or (T[1] <> '>') then
    Exit;
  AContent := Copy(T, 2, MaxInt);
  if (AContent <> '') and (AContent[1] = ' ') then
    Delete(AContent, 1, 1);
  Result := True;
end;

function SplitRow(const S: string): TStringList;
var
  T, LCell: string;
  I: Integer;
  LInCode: Boolean;
begin
  Result := TStringList.Create;
  T := Trim(S);
  if (T <> '') and (T[1] = '|') then
    Delete(T, 1, 1);
  if (T <> '') and (T[Length(T)] = '|') and
    ((Length(T) = 1) or (T[Length(T) - 1] <> '\')) then
    Delete(T, Length(T), 1);
  LCell := '';
  LInCode := False;
  I := 1;
  while I <= Length(T) do
  begin
    if (T[I] = '\') and (I < Length(T)) and (T[I + 1] = '|') then
    begin
      LCell := LCell + '|';
      Inc(I, 2);
      Continue;
    end;
    if T[I] = '`' then
      LInCode := not LInCode;
    if (T[I] = '|') and not LInCode then
    begin
      Result.Add(Trim(LCell));
      LCell := '';
    end
    else
      LCell := LCell + T[I];
    Inc(I);
  end;
  Result.Add(Trim(LCell));
end;

function IsTableSeparator(const S: string; AAligns: TStrings): Boolean;
var
  LCells: TStringList;
  I, J: Integer;
  C: string;
begin
  Result := False;
  if Pos('-', S) = 0 then
    Exit;
  LCells := SplitRow(S);
  try
    if LCells.Count = 0 then
      Exit;
    for I := 0 to LCells.Count - 1 do
    begin
      C := LCells[I];
      if C = '' then
        Exit;
      for J := 1 to Length(C) do
        if not (C[J] in ['-', ':', ' ']) then
          Exit;
      if Pos('-', C) = 0 then
        Exit;
      if AAligns <> nil then
      begin
        if (C[1] = ':') and (C[Length(C)] = ':') then
          AAligns.Add('center')
        else if C[Length(C)] = ':' then
          AAligns.Add('right')
        else
          AAligns.Add('');
      end;
    end;
    Result := True;
  finally
    LCells.Free;
  end;
end;

// Position of the closing delimiter ADelim at or after AFrom, skipping code
// spans; the text before it must not end with a space. 0 when not found.
function FindClosing(const S, ADelim: string; AFrom: Integer; AIntraword: Boolean): Integer;
var
  I, N, K: Integer;
begin
  Result := 0;
  N := Length(ADelim);
  I := AFrom;
  while I <= Length(S) - N + 1 do
  begin
    if S[I] = '\' then
    begin
      Inc(I, 2);
      Continue;
    end;
    if S[I] = '`' then
    begin
      K := I + 1;
      while (K <= Length(S)) and (S[K] <> '`') do
        Inc(K);
      if K <= Length(S) then
      begin
        I := K + 1;
        Continue;
      end;
    end;
    if (Copy(S, I, N) = ADelim) and (I > AFrom) and not (S[I - 1] in [' ', #9]) then
    begin
      // "**" inside "***" etc.: take the last delimiter of a run
      if (I + N <= Length(S)) and (S[I + N] = ADelim[1]) and (N = 1) then
      begin
        Inc(I);
        Continue;
      end;
      if AIntraword or (I + N > Length(S)) or not IsWordChar(S[I + N]) then
        Exit(I);
    end;
    Inc(I);
  end;
end;

function CleanUrl(const AUrl: string): string;
begin
  Result := Trim(AUrl);
  if (Result <> '') and (Result[1] = '<') and (Result[Length(Result)] = '>') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function IsSafeUrl(const AUrl: string): Boolean;
var
  L: string;
begin
  L := LowerCase(Trim(AUrl));
  Result := (Pos('http://', L) = 1) or (Pos('https://', L) = 1) or
    (Pos('mailto:', L) = 1) or ((Pos(':', L) = 0) and (L <> ''));
end;

function RenderInline(const S: string): string;
var
  I, J, K, N, LDepth: Integer;
  C: Char;
  LText, LUrl, LTail: string;
  LIsImage: Boolean;

  procedure Emit(const AValue: string);
  begin
    Result := Result + AValue;
  end;

begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    C := S[I];
    case C of
      '\':
        begin
          if (I < Length(S)) and IsAsciiPunct(S[I + 1]) then
          begin
            Emit(RpHtmlEscape(S[I + 1]));
            Inc(I, 2);
          end
          else
          begin
            Emit('\');
            Inc(I);
          end;
          Continue;
        end;
      '`':
        begin
          N := 0;
          while (I + N <= Length(S)) and (S[I + N] = '`') do
            Inc(N);
          J := I + N;
          K := 0;
          while J <= Length(S) do
          begin
            if S[J] = '`' then
            begin
              K := 0;
              while (J + K <= Length(S)) and (S[J + K] = '`') do
                Inc(K);
              if K = N then
                Break;
              Inc(J, K);
              K := 0;
            end
            else
              Inc(J);
          end;
          if (J <= Length(S)) and (K = N) then
          begin
            LText := Copy(S, I + N, J - I - N);
            if (Length(LText) >= 2) and (LText[1] = ' ') and (LText[Length(LText)] = ' ') and
              (Trim(LText) <> '') then
              LText := Copy(LText, 2, Length(LText) - 2);
            Emit('<code>' + RpHtmlEscape(LText) + '</code>');
            I := J + N;
          end
          else
          begin
            Emit(StringOfChar('`', N));
            Inc(I, N);
          end;
          Continue;
        end;
      '*', '_':
        begin
          N := 0;
          while (I + N <= Length(S)) and (S[I + N] = C) do
            Inc(N);
          // Opening: followed by a non space; "_" not inside a word
          if (I + N <= Length(S)) and not (S[I + N] in [' ', #9]) and
            ((C = '*') or (I = 1) or not IsWordChar(S[I - 1])) then
          begin
            if N >= 3 then
            begin
              J := FindClosing(S, StringOfChar(C, 3), I + 3, C = '*');
              if J > 0 then
              begin
                Emit('<b><i>' + RenderInline(Copy(S, I + 3, J - I - 3)) + '</i></b>');
                I := J + 3;
                Continue;
              end;
            end;
            if N >= 2 then
            begin
              J := FindClosing(S, StringOfChar(C, 2), I + 2, C = '*');
              if J > 0 then
              begin
                Emit('<b>' + RenderInline(Copy(S, I + 2, J - I - 2)) + '</b>');
                I := J + 2;
                Continue;
              end;
            end;
            if N = 1 then
            begin
              J := FindClosing(S, C, I + 1, C = '*');
              if J > 0 then
              begin
                Emit('<i>' + RenderInline(Copy(S, I + 1, J - I - 1)) + '</i>');
                I := J + 1;
                Continue;
              end;
            end;
          end;
          Emit(StringOfChar(C, N));
          Inc(I, N);
          Continue;
        end;
      '~':
        begin
          if (I < Length(S)) and (S[I + 1] = '~') and (I + 2 <= Length(S)) and
            not (S[I + 2] in [' ', #9]) then
          begin
            J := FindClosing(S, '~~', I + 2, True);
            if J > 0 then
            begin
              Emit('<s>' + RenderInline(Copy(S, I + 2, J - I - 2)) + '</s>');
              I := J + 2;
              Continue;
            end;
          end;
          Emit('~');
          Inc(I);
          Continue;
        end;
      '!', '[':
        begin
          LIsImage := (C = '!') and (I < Length(S)) and (S[I + 1] = '[');
          if (C = '[') or LIsImage then
          begin
            if LIsImage then
              J := I + 2
            else
              J := I + 1;
            LDepth := 1;
            K := J;
            while (K <= Length(S)) and (LDepth > 0) do
            begin
              if S[K] = '\' then
                Inc(K)
              else if S[K] = '[' then
                Inc(LDepth)
              else if S[K] = ']' then
                Dec(LDepth);
              if LDepth > 0 then
                Inc(K);
            end;
            if (K < Length(S)) and (S[K + 1] = '(') then
            begin
              // Closing parenthesis of the destination (balanced, as
              // markdown-it: "(a(b)c)")
              N := 0;
              LDepth := 1;
              J := K + 2;
              while J <= Length(S) do
              begin
                if S[J] = '(' then
                  Inc(LDepth)
                else if S[J] = ')' then
                begin
                  Dec(LDepth);
                  if LDepth = 0 then
                  begin
                    N := J - (K + 2) + 1;
                    Break;
                  end;
                end;
                Inc(J);
              end;
              if LIsImage then
                J := I + 2
              else
                J := I + 1;
              if N > 0 then
              begin
                LText := Copy(S, J, K - J);
                LUrl := CleanUrl(Copy(S, K + 2, N - 1));
                // Optional title: url "title"
                if Pos(' ', LUrl) > 0 then
                  LUrl := Copy(LUrl, 1, Pos(' ', LUrl) - 1);
                if IsSafeUrl(LUrl) then
                begin
                  if LIsImage then
                    Emit('<a href="' + RpHtmlEscape(LUrl) + '">[' +
                      RpHtmlEscape(LText) + ']</a>')
                  else
                    Emit('<a href="' + RpHtmlEscape(LUrl) + '">' +
                      RenderInline(LText) + '</a>');
                end
                else
                  Emit(RenderInline(LText));
                I := K + 2 + N;
                Continue;
              end;
            end;
          end;
          Emit(RpHtmlEscape(C));
          Inc(I);
          Continue;
        end;
      '<':
        begin
          J := Pos('>', Copy(S, I + 1, MaxInt));
          if J > 0 then
          begin
            LUrl := Copy(S, I + 1, J - 1);
            if ((Pos('http://', LowerCase(LUrl)) = 1) or (Pos('https://', LowerCase(LUrl)) = 1) or
              (Pos('mailto:', LowerCase(LUrl)) = 1)) and (Pos(' ', LUrl) = 0) then
            begin
              Emit('<a href="' + RpHtmlEscape(LUrl) + '">' + RpHtmlEscape(LUrl) + '</a>');
              I := I + J + 1;
              Continue;
            end;
          end;
          Emit('&lt;');
          Inc(I);
          Continue;
        end;
      'h', 'H':
        begin
          if ((I = 1) or not IsWordChar(S[I - 1])) and
            ((LowerCase(Copy(S, I, 7)) = 'http://') or (LowerCase(Copy(S, I, 8)) = 'https://')) then
          begin
            J := I;
            while (J <= Length(S)) and not (S[J] in [' ', #9, '<', '>', '"']) do
              Inc(J);
            LUrl := Copy(S, I, J - I);
            LTail := '';
            while (LUrl <> '') and (LUrl[Length(LUrl)] in ['.', ',', ';', ':', '!', '?', ')', '''', '*', '_']) do
            begin
              LTail := LUrl[Length(LUrl)] + LTail;
              Delete(LUrl, Length(LUrl), 1);
            end;
            if Length(LUrl) > 8 then
            begin
              Emit('<a href="' + RpHtmlEscape(LUrl) + '">' + RpHtmlEscape(LUrl) + '</a>');
              I := I + Length(LUrl);
              Continue;
            end;
          end;
          Emit(C);
          Inc(I);
          Continue;
        end;
    else
      Emit(RpHtmlEscape(C));
      Inc(I);
    end;
  end;
end;

// Lines of a paragraph: markdown-it "breaks: true" turns each newline into
// a line break
function RenderParagraph(ALines: TStrings): string;
var
  I: Integer;
  L: string;
begin
  Result := '';
  for I := 0 to ALines.Count - 1 do
  begin
    L := Trim(ALines[I]);
    if I > 0 then
      Result := Result + '<br>';
    Result := Result + RenderInline(L);
  end;
  Result := '<p>' + Result + '</p>';
end;

{ TMdRenderer }

constructor TMdRenderer.Create(const AText: string);
begin
  inherited Create;
  FLines := TStringList.Create;
  FLines.Text := StringReplace(AText, #13#10, #10, [rfReplaceAll]);
end;

destructor TMdRenderer.Destroy;
begin
  FLines.Free;
  inherited Destroy;
end;

function TMdRenderer.Render: string;
begin
  Result := RenderBlocks(0, FLines.Count - 1);
end;

function TMdRenderer.RenderTable(var AIndex: Integer; AEnd: Integer): string;
var
  LHeader, LRow, LAligns: TStringList;
  I: Integer;

  function AlignAttr(ACol: Integer): string;
  begin
    if (ACol < LAligns.Count) and (LAligns[ACol] <> '') then
      Result := ' align="' + LAligns[ACol] + '"'
    else
      Result := ' align="left"';
  end;

begin
  LAligns := TStringList.Create;
  LHeader := SplitRow(FLines[AIndex]);
  try
    IsTableSeparator(FLines[AIndex + 1], LAligns);
    Result := '<table width="100%" border="1" cellspacing="0" cellpadding="4" bordercolor="' +
      MdClrBorder + '"><tr>';
    for I := 0 to LHeader.Count - 1 do
      Result := Result + '<th bgcolor="' + MdClrSurface + '"' + AlignAttr(I) + '>' +
        RenderInline(LHeader[I]) + '</th>';
    Result := Result + '</tr>';
    Inc(AIndex, 2);
    while (AIndex <= AEnd) and (not IsBlank(FLines[AIndex])) and
      (Pos('|', FLines[AIndex]) > 0) do
    begin
      LRow := SplitRow(FLines[AIndex]);
      try
        Result := Result + '<tr>';
        for I := 0 to LHeader.Count - 1 do
        begin
          if I < LRow.Count then
            Result := Result + '<td' + AlignAttr(I) + '>' + RenderInline(LRow[I]) + '</td>'
          else
            Result := Result + '<td></td>';
        end;
        Result := Result + '</tr>';
      finally
        LRow.Free;
      end;
      Inc(AIndex);
    end;
    Result := Result + '</table>';
  finally
    LHeader.Free;
    LAligns.Free;
  end;
end;

type
  TMdListLevel = record
    Indent: Integer;
    Ordered: Boolean;
  end;

function TMdRenderer.RenderList(var AIndex: Integer; AEnd: Integer): string;
var
  LLevels: array of TMdListLevel;
  LCount: Integer;
  LIndent, LStart, J: Integer;
  LOrdered: Boolean;
  LContent, L, LDummy: string;
  LFenceChar: Char;
  LFenceLen: Integer;

  procedure OpenList(AIndent: Integer; AOrdered: Boolean; AStartNum: Integer);
  begin
    if LCount >= Length(LLevels) then
      SetLength(LLevels, LCount + 4);
    LLevels[LCount].Indent := AIndent;
    LLevels[LCount].Ordered := AOrdered;
    Inc(LCount);
    if AOrdered then
    begin
      if AStartNum <> 1 then
        Result := Result + '<ol start="' + IntToStr(AStartNum) + '">'
      else
        Result := Result + '<ol>';
    end
    else
      Result := Result + '<ul>';
  end;

  procedure CloseList;
  begin
    Result := Result + '</li>';
    if LLevels[LCount - 1].Ordered then
      Result := Result + '</ol>'
    else
      Result := Result + '</ul>';
    Dec(LCount);
  end;

begin
  Result := '';
  LCount := 0;
  while AIndex <= AEnd do
  begin
    L := FLines[AIndex];
    if IsBlank(L) then
    begin
      J := AIndex + 1;
      while (J <= AEnd) and IsBlank(FLines[J]) do
        Inc(J);
      if (J <= AEnd) and (ListItemInfo(FLines[J], LIndent, LOrdered, LStart, LContent) or
        ((LCount > 0) and (LeadingSpaces(FLines[J]) >= 2))) then
      begin
        AIndex := J;
        Continue;
      end;
      Break;
    end;
    if IsFence(L, LFenceChar, LFenceLen) or (HeadingLevel(L, LDummy) > 0) or IsRule(L) then
      Break;
    if ListItemInfo(L, LIndent, LOrdered, LStart, LContent) then
    begin
      while (LCount > 0) and (LIndent + 2 <= LLevels[LCount - 1].Indent) do
        CloseList;
      if (LCount = 0) or (LIndent >= LLevels[LCount - 1].Indent + 2) then
        OpenList(LIndent, LOrdered, LStart)
      else if LLevels[LCount - 1].Ordered <> LOrdered then
      begin
        CloseList;
        OpenList(LIndent, LOrdered, LStart);
      end
      else
        Result := Result + '</li>';
      Result := Result + '<li>' + RenderInline(LContent);
    end
    else
    begin
      if LCount = 0 then
        Break;
      Result := Result + '<br>' + RenderInline(Trim(L));
    end;
    Inc(AIndex);
  end;
  while LCount > 0 do
    CloseList;
end;

function TMdRenderer.RenderBlocks(AStart, AEnd: Integer): string;
var
  I, J, LLevel, LIndent, LStart: Integer;
  L, LText, LCode, LQuote: string;
  LPara, LQuoteLines: TStringList;
  LFenceChar: Char;
  LFenceLen, LClose: Integer;
  LOrdered: Boolean;
  LSub: TMdRenderer;

  procedure FlushParagraph;
  begin
    if LPara.Count > 0 then
    begin
      Result := Result + RenderParagraph(LPara);
      LPara.Clear;
    end;
  end;

begin
  Result := '';
  LPara := TStringList.Create;
  try
    I := AStart;
    while I <= AEnd do
    begin
      L := FLines[I];
      if IsBlank(L) then
      begin
        FlushParagraph;
        Inc(I);
        Continue;
      end;
      if IsFence(L, LFenceChar, LFenceLen) then
      begin
        FlushParagraph;
        LIndent := LeadingSpaces(L);
        LCode := '';
        J := I + 1;
        LClose := -1;
        while J <= AEnd do
        begin
          if IsClosingFence(FLines[J], LFenceChar, LFenceLen) then
          begin
            LClose := J;
            Break;
          end;
          // Remove the indentation of the opening fence
          LText := FLines[J];
          if (LIndent > 0) and (LeadingSpaces(LText) >= LIndent) then
            Delete(LText, 1, LIndent);
          if LCode <> '' then
            LCode := LCode + #10;
          LCode := LCode + LText;
          Inc(J);
        end;
        Result := Result + '<table width="100%" border="0" cellspacing="0" cellpadding="6"><tr>' +
          '<td bgcolor="' + MdClrDeep + '"><pre>' + RpHtmlEscape(LCode) +
          '</pre></td></tr></table>';
        if LClose >= 0 then
          I := LClose + 1
        else
          I := J;
        Continue;
      end;
      LLevel := HeadingLevel(L, LText);
      if LLevel > 0 then
      begin
        FlushParagraph;
        Result := Result + '<h' + IntToStr(LLevel) + '>' + RenderInline(LText) +
          '</h' + IntToStr(LLevel) + '>';
        Inc(I);
        Continue;
      end;
      if LPara.Count > 0 then
      begin
        LLevel := SetextLevel(L);
        if LLevel > 0 then
        begin
          Result := Result + '<h' + IntToStr(LLevel) + '>' +
            RenderInline(Trim(StringReplace(LPara.Text, LineEnding, ' ', [rfReplaceAll]))) +
            '</h' + IntToStr(LLevel) + '>';
          LPara.Clear;
          Inc(I);
          Continue;
        end;
      end;
      if IsRule(L) then
      begin
        FlushParagraph;
        Result := Result + '<hr>';
        Inc(I);
        Continue;
      end;
      if QuoteContent(L, LQuote) then
      begin
        FlushParagraph;
        LQuoteLines := TStringList.Create;
        try
          while (I <= AEnd) and QuoteContent(FLines[I], LQuote) do
          begin
            LQuoteLines.Add(LQuote);
            Inc(I);
          end;
          LSub := TMdRenderer.Create(LQuoteLines.Text);
          try
            Result := Result + '<blockquote><i>' + LSub.Render + '</i></blockquote>';
          finally
            LSub.Free;
          end;
        finally
          LQuoteLines.Free;
        end;
        Continue;
      end;
      if (Pos('|', L) > 0) and (I < AEnd) and IsTableSeparator(FLines[I + 1], nil) then
      begin
        FlushParagraph;
        Result := Result + RenderTable(I, AEnd);
        Continue;
      end;
      if ListItemInfo(L, LIndent, LOrdered, LStart, LText) and
        ((LPara.Count = 0) or (not LOrdered) or (LStart = 1)) and (LIndent <= 3) then
      begin
        FlushParagraph;
        Result := Result + RenderList(I, AEnd);
        Continue;
      end;
      LPara.Add(L);
      Inc(I);
    end;
    FlushParagraph;
  finally
    LPara.Free;
  end;
end;

function RenderMarkdown(const AText: string): string;
var
  LRenderer: TMdRenderer;
begin
  LRenderer := TMdRenderer.Create(AText);
  try
    Result := LRenderer.Render;
  finally
    LRenderer.Free;
  end;
end;

// <think> blocks of the reasoning models, as in index.html (a collapsible
// block there; IPro has no <details>, so a muted block with its title)
function RenderThinkSegment(const AContent: string; AOpen: Boolean): string;
var
  LBody: string;
begin
  LBody := Trim(AContent);
  if (LBody = '') and not AOpen then
    Exit('');
  if LBody = '' then
    LBody := '<i>...</i>'
  else
    LBody := RenderMarkdown(LBody);
  Result := '<table width="100%" border="0" cellspacing="0" cellpadding="6"><tr>' +
    '<td bgcolor="' + MdClrDeep + '"><font color="' + MdClrCode + '">Thinking...</font>' +
    '<br><font color="' + MdClrSubtle + '">' + LBody + '</font></td></tr></table>';
end;

function RpMarkdownToHtml(const AMarkdown: string): string;
var
  LLower, LText: string;
  P, Q: Integer;
begin
  if AMarkdown = '' then
    Exit('');
  LText := AMarkdown;
  LLower := LowerCase(LText);
  if Pos('<think>', LLower) = 0 then
    Exit(RenderMarkdown(LText));
  Result := '';
  while LText <> '' do
  begin
    LLower := LowerCase(LText);
    P := Pos('<think>', LLower);
    if P = 0 then
    begin
      Result := Result + RenderMarkdown(LText);
      Break;
    end;
    if P > 1 then
      Result := Result + RenderMarkdown(Copy(LText, 1, P - 1));
    Q := Pos('</think>', LLower);
    if (Q = 0) or (Q < P) then
    begin
      // Still thinking (streaming): open block with the rest
      Result := Result + RenderThinkSegment(Copy(LText, P + 7, MaxInt), True);
      Break;
    end;
    Result := Result + RenderThinkSegment(Copy(LText, P + 7, Q - P - 7), False);
    LText := Copy(LText, Q + 8, MaxInt);
  end;
end;

end.
