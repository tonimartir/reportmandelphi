program repmandesigner_lcl;

{*******************************************************}
{                                                       }
{       Report Manager Designer - LCL                   }
{                                                       }
{       repmandesigner_lcl.lpr                          }
{       Standalone LCL designer (Linux GTK2, Windows)   }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

{ Usage: repmandesigner_lcl [--help] [--version] [--check-https [url]]
                            [report.rep]

  Uses only the reportman_rtl / reportman_lcl / reportman_designlcl
  packages (no engine search paths in the .lpi). The project lives in its
  own folder because repman\ holds old Delphi units (TmSchema.pas...) that
  FPC would take instead of the LCL ones; the executable is written to
  repman\, next to the translations and repsamples\.

  Command line, data folders and preferences file: see rmdcmdline.pas
  (listed before Interfaces so that --help/--version work without a
  display). Linux packages: build/linux (docs/linux-install.md). }

{$mode delphi}{$H+}

uses
  {$IFDEF UNIX}
  cthreads, cwstring,
  {$ENDIF}
  rmdcmdline,
  SysUtils, Classes, IniFiles, Interfaces, Forms, Controls, Dialogs,
  rpmdconsts, rpmdfmainlcl;

{$R *.res}

type
  { Writes unhandled GUI exceptions to stderr before showing them, so a
    launch from a terminal or a smoke test sees them. }
  TExceptionLogger = class
    procedure AppException(Sender: TObject; E: Exception);
  end;

  {$IFDEF DARWIN}
  { The files macOS asks the application to open: double click on a .rep
    in the Finder, dropping it on the icon of the application, Open With.
    The Info.plist of the package declares the type (make-package.sh); LCL
    Cocoa keeps the files until the application runs and gives them to
    Application.OnDropFiles. }
  TFinderOpener = class
    procedure OpenFiles(Sender: TObject; const FileNames: array of string);
  end;
  {$ENDIF}

var
  MainForm: TFRpMainFLCL;
  ExceptionLogger: TExceptionLogger;
  FileArg: string;
  {$IFDEF DARWIN}
  FinderOpener: TFinderOpener;
  {$ENDIF}

procedure TExceptionLogger.AppException(Sender: TObject; E: Exception);
begin
  WriteStd('ERROR: ' + E.ClassName + ': ' + E.Message, True);
  Application.ShowException(E);
end;

procedure LoadPreferences(AForm: TFRpMainFLCL);
var
  ini: TMemIniFile;
  l, t, w, h: Integer;
  lastdir: string;
begin
  lastdir := '';
  try
    if FileExists(ConfigFileName) then
    begin
      ini := TMemIniFile.Create(ConfigFileName);
      try
        w := ini.ReadInteger('Window', 'Width', 0);
        h := ini.ReadInteger('Window', 'Height', 0);
        if (w >= 400) and (h >= 300) then
        begin
          l := ini.ReadInteger('Window', 'Left', AForm.Left);
          t := ini.ReadInteger('Window', 'Top', AForm.Top);
          AForm.Position := poDesigned;
          AForm.SetBounds(l, t, w, h);
          AForm.MakeFullyVisible(nil, True);
          if ini.ReadBool('Window', 'Maximized', False) then
            AForm.WindowState := wsMaximized;
        end;
        lastdir := ini.ReadString('Files', 'LastDir', '');
      finally
        ini.Free;
      end;
    end;
  except
    // Corrupt or unreadable preferences never stop the designer
    on E: Exception do
      WriteStd('WARNING: preferences not loaded (' + E.Message + ')', True);
  end;
  if (lastdir = '') or not DirectoryExists(lastdir) then
    lastdir := FindSamplesDir;
  if lastdir <> '' then
  begin
    AForm.OpenDialog1.InitialDir := lastdir;
    AForm.SaveDialog1.InitialDir := lastdir;
  end;
end;

procedure SavePreferences(AForm: TFRpMainFLCL);
var
  ini: TMemIniFile;
  lastdir: string;
