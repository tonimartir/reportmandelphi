object PreviewControl: TPreviewControl
  Left = 244
  Top = 140
  Width = 870
  Height = 600
  Caption = 'PreviewControl'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -14
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OnCreate = ActiveFormCreate
  OnDestroy = ActiveFormDestroy
  PixelsPerInch = 120
  TextHeight = 16
  object PControl: TRpPreviewControl
    Left = 0
    Top = 0
    Width = 870
    Height = 600
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    HorzScrollBar.Tracking = True
    VertScrollBar.Tracking = True
    Align = alClient
    BorderStyle = bsNone
    Color = clAppWorkSpace
    ParentColor = False
    TabOrder = 0
    EntirePageCount = 1
    EntireTopDown = False
    AutoScale = AScaleReal
  end
end
