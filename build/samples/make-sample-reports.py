#!/usr/bin/env python3
"""Writes the sample reports of Report Manager (the .rep files of samples/).

The samples are shared by every designer: the Delphi VCL designer, the
Lazarus designer (Windows, Linux, macOS), the .NET designer and the web
designer. So they are written in the XML format, the only one the three
engines read, exactly as rpxmlstream.pas writes it (same properties, same
order, same encoding of the values).

Every report reads samples.db, the SQLite database next to it (see
make-samples-db.py), through one connection, SAMPLES, stored in the report
itself: driver FireDAC and three hidden parameters (DBPARAM_DRIVERNAME,
DBPARAM_DRIVERID and DBPARAM_DATABASE) instead of an entry of
dbxconnections.ini. The Delphi engine opens it with FireDAC, the Free Pascal
engine with SQLdb and the .NET engine with Microsoft.Data.Sqlite; the three
look for the relative database name in the folder of the report.

    python make-sample-reports.py <samples folder>
"""
import os
import sys

# ---------------------------------------------------------------------------
# Units and colours
# ---------------------------------------------------------------------------
# Report Manager measures in twips (1440 per inch, 567 per centimetre) and
# stores colours as Windows COLORREF values (0x00BBGGRR).


def rgb(r, g, b):
    return r + g * 256 + b * 65536


WHITE = rgb(255, 255, 255)
BLACK = rgb(0, 0, 0)
DARK = rgb(0x1F, 0x4E, 0x79)      # header bands, titles
ACCENT = rgb(0x2E, 0x75, 0xB6)    # rules under group titles
LIGHT = rgb(0xEE, 0xF3, 0xF8)     # boxes, group bands
GRAY = rgb(0x59, 0x59, 0x59)      # secondary text
MIDGRAY = rgb(0x8C, 0x8C, 0x8C)
LINE = rgb(0xBF, 0xBF, 0xBF)      # page footer rule
ROWLINE = rgb(0xE3, 0xE3, 0xE3)   # separators between detail rows
RED = rgb(0xC0, 0x00, 0x00)

BOLD, ITALIC = 1, 2
LEFT, RIGHT, CENTER = 0, 2, 4
VCENTER = 32

# A4 portrait with the default margins of the engine
PAGE_W, PAGE_H = 11906, 16837
MARGIN_L, MARGIN_T, MARGIN_R, MARGIN_B = 574, 574, 574, 861
WIDTH = PAGE_W - MARGIN_L - MARGIN_R           # printable width: 10758

COMPANY = 'Mare Nostrum Fine Foods'
FOOTER_TEXT = 'Report Manager sample report · data: samples.db (SQLite)'

# Enumerations, as integers (rptypes.pas, rpsection.pas, rpmdcharttypes.pas)
SEC_PHEADER, SEC_GHEADER, SEC_DETAIL, SEC_GFOOTER, SEC_PFOOTER = range(5)
AG_NONE, AG_GROUP, AG_PAGE, AG_GENERAL = range(4)
AGT_SUM, AGT_MIN, AGT_MAX = range(3)
SHAPE_RECT, SHAPE_ROUNDRECT, SHAPE_HLINE = 0, 2, 6
BRUSH_SOLID, BRUSH_CLEAR = 0, 1
PEN_SOLID, PEN_DOT, PEN_CLEAR = 0, 2, 5
PARAM_STRING, PARAM_INTEGER, PARAM_DATE = 0, 1, 3
PARAM_UNKNOWN = 16
CHART_BAR, CHART_HORZBAR, CHART_PIE = 1, 3, 5
BARCODE_EAN13 = 15
DRAW_FULL = 2
DRIVER_FIREDAC = 9

CONNECTION = 'SAMPLES'

# ---------------------------------------------------------------------------
# XML writer (rpxmlstream.pas)
# ---------------------------------------------------------------------------
CRLF = '\r\n'
MAXDATAWIDTH = 40
ALPHA = set('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_ .()=;:')


def rp_string(value):
    """StringToRpString / WStringToRpString: everything but letters, digits
    and a few signs is written as #<code>#, with a line break every 40
    characters or so."""
    out = []
    alen = 0
    for ch in value:
        if ch in ALPHA:
            piece = ch
        else:
            code = ord(ch)
            if code > 0xFFFF:
                raise ValueError('Only characters of the BMP: %r' % ch)
            piece = '#%d#' % code
        out.append(piece)
        alen += len(piece)
        if alen > MAXDATAWIDTH:
            out.append(CRLF)
            alen = 0
    return ''.join(out)


class XmlOut:
    def __init__(self):
        self.parts = []

    def raw(self, text):
        self.parts.append(text + CRLF)

    def i(self, name, value):
        self.raw('<%s type="Integer">%d</%s>' % (name, value, name))

    def d(self, name, value):
        text = repr(float(value))
        if text.endswith('.0'):
            text = text[:-2]
        self.raw('<%s type="Double">%s</%s>' % (name, text, name))

    def b(self, name, value):
        self.raw('<%s type="Boolean">%s</%s>' % (name, 'True' if value else 'False', name))

    def s(self, name, value):
        if any(ord(c) > 127 for c in value):
            raise ValueError('%s is an AnsiString property: ASCII only (%r)' % (name, value))
        self.raw('<%s type="String">%s</%s>' % (name, rp_string(value), name))

    def w(self, name, value):
        self.raw('<%s type="WideString">%s</%s>' % (name, rp_string(value), name))

    def text(self):
        return ''.join(self.parts)


def lines(*items):
    """TStrings.Text: every line ends with CRLF."""
    return ''.join(item + CRLF for item in items)


# ---------------------------------------------------------------------------
# Report model
# ---------------------------------------------------------------------------
class Component:
    kind = None

    def __init__(self, x, y, w, h, **props):
        self.x, self.y, self.w, self.h = x, y, w, h
        self.props = props
        self.name = None

    def get(self, key, default):
        return self.props.get(key, default)

    def write_common(self, out, classname):
        out.raw('<COMPONENT>')
        out.s('NAME', self.name)
        out.s('CLASSNAME', classname)
        out.i('WIDTH', self.w)
        out.i('HEIGHT', self.h)
        out.w('PRINTCONDITION', self.get('condition', ''))
        out.w('DOBEFOREPRINT', '')
        out.w('DOAFTERPRINT', '')
        out.s('ANNOTATION', '')
        out.i('POSX', self.x)
        out.i('POSY', self.y)
        out.i('ALIGN', self.get('align_pos', 0))

    def write_text_props(self, out):
        out.w('WFONTNAME', self.get('font', 'Arial'))
        out.w('LFONTNAME', self.get('lfont', 'Helvetica'))
        out.i('BIDIMODE', self.get('bidi', 0))
        out.i('TYPE1FONT', self.get('type1', 0))
        out.i('FONTSIZE', self.get('size', 9))
        out.i('FONTROTATION', 0)
        out.i('FONTSTYLE', self.get('style', 0))
        out.i('FONTCOLOR', self.get('color', BLACK))
        back = self.get('back', None)
        out.i('BACKCOLOR', WHITE if back is None else back)
        out.b('TRANSPARENT', back is None)
        out.b('CUTTEXT', self.get('cut', False))
        out.i('ALIGNMENT', self.get('alignment', LEFT))
        out.i('VALIGNMENT', self.get('valignment', 0))
        out.i('INTERLINE', 0)
        out.b('WORDWRAP', self.get('wordwrap', False))
        out.b('WORDBREAK', False)
        out.b('SINGLELINE', False)
        out.b('MULTIPAGE', self.get('multipage', False))
        out.i('PRINTSTEP', 0)
        if self.get('html', False):
            out.b('ISHTML', True)


class Label(Component):
    def write(self, out):
        self.write_common(out, 'TRPLABEL')
        self.write_text_props(out)
        out.w('WIDETEXT', self.get('text', ''))
        out.raw('</COMPONENT>')


class Expression(Component):
    def write(self, out):
        self.write_common(out, 'TRPEXPRESSION')
        self.write_text_props(out)
        out.w('EXPRESSION', self.get('expr', ''))
        out.w('AGINIVALUE', '0')
        out.w('EXPORTEXPRESSION', '')
        out.i('DATATYPE', PARAM_UNKNOWN)
        out.w('DISPLAYFORMAT', self.get('fmt', ''))
        out.s('IDENTIFIER', self.get('identifier', ''))
        out.i('AGGREGATE', self.get('aggregate', AG_NONE))
        out.s('GROUPNAME', self.get('group', ''))
        out.i('AGTYPE', self.get('agtype', AGT_SUM))
        out.b('AUTOEXPAND', self.get('autoexpand', False))
        out.b('AUTOCONTRACT', self.get('autocontract', False))
        out.b('PRINTONLYONE', False)
        out.b('PRINTNULLS', True)
        out.w('EXPORTDISPLAYFORMAT', '')
        out.i('EXPORTLINE', 0)
        out.i('EXPORTPOSITION', 0)
        out.i('EXPORTSIZE', 1)
        out.b('EXPORTDONEWLINE', False)
        out.raw('</COMPONENT>')


