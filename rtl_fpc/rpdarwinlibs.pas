unit rpdarwinlibs;

{ The libraries that the engine loads on macOS (FPC, Darwin): its own ones
  (FreeType, HarfBuzz, fontconfig) and the client libraries of the database
  servers. Empty for the other targets.

  An application started from the Finder does not receive DYLD_LIBRARY_PATH,
  and the client libraries of the usual installers are not in the dyld search
  (/usr/local/lib, /usr/lib): Homebrew does not link libpq nor mysql-client
  there, and EnterpriseDB, Postgres.app, MySQL and Firebird install them in
  their own folders. They are looked for there. }

{$mode delphi}{$H+}

interface

{$IFDEF DARWIN}
uses
  SysUtils, Classes, dynlibs;

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
{$ENDIF}

implementation

{$IFDEF DARWIN}

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

{$ENDIF}

end.
