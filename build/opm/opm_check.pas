{ opm_check: comprueba los artefactos OPM de Report Manager con el mismo codigo
  que usa el Online Package Manager de Lazarus (fpjson, fpjsonrtti, zipper,
  md5), sin necesitar el IDE.

  Reproduce, simplificado, lo que hace components/onlinepackagemanager:
    - opkman_serializablepackages.JSONToPackages: lee la lista de paquetes
      (PackageDataN / PackageFilesN), con VarToDateTime de RepositoryDate y la
      conversion '\/' -> PathDelim de PackageBaseDir y RelativeFilePath.
    - opkman_updates.TUpdatePackage.LoadFromJSON: lee el JSON de updates con
      TJSONDeStreamer.
    - opkman_zipper.TPackageUnzipper: calcula IsDirZipped/ZippedBaseDir y
      descomprime con TUnZipper.
    - IsPackageExtracted / IsPackageDownloaded: comprueba tamano, MD5 y que
      cada .lpk quede en <destino><PackageBaseDir><RelativeFilePath><Name>.

  Uso: opm_check <lista.json> <update.json> <paquete.zip> <dir_destino>
  Codigo de salida 0 si todo cuadra, 1 si hay algun error. }
program opm_check;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Variants, fpjson, jsonparser, fpjsonrtti, zipper, md5;

type
  TUpdateLazPackages = class(TCollectionItem)
  private
    FName: String;
    FVersion: String;
    FForceNotify: Boolean;
    FInternalVersion: Integer;
  published
    property Name: String read FName write FName;
    property Version: String read FVersion write FVersion;
    property ForceNotify: Boolean read FForceNotify write FForceNotify;
    property InternalVersion: Integer read FInternalVersion write FInternalVersion;
  end;

  TUpdatePackageData = class(TPersistent)
  private
    FDownloadZipURL: String;
    FDisableInOPM: Boolean;
    FName: String;
  published
    property Name: String read FName write FName;
    property DownloadZipURL: String read FDownloadZipURL write FDownloadZipURL;
    property DisableInOPM: Boolean read FDisableInOPM write FDisableInOPM;
  end;

  TUpdatePackage = class(TPersistent)
  private
    FUpdatePackageData: TUpdatePackageData;
    FUpdateLazPackages: TCollection;
  public
    constructor Create;
    destructor Destroy; override;
  published
    property UpdatePackageData: TUpdatePackageData read FUpdatePackageData write FUpdatePackageData;
    property UpdateLazPackages: TCollection read FUpdateLazPackages write FUpdateLazPackages;
  end;

constructor TUpdatePackage.Create;
begin
  FUpdatePackageData := TUpdatePackageData.Create;
  FUpdateLazPackages := TCollection.Create(TUpdateLazPackages);
end;

destructor TUpdatePackage.Destroy;
begin
  FUpdatePackageData.Free;
  FUpdateLazPackages.Free;
  inherited Destroy;
end;

var
  Errors: Integer = 0;

procedure Fail(const AMsg: String);
begin
  WriteLn('ERROR: ', AMsg);
  Inc(Errors);
end;

function ReadFileAsString(const AFileName: String): String;
var
  SS: TStringStream;
begin
  SS := TStringStream.Create('');
  try
    SS.LoadFromFile(AFileName);
    Result := SS.DataString;
  finally
    SS.Free;
  end;
end;

function FromJSONPath(const S: String): String;
begin
  // opkman_serializablepackages: StringReplace(..., '\/', PathDelim, [rfReplaceAll])
  Result := StringReplace(S, '\/', PathDelim, [rfReplaceAll]);
end;

var
  ListFile, UpdateFile, ZipFile, DestDir: String;
  Data: TJSONData;
  Obj: TJSONObject;
  Arr: TJSONArray;
  I, J, PkgCount: Integer;
  PackageBaseDir, RepoFileName, RepoHash, S: String;
  RepoSize: Int64;
  RepoDate: TDateTime;
  PkgNames, PkgPaths, PkgVersions: TStringList;
  Upd: TUpdatePackage;
  DeStreamer: TJSONDeStreamer;
  UnZipper: TUnZipper;
  BaseDir: String;
  IsDirZipped: Boolean;
  P: Integer;
  ULP: TUpdateLazPackages;
