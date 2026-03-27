object FRpLoginFrameVCL: TFRpLoginFrameVCL
  Left = 0
  Top = 0
  Width = 250
  Height = 40
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  TabOrder = 0
  PixelsPerInch = 120
  object PContainer: TPanel
    Left = 0
    Top = 0
    Width = 250
    Height = 40
    Cursor = crHandPoint
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alClient
    BevelOuter = bvNone
    BorderStyle = bsSingle
    Ctl3D = False
    ParentCtl3D = False
    TabOrder = 0
    OnClick = ImageAvatarClick
    DesignSize = (
      248
      38)
    object ImageAvatar: TImage
      Left = 6
      Top = 5
      Width = 28
      Height = 28
      Cursor = crHandPoint
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Center = True
      Proportional = True
      Stretch = True
      Visible = False
      OnClick = ImageAvatarClick
    end
    object LabelUser: TLabel
      Left = 40
      Top = 12
      Width = 73
      Height = 20
      Cursor = crHandPoint
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'User Name'
      Visible = False
      OnClick = ImageAvatarClick
    end
    object LabelArrow: TLabel
      Left = 224
      Top = 13
      Width = 14
      Height = 14
      Cursor = crHandPoint
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Anchors = [akTop, akRight]
      Caption = '6'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -14
      Font.Name = 'Marlett'
      Font.Style = []
      ParentFont = False
      Visible = False
      OnClick = ImageAvatarClick
    end
    object BtnLogin: TButton
      Left = 0
      Top = 0
      Width = 248
      Height = 38
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Align = alClient
      Caption = 'Login with AI'
      TabOrder = 0
      OnClick = BtnLoginClick
      ExplicitHeight = 48
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
