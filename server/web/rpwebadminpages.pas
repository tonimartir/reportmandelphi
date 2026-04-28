unit rpwebadminpages;

{$I rpconf.inc}

interface

uses
  Classes, SysUtils, Generics.Collections, rptypes, rpwebserverconfigadmin;

type
  TRpWebAdminPageRenderer = class
  private
    class function BuildPage(const ATitle, ABody: string): string; static;
    class function MessageBlock(const AMessageText: string): string; static;
    class function BoolChecked(const AValue: Boolean): string; static;
    class function GroupCheckboxes(AAllGroups, ASelectedGroups: TStrings): string; static;
    class function AdminNav(const AAuthInputs: string): string; static;
  public
    class function RenderBootstrapPage(const AMessageText: string): string; static;
    class function RenderAdminLoginPage(const AMessageText: string): string; static;
    class function RenderAdminHome(const AServerInfo: TRpWebServerConfigInfo;
      const AAuthInputs: string): string; static;
    class function RenderServerConfig(const AData: TRpWebServerConfigFormData;
      const AAuthInputs, AMessageText: string): string; static;
    class function RenderUsersList(const AUsers: TList<TRpWebServerUser>;
      const AAuthInputs, AMessageText: string): string; static;
    class function RenderUserEdit(const ARequest: TRpWebUserEditRequest;
      AAllGroups: TStrings; const AIsNew: Boolean;
      const AAuthInputs, AMessageText: string): string; static;
    class function RenderGroupsList(const AGroups: TList<TRpWebServerGroup>;
      const AAuthInputs, AMessageText: string): string; static;
    class function RenderGroupEdit(const ARequest: TRpWebGroupEditRequest;
      const AIsNew: Boolean; const AAuthInputs, AMessageText: string): string; static;
    class function RenderAliasesList(const AAliases: TList<TRpWebServerAlias>;
      const AAuthInputs, AMessageText: string): string; static;
    class function RenderAliasEdit(const ARequest: TRpWebAliasEditRequest;
      AAllGroups: TStrings; const AIsNew: Boolean;
      const AAuthInputs, AMessageText: string): string; static;
    class function RenderApiKeysList(const AKeys: TList<TRpWebServerApiKey>;
      AUsers: TStrings; const AAuthInputs, AMessageText: string): string; static;
    class function RenderApiKeyCreated(
      const AResult: TRpWebGeneratedApiKeyResult; const AAuthInputs: string): string; static;
    class function RenderDiagnostics(const AServerInfo: TRpWebServerConfigInfo;
      const AAuthInputs, AMessageText: string): string; static;
    class function RenderError(const ATitle, AMessageText: string): string; static;
  end;

implementation

class function TRpWebAdminPageRenderer.BuildPage(const ATitle, ABody: string): string;
begin
  Result := '<html><head><title>' + RpHtmlEncode(ATitle) + '</title>' +
    '<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">' +
    '</head><body bgcolor="#FFFFFF"><h2>' + RpHtmlEncode(ATitle) + '</h2>' +
    ABody + '</body></html>';
end;

class function TRpWebAdminPageRenderer.MessageBlock(
  const AMessageText: string): string;
begin
  if Length(Trim(AMessageText)) = 0 then
    Result := ''
  else
    Result := '<p><b>' + RpHtmlEncode(AMessageText) + '</b></p>';
end;

class function TRpWebAdminPageRenderer.BoolChecked(const AValue: Boolean): string;
begin
  if AValue then
    Result := ' checked'
  else
    Result := '';
end;

class function TRpWebAdminPageRenderer.GroupCheckboxes(AAllGroups,
  ASelectedGroups: TStrings): string;
var
  I: Integer;
  LName: string;
begin
  Result := '';
  for I := 0 to AAllGroups.Count - 1 do
  begin
    LName := AAllGroups.Names[I];
    if Length(LName) = 0 then
      LName := AAllGroups[I];
    Result := Result + '<label><input type="checkbox" name="group_' +
      RpHtmlEncode(LName) + '" value="1"';
    if ASelectedGroups.IndexOfName(LName) >= 0 then
      Result := Result + ' checked';
    Result := Result + '> ' + RpHtmlEncode(LName) + '</label><br/>';
  end;
