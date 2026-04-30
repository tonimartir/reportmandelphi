unit rpwebserverconfigadmin;

{$I rpconf.inc}

interface

uses
  Classes, SysUtils, IniFiles, Generics.Collections, rpmdshfolder, rpdatainfo;

function ResolveReportmanServerConfigFileName(
  const AConfigOverride: string = ''): string;

type
  TRpWebServerConfigFormData = record
    PagesDir: string;
    TcpPort: string;
    LogFile: string;
    LogJson: Boolean;
    UserAccess: Boolean;
    ApiKeyAccess: Boolean;
    ShowUnauthorizedPage: Boolean;
    UrlGetParams: Boolean;
  end;

  TRpWebServerUser = record
    UserName: string;
    PasswordMasked: string;
    IsAdmin: Boolean;
    Groups: TStringList;
    class function Create: TRpWebServerUser; static;
    procedure Clear;
  end;

  TRpWebServerGroup = record
    GroupName: string;
    Description: string;
  end;

  TRpWebServerAlias = record
    AliasName: string;
    TargetValue: string;
    IsConnectionAlias: Boolean;
    AllowedGroups: TStringList;
    class function Create: TRpWebServerAlias; static;
    procedure Clear;
  end;

  TRpWebServerApiKey = record
    KeyName: string;
    SecretMasked: string;
    SecretPlainText: string;
    UserName: string;
  end;

  TRpWebServerConfigInfo = record
    ConfigFileName: string;
    DBXConnectionsFileName: string;
    BootstrapRequired: Boolean;
    HasAdminUser: Boolean;
    UsersCount: Integer;
    GroupsCount: Integer;
    AliasesCount: Integer;
    ApiKeysCount: Integer;
  end;

  TRpWebBootstrapRequest = record
    UserName: string;
    Password: string;
    ConfirmPassword: string;
  end;

  TRpWebUserEditRequest = record
    OriginalUserName: string;
    UserName: string;
    Password: string;
    ConfirmPassword: string;
    ChangePassword: Boolean;
    IsAdmin: Boolean;
    Groups: TStringList;
    class function Create: TRpWebUserEditRequest; static;
    procedure Clear;
  end;

  TRpWebGroupEditRequest = record
    OriginalGroupName: string;
    GroupName: string;
    Description: string;
  end;

  TRpWebAliasType = (
    watFolder,
    watConnection
  );

  TRpWebAliasEditRequest = record
    OriginalAliasName: string;
    AliasName: string;
    AliasType: TRpWebAliasType;
    TargetValue: string;
    AllowedGroups: TStringList;
    class function Create: TRpWebAliasEditRequest; static;
    procedure Clear;
  end;

  TRpWebApiKeyCreateRequest = record
    KeyName: string;
    UserName: string;
  end;

  TRpWebGeneratedApiKeyResult = record
    KeyName: string;
    SecretPlainText: string;
    UserName: string;
  end;

  TRpWebServerConfigAdminService = class
  private
    FConfigOverride: string;
    function LoadIni: TMemIniFile;
    function NormalizeName(const AValue: string): string;
    function BoolToIni(const AValue: Boolean): string;
    function MaskSecret(const ASecret: string): string;
    procedure LoadUserGroups(AIni: TMemIniFile; const AUserName: string;
      AGroups: TStrings);
    procedure LoadAliasGroups(AIni: TMemIniFile; const AAliasName: string;
      AGroups: TStrings);
    procedure SaveSectionNameList(AIni: TMemIniFile; const ASection: string;
      AValues: TStrings);
    procedure ValidatePasswordPair(const APassword, AConfirmPassword: string);
    procedure EnsureUserExists(AIni: TMemIniFile; const AUserName: string);
    function GenerateApiSecret: string;
  public
    constructor Create(const AConfigOverride: string = '');

    function GetConfigFileName: string;
    function GetConfigInfo: TRpWebServerConfigInfo;
    function BootstrapRequired: Boolean;
    procedure BootstrapFirstAdmin(const ABootstrap: TRpWebBootstrapRequest);

    function LoadServerConfigFormData: TRpWebServerConfigFormData;
    procedure SaveServerConfigFormData(const AData: TRpWebServerConfigFormData);

    procedure ListUsers(AUsers: TList<TRpWebServerUser>);
    procedure GetUser(const AUserName: string; out AUser: TRpWebServerUser);
    function LoadUserEditRequest(const AUserName: string): TRpWebUserEditRequest;
    procedure SaveUserEditRequest(const ARequest: TRpWebUserEditRequest;
      const AIsNew: Boolean);
    procedure DeleteUser(const AUserName: string);
    function CanDeleteUser(const AUserName: string; out AReason: string): Boolean;

    procedure ListGroups(AGroups: TList<TRpWebServerGroup>);
    function LoadGroupEditRequest(const AGroupName: string): TRpWebGroupEditRequest;
    procedure SaveGroupEditRequest(const ARequest: TRpWebGroupEditRequest;
      const AIsNew: Boolean);
    procedure DeleteGroup(const AGroupName: string);

    procedure ListAliases(AAliases: TList<TRpWebServerAlias>);
    function LoadAliasEditRequest(const AAliasName: string): TRpWebAliasEditRequest;
    procedure SaveAliasEditRequest(const ARequest: TRpWebAliasEditRequest;
      const AIsNew: Boolean);
    procedure DeleteAlias(const AAliasName: string);
    function ValidateAliasTarget(const AAliasType: TRpWebAliasType;
      const ATargetValue: string): string;

    procedure ListApiKeys(AKeys: TList<TRpWebServerApiKey>);
    function SaveApiKeyCreateRequest(
      const ARequest: TRpWebApiKeyCreateRequest): TRpWebGeneratedApiKeyResult;
    procedure DeleteApiKey(const AKeyName: string);
    function IsLastAdmin(const AUserName: string): Boolean;
  end;