class Shape(Component):
    def write(self, out):
        self.write_common(out, 'TRPSHAPE')
        fill = self.get('fill', None)
        pen = self.get('pen', fill if fill is not None else BLACK)
        out.i('SHAPE', self.get('shape', SHAPE_RECT))
        out.i('BRUSHSTYLE', BRUSH_CLEAR if fill is None else BRUSH_SOLID)
        out.i('BRUSHCOLOR', WHITE if fill is None else fill)
        out.i('PENSTYLE', self.get('penstyle', PEN_SOLID))
        out.i('PENCOLOR', pen)
        out.i('PENWIDTH', self.get('penwidth', 0))
        out.raw('</COMPONENT>')


class Image(Component):
    def write(self, out):
        self.write_common(out, 'TRPIMAGE')
        out.w('EXPRESSION', self.get('expr', ''))
        out.i('ROTATION', 0)
        out.i('DRAWSTYLE', self.get('drawstyle', DRAW_FULL))
        out.i('DPIRES', 100)
        out.i('COPYMODE', 10)
        out.i('CACHEDIMAGE', 0)
        out.raw('</COMPONENT>')


class Barcode(Component):
    def write(self, out):
        self.write_common(out, 'TRPBARCODE')
        out.w('EXPRESSION', self.get('expr', ''))
        out.i('MODUL', self.get('modul', 15))
        out.d('RATIO', 2.0)
        out.i('TYP', self.get('typ', BARCODE_EAN13))
        out.b('CHECKSUM', False)
        out.w('DISPLAYFORMAT', '')
        out.i('ROTATION', 0)
        out.i('BCOLOR', BLACK)
        out.i('BACKCOLOR', WHITE)
        out.b('TRANSPARENT', True)
        out.i('NUMCOLUMNS', 0)
        out.i('NUMROWS', 0)
        out.i('ECCLEVEL', -1)
        out.b('TRUNCATED', False)
        out.raw('</COMPONENT>')


class Chart(Component):
    def write(self, out):
        self.write_common(out, 'TRPCHART')
        self.write_text_props(out)
        out.w('VALUEEXPRESSION', self.get('value', ''))
        out.w('VALUEXEXPRESSION', '')
        out.w('GETVALUECONDITION', '')
        out.w('CHANGESERIEEXPRESSION', self.get('changeserie', ''))
        out.w('CAPTIONEXPRESSION', self.get('caption', ''))
        out.w('COLOREXPRESSION', self.get('colorexpr', ''))
        out.w('SERIECOLOREXPRESSION', '')
        out.w('SERIECAPTION', self.get('seriecaption', ''))
        out.w('CLEAREXPRESSION', '')
        out.b('CHANGESERIEBOOL', self.get('changeseriebool', False))
        out.i('CHARTTYPE', self.get('charttype', CHART_BAR))
        out.w('IDENTIFIER', '')
        out.b('CLEAREXPRESSIONBOOL', False)
        out.i('DRIVER', 0)
        out.b('VIEW3D', self.get('view3d', False))
        out.b('VIEW3DWALLS', False)
        out.i('PERSPECTIVE', 15)
        out.i('ELEVATION', 345)
        out.i('ROTATION', 345)
        out.i('ZOOM', 100)
        out.i('HORZOFFSET', 0)
        out.i('VERTOFFSET', 0)
        out.i('TILT', 0)
        out.b('ORTHOGONAL', True)
        out.i('MULTIBAR', 1)
        out.i('RESOLUTION', self.get('resolution', 200))
        out.b('SHOWLEGEND', self.get('legend', False))
        out.b('SHOWHINT', True)
        out.i('MARKSTYLE', 0)
        out.i('HORZFONTSIZE', self.get('hfont', 8))
        out.i('VERTFONTSIZE', self.get('vfont', 8))
        out.i('HORZFONTROTATION', self.get('hrotation', 0))
        out.i('VERTFONTROTATION', 0)
        out.i('AUTORANGE', 0)
        out.d('YMIN', 0)
        out.d('YMAX', 0)
        out.raw('</COMPONENT>')


class Section:
    def __init__(self, report, kind, height, group='', change='', **props):
        self.report = report
        self.kind = kind
        self.height = height
        self.group = group
        self.change = change
        self.props = props
        self.items = []
        self.name = None

    def add(self, comp):
        prefix = {'Label': 'TRpLabel', 'Expression': 'TRpExpression', 'Shape': 'TRpShape',
                  'Image': 'TRpImage', 'Barcode': 'TRpBarcode', 'Chart': 'TRpChart'}
        comp.name = self.report.next_name(prefix[type(comp).__name__])
        self.items.append(comp)
        return comp

    # shortcuts
    def label(self, x, y, w, h, text, **p):
        return self.add(Label(x, y, w, h, text=text, **p))

    def expr(self, x, y, w, h, expr, **p):
        return self.add(Expression(x, y, w, h, expr=expr, **p))

    def rect(self, x, y, w, h, fill=None, **p):
        return self.add(Shape(x, y, w, h, fill=fill, **p))

    def write(self, out, subreport_name):
        get = self.props.get
        out.raw('<SECTION>')
        out.s('NAME', self.name)
        out.i('WIDTH', get('width', WIDTH))
        out.i('HEIGHT', self.height)
        out.w('PRINTCONDITION', get('condition', ''))
        out.w('DOBEFOREPRINT', '')
        out.w('DOAFTERPRINT', '')
        out.s('SUBREPORT', subreport_name)
        out.s('GROUPNAME', self.group)
        out.w('CHANGEEXPRESSION', self.change)
        out.w('BEGINPAGEEXPRESSION', get('beginpage', ''))
        out.w('SKIPEXPREV', '')
        out.w('SKIPEXPREH', '')
        out.w('SKIPTOPAGEEXPRE', '')
        out.w('BACKEXPRESSION', '')
        out.b('CHANGEBOOL', False)
        out.b('PAGEREPEAT', get('pagerepeat', False))
        out.b('FORCEPRINT', get('forceprint', False))
        out.b('SKIPPAGE', get('skippage', False))
        out.b('ALIGNBOTTOM', False)
        out.i('SECTIONTYPE', self.kind)
        out.b('AUTOEXPAND', get('autoexpand', False))
        out.b('AUTOCONTRACT', get('autocontract', False))
        out.b('HORZDESP', get('horzdesp', False))
        out.b('VERTDESP', False)
        out.s('EXTERNALFILENAME', '')
        out.s('EXTERNALCONNECTION', '')
        out.s('EXTERNALTABLE', 'REPMAN_REPORTS')
        out.s('EXTERNALFIELD', 'REPORT')
        out.s('EXTERNALSEARCHFIELD', 'REPORT_NAME')
        out.s('EXTERNALSEARCHVALUE', '')
        out.i('STREAMFORMAT', 1)
        out.b('SKIPRELATIVEH', False)
        out.b('SKIPRELATIVEV', False)
        out.i('SKIPTYPE', 0)
        out.b('ININUMPAGE', False)
        out.b('GLOBAL', False)
        out.i('DPIRES', 100)
        out.i('CACHEDIMAGE', 0)
        out.i('BACKSTYLE', 0)
        out.i('DRAWSTYLE', DRAW_FULL)
        for item in self.items:
            item.write(out)
        out.raw('</SECTION>')


