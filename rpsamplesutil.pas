{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpsamplesutil                                   }
{                                                       }
{       The sample reports of the designers: where      }
{       they are installed, their index and the working }
{       copy in the documents of the user               }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpsamplesutil;

{ The samples folder (samples/ of the repository, made by build/samples) is
  the same for every designer: the Delphi VCL designer, the Lazarus designer
  and the .NET designer (Reportman.Designer/WelcomeForm.cs, which does the
  same as this unit). It holds the reports, samples.db (SQLite) and
  samples.ini, the index the welcome window lists:

    [fishes.rep]
    Title=Fishes (classic)
    Title.es=Peces (clasico)
    Description=...
    Description.es=...
    Thumbnail=thumbnails/fishes.png

  The installed folder may be read only (Program Files, /opt, an application
  bundle that a change would break), so a sample is opened from a working
  copy in the documents of the user: <Documents>/Report Manager/Samples.

  dbxschemas/SAMPLES.json is the local schema of the connection of the
  samples for the AI copilot, made with the local schema editor: it goes to
  the dbxschemas folder next to the connections file of the computer
  (RpInstallSamplesSchema), not to the working copy. }

interface

{$I rpconf.inc}

uses
  Classes, SysUtils, IniFiles, rpdatainfo, rplocalschemas
{$IFDEF MSWINDOWS}
  , Windows, rpmdshfolder
{$ENDIF}
{$IFDEF FPC}
  {$IFDEF DARWIN}
  , rpdarwinlibs
  {$ENDIF}
{$ENDIF}
  ;

const
  RP_SAMPLES_INDEX = 'samples.ini';
  // The connection alias of the sample reports and the folder of its local
  // schema (dbxschemas/<ALIAS>.json, as next to the connections file)
  RP_SAMPLES_ALIAS = 'SAMPLES';
  RP_SAMPLES_SCHEMAS = 'dbxschemas';

type
  // A sample of the index, with its texts in the language of the user
  TRpSampleInfo = class(TObject)
  public
    FileName: string;
    Title: string;
    Description: string;
    Thumbnail: string;
    // A request to the copilot that changes the dataset and the report of
    // the sample, checked with the AI (English, the Prompt key of the index)
    Prompt: string;
  end;

// The installed samples folder, with the path delimiter: the samples
// folder of the application (RpSamplesFolder, set by the Lazarus designer),
// samples next to the program, in the bundle of macOS, or, in a development
// tree, the first samples folder with an index above the program. '' when
// there is none.
function RpInstalledSamplesFolder: string;
// <Documents>/Report Manager/Samples, with the path delimiter
function RpSamplesWorkingFolder: string;
// Copies the installed samples to the working folder: the files that are
// not there yet, and the database, the index and the pictures when the
// installed ones are newer. A report already there is never replaced: the
// user may have changed it.
procedure RpUpdateSamplesWorkingCopy(const AInstalled, AWorking: string);
// The local schema of the samples (dbxschemas/SAMPLES.json of the installed
// samples) into the dbxschemas folder next to the connections file of this
// computer, where the copilot and the local schema editor look for it, when
// it is not there yet: a new installation asks the copilot for a report on
// the samples at once. An existing file is never replaced (the user may have
// changed it): only a subschema of an older version that the user did not
// change is brought up to date. The file installed, or '' when nothing was
// copied.
function RpInstallSamplesSchema(const AInstalled: string): string;
// The samples of the index of AFolder, in its order (AList owns them)
procedure RpLoadSamples(const AFolder: string; AList: TList);
procedure RpFreeSamples(AList: TList);
// The Prompt of a sample report of the index of its folder (the welcome
// window writes it in the copilot when it opens the sample); '' when the
// report is not a sample or has none
function RpSamplePrompt(const AReportFile: string): string;
// Two letter code of the language of the user (es, ca, de...): the texts
// of the index in that language, as the translations of the designer
function RpSamplesLanguage: string;

implementation