implementation

procedure CopyFileSimple(const ASourceFileName, ADestFileName: string);
var
  LSource: TFileStream;
  LDest: TFileStream;
begin
  LSource := TFileStream.Create(ASourceFileName, fmOpenRead or fmShareDenyWrite);
  try
    ForceDirectories(ExtractFilePath(ADestFileName));
    LDest := TFileStream.Create(ADestFileName, fmCreate);
    try
      LDest.CopyFrom(LSource, 0);
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
end;

function CanWriteToPath(const AFileName: string): Boolean;
var
  LDir: string;
  LProbeFileName: string;
  LStream: TFileStream;
  LExisting: Boolean;
  LGuid: TGUID;
begin
  Result := False;
  LExisting := FileExists(AFileName);
  if LExisting then
  begin
    try
      LStream := TFileStream.Create(AFileName, fmOpenReadWrite or fmShareDenyNone);
      try
        Result := True;
      finally
        LStream.Free;
      end;
    except
      Result := False;
    end;
    Exit;
  end;

  LDir := ExtractFilePath(AFileName);
  if Length(Trim(LDir)) = 0 then
    LDir := '.' + PathDelim;
  try
    ForceDirectories(LDir);
    if CreateGUID(LGuid) <> 0 then
      raise Exception.Create('Could not create temporary file name');
    LProbeFileName := IncludeTrailingPathDelimiter(LDir) +
      '.rpweb-write-test-' + GUIDToString(LGuid) + '.tmp';
    LStream := TFileStream.Create(LProbeFileName, fmCreate);
    try
      Result := True;
    finally
      LStream.Free;
      DeleteFile(LProbeFileName);
    end;
  except
    Result := False;
  end;
end;

function ResolveReportmanServerConfigFileName(
  const AConfigOverride: string): string;
var
  LCommonFileName: string;
  LLocalFileName: string;
begin
  if Length(Trim(AConfigOverride)) > 0 then
    Exit(Trim(AConfigOverride));

  LCommonFileName := Obtainininamecommonconfig('', '', 'reportmanserver');
  LLocalFileName := Obtainininamelocalconfig('', '', 'reportmanserver');

{$IFDEF LINUX}
  if FileExists(LLocalFileName) then
    Exit(LLocalFileName);

  if FileExists(LCommonFileName) then
  begin
    CopyFileSimple(LCommonFileName, LLocalFileName);
    Exit(LLocalFileName);
  end;

  ForceDirectories(ExtractFilePath(LLocalFileName));
  Exit(LLocalFileName);
{$ENDIF}

  if CanWriteToPath(LCommonFileName) then
    Exit(LCommonFileName);

  if FileExists(LLocalFileName) or CanWriteToPath(LLocalFileName) then
    Exit(LLocalFileName);

  Result := LCommonFileName;
end;

function NormalizeSectionKeyValues(AIni: TMemIniFile; const ASection: string): TStringList;
begin
  Result := TStringList.Create;
  AIni.ReadSectionValues(ASection, Result);
end;

{ TRpWebServerUser }

class function TRpWebServerUser.Create: TRpWebServerUser;
begin
  Result.UserName := '';
  Result.PasswordMasked := '';
  Result.IsAdmin := False;
  Result.Groups := TStringList.Create;
end;

procedure TRpWebServerUser.Clear;
begin
  Groups.Free;
  Groups := nil;
  UserName := '';
  PasswordMasked := '';
  IsAdmin := False;
end;

{ TRpWebServerAlias }

class function TRpWebServerAlias.Create: TRpWebServerAlias;
begin
  Result.AliasName := '';
  Result.TargetValue := '';
  Result.IsConnectionAlias := False;
  Result.AllowedGroups := TStringList.Create;
end;

procedure TRpWebServerAlias.Clear;
begin
  AllowedGroups.Free;
  AllowedGroups := nil;
  AliasName := '';
  TargetValue := '';
  IsConnectionAlias := False;
end;

{ TRpWebUserEditRequest }

class function TRpWebUserEditRequest.Create: TRpWebUserEditRequest;
begin
  Result.OriginalUserName := '';
  Result.UserName := '';
  Result.Password := '';
  Result.ConfirmPassword := '';
  Result.ChangePassword := True;
  Result.IsAdmin := False;
  Result.Groups := TStringList.Create;
end;

procedure TRpWebUserEditRequest.Clear;
begin
  Groups.Free;
  Groups := nil;
  OriginalUserName := '';
  UserName := '';
  Password := '';
  ConfirmPassword := '';
  ChangePassword := False;
  IsAdmin := False;
