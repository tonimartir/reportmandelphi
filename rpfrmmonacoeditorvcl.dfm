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
          Value = 42.000000000000000000
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
          Control = PSchemaConfigHost
          Row = 0
        end
        item
          Column = 2
          Control = PLoginControl
          Row = 0
        end
        item
          Column = 3
          Control = PAIButtonHost
          Row = 0
        end
        item
          Column = 4
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
      object PSchemaConfigHost: TPanel
        AlignWithMargins = True
        Left = 158
        Top = 8
        Width = 30
        Height = 34
        Margins.Left = 0
        Margins.Top = 8
        Margins.Right = 8
        Margins.Bottom = 8
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 2
        ExplicitLeft = 166
      end
      object PLoginControl: TPanel
        AlignWithMargins = True
        Left = 204
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
        ExplicitLeft = 212
      end
      object PAIButtonHost: TPanel
        AlignWithMargins = True
        Left = 420
        Top = 8
        Width = 52
        Height = 34
        Margins.Left = 8
        Margins.Top = 8
        Margins.Right = 8
        Margins.Bottom = 8
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 3
        ExplicitLeft = 428
      end
      object PAISelectionHost: TPanel
        AlignWithMargins = True
        Left = 488
        Top = 0
        Width = 262
        Height = 50
        Margins.Left = 8
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 4
        ExplicitLeft = 496
        ExplicitWidth = 254
      end
    end
  end
  object PControl: TPageControl
    Left = 0
    Top = 50
    Width = 750
    Height = 450
    ActivePage = TabSQL
    Align = alClient
    TabOrder = 1
    object TabSQL: TTabSheet
      Caption = 'Editor SQL'
      object Edge: TEdgeBrowser
        Left = 0
        Top = 0
        Width = 742
        Height = 422
        Align = alClient
        TabOrder = 0
        OnCreateWebViewCompleted = EdgeCreateWebViewCompleted
      end
    end
    object TabLog: TTabSheet
      Caption = 'Log'
      ImageIndex = 1
      object PLogTop: TPanel
        Left = 0
        Top = 0
        Width = 742
        Height = 33
        Align = alTop
        BevelOuter = bvNone
        Padding.Left = 6
        Padding.Top = 4
        Padding.Right = 6
        Padding.Bottom = 4
        TabOrder = 0
        object BClearLog: TButton
          Left = 6
          Top = 4
          Width = 75
          Height = 25
          Align = alLeft
          Caption = 'Clear'
          TabOrder = 0
          OnClick = BClearLogClick
        end
      end
      object MemoLog: TMemo
        Left = 0
        Top = 33
        Width = 742
        Height = 389
        Align = alClient
        ReadOnly = True
        ScrollBars = ssBoth
        TabOrder = 1
        WordWrap = False
      end
    end
  end
end