end;

class function TRpWebAdminPageRenderer.AdminNav(const AAuthInputs: string): string;
begin
  Result :=
    '<table border="0"><tr>' +
    '<td><form method="post" action="/admin">' + AAuthInputs + '<input type="submit" value="Admin"></form></td>' +
    '<td><form method="post" action="/admin/server-config">' + AAuthInputs + '<input type="submit" value="Server config"></form></td>' +
    '<td><form method="post" action="/admin/users">' + AAuthInputs + '<input type="submit" value="Users"></form></td>' +
    '<td><form method="post" action="/admin/groups">' + AAuthInputs + '<input type="submit" value="Groups"></form></td>' +
    '<td><form method="post" action="/admin/aliases">' + AAuthInputs + '<input type="submit" value="Aliases"></form></td>' +
    '<td><form method="post" action="/admin/apikeys">' + AAuthInputs + '<input type="submit" value="API keys"></form></td>' +
    '<td><form method="post" action="/admin/diagnostics">' + AAuthInputs + '<input type="submit" value="Diagnostics"></form></td>' +
    '</tr></table><hr/>';
end;

class function TRpWebAdminPageRenderer.RenderBootstrapPage(
  const AMessageText: string): string;
begin
  Result := BuildPage('Reportman Admin Bootstrap',
    MessageBlock(AMessageText) +
    '<form method="post" action="/admin/bootstrap">' +
    '<p>User: <input type="text" name="bootstrap_user" value="ADMIN"></p>' +
    '<p>Password: <input type="password" name="bootstrap_password"></p>' +
    '<p>Confirm password: <input type="password" name="bootstrap_password_confirm"></p>' +
    '<p><input type="submit" value="Create ADMIN"></p>' +
    '</form>');
end;

class function TRpWebAdminPageRenderer.RenderAdminLoginPage(
  const AMessageText: string): string;
begin
  Result := BuildPage('Reportman Admin Login',
    MessageBlock(AMessageText) +
    '<form method="post" action="/admin/login">' +
    '<p>User: <input type="text" name="username" value="ADMIN"></p>' +
    '<p>Password: <input type="password" name="password"></p>' +
    '<p><input type="submit" value="Login"></p>' +
    '</form>');
end;

class function TRpWebAdminPageRenderer.RenderAdminHome(
  const AServerInfo: TRpWebServerConfigInfo; const AAuthInputs: string): string;
begin
  Result := BuildPage('Reportman Admin',
    AdminNav(AAuthInputs) +
    '<p>Config file: ' + RpHtmlEncode(AServerInfo.ConfigFileName) + '</p>' +
    '<p>Users: ' + IntToStr(AServerInfo.UsersCount) + '</p>' +
    '<p>Groups: ' + IntToStr(AServerInfo.GroupsCount) + '</p>' +
    '<p>Aliases: ' + IntToStr(AServerInfo.AliasesCount) + '</p>' +
    '<p>API keys: ' + IntToStr(AServerInfo.ApiKeysCount) + '</p>' +
    '<p>Bootstrap required: ' + RpHtmlEncode(BoolToStr(AServerInfo.BootstrapRequired, True)) + '</p>');
end;

class function TRpWebAdminPageRenderer.RenderServerConfig(
  const AData: TRpWebServerConfigFormData; const AAuthInputs,
  AMessageText: string): string;
begin
  Result := BuildPage('Server Config',
    AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<form method="post" action="/admin/server-config">' + AAuthInputs +
    '<p>PAGESDIR: <input type="text" name="cfg_pagesdir" size="80" value="' + RpHtmlEncode(AData.PagesDir) + '"></p>' +
    '<p>TCPPORT: <input type="text" name="cfg_tcpport" value="' + RpHtmlEncode(AData.TcpPort) + '"></p>' +
    '<p>LOGFILE: <input type="text" name="cfg_logfile" size="80" value="' + RpHtmlEncode(AData.LogFile) + '"></p>' +
    '<p><label><input type="checkbox" name="cfg_log_json" value="1"' + BoolChecked(AData.LogJson) + '> LOG_JSON</label></p>' +
    '<p><label><input type="checkbox" name="cfg_user_access" value="1"' + BoolChecked(AData.UserAccess) + '> USER_ACCESS</label></p>' +
    '<p><label><input type="checkbox" name="cfg_api_key_access" value="1"' + BoolChecked(AData.ApiKeyAccess) + '> API_KEY_ACCESS</label></p>' +
    '<p><label><input type="checkbox" name="cfg_show_unauthorized" value="1"' + BoolChecked(AData.ShowUnauthorizedPage) + '> SHOWUNAUTHORIZEDPAGE</label></p>' +
    '<p><label><input type="checkbox" name="cfg_require_https" value="1"' + BoolChecked(AData.RequireHttps) + '> REQUIRE_HTTPS</label></p>' +
    '<p><label><input type="checkbox" name="cfg_url_get_params" value="1"' + BoolChecked(AData.UrlGetParams) + '> URLGETPARAMS</label></p>' +
    '<p><input type="submit" value="Save"></p></form>');
