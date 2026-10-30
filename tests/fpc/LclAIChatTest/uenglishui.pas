{ The checks compare the English texts, and the engine translates them to
  the language of the user (rptranslator: the thread locale on Windows, a
  reportmanres file next to the executable elsewhere, and the tests have
  none). This unit is the first one of the program, so its initialization
  runs before the one of rpmdconsts: the tests see English on a Spanish or
  Polish Windows too. }
unit uenglishui;

{$mode delphi}

interface

// After SysUtils: its initialization sets the thread locale of the user
// again on Windows
{$IFDEF MSWINDOWS}
uses
  Windows, SysUtils;
{$ENDIF}

implementation

initialization
{$IFDEF MSWINDOWS}
  // English (United States)
  SetThreadLocale($0409);
{$ENDIF}
end.
