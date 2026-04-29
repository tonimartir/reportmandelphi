unit rpwebadminpages;

{$I rpconf.inc}

interface

uses
  Classes, SysUtils, Generics.Collections, rptypes, rpwebserverconfigadmin,
  rpwebdbxadmin;

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
    class function RenderConnectionsList(const AItems: TList<TRpWebConnectionItem>;
      const AAuthInputs, AMessageText: string): string; static;
    class function RenderConnectionEdit(const AConnectionName: string;
      const AParams: TList<TRpWebConnectionParam>;
      const AAuthInputs, AMessageText: string;
      AHubConnections: TStrings = nil): string; static;
    class function RenderConnectionNew(ADrivers, ADbExpressDrivers: TStrings;
      const AAuthInputs, AMessageText: string): string; static;
    class function RenderConnectionRaw(const AConfigText: string;
      const AAuthInputs, AMessageText: string): string; static;
    class function RenderConnectionTest(const AConnectionName: string;
      const AResult: TRpWebConnectionTestResult; const AAuthInputs: string;
      ACurrentValues: TStrings = nil): string; static;
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
    '<td><form method="post" action="/admin/connections">' + AAuthInputs + '<input type="submit" value="Connections"></form></td>' +
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
    '<p><label><input type="checkbox" name="cfg_url_get_params" value="1"' + BoolChecked(AData.UrlGetParams) + '> URLGETPARAMS</label></p>' +
    '<p><input type="submit" value="Save"></p></form>');
end;

class function TRpWebAdminPageRenderer.RenderConnectionsList(
  const AItems: TList<TRpWebConnectionItem>; const AAuthInputs,
  AMessageText: string): string;
var
  I: Integer;
begin
  Result := AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<form method="post" action="/admin/connections/new">' + AAuthInputs +
    '<p><input type="submit" value="New connection"></p></form>' +
    '<form method="post" action="/admin/connections/raw">' + AAuthInputs +
    '<p><input type="submit" value="Edit dbxconnections.ini manually"></p></form>' +
    '<table border="1"><tr><th>Name</th><th>Driver</th><th>Actions</th></tr>';
  for I := 0 to AItems.Count - 1 do
  begin
    Result := Result + '<tr><td>' + RpHtmlEncode(AItems[I].Name) + '</td><td>' +
      RpHtmlEncode(AItems[I].DisplayDriverName) + '</td><td>' +
      '<form method="post" action="/admin/connections/edit">' + AAuthInputs +
      '<input type="hidden" name="name" value="' + RpHtmlEncode(AItems[I].Name) + '"><input type="submit" value="Edit"></form>' +
      '<form method="post" action="/admin/connections/test">' + AAuthInputs +
      '<input type="hidden" name="connection_name" value="' + RpHtmlEncode(AItems[I].Name) + '"><input type="submit" value="Test"></form>' +
      '<form method="post" action="/admin/connections/delete">' + AAuthInputs +
      '<input type="hidden" name="connection_name" value="' + RpHtmlEncode(AItems[I].Name) + '"><input type="submit" value="Delete"></form>' +
      '</td></tr>';
  end;
  Result := BuildPage('Connections', Result + '</table>');
end;

class function TRpWebAdminPageRenderer.RenderConnectionNew(ADrivers,
  ADbExpressDrivers: TStrings; const AAuthInputs, AMessageText: string): string;
var
  I: Integer;
  LOptions: string;
  LDbxOptions: string;
begin
  LOptions := '';
  for I := 0 to ADrivers.Count - 1 do
    LOptions := LOptions + '<option value="' + RpHtmlEncode(ADrivers[I]) + '">' +
      RpHtmlEncode(ADrivers[I]) + '</option>';
  LDbxOptions := '<option value="">Select DBExpress driver...</option>';
  for I := 0 to ADbExpressDrivers.Count - 1 do
    LDbxOptions := LDbxOptions + '<option value="' +
      RpHtmlEncode(ADbExpressDrivers[I]) + '">' +
      RpHtmlEncode(ADbExpressDrivers[I]) + '</option>';
  Result := BuildPage('New Connection',
    AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<form method="post" action="/admin/connections/new">' + AAuthInputs +
    '<p>Name: <input type="text" name="connection_name"></p>' +
    '<p>Driver: <select name="driver_name">' + LOptions + '</select></p>' +
    '<p>DBExpress driver: <select name="dbexpress_driver_name">' +
    LDbxOptions + '</select> Use only when Driver = DBExpress.</p>' +
    '<p><input type="submit" name="connection_action_create" value="Create"></p></form>');