class SubReport:
    def __init__(self, report, alias):
        self.report = report
        self.alias = alias
        self.name = report.next_name('TRpSubReport')
        self.pheader = []
        self.gheaders = []   # outermost first
        self.details = []
        self.gfooters = []   # innermost first
        self.pfooter = []

    def section(self, kind, height, **p):
        sec = Section(self.report, kind, height, **p)
        sec.name = self.report.next_name('TRpSection')
        {SEC_PHEADER: self.pheader, SEC_DETAIL: self.details, SEC_PFOOTER: self.pfooter}[kind].append(sec)
        return sec

    def group(self, name, change, header_height, footer_height, header=None, footer=None):
        """A group: header and footer sections with the same GROUPNAME. Call it
        from the outermost group to the innermost one."""
        hsec = Section(self.report, SEC_GHEADER, header_height, group=name, change=change,
                       **(header or {}))
        hsec.name = self.report.next_name('TRpSection')
        fsec = Section(self.report, SEC_GFOOTER, footer_height, group=name, change=change,
                       **(footer or {}))
        fsec.name = self.report.next_name('TRpSection')
        self.gheaders.append(hsec)
        self.gfooters.insert(0, fsec)
        return hsec, fsec

    def sections(self):
        return self.pheader + self.gheaders + self.details + self.gfooters + self.pfooter

    def write(self, out):
        out.raw('<SUBREPORT>')
        out.s('NAME', self.name)
        out.s('ALIAS', self.alias)
        out.b('PRINTONLYIFDATAAVAILABLE', True)
        out.b('REOPENONPRINT', True)
        for sec in self.sections():
            sec.write(out, self.name)
        out.raw('</SUBREPORT>')


class Param:
    def __init__(self, name, ptype, value, description='', visible=True, datasets=()):
        self.name, self.ptype, self.value = name, ptype, value
        self.description, self.visible, self.datasets = description, visible, datasets

    def write(self, out):
        out.s('NAME', self.name)
        out.s('INTNAME', self.name)
        out.w('DESCRIPTION', self.description)
        out.w('HINT', '')
        out.w('ERRORMESSAGE', '')
        out.w('VALIDATION', '')
        out.w('SEARCH', '')
        out.b('VISIBLE', self.visible)
        out.b('ISREADONLY', False)
        out.b('NEVERVISIBLE', not self.visible)
        out.b('ALLOWNULLS', False)
        out.i('PARAMTYPE', self.ptype)
        out.s('DATASETS', lines(*self.datasets))
        out.s('ITEMS', '')
        out.s('VALUES', '')
        out.s('SELECTED', '')
        out.s('LOOKUPDATASET', '')
        out.s('SEARCHDATASET', '')
        out.s('SEARCHPARAM', '')
        if self.ptype == PARAM_INTEGER:
            out.i('VALUE', self.value)
        elif self.ptype == PARAM_DATE:
            out.d('VALUE', self.value)
        else:
            out.s('VALUE', self.value)


def delphi_date(year, month, day):
    """TDateTime of a date: days since 30-12-1899."""
    import datetime
    return (datetime.date(year, month, day) - datetime.date(1899, 12, 30)).days


class Report:
    def __init__(self, title, subject=''):
        self.title = title
        self.subject = subject
        self.counters = {}
        self.datasets = []
        self.params = []
        self.subreports = []
        self.page = {}
        # The connection, in the report: FireDAC + SQLite on samples.db,
        # next to the report
        self.params.append(Param('DBPARAM_DRIVERNAME', PARAM_STRING, 'FireDac',
                                 'Connection SAMPLES: driver', visible=False))
        self.params.append(Param('DBPARAM_DRIVERID', PARAM_STRING, 'SQLite',
                                 'Connection SAMPLES: database type', visible=False))
        self.params.append(Param('DBPARAM_DATABASE', PARAM_STRING, 'samples.db',
                                 'Connection SAMPLES: database file, relative to the report',
                                 visible=False))

    def next_name(self, prefix):
        n = self.counters.get(prefix, 0)
        self.counters[prefix] = n + 1
        return '%s%d' % (prefix, n)

    def dataset(self, alias, sql, datasource=''):
        self.datasets.append((alias, sql, datasource))

    def param(self, *args, **kw):
        self.params.append(Param(*args, **kw))

    def subreport(self, alias):
        sub = SubReport(self, alias)
        self.subreports.append(sub)
        return sub

    def xml(self):
        p = self.page
        out = XmlOut()
        out.raw('<?xml version="1.0" standalone="no"?>')
        out.raw('<!DOCTYPE REPORT_MANAGER_2>')
        out.raw('<REPORT>')
        out.w('WFONTNAME', 'Arial')
        out.w('LFONTNAME', 'Helvetica')
        out.b('GRIDVISIBLE', True)
        out.b('GRIDLINES', False)
        out.b('GRIDENABLED', True)
        out.i('GRIDCOLOR', 16711680)
        out.i('GRIDWIDTH', 115)
        out.i('GRIDHEIGHT', 115)
        out.i('PAGEORIENTATION', 1)          # portrait
        out.i('PAGESIZE', 1)                 # rpPageSizeCustom: PAGESIZEQT
        out.i('PAGESIZEQT', 0)               # A4
        out.i('PAGEHEIGHT', PAGE_H)
        out.i('PAGEWIDTH', PAGE_W)
        out.i('CUSTOMPAGEHEIGHT', PAGE_H)
        out.i('CUSTOMPAGEWIDTH', PAGE_W)
        out.i('PAGEBACKCOLOR', WHITE)
        out.i('PREVIEWSTYLE', 0)
        out.b('PREVIEWMARGINS', False)
        out.i('PREVIEWWINDOW', 0)
        out.i('LEFTMARGIN', p.get('left', MARGIN_L))
        out.i('TOPMARGIN', p.get('top', MARGIN_T))
        out.i('RIGHTMARGIN', p.get('right', MARGIN_R))
        out.i('BOTTOMMARGIN', p.get('bottom', MARGIN_B))
        out.i('PRINTERSELECT', 0)
        out.i('LANGUAGE', -1)
        out.i('COPIES', 1)
        out.b('COLLATECOPIES', False)
        out.b('TWOPASS', False)
        out.i('PRINTERFONTS', 0)
        out.b('PRINTONLYIFDATAAVAILABLE', False)
        out.i('STREAMFORMAT', 3)             # rpStreamXML
        out.b('REPORTACTIONDRAWERBEFORE', False)
        out.b('REPORTACTIONDRAWERAFTER', False)
        out.b('PREVIEWABOUT', True)
        out.i('TYPE1FONT', 0)
        out.i('FONTSIZE', 10)
        out.i('FONTROTATION', 0)
        out.i('FONTSTYLE', 0)
        out.i('FONTCOLOR', 0)
        out.i('BACKCOLOR', WHITE)
        out.b('TRANSPARENT', True)
        out.b('CUTTEXT', False)
        out.i('ALIGNMENT', 0)
        out.i('VALIGNMENT', 0)
        out.b('WORDWRAP', False)
        out.b('SINGLELINE', False)
        out.b('MULTIPAGE', False)
        out.i('PRINTSTEP', 0)
        out.i('PAPERSOURCE', 0)
        out.i('DUPLEX', 0)
        out.s('FORCEPAPERNAME', '')
        out.i('LINESPERINCH', 600)
        out.i('PDFCONFORMANCE', 0)
        out.b('PDFCOMPRESSED', True)
        out.s('DOCAUTHOR', COMPANY)
        out.s('DOCCREATOR', 'Report Manager')
        out.s('DOCPRODUCER', '')
        out.s('DOCSUBJECT', self.subject)
        out.s('DOCTITLE', self.title)
        out.s('DOCCREATIONDATE', '')
        out.s('DOCMODIFICATIONDATE', '')
        out.s('DOCKEYWORDS', '')
        out.s('DOCXMPCONTENT', '')

        out.raw('<DATABASEINFO>')
        out.s('ALIAS', CONNECTION)
        out.s('NAME', 'TRpDatabaseInfoItem0')
        out.s('CONFIGFILE', '')
        out.b('LOADPARAMS', False)
        out.b('LOADDRIVERPARAMS', False)
        out.b('LOGINPROMPT', False)
        out.i('DRIVER', DRIVER_FIREDAC)
        out.s('REPORTTABLE', 'REPMAN_REPORTS')
        out.s('REPORTSEARCHFIELD', 'REPORT_NAME')
        out.s('REPORTFIELD', 'REPORT')
        out.s('REPORTGROUPSTABLE', 'REPMAN_GROUPS')
        out.w('ADOCONNECTIONSTRING', '')
        out.i('DOTNETDRIVER', 0)
        out.s('PROVIDERFACTORY', '')
        out.raw('</DATABASEINFO>')

        for n, (alias, sql, datasource) in enumerate(self.datasets):
            out.raw('<DATAINFO>')
            out.s('ALIAS', alias)
            out.s('NAME', 'TRpDataInfoItem%d' % n)
            out.s('DATABASEALIAS', CONNECTION)
            out.w('SQL', sql)
            out.s('DATASOURCE', datasource)
            for tag in ('MYBASEFILENAME', 'MYBASEFIELDS', 'MYBASEINDEXFIELDS',
                        'MYBASEMASTERFIELDS', 'BDEINDEXFIELDS', 'BDEINDEXNAME', 'BDETABLE'):
                out.s(tag, '')
            out.i('BDETYPE', 0)
            for tag in ('BDEFILTER', 'BDEMASTERFIELDS', 'BDEFIRSTRANGE', 'BDELASTRANGE',
                        'DATAUNIONS'):
                out.s(tag, '')
            out.b('GROUPUNION', False)
            out.b('OPENONSTART', True)
            out.b('PARALLELUNION', False)
            out.raw('</DATAINFO>')

        for prm in self.params:
            out.raw('<PARAMETER>')
            prm.write(out)
            out.raw('</PARAMETER>')

        for sub in self.subreports:
            sub.write(out)
        out.raw('</REPORT>')
        return out.text()


