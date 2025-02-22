unit reportman_TLB;

// ************************************************************************ //
// WARNING
// -------
// The types declared in this file were generated from data read from a
// Type Library. If this type library is explicitly or indirectly (via
// another type library referring to this type library) re-imported, or the
// 'Refresh' command of the Type Library Editor activated while editing the
// Type Library, the contents of this file will be regenerated and all
// manual modifications will be lost.
// ************************************************************************ //

// $Rev: 98336 $
// File generated on 22/02/2025 21:54:20 from Type Library described below.

// ************************************************************************  //
// Type Lib: C:\desarrollo\prog\toni\reportman\activex\reportman (1)
// LIBID: {D4D26F6B-6564-44F4-A913-03C91CE37740}
// LCID: 0
// Helpfile:
// HelpString: Report Manager ActiveX Library
// DepndLst:
//   (1) v2.0 stdole, (C:\Windows\SysWOW64\stdole2.tlb)
// SYS_KIND: SYS_WIN32
// ************************************************************************ //
{$TYPEDADDRESS OFF} // Unit must be compiled without type-checked pointers.
{$WARN SYMBOL_PLATFORM OFF}
{$WRITEABLECONST ON}
{$VARPROPSETTER ON}
{$ALIGN 4}

interface

uses Winapi.Windows, System.Classes, System.Variants, System.Win.StdVCL, Vcl.Graphics, Vcl.OleCtrls, Vcl.OleServer, Winapi.ActiveX;



// *********************************************************************//
// GUIDS declared in the TypeLibrary. Following prefixes are used:
//   Type Libraries     : LIBID_xxxx
//   CoClasses          : CLASS_xxxx
//   DISPInterfaces     : DIID_xxxx
//   Non-DISP interfaces: IID_xxxx
// *********************************************************************//
const
  // TypeLibrary Major and minor versions
  reportmanMajorVersion = 2;
  reportmanMinorVersion = 1;

  LIBID_reportman: TGUID = '{D4D26F6B-6564-44F4-A913-03C91CE37740}';

  IID_IReportManX: TGUID = '{B3AE1470-158D-4855-83DB-BC3A2746C26E}';
  DIID_IReportManXEvents: TGUID = '{50909EA4-8F4F-4865-877D-287FC7072177}';
  CLASS_ReportManX: TGUID = '{DC30E149-4129-450F-BDFE-BD9E6F31147E}';
  IID_IReportReport: TGUID = '{2FCB34BE-8DD4-4567-A771-9965C2FD3A04}';
  CLASS_ReportReport: TGUID = '{E30FD4FC-F47A-4932-A3E6-6694550588F3}';
  IID_IReportParameters: TGUID = '{A5F6E90E-DFE7-49DA-AA38-C1A41C995B6B}';
  CLASS_ReportParameters: TGUID = '{F79CF82C-C2AD-46CC-ABEA-084016CFE58A}';
  IID_IReportParam: TGUID = '{F1634F9E-DE5A-411E-9A9E-3A46707A7ABB}';
  CLASS_ReportParam: TGUID = '{E96B253E-143E-40E8-BFDA-366C5F112DAE}';
  IID_IReportmanXAServer: TGUID = '{F3A6B88C-D629-402E-BC62-BAB0E2EE39AF}';
  CLASS_ReportmanXAServer: TGUID = '{FD3BE5E5-CBE4-4C29-A733-8CB842999075}';
  IID_IPreviewControl: TGUID = '{3D8043B8-E2F6-4F5D-B055-571924F5B0DC}';
  DIID_IPreviewControlEvents: TGUID = '{7364E2EA-8EEC-4673-9059-3B078C388717}';
  CLASS_PreviewControl: TGUID = '{45978803-4B15-4E0E-98CE-AED9B1E1B701}';

// *********************************************************************//
// Declaration of Enumerations defined in Type Library
// *********************************************************************//
// Constants for enum TxHelpType
type
  TxHelpType = TOleEnum;
const
  htKeyword = $00000000;
  htContext = $00000001;

// Constants for enum TxParamType
type
  TxParamType = TOleEnum;
const
  rpParamString = $00000000;
  rpParamInteger = $00000001;
  rpParamDouble = $00000002;
  rpParamDate = $00000003;
  rpParamTime = $00000004;
  rpParamDateTime = $00000005;
  rpParamCurrency = $00000006;
  rpParamBool = $00000007;
  rpParamExpreB = $00000008;
  rpParamExpreA = $00000009;
  rpParamSubst = $0000000A;
  rpParamList = $0000000B;
  rpParamUnknown = $0000000C;

// Constants for enum TxAutoScaleType
type
  TxAutoScaleType = TOleEnum;
