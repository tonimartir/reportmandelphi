# Plan repwebexe Docker + editor web de conexiones

## Objetivo

Crear una solucion Docker autocontenida para `repwebexe` en Linux, ejecutandolo en modo `selfhosted`, con configuracion persistente de `dbxconnections.ini` y un asistente web de administracion integrado en el propio servidor.

La administracion web no debe limitarse a `dbxconnections.ini`. Debe cubrir tambien la administracion funcional de `reportmanserver.ini`, ya que ese fichero contiene la seguridad del servidor, los usuarios, grupos, API keys y los aliases que apuntan a carpetas de informes o a aliases de conexion.

La primera fase debe centrarse primero en `reportmanserver.ini` y, una vez cerrada esa base administrativa, continuar con `dbxconnections.ini`.

Las dos areas persistentes del proyecto son:

- `reportmanserver.ini`
- `dbxconnections.ini`

`dbxdrivers` queda controlado por la imagen Docker y no por el usuario final, salvo evolucion futura muy controlada.

Tambien debe existir un modo de edicion manual de `dbxconnections.ini` para que un usuario pueda arrancar el Docker y pegar o importar la configuracion que ya usaba antes de Docker.

Tambien debe existir administracion asistida y, cuando proceda, modo manual controlado para `reportmanserver.ini`, porque en Docker es razonable que el mismo servicio administre sus usuarios, grupos, aliases, rutas y API keys.

## Decision arquitectonica

- El asistente web se integra en `repwebexe`, no en un servicio separado.
- La prueba de conexion debe usar la misma logica Delphi que usara el servidor real.
- El contenedor debe ser autonomo: binario, dependencias y configuracion controlada dentro de la imagen o mediante volumenes explicitos.
- El modo preferente de despliegue Docker es `repwebexe -selfhosted -port=<PORT>`; no hace falta un Apache/nginx delante salvo una necesidad posterior muy concreta.
- La administracion debe abarcar `dbxconnections.ini` y `reportmanserver.ini`.
- Debe existir modo asistido para configuracion funcional y modo manual al menos para `dbxconnections.ini`.
- La seguridad del area admin debe estar gobernada por `reportmanserver.ini` una vez exista al menos un administrador.

## Alcance administrativo completo

El area admin debe cubrir, como minimo, estas capacidades:

1. Administrar conexiones de datos en `dbxconnections.ini`.
2. Administrar usuarios de acceso al servidor web.
3. Administrar grupos.
4. Administrar pertenencia de usuarios a grupos.
5. Administrar aliases de informes definidos en `reportmanserver.ini`.
6. Administrar permisos de grupos sobre aliases.
7. Crear y revocar API keys del servidor.
8. Asociar API keys a usuarios internos.
9. Editar opciones funcionales del servidor dentro de `reportmanserver.ini`.
10. Mostrar rutas efectivas de configuracion y de volumenes montados.

El caso de uso importante es que las carpetas reales de informes pueden vivir en un volumen aparte. Por tanto, el panel debe tratar los aliases y sus rutas como configuracion de primer nivel, no como detalle secundario.

## Bootstrap y primer administrador

Debe existir una estrategia clara para el primer acceso al area admin.

Regla base propuesta:

- si no existe ningun usuario administrador utilizable en `reportmanserver.ini`, el sistema entra en modo bootstrap de administracion
- en ese modo, la unica operacion permitida es crear el primer usuario admin y definir su password
- una vez creado el primer admin, el modo bootstrap queda desactivado y el acceso normal pasa a autenticacion admin

La suposicion funcional correcta es que el primer usuario sera `ADMIN` por defecto, salvo que el usuario quiera indicar otro nombre en el asistente inicial.

El plan debe contemplar dos opciones de bootstrap, decidiendose una en implementacion:

1. `ADMIN` predefinido con password vacio y obligacion de establecer password en primer acceso.
2. sin admin valido inicial y asistente de bootstrap que crea el primer admin.

La opcion 2 es preferible porque evita dejar un usuario admin funcional sin password definida.

## Fase 1: Area admin web

### Objetivo funcional

Construir un area admin web utilizable por un usuario real para gestionar tanto la configuracion de conexiones como la configuracion funcional y de seguridad del servidor.

El orden de implementacion dentro de esta fase debe ser:

1. primero el asistente de `reportmanserver.ini`
2. despues los endpoints y pantallas de `dbxconnections.ini`

### Alcance

1. Mostrar un menu principal de administracion.
2. Gestionar configuracion funcional y seguridad en `reportmanserver.ini`.
3. Gestionar usuarios administradores y usuarios funcionales.
4. Gestionar grupos y pertenencia a grupos.
5. Gestionar aliases y rutas de informes.
6. Gestionar API keys y su asociacion a usuarios.
7. Gestionar conexiones en `dbxconnections.ini`.
8. Probar conexiones reales.
9. Editar manualmente el contenido completo de `dbxconnections.ini`.
10. Guardar cambios persistentes en disco.

### Subfases de implementacion de la fase 1

#### Fase 1A: Asistente de `reportmanserver.ini`

Esta es la primera entrega real del proyecto.

Debe incluir:

1. menu principal admin
2. bootstrap del primer admin
3. login admin
4. configuracion general y de seguridad del servidor
5. usuarios
6. grupos
7. aliases y rutas de informes
8. API keys
9. diagnostico admin

No depende todavia de tener lista la administracion de conexiones de base de datos.

#### Fase 1B: Administracion de `dbxconnections.ini`

Esta es la segunda entrega dentro del area admin.

Debe incluir:

1. listado de conexiones
2. alta y edicion asistida
3. prueba real de conexion
4. edicion manual completa de `dbxconnections.ini`

Esta subfase se apoya en la infraestructura admin creada en la Fase 1A.

### Base tecnica existente a reutilizar

- `TRpConnAdmin.AddConnection` para alta desde plantilla de driver.
- `TRpConnAdmin.GetConnectionNames` para listado.
- `TRpConnAdmin.GetConnectionParams` para edicion asistida.
- `TRpConnAdmin.DeleteConnection` para borrado.
- La logica de prueba de conexion del configurador VCL para ejecutar pruebas reales con DBX, FireDAC o Zeos segun corresponda.

### Rutas web propuestas

- `/admin`
- `/admin/bootstrap`
- `/admin/connections`
- `/admin/connections/new`
- `/admin/connections/edit?name=...`
- `/admin/connections/test`
- `/admin/connections/delete`
- `/admin/connections/raw`
- `/admin/diagnostics`
- `/admin/server-config`
- `/admin/users`
- `/admin/users/new`
- `/admin/users/edit?name=...`
- `/admin/groups`
- `/admin/groups/edit?name=...`
- `/admin/aliases`
- `/admin/aliases/edit?name=...`
- `/admin/apikeys`
- `/admin/apikeys/new`
- `/admin/apikeys/delete`

### Pantallas propuestas

#### 1. Menu principal de administracion

Debe existir una portada principal en `/admin` para que el usuario no tenga que conocer endpoints manualmente.

Debe mostrar:

- acceso a `Conexiones`
- acceso a `Configuracion del servidor`
- acceso a `Usuarios`
- acceso a `Grupos`
- acceso a `Aliases de informes`
- acceso a `API keys`
- acceso a `Nueva conexion`
- acceso a `Editar dbxconnections.ini manualmente`
- acceso a `Diagnostico`
- ruta efectiva de `dbxconnections.ini`
- ruta efectiva de `dbxdrivers`
- ruta efectiva de `reportmanserver.ini`

Debe mostrar tambien un resumen funcional:

- numero de conexiones
- numero de usuarios
- numero de grupos
- numero de aliases
- si existe al menos un administrador valido

Debe ser el punto de entrada normal del area admin.

#### 1.b. Bootstrap del primer administrador

Si no existe ningun admin valido, la entrada debe ir a una pantalla de bootstrap.

Debe permitir:

- elegir nombre del primer admin, proponiendo `ADMIN`
- definir password inicial
- confirmar password
- opcionalmente definir ruta inicial de `reportmanserver.ini` si hiciera falta

Tras completarlo, debe crear la base minima de configuracion administrativa y redirigir al menu principal.

#### 2. Listado de conexiones

Debe mostrar:

- nombre de la conexion
- driver asociado
- acciones de editar, probar y borrar
- acceso a crear nueva conexion
- acceso a modo manual del INI

Tambien debe ofrecer navegacion visible de vuelta al menu principal.

#### 3. Alta y edicion asistida

Debe permitir:

