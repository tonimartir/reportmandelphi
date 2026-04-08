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
    Height = 63
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
      Height = 63
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
      object PAIButtonHost: TPanel
        AlignWithMargins = True
        Left = 204
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
        ExplicitLeft = 212
      end
      object PAISelectionHost: TPanel
        AlignWithMargins = True
        Left = 272
        Top = 0
        Width = 478
        Height = 63
        Margins.Left = 8
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 4
        ExplicitLeft = 280
        ExplicitWidth = 470
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
    object TabAudit: TTabSheet
      Caption = 'Audit'
      ImageIndex = 1
      object PAuditTop: TPanel
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
        object BAuditSQL: TButton
          Left = 6
          Top = 4
          Width = 90
          Height = 25
          Align = alLeft
          Caption = 'Audit SQL'
          TabOrder = 0
          OnClick = BAuditSQLClick
        end
      end
      object MemoAudit: TMemo
        Left = 0
        Top = 33
        Width = 742
        Height = 389
        Align = alClient
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 1
        WordWrap = True
      end
    end
  end
end
