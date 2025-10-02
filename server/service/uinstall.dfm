object FStartService: TFStartService
  Left = 213
  Top = 147
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  ActiveControl = EUserName
  BorderStyle = bsDialog
  Caption = 'Instalation of Report Manager Service'
  ClientHeight = 459
  ClientWidth = 554
  Color = clBtnFace
  ParentFont = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 120
  TextHeight = 20
  object LUser: TLabel
    Left = 15
    Top = 150
    Width = 70
    Height = 20
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'User name'
  end
  object LPassword: TLabel
    Left = 15
    Top = 185
    Width = 61
    Height = 20
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Password'
  end
  object LConfirm: TLabel
    Left = 15
    Top = 220
    Width = 120
    Height = 20
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Confirm password'
  end
  object Label1: TLabel
    Left = 15
    Top = 65
    Width = 521
    Height = 61
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    AutoSize = False
    Caption = 
      'You should enter a valid user system account and password. This ' +
      'account will start the service and should have rights to access ' +
      'report directories. If left blank the LocalSystem account will b' +
      'e used but it does not work in all systems'
    WordWrap = True
  end
  object Label2: TLabel
    Left = 15
    Top = 5
    Width = 516
    Height = 61
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    AutoSize = False
    Caption = 
      'This application must be executed in the server machine you want' +
      ' to install the service. You must have Administration rights in ' +
      'this machine.'
    WordWrap = True
  end
  object EUserName: TEdit
    Left = 195
    Top = 145
    Width = 151
    Height = 28
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    TabOrder = 0
  end
  object EPassword: TEdit
    Left = 195
    Top = 180
    Width = 151
    Height = 28
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    PasswordChar = '*'
    TabOrder = 1
  end
  object EConfirm: TEdit
    Left = 195
    Top = 215
    Width = 151
    Height = 28
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    PasswordChar = '*'
    TabOrder = 2
  end
  object BInstall: TButton
    Left = 15
    Top = 265
    Width = 166
    Height = 41
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Install service'
    TabOrder = 3
    OnClick = BInstallClick
  end
  object BUnInstall: TButton
    Left = 315
    Top = 260
    Width = 166
    Height = 41
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Uninstall service'
    TabOrder = 4
    OnClick = BUnInstallClick
  end
  object GroupBox1: TGroupBox
    Left = 15
    Top = 315
    Width = 526
    Height = 131
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Current service status'
    TabOrder = 5
    object LStatus: TLabel
      Left = 15
      Top = 30
      Width = 266
      Height = 26
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      AutoSize = False
    end
    object Label3: TLabel
      Left = 10
      Top = 105
      Width = 315
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Go to system services to change startup options'
    end
    object BStart: TButton
      Left = 10
      Top = 65
      Width = 156
      Height = 36
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Start Service'
      Enabled = False
      TabOrder = 0
      OnClick = BStartClick
    end
    object BStop: TButton
      Left = 170
      Top = 65
      Width = 161
      Height = 36
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Stop service'
      Enabled = False
      TabOrder = 1
      OnClick = BStopClick
    end
    object BRefresh: TButton
      Left = 340
      Top = 65
      Width = 176
      Height = 36
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Refresh Status'
      TabOrder = 2
      OnClick = BRefreshClick
    end
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 3000
    OnTimer = Timer1Timer
    Left = 328
    Top = 140
  end
end