function SamplesFolderOf(const ADir: string): string;
begin
  Result := '';
  if ADir = '' then
    Exit;
  if FileExists(IncludeTrailingPathDelimiter(ADir) + RP_SAMPLES_INDEX) then
    Result := IncludeTrailingPathDelimiter(ADir);
end;

function RpInstalledSamplesFolder: string;
var
  dir, parent: string;
  level: Integer;
{$IFDEF FPC}
{$IFDEF DARWIN}
  dirs: TStringArray;
  i: Integer;
{$ENDIF}
{$ENDIF}
begin
{$IFDEF FPC}
  Result := SamplesFolderOf(RpSamplesFolder);
  if Result <> '' then
    Exit;
{$IFDEF DARWIN}
  dirs := RpDarwinDataDirs;
  for i := 0 to High(dirs) do
  begin
    Result := SamplesFolderOf(IncludeTrailingPathDelimiter(dirs[i]) + 'samples');
    if Result <> '' then
      Exit;
  end;
{$ENDIF}
{$ENDIF}
  dir := ExcludeTrailingPathDelimiter(ExtractFilePath(ExpandFileName(ParamStr(0))));
  for level := 0 to 6 do
  begin
    Result := SamplesFolderOf(IncludeTrailingPathDelimiter(dir) + 'samples');
    if Result <> '' then
      Exit;
    parent := ExcludeTrailingPathDelimiter(ExtractFilePath(dir));
    if (parent = '') or (parent = dir) then
      Break;
    dir := parent;
  end;
  Result := '';
end;

{$IFNDEF MSWINDOWS}
// XDG_DOCUMENTS_DIR of ~/.config/user-dirs.dirs (a localized name, such as
// ~/Documentos), else ~/Documents
function UnixDocumentsFolder: string;
var
  home, line, value: string;
  lines: TStringList;
  i: Integer;
begin
  home := GetEnvironmentVariable('HOME');
  Result := IncludeTrailingPathDelimiter(home) + 'Documents';
{$IFNDEF DARWIN}
  lines := TStringList.Create;
  try
    if FileExists(home + '/.config/user-dirs.dirs') then
      lines.LoadFromFile(home + '/.config/user-dirs.dirs');
    for i := 0 to lines.Count - 1 do
    begin
      line := Trim(lines[i]);
      if Copy(line, 1, 18) = 'XDG_DOCUMENTS_DIR=' then
      begin
        value := Copy(line, 19, Length(line));
        if (Length(value) > 1) and (value[1] = '"') then
          value := Copy(value, 2, Length(value) - 2);
        value := StringReplace(value, '$HOME', home, []);
        if (value <> '') and (value <> home) and (value <> home + '/') then
          Result := value;
      end;
    end;
  finally
    lines.Free;
  end;
{$ENDIF}
  if not DirectoryExists(Result) then
    Result := home;
end;
{$ENDIF}

function RpSamplesWorkingFolder: string;
{$IFDEF MSWINDOWS}
const
  CSIDL_PERSONAL = $0005;
var
  buffer: array[0..MAX_PATH] of WideChar;
{$ENDIF}
begin
  Result := '';
{$IFDEF MSWINDOWS}
  if Assigned(SHGetFolderPathW) and
    (SHGetFolderPathW(0, CSIDL_PERSONAL, 0, 0, buffer) = S_OK) then
    Result := string(WideString(PWideChar(@buffer[0])));
  if Result = '' then
    Result := GetEnvironmentVariable('USERPROFILE');
{$ELSE}
  Result := UnixDocumentsFolder;
{$ENDIF}
  Result := IncludeTrailingPathDelimiter(Result) + 'Report Manager' + PathDelim +
    'Samples' + PathDelim;
end;

function FileTime(const AFileName: string): TDateTime;
begin
  if not FileAge(AFileName, Result) then
    Result := 0;
end;

procedure CopyFileTo(const ASource, ATarget: string);
var
  source, target: TFileStream;
begin
  source := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    target := TFileStream.Create(ATarget, fmCreate);
    try
      target.CopyFrom(source, 0);
    finally
      target.Free;
    end;
  finally
    source.Free;
  end;
  // The date of the installed file: a newer installation is told by it
  FileSetDate(ATarget, DateTimeToFileDate(FileTime(ASource)));