# ---------------------------------------------------------------------------
# The common look: a band with the company and the title, and a page footer
# ---------------------------------------------------------------------------
def banner(sub, title, subtitle):
    sec = sub.section(SEC_PHEADER, 1300)
    sec.rect(0, 0, WIDTH, 820, fill=DARK)
    sec.label(260, 120, 6000, 230, COMPANY.upper(), size=8, style=BOLD, color=rgb(0xBD, 0xD7, 0xEE))
    sec.label(260, 330, 7600, 420, title, size=18, style=BOLD, color=WHITE)
    sec.label(WIDTH - 3060, 120, 1500, 230, 'Printed on', size=8, color=rgb(0xBD, 0xD7, 0xEE),
              alignment=RIGHT)
    sec.expr(WIDTH - 1500, 120, 1240, 230, 'TODAY', size=8, color=WHITE, alignment=RIGHT,
             fmt='dd/mm/yyyy')
    sec.label(0, 920, WIDTH, 260, subtitle, size=9, style=ITALIC, color=GRAY)
    return sec


def page_footer(sub):
    sec = sub.section(SEC_PFOOTER, 520)
    sec.rect(0, 80, WIDTH, 15, fill=LINE)
    sec.label(0, 190, 7000, 230, FOOTER_TEXT, size=8, color=MIDGRAY)
    sec.expr(WIDTH - 2000, 190, 2000, 230, "'Page '+STR(PAGE)", size=8, color=MIDGRAY,
             alignment=RIGHT)
    return sec


def column_headers(sec, y, columns, color=GRAY, size=8, style=BOLD):
    """columns: (x, width, caption, alignment)"""
    for x, w, caption, align in columns:
        sec.label(x, y, w, 240, caption, size=size, style=style, color=color, alignment=align)


# ---------------------------------------------------------------------------
# The samples
# ---------------------------------------------------------------------------
def customers():
    rep = Report('Customers by country', 'The customers grouped by country, with a count per group')
    rep.dataset('CUST', 'SELECT CODE, COMPANY_NAME, CONTACT_NAME, CITY, COUNTRY, PHONE, '
                        'CUSTOMER_SINCE FROM CUSTOMERS ORDER BY COUNTRY, COMPANY_NAME')
    sub = rep.subreport('CUST')
    banner(sub, 'Customers by country',
           'Every customer, grouped by country, with the contact person and the phone number')
    cols = [(0, 800, 'Code', LEFT), (900, 3000, 'Company', LEFT), (4000, 2200, 'Contact', LEFT),
            (6300, 1600, 'City', LEFT), (8000, 1650, 'Phone', LEFT),
            (9700, 1058, 'Customer since', RIGHT)]
    _, total = sub.group('TOTAL', '', 0, 700)
    head, foot = sub.group('COUNTRY', 'CUST.COUNTRY', 900, 520,
                           header={'pagerepeat': True, 'beginpage': 'FREE_SPACE_CMS<3'})
    head.expr(0, 150, 7000, 340, 'CUST.COUNTRY', size=13, style=BOLD, color=DARK)
    head.rect(0, 540, WIDTH, 20, fill=ACCENT)
    column_headers(head, 620, cols)
    det = sub.section(SEC_DETAIL, 320)
    det.expr(0, 50, 800, 240, 'CUST.CODE', color=GRAY)
    det.expr(900, 50, 3000, 240, 'CUST.COMPANY_NAME', cut=True)
    det.expr(4000, 50, 2200, 240, 'CUST.CONTACT_NAME', cut=True)
    det.expr(6300, 50, 1600, 240, 'CUST.CITY', cut=True)
    det.expr(8000, 50, 1650, 240, 'CUST.PHONE', color=GRAY)
    det.expr(9700, 50, 1058, 240, 'CUST.CUSTOMER_SINCE', fmt='dd/mm/yyyy', alignment=RIGHT)
    det.rect(0, 305, WIDTH, 10, fill=ROWLINE)
    foot.label(WIDTH - 3600, 90, 2500, 250, 'Customers in this country', color=GRAY, alignment=RIGHT)
    foot.expr(WIDTH - 1000, 90, 1000, 250, '1', style=BOLD, alignment=RIGHT, fmt='#,##0',
              aggregate=AG_GROUP, group='COUNTRY')
    total.rect(0, 150, WIDTH, 420, fill=LIGHT)
    total.label(200, 220, 5000, 280, 'Total customers', size=10, style=BOLD, color=DARK)
    total.expr(WIDTH - 1700, 220, 1500, 280, '1', size=10, style=BOLD, color=DARK, alignment=RIGHT,
               fmt='#,##0', aggregate=AG_GENERAL)
    page_footer(sub)
    return rep


