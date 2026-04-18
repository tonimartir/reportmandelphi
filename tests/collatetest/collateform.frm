VERSION 5.00
Object = "{D4D26F6B-6564-44F4-A913-03C91CE37740}#2.1#0"; "reportman.ocx"
Begin VB.Form Form1 
   Caption         =   "Form1"
   ClientHeight    =   5430
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   8235
   LinkTopic       =   "Form1"
   ScaleHeight     =   5430
   ScaleWidth      =   8235
   StartUpPosition =   3  'Windows Default
   Begin reportman.ReportManX ReportManX1 
      Height          =   300
      Left            =   240
      TabIndex        =   1
      Top             =   0
      Width           =   1125
      filename        =   ""
      Preview         =   0   'False
      ShowProgress    =   0   'False
      ShowPrintDialog =   0   'False
      Title           =   ""
      Language        =   0
      DoubleBuffered  =   0   'False
      Enabled         =   -1  'True
      Object.Visible         =   -1  'True
      Cursor          =   0
      HelpType        =   1
      HelpKeyword     =   ""
      DefaultPrinter  =   "HP Color LaserJet Pro MFP M477 PCL 6"
      AsyncExecution  =   0   'False
      DebugMode       =   0   'False
   End
   Begin reportman.PreviewControl PreviewControl1 
      Height          =   4095
      Left            =   720
      TabIndex        =   0
      Top             =   480
      Width           =   6255
      Object.Visible         =   -1  'True
      AutoScroll      =   0   'False
      AutoSize        =   0   'False
      AxBorderStyle   =   1
      Caption         =   "PreviewControl"
      Color           =   -16777201
      BeginProperty Font {0BE35203-8F91-11CE-9DE3-00AA004BB851} 
         Name            =   "MS Sans Serif"
         Size            =   8.25
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      KeyPreview      =   0   'False
      PixelsPerInch   =   96
      PrintScale      =   1
      Scaled          =   -1  'True
      DropTarget      =   0   'False
      HelpFile        =   ""
      DoubleBuffered  =   0   'False
      Enabled         =   -1  'True
      Cursor          =   0
      AutoScale       =   0
      PreviewScale    =   0
      EntirePageCount =   1
      EntireTopDown   =   0   'False
      Page            =   -1
      Finished        =   0   'False
   End
   Begin VB.CommandButton Command2 
      Caption         =   "Preview COntrol"
      Height          =   735
      Left            =   4560
      TabIndex        =   3
      Top             =   4680
      Width           =   2535
   End
   Begin VB.CommandButton Command1 
      Caption         =   "Preview modal"
      Height          =   615
      Left            =   1440
      TabIndex        =   2
      Top             =   4680
      Width           =   2175
   End
End
Attribute VB_Name = "Form1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Private Sub Command1_Click()
Dim rutaReporte As String
    
    ' Verificamos si App.Path ya termina con la barra invertida
    If Right$(App.Path, 1) = "\" Then
        rutaReporte = App.Path & "collatetest.rep"
    Else
        rutaReporte = App.Path & "\collatetest.rep"
    End If
    
    ' Asignamos la ruta completa al componente
    ReportManX1.FileName = rutaReporte
    ReportManX1.Preview = True
    ReportManX1.Execute
End Sub

Private Sub Command2_Click()
Dim rutaReporte As String
    
    If Right$(App.Path, 1) = "\" Then
        rutaReporte = App.Path & "collatetest.rep"
    Else
        rutaReporte = App.Path & "\collatetest.rep"
    End If

    ReportManX1.FileName = rutaReporte
       PreviewControl1.SetReport ReportManX1.Report
End Sub


