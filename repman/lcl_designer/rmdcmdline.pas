unit rmdcmdline;

{*******************************************************}
{                                                       }
{       Report Manager Designer - LCL                   }
{                                                       }
{       rmdcmdline.pas                                  }
{       Command line and data folders of the            }
{       standalone LCL designer (repmandesigner_lcl)    }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

{ The program lists this unit before Interfaces: its initialization answers
  --help and --version, and reports a missing display (GTK2, Qt6), before the
  LCL widgetset connects to the display (which would exit silently or, Qt,
  abort). With Qt6 it also chooses the Qt platform: X11 (also XWayland)
  unless the user sets QT_QPA_PLATFORM (see SetupQtPlatform).

  Runtime files:
  - Translations (reportmanres.*): the engine (rptranslator) reads them next
    to the executable (ParamStr(0), which FPC resolves through
    /proc/self/exe, so a /usr/bin symlink still finds them). Windows also
    has them as resources. On macOS ParamStr(0) is the link of the bundle
    (X.app/Contents/MacOS): the engine and DataDirs also look in
    Contents/Resources and next to the real executable (RpDarwinDataDirs),
    and the language is the one of the system (RpDarwinUserLanguage) when
    there is no LANG, as with the applications started from the Finder.
  - Samples: <exe dir>/samples, <exe dir>/repsamples (development tree) or
    <prefix>/share/reportman-designer/samples (<prefix> = <exe dir>/..).
  - Preferences (window position, last folder): Linux
    $XDG_CONFIG_HOME/reportman/ (default ~/.config/reportman/), Windows
    %LOCALAPPDATA%\reportman\.
  - LCL texts (buttons of the message dialogs, standard dialogs...): the
    LCLStrConsts resourcestrings are translated from
    <exe dir>/languages/lclstrconsts.<lang>.po (the files Lazarus ships in
    lcl/languages; the Linux packages install them), in the language the
    engine uses for reportmanres.*. Without the file the LCL stays in English. }

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, gettext, Translations, rpmdconsts
  {$IFDEF DARWIN}, rpdarwinlibs{$ENDIF};

const
  APP_NAME = 'Report Manager Designer';
  APP_ID = 'reportman-designer';
  CONFIG_SUBDIR = 'reportman';
  CONFIG_FILE = 'designer_lcl.ini';
  // --check-https without a url: the server of the login and the AI
  CHECK_HTTPS_URL = 'https://aiapi.reportman.es/';
  // -dLCL<widgetset> comes from the usage options of the LCL package
  {$IF DEFINED(LCLGTK2)}
  WIDGETSET = 'gtk2';
  {$ELSEIF DEFINED(LCLQT5)}
  WIDGETSET = 'qt5';
  {$ELSEIF DEFINED(LCLQT6)}
  WIDGETSET = 'qt6';
  {$ELSEIF DEFINED(LCLWIN32)}
  WIDGETSET = 'win32';
  {$ELSEIF DEFINED(LCLCOCOA)}
  WIDGETSET = 'cocoa';
  {$ELSE}
  WIDGETSET = 'other';
  {$IFEND}

// Writes a line to stdout/stderr (ignored when there is no console)
procedure WriteStd(const S: string; ToErr: Boolean);
function ExeDir: string;
function FindSamplesDir: string;
function FindTranslationsDir: string;
function UserConfigDir: string;
function ConfigFileName: string;
// First non-option argument (a path or a file:// URI), '' if none
function CommandLineFile: string;
// The lclstrconsts .po file for the user language, '' if there is none
function LCLTranslationFile: string;
// Translates the LCL resourcestrings (call it before Application.Initialize)
procedure TranslateLCL;

implementation

uses
  openssl, rphttpclientfpc;

procedure WriteStd(const S: string; ToErr: Boolean);
begin
  {$I-}
  if ToErr then
  begin
    WriteLn(StdErr, S);
    Flush(StdErr);
  end
  else
  begin
    WriteLn(S);
    Flush(Output);
  end;
  {$I+}
  IOResult;
end;

function ExeDir: string;
begin
  Result := ExtractFilePath(ExpandFileName(ParamStr(0)));
end;

