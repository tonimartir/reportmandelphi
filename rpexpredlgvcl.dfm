object FRpExpredialogVCL: TFRpExpredialogVCL
  Left = 320
  Top = 101
  Caption = 'Dialog'
  ClientHeight = 558
  ClientWidth = 733
  Color = clBtnFace
  ParentFont = True
  Position = poScreenCenter
  ShowHint = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 120
  TextHeight = 20
  object PBottom: TPanel
    Left = 0
    Top = 175
    Width = 733
    Height = 383
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitTop = 256
    ExplicitWidth = 804
    DesignSize = (
      733
      383)
    object LabelCategory: TLabel
      Left = 6
      Top = 6
      Width = 75
      Height = 25
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Category'
    end
    object LOperation: TLabel
      Left = 188
      Top = 6
      Width = 83
      Height = 25
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Operation'
    end
    object LModel: TLabel
      Left = 6
      Top = 220
      Width = 695
      Height = 45
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
      Caption = 'LModel'
      WordWrap = True
      ExplicitWidth = 766
    end
    object LHelp: TLabel
      Left = 6
      Top = 181
      Width = 40
      Height = 25
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Help'
    end
    object LParams: TLabel
      Left = 6
      Top = 267
      Width = 702
      Height = 55
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
      Caption = 'Params'
      WordWrap = True
      ExplicitWidth = 773
    end
    object LItems: TListBox
      Left = 188
      Top = 31
      Width = 520
      Height = 139
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akLeft, akTop, akRight]
      ItemHeight = 20
      TabOrder = 0
      OnClick = LItemsClick
      OnDblClick = LItemsDblClick
      ExplicitWidth = 870
    end
    object BCancel: TButton
      Left = 180
      Top = 332
      Width = 133
      Height = 39
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '&Cancel'
      ModalResult = 2
      TabOrder = 1
    end
    object BOK: TButton
      Left = 6
      Top = 332
      Width = 133
      Height = 39
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '&OK'
      Default = True
      TabOrder = 2
      OnClick = BOKClick
    end
    object LCategory: TListBox
      Left = 6
      Top = 31
      Width = 170
      Height = 139
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      ItemHeight = 20
      Items.Strings = (
        'Database fields'
        'Functions'
        'Variables'
        'Constants'
        'Operators')
      TabOrder = 3
      OnClick = LCategoryClick
    end
  end
  object PAlClient: TPanel
    Left = 0
    Top = 0
    Width = 733
    Height = 175
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitWidth = 1083
    ExplicitHeight = 306
    object MemoExpre: TMemo
      Left = 0
      Top = 0
      Width = 733
      Height = 124
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alClient
      Lines.Strings = (
        'MemoExpre')
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
      ExplicitWidth = 804
      ExplicitHeight = 154
    end
    object Panel1: TPanel
      Left = 0
      Top = 124
      Width = 733
      Height = 51
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alBottom
      TabOrder = 1
      ExplicitTop = 255
      ExplicitWidth = 1083
      object BShowResult: TButton
        Left = 488
        Top = 6
        Width = 232
        Height = 39
        Hint = 'Evaluates the expresion and shows the result'
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Show Result'
        TabOrder = 0
        OnClick = BShowResultClick
      end
      object BCheckSyn: TButton
        Left = 231
        Top = 6
        Width = 227
        Height = 39
        Hint = 'Syntax check the expresion'
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Syntax check'
        TabOrder = 1
        OnClick = BCheckSynClick
      end
      object BAdd: TButton
        Left = 6
        Top = 6
        Width = 202
        Height = 39
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Add selection'
        TabOrder = 2
        OnClick = BitBtn1Click
      end
    end
  end
end
