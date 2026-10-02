unit rpdarwinlibs;

{ The libraries that the engine loads on macOS (FPC, Darwin): its own ones
  (FreeType, HarfBuzz, fontconfig) and the client libraries of the database
  servers. Empty for the other targets.

  An application started from the Finder does not receive DYLD_LIBRARY_PATH,
  and the client libraries of the usual installers are not in the dyld search
  (/usr/local/lib, /usr/lib): Homebrew does not link libpq nor mysql-client
  there, and EnterpriseDB, Postgres.app, MySQL and Firebird install them in
  their own folders. They are looked for there.

  Also the language of the user: an application started from the Finder
  does not receive LANG either. }

{$mode delphi}{$H+}

interface

{$IFDEF DARWIN}
uses
  SysUtils, Classes, dynlibs, BaseUnix;

// Loads a library of the engine: first the copy in the application bundle
// (Contents/Frameworks), then the one next to the executable, then the dyld
// search (DYLD_LIBRARY_PATH, /usr/local/lib) and the Homebrew and MacPorts
// prefixes. NilHandle when no copy loads.
function RpLoadDarwinLibrary(const AName: string): TLibHandle;

// The client libraries of a kind of database server that are installed, in
// the folders of the usual installers, the newest version first:
//   pq        PostgreSQL (Homebrew, MacPorts, Postgres.app, EnterpriseDB)
//   mysql     MySQL (the MySQL package, Homebrew, MacPorts)
//   mariadb   the MariaDB client (Homebrew mariadb-connector-c)
//   fbclient  Firebird (the Firebird package)
//   odbc      unixODBC (Homebrew, MacPorts) and the iODBC of macOS
//   sqlite    the SQLite of macOS
function RpDarwinClientLibraries(const AKind: string): TStringArray;

// The folder of an OpenSSL 3 or 1.1 (libssl and libcrypto) and its version
// suffix ('.3' or '.1.1'), in this order: AFirst (the folder the application
// chose), RP_OPENSSL_DIR, the application bundle (Contents/Frameworks), the
// folder of the executable, ~/lib, Homebrew (openssl@3, openssl@1.1) and
// MacPorts. Never the OpenSSL 0.9.8 of macOS (/usr/lib): it has no
// functions to verify certificates.
function RpDarwinOpenSSL(const AFirst: string; out AFolder, AVersion: string): Boolean;

// The language of the user, as LANG writes it without the encoding ('es_ES',
// 'en_GB', 'pt_BR'): the first language of System Preferences > Language &
// Region and the country of the region when the language has none. The
// engine, the LCL and the AI language read LC_ALL, LC_MESSAGES and LANG on
// Unix, and macOS gives no LANG to the applications started from the Finder
// (Terminal does set it). '' when it is not known.
function RpDarwinUserLanguage: string;

// The folders of the data files of the application (translations...), with
// a path delimiter at the end: Contents/Resources of the application bundle
// and the folder of the executable, the real one first. Lazarus writes the
// executable next to the project and links it from X.app/Contents/MacOS,
// and ParamStr(0) is that link.
function RpDarwinDataDirs: TStringArray;

// Before loading fontconfig: when the application bundle carries its
// configuration (Contents/Resources/fonts/fonts.conf, see
// build/macos/make-package.sh) and the user did not set FONTCONFIG_FILE nor
// FONTCONFIG_PATH, that folder as FONTCONFIG_PATH. The fontconfig built by
// build-deps.sh looks for its configuration in the folder where it was built.
procedure RpDarwinPrepareFontconfig;
{$ENDIF}

implementation

{$IFDEF DARWIN}

{$linkframework CoreFoundation}

// The CoreFoundation functions that RpDarwinUserLanguage uses, declared here
// because the console programs do not link the LCL nor MacOSAll (cdecl: FPC
// adds the underscore of the C names)
const
  kCFStringEncodingUTF8 = $08000100;

function CFLocaleCopyPreferredLanguages: Pointer; cdecl; external name 'CFLocaleCopyPreferredLanguages';
function CFLocaleCopyCurrent: Pointer; cdecl; external name 'CFLocaleCopyCurrent';
function CFLocaleGetIdentifier(ALocale: Pointer): Pointer; cdecl; external name 'CFLocaleGetIdentifier';
function CFArrayGetCount(AArray: Pointer): PtrInt; cdecl; external name 'CFArrayGetCount';
function CFArrayGetValueAtIndex(AArray: Pointer; AIndex: PtrInt): Pointer; cdecl; external name 'CFArrayGetValueAtIndex';
function CFStringGetCString(AString: Pointer; ABuffer: PAnsiChar; ABufferSize: PtrInt;
  AEncoding: Cardinal): Byte; cdecl; external name 'CFStringGetCString';