- seleccionar driver
- crear seccion nueva desde plantilla del driver
- mostrar y editar los parametros de esa seccion
- guardar cambios de forma explicita

La web no necesita replicar el layout VCL. Basta con un formulario dinamico basado en pares `clave=valor`.

La pantalla debe incluir enlaces o botones visibles a:

- menu principal admin
- listado de conexiones
- edicion manual del INI

#### 4. Prueba de conexion

Debe ejecutar la misma logica de apertura real que usara Reportman en produccion.

Debe devolver:

- exito o error
- mensaje detallado de excepcion
- driver realmente usado
- parametros relevantes no sensibles

Debe incluir una accion clara para volver a la edicion o regresar al menu principal.

#### 5. Edicion manual de `dbxconnections.ini`

Debe existir una pantalla con editor de texto completo.

Casos de uso:

- pegar un fichero heredado de una instalacion previa
- corregir manualmente parametros avanzados
- importar rapidamente configuraciones existentes

Reglas:

- validar sintaxis INI minima al guardar
- recargar configuracion en memoria tras guardar
- no corregir automaticamente contenido del usuario
- mostrar errores de parseo con suficiente detalle

Debe ofrecer navegacion directa al menu principal y al listado de conexiones.

#### 6. Pantalla de diagnostico admin

Debe existir una pantalla de diagnostico simple y util.

Debe mostrar:

- ruta efectiva de `dbxconnections.ini`
- ruta efectiva de `dbxdrivers`
- ruta efectiva de `reportmanserver.ini`
- numero de conexiones cargadas
- drivers disponibles
- mensajes de diagnostico relevantes

#### 7. Configuracion del servidor

Debe administrar, como minimo, claves funcionales de `[CONFIG]` y `[SECURITY]` de `reportmanserver.ini`.

Debe incluir:

- `PAGESDIR`
- `TCPPORT`
- `LOGFILE`
- `LOG_JSON`
- `USER_ACCESS`
- `API_KEY_ACCESS`
- `SHOWUNAUTHORIZEDPAGE`
- `URLGETPARAMS`

Formulario concreto propuesto:

- bloque `General`
- campo `PAGESDIR`
- campo `TCPPORT`
- campo `LOGFILE`
- checkbox `LOG_JSON`
- bloque `Seguridad`
- checkbox `USER_ACCESS`
- checkbox `API_KEY_ACCESS`
- checkbox `SHOWUNAUTHORIZEDPAGE`
- checkbox `URLGETPARAMS`
- boton `Guardar`
- boton `Cancelar`
- enlace `Volver a Admin`

Comportamiento esperado:

- validacion de campos antes de guardar
- mostrar la ruta efectiva del INI que se esta modificando
- no mezclar en esta pantalla usuarios, grupos o aliases

#### 8. Usuarios y grupos

Debe permitir:

- listar usuarios
- crear usuario
- cambiar password
- marcar o desmarcar admin
- borrar usuario
- editar grupos del usuario

La nocion de admin debe modelarse de forma explicita en la UI, aunque internamente se siga respetando la semantica actual de `ADMIN` en el INI.

Formulario concreto de usuario:

- campo `user_name`
- checkbox `is_admin`
- lista de grupos con multiseleccion o checkboxes
- campo `user_password`
- checkbox `change_password` al editar
- boton `Guardar`
- boton `Borrar` cuando aplique
- boton `Cancelar`

Reglas funcionales:

- no permitir borrar el ultimo admin valido
- no permitir quitar privilegios al ultimo admin valido
- si se renombra `ADMIN`, la semantica interna debe seguir siendo consistente con el modelo elegido

Pantalla de grupos:

- listado de grupos
- alta rapida de grupo
- edicion de nombre y descripcion
- borrado con validacion de referencias

#### 9. Aliases de informes

Debe permitir:

- listar aliases
- editar nombre y ruta
- distinguir alias de carpeta de alias de conexion `:NAME`
- asignar grupos permitidos a cada alias

Como los informes pueden vivir en un volumen separado, esta pantalla es critica y debe ser facil de usar.

Formulario concreto de alias:

- campo `alias_name`
- selector `alias_type` con valores `folder` y `connection`
- campo `alias_target`
- ayuda visible indicando que `connection` se almacena como `:NAME`
- grupos permitidos del alias mediante checkboxes
- boton `Guardar`
- boton `Borrar` cuando aplique
- boton `Cancelar`

Reglas funcionales:

- validar si la ruta de carpeta existe cuando el alias es de tipo `folder`
- permitir rutas a volumenes montados del contenedor
- no exigir que el volumen este dentro del arbol de aplicacion
- si el alias es de tipo `connection`, validar formato `:NAME`

#### 10. API keys

Debe permitir:

- listar API keys logicas
- crear una nueva API key con secreto generado
- asociarla a un usuario interno existente
- revocarla o regenerarla

El secreto solo debe mostrarse completo en el momento de creacion o regeneracion.

Formulario concreto de API key:

- campo `api_key_name`
- selector `api_key_user`
- boton `Crear API key`
- boton `Regenerar` por fila existente
- boton `Revocar` por fila existente

Reglas funcionales:

- el nombre logico debe ser unico
- debe apuntar siempre a un usuario existente
- la regeneracion invalida inmediatamente el secreto anterior
- el secreto plano solo se muestra una vez tras crear o regenerar

#### 10.b. Formularios minimos de Fase 1A

Para que la primera entrega sea util, deben existir como minimo estas pantallas HTML concretas:

1. `Bootstrap admin`
2. `Login admin`
3. `Menu principal admin`
4. `Configuracion del servidor`
5. `Usuarios`
6. `Editar usuario`
7. `Grupos`
8. `Aliases`
9. `Editar alias`
10. `API keys`
11. `Diagnostico`

No es obligatorio que todas tengan diseño rico, pero si que cubran el flujo completo.

### Seguridad

El area admin debe quedar separada de las paginas publicas de informes.

Requisitos:

- autenticacion fuerte
- sin acceso anonimo
- sin exponer contrasenas en claro al volver a renderizar cuando no haga falta
- registrar accesos administrativos y operaciones de guardado o prueba
- proteger bootstrap para que solo exista mientras no haya admin valido
- no mostrar secretos completos de API keys salvo en creacion o regeneracion

### Escritura en disco

En esta primera fase, la unica escritura funcional necesaria sera:

- `dbxconnections.ini`
- `reportmanserver.ini`
- opcionalmente logs del servicio

No debe haber escritura sobre binarios o sobre el arbol de aplicacion.

### Concurrencia y consistencia

Como el backend escribira un fichero INI compartido, conviene:

- serializar escrituras
- releer desde disco antes de guardar
- evitar sobrescrituras silenciosas entre modo asistido y modo manual
- hacer backup opcional antes de guardar en modo manual

### Resultado esperado de la fase 1

Un `repwebexe` con panel admin capaz de configurar conexiones reales, usuarios, grupos, aliases, API keys y configuracion funcional del servidor dentro del contenedor sin depender de herramientas externas ni de edicion manual obligatoria del sistema de ficheros.

### Especificacion de implementacion de la fase 1

#### Objetivo de implementacion

La implementacion debe evitar duplicar logica ya existente en VCL y en `rpdatainfo`. La parte web debe actuar como una capa HTTP y HTML sobre servicios Delphi reutilizables.

La regla principal es esta:

- la logica de negocio de conexiones debe quedar en unidades reutilizables
- la capa web solo debe traducir request y response
- la persistencia debe seguir saliendo de `TRpConnAdmin` y de las clases de datos ya existentes

Ademas, el area admin debe ser navegable y facil de usar. El usuario debe poder entrar por `/admin` y acceder desde ahi a todas las operaciones principales sin recordar rutas internas.

#### Unidades Delphi a crear o refactorizar

Se recomienda introducir una pequeña capa de administracion web de conexiones en `server/web`.

Propuesta inicial:

- una unidad de servicios, por ejemplo `rpwebdbxadmin.pas`
- una unidad opcional para renderizado HTML admin, por ejemplo `rpwebadminpages.pas`
- ampliaciones puntuales en `rpwebpages.pas` para enrutar URLs admin
- cambios minimos en `rpwebmodule.pas` solo si hacen falta para exponer nuevos endpoints

#### Flujo de navegacion principal esperado

El flujo base debe ser este:

1. el usuario entra en `/admin`
2. ve un menu principal con acciones claras
3. elige `Configuracion del servidor`, `Usuarios`, `Grupos`, `Aliases`, `API keys`, `Conexiones`, `Edicion manual` o `Diagnostico`
4. desde cualquier pantalla puede volver a `/admin`

