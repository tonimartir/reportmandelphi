{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpsysutilsfpc                                   }
{       Delphi System.SysUtils / System.DateUtils       }
{       functions missing or different in Free Pascal   }
{                                                       }
{       This file is under the MPL license              }
{       A copy of the license is in the license.txt     }
{       file included with this distribution            }
{                                                       }
{*******************************************************}

// Pieces of Delphi's RTL used by the shared Hub units:
// - TFormatSettings.Invariant (not in FPC 3.2.2), as a record helper.
// - ISO 8601 dates. FPC 3.2.2's DateUtils has ISO8601ToDate, but it rejects
//   dates without a time, only accepts 3 fraction digits and misreads
//   "2024-01-15" as a time zone. The Hub (.NET) sends "2024-01-15T10:30:00",
//   with up to 7 fraction digits, with or without "Z"/offset. These
//   functions follow Delphi's System.DateUtils: a value without time zone is
//   UTC; with AReturnUTC = False the result is converted to local time.
//   List this unit after DateUtils so that these versions are used.

unit rpsysutilsfpc;

{$mode delphi}{$H+}

interface

uses
  SysUtils;

type
  TRpFormatSettingsHelper = record helper for TFormatSettings
  public
    // Culture independent settings: '.' decimals, ',' thousands,
    // MM/dd/yyyy dates and HH:mm:ss times
    class function Invariant: TFormatSettings; static;
  end;

function TryISO8601ToDate(const AISODate: string; out Value: TDateTime;
  AReturnUTC: Boolean = True): Boolean;
function ISO8601ToDate(const AISODate: string; AReturnUTC: Boolean = True): TDateTime;
function DateToISO8601(const ADate: TDateTime; AInputIsUTC: Boolean = True): string;

implementation

uses
  DateUtils;

{ TRpFormatSettingsHelper }

class function TRpFormatSettingsHelper.Invariant: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.CurrencyFormat := 0;
  Result.NegCurrFormat := 0;
  Result.ThousandSeparator := ',';
  Result.DecimalSeparator := '.';
  Result.CurrencyDecimals := 2;
  Result.DateSeparator := '/';
  Result.TimeSeparator := ':';
  Result.ListSeparator := ',';
  Result.CurrencyString := '';
  Result.ShortDateFormat := 'MM/dd/yyyy';
  Result.LongDateFormat := 'dddd, dd MMMMM yyyy';
  Result.TimeAMString := 'AM';
  Result.TimePMString := 'PM';
  Result.ShortTimeFormat := 'HH:mm';
  Result.LongTimeFormat := 'HH:mm:ss';
end;

function TryISO8601ToDate(const AISODate: string; out Value: TDateTime;
  AReturnUTC: Boolean): Boolean;
var
  P, LLen: Integer;
  LYear, LMonth, LDay, LHour, LMinute, LSec, LMSec: Integer;
  LOffsetMinutes, LOffsetHours, LOffsetMins: Integer;
  LHasTZ, LNegative, LAddDay, LAddMinute, LAddSecond: Boolean;
  LDate, LTime: TDateTime;
  LFraction: string;
  LSign: Char;

  function Digits(ACount: Integer; out AValue: Integer): Boolean;
  var
    K: Integer;
  begin
    AValue := 0;
    Result := P + ACount - 1 <= LLen;
    if not Result then
      Exit;
    for K := 0 to ACount - 1 do
    begin
      if not (AISODate[P + K] in ['0'..'9']) then
        Exit(False);
      AValue := AValue * 10 + Ord(AISODate[P + K]) - Ord('0');
    end;
    Inc(P, ACount);
  end;

  function Peek: Char;
  begin
    if P <= LLen then
      Result := AISODate[P]
    else
      Result := #0;
  end;