end;

class function TRpWebAdminPageRenderer.RenderUsersList(
  const AUsers: TList<TRpWebServerUser>; const AAuthInputs,
  AMessageText: string): string;
var
  I: Integer;
begin
  Result := AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<form method="post" action="/admin/users/new">' + AAuthInputs + '<p><input type="submit" value="New user"></p></form>' +
    '<table border="1"><tr><th>User</th><th>Admin</th><th>Groups</th><th>Actions</th></tr>';
  for I := 0 to AUsers.Count - 1 do
  begin
    Result := Result + '<tr><td>' + RpHtmlEncode(AUsers[I].UserName) + '</td><td>' +
      RpHtmlEncode(BoolToStr(AUsers[I].IsAdmin, True)) + '</td><td>' +
      RpHtmlEncode(StringReplace(AUsers[I].Groups.CommaText, ',', ', ', [rfReplaceAll])) + '</td><td>' +
      '<form method="post" action="/admin/users/edit"><input type="hidden" name="name" value="' + RpHtmlEncode(AUsers[I].UserName) + '">' +
      AAuthInputs + '<input type="submit" value="Edit"></form>';
    if not AUsers[I].IsAdmin then
      Result := Result + '<form method="post" action="/admin/users/delete">' + AAuthInputs +
        '<input type="hidden" name="name" value="' + RpHtmlEncode(AUsers[I].UserName) + '"><input type="submit" value="Delete"></form>';
    Result := Result + '</td></tr>';
  end;
  Result := BuildPage('Users', Result + '</table>');
end;

class function TRpWebAdminPageRenderer.RenderUserEdit(
  const ARequest: TRpWebUserEditRequest; AAllGroups: TStrings;
  const AIsNew: Boolean; const AAuthInputs, AMessageText: string): string;
var
  LAction: string;
begin
  if AIsNew then
    LAction := '/admin/users/new'
  else
    LAction := '/admin/users/edit';
  Result := BuildPage('Edit User',
    AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<form method="post" action="' + LAction + '">' + AAuthInputs +
    '<input type="hidden" name="original_user_name" value="' + RpHtmlEncode(ARequest.OriginalUserName) + '">' +
    '<p>User name: <input type="text" name="user_name" value="' + RpHtmlEncode(ARequest.UserName) + '"></p>' +
    '<p><label><input type="checkbox" name="is_admin" value="1"' + BoolChecked(ARequest.IsAdmin) + '> Is admin</label></p>' +
    '<p><label><input type="checkbox" name="change_password" value="1"' + BoolChecked(ARequest.ChangePassword or AIsNew) + '> Change password</label></p>' +
    '<p>Password: <input type="password" name="user_password"></p>' +
    '<p>Confirm password: <input type="password" name="user_password_confirm"></p>' +
    '<p>Groups:</p>' + GroupCheckboxes(AAllGroups, ARequest.Groups) +
    '<p><input type="submit" value="Save"></p></form>');
end;

class function TRpWebAdminPageRenderer.RenderGroupsList(
  const AGroups: TList<TRpWebServerGroup>; const AAuthInputs,
  AMessageText: string): string;
var
  I: Integer;