No se debe asumir que el usuario aterrice directamente en una URL profunda.

En la primera entrega real, las opciones de `Configuracion del servidor`, `Usuarios`, `Grupos`, `Aliases`, `API keys` y `Diagnostico` son prioritarias sobre `Conexiones`.

#### Firmas Delphi concretas propuestas

La siguiente propuesta intenta dejar cerrados los contratos principales sin forzar todavia todos los detalles internos.

##### `rpwebdbxadmin.pas`

Esta unidad pertenece a la Fase 1B, no a la primera entrega.

```pascal
unit rpwebdbxadmin;

interface

uses
	Classes, SysUtils, Generics.Collections, rpdatainfo;

type
	TRpWebEditorKind = (
		weText,
		wePassword,
		weCombo,
		weReadOnly,
		weTextArea
	);

	TRpWebConnectionParam = record
		Name: string;
		Value: string;
		OriginalValue: string;
		IsSensitive: Boolean;
		IsReadOnly: Boolean;
		EditorKind: TRpWebEditorKind;
		Options: TStringList;
		class function Create: TRpWebConnectionParam; static;
		procedure Clear;
	end;

	TRpWebConnectionItem = record
		Name: string;
		DriverName: string;
		DisplayDriverName: string;
	end;

	TRpWebConnectionTestResult = record
		Success: Boolean;
		MessageText: string;
		DriverName: string;
		SafeDetails: TStringList;
		class function Create: TRpWebConnectionTestResult; static;
		procedure Clear;
	end;

	TRpWebRawConfigResult = record
		Success: Boolean;
		MessageText: string;
		ConfigText: string;
		BackupFileName: string;
	end;

	TRpWebEffectiveConfigInfo = record
		DriversFileName: string;
		ConnectionsFileName: string;
		DriversOverride: string;
		ConnectionsOverride: string;
	end;

	TRpWebAdminSaveMode = (
		wsmAssisted,
		wsmRaw
	);

	TRpWebDbxAdminService = class
	private
		FConnectionsOverride: string;
		FDriversOverride: string;
		function CreateConnAdmin: TRpConnAdmin;
		function IsSensitiveParam(const AName: string): Boolean;
		function IsReadOnlyParam(const AName: string): Boolean;
		function ResolveEditorKind(const AName: string; const AValue: string;
			AOptions: TStrings): TRpWebEditorKind;
		procedure FillDriverOptions(AConnAdmin: TRpConnAdmin;
			const AParamName: string; AOptions: TStrings);
		procedure ValidateConnectionName(const AName: string);
		procedure ReloadAfterWrite;
	public
		constructor Create(const AConnectionsOverride: string = '';
			const ADriversOverride: string = '');

		function GetEffectiveConfigInfo: TRpWebEffectiveConfigInfo;

		procedure ListConnections(AItems: TList<TRpWebConnectionItem>;
			const ADriverFilter: string = '');
		procedure ListDrivers(ADrivers: TStrings);
		procedure GetConnectionParams(const AConnectionName: string;
			AParams: TList<TRpWebConnectionParam>);

		procedure CreateConnection(const AConnectionName, ADriverName: string);
		procedure UpdateConnectionParams(const AConnectionName: string;
			AValues: TStrings);
		procedure DeleteConnection(const AConnectionName: string);

		function LoadRawDbxConnections: TRpWebRawConfigResult;
		function SaveRawDbxConnections(const AConfigText: string;
			const ACreateBackup: Boolean = True): TRpWebRawConfigResult;

		function TestConnection(const AConnectionName: string): TRpWebConnectionTestResult;
		function TestConnectionValues(const AConnectionName: string;
			AValues: TStrings): TRpWebConnectionTestResult;
	end;

implementation
```

Notas sobre esta firma:

- `CreateConnAdmin` debe crear una instancia fresca por operacion, para evitar estado compartido entre requests HTTP.
- `TestConnectionValues` queda prevista para el modo avanzado de probar cambios aun no guardados.
- `TStrings` se usa en actualizacion y pruebas temporales para reducir friccion con `TRpConnAdmin`.

##### `rpwebserverconfigadmin.pas`

Esta unidad pertenece a la Fase 1A y es la prioridad inicial de implementacion.

La administracion de `reportmanserver.ini` conviene separarla de `dbxconnections.ini` para no mezclar seguridad, aliases y conexiones de datos.

```pascal
unit rpwebserverconfigadmin;

interface

uses
	Classes, SysUtils, Generics.Collections;

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
		UserName: string;
		class function Create: TRpWebServerApiKey; static;
		procedure Clear;
	end;

	TRpWebServerSecurityConfig = record
		UserAccess: Boolean;
		ApiKeyAccess: Boolean;
		ShowUnauthorizedPage: Boolean;
		UrlGetParams: Boolean;
	end;

	TRpWebServerRuntimeConfig = record
		PagesDir: string;
		TcpPort: string;
		LogFile: string;
		LogJson: Boolean;
	end;

	TRpWebServerConfigInfo = record
		ConfigFileName: string;
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
		function GetConfigFileName: string;
		procedure ValidateUserName(const AUserName: string);
		procedure ValidateGroupName(const AGroupName: string);
		procedure ValidateAliasName(const AAliasName: string);
		procedure ValidateApiKeyName(const AKeyName: string);
		procedure ReloadAfterWrite;
	public
		constructor Create(const AConfigOverride: string = '');

		function GetConfigInfo: TRpWebServerConfigInfo;
		function BootstrapRequired: Boolean;
		procedure BootstrapFirstAdmin(const ABootstrap: TRpWebBootstrapRequest);

		function LoadServerConfigFormData: TRpWebServerConfigFormData;
		function LoadRuntimeConfig: TRpWebServerRuntimeConfig;
		function LoadSecurityConfig: TRpWebServerSecurityConfig;
		procedure SaveServerConfigFormData(const AData: TRpWebServerConfigFormData);
		procedure SaveRuntimeConfig(const AConfig: TRpWebServerRuntimeConfig);
		procedure SaveSecurityConfig(const AConfig: TRpWebServerSecurityConfig);

		procedure ListUsers(AUsers: TList<TRpWebServerUser>);
		procedure GetUser(const AUserName: string; out AUser: TRpWebServerUser);
		function LoadUserEditRequest(const AUserName: string): TRpWebUserEditRequest;
		procedure CreateUser(const AUserName, APassword: string;
			const AIsAdmin: Boolean; AGroups: TStrings);
		procedure SaveUserEditRequest(const ARequest: TRpWebUserEditRequest;
			const AIsNew: Boolean);
		procedure UpdateUser(const AOriginalUserName, ANewUserName: string;
			const APassword: string; const AChangePassword: Boolean;
			const AIsAdmin: Boolean; AGroups: TStrings);
		procedure DeleteUser(const AUserName: string);
		function CanDeleteUser(const AUserName: string; out AReason: string): Boolean;

		procedure ListGroups(AGroups: TList<TRpWebServerGroup>);
		function LoadGroupEditRequest(const AGroupName: string): TRpWebGroupEditRequest;
		procedure CreateGroup(const AGroupName, ADescription: string);
		procedure SaveGroupEditRequest(const ARequest: TRpWebGroupEditRequest;
			const AIsNew: Boolean);
		procedure UpdateGroup(const AOriginalGroupName, ANewGroupName,
			ADescription: string);
		procedure DeleteGroup(const AGroupName: string);

		procedure ListAliases(AAliases: TList<TRpWebServerAlias>);
		procedure GetAlias(const AAliasName: string; out AAlias: TRpWebServerAlias);
		function LoadAliasEditRequest(const AAliasName: string): TRpWebAliasEditRequest;
		procedure CreateAlias(const AAliasName, ATargetValue: string;
			AAllowedGroups: TStrings);
		procedure SaveAliasEditRequest(const ARequest: TRpWebAliasEditRequest;
			const AIsNew: Boolean);
		procedure UpdateAlias(const AOriginalAliasName, ANewAliasName,
			ATargetValue: string; AAllowedGroups: TStrings);
		procedure DeleteAlias(const AAliasName: string);
		function ValidateAliasTarget(const AAliasType: TRpWebAliasType;
			const ATargetValue: string): string;

		procedure ListApiKeys(AKeys: TList<TRpWebServerApiKey>);
		function LoadApiKeyCreateRequest: TRpWebApiKeyCreateRequest;
		function SaveApiKeyCreateRequest(
			const ARequest: TRpWebApiKeyCreateRequest): TRpWebGeneratedApiKeyResult;
		function CreateApiKey(const AKeyName, AUserName: string): TRpWebGeneratedApiKeyResult;
		function RegenerateApiKey(const AKeyName: string): TRpWebGeneratedApiKeyResult;
		procedure DeleteApiKey(const AKeyName: string);
		function IsLastAdmin(const AUserName: string): Boolean;
	end;

implementation
```