// Directories where the packaged data files can be found, in order
function DataDirs: TStringList;
{$IFDEF UNIX}
var
  appdir: string;
{$ENDIF}
begin
  Result := TStringList.Create;
  {$IFDEF DARWIN}
  // An application bundle: Contents/Resources and the folder of the real
  // executable (ParamStr(0) is the link in Contents/MacOS)
  for appdir in RpDarwinDataDirs do
    if Result.IndexOf(appdir) < 0 then
      Result.Add(appdir);
  {$ENDIF}
  Result.Add(ExeDir);
  Result.Add(ExpandFileName(ExeDir + '..' + PathDelim + 'share' + PathDelim +
    APP_ID) + PathDelim);
  {$IFDEF UNIX}
  // AppImage: $APPDIR is the root of the mounted image
  appdir := GetEnvironmentVariable('APPDIR');
  if appdir <> '' then
    Result.Add(IncludeTrailingPathDelimiter(appdir) + 'usr/share/' + APP_ID + '/');
  Result.Add('/usr/local/share/' + APP_ID + '/');
  Result.Add('/usr/share/' + APP_ID + '/');
  {$ENDIF}
end;

function FindSamplesDir: string;
var
  dirs: TStringList;
  i: Integer;
begin
  Result := '';
  dirs := DataDirs;
  try
    for i := 0 to dirs.Count - 1 do
    begin
      if DirectoryExists(dirs[i] + 'samples') then
        Exit(dirs[i] + 'samples');
      if DirectoryExists(dirs[i] + 'repsamples') then
        Exit(dirs[i] + 'repsamples');
    end;
  finally
    dirs.Free;
  end;
end;

function FindTranslationsDir: string;
var
  dirs: TStringList;
  i: Integer;
begin
  Result := '';
  dirs := DataDirs;
  try
    for i := 0 to dirs.Count - 1 do
      if FileExists(dirs[i] + 'reportmanres.en') then
        Exit(dirs[i]);
  finally
    dirs.Free;
  end;
end;

function UserConfigDir: string;
var
  base: string;
begin
  {$IFDEF UNIX}
  // XDG Base Directory: $XDG_CONFIG_HOME (absolute) or ~/.config
  base := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if (base = '') or (base[1] <> '/') then
    base := IncludeTrailingPathDelimiter(GetUserDir) + '.config';
  {$ELSE}
  base := GetEnvironmentVariable('LOCALAPPDATA');
  if base = '' then
    base := ExtractFileDir(ExcludeTrailingPathDelimiter(GetAppConfigDir(False)));
  {$ENDIF}
  Result := IncludeTrailingPathDelimiter(base) + CONFIG_SUBDIR + PathDelim;
end;

function ConfigFileName: string;
begin
  Result := UserConfigDir + CONFIG_FILE;
end;

// Accepts plain paths and file:// URIs (some file managers pass URIs)
function ArgToFileName(const Arg: string): string;
var
  i: Integer;
begin
  Result := Arg;
  if not SameText(Copy(Arg, 1, 7), 'file://') then
    Exit;
  Result := '';
  i := 8;
  // file://localhost/path
  if SameText(Copy(Arg, i, 9), 'localhost') then
    Inc(i, 9);
  while i <= Length(Arg) do
  begin
    if (Arg[i] = '%') and (i + 2 <= Length(Arg)) then
    begin
      Result := Result + Chr(StrToIntDef('$' + Copy(Arg, i + 1, 2), Ord('?')));
      Inc(i, 3);
    end
    else
    begin
      Result := Result + Arg[i];
      Inc(i);
    end;
  end;
  {$IFDEF MSWINDOWS}
  // file:///C:/dir/file.rep
  if (Length(Result) > 2) and (Result[1] = '/') and (Result[3] = ':') then
    Delete(Result, 1, 1);
  Result := StringReplace(Result, '/', PathDelim, [rfReplaceAll]);
  {$ENDIF}
end;

function CommandLineFile: string;
var
  i: Integer;
  p: string;
begin
  Result := '';
  for i := 1 to ParamCount do
  begin
    p := ParamStr(i);
    // Options (toolkit ones such as --display) are left to the LCL
    if (Length(p) > 0) and (p[1] = '-') then
      Continue;
    Exit(ArgToFileName(p));
  end;