procedure CFRelease(AObject: Pointer); cdecl; external name 'CFRelease';

// The environment of the C library, which fontconfig reads
function setenv(AName, AValue: PAnsiChar; AOverwrite: Integer): Integer; cdecl; external 'c' name 'setenv';

function CFStringText(AString: Pointer): string;
var
  LBuffer: array[0..255] of AnsiChar;
begin
  Result := '';
  if (AString <> nil) and (CFStringGetCString(AString, @LBuffer[0], SizeOf(LBuffer),
    kCFStringEncodingUTF8) <> 0) then
    Result := string(PAnsiChar(@LBuffer[0]));
end;

// The parts of 'es-ES', 'zh-Hans-CN' or 'es_ES@calendar=...': the language
// and, when the last part has two letters, the country
procedure SplitLanguage(const AText: string; out ALanguage, ACountry: string);
var
  LText, LLast: string;
  i: Integer;
begin
  LText := AText;
  i := Pos('@', LText);
  if i > 0 then
    SetLength(LText, i - 1);
  LText := StringReplace(LText, '-', '_', [rfReplaceAll]);
  i := Pos('_', LText);
  if i = 0 then
  begin
    ALanguage := LowerCase(LText);
    ACountry := '';
    Exit;
  end;
  ALanguage := LowerCase(Copy(LText, 1, i - 1));
  LLast := LText;
  i := LastDelimiter('_', LLast);
  LLast := Copy(LLast, i + 1, MaxInt);
  if Length(LLast) = 2 then
    ACountry := UpperCase(LLast)
  else
    ACountry := '';
end;

function RpDarwinDataDirs: TStringArray;
var
  LLinked, LPath, LTarget, LDir: string;
  i: Integer;

  procedure AddDir(const ADir: string);
  var
    j: Integer;
  begin
    for j := 0 to High(Result) do
      if Result[j] = ADir then
        Exit;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := ADir;
  end;

begin
  Result := nil;
  LLinked := ExpandFileName(ParamStr(0));
  LPath := LLinked;
  for i := 1 to 8 do
  begin
    LTarget := fpReadLink(LPath);
    if LTarget = '' then
      Break;
    if LTarget[1] <> '/' then
      LTarget := ExtractFilePath(LPath) + LTarget;
    LPath := ExpandFileName(LTarget);
  end;
  LDir := ExtractFilePath(LLinked);
  // X.app/Contents/MacOS/ -> X.app/Contents/Resources/
  if Pos('.app/Contents/MacOS/', LDir) > 0 then
    AddDir(ExpandFileName(LDir + '../Resources') + '/');
  AddDir(ExtractFilePath(LPath));
  AddDir(LDir);
end;

procedure RpDarwinPrepareFontconfig;
var
  LDir: string;
begin
  if (GetEnvironmentVariable('FONTCONFIG_FILE') <> '') or
    (GetEnvironmentVariable('FONTCONFIG_PATH') <> '') then
    Exit;
  LDir := ExtractFilePath(ExpandFileName(ParamStr(0)));
  if Pos('.app/Contents/MacOS/', LDir) = 0 then
    Exit;
  LDir := ExpandFileName(LDir + '../Resources/fonts');
  if FileExists(LDir + '/fonts.conf') then
    setenv('FONTCONFIG_PATH', PAnsiChar(AnsiString(LDir)), 1);
end;

function RpDarwinUserLanguage: string;
var
  LArray, LLocale: Pointer;
  LPreferred, LRegion, LLanguage, LCountry, LRegionLanguage, LRegionCountry: string;