Notas sobre esta firma:

- esta unidad debe trabajar sobre la estructura real de `reportmanserver.ini`, incluyendo secciones dinamicas `USERGROUPS<USER>` y `GROUPALLOW<ALIAS>`.
- `BootstrapRequired` debe ser el gate central para decidir si se presenta `/admin/bootstrap` o el login admin normal.
- `CreateApiKey` y `RegenerateApiKey` deben devolver el secreto plano solo una vez.

##### `rpwebadminauth.pas`

Esta unidad pertenece a la Fase 1A porque el bootstrap y el login admin dependen de ella.

Para no mezclar autenticacion admin con la autenticacion funcional del servidor web, conviene una pequeña unidad de apoyo.

```pascal
unit rpwebadminauth;

interface

uses
	Classes, SysUtils, rpwebserverconfigadmin;

type
	TRpWebAdminAuthResult = record
		Success: Boolean;
		UserName: string;
		IsAdmin: Boolean;
		BootstrapRequired: Boolean;
		MessageText: string;
	end;

	TRpWebAdminAuthService = class
	public
		class function TryLogin(const AUserName, APassword: string;
			const AConfigOverride: string = ''): TRpWebAdminAuthResult; static;
		class function BootstrapRequired(const AConfigOverride: string = ''): Boolean; static;
	end;

implementation
```

Notas sobre esta firma:

- la UI admin debe usar este servicio para decidir si enseña bootstrap, login o menu principal.
- si en el futuro se añade sesion o cookie, esta unidad es el sitio correcto para centralizar la validacion.

##### `rpwebdbxtest.pas`

Conviene extraer la prueba de conexion a una unidad separada y no visual.

```pascal
unit rpwebdbxtest;

interface

uses
	Classes, SysUtils, rpdatainfo, rpwebdbxadmin;

type
	TRpDbxConnectionTester = class
	public
		class function TestSavedConnection(AConnAdmin: TRpConnAdmin;
			const AConnectionName: string): TRpWebConnectionTestResult; static;
		class function TestConnectionParams(const AConnectionName: string;
			AParams: TStrings; AConnAdmin: TRpConnAdmin): TRpWebConnectionTestResult; static;
	end;

implementation
```

Notas sobre esta firma:

- `TestSavedConnection` cubre el primer hito funcional.
- `TestConnectionParams` permite reutilizar despues el boton `Probar` antes de `Guardar`.
- esta unidad debe contener la logica hoy embebida en `rpdbxconfigvcl.pas`.

##### `rpwebadminpages.pas`

Si se quiere aislar HTML del servicio, una firma razonable seria esta:

```pascal
unit rpwebadminpages;

interface

uses
	Classes, SysUtils, Generics.Collections, rpwebdbxadmin;

type
	TRpWebAdminPageRenderer = class
	public
		class function RenderBootstrapPage(const AMessageText: string): string; static;
		class function RenderAdminLoginPage(const AMessageText: string): string; static;
		class function RenderAdminHome(
			const AConfigInfo: TRpWebEffectiveConfigInfo;
			const AConnectionCount: Integer; ADrivers: TStrings;
			const AServerInfo: TRpWebServerConfigInfo): string; static;
		class function RenderConnectionsList(
			const AItems: TList<TRpWebConnectionItem>): string; static;
		class function RenderConnectionEdit(const AConnectionName: string;
			const AParams: TList<TRpWebConnectionParam>): string; static;
		class function RenderConnectionNew(ADrivers: TStrings): string; static;
		class function RenderConnectionRaw(const AConfigText, AMessageText: string): string; static;
		class function RenderConnectionTest(const AConnectionName: string;
			const AResult: TRpWebConnectionTestResult): string; static;
		class function RenderServerConfig(
			const AData: TRpWebServerConfigFormData): string; static;
		class function RenderUsersList(const AUsers: TList<TRpWebServerUser>): string; static;
		class function RenderUserEdit(const ARequest: TRpWebUserEditRequest;
			AAllGroups: TStrings; const AIsNew: Boolean): string; static;
		class function RenderGroupsList(const AGroups: TList<TRpWebServerGroup>): string; static;
		class function RenderGroupEdit(const ARequest: TRpWebGroupEditRequest;
			const AIsNew: Boolean): string; static;
		class function RenderAliasesList(const AAliases: TList<TRpWebServerAlias>): string; static;
		class function RenderAliasEdit(const ARequest: TRpWebAliasEditRequest;
			AAllGroups: TStrings; const AIsNew: Boolean): string; static;
		class function RenderApiKeysList(const AKeys: TList<TRpWebServerApiKey>): string; static;
		class function RenderApiKeyNew(AUsers: TStrings): string; static;
		class function RenderApiKeyCreated(
			const AResult: TRpWebGeneratedApiKeyResult): string; static;
		class function RenderDiagnostics(const AConfigInfo: TRpWebEffectiveConfigInfo;
			const AItems: TList<TRpWebConnectionItem>; ADrivers: TStrings;
			const AServerInfo: TRpWebServerConfigInfo;
			const AMessageText: string): string; static;
		class function RenderError(const ATitle, AMessageText: string): string; static;
	end;

implementation
```

Notas sobre esta firma:

- si el renderizado acaba siendo simple, estas funciones podrian vivir directamente en `rpwebpages.pas`.
- si crecen varias plantillas admin, esta separacion evita inflar `rpwebpages.pas`.
- en la primera entrega deben implementarse primero `RenderBootstrapPage`, `RenderAdminLoginPage`, `RenderAdminHome`, `RenderServerConfig`, `RenderUsersList`, `RenderGroupsList`, `RenderAliasesList`, `RenderApiKeysList` y `RenderDiagnostics`.
- `RenderConnectionsList`, `RenderConnectionEdit`, `RenderConnectionNew`, `RenderConnectionRaw` y `RenderConnectionTest` pertenecen a la Fase 1B.

##### Cambios concretos propuestos en `rpwebpages.pas`

No hace falta mover toda la logica a esta unidad, pero si cerrar un pequeno contrato de entrada.

Firmas sugeridas:

```pascal
type
	TRpWebPageLoader = class(TComponent)
	private
		function IsAdminRoute(const APathInfo: string): Boolean;
		function IsBootstrapRoute(const APathInfo: string): Boolean;
		procedure CheckBootstrapAllowed;
		procedure CheckAdminLogin(Request: TWebRequest;
			out AUserName: string; out AIsAdmin: Boolean);

		function LoadAdminBootstrapPage(Request: TWebRequest): string;
		function ExecuteAdminBootstrap(Request: TWebRequest): string;
		function LoadAdminLoginPage(Request: TWebRequest): string;
		function ExecuteAdminLogin(Request: TWebRequest): string;
		function LoadAdminHomePage(Request: TWebRequest): string;
		function LoadAdminServerConfigPage(Request: TWebRequest): string;
		function ExecuteAdminServerConfigSave(Request: TWebRequest): string;
		function LoadAdminUsersPage(Request: TWebRequest): string;
		function LoadAdminUserEditPage(Request: TWebRequest): string;
		function ExecuteAdminUserCreate(Request: TWebRequest): string;
		function ExecuteAdminUserSave(Request: TWebRequest): string;
		function ExecuteAdminUserDelete(Request: TWebRequest): string;
		function LoadAdminGroupsPage(Request: TWebRequest): string;
		function ExecuteAdminGroupCreate(Request: TWebRequest): string;
		function ExecuteAdminGroupSave(Request: TWebRequest): string;
		function ExecuteAdminGroupDelete(Request: TWebRequest): string;
		function LoadAdminAliasesPage(Request: TWebRequest): string;
		function LoadAdminAliasEditPage(Request: TWebRequest): string;
		function ExecuteAdminAliasCreate(Request: TWebRequest): string;
		function ExecuteAdminAliasSave(Request: TWebRequest): string;
		function ExecuteAdminAliasDelete(Request: TWebRequest): string;
		function LoadAdminApiKeysPage(Request: TWebRequest): string;
		function ExecuteAdminApiKeyCreate(Request: TWebRequest): string;
		function ExecuteAdminApiKeyDelete(Request: TWebRequest): string;
		function LoadAdminConnectionsPage(Request: TWebRequest): string;
		function LoadAdminConnectionNewPage(Request: TWebRequest): string;
		function LoadAdminConnectionEditPage(Request: TWebRequest): string;
		function LoadAdminDiagnosticsPage(Request: TWebRequest): string;
		function ExecuteAdminConnectionCreate(Request: TWebRequest): string;
		function ExecuteAdminConnectionSave(Request: TWebRequest): string;
		function ExecuteAdminConnectionDelete(Request: TWebRequest): string;
		function ExecuteAdminConnectionTest(Request: TWebRequest): string;
		function LoadAdminRawConnectionsPage(Request: TWebRequest): string;
		function ExecuteAdminRawConnectionsSave(Request: TWebRequest): string;
	end;
```

