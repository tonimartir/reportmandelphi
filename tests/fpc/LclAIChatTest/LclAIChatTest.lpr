{ Tests of the LCL foundation of the AI assistants (Phase 7.2) against a
  local fake Hub. No external network.

  LclAIChatTest                 run all the tests (exit code 1 on failure)
  LclAIChatTest --verbose       print every check
  LclAIChatTest --shots=<dir>   also save screenshots of the frames

  The program runs itself again with LOCALAPPDATA set to a temporary folder
  (the Hub session of the user is never read or written) and heaptrc
  writing its report to a file there; the run fails if that report shows
  unfreed memory. }
program LclAIChatTest;

{$mode delphi}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  Interfaces, SysUtils, Classes, Forms, process, utestutil, uaichattests,
  uaiexprtests, uaisqltests;

function OptionValue(const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ParamCount do
    if SameText(Copy(ParamStr(I), 1, Length(AName) + 1), AName + '=') then
      Exit(Copy(ParamStr(I), Length(AName) + 2, MaxInt));
end;

function HasOption(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), AName) then
      Exit(True);
end;

procedure DeleteTree(const APath: string);
var
  LSearch: TSearchRec;
  LBase: string;
begin
  LBase := IncludeTrailingPathDelimiter(APath);
  if FindFirst(LBase + AllFilesMask, faAnyFile, LSearch) = 0 then
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then
        Continue;
      if (LSearch.Attr and faDirectory) <> 0 then
        DeleteTree(LBase + LSearch.Name)
      else
        DeleteFile(LBase + LSearch.Name);
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
  RemoveDir(APath);
end;

// Runs this program again inside a sandbox; returns its exit code
function RunSandboxed: Integer;
var
  LProcess: TProcess;
  LSandbox, LVar, LHeapLog: string;
  LLog: TStringList;
  I: Integer;
begin
  LSandbox := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'rpaichattest_' +
    IntToStr(GetProcessID);
  ForceDirectories(LSandbox);
  LHeapLog := IncludeTrailingPathDelimiter(LSandbox) + 'heaptrc.log';
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := ParamStr(0);
    for I := 1 to ParamCount do
      LProcess.Parameters.Add(ParamStr(I));
    for I := 1 to GetEnvironmentVariableCount do
    begin
      LVar := GetEnvironmentString(I);
      if SameText(Copy(LVar, 1, 13), 'LOCALAPPDATA=') or SameText(Copy(LVar, 1, 8), 'HEAPTRC=') then
        Continue;
      LProcess.Environment.Add(LVar);
    end;
    LProcess.Environment.Add('LOCALAPPDATA=' + LSandbox);
    LProcess.Environment.Add('HEAPTRC=log=' + LHeapLog);
    LProcess.Environment.Add('RPAICHATTEST_CHILD=1');
    LProcess.Options := [poWaitOnExit];
    LProcess.Execute;
    Result := LProcess.ExitStatus;
    if Result = 0 then
    begin
      LLog := TStringList.Create;
      try
        if FileExists(LHeapLog) then
          LLog.LoadFromFile(LHeapLog);
        if Pos(#10'0 unfreed memory blocks', #10 + AdjustLineBreaks(LLog.Text, tlbsLF)) > 0 then
          WriteLn('heaptrc: 0 unfreed memory blocks')
        else
        begin
          WriteLn('[TEST_FAILED] heaptrc reports unfreed memory (or no report):');
          WriteLn(Copy(LLog.Text, 1, 6000));
          Result := 1;
        end;
      finally
        LLog.Free;
      end;
    end;
  finally
    LProcess.Free;
    DeleteTree(LSandbox);
  end;
end;

begin
  Verbose := HasOption('--verbose');
  if GetEnvironmentVariable('RPAICHATTEST_CHILD') = '' then
  begin
    ExitCode := RunSandboxed;
    Exit;
  end;
  Application.Scaled := True;
  Application.Initialize;
  try
    RunAIChatTests(OptionValue('--shots'));
    RunAIExprTests(OptionValue('--shots'));
    RunAISqlTests(OptionValue('--shots'));
  except
    on E: Exception do
      Fail('unexpected exception ' + E.ClassName + ': ' + E.Message);
  end;
  Log('');
  Log(Format('[TESTS_PASSED] %d checks, %d skipped', [TestCount, SkipCount]));
end.