end;

class function TRpWebAdminPageRenderer.RenderConnectionEdit(
  const AConnectionName: string; const AParams: TList<TRpWebConnectionParam>;
  const AAuthInputs, AMessageText: string; AHubConnections: TStrings = nil): string;
var
  I, J: Integer;
  LParam: TRpWebConnectionParam;
  LFieldHtml: string;
  LListId: string;
  LDriverName: string;
  LCurrentHubDatabaseId: string;
begin
  LDriverName := '';
  LCurrentHubDatabaseId := '';
  for I := 0 to AParams.Count - 1 do
  begin
    if SameText(AParams[I].Name, 'DriverName') then
      LDriverName := Trim(AParams[I].Value)
    else if SameText(AParams[I].Name, 'HubDatabaseId') then
      LCurrentHubDatabaseId := Trim(AParams[I].Value);
  end;

  Result := AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<script>' +
    'function rpCaptureConnectionFormState(form){' +
    'var pairs=[],formData,entry,name,stateField;' +
    'stateField=form.elements["connection_form_state"];' +
    'if(!stateField)return true;' +
    'formData=new FormData(form);' +
    'for(entry of formData.entries()){' +
    'name=entry[0]||"";' +
    'if(name.indexOf("connparam_")!==0)continue;' +
    'pairs.push(encodeURIComponent(name)+"="+encodeURIComponent(entry[1]||""));' +
    '}' +
    'stateField.value=pairs.join("&");' +
    'return true;' +
    '}' +
    '</script>' +
    '<form method="post" action="/admin/connections/edit" onsubmit="return rpCaptureConnectionFormState(this);">' + AAuthInputs +
    '<input type="hidden" name="connection_form_state" value="">' +
    '<input type="hidden" name="connection_name" value="' + RpHtmlEncode(AConnectionName) + '">';
  for I := 0 to AParams.Count - 1 do
  begin
    LParam := AParams[I];
    case LParam.EditorKind of
      weReadOnly:
        LFieldHtml := RpHtmlEncode(LParam.Value) +
          '<input type="hidden" name="connparam_' + RpHtmlEncode(LParam.Name) +
          '" value="' + RpHtmlEncode(LParam.Value) + '">';
      wePassword:
        LFieldHtml := '<input type="password" name="connparam_' + RpHtmlEncode(LParam.Name) +
          '" value="' + RpHtmlEncode(LParam.Value) + '" size="80">';
      weCombo:
        begin
          LFieldHtml := '<select name="connparam_' + RpHtmlEncode(LParam.Name) + '">';
          for J := 0 to LParam.Options.Count - 1 do
          begin
            LFieldHtml := LFieldHtml + '<option value="' + RpHtmlEncode(LParam.Options[J]) + '"';
            if SameText(LParam.Options[J], LParam.Value) then
              LFieldHtml := LFieldHtml + ' selected';
            LFieldHtml := LFieldHtml + '>' + RpHtmlEncode(LParam.Options[J]) + '</option>';
          end;
          LFieldHtml := LFieldHtml + '</select>';
          if SameText(LParam.Name, 'DriverName') or
            SameText(LParam.Name, 'DriverID') or
            SameText(LParam.Name, 'DBXDriverName') then
          begin
            LFieldHtml := LFieldHtml +
              ' <button type="submit" name="connection_action_change_driver">Apply driver</button>';
            if SameText(LDriverName, 'FireDac') and SameText(LParam.Name, 'DriverID') then
              LFieldHtml := LFieldHtml +
                ' <button type="submit" name="connection_action_change_driver_clear">Apply driver (clear)</button>';
          end;
        end;
      weComboEditable:
        begin
          LListId := 'connparam_list_' + IntToStr(I);
          LFieldHtml := '<input type="text" name="connparam_' + RpHtmlEncode(LParam.Name) +
            '" value="' + RpHtmlEncode(LParam.Value) + '" size="100" list="' +
            RpHtmlEncode(LListId) + '"><datalist id="' + RpHtmlEncode(LListId) + '">';
          for J := 0 to LParam.Options.Count - 1 do
            LFieldHtml := LFieldHtml + '<option value="' + RpHtmlEncode(LParam.Options[J]) + '">';
          LFieldHtml := LFieldHtml + '</datalist>';
        end;
      weTextArea:
        LFieldHtml := '<textarea name="connparam_' + RpHtmlEncode(LParam.Name) +
          '" cols="100" rows="4">' + RpHtmlEncode(LParam.Value) + '</textarea>';
    else
      LFieldHtml := '<input type="text" name="connparam_' + RpHtmlEncode(LParam.Name) +
        '" value="' + RpHtmlEncode(LParam.Value) + '" size="100">';
    end;
    if SameText(LDriverName, 'Reportman AI Agent') and SameText(LParam.Name, 'HubDatabaseId') then
    begin
      LFieldHtml := LFieldHtml +
        ' <button type="submit" name="connection_action_select_hub">Select Connection...</button>';
      if Assigned(AHubConnections) and (AHubConnections.Count > 0) then
      begin
        LFieldHtml := LFieldHtml + '<br><select name="hub_connection_selector" onchange="this.form.elements[''connparam_HubDatabaseId''].value=this.value;">' +
          '<option value="">Select a connection...</option>';
        for J := 0 to AHubConnections.Count - 1 do
        begin
          LFieldHtml := LFieldHtml + '<option value="' + RpHtmlEncode(AHubConnections.ValueFromIndex[J]) + '"';
          if SameText(AHubConnections.ValueFromIndex[J], LCurrentHubDatabaseId) then
            LFieldHtml := LFieldHtml + ' selected';
          LFieldHtml := LFieldHtml + '>' + RpHtmlEncode(AHubConnections.Names[J]) + '</option>';
        end;
        LFieldHtml := LFieldHtml + '</select>';
      end;
    end;
    Result := Result + '<p>' + RpHtmlEncode(LParam.Name) + ': ' + LFieldHtml + '</p>';
  end;
  Result := BuildPage('Edit Connection', Result +
    '<p><input type="submit" name="connection_action_save" value="Save"></p>' +
    '<p><button type="submit" name="connection_action_test">Test connection</button></p></form>');