Notas sobre esta firma:

- `Load...Page` devuelve HTML para `GET`.
- `Execute...` procesa `POST` y puede devolver HTML de resultado o una redireccion renderizada.
- `CheckAdminLogin` debe validar autenticacion y permiso admin sin mezclarlo con privilegios normales de acceso a alias.
- la primera entrega debe implementar primero: bootstrap, login admin, home admin, server config, users, groups, aliases, apikeys y diagnostics.
- los handlers de `dbxconnections.ini` quedan planificados para la segunda entrega de esta fase.

##### Mapeo exacto Fase 1A: ruta -> handler -> servicio -> renderer

La implementacion de la primera entrega debe seguir este mapa operativo.

###### 1. Entrada admin y bootstrap

Ruta:

- `GET /admin`

Handler principal:

- `LoadAdminHomePage`

Decision interna esperada:

1. consultar `TRpWebAdminAuthService.BootstrapRequired`
2. si `True`, redirigir funcionalmente a `LoadAdminBootstrapPage`
3. si no hay sesion admin valida, redirigir funcionalmente a `LoadAdminLoginPage`
4. si hay admin autenticado, cargar datos del dashboard y renderizar home

Servicios implicados:

- `TRpWebAdminAuthService`
- `TRpWebServerConfigAdminService.GetConfigInfo`
- `TRpWebServerConfigAdminService.ListUsers` o contadores equivalentes
- `TRpWebServerConfigAdminService.ListGroups` o contadores equivalentes
- `TRpWebServerConfigAdminService.ListAliases` o contadores equivalentes

Renderer:

- `RenderAdminHome`

Ruta:

- `GET /admin/bootstrap`

Handler:

- `LoadAdminBootstrapPage`

Servicios:

- `TRpWebAdminAuthService.BootstrapRequired`

Renderer:

- `RenderBootstrapPage`

Ruta:

- `POST /admin/bootstrap`

Handler:

- `ExecuteAdminBootstrap`

Servicios:

- `TRpWebRequestHelper.RequireParam`
- `TRpWebServerConfigAdminService.BootstrapFirstAdmin`

Renderer o salida:

- en error: `RenderBootstrapPage`
- en exito: redireccion funcional a `LoadAdminLoginPage` o `LoadAdminHomePage`

###### 2. Login admin

Ruta:

- `GET /admin/login`

Handler:

- `LoadAdminLoginPage`

Servicios:

- `TRpWebAdminAuthService.BootstrapRequired`

Renderer:

- `RenderAdminLoginPage`

Ruta:

- `POST /admin/login`

Handler:

- `ExecuteAdminLogin`

Servicios:

- `TRpWebRequestHelper.RequireParam`
- `TRpWebAdminAuthService.TryLogin`

Renderer o salida:

- en error: `RenderAdminLoginPage`
- en exito: redireccion funcional a `LoadAdminHomePage`

###### 3. Dashboard admin

Ruta:

- `GET /admin`

Handler:

- `LoadAdminHomePage`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.GetConfigInfo`
- `TRpWebDbxAdminService.GetEffectiveConfigInfo` solo para mostrar rutas, aunque la Fase 1B no este implementada aun

Renderer:

- `RenderAdminHome`

###### 4. Configuracion del servidor

Ruta:

- `GET /admin/server-config`

Handler:

- `LoadAdminServerConfigPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.LoadServerConfigFormData`

Renderer:

- `RenderServerConfig`

Ruta:

- `POST /admin/server-config`

Handler:

- `ExecuteAdminServerConfigSave`

Servicios:

- `CheckAdminLogin`
- `TRpWebRequestHelper.RequireParam` y `OptionalParam`
- `TRpWebServerConfigAdminService.SaveServerConfigFormData`
- `TRpWebServerConfigAdminService.LoadServerConfigFormData`

Renderer o salida:

- en error: `RenderServerConfig`
- en exito: `RenderServerConfig` con mensaje o redireccion al mismo GET

###### 5. Usuarios

Ruta:

- `GET /admin/users`

Handler:

- `LoadAdminUsersPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.ListUsers`

Renderer:

- `RenderUsersList`

Ruta:

- `GET /admin/users/new`

Handler:

- `LoadAdminUserEditPage`

Servicios:

- `CheckAdminLogin`
- inicializacion vacia de `TRpWebUserEditRequest`
- `TRpWebServerConfigAdminService.ListGroups`

Renderer:

- `RenderUserEdit`

Ruta:

- `GET /admin/users/edit?name=...`

Handler:

- `LoadAdminUserEditPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.LoadUserEditRequest`
- `TRpWebServerConfigAdminService.ListGroups`

Renderer:

- `RenderUserEdit`

Ruta:

- `POST /admin/users/new`

Handler:

- `ExecuteAdminUserCreate`

Servicios:

- `CheckAdminLogin`
- `TRpWebRequestHelper.RequireParam`
- `TRpWebRequestHelper.CollectServerUserGroups`
- `TRpWebServerConfigAdminService.SaveUserEditRequest`

Renderer o salida:

- en error: `RenderUserEdit`
- en exito: redireccion a `LoadAdminUsersPage`

Ruta:

- `POST /admin/users/edit`

Handler:

- `ExecuteAdminUserSave`

Servicios:

- `CheckAdminLogin`
- `TRpWebRequestHelper.RequireParam`
- `TRpWebRequestHelper.CollectServerUserGroups`
- `TRpWebServerConfigAdminService.SaveUserEditRequest`

Renderer o salida:

- en error: `RenderUserEdit`
- en exito: redireccion a `LoadAdminUsersPage`

Ruta:

- `POST /admin/users/delete`

Handler:

- `ExecuteAdminUserDelete`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.CanDeleteUser`
- `TRpWebServerConfigAdminService.DeleteUser`

Renderer o salida:

- en error: `RenderUsersList` o `RenderError`
- en exito: redireccion a `LoadAdminUsersPage`

###### 6. Grupos

Ruta:

- `GET /admin/groups`

Handler:

- `LoadAdminGroupsPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.ListGroups`

Renderer:

- `RenderGroupsList`

Ruta:

- `POST /admin/groups/new`

Handler:

- `ExecuteAdminGroupCreate`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.SaveGroupEditRequest`

Renderer o salida:

- en error: `RenderGroupEdit` o `RenderGroupsList`
- en exito: redireccion a `LoadAdminGroupsPage`

Ruta:

- `POST /admin/groups/edit`

Handler:

- `ExecuteAdminGroupSave`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.SaveGroupEditRequest`

Renderer o salida:

- en error: `RenderGroupEdit`
- en exito: redireccion a `LoadAdminGroupsPage`

Ruta:

- `POST /admin/groups/delete`

Handler:

- `ExecuteAdminGroupDelete`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.DeleteGroup`

Renderer o salida:

- en error: `RenderGroupsList` o `RenderError`
- en exito: redireccion a `LoadAdminGroupsPage`

###### 7. Aliases de informes

Ruta:

- `GET /admin/aliases`

Handler:

- `LoadAdminAliasesPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.ListAliases`

Renderer:

- `RenderAliasesList`

Ruta:

- `GET /admin/aliases/edit?name=...`

Handler:

- `LoadAdminAliasEditPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.LoadAliasEditRequest`
- `TRpWebServerConfigAdminService.ListGroups`

Renderer:

- `RenderAliasEdit`

Ruta:

- `POST /admin/aliases/new`

Handler:

- `ExecuteAdminAliasCreate`

Servicios:

- `CheckAdminLogin`
- `TRpWebRequestHelper.CollectAliasAllowedGroups`
- `TRpWebServerConfigAdminService.SaveAliasEditRequest`

Renderer o salida:

- en error: `RenderAliasEdit`
- en exito: redireccion a `LoadAdminAliasesPage`

Ruta:

- `POST /admin/aliases/edit`

Handler:

- `ExecuteAdminAliasSave`

Servicios:

- `CheckAdminLogin`
- `TRpWebRequestHelper.CollectAliasAllowedGroups`
- `TRpWebServerConfigAdminService.ValidateAliasTarget`
- `TRpWebServerConfigAdminService.SaveAliasEditRequest`

Renderer o salida:

- en error: `RenderAliasEdit`
- en exito: redireccion a `LoadAdminAliasesPage`

Ruta:

- `POST /admin/aliases/delete`

Handler:

- `ExecuteAdminAliasDelete`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.DeleteAlias`

