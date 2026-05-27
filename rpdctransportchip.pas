// =====================================================================
//   Report Manager - rpdctransportchip
//
//   Small VCL helper that paints a TPanel as a colored "transport
//   chip" - the visual indicator used by the Designer to surface
//   the live Direct Channel state in dialogs (Sample Data, Test
//   Connection, KPI grid). Mirrors the WebRtcStatusChip pattern
//   used in Reportman.Web (Angular) so users get the same color
//   semantics across platforms:
//
//     green   = Direct P2P (host candidates, LAN)
//     teal    = Hole-Punch (NAT/STUN, srflx/prflx)
//     orange  = Relay (TURN)
//     gray    = API HTTP fallback (no DC for this query)
//     pale    = Unknown / not negotiated yet
//
//   Windows-only: declared inside {$IFDEF MSWINDOWS} so cross-
//   platform tools (printreptopdf) skip it.
//
//   Copyright (c) 2026 Toni Martir
//   toni@reportman.es
// =====================================================================

unit rpdctransportchip;

interface

{$I rpconf.inc}

{$IFDEF MSWINDOWS}

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.ExtCtrls,
  rpdatadirect,        // TRpDcConnectionMode
  rpdcintegration;     // FormatTransportMode

// Paint AChip according to AMode + AFallbackApi. Sets Caption,
// Color, Font.Color and a slight border. The panel must have been
// created already (typically inside the host form's FormCreate).
// Suggested panel size: 22 px high, ~160 px wide.
procedure ApplyTransportChip(AChip: TPanel;
                             AMode: TRpDcConnectionMode;
                             AFallbackApi: Boolean);

// Convenience overload that takes a hubDatabaseId, looks up both
// the mode and the fallback flag from rpdcintegration, and applies.
procedure ApplyTransportChipForDatabase(AChip: TPanel;
                                         HubDatabaseId: Int64);

{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

procedure ApplyTransportChip(AChip: TPanel;
                             AMode: TRpDcConnectionMode;
                             AFallbackApi: Boolean);
const
  // Bevel-less inset look: dark border, lighter fill, white text.
  ClrDirectFill  = $00A5D684;  // soft green BGR
  ClrDirectText  = $0023501C;
  ClrHoleFill    = $00BDB76B;  // teal BGR
  ClrHoleText    = $00203C40;
  ClrRelayFill   = $001F8DEB;  // amber/orange BGR
  ClrRelayText   = $00FFFFFF;
  ClrApiFill     = $00BDBDBD;  // neutral gray BGR
  ClrApiText     = $00404040;
  ClrUnknownFill = $00E0E0E0;  // very pale
  ClrUnknownText = $00808080;
var
  fillColor, textColor: TColor;
begin
  if AChip = nil then Exit;

  if AFallbackApi then
  begin
    fillColor := ClrApiFill;
    textColor := ClrApiText;
  end
  else case AMode of
    rcmDirectP2P: begin fillColor := ClrDirectFill;  textColor := ClrDirectText;  end;
    rcmHolePunch: begin fillColor := ClrHoleFill;    textColor := ClrHoleText;    end;
    rcmRelay:     begin fillColor := ClrRelayFill;   textColor := ClrRelayText;   end;
  else            fillColor := ClrUnknownFill; textColor := ClrUnknownText;
  end;

  AChip.BevelOuter        := bvNone;
  AChip.BorderStyle       := bsNone;
  AChip.ParentBackground  := False;
  AChip.Color             := TColor(fillColor);
  AChip.Font.Color        := TColor(textColor);
  AChip.Font.Style        := [fsBold];
  AChip.Font.Size         := 8;
  AChip.Caption           := FormatTransportMode(AMode, AFallbackApi);
  AChip.Hint              := AChip.Caption;
  AChip.ShowHint          := True;
end;

procedure ApplyTransportChipForDatabase(AChip: TPanel;
                                         HubDatabaseId: Int64);
begin
  ApplyTransportChip(AChip,
                     GetLastTransportForDatabase(HubDatabaseId),
                     DidFallBackToApiForDatabase(HubDatabaseId));
end;

{$ENDIF}

end.
