unit activex_ai_TLB;

{$TYPEDADDRESS OFF}
{$WARN SYMBOL_PLATFORM OFF}
{$WRITEABLECONST ON}
{$VARPROPSETTER ON}
{$ALIGN 4}

interface

uses
  Winapi.Windows, System.Classes, System.Variants, System.Win.StdVCL,
  Vcl.Graphics, Vcl.OleCtrls, Winapi.ActiveX;

const
  activex_aiMajorVersion = 1;
  activex_aiMinorVersion = 0;

  LIBID_activex_ai: TGUID = '{5E388645-51A0-4C40-8E7B-3A774F3D85F1}';
  IID_IReportmanAIActiveX: TGUID = '{7D58AF9D-2482-4BD8-B2AA-6B063E35B464}';
  DIID_IReportmanAIActiveXEvents: TGUID = '{03F5FB43-6AC3-4D42-9A33-17F70C1103FA}';
  CLASS_ReportmanAIActiveX: TGUID = '{79E31982-C4C7-4E66-A64B-D4AF59BD4E88}';

type
  IReportmanAIActiveX = interface(IDispatch)
    ['{7D58AF9D-2482-4BD8-B2AA-6B063E35B464}']
    function Get_Url: WideString; safecall;
    procedure Set_Url(const Value: WideString); safecall;
    function Get_ProfileName: WideString; safecall;
    procedure Set_ProfileName(const Value: WideString); safecall;
    function Get_CanGoBack: WordBool; safecall;
    function Get_CanGoForward: WordBool; safecall;
    function Get_Version: WideString; safecall;
    procedure Navigate(const url: WideString); safecall;
    procedure Reload; safecall;
    procedure GoBack; safecall;
    procedure GoForward; safecall;
    procedure ExecuteScript(const script: WideString); safecall;
    procedure RetryInitialize; safecall;
    property Url: WideString read Get_Url write Set_Url;
    property ProfileName: WideString read Get_ProfileName write Set_ProfileName;
    property CanGoBack: WordBool read Get_CanGoBack;
    property CanGoForward: WordBool read Get_CanGoForward;
    property Version: WideString read Get_Version;
  end;

  IReportmanAIActiveXDisp = dispinterface
    ['{7D58AF9D-2482-4BD8-B2AA-6B063E35B464}']
    property Url: WideString dispid 1;
    property ProfileName: WideString dispid 11;
    property CanGoBack: WordBool readonly dispid 2;
    property CanGoForward: WordBool readonly dispid 3;
    property Version: WideString readonly dispid 4;
    procedure Navigate(const url: WideString); dispid 5;
    procedure Reload; dispid 6;
    procedure GoBack; dispid 7;
    procedure GoForward; dispid 8;
    procedure ExecuteScript(const script: WideString); dispid 9;
    procedure RetryInitialize; dispid 10;
  end;

  IReportmanAIActiveXEvents = dispinterface
    ['{03F5FB43-6AC3-4D42-9A33-17F70C1103FA}']
    procedure NavigationStarting(const url: WideString); dispid 1;
    procedure NavigationCompleted(const url: WideString); dispid 2;
    procedure MessageReceived(const message: WideString); dispid 3;
    procedure HostError(const message: WideString); dispid 4;
  end;

implementation

end.