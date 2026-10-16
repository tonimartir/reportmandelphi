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
  copy in the documents of the user: <Documents>/Report Manager/Samples. }

interface

{$I rpconf.inc}

uses
  Classes, SysUtils, IniFiles
{$IFDEF MSWINDOWS}
  , Windows, rpmdshfolder
{$ENDIF}
{$IFDEF FPC}
  , rpdatainfo
  {$IFDEF DARWIN}
  , rpdarwinlibs
  {$ENDIF}
{$ENDIF}
  ;

const
  RP_SAMPLES_INDEX = 'samples.ini';

type
  // A sample of the index, with its texts in the language of the user
  TRpSampleInfo = class(TObject)
  public
    FileName: string;
    Title: string;
    Description: string;
    Thumbnail: string;
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
// The samples of the index of AFolder, in its order (AList owns them)
procedure RpLoadSamples(const AFolder: string; AList: TList);
procedure RpFreeSamples(AList: TList);
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
        UpdateFolder(IncludeTrailingPathDelimiter(source), IncludeTrailingPathDelimiter(target))
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
      AList.Add(sample);
    end;
  finally
    sections.Free;
    ini.Free;
  end;
end;

end.
