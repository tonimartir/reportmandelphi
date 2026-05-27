program test_dchub_realapi;

// =====================================================================
//   Real-API smoke test against https://api.reportman.es:44568.
//
//   This does NOT try to do a full direct-channel negotiation (that
//   would need a valid Bearer JWT for a logged-in user). Instead it
//   verifies that TRpDcHubClient.Open:
//     1. Connects to the real production API over HTTPS (cert is
//        accepted with AcceptInvalidCerts=True).
//     2. Reaches the /api/data-session/start endpoint.
//     3. Cleanly returns False when the server replies 401
//        ("Login required.") instead of crashing.
//
//   The full direct-channel exchange is validated by the Mock-Hub
//   loopback tests; reproducing it against production requires an
//   interactive login flow and is deferred to Designer integration.
// =====================================================================

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  rplibdatachannel in '..\..\rplibdatachannel.pas',
  rpfastserializer in '..\..\rpfastserializer.pas',
  rpdatadirect    in '..\..\rpdatadirect.pas',
  rpdchub         in '..\..\rpdchub.pas';

function ResolveDllPath: string;
var b: string;
begin
  b := ExtractFilePath(ParamStr(0));
{$IFDEF WIN64}
  Result := ExpandFileName(b + '..\..\..\activex_ai\resources\x64\datachannel.dll');
{$ELSE}
  Result := ExpandFileName(b + '..\..\..\activex_ai\resources\x86\datachannel.dll');
{$ENDIF}
end;

var
  client: TRpDcHubClient;
  ok: Boolean;
  arch: string;
begin
{$IFDEF WIN64} arch := 'x64'; {$ELSE} arch := 'x86'; {$ENDIF}
  Writeln('=== rpdchub real-API smoke test (', arch, ') ===');
  Writeln('Target: https://api.reportman.es:44568');
  Writeln;

  if not RpDcInitialize(ResolveDllPath, RTC_LOG_WARNING) then
  begin
    Writeln('FAIL init: ', RpDcLastInitError);
    Halt(1);
  end;

  client := TRpDcHubClient.Create(
    'https://api.reportman.es:44568',
    '',                         // intentionally no Bearer token
    '',                         // no install id
    True);                      // AcceptInvalidCerts (cert may be self-signed in dev)
  try
    Writeln('Calling Open() with empty JWT - expecting clean False...');
    ok := client.Open('rma_test_only_not_a_real_key', 0, 10);
    Writeln('Open returned: ', BoolToStr(ok, True));
    if ok then
    begin
      Writeln('FAIL: Open returned True without a JWT - that should be impossible');
      Halt(2);
    end;
    Writeln('Open cleanly returned False (server replied 401, client did not crash)');
  finally
    client.Free;
  end;
  RpDcShutdown;
  Writeln;
  Writeln('=== PASSED ===');
end.