const
  AScaleReal = $00000000;
  AScaleWide = $00000001;
  AScaleHeight = $00000002;
  AScaleEntirePage = $00000003;
  AScaleCustom = $00000004;

// Constants for enum TxBorderStyle
type
  TxBorderStyle = TOleEnum;
const
  bsNone = $00000000;
  bsSingle = $00000001;

// Constants for enum TxDragMode
type
  TxDragMode = TOleEnum;
const
  dmManual = $00000000;
  dmAutomatic = $00000001;

// Constants for enum TxMouseButton
type
  TxMouseButton = TOleEnum;
const
  mbLeft = $00000000;
  mbRight = $00000001;
  mbMiddle = $00000002;

// Constants for enum TxActiveFormBorderStyle
type
  TxActiveFormBorderStyle = TOleEnum;
const
  afbNone = $00000000;
  afbSingle = $00000001;
  afbSunken = $00000002;
  afbRaised = $00000003;

// Constants for enum TxPrintScale
type
  TxPrintScale = TOleEnum;
const
  poNone = $00000000;
  poProportional = $00000001;
  poPrintToFit = $00000002;

// Constants for enum TxPDFConformanceType
type
  TxPDFConformanceType = TOleEnum;
const
  PDF_1_4 = $00000001;
  PDF_A_3 = $00000002;
  PDF_Default = $00000000;

// Constants for enum TxAFRelationShip
type
  TxAFRelationShip = TOleEnum;
const
  AFUnspecified = $00000000;
  AFAlternative = $00000001;
  AFData = $00000002;
  AFSource = $00000003;
  AFSupplement = $00000004;

type

// *********************************************************************//
// Forward declaration of types defined in TypeLibrary
// *********************************************************************//
  IReportManX = interface;
  IReportManXDisp = dispinterface;
  IReportManXEvents = dispinterface;
  IReportReport = interface;
  IReportReportDisp = dispinterface;
  IReportParameters = interface;
  IReportParametersDisp = dispinterface;
  IReportParam = interface;
  IReportParamDisp = dispinterface;
  IReportmanXAServer = interface;
  IReportmanXAServerDisp = dispinterface;
  IPreviewControl = interface;
  IPreviewControlDisp = dispinterface;
  IPreviewControlEvents = dispinterface;

// *********************************************************************//
// Declaration of CoClasses defined in Type Library
// (NOTE: Here we map each CoClass to its Default Interface)
// *********************************************************************//
  ReportManX = IReportManX;
  ReportReport = IReportReport;
  ReportParameters = IReportParameters;
  ReportParam = IReportParam;
  ReportmanXAServer = IReportmanXAServer;
  PreviewControl = IPreviewControl;


// *********************************************************************//
// Declaration of structures, unions and aliases.
// *********************************************************************//
  PPUserType1 = ^IFontDisp; {*}


