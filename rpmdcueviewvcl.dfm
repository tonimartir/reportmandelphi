object FRpCueViewVCL: TFRpCueViewVCL
  Left = 0
  Top = 0
  Width = 350
  Height = 500
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  TabOrder = 0
  PixelsPerInch = 120
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 350
    Height = 38
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object BUndo: TSpeedButton
      Left = 0
      Top = 0
      Width = 35
      Height = 35
      Hint = 'Deshacer (Ctrl+Z)'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Flat = True
      ParentShowHint = False
      ShowHint = True
      OnClick = BUndoClick
    end
    object BRedo: TSpeedButton
      Left = 35
      Top = 0
      Width = 35
      Height = 35
      Hint = 'Rehacer (Ctrl+Y)'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Flat = True
      ParentShowHint = False
      ShowHint = True
      OnClick = BRedoClick
    end
    object BClear: TSpeedButton
      Left = 70
      Top = 0
      Width = 35
      Height = 35
      Hint = 'Limpiar cola'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Flat = True
      ParentShowHint = False
      ShowHint = True
      OnClick = BClearClick
    end
    object LTitle: TLabel
      Left = 113
      Top = 9
      Width = 93
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Cola deshacer'
    end
  end
  object ListViewCue: TListView
    Left = 0
    Top = 38
    Width = 350
    Height = 462
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alClient
    Columns = <
      item
        Caption = 'Op'
        Width = 38
      end
      item
        Caption = 'Componente'
        Width = 150
      end
      item
        Caption = 'Clase'
        Width = 100
      end
      item
        Caption = 'Fecha'
        Width = 138
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnDblClick = ListViewCueDblClick
  end
end