end;

function LCLTranslationFile: string;
var
  lang, fallback, code, dir: string;
  cands: array[0..2] of string;
  dirs: TStringList;
  i, j, p: Integer;
begin
  Result := '';
  // Same language as the engine (rptranslator): LC_ALL, LC_MESSAGES, LANG on
  // Unix, the user locale on Windows ('es_ES', fallback 'es')
  gettext.GetLanguageIDs(lang, fallback);
  {$IFDEF DARWIN}
  // macOS gives no LANG to the applications started from the Finder
  if lang = '' then
    lang := RpDarwinUserLanguage;
  {$ENDIF}
  // es_ES.UTF-8 / ca_ES@valencia -> es_ES / ca_ES
  p := Pos('.', lang);
  if p > 0 then
    SetLength(lang, p - 1);
  p := Pos('@', lang);
  if p > 0 then
    SetLength(lang, p - 1);
  p := Pos('_', lang);
  if p > 0 then
    code := LowerCase(Copy(lang, 1, p - 1))
  else
    code := LowerCase(lang);
  // C, POSIX... (no language): the LCL stays in English
  if (Length(code) < 2) or (Length(code) > 3) then
    Exit;
  cands[0] := lang;
  cands[1] := code;
  // Lazarus has pt and pt_BR: pt_BR when the country has no file
  if code = 'pt' then
    cands[2] := 'pt_BR'
  else
    cands[2] := '';
  dirs := DataDirs;
  try
    for j := 0 to dirs.Count - 1 do
    begin
      dir := dirs[j] + 'languages' + PathDelim;
      for i := Low(cands) to High(cands) do
        if (cands[i] <> '') and FileExists(dir + 'lclstrconsts.' + cands[i] + '.po') then
          Exit(dir + 'lclstrconsts.' + cands[i] + '.po');
    end;
  finally
    dirs.Free;
  end;
end;

procedure TranslateLCL;
var
  fname: string;
begin
  fname := LCLTranslationFile;
  if fname = '' then
    Exit;
  try
    // gettext has a .mo version with the same name: the .po one is wanted
    Translations.TranslateUnitResourceStrings('lclstrconsts', fname);
  except
    // A damaged .po file only leaves the LCL texts in English
    on E: Exception do
      WriteStd('WARNING: ' + fname + ' not loaded (' + E.Message + ')', True);
  end;
end;

procedure ShowUsage;
begin
  WriteStd(APP_NAME + ' ' + RM_VERSION, False);
  WriteStd('Usage: ' + ExtractFileName(ParamStr(0)) +
    ' [--help] [--version] [--check-https [url]] [report.rep]', False);
  WriteStd('', False);
  WriteStd('  report.rep     report file to open (path or file:// URI)', False);
  WriteStd('  --version      print the version and the data folders, then exit', False);
  WriteStd('  --check-https  connect to ' + CHECK_HTTPS_URL + ' (or url) as the', False);
  WriteStd('                 login and the AI assistants do, print the result and', False);
  WriteStd('                 exit (0: the server answered, 1: it did not)', False);
  WriteStd('  --help         print this help, then exit', False);
end;

{ --check-https: the TLS connection of the login, the AI assistants and the
  Reportman DB Agent driver (rphttpclientfpc, OpenSSL loaded at run time,
  the server certificate verified), without a display. Any HTTP answer
  means that OpenSSL loaded and the certificate was accepted. On macOS it
  shows the OpenSSL that was loaded (Contents/Frameworks in the package). }
procedure CheckHttps(const AURL: string);
var
  client: THTTPClient;
  resp: IHTTPResponse;
  err: string;
begin
  if not RpOpenSSLAvailable(err) then
  begin
    WriteStd('ERROR: ' + err, True);
    Halt(1);
  end;
  {$IFDEF DARWIN}
  WriteStd('OpenSSL:      ' + DLLSSLName + DLLVersions[1] + '.dylib', False);
  {$ENDIF}
  client := THTTPClient.Create;
  try
    try
      resp := client.Get(AURL);
      WriteStd('HTTPS:        ' + AURL + ' -> ' + IntToStr(resp.StatusCode) +
        ' ' + resp.StatusText, False);
      WriteStd('Certificates: ' + RpHttpTrustStoreInfo, False);
    except
      on E: Exception do
      begin
        WriteStd('ERROR: ' + AURL + ': ' + E.ClassName + ': ' + E.Message, True);
        Halt(1);
      end;
    end;
  finally
    client.Free;
  end;
  if resp.StatusCode <= 0 then
    Halt(1);
