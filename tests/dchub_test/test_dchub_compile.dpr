program test_dchub_compile;

{*******************************************************}
{                                                       }
{   Smoke test for rpdchub.pas - only verifies that the }
{   unit compiles and instantiates without crashing. No }
{   network activity.                                   }
{                                                       }
{*******************************************************}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  Datasnap.DBClient,
  MidasLib,
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
begin
  Writeln('=== rpdchub compile smoke test ===');
  if not RpDcInitialize(ResolveDllPath) then
  begin
    Writeln('FAIL: RpDcInitialize: ', RpDcLastInitError);
    Halt(1);
  end;
  client := TRpDcHubClient.Create('https://localhost:1234', 'dummy-token');
  try
    Writeln('Constructed OK. ConnectionMode (pre-open) = ',
            Integer(client.ConnectionMode));
  finally
    client.Free;
  end;
  RpDcShutdown;
  Writeln('PASSED');
end.
