object FRpChatFrame: TFRpChatFrame
  Left = 0
  Top = 0
  Width = 400
  Height = 698
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  TabOrder = 0
  PixelsPerInch = 120
  object PRoot: TPanel
    Left = 0
    Top = 0
    Width = 400
    Height = 698
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object PTop: TPanel
      Left = 0
      Top = 0
      Width = 400
      Height = 166
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object GridTop: TGridPanel
        Left = 0
        Top = 0
        Width = 400
        Height = 166
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Align = alClient
        BevelOuter = bvNone
        ColumnCollection = <
          item
            Value = 100.000000000000000000
          end>
        ControlCollection = <
          item
            Column = 0
            Control = PLoginHost
            Row = 0
          end
          item
            Column = 0
            Control = PAISelectionHost
            Row = 1
          end
          item
            Column = 0
            Control = PSchemaHost
            Row = 2
          end>
        ParentBackground = False
        RowCollection = <
          item
            SizeStyle = ssAuto
            Value = 40.000000000000000000
          end
          item
            SizeStyle = ssAuto
            Value = 63.000000000000000000
          end
          item
            SizeStyle = ssAuto
            Value = 30.000000000000000000
          end>
        TabOrder = 0
        object PLoginHost: TPanel
          AlignWithMargins = True
          Left = 0
          Top = 0
          Width = 400
          Height = 50
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 0
        end
        object PAISelectionHost: TPanel
          AlignWithMargins = True
          Left = 0
          Top = 50
          Width = 400
          Height = 79
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
        end
        object PSchemaHost: TPanel
          AlignWithMargins = True
          Left = 0
          Top = 129
          Width = 400
          Height = 37
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 2
          object LSchema: TLabel
            Left = 0
            Top = 0
            Width = 52
            Height = 20
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Align = alLeft
            Caption = 'Schema'
            Layout = tlCenter
          end
          object ComboSchema: TComboBox
            AlignWithMargins = True
            Left = 60
            Top = 5
            Width = 220
            Height = 22
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Align = alClient
            Style = csDropDownList
            TabOrder = 0
          end
          object PSchemaConfigHost: TPanel
            AlignWithMargins = True
            Left = 285
            Top = 5
            Width = 35
            Height = 27
            Margins.Left = 0
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Align = alRight
            BevelOuter = bvNone
            TabOrder = 1
            ExplicitHeight = 28
          end
          object BRefreshSchemas: TButton
            AlignWithMargins = True
            Left = 325
            Top = 4
            Width = 75
            Height = 29
            Margins.Left = 0
            Margins.Top = 4
            Margins.Right = 0
            Margins.Bottom = 4
            Align = alRight
            Caption = 'Refresh'
            TabOrder = 2
            OnClick = BRefreshSchemasClick
            ExplicitHeight = 30
          end
        end
      end
    end
    object PControl: TPageControl
      Left = 0
      Top = 166
      Width = 400
      Height = 422
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      ActivePage = TabChat
      Align = alClient
      TabOrder = 1
      object TabChat: TTabSheet
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Chat'
        object MemoConversation: TMemo
          Left = 0
          Top = 0
          Width = 390
          Height = 403
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Align = alClient
          ReadOnly = True
          ScrollBars = ssVertical
          TabOrder = 0
        end
      end
      object TabLog: TTabSheet
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Log'
        ImageIndex = 1
        object PLogTop: TPanel
          Left = 0
          Top = 0
          Width = 390
          Height = 41
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Align = alTop
          BevelOuter = bvNone
          Padding.Left = 8
          Padding.Top = 5
          Padding.Right = 8
          Padding.Bottom = 5
          TabOrder = 0
          object BClearLog: TButton
            Left = 8
            Top = 5
            Width = 93
            Height = 31
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Align = alLeft
            Caption = 'Clear'
            TabOrder = 0
            OnClick = BClearLogClick
          end
          object PLogButtonSpacer: TPanel
            Left = 101
            Top = 5
            Width = 10
            Height = 31
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Align = alLeft
            BevelOuter = bvNone
            TabOrder = 1
          end
          object BReportAI: TButton
            Left = 111
            Top = 5
            Width = 138
            Height = 31
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Align = alLeft
            Caption = 'Report content'
            TabOrder = 2
            OnClick = BReportAIClick
          end
        end
        object MemoLog: TMemo
          Left = 0
          Top = 41
          Width = 390
          Height = 362
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Align = alClient
          ReadOnly = True
          ScrollBars = ssBoth
          TabOrder = 1
          WordWrap = False
        end
      end
    end
    object PBottom: TPanel
      Left = 0
      Top = 588
      Width = 400
      Height = 110
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Align = alBottom
      BevelOuter = bvNone
      Padding.Left = 8
      Padding.Top = 8
      Padding.Right = 8
      Padding.Bottom = 8
      TabOrder = 2
      object MemoPrompt: TMemo
        Left = 8
        Top = 8
        Width = 282
        Height = 95
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Align = alClient
        ScrollBars = ssVertical
        TabOrder = 0
        WantReturns = False
        OnChange = MemoPromptChange
      end
      object PButtons: TPanel
        Left = 290
        Top = 8
        Width = 103
        Height = 95
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Align = alRight
        BevelOuter = bvNone
        TabOrder = 1
        object BSend: TButton
          Left = 0
          Top = 0
          Width = 103
          Height = 30
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Align = alTop
          Caption = 'Send'
          TabOrder = 0
          OnClick = BSendClick
        end
        object BApply: TButton
          Left = 0
          Top = 30
          Width = 103
          Height = 30
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Align = alTop
          Caption = 'Apply'
          TabOrder = 1
          OnClick = BApplyClick
        end
        object BClear: TButton
          Left = 0
          Top = 60
          Width = 103
          Height = 30
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Align = alTop
          Caption = 'Clear'
          TabOrder = 2
          OnClick = BClearClick
        end
      end
    end
  end
end