def invoices():
    rep = Report('Invoices', 'One invoice per order: customer, lines, VAT and total')
    rep.param('FIRST_ORDER', PARAM_INTEGER, 1, 'From order number', datasets=('INV',))
    rep.param('LAST_ORDER', PARAM_INTEGER, 4, 'To order number', datasets=('INV',))
    rep.dataset('INV', 'SELECT O.ORDER_ID, O.ORDER_NUMBER, O.ORDER_DATE, O.STATUS, O.VAT_RATE, '
                       'C.CODE AS CUSTOMER_CODE, C.COMPANY_NAME, C.CONTACT_NAME, C.ADDRESS, '
                       'C.POSTAL_CODE, C.CITY, C.COUNTRY, E.FIRST_NAME, E.LAST_NAME, '
                       'L.LINE_NO, P.SKU, P.NAME AS PRODUCT, P.UNIT, L.QUANTITY, L.UNIT_PRICE, '
                       'L.DISCOUNT '
                       'FROM ORDERS O '
                       'JOIN CUSTOMERS C ON C.CUSTOMER_ID = O.CUSTOMER_ID '
                       'JOIN EMPLOYEES E ON E.EMPLOYEE_ID = O.EMPLOYEE_ID '
                       'JOIN ORDER_LINES L ON L.ORDER_ID = O.ORDER_ID '
                       'JOIN PRODUCTS P ON P.PRODUCT_ID = L.PRODUCT_ID '
                       'WHERE O.ORDER_ID BETWEEN :FIRST_ORDER AND :LAST_ORDER '
                       'ORDER BY O.ORDER_ID, L.LINE_NO')
    sub = rep.subreport('INV')
    amount = 'INV.QUANTITY*INV.UNIT_PRICE*(1-INV.DISCOUNT/100)'
    # SkipPage starts a new page after the section: one invoice per page
    head, foot = sub.group('INVOICE', 'INV.ORDER_ID', 4080, 2400,
                           header={'pagerepeat': True}, footer={'skippage': True})
    # Issuer
    head.label(0, 0, 6500, 460, COMPANY, size=18, style=BOLD, color=DARK)
    head.label(0, 500, 6500, 230, 'Muelle de Levante 12 · 08039 Barcelona · Spain',
               size=8, color=GRAY)
    head.label(0, 730, 6500, 230, 'VAT ES-B00000000 · +34 930 000 000 · '
               'billing@marenostrum.example', size=8, color=GRAY)
    # Invoice data
    head.label(WIDTH - 4000, 0, 4000, 520, 'INVOICE', size=22, style=BOLD, color=DARK,
               alignment=RIGHT)
    rows = [('Invoice number', 'INV.ORDER_NUMBER', ''),
            ('Date', 'INV.ORDER_DATE', 'dd/mm/yyyy'),
            ('Customer code', 'INV.CUSTOMER_CODE', ''),
            ('Sales representative', "INV.FIRST_NAME+' '+INV.LAST_NAME", '')]
    for n, (caption, value, fmt) in enumerate(rows):
        y = 1300 + n * 290
        head.label(WIDTH - 4600, y, 2100, 250, caption, size=8, color=GRAY)
        head.expr(WIDTH - 2500, y, 2500, 250, value, style=BOLD, alignment=RIGHT, fmt=fmt)
    # Customer
    head.rect(0, 1200, 5800, 2050, fill=LIGHT, shape=SHAPE_ROUNDRECT)
    head.label(250, 1330, 3000, 220, 'BILL TO', size=7, style=BOLD, color=ACCENT)
    head.expr(250, 1580, 5400, 300, 'INV.COMPANY_NAME', size=11, style=BOLD)
    head.expr(250, 1930, 5400, 250, "'Attn. '+INV.CONTACT_NAME", color=GRAY)
    head.expr(250, 2210, 5400, 250, 'INV.ADDRESS')
    head.expr(250, 2470, 5400, 250, "INV.POSTAL_CODE+' '+INV.CITY")
    head.expr(250, 2730, 5400, 250, 'UPPERCASE(INV.COUNTRY)', style=BOLD)
    # Lines header
    head.rect(0, 3560, WIDTH, 400, fill=DARK)
    column_headers(head, 3640, [(100, 300, '#', LEFT), (450, 1000, 'SKU', LEFT),
                                (1500, 4200, 'Description', LEFT), (5750, 900, 'Qty.', RIGHT),
                                (6750, 1250, 'Unit price', RIGHT), (8050, 750, 'Disc.', RIGHT),
                                (8850, 1808, 'Amount', RIGHT)], color=WHITE)
    det = sub.section(SEC_DETAIL, 540)
    det.expr(100, 70, 300, 240, 'INV.LINE_NO', color=GRAY)
    det.expr(450, 70, 1000, 240, 'INV.SKU', size=8, color=GRAY)
    det.expr(1500, 50, 4200, 250, 'INV.PRODUCT', cut=True)
    det.expr(1500, 290, 4200, 210, 'INV.UNIT', size=7, color=MIDGRAY)
    det.expr(5750, 70, 900, 240, 'INV.QUANTITY', alignment=RIGHT, fmt='#,##0')
    det.expr(6750, 70, 1250, 240, 'INV.UNIT_PRICE', alignment=RIGHT, fmt='#,##0.00')
    det.expr(8050, 70, 750, 240, "STR(INV.DISCOUNT)+'%'", alignment=RIGHT, color=GRAY,
             condition='INV.DISCOUNT>0')
    det.expr(8850, 70, 1808, 240, amount, alignment=RIGHT, fmt='#,##0.00')
    det.rect(0, 525, WIDTH, 10, fill=ROWLINE)
    # Totals
    x = WIDTH - 4400
    foot.label(x, 200, 2300, 260, 'Subtotal', color=GRAY, alignment=RIGHT)
    foot.expr(WIDTH - 2000, 200, 1900, 260, amount, alignment=RIGHT, fmt='#,##0.00',
              aggregate=AG_GROUP, group='INVOICE', identifier='SUBTOTAL')
    foot.expr(x, 500, 2300, 260, 'INV.VAT_RATE', color=GRAY, alignment=RIGHT,
              fmt='"VAT "0"%"', aggregate=AG_GROUP, group='INVOICE', agtype=AGT_MAX)
    foot.expr(WIDTH - 2000, 500, 1900, 260, amount + '*INV.VAT_RATE/100', alignment=RIGHT,
              fmt='#,##0.00', aggregate=AG_GROUP, group='INVOICE', identifier='VATAMOUNT')
    foot.rect(x, 840, 4400, 460, fill=DARK)
    foot.label(x + 150, 920, 2000, 300, 'TOTAL (EUR)', size=11, style=BOLD, color=WHITE)
    foot.expr(WIDTH - 2400, 920, 2300, 300, 'SUBTOTAL+VATAMOUNT', size=11, style=BOLD,
              color=WHITE, alignment=RIGHT, fmt='#,##0.00')
    foot.label(0, 220, 5500, 230, 'Amounts in euros. Payment within 30 days by bank transfer.',
               size=8, color=GRAY)
    foot.label(0, 470, 5500, 230, 'IBAN ES00 0000 0000 0000 0000 0000', size=8, color=GRAY)
    foot.label(0, 1000, 5500, 300, 'Thank you for your business!', size=11, style=ITALIC,
               color=DARK)
    page_footer(sub)
    return rep


def sales_by_category():
    rep = Report('Sales by category', 'Product sales of a year, grouped by category, '
                 'with a summary chart')
    rep.param('SALES_YEAR', PARAM_INTEGER, 2025, 'Year', datasets=('PROD', 'CATS'))
    sales = 'SUM(L.QUANTITY*L.UNIT_PRICE*(1-L.DISCOUNT/100.0))'
    joins = ('FROM ORDER_LINES L '
             'JOIN ORDERS O ON O.ORDER_ID = L.ORDER_ID '
             'JOIN PRODUCTS P ON P.PRODUCT_ID = L.PRODUCT_ID '
             'JOIN CATEGORIES C ON C.CATEGORY_ID = P.CATEGORY_ID '
             "WHERE CAST(strftime('%Y', O.ORDER_DATE) AS INTEGER) = :SALES_YEAR ")
    rep.dataset('PROD', 'SELECT C.NAME AS CATEGORY, P.SKU, P.NAME AS PRODUCT, '
                        'SUM(L.QUANTITY) AS UNITS, ' + sales + ' AS SALES ' + joins +
                        'GROUP BY C.NAME, P.SKU, P.NAME ORDER BY C.NAME, SALES DESC')
    rep.dataset('CATS', 'SELECT C.NAME AS CATEGORY, SUM(L.QUANTITY) AS UNITS, ' + sales +
                        ' AS SALES, 100.0 * ' + sales + ' / (SELECT ' + sales + ' ' + joins +
                        ') AS SHARE ' + joins + 'GROUP BY C.NAME ORDER BY SALES DESC')
    # Products, by category
    sub = rep.subreport('PROD')
    banner(sub, 'Sales by category', 'Units and sales of every product in the year, '
           'by category, from the most to the least sold')
    sub.pheader[0].expr(WIDTH - 2500, 920, 2500, 260, "'Year '+STR(SALES_YEAR)", size=9, style=BOLD,
                        color=DARK, alignment=RIGHT)
    cols = [(0, 1100, 'SKU', LEFT), (1200, 5600, 'Product', LEFT), (6900, 1500, 'Units', RIGHT),
            (8500, 2258, 'Sales (EUR)', RIGHT)]
    _, total = sub.group('TOTAL', '', 0, 700, footer={'skippage': True})
    head, foot = sub.group('CATEGORY', 'PROD.CATEGORY', 880, 560,
                           header={'pagerepeat': True, 'beginpage': 'FREE_SPACE_CMS<3'})
    head.expr(0, 150, 8000, 340, 'PROD.CATEGORY', size=13, style=BOLD, color=DARK)
    head.rect(0, 540, WIDTH, 20, fill=ACCENT)
    column_headers(head, 610, cols)
    det = sub.section(SEC_DETAIL, 310)
    det.expr(0, 45, 1100, 240, 'PROD.SKU', size=8, color=GRAY)
    det.expr(1200, 40, 5600, 240, 'PROD.PRODUCT', cut=True)
    det.expr(6900, 40, 1500, 240, 'PROD.UNITS', alignment=RIGHT, fmt='#,##0')
    det.expr(8500, 40, 2258, 240, 'PROD.SALES', alignment=RIGHT, fmt='#,##0.00')
    det.rect(0, 295, WIDTH, 10, fill=ROWLINE)
    foot.rect(5000, 80, WIDTH - 5000, 360, fill=LIGHT)
    foot.label(5100, 130, 1700, 260, 'Category total', style=BOLD, color=DARK)
    foot.expr(6900, 130, 1500, 260, 'PROD.UNITS', style=BOLD, color=DARK, alignment=RIGHT,
              fmt='#,##0', aggregate=AG_GROUP, group='CATEGORY')
    foot.expr(8500, 130, 2158, 260, 'PROD.SALES', style=BOLD, color=DARK, alignment=RIGHT,
              fmt='#,##0.00', aggregate=AG_GROUP, group='CATEGORY')
    total.rect(0, 150, WIDTH, 440, fill=DARK)
    total.label(200, 230, 5000, 290, 'Total of the year', size=11, style=BOLD, color=WHITE)
    total.expr(6900, 230, 1500, 290, 'PROD.UNITS', size=11, style=BOLD, color=WHITE,
               alignment=RIGHT, fmt='#,##0', aggregate=AG_GENERAL)
    total.expr(8500, 230, 2158, 290, 'PROD.SALES', size=11, style=BOLD, color=WHITE,
               alignment=RIGHT, fmt='#,##0.00', aggregate=AG_GENERAL)
    page_footer(sub)
    # Summary by category, with a chart: a second subreport on its own data
    sub2 = rep.subreport('CATS')
    banner(sub2, 'Sales by category', 'Summary by category: units, sales and their chart')
    sub2.pheader[0].expr(WIDTH - 2500, 920, 2500, 260, "'Year '+STR(SALES_YEAR)", size=9,
                         style=BOLD, color=DARK, alignment=RIGHT)
    head2, foot2 = sub2.group('SUMMARY', '', 1000, 6200)
    head2.label(0, 100, 8000, 420, 'Summary by category', size=16, style=BOLD, color=DARK)
    head2.rect(0, 600, WIDTH, 20, fill=ACCENT)
    column_headers(head2, 700, [(0, 5000, 'Category', LEFT), (5200, 1600, 'Units', RIGHT),
                                (7000, 2000, 'Sales (EUR)', RIGHT), (9100, 1658, 'Share', RIGHT)])
    det2 = sub2.section(SEC_DETAIL, 320)
    det2.expr(0, 45, 5000, 240, 'CATS.CATEGORY')
    det2.expr(5200, 45, 1600, 240, 'CATS.UNITS', alignment=RIGHT, fmt='#,##0')
    det2.expr(7000, 45, 2000, 240, 'CATS.SALES', alignment=RIGHT, fmt='#,##0.00')
    det2.expr(9100, 45, 1658, 240, 'CATS.SHARE', alignment=RIGHT, fmt='0.0"%"', color=GRAY)
    det2.rect(0, 305, WIDTH, 10, fill=ROWLINE)
    foot2.rect(0, 60, WIDTH, 400, fill=LIGHT)
    foot2.label(200, 130, 4000, 270, 'Total', style=BOLD, color=DARK)
    foot2.expr(5200, 130, 1600, 270, 'CATS.UNITS', style=BOLD, color=DARK, alignment=RIGHT,
               fmt='#,##0', aggregate=AG_GENERAL)
    foot2.expr(7000, 130, 2000, 270, 'CATS.SALES', style=BOLD, color=DARK, alignment=RIGHT,
               fmt='#,##0.00', aggregate=AG_GENERAL)
    foot2.add(Chart(0, 800, WIDTH, 5300, value='CATS.SALES', caption='CATS.CATEGORY',
                    charttype=CHART_HORZBAR, hfont=8, vfont=8, colorexpr=str(ACCENT)))
    page_footer(sub2)
    return rep