// *********************************************************************//
// Interface: IReportManX
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {B3AE1470-158D-4855-83DB-BC3A2746C26E}
// *********************************************************************//
  IReportManX = interface(IDispatch)
    ['{B3AE1470-158D-4855-83DB-BC3A2746C26E}']
    procedure SetDatasetSQL(const datasetname: WideString; const sqlsentence: WideString); safecall;
    procedure SetDatabaseConnectionString(const databasename: WideString;
                                          const connectionstring: WideString); safecall;
    function GetDatasetSQL(const datasetname: WideString): WideString; safecall;
    function GetDatabaseConnectionString(const databasename: WideString): WideString; safecall;
    procedure SetParamValue(const paramname: WideString; paramvalue: OleVariant); safecall;
    function GetParamValue(const paramname: WideString): OleVariant; safecall;
    function Execute: WordBool; safecall;
    procedure PrinterSetup; safecall;
    function ShowParams: WordBool; safecall;
    procedure SaveToPDF(const filename: WideString; compressed: WordBool); safecall;
    function PrintRange(frompage: Integer; topage: Integer; copies: Integer; collate: WordBool): WordBool; safecall;
    function Get_filename: WideString; safecall;
    procedure Set_filename(const Value: WideString); safecall;
    function Get_Preview: WordBool; safecall;
    procedure Set_Preview(Value: WordBool); safecall;
    function Get_ShowProgress: WordBool; safecall;
    procedure Set_ShowProgress(Value: WordBool); safecall;
    function Get_ShowPrintDialog: WordBool; safecall;
    procedure Set_ShowPrintDialog(Value: WordBool); safecall;
    function Get_Title: WideString; safecall;
    procedure Set_Title(const Value: WideString); safecall;
    function Get_Language: Integer; safecall;
    procedure Set_Language(Value: Integer); safecall;
    function Get_DoubleBuffered: WordBool; safecall;
    procedure Set_DoubleBuffered(Value: WordBool); safecall;
    function Get_AlignDisabled: WordBool; safecall;
    function Get_VisibleDockClientCount: Integer; safecall;
    function DrawTextBiDiModeFlagsReadingOnly: Integer; safecall;
    function Get_Enabled: WordBool; safecall;
    procedure Set_Enabled(Value: WordBool); safecall;
    procedure InitiateAction; safecall;
    function IsRightToLeft: WordBool; safecall;
    function UseRightToLeftReading: WordBool; safecall;
    function UseRightToLeftScrollBar: WordBool; safecall;
    function Get_Visible: WordBool; safecall;
    procedure Set_Visible(Value: WordBool); safecall;
    function Get_Cursor: Smallint; safecall;
    procedure Set_Cursor(Value: Smallint); safecall;
    function Get_HelpType: TxHelpType; safecall;
    procedure Set_HelpType(Value: TxHelpType); safecall;
    function Get_HelpKeyword: WideString; safecall;
    procedure Set_HelpKeyword(const Value: WideString); safecall;
    procedure SetSubComponent(IsSubComponent: WordBool); safecall;
    procedure AboutBox; safecall;
    procedure ExecuteRemote(const hostname: WideString; port: Integer; const user: WideString;
                            const password: WideString; const aliasname: WideString;
                            const reportname: WideString); safecall;
    procedure CalcReport(ShowProgress: WordBool); safecall;
    procedure Compose(const Report: ReportReport; Execute: WordBool); safecall;
    procedure SaveToText(const filename: WideString; const textdriver: WideString); safecall;
    function Get_Report: ReportReport; safecall;
    procedure SaveToExcel(const filename: WideString); safecall;
    procedure SaveToHTML(const filename: WideString); safecall;
    procedure SetRecordSet(const datasetname: WideString; const Value: IDispatch); safecall;
    procedure SaveToCustomText(const filename: WideString); safecall;
    procedure SaveToCSV(const filename: WideString); safecall;
    procedure SaveToSVG(const filename: WideString); safecall;
    procedure SaveToMetafile(const filename: WideString); safecall;
    procedure SaveToExcel2(const filename: WideString); safecall;
    function Get_DefaultPrinter: WideString; safecall;
    procedure Set_DefaultPrinter(const Value: WideString); safecall;
    function Get_PrintersAvailable: WideString; safecall;
    procedure GetRemoteParams(const hostname: WideString; port: Integer; const user: WideString;
                              const password: WideString; const aliasname: WideString;
                              const reportname: WideString); safecall;
    procedure SaveToCSV2(const filename: WideString; const separator: WideString); safecall;
    function Get_AsyncExecution: WordBool; safecall;
    procedure Set_AsyncExecution(Value: WordBool); safecall;
    procedure SaveToHTMLSingle(const filename: WideString); safecall;
    procedure SaveToFile(const filename: WideString); safecall;
    procedure AddEmbeddedFile(const fileName: WideString; const mimeType: WideString;
                              const base64Stream: WideString; const description: WideString;
                              AFRelationShip: TxAFRelationShip; const ISOCreationDate: WideString;
                              const ISOModificationDate: WideString); safecall;
    procedure AddMetadata(const title: WideString; const author: WideString;
                          const subject: WideString; const creator: WideString;
                          const producer: WideString; const keywords: WideString;
                          const creationDate: WideString; const modificationDate: WideString); safecall;
    procedure AddXMPMetadata(const XMPContent: WideString); safecall;
    procedure SetPDFConformance(PDFConformance: TxPDFConformanceType); safecall;
    function Get_DebugMode: WordBool; safecall;
    procedure Set_DebugMode(Value: WordBool); safecall;
    property filename: WideString read Get_filename write Set_filename;
    property Preview: WordBool read Get_Preview write Set_Preview;
    property ShowProgress: WordBool read Get_ShowProgress write Set_ShowProgress;
    property ShowPrintDialog: WordBool read Get_ShowPrintDialog write Set_ShowPrintDialog;
    property Title: WideString read Get_Title write Set_Title;
    property Language: Integer read Get_Language write Set_Language;
    property DoubleBuffered: WordBool read Get_DoubleBuffered write Set_DoubleBuffered;
    property AlignDisabled: WordBool read Get_AlignDisabled;
    property VisibleDockClientCount: Integer read Get_VisibleDockClientCount;
    property Enabled: WordBool read Get_Enabled write Set_Enabled;
    property Visible: WordBool read Get_Visible write Set_Visible;
    property Cursor: Smallint read Get_Cursor write Set_Cursor;
    property HelpType: TxHelpType read Get_HelpType write Set_HelpType;
    property HelpKeyword: WideString read Get_HelpKeyword write Set_HelpKeyword;
    property Report: ReportReport read Get_Report;
    property DefaultPrinter: WideString read Get_DefaultPrinter write Set_DefaultPrinter;
    property PrintersAvailable: WideString read Get_PrintersAvailable;
    property AsyncExecution: WordBool read Get_AsyncExecution write Set_AsyncExecution;
    property DebugMode: WordBool read Get_DebugMode write Set_DebugMode;
  end;