begin
  if ParamCount <> 4 then
  begin
    WriteLn('Uso: opm_check <lista.json> <update.json> <paquete.zip> <dir_destino>');
    Halt(2);
  end;
  ListFile := ParamStr(1);
  UpdateFile := ParamStr(2);
  ZipFile := ParamStr(3);
  DestDir := IncludeTrailingPathDelimiter(ParamStr(4));

  PkgNames := TStringList.Create;
  PkgPaths := TStringList.Create;
  PkgVersions := TStringList.Create;
  PkgCount := 0;
  PackageBaseDir := '';
  RepoFileName := '';
  RepoHash := '';
  RepoSize := 0;

  { 1. Lista de paquetes (JSONToPackages / JSONToPackageData / JSONToLazarusPackages) }
  try
    Data := GetJSON(ReadFileAsString(ListFile));
    try
      if Data.JSONType <> jtObject then
        Fail('la lista de paquetes no es un objeto JSON')
      else
        for I := 0 to Data.Count - 1 do
        begin
          if Data.Items[I].JSONType = jtObject then
          begin
            Inc(PkgCount);
            Obj := TJSONObject(Data.Items[I]);
            // Mismo orden y mismas conversiones Variant que JSONToPackageData
            S := Obj.Get('Name');
            WriteLn('Name              : ', S);
            S := Obj.Get('DisplayName');
            WriteLn('DisplayName       : ', S);
            S := Obj.Get('Category');
            WriteLn('Category          : ', S);
            S := Obj.Get('CommunityDescription');
            S := Obj.Get('ExternalDependecies');
            J := Obj.Get('OrphanedPackage');
            RepoFileName := Obj.Get('RepositoryFileName');
            RepoSize := Obj.Get('RepositoryFileSize');
            RepoHash := Obj.Get('RepositoryFileHash');
            RepoDate := VarToDateTime(Obj.Get('RepositoryDate'));
            PackageBaseDir := Obj.Get('PackageBaseDir');
            if PackageBaseDir <> '' then
              PackageBaseDir := FromJSONPath(PackageBaseDir);
            S := Obj.Get('HomePageURL');
            WriteLn('HomePageURL       : ', S);
            S := Obj.Get('DownloadURL');
            WriteLn('DownloadURL (upd) : ', S);
            S := Obj.Get('SVNURL');
            WriteLn('SVNURL            : ', S);
            WriteLn('RepositoryFile    : ', RepoFileName, ' (', RepoSize, ' bytes, md5 ', RepoHash, ')');
            WriteLn('RepositoryDate    : ', FormatDateTime('yyyy-mm-dd hh:nn:ss', RepoDate));
            WriteLn('PackageBaseDir    : ', PackageBaseDir);
          end
          else if Data.Items[I].JSONType = jtArray then
          begin
            Arr := TJSONArray(Data.Items[I]);
            for J := 0 to Arr.Count - 1 do
            begin
              Obj := TJSONObject(Arr.Items[J]);
              S := Obj.Get('Name');
              PkgNames.Add(S);
              S := Obj.Get('Description');
              S := Obj.Get('Author');
              S := Obj.Get('License');
              S := Obj.Get('RelativeFilePath');
              if S <> '' then
                S := FromJSONPath(S);
              PkgPaths.Add(S);
              S := Obj.Get('VersionAsString');
              PkgVersions.Add(S);
              S := Obj.Get('LazCompatibility');
              S := Obj.Get('FPCCompatibility');
              S := Obj.Get('SupportedWidgetSet');
              P := Obj.Get('PackageType');
              S := Obj.Get('DependenciesAsString');
              WriteLn('  ', PkgNames[J], ' ', PkgVersions[J], ' en ', PkgPaths[J],
                ' tipo=', P, ' deps=', S);
            end;
          end;
        end;
    finally
      Data.Free;
    end;
  except
    on E: Exception do
      Fail('lista de paquetes: ' + E.ClassName + ': ' + E.Message);
  end;
  if PkgCount <> 1 then
    Fail('se esperaba exactamente 1 PackageData en la lista, hay ' + IntToStr(PkgCount));
  if PkgNames.Count = 0 then
    Fail('la lista no contiene ningun .lpk');

  { 2. JSON de updates (TUpdatePackage.LoadFromJSON) }
  Upd := TUpdatePackage.Create;
  DeStreamer := TJSONDeStreamer.Create(nil);
  try
    try
      S := ReadFileAsString(UpdateFile);
      S := StringReplace(S, 'UpdatePackageFiles', 'UpdateLazPackages', [rfReplaceAll, rfIgnoreCase]);
      DeStreamer.JSONToObject(S, Upd);
      WriteLn('Update JSON       : Name=', Upd.UpdatePackageData.Name,
        ' DisableInOPM=', Upd.UpdatePackageData.DisableInOPM);
      WriteLn('  DownloadZipURL  : ', Upd.UpdatePackageData.DownloadZipURL);
      if Pos('.zip', LowerCase(Upd.UpdatePackageData.DownloadZipURL)) = 0 then
        Fail('DownloadZipURL no apunta a un .zip');
      if Upd.UpdateLazPackages.Count <> PkgNames.Count then
        Fail('el JSON de updates tiene ' + IntToStr(Upd.UpdateLazPackages.Count) +
          ' paquetes y la lista ' + IntToStr(PkgNames.Count));
      for I := 0 to Upd.UpdateLazPackages.Count - 1 do
      begin
        ULP := TUpdateLazPackages(Upd.UpdateLazPackages.Items[I]);
        WriteLn('  ', ULP.Name, ' ', ULP.Version, ' ForceNotify=', ULP.ForceNotify,
          ' InternalVersion=', ULP.InternalVersion);
        J := PkgNames.IndexOf(ULP.Name);
        if J < 0 then
          Fail('update JSON: ' + ULP.Name + ' no esta en la lista de paquetes')
        else if PkgVersions[J] <> ULP.Version then
          Fail('update JSON: version de ' + ULP.Name + ' = ' + ULP.Version +
            ', en la lista = ' + PkgVersions[J]);
      end;
    except
      on E: Exception do
        Fail('JSON de updates: ' + E.ClassName + ': ' + E.Message);
    end;
  finally
    DeStreamer.Free;
    Upd.Free;
  end;

  { 3. Zip: tamano y MD5 (IsPackageDownloaded / CreateJSON) }
  if not FileExists(ZipFile) then
    Fail('no existe ' + ZipFile)
  else
  begin
    if ExtractFileName(ZipFile) <> RepoFileName then
      Fail('RepositoryFileName=' + RepoFileName + ' pero el zip es ' + ExtractFileName(ZipFile));
    with TFileStream.Create(ZipFile, fmOpenRead or fmShareDenyNone) do
    try
      if Size <> RepoSize then
        Fail('RepositoryFileSize=' + IntToStr(RepoSize) + ' pero el zip mide ' + IntToStr(Size));
    finally
      Free;
    end;
    S := MD5Print(MD5File(ZipFile));
    if S <> RepoHash then
      Fail('RepositoryFileHash=' + RepoHash + ' pero MD5 del zip=' + S);

    { 4. Descompresion como TPackageUnzipper }
    UnZipper := TUnZipper.Create;
    try
      try
        UnZipper.FileName := ZipFile;
        UnZipper.Examine;
        IsDirZipped := True;
        BaseDir := '';
        if UnZipper.Entries.Count > 0 then
        begin
          S := UnZipper.Entries[0].ArchiveFileName;
          P := Pos('/', S);
          if P = 0 then
            P := Pos('\', S);
          if P <> 0 then
            BaseDir := Copy(S, 1, P);
        end;
        for I := 0 to UnZipper.Entries.Count - 1 do
          if Pos(BaseDir, UnZipper.Entries[I].ArchiveFileName) = 0 then
            IsDirZipped := False;
        if not IsDirZipped then
          BaseDir := ''
        else
          SetLength(BaseDir, Length(BaseDir) - 1);
        WriteLn('Zip               : ', UnZipper.Entries.Count, ' entradas, IsDirZipped=',
          IsDirZipped, ', ZippedBaseDir=', BaseDir);
        if not IsDirZipped then
          Fail('el zip no tiene una unica carpeta raiz');
        if IncludeTrailingPathDelimiter(BaseDir) <> PackageBaseDir then
          WriteLn('AVISO: ZippedBaseDir (', BaseDir, ') <> PackageBaseDir (', PackageBaseDir,
            '); OPM copiara el arbol');
        ForceDirectories(DestDir);
        UnZipper.OutputPath := DestDir;
        UnZipper.UnZipAllFiles;
      except
        on E: Exception do
          Fail('descomprimiendo: ' + E.ClassName + ': ' + E.Message);
      end;
    finally
      UnZipper.Free;
    end;

    { 5. IsPackageExtracted }
    for I := 0 to PkgNames.Count - 1 do
    begin
      S := DestDir + PackageBaseDir + PkgPaths[I] + PkgNames[I];
      if FileExists(S) then
        WriteLn('OK  ', S)
      else
        Fail('no se encuentra ' + S);
    end;
  end;

  PkgNames.Free;
  PkgPaths.Free;
  PkgVersions.Free;
  if Errors = 0 then
  begin
    WriteLn('opm_check: OK');
    Halt(0);
  end
  else
  begin
    WriteLn('opm_check: ', Errors, ' error(es)');
    Halt(1);
  end;
end.
