{ Tests of the Hub/AI client base units under Free Pascal (Phase 7.1):
  JSON, encoding and date shims against Delphi's output, the HTTP client
  shim (local HTTP/HTTPS servers), and the rpdbHttp driver, the AI client
  methods and the Hub login against a local fake Hub. No external network.

  HubClientTest            run all the tests (exit code 1 on the first failure)
  HubClientTest --verbose  print every check
  HubClientTest --smoke    only a manual TLS check against the real Hub
                           (unauthenticated GET /api/Tiers)

  The program runs itself again with LOCALAPPDATA (and HOME on Linux) set to
  a temporary folder, so the Hub settings of the user are never read or
  written. TLS tests need OpenSSL and the openssl command (Windows: put for
  example C:\Program Files\Git\mingw64\bin in the PATH); they are skipped
  otherwise. }
program HubClientTest;

{$mode delphi}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  LazUTF8, SysUtils, Classes, process, rptypes, rphttpclientfpc, utestutil,
  ujsontests, uhttptests, uhubtests;

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
  LSandbox, LVar: string;
  I: Integer;
begin
  LSandbox := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'rphubtest_' +
    IntToStr(GetProcessID);
  ForceDirectories(LSandbox);
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := ParamStr(0);
    for I := 1 to ParamCount do
      LProcess.Parameters.Add(ParamStr(I));
    for I := 1 to GetEnvironmentVariableCount do
    begin
      LVar := GetEnvironmentString(I);
      if SameText(Copy(LVar, 1, 13), 'LOCALAPPDATA=') then
        Continue;
{$IFNDEF MSWINDOWS}
      if Copy(LVar, 1, 5) = 'HOME=' then
        Continue;
{$ENDIF}
      LProcess.Environment.Add(LVar);
    end;
    LProcess.Environment.Add('LOCALAPPDATA=' + LSandbox);
{$IFNDEF MSWINDOWS}
    LProcess.Environment.Add('HOME=' + LSandbox);
{$ENDIF}
    LProcess.Environment.Add('RPHUBTEST_CHILD=1');
    LProcess.Options := [poWaitOnExit];
    LProcess.Execute;
    Result := LProcess.ExitStatus;
  finally
    LProcess.Free;
    DeleteTree(LSandbox);
  end;
end;

procedure SmokeTest;
var
  LClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LError: string;
begin
  Section('Smoke test against ' + HUB_API_URL + ' (real network)');
  if not RpOpenSSLAvailable(LError) then
    Fail(LError);
  LClient := TNetHTTPClient.Create(nil);
  try
    LResponse := LClient.Get(HUB_API_URL + '/api/Tiers');
    Log('  HTTP ' + IntToStr(LResponse.StatusCode) + ' ' + LResponse.StatusText);
    Log('  ' + Copy(LResponse.ContentAsString, 1, 300));
    Check((LResponse.StatusCode >= 200) and (LResponse.StatusCode < 500),
      'TLS connection with a verified certificate');
  finally
    LClient.Free;
  end;
end;

begin
  Verbose := HasOption('--verbose');
  if HasOption('--smoke') then
  begin
    SmokeTest;
    Log('[SMOKE_PASSED]');
    Exit;
  end;
  if GetEnvironmentVariable('RPHUBTEST_CHILD') = '' then
  begin
    ExitCode := RunSandboxed;
    Exit;
  end;
  try
    RunJsonTests;
    RunHttpTests;
    RunHubTests;
  except
    on E: Exception do
      Fail('unexpected exception ' + E.ClassName + ': ' + E.Message);
  end;
  Log('');
  Log(Format('[TESTS_PASSED] %d checks, %d skipped', [TestCount, SkipCount]));
end.