// *********************************************************************//
// DispIntf:  IReportManXDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {B3AE1470-158D-4855-83DB-BC3A2746C26E}
// *********************************************************************//
  IReportManXDisp = dispinterface
    ['{B3AE1470-158D-4855-83DB-BC3A2746C26E}']
    procedure SetDatasetSQL(const datasetname: WideString; const sqlsentence: WideString); dispid 1;
    procedure SetDatabaseConnectionString(const databasename: WideString;
                                          const connectionstring: WideString); dispid 2;
    function GetDatasetSQL(const datasetname: WideString): WideString; dispid 3;
    function GetDatabaseConnectionString(const databasename: WideString): WideString; dispid 4;
    procedure SetParamValue(const paramname: WideString; paramvalue: OleVariant); dispid 5;
    function GetParamValue(const paramname: WideString): OleVariant; dispid 6;
    function Execute: WordBool; dispid 7;
    procedure PrinterSetup; dispid 8;
    function ShowParams: WordBool; dispid 9;
    procedure SaveToPDF(const filename: WideString; compressed: WordBool); dispid 10;
    function PrintRange(frompage: Integer; topage: Integer; copies: Integer; collate: WordBool): WordBool; dispid 11;
    property filename: WideString dispid 12;
    property Preview: WordBool dispid 13;
    property ShowProgress: WordBool dispid 14;
    property ShowPrintDialog: WordBool dispid 15;
    property Title: WideString dispid 16;
    property Language: Integer dispid 17;
    property DoubleBuffered: WordBool dispid 18;
    property AlignDisabled: WordBool readonly dispid 19;
    property VisibleDockClientCount: Integer readonly dispid 20;
    function DrawTextBiDiModeFlagsReadingOnly: Integer; dispid 22;
    property Enabled: WordBool dispid -514;
    procedure InitiateAction; dispid 23;
    function IsRightToLeft: WordBool; dispid 24;
    function UseRightToLeftReading: WordBool; dispid 27;
    function UseRightToLeftScrollBar: WordBool; dispid 28;
    property Visible: WordBool dispid 29;
    property Cursor: Smallint dispid 30;
    property HelpType: TxHelpType dispid 31;
    property HelpKeyword: WideString dispid 32;
    procedure SetSubComponent(IsSubComponent: WordBool); dispid 34;
    procedure AboutBox; dispid -552;
    procedure ExecuteRemote(const hostname: WideString; port: Integer; const user: WideString;
                            const password: WideString; const aliasname: WideString;
                            const reportname: WideString); dispid 201;
    procedure CalcReport(ShowProgress: WordBool); dispid 202;
    procedure Compose(const Report: ReportReport; Execute: WordBool); dispid 203;
    procedure SaveToText(const filename: WideString; const textdriver: WideString); dispid 204;
    property Report: ReportReport readonly dispid 21;
    procedure SaveToExcel(const filename: WideString); dispid 25;
    procedure SaveToHTML(const filename: WideString); dispid 26;
    procedure SetRecordSet(const datasetname: WideString; const Value: IDispatch); dispid 33;
    procedure SaveToCustomText(const filename: WideString); dispid 35;
    procedure SaveToCSV(const filename: WideString); dispid 36;
    procedure SaveToSVG(const filename: WideString); dispid 37;
    procedure SaveToMetafile(const filename: WideString); dispid 38;
    procedure SaveToExcel2(const filename: WideString); dispid 39;
    property DefaultPrinter: WideString dispid 42;
    property PrintersAvailable: WideString readonly dispid 44;
    procedure GetRemoteParams(const hostname: WideString; port: Integer; const user: WideString;
                              const password: WideString; const aliasname: WideString;
                              const reportname: WideString); dispid 40;
    procedure SaveToCSV2(const filename: WideString; const separator: WideString); dispid 41;
    property AsyncExecution: WordBool dispid 43;
    procedure SaveToHTMLSingle(const filename: WideString); dispid 205;
    procedure SaveToFile(const filename: WideString); dispid 206;
    procedure AddEmbeddedFile(const fileName: WideString; const mimeType: WideString;
                              const base64Stream: WideString; const description: WideString;
                              AFRelationShip: TxAFRelationShip; const ISOCreationDate: WideString;
                              const ISOModificationDate: WideString); dispid 208;
    procedure AddMetadata(const title: WideString; const author: WideString;
                          const subject: WideString; const creator: WideString;
                          const producer: WideString; const keywords: WideString;
                          const creationDate: WideString; const modificationDate: WideString); dispid 209;
    procedure AddXMPMetadata(const XMPContent: WideString); dispid 210;
    procedure SetPDFConformance(PDFConformance: TxPDFConformanceType); dispid 207;
    property DebugMode: WordBool dispid 211;
  end;