begin
  Result := AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<form method="post" action="/admin/groups/new">' + AAuthInputs +
    '<p>Name: <input type="text" name="group_name"> Description: <input type="text" name="group_description"> <input type="submit" value="Create group"></p></form>' +
    '<table border="1"><tr><th>Group</th><th>Description</th><th>Actions</th></tr>';
  for I := 0 to AGroups.Count - 1 do
  begin
    Result := Result + '<tr><td>' + RpHtmlEncode(AGroups[I].GroupName) + '</td><td>' + RpHtmlEncode(AGroups[I].Description) + '</td><td>' +
      '<form method="post" action="/admin/groups/edit">' + AAuthInputs + '<input type="hidden" name="name" value="' + RpHtmlEncode(AGroups[I].GroupName) + '"><input type="submit" value="Edit"></form>' +
      '<form method="post" action="/admin/groups/delete">' + AAuthInputs + '<input type="hidden" name="name" value="' + RpHtmlEncode(AGroups[I].GroupName) + '"><input type="submit" value="Delete"></form>' +
      '</td></tr>';
  end;
  Result := BuildPage('Groups', Result + '</table>');
end;

class function TRpWebAdminPageRenderer.RenderGroupEdit(
  const ARequest: TRpWebGroupEditRequest; const AIsNew: Boolean;
  const AAuthInputs, AMessageText: string): string;
begin
  Result := BuildPage('Edit Group',
    AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<form method="post" action="/admin/groups/edit">' + AAuthInputs +
    '<input type="hidden" name="original_group_name" value="' + RpHtmlEncode(ARequest.OriginalGroupName) + '">' +
    '<p>Name: <input type="text" name="group_name" value="' + RpHtmlEncode(ARequest.GroupName) + '"></p>' +
    '<p>Description: <input type="text" name="group_description" size="80" value="' + RpHtmlEncode(ARequest.Description) + '"></p>' +
    '<p><input type="submit" value="Save"></p></form>');
end;

class function TRpWebAdminPageRenderer.RenderAliasesList(
  const AAliases: TList<TRpWebServerAlias>; const AAuthInputs,
  AMessageText: string): string;
var
  I: Integer;
begin
  Result := AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<form method="post" action="/admin/aliases/edit">' + AAuthInputs + '<p><input type="submit" value="New alias"></p></form>' +
    '<table border="1"><tr><th>Alias</th><th>Type</th><th>Target</th><th>Groups</th><th>Actions</th></tr>';
  for I := 0 to AAliases.Count - 1 do
  begin
    Result := Result + '<tr><td>' + RpHtmlEncode(AAliases[I].AliasName) + '</td><td>';
    if AAliases[I].IsConnectionAlias then
      Result := Result + 'connection'
    else
      Result := Result + 'folder';
    Result := Result + '</td><td>' + RpHtmlEncode(AAliases[I].TargetValue) + '</td><td>' +
      RpHtmlEncode(StringReplace(AAliases[I].AllowedGroups.CommaText, ',', ', ', [rfReplaceAll])) + '</td><td>' +
      '<form method="post" action="/admin/aliases/edit">' + AAuthInputs + '<input type="hidden" name="name" value="' + RpHtmlEncode(AAliases[I].AliasName) + '"><input type="submit" value="Edit"></form>' +
      '<form method="post" action="/admin/aliases/delete">' + AAuthInputs + '<input type="hidden" name="name" value="' + RpHtmlEncode(AAliases[I].AliasName) + '"><input type="submit" value="Delete"></form>' +
      '</td></tr>';
  end;
  Result := BuildPage('Aliases', Result + '</table>');
end;

class function TRpWebAdminPageRenderer.RenderAliasEdit(
  const ARequest: TRpWebAliasEditRequest; AAllGroups: TStrings;
  const AIsNew: Boolean; const AAuthInputs, AMessageText: string): string;
var
  LTypeFolder, LTypeConnection: string;
  LAction: string;
