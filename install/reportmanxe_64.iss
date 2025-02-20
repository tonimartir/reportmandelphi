; -- 64Bit.iss --
; Demonstrates installation of a program built for the x64 (a.k.a. AMD64)
; architecture.
; To successfully run this installation and the program it installs,
; you must have a "x64" edition of Windows.

; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!

[Setup]
AppName=Report Manager Designer (x64)
AppVersion=3.7.5
DefaultDirName={commonpf64}\Report Manager
DefaultGroupName=Report Manager
UninstallDisplayIcon={app}\repmandxp.exe
Compression=lzma2
SolidCompression=yes
OutputDir=C:\desarrollo\prog\toni\reportman\install\Output
; "ArchitecturesAllowed=x64" specifies that Setup cannot run on
; anything but x64.
ArchitecturesAllowed=x64
; "ArchitecturesInstallIn64BitMode=x64" requests that the install be
; done in "64-bit mode" on x64, meaning it should use the native
; 64-bit Program Files directory and the 64-bit view of the registry.
ArchitecturesInstallIn64BitMode=x64
AppPublisher=Toni Martir
AppPublisherURL=http://reportman.sourceforge.net
VersionInfoProductName=Report Manager
VersionInfoProductVersion=3.7.5
OutputBaseFilename=reportman_designer_3_7_5_x64

[Files]
Source: "c:\desarrollo\prog\toni\reportman\repman\binr64\repmandxp.exe"; DestDir: "{app}"
Source: "c:\desarrollo\prog\toni\reportman\repman\repsamples\sample4.rep"; DestDir: "{app}\Examples"
Source: "c:\desarrollo\prog\toni\reportman\repman\biolife.cds"; DestDir: "{app}\Examples"
Source: "c:\desarrollo\prog\toni\reportman\repman\binr64\net2\*.*"; DestDir: "{app}\net2"
Source: "c:\desarrollo\prog\toni\reportman\repman\binr64\net2\x86\*.*"; DestDir: "{app}\net2\x86"
Source: "c:\desarrollo\prog\toni\reportman\repman\binr64\net2\x64\*.*"; DestDir: "{app}\net2\x64"
Source: "c:\desarrollo\prog\toni\reportman\repman\dbxdrivers.ini"; DestDir: "{%PUBLIC}"
Source: "c:\desarrollo\prog\toni\reportman\repman\dbxconnections.ini"; DestDir: "{%PUBLIC}"
Source: "c:\desarrollo\prog\toni\reportman\repman\utils\printreptopdf\binr64\printreptopdf.exe"; DestDir: "{app}"
Source: "c:\desarrollo\prog\toni\reportman\activex\binr64\Reportman.ocx"; DestDir: "{app}"
Source: "c:\desarrollo\prog\toni\reportman\repman\utils\printrep\binr64\printrepxp.exe"; DestDir: "{app}"
Source: "c:\desarrollo\prog\toni\reportman\repman\utils\metaprint\binr64\metaprintxp.exe"; DestDir: "{app}"
Source: "c:\desarrollo\prog\toni\reportman\repman\reportmanres.*"; DestDir: "{app}\Translation"
Source: "c:\desarrollo\prog\toni\reportman\repman\utils\rptranslator\binr64\rptranslate.exe"; DestDir: "{app}\Translation"
Source: "c:\desarrollo\prog\toni\reportman\repman\utils\rptranslator\rptranslateres.*"; DestDir: "{app}\Translation"
Source: "c:\desarrollo\prog\toni\reportman\server\app\binr64\reportserverappxp.exe"; DestDir: "{app}"
Source: "c:\desarrollo\prog\toni\reportman\server\config\binr64\repserverconfigxp.exe"; DestDir: "{app}"
Source: "c:\desarrollo\prog\toni\reportman\server\service\binr64\repserverservice.exe"; DestDir: "{app}"
Source: "c:\desarrollo\prog\toni\reportman\server\service\binr64\repserviceinstall.exe"; DestDir: "{app}"
Source: "c:\desarrollo\prog\toni\reportman\repman\utils\metaview\binr64\metaviewxp.exe"; DestDir: "{app}"
Source: "c:\desarrollo\prog\toni\reportman\server\web\binr64\repwebexe.exe"; DestDir: "{app}\Web"
Source: "c:\desarrollo\prog\toni\reportman\server\web\binr64\repwebserver.dll"; DestDir: "{app}\Web"
Source: "c:\desarrollo\prog\toni\reportman\server\web\*.html"; DestDir: "{app}\Web\Templates"
Source: "c:\desarrollo\prog\toni\reportman\server\web\binr64\repwebserver.dll"; DestDir: "{app}\Web"