// *********************************************************************//
// DispIntf:  IReportManXEvents
// Flags:     (0)
// GUID:      {50909EA4-8F4F-4865-877D-287FC7072177}
// *********************************************************************//
  IReportManXEvents = dispinterface
    ['{50909EA4-8F4F-4865-877D-287FC7072177}']
  end;

// *********************************************************************//
// Interface: IReportReport
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {2FCB34BE-8DD4-4567-A771-9965C2FD3A04}
// *********************************************************************//
  IReportReport = interface(IDispatch)
    ['{2FCB34BE-8DD4-4567-A771-9965C2FD3A04}']
    function Get_Params: ReportParameters; safecall;
    function Get_VCLReport: PWideChar; safecall;
    procedure AddColumn(Width: Integer; const Expression: WideString; const ExpFormat: WideString;
                        const Caption: WideString; const CaptionFormat: WideString;
                        const SumaryExpression: WideString; const SumaryFormat: WideString); safecall;
    function Get_AutoResizeColumns: WordBool; safecall;
    procedure Set_AutoResizeColumns(Value: WordBool); safecall;
    procedure SaveToFile(const filename: WideString); safecall;
    property Params: ReportParameters read Get_Params;
    property VCLReport: PWideChar read Get_VCLReport;
    property AutoResizeColumns: WordBool read Get_AutoResizeColumns write Set_AutoResizeColumns;
  end;

// *********************************************************************//
// DispIntf:  IReportReportDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {2FCB34BE-8DD4-4567-A771-9965C2FD3A04}
// *********************************************************************//
  IReportReportDisp = dispinterface
    ['{2FCB34BE-8DD4-4567-A771-9965C2FD3A04}']
    property Params: ReportParameters readonly dispid 1;
    property VCLReport: {NOT_OLEAUTO(PWideChar)}OleVariant readonly dispid 3;
    procedure AddColumn(Width: Integer; const Expression: WideString; const ExpFormat: WideString;
                        const Caption: WideString; const CaptionFormat: WideString;
                        const SumaryExpression: WideString; const SumaryFormat: WideString); dispid 2;
    property AutoResizeColumns: WordBool dispid 4;
    procedure SaveToFile(const filename: WideString); dispid 201;
  end;

// *********************************************************************//
// Interface: IReportParameters
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {A5F6E90E-DFE7-49DA-AA38-C1A41C995B6B}
// *********************************************************************//
  IReportParameters = interface(IDispatch)
    ['{A5F6E90E-DFE7-49DA-AA38-C1A41C995B6B}']
    function Get_Count: Integer; safecall;
    function Get_Items(Index: Integer): ReportParam; safecall;
    function ParamExists(const paramname: WideString): WordBool; safecall;
    property Count: Integer read Get_Count;
    property Items[Index: Integer]: ReportParam read Get_Items;
  end;

// *********************************************************************//
// DispIntf:  IReportParametersDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {A5F6E90E-DFE7-49DA-AA38-C1A41C995B6B}
// *********************************************************************//
  IReportParametersDisp = dispinterface
    ['{A5F6E90E-DFE7-49DA-AA38-C1A41C995B6B}']
    property Count: Integer readonly dispid 1;
    property Items[Index: Integer]: ReportParam readonly dispid 2;
    function ParamExists(const paramname: WideString): WordBool; dispid 3;
  end;

// *********************************************************************//
// Interface: IReportParam
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {F1634F9E-DE5A-411E-9A9E-3A46707A7ABB}
// *********************************************************************//
  IReportParam = interface(IDispatch)
    ['{F1634F9E-DE5A-411E-9A9E-3A46707A7ABB}']
    function Get_Name: WideString; safecall;
    procedure Set_Name(const Value: WideString); safecall;
    function Get_Description: WideString; safecall;
    procedure Set_Description(const Value: WideString); safecall;
    function Get_Visible: WordBool; safecall;
    procedure Set_Visible(Value: WordBool); safecall;
    function Get_ParamType: TxParamType; safecall;
    procedure Set_ParamType(Value: TxParamType); safecall;
    function Get_Value: OleVariant; safecall;
    procedure Set_Value(Value: OleVariant); safecall;
    property Name: WideString read Get_Name write Set_Name;
    property Description: WideString read Get_Description write Set_Description;
    property Visible: WordBool read Get_Visible write Set_Visible;
    property ParamType: TxParamType read Get_ParamType write Set_ParamType;
    property Value: OleVariant read Get_Value write Set_Value;
  end;

