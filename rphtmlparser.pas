unit rphtmlparser;

interface

uses
  Classes, SysUtils, System.Generics.Collections;

type
  { Supported HTML styles }
  THtmlStyle = (hsBold, hsItalic, hsUnderline, hsStrikeOut);
  THtmlStyles = set of THtmlStyle;

  { A segment of text with a specific set of styles }
  THtmlSegment = class
  private
    FText: string;
    FStyles: THtmlStyles;
    FFontFamily: string;
    FFontSize: Single;
    FHasFontSize: Boolean;
  public
    constructor Create(const AText: string; AStyles: THtmlStyles;
      const AFontFamily: string = ''; AFontSize: Single = 0; AHasFontSize: Boolean = False);
    property Text: string read FText write FText;
    property Styles: THtmlStyles read FStyles write FStyles;
    property FontFamily: string read FFontFamily write FFontFamily;
    property FontSize: Single read FFontSize write FFontSize;
    property HasFontSize: Boolean read FHasFontSize write FHasFontSize;
  end;

  { A list of HTML segments }
  THtmlSegmentList = class(TObjectList<THtmlSegment>)
  end;

{ Parses an HTML string into a list of segments with applied styles.
  Supports <b>, <strong>, <i>, <em>, <u>, <s>, <strike>, <del>, <br>,
  <font face="..." size="...">, <span style="font-family:...; font-size:..."> tags.
  Decodes basic HTML entities. }
function ParseHtml(const AText: string; const DefaultFontFamily: string = ''): THtmlSegmentList;

implementation

uses
  StrUtils;

{ THtmlSegment }

constructor THtmlSegment.Create(const AText: string; AStyles: THtmlStyles;
  const AFontFamily: string; AFontSize: Single; AHasFontSize: Boolean);
begin
  FText := AText;
  FStyles := AStyles;
  FFontFamily := AFontFamily;
  FFontSize := AFontSize;
  FHasFontSize := AHasFontSize;
end;

