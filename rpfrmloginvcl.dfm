object FRpLoginVCL: TFRpLoginVCL
  Left = 0
  Top = 0
  Width = 320
  Height = 240
  TabOrder = 0
  object PGuest: TPanel
    Left = 0
    Top = 0
    Width = 320
    Height = 180
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object BLoginGoogle: TButton
      Left = 40
      Top = 20
      Width = 240
      Height = 40
      Caption = 'Login with Google'
      TabOrder = 0
      OnClick = BLoginGoogleClick
    end
    object BLoginMicrosoft: TButton
      Left = 40
      Top = 70
      Width = 240
      Height = 40
      Caption = 'Login with Microsoft'
      TabOrder = 1
      OnClick = BLoginMicrosoftClick
    end
    object BLoginEmail: TButton
      Left = 40
      Top = 120
      Width = 240
      Height = 40
      Caption = 'Login with Email'
      TabOrder = 2
      OnClick = BLoginEmailClick
    end
  end
  object PEmail: TPanel
    Left = 0
    Top = 0
    Width = 320
    Height = 120
    Align = alTop
    BevelOuter = bvNone
    Visible = False
    TabOrder = 1
    object LEmail: TLabel
      Left = 20
      Top = 10
      Width = 32
      Height = 13
      Caption = 'Email:'
    end
    object EEmail: TEdit
      Left = 20
      Top = 30
      Width = 280
      Height = 21
      TabOrder = 0
    end
    object BSendCode: TButton
      Left = 20
      Top = 60
      Width = 130
      Height = 30
      Caption = 'Send Code'
      TabOrder = 1
      OnClick = BSendCodeClick
    end
    object BCancelEmail: TButton
      Left = 170
      Top = 60
      Width = 130
      Height = 30
      Caption = 'Cancel'
      TabOrder = 2
      OnClick = BCancelEmailClick
    end
  end
  object PCode: TPanel
    Left = 0
    Top = 0
    Width = 320
    Height = 120
    Align = alTop
    BevelOuter = bvNone
    Visible = False
    TabOrder = 2
    object LCode: TLabel
      Left = 20
      Top = 10
      Width = 84
      Height = 13
      Caption = 'Validation Code:'
    end
    object ECode: TEdit
      Left = 20
      Top = 30
      Width = 280
      Height = 21
      TabOrder = 0
    end
    object BLogin: TButton
      Left = 20
      Top = 60
      Width = 280
      Height = 40
      Caption = 'Login'
      TabOrder = 1
      OnClick = BLoginClick
    end
  end
  object LStatus: TLabel
    Left = 0
    Top = 227
    Width = 320
    Height = 13
    Align = alBottom
    Alignment = taCenter
    Caption = 'Status'
    ExplicitWidth = 31
  end
end