end;

class function TRpWebAdminPageRenderer.RenderConnectionRaw(
  const AConfigText, AAuthInputs, AMessageText: string): string;
begin
  Result := BuildPage('Edit dbxconnections.ini',
    AdminNav(AAuthInputs) + MessageBlock(AMessageText) +
    '<form method="post" action="/admin/connections/raw">' + AAuthInputs +
    '<p><label><input type="checkbox" name="create_backup" value="1" checked> Create backup</label></p>' +
    '<p><textarea name="raw_config_text" cols="120" rows="30">' + RpHtmlEncode(AConfigText) + '</textarea></p>' +
    '<p><input type="submit" name="raw_action_save" value="Save raw dbxconnections.ini"></p></form>');
end;

class function TRpWebAdminPageRenderer.RenderConnectionTest(
  const AConnectionName: string; const AResult: TRpWebConnectionTestResult;
  const AAuthInputs: string; ACurrentValues: TStrings): string;
var
  I: Integer;
  LDetails: string;
  LHiddenValues: string;
  LName: string;
begin
  LDetails := '';
  LHiddenValues := '';
  for I := 0 to AResult.SafeDetails.Count - 1 do
    LDetails := LDetails + '<li>' + RpHtmlEncode(AResult.SafeDetails[I]) + '</li>';
  if ACurrentValues <> nil then
    for I := 0 to ACurrentValues.Count - 1 do
    begin
      LName := Trim(ACurrentValues.Names[I]);
      if Length(LName) = 0 then
        Continue;
      LHiddenValues := LHiddenValues + '<input type="hidden" name="connparam_' +
        RpHtmlEncode(LName) + '" value="' +
        RpHtmlEncode(ACurrentValues.ValueFromIndex[I]) + '">';
    end;
  Result := BuildPage('Connection Test',
    AdminNav(AAuthInputs) +
    '<p>Connection: ' + RpHtmlEncode(AConnectionName) + '</p>' +
    '<p>Success: ' + RpHtmlEncode(BoolToStr(AResult.Success, True)) + '</p>' +
    '<p>Message: ' + RpHtmlEncode(AResult.MessageText) + '</p>' +
    '<p>Driver: ' + RpHtmlEncode(AResult.DriverName) + '</p>' +
    '<ul>' + LDetails + '</ul>' +
    '<form method="post" action="/admin/connections/edit">' + AAuthInputs +
    '<input type="hidden" name="name" value="' + RpHtmlEncode(AConnectionName) + '">' +
    LHiddenValues + '<input type="submit" value="Back to edit"></form>');
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