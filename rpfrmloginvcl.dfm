object FRpLoginVCL: TFRpLoginVCL
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Login to Reportman.AI'
  ClientHeight = 450
  ClientWidth = 400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 13
  object LTitle: TLabel
    Left = 24
    Top = 16
    Width = 135
    Height = 19
    Caption = 'Account Login'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LStatus: TLabel
    Left = 24
    Top = 320
    Width = 352
    Height = 13
    AutoSize = False
    Caption = 'Ready'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    WordWrap = True
  end
  object BtnGoogle: TButton
    Left = 24
    Top = 56
    Width = 352
    Height = 41
    Caption = 'Login with Google'
    TabOrder = 0
    OnClick = BtnGoogleClick
  end
  object BtnMicrosoft: TButton
    Left = 24
    Top = 112
    Width = 352
    Height = 41
    Caption = 'Login with Microsoft'
    TabOrder = 1
    OnClick = BtnMicrosoftClick
  end
  object BtnEmail: TButton
    Left = 24
    Top = 168
    Width = 352
    Height = 41
    Caption = 'Login with Email Code'
    TabOrder = 2
    OnClick = BtnEmailClick
  end
  object PanelEmail: TPanel
    Left = 24
    Top = 216
    Width = 352
    Height = 97
    BevelOuter = bvNone
    TabOrder = 3
    Visible = False
    object LEmail: TLabel
      Left = 0
      Top = 8
      Width = 28
      Height = 13
      Caption = 'Email:'
    end
    object LCode: TLabel
      Left = 0
      Top = 56
      Width = 83
      Height = 13
      Caption = 'Verification Code:'
    end
    object EditEmail: TEdit
      Left = 0
      Top = 24
      Width = 265
      Height = 21
      TabOrder = 0
    end
    object EditCode: TEdit
      Left = 0
      Top = 72
      Width = 265
      Height = 21
      TabOrder = 1
    end
    object BtnSendCode: TButton
      Left = 271
      Top = 22
      Width = 81
      Height = 25
      Caption = 'Send Code'
      TabOrder = 2
      OnClick = BtnSendCodeClick
    end
    object BtnLoginCode: TButton
      Left = 271
      Top = 70
      Width = 81
      Height = 25
      Caption = 'Login'
      TabOrder = 3
      OnClick = BtnLoginCodeClick
    end
  end
  object MemoLog: TMemo
    Left = 24
    Top = 344
    Width = 352
    Height = 89
    Color = clInfoBk
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clInfoText
    Font.Height = -11
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 4
  end
end
