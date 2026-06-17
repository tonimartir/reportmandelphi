; Report Manager .NET Designer (x86) - instalador independiente.
; Instala el designer + printreport .NET (self-contained win-x86, NO requiere el
; runtime .NET instalado) en {app}\net2. Si se instala en la misma carpeta que el
; Report Designer Delphi (x86), este puede usar el driver .NET. Tambien funciona
; como producto standalone (con acceso en el menu inicio).

[Setup]
AppName=Report Manager .NET Designer (x86)
AppVersion=4.0.10
DefaultDirName={commonpf32}\Report Manager
DefaultGroupName=Report Manager
UninstallDisplayIcon={app}\net2\designer.exe
Compression=lzma2
SolidCompression=yes
OutputDir=C:\desarrollo\prog\toni\reportman\install\Output
AppPublisher=Toni Martir
AppPublisherURL=http://reportman.sourceforge.net
VersionInfoProductName=Report Manager .NET Designer
VersionInfoProductVersion=4.0.10
OutputBaseFilename=reportman_designer_net_4_0_10_x86

[Files]
Source: "c:\desarrollo\prog\toni\reportman\repman\binr32\net2\*"; DestDir: "{app}\net2"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\Report Manager .NET Designer"; Filename: "{app}\net2\designer.exe"

[Run]
Filename: "{app}\net2\designer.exe"; Flags: postinstall nowait skipifsilent; Description: "Iniciar Report Manager .NET Designer"
