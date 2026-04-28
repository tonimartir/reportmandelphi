unit rpwebpages;

{$I rpconf.inc}

interface

uses SysUtils,Classes,HTTPApp,rpmdconsts,Inifiles,rpalias,System.NetEncoding,
 Generics.Collections,
{$IFNDEF USEVARIANTS}
 Windows,FileCtrl,asptlb,
{$ENDIF}
 rpmdshfolder,rptypes,rpreport,rppdfdriver,rpparams,rptextdriver,rpsvgdriver,
 rpcsvdriver,rpdatainfo,rpwebserverconfigadmin,rpwebadminauth,
 rpwebadminpages,
{$IFDEF USEVARIANTS}
 Variants,
{$ENDIF}
{$IFDEF USEBDE}
  dbtables,
{$ENDIF}
{$IFNDEF FORCECONSOLE}
{$IFDEF MSWINDOWS}
  rpgdidriver,Windows,
{$ENDIF}
{$ENDIF}
// jclDebug;
rpmetafile;

const
 REPMAN_LOGIN_LABEL='ReportManagerLoginLabel';
 REPMAN_USER_LABEL='UserNameLabel';
 REPMAN_PASSWORD_LABEL='PasswordLabel';
 REPMAN_INDEX_LABEL='ReportManagerIndexLabel';
 REPMAN_WEBSERVER='RepManWebServer';
 REPMAN_AVAILABLE_ALIASES='AvailableAliasesLabel';
 REPMAN_REPORTS_LABEL='ReportManagerReportsLabel';
 REPMAN_REPORTSLOC_LABEL='ReportsLocationAlias';
 REPMAN_PARAMSLABEL='ReportManagerParamsLabel';
 REPMAN_PARAMSLOCATION='ReportsParamsTableLocation';
 REPMAN_EXECUTELABEL='RepManExecuteLabel';
 REPMAN_HIDDEN='ReportHiddenLocation';
 REPMAN_REPORTTITLE='ReportTitleLocation';
type
 TRpWebPage=(rpwLogin,rpwIndex,rpwVersion,rpwShowParams,rpwShowAlias);

 EHttpError=class(Exception)
  private
   FStatusCode:Integer;
   FShowErrorPage:Boolean;
  public
   constructor CreateHttp(AStatusCode: Integer; const AMessage: string;
    AShowErrorPage: Boolean);
   property StatusCode:Integer read FStatusCode;
   property ShowErrorPage:Boolean read FShowErrorPage;
 end;

 TRpWebPageLoader=class(TObject)
  private
   Owner:TComponent;
   Ffilenameconfig:string;
   fport:integer;
   laliases:TStringList;
   lusers,lgroups,LUserGroups,LAliasGroups:TStringList;
    LServerApiKeys:TStringList;
    LServerApiKeyUsers:TStringList;
   aresult:TStringList;
   FPagesDirectory:String;
   initreaded:boolean;
   InitErrorMessage:string;
   LogFileErrorMessage:String;
   loginpage:string;
   indexpage:string;
   showaliaspage:string;
   showerrorpage:string;
   paramspage:string;
   isadmin:boolean;
  FAllowUserAccess:Boolean;
  FAllowApiKeyAccess:Boolean;
  FRequireHttps:Boolean;
  FShowUnauthorizedPage:Boolean;
  FUrlGetParams:Boolean;
  FLogJson:Boolean;
   FRpAliasLibs:TRpAlias;
{$IFDEF USEBDE}
   ASession:TSession;
   BDESessionDir:String;
   BDESessionDirOK:String;
{$ENDIF}
   logfileerror:boolean;
   FLogFilename:String;
  FJsonLogFilename:String;
   function CreateReport:TRpReport;
   procedure InitConfig;
   procedure CheckInitReaded;
   function GenerateError(e: Exception):string;
   function LoadLoginPage(Request: TWebRequest):string;
   function LoadIndexPage(Request: TWebRequest):string;
   function LoadAliasPage(Request: TWebRequest):string;
   function LoadParamsPage(Request: TWebRequest):string;
   function CheckPrivileges(username,aliasname:String):Boolean;
  function GetRequestParam(Request: TWebRequest; const AName: string): string;
  function GetAdminParam(Request: TWebRequest; const AName: string): string;
  function CreateRequestParamList(Request: TWebRequest): TStringList;
  function CreateAdminParamList(Request: TWebRequest): TStringList;
  function HiddenInput(const AName, AValue: string): string;
  function HiddenAuthInputs(Request: TWebRequest): string;
  function HiddenAdminAuthInputs(Request: TWebRequest): string;
  function GetRequestValue(Request: TWebRequest; const AName: string): string;
  function GetRequestHeader(Request: TWebRequest; const AName: string): string;
  function GetFirstRequestValue(Request: TWebRequest;
   const ANames: array of string): string;
  function GetRemoteAddr(Request: TWebRequest): string;
  function GetForwardedFor(Request: TWebRequest): string;
  function IsSecureConnection(Request: TWebRequest): Boolean;
  function GetConnectionType(Request: TWebRequest): string;
  function GetCertificateValidityText(Request: TWebRequest): string;
  procedure CheckRequireHttps(Request: TWebRequest);
  function HasServerApiKey(Request: TWebRequest): Boolean;
  function GetServerApiKeyName(Request: TWebRequest): string;
  function ReportParamsToJson(AReport: TRpReport): string;
  function TryAuthenticateServerApiKey(Request: TWebRequest;
   out AUserName: string; out AIsAdmin: Boolean): Boolean;
  function TryAuthenticateUserPassword(Request: TWebRequest;
   out AUserName: string; out AIsAdmin: Boolean): Boolean;
  procedure ResolveAuthenticatedUser(Request: TWebRequest;
   out AUserName: string; out AIsAdmin: Boolean);
  function TryAdminLogin(Request: TWebRequest; out AUserName,
   AMessageText: string): Boolean;
  procedure CheckAdminLogin(Request: TWebRequest; out AUserName: string;
   out AIsAdmin: Boolean);
  class function RequestHasParam(Request: TWebRequest;
   const AName: string): Boolean; static;
  class function RequestCheckboxChecked(Request: TWebRequest;
   const AName: string): Boolean; static;
  procedure CollectAdminPrefixedValues(Request: TWebRequest;
   const APrefix: string; AValues: TStrings);
  procedure LoadAllGroupNames(AGroupNames: TStrings);
  procedure LoadAllUserNames(AUserNames: TStrings);
  function LoadAdminBootstrapPage(Request: TWebRequest): string;
  function ExecuteAdminBootstrap(Request: TWebRequest): string;
  function LoadAdminLoginPage(Request: TWebRequest): string;
  function ExecuteAdminLogin(Request: TWebRequest): string;
  function LoadAdminHomePage(Request: TWebRequest): string;
  function LoadAdminServerConfigPage(Request: TWebRequest;
   const AMessageText: string=''): string;
  function ExecuteAdminServerConfigSave(Request: TWebRequest): string;
  function LoadAdminUsersPage(Request: TWebRequest;
   const AMessageText: string=''): string;
  function LoadAdminUserEditPage(Request: TWebRequest;
   const AMessageText: string=''): string;
  function ExecuteAdminUserCreate(Request: TWebRequest): string;
  function ExecuteAdminUserSave(Request: TWebRequest): string;
  function ExecuteAdminUserDelete(Request: TWebRequest): string;
  function LoadAdminGroupsPage(Request: TWebRequest;
   const AMessageText: string=''): string;
  function LoadAdminGroupEditPage(Request: TWebRequest;
   const AMessageText: string=''): string;
  function ExecuteAdminGroupCreate(Request: TWebRequest): string;
  function ExecuteAdminGroupSave(Request: TWebRequest): string;
  function ExecuteAdminGroupDelete(Request: TWebRequest): string;
  function LoadAdminAliasesPage(Request: TWebRequest;
   const AMessageText: string=''): string;
  function LoadAdminAliasEditPage(Request: TWebRequest;
   const AMessageText: string=''): string;
  function ExecuteAdminAliasCreate(Request: TWebRequest): string;
  function ExecuteAdminAliasSave(Request: TWebRequest): string;
  function ExecuteAdminAliasDelete(Request: TWebRequest): string;
  function LoadAdminApiKeysPage(Request: TWebRequest;
   const AMessageText: string=''): string;
  function ExecuteAdminApiKeyCreate(Request: TWebRequest): string;
  function ExecuteAdminApiKeyDelete(Request: TWebRequest): string;
  function LoadAdminDiagnosticsPage(Request: TWebRequest;
   const AMessageText: string=''): string;
  procedure WriteStructuredLog(const AEvent,AUser,AApiKey,ARemoteAddr,
   AForwardedFor,AReport,AParamsJson,AMessage: string);
  procedure WriteExecuteReportLog(const AUser,AApiKey,ARemoteAddr,
   AForwardedFor,AReport,AParamsJson: string);
   procedure ClearLists;
   procedure LoadReport(pdfreport:TRpReport;aliasname,reportname:String);
  public
   procedure WriteLog(aMessage:String);
   procedure ExecuteReport(Request: TWebRequest;Response:TWebResponse);
   procedure CheckLogin(Request:TWebRequest);
   procedure GetWebPage(Request: TWebRequest;apage:TRpWebPage;Response:TWebResponse);
  procedure HandleAdminRequest(Request: TWebRequest; Response:TWebResponse);
   constructor Create(AOwner:TComponent);
   destructor Destroy;override;
  end;


implementation

constructor EHttpError.CreateHttp(AStatusCode: Integer; const AMessage: string;
 AShowErrorPage: Boolean);
begin
 inherited Create(AMessage);
 FStatusCode:=AStatusCode;
 FShowErrorPage:=AShowErrorPage;
end;

function ReadConfigBool(inif: TMemInifile; const Section, Ident: string;
  Default: Boolean): Boolean;
var
 LValue:string;
begin
 LValue:=Trim(inif.ReadString(Section,Ident,''));
 if Length(LValue)<1 then
 begin
  Result:=Default;
  exit;
 end;
 if SameText(LValue,'1') or SameText(LValue,'TRUE') or SameText(LValue,'YES')
  or SameText(LValue,'ON') then
 begin
  Result:=True;
  exit;
 end;
 if SameText(LValue,'0') or SameText(LValue,'FALSE') or SameText(LValue,'NO')
  or SameText(LValue,'OFF') then
 begin
  Result:=False;
  exit;
 end;
 Result:=Default;
end;

function FirstToken(const AValue: string): string;
var
 SepPos:Integer;
begin
 Result:=Trim(AValue);
 SepPos:=Pos(',',Result);
 if SepPos>0 then
  Result:=Trim(Copy(Result,1,SepPos-1));
end;

function IsTruthyValue(const AValue: string): Boolean;
var
 LValue:string;
begin
 LValue:=UpperCase(Trim(AValue));
 Result:=(LValue='1') or (LValue='TRUE') or (LValue='YES') or
  (LValue='ON') or (LValue='HTTPS') or (LValue='SUCCESS') or
  (LValue='OK') or (LValue='VALID');
end;

function IsFalsyValue(const AValue: string): Boolean;
var
 LValue:string;
begin
 LValue:=UpperCase(Trim(AValue));
 Result:=(LValue='0') or (LValue='FALSE') or (LValue='NO') or
  (LValue='OFF') or (LValue='HTTP') or (LValue='NONE') or
  (LValue='FAIL') or (LValue='FAILED') or (LValue='INVALID');
end;

function JsonString(const AValue: string): string;
var
 i:Integer;
 ch:Char;
begin
 Result:='"';
 for i:=1 to Length(AValue) do
 begin
  ch:=AValue[i];
  case ch of
   '"':Result:=Result+'\"';
   '\':Result:=Result+'\\';
   '/':Result:=Result+'\/';
   #8:Result:=Result+'\b';
   #9:Result:=Result+'\t';
   #10:Result:=Result+'\n';
   #12:Result:=Result+'\f';
   #13:Result:=Result+'\r';
   else
    if Ord(ch)<32 then
     Result:=Result+'\u'+IntToHex(Ord(ch),4)
    else
     Result:=Result+ch;
  end;
 end;
 Result:=Result+'"';
end;

