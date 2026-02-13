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
  public
    constructor Create(const AText: string; AStyles: THtmlStyles);
    property Text: string read FText write FText;
    property Styles: THtmlStyles read FStyles write FStyles;
  end;

  { A list of HTML segments }
  THtmlSegmentList = class(TObjectList<THtmlSegment>)
  end;

{ Parses an HTML string into a list of segments with applied styles.
  Supports <b>, <strong>, <i>, <em>, <u>, <s>, <strike>, <del>, <br> tags.
  Decodes basic HTML entities. }
function ParseHtml(const AText: string): THtmlSegmentList;

implementation

uses
  StrUtils;

{ THtmlSegment }

constructor THtmlSegment.Create(const AText: string; AStyles: THtmlStyles);
begin
  FText := AText;
  FStyles := AStyles;
end;

{ Helper: Decode basic HTML entities }
function DecodeHtml(const S: string): string;
begin
  Result := StringReplace(S, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&nbsp;', #160, [rfReplaceAll]);
  Result := StringReplace(Result, '&apos;', '''', [rfReplaceAll]);
end;

function ParseHtml(const AText: string): THtmlSegmentList;
var
  P, PStart: PChar;
  CurrentStyles: THtmlStyles;
  TagName: string;
  IsClosing: Boolean;

  procedure AddSegment(const Text: string);
  var
    LastSeg: THtmlSegment;
  begin
    if Text = '' then Exit;

    // Do not merge if the new text is a newline (from <br>)
    if Text = #13#10 then
    begin
      Result.Add(THtmlSegment.Create(Text, CurrentStyles));
      Exit;
    end;

    // optimization: merge with previous segment if styles are the same AND previous segment is NOT a newline
    if Result.Count > 0 then
    begin
      LastSeg := Result.Last;
      if (LastSeg.Styles = CurrentStyles) and (LastSeg.Text <> #13#10) then
      begin
        LastSeg.Text := LastSeg.Text + Text;
        Exit;
      end;
    end;
    Result.Add(THtmlSegment.Create(Text, CurrentStyles));
  end;

begin
  Result := THtmlSegmentList.Create(True); // Owns objects
  CurrentStyles := [];

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

      // Extract Tag Name
      PStart := P;
      while (P^ <> #0) and (P^ <> '>') and (P^ <> ' ') do
        Inc(P);

      TagName := LowerCase(Copy(AText, PStart - PChar(AText) + 1, P - PStart));

      // Skip attributes/whitespace until '>'
      while (P^ <> #0) and (P^ <> '>') do
        Inc(P);

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
      else
      begin
        // Unknown or unsupported tags (e.g. <font>, <span>) are ignored.
        // The parser effectively strips them.
      end;
    end;
  end;
end;

end.