begin
  Result := False;
  Value := 0;
  LLen := Length(AISODate);
  if LLen < 8 then
    Exit;
  LHour := 0;
  LMinute := 0;
  LSec := 0;
  LMSec := 0;
  LHasTZ := False;
  LOffsetMinutes := 0;
  P := 1;
  LNegative := Peek = '-';
  if LNegative then
    Inc(P);
  // Date: YYYY-MM-DD or YYYYMMDD
  if not Digits(4, LYear) then
    Exit;
  if Peek = '-' then
  begin
    Inc(P);
    if not Digits(2, LMonth) or (Peek <> '-') then
      Exit;
    Inc(P);
    if not Digits(2, LDay) then
      Exit;
  end
  else
  begin
    if not Digits(2, LMonth) or not Digits(2, LDay) then
      Exit;
  end;
  if P <= LLen then
  begin
    if AISODate[P] <> 'T' then
      Exit;
    Inc(P);
    // Time: hh[:mm[:ss]] or hhmm[ss]
    if not Digits(2, LHour) then
      Exit;
    if Peek = ':' then
    begin
      Inc(P);
      if not Digits(2, LMinute) then
        Exit;
      if Peek = ':' then
      begin
        Inc(P);
        if not Digits(2, LSec) then
          Exit;
      end;
    end
    else if Peek in ['0'..'9'] then
    begin
      if not Digits(2, LMinute) then
        Exit;
      if Peek in ['0'..'9'] then
        if not Digits(2, LSec) then
          Exit;
    end;
    // Fraction of a second, any number of digits (Delphi keeps milliseconds)
    if Peek in ['.', ','] then
    begin
      Inc(P);
      LFraction := '';
      while (Peek in ['0'..'9']) and (Length(LFraction) < 10) do
      begin
        LFraction := LFraction + Peek;
        Inc(P);
      end;
      if LFraction = '' then
        Exit;
      while Peek in ['0'..'9'] do
        Inc(P);
      LMSec := StrToInt(Copy(LFraction + '000', 1, 3));
    end;
    // Time zone
    if Peek = 'Z' then
    begin
      Inc(P);
      LHasTZ := True;
    end
    else if Peek in ['+', '-'] then
    begin
      LSign := Peek;
      Inc(P);
      if not Digits(2, LOffsetHours) then
        Exit;
      LOffsetMins := 0;
      if Peek = ':' then
      begin
        Inc(P);
        if not Digits(2, LOffsetMins) then
          Exit;
      end
      else if Peek in ['0'..'9'] then
        if not Digits(2, LOffsetMins) then
          Exit;
      LOffsetMinutes := LOffsetHours * 60 + LOffsetMins;
      if LSign = '-' then
        LOffsetMinutes := -LOffsetMinutes;
      LHasTZ := True;
    end;
    if P <= LLen then
      Exit;
  end;
  LAddDay := LHour = 24;
  if LAddDay then
    LHour := 0;
  LAddMinute := LSec = 60;
  if LAddMinute then
    LSec := 0;
  LAddSecond := LMSec = 1000;
  if LAddSecond then
    LMSec := 0;
  if not TryEncodeDate(LYear, LMonth, LDay, LDate) then
    Exit;
  if not TryEncodeTime(LHour, LMinute, LSec, LMSec, LTime) then
    Exit;
  if LNegative then
    LDate := -LDate;
  if LDate >= 0 then
    Value := LDate + LTime
  else
    Value := LDate - LTime;
  if LAddDay then
    Value := IncDay(Value);
  if LAddMinute then
    Value := IncMinute(Value);
  if LAddSecond then
    Value := IncSecond(Value);
  // To UTC, then to local time if asked
  if LHasTZ and (LOffsetMinutes <> 0) then
    Value := IncMinute(Value, -LOffsetMinutes);
  if not AReturnUTC then
    Value := UniversalTimeToLocal(Value);
  Result := True;
end;

function ISO8601ToDate(const AISODate: string; AReturnUTC: Boolean): TDateTime;
begin
  if not TryISO8601ToDate(AISODate, Result, AReturnUTC) then
    raise EConvertError.CreateFmt('''%s'' is not a valid ISO 8601 date/time', [AISODate]);
end;

function DateToISO8601(const ADate: TDateTime; AInputIsUTC: Boolean): string;
var
  LBias: Integer;
  LSign: Char;
begin
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"."zzz', ADate) + 'Z';
  if not AInputIsUTC then
  begin
    // Minutes to add to local time to get UTC
    LBias := Round(MinuteSpan(LocalTimeToUniversal(ADate), ADate));
    if LocalTimeToUniversal(ADate) > ADate then
      LBias := -LBias;
    // Delphi writes the offset of the local zone (sign of local - UTC)
    if LBias <> 0 then
    begin
      SetLength(Result, Length(Result) - 1);
      if LBias > 0 then
        LSign := '+'
      else
        LSign := '-';
      LBias := Abs(LBias);
      Result := Result + LSign + Format('%.2d:%.2d', [LBias div 60, LBias mod 60]);
    end;
  end;
end;

end.