end;

{ TRpWebAliasEditRequest }

class function TRpWebAliasEditRequest.Create: TRpWebAliasEditRequest;
begin
  Result.OriginalAliasName := '';
  Result.AliasName := '';
  Result.AliasType := watFolder;
  Result.TargetValue := '';
  Result.AllowedGroups := TStringList.Create;
end;

procedure TRpWebAliasEditRequest.Clear;
begin
  AllowedGroups.Free;
  AllowedGroups := nil;
  OriginalAliasName := '';
  AliasName := '';
  AliasType := watFolder;
  TargetValue := '';
end;

{ TRpWebServerConfigAdminService }

constructor TRpWebServerConfigAdminService.Create(const AConfigOverride: string);
begin
  inherited Create;
  FConfigOverride := AConfigOverride;
end;

function TRpWebServerConfigAdminService.LoadIni: TMemIniFile;
var
  LFileName: string;
begin
  LFileName := GetConfigFileName;
  ForceDirectories(ExtractFilePath(LFileName));
  Result := TMemIniFile.Create(LFileName);
{$IFDEF USEVARIANTS}
  Result.CaseSensitive := False;
{$ENDIF}
end;

function TRpWebServerConfigAdminService.NormalizeName(const AValue: string): string;
begin
  Result := UpperCase(Trim(AValue));
end;

function TRpWebServerConfigAdminService.BoolToIni(const AValue: Boolean): string;
begin
  if AValue then
    Result := '1'
  else
    Result := '0';
end;

function TRpWebServerConfigAdminService.MaskSecret(const ASecret: string): string;
begin
  if Length(ASecret) < 1 then
    Exit('');
  if Length(ASecret) <= 4 then
    Exit('****');
  Result := '****' + Copy(ASecret, Length(ASecret) - 3, 4);
end;

procedure TRpWebServerConfigAdminService.LoadUserGroups(AIni: TMemIniFile;
  const AUserName: string; AGroups: TStrings);
begin
  AGroups.Clear;
  if SameText(AUserName, 'ADMIN') then
    Exit;
  AIni.ReadSectionValues('USERGROUPS' + NormalizeName(AUserName), AGroups);
end;

procedure TRpWebServerConfigAdminService.LoadAliasGroups(AIni: TMemIniFile;
  const AAliasName: string; AGroups: TStrings);
begin
  AGroups.Clear;
  AIni.ReadSectionValues('GROUPALLOW' + NormalizeName(AAliasName), AGroups);
end;

procedure TRpWebServerConfigAdminService.SaveSectionNameList(AIni: TMemIniFile;
  const ASection: string; AValues: TStrings);
var
  I: Integer;
  LName: string;
begin
  AIni.EraseSection(ASection);
  for I := 0 to AValues.Count - 1 do
  begin
    LName := NormalizeName(AValues.Names[I]);
    if Length(LName) = 0 then
      LName := NormalizeName(AValues[I]);
    if Length(LName) > 0 then
      AIni.WriteString(ASection, LName, '');
  end;
end;

procedure TRpWebServerConfigAdminService.ValidatePasswordPair(const APassword,
  AConfirmPassword: string);
begin
  if Length(APassword) < 1 then
    raise Exception.Create('Password is required');
  if APassword <> AConfirmPassword then
    raise Exception.Create('Passwords do not match');
end;

procedure TRpWebServerConfigAdminService.EnsureUserExists(AIni: TMemIniFile;
  const AUserName: string);
var
  LUsers: TStringList;
begin
  LUsers := NormalizeSectionKeyValues(AIni, 'USERS');
  try
    if LUsers.IndexOfName(NormalizeName(AUserName)) < 0 then
      raise Exception.Create('User not found: ' + AUserName);
  finally
    LUsers.Free;
  end;
end;

function TRpWebServerConfigAdminService.GenerateApiSecret: string;
var
  LGuid: TGUID;