function LogString(const AValue: string): string;
begin
 Result:=StringReplace(AValue,'\','\\',[rfReplaceAll]);
 Result:=StringReplace(Result,'"','\"',[rfReplaceAll]);
 Result:=StringReplace(Result,#13,'\r',[rfReplaceAll]);
 Result:=StringReplace(Result,#10,'\n',[rfReplaceAll]);
end;

function CsvString(const AValue: string): string;
begin
 Result:=StringReplace(AValue,'"','""',[rfReplaceAll]);
 Result:='"'+Result+'"';
end;

function LogLineBreak: string;
begin
{$IFDEF MSWINDOWS}
 Result:=#13#10;
{$ENDIF}
{$IFDEF LINUX}
 Result:=#10;
{$ENDIF}
end;


procedure TRpWebPageLoader.ClearLists;
var
 i:integer;
begin
 laliases.clear;
 lusers.clear;
 lgroups.Clear;
 for i:=0 to LUserGroups.Count-1 do
 begin
  TStringList(LUserGroups.Objects[i]).free;
 end;
 LUserGroups.Clear;
 for i:=0 to LAliasGroups.Count-1 do
 begin
  TStringList(LAliasGroups.Objects[i]).Free;
 end;
 LAliasGroups.Clear;
 LServerApiKeys.Clear;
 LServerApiKeyUsers.Clear;
end;

function TRpWebPageLoader.GetRequestParam(Request: TWebRequest;
  const AName: string): string;
begin
 if Request.ContentFields.IndexOfName(AName)>=0 then
 begin
  Result:=Request.ContentFields.Values[AName];
  exit;
 end;
 if FUrlGetParams and (Request.QueryFields.IndexOfName(AName)>=0) then
 begin
  Result:=Request.QueryFields.Values[AName];
  exit;
 end;
 Result:='';
end;

function TRpWebPageLoader.GetAdminParam(Request: TWebRequest;
  const AName: string): string;
begin
 if Request.ContentFields.IndexOfName(AName)>=0 then
 begin
  Result:=Request.ContentFields.Values[AName];
  exit;
 end;
 if Request.QueryFields.IndexOfName(AName)>=0 then
 begin
  Result:=Request.QueryFields.Values[AName];
  exit;
 end;
 Result:='';
end;

function TRpWebPageLoader.CreateRequestParamList(Request: TWebRequest): TStringList;
var
 i:Integer;
begin
 Result:=TStringList.Create;
 Result.AddStrings(Request.ContentFields);
 if FUrlGetParams then
 begin
  for i:=0 to Request.QueryFields.Count-1 do
  begin
   if Request.ContentFields.IndexOfName(Request.QueryFields.Names[i])<0 then
    Result.Add(Request.QueryFields.Strings[i]);
  end;
 end;
end;

function TRpWebPageLoader.CreateAdminParamList(Request: TWebRequest): TStringList;
var
 i:Integer;
begin
 Result:=TStringList.Create;
 Result.AddStrings(Request.ContentFields);
 for i:=0 to Request.QueryFields.Count-1 do
 begin
  if Result.IndexOfName(Request.QueryFields.Names[i])<0 then
   Result.Add(Request.QueryFields.Strings[i]);
 end;
end;

function TRpWebPageLoader.HiddenInput(const AName, AValue: string): string;
begin
 Result:='<input type="hidden" name="'+HtmlEncode(AName)+'" value="'+
  HtmlEncode(AValue)+'">';
end;

function TRpWebPageLoader.HiddenAuthInputs(Request: TWebRequest): string;
begin
 Result:='';
 if HasServerApiKey(Request) then
  exit;
 Result:=HiddenInput('username',GetRequestParam(Request,'username'))+
  HiddenInput('password',GetRequestParam(Request,'password'));
end;

function TRpWebPageLoader.HiddenAdminAuthInputs(Request: TWebRequest): string;
begin
 Result:=HiddenInput('username',GetAdminParam(Request,'username'))+
  HiddenInput('password',GetAdminParam(Request,'password'));
end;

class function TRpWebPageLoader.RequestHasParam(Request: TWebRequest;
  const AName: string): Boolean;
begin
 Result:=(Request.ContentFields.IndexOfName(AName)>=0) or
  (Request.QueryFields.IndexOfName(AName)>=0);
end;

class function TRpWebPageLoader.RequestCheckboxChecked(Request: TWebRequest;
  const AName: string): Boolean;
begin
 Result:=RequestHasParam(Request,AName) and
  (Trim(Request.ContentFields.Values[AName]+Request.QueryFields.Values[AName])<>'');
end;

procedure TRpWebPageLoader.CollectAdminPrefixedValues(Request: TWebRequest;
  const APrefix: string; AValues: TStrings);
var
 LParams:TStringList;
 i:Integer;
 LName:string;
begin
 AValues.Clear;
 LParams:=CreateAdminParamList(Request);
 try
  for i:=0 to LParams.Count-1 do
  begin
   LName:=LParams.Names[i];
   if Pos(APrefix,LName)=1 then
    AValues.Add(Copy(LName,Length(APrefix)+1,Length(LName))+'=');
  end;
 finally
  LParams.Free;
 end;
end;

function TRpWebPageLoader.GetRequestHeader(Request: TWebRequest;
  const AName: string): string;
var
 CgiHeaderName:String;
begin
 Result:=Trim(Request.GetFieldByName(AName));
 if Length(Result)>0 then
  exit;
 CgiHeaderName:='HTTP_'+StringReplace(UpperCase(AName),'-','_',[rfReplaceAll]);
 Result:=Trim(Request.GetFieldByName(CgiHeaderName));
end;

function TRpWebPageLoader.GetRequestValue(Request: TWebRequest;
  const AName: string): string;
begin
 Result:=Trim(Request.GetFieldByName(AName));
end;

function TRpWebPageLoader.GetFirstRequestValue(Request: TWebRequest;
  const ANames: array of string): string;
var
 i:Integer;
begin
 Result:='';
 for i:=Low(ANames) to High(ANames) do
 begin
  Result:=GetRequestValue(Request,ANames[i]);
  if Length(Result)>0 then
   exit;
 end;
end;

function TRpWebPageLoader.GetRemoteAddr(Request: TWebRequest): string;
begin
 Result:=GetFirstRequestValue(Request,['REMOTE_ADDR','REMOTE_HOST','CLIENT_IP']);
end;

function TRpWebPageLoader.GetForwardedFor(Request: TWebRequest): string;
begin
 Result:=GetRequestHeader(Request,'X-Forwarded-For');
end;

function TRpWebPageLoader.IsSecureConnection(Request: TWebRequest): Boolean;
var
 LValue:string;
begin
 Result:=False;
 LValue:=GetFirstRequestValue(Request,['HTTPS','SERVER_PORT_SECURE']);
 if IsTruthyValue(LValue) then
 begin
  Result:=True;
  exit;
 end;
 if IsFalsyValue(LValue) then
  exit;

 LValue:=GetFirstRequestValue(Request,['REQUEST_SCHEME','URL_SCHEME']);
 if SameText(Trim(LValue),'HTTPS') then
 begin
  Result:=True;
  exit;
 end;

 LValue:=FirstToken(GetRequestHeader(Request,'X-Forwarded-Proto'));
 if SameText(LValue,'HTTPS') then
 begin
  Result:=True;
  exit;
 end;

 LValue:=GetRequestHeader(Request,'X-Forwarded-Ssl');
 if IsTruthyValue(LValue) then
 begin
  Result:=True;
  exit;
 end;

 LValue:=GetRequestHeader(Request,'Front-End-Https');
 if IsTruthyValue(LValue) then
 begin
  Result:=True;
  exit;
 end;
end;

function TRpWebPageLoader.GetConnectionType(Request: TWebRequest): string;
var
 LValue:string;
begin
 LValue:=GetFirstRequestValue(Request,['HTTPS']);
 if IsTruthyValue(LValue) then
 begin
  Result:='HTTPS';
  exit;
 end;
 if IsFalsyValue(LValue) then
 begin
  Result:='HTTP';
  exit;
 end;

 LValue:=GetFirstRequestValue(Request,['SERVER_PORT_SECURE']);
 if IsTruthyValue(LValue) then
 begin
  Result:='HTTPS';
  exit;
 end;

 LValue:=GetFirstRequestValue(Request,['REQUEST_SCHEME','URL_SCHEME']);
 if SameText(Trim(LValue),'HTTPS') then
 begin
  Result:='HTTPS';
  exit;
 end;
 if SameText(Trim(LValue),'HTTP') then
 begin
  Result:='HTTP';
  exit;
 end;

 LValue:=FirstToken(GetRequestHeader(Request,'X-Forwarded-Proto'));
 if SameText(LValue,'HTTPS') then
 begin
  Result:='HTTPS (forwarded)';
  exit;
 end;
 if SameText(LValue,'HTTP') then
 begin
  Result:='HTTP (forwarded)';
  exit;
 end;

 if IsTruthyValue(GetRequestHeader(Request,'X-Forwarded-Ssl')) or
   IsTruthyValue(GetRequestHeader(Request,'Front-End-Https')) then
 begin
  Result:='HTTPS (forwarded)';
  exit;
 end;

 Result:='Unknown';
end;

function TRpWebPageLoader.GetCertificateValidityText(Request: TWebRequest): string;
var
 LValue:string;
begin
 if not IsSecureConnection(Request) then
 begin
  Result:='No';
  exit;
 end;

 LValue:=GetFirstRequestValue(Request,['SSL_SERVER_VERIFY','CERT_SERVER_VERIFY',
  'SSL_VERIFY_RESULT','CERT_VERIFY_RESULT']);
 if Length(LValue)>0 then
 begin
  if IsTruthyValue(LValue) or (Trim(LValue)='0') then
   Result:='Yes'
  else
   Result:='No ('+LValue+')';
  exit;
 end;

 Result:='Unknown';
end;

procedure TRpWebPageLoader.CheckRequireHttps(Request: TWebRequest);
begin
 if not FRequireHttps then
  exit;
 if IsSecureConnection(Request) then
  exit;
 Raise EHttpError.CreateHttp(403,'HTTPS required',True);
end;

function TRpWebPageLoader.HasServerApiKey(Request: TWebRequest): Boolean;
begin
 Result:=Length(GetRequestHeader(Request,'X-ReportmanServer-ApiKey'))>0;
end;

function TRpWebPageLoader.GetServerApiKeyName(Request: TWebRequest): string;
var
 LApiKey:String;
 i:Integer;
begin
 Result:='';
 LApiKey:=GetRequestHeader(Request,'X-ReportmanServer-ApiKey');
 if Length(LApiKey)<1 then
  exit;
 for i:=0 to LServerApiKeys.Count-1 do
 begin
  if LServerApiKeys.ValueFromIndex[i]=LApiKey then
  begin
   Result:=Trim(LServerApiKeys.Names[i]);
   exit;
  end;
 end;
end;

function TRpWebPageLoader.ReportParamsToJson(AReport: TRpReport): string;
var
 i,k,LIndex:Integer;
 LParam:TRpParam;
 LValue:String;
begin
 Result:='{';
 for i:=0 to AReport.Params.Count-1 do
 begin
  if i>0 then
   Result:=Result+',';
  LParam:=AReport.Params.Items[i];
  Result:=Result+JsonString(LParam.Name)+':';
  if VarIsNull(LParam.Value) then
  begin
   Result:=Result+'null';
   continue;
  end;
  if LParam.ParamType=rpParamMultiple then
  begin
   Result:=Result+'[';
   for k:=0 to LParam.Selected.Count-1 do
   begin
    if k>0 then
     Result:=Result+',';
    LIndex:=StrToIntDef(LParam.Selected.Strings[k],-1);
    if (LIndex>=0) and (LIndex<LParam.Values.Count) then
     LValue:=LParam.Values.Strings[LIndex]
    else
     LValue:=LParam.Selected.Strings[k];
    Result:=Result+JsonString(LValue);
   end;
   Result:=Result+']';
  end
  else
   Result:=Result+JsonString(LParam.AsString);
 end;
 Result:=Result+'}';
end;

function TRpWebPageLoader.TryAuthenticateServerApiKey(Request: TWebRequest;
  out AUserName: string; out AIsAdmin: Boolean): Boolean;
var
 LApiKey:String;
 LApiKeyName:String;
 LMappedUser:String;
 i:Integer;
begin
 Result:=False;
 AUserName:='';
 AIsAdmin:=False;
 if not FAllowApiKeyAccess then
  exit;
 LApiKey:=GetRequestHeader(Request,'X-ReportmanServer-ApiKey');
 if Length(LApiKey)<1 then
  exit;
 for i:=0 to LServerApiKeys.Count-1 do
 begin
  LApiKeyName:=Trim(LServerApiKeys.Names[i]);
  if Length(LApiKeyName)<1 then
   continue;
  if LServerApiKeys.ValueFromIndex[i]=LApiKey then
  begin
   LMappedUser:=UpperCase(Trim(LServerApiKeyUsers.Values[LApiKeyName]));
   if Length(LMappedUser)<1 then
    Raise EHttpError.CreateHttp(401,
     TranslateStr(848,'Incorrect user name or password'),FShowUnauthorizedPage);
   if LUsers.IndexOfName(LMappedUser)<0 then
    Raise EHttpError.CreateHttp(401,
     TranslateStr(848,'Incorrect user name or password'),FShowUnauthorizedPage);
   AUserName:=LMappedUser;
   AIsAdmin:=AUserName='ADMIN';
   Result:=True;
   exit;
  end;
 end;
 Raise EHttpError.CreateHttp(401,
  TranslateStr(848,'Incorrect user name or password'),FShowUnauthorizedPage);
end;

function TRpWebPageLoader.TryAuthenticateUserPassword(Request: TWebRequest;
  out AUserName: string; out AIsAdmin: Boolean): Boolean;
var
 password:string;
 index:integer;
begin
 Result:=False;
 AUserName:='';
 AIsAdmin:=False;
 if not FAllowUserAccess then
  exit;
 AUserName:=UpperCase(GetRequestParam(Request,'username'));
 password:=GetRequestParam(Request,'password');
 if Length(AUserName)<1 then
  exit;
 index:=LUsers.IndexOfName(AUserName);
 if index>=0 then
 begin
  if LUsers.Values[AUserName]=password then
  begin
   AIsAdmin:=AUserName='ADMIN';
   Result:=True;
  end;
 end;
end;

procedure TRpWebPageLoader.ResolveAuthenticatedUser(Request: TWebRequest;
  out AUserName: string; out AIsAdmin: Boolean);
begin
 AUserName:='';
 AIsAdmin:=False;
 if HasServerApiKey(Request) then
 begin
  if TryAuthenticateServerApiKey(Request,AUserName,AIsAdmin) then
   exit;
 end;
 if TryAuthenticateUserPassword(Request,AUserName,AIsAdmin) then
  exit;
 Raise EHttpError.CreateHttp(401,
  TranslateStr(848,'Incorrect user name or password'),FShowUnauthorizedPage);
end;

function TRpWebPageLoader.TryAdminLogin(Request: TWebRequest; out AUserName,
  AMessageText: string): Boolean;
var
 LAuthResult:TRpWebAdminAuthResult;
begin
 LAuthResult:=TRpWebAdminAuthService.TryLogin(GetAdminParam(Request,'username'),
  GetAdminParam(Request,'password'));
 Result:=LAuthResult.Success;
 AUserName:=LAuthResult.UserName;
 AMessageText:=LAuthResult.MessageText;
end;

procedure TRpWebPageLoader.CheckAdminLogin(Request: TWebRequest;
  out AUserName: string; out AIsAdmin: Boolean);
var
 LMessage:string;
begin
 if not TryAdminLogin(Request,AUserName,LMessage) then
  Raise EHttpError.CreateHttp(401,LMessage,FShowUnauthorizedPage);
 AIsAdmin:=True;
end;

procedure TRpWebPageLoader.LoadAllGroupNames(AGroupNames: TStrings);
var
 LService:TRpWebServerConfigAdminService;
 LGroups:TList<TRpWebServerGroup>;
 i:Integer;
begin
 AGroupNames.Clear;
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LGroups:=TList<TRpWebServerGroup>.Create;
  try
   LService.ListGroups(LGroups);
   for i:=0 to LGroups.Count-1 do
    AGroupNames.Add(LGroups[i].GroupName+'='+LGroups[i].Description);
  finally
   LGroups.Free;
  end;
 finally
  LService.Free;
 end;
end;

procedure TRpWebPageLoader.LoadAllUserNames(AUserNames: TStrings);
var
 LService:TRpWebServerConfigAdminService;
 LUsers:TList<TRpWebServerUser>;
 i:Integer;
begin
 AUserNames.Clear;
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LUsers:=TList<TRpWebServerUser>.Create;
  try
   LService.ListUsers(LUsers);
   for i:=0 to LUsers.Count-1 do
   begin
    AUserNames.Add(LUsers[i].UserName+'=');
    LUsers[i].Clear;
   end;
  finally
   LUsers.Free;
  end;
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.CheckPrivileges(username,aliasname:String):Boolean;
var
 i,index:integer;
 lugroups:TStringList;
 lagroups:TStringList;
begin
 Result:=true;
 if username='ADMIN' then
  exit;
 index:=LUserGroups.IndexOf(username);
 if index<0 then
  Raise Exception.Create(SRpAuthFailed+' - '+username);
 lugroups:=TStringList(LUserGroups.Objects[index]);
 index:=LAliasGroups.IndexOf(aliasname);
 if index<0 then
  Raise Exception.Create(SRpAuthFailed+' - '+aliasname);
 lagroups:=TStringList(LAliasGroups.Objects[index]);
 if ((lagroups.Count>0) and (lugroups.Count>0)) then
 begin
  Result:=false;
  for i:=0 to lugroups.Count-1 do
  begin
   if lagroups.IndexOfName(lugroups.Names[i])>=0 then
   begin
    Result:=true;
    break;
   end;
  end;
 end;
end;

procedure TRpWebPageLoader.CheckLogin(Request:TWebRequest);
var
 username:string;
 aliasname:String;
 aisadmin:Boolean;
begin
 CheckRequireHttps(Request);
 ResolveAuthenticatedUser(Request,username,aisadmin);
 isadmin:=aisadmin;
 aliasname:=GetRequestParam(Request,'aliasname');
 if Length(aliasname)>0 then
 begin
  if not CheckPrivileges(username,aliasname) then
   Raise Exception.Create(TranslateStr(848,'Incorrect user name or password'));
 end;
end;

procedure TRpWebPageLoader.CheckInitReaded;
begin
 if not initreaded then
  Raise Exception.Create(TranslateStr(839,'Configuration file error')+
   '-'+InitErrorMessage+' - '+FFileNameConfig);
end;



function TRpWebPageLoader.LoadLoginPage(Request: TWebRequest):string;
var
 astring:String;
begin
 if not FAllowUserAccess then
 begin
  Result:='<html><body><h3>'+HtmlEncode(TranslateStr(838,'Report Manager Login'))+
   '</h3><p>User/password access disabled. Use X-ReportmanServer-ApiKey header.</p></body></html>';
  exit;
 end;
 if Length(FPagesDirectory)<1 then
 begin
  astring:=loginpage;
  if FUrlGetParams then
   astring:=StringReplace(astring,'method="post"','method="get"',[rfReplaceAll]);
 end
 else
 begin
  if FUrlGetParams then
   aresult.LoadFromFile(FPagesDirectory+'rplogin_get.html')
  else
   aresult.LoadFromFile(FPagesDirectory+'rplogin.html');
  astring:=aresult.Text;
 end;
 // Substitute translations
 astring:=StringReplace(astring,REPMAN_LOGIN_LABEL,
  TranslateStr(838,'Report Manager Login'),[rfReplaceAll]);
 astring:=StringReplace(astring,REPMAN_USER_LABEL,
  TranslateStr(751,'User Name'),[rfReplaceAll]);
 astring:=StringReplace(astring,REPMAN_PASSWORD_LABEL,
  TranslateStr(752,'Password'),[rfReplaceAll]);
 astring:=StringReplace(astring,REPMAN_WEBSERVER,
  TranslateStr(837,'Report Manager Web Server'),[rfReplaceAll]);

 Result:=astring;
end;

function TRpWebPageLoader.LoadIndexPage(Request: TWebRequest):string;
var
 astring,username:String;
 aliasesstring:String;
 i:integer;
 LisAdmin:Boolean;
begin
 ResolveAuthenticatedUser(Request,username,LisAdmin);
 if Length(FPagesDirectory)<1 then
 begin
  astring:=indexpage;
 end
 else
 begin
  if FUrlGetParams then
   aresult.LoadFromFile(FPagesDirectory+'rpindex_get.html')
  else
   aresult.LoadFromFile(FPagesDirectory+'rpindex.html');
  astring:=aresult.Text;
 end;
 astring:=StringReplace(astring,REPMAN_WEBSERVER,
  TranslateStr(837,'Report Manager Web Server'),[rfReplaceAll]);
 astring:=StringReplace(astring,REPMAN_INDEX_LABEL,
  TranslateStr(846,'Report Manager Index'),[rfReplaceAll]);

 aliasesstring:=TranslateStr(847,'Available Report Groups');
 for i:=0 to laliases.Count-1 do
 begin
  if CheckPrivileges(username,laliases.Names[i]) then
    begin
     if FUrlGetParams then
      aliasesstring:=aliasesstring+#10+'<p><a href="./showalias?aliasname='+
       laliases.Names[i]+'&'+Request.Query+'">'+laliases.Names[i]+'</a></p>'
     else
      aliasesstring:=aliasesstring+#10+'<form method="post" action="./showalias">'+
       HiddenInput('aliasname',laliases.Names[i])+HiddenAuthInputs(Request)+
       '<input type="submit" value="'+HtmlEncode(laliases.Names[i])+'">'+
       '</form>';
    end;
 end;

 astring:=StringReplace(astring,REPMAN_AVAILABLE_ALIASES,
  aliasesstring,[rfReplaceAll]);

 Result:=astring;
end;

function TRpWebPageLoader.LoadAdminBootstrapPage(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
begin
 LService:=TRpWebServerConfigAdminService.Create;
 try
  if not LService.BootstrapRequired then
   Result:=TRpWebAdminPageRenderer.RenderAdminLoginPage(
    'Bootstrap is no longer required')
  else
   Result:=TRpWebAdminPageRenderer.RenderBootstrapPage('');
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminBootstrap(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
 LBootstrap:TRpWebBootstrapRequest;
begin
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LBootstrap.UserName:=GetAdminParam(Request,'bootstrap_user');
  LBootstrap.Password:=GetAdminParam(Request,'bootstrap_password');
  LBootstrap.ConfirmPassword:=GetAdminParam(Request,'bootstrap_password_confirm');
  try
   LService.BootstrapFirstAdmin(LBootstrap);
   InitConfig;
   Result:=TRpWebAdminPageRenderer.RenderAdminLoginPage(
    'ADMIN bootstrap completed. Log in now.');
  except
   on E:Exception do
    Result:=TRpWebAdminPageRenderer.RenderBootstrapPage(E.Message);
  end;
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.LoadAdminLoginPage(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
begin
 LService:=TRpWebServerConfigAdminService.Create;
 try
  if LService.BootstrapRequired then
   Result:=TRpWebAdminPageRenderer.RenderBootstrapPage('')
  else
   Result:=TRpWebAdminPageRenderer.RenderAdminLoginPage('');
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminLogin(Request: TWebRequest): string;
var
 LUserName,LMessage:string;
begin
 if TryAdminLogin(Request,LUserName,LMessage) then
  Result:=LoadAdminHomePage(Request)
 else
  Result:=TRpWebAdminPageRenderer.RenderAdminLoginPage(LMessage);
end;

function TRpWebPageLoader.LoadAdminHomePage(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
 LUserName,LMessage:string;
begin
 LService:=TRpWebServerConfigAdminService.Create;
 try
  if LService.BootstrapRequired then
  begin
   Result:=TRpWebAdminPageRenderer.RenderBootstrapPage('');
   exit;
  end;
  if not TryAdminLogin(Request,LUserName,LMessage) then
  begin
   Result:=TRpWebAdminPageRenderer.RenderAdminLoginPage(LMessage);
   exit;
  end;
  Result:=TRpWebAdminPageRenderer.RenderAdminHome(LService.GetConfigInfo,
   HiddenAdminAuthInputs(Request));
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.LoadAdminServerConfigPage(Request: TWebRequest;
  const AMessageText: string): string;
var
 LService:TRpWebServerConfigAdminService;
 LUserName:string;
 LIsAdmin:Boolean;
begin
 CheckAdminLogin(Request,LUserName,LIsAdmin);
 LService:=TRpWebServerConfigAdminService.Create;
 try
  Result:=TRpWebAdminPageRenderer.RenderServerConfig(
   LService.LoadServerConfigFormData,HiddenAdminAuthInputs(Request),
   AMessageText);
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminServerConfigSave(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
 LData:TRpWebServerConfigFormData;
begin
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LData.PagesDir:=GetAdminParam(Request,'cfg_pagesdir');
  LData.TcpPort:=GetAdminParam(Request,'cfg_tcpport');
  LData.LogFile:=GetAdminParam(Request,'cfg_logfile');
  LData.LogJson:=RequestCheckboxChecked(Request,'cfg_log_json');
  LData.UserAccess:=RequestCheckboxChecked(Request,'cfg_user_access');
  LData.ApiKeyAccess:=RequestCheckboxChecked(Request,'cfg_api_key_access');
  LData.ShowUnauthorizedPage:=RequestCheckboxChecked(Request,
   'cfg_show_unauthorized');
  LData.RequireHttps:=RequestCheckboxChecked(Request,'cfg_require_https');
  LData.UrlGetParams:=RequestCheckboxChecked(Request,'cfg_url_get_params');
  try
   LService.SaveServerConfigFormData(LData);
   InitConfig;
   Result:=LoadAdminServerConfigPage(Request,'Server config saved');
  except
   on E:Exception do
    Result:=TRpWebAdminPageRenderer.RenderServerConfig(LData,
     HiddenAdminAuthInputs(Request),E.Message);
  end;
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.LoadAdminUsersPage(Request: TWebRequest;
  const AMessageText: string): string;
var
 LService:TRpWebServerConfigAdminService;
 LUsers:TList<TRpWebServerUser>;
 LUserName:string;
 LIsAdmin:Boolean;
 i:Integer;
begin
 CheckAdminLogin(Request,LUserName,LIsAdmin);
 LService:=TRpWebServerConfigAdminService.Create;
 LUsers:=TList<TRpWebServerUser>.Create;
 try
  LService.ListUsers(LUsers);
  Result:=TRpWebAdminPageRenderer.RenderUsersList(LUsers,
   HiddenAdminAuthInputs(Request),AMessageText);
 finally
  for i:=0 to LUsers.Count-1 do
   LUsers[i].Clear;
  LUsers.Free;
  LService.Free;
 end;
end;

function TRpWebPageLoader.LoadAdminUserEditPage(Request: TWebRequest;
  const AMessageText: string): string;
var
 LService:TRpWebServerConfigAdminService;
 LRequest:TRpWebUserEditRequest;
 LGroupNames:TStringList;
 LName,LUserName:string;
 LIsAdmin,IsNew:Boolean;
begin
 CheckAdminLogin(Request,LUserName,LIsAdmin);
 LService:=TRpWebServerConfigAdminService.Create;
 LGroupNames:=TStringList.Create;
 try
  LName:=GetAdminParam(Request,'name');
  IsNew:=Length(Trim(LName))=0;
  if IsNew then
   LRequest:=TRpWebUserEditRequest.Create
  else
   LRequest:=LService.LoadUserEditRequest(LName);
  try
   LoadAllGroupNames(LGroupNames);
   Result:=TRpWebAdminPageRenderer.RenderUserEdit(LRequest,LGroupNames,IsNew,
    HiddenAdminAuthInputs(Request),AMessageText);
  finally
   LRequest.Clear;
  end;
 finally
  LGroupNames.Free;
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminUserCreate(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
 LRequest:TRpWebUserEditRequest;
begin
 if not RequestHasParam(Request,'user_name') then
 begin
  Result:=LoadAdminUserEditPage(Request);
  exit;
 end;
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LRequest:=TRpWebUserEditRequest.Create;
  try
   LRequest.UserName:=GetAdminParam(Request,'user_name');
   LRequest.Password:=GetAdminParam(Request,'user_password');
   LRequest.ConfirmPassword:=GetAdminParam(Request,'user_password_confirm');
   LRequest.ChangePassword:=True;
   LRequest.IsAdmin:=RequestCheckboxChecked(Request,'is_admin');
   CollectAdminPrefixedValues(Request,'group_',LRequest.Groups);
   try
    LService.SaveUserEditRequest(LRequest,True);
    InitConfig;
    Result:=LoadAdminUsersPage(Request,'User created');
   except
    on E:Exception do
     Result:=LoadAdminUserEditPage(Request,E.Message);
   end;
  finally
   LRequest.Clear;
  end;
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminUserSave(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
 LRequest:TRpWebUserEditRequest;
begin
 if not RequestHasParam(Request,'user_name') then
 begin
  Result:=LoadAdminUserEditPage(Request);
  exit;
 end;
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LRequest:=TRpWebUserEditRequest.Create;
  try
   LRequest.OriginalUserName:=GetAdminParam(Request,'original_user_name');
   LRequest.UserName:=GetAdminParam(Request,'user_name');
   LRequest.Password:=GetAdminParam(Request,'user_password');
   LRequest.ConfirmPassword:=GetAdminParam(Request,'user_password_confirm');
   LRequest.ChangePassword:=RequestCheckboxChecked(Request,'change_password');
   LRequest.IsAdmin:=RequestCheckboxChecked(Request,'is_admin');
   CollectAdminPrefixedValues(Request,'group_',LRequest.Groups);
   try
    LService.SaveUserEditRequest(LRequest,False);
    InitConfig;
    Result:=LoadAdminUsersPage(Request,'User saved');
   except
    on E:Exception do
     Result:=LoadAdminUserEditPage(Request,E.Message);
   end;
  finally
   LRequest.Clear;
  end;
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminUserDelete(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
 LReason:string;
begin
 LService:=TRpWebServerConfigAdminService.Create;
 try
  if not LService.CanDeleteUser(GetAdminParam(Request,'name'),LReason) then
   Result:=LoadAdminUsersPage(Request,LReason)
  else
  begin
   LService.DeleteUser(GetAdminParam(Request,'name'));
   InitConfig;
   Result:=LoadAdminUsersPage(Request,'User deleted');
  end;
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.LoadAdminGroupsPage(Request: TWebRequest;
  const AMessageText: string): string;
var
 LService:TRpWebServerConfigAdminService;
 LGroups:TList<TRpWebServerGroup>;
 LUserName:string;
 LIsAdmin:Boolean;
begin
 CheckAdminLogin(Request,LUserName,LIsAdmin);
 LService:=TRpWebServerConfigAdminService.Create;
 LGroups:=TList<TRpWebServerGroup>.Create;
 try
  LService.ListGroups(LGroups);
  Result:=TRpWebAdminPageRenderer.RenderGroupsList(LGroups,
   HiddenAdminAuthInputs(Request),AMessageText);
 finally
  LGroups.Free;
  LService.Free;
 end;
end;

function TRpWebPageLoader.LoadAdminGroupEditPage(Request: TWebRequest;
  const AMessageText: string): string;
var
 LRequest:TRpWebGroupEditRequest;
 LService:TRpWebServerConfigAdminService;
 LName,LUserName:string;
 LIsAdmin:Boolean;
begin
 CheckAdminLogin(Request,LUserName,LIsAdmin);
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LName:=GetAdminParam(Request,'name');
  if Length(Trim(LName))>0 then
   LRequest:=LService.LoadGroupEditRequest(LName)
  else
  begin
   LRequest.OriginalGroupName:='';
   LRequest.GroupName:='';
   LRequest.Description:='';
  end;
  Result:=TRpWebAdminPageRenderer.RenderGroupEdit(LRequest,
   Length(Trim(LName))=0,HiddenAdminAuthInputs(Request),AMessageText);
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminGroupCreate(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
 LRequest:TRpWebGroupEditRequest;
begin
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LRequest.OriginalGroupName:='';
  LRequest.GroupName:=GetAdminParam(Request,'group_name');
  LRequest.Description:=GetAdminParam(Request,'group_description');
  try
   LService.SaveGroupEditRequest(LRequest,True);
   InitConfig;
   Result:=LoadAdminGroupsPage(Request,'Group created');
  except
   on E:Exception do
    Result:=LoadAdminGroupsPage(Request,E.Message);
  end;
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminGroupSave(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
 LRequest:TRpWebGroupEditRequest;
begin
 if not RequestHasParam(Request,'group_name') then
 begin
  Result:=LoadAdminGroupEditPage(Request);
  exit;
 end;
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LRequest.OriginalGroupName:=GetAdminParam(Request,'original_group_name');
  LRequest.GroupName:=GetAdminParam(Request,'group_name');
  LRequest.Description:=GetAdminParam(Request,'group_description');
  try
   LService.SaveGroupEditRequest(LRequest,False);
   InitConfig;
   Result:=LoadAdminGroupsPage(Request,'Group saved');
  except
   on E:Exception do
    Result:=LoadAdminGroupEditPage(Request,E.Message);
  end;
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminGroupDelete(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
begin
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LService.DeleteGroup(GetAdminParam(Request,'name'));
  InitConfig;
  Result:=LoadAdminGroupsPage(Request,'Group deleted');
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.LoadAdminAliasesPage(Request: TWebRequest;
  const AMessageText: string): string;
var
 LService:TRpWebServerConfigAdminService;
 LAliases:TList<TRpWebServerAlias>;
 LUserName:string;
 LIsAdmin:Boolean;
 i:Integer;
begin
 CheckAdminLogin(Request,LUserName,LIsAdmin);
 LService:=TRpWebServerConfigAdminService.Create;
 LAliases:=TList<TRpWebServerAlias>.Create;
 try
  LService.ListAliases(LAliases);
  Result:=TRpWebAdminPageRenderer.RenderAliasesList(LAliases,
   HiddenAdminAuthInputs(Request),AMessageText);
 finally
  for i:=0 to LAliases.Count-1 do
   LAliases[i].Clear;
  LAliases.Free;
  LService.Free;
 end;
end;

function TRpWebPageLoader.LoadAdminAliasEditPage(Request: TWebRequest;
  const AMessageText: string): string;
var
 LService:TRpWebServerConfigAdminService;
 LRequest:TRpWebAliasEditRequest;
 LGroupNames:TStringList;
 LName,LUserName:string;
 LIsAdmin,IsNew:Boolean;
begin
 CheckAdminLogin(Request,LUserName,LIsAdmin);
 LService:=TRpWebServerConfigAdminService.Create;
 LGroupNames:=TStringList.Create;
 try
  LName:=GetAdminParam(Request,'name');
  IsNew:=Length(Trim(LName))=0;
  if IsNew then
   LRequest:=TRpWebAliasEditRequest.Create
  else
   LRequest:=LService.LoadAliasEditRequest(LName);
  try
   LoadAllGroupNames(LGroupNames);
   Result:=TRpWebAdminPageRenderer.RenderAliasEdit(LRequest,LGroupNames,IsNew,
    HiddenAdminAuthInputs(Request),AMessageText);
  finally
   LRequest.Clear;
  end;
 finally
  LGroupNames.Free;
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminAliasCreate(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
 LRequest:TRpWebAliasEditRequest;
begin
 if not RequestHasParam(Request,'alias_name') then
 begin
  Result:=LoadAdminAliasEditPage(Request);
  exit;
 end;
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LRequest:=TRpWebAliasEditRequest.Create;
  try
   LRequest.AliasName:=GetAdminParam(Request,'alias_name');
   if SameText(GetAdminParam(Request,'alias_type'),'connection') then
    LRequest.AliasType:=watConnection
   else
    LRequest.AliasType:=watFolder;
   LRequest.TargetValue:=GetAdminParam(Request,'alias_target');
   CollectAdminPrefixedValues(Request,'group_',LRequest.AllowedGroups);
   try
    LService.SaveAliasEditRequest(LRequest,True);
    InitConfig;
    Result:=LoadAdminAliasesPage(Request,'Alias created');
   except
    on E:Exception do
     Result:=LoadAdminAliasEditPage(Request,E.Message);
   end;
  finally
   LRequest.Clear;
  end;
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminAliasSave(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
 LRequest:TRpWebAliasEditRequest;
begin
 if not RequestHasParam(Request,'alias_name') then
 begin
  Result:=LoadAdminAliasEditPage(Request);
  exit;
 end;
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LRequest:=TRpWebAliasEditRequest.Create;
  try
   LRequest.OriginalAliasName:=GetAdminParam(Request,'original_alias_name');
   LRequest.AliasName:=GetAdminParam(Request,'alias_name');
   if SameText(GetAdminParam(Request,'alias_type'),'connection') then
    LRequest.AliasType:=watConnection
   else
    LRequest.AliasType:=watFolder;
   LRequest.TargetValue:=GetAdminParam(Request,'alias_target');
   CollectAdminPrefixedValues(Request,'group_',LRequest.AllowedGroups);
   try
    LService.SaveAliasEditRequest(LRequest,False);
    InitConfig;
    Result:=LoadAdminAliasesPage(Request,'Alias saved');
   except
    on E:Exception do
     Result:=LoadAdminAliasEditPage(Request,E.Message);
   end;
  finally
   LRequest.Clear;
  end;
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminAliasDelete(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
begin
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LService.DeleteAlias(GetAdminParam(Request,'name'));
  InitConfig;
  Result:=LoadAdminAliasesPage(Request,'Alias deleted');
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.LoadAdminApiKeysPage(Request: TWebRequest;
  const AMessageText: string): string;
var
 LService:TRpWebServerConfigAdminService;
 LKeys:TList<TRpWebServerApiKey>;
 LUsers:TStringList;
 LUserName:string;
 LIsAdmin:Boolean;
begin
 CheckAdminLogin(Request,LUserName,LIsAdmin);
 LService:=TRpWebServerConfigAdminService.Create;
 LKeys:=TList<TRpWebServerApiKey>.Create;
 LUsers:=TStringList.Create;
 try
  LService.ListApiKeys(LKeys);
  LoadAllUserNames(LUsers);
  Result:=TRpWebAdminPageRenderer.RenderApiKeysList(LKeys,LUsers,
   HiddenAdminAuthInputs(Request),AMessageText);
 finally
  LUsers.Free;
  LKeys.Free;
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminApiKeyCreate(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
 LRequest:TRpWebApiKeyCreateRequest;
 LResult:TRpWebGeneratedApiKeyResult;
begin
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LRequest.KeyName:=GetAdminParam(Request,'api_key_name');
  LRequest.UserName:=GetAdminParam(Request,'api_key_user');
  try
   LResult:=LService.SaveApiKeyCreateRequest(LRequest);
   InitConfig;
   Result:=TRpWebAdminPageRenderer.RenderApiKeyCreated(LResult,
    HiddenAdminAuthInputs(Request));
  except
   on E:Exception do
    Result:=LoadAdminApiKeysPage(Request,E.Message);
  end;
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.ExecuteAdminApiKeyDelete(Request: TWebRequest): string;
var
 LService:TRpWebServerConfigAdminService;
begin
 LService:=TRpWebServerConfigAdminService.Create;
 try
  LService.DeleteApiKey(GetAdminParam(Request,'name'));
  InitConfig;
  Result:=LoadAdminApiKeysPage(Request,'API key deleted');
 finally
  LService.Free;
 end;
end;

function TRpWebPageLoader.LoadAdminDiagnosticsPage(Request: TWebRequest;
  const AMessageText: string): string;
var
 LService:TRpWebServerConfigAdminService;
 LUserName:string;
 LIsAdmin:Boolean;
begin
 CheckAdminLogin(Request,LUserName,LIsAdmin);
 LService:=TRpWebServerConfigAdminService.Create;
 try
  Result:=TRpWebAdminPageRenderer.RenderDiagnostics(LService.GetConfigInfo,
   HiddenAdminAuthInputs(Request),AMessageText);
 finally
  LService.Free;
 end;
end;

{$IFDEF MSWINDOWS}
function GetCurrentUserName : string;
const
  cnMaxUserNameLen = 254;
var
  sUserName     : string;
  dwUserNameLen : DWORD;
begin
  dwUserNameLen := cnMaxUserNameLen-1;
  SetLength( sUserName, cnMaxUserNameLen );
  GetUserName(
    PChar( sUserName ),
    dwUserNameLen );
  SetLength( sUserName, dwUserNameLen );
  Result := sUserName;
end;
{$ENDIF}


procedure TRpWebPageLoader.GetWebPage(Request: TWebRequest;apage:TRpWebPage;
 Response:TWebResponse);
var
 astring:string;
 atemp:string;
 i:integer;
 ConAdmin:TRpConnAdmin;
 memstream:TMemoryStream;
begin
 try
  CheckInitReaded;
  if apage<>rpwVersion then
   CheckRequireHttps(Request);
  if Not (apage in [rpwVersion,rpwLogin]) then
   CheckLogin(Request);
  case apage of
   rpwVersion:
    begin
     astring:='<html><body>'+TranslateStr(837,'Report Manager Web Server')+#10+
      '<p></p>'+TranslateStr(91,'Version')+' '+RM_VERSION+#10+'<p></p>'+
      TranslateStr(743,'Configuration File')+': '+HtmlEncode(Ffilenameconfig);
     if Length(FLogFileName)>0 then
      astring:=astring+'<p>[CONFIG]LOGFILE='+
       HtmlEncode(ExpandFileName(FLogFileName))+'</p>'
     else
      astring:=astring+'<p>[CONFIG]LOGFILE=</p>';
     astring:=astring+'<p>[CONFIG]LOG_JSON='+
      HtmlEncode(BoolToStr(FLogJson,True))+'</p>';
     if Length(FJsonLogFilename)>0 then
      astring:=astring+'<p>JSON Log File='+
       HtmlEncode(ExpandFileName(FJsonLogFilename))+'</p>'
     else
      astring:=astring+'<p>JSON Log File=</p>';

     if Length(LogFileErrorMessage)>0 then
     begin
      astring:=astring+'<p>'+HtmlEncode(LogFileErrorMessage)+'</p>';
     end;
     // Configuration
     astring:=astring+'<p>[CONFIG]PAGESDIR='+HtmlEncode(FPagesDirectory)+'</p>';
    astring:=astring+'<p>[SECURITY]USER_ACCESS='+HtmlEncode(BoolToStr(FAllowUserAccess,True))+'</p>';
    astring:=astring+'<p>[SECURITY]API_KEY_ACCESS='+HtmlEncode(BoolToStr(FAllowApiKeyAccess,True))+'</p>';
    astring:=astring+'<p>[SECURITY]REQUIRE_HTTPS='+HtmlEncode(BoolToStr(FRequireHttps,True))+'</p>';
    astring:=astring+'<p>[SECURITY]SHOWUNAUTHORIZEDPAGE='+HtmlEncode(BoolToStr(FShowUnauthorizedPage,True))+'</p>';
    astring:=astring+'<p>[SECURITY]URLGETPARAMS='+HtmlEncode(BoolToStr(FUrlGetParams,True))+'</p>';
    astring:=astring+'<p>Connection type='+HtmlEncode(GetConnectionType(Request))+'</p>';
    astring:=astring+'<p>Connection secure='+HtmlEncode(BoolToStr(IsSecureConnection(Request),True))+'</p>';
    atemp:=GetFirstRequestValue(Request,['SSL_PROTOCOL','HTTPS_PROTOCOL']);
    if Length(atemp)>0 then
     astring:=astring+'<p>TLS protocol='+HtmlEncode(atemp)+'</p>';
    atemp:=GetFirstRequestValue(Request,['SSL_CIPHER','HTTPS_CIPHER']);
    if Length(atemp)>0 then
     astring:=astring+'<p>TLS cipher='+HtmlEncode(atemp)+'</p>';
    atemp:=GetFirstRequestValue(Request,['SSL_CIPHER_USEKEYSIZE','HTTPS_KEYSIZE']);
    if Length(atemp)>0 then
     astring:=astring+'<p>TLS key size='+HtmlEncode(atemp)+'</p>';
    atemp:=GetFirstRequestValue(Request,['SSL_SERVER_S_DN','CERT_SUBJECT']);
    if Length(atemp)>0 then
     astring:=astring+'<p>Certificate subject='+HtmlEncode(atemp)+'</p>';
    atemp:=GetFirstRequestValue(Request,['SSL_SERVER_I_DN','CERT_ISSUER']);
    if Length(atemp)>0 then
     astring:=astring+'<p>Certificate issuer='+HtmlEncode(atemp)+'</p>';
    atemp:=GetFirstRequestValue(Request,['CERT_SERIALNUMBER','SSL_SERVER_M_SERIAL']);
    if Length(atemp)>0 then
     astring:=astring+'<p>Certificate serial='+HtmlEncode(atemp)+'</p>';
    atemp:=GetFirstRequestValue(Request,['SSL_SERVER_V_START','CERT_VALIDFROM']);
    if Length(atemp)>0 then
     astring:=astring+'<p>Certificate valid from='+HtmlEncode(atemp)+'</p>';
    atemp:=GetFirstRequestValue(Request,['SSL_SERVER_V_END','CERT_VALIDUNTIL']);
    if Length(atemp)>0 then
     astring:=astring+'<p>Certificate valid until='+HtmlEncode(atemp)+'</p>';
    atemp:=GetFirstRequestValue(Request,['SSL_SERVER_VERIFY','CERT_SERVER_VERIFY',
     'SSL_VERIFY_RESULT','CERT_VERIFY_RESULT']);
    if Length(atemp)>0 then
     astring:=astring+'<p>Certificate verify raw='+HtmlEncode(atemp)+'</p>';
    astring:=astring+'<p>Certificate valid='+HtmlEncode(GetCertificateValidityText(Request))+'</p>';
     astring:=astring+'<p>Configured libs:<br/>';
     // Configured libs
     for i:=0 to FRpAliasLibs.Connections.Count-1 do
     begin
      astring:=astring+HtmlEncode(FRpAliasLibs.Connections.Items[i].Alias)+'<br/>';
     end;
     astring:=astring+'</p>';
     try
      ConAdmin:=TRpConnAdmin.Create;
      try
       astring:=astring+'<p>[DBXCONNECTIONS]='+
        HtmlEncode(ConAdmin.configfilename)+'</p>';
       try
        memstream:=TMemoryStream.Create;
        try
         memstream.LoadFromFile(ConAdmin.configfilename);
        finally
         memstream.free;
        end;
        astring:=astring+'<p>DBXConnections accessibility ok'+'</p>';
       except
        On E:Exception do
        begin
         astring:=astring+'<p>DBXConnections accessibility error:'+
          HtmlEncode(E.Message)+'</p>';
        end;
       end;
      finally
       ConAdmin.Free;
      end;
     except
      on E:Exception do
      begin
       astring:=astring+'<p><b>DBXConnections accessibility error:'+
        HtmlEncode(E.Message)+'</b></p>';
      end;
     end;
     astring:=astring+'</p>';
     astring:=astring+'<p>Decimal separator:'+FormatSettings.DecimalSeparator+'</p>';
     astring:=astring+'<p>Thousand separator:'+FormatSettings.ThousandSeparator+'</p>';
     // Environment variables
     atemp:=GetEnvironmentVariable('LANG');
     astring:=astring+'<p>LANG='+atemp+'</p>';
     atemp:=GetEnvironmentVariable('OLD_LC_NUMERIC');
     astring:=astring+'<p>OLD_LC_NUMERIC='+atemp+'</p>';
     atemp:=GetEnvironmentVariable('LC_NUMERIC');
     astring:=astring+'<p>LC_NUMERIC='+atemp+'</p>';
     atemp:=GetEnvironmentVariable('KYLIX_DEFINEDENVLOCALES');
     astring:=astring+'<p>KYLIX_DEFINEDENVLOCALES='+atemp+'</p>';
     atemp:=GetEnvironmentVariable('KYLIX_THOUSAND_SEPARATOR');
     astring:=astring+'<p>KYLIX_THOUSAND_SEPARATOR='+atemp+'</p>';
     atemp:=GetEnvironmentVariable('KYLIX_DECIMAL_SEPARATOR');
     astring:=astring+'<p>KYLIX_DECIMAL_SEPARATOR='+atemp+'</p>';
     atemp:=GetEnvironmentVariable('KYLIX_DATE_SEPARATOR');
     astring:=astring+'<p>KYLIX_DATE_SEPARATOR='+atemp+'</p>';
     atemp:=GetEnvironmentVariable('KYLIX_TIME_SEPARATOR');
     astring:=astring+'<p>KYLIX_TIME_SEPARATOR='+atemp+'</p>';
     atemp:=GetEnvironmentVariable('USERNAME');
     astring:=astring+'<p>USERNAME='+atemp+'</p>';
     astring:=astring+'</body></html>';
{$IFDEF MSWINDOWS}
     atemp:=GetCurrentUserName;
     astring:=astring+'<p>Current user='+atemp+'</p>';
{$ENDIF}
     astring:=astring+'</body></html>';
     Response.Content:=astring;
    end;
   rpwLogin:
    begin
     astring:=LoadLoginPage(Request);
     Response.Content:=astring;
    end;
   rpwIndex:
    begin
     astring:=LoadIndexPage(Request);
     Response.Content:=astring;
    end;
   rpwShowAlias:
    begin
     astring:=LoadAliasPage(Request);
     Response.Content:=astring;
    end;
   rpwShowParams:
    begin
     astring:=LoadParamsPage(Request);
     if Length(astring)<1 then
      ExecuteReport(Request,Response)
     else
      Response.Content:=astring;
    end;
  end;
 except
    On E:EHttpError do
    begin
     Response.StatusCode:=E.StatusCode;
     Response.Content:=GenerateError(E);
    end;
  On E:Exception do
  begin
   Response.Content:=GenerateError(E);
  end;
 end;
end;

procedure TRpWebPageLoader.HandleAdminRequest(Request: TWebRequest;
 Response:TWebResponse);
var
 LPath:string;
begin
 try
  CheckInitReaded;
  CheckRequireHttps(Request);
  LPath:=LowerCase(Request.PathInfo);
  if LPath='/admin' then
   Response.Content:=LoadAdminHomePage(Request)
  else if LPath='/admin/bootstrap' then
  begin
   if Request.MethodType=mtPost then
    Response.Content:=ExecuteAdminBootstrap(Request)
   else
    Response.Content:=LoadAdminBootstrapPage(Request);
  end
  else if LPath='/admin/login' then
  begin
   if Request.MethodType=mtPost then
    Response.Content:=ExecuteAdminLogin(Request)
   else
    Response.Content:=LoadAdminLoginPage(Request);
  end
  else if LPath='/admin/server-config' then
  begin
   if RequestHasParam(Request,'cfg_tcpport') or
    RequestHasParam(Request,'cfg_pagesdir') or
    RequestHasParam(Request,'cfg_logfile') then
    Response.Content:=ExecuteAdminServerConfigSave(Request)
   else
    Response.Content:=LoadAdminServerConfigPage(Request);
  end
  else if LPath='/admin/users' then
   Response.Content:=LoadAdminUsersPage(Request)
  else if LPath='/admin/users/new' then
   Response.Content:=ExecuteAdminUserCreate(Request)
  else if LPath='/admin/users/edit' then
   Response.Content:=ExecuteAdminUserSave(Request)
  else if LPath='/admin/users/delete' then
   Response.Content:=ExecuteAdminUserDelete(Request)
  else if LPath='/admin/groups' then
   Response.Content:=LoadAdminGroupsPage(Request)
  else if LPath='/admin/groups/new' then
   Response.Content:=ExecuteAdminGroupCreate(Request)
  else if LPath='/admin/groups/edit' then
   Response.Content:=ExecuteAdminGroupSave(Request)
  else if LPath='/admin/groups/delete' then
   Response.Content:=ExecuteAdminGroupDelete(Request)
  else if LPath='/admin/aliases' then
   Response.Content:=LoadAdminAliasesPage(Request)
  else if LPath='/admin/aliases/new' then
   Response.Content:=ExecuteAdminAliasCreate(Request)
  else if LPath='/admin/aliases/edit' then
   Response.Content:=ExecuteAdminAliasSave(Request)
  else if LPath='/admin/aliases/delete' then
   Response.Content:=ExecuteAdminAliasDelete(Request)
  else if LPath='/admin/apikeys' then
   Response.Content:=LoadAdminApiKeysPage(Request)
  else if LPath='/admin/apikeys/new' then
   Response.Content:=ExecuteAdminApiKeyCreate(Request)
  else if LPath='/admin/apikeys/delete' then
   Response.Content:=ExecuteAdminApiKeyDelete(Request)
  else if LPath='/admin/diagnostics' then
   Response.Content:=LoadAdminDiagnosticsPage(Request)
  else
   Raise EHttpError.CreateHttp(404,'Admin route not found',True);
 except
  on E:EHttpError do
  begin
   Response.StatusCode:=E.StatusCode;
   if E.StatusCode=401 then
    Response.Content:=TRpWebAdminPageRenderer.RenderAdminLoginPage(E.Message)
   else
    Response.Content:=GenerateError(E);
  end;
  on E:Exception do
   Response.Content:=GenerateError(E);
 end;
end;

function TRpWebPageLoader.GenerateError(e: Exception):string;
var
 astring:String;
 errmessage:String;
 ahttpError:EHttpError;
begin
 if e is EHttpError then
 begin
  ahttpError:=EHttpError(e);
  if not ahttpError.ShowErrorPage then
  begin
   Result:=ahttpError.Message;
   exit;
  end;
 end;
 errmessage := 'Error: '  + e.Message;
 if Length(e.StackTrace)>0 then
 begin
  errmessage := errmessage + ' StackTrace: ' + e.StackTrace;
 end;

 if Length(FPagesDirectory)<1 then
 begin
  astring:=showerrorpage;
 end
 else
 begin
  aresult.LoadFromFile(FPagesDirectory+'rperror.html');
  astring:=aresult.Text;
 end;
 astring:=StringReplace(astring,'ReportManagerErrorLabel',
  errmessage,[rfReplaceAll]);

 Result:=astring;
end;

constructor TRpWebPageLoader.Create(AOwner:TComponent);
begin
 inherited Create;
 Owner:=AOwner;
 initreaded:=false;
 FRpAliasLibs:=TRpAlias.Create(nil);
 FAllowUserAccess:=True;
 FAllowApiKeyAccess:=True;
 FRequireHttps:=False;
 FShowUnauthorizedPage:=True;
 FUrlGetParams:=False;
 FLogJson:=True;

 lusers:=TStringList.Create;
 lgroups:=TStringList.Create;
 lusergroups:=TStringList.Create;
 laliasgroups:=TStringList.Create;
 laliases:=TStringList.Create;
 LServerApiKeys:=TStringList.Create;
 LServerApiKeyUsers:=TStringList.Create;
 aresult:=TStringList.Create;

 aresult.clear;
 aresult.Add('<html>');
 aresult.Add('<head>');
 aresult.Add('<title>RepManWebServer</title>');
 aresult.Add('<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">');
 aresult.Add('</head>');

 aresult.Add('<body bgcolor="#FFFFFF">');
 aresult.Add('<h3 align="center">ReportManagerLoginLabel</h3>');
 aresult.Add('<form method="post" action="./index">');
 aresult.Add('<table width="90%" border="1">');
 aresult.Add('<tr>');
 aresult.Add('<td>UserNameLabel</td>');
 aresult.Add('<td>');
 aresult.Add('<input type="text" name="username">');
 aresult.Add('</td>');
 aresult.Add('</tr>');
 aresult.Add('<tr>');
 aresult.Add('<td>PasswordLabel</td>');
 aresult.Add('<td>');
 aresult.Add('<input type="password" name="password">');
 aresult.Add('</td>');
 aresult.Add('</tr>');
 aresult.Add('</table>');
 aresult.Add('<p>');
 aresult.Add('<input type="submit" value="ReportManagerLoginLabel">');
 aresult.Add('</p>');
 aresult.Add('</form>');
 aresult.Add('<p>&nbsp; </p>');
 aresult.Add('</body>');
 aresult.Add('</html>');
 loginpage:=aresult.Text;

 aresult.clear;
 aresult.Add('<html>');
 aresult.Add('<head>');
 aresult.Add('<title>RepManWebServer</title>');
 aresult.Add('<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">');
 aresult.Add('</head>');
 aresult.Add('<body bgcolor="#FFFFFF">');
 aresult.Add('<h3 align="center"> ReportManagerIndexLabel</h3>');
 aresult.Add('<p>AvailableAliasesLabel</p>');
 aresult.Add('</body>');
 aresult.Add('</html>');
 indexpage:=aresult.Text;


 aresult.clear;
 aresult.Add('<html>');
 aresult.Add('<head>');
 aresult.Add('<title>RepManWebServer</title>');
 aresult.Add('<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">');
 aresult.Add('</head>');
 aresult.Add('<body bgcolor="#FFFFFF">');
 aresult.Add('<h3 align="center">ReportManagerReportsLabel</h3>');
 aresult.Add('<p>ReportsLocationAlias</p>');
 aresult.Add('</body>');
 aresult.Add('</html>');
 showaliaspage:=aresult.text;

 aresult.clear;
 aresult.Add('<html>');
 aresult.Add('<head>');
 aresult.Add('<title>RepManWebServer</title>');
 aresult.Add('<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">');
 aresult.Add('</head>');
 aresult.Add('<body bgcolor="#FFFFFF">');
 aresult.Add('<h3 align="center">ReportManagerErrorLabel</h3>');
 aresult.Add('</body>');
 aresult.Add('</html>');
 showerrorpage:=aresult.text;

 aresult.clear;
 aresult.Add('<html>');
 aresult.Add('<head>');
 aresult.Add('<title>RepManWebServer</title>');
 aresult.Add('<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">');
 aresult.Add('</head>');
 aresult.Add('<body bgcolor="#FFFFFF">');
 aresult.Add('<h2>ReportTitleLocation<h2>');
 aresult.Add('<p><h3 align="center">ReportManagerParamsLabel</h3></p>');
 aresult.Add('<form method="post" name="fparams" id="fparams" action="./execute.pdf">');
 aresult.Add('ReportHiddenLocation');
 aresult.Add('<p>ReportsParamsTableLocation</p>');
 aresult.Add('<p>');
 aresult.Add('<input type="submit" value="RepManExecuteLabel">');
 aresult.Add('</p>');

 aresult.Add('</form>');
 aresult.Add('</body>');
 aresult.Add('</html>');
 paramspage:=aresult.text;

 InitConfig;
end;

destructor TRpWebPageLoader.Destroy;
begin
 FRpAliasLibs.free;
 ClearLists;
 lusers.free;
 lgroups.free;
 LUserGroups.free;
 LAliasGroups.free;
 laliases.Free;
 LServerApiKeys.Free;
 LServerApiKeyUsers.Free;
 aresult.free;

 inherited Destroy;
end;

procedure TRpWebPageLoader.WriteLog(aMessage:String);
begin
 WriteStructuredLog('LOG','','','','','','{}',aMessage);
end;

procedure WriteTextToFile(const AFilename,AContent: string);
var
 FLogFile:TFileStream;
begin
 FLogFile:=TFileStream.Create(AFilename,fmOpenReadWrite or fmShareDenyNone);
 try
  FLogFile.Seek(0,soFromEnd);
  FLogFile.Write(AContent[1],Length(AContent));
 finally
  FLogFile.Free;
 end;
end;

procedure TRpWebPageLoader.WriteStructuredLog(const AEvent,AUser,AApiKey,
 ARemoteAddr,AForwardedFor,AReport,AParamsJson,AMessage: string);
var
 LTimestamp:String;
 LCsvLine:String;
 LJsonLine:String;
begin
 if logfileerror then
  exit;
 if Length(FLogFileName)<1 then
  exit;
 LTimestamp:=FormatDateTime('yyyy-mm-dd hh:nn:ss',Now);
 LCsvLine:=CsvString(LTimestamp)+','+CsvString(AEvent)+','+
  CsvString(AUser)+','+CsvString(AApiKey)+','+CsvString(ARemoteAddr)+','+
  CsvString(AForwardedFor)+','+CsvString(AReport)+','+
  CsvString(AParamsJson)+','+CsvString(AMessage)+LogLineBreak;
 WriteTextToFile(FLogFilename,LCsvLine);
 if FLogJson and (Length(FJsonLogFilename)>0) then
 begin
  LJsonLine:='{"timestamp":"'+LogString(LTimestamp)+'","event":"'+
   LogString(AEvent)+'","user":"'+LogString(AUser)+'","api_key":"'+
   LogString(AApiKey)+'","remote_addr":"'+LogString(ARemoteAddr)+
   '","x_forwarded_for":"'+LogString(AForwardedFor)+'","report":"'+
   LogString(AReport)+'","params_json":'+AParamsJson+',"message":"'+
   LogString(AMessage)+'"}'+LogLineBreak;
  WriteTextToFile(FJsonLogFilename,LJsonLine);
 end;
end;

procedure TRpWebPageLoader.WriteExecuteReportLog(const AUser,AApiKey,
 ARemoteAddr,AForwardedFor,AReport,AParamsJson: string);
begin
 WriteStructuredLog('EXECUTE_REPORT',AUser,AApiKey,ARemoteAddr,AForwardedFor,
  AReport,AParamsJson,'');
end;

procedure TRpWebPageLoader.InitConfig;
var
 inif:TMemInifile;
 i:integer;
 FLogFile:TFileStream;
 alist:TStringList;
begin
 Ffilenameconfig:='';
 try
  Ffilenameconfig:=Obtainininamecommonconfig('','','reportmanserver');
  ForceDirectories(ExtractFilePath(ffilenameconfig));
  inif:=TMemInifile.Create(ffilenameconfig);
  try
   ClearLists;
{$IFDEF USEVARIANTS}
   inif.CaseSensitive:=false;
{$ENDIF}
   FPagesDirectory:=Trim(inif.Readstring('CONFIG','PAGESDIR',''));
   fport:=inif.ReadInteger('CONFIG','TCPPORT',3060);
  FAllowUserAccess:=ReadConfigBool(inif,'SECURITY','USER_ACCESS',True);
  FAllowApiKeyAccess:=ReadConfigBool(inif,'SECURITY','API_KEY_ACCESS',True);
  FRequireHttps:=ReadConfigBool(inif,'SECURITY','REQUIRE_HTTPS',False);
  FShowUnauthorizedPage:=ReadConfigBool(inif,'SECURITY',
   'SHOWUNAUTHORIZEDPAGE',True);
  FUrlGetParams:=ReadConfigBool(inif,'SECURITY','URLGETPARAMS',False);
  FLogJson:=ReadConfigBool(inif,'CONFIG','LOG_JSON',True);
   inif.ReadSectionValues('USERS',lusers);
   inif.ReadSectionValues('GROUPS',lgroups);
   inif.ReadSectionValues('ALIASES',laliases);
  inif.ReadSectionValues('SERVERAPIKEYS',LServerApiKeys);
  inif.ReadSectionValues('SERVERAPIKEYUSERS',LServerApiKeyUsers);
   i:=0;
   while i<lusers.count do
   begin
    if Length(Trim(lusers.strings[i]))<1 then
     LUsers.delete(i)
    else
     inc(i);
   end;
   while i<lgroups.count do
   begin
    if Length(Trim(lgroups.strings[i]))<1 then
     LGroups.delete(i)
    else
     inc(i);
   end;
   i:=0;
   while i<laliases.count do
   begin
    if Length(Trim(laliases.strings[i]))<1 then
     laliases.delete(i)
    else
     inc(i);
   end;
   for i:=0 to lusers.count-1 do
   begin
    if Length(lusers.Names[i])<1 then
     lusers.Strings[i]:=lusers.Strings[i]+'=';
   end;
   for i:=0 to laliases.count-1 do
   begin
    if Length(laliases.Names[i])<1 then
     laliases.Strings[i]:=laliases.Strings[i]+'=';
   end;
   if lusers.IndexOfName('ADMIN')<0 then
    lusers.Add('ADMIN=');
   // Read privilege lists
   for i:=0 to lusers.Count-1 do
   begin
    if lusers.Names[i]<>'ADMIN' then
    begin
     alist:=TStringList.Create;
     LUserGroups.AddObject(lusers.Names[i],alist);
     inif.ReadSectionValues('USERGROUPS'+lusers.Names[i],alist);
    end;
   end;
   for i:=0 to LAliases.Count-1 do
   begin
    alist:=TStringList.Create;
    LAliasGroups.AddObject(LAliases.Names[i],alist);
    inif.ReadSectionValues('GROUPALLOW'+LAliases.Names[i],alist);
   end;


   // Gets the log file and try to create it
   logfileerror:=false;
   LogFileErrorMessage:='';
   FLogFilename:=inif.Readstring('CONFIG','LOGFILE','');
   FJsonLogFilename:='';
   if Length(FLogFilename)>0 then
   begin
    if FLogJson then
     FJsonLogFilename:=ChangeFileExt(FLogFilename,'.jsonl');
    if Not (FileExists(FLogFileName)) then
    begin
     try
      FLogFile:=TFileStream.Create(FLogFilename,fmOpenReadWrite or fmCreate);
      FLogFile.Free;
      WriteTextToFile(FLogFilename,'timestamp,event,user,api_key,remote_addr,'+
       'x_forwarded_for,report,params_json,message'+LogLineBreak);
     except
      On E:Exception do
      begin
       logfileerror:=true;
      LogFileErrorMessage:=E.Message;
      end;
     end;
    end;
    if FLogJson and (not logfileerror) and (not FileExists(FJsonLogFilename)) then
    begin
     try
      FLogFile:=TFileStream.Create(FJsonLogFilename,fmOpenReadWrite or fmCreate);
      FLogFile.Free;
     except
      On E:Exception do
      begin
       logfileerror:=true;
      LogFileErrorMessage:=E.Message;
      end;
     end;
    end;
   end;
  finally
   inif.free;
  end;
  FRpAliasLibs.Connections.LoadFromFile(FFilenameConfig);
  initreaded:=true;
 except
  on E:Exception do
  begin
   InitErrorMessage:=E.Message+' Configuration file:'+Ffilenameconfig;
  end;
 end;
end;


function TRpWebPageLoader.LoadAliasPage(Request: TWebRequest):string;
var
 astring,reportname:String;
 reportlist:String;
 aliasname:String;
 i:integer;
 alist:TStringList;
 dirpath:String;
begin
 if Length(FPagesDirectory)<1 then
 begin
  astring:=showaliaspage;
 end
 else
 begin
    if FUrlGetParams then
     aresult.LoadFromFile(FPagesDirectory+'rpalias_get.html')
    else
     aresult.LoadFromFile(FPagesDirectory+'rpalias.html');
  astring:=aresult.Text;
 end;
 astring:=StringReplace(astring,REPMAN_WEBSERVER,
  TranslateStr(837,'Report Manager Web Server'),[rfReplaceAll]);
 astring:=StringReplace(astring,REPMAN_REPORTS_LABEL,
  TranslateStr(837,'Reports'),[rfReplaceAll]);
 reportlist:='';
 aliasname:=GetRequestParam(Request,'aliasname');
 if Length(aliasname)>0 then
 begin
  dirpath:=laliases.Values[aliasname];
  alist:=TStringList.Create;
  try
   if Length(dirpath)<1 then
    Raise Exception.Create(SRPAliasNotExists);
   if dirpath[1]=':' then
    FRpAliasLibs.Connections.FillTreeDir(Copy(dirpath,2,Length(dirpath)),alist)
   else
   begin
    if Not DirectoryExists(dirpath) then
     Raise Exception.Create(SrpDirectoryNotExists+ ' - '+dirpath);
    FillTreeDir(dirpath,alist);
   end;
   for i:=0 to alist.Count-1 do
   begin
    reportname:=alist.Strings[i];
    if Length(reportname)>0 then
    begin
     if reportname[1]=C_DIRSEPARATOR then
      reportname:=Copy(reportname,2,Length(reportname));
     if FUrlGetParams then
      reportlist:=reportlist+#10+'<p><a href="./showparams?reportname='+
       alist.Strings[i]+'&'+Request.Query+'">'+reportname+'</a></p>'
     else
      reportlist:=reportlist+#10+'<form method="post" action="./showparams">'+
       HiddenInput('reportname',alist.Strings[i])+HiddenInput('aliasname',aliasname)+
       HiddenAuthInputs(Request)+'<input type="submit" value="'+
       HtmlEncode(reportname)+'">'+'</form>';
    end;
   end;
  finally
   alist.free;
  end;
 end;
 astring:=StringReplace(astring,REPMAN_REPORTSLOC_LABEL,
  reportlist,[rfReplaceAll]);
 Result:=astring;
end;

procedure TRpWebPageLoader.LoadReport(pdfreport:TRpReport;aliasname,reportname:String);
var
 dirpath:String;
 astream:TStream;
begin
 dirpath:=laliases.Values[aliasname];
 if Length(dirpath)<1 then
  Raise Exception.Create(SRPAliasNotExists);
 if dirpath[1]=':' then
 begin
  astream:=FRpAliasLibs.Connections.GetReportStream(Copy(dirpath,2,Length(dirpath)),
   ExtractFileName(reportname),nil);
  try
   pdfreport.LoadFromStream(astream);
  finally
   astream.free;
  end;
 end
 else
 begin
  reportname:=dirpath+C_DIRSEPARATOR+reportname;
  reportname:=ChangeFileExt(reportname,'.rep');
  pdfreport.LoadFromFile(reportname);
 end;
end;

// returns empty string if no parameters in the report
function TRpWebPageLoader.LoadParamsPage(Request: TWebRequest):string;
var
 pdfreport:TRpReport;
 aliasname,reportname,areportname:string;
 visibleparam:Boolean;
 i,k,selectedindex:integer;
 astring,inputstring:String;
 aparamstring:String;
 aparam:TRpParam;
 multisize:integer;
 prevvalue,tofocus:string;
begin
 aliasname:=GetRequestParam(Request,'aliasname');
 reportname:=GetRequestParam(Request,'reportname');
 Result:='';
 // Load the report
 pdfreport:=TRpReport.Create(Owner);
 try
  if Length(aliasname)>0 then
  begin
   LoadReport(pdfreport,aliasname,reportname);
   // Assign language
  if Length(GetRequestParam(Request,'LANGUAGE'))>0 then
   pdfreport.Language:=StrToInt(GetRequestParam(Request,'LANGUAGE'));
   pdfreport.Params.UpdateLookup;
   // Count visible parameters
   visibleparam:=false;
   for i:=0 to pdfreport.Params.Count-1 do
   begin
    if ((pdfreport.Params.Items[i].Visible) and
     (not pdfreport.Params.Items[i].NeverVisible)) then
    begin
     visibleparam:=true;
     break;
    end;
   end;
   if visibleparam then
   begin
    // Creates the parameters form
    if Length(FPagesDirectory)<1 then
    begin
     astring:=paramspage;
     if FUrlGetParams then
      astring:=StringReplace(astring,'method="post"','method="get"',[rfReplaceAll]);
    end
    else
    begin
    if FUrlGetParams then
     aresult.LoadFromFile(FPagesDirectory+'rpparams_get.html')
    else
     aresult.LoadFromFile(FPagesDirectory+'rpparams.html');
     astring:=aresult.Text;
    end;
    astring:=StringReplace(astring,REPMAN_WEBSERVER,
     TranslateStr(837,'Report Manager Web Server'),[rfReplaceAll]);
    astring:=StringReplace(astring,REPMAN_PARAMSLABEL,
     TranslateStr(135,'Parameter values'),[rfReplaceAll]);
    astring:=StringReplace(astring,REPMAN_EXECUTELABEL,
     TranslateStr(779,'Execute'),[rfReplaceAll]);
    areportname:=GetRequestParam(Request,'reportname');
    if Length(areportname)>0 then
    begin
     if areportname[1]=C_DIRSEPARATOR then
      areportname:=Copy(areportname,2,Length(areportname));
    end;
    astring:=StringReplace(astring,REPMAN_REPORTTITLE,
     areportname,[rfReplaceAll]);

    inputstring:='<input type="hidden" name="reportname" '+
    'value="'+HtmlEncode(GetRequestParam(Request,'reportname'))+'">';
    inputstring:=inputstring+'<input type="hidden" name="aliasname" '+
    'value="'+HtmlEncode(GetRequestParam(Request,'aliasname'))+'">';
    if not HasServerApiKey(Request) then
    begin
     inputstring:=inputstring+'<input type="hidden" name="username" '+
     'value="'+HtmlEncode(GetRequestParam(Request,'username'))+'">';
     inputstring:=inputstring+'<input type="hidden" name="password" '+
     'value="'+HtmlEncode(GetRequestParam(Request,'password'))+'">';
    end;
    astring:=StringReplace(astring,REPMAN_HIDDEN,
     inputstring,[rfReplaceAll]);

    // Add previous parameters
    aparamstring:='<table width="90%" border="1">'+#10;
    for i:=0 to pdfreport.Params.Count-1 do
    begin
     aparam:=pdfreport.Params.Items[i];
     if ((aparam.Visible) and (not aparam.NeverVisible))  then
     begin
      prevvalue:=Request.ContentFields.Values['Param'+aparam.Name];
      if (Length(prevvalue)<1) and FUrlGetParams then
       prevvalue:=Request.QueryFields.Values['Param'+aparam.Name];
      aparamstring:=aparamstring+'<tr>'+#10+
       '<td>'+HtmlEncode(aparam.Description)+'</td>'+#10+
       '<td>'+#10;
      case aparam.ParamType of
       rpParamBool:
        begin
         aparamstring:=aparamstring+
          '<select name="Param'+aparam.Name+'" id="Param'+aparam.Name+'" ';
         if Length(aparam.Hint)>0 then
          aparamstring:=aparamstring+' alt="'+HtmlEncode(aparam.Hint)+'" ';
         if aparam.IsReadOnly then
          aparamstring:=aparamstring+' readonly ';
         aparamstring:=aparamstring+'>'+#10;
         aparamstring:=aparamstring+'<option value="'+
           BoolToStr(false,true)+'" ';
         // Check if it's a post back
         if Length(prevvalue)>0 then
         begin
          if prevvalue=BoolToStr(true,true) then
           aparam.Value:=true
          else
           aparam.Value:=false;
         end;
         if Not VarIsNull(aparam.Value) then
          if Not aparam.Value then
           aparamstring:=aparamstring+' selected ';
         aparamstring:=aparamstring+'>'+HtmlEncode(SRpNo)+
          '</option>'+#10;
         aparamstring:=aparamstring+'<option value="'+
           BoolToStr(true,true)+'" ';
         if Not VarIsNull(aparam.Value) then
          if aparam.Value then
           aparamstring:=aparamstring+' selected ';
         aparamstring:=aparamstring+'>'+HtmlEncode(SRpYes)+
          '</option>'+#10;
         aparamstring:=aparamstring+
          '</select>'+#10;
        end;
       rpParamMultiple:
        begin
         // Check if it's a post back
         if Length(prevvalue)>0 then
         begin
          aparam.Value:=StrToInt(prevvalue);
         end;
         aparamstring:=aparamstring+'<select name="Param'+
          aparam.Name+'" id="Param'+aparam.Name+'" ';
         aparamstring:=aparamstring+' multiple ';
         if Length(aparam.Hint)>0 then
           aparamstring:=aparamstring+' alt="'+HtmlEncode(aparam.Hint)+'" ';
         if aparam.Isreadonly then
          aparamstring:=aparamstring+' readonly ';
         multisize:=10;
         if aparam.Items.Count<10 then
          multisize:=aparam.Items.Count;
         aparamstring:=aparamstring+' size="'+IntToStr(multisize)+'" >'+#10;
         for k:=0 to aparam.Items.Count-1 do
         begin
          aparamstring:=aparamstring+'<option value="'+
            IntToStr(k)+'" ';
          if aparam.Selected.IndexOf(IntToStr(k))>=0 then
           aparamstring:=aparamstring+' selected ';
          aparamstring:=aparamstring+'>'+HtmlEncode(aparam.Items.Strings[k])+
           '</option>'+#10;
         end;
         aparamstring:=aparamstring+'</select>'+#10;
        end;
       rpParamList:
        begin
         // Check if it's a post back
         if Length(prevvalue)>0 then
         begin
          aparam.Value:=StrToInt(prevvalue);
         end;
         aparamstring:=aparamstring+'<select name="Param'+
          aparam.Name+'" id="Param'+aparam.Name+'" ';
         if Length(aparam.Hint)>0 then
           aparamstring:=aparamstring+' alt="'+HtmlEncode(aparam.Hint)+'" ';
         if aparam.Isreadonly then
          aparamstring:=aparamstring+' readonly ';
         aparamstring:=aparamstring+'>'+#10;
         if Not VarIsNull(aparam.value) then
         begin
          if VarType(aparam.Value)=varInteger then
           selectedindex:=aparam.Value
          else
           selectedindex:=aparam.Values.IndexOf(String(aparam.Value));
         end
         else
          selectedindex:=-1;
         for k:=0 to aparam.Items.Count-1 do
         begin
          aparamstring:=aparamstring+'<option value="'+
            IntToStr(k)+'" ';
          if k=selectedindex then
           aparamstring:=aparamstring+' selected ';
          aparamstring:=aparamstring+'>'+HtmlEncode(aparam.Items.Strings[k])+
           '</option>'+#10;
         end;
         aparamstring:=aparamstring+'</select>'+#10;
        end;
       else
       begin
        // Check if it's a post back
        if Length(prevvalue)=0 then
         prevvalue:=aparam.AsString;
        aparamstring:=aparamstring+
         '<input type="text" name="Param'+
         aparam.Name+'" id="Param'+aparam.Name+'" ';
        if Length(aparam.Hint)>0 then
         aparamstring:=aparamstring+' alt="'+HtmlEncode(aparam.Hint)+'" ';
        if aparam.IsReadOnly then
         aparamstring:=aparamstring+' readonly '+#10;
        aparamstring:=aparamstring+
         ' value="'+HtmlEncode(prevvalue)+'">';
       end;
      end;
      aparamstring:=aparamstring+'</td>'+#10;
      if pdfreport.Params.Items[i].AllowNulls then
      begin
       aparamstring:=aparamstring+
        '<td>'+#10+
        '<input type="checkbox" name="NULLParam'+
        pdfreport.Params.Items[i].Name+'" value="NULL"';
       if pdfreport.Params.Items[i].Value=Null then
        aparamstring:=aparamstring+' checked ';
       aparamstring:=aparamstring+'>'+#10+
        ' '+TranslateStr(196,'Null value')+'</td>'+#10+
        '</tr>';
      end;
{    <tr>
      <td>LabelParam2</td>
      <td>
        <select name="Param2Value">
          <option value="True">True</option>
          <option value="False">False</option>
        </select>
      </td>
      <td>
        <input type="checkbox" name="Param1Null2" value="Null" checked>
        Null </td>
    </tr>
}    end;
    end;
    if Length(GetRequestParam(Request,'ERROR_MESSAGE'))>0 then
    begin
     aparamstring:=aparamstring+'<tr>'+
      '<td  colspan="2"><b>'+HtmlEncode(GetRequestParam(Request,'ERROR_MESSAGE'))
      +'</b></td><tr>';
    end;
    tofocus:=GetRequestParam(Request,'ERROR_PARAM');
    if Length(tofocus)>0 then
    begin
      aparamstring:=aparamstring+
       '<script type="text/javascript">'+#10+
       '<!--'+#10+
       ' document.fparams.'+tofocus+'.focus();'+#10+
//       ' document.fparams.'+tofocus+'.scrollIntoView();'+#10+
       '// -->'+#10+
       '</script>'+#10;
    end;

    aparamstring:=aparamstring+
     '</table>'+#10;
    // Insert the params table
    astring:=StringReplace(astring,REPMAN_PARAMSLOCATION,
     aparamstring,[rfReplaceAll]);
    Result:=astring;
   end;
  end;
 finally
  pdfreport.Free;
 end;
end;

procedure TRpWebPageLoader.ExecuteReport(Request: TWebRequest;Response:TWebResponse);
var
 pdfreport:TRpReport;
 username,reportname:string;
 aliasname:string;
 astream:TMemoryStream;
 paramname,paramvalue:string;
 dometafile:boolean;
 dosvg,dotxt,docsv:Boolean;
 i,index,pageindex,k:integer;
 aname:string;
 paramisnull:boolean;
 adriver:TRpPDFDriver;
 param:TRpParam;
 checkparamname,checkamessage:string;
 doexit:boolean;
 separator,textdriver:string;
 LisAdmin:Boolean;
 requestfields:TStringList;
 apiKeyName,paramsJson,remoteAddr,forwardedFor:string;
begin
 CheckLogin(Request);
 dometafile:=false;
 docsv:=false;
 dosvg:=false;
 dotxt:=false;
 doexit:=false;
 ResolveAuthenticatedUser(Request,username,LisAdmin);
 apiKeyName:=GetServerApiKeyName(Request);
 remoteAddr:=GetRemoteAddr(Request);
 forwardedFor:=GetForwardedFor(Request);
 paramsJson:='{}';
 reportname:='';
 try
  aliasname:=GetRequestParam(Request,'aliasname');
  reportname:=GetRequestParam(Request,'reportname');
  pdfreport:=CreateReport;
  try
   WriteLog('Loading report: '+aliasname+':'+reportname+' into memory');
   LoadReport(pdfreport,aliasname,reportname);
   WriteLog('Report Loaded');
  if Length(GetRequestParam(Request,'LANGUAGE'))>0 then
   pdfreport.Language:=StrToInt(GetRequestParam(Request,'LANGUAGE'));
   pdfreport.Params.UpdateLookup;
   WriteLog('Assigning parameters to the report');
   // Clear multiple selection parameters
   for i:=0 to pdfreport.Params.Count-1 do
   begin
    param:=pdfreport.Params.Items[i];
    if param.ParamType=rpParamMultiple then
    begin
     param.Selected.Clear;
    end;
   end;
   // Assigns parameters to the report
   requestfields:=CreateRequestParamList(Request);
  try
   for i:=0 to requestfields.Count-1 do
   begin
    if Pos('Param',requestfields.Names[i])=1 then
    begin
     paramname:=Copy(requestfields.Names[i],6,Length(requestfields.Names[i]));
     paramvalue:=requestfields.Values[requestfields.Names[i]];
     paramisnull:=false;
     // Check for error assigning parameters
     try
      index:=requestfields.IndexOfName('NULLParam'+paramname);
      if index>=0 then
      begin
       if requestfields.Values[requestfields.Names[index]]='NULL' then
        paramisnull:=True;
      end;
      param:=pdfreport.Params.ParamByName(paramname);
      if param.ParamType=rpParamMultiple then
      begin
       param.Selected.Clear;
       for k:=0 to requestfields.Count-1 do
       begin
        if requestfields.Names[k]='Param'+paramname then
        begin
         aname:=requestfields.Names[k];
         index:=StrToInt(requestfields.ValueFromIndex[k]);
         if index<param.Values.Count then
          param.Selected.Add(IntToStr(Index));
        end;
       end;
      end
      else
      if paramisnull then
       param.Value:=Null
      else
      begin
       // Assign the parameter as a string
       if param.ParamType=rpParamList then
       begin
 //       param.Value:=StrToInt(paramvalue);
        param.Value:=param.Values.Strings[StrToInt(paramvalue)];
       end
       else
       begin
        param.AsString:=paramvalue;
       end;
      end;
     except
      On E:Exception do
      begin
      Request.ContentFields.Values['ERROR_MESSAGE']:=E.Message;
      Request.ContentFields.Values['ERROR_PARAM']:='Param'+paramname;
       Response.Content:=LoadParamsPage(Request);
       doexit:=true;
       break;;
      end;
     end;
    end;
    if Uppercase(requestfields.Names[i])='METAFILE' then
    begin
     dometafile:=requestfields.Values['METAFILE']='1';
     docsv:=requestfields.Values['METAFILE']='2';
     dotxt:=requestfields.Values['METAFILE']='3';
     dosvg:=requestfields.Values['METAFILE']='4';
    end;
   end;
   finally
    requestfields.Free;
   end;
   if doexit then
    exit;
   // Assigns pusername param if exists
   index:=pdfreport.Params.IndexOf('PUSERNAME');
   if index>=0 then
    pdfreport.Params.ParamByName('PUSERNAME').Value:=username;
   // Check parameter values, if error show error on
   // Parameters page
   if not pdfreport.CheckParameters(pdfreport.Params,checkparamname,checkamessage) then
   begin
    Request.ContentFields.Values['ERROR_MESSAGE']:=checkamessage;
    Request.ContentFields.Values['ERROR_PARAM']:='Param'+checkparamname;
    Response.Content:=LoadParamsPage(Request);
    exit;
   end;
    paramsJson:=ReportParamsToJson(pdfreport);
    WriteExecuteReportLog(username,apiKeyName,remoteAddr,forwardedFor,
     aliasname+':'+reportname,paramsJson);
   WriteLog('Creating memory stream');
   astream:=TMemoryStream.Create;
   try
    WriteLog('Memory stream created');
    astream.Clear;
    if dometafile then
    begin
{$IFDEF FORCECONSOLE}
     WriteLog('Calculating report metafile: console mode');
     rppdfdriver.PrintReportMetafileStream(pdfreport,'',false,true,1,9999,1,
      astream,true,false);
{$ENDIF}
{$IFNDEF FORCECONSOLE}
     WriteLog('Calculating report metafile: not console mode');
 {$IFDEF MSWINDOWS}
     rpgdidriver.ExportReportToPDFMetaStream(pdfreport,'',
      false,true,1,9999,1,false,astream,true,false,true);
 {$ENDIF}
 {$IFDEF LINUX}
     rppdfdriver.PrintReportPDFStream(pdfreport,'',
      false,true,1,9999,1,astream,true,false,pdfReport.PDFConformance = TPDFConformanceType.PDF_A_3);
 {$ENDIF}
{$ENDIF}
     WriteLog('Writing response (application/rpmf)');
     Response.ContentType := 'application/rpmf';
     astream.Seek(0,soFromBeginning);
     Response.ContentStream:=astream;
     WriteLog(reportname+' Executed Metafile');
    end
    else
    if dotxt then
    begin
     WriteLog('Calculating report, PLAIN');
     textdriver:='PLAIN';
    if Length(GetRequestParam(Request,'TEXTDRIVER'))>0 then
     textdriver:=GetRequestParam(Request,'TEXTDRIVER');
     rptextdriver.PrintReportToStream(pdfreport,'',false,true,1,9999,1,
     astream,true,GetRequestParam(Request,'OEMCONVERT')='1',textdriver);
     WriteLog('Writing response, PLAIN');
     Response.ContentType := 'text/plain';
     astream.Seek(0,soFromBeginning);
     Response.ContentStream:=astream;
     WriteLog(reportname+' Executed Text');
    end
    else
    if docsv then
    begin
     WriteLog('Calculating report, CSV');
     separator:=',';
    if Length(GetRequestParam(Request,'SEPARATOR'))>0 then
     separator:=GetRequestParam(Request,'SEPARATOR');
     adriver:=TRpPdfDriver.Create;
     pdfreport.TwoPass:=true;
     pdfreport.PrintAll(adriver);
     rpcsvdriver.ExportMetafileToCSVStream(pdfreport.metafile,
      astream,false,true,1,MAX_PAGECOUNT,separator);
     WriteLog('Writing response, CSV');
     Response.ContentType := 'text/plain';
     astream.Seek(0,soFromBeginning);
     Response.ContentStream:=astream;
     WriteLog(reportname+' Executed CSV');
    end
    else
    if dosvg then
    begin
     WriteLog('Calculating report, SVG');
     adriver:=TRpPdfDriver.Create;
     pdfreport.TwoPass:=true;
     pdfreport.PrintAll(adriver);
    if GetRequestParam(Request,'PAGEINDEX')='' then
      pageindex:=1
     else
     pageindex:=StrToInt(GetRequestParam(Request,'PAGEINDEX'));
     rpsvgdriver.MetafilePageToSVG(pdfreport.metafile,pageindex,astream,'','');
     WriteLog('Writing response, SVG');
     Response.ContentType := 'application/svg';
     astream.Seek(0,soFromBeginning);
     Response.ContentStream:=astream;
     WriteLog(reportname+' Executed SVG');
    end
    else
    begin
{$IFDEF FORCECONSOLE}
     WriteLog('Calculating report pdf: console mode');
     rppdfdriver.PrintReportPDFStream(pdfreport,'',false,true,1,9999,1,
      astream,true,false);
{$ENDIF}
{$IFNDEF FORCECONSOLE}
     WriteLog('Calculating report pdf: not console mode');
 {$IFDEF MSWINDOWS}
     rpgdidriver.ExportReportToPDFMetaStream(pdfreport,'',
      false,true,1,9999,1,false,astream,true,false,false);
 {$ENDIF}
 {$IFDEF LINUX}
     rppdfdriver.PrintReportPDFStream(pdfreport,'',
      false,true,1,9999,1,astream,true,false,pdfReport.PDFConformance = TPDFConformanceType.PDF_A_3);
 {$ENDIF}
{$ENDIF}
     astream.Seek(0,soFromBeginning);
     // Testing to pdf file
     // astream.SaveToFile('c:\datos\prueba.pdf');
     astream.Seek(0,soFromBeginning);
     WriteLog('Writing response, PDF');
     Response.ContentType := 'application/pdf';
     Response.ContentStream:=astream;
     WriteLog(reportname+' Executed PDF');
    end;
   except
    astream.free;
    raise;
   end;
  finally
   pdfreport.Free;
  end;
 except
  On E:Exception do
  begin
   Response.Content:=GenerateError(E);
  end;
 end;
end;

// Returns parameter page if no params available

function TRpWebPageLoader.CreateReport:TRpReport;
{$IFDEF USEBDE}
var
 sesname:string;
{$ENDIF}
begin
{$IFDEF USEBDE}
 if Not Assigned(ASession) then
 begin
  // If can not create session omit it
  try
   ASession:=TSession.Create(Owner);
   ASession.AutoSessionName:=True;
   ASession.Open;
   sesname:=ASession.SessionName;
   ASession.Close;
   ASession.PrivateDir:=ChangeFileExt(Obtainininamecommonconfig('','BDESessions','Session'+ASession.SessionName),'');
   BDESessionDir:=ASession.PrivateDir;
   ForceDirectories(ASession.PrivateDir);
   ASession.Open;
   BDESessionDirOk:=ASession.PrivateDir;
  except
   ASession.free;
   ASession:=nil;
  end;
 end;
{$ENDIF}
 Result:=TRpReport.Create(nil);
{$IFDEF USEBDE}
 if Assigned(ASession) then
  Result.DatabaseInfo.BDESession:=ASession;
{$ENDIF}
end;
(*
initialization
  // Enable raw mode (default mode uses stack frames which aren't always generated by the compiler)
  Include(JclStackTrackingOptions, stRawMode);
  // Disable stack tracking in dynamically loaded modules (it makes stack tracking code a bit faster)
  Include(JclStackTrackingOptions, stStaticModuleList);
  // Initialize Exception tracking
  JclStartExceptionTracking;
finalization
  JclStopExceptionTracking;
  *)
end.