begin
  LTypeFolder := '';
  LTypeConnection := '';
  if ARequest.AliasType = watConnection then
    LTypeConnection := ' checked'
  else
    LTypeFolder := ' checked';
  if AIsNew then
    LAction := '/admin/aliases/new'
  else
    LAction := '/admin/aliases/edit';
  Result := BuildPage('Edit Alias',
    AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<form method="post" action="' + LAction + '">' + AAuthInputs +
    '<input type="hidden" name="original_alias_name" value="' + RpHtmlEncode(ARequest.OriginalAliasName) + '">' +
    '<p>Name: <input type="text" name="alias_name" value="' + RpHtmlEncode(ARequest.AliasName) + '"></p>' +
    '<p><label><input type="radio" name="alias_type" value="folder"' + LTypeFolder + '> Folder</label>' +
    ' <label><input type="radio" name="alias_type" value="connection"' + LTypeConnection + '> Connection</label></p>' +
    '<p>Target: <input type="text" name="alias_target" size="80" value="' + RpHtmlEncode(ARequest.TargetValue) + '"></p>' +
    '<p>Allowed groups:</p>' + GroupCheckboxes(AAllGroups, ARequest.AllowedGroups) +
    '<p><input type="submit" value="Save"></p></form>');
end;

class function TRpWebAdminPageRenderer.RenderApiKeysList(
  const AKeys: TList<TRpWebServerApiKey>; AUsers: TStrings;
  const AAuthInputs, AMessageText: string): string;
var
  I: Integer;
  LUserOptions: string;
  LUserName: string;
begin
  LUserOptions := '';
  for I := 0 to AUsers.Count - 1 do
  begin
    LUserName := AUsers.Names[I];
    if Length(LUserName) = 0 then
      LUserName := AUsers[I];
    LUserOptions := LUserOptions + '<option value="' + RpHtmlEncode(LUserName) + '">' + RpHtmlEncode(LUserName) + '</option>';
  end;
  Result := AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<form method="post" action="/admin/apikeys/new">' + AAuthInputs +
    '<p>Name: <input type="text" name="api_key_name"> User: <select name="api_key_user">' + LUserOptions + '</select> <input type="submit" value="Create API key"></p></form>' +
    '<table border="1"><tr><th>Key</th><th>User</th><th>Secret</th><th>Actions</th></tr>';
  for I := 0 to AKeys.Count - 1 do
  begin
    Result := Result + '<tr><td>' + RpHtmlEncode(AKeys[I].KeyName) + '</td><td>' + RpHtmlEncode(AKeys[I].UserName) + '</td><td>' +
      RpHtmlEncode(AKeys[I].SecretMasked) + '</td><td>' +
      '<form method="post" action="/admin/apikeys/delete">' + AAuthInputs + '<input type="hidden" name="name" value="' + RpHtmlEncode(AKeys[I].KeyName) + '"><input type="submit" value="Delete"></form>' +
      '</td></tr>';
  end;
  Result := BuildPage('API Keys', Result + '</table>');
end;

class function TRpWebAdminPageRenderer.RenderApiKeyCreated(
  const AResult: TRpWebGeneratedApiKeyResult; const AAuthInputs: string): string;
begin
  Result := BuildPage('API Key Created',
    AdminNav(AAuthInputs) +
    '<p>Key name: ' + RpHtmlEncode(AResult.KeyName) + '</p>' +
    '<p>User: ' + RpHtmlEncode(AResult.UserName) + '</p>' +
    '<p>Secret: <b>' + RpHtmlEncode(AResult.SecretPlainText) + '</b></p>');
end;

class function TRpWebAdminPageRenderer.RenderDiagnostics(
  const AServerInfo: TRpWebServerConfigInfo; const AAuthInputs,
  AMessageText: string): string;
begin
  Result := BuildPage('Diagnostics',
    AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<p>Config file: ' + RpHtmlEncode(AServerInfo.ConfigFileName) + '</p>' +
    '<p>Users: ' + IntToStr(AServerInfo.UsersCount) + '</p>' +
    '<p>Groups: ' + IntToStr(AServerInfo.GroupsCount) + '</p>' +
    '<p>Aliases: ' + IntToStr(AServerInfo.AliasesCount) + '</p>' +
    '<p>API keys: ' + IntToStr(AServerInfo.ApiKeysCount) + '</p>' +
    '<p>Bootstrap required: ' + RpHtmlEncode(BoolToStr(AServerInfo.BootstrapRequired, True)) + '</p>');
end;

class function TRpWebAdminPageRenderer.RenderError(const ATitle,
  AMessageText: string): string;
begin
  Result := BuildPage(ATitle, MessageBlock(AMessageText));
end;

end.