object FRpMonacoEditorVCL: TFRpMonacoEditorVCL
  Left = 0
  Top = 0
  Width = 750
  Height = 500
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  TabOrder = 0
  PixelsPerInch = 120
  object PTop: TPanel
    Left = 0
    Top = 0
    Width = 750
    Height = 50
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object GridTopHeader: TGridPanel
      Left = 0
      Top = 0
      Width = 750
      Height = 50
      Align = alClient
      BevelOuter = bvNone
      ColumnCollection = <
        item
          SizeStyle = ssAuto
          Value = 150.000000000000000000
        end
        item
          SizeStyle = ssAuto
          Value = 200.000000000000000000
        end
        item
          SizeStyle = ssAuto
          Value = 52.000000000000000000
        end
        item
          Value = 100.000000000000000000
        end>
      ControlCollection = <
        item
          Column = 0
          Control = ComboSchema
          Row = 0
        end
        item
          Column = 1
          Control = PLoginControl
          Row = 0
        end
        item
          Column = 2
          Control = PAIButtonHost
          Row = 0
        end
        item
          Column = 3
          Control = PAISelectionHost
          Row = 0
        end>
      ParentBackground = False
      RowCollection = <
        item
          Value = 100.000000000000000000
        end>
      TabOrder = 0
      object ComboSchema: TComboBox
        AlignWithMargins = True
        Left = 8
        Top = 11
        Width = 142
        Height = 28
        Margins.Left = 8
        Margins.Top = 11
        Margins.Right = 8
        Margins.Bottom = 11
        Align = alClient
        Style = csDropDownList
        TabOrder = 0
      end
      object PLoginControl: TPanel
        AlignWithMargins = True
        Left = 166
        Top = 5
        Width = 200
        Height = 40
        Margins.Left = 8
        Margins.Top = 5
        Margins.Right = 8
        Margins.Bottom = 5
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
      end
      object PAIButtonHost: TPanel
        AlignWithMargins = True
        Left = 382
        Top = 8
        Width = 52
        Height = 34
        Margins.Left = 8
        Margins.Top = 8
        Margins.Right = 8
        Margins.Bottom = 8
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 2
      end
      object PAISelectionHost: TPanel
        AlignWithMargins = True
        Left = 450
        Top = 0
        Width = 300
        Height = 50
        Margins.Left = 8
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 3
      end
    end
  end
  object Edge: TEdgeBrowser
    Left = 0
    Top = 50
    Width = 750
    Height = 450
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alClient
    TabOrder = 1
    OnCreateWebViewCompleted = EdgeCreateWebViewCompleted
  end
end