; Api libraries
Source: c:\desarrollo\prog\toni\reportman\rpreportman.h; DestDir: {app}\api; Flags: ignoreversion
Source: c:\desarrollo\prog\toni\reportman\rpreportmanapi.bas; DestDir: {app}\api;  Flags: ignoreversion
Source: c:\desarrollo\prog\toni\reportman\tests\gcctest\Reportman.def; DestDir: {app}\api;  Flags: ignoreversion

; Drivers
Source: "c:\desarrollo\prog\toni\reportman\drivers\x64\*"; DestDir: "{app}"


[Icons]
Name: "{group}\Report Manager Designer"; Filename: "{app}\repmandxp.exe"
Name: "{group}\Report Manager Server"; Filename: "{app}\reportserverappxp.exe"
Name: "{group}\Report Manager Server Configuration"; Filename: "{app}\repserverconfigxp.exe"
Name: "{group}\Report Manager Client"; Filename: "{app}\metaviewxp.exe"
Name: "{group}\Report Manager Translator"; Filename: "{app}\Translation\rptranslate.exe"

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "catalan"; MessagesFile: "compiler:Languages\Catalan.isl"
Name: "czech"; MessagesFile: "compiler:Languages\Czech.isl"
Name: "dutch"; MessagesFile: "compiler:Languages\Dutch.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Registry]
Root: HKCR; SubKey: ".rep"; ValueType: string; ValueData: "Report Manager Template"; Flags: uninsdeletekey
Root: HKCR; SubKey: "Report Manager Template"; ValueType: string; ValueData: "Report Manager Designer Template File"; Flags: uninsdeletekey
Root: HKCR; SubKey: "Report Manager Template\Shell\Open\Command"; ValueType: string; ValueData: """{app}\repmandxp.exe"" ""%1"""; Flags: uninsdeletekey
Root: HKCR; Subkey: "Report Manager Template\DefaultIcon"; ValueType: string; ValueData: "{app}\repmandxp.exe,0"; Flags: uninsdeletevalue
Root: HKCR; Subkey: .rpmf; ValueType: string; ValueName: ; ValueData: Report Manager Client; Flags: uninsdeletevalue
Root: HKCR; Subkey: Report Manager Client; ValueType: string; ValueName: ; ValueData: Report Manager Metafile; Flags: uninsdeletekey
Root: HKCR; Subkey: Report Manager Client\DefaultIcon; ValueType: string; ValueName: ; ValueData: {app}\metaviewxp.exe,0
Root: HKCR; Subkey: Report Manager Client\shell\open\command; ValueType: string; ValueName: ; ValueData: """{app}\metaviewxp.exe"" ""%1"""

[INI]
Filename: "{app}\Report Manager Web.url"; Section: "InternetShortcut"; Key: "URL"; String: "http://reportman.sourceforge.net"

[UninstallDelete]
Type: files; Name: "{app}\Report Manager Web.url"

[Run]
Filename: "{app}\Examples\sample4.rep"; Flags: postinstall runasoriginaluser nowait shellexec; Description: "Report Manager sample report"
  