def product_catalog():
    rep = Report('Product catalogue', 'Products by category with EAN-13 barcodes and stock alerts')
    rep.dataset('CAT', 'SELECT C.NAME AS CATEGORY, C.DESCRIPTION AS CATEGORY_DESCRIPTION, '
                       'P.SKU, P.EAN13, P.NAME, P.UNIT, P.UNIT_PRICE, P.UNITS_IN_STOCK, '
                       'P.REORDER_LEVEL '
                       'FROM PRODUCTS P JOIN CATEGORIES C ON C.CATEGORY_ID = P.CATEGORY_ID '
                       'ORDER BY C.NAME, P.NAME')
    sub = rep.subreport('CAT')
    banner(sub, 'Product catalogue', 'Every product with its EAN-13 barcode, price and stock; '
           'the products below their reorder level are marked in red')
    head, foot = sub.group('CATEGORY', 'CAT.CATEGORY', 1400, 200,
                           header={'pagerepeat': True, 'beginpage': 'FREE_SPACE_CMS<4'})
    head.rect(0, 150, WIDTH, 760, fill=LIGHT)
    head.rect(0, 150, 80, 760, fill=ACCENT)
    head.expr(260, 230, 8000, 340, 'CAT.CATEGORY', size=13, style=BOLD, color=DARK)
    head.expr(260, 580, 9000, 250, 'CAT.CATEGORY_DESCRIPTION', style=ITALIC, color=GRAY)
    column_headers(head, 1070, [(0, 2300, 'Barcode', LEFT), (2500, 4300, 'Product', LEFT),
                                (6900, 1300, 'SKU', LEFT), (8250, 1150, 'Price', RIGHT),
                                (9450, 1308, 'In stock', RIGHT)])
    det = sub.section(SEC_DETAIL, 1000)
    # EAN-13 is 95 modules wide: 95 x 20 twips, the digits centered below
    det.add(Barcode(100, 110, 1900, 560, expr='CAT.EAN13', modul=20))
    det.expr(100, 690, 1900, 200, 'CAT.EAN13', size=7, color=GRAY, alignment=CENTER)
    det.expr(2500, 180, 4300, 280, 'CAT.NAME', size=10, style=BOLD, cut=True)
    det.expr(2500, 490, 4300, 240, 'CAT.UNIT', color=GRAY)
    det.expr(6900, 200, 1300, 240, 'CAT.SKU', color=GRAY)
    det.expr(8250, 190, 1150, 260, 'CAT.UNIT_PRICE', size=10, style=BOLD, alignment=RIGHT,
             fmt='#,##0.00')
    det.expr(9450, 190, 1308, 260, 'CAT.UNITS_IN_STOCK', size=10, alignment=RIGHT, fmt='#,##0',
             condition='CAT.UNITS_IN_STOCK>=CAT.REORDER_LEVEL')
    det.expr(9450, 190, 1308, 260, 'CAT.UNITS_IN_STOCK', size=10, style=BOLD, color=RED,
             alignment=RIGHT, fmt='#,##0', condition='CAT.UNITS_IN_STOCK<CAT.REORDER_LEVEL')
    det.label(8450, 500, 2308, 220, 'Below reorder level', size=7, style=BOLD, color=RED,
              alignment=RIGHT, condition='CAT.UNITS_IN_STOCK<CAT.REORDER_LEVEL')
    det.rect(0, 980, WIDTH, 10, fill=ROWLINE)
    page_footer(sub)
    return rep