Renderer o salida:

- en error: `RenderAliasesList` o `RenderError`
- en exito: redireccion a `LoadAdminAliasesPage`

###### 8. API keys

Ruta:

- `GET /admin/apikeys`

Handler:

- `LoadAdminApiKeysPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.ListApiKeys`
- `TRpWebServerConfigAdminService.ListUsers`

Renderer:

- `RenderApiKeysList`

Ruta:

- `POST /admin/apikeys/new`

Handler:

- `ExecuteAdminApiKeyCreate`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.SaveApiKeyCreateRequest`

Renderer o salida:

- en error: `RenderApiKeysList` o `RenderError`
- en exito: `RenderApiKeyCreated`

Ruta:

- `POST /admin/apikeys/delete`

Handler:

- `ExecuteAdminApiKeyDelete`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.DeleteApiKey`

Renderer o salida:

- en error: `RenderApiKeysList` o `RenderError`
- en exito: redireccion a `LoadAdminApiKeysPage`

###### 9. Diagnostico admin

Ruta:

- `GET /admin/diagnostics`

Handler:

- `LoadAdminDiagnosticsPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebServerConfigAdminService.GetConfigInfo`
- `TRpWebDbxAdminService.GetEffectiveConfigInfo`
- `TRpWebServerConfigAdminService.ListAliases`
- `TRpWebServerConfigAdminService.ListGroups`
- `TRpWebServerConfigAdminService.ListUsers`

Renderer:

- `RenderDiagnostics`

##### Mapeo exacto Fase 1B: ruta -> handler -> servicio -> renderer

La segunda entrega del area admin debe seguir este mapa operativo para `dbxconnections.ini`.

###### 1. Listado de conexiones

Ruta:

- `GET /admin/connections`

Handler:

- `LoadAdminConnectionsPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebDbxAdminService.ListConnections`
- `TRpWebDbxAdminService.GetEffectiveConfigInfo`

Renderer:

- `RenderConnectionsList`

Notas de salida:

- la pagina debe mostrar nombre de conexion, driver, resumen no sensible de parametros y acciones `Editar`, `Probar`, `Borrar`
- la pagina debe incluir enlace visible a `Nueva conexion`, `Editar dbxconnections.ini manualmente` y `Volver a Admin`

###### 2. Alta de conexion

Ruta:

- `GET /admin/connections/new`

Handler:

- `LoadAdminConnectionNewPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebDbxAdminService.ListDrivers`

Renderer:

- `RenderConnectionNew`

Ruta:

- `POST /admin/connections/new`

Handler:

- `ExecuteAdminConnectionCreate`

Servicios:

- `CheckAdminLogin`
- `TRpWebRequestHelper.RequireParam` para `connection_name`
- `TRpWebRequestHelper.RequireParam` para `driver_name`
- `TRpWebDbxAdminService.CreateConnection`

Renderer o salida:

- en error: `RenderConnectionNew`
- en exito: redireccion funcional a `LoadAdminConnectionEditPage` de la conexion creada

###### 3. Edicion asistida de conexion

Ruta:

- `GET /admin/connections/edit?name=...`

Handler:

- `LoadAdminConnectionEditPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebRequestHelper.RequireParam` para `name`
- `TRpWebDbxAdminService.GetConnectionParams`

Renderer:

- `RenderConnectionEdit`

Ruta:

- `POST /admin/connections/edit`

Handler:

- `ExecuteAdminConnectionSave`

Servicios:

- `CheckAdminLogin`
- `TRpWebRequestHelper.RequireParam` para `connection_name`
- `TRpWebRequestHelper.CollectConnectionParamValues`
- `TRpWebDbxAdminService.UpdateConnectionParams`
- `TRpWebDbxAdminService.GetConnectionParams` para recargar estado confirmado

Renderer o salida:

- en error: `RenderConnectionEdit`
- en exito: `RenderConnectionEdit` con mensaje o redireccion al mismo `GET`

Regla local:

- el handler no debe decidir manualmente que claves son editables; esa decision pertenece a `TRpWebDbxAdminService`

###### 4. Prueba de conexion

Ruta:

- `POST /admin/connections/test`

Handler:

- `ExecuteAdminConnectionTest`

Servicios:

- `CheckAdminLogin`
- `TRpWebRequestHelper.RequireParam` para `connection_name`
- `TRpWebRequestHelper.CollectConnectionParamValues` cuando se permita probar cambios no guardados
- `TRpWebDbxAdminService.TestConnection` para modo minimo viable
- `TRpWebDbxAdminService.TestConnectionValues` para modo deseable con overrides temporales

Renderer o salida:

- `RenderConnectionTest`

Decision funcional inicial:

1. si el formulario de prueba no trae overrides, usar `TestConnection`
2. si el formulario trae pares editados, usar `TestConnectionValues`
3. en la primera implementacion se puede dejar `TestConnectionValues` como opcion prevista y ejecutar solo `TestConnection`

###### 5. Borrado de conexion

Ruta:

- `POST /admin/connections/delete`

Handler:

- `ExecuteAdminConnectionDelete`

Servicios:

- `CheckAdminLogin`
- `TRpWebRequestHelper.RequireParam` para `connection_name`
- `TRpWebDbxAdminService.DeleteConnection`
- `TRpWebDbxAdminService.ListConnections`

Renderer o salida:

- en error: `RenderConnectionsList`
- en exito: redireccion funcional a `LoadAdminConnectionsPage`

###### 6. Edicion manual completa de dbxconnections.ini

Ruta:

- `GET /admin/connections/raw`

Handler:

- `LoadAdminConnectionsRawPage`

Servicios:

- `CheckAdminLogin`
- `TRpWebDbxAdminService.LoadRawDbxConnections`
- `TRpWebDbxAdminService.GetEffectiveConfigInfo`

Renderer:

- `RenderConnectionRaw`

Ruta:

- `POST /admin/connections/raw`

Handler:

- `ExecuteAdminConnectionsRawSave`

Servicios:

- `CheckAdminLogin`
- `TRpWebRequestHelper.RequireParam` para `raw_config_text`
- `TRpWebRequestHelper.OptionalCheckbox` para `create_backup`
- `TRpWebDbxAdminService.SaveRawDbxConnections`
- `TRpWebDbxAdminService.LoadRawDbxConnections` para releer el estado persistido

Renderer o salida:

- en error: `RenderConnectionRaw`
- en exito: `RenderConnectionRaw` con mensaje de confirmacion y ruta efectiva

###### 7. Regla transversal de Fase 1B

Todos los handlers de Fase 1B deben seguir esta estructura comun:

1. validar login admin con `CheckAdminLogin`
2. parsear request con `TRpWebRequestHelper`
3. delegar la logica de negocio a `TRpWebDbxAdminService`
4. renderizar con `TRpWebAdminPageRenderer`
5. no leer ni escribir `dbxconnections.ini` directamente desde `rpwebpages.pas`
6. no decidir en el handler que parametros son sensibles, ocultables o de solo lectura

###### Regla transversal de Fase 1A

Todos los handlers de Fase 1A deben seguir esta estructura comun:

1. validar bootstrap o login admin segun corresponda
2. parsear request con `TRpWebRequestHelper`
3. delegar la logica de negocio a `TRpWebServerConfigAdminService`
4. renderizar con `TRpWebAdminPageRenderer`
5. no escribir directamente el INI desde `rpwebpages.pas`

##### Firmas auxiliares para parseo de request

Para evitar acoplar los handlers a `ContentFields`, conviene introducir helpers muy simples.