begin
  try
    if not ForceDirectories(UserConfigDir) then
      Exit;
    ini := TMemIniFile.Create(ConfigFileName);
    try
      ini.WriteBool('Window', 'Maximized', AForm.WindowState = wsMaximized);
      ini.WriteInteger('Window', 'Left', AForm.RestoredLeft);
      ini.WriteInteger('Window', 'Top', AForm.RestoredTop);
      ini.WriteInteger('Window', 'Width', AForm.RestoredWidth);
      ini.WriteInteger('Window', 'Height', AForm.RestoredHeight);
      lastdir := '';
      if AForm.FileName <> '' then
        lastdir := ExtractFileDir(AForm.FileName)
      else if AForm.OpenDialog1.FileName <> '' then
        lastdir := ExtractFileDir(AForm.OpenDialog1.FileName);
      if lastdir <> '' then
        ini.WriteString('Files', 'LastDir', lastdir);
      ini.UpdateFile;
    finally
      ini.Free;
    end;
  except
    on E: Exception do
      WriteStd('WARNING: preferences not saved (' + E.Message + ')', True);
  end;
end;

procedure OpenFromCommandLine(AForm: TFRpMainFLCL; const AFile: string);
var
  fname: string;
begin
  // Relative paths are relative to the working directory
  fname := ExpandFileName(AFile);
  if not FileExists(fname) then
  begin
    WriteStd('ERROR: file not found: ' + fname, True);
    MessageDlg(Application.Title, TranslateStr(731, 'Not found') + ':' +
      LineEnding + fname, mtError, [mbOK], 0);
    Exit;
  end;
  try
    AForm.OpenReportFile(fname);
    // The file dialogs start where the opened report is
    AForm.OpenDialog1.InitialDir := ExtractFileDir(fname);
    AForm.SaveDialog1.InitialDir := ExtractFileDir(fname);
  except
    on E: Exception do
    begin
      WriteStd('ERROR: cannot open ' + fname + ': ' + E.Message, True);
      MessageDlg(Application.Title, fname + LineEnding + LineEnding + E.Message,
        mtError, [mbOK], 0);
    end;
  end;
end;

{$IFDEF DARWIN}
procedure TFinderOpener.OpenFiles(Sender: TObject; const FileNames: array of string);
var
  i: Integer;
begin
  // The designer edits one report: the first .rep (OpenReportFile asks
  // first when the current one has changes)
  for i := Low(FileNames) to High(FileNames) do
    if SameText(ExtractFileExt(FileNames[i]), '.rep') then
    begin
      Application.BringToFront;
      OpenFromCommandLine(MainForm, FileNames[i]);
      Exit;
    end;
end;
{$ENDIF}

begin
  FileArg := CommandLineFile;
  // LCL texts (dialog buttons...) in the language of reportmanres.*
  TranslateLCL;
  RequireDerivedFormResource := True;
  // Translated like the VCL designer (rpgraphutilsvcl); the console
  // messages keep APP_NAME
  Application.Title := TranslateStr(1, 'Report Manager Designer');
  Application.Scaled := True;
  Application.Initialize;
  ExceptionLogger := TExceptionLogger.Create;
  try
    Application.OnException := ExceptionLogger.AppException;
    Application.CreateForm(TFRpMainFLCL, MainForm);
    LoadPreferences(MainForm);
    if FileArg <> '' then
      OpenFromCommandLine(MainForm, FileArg);
    {$IFDEF DARWIN}
    FinderOpener := TFinderOpener.Create;
    Application.AddOnDropFilesHandler(FinderOpener.OpenFiles);
    {$ENDIF}
    Application.Run;
    SavePreferences(MainForm);
  finally
    {$IFDEF DARWIN}
    if Assigned(FinderOpener) then
    begin
      Application.RemoveOnDropFilesHandler(FinderOpener.OpenFiles);
      FinderOpener.Free;
    end;
    {$ENDIF}
    Application.OnException := nil;
    ExceptionLogger.Free;
  end;
end.