end;

procedure ShowVersion;
begin
  WriteStd(APP_NAME + ' ' + RM_VERSION + ' (LCL ' + WIDGETSET + ')', False);
  WriteStd('Executable:   ' + ParamStr(0), False);
  WriteStd('Translations: ' + FindTranslationsDir, False);
  WriteStd('LCL language: ' + LCLTranslationFile, False);
  WriteStd('Samples:      ' + FindSamplesDir, False);
  WriteStd('Preferences:  ' + ConfigFileName, False);
end;

{$IF DEFINED(UNIX) AND DEFINED(LCLQT6)}
function setenv(const name, value: PAnsiChar; overwrite: LongInt): LongInt;
  cdecl; external 'c' name 'setenv';

{ Qt6 platform plugin. Qt reads QT_QPA_PLATFORM when the widgetset creates
  the QApplication, after this unit's initialization. The default is xcb
  (X11; in a Wayland session, XWayland): with the native Wayland backend the
  LCL cannot place windows (the designer restores its position and centers
  its dialogs, poScreenCenter/poMainFormCenter), and it has only been tested
  headless. A value set by the user (QT_QPA_PLATFORM=wayland, or -platform)
  is kept.
  Wayland without XWayland (no DISPLAY): the native backend (qt6-wayland).
  Without DISPLAY nor WAYLAND_DISPLAY Qt would abort with a long message. }
procedure SetupQtPlatform;
var
  cl: string;
begin
  cl := LowerCase(string(CmdLine));
  if (GetEnvironmentVariable('QT_QPA_PLATFORM') <> '') or
     (Pos('-platform', cl) > 0) then
    Exit;
  // (an empty QT_QPA_PLATFORM counts as not set, as in Qt)
  if (GetEnvironmentVariable('DISPLAY') <> '') or (Pos('-display', cl) > 0) then
    setenv('QT_QPA_PLATFORM', 'xcb', 1)
  else if GetEnvironmentVariable('WAYLAND_DISPLAY') <> '' then
    setenv('QT_QPA_PLATFORM', 'wayland', 1)
  else
  begin
    WriteStd(ExtractFileName(ParamStr(0)) + ': cannot open the display ' +
      '(neither DISPLAY nor WAYLAND_DISPLAY is set). Run it from a graphical ' +
      'session, with "ssh -X" or through a remote desktop.', True);
    Halt(1);
  end;
end;
{$IFEND}

procedure HandleEarlyOptions;
var
  i: Integer;
  p: string;
begin
  for i := 1 to ParamCount do
  begin
    p := ParamStr(i);
    if (p = '--help') or (p = '-h') or (p = '-?') then
    begin
      ShowUsage;
      Halt(0);
    end;
    if (p = '--version') or (p = '-v') then
    begin
      ShowVersion;
      Halt(0);
    end;
    if p = '--check-https' then
    begin
      p := ParamStr(i + 1);
      if (p = '') or (p[1] = '-') then
        p := CHECK_HTTPS_URL;
      CheckHttps(p);
      Halt(0);
    end;
  end;
  {$IF DEFINED(UNIX) AND DEFINED(LCLGTK2)}
  // GTK2 is X11 only (XWayland sets DISPLAY too); without a display the
  // widgetset would stop the program without any message
  if (GetEnvironmentVariable('DISPLAY') = '') and
     (Pos('--display', LowerCase(CmdLine)) = 0) then
  begin
    WriteStd(ExtractFileName(ParamStr(0)) + ': cannot open the X display ' +
      '(DISPLAY is not set). Run it from a graphical session, with ' +
      '"ssh -X" or through a remote desktop.', True);
    Halt(1);
  end;
  {$IFEND}
  {$IF DEFINED(UNIX) AND DEFINED(LCLQT6)}
  SetupQtPlatform;
  {$IFEND}
end;

initialization
  HandleEarlyOptions;
end.