// *********************************************************************//
// DispIntf:  IReportParamDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {F1634F9E-DE5A-411E-9A9E-3A46707A7ABB}
// *********************************************************************//
  IReportParamDisp = dispinterface
    ['{F1634F9E-DE5A-411E-9A9E-3A46707A7ABB}']
    property Name: WideString dispid 1;
    property Description: WideString dispid 2;
    property Visible: WordBool dispid 3;
    property ParamType: TxParamType dispid 4;
    property Value: OleVariant dispid 5;
  end;

// *********************************************************************//
// Interface: IReportmanXAServer
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {F3A6B88C-D629-402E-BC62-BAB0E2EE39AF}
// *********************************************************************//
  IReportmanXAServer = interface(IDispatch)
    ['{F3A6B88C-D629-402E-BC62-BAB0E2EE39AF}']
    procedure GetPDF(const Report: IReportReport; compressed: WordBool); safecall;
    procedure GetCustomText(const Report: IReportReport); safecall;
    procedure GetText(const Report: IReportReport); safecall;
    procedure GetCSV(const Report: IReportReport); safecall;
    procedure GetMetafile(const Report: IReportReport); safecall;
    procedure GetCSV2(const Report: IReportReport; const separator: WideString); safecall;
  end;

// *********************************************************************//
// DispIntf:  IReportmanXAServerDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {F3A6B88C-D629-402E-BC62-BAB0E2EE39AF}
// *********************************************************************//
  IReportmanXAServerDisp = dispinterface
    ['{F3A6B88C-D629-402E-BC62-BAB0E2EE39AF}']
    procedure GetPDF(const Report: IReportReport; compressed: WordBool); dispid 1;
    procedure GetCustomText(const Report: IReportReport); dispid 2;
    procedure GetText(const Report: IReportReport); dispid 3;
    procedure GetCSV(const Report: IReportReport); dispid 4;
    procedure GetMetafile(const Report: IReportReport); dispid 5;
    procedure GetCSV2(const Report: IReportReport; const separator: WideString); dispid 6;
  end;