end;

procedure UpdateFolder(const ASource, ATarget: string);
var
  search: TSearchRec;
  source, target: string;
  docopy: Boolean;
begin
  ForceDirectories(ATarget);
  if FindFirst(ASource + '*', faAnyFile, search) <> 0 then
    Exit;
  try
    repeat
      if (search.Name = '.') or (search.Name = '..') then
        Continue;
      source := ASource + search.Name;
      target := ATarget + search.Name;
      if (search.Attr and faDirectory) <> 0 then
      begin
        // The local schema goes next to the connections file
        // (RpInstallSamplesSchema), not to the documents
        if not SameText(search.Name, RP_SAMPLES_SCHEMAS) then
          UpdateFolder(IncludeTrailingPathDelimiter(source), IncludeTrailingPathDelimiter(target));
      end
      else
      begin
        docopy := not FileExists(target);
        if (not docopy) and (not SameText(ExtractFileExt(search.Name), '.rep')) then
          docopy := FileTime(source) > FileTime(target) + 1 / (24 * 3600);
        if docopy then
          CopyFileTo(source, target);
      end;
    until FindNext(search) <> 0;
  finally
    SysUtils.FindClose(search);
  end;
end;

procedure RpUpdateSamplesWorkingCopy(const AInstalled, AWorking: string);
begin
  UpdateFolder(IncludeTrailingPathDelimiter(AInstalled), IncludeTrailingPathDelimiter(AWorking));
end;

// The subschema Fishes of the samples of 4.0.22 left the picture GRAPHIC
// out, and the AI then dropped it from the dataset of fishes.rep when it
// changed it (the report did not print any more). The file of an existing
// installation gets it while that subschema is still the one shipped: its
// description and its columns as they were
procedure UpgradeSamplesSchema(const AFileName: string);
const
  COldFishes = 'The classic fishes sample, without the pictures.';
  CNewFishes = 'The classic fishes sample; GRAPHIC is the picture of each ' +
    'fish, printed by the report.';
var
  LFile: TRpLocalSchemaFile;
  LColumns: TStringList;
  I: Integer;
  LSchema: TRpLocalSubSchema;
begin
  LFile := TRpLocalSchemaFile.Create;
  LColumns := TStringList.Create;
  try
    if not LFile.LoadFromFile(AFileName) then
      Exit;
    for I := 0 to LFile.SchemaCount - 1 do
    begin
      LSchema := LFile.Schemas[I];
      if (not SameText(LSchema.Name, 'Fishes')) or
        (LSchema.Description <> COldFishes) then
        Continue;
      if not LSchema.GetColumns('FISHES', LColumns) then
        Continue;
      if LColumns.IndexOf('GRAPHIC') >= 0 then
        Continue;
      LColumns.Add('GRAPHIC');
      LSchema.SetColumns('FISHES', LColumns);
      LSchema.Description := CNewFishes;
      LFile.SaveToFile(AFileName);
      Exit;
    end;
  finally
    LColumns.Free;
    LFile.Free;
  end;
end;

function RpInstallSamplesSchema(const AInstalled: string): string;
var
  LAdmin: TRpConnAdmin;
  LSource, LTarget: string;
begin
  Result := '';
  if AInstalled = '' then
    Exit;
  LSource := IncludeTrailingPathDelimiter(AInstalled) + RP_SAMPLES_SCHEMAS +
    PathDelim + RP_SAMPLES_ALIAS + '.json';
  if not FileExists(LSource) then
    Exit;
  try
    // The folder RpLocalSchemaFileName uses: that of the connections file
    LAdmin := TRpConnAdmin.Create;
    try
      LTarget := ExtractFilePath(ExpandFileName(LAdmin.configfilename));
    finally
      LAdmin.Free;
    end;
    LTarget := IncludeTrailingPathDelimiter(LTarget + RP_SAMPLES_SCHEMAS) +
      RP_SAMPLES_ALIAS + '.json';
    if FileExists(LTarget) then
    begin
      UpgradeSamplesSchema(LTarget);
      Exit;
    end;
    ForceDirectories(ExtractFilePath(LTarget));
    CopyFileTo(LSource, LTarget);
    if FileExists(LTarget) then
      Result := LTarget;
  except
    // A folder that can not be written: the copilot asks for a subschema,
    // as without the file
    Result := '';
  end;