```pascal
type
	TRpWebRequestHelper = class
	public
		class function RequireParam(Request: TWebRequest;
			const AName: string): string; static;
		class function OptionalParam(Request: TWebRequest;
			const AName: string; const ADefault: string = ''): string; static;
		class procedure CollectConnectionValues(Request: TWebRequest;
			AValues: TStrings); static;
		class procedure CollectServerUserGroups(Request: TWebRequest;
			AGroups: TStrings); static;
		class procedure CollectAliasAllowedGroups(Request: TWebRequest;
			AGroups: TStrings); static;
	end;
```

Notas sobre esta firma:

- `CollectConnectionValues` debe recoger solo los campos editables del formulario asistido.
- los nombres internos del formulario conviene fijarlos con un prefijo estable, por ejemplo `cfg_`.

##### Convencion de nombres para el formulario web

Se recomienda esta traduccion para evitar ambiguedades:

- nombre de la conexion: `connection_name`
- nombre del driver al crear: `driver_name`
- parametros editables: `cfg_<PARAMNAME>`
- contenido manual del INI: `raw_config`
- flag de backup manual: `create_backup`
- nombre de usuario admin bootstrap: `bootstrap_user`
- password bootstrap: `bootstrap_password`
- confirmacion bootstrap: `bootstrap_password_confirm`
- usuario editable: `user_name`
- password editable: `user_password`
- flag cambiar password: `change_password`
- grupo editable: `group_name`
- alias editable: `alias_name`
- ruta o valor alias: `alias_target`
- grupos permitidos de alias: `alias_group_<GROUPNAME>`
- api key logica: `api_key_name`
- usuario asociado a api key: `api_key_user`

Con ello, `CollectConnectionValues` puede convertir `cfg_PASSWORD=...` en `PASSWORD=...` antes de llamar al servicio.

##### Requisito explicito de usabilidad

La implementacion HTML debe cumplir estos minimos:

- menu admin visible en la portada principal
- enlaces o breadcrumb de vuelta al menos a `Admin` y `Conexiones`
- botones claros de `Guardar`, `Probar`, `Volver` y `Cancelar` cuando proceda
- no depender de que el usuario recuerde nombres de endpoint
- lenguaje visible orientado a usuario funcional y no solo a desarrollador

##### Contrato minimo de excepciones

Todas las firmas anteriores deben trabajar con excepciones Delphi normales para errores funcionales.

Errores esperables:

- conexion inexistente
- driver inexistente
- nombre de conexion invalido
- error de parseo del INI
- error de acceso al fichero
- error real de apertura de conexion

En la capa web esos errores deben capturarse y renderizarse como HTML admin legible.

#### Responsabilidad de `rpwebdbxadmin.pas`

Debe concentrar las operaciones del editor de conexiones.

Metodos o funciones esperables:

- `ListConnections`
- `ListDrivers`
- `GetConnectionParams`
- `CreateConnection`
- `UpdateConnectionParams`
- `DeleteConnection`
- `LoadRawDbxConnections`
- `SaveRawDbxConnections`
- `TestConnection`
- `GetEffectiveConfigInfo`

Esta unidad no debe depender de controles VCL.

Debe reutilizar:

- `TRpConnAdmin`
- `TStringList` o `TMemIniFile` para parseo y persistencia
- la misma logica de test real que ahora existe en `rpdbxconfigvcl`

#### Responsabilidad de `rpwebadminpages.pas`

Si se separa el renderizado, esta unidad debe limitarse a construir HTML o respuestas de texto para el area admin.

Responsabilidades:

- renderizar listado de conexiones
- renderizar formulario de alta o edicion
- renderizar editor manual del INI
- renderizar pagina de resultado de prueba
- renderizar mensajes de error admin de forma consistente

No debe contener logica de acceso a base de datos ni escritura directa de configuracion.

#### Refactor necesario desde `rpdbxconfigvcl.pas`

La pieza mas sensible es la prueba de conexion.

Conviene extraer de `rpdbxconfigvcl.pas` la logica de prueba a una funcion reutilizable, por ejemplo en una unidad comun no visual. Esa funcion debe recibir:

- nombre de conexion o parametros efectivos
- objeto `TRpConnAdmin` o lista de parametros ya resuelta
- opcion para ocultar datos sensibles en el resultado

Y debe devolver un resultado estructurado:

- `Success`
- `Message`
- `DriverName`
- `SafeDetails`

Esto evita duplicar el bloque de pruebas DBX, FireDAC y Zeos en la parte web.

#### Modelo interno de datos recomendado

Para no acoplar HTML a `TStrings`, conviene introducir tipos simples.

Registros o clases sugeridas:

- `TRpWebConnectionItem`
- `TRpWebConnectionParam`
- `TRpWebConnectionTestResult`
- `TRpWebRawConfigResult`

Campos minimos sugeridos para `TRpWebConnectionItem`:

- `Name`
- `DriverName`
- `DisplayDriverName`

Campos minimos sugeridos para `TRpWebConnectionParam`:

- `Name`
- `Value`
- `IsSensitive`
- `IsReadOnly`
- `EditorKind`

`EditorKind` permitiria distinguir al menos:

- texto
- password
- combo
- readonly

#### Flujo HTTP propuesto

##### GET `/admin/connections`

Debe:

- autenticar
- cargar listado de conexiones
- renderizar pagina principal admin

##### GET `/admin/connections/new`

Debe:

- autenticar
- cargar drivers disponibles
- renderizar formulario de alta

##### POST `/admin/connections/new`

Debe:

- validar nombre de conexion
- validar driver
- crear seccion mediante `TRpConnAdmin.AddConnection`
- redirigir a edicion asistida

##### GET `/admin/connections/edit?name=...`

Debe:

- autenticar
- validar existencia de la conexion
- cargar parametros
- renderizar formulario dinamico

##### POST `/admin/connections/edit`

Debe:

- autenticar
- validar nombre de conexion
- actualizar solo los pares recibidos
- persistir fichero
- recargar configuracion
- mostrar resultado o redirigir

##### POST `/admin/connections/test`

Debe:

- autenticar
- leer el estado actual desde disco
- opcionalmente aplicar overrides temporales si se prueba antes de guardar
- ejecutar prueba real
- devolver pagina HTML o JSON sencillo con resultado

##### POST `/admin/connections/delete`

Debe:

- autenticar
- validar nombre de conexion
- borrar seccion
- persistir
- redirigir al listado

##### GET `/admin/connections/raw`

Debe:

- autenticar
- cargar contenido textual completo del INI
- mostrar editor manual

##### POST `/admin/connections/raw`

Debe:

- autenticar
- validar texto INI recibido
- crear backup opcional
- escribir fichero completo
- recargar `TRpConnAdmin`
- mostrar exito o error de parseo

#### Decisiones de interfaz web

La interfaz debe ser funcional antes que sofisticada.

Elementos recomendados:

- menu simple para cambiar entre listado y modo manual
- tabla de conexiones con acciones por fila
- formulario de pares `clave=valor`
- boton `Guardar`
- boton `Probar`
- boton `Volver al listado`

Para primera version no hace falta JavaScript complejo. Puede resolverse con formularios HTML clasicos y respuestas completas del servidor.

#### Manejo de campos sensibles

Hay que distinguir al menos estos casos:

- `PASSWORD`
- `User_Name` no sensible pero conviene tratarlo con cuidado
- cadenas de conexion ADO si en algun caso contienen password embebida
- cualquier otra clave que contenga `PASSWORD`, `PWD`, `SECRET`, `APIKEY` o `TOKEN`

Reglas:

- en edicion asistida, renderizar como password cuando proceda
- en respuestas de prueba, no devolver nunca secretos completos
- en logs, enmascarar valores sensibles

#### Estrategia de guardado asistido

Para evitar corrupciones, el guardado de una conexion debe seguir este flujo:

1. crear `TRpConnAdmin`
2. releer estado actual de `dbxconnections.ini`
3. validar que la seccion existe
4. actualizar solo las claves editables
5. llamar a `UpdateFile`
6. destruir y recrear el administrador para confirmar recarga limpia

No conviene mantener un `TRpConnAdmin` global mutable compartido entre requests si no hace falta.

#### Estrategia de edicion manual del INI

El modo manual necesita un tratamiento mas estricto.

Flujo recomendado:

1. recibir texto completo
2. validar que no este vacio
3. cargarlo en `TMemIniFile` temporal o mecanismo equivalente
4. comprobar que no falla el parseo
5. si es valido, hacer backup del fichero anterior con timestamp
6. escribir el nuevo contenido de una vez
7. recrear `TRpConnAdmin`
8. verificar que el nuevo fichero puede leerse

Si falla la recarga final, debe informarse claramente y conservar el backup.