begin
  Result := '';
  LPreferred := '';
  LArray := CFLocaleCopyPreferredLanguages;
  if LArray <> nil then
  try
    if CFArrayGetCount(LArray) > 0 then
      LPreferred := CFStringText(CFArrayGetValueAtIndex(LArray, 0));
  finally
    CFRelease(LArray);
  end;
  // The region (es_ES): its country completes a language without one
  LRegion := '';
  LLocale := CFLocaleCopyCurrent;
  if LLocale <> nil then
  try
    LRegion := CFStringText(CFLocaleGetIdentifier(LLocale));
  finally
    CFRelease(LLocale);
  end;
  SplitLanguage(LRegion, LRegionLanguage, LRegionCountry);
  if LPreferred <> '' then
    SplitLanguage(LPreferred, LLanguage, LCountry)
  else
  begin
    LLanguage := LRegionLanguage;
    LCountry := LRegionCountry;
  end;
  if LCountry = '' then
    LCountry := LRegionCountry;
  if (Length(LLanguage) < 2) or (Length(LLanguage) > 3) then
    Exit;
  Result := LLanguage;
  if LCountry <> '' then
    Result := Result + '_' + LCountry;
end;

function RpLoadDarwinLibrary(const AName: string): TLibHandle;
var
  LExeDir: string;
  LPaths: array[0..4] of string;
  I: Integer;
begin
  LExeDir := ExtractFilePath(ParamStr(0));
  LPaths[0] := LExeDir + '../Frameworks/' + AName;
  LPaths[1] := LExeDir + AName;
  LPaths[2] := AName;
  LPaths[3] := '/opt/homebrew/lib/' + AName;
  LPaths[4] := '/opt/local/lib/' + AName;
  Result := NilHandle;
  for I := Low(LPaths) to High(LPaths) do
  begin
    Result := SafeLoadLibrary(LPaths[I]);
    if Result <> NilHandle then
      Exit;
  end;
end;

const
  // Homebrew prefixes: Intel and Apple Silicon
  BREW_PREFIXES: array[0..1] of string = ('/usr/local', '/opt/homebrew');
  // libmysqlclient.21: MySQL 8.0, the API of the SQLdb connector
  MYSQL_NAMES: array[0..1] of string = ('libmysqlclient.21.dylib', 'libmysqlclient.dylib');

procedure AddFile(AList: TStrings; const APath: string);
begin
  if FileExists(APath) and (AList.IndexOf(APath) < 0) then
    AList.Add(APath);
end;

// The libraries of the folders of every version, the newest first:
// AFolder + APrefix + <version> + ASubPath
// (/Library/PostgreSQL/16/lib/..., /usr/local/opt/postgresql@16/lib/...)
function CompareVersions(AList: TStringList; AIndex1, AIndex2: Integer): Integer;
begin
  Result := Integer(PtrInt(AList.Objects[AIndex2])) - Integer(PtrInt(AList.Objects[AIndex1]));
end;

procedure AddVersions(AList: TStrings; const AFolder, APrefix, ASubPath: string);
var
  LDirs: TStringList;
  LRec: TSearchRec;
  LVersion: string;
  I: Integer;
begin
  LDirs := TStringList.Create;
  try
    if FindFirst(AFolder + APrefix + '*', faDirectory, LRec) = 0 then
    try
      repeat
        if (LRec.Name <> '.') and (LRec.Name <> '..') and
          ((LRec.Attr and faDirectory) <> 0) then
        begin
          // The major version: the digits after the prefix
          LVersion := Copy(LRec.Name, Length(APrefix) + 1, MaxInt);
          I := 1;
          while (I <= Length(LVersion)) and (LVersion[I] in ['0'..'9']) do
            Inc(I);
          LDirs.AddObject(LRec.Name, TObject(PtrInt(StrToIntDef(Copy(LVersion, 1, I - 1), 0))));
        end;
      until FindNext(LRec) <> 0;
    finally
      FindClose(LRec);
    end;
    LDirs.CustomSort(CompareVersions);
    for I := 0 to LDirs.Count - 1 do
      AddFile(AList, AFolder + LDirs[I] + ASubPath);
  finally
    LDirs.Free;
  end;
end;

function RpDarwinClientLibraries(const AKind: string): TStringArray;
var
  LList: TStringList;
  LBrew, LName: string;
  I: Integer;
