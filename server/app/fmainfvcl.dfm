object FSerMainVCL: TFSerMainVCL
  Left = 36
  Top = 82
  Width = 768
  Height = 452
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  VertScrollBar.Range = 146
  ActiveControl = LMEssages
  Caption = 'Report Manager Server application'
  Color = clBtnFace
  ParentFont = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 120
  TextHeight = 20
  object LMEssages: TMemo
    Left = 0
    Top = 186
    Width = 750
    Height = 219
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alClient
    Color = clInfoBk
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 0
    WordWrap = False
    ExplicitWidth = 526
    ExplicitHeight = 121
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 750
    Height = 186
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alTop
    TabOrder = 1
    ExplicitWidth = 526
    DesignSize = (
      750
      186)
    object LLog: TLabel
      Left = 10
      Top = 90
      Width = 50
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Log file'
    end
    object LHost: TLabel
      Left = 10
      Top = 60
      Width = 31
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Host'
    end
    object LHostName: TLabel
      Left = 165
      Top = 60
      Width = 20
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = '     '
    end
    object LConfigFile: TLabel
      Left = 10
      Top = 120
      Width = 116
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Configuration file'
    end
    object LPort: TLabel
      Left = 10
      Top = 155
      Width = 26
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Port'
    end
    object LPortNumber: TLabel
      Left = 220
      Top = 150
      Width = 181
      Height = 26
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      AutoSize = False
    end
    object LVersion: TLabel
      Left = 365
      Top = 55
      Width = 48
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Version'
    end
    object BStartServer: TButton
      Left = 10
      Top = 10
      Width = 166
      Height = 36
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Start Server'
      TabOrder = 0
      OnClick = BStartServerClick
    end
    object BStopServer: TButton
      Left = 195
      Top = 10
      Width = 166
      Height = 36
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Stop Server'
      Enabled = False
      TabOrder = 1
      OnClick = BStopServerClick
    end
    object ELogFIle: TEdit
      Left = 220
      Top = 85
      Width = 521
      Height = 28
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Anchors = [akLeft, akTop, akRight]
      Color = clInfoBk
      ReadOnly = True
      TabOrder = 2
    end
    object EConfigFile: TEdit
      Left = 220
      Top = 115
      Width = 521
      Height = 28
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Anchors = [akLeft, akTop, akRight]
      Color = clInfoBk
      ReadOnly = True
      TabOrder = 3
    end
    object BConfigLibs: TButton
      Left = 375
      Top = 10
      Width = 176
      Height = 36
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Configure Libraries'
      TabOrder = 4
      OnClick = BConfigLibsClick
    end
  end
end