end;

function RpSamplesLanguage: string;
{$IFDEF MSWINDOWS}
var
  buffer: array[0..9] of Char;
begin
  Result := '';
  if GetLocaleInfo(GetThreadLocale, LOCALE_SISO639LANGNAME, buffer, Length(buffer)) > 0 then
    Result := LowerCase(string(PChar(@buffer[0])));
end;
{$ELSE}
var
  lang: string;
begin
  // The order of the translations (rptranslator): LC_ALL, LC_MESSAGES, LANG
  lang := GetEnvironmentVariable('LC_ALL');
  if lang = '' then
    lang := GetEnvironmentVariable('LC_MESSAGES');
  if lang = '' then
    lang := GetEnvironmentVariable('LANG');
{$IFDEF FPC}
{$IFDEF DARWIN}
  if lang = '' then
    lang := RpDarwinUserLanguage;
{$ENDIF}
{$ENDIF}
  Result := LowerCase(Copy(lang, 1, 2));
end;
{$ENDIF}

procedure RpFreeSamples(AList: TList);
var
  i: Integer;
begin
  for i := 0 to AList.Count - 1 do
    TObject(AList[i]).Free;
  AList.Clear;
end;

function RpSamplePrompt(const AReportFile: string): string;
var
  ini: TMemIniFile;
  index: string;
begin
  Result := '';
  if AReportFile = '' then
    Exit;
  index := ExtractFilePath(ExpandFileName(AReportFile)) + RP_SAMPLES_INDEX;
  if not FileExists(index) then
    Exit;
{$IFDEF FPC}
  ini := TMemIniFile.Create(index);
{$ELSE}
  ini := TMemIniFile.Create(index, TEncoding.UTF8);
{$ENDIF}
  try
    Result := Trim(ini.ReadString(ExtractFileName(AReportFile), 'Prompt', ''));
  finally
    ini.Free;
  end;
end;

procedure RpLoadSamples(const AFolder: string; AList: TList);
var
  ini: TMemIniFile;
  sections: TStringList;
  sample: TRpSampleInfo;
  lang, folder: string;
  i: Integer;

  function Localized(const ASection, AKey, ADefault: string): string;
  begin
    Result := '';
    if lang <> '' then
      Result := ini.ReadString(ASection, AKey + '.' + lang, '');
    if Result = '' then
      Result := ini.ReadString(ASection, AKey, ADefault);
  end;

begin
  folder := IncludeTrailingPathDelimiter(AFolder);
  if not FileExists(folder + RP_SAMPLES_INDEX) then
    Exit;
  lang := RpSamplesLanguage;
{$IFDEF FPC}
  // UTF-8, as the strings of the LCL
  ini := TMemIniFile.Create(folder + RP_SAMPLES_INDEX);
{$ELSE}
  ini := TMemIniFile.Create(folder + RP_SAMPLES_INDEX, TEncoding.UTF8);
{$ENDIF}
  sections := TStringList.Create;
  try
    // The sections in the order of the file
    ini.ReadSections(sections);
    for i := 0 to sections.Count - 1 do
    begin
      if not FileExists(folder + sections[i]) then
        Continue;
      sample := TRpSampleInfo.Create;
      sample.FileName := sections[i];
      sample.Title := Localized(sections[i], 'Title', ChangeFileExt(sections[i], ''));
      sample.Description := Localized(sections[i], 'Description', '');
      sample.Thumbnail := StringReplace(ini.ReadString(sections[i], 'Thumbnail', ''),
        '/', PathDelim, [rfReplaceAll]);
      sample.Prompt := ini.ReadString(sections[i], 'Prompt', '');
      AList.Add(sample);
    end;
  finally
    sections.Free;
    ini.Free;
  end;
end;

end.
