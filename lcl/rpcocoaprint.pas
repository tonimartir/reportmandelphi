{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpcocoaprint                                    }
{       Printing with LCL Cocoa (macOS): the page       }
{       margins Printer4Lazarus leaves undefined        }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

{ Printer4Lazarus with Cocoa (Lazarus 4.8) draws the document into a PDF of
  the size of the printable area (PaperRect.WorkRect) and, in Printer.EndDoc,
  prints it through NSPrintOperation with NSPrintInfo.sharedPrintInfo. It
  never sets the margins of that print info, and they can be garbage: a top
  margin of 13430255616 points was seen on macOS 11, so AppKit placed the
  page far outside the paper and the printer received a blank sheet. That
  happened with every printer, and with a plain LCL program as well.

  RpPrepareCocoaPrinting, called right before Printer.EndDoc, sets the
  margins to the ones of the printable area and turns off the centering, so
  the origin of Printer.Canvas is the corner of the printable area, as on
  Windows and Linux. Elsewhere (and with other widgetsets) it does nothing. }

unit rpcocoaprint;

{$mode objfpc}{$H+}
{$IF DEFINED(DARWIN) AND DEFINED(LCLCOCOA)}
{$modeswitch objectivec1}
{$IFEND}

interface

// Before Printer.EndDoc: the margins of the page in the print info of macOS
procedure RpPrepareCocoaPrinting;

implementation

{$IF DEFINED(DARWIN) AND DEFINED(LCLCOCOA)}
uses
  SysUtils, Printers, CocoaAll;

procedure RpPrepareCocoaPrinting;
var
  info: NSPrintInfo;
  pr: TPaperRect;
  kx, ky: Double;
begin
  if (Printer = nil) or (Printer.XDPI <= 0) or (Printer.YDPI <= 0) then
    Exit;
  try
    pr := Printer.PaperSize.PaperRect;
  except
    // No paper information: AppKit keeps its own margins
    Exit;
  end;
  if (pr.WorkRect.Right <= pr.WorkRect.Left) or (pr.WorkRect.Bottom <= pr.WorkRect.Top) then
    Exit;
  // PaperRect is in printer dots (XDPI, YDPI), NSPrintInfo in points
  kx := 72 / Printer.XDPI;
  ky := 72 / Printer.YDPI;
  info := NSPrintInfo.sharedPrintInfo;
  info.setLeftMargin(pr.WorkRect.Left * kx);
  info.setTopMargin(pr.WorkRect.Top * ky);
  info.setRightMargin((pr.PhysicalRect.Right - pr.WorkRect.Right) * kx);
  info.setBottomMargin((pr.PhysicalRect.Bottom - pr.WorkRect.Bottom) * ky);
  info.setHorizontallyCentered(False);
  info.setVerticallyCentered(False);
end;
{$ELSE}
procedure RpPrepareCocoaPrinting;
begin
end;
{$IFEND}

end.
