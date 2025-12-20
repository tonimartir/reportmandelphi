object FRpVCLProgress: TFRpVCLProgress
  Left = 156
  Top = 200
  Width = 619
  Height = 247
  HorzScrollBar.Range = 453
  VertScrollBar.Range = 109
  ActiveControl = BCancel
  Caption = 'Print progress'
  Color = clBtnFace
  ParentFont = True
  Position = poScreenCenter
  Scaled = False
  ShowHint = True
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 120
  DesignSize = (
    601
    200)
  TextHeight = 20
  object LProcessing: TLabel
    Left = 8
    Top = 40
    Width = 465
    Height = 44
    Margins.Left = 2
    Margins.Top = 2
    Margins.Right = 2
    Margins.Bottom = 2
    AutoSize = False
    Caption = 'Processing'
  end
  object LRecordCount: TLabel
    Left = 104
    Top = 40
    Width = 305
    Height = 21
    Margins.Left = 2
    Margins.Top = 2
    Margins.Right = 2
    Margins.Bottom = 2
    AutoSize = False
  end
  object LTitle: TLabel
    Left = 8
    Top = 4
    Width = 472
    Height = 32
    Margins.Left = 2
    Margins.Top = 2
    Margins.Right = 2
    Margins.Bottom = 2
    AutoSize = False
    Caption = 'Tittle'
    Visible = False
  end
  object LTittle: TLabel
    Left = 76
    Top = 4
    Width = 357
    Height = 32
    Margins.Left = 2
    Margins.Top = 2
    Margins.Right = 2
    Margins.Bottom = 2
    AutoSize = False
  end
  object BCancel: TButton
    Left = 187
    Top = 140
    Width = 204
    Height = 39
    Margins.Left = 2
    Margins.Top = 2
    Margins.Right = 2
    Margins.Bottom = 2
    Anchors = [akLeft, akRight, akBottom]
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 0
    OnClick = BCancelClick
  end
  object BOK: TButton
    Left = 7
    Top = 146
    Width = 81
    Height = 26
    Margins.Left = 2
    Margins.Top = 2
    Margins.Right = 2
    Margins.Bottom = 2
    Anchors = [akLeft, akBottom]
    Caption = 'OK'
    Default = True
    TabOrder = 1
    Visible = False
    OnClick = BOKClick
  end
  object GPrintRange: TGroupBox
    Left = 7
    Top = 8
    Width = 466
    Height = 113
    Margins.Left = 2
    Margins.Top = 2
    Margins.Right = 2
    Margins.Bottom = 2
    Caption = 'Print Range'
    TabOrder = 2
    Visible = False
    object LTo: TLabel
      Left = 136
      Top = 85
      Width = 16
      Height = 20
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      Caption = 'To'
    end
    object LFrom: TLabel
      Left = 14
      Top = 84
      Width = 34
      Height = 20
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      Caption = 'From'
    end
    object EFrom: TRpMaskEdit
      Left = 56
      Top = 80
      Width = 53
      Height = 28
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      TabOrder = 0
      Text = ''
    end
    object ETo: TRpMaskEdit
      Left = 180
      Top = 81
      Width = 73
      Height = 28
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      TabOrder = 1
      Text = ''
    end
    object RadioAll: TRadioButton
      Left = 180
      Top = 36
      Width = 341
      Height = 25
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      Caption = 'All pages'
      TabOrder = 2
    end
    object RadioRange: TRadioButton
      Left = 12
      Top = 48
      Width = 213
      Height = 25
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      Caption = 'Range'
      TabOrder = 3
    end
  end
  object GBitmap: TGroupBox
    Left = 7
    Top = 7
    Width = 453
    Height = 121
    Margins.Left = 2
    Margins.Top = 2
    Margins.Right = 2
    Margins.Bottom = 2
    TabOrder = 3
    Visible = False
    object LHorzRes: TLabel
      Left = 13
      Top = 16
      Width = 258
      Height = 20
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      Caption = 'Horizotal resolution in dots per inchess'
    end
    object LVertRes: TLabel
      Left = 12
      Top = 52
      Width = 258
      Height = 20
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      Caption = 'Horizotal resolution in dots per inchess'
    end
    object EHorzRes: TRpMaskEdit
      Left = 364
      Top = 14
      Width = 77
      Height = 28
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      TabOrder = 0
      Text = '100'
      EditType = teinteger
    end
    object EVertRes: TRpMaskEdit
      Left = 364
      Top = 46
      Width = 77
      Height = 28
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      TabOrder = 1
      Text = '100'
      EditType = teinteger
    end
    object CheckMono: TCheckBox
      Left = 12
      Top = 80
      Width = 277
      Height = 17
      Margins.Left = 2
      Margins.Top = 2
      Margins.Right = 2
      Margins.Bottom = 2
      Caption = 'Monocrhome'
      TabOrder = 2
    end
  end
end
