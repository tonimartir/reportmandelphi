object FRpLoginVCL: TFRpLoginVCL
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Login - Reportman AI'
  ClientHeight = 320
  ClientWidth = 380
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  object PanelButtons: TPanel
    Left = 0
    Top = 0
    Width = 380
    Height = 200
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object LTitle: TLabel
      Left = 24
      Top = 16
      Width = 332
      Height = 24
      Alignment = taCenter
      AutoSize = False
      Caption = 'Sign in to Reportman AI'
      Font.Height = -16
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object BtnGoogle: TButton
      Left = 60
      Top = 56
      Width = 260
      Height = 36
      Caption = 'Continue with Google'
      TabOrder = 0
      OnClick = BtnGoogleClick
    end
    object BtnMicrosoft: TButton
      Left = 60
      Top = 100
      Width = 260
      Height = 36
      Caption = 'Continue with Microsoft'
      TabOrder = 1
      OnClick = BtnMicrosoftClick
    end
    object BtnEmail: TButton
      Left = 60
      Top = 144
      Width = 260
      Height = 36
      Caption = 'Continue with Email'
      TabOrder = 2
      OnClick = BtnEmailClick
    end
  end
  object PanelEmail: TPanel
    Left = 0
    Top = 200
    Width = 380
    Height = 120
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    Visible = False
    object LEmail: TLabel
      Left = 24
      Top = 8
      Width = 30
      Height = 13
      Caption = 'Email:'
    end
    object LCode: TLabel
      Left = 24
      Top = 56
      Width = 30
      Height = 13
      Caption = 'Code:'
    end
    object EditEmail: TEdit
      Left = 60
      Top = 4
      Width = 200
      Height = 21
      TabOrder = 0
    end
    object BtnSendCode: TButton
      Left = 268
      Top = 2
      Width = 100
      Height = 25
      Caption = 'Send Code'
      TabOrder = 1
      OnClick = BtnSendCodeClick
    end
    object EditCode: TEdit
      Left = 60
      Top = 52
      Width = 100
      Height = 21
      TabOrder = 2
    end
    object BtnLoginCode: TButton
      Left = 168
      Top = 50
      Width = 100
      Height = 25
      Caption = 'Login'
      TabOrder = 3
      OnClick = BtnLoginCodeClick
    end
    object LStatus: TLabel
      Left = 24
      Top = 88
      Width = 340
      Height = 13
      AutoSize = False
      Font.Color = clRed
      ParentFont = False
    end
  end
end