begin
  LList := TStringList.Create;
  try
    if AKind = 'pq' then
    begin
      for LBrew in BREW_PREFIXES do
      begin
        AddFile(LList, LBrew + '/opt/libpq/lib/libpq.5.dylib');
        AddFile(LList, LBrew + '/lib/libpq.5.dylib');
        AddVersions(LList, LBrew + '/opt/', 'postgresql@', '/lib/libpq.5.dylib');
        AddVersions(LList, LBrew + '/opt/', 'postgresql@', '/lib/postgresql/libpq.5.dylib');
      end;
      AddFile(LList, '/Applications/Postgres.app/Contents/Versions/latest/lib/libpq.5.dylib');
      AddVersions(LList, '/Library/PostgreSQL/', '', '/lib/libpq.5.dylib');
      AddVersions(LList, '/opt/local/lib/', 'postgresql', '/libpq.5.dylib');
    end
    else if AKind = 'mysql' then
    begin
      for LName in MYSQL_NAMES do
      begin
        AddFile(LList, '/usr/local/mysql/lib/' + LName);
        for LBrew in BREW_PREFIXES do
        begin
          AddFile(LList, LBrew + '/opt/mysql-client/lib/' + LName);
          AddVersions(LList, LBrew + '/opt/', 'mysql-client@', '/lib/' + LName);
          AddFile(LList, LBrew + '/opt/mysql/lib/' + LName);
          AddVersions(LList, LBrew + '/opt/', 'mysql@', '/lib/' + LName);
          AddFile(LList, LBrew + '/lib/' + LName);
        end;
        AddVersions(LList, '/opt/local/lib/', 'mysql', '/mysql/' + LName);
      end;
    end
    else if AKind = 'mariadb' then
    begin
      for LBrew in BREW_PREFIXES do
      begin
        AddFile(LList, LBrew + '/opt/mariadb-connector-c/lib/mariadb/libmariadb.3.dylib');
        AddFile(LList, LBrew + '/lib/mariadb/libmariadb.3.dylib');
        AddFile(LList, LBrew + '/opt/mariadb/lib/libmariadb.3.dylib');
      end;
    end
    else if AKind = 'fbclient' then
    begin
      AddFile(LList, '/Library/Frameworks/Firebird.framework/Versions/A/Libraries/libfbclient.dylib');
      AddFile(LList, '/Library/Frameworks/Firebird.framework/Libraries/libfbclient.dylib');
      // Firebird 2.5: the framework is the client library
      AddFile(LList, '/Library/Frameworks/Firebird.framework/Firebird');
    end
    else if AKind = 'odbc' then
    begin
      for LBrew in BREW_PREFIXES do
        AddFile(LList, LBrew + '/lib/libodbc.2.dylib');
      AddFile(LList, '/opt/local/lib/libodbc.2.dylib');
      // The system libraries are in the dyld cache, not on the disk
      LList.Add('/usr/lib/libiodbc.2.dylib');
    end
    else if AKind = 'sqlite' then
      LList.Add('/usr/lib/libsqlite3.dylib');
    SetLength(Result, LList.Count);
    for I := 0 to LList.Count - 1 do
      Result[I] := LList[I];
  finally
    LList.Free;
  end;
end;

function RpDarwinOpenSSL(const AFirst: string; out AFolder, AVersion: string): Boolean;
const
  VERSIONS: array[0..1] of string = ('.3', '.1.1');
var
  LDirs: TStringList;
  LExeDir, LDir, LBrew, LVersion: string;
  I: Integer;
begin
  Result := False;
  AFolder := '';
  AVersion := '';
  LExeDir := ExtractFilePath(ParamStr(0));
  LDirs := TStringList.Create;
  try
    if AFirst <> '' then
      LDirs.Add(AFirst);
    if GetEnvironmentVariable('RP_OPENSSL_DIR') <> '' then
      LDirs.Add(GetEnvironmentVariable('RP_OPENSSL_DIR'));
    LDirs.Add(LExeDir + '../Frameworks');
    LDirs.Add(LExeDir);
    LDirs.Add(GetEnvironmentVariable('HOME') + '/lib');
    for LBrew in BREW_PREFIXES do
    begin
      LDirs.Add(LBrew + '/opt/openssl@3/lib');
      LDirs.Add(LBrew + '/opt/openssl@1.1/lib');
      LDirs.Add(LBrew + '/lib');
    end;
    LDirs.Add('/opt/local/lib');
    for I := 0 to LDirs.Count - 1 do
    begin
      LDir := IncludeTrailingPathDelimiter(ExpandFileName(LDirs[I]));
      for LVersion in VERSIONS do
        if FileExists(LDir + 'libssl' + LVersion + '.dylib') and
          FileExists(LDir + 'libcrypto' + LVersion + '.dylib') then
        begin
          AFolder := LDir;
          AVersion := LVersion;
          Exit(True);
        end;
    end;
  finally
    LDirs.Free;
  end;
end;

{$ENDIF}

end.