// *********************************************************************//
// Interface: IPreviewControl
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {3D8043B8-E2F6-4F5D-B055-571924F5B0DC}
// *********************************************************************//
  IPreviewControl = interface(IDispatch)
    ['{3D8043B8-E2F6-4F5D-B055-571924F5B0DC}']
    function Get_Visible: WordBool; safecall;
    procedure Set_Visible(Value: WordBool); safecall;
    function Get_AutoScroll: WordBool; safecall;
    procedure Set_AutoScroll(Value: WordBool); safecall;
    function Get_AutoSize: WordBool; safecall;
    procedure Set_AutoSize(Value: WordBool); safecall;
    function Get_AxBorderStyle: TxActiveFormBorderStyle; safecall;
    procedure Set_AxBorderStyle(Value: TxActiveFormBorderStyle); safecall;
    function Get_Caption: WideString; safecall;
    procedure Set_Caption(const Value: WideString); safecall;
    function Get_Color: OLE_COLOR; safecall;
    procedure Set_Color(Value: OLE_COLOR); safecall;
    function Get_Font: IFontDisp; safecall;
    procedure Set_Font(const Value: IFontDisp); safecall;
    procedure _Set_Font(var Value: IFontDisp); safecall;
    function Get_KeyPreview: WordBool; safecall;
    procedure Set_KeyPreview(Value: WordBool); safecall;
    function Get_PixelsPerInch: Integer; safecall;
    procedure Set_PixelsPerInch(Value: Integer); safecall;
    function Get_PrintScale: TxPrintScale; safecall;
    procedure Set_PrintScale(Value: TxPrintScale); safecall;
    function Get_Scaled: WordBool; safecall;
    procedure Set_Scaled(Value: WordBool); safecall;
    function Get_Active: WordBool; safecall;
    function Get_DropTarget: WordBool; safecall;
    procedure Set_DropTarget(Value: WordBool); safecall;
    function Get_HelpFile: WideString; safecall;
    procedure Set_HelpFile(const Value: WideString); safecall;
    function Get_DoubleBuffered: WordBool; safecall;
    procedure Set_DoubleBuffered(Value: WordBool); safecall;
    function Get_VisibleDockClientCount: Integer; safecall;
    function Get_Enabled: WordBool; safecall;
    procedure Set_Enabled(Value: WordBool); safecall;
    function Get_Cursor: Smallint; safecall;
    procedure Set_Cursor(Value: Smallint); safecall;
    procedure SetReport(const Report: IReportReport); safecall;
    function Get_AutoScale: TxAutoScaleType; safecall;
    procedure Set_AutoScale(Value: TxAutoScaleType); safecall;
    function Get_PreviewScale: Double; safecall;
    procedure Set_PreviewScale(Value: Double); safecall;
    function Get_EntirePageCount: Integer; safecall;
    procedure Set_EntirePageCount(Value: Integer); safecall;
    function Get_EntireTopDown: WordBool; safecall;
    procedure Set_EntireTopDown(Value: WordBool); safecall;
    procedure FirstPage; safecall;
    procedure PriorPage; safecall;
    procedure NextPage; safecall;
    procedure LastPage; safecall;
    procedure RefreshMetafile; safecall;
    function Get_Page: Integer; safecall;
    procedure Set_Page(Value: Integer); safecall;
    procedure DoScroll(vertical: WordBool; increment: Integer); safecall;
    function Get_Finished: WordBool; safecall;
    procedure Set_Finished(Value: WordBool); safecall;
    procedure SaveToFile(const filename: WideString; format: Integer; const textdriver: WideString;
                         horzres: Integer; vertres: Integer; mono: WordBool); safecall;
    procedure Clear; safecall;
    property Visible: WordBool read Get_Visible write Set_Visible;
    property AutoScroll: WordBool read Get_AutoScroll write Set_AutoScroll;
    property AutoSize: WordBool read Get_AutoSize write Set_AutoSize;
    property AxBorderStyle: TxActiveFormBorderStyle read Get_AxBorderStyle write Set_AxBorderStyle;
    property Caption: WideString read Get_Caption write Set_Caption;
    property Color: OLE_COLOR read Get_Color write Set_Color;
    property Font: IFontDisp read Get_Font write Set_Font;
    property KeyPreview: WordBool read Get_KeyPreview write Set_KeyPreview;
    property PixelsPerInch: Integer read Get_PixelsPerInch write Set_PixelsPerInch;
    property PrintScale: TxPrintScale read Get_PrintScale write Set_PrintScale;
    property Scaled: WordBool read Get_Scaled write Set_Scaled;
    property Active: WordBool read Get_Active;
    property DropTarget: WordBool read Get_DropTarget write Set_DropTarget;
    property HelpFile: WideString read Get_HelpFile write Set_HelpFile;
    property DoubleBuffered: WordBool read Get_DoubleBuffered write Set_DoubleBuffered;
    property VisibleDockClientCount: Integer read Get_VisibleDockClientCount;
    property Enabled: WordBool read Get_Enabled write Set_Enabled;
    property Cursor: Smallint read Get_Cursor write Set_Cursor;
    property AutoScale: TxAutoScaleType read Get_AutoScale write Set_AutoScale;
    property PreviewScale: Double read Get_PreviewScale write Set_PreviewScale;
    property EntirePageCount: Integer read Get_EntirePageCount write Set_EntirePageCount;
    property EntireTopDown: WordBool read Get_EntireTopDown write Set_EntireTopDown;
    property Page: Integer read Get_Page write Set_Page;
    property Finished: WordBool read Get_Finished write Set_Finished;
  end;

// *********************************************************************//
// DispIntf:  IPreviewControlDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {3D8043B8-E2F6-4F5D-B055-571924F5B0DC}
// *********************************************************************//
  IPreviewControlDisp = dispinterface
    ['{3D8043B8-E2F6-4F5D-B055-571924F5B0DC}']
    property Visible: WordBool dispid 1;
    property AutoScroll: WordBool dispid 2;
    property AutoSize: WordBool dispid 3;
    property AxBorderStyle: TxActiveFormBorderStyle dispid 4;
    property Caption: WideString dispid -518;
    property Color: OLE_COLOR dispid -501;
    property Font: IFontDisp dispid -512;
    property KeyPreview: WordBool dispid 5;
    property PixelsPerInch: Integer dispid 6;
    property PrintScale: TxPrintScale dispid 7;
    property Scaled: WordBool dispid 8;
    property Active: WordBool readonly dispid 9;
    property DropTarget: WordBool dispid 10;
    property HelpFile: WideString dispid 11;
    property DoubleBuffered: WordBool dispid 12;
    property VisibleDockClientCount: Integer readonly dispid 13;
    property Enabled: WordBool dispid -514;
    property Cursor: Smallint dispid 14;
    procedure SetReport(const Report: IReportReport); dispid 16;
    property AutoScale: TxAutoScaleType dispid 15;
    property PreviewScale: Double dispid 17;
    property EntirePageCount: Integer dispid 18;
    property EntireTopDown: WordBool dispid 19;
    procedure FirstPage; dispid 20;
    procedure PriorPage; dispid 21;
    procedure NextPage; dispid 22;
    procedure LastPage; dispid 23;
    procedure RefreshMetafile; dispid 24;
    property Page: Integer dispid 25;
    procedure DoScroll(vertical: WordBool; increment: Integer); dispid 26;
    property Finished: WordBool dispid 27;
    procedure SaveToFile(const filename: WideString; format: Integer; const textdriver: WideString;
                         horzres: Integer; vertres: Integer; mono: WordBool); dispid 28;
    procedure Clear; dispid 29;
  end;