#### Estrategia de prueba de conexion

Debe haber dos modos posibles, aunque solo uno sea obligatorio en primera version.

Modo 1, minimo viable:

- probar una conexion ya guardada por nombre

Modo 2, deseable:

- probar parametros aun no guardados mediante una seccion temporal en memoria

Para arrancar rapido, el plan base puede usar solo el modo 1. Si se quiere mejor UX, despues se añade el modo 2.

#### Autenticacion y autorizacion

El area admin no debe mezclarse con el acceso de usuario normal a informes.

Decisiones a concretar durante implementacion:

- si se reutiliza `reportmanserver.ini` para credenciales admin
- si se crea una bandera explicita de usuario administrador
- si se limita el acceso admin a determinadas IPs en entorno Docker privado

Minimo aceptable:

- autenticacion previa obligatoria
- chequeo explicito de permiso admin para rutas `/admin/*`

#### Logging y diagnostico

Conviene dejar trazas administrativas de bajo coste.

Operaciones a registrar:

- acceso al panel admin
- alta de conexion
- borrado de conexion
- guardado asistido
- guardado manual del INI
- prueba de conexion
- errores de parseo o excepciones de drivers

Sin incluir secretos completos.

#### HTML y templates

Se puede empezar con HTML embebido o con plantillas simples en disco.

Recomendacion pragmatica:

- reutilizar el enfoque actual de paginas HTML del servidor web si ya existe una convencion estable
- mantener las plantillas admin separadas de las publicas

Rutas sugeridas para plantillas:

- `server/web/admin/connections.html`
- `server/web/admin/connection_edit.html`
- `server/web/admin/connection_raw.html`
- `server/web/admin/connection_test.html`

#### Orden de implementacion de codigo para fase 1

1. extraer la logica de test de conexion fuera del formulario VCL
2. crear unidad de servicio `rpwebdbxadmin.pas`
3. añadir rutas admin a `rpwebpages.pas`
4. implementar listado de conexiones
5. implementar alta y borrado
6. implementar edicion asistida
7. implementar prueba de conexion
8. implementar modo manual del INI
9. añadir logging y enmascarado de secretos

#### Hitos tecnicos verificables

Hito A:

- una URL admin lista conexiones reales desde `dbxconnections.ini`

Hito B:

- se puede crear una seccion nueva desde un driver soportado

Hito C:

- se puede editar y guardar una conexion existente

Hito D:

- se puede ejecutar una prueba real y ver el error exacto

Hito E:

- se puede pegar un `dbxconnections.ini` completo y recargarlo

#### Riesgos especificos de implementacion de la fase 1

- duplicar la logica de prueba en web y VCL, generando comportamientos divergentes
- exponer contrasenas al re-renderizar formularios
- mantener estado mutable compartido entre peticiones HTTP
- no recargar correctamente el fichero despues de escritura manual
- romper compatibilidad con configuraciones antiguas si el parser se vuelve demasiado estricto

#### Criterio de calidad para cerrar la fase 1

La fase 1 no debe darse por cerrada solo porque la UI exista. Debe cumplirse que:

- la prueba de conexion web usa el mismo camino funcional que la prueba VCL o una extraccion directa de ese camino
- el modo manual permite pegar una configuracion heredada real
- la persistencia de `dbxconnections.ini` funciona sin tocar otras rutas del contenedor
- los errores se presentan de forma util para diagnostico operativo

## Fase 2: Docker autonomo

### Objetivo funcional

Disponer de un contenedor Linux autocontenido para `repwebexe`, ejecutado en modo `selfhosted`, con configuracion persistente y soporte para drivers necesarios.

### Estructura inicial prevista

- `server/docker/web/Dockerfile`
- `server/docker/web/docker-compose.yml`
- `server/docker/web/config/`
- `server/docker/web/scripts/`
- `server/docker/web/README.md`

### Decision de hosting web

`repwebexe` ya dispone de modo selfhosted y puede abrir directamente el puerto HTTP del contenedor.

Consecuencia operativa:

1. El contenedor puede ser de proceso unico: `repwebexe -selfhosted -port=<PORT>`.
2. El `Dockerfile` puede exponer directamente ese puerto sin capa CGI intermedia.
3. Un reverse proxy externo solo seria opcional para TLS, routing o politicas corporativas, no un requisito de la imagen base.

Esto simplifica mucho la imagen y elimina la necesidad de Apache/nginx en la primera version Docker.

### Dependencias del contenedor

La imagen debe incluir:

- `repwebexe` Linux
- runtime necesario
- soporte del modo `selfhosted`
- `dbxdrivers` preconfigurado
- soporte de drivers decidido para la primera version
- si aplica, `unixODBC` y sus drivers concretos

### Volumenes y persistencia

Separar claramente:

- aplicacion: solo lectura
- configuracion de conexiones: lectura/escritura
- logs: lectura/escritura opcional

El caso critico es `dbxconnections.ini`, que debe vivir en una ruta persistente y conocida.

### Ubicacion de `dbxconnections.ini`

Para Docker conviene usar una ruta fija y documentada, mejor que depender de rutas implicitas de usuario.

La recomendacion es forzar una ruta estable mediante configuracion de override o un mecanismo equivalente del proceso, para que el volumen sea predecible.

### Compatibilidad con configuraciones heredadas

El contenedor debe soportar tres escenarios:

1. primer arranque con configuracion vacia
2. arranque con `dbxconnections.ini` ya montado desde volumen
3. importacion o pegado de un fichero antiguo desde el editor web

Esto es un requisito funcional explicito del proyecto.

### Seguridad del contenedor

- ejecutar como usuario no root
- escritura solo en configuracion y logs
- proteger el area admin
- evitar permisos amplios sobre todo el filesystem del contenedor

### Validaciones de arranque

El entrypoint o script de inicio debe verificar:

- existencia del binario `repwebexe`
- presencia del modo `-selfhosted` operativo
- disponibilidad de rutas de configuracion
- presencia de librerias criticas
- permisos de escritura solo donde proceda
- puerto final resuelto desde `-port` o `CONFIG/TCPPORT`

### Resultado esperado de la fase 2

Un Docker autocontenido que pueda arrancar por si solo, aceptar configuracion heredada de conexiones y administrar esa configuracion desde el propio panel web, sin servidor web frontal embebido en la imagen.

## Orden de implementacion recomendado

1. Encapsular logica comun de gestion y prueba de conexiones reutilizable desde web.
2. Integrar el panel admin en `repwebexe`.
3. Implementar el modo manual completo para `dbxconnections.ini`.
4. Construir el contenedor Docker alrededor de esa base funcional.
5. Validar el flujo de importacion de un `dbxconnections.ini` heredado.
6. Validar pruebas reales con los drivers soportados por la imagen.

## Criterios de aceptacion

### Fase 1

- se pueden listar conexiones existentes
- se puede crear una conexion nueva desde un driver soportado
- se pueden editar parametros y persistirlos
- se puede borrar una conexion
- se puede probar una conexion real desde web
- se puede pegar o editar manualmente `dbxconnections.ini`
- tras guardar, el sistema relee la configuracion sin reinicio manual

### Fase 2

- el contenedor arranca sin depender de configuracion manual en el host
- `dbxconnections.ini` persiste en un volumen
- se puede montar una configuracion antigua y usarla directamente
- el panel admin funciona dentro del contenedor
- `repwebexe` escucha directamente en el puerto publicado del contenedor
- no se escribe fuera de las rutas previstas

## Riesgos a vigilar

- diferencias entre comportamiento CGI legado y selfhosted en cabeceras, URLs base o despliegues antiguos
- diferencias de librerias nativas entre host de build y runtime Linux
- errores por concurrencia si coinciden modo manual y modo asistido
- exposicion de secretos si el panel admin no filtra adecuadamente los campos sensibles
- confusion entre lo que pertenece a `dbxdrivers` y lo que pertenece a `dbxconnections.ini`

## Fuera de alcance inicial

- editor libre de `dbxdrivers`
- orquestacion multi-contenedor compleja
- catalogo grafico avanzado de drivers instalados
- migracion automatica de todos los formatos historicos de configuracion

## Siguiente paso recomendado

Convertir este plan en una especificacion tecnica de implementacion con:

- clases Delphi nuevas o refactorizadas
- endpoints concretos
- plantillas HTML necesarias
- ruta exacta de persistencia para `dbxconnections.ini`
- contrato exacto de arranque Docker: `-selfhosted`, `-port`, `-bind` y volumenes persistentes
