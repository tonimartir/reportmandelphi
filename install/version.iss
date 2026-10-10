; Version of the Windows installers, included by the four reportmanxe_*.iss.
;
; AppVer     e.g. 4.0.18  (AppVersion, VersionInfoProductVersion)
; AppVerU    e.g. 4_0_18  (OutputBaseFilename)
;
; build\sourceforge\02-designer-innosetup.ps1 passes it as ISCC /DAppVer=<v>;
; without it (compiling from the Inno Setup IDE) it is read from RM_VERSION in
; rpmdconsts.pas, so the version is never written by hand here.

#ifndef AppVer
  ; SourcePath is the folder of the script being compiled: install\
  #define RmConstsFile AddBackslash(SourcePath) + "..\rpmdconsts.pas"
  #define RmConsts FileOpen(RmConstsFile)
  #if !RmConsts
    #error Cannot open rpmdconsts.pas to read RM_VERSION; pass ISCC /DAppVer=x.y.z
  #endif
  #define RmVersionLine ""
  #sub ReadRmVersionLine
    #define private Line FileRead(RmConsts)
    #if Pos("RM_VERSION", Line) > 0
      #define public RmVersionLine Line
    #endif
  #endsub
  #for {0; RmVersionLine == "" && !FileEof(RmConsts); 0} ReadRmVersionLine
  #expr FileClose(RmConsts)
  #if RmVersionLine == ""
    #error RM_VERSION not found in rpmdconsts.pas; pass ISCC /DAppVer=x.y.z
  #endif
  ; RM_VERSION='4.0.18';  ->  4.0.18
  ; AppVer and AppVerU are public: the script that includes this file does not
  ; see them otherwise
  #define public RmVersionFrom Pos("'", RmVersionLine) + 1
  #define public AppVer Copy(RmVersionLine, RmVersionFrom, RPos("'", RmVersionLine) - RmVersionFrom)
#endif

#if AppVer == ""
  #error Empty version; pass ISCC /DAppVer=x.y.z
#endif
#define public AppVerU StringChange(AppVer, ".", "_")
