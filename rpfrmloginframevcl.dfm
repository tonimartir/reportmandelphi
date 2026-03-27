object FRpLoginFrameVCL: TFRpLoginFrameVCL
  Left = 0
  Top = 0
  Width = 200
  Height = 40
  TabOrder = 0
  object PContainer: TPanel
    Left = 0
    Top = 0
    Width = 200
    Height = 40
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object ImageAvatar: TImage
      Left = 4
      Top = 4
      Width = 32
      Height = 32
      Center = True
      Proportional = True
      Stretch = True
      Visible = False
      OnClick = ImageAvatarClick
    end
    object LabelUser: TLabel
      Left = 42
      Top = 13
      Width = 56
      Height = 13
      Caption = 'User Name'
      Visible = False
      OnClick = ImageAvatarClick
    end
    object BtnLogin: TButton
      Left = 0
      Top = 0
      Width = 200
      Height = 40
      Align = alClient
      Caption = 'Login with AI'
      TabOrder = 0
      OnClick = BtnLoginClick
    end
  end
  object PopupUser: TPopupMenu
    Left = 144
    Top = 8
    object MenuItemProfile: TMenuItem
      Caption = 'Profile Info'
      OnClick = MenuItemProfileClick
    end
    object N1: TMenuItem
      Caption = '-'
    end
    object MenuItemLogout: TMenuItem
      Caption = 'Logout'
      OnClick = MenuItemLogoutClick
    end
  end
end