def monthly_sales():
    rep = Report('Monthly sales', 'Orders and sales by month between two dates, with a chart')
    rep.param('FROM_DATE', PARAM_DATE, delphi_date(2025, 1, 1), 'From date', datasets=('MON',))
    rep.param('TO_DATE', PARAM_DATE, delphi_date(2025, 12, 31), 'To date', datasets=('MON',))
    rep.dataset('MON', "SELECT strftime('%Y-%m', O.ORDER_DATE) AS PERIOD, "
                       "substr('JanFebMarAprMayJunJulAugSepOctNovDec', "
                       "(CAST(strftime('%m', O.ORDER_DATE) AS INTEGER) - 1) * 3 + 1, 3) "
                       "|| ' ' || strftime('%Y', O.ORDER_DATE) AS MONTH_NAME, "
                       'COUNT(DISTINCT O.ORDER_ID) AS ORDERS, SUM(L.QUANTITY) AS UNITS, '
                       'SUM(L.QUANTITY*L.UNIT_PRICE*(1-L.DISCOUNT/100.0)) AS SALES '
                       'FROM ORDERS O JOIN ORDER_LINES L ON L.ORDER_ID = O.ORDER_ID '
                       'WHERE O.ORDER_DATE BETWEEN date(:FROM_DATE) AND date(:TO_DATE) '
                       'GROUP BY 1, 2 ORDER BY 1')
    sub = rep.subreport('MON')
    banner(sub, 'Monthly sales', 'Orders, units and sales by month between the two dates '
           'of the parameters')
    # Dates through DisplayFormat, which the .NET engine converts (FORMATSTR
    # passes the format as is)
    ph = sub.pheader[0]
    ph.label(WIDTH - 4300, 920, 1300, 260, 'Period', size=9, color=GRAY, alignment=RIGHT)
    ph.expr(WIDTH - 2950, 920, 1250, 260, 'FROM_DATE', size=9, style=BOLD, color=DARK,
            alignment=RIGHT, fmt='dd/mm/yyyy')
    ph.label(WIDTH - 1700, 920, 400, 260, '–', size=9, color=DARK, alignment=CENTER)
    ph.expr(WIDTH - 1250, 920, 1250, 260, 'TO_DATE', size=9, style=BOLD, color=DARK,
            alignment=RIGHT, fmt='dd/mm/yyyy')
    cols = [(0, 2600, 'Month', LEFT), (2800, 1600, 'Orders', RIGHT), (4600, 1600, 'Units', RIGHT),
            (6400, 2100, 'Sales (EUR)', RIGHT), (8700, 2058, 'Average order', RIGHT)]
    head, foot = sub.group('TOTAL', '', 560, 7000, header={'pagerepeat': True})
    column_headers(head, 150, cols)
    head.rect(0, 460, WIDTH, 20, fill=ACCENT)
    det = sub.section(SEC_DETAIL, 330)
    det.expr(0, 50, 2600, 240, 'MON.MONTH_NAME', style=BOLD)
    det.expr(2800, 50, 1600, 240, 'MON.ORDERS', alignment=RIGHT, fmt='#,##0')
    det.expr(4600, 50, 1600, 240, 'MON.UNITS', alignment=RIGHT, fmt='#,##0')
    det.expr(6400, 50, 2100, 240, 'MON.SALES', alignment=RIGHT, fmt='#,##0.00')
    det.expr(8700, 50, 2058, 240, 'MON.SALES/MON.ORDERS', alignment=RIGHT, fmt='#,##0.00',
             color=GRAY)
    det.rect(0, 315, WIDTH, 10, fill=ROWLINE)
    foot.rect(0, 120, WIDTH, 440, fill=DARK)
    foot.label(200, 200, 2400, 290, 'Total', size=11, style=BOLD, color=WHITE)
    foot.expr(2800, 200, 1600, 290, 'MON.ORDERS', size=11, style=BOLD, color=WHITE,
              alignment=RIGHT, fmt='#,##0', aggregate=AG_GENERAL, identifier='TOTALORDERS')
    foot.expr(4600, 200, 1600, 290, 'MON.UNITS', size=11, style=BOLD, color=WHITE,
              alignment=RIGHT, fmt='#,##0', aggregate=AG_GENERAL)
    foot.expr(6400, 200, 2100, 290, 'MON.SALES', size=11, style=BOLD, color=WHITE,
              alignment=RIGHT, fmt='#,##0.00', aggregate=AG_GENERAL, identifier='TOTALSALES')
    foot.expr(8700, 200, 1958, 290, 'TOTALSALES/TOTALORDERS', size=11, style=BOLD,
              color=WHITE, alignment=RIGHT, fmt='#,##0.00')
    foot.label(0, 900, 8000, 360, 'Sales by month (EUR)', size=13, style=BOLD, color=DARK)
    foot.add(Chart(0, 1350, WIDTH, 5500, value='MON.SALES', caption='MON.MONTH_NAME',
                   charttype=CHART_BAR, hfont=8, vfont=8, colorexpr=str(ACCENT)))
    page_footer(sub)
    return rep


def labels():
    rep = Report('Address labels', 'Customer address labels, 3 x 8 per A4 sheet (70 x 36 mm)')
    rep.page = {'left': 0, 'right': 0, 'top': 255, 'bottom': 255}
    rep.dataset('ADDR', 'SELECT COMPANY_NAME, CONTACT_NAME, ADDRESS, POSTAL_CODE, CITY, COUNTRY '
                        'FROM CUSTOMERS ORDER BY COUNTRY, COMPANY_NAME')
    sub = rep.subreport('ADDR')
    w, h = 3968, 2041          # 70 x 36 mm
    det = sub.section(SEC_DETAIL, h, width=w, horzdesp=True)
    det.rect(70, 70, w - 140, h - 140, shape=SHAPE_ROUNDRECT, pen=LINE, penstyle=PEN_DOT)
    det.expr(330, 330, w - 600, 290, 'ADDR.COMPANY_NAME', size=10, style=BOLD, cut=True)
    det.expr(330, 650, w - 600, 250, "'Attn. '+ADDR.CONTACT_NAME", color=GRAY, cut=True)
    det.expr(330, 900, w - 600, 250, 'ADDR.ADDRESS', cut=True)
    det.expr(330, 1150, w - 600, 250, "ADDR.POSTAL_CODE+' '+ADDR.CITY", cut=True)
    det.expr(330, 1400, w - 600, 250, 'UPPERCASE(ADDR.COUNTRY)', style=BOLD, cut=True)
    return rep


def fishes():
    """The classic sample (sample4.rep), now on the FISHES table of samples.db."""
    rep = Report('Fishes (classic)', 'The classic Report Manager sample: biolife fishes')
    # The parameters of the classic sample, before the connection ones
    rep.params[0:0] = [Param('TITLE1', PARAM_STRING, 'Fishes, species', 'Title 1'),
                       Param('TITLE2', PARAM_STRING, 'Descriptions and images', 'Title 2')]
    rep.dataset('FISH', 'SELECT SPECIES_NO, CATEGORY, COMMON_NAME, SPECIES_NAME, LENGTH_CM, '
                        'LENGTH_IN, NOTES, GRAPHIC FROM FISHES ORDER BY CATEGORY, COMMON_NAME')
    sub = rep.subreport('FISH')
    # Page header
    ph = sub.section(SEC_PHEADER, 454, width=10900)
    ph.label(5865, 0, 1440, 275, 'Page\nPage\nPágina')
    ph.expr(7470, 0, 1440, 275, 'Page')
    ph.expr(120, 0, 3210, 465, 'Title1', size=14)
    # Summary group (the chart) and category group
    sumh, sumf = sub.group('SUMARY', '', 0, 4590, header={'width': 10900},
                           footer={'width': 10900})
    cath, catf = sub.group('F', 'FISH.CATEGORY', 1215, 574,
                           header={'width': 10900, 'pagerepeat': True,
                                   'beginpage': 'FREE_SPACE_CMS<6.5'},
                           footer={'width': 10900})
    cath.rect(0, 0, 6437, 691, fill=WHITE, shape=SHAPE_ROUNDRECT, pen=BLACK)
    cath.label(120, 225, 1843, 576, 'Category\nCategory\nCategoría', size=16, style=6)
    cath.expr(2070, 225, 3557, 576, 'FISH.CATEGORY', size=16, style=3)
    cath.expr(6675, 120, 3210, 465, 'Title2', size=12)
    # Two detail sections: the name and length, and the notes with the picture
    d1 = sub.section(SEC_DETAIL, 150, width=10772, autoexpand=True, autocontract=True)
    d1.expr(1725, 0, 3915, 345, 'FISH.COMMON_NAME', style=BOLD)
    d1.label(120, 0, 1500, 345, 'Name\nName\nNombre', style=4)
    d1.label(5865, 0, 1830, 345, 'Length\nLength\nLongitud', style=4)
    d1.expr(7710, 0, 2419, 346, 'FISH.LENGTH_CM', style=BOLD)
    d1.rect(0, 0, 28, 57, fill=BLACK, pen=BLACK, penwidth=57, shape=7, align_pos=5)
    d2 = sub.section(SEC_DETAIL, 1365, width=10205, autoexpand=True, autocontract=True)
    d2.expr(120, 0, 7245, 690, 'FISH.NOTES', size=13, alignment=1024, wordwrap=True,
            multipage=True)
    d2.add(Image(8055, 0, 2070, 690, expr='FISH.GRAPHIC'))
    d2.rect(0, 0, 28, 465, fill=BLACK, pen=BLACK, penwidth=57, shape=7, align_pos=5)
    catf.expr(1155, 120, 1830, 450, '1', aggregate=AG_GROUP, group='F')
    sumf.add(Chart(0, 570, 10815, 3915, size=6, value='FISH.LENGTH_CM',
                   caption='FISH.COMMON_NAME', changeserie='True', charttype=CHART_PIE,
                   legend=True, hfont=10, vfont=10, resolution=200))
    sumf.label(0, 120, 4605, 450, 'Length in cms Chart\nLength in cms Chart\n'
               'Gráfico de longitud en cms', size=15, style=7)
    # Page footer
    pf = sub.section(SEC_PFOOTER, 1134, width=10772)
    pf.rect(0, 0, 10695, 1155, fill=WHITE, pen=BLACK)
    pf.label(0, 120, 10695, 915, 'Sample report for Report Manager ', size=30, alignment=CENTER)
    return rep


# The fonts of each script, embedded in the PDF (Type1Font poEmbedded) so the
# text needs no font in the reader: WFontName on Windows, LFontName on Linux
# and macOS. When the family is not installed the engine takes a font of the
# system with those characters (fontconfig on Linux, the substitution list of
# Core Text on macOS: Kohinoor Devanagari, Thonburi, Hiragino Sans). Right to
# left scripts use the bidirectional mode.
SCRIPT_FONTS = [
    (('Latin', 'Greek', 'Cyrillic'), 'Arial', 'DejaVu Sans', False),
    (('Arabic',), 'Arial', 'Noto Sans Arabic', True),
    (('Hebrew',), 'Arial', 'Noto Sans Hebrew', True),
    (('Devanagari',), 'Nirmala UI', 'Noto Sans Devanagari', False),
    (('Thai',), 'Leelawadee UI', 'Noto Sans Thai', False),
    (('Japanese',), 'Yu Gothic', 'Noto Sans CJK JP', False),
]
EMBEDDED = 6
BIDI_PARTIAL = 1
ALIGN_BOTTOM = 1


