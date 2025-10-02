object FMainVCL: TFMainVCL
  Left = 134
  Top = 83
  Width = 830
  Height = 599
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  HorzScrollBar.Range = 486
  VertScrollBar.Range = 201
  ActiveControl = ComboHost
  Caption = 'Report Manager Server configuration'
  Color = clBtnFace
  ParentFont = True
  Position = poScreenCenter
  ShowHint = True
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 120
  DesignSize = (
    812
    552)
  TextHeight = 20
  object LHost: TLabel
    Left = 15
    Top = 15
    Width = 31
    Height = 20
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Host'
  end
  object LPort: TLabel
    Left = 636
    Top = 9
    Width = 26
    Height = 20
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Anchors = [akTop, akRight]
    Caption = 'Port'
    ExplicitLeft = 472
  end
  object GUser: TGroupBox
    Left = 10
    Top = 70
    Width = 793
    Height = 152
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Anchors = [akLeft, akTop, akRight]
    Caption = 'User information'
    TabOrder = 1
    ExplicitWidth = 749
    DesignSize = (
      793
      152)
    object LUserName: TLabel
      Left = 10
      Top = 30
      Width = 70
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'User name'
    end
    object LPassword: TLabel
      Left = 10
      Top = 65
      Width = 61
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Password'
    end
    object EUserName: TEdit
      Left = 139
      Top = 24
      Width = 635
      Height = 28
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 0
      Text = 'Admin'
      ExplicitWidth = 340
    end
    object EPassword: TEdit
      Left = 138
      Top = 60
      Width = 636
      Height = 28
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Anchors = [akLeft, akTop, akRight]
      PasswordChar = '*'
      TabOrder = 2
      ExplicitWidth = 341
    end
    object BConnect: TButton
      Left = 10
      Top = 105
      Width = 141
      Height = 31
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Connect'
      TabOrder = 1
      OnClick = BConnectClick
    end
  end
  object GServerinfo: TGroupBox
    Left = 9
    Top = 46
    Width = 794
    Height = 411
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Anchors = [akLeft, akTop, akRight]
    Caption = 'Server information'
    TabOrder = 2
    Visible = False
    ExplicitWidth = 750
    DesignSize = (
      794
      411)
    object PControl: TPageControl
      Left = 10
      Top = 24
      Width = 761
      Height = 327
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      ActivePage = TabUsers
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 1
      ExplicitWidth = 608
      object TabUsers: TTabSheet
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Users'
        DesignSize = (
          753
          292)
        object GUsers: TGroupBox
          Left = 0
          Top = 0
          Width = 748
          Height = 164
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akLeft, akTop, akRight]
          Caption = 'Users'
          TabOrder = 0
          ExplicitWidth = 595
          DesignSize = (
            748
            164)
          object LUsers: TListBox
            Left = 4
            Top = 27
            Width = 538
            Height = 113
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Anchors = [akLeft, akTop, akRight]
            ItemHeight = 20
            TabOrder = 0
            OnClick = LUsersClick
            ExplicitWidth = 385
          end
          object BDeleteUser: TButton
            Left = 550
            Top = 108
            Width = 191
            Height = 31
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Anchors = [akTop, akRight]
            Caption = 'Delete'
            TabOrder = 3
            OnClick = BDeleteUserClick
            ExplicitLeft = 397
          end
          object BAddUser: TButton
            Left = 550
            Top = 29
            Width = 191
            Height = 30
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Anchors = [akTop, akRight]
            Caption = 'Add'
            TabOrder = 1
            OnClick = BAddUserClick
            ExplicitLeft = 397
          end
          object BChangePassword: TButton
            Left = 550
            Top = 65
            Width = 191
            Height = 35
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Anchors = [akTop, akRight]
            Caption = 'Change Password'
            TabOrder = 2
            OnClick = BChangePasswordClick
            ExplicitLeft = 397
          end
        end
        object GGroups: TGroupBox
          Left = 1
          Top = 152
          Width = 291
          Height = 136
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Groups'
          TabOrder = 1
          object LGroups: TListBox
            Left = 133
            Top = 20
            Width = 148
            Height = 101
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            ItemHeight = 20
            TabOrder = 0
          end
          object BAddGroup: TButton
            Left = 5
            Top = 20
            Width = 120
            Height = 41
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Caption = 'Add'
            TabOrder = 1
            OnClick = BAddGroupClick
          end
          object BDeleteGroup: TButton
            Left = 4
            Top = 79
            Width = 121
            Height = 42
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Caption = 'Delete'
            TabOrder = 2
            OnClick = BDeleteGroupClick
          end
        end
        object GUserGroups: TGroupBox
          Left = 296
          Top = 152
          Width = 453
          Height = 136
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akLeft, akTop, akRight]
          Caption = 'The user is member of this groups'
          TabOrder = 2
          ExplicitWidth = 300
          DesignSize = (
            453
            136)
          object LUserGroups: TListBox
            Left = 50
            Top = 25
            Width = 398
            Height = 96
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Anchors = [akLeft, akTop, akRight]
            ItemHeight = 20
            TabOrder = 0
            ExplicitWidth = 264
          end
          object BAddUserGroup: TBitBtn
            Left = 5
            Top = 30
            Width = 41
            Height = 41
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Glyph.Data = {
              AA040000424DAA04000000000000360000002800000013000000130000000100
              18000000000074040000C40E0000C40E00000000000000000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF00
              0000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000000000FF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000000000000000FF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FF000000000000000000000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FF000000000000000000FF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FF000000000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF00
              0000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000}
            TabOrder = 1
            OnClick = BAddUserGroupClick
          end
          object BDeleteUserGroup: TBitBtn
            Left = 5
            Top = 75
            Width = 41
            Height = 41
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Glyph.Data = {
              AA040000424DAA04000000000000360000002800000013000000130000000100
              18000000000074040000C40E0000C40E00000000000000000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF00
              0000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000000000FF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000000000000000FF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000000000000000000000FF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FF000000000000000000FF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FF000000000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF00
              0000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000}
            TabOrder = 2
            OnClick = BDeleteUserGroupClick
          end
        end
      end
      object TabAliases: TTabSheet
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Aliases'
        ImageIndex = 2
        DesignSize = (
          753
          292)
        object GReportDirectories: TGroupBox
          Left = 0
          Top = 0
          Width = 753
          Height = 166
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akLeft, akTop, akRight]
          Caption = 'Report server directories'
          TabOrder = 0
          ExplicitWidth = 619
          DesignSize = (
            753
            166)
          object DBGrid1: TDBGrid
            Left = 5
            Top = 20
            Width = 743
            Height = 101
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Anchors = [akLeft, akTop, akRight]
            DataSource = SDirectories
            ReadOnly = True
            TabOrder = 0
            TitleFont.Charset = DEFAULT_CHARSET
            TitleFont.Color = clWindowText
            TitleFont.Height = -15
            TitleFont.Name = 'Segoe UI'
            TitleFont.Style = []
          end
          object BAddAlias: TButton
            Left = 5
            Top = 124
            Width = 166
            Height = 37
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Caption = 'Add'
            TabOrder = 1
            OnClick = BAddAliasClick
          end
          object BDeleteAlias: TButton
            Left = 175
            Top = 124
            Width = 166
            Height = 37
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Caption = 'Delete'
            TabOrder = 2
            OnClick = BDeleteAliasClick
          end
          object BPreviewTree: TButton
            Left = 350
            Top = 124
            Width = 398
            Height = 37
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Anchors = [akLeft, akTop, akRight]
            Caption = 'Preview Report Tree'
            TabOrder = 3
            OnClick = BPreviewTreeClick
            ExplicitWidth = 264
          end
        end
        object GGroups2: TGroupBox
          Left = 0
          Top = 170
          Width = 246
          Height = 131
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Groups'
          TabOrder = 1
          object LGroups2: TListBox
            Left = 5
            Top = 20
            Width = 231
            Height = 101
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            ItemHeight = 20
            TabOrder = 0
          end
        end
        object GAliasGroups: TGroupBox
          Left = 250
          Top = 170
          Width = 503
          Height = 131
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akLeft, akTop, akRight]
          Caption = 'This alias is accessible by this user groups'
          TabOrder = 2
          ExplicitWidth = 369
          DesignSize = (
            503
            131)
          object LAliasGroups: TListBox
            Left = 50
            Top = 25
            Width = 448
            Height = 96
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Anchors = [akLeft, akTop, akRight]
            ItemHeight = 20
            TabOrder = 0
            ExplicitWidth = 314
          end
          object BDeleteAliasGroup: TBitBtn
            Left = 5
            Top = 80
            Width = 41
            Height = 41
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Glyph.Data = {
              AA040000424DAA04000000000000360000002800000013000000130000000100
              18000000000074040000C40E0000C40E00000000000000000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF00
              0000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000000000FF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000000000000000FF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000000000000000000000FF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FF000000000000000000FF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FF000000000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF00
              0000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000}
            TabOrder = 2
            OnClick = BDeleteAliasGroupClick
          end
          object BAddAliasGroup: TBitBtn
            Left = 5
            Top = 30
            Width = 41
            Height = 41
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Glyph.Data = {
              AA040000424DAA04000000000000360000002800000013000000130000000100
              18000000000074040000C40E0000C40E00000000000000000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF00
              0000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000000000FF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000000000000000FF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FF000000000000000000000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FF000000000000000000FF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FF000000000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FF000000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF00
              0000FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
              FF00FFFF00FFFF00FFFF00FFFF00FF000000FF00FFFF00FFFF00FFFF00FFFF00
              FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
              00FFFF00FFFF00FFFF00FF000000}
            TabOrder = 1
            OnClick = BAddAliasGroupClick
          end
        end
      end
      object TabConnections: TTabSheet
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Connections'
        ImageIndex = 2
        object PBotTasks: TPanel
          Left = 0
          Top = 256
          Width = 753
          Height = 36
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Align = alBottom
          TabOrder = 0
          ExplicitTop = 265
          ExplicitWidth = 619
          object BRefresh: TButton
            Left = 10
            Top = 5
            Width = 156
            Height = 26
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Caption = 'Refresh'
            TabOrder = 0
            OnClick = BRefreshClick
          end
          object BStop: TButton
            Left = 180
            Top = 5
            Width = 141
            Height = 26
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Caption = 'Close connection'
            TabOrder = 1
            OnClick = BStopClick
          end
        end
        object GTasks: TDBGrid
          Left = 0
          Top = 0
          Width = 753
          Height = 256
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Align = alClient
          DataSource = SData
          TabOrder = 1
          TitleFont.Charset = DEFAULT_CHARSET
          TitleFont.Color = clWindowText
          TitleFont.Height = -15
          TitleFont.Name = 'Segoe UI'
          TitleFont.Style = []
          Visible = False
        end
      end
    end
    object BCloseConnection: TButton
      Left = 10
      Top = 356
      Width = 216
      Height = 42
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Close connection'
      TabOrder = 0
      OnClick = BCloseConnectionClick
    end
  end
  object ComboHost: TComboBox
    Left = 115
    Top = 10
    Width = 500
    Height = 28
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
    Items.Strings = (
      'localhost')
    ExplicitWidth = 336
  end
  object LMessages: TListBox
    Left = 9
    Top = 465
    Width = 794
    Height = 79
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Anchors = [akLeft, akTop, akRight, akBottom]
    Color = clInfoBk
    ItemHeight = 20
    TabOrder = 3
    ExplicitWidth = 750
    ExplicitHeight = 44
  end
  object ComboPort: TComboBox
    Left = 691
    Top = 9
    Width = 96
    Height = 28
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Anchors = [akTop, akRight]
    TabOrder = 4
    Text = '3060'
    Items.Strings = (
      '3060')
    ExplicitLeft = 527
  end
  object Trans: TRpTranslator
    Active = False
    Filename = 'reportmanres'
    Left = 352
    Top = 8
  end
  object DDirectories: TClientDataSet
    Aggregates = <>
    Params = <>
    AfterPost = DDirectoriesAfterScroll
    AfterScroll = DDirectoriesAfterScroll
    Left = 348
    Top = 276
    object DDirectoriesAlias: TStringField
      DisplayLabel = 'Server alias'
      DisplayWidth = 15
      FieldName = 'Alias'
      Size = 30
    end
    object DDirectoriesServerPath: TStringField
      DisplayLabel = 'Server Path'
      DisplayWidth = 50
      FieldName = 'ServerPath'
      Size = 250
    end
  end
  object SDirectories: TDataSource
    DataSet = DDirectories
    Left = 312
    Top = 272
  end
  object adata: TClientDataSet
    Aggregates = <>
    Params = <>
    Left = 116
    Top = 120
    object adataID: TIntegerField
      DisplayLabel = 'Id.'
      FieldName = 'ID'
    end
    object adataLASTOPERATION: TDateTimeField
      DisplayLabel = 'Last Operation'
      FieldName = 'LASTOPERATION'
    end
    object adataCONNECTIONDATE: TDateTimeField
      DisplayLabel = 'Conn.Date'
      FieldName = 'CONNECTIONDATE'
    end
    object adataUSERNAME: TStringField
      DisplayLabel = 'User Name'
      FieldName = 'USERNAME'
      Size = 40
    end
    object adataRUNNING: TBooleanField
      DisplayLabel = 'Running'
      FieldName = 'RUNNING'
    end
  end
  object SData: TDataSource
    DataSet = adata
    Left = 172
    Top = 124
  end
end
