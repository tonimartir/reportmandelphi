object FRpEmbeddedFile: TFRpEmbeddedFile
  Left = 0
  Top = 0
  Caption = 'FRpEmbeddedFile'
  ClientHeight = 382
  ClientWidth = 765
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -15
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  PixelsPerInch = 120
  DesignSize = (
    765
    382)
  TextHeight = 20
  object labelDescription: TLabel
    Left = 20
    Top = 24
    Width = 76
    Height = 20
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Description'
  end
  object labelFilename: TLabel
    Left = 20
    Top = 72
    Width = 67
    Height = 20
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'File Name'
  end
  object labelRelationShip: TLabel
    Left = 20
    Top = 168
    Width = 82
    Height = 20
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'Relationship'
  end
  object labelMimeType: TLabel
    Left = 19
    Top = 120
    Width = 71
    Height = 20
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'Mime type'
  end
  object labelCreationDate: TLabel
    Left = 20
    Top = 216
    Width = 165
    Height = 20
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'Creation Date (ISO 8601)'
  end
  object labelModificationDate: TLabel
    Left = 20
    Top = 272
    Width = 196
    Height = 20
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'Modificacion Date (ISO 8601)'
  end
  object textDescription: TEdit
    Left = 248
    Top = 20
    Width = 497
    Height = 28
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
  end
  object textFilename: TEdit
    Left = 248
    Top = 69
    Width = 497
    Height = 28
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 1
  end
  object bok: TButton
    Left = 20
    Top = 336
    Width = 157
    Height = 37
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Anchors = [akLeft, akBottom]
    Caption = 'Ok'
    Default = True
    ModalResult = 1
    TabOrder = 6
    ExplicitTop = 315
  end
  object BCancel: TButton
    Left = 580
    Top = 328
    Width = 165
    Height = 37
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Anchors = [akRight, akBottom]
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 7
  end
  object ComboRelationShip: TComboBox
    Left = 248
    Top = 165
    Width = 497
    Height = 28
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Style = csDropDownList
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 3
  end
  object ComboMimeType: TComboBox
    Left = 248
    Top = 117
    Width = 497
    Height = 28
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 2
  end
  object textCreationDate: TEdit
    Left = 248
    Top = 213
    Width = 497
    Height = 28
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 4
  end
  object textModificationDate: TEdit
    Left = 248
    Top = 269
    Width = 497
    Height = 28
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 5
  end
end