// *********************************************************************//
// DispIntf:  IPreviewControlEvents
// Flags:     (0)
// GUID:      {7364E2EA-8EEC-4673-9059-3B078C388717}
// *********************************************************************//
  IPreviewControlEvents = dispinterface
    ['{7364E2EA-8EEC-4673-9059-3B078C388717}']
    procedure OnActivate; dispid 1;
    procedure OnClick; dispid 2;
    procedure OnCreate; dispid 3;
    procedure OnDblClick; dispid 5;
    procedure OnDestroy; dispid 6;
    procedure OnDeactivate; dispid 7;
    procedure OnKeyPress(var Key: Smallint); dispid 11;
    procedure OnPaint; dispid 16;
    procedure OnWorkProgress(records: Integer; pagecount: Integer; var docancel: WordBool); dispid 4;
    procedure OnPageDrawn(PageDrawn: Integer; PagesDrawn: Integer); dispid 8;
  end;

// *********************************************************************//
// The Class CoReportReport provides a Create and CreateRemote method to
// create instances of the default interface IReportReport exposed by
// the CoClass ReportReport. The functions are intended to be used by
// clients wishing to automate the CoClass objects exposed by the
// server of this typelibrary.
// *********************************************************************//
  CoReportReport = class
    class function Create: IReportReport;
    class function CreateRemote(const MachineName: string): IReportReport;
  end;

// *********************************************************************//
// The Class CoReportParameters provides a Create and CreateRemote method to
// create instances of the default interface IReportParameters exposed by
// the CoClass ReportParameters. The functions are intended to be used by
// clients wishing to automate the CoClass objects exposed by the
// server of this typelibrary.
// *********************************************************************//
  CoReportParameters = class
    class function Create: IReportParameters;
    class function CreateRemote(const MachineName: string): IReportParameters;
  end;

// *********************************************************************//
// The Class CoReportParam provides a Create and CreateRemote method to
// create instances of the default interface IReportParam exposed by
// the CoClass ReportParam. The functions are intended to be used by
// clients wishing to automate the CoClass objects exposed by the
// server of this typelibrary.
// *********************************************************************//
  CoReportParam = class
    class function Create: IReportParam;
    class function CreateRemote(const MachineName: string): IReportParam;
  end;

// *********************************************************************//
// The Class CoReportmanXAServer provides a Create and CreateRemote method to
// create instances of the default interface IReportmanXAServer exposed by
// the CoClass ReportmanXAServer. The functions are intended to be used by
// clients wishing to automate the CoClass objects exposed by the
// server of this typelibrary.
// *********************************************************************//
  CoReportmanXAServer = class
    class function Create: IReportmanXAServer;
    class function CreateRemote(const MachineName: string): IReportmanXAServer;
  end;

implementation

uses System.Win.ComObj;

class function CoReportReport.Create: IReportReport;
begin
  Result := CreateComObject(CLASS_ReportReport) as IReportReport;
end;

class function CoReportReport.CreateRemote(const MachineName: string): IReportReport;
begin
  Result := CreateRemoteComObject(MachineName, CLASS_ReportReport) as IReportReport;
end;

class function CoReportParameters.Create: IReportParameters;
begin
  Result := CreateComObject(CLASS_ReportParameters) as IReportParameters;
end;

class function CoReportParameters.CreateRemote(const MachineName: string): IReportParameters;
begin
  Result := CreateRemoteComObject(MachineName, CLASS_ReportParameters) as IReportParameters;
end;

class function CoReportParam.Create: IReportParam;
begin
  Result := CreateComObject(CLASS_ReportParam) as IReportParam;
end;

class function CoReportParam.CreateRemote(const MachineName: string): IReportParam;
begin
  Result := CreateRemoteComObject(MachineName, CLASS_ReportParam) as IReportParam;
end;

class function CoReportmanXAServer.Create: IReportmanXAServer;
begin
  Result := CreateComObject(CLASS_ReportmanXAServer) as IReportmanXAServer;
end;

class function CoReportmanXAServer.CreateRemote(const MachineName: string): IReportmanXAServer;
begin
  Result := CreateRemoteComObject(MachineName, CLASS_ReportmanXAServer) as IReportmanXAServer;
end;

end.