{ Helper: Decode basic HTML entities }
function DecodeHtml(const S: string): string;
begin
  Result := StringReplace(S, '&nbsp;', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&#39;', '''', [rfReplaceAll]);
end;

{ Extract font-family from style attribute: font-family: 'Name' or font-family: Name }
function ExtractFontFamily(const Attrs: string): string;
var
  p, p2: Integer;
  val: string;
begin
  Result := '';
  p := Pos('font-family', LowerCase(Attrs));
  if p = 0 then Exit;
  p := PosEx(':', Attrs, p);
  if p = 0 then Exit;
  Inc(p);
  while (p <= Length(Attrs)) and (Attrs[p] = ' ') do Inc(p);
  // Skip optional quote
  if (p <= Length(Attrs)) and (Attrs[p] = '''') then
  begin
    Inc(p);
    p2 := PosEx('''', Attrs, p);
    if p2 > 0 then
      Result := Copy(Attrs, p, p2 - p);
  end
  else
  begin
    p2 := p;
    while (p2 <= Length(Attrs)) and (Attrs[p2] <> ';') and (Attrs[p2] <> '''') and (Attrs[p2] <> '"') do
      Inc(p2);
    Result := Trim(Copy(Attrs, p, p2 - p));
  end;
end;

{ Extract font-size from style attribute: font-size: Npt or font-size: Npx }
function ExtractFontSize(const Attrs: string): Single;
var
  p, p2: Integer;
  numStr: string;
begin
  Result := 0;
  p := Pos('font-size', LowerCase(Attrs));
  if p = 0 then Exit;
  p := PosEx(':', Attrs, p);
  if p = 0 then Exit;
  Inc(p);
  while (p <= Length(Attrs)) and (Attrs[p] = ' ') do Inc(p);
  // Skip optional quote
  if (p <= Length(Attrs)) and (Attrs[p] = '''') then Inc(p);
  p2 := p;
  while (p2 <= Length(Attrs)) and (Attrs[p2] in ['0'..'9', '.']) do Inc(p2);
  numStr := Copy(Attrs, p, p2 - p);
  if numStr <> '' then
    Result := StrToFloatDef(numStr, 0);
end;

{ Extract face attribute from <font face="..."> }
function ExtractFontFace(const Attrs: string): string;
var
  p, p2: Integer;
  delim: Char;
begin
  Result := '';
  p := Pos('face', LowerCase(Attrs));
  if p = 0 then Exit;
  p := PosEx('=', Attrs, p);
  if p = 0 then Exit;
  Inc(p);
  while (p <= Length(Attrs)) and (Attrs[p] = ' ') do Inc(p);
  if (p > Length(Attrs)) then Exit;
  if Attrs[p] in ['"', ''''] then
  begin
    delim := Attrs[p];
    Inc(p);
    p2 := PosEx(delim, Attrs, p);
    if p2 > 0 then
      Result := Copy(Attrs, p, p2 - p);
  end
  else
  begin
    p2 := p;
    while (p2 <= Length(Attrs)) and (Attrs[p2] <> ' ') and (Attrs[p2] <> '>') do Inc(p2);
    Result := Trim(Copy(Attrs, p, p2 - p));
  end;
end;

{ Extract legacy size attribute from <font size="N"> and convert to pt }
function ExtractLegacyFontSize(const Attrs: string): Single;
var
  p, p2: Integer;
  numStr: string;
  sizeVal: Integer;
begin
  Result := 0;
  p := Pos('size', LowerCase(Attrs));
  if p = 0 then Exit;
  p := PosEx('=', Attrs, p);
  if p = 0 then Exit;
  Inc(p);
  while (p <= Length(Attrs)) and (Attrs[p] = ' ') do Inc(p);
  if (p <= Length(Attrs)) and (Attrs[p] in ['"', '''']) then Inc(p);
  p2 := p;
  while (p2 <= Length(Attrs)) and (Attrs[p2] in ['0'..'9']) do Inc(p2);
  numStr := Copy(Attrs, p, p2 - p);
  if numStr = '' then Exit;
  sizeVal := StrToIntDef(numStr, 0);
  case sizeVal of
    1: Result := 8;
    2: Result := 10;
    3: Result := 12;
    4: Result := 14;
    5: Result := 18;
    6: Result := 24;
    7: Result := 36;
  else
    Result := sizeVal; // Assume already a pt size
  end;
end;

function ParseHtml(const AText: string; const DefaultFontFamily: string): THtmlSegmentList;
var
  P, PStart, PAttrStart: PChar;
  CurrentStyles: THtmlStyles;
  TagName: string;
  TagAttrs: string;
  IsClosing: Boolean;
  CurrentFontFamily: string;
  CurrentFontSize: Single;
  CurrentHasFontSize: Boolean;
  FontFamilyStack: TStack<string>;
  FontSizeStack: TStack<Single>;
  ExtFamily: string;
  ExtSize: Single;

  procedure AddSegment(const Text: string);
  var
    LastSeg: THtmlSegment;
  begin
    if Text = '' then Exit;

    // Do not merge if the new text is a newline (from <br>)
    if Text = #13#10 then
    begin
      Result.Add(THtmlSegment.Create(Text, CurrentStyles, CurrentFontFamily, CurrentFontSize, CurrentHasFontSize));
      Exit;
    end;

    // optimization: merge with previous segment if styles AND font are the same AND previous segment is NOT a newline
    if Result.Count > 0 then
    begin
      LastSeg := Result.Last;
      if (LastSeg.Styles = CurrentStyles) and (LastSeg.Text <> #13#10)
         and (LastSeg.FontFamily = CurrentFontFamily)
         and (LastSeg.FontSize = CurrentFontSize)
         and (LastSeg.HasFontSize = CurrentHasFontSize) then
      begin
        LastSeg.Text := LastSeg.Text + Text;
        Exit;
      end;
    end;
    Result.Add(THtmlSegment.Create(Text, CurrentStyles, CurrentFontFamily, CurrentFontSize, CurrentHasFontSize));
  end;

begin
  Result := THtmlSegmentList.Create(True); // Owns objects
  CurrentStyles := [];
  CurrentFontFamily := DefaultFontFamily;
  CurrentFontSize := 0;
  CurrentHasFontSize := False;

  FontFamilyStack := TStack<string>.Create;
  FontSizeStack := TStack<Single>.Create;
  try
    FontFamilyStack.Push(DefaultFontFamily);
    FontSizeStack.Push(0);

    P := PChar(AText);
    while P^ <> #0 do
    begin
      PStart := P;

      // 1. Accumulate text until the next tag '<'
      while (P^ <> #0) and (P^ <> '<') do
        Inc(P);

      if P > PStart then
      begin
        AddSegment(DecodeHtml(Copy(AText, PStart - PChar(AText) + 1, P - PStart)));
      end;

      // 2. Process tag
      if P^ = '<' then
      begin
        Inc(P); // Skip '<'
        IsClosing := False;
        if P^ = '/' then
        begin
          IsClosing := True;
          Inc(P);
        end;

        // Extract Tag Name (stop at '>', ' ', or end)
        PStart := P;
        while (P^ <> #0) and (P^ <> '>') and (P^ <> ' ') do
          Inc(P);

        TagName := LowerCase(Copy(AText, PStart - PChar(AText) + 1, P - PStart));

        // Extract attributes (everything between tag name and '>')
        PAttrStart := P;
        while (P^ <> #0) and (P^ <> '>') do
          Inc(P);
        TagAttrs := Copy(AText, PAttrStart - PChar(AText) + 1, P - PAttrStart);

        if P^ = '>' then
          Inc(P); // Skip '>'

        // Update CurrentStyles based on TagName
        if (TagName = 'b') or (TagName = 'strong') then
        begin
          if IsClosing then Exclude(CurrentStyles, hsBold) else Include(CurrentStyles, hsBold);
        end
        else if (TagName = 'i') or (TagName = 'em') then
        begin
          if IsClosing then Exclude(CurrentStyles, hsItalic) else Include(CurrentStyles, hsItalic);
        end
        else if (TagName = 'u') then
        begin
          if IsClosing then Exclude(CurrentStyles, hsUnderline) else Include(CurrentStyles, hsUnderline);
        end
        else if (TagName = 's') or (TagName = 'strike') or (TagName = 'del') then
        begin
          if IsClosing then Exclude(CurrentStyles, hsStrikeOut) else Include(CurrentStyles, hsStrikeOut);
        end
        else if (TagName = 'br') then
        begin
           // <br> is treated as a newline character in the text
           AddSegment(#13#10);
        end
        else if (TagName = 'span') then
        begin
          if IsClosing then
          begin
            if FontFamilyStack.Count > 1 then
            begin
              FontFamilyStack.Pop;
              CurrentFontFamily := FontFamilyStack.Peek;
            end;
            if FontSizeStack.Count > 1 then
            begin
              FontSizeStack.Pop;
              ExtSize := FontSizeStack.Peek;
              if ExtSize > 0 then
              begin
                CurrentFontSize := ExtSize;
                CurrentHasFontSize := True;
              end
              else
              begin
                CurrentFontSize := 0;
                CurrentHasFontSize := False;
              end;
            end;
          end
          else
          begin
            ExtFamily := ExtractFontFamily(TagAttrs);
            if ExtFamily <> '' then
            begin
              FontFamilyStack.Push(ExtFamily);
              CurrentFontFamily := ExtFamily;
            end
            else
              FontFamilyStack.Push(CurrentFontFamily);

            ExtSize := ExtractFontSize(TagAttrs);
            if ExtSize > 0 then
            begin
              FontSizeStack.Push(ExtSize);
              CurrentFontSize := ExtSize;
              CurrentHasFontSize := True;
            end
            else
              FontSizeStack.Push(CurrentFontSize);
          end;
        end
        else if (TagName = 'font') then
        begin
          if IsClosing then
          begin
            if FontFamilyStack.Count > 1 then
            begin
              FontFamilyStack.Pop;
              CurrentFontFamily := FontFamilyStack.Peek;
            end;
            if FontSizeStack.Count > 1 then
            begin
              FontSizeStack.Pop;
              ExtSize := FontSizeStack.Peek;
              if ExtSize > 0 then
              begin
                CurrentFontSize := ExtSize;
                CurrentHasFontSize := True;
              end
              else
              begin
                CurrentFontSize := 0;
                CurrentHasFontSize := False;
              end;
            end;
          end
          else
          begin
            ExtFamily := ExtractFontFace(TagAttrs);
            if ExtFamily <> '' then
            begin
              FontFamilyStack.Push(ExtFamily);
              CurrentFontFamily := ExtFamily;
            end
            else
              FontFamilyStack.Push(CurrentFontFamily);

            ExtSize := ExtractLegacyFontSize(TagAttrs);
            if ExtSize > 0 then
            begin
              FontSizeStack.Push(ExtSize);
              CurrentFontSize := ExtSize;
              CurrentHasFontSize := True;
            end
            else
              FontSizeStack.Push(CurrentFontSize);
          end;
        end;
        // Other unknown tags are silently ignored (stripped)
      end;
    end;
  finally
    FontFamilyStack.Free;
    FontSizeStack.Free;
  end;
end;

end.