def international():
    rep = Report('International text', 'The same message in nine languages and eight scripts')
    rep.dataset('G', 'SELECT LANGUAGE, NATIVE_NAME, SCRIPT, DIRECTION, GREETING, PARAGRAPH '
                     'FROM GREETINGS ORDER BY GREETING_ID')
    sub = rep.subreport('G')
    banner(sub, 'International text', 'The same message in nine languages and eight scripts: '
           'shaped, right to left where needed, with its fonts embedded in the PDF')
    head, foot = sub.group('TOTAL', '', 560, 0, header={'pagerepeat': True})
    column_headers(head, 150, [(0, 2300, 'Language', LEFT), (2600, WIDTH - 2600, 'Text', LEFT)])
    head.rect(0, 460, WIDTH, 20, fill=ACCENT)
    det = sub.section(SEC_DETAIL, 1200, autoexpand=True)
    det.expr(0, 90, 2300, 280, 'G.LANGUAGE', size=10, style=BOLD, color=DARK)
    det.expr(0, 390, 2300, 240, "G.SCRIPT+IIF(G.DIRECTION='RTL',', right to left','')",
             size=8, color=GRAY)
    width = WIDTH - 2600
    for scripts, wfont, lfont, rtl in SCRIPT_FONTS:
        condition = ' OR '.join("(G.SCRIPT='%s')" % script for script in scripts)
        common = dict(font=wfont, lfont=lfont, type1=EMBEDDED, condition=condition,
                      alignment=RIGHT if rtl else LEFT, bidi=BIDI_PARTIAL if rtl else 0)
        det.expr(2600, 60, width, 420, 'G.GREETING', size=15, style=BOLD, color=DARK, **common)
        det.expr(2600, 520, width, 560, 'G.PARAGRAPH', size=10, wordwrap=True,
                 autoexpand=True, **common)
    det.rect(0, 1175, WIDTH, 10, fill=ROWLINE, align_pos=ALIGN_BOTTOM)
    page_footer(sub)
    return rep


def letter():
    rep = Report('Customer letter', 'A personalised letter for each customer, with HTML text')
    rep.param('FIRST_CUSTOMER', PARAM_INTEGER, 1, 'From customer number', datasets=('LET',))
    rep.param('LAST_CUSTOMER', PARAM_INTEGER, 3, 'To customer number', datasets=('LET',))
    rep.dataset('LET', 'SELECT C.CUSTOMER_ID, C.COMPANY_NAME, C.CONTACT_NAME, C.ADDRESS, '
                       'C.POSTAL_CODE, C.CITY, C.COUNTRY, C.CUSTOMER_SINCE, '
                       '(SELECT COUNT(*) FROM ORDERS O WHERE O.CUSTOMER_ID = C.CUSTOMER_ID) '
                       'AS ORDER_COUNT '
                       'FROM CUSTOMERS C '
                       'WHERE C.CUSTOMER_ID BETWEEN :FIRST_CUSTOMER AND :LAST_CUSTOMER '
                       'ORDER BY C.CUSTOMER_ID')
    sub = rep.subreport('LET')
    # The letterhead, the address and the subject
    det = sub.section(SEC_DETAIL, 4200)
    det.rect(0, 0, WIDTH, 60, fill=DARK)
    det.label(0, 220, 6500, 460, COMPANY, size=18, style=BOLD, color=DARK)
    det.label(0, 700, 6500, 230, 'Muelle de Levante 12 \u00b7 08039 Barcelona \u00b7 Spain', size=8,
              color=GRAY)
    det.label(0, 930, 6500, 230, 'www.marenostrum.example \u00b7 +34 930 000 000', size=8,
              color=GRAY)
    # The address, where the window of the envelope is
    x = 6300
    det.expr(x, 1500, WIDTH - x, 280, 'LET.COMPANY_NAME', size=10, style=BOLD, cut=True)
    det.expr(x, 1800, WIDTH - x, 250, "'Attn. '+LET.CONTACT_NAME", cut=True)
    det.expr(x, 2050, WIDTH - x, 250, 'LET.ADDRESS', cut=True)
    det.expr(x, 2300, WIDTH - x, 250, "LET.POSTAL_CODE+' '+LET.CITY", cut=True)
    det.expr(x, 2550, WIDTH - x, 250, 'UPPERCASE(LET.COUNTRY)', style=BOLD, cut=True)
    det.label(0, 3200, 1400, 250, 'Barcelona,', color=GRAY)
    det.expr(1400, 3200, 2000, 250, 'TODAY', color=GRAY, fmt='dd/mm/yyyy')
    det.label(0, 3650, WIDTH, 340, 'The new harvest is here: 10% off your next order', size=13,
              style=BOLD, color=DARK)
    # The body, text with HTML marks (bold, italics, underline, strike, colours
    # and another font). One detail section per paragraph: a section grows
    # with its text and the next one follows it
    paragraphs = [
        "'Dear <b>'+LET.CONTACT_NAME+'</b>,'",
        "'Thank you for trusting <b><font color=\"#1F4E79\">Mare Nostrum Fine Foods</font></b> "
        "since <b>'+STR(YEAR(LET.CUSTOMER_SINCE))+'</b>: you have placed <b>'"
        "+STR(LET.ORDER_COUNT)+' orders</b> with us, and we are proud to supply <i>'"
        "+LET.COMPANY_NAME+'</i> in <u>'+LET.CITY+'</u>.'",
        "'The <font color=\"#548235\"><b>new harvest</b></font> has arrived. Our "
        "<b>Arbequina</b> and <b>Picual</b> extra virgin olive oils were cold pressed in "
        "October, and this month they come with a special price:<br>'"
        "+'\u2022 Arbequina Extra Virgin Olive Oil, 500 ml: <s>9,80</s> "
        "<b><font color=\"#C00000\">8,82</font></b><br>'"
        "+'\u2022 Picual Extra Virgin Olive Oil, 1 l: <s>14,50</s> "
        "<b><font color=\"#C00000\">13,05</font></b>'",
        "'Write the code <font face=\"Courier New\"><b>HARVEST-10</b></font> in your next "
        "order before <b>31 December</b> and the <font color=\"#C00000\"><b>10% discount</b>"
        "</font> applies to the <i>whole</i> order: not only to the oils, but to the cheeses "
        "and the wines too.'",
        "'Kind regards,'",
    ]
    for text in paragraphs:
        # The space between paragraphs is above the text: a section that grows
        # keeps it
        sec = sub.section(SEC_DETAIL, 420, autoexpand=True)
        sec.expr(0, 160, WIDTH, 260, text, size=10, wordwrap=True, autoexpand=True, html=True)
    # The signature, and a new page for the next letter
    sign = sub.section(SEC_DETAIL, 900, skippage=True)
    sign.label(0, 300, 5000, 270, 'Laura Navarro', size=10, style=BOLD)
    sign.label(0, 570, 5000, 250, 'Sales Manager', style=ITALIC, color=GRAY)
    pf = sub.section(SEC_PFOOTER, 520)
    pf.rect(0, 80, WIDTH, 15, fill=LINE)
    pf.label(0, 190, WIDTH, 230, COMPANY + ' \u00b7 Muelle de Levante 12 \u00b7 08039 Barcelona '
             '\u00b7 VAT ES-B00000000', size=8, color=MIDGRAY, alignment=CENTER)
    return rep

SAMPLES = [
    ('fishes.rep', fishes),
    ('customers.rep', customers),
    ('invoices.rep', invoices),
    ('sales-by-category.rep', sales_by_category),
    ('product-catalog.rep', product_catalog),
    ('monthly-sales.rep', monthly_sales),
    ('labels.rep', labels),
    ('letter.rep', letter),
    ('international.rep', international),
]


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    folder = sys.argv[1]
    os.makedirs(folder, exist_ok=True)
    for filename, build in SAMPLES:
        path = os.path.join(folder, filename)
        with open(path, 'w', encoding='ascii', newline='') as f:
            f.write(build().xml())
        print('%s: %d bytes' % (path, os.path.getsize(path)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