begin
  if CreateGUID(LGuid) <> 0 then
    raise Exception.Create('Could not generate API key secret');
  Result := GUIDToString(LGuid);
  Result := StringReplace(Result, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
end;

function TRpWebServerConfigAdminService.GetConfigFileName: string;
begin
  Result := ResolveReportmanServerConfigFileName(FConfigOverride);
end;

function TRpWebServerConfigAdminService.GetConfigInfo: TRpWebServerConfigInfo;
var
  LIni: TMemIniFile;
  LConnAdmin: TRpConnAdmin;
  LUsers, LGroups, LAliases, LApiKeys: TStringList;
begin
  Result.ConfigFileName := GetConfigFileName;
  LConnAdmin := TRpConnAdmin.Create;
  try
    Result.DBXConnectionsFileName := LConnAdmin.configfilename;
  finally
    LConnAdmin.Free;
  end;
  Result.BootstrapRequired := BootstrapRequired;
  Result.HasAdminUser := not Result.BootstrapRequired;
  LIni := LoadIni;
  try
    LUsers := NormalizeSectionKeyValues(LIni, 'USERS');
    LGroups := NormalizeSectionKeyValues(LIni, 'GROUPS');
    LAliases := NormalizeSectionKeyValues(LIni, 'ALIASES');
    LApiKeys := NormalizeSectionKeyValues(LIni, 'SERVERAPIKEYS');
    try
      if LUsers.IndexOfName('ADMIN') < 0 then
        LUsers.Add('ADMIN=');
      Result.UsersCount := LUsers.Count;
      Result.GroupsCount := LGroups.Count;
      Result.AliasesCount := LAliases.Count;
      Result.ApiKeysCount := LApiKeys.Count;
    finally
      LUsers.Free;
      LGroups.Free;
      LAliases.Free;
      LApiKeys.Free;
    end;
  finally
    LIni.Free;
  end;
end;

function TRpWebServerConfigAdminService.BootstrapRequired: Boolean;
var
  LIni: TMemIniFile;
begin
  LIni := LoadIni;
  try
    Result := Length(Trim(LIni.ReadString('USERS', 'ADMIN', ''))) = 0;
  finally
    LIni.Free;
  end;
end;

procedure TRpWebServerConfigAdminService.BootstrapFirstAdmin(
  const ABootstrap: TRpWebBootstrapRequest);
var
  LIni: TMemIniFile;
  LUserName: string;
begin
  if not BootstrapRequired then
    raise Exception.Create('Bootstrap is not allowed after ADMIN is configured');
  LUserName := NormalizeName(ABootstrap.UserName);
  if (Length(LUserName) > 0) and (LUserName <> 'ADMIN') then
    raise Exception.Create('Current server model only supports ADMIN as the first admin');
  ValidatePasswordPair(ABootstrap.Password, ABootstrap.ConfirmPassword);
  LIni := LoadIni;
  try
    LIni.WriteString('USERS', 'ADMIN', ABootstrap.Password);
    if Length(Trim(LIni.ReadString('SECURITY', 'USER_ACCESS', ''))) = 0 then
      LIni.WriteString('SECURITY', 'USER_ACCESS', '1');
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

function TRpWebServerConfigAdminService.LoadServerConfigFormData: TRpWebServerConfigFormData;
var
  LIni: TMemIniFile;
begin
  LIni := LoadIni;
  try
    Result.PagesDir := Trim(LIni.ReadString('CONFIG', 'PAGESDIR', ''));
    Result.TcpPort := Trim(LIni.ReadString('CONFIG', 'TCPPORT', '3060'));
    Result.LogFile := Trim(LIni.ReadString('CONFIG', 'LOGFILE', ''));
    Result.LogJson := Trim(LIni.ReadString('CONFIG', 'LOG_JSON', '1')) <> '0';
    Result.UserAccess := Trim(LIni.ReadString('SECURITY', 'USER_ACCESS', '1')) <> '0';
    Result.ApiKeyAccess := Trim(LIni.ReadString('SECURITY', 'API_KEY_ACCESS', '1')) <> '0';
    Result.ShowUnauthorizedPage := Trim(LIni.ReadString('SECURITY', 'SHOWUNAUTHORIZEDPAGE', '1')) <> '0';
    Result.UrlGetParams := Trim(LIni.ReadString('SECURITY', 'URLGETPARAMS', '0')) <> '0';
  finally
    LIni.Free;
  end;
end;

procedure TRpWebServerConfigAdminService.SaveServerConfigFormData(
  const AData: TRpWebServerConfigFormData);
var
  LIni: TMemIniFile;
begin
  if (Length(Trim(AData.TcpPort)) > 0) and (StrToIntDef(Trim(AData.TcpPort), -1) < 0) then
    raise Exception.Create('TCPPORT must be a valid integer');
  LIni := LoadIni;
  try
    LIni.WriteString('CONFIG', 'PAGESDIR', Trim(AData.PagesDir));
    LIni.WriteString('CONFIG', 'TCPPORT', Trim(AData.TcpPort));
    LIni.WriteString('CONFIG', 'LOGFILE', Trim(AData.LogFile));
    LIni.WriteString('CONFIG', 'LOG_JSON', BoolToIni(AData.LogJson));
    LIni.WriteString('SECURITY', 'USER_ACCESS', BoolToIni(AData.UserAccess));
    LIni.WriteString('SECURITY', 'API_KEY_ACCESS', BoolToIni(AData.ApiKeyAccess));
    LIni.WriteString('SECURITY', 'SHOWUNAUTHORIZEDPAGE', BoolToIni(AData.ShowUnauthorizedPage));
    LIni.DeleteKey('SECURITY', 'REQUIRE_HTTPS');
    LIni.WriteString('SECURITY', 'URLGETPARAMS', BoolToIni(AData.UrlGetParams));
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

procedure TRpWebServerConfigAdminService.ListUsers(AUsers: TList<TRpWebServerUser>);
var
  LIni: TMemIniFile;
  LUsers: TStringList;
  LUser: TRpWebServerUser;
  I: Integer;
  LName: string;
begin
  LIni := LoadIni;
  try
    LUsers := NormalizeSectionKeyValues(LIni, 'USERS');
    try
      if LUsers.IndexOfName('ADMIN') < 0 then
        LUsers.Add('ADMIN=');
      for I := 0 to LUsers.Count - 1 do
      begin
        LName := NormalizeName(LUsers.Names[I]);
        if Length(LName) = 0 then
          Continue;
        LUser := TRpWebServerUser.Create;
        LUser.UserName := LName;
        LUser.PasswordMasked := MaskSecret(LUsers.ValueFromIndex[I]);
        LUser.IsAdmin := SameText(LName, 'ADMIN');
        LoadUserGroups(LIni, LName, LUser.Groups);
        AUsers.Add(LUser);
      end;
    finally
      LUsers.Free;
    end;
  finally
    LIni.Free;
  end;
end;

procedure TRpWebServerConfigAdminService.GetUser(const AUserName: string;
  out AUser: TRpWebServerUser);
var
  LIni: TMemIniFile;
  LName: string;
  LPassword: string;
begin
  AUser := TRpWebServerUser.Create;
  LIni := LoadIni;
  try
    LName := NormalizeName(AUserName);
    LPassword := LIni.ReadString('USERS', LName, #0);
    if LPassword = #0 then
      raise Exception.Create('User not found: ' + AUserName);
    AUser.UserName := LName;
    AUser.PasswordMasked := MaskSecret(LPassword);
    AUser.IsAdmin := SameText(LName, 'ADMIN');
    LoadUserGroups(LIni, LName, AUser.Groups);
  finally
    LIni.Free;
  end;
end;

function TRpWebServerConfigAdminService.LoadUserEditRequest(
  const AUserName: string): TRpWebUserEditRequest;
var
  LUser: TRpWebServerUser;
begin
  Result := TRpWebUserEditRequest.Create;
  GetUser(AUserName, LUser);
  try
    Result.OriginalUserName := LUser.UserName;
    Result.UserName := LUser.UserName;
    Result.IsAdmin := LUser.IsAdmin;
    Result.ChangePassword := False;
    Result.Groups.Assign(LUser.Groups);
  finally
    LUser.Clear;
  end;
end;

procedure TRpWebServerConfigAdminService.SaveUserEditRequest(
  const ARequest: TRpWebUserEditRequest; const AIsNew: Boolean);
var
  LIni: TMemIniFile;
  LOriginalName: string;
  LNewName: string;
  LApiKeys: TStringList;
  I: Integer;
begin
  LOriginalName := NormalizeName(ARequest.OriginalUserName);
  LNewName := NormalizeName(ARequest.UserName);
  if Length(LNewName) < 1 then
    raise Exception.Create('User name is required');
  if ARequest.IsAdmin and (LNewName <> 'ADMIN') then
    raise Exception.Create('Current server model only supports ADMIN as admin');
  if (LNewName = 'ADMIN') and (not ARequest.IsAdmin) then
    raise Exception.Create('ADMIN cannot lose admin privileges');
  if AIsNew or ARequest.ChangePassword or SameText(LNewName, 'ADMIN') and BootstrapRequired then
    ValidatePasswordPair(ARequest.Password, ARequest.ConfirmPassword);

  LIni := LoadIni;
  try
    if AIsNew then
    begin
      if LIni.ReadString('USERS', LNewName, #0) <> #0 then
        raise Exception.Create('User already exists: ' + LNewName);
    end
    else
    begin
      EnsureUserExists(LIni, LOriginalName);
      if (LOriginalName <> LNewName) and (LIni.ReadString('USERS', LNewName, #0) <> #0) then
        raise Exception.Create('User already exists: ' + LNewName);
    end;

    if not AIsNew and (LOriginalName <> LNewName) then
    begin
      if SameText(LOriginalName, 'ADMIN') then
        raise Exception.Create('ADMIN cannot be renamed');
      LIni.WriteString('USERS', LNewName, LIni.ReadString('USERS', LOriginalName, ''));
      LIni.DeleteKey('USERS', LOriginalName);
      SaveSectionNameList(LIni, 'USERGROUPS' + LNewName, ARequest.Groups);
      LIni.EraseSection('USERGROUPS' + LOriginalName);
      LApiKeys := NormalizeSectionKeyValues(LIni, 'SERVERAPIKEYUSERS');
      try
        for I := 0 to LApiKeys.Count - 1 do
        begin
          if SameText(NormalizeName(LApiKeys.ValueFromIndex[I]), LOriginalName) then
            LIni.WriteString('SERVERAPIKEYUSERS', LApiKeys.Names[I], LNewName);
        end;
      finally
        LApiKeys.Free;
      end;
    end;

    if AIsNew or (LOriginalName = LNewName) then
    begin
      if AIsNew or ARequest.ChangePassword then
        LIni.WriteString('USERS', LNewName, ARequest.Password)
      else if LIni.ReadString('USERS', LNewName, #0) = #0 then
        LIni.WriteString('USERS', LNewName, '');
    end;

    if not SameText(LNewName, 'ADMIN') then
      SaveSectionNameList(LIni, 'USERGROUPS' + LNewName, ARequest.Groups)
    else
      LIni.EraseSection('USERGROUPSADMIN');
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

procedure TRpWebServerConfigAdminService.DeleteUser(const AUserName: string);
var
  LIni: TMemIniFile;
  LName: string;
  LKeys: TStringList;
  I: Integer;
  LApiKeyName: string;
begin
  LName := NormalizeName(AUserName);
  if SameText(LName, 'ADMIN') then
    raise Exception.Create('ADMIN cannot be deleted');
  LIni := LoadIni;
  try
    LIni.DeleteKey('USERS', LName);
    LIni.EraseSection('USERGROUPS' + LName);
    LKeys := NormalizeSectionKeyValues(LIni, 'SERVERAPIKEYUSERS');
    try
      for I := LKeys.Count - 1 downto 0 do
      begin
        if SameText(NormalizeName(LKeys.ValueFromIndex[I]), LName) then
        begin
          LApiKeyName := LKeys.Names[I];
          LIni.DeleteKey('SERVERAPIKEYUSERS', LApiKeyName);
          LIni.DeleteKey('SERVERAPIKEYS', LApiKeyName);
        end;
      end;
    finally
      LKeys.Free;
    end;
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

function TRpWebServerConfigAdminService.CanDeleteUser(const AUserName: string;
  out AReason: string): Boolean;
begin
  Result := False;
  AReason := '';
  if SameText(NormalizeName(AUserName), 'ADMIN') then
  begin
    AReason := 'ADMIN cannot be deleted';
    Exit;
  end;
  Result := True;
end;

procedure TRpWebServerConfigAdminService.ListGroups(AGroups: TList<TRpWebServerGroup>);
var
  LIni: TMemIniFile;
  LValues: TStringList;
  I: Integer;
  LGroup: TRpWebServerGroup;
begin
  LIni := LoadIni;
  try
    LValues := NormalizeSectionKeyValues(LIni, 'GROUPS');
    try
      for I := 0 to LValues.Count - 1 do
      begin
        if Length(Trim(LValues.Names[I])) = 0 then
          Continue;
        LGroup.GroupName := NormalizeName(LValues.Names[I]);
        LGroup.Description := LValues.ValueFromIndex[I];
        AGroups.Add(LGroup);
      end;
    finally
      LValues.Free;
    end;
  finally
    LIni.Free;
  end;
end;

function TRpWebServerConfigAdminService.LoadGroupEditRequest(
  const AGroupName: string): TRpWebGroupEditRequest;
var
  LIni: TMemIniFile;
  LName: string;
  LValue: string;
begin
  LIni := LoadIni;
  try
    LName := NormalizeName(AGroupName);
    LValue := LIni.ReadString('GROUPS', LName, #0);
    if LValue = #0 then
      raise Exception.Create('Group not found: ' + AGroupName);
    Result.OriginalGroupName := LName;
    Result.GroupName := LName;
    Result.Description := LValue;
  finally
    LIni.Free;
  end;
end;

procedure TRpWebServerConfigAdminService.SaveGroupEditRequest(
  const ARequest: TRpWebGroupEditRequest; const AIsNew: Boolean);
var
  LIni: TMemIniFile;
  LOriginalName: string;
  LNewName: string;
  LUsers, LAliases: TStringList;
  LGroups: TStringList;
  I: Integer;
begin
  LOriginalName := NormalizeName(ARequest.OriginalGroupName);
  LNewName := NormalizeName(ARequest.GroupName);
  if Length(LNewName) < 1 then
    raise Exception.Create('Group name is required');
  LIni := LoadIni;
  try
    if AIsNew then
    begin
      if LIni.ReadString('GROUPS', LNewName, #0) <> #0 then
        raise Exception.Create('Group already exists: ' + LNewName);
    end
    else
    begin
      if LIni.ReadString('GROUPS', LOriginalName, #0) = #0 then
        raise Exception.Create('Group not found: ' + LOriginalName);
      if (LOriginalName <> LNewName) and (LIni.ReadString('GROUPS', LNewName, #0) <> #0) then
        raise Exception.Create('Group already exists: ' + LNewName);
    end;

    LIni.WriteString('GROUPS', LNewName, Trim(ARequest.Description));
    if (not AIsNew) and (LOriginalName <> LNewName) then
    begin
      LIni.DeleteKey('GROUPS', LOriginalName);
      LUsers := NormalizeSectionKeyValues(LIni, 'USERS');
      LAliases := NormalizeSectionKeyValues(LIni, 'ALIASES');
      try
        for I := 0 to LUsers.Count - 1 do
        begin
          if SameText(NormalizeName(LUsers.Names[I]), 'ADMIN') then
            Continue;
          LGroups := NormalizeSectionKeyValues(LIni, 'USERGROUPS' + NormalizeName(LUsers.Names[I]));
          try
            if LGroups.IndexOfName(LOriginalName) >= 0 then
            begin
              LGroups.Delete(LGroups.IndexOfName(LOriginalName));
              LGroups.Add(LNewName + '=');
              SaveSectionNameList(LIni, 'USERGROUPS' + NormalizeName(LUsers.Names[I]), LGroups);
            end;
          finally
            LGroups.Free;
          end;
        end;

        for I := 0 to LAliases.Count - 1 do
        begin
          LGroups := NormalizeSectionKeyValues(LIni, 'GROUPALLOW' + NormalizeName(LAliases.Names[I]));
          try
            if LGroups.IndexOfName(LOriginalName) >= 0 then
            begin
              LGroups.Delete(LGroups.IndexOfName(LOriginalName));
              LGroups.Add(LNewName + '=');
              SaveSectionNameList(LIni, 'GROUPALLOW' + NormalizeName(LAliases.Names[I]), LGroups);
            end;
          finally
            LGroups.Free;
          end;
        end;
      finally
        LUsers.Free;
        LAliases.Free;
      end;
    end;
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

procedure TRpWebServerConfigAdminService.DeleteGroup(const AGroupName: string);
var
  LIni: TMemIniFile;
  LUsers, LAliases, LGroups: TStringList;
  I: Integer;
  LName: string;
begin
  LName := NormalizeName(AGroupName);
  LIni := LoadIni;
  try
    LIni.DeleteKey('GROUPS', LName);
    LUsers := NormalizeSectionKeyValues(LIni, 'USERS');
    LAliases := NormalizeSectionKeyValues(LIni, 'ALIASES');
    try
      for I := 0 to LUsers.Count - 1 do
      begin
        if SameText(NormalizeName(LUsers.Names[I]), 'ADMIN') then
          Continue;
        LGroups := NormalizeSectionKeyValues(LIni, 'USERGROUPS' + NormalizeName(LUsers.Names[I]));
        try
          if LGroups.IndexOfName(LName) >= 0 then
          begin
            LGroups.Delete(LGroups.IndexOfName(LName));
            SaveSectionNameList(LIni, 'USERGROUPS' + NormalizeName(LUsers.Names[I]), LGroups);
          end;
        finally
          LGroups.Free;
        end;
      end;
      for I := 0 to LAliases.Count - 1 do
      begin
        LGroups := NormalizeSectionKeyValues(LIni, 'GROUPALLOW' + NormalizeName(LAliases.Names[I]));
        try
          if LGroups.IndexOfName(LName) >= 0 then
          begin
            LGroups.Delete(LGroups.IndexOfName(LName));
            SaveSectionNameList(LIni, 'GROUPALLOW' + NormalizeName(LAliases.Names[I]), LGroups);
          end;
        finally
          LGroups.Free;
        end;
      end;
    finally
      LUsers.Free;
      LAliases.Free;
    end;
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

procedure TRpWebServerConfigAdminService.ListAliases(AAliases: TList<TRpWebServerAlias>);
var
  LIni: TMemIniFile;
  LValues: TStringList;
  I: Integer;
  LAlias: TRpWebServerAlias;
begin
  LIni := LoadIni;
  try
    LValues := NormalizeSectionKeyValues(LIni, 'ALIASES');
    try
      for I := 0 to LValues.Count - 1 do
      begin
        if Length(Trim(LValues.Names[I])) = 0 then
          Continue;
        LAlias := TRpWebServerAlias.Create;
        LAlias.AliasName := NormalizeName(LValues.Names[I]);
        LAlias.TargetValue := Trim(LValues.ValueFromIndex[I]);
        LAlias.IsConnectionAlias := (Length(LAlias.TargetValue) > 0) and (LAlias.TargetValue[1] = ':');
        LoadAliasGroups(LIni, LAlias.AliasName, LAlias.AllowedGroups);
        AAliases.Add(LAlias);
      end;
    finally
      LValues.Free;
    end;
  finally
    LIni.Free;
  end;
end;

function TRpWebServerConfigAdminService.LoadAliasEditRequest(
  const AAliasName: string): TRpWebAliasEditRequest;
var
  LIni: TMemIniFile;
  LName: string;
  LValue: string;
begin
  Result := TRpWebAliasEditRequest.Create;
  LIni := LoadIni;
  try
    LName := NormalizeName(AAliasName);
    LValue := LIni.ReadString('ALIASES', LName, #0);
    if LValue = #0 then
      raise Exception.Create('Alias not found: ' + AAliasName);
    Result.OriginalAliasName := LName;
    Result.AliasName := LName;
    Result.TargetValue := Trim(LValue);
    if (Length(Result.TargetValue) > 0) and (Result.TargetValue[1] = ':') then
      Result.AliasType := watConnection
    else
      Result.AliasType := watFolder;
    LoadAliasGroups(LIni, LName, Result.AllowedGroups);
  finally
    LIni.Free;
  end;
end;

function TRpWebServerConfigAdminService.ValidateAliasTarget(
  const AAliasType: TRpWebAliasType; const ATargetValue: string): string;
var
  LValue: string;
begin
  Result := '';
  LValue := Trim(ATargetValue);
  if Length(LValue) < 1 then
    Exit('Alias target is required');
  if AAliasType = watConnection then
  begin
    if LValue[1] <> ':' then
      Exit('Connection aliases must start with :');
    Exit('');
  end;
end;

procedure TRpWebServerConfigAdminService.SaveAliasEditRequest(
  const ARequest: TRpWebAliasEditRequest; const AIsNew: Boolean);
var
  LIni: TMemIniFile;
  LOriginalName: string;
  LNewName: string;
  LTargetValue: string;
  LValidationError: string;
  LGroups: TStringList;
begin
  LOriginalName := NormalizeName(ARequest.OriginalAliasName);
  LNewName := NormalizeName(ARequest.AliasName);
  if Length(LNewName) < 1 then
    raise Exception.Create('Alias name is required');
  LTargetValue := Trim(ARequest.TargetValue);
  LValidationError := ValidateAliasTarget(ARequest.AliasType, LTargetValue);
  if Length(LValidationError) > 0 then
    raise Exception.Create(LValidationError);
  if ARequest.AliasType = watConnection then
    LTargetValue := ':' + StringReplace(Copy(LTargetValue, 2, Length(LTargetValue)), ':', '', [rfReplaceAll]);

  LIni := LoadIni;
  try
    if AIsNew then
    begin
      if LIni.ReadString('ALIASES', LNewName, #0) <> #0 then
        raise Exception.Create('Alias already exists: ' + LNewName);
    end
    else
    begin
      if LIni.ReadString('ALIASES', LOriginalName, #0) = #0 then
        raise Exception.Create('Alias not found: ' + LOriginalName);
      if (LOriginalName <> LNewName) and (LIni.ReadString('ALIASES', LNewName, #0) <> #0) then
        raise Exception.Create('Alias already exists: ' + LNewName);
    end;
    LIni.WriteString('ALIASES', LNewName, LTargetValue);
    SaveSectionNameList(LIni, 'GROUPALLOW' + LNewName, ARequest.AllowedGroups);
    if (not AIsNew) and (LOriginalName <> LNewName) then
    begin
      LIni.DeleteKey('ALIASES', LOriginalName);
      LGroups := NormalizeSectionKeyValues(LIni, 'GROUPALLOW' + LOriginalName);
      try
        SaveSectionNameList(LIni, 'GROUPALLOW' + LNewName, LGroups);
      finally
        LGroups.Free;
      end;
      LIni.EraseSection('GROUPALLOW' + LOriginalName);
    end;
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

procedure TRpWebServerConfigAdminService.DeleteAlias(const AAliasName: string);
var
  LIni: TMemIniFile;
  LName: string;
begin
  LName := NormalizeName(AAliasName);
  LIni := LoadIni;
  try
    LIni.DeleteKey('ALIASES', LName);
    LIni.EraseSection('GROUPALLOW' + LName);
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

procedure TRpWebServerConfigAdminService.ListApiKeys(AKeys: TList<TRpWebServerApiKey>);
var
  LIni: TMemIniFile;
  LValues, LUsers: TStringList;
  I: Integer;
  LKey: TRpWebServerApiKey;
begin
  LIni := LoadIni;
  try
    LValues := NormalizeSectionKeyValues(LIni, 'SERVERAPIKEYS');
    LUsers := NormalizeSectionKeyValues(LIni, 'SERVERAPIKEYUSERS');
    try
      for I := 0 to LValues.Count - 1 do
      begin
        if Length(Trim(LValues.Names[I])) = 0 then
          Continue;
        LKey.KeyName := NormalizeName(LValues.Names[I]);
        LKey.SecretMasked := MaskSecret(LValues.ValueFromIndex[I]);
        LKey.SecretPlainText := LValues.ValueFromIndex[I];
        LKey.UserName := NormalizeName(LUsers.Values[LKey.KeyName]);
        AKeys.Add(LKey);
      end;
    finally
      LValues.Free;
      LUsers.Free;
    end;
  finally
    LIni.Free;
  end;
end;

function TRpWebServerConfigAdminService.SaveApiKeyCreateRequest(
  const ARequest: TRpWebApiKeyCreateRequest): TRpWebGeneratedApiKeyResult;
var
  LIni: TMemIniFile;
  LKeyName: string;
  LUserName: string;
begin
  LKeyName := NormalizeName(ARequest.KeyName);
  LUserName := NormalizeName(ARequest.UserName);
  if Length(LKeyName) < 1 then
    raise Exception.Create('API key name is required');
  if Length(LUserName) < 1 then
    raise Exception.Create('API key user is required');

  LIni := LoadIni;
  try
    EnsureUserExists(LIni, LUserName);
    if LIni.ReadString('SERVERAPIKEYS', LKeyName, #0) <> #0 then
      raise Exception.Create('API key already exists: ' + LKeyName);
    Result.KeyName := LKeyName;
    Result.UserName := LUserName;
    Result.SecretPlainText := GenerateApiSecret;
    LIni.WriteString('SERVERAPIKEYS', LKeyName, Result.SecretPlainText);
    LIni.WriteString('SERVERAPIKEYUSERS', LKeyName, LUserName);
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

procedure TRpWebServerConfigAdminService.DeleteApiKey(const AKeyName: string);
var
  LIni: TMemIniFile;
  LName: string;
begin
  LName := NormalizeName(AKeyName);
  LIni := LoadIni;
  try
    LIni.DeleteKey('SERVERAPIKEYS', LName);
    LIni.DeleteKey('SERVERAPIKEYUSERS', LName);
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

function TRpWebServerConfigAdminService.IsLastAdmin(const AUserName: string): Boolean;
begin
  Result := SameText(NormalizeName(AUserName), 'ADMIN') and (not BootstrapRequired);
end;

end.