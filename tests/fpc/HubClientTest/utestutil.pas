{ Minimal test helpers for HubClientTest: every check prints a line; the
  first failure prints [TEST_FAILED] and ends the program with exit code 1. }
unit utestutil;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes;

var
  TestCount: Integer = 0;
  SkipCount: Integer = 0;
  Verbose: Boolean = False;

procedure Log(const S: string);
procedure Section(const S: string);
procedure Pass(const AMessage: string);
procedure Fail(const AMessage: string);
procedure Check(ACondition: Boolean; const AMessage: string);
procedure CheckEquals(const AExpected, AActual, AMessage: string); overload;
procedure CheckEquals(AExpected, AActual: Int64; const AMessage: string); overload;
procedure CheckContains(const ASubText, AText, AMessage: string);
procedure Skip(const AMessage: string);
// Memory currently allocated by the heap manager (for leak checks)
function HeapUsed: PtrUInt;
function ElapsedMs(AStart: QWord): Int64;

implementation

uses
{$IFDEF MSWINDOWS}
  Windows;
{$ELSE}
  BaseUnix;
{$ENDIF}

procedure Log(const S: string);
begin
  WriteLn(S);
  Flush(Output);
end;

procedure Section(const S: string);
begin
  Log('');
  Log('== ' + S);
end;

procedure Pass(const AMessage: string);
begin
  Inc(TestCount);
  if Verbose then
    Log('  ok   ' + AMessage);
end;

procedure Fail(const AMessage: string);
begin
  Log('[TEST_FAILED] ' + AMessage);
  // Leave at once with exit code 1: the fake servers may still have
  // threads running, and finalization with them alive can crash
{$IFDEF MSWINDOWS}
  ExitProcess(1);
{$ELSE}
  fpExit(1);
{$ENDIF}
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Pass(AMessage)
  else
    Fail(AMessage);
end;

procedure CheckEquals(const AExpected, AActual, AMessage: string);
begin
  if AExpected = AActual then
    Pass(AMessage)
  else
    Fail(AMessage + sLineBreak + '    expected: ' + AExpected + sLineBreak +
      '    actual:   ' + AActual);
end;

procedure CheckEquals(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected = AActual then
    Pass(AMessage)
  else
    Fail(AMessage + Format(' (expected %d, actual %d)', [AExpected, AActual]));
end;

procedure CheckContains(const ASubText, AText, AMessage: string);
begin
  if Pos(ASubText, AText) > 0 then
    Pass(AMessage)
  else
    Fail(AMessage + sLineBreak + '    expected to contain: ' + ASubText + sLineBreak +
      '    actual: ' + AText);
end;

procedure Skip(const AMessage: string);
begin
  Inc(SkipCount);
  Log('  SKIP ' + AMessage);
end;

function HeapUsed: PtrUInt;
begin
  Result := GetFPCHeapStatus.CurrHeapUsed;
end;

function ElapsedMs(AStart: QWord): Int64;
begin
  Result := Int64(GetTickCount64 - AStart);
end;

end.
