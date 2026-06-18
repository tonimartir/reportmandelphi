# Phase 6.0 — Documentation triage findings

Auto-generated from the multi-agent triage of 147 doc pages. Source: `C:/Users/admin/AppData/Local/Temp/2/claude/C--desarrollo-prog-toni-reportman/8717ce48-364e-40f5-aece-2d9daa55a5f3/tasks/w0jz2w38g.output`.

## Rollup

| Metric | Value |
|---|---|
| Pages triaged | 147 |
| Priority high / medium / low | 16 / 71 / 60 |
| Pages with typos (total typos) | 101 (445) |
| Pages with mojibake | 4 |
| Pages with obsolete refs (total) | 85 (264) |
| Pages with dead/legacy links (total) | 25 (47) |
| Weak/missing title | 72 |
| Weak/auto-generated description | 142 |

## A. Mojibake — encoding corruption (4 pages)

- `doc/doc/barcodes.html` — Barcode printing
- `doc/doc/bidi_behavior.html` — Delphi BiDi Behavior
- `doc/doc/refbarcode.html` — Common properties for TRpBarcode
- `doc/doc/license.html` — Report Manager License

## B. Dead / legacy external links (46 flagged across 25 pages)

| Page | href | Anchor | Reason | Recommendation |
|---|---|---|---|---|
| `index.html` | http://www.borland.com/delphi | Delphi | borland.com is a dead vendor host and uses non-https http:// | borland.com is gone -> point to docwiki.embarcadero.com (and use https) |
| `index.html` | http://www.borland.com/cppbuilder | Builder | borland.com is a dead vendor host and uses non-https http:// | borland.com is gone -> point to docwiki.embarcadero.com (and use https) |
| `features.html` | http://zeoslib.sourceforge.net | Zeos database objects | non-https http:// external link | switch to https |
| `interoperability.html` | http://www.geocities.com/rho_linux_br/k2oe-components-mini-howto/k2_pt_BR.html | Kylix Open Editions and FreeCLX | GeoCities was shut down in 2009; the host is dead, and the link is non-https http:// | remove (geocities is gone) |
| `success.html` | http://www.amnet.co.cr | http://www.amnet.co.cr | non-https http:// external link to a third-party testimonial host | switch to https or remove if dead |
| `success.html` | http://ahmedabad.sancharnet.in/vso_ad1/ | http://ahmedabad.sancharnet.in/vso_ad1/ | non-https http:// link to sancharnet.in, a long-defunct Indian ISP personal-page host (dead) | remove (sancharnet.in personal pages are gone) |
| `installwin.html` | http://sourceforge.net/projects/reportman | http://sourceforge.net/projects/reportman | Non-https external link to SourceForge | switch to https |
| `delphicomp.html` | http://sourceforge.net/projects/reportman | http://sourceforge.net/projects/reportman | Non-https external link to SourceForge | switch to https |
| `delphicomp.html` | http://www.indyproject.org | install Indy components | Non-https (indyproject http) external link | switch to https (https://www.indyproject.org) |
| `buildercomp.html` | http://sourceforge.net/projects/reportman | http://sourceforge.net/projects/reportman | Non-https external link to SourceForge | switch to https |
| `buildercomp.html` | http://bdn.borland.com/article/0,1410,29631,00.html | this article (http://bdn.borland.com/article/0,1410,29631,00.html) | Borland Developer Network is gone; URL is dead and non-https | borland.com is gone -> docwiki.embarcadero.com or remove |
| `buildercomp.html` | http://bdn.borland.com/article/0,1410,29638,00.html | this article (http://bdn.borland.com/article/0,1410,29638,00.html) | Borland Developer Network is gone; URL is dead and non-https | borland.com is gone -> docwiki.embarcadero.com or remove |
| `axtivexcomp.html` | http://sourceforge.net/projects/reportman | http://sourceforge.net/projects/reportman | Non-https external link to SourceForge | switch to https |
| `installlin.html` | http://sourceforge.net/projects/reportman | http://sourceforge.net/projects/reportman | Non-https external link to SourceForge | switch to https://sourceforge.net/projects/reportman |
| `otherlang.html` | http://wiki.rubyonrails.org/rails/pages/HowtoReportMan | Ruby on rails | The Ruby on Rails wiki (wiki.rubyonrails.org) was discontinued years ago; this page is dead. Also non-https. | rubyonrails wiki discontinued -> remove the link (or replace with a current Ruby integration reference) |
| `visualnetcomp.html` | http://sourceforge.net/projects/reportman | http://sourceforge.net/projects/reportman | Non-https external link to SourceForge | switch to https://sourceforge.net/projects/reportman |
| `kylixcomp.html` | http://sourceforge.net/projects/reportman | http://sourceforge.net/projects/reportman | Non-https external link to SourceForge | switch to https://sourceforge.net/projects/reportman |
| `installwebreport.html` | http://plugindoc.mozdev.org/en-AU/windows.html | for Mozilla | mozdev.org/plugindoc was shut down long ago; dead host, also non-https | remove the dead Mozilla plugin link |
| `installwebreport.html` | http://www.iol.ie/%7Elocka/mozilla/plugin.htm | http://www.iol.ie/~locka/mozilla/plugin.htm | Abandoned personal ISP homepage (iol.ie); dead, non-https | remove the dead link |
| `installwebreport.html` | http://reportman.dnsalias.net/reportmanserver/reportman.htm | Click here | Old dynamic-DNS demo host (dnsalias.net), no longer reachable; non-https | remove or point to a current reportman.es demo |
| `python_bind.html` | http://wxwidgets.org/newlicen.htm | http://wxwidgets.org/newlicen.htm | non-https external link to an old wxWidgets license page that no longer exists at this path | switch to https and update to current wxWidgets license URL (https://www.wxwidgets.org/about/licence/) |
| `python_bind.html` | http://starship.python.net/crew/theller/ctypes/index.html | http://starship.python.net/crew/theller/ctypes/index.html | non-https link to the abandoned starship.python.net ctypes page; ctypes is now part of the Python standard library and this host is dead | remove or replace with https://docs.python.org/3/library/ctypes.html |
| `python_bind.html` | file:///C\|/python23/lib/site-packages/reportman.py | c:\python23\lib\site-packages\reportman.py | local file:// link to a Python 2.3 site-packages path on the original author's machine; not a valid web target | remove the file:// link (leave as plain text or drop) |
| `webserverintro.html` | http://localhost:8080/admin/login | http://localhost:8080/admin/login | Plain http:// link (localhost example, but rendered as a clickable http link) | Acceptable as a localhost example; if flagged, present as non-clickable code rather than an http link |
| `webserverinstall.html` | http://localhost/cgi-bin/repwebserver.dll/version | http://localhost/cgi-bin/repwebserver.dll/version | Plain http:// localhost example link | Acceptable as a localhost example; present as code rather than a clickable http link if flagged |
| `webserverinstall.html` | http://localhost/cgi-bin/repwebserver.dll/login | http://localhost/cgi-bin/repwebserver.dll/login | Plain http:// localhost example link | Acceptable as a localhost example; present as code rather than a clickable http link if flagged |
| `webserveroperations.html` | http://localhost/cgi-bin/repwebserver.dll/login | http://localhost/cgi-bin/repwebserver.dll/login | Plain http:// localhost example link | Acceptable as a localhost example; present as code rather than a clickable http link if flagged |
| `webserveroperations.html` | http://localhost/cgi-bin/repwebserver.dll/version | http://localhost/cgi-bin/repwebserver.dll/version | Plain http:// localhost example link | Acceptable as a localhost example; present as code rather than a clickable http link if flagged |
| `webserveroperations.html` | http://localhost/cgi-bin/repwebexe.bin/version | http://localhost/cgi-bin/repwebexe.bin/version | Plain http:// localhost example link | Acceptable as a localhost example; present as code rather than a clickable http link if flagged |
| `teechart.html` | http://www.steema.com | Steema corporation | Non-https external link to vendor site | switch to https (https://www.steema.com) |
| `openingdatatrouble.html` | http://open-dbexpress.sourceforge.net | http://open-dbexpress.sourceforge.net | non-https external link to an abandoned SourceForge project | switch to https and verify the project still exists, otherwise remove |
| `openingdatatrouble.html` | http://zeoslib.sourceforge.net | Zeos library | non-https external link | switch to https (https://zeoslib.sourceforge.io) |
| `openingdatatrouble.html` | http://www.ibobjects.com | http://www.ibobjects.com | non-https external link (plain text, not a real anchor) | switch to https |
| `openingdatatrouble.html` | http://sourceforge.net/projects/firebird | http://sourceforge.net/projects/firebird | non-https external link | switch to https |
| `openingdatatrouble.html` | http://www.ibaccess.org | http://www.ibaccess.org | non-https external link to a likely-dead vendor page | switch to https and verify, otherwise remove |
| `refdatabaseinfo.html` | http://zeoslib.sourceforge.net | Zeos library | Non-https (http://) external link to a SourceForge project page | switch to https (https://zeoslib.sourceforge.net) and verify the project is still maintained |
| `licensequestions.html` | http://reportman.es | http://reportman.es | Non-https URL written in body text for the current project site | switch to https (https://reportman.es) |
| `building.html` | http://www.borland.com/delphi | Delphi 6/7 Professional | borland.com product pages are gone (Borland was absorbed by Embarcadero/Idera) and the link is non-https | borland.com is gone -> point to https://www.embarcadero.com / docwiki.embarcadero.com |
| `building.html` | http://www.borland.com/kylix | Kylix 2/3 Professional | borland.com Kylix page is dead; Kylix is discontinued and link is non-https | borland.com is gone; Kylix discontinued -> remove or mark legacy |
| `building.html` | http://www.innosetup.com | InnoSetup | Non-https; canonical site is jrsoftware.org | switch to https://jrsoftware.org/isinfo.php |
| `building.html` | http://www.wincvs.org | CVS | Non-https and WinCVS project is effectively abandoned; project moved off CVS | remove / replace with current Git repository link |
| `pdfoutput.html` | http://freetype.sourceforge.net | freetype library | Non-https and stale host; FreeType project now lives at freetype.org | switch to https://freetype.org |
| `whatisnew.html` | http://zeoslib.sourceforge.net | Zeos library | non-https external link to an old project host | switch to https |
| `whatisnew.html` | http://www.delphi-jedi.org | Project Jedi Alliance | non-https external link | switch to https (https://www.delphi-jedi.org) |
| `knownissues.html` | http://www.trolltech.com/developer/changes/3.0.5.html | kwown bug of Qt Libraries | non-https link to trolltech.com, a defunct vendor domain (now Qt; old developer/changes URL is dead) | remove or repoint to qt.io changelog; trolltech.com is gone |
| `knownissues.html` | http://www.trolltech.com/developer/changes/3.0.5.html | kwown bug of Qt Libraries | second occurrence of the same dead non-https trolltech.com link | remove or repoint to qt.io changelog; trolltech.com is gone |

## C. Obsolete technology references (264 across 85 pages)

### By kind

| Kind | Total | keep-historical | reword | remove |
|---|---|---|---|---|
| other | 42 | 25 | 17 | 0 |
| clx | 40 | 30 | 10 | 0 |
| kylix | 37 | 20 | 17 | 0 |
| delphi-old | 34 | 23 | 11 | 0 |
| qt | 28 | 19 | 9 | 0 |
| borland | 22 | 9 | 13 | 0 |
| activex-plugin | 19 | 18 | 1 | 0 |
| bde | 16 | 15 | 1 | 0 |
| dbexpress-old | 14 | 13 | 1 | 0 |
| ie-plugin | 5 | 3 | 2 | 0 |
| openoffice-aside | 4 | 4 | 0 | 0 |
| yahoo-groups | 2 | 0 | 0 | 2 |
| boxed-product | 1 | 0 | 1 | 0 |

### Detail (rec = remove or reword first)

| Page | Kind | Rec | Snippet |
|---|---|---|---|
| `faq.html` | yahoo-groups | remove | You should use the reportman group at yahoo groups |
| `faq.html` | yahoo-groups | remove | use reportman group at yahoo groups for this tasks |
| `index.html` | ie-plugin | reword | ActiveX plugin allows embedding the preview and print in a Microsoft Internet Explorer |
| `index.html` | delphi-old | reword | New: Delphi 10.4.2 for .Net support. |
| `index.html` | boxed-product | reword | Boxed product and other services available for purchase. |
| `requirements.html` | other | reword | Report Manager works in all current Microsoft OS, Win98,Windows Millenium, Windows NT, Windows 2000, Windows XP |
| `requirements.html` | kylix | reword | To compile Report Manager you need Delphi, C++Builder in Microsoft Windows or Kylix in Linux. |
| `requirements.html` | qt | reword | Report Manager Designer uses Qt library widgets under X Window System |
| `requirements.html` | other | reword | shfolder.dll, shlwapi.dll system files provided by Internet Explorer 5 or better, Windows 2000, Millenium and XP already |
| `requirements.html` | other | reword | can be fast enought using a old Pentium 75 machine |
| `requirements.html` | other | reword | glibc 2.2 or better, jpeg library |
| `features.html` | kylix | reword | Cross platform supporting Windows and Linux (Kylix/Delphi/C++Builder) |
| `features.html` | delphi-old | reword | Supports Delphi 5E-6PE-7PE-8-XE 10.4, Kylix 2-3 (deprecated),C++Builder 4E |
| `features.html` | qt | reword | Driver selection when designing the report (Qt driver or Windows GDI driver) |
| `interoperability.html` | borland | reword | Database connections abstraction is done throught dbxconnections.ini and dbxdrivers.ini files provided by Report Manager |
| `installwin.html` | delphi-old | reword | if you are using NT technology (WNT,W2000,WXP) |
| `installwin.html` | delphi-old | reword | control panel and add/remove software |
| `installwin.html` | other | reword | Documents & Settings\Local Config\All Users\reporman.ini |
| `delphicomp.html` | other | reword | you must upgrade to latest version 9 |
| `delphicomp.html` | borland | reword | just like other Borland packages |
| `buildercomp.html` | borland | reword | just like other Borland packages |
| `deploy.html` | delphi-old | reword | Distribute the .manifest file of the executables so they will look with the XP theme |
| `deploy.html` | delphi-old | reword | Service application for Windows NT Systems and upper |
| `installlin.html` | qt | reword | issues with Borland provided qt libraries |
| `installlin.html` | borland | reword | /home/yourusername/.borland directory |
| `kylixcomp.html` | borland | reword | just like other Borland packages |
| `installserver.html` | other | reword | If you are running Windows 98/Me you can add a shortcut |
| `installserver.html` | other | reword | If you are running Windows NT/2000/XP you can install the server as a service |
| `webserverinstall.html` | borland | reword | /home/username/.borland directory |
| `webserverinstall.html` | kylix | reword | place this libs (provided with the report designer) in /opt/kylixlibs directory |
| `webserverinstall.html` | kylix | reword | SetEnv KYLIX_DEFINEDENVLOCALES yes / KYLIX_THOUSAND_SEPARATOR ... |
| `webserverinstall.html` | other | reword | in Suse 7.3, is /usr/local/httpd/cgi-bin |
| `webserverinstall.html` | other | reword | You will find the html original files (models) in the cvs development tree |
| `openingdata.html` | kylix | reword | if you are using Delphi/Kylix/Builder development enviroments |
| `pagesetup.html` | kylix | reword | before printing you can switch language from Report Manager Designer and Report Manager components in Delphi/Kylix/Build |
| `pagesetup.html` | other | reword | you can install the ps2ascii as a filter in your printer spooler. If you have some sample of doing it, please e-mail me |
| `preferences.html` | delphi-old | reword | the widget appearance is the same as Windows 9x/NT/Millenium/2000 |
| `usingcompo.html` | kylix | reword | Using report components in Delphi/Kylix/Builder |
| `commandline.html` | ie-plugin | reword | the native format can be viewed with metaview or Internet explorer plugin |
| `replibraries.html` | kylix | reword | Delphi/Bulider/Kylix components support also report libraries from the IDE |
| `barcodes.html` | qt | reword | In Linux, the qt library (version 2.3) have only a resolution of 100dpi |
| `teechart.html` | kylix | reword | you can't use the Report Manager engine without an X Server running in Linux |
| `internatsupport.html` | qt | reword | linux is also supported via Qt libraries |
| `internatsupport.html` | other | reword | Generation of PDF files is not implemented for WideString languages |
| `compsiterep.html` | clx | reword | Using composite reports with VCL/CLX components |
| `openingdatatrouble.html` | borland | reword | Borland newsgroups about dbexpress |
| `openingdatatrouble.html` | borland | reword | Borland newsgroups about BDE |
| `openingdatatrouble.html` | other | reword | you should download the ODBC driver update from Microsoft web site |
| `htmloutput.html` | other | reword | font sizes represented by Internet explorer, some lines may overwrite |
| `htmloutput.html` | other | reword | similar to Internet Explorer font rendering |
| `refimage.html` | clx | reword | Windows QT / Linux QT / TCLXReport columns in the supported image formats table |
| `refimage.html` | kylix | reword | by calling from Delphi/Builder/Kylix source code the RegisterGraphicFileFormat function |
| `refchart.html` | kylix | reword | Default driver will get TeeChart in Windows and Native in Linux (to avoid Qt libs dependence and because it's not includ |
| `refdatabaseinfo.html` | clx | reword | CLX/VCLReport property: Report.DatabaseInfo |
| `refdatainfo.html` | clx | reword | CLX/VCLReport property: Report.DatabaseInfo |
| `refparameters.html` | clx | reword | CLX/VCLReport property: Report.Params |
| `refreport.html` | clx | reword | CLX/VCLReport property: Report |
| `building.html` | delphi-old | reword | Delphi 6/7 Professional |
| `building.html` | kylix | reword | Kylix 2/3 Professional ... FreeCLX |
| `building.html` | other | reword | CVS to obtain the source also SSH |
| `building.html` | delphi-old | reword | repman\reportman.bpg / reportmanxp.bpg |
| `building.html` | qt | reword | Qt dependent and Pure VCL ... marqued here as xp |
| `building.html` | borland | reword | with borland make in the path |
| `devdriver.html` | clx | reword | TRpQtDriver / rpqtdriver / TCLXReport |
| `devdriver.html` | other | reword | rpexceldriver |
| `devdriver.html` | qt | reword | metaview in Linux (QtDriver) |
| `devdriver.html` | activex-plugin | reword | ActiveX control plugin |
| `units.html` | clx | reword | and Visual CLX package |
| `left2.html` | kylix | reword | Kylix (installation link) |
| `faq.html` | delphi-old | reword | Delphi 4,5 Enterprise. Delphi 6 Professional ... Delphi 7 |
| `faq.html` | borland | reword | C++Builder 4,5 Enterprise. C++Builder 6 ... |
| `faq.html` | kylix | reword | Kylix 1,2,3 Desktop and Enterprise ... FreeCLX |
| `faq.html` | borland | reword | linked inside the executable or as a Borland package |
| `faq.html` | borland | reword | Any Delphi/C++Builder version accepting ActiveX controls (Borland personal editions) |
| `mfeatures.html` | borland | reword | Add Borland .Net data providers and Microsoft .Net data providers |
| `doc/tutorial/index.html` | bde | reword | If you select the BDE driver the BDE alias is the connection name |
| `doc/tutorial/index.html` | dbexpress-old | reword | if you select DBExpress you must select a DBExpress connection |
| `doc/tutorial/testing.html` | kylix | reword | integrate the reporting engine in your delphi/kylix application |
| `doc/tutorial/integrating.html` | kylix | reword | Integrating into the application with delphi/kylix |
| `doc/tutorial/integrating.html` | clx | reword | the TCLXReport component |
| `doc/tutorial/integrating.html` | clx | reword | Drop the TNewCLXReport to a form |
| `doc/tutorial/integrating.html` | kylix | reword | refer to documentation in Kylix and Delphi |
| `units/rpclxreport.html` | qt | reword | uses the TRpGDIDriver (Windows only), TRpQtDriver and TRpPDFDriver print drivers |
| `units/rpclxreport.html` | qt | reword | In Windows you can select the TRpQtDriver with the driver property |
| `units/rpmdshfolder.html` | delphi-old | reword | compatible with Windows 2000 and Linux |
| `index.html` | activex-plugin | keep-historical | development enviroment accepting ActiveX controls (Visual Basic,Visual FoxPro...) |
| `index.html` | kylix | keep-historical | If you are using Delphi/Kylix/Builder, you can include the reporting engine in your executables |
| `features.html` | ie-plugin | keep-historical | Report Manager Internet explorer plugin (deprecated) |
| `features.html` | bde | keep-historical | Windows: Borland database engine (DBase, Paradox, Interbase, Oracle, DB2, SQL Server, ODBC) |
| `features.html` | dbexpress-old | keep-historical | Windows & Linux: DBExpress (Interbase, MySQL, PostgreSQL, DB2, Oracle,DB2,Informix, ODBC) |
| `features.html` | other | keep-historical | Windows: Microsoft Data Access Objects (Microsoft Jet, ODBC...) |
| `features.html` | other | keep-historical | Exports to Excel (Windows), CSV file or plain text file |
| `interoperability.html` | delphi-old | keep-historical | Delphi 4/5 Enterprise, Delphi 6/7 Prof. , Ent., Architech. |
| `interoperability.html` | kylix | keep-historical | Kylix 1/2/3 Desktop, Pro or Enterprise |
| `interoperability.html` | delphi-old | keep-historical | Delphi 8 for .Net |
| `interoperability.html` | clx | keep-historical | It's reported to work with Kylix Open Editions and FreeCLX |
| `success.html` | bde | keep-historical | succesfull migration from Paradox under BDE and Crystal Reports to a new application using FireBird under IBX |
| `success.html` | kylix | keep-historical | we develop in Delphi 7 / Kylix 3 and use RM v1.6. , INTERBASE v6 on linux server. Win98/2000 and Linux RedHat/Mandrake |
| `installwin.html` | borland | keep-historical | If you have installed Borland Delphi6 /C++Builder 6 product before, Report Manager will use Borland database connection  |
| `installwin.html` | dbexpress-old | keep-historical | HKEY_LOCAL_MACHINE\SOFTWARE\Borland\DBExpress |
| `delphicomp.html` | delphi-old | keep-historical | Delphi 5 ... rppack_del5.dpk |
| `delphicomp.html` | delphi-old | keep-historical | Delphi 6/7 ... rppack_del.dpk |
| `delphicomp.html` | delphi-old | keep-historical | Delphi 2005 ... rppack_del2005.bsdproj |
| `delphicomp.html` | delphi-old | keep-historical | Delphi 2009 ... rppack_del2009.bsdproj |
| `delphicomp.html` | clx | keep-historical | Visual CLX package, for cross platform development |
| `buildercomp.html` | delphi-old | keep-historical | Builder 4 ... rppack_builder4.bpk |
| `buildercomp.html` | delphi-old | keep-historical | Builder 6 ... rppack_builder6.bpk |
| `buildercomp.html` | clx | keep-historical | Visual CLX package, for cross platform development |
| `buildercomp.html` | qt | keep-historical | the GDI driver is never used, only Qt printing is available |
| `buildercomp.html` | qt | keep-historical | known problems using qt library wrappers, and QPrinter ... install a updated qtintf.dll library |
| `axtivexcomp.html` | activex-plugin | keep-historical | use the Report Manager ActiveX to generate the pdf inside a ASP page |
| `axtivexcomp.html` | other | keep-historical | developed under W/98 and runs under the Windows Scripting Host (WSH) |
| `axtivexcomp.html` | other | keep-historical | later viewed with the Adobe Acrobat Reader |
| `axtivexcomp.html` | other | keep-historical | Microsoft Transaction Server Object |
| `axtivexcomp.html` | other | keep-historical | SaveToExcel(const filename: String); // Needs Excel installation |
| `compileropts.html` | kylix | keep-historical | compiling Report Manager engine with Delphi/Builder/Kylix |
| `compileropts.html` | bde | keep-historical | USEBDE ... Allow the use of Borland Database Engine and also the SQL Links technology |
| `compileropts.html` | dbexpress-old | keep-historical | USESQLEXPRESS ... Allow the use of all DBExpress drivers |
| `compileropts.html` | other | keep-historical | USEIBO ... Jason Wharton's Interbase Objects |
| `compileropts.html` | delphi-old | keep-historical | if you define USESQLEXPRESS but Delphi 5 compiler version is found the define will be disabled |
| `deploy.html` | kylix | keep-historical | libborqtintf-6.9-qt2.3.so ... Interface to QT libs. (Kylix 3) |
| `deploy.html` | kylix | keep-historical | QT Linux libs and Windows qt libs and interface to qtlibs (Kylix 2) |
| `deploy.html` | other | keep-historical | libmidas.so.1 ... Database cached dataset and MyBase driver |
| `deploy.html` | dbexpress-old | keep-historical | Deployment of dbexpress drivers |
| `deploy.html` | bde | keep-historical | If you use BDE driver you must deploy the entire BDE with the sqllinks dlls |
| `deploy.html` | clx | keep-historical | Visual CLX applications |
| `deploy.html` | qt | keep-historical | qtintf70.dll (Delphi 7) or qtintf.dll (Delphi 6) |
| `deploy.html` | borland | keep-historical | qt runtime files provided by Borland since Kylix 3 |
| `installlin.html` | dbexpress-old | keep-historical | 'dbxdrivers' and 'dbxconnections' files |
| `installlin.html` | other | keep-historical | enable, by default, the use of kprinter to print reports |
| `delphinetcomp.html` | delphi-old | keep-historical | Compiling and using Report Manager from Delphi for .Net |
| `kylixcomp.html` | kylix | keep-historical | Compiling Report Manager using Kylix |
| `kylixcomp.html` | clx | keep-historical | Visual CLX package, for cross platform development |
| `kylixcomp.html` | other | keep-historical | if you disable ADO support you can remove adortl dependence |
| `installwebreport.html` | ie-plugin | keep-historical | WebReportManX control is a plugin for Windows Internet Explorer |
| `installwebreport.html` | activex-plugin | keep-historical | enable installation of unsigned ActiveX controls option in Internet Explorer |
| `installwebreport.html` | activex-plugin | keep-historical | In Winfows XP Service Pack #2, the installation of plugins have limited to certificates |
| `gnuc.html` | borland | keep-historical | Borland C++ command line compiler, Borland Delphi |
| `gnuc.html` | qt | keep-historical | libreportmanapiqt.so (qt dependence, X-Server need) |
| `gnuc.html` | clx | keep-historical | In some linux distros you must define the CLX_USE_LIBQT=true enviroment variable |
| `gnuc.html` | activex-plugin | keep-historical | In Microsoft Windows the functions are inside Reportman.ocx library |
| `php.html` | other | keep-historical | cgi-bin/repwebexe.bin/execute.pdf |
| `python.html` | activex-plugin | keep-historical | in Microsoft Windows you can use the ActiveX control after registering it |
| `python.html` | activex-plugin | keep-historical | report = win32com.client.Dispatch("ReportMan.ReportManX") |
| `python_bind.html` | activex-plugin | keep-historical | This module implements python bindings to the ReportMan ActiveX control. |
| `python_bind.html` | activex-plugin | keep-historical | Implements wrapper class around Report Manager ActiveX control. |
| `javascript.html` | other | keep-historical | a copy of repwebserver.dll in the directory /cgi-bin |
| `serverintro.html` | other | keep-historical | you can install the report server in a linux machine and execute report client in MS Windows machines or vice-versa |
| `serverclient.html` | qt | keep-historical | libborqtint.6.9.so |
| `serverclient.html` | kylix | keep-historical | metaview, metaview.sh, libborqtint.6.9.so |
| `serverclientcustom.html` | clx | keep-historical | TVCLReport-TCLXReport-TPDFReport components |
| `serversmp.html` | other | keep-historical | It also supports intel hyperthreading technology |
| `serversmp.html` | other | keep-historical | the ISAPI module (repwebserver.dll) |
| `webserverinstall.html` | other | keep-historical | Compatibility: PassEnv is only available in Apache 1.1 and later |
| `openingdata.html` | dbexpress-old | keep-historical | we will use DBExpress driver to connect througth Interbase/Firebird |
| `preferences.html` | clx | keep-historical | you can select to print using Qt/CLX library or GDI/VCL library |
| `preferences.html` | clx | keep-historical | the same result as using TCLXDriver |
| `preferences.html` | clx | keep-historical | Needs ghostcript in Linux |
| `preferences.html` | qt | keep-historical | Qt System print dialog |
| `usingcompo.html` | clx | keep-historical | TCLXDriver ... Report preview and printing for cross platform CLX applications |
| `usingcompo.html` | delphi-old | keep-historical | compatibility columns D6D7/B6, K2/K3, D5/B4 |
| `usingcompo.html` | clx | keep-historical | preview/print reports using cross platform CLX library in Delphi 6/C++Builder 6 and Kylix 2 |
| `repparams.html` | kylix | keep-historical | From Delphi/Kylix/Builder you can evaluate this expression |
| `repparams.html` | kylix | keep-historical | Using parameters from Delphi/Builder/Kylix/ActiveX |
| `repparams.html` | clx | keep-historical | CLXReport1.Report.Evaluator.EvaluateText |
| `repparams.html` | clx | keep-historical | VCL/CLX Components |
| `repparams.html` | dbexpress-old | keep-historical | For DBExpress also DriverName, VendorLib,LibraryName,GetDriverFunc |
| `repparams.html` | bde | keep-historical | Note: With the BDE driver you can link Tables |
| `linkedquerys.html` | bde | keep-historical | Note: With the BDE driver you can link Tables by selecting the correct IndexFields and Master Fields properties like you |
| `labels.html` | clx | keep-historical | CLXReport1.Execute; |
| `exevaluator.html` | kylix | keep-historical | Using the expression evaluator in Delphi/Kylix/Builder |
| `exevaluator.html` | delphi-old | keep-historical | like using variant type in object pascal language |
| `teechart.html` | kylix | keep-historical | TeeChart is not provided in Kylix |
| `teechart.html` | clx | keep-historical | the engine uses VCL TeeChart version in Windows (Delphi), and CLX version in Kylix |
| `teechart.html` | kylix | keep-historical | it's also available for Kylix |
| `bidi_behavior.html` | delphi-old | keep-historical | The table reflects the behavior of Delphi's VCL controls, and uses Delphi's terminology for BiDiMode settings |
| `compsiterep.html` | activex-plugin | keep-historical | Using composite reports with ActiveX components |
| `openingdatatrouble.html` | dbexpress-old | keep-historical | DBExpress is a technology introduced by Borland since the release of Delphi 6 |
| `openingdatatrouble.html` | bde | keep-historical | Borland Database Engine ... have been updated until Delphi 6 |
| `openingdatatrouble.html` | kylix | keep-historical | compilation (Kylix/Builder/Delphi) modify the rpconf.inc file |
| `openingdatatrouble.html` | other | keep-historical | Getting to work all databases and database drivers in Suse 9.0 |
| `inmemorydata.html` | borland | keep-historical | created by TClientDataset component from Borland tools |
| `parallel.html` | bde | keep-historical | DBDEMOS connection (Borland database engine) |
| `refcommon.html` | other | keep-historical | url:http://mydomain.com, will provide a link in PDF output |
| `refcommontext.html` | qt | keep-historical | the driver uses system fonts, usually GDI and Qt |
| `refcommontext.html` | qt | keep-historical | but Qt library does not implement RightToLeft so in Linux is partially supported |
| `refchart.html` | openoffice-aside | keep-historical | the drivers not supporting charts are Excel and Plain Text driver |
| `refbarcode.html` | openoffice-aside | keep-historical | the drivers not supporting drawing and filling rects, that is the Excel and Plain text driver |
| `refdatabaseinfo.html` | bde | keep-historical | BDE: The alias must coincide with an existent Borland Database Engine Alias |
| `refdatabaseinfo.html` | bde | keep-historical | The Borland Database Engine must be installed in the client machine ... if the BDE also have SQL Links available |
| `refdatabaseinfo.html` | dbexpress-old | keep-historical | DBExpress: The configuration is read from dbxconnections file, using Borland conventions |
| `refdatabaseinfo.html` | delphi-old | keep-historical | Interbase Express is a Borland library ... IBO ... commercial product from Jason Wharton ... modify rpconf.inc file |
| `refdatabaseinfo.html` | borland | keep-historical | ADO is a native Borland interface to Microsoft Database Objects |
| `refdatabaseinfo.html` | kylix | keep-historical | compile IBO with the engine ... (Kylix/Builder/Delphi) modify the rpconf.inc file |
| `refdatainfo.html` | bde | keep-historical | BDE Driver: The BDE Alias |
| `refdatainfo.html` | dbexpress-old | keep-historical | DbExpress: DBExpress connection name |
| `refdatainfo.html` | activex-plugin | keep-historical | ActiveX Report property: Available only by ActiveX interface |
| `refparameters.html` | activex-plugin | keep-historical | ActiveX Report property: Available only by ActiveX interface |
| `refreport.html` | activex-plugin | keep-historical | ActiveX Report property: Not available |
| `refreport.html` | qt | keep-historical | PageSizeQt ... This is the page size standard index in the Qt library sequence |
| `licensequestions.html` | dbexpress-old | keep-historical | A commercial DBExpress database driver |
| `licensequestions.html` | delphi-old | keep-historical | installable on the Delphi component palete |
| `building.html` | delphi-old | keep-historical | Delphi 5/Builder 4 (MSDOS style line ends) |
| `devdriver.html` | openoffice-aside | keep-historical | Printing from Openoffice ... Exporting from OpenOffice to PDF |
| `devdriver.html` | borland | keep-historical | forget to get it to work in Linux at least until Borland upgrades to Qt 3 |
| `pdfoutput.html` | openoffice-aside | keep-historical | Applications like OpenOffice take the font information ... |
| `pdfoutput.html` | other | keep-historical | True type font linking and embedding is available from version 2.2 |
| `units.html` | qt | keep-historical | rpqtdriver.pas |
| `units.html` | clx | keep-historical | rpclxreport.pas |
| `units.html` | activex-plugin | keep-historical | rpactivex.pas / rpaxreportimp.pas |
| `devnotes.html` | delphi-old | keep-historical | why Delphi 5 enterprise version at least need |
| `devnotes.html` | borland | keep-historical | Borland changes in TFiler in Delphi 6 and up |
| `devnotes.html` | clx | keep-historical | The Open/Save dialog Windows CLX bug since Delphi 7 |
| `devnotes.html` | delphi-old | keep-historical | the application will crash (Win9x) ... only in Win9x systems |
| `license.html` | other | keep-historical | Netscape Communications Corporation may publish revised ... versions of the License |
| `left2.html` | activex-plugin | keep-historical | Active X (installation link) |
| `whatisnew.html` | delphi-old | keep-historical | compiled with Delphi for .Net |
| `whatisnew.html` | borland | keep-historical | Borland C++ Builder 6 support |
| `whatisnew.html` | kylix | keep-historical | Kylix (KDE integration REPMANUSEKPRINTER) |
| `whatisnew.html` | ie-plugin | keep-historical | ActiveX Internet explorer plugin |
| `whatisnew.html` | other | keep-historical | track changes in your reports with cvs |
| `whatisnew.html` | other | keep-historical | Excel export support for Microsoft Windows |
| `whatisnew.html` | bde | keep-historical | BDE / DBExpress / DAO driver mentions in old version notes |
| `faq.html` | other | keep-historical | Visual C++, Visual Basic, Visual Foxpro |
| `faq.html` | bde | keep-historical | BDE should detect opened aliases |
| `faq.html` | delphi-old | keep-historical | Why Report Manager needs TClientDataset class? ... Delphi 5 Professional or lower can not be used |
| `faq.html` | clx | keep-historical | some VisualCLX components are thread safe ... VisualCLX components in the main thread |
| `faq.html` | qt | keep-historical | Report Manager uses the Kylix graphic engine that uses the Qt graphic engine |
| `faq.html` | activex-plugin | keep-historical | Why does my Active Server Page freeze when using the ActiveX control? |
| `knownissues.html` | kylix | keep-historical | some generated Kylix generated applications don't work correctly in some Linux distros |
| `knownissues.html` | kylix | keep-historical | export CLX_USE_LIBQT=true ... libborqt.so (Kylix 2/3) |
| `knownissues.html` | borland | keep-historical | copy dbxdrivers ... to /home/yourusername/.borland directory |
| `knownissues.html` | qt | keep-historical | This issue only affects the Qt Driver (CLX) in Windows systems |
| `knownissues.html` | qt | keep-historical | kwown bug of Qt Libraries ... fixed in 3.0.5 |
| `knownissues.html` | kylix | keep-historical | Report Manager uses the Kylix graphic engine ... KYLIX_PRINTBUG |
| `knownissues.html` | delphi-old | keep-historical | Access violation passing runtime linked querys ... using Delphi 7 |
| `knownissues.html` | other | keep-historical | Connecting to Oracle 9i databases ... 8.1.7 Oracle version |
| `knownissues.html` | bde | keep-historical | this bug seems to be reproduced only with ADO and BDE drivers |
| `knownissues.html` | dbexpress-old | keep-historical | This problem appear in Interbase dbexpress driver, use IBX driver instead |
| `knownissues.html` | other | keep-historical | Connecting to MySQL from ADO/ODBC ... MyODBC configuration |
| `mfeatures.html` | delphi-old | keep-historical | compile with Professional versions of Delphi 4/5 and Builder 4/5 |
| `mfeatures.html` | delphi-old | keep-historical | Removing the TClientDataset dependence |
| `units/rpactivexreport.html` | activex-plugin | keep-historical | the base class for the ActiveX control |
| `units/rpaxreportimp.html` | activex-plugin | keep-historical | report Manager ActiveX control, based on TRpActiveXReport |
| `units/rpclxreport.html` | clx | keep-historical | palette installable TCLXReport component |
| `units/rpcompobase.html` | kylix | keep-historical | Delphi/Builder/Kylix palette installable report components |
| `units/rpcompobase.html` | clx | keep-historical | for each driver and platform (TVCLReport,TPDFReport,TCLXReport) |
| `units/rpdatainfo.html` | bde | keep-historical | applicable only to Borland Database Engine datasets |
| `units/rpdatainfo.html` | dbexpress-old | keep-historical | load configuration from DBExpress configuration files, used by DBExpress, IBX, IBO... |
| `units/rpexpredlg.html` | clx | keep-historical | CLX expression build wizard dialog |
| `units/rpgdidriver.html` | qt | keep-historical | TFRpQtProgress |
| `units/rpgdidriver.html` | qt | keep-historical | procedure PageSizeSelection (rpPageSize:TPageSizeQt); |
| `units/rpgraphutils.html` | clx | keep-historical | CLX graphic functions and standard message dialog |
| `units/rpgraphutils.html` | qt | keep-historical | load qt library resource strings |
| `units/rppagesetup.html` | clx | keep-historical | CLX page setup and print setup dialog |
| `units/rppreview.html` | clx | keep-historical | CLX applications preview |
| `units/rppreview.html` | qt | keep-historical | uses the TRpQtDriver component |
| `units/rpqtdriver.html` | qt | keep-historical | QT print driver for Windows and Linux |
| `units/rpqtdriver.html` | clx | keep-historical | Qt print driver print driver using CLX library |
| `units/rprfparams.html` | clx | keep-historical | CLX applications user parameters window |
| `units/rpruler.html` | clx | keep-historical | CLX ruler drawing |
| `units/rptypes.html` | qt | keep-historical | page selection when using the Qt driver |
| `units/rpvgraphutils.html` | clx | keep-historical | CLX to GDI conversion routines |
| `units/rpvgraphutils.html` | clx | keep-historical | functions implemented by the CLX library but not in VCL |

## D. Typos — 302 unique misspellings (445 total occurrences)

| wrong | correct | # pages | pages |
|---|---|---|---|
| diferent | different | 15 | installlin.html, visualnetcomp.html, serverclient.html, webserverinstall.html, webserveroperations.html, repparams.html, labels.html, exevaluator.html, +7 |
| sumary | summary | 14 | webserverinstall.html, refcommon.html, refcommontext.html, refsubreport.html, refsection.html, reflabel.html, refexpression.html, refdraw.html, +6 |
| throught | through | 9 | interoperability.html, openingdata.html, droppingfields.html, repparams.html, dotmatrix.html, openingdatatrouble.html, refsection.html, refimage.html, +1 |
| enviroment | environment | 8 | index.html, requirements.html, axtivexcomp.html, deploy.html, gnuc.html, translation.html, faq.html, knownissues.html |
| inchess | inches | 8 | features.html, preferences.html, dotmatrix.html, refcommon.html, refcommontext.html, refchart.html, refreport.html, units/rpmunits.html |
| querys | queries | 7 | dotnetport.html, serverintro.html, serversmp.html, childsubreports.html, openingdatatrouble.html, inmemorydata.html, knownissues.html |
| dependences | dependencies | 6 | delphicomp.html, visualnetcomp.html, teechart.html, openingdatatrouble.html, building.html, devdriver.html |
| recomended | recommended | 5 | requirements.html, serversmp.html, exevaluator.html, openingdatatrouble.html, knownissues.html |
| architechture | architecture | 5 | serversmp.html, refimage.html, refchart.html, refbarcode.html, devdriver.html |
| usefull | useful | 5 | webserveroperations.html, commandline.html, repparams.html, openingdatatrouble.html, refexpression.html |
| enhacements | enhancements | 4 | index.html, licensequestions.html, whatisnew.html, faq.html |
| aditional | additional | 4 | features.html, refimage.html, refchart.html, refbarcode.html |
| proces | process | 4 | deploy.html, devdriver.html, faq.html, units/rpmetafile.html |
| prefered | preferred | 4 | dotnetport.html, pagesetup.html, repparams.html, formfilling.html |
| wich | which | 4 | pagesetup.html, openingdatatrouble.html, refexpression.html, faq.html |
| enhace | enhance | 4 | inmemorydata.html, refsection.html, refimage.html, licensequestions.html |
| writting | writing | 3 | features.html, knownissues.html, units/rptranslator.html |
| clic | click | 3 | installwin.html, droppingfields.html, parallel.html |
| dependeces | dependencies | 3 | delphicomp.html, buildercomp.html, kylixcomp.html |
| projetcs | projects | 3 | delphicomp.html, buildercomp.html, kylixcomp.html |
| allways | always | 3 | deploy.html, visualnetcomp.html, htmloutput.html |
| postcript | postscript | 3 | installlin.html, whatisnew.html, faq.html |
| avaliable | available | 3 | dotnetport.html, serverclient.html, translation.html |
| ghostcript | ghostscript | 3 | pagesetup.html, preferences.html, faq.html |
| Tittle | Title | 3 | usingcompo.html, tut/integrating.html, units/rpgdidriver.html |
| desplacement | displacement | 3 | labels.html, refsection.html, left2.html |
| enhaced | enhanced | 3 | licensequestions.html, whatisnew.html, mfeatures.html |
| enought | enough | 2 | requirements.html, pdfoutput.html |
| desingning | designing | 2 | features.html, mfeatures.html |
| comunication | communication | 2 | interoperability.html, dotmatrix.html |
| comand | command | 2 | interoperability.html, webserverinstall.html |
| openened | opened | 2 | interoperability.html, whatisnew.html |
| enviroments | environments | 2 | interoperability.html, openingdata.html |
| Successfull | Successful | 2 | success.html, gnuc.html |
| Manger | Manager | 2 | success.html, usingcompo.html |
| diference | difference | 2 | installlin.html, devdriver.html |
| wil | will | 2 | installwebreport.html, droppingfields.html |
| funtions | functions | 2 | gnuc.html, pdfoutput.html |
| functionallity | functionality | 2 | gnuc.html, openingdatatrouble.html |
| accesible | accessible | 2 | serverintro.html, webserverinstall.html |
| bandwith | bandwidth | 2 | serverintro.html, parallel.html |
| informatino | information | 2 | webserveroperations.html, droppingfields.html |
| begining | beginning | 2 | reportheader.html, exevaluator.html |
| datset | dataset | 2 | reportheader.html, linkedquerys.html |
| independenly | independently | 2 | usingcompo.html, commandline.html |
| Bulider | Builder | 2 | usingcompo.html, replibraries.html |
| Chinesse | Chinese | 2 | exevaluator.html, internatsupport.html |
| gerenerates | generates | 2 | barcodes.html, refbarcode.html |
| Unfortunatelly | Unfortunately | 2 | teechart.html, pdfoutput.html |
| numer | number | 2 | inmemorydata.html, devdriver.html |
| bellow | below | 2 | refsection.html, refdatainfo.html |
| aditionally | additionally | 2 | refdatabaseinfo.html, refdatainfo.html |
| viceversa | vice versa | 2 | licensequestions.html, units/rpwriter.html |
| languajes | languages | 2 | building.html, devnotes.html |
| enhacement | enhancement | 2 | devdriver.html, pdfoutput.html |
| appropiate | appropriate | 2 | pdfoutput.html, faq.html |
| rInchess | rInches | 2 | units/rpruler.html, units/rprulervcl.html |
| Simetric | Symmetric | 1 | features.html |
| margings | margins | 1 | features.html |
| becuase | because | 1 | features.html |
| acomodate | accommodate | 1 | features.html |
| containe | contained | 1 | features.html |
| componets | components | 1 | features.html |
| readed | read | 1 | features.html |
| Architech | Architect | 1 | interoperability.html |
| Profesional | Professional | 1 | interoperability.html |
| Implementaiton | Implementation | 1 | success.html |
| succesfull | successful | 1 | success.html |
| reciepts | receipts | 1 | success.html |
| historys | histories | 1 | success.html |
| painfull | painful | 1 | success.html |
| coversion | conversion | 1 | success.html |
| a easy process | an easy process | 1 | installwin.html |
| intall | install | 1 | installwin.html |
| reporman.ini | reportman.ini | 1 | installwin.html |
| a a quick launch | a quick launch | 1 | installwin.html |
| apper | appear | 1 | delphicomp.html |
| rppackdesisgnvcl_del | rppackdesignvcl_del | 1 | delphicomp.html |
| Componentes | Components | 1 | buildercomp.html |
| a updated | an updated | 1 | buildercomp.html |
| an complete | a complete | 1 | buildercomp.html |
| preceeding | preceding | 1 | axtivexcomp.html |
| elementent | element | 1 | axtivexcomp.html |
| an complete example | a complete example | 1 | axtivexcomp.html |
| an instance | an instance | 1 | axtivexcomp.html |
| a engine capability | an engine capability | 1 | compileropts.html |
| Simetric Multiprocessing | Symmetric Multiprocessing | 1 | deploy.html |
| this scripts | these scripts | 1 | deploy.html |
| postcriptfile | postscriptfile | 1 | installlin.html |
| exmple | example | 1 | linuxprintreptopdf.html |
| linq | link | 1 | linuxprintreptopdf.html |
| estandard | standard | 1 | otherlang.html |
| Winfows | Windows | 1 | installwebreport.html |
| byreally | by really | 1 | installwebreport.html |
| emited | emitted | 1 | installwebreport.html |
| mltiprocessor | multiprocessor | 1 | installserver.html |
| multple | multiple | 1 | installserver.html |
| petittion | petition | 1 | installserver.html |
| reporservercon | reportservercon | 1 | installserver.html |
| diferences | differences | 1 | dotnetport.html |
| fortmat | format | 1 | dotnetport.html |
| mahine | machine | 1 | dotnetport.html |
| stablished | established | 1 | dotnetport.html |
| Transacion | Transaction | 1 | dotnetport.html |
| ususally | usually | 1 | gnuc.html |
| proyect | project | 1 | gnuc.html |
| invliad | invalid | 1 | php.html |
| necassary | necessary | 1 | python_bind.html |
| compatability | compatibility | 1 | python_bind.html |
| commpressed | compressed | 1 | python_bind.html |
| paramater | parameter | 1 | python_bind.html |
| Proudces | Produces | 1 | python_bind.html |
| ValurError | ValueError | 1 | python_bind.html |
| ammount | amount | 1 | serversmp.html |
| transfered | transferred | 1 | serversmp.html |
| ystem | system | 1 | serversmp.html |
| sever | server | 1 | serversmp.html |
| Chek | Check | 1 | webserverinstall.html |
| otsetup | to setup | 1 | webserverinstall.html |
| rebwebexe.exe | repwebexe.exe | 1 | webserverinstall.html |
| varaibles | variables | 1 | webserverinstall.html |
| settigs | settings | 1 | webserverinstall.html |
| por | for | 1 | webserveroperations.html |
| througth | through | 1 | openingdata.html |
| Repeteable | Repeatable | 1 | openingdata.html |
| beginnning | beginning | 1 | reportheader.html |
| deail | detail | 1 | groupheader.html |
| musbe | must be | 1 | groupheader.html |
| enine | engine | 1 | pagesetup.html |
| pager | pages | 1 | pagesetup.html |
| prevew | preview | 1 | preferences.html |
| expresions | expressions | 1 | usingcompo.html |
| subdiretories | subdirectories | 1 | usingcompo.html |
| plaform | platform | 1 | usingcompo.html |
| pats | paths | 1 | usingcompo.html |
| reeport | report | 1 | usingcompo.html |
| centraliced | centralized | 1 | replibraries.html |
| PosgreSQL | PostgreSQL | 1 | replibraries.html |
| reconized | recognized | 1 | repparams.html |
| analizing | analyzing | 1 | repparams.html |
| missplace | misplace | 1 | repparams.html |
| Sometines | Sometimes | 1 | repparams.html |
| loockup | lookup | 1 | repparams.html |
| paramerter | parameter | 1 | repparams.html |
| paremeter | parameter | 1 | repparams.html |
| sustitition | substitution | 1 | repparams.html |
| sustitution | substitution | 1 | repparams.html |
| attatched | attached | 1 | repparams.html |
| with | width | 1 | labels.html |
| skiped | skipped | 1 | labels.html |
| Adress | Address | 1 | labels.html |
| despacement | displacement | 1 | labels.html |
| especify | specify | 1 | externalsec.html |
| A search field field name | A search field name | 1 | externalsec.html |
| interactuate | interact | 1 | exevaluator.html |
| interactuates | interacts | 1 | exevaluator.html |
| Suported | Supported | 1 | exevaluator.html |
| Althoug | Although | 1 | exevaluator.html |
| suport | support | 1 | exevaluator.html |
| substrin | substring | 1 | exevaluator.html |
| wher | where | 1 | exevaluator.html |
| Retutns | Returns | 1 | exevaluator.html |
| paraeters | parameters | 1 | exevaluator.html |
| Parenethesis | Parenthesis | 1 | exevaluator.html |
| witdh | width | 1 | exevaluator.html |
| logaritthmic | logarithmic | 1 | exevaluator.html |
| lossing | losing | 1 | exevaluator.html |
| Convers | Converts | 1 | exevaluator.html |
| unsing | using | 1 | exevaluator.html |
| Identifer | Identifier | 1 | exevaluator.html |
| Checsum | Checksum | 1 | barcodes.html |
| simbols | symbols | 1 | barcodes.html |
| barcode with is wider | barcode width is wider | 1 | barcodes.html |
| commmand | command | 1 | teechart.html |
| suppolrt | support | 1 | internatsupport.html |
| modigy | modify | 1 | internatsupport.html |
| secuences | sequences | 1 | dotmatrix.html |
| additonal | additional | 1 | dotmatrix.html |
| Intallation | Installation | 1 | openingdatatrouble.html |
| configuratoin | configuration | 1 | openingdatatrouble.html |
| Loign | Login | 1 | openingdatatrouble.html |
| pacakage | package | 1 | openingdatatrouble.html |
| acchieved | achieved | 1 | formfilling.html |
| ans | and | 1 | customoutput.html |
| performanc | performance | 1 | inmemorydata.html |
| Stablish | Establish | 1 | inmemorydata.html |
| connectoin | connection | 1 | inmemorydata.html |
| easyly | easily | 1 | parallel.html |
| fileds | fields | 1 | parallel.html |
| feaute | feature | 1 | parallel.html |
| desinger | designer | 1 | parallel.html |
| minimze | minimize | 1 | htmloutput.html |
| trutype | truetype | 1 | htmloutput.html |
| funtion | function | 1 | drawfunctions.html |
| rectangl | rectangle | 1 | drawfunctions.html |
| Horzontal | Horizontal | 1 | drawfunctions.html |
| backgroung | background | 1 | drawfunctions.html |
| folowing | following | 1 | drawfunctions.html |
| evaulated | evaluated | 1 | refcommon.html |
| Aligment | Alignment | 1 | refcommontext.html |
| bi done | be done | 1 | refcommontext.html |
| widh | width | 1 | refcommontext.html |
| horizzontal | horizontal | 1 | refsection.html |
| displazement | displacement | 1 | refsection.html |
| verticalposition | vertical position | 1 | refsection.html |
| propery | property | 1 | refsection.html |
| Postion | Position | 1 | refsection.html |
| formating | formatting | 1 | refexpression.html |
| behaviour | behavior | 1 | refexpression.html |
| desviation | deviation | 1 | refexpression.html |
| sectoin | section | 1 | refimage.html |
| beatiful | beautiful | 1 | refimage.html |
| ourput | output | 1 | refimage.html |
| SerieChangeExpressoin | SerieChangeExpression | 1 | refchart.html |
| balue | value | 1 | refchart.html |
| foces | forces | 1 | refchart.html |
| Perpective | Perspective | 1 | refchart.html |
| adjunts | adjusts | 1 | refchart.html |
| minium | minimum | 1 | refchart.html |
| diferently | differently | 1 | refchart.html |
| aphanumeric | alphanumeric | 1 | refbarcode.html |
| PDF437 | PDF417 | 1 | refbarcode.html |
| dbxconnectoins | dbxconnections | 1 | refdatabaseinfo.html |
| dbxconneciions | dbxconnections | 1 | refdatabaseinfo.html |
| methos | methods | 1 | refdatainfo.html |
| coneptually | conceptually | 1 | refreport.html |
| GridWith | GridWidth | 1 | refreport.html |
| Colletion | Collection | 1 | refreport.html |
| designerWidth | designer, width | 1 | refreport.html |
| comercial | commercial | 1 | licensequestions.html |
| enhaces | enhances | 1 | licensequestions.html |
| examinig | examining | 1 | licensequestions.html |
| autor | author | 1 | licensequestions.html |
| probes | proves | 1 | licensequestions.html |
| palete | palette | 1 | licensequestions.html |
| idependent | independent | 1 | licensequestions.html |
| beacuse | because | 1 | licensequestions.html |
| annonying | annoying | 1 | licensequestions.html |
| omiting | omitting | 1 | licensequestions.html |
| librarys | libraries | 1 | licensequestions.html |
| internacionalization | internationalization | 1 | translation.html |
| marqued | marked | 1 | building.html |
| innecessary | unnecessary | 1 | building.html |
| build the distributable | built the distributable | 1 | building.html |
| availabe | available | 1 | devdriver.html |
| rppdffriver | rppdfdriver | 1 | devdriver.html |
| symple | simple | 1 | devdriver.html |
| infomation | information | 1 | pdfoutput.html |
| informantion | information | 1 | pdfoutput.html |
| maching | matching | 1 | pdfoutput.html |
| similiar | similar | 1 | pdfoutput.html |
| algorith | algorithm | 1 | pdfoutput.html |
| embbed | embed | 1 | pdfoutput.html |
| catching | caching | 1 | pdfoutput.html |
| Devoloper | Developer | 1 | devnotes.html |
| pagckages | packages | 1 | devnotes.html |
| availble | available | 1 | devnotes.html |
| sinc | since | 1 | devnotes.html |
| assignement | assignment | 1 | devnotes.html |
| assignements | assignments | 1 | devnotes.html |
| Linked querys | Linked queries | 1 | left2.html |
| Compatibilty | Compatibility | 1 | whatisnew.html |
| whe | when | 1 | whatisnew.html |
| Paral.lel | Parallel | 1 | whatisnew.html |
| embeded | embedded | 1 | whatisnew.html |
| devangari | devanagari | 1 | whatisnew.html |
| comunications | communications | 1 | whatisnew.html |
| dinamically | dynamically | 1 | whatisnew.html |
| Portuguesse | Portuguese | 1 | whatisnew.html |
| bufixes | bugfixes | 1 | faq.html |
| compoenent | component | 1 | faq.html |
| becasuse | because | 1 | faq.html |
| paralel | parallel | 1 | faq.html |
| consumtion | consumption | 1 | faq.html |
| eception | exception | 1 | knownissues.html |
| kwown | known | 1 | knownissues.html |
| manufactures | manufacturers | 1 | knownissues.html |
| manufacter | manufacturer | 1 | knownissues.html |
| inplementation | implementation | 1 | knownissues.html |
| appear | appears | 1 | knownissues.html |
| Monocrome | Monochrome | 1 | mfeatures.html |
| TeeChar | TeeChart | 1 | mfeatures.html |
| turorial | tutorial | 1 | tut/index.html |
| compresded | compressed | 1 | tut/testing.html |
| methot | method | 1 | tut/integrating.html |
| evalator | evaluator | 1 | units/rpalias.html |
| paletter | palette | 1 | units/rpeval.html |
| neares | nearest | 1 | units/rpevalfunc.html |
| reaaly | really | 1 | units/rplastsav.html |
| defaul | default | 1 | units/rpmdchart.html |
| enviromnments | environments | 1 | units/rpmdshfolder.html |
| rupported | supported | 1 | units/rpmetafile.html |
| conatining | containing | 1 | units/rppdffile.html |
| widhts | widths | 1 | units/rppdffile.html |
| JPef | JPeg | 1 | units/rppdffile.html |
| runnning | running | 1 | units/rppdfreport.html |
| naturar | natural | 1 | units/rpreport.html |
| functios | functions | 1 | units/rpsubreport.html |
| sufix | suffix | 1 | units/rptranslator.html |
| selectoin | selection | 1 | units/rptypes.html |
| Boollean | Boolean | 1 | units/rptypeval.html |
| comparation | comparison | 1 | units/rptypeval.html |

## E. Title quality — 72 pages need a hand-written title

| Page | Current | Quality | Suggested |
|---|---|---|---|
| `success.html` | Successfull projects | weak | Successful projects |
| `linuxcomp.html` | Report Manager - Compile printreptopdf on Linux (development setup) | weak | Compile printreptopdf on Linux (dev setup) |
| `dotnetport.html` | Report Manager - Dot net version | weak | Report Manager .NET version and library setup |
| `python_bind.html` | Python: module reportman | weak | Python reportman Module - ctypes API Bindings |
| `javascript.html` | Using Report Manager from PHP | weak | Using Report Manager from JavaScript |
| `serverintro.html` | Report Manager Server | weak | TCP Report Server Introduction |
| `serverserver.html` | Report Manager Server | weak | Running the Report Server |
| `webserverintro.html` | Report Manager Web Server | weak | Report Manager Web Server (Docker, self-hosted) |
| `openingdata.html` | Opening Data | weak | Opening the Dataset - Report Manager |
| `usingcompo.html` | Using report components Delphi/Kylix/Builder | weak | Using Report Manager Components in Delphi |
| `linkedquerys.html` | Linked querys | weak | Linked queries |
| `labels.html` | Printing labels (horizontal movement) | weak | Printing labels |
| `internatsupport.html` | International suppolrt | weak | International and Unicode Support |
| `bidi_behavior.html` | Delphi BiDi Behavior | weak | Bidirectional Text (BiDi) Behavior |
| `dotmatrix.html` | Print output and design for dot matrix and pos devices | weak | Dot Matrix and POS Printer Output |
| `parallel.html` | In memory datasets | generic | Parallel Unions for Columnar Reports |
| `refparameters.html` | Report parameters in a report reference | weak | TRpParamList report parameters reference |
| `devdriver.html` | Driver architechture of Report Manager | weak | Driver Architecture |
| `left2.html` | Main Report Manager Index | weak | Documentation Index |
| `knownissues.html` | Known Issues | weak | Known Issues and Workarounds |
| `mfeatures.html` | Missing Features | weak | Missing Features and To-Do List |
| `tut/integrating.html` | Integrating into the application with delphi/kylix | weak | Integrating reports into Delphi/C++Builder apps |
| `units/rpactivexreport.html` | Units documentation - rpactivexreport.pas | generic | rpactivexreport.pas - TRpActiveXReport base class |
| `units/rpalias.html` | Units documentation - rpalias.pas | generic | rpalias.pas - TRpAlias dataset alias component |
| `units/rpaxreportimp.html` | Units documentation - rpaxreportimp.pas | generic | rpaxreportimp.pas - TReportManX ActiveX control |
| `units/rpclxreport.html` | Units documentation - rpclxreport.pas | generic | rpclxreport.pas - TCLXReport component |
| `units/rpcompobase.html` | Units documentation - rpcompobase.pas | generic | rpcompobase.pas - TCBaseReport component base class |
| `units/rpdatainfo.html` | Units documentation - rpdatainfo.pas | generic | rpdatainfo.pas - Database and dataset driver registry |
| `units/rpdataset.html` | Units documentation - rpdataset.pas | generic | rpdataset.pas - Two-record-buffer TRpDataset |
| `units/rpdrawitem.html` | Units documentation - rpdrawitem.pas | generic | rpdrawitem.pas - TRpShape and TRpImage |
| `units/rpeval.html` | Units documentation - rpeval.pas | generic | rpeval.pas - TRpEvaluator expression evaluator |
| `units/rpevalfunc.html` | Units documentation - rpevalfunc.pas | generic | rpevalfunc.pas - Built-in evaluator functions |
| `units/rpexpredlg.html` | Units documentation - rpexpredlg.pas | generic | rpexpredlg.pas - CLX expression build wizard |
| `units/rpexpredlgvcl.html` | Units documentation - rpexpredlgvcl.pas | generic | rpexpredlgvcl.pas - VCL expression build wizard |
| `units/rpgdidriver.html` | Units documentation - rpgdidriver.pas | generic | rpgdidriver.pas - Windows GDI print driver |
| `units/rpgdifonts.html` | Units documentation - rpgdifonts.pas | generic | rpgdifonts.pas - Windows device font selection |
| `units/rpgraphutils.html` | Units documentation - rpgraphutils.pas | generic | rpgraphutils.pas - CLX graphic helpers and dialogs |
| `units/rpgraphutilsvcl.html` | Units documentation - rpgraphutilsvcl.pas | generic | rpgraphutilsvcl.pas - VCL graphic helpers and dialogs |
| `units/rplabelitem.html` | Units documentation - rpprintitem.pas | generic | rplabelitem.pas - TRpLabel and TRpExpression |
| `units/rplastsav.html` | Units documentation - rplastsav.pas | generic | rplastsav.pas - Recent Files Component |
| `units/rpmdbarcode.html` | Units documentation - rpmdbarcode.pas | generic | rpmdbarcode.pas - TRpBarcode Component |
| `units/rpmdchart.html` | Units documentation - rpmdchart.pas | generic | rpmdchart.pas - TRpChart Component |
| `units/rpmdconsts.html` | Units documentation - rpmdconsts.pas | generic | rpmdconsts.pas - Resource String Translation |
| `units/rpmdshfolder.html` | Units documentation - rpmdshfolder.pas | generic | rpmdshfolder.pas - Config File Paths |
| `units/rpmetafile.html` | Units documentation - rpmetafile.pas | generic | rpmetafile.pas - Metafile & Driver Layer |
| `units/rpmreg.html` | Units documentation - rpmreg.pas | generic | rpmreg.pas - Non-Visual Package Registration |
| `units/rpmunits.html` | Units documentation - rpmunits.pas | generic | rpmunits.pas - Unit Conversion Functions |
| `units/rppagesetup.html` | Units documentation - rppagesetup.pas | generic | rppagesetup.pas - Page Setup Dialog (CLX) |
| `units/rppagesetupvcl.html` | Units documentation - rppagesetupvcl.pas | generic | rppagesetupvcl.pas - Page Setup Dialog (VCL) |
| `units/rpparams.html` | Units documentation - rpparams.pas | generic | rpparams.pas - Report Parameters |
| `units/rpparser.html` | Units documentation - rpparser.pas | generic | rpparser.pas - Expression Parser |
| `units/rppdfdriver.html` | Units documentation - rppdfdriver.pas | generic | rppdfdriver.pas - PDF Print Driver |
| `units/rppdffile.html` | Units documentation - rppdffile.pas | generic | rppdffile.pas - PDF Canvas & File Writer |
| `units/rppdfreport.html` | Units documentation - rppdfreport.pas | generic | rppdfreport.pas - TPDFReport Component |
| `units/rppreview.html` | Units documentation - rppreview.pas | generic | rppreview.pas - Report Preview (CLX) |
| `units/rpprintitem.html` | Units documentation - rpprintitem.pas | generic | rpprintitem.pas - Base Print Component Classes |
| `units/rpqtdriver.html` | Units documentation - rpqtdriver.pas | generic | rpqtdriver.pas - Qt/CLX Print Driver |
| `units/rpreport.html` | Units documentation - rpreport.pas | generic | rpreport.pas - TRpReport Document Class |
| `units/rprfparams.html` | Units documentation - rprfparams.pas | generic | rprfparams.pas - CLX Runtime Parameters Dialog |
| `units/rprfvparams.html` | Units documentation - rprfvparams.pas | generic | rprfvparams.pas - VCL Runtime Parameters Dialog |
| `units/rpruler.html` | Units documentation - rpruler.pas | generic | rpruler.pas - CLX Ruler Control |
| `units/rprulervcl.html` | Units documentation - rprulervcl.pas | generic | rprulervcl.pas - VCL Ruler Control |
| `units/rpsection.html` | Units documentation - rpsection.pas | generic | rpsection.pas - TRpSection Band Container |
| `units/rpsecutil.html` | Units documentation - rpsecutil.pas | generic | rpsecutil.pas - Section Collection Classes |
| `units/rpsubreport.html` | Units documentation - rpsubreport.pas | generic | rpsubreport.pas - TRpSubReport Container |
| `units/rptranslator.html` | Units documentation - rptranslator.pas | generic | rptranslator.pas - Localization Components |
| `units/rptypes.html` | Units documentation - rptypes.pas | generic | rptypes.pas - Base Types and Utilities |
| `units/rptypeval.html` | Units documentation - rptypeval.pas | generic | rptypeval.pas - Expression Evaluator Types |
| `units/rpvclreport.html` | Units documentation - rpvclreport.pas | generic | rpvclreport.pas - TVCLReport Component |
| `units/rpvgraphutils.html` | Units documentation - rpvgraphutils.pas | generic | rpvgraphutils.pas - CLX-to-GDI Helpers |
| `units/rpvpreview.html` | Units documentation - rpvpreview.pas | generic | rpvpreview.pas - VCL Preview Form |
| `units/rpwriter.html` | Units documentation - rpwriter.pas | generic | rpwriter.pas - Report Text Serialization |

## F. Meta descriptions — 142 weak/auto total; 82 on high/medium pages (shown)

| Page | Pri | Quality | Suggested |
|---|---|---|---|
| `requirements.html` | high | auto-generated | Hardware and software requirements for Report Manager Designer and engine on Windows and modern Linux distributions, including X11 and PDF export needs. |
| `features.html` | high | auto-generated | Full feature list of Report Manager: cross-platform engine, PDF/HTML/Excel/CSV export, subreports, barcodes (incl. QR), charts, multi-database drivers and report server. |
| `installwin.html` | high | auto-generated | How to install the Report Manager Designer on Microsoft Windows: download, run setup, choose folders, and configure database connection files. |
| `installlin.html` | high | auto-generated | How to install Report Manager Designer on Linux via RPM or tar.gz, configure library paths, database files, and printer options. |
| `serverintro.html` | high | auto-generated | Overview of Report Manager's multithreaded TCP/IP report server: how clients request reports, aliases, users, and thread-safe configuration. |
| `webserverintro.html` | high | auto-generated | Run the Report Manager Web Server via Docker: built-in admin panel, database connections, API keys and rendering reports to PDF, CSV, SVG and more. |
| `webserverinstall.html` | high | auto-generated | Install the Report Manager Web Server on Windows IIS (CGI/ISAPI) or Linux Apache: configure handlers, database files, permissions, logging and locales. |
| `openingdata.html` | high | auto-generated | Connect a Report Manager report to a database: create a connection, add a dataset with an SQL query, preview the data, and assign it to a subreport. |
| `droppingfields.html` | high | auto-generated | Drag dataset fields onto a report detail section, add labels and shapes, adjust section height, then preview and export to PDF, text or Report Metafile. |
| `whatisnew.html` | high | auto-generated | Report Manager release notes: 4.0.10 adds an AI Copilot, AI report generation, SQL autocomplete, DB Agent connections, undo/redo and a Docker report server. |
| `tut/dropping.html` | high | auto-generated | Tutorial: drop labels and expression fields onto the detail section, edit the text property, and add fonts and drawing items in the Designer. |
| `tut/testing.html` | high | auto-generated | Tutorial: preview a report, print it, save it as a metafile for metaview.exe, or export to compressed or uncompressed Adobe PDF. |
| `tut/integrating.html` | high | auto-generated | Tutorial: install the Report Manager packages, drop the report component on a form, bind datasets via TRpAlias, and call Execute, SaveToPdf or ShowParams. |
| `howitwork.html` | medium | auto-generated | Engine overview: how Report Manager processes datasets, parameters, subreports, sections (bands) and components to lay out and print a report. |
| `interoperability.html` | medium | auto-generated | How Report Manager integrates with Delphi, C++Builder, .NET, ActiveX, shared libraries, command-line tools and web servers across Windows and Linux. |
| `success.html` | medium | auto-generated | Real-world Report Manager case studies and testimonials from companies using it for veterinary, telecom and medical laboratory reporting on Windows and Linux. |
| `delphicomp.html` | medium | auto-generated | How to compile and install the Report Manager packages in Delphi, including package install order, Indy setup, and rpconf.inc options. |
| `buildercomp.html` | medium | auto-generated | How to compile and install the Report Manager packages in C++Builder, with package install order, Qt/CLX notes, and Zeos support steps. |
| `axtivexcomp.html` | medium | auto-generated | Register and use the Report Manager ActiveX (ReportManX) control: properties, methods, and VB/VBScript/ASP examples for generating reports and PDFs. |
| `compileropts.html` | medium | auto-generated | Report Manager engine compiler defines in rpconf.inc (USESQLEXPRESS, USEIBX, USEADO, USEBDE, USEIBO, INDY10) to enable or disable database drivers. |
| `deploy.html` | medium | auto-generated | Files to deploy with Report Manager on Windows and Linux: executables, resource strings, DBExpress drivers, native/CLX runtimes, and the ActiveX control. |
| `otherlang.html` | medium | auto-generated | Use the Report Manager engine from other languages: PHP, GNU C, Python, JavaScript and Ruby on Rails samples and documentation. |
| `visualnetcomp.html` | medium | auto-generated | Install the Report Manager .NET assemblies (Reportman.Drawing, Reporting, Forms, Designer, Web) and their dependencies in Visual Studio. |
| `installwebreport.html` | medium | auto-generated | Reference for the deprecated WebReportManX ActiveX control: parameters and legacy Internet Explorer setup for previewing/printing report metafiles. |
| `installserver.html` | medium | auto-generated | Install the Report Manager TCP report server on Windows (as a service or standalone) or on Linux, plus multiprocessor setup notes. |
| `dotnetport.html` | medium | auto-generated | Overview of the C# port of the Report Manager engine: designing reports for .NET, current limitations, and sample code for executing reports. |
| `gnuc.html` | medium | auto-generated | Call the Report Manager engine from GNU C, C++, or any language that can load its DLL/shared library. Function reference, parameter types, and compile commands. |
| `php.html` | medium | auto-generated | Sample PHP code that launches a Report Manager report as a PDF through repwebexe, passing report name, alias, and parameters via a dynamic URL. |
| `python.html` | medium | auto-generated | Use Report Manager from Python via the C shared library, or on Windows through the registered ReportManX ActiveX control. |
| `javascript.html` | medium | auto-generated | A JavaScript RMReport helper class that builds repwebserver URLs to launch Report Manager reports as PDFs with parameters from intranet pages. |
| `serverserver.html` | medium | auto-generated | How to run the Report Manager TCP server as a background service or visible reportserverapp, with library configuration and printreptopdf setup. |
| `serverclient.html` | medium | auto-generated | How to connect the metaview report client to a Report Manager Server: aliases, report trees, parameters, printing and saving to PDF. |
| `serverclientcustom.html` | medium | auto-generated | Build a custom Report Manager client: use Delphi VCL/PDF report components and ExecuteRemote, or the standard C API or ActiveX methods. |
| `serverconfig.html` | medium | auto-generated | Configure the Report Manager server with repserverconfig: port 3060, users, user groups, alias privileges, libraries and report tree preview. |
| `serversmp.html` | medium | auto-generated | How Report Manager server uses multiprocessor and SMP machines: per-request threads/processes via printreptopdf, performance gains, and disabling SMP. |
| `webserveroperations.html` | medium | auto-generated | Reference for Report Manager Web Server commands and request parameters: login, version, aliasname, reportname, metafile output formats, language and CSV options. |
| `pageheader.html` | medium | auto-generated | Add page header and footer sections that print on every page, apply print conditions, and use the Page function to show page numbers in a footer. |
| `reportheader.html` | medium | auto-generated | Use subreport header, summary and group sections in Report Manager, and add aggregate expressions to count records or sum totals in the summary. |
| `groupheader.html` | medium | auto-generated | Group report data with group headers and footers, set the group change expression, count records per group, and order datasets correctly for grouping. |
| `pagesetup.html` | medium | auto-generated | Configure report page size, orientation, margins, printer fonts, duplex, two-pass mode, save format and printer selection in the Report Manager page setup. |
| `reportgrid.html` | medium | auto-generated | Use the Report Manager design grid to align components: enable it, switch between points and lines, and change the grid color, per-report. |
| `preferences.html` | medium | auto-generated | Set Report Manager Designer preferences: measurement units, the GDI/VCL vs Qt/CLX print driver choice and their differences, print dialog, status bar and widget style. |
| `usingcompo.html` | medium | auto-generated | Guide to the Report Manager VCL/CLX components (TRpEvaluator, TVCLReport, TRpPDFReport, TRpDesigner): properties, methods, and how to preview or print a report. |
| `commandline.html` | medium | auto-generated | Report Manager command line tools: reptotxt, txttorep, printrep, printreptopdf, metaprint and compilerep for converting, printing and embedding report definitions. |
| `repparams.html` | medium | auto-generated | How to define and use Report Manager parameters: types, validation, lookup search datasets, string substitution, special engine parameters and runtime editing. |
| `linkedquerys.html` | medium | auto-generated | Link secondary datasets to a subreport's main dataset in Report Manager by naming parameters after master fields, so detail queries refresh per record. |
| `childsubreports.html` | medium | auto-generated | Use the Child Subreport section property in Report Manager to nest subreports per detail record, enabling many-to-many master/detail layouts and subtotals. |
| `labels.html` | medium | auto-generated | Design label sheets in Report Manager: measure label spacing, set page margins and detail size, and use Horz.Desp./Vert.Desp. for multi-column layouts. |
| `externalsec.html` | medium | auto-generated | Share a common header/section across many Report Manager reports via the External Path property, storing the section in an external file or database field. |
| `exevaluator.html` | medium | auto-generated | Report Manager's expression evaluator: Pascal-like syntax, data types, operators, built-in functions, runtime variables (Page, Free_space, PAGECOUNT) and aggregates. |
| `barcodes.html` | medium | auto-generated | Barcode types supported by Report Manager (2of5, Code39/93/128, EAN, MSI, Postnet, Codabar) and the Ratio, Calc.Checksum, Modul and Rotation properties. |
| `teechart.html` | medium | auto-generated | Enable TeeChart in Report Manager via the USETEECHART define and the chart Driver property; covers VCL/CLX dependencies, limitations and the native chart driver. |
| `internatsupport.html` | medium | auto-generated | How Report Manager handles multilanguage labels, Unicode text, and bidirectional (Hebrew/Arabic) output across Windows, Linux and PDF. |
| `bidi_behavior.html` | medium | auto-generated | Reference table of BiDiMode and horizontal alignment combinations for bidirectional (Hebrew/Arabic) text, with worked examples. |
| `compsiterep.html` | medium | auto-generated | Concatenate fully processed reports into one document using the Compose method, shown with VCL/CLX components and ActiveX. |
| `dotmatrix.html` | medium | auto-generated | Configure page size, fonts and escape-code drivers (EPSON, IBM, thermal/POS) to print Report Manager reports on dot matrix and receipt printers. |
| `openingdatatrouble.html` | medium | auto-generated | Troubleshooting database connections in Report Manager: driver overview (DBExpress, BDE, Zeos, IBX) and step-by-step setup examples. |
| `formfilling.html` | medium | auto-generated | Fill preprinted forms by placing a scanned or PDF background image in a report section and dropping fields and expressions on top. |
| `customoutput.html` | medium | auto-generated | Generate customized fixed-position text files from a report using per-expression Export Line, Position, Size and New Line properties. |
| `inmemorydata.html` | medium | auto-generated | Use the MyBase driver to build in-memory datasets: load from files, sort, union, group and apply master-detail filters for fast reports. |
| `parallel.html` | medium | auto-generated | Combine multiple datasets side by side with parallel unions to build columnar reports, using prefixed field names and optional common-field joins. |
| `htmloutput.html` | medium | auto-generated | Export reports to multi-file or single-file HTML, with page-setup and font guidelines to avoid line overlap and layout problems. |
| `drawfunctions.html` | medium | auto-generated | Reference for Report Manager draw functions (TextOp, GraphicOp, ImageOp, OnBarcodeOp) usable in expressions, with full parameter tables. |
| `refcommon.html` | medium | auto-generated | Reference for the common Report Manager component properties: Width, Height, Print Condition, Before/After Print, position, alignment and PDF annotations. |
| `refcommontext.html` | medium | auto-generated | Text-component properties shared by TRpLabel, TRpExpression and TRpChart: alignment, fonts, color, word wrap, rotation, Bidi and HTML markup with expression substitution. |
| `refsection.html` | medium | auto-generated | Reference for TRpSection properties: displacement, auto expand/contract, group breaks, page skipping, child subreports, external sections and custom text export. |
| `refexpression.html` | medium | auto-generated | Reference for TRpExpression: expression evaluation, data type, display format, multi-page output, identifiers and aggregate (sum, min, max, avg, std) options. |
| `refimage.html` | medium | auto-generated | Reference for the TRpImage component: draw styles, embedded vs expression images, resolution and the image file formats supported by each output driver. |
| `refchart.html` | medium | auto-generated | Reference for the TRpChart component: chart expressions, series, chart type and driver, 3D/TeeChart view options, axis ranges and color expressions. |
| `refbarcode.html` | medium | auto-generated | Reference for the TRpBarcode component: supported barcode types (2 of 5, Code39/93/128, EAN, MSI, PDF417, QR), checksum, module, ratio and rotation. |
| `refdatabaseinfo.html` | medium | auto-generated | Reference for report database connections (TRpDatabaseInfoList): the Alias and Driver properties for MyBase, BDE, DBExpress, IBX, IBO, ADO and ZeosLib backends. |
| `refreport.html` | medium | auto-generated | Reference for the TRpReport top-level object: grid, printer selection, page size and margins, copies, two-pass printing, language and the data/parameter collections. |
| `licensequestions.html` | medium | auto-generated | Developer FAQ on the Report Manager MPL license: commercial use, third-party libraries, scripting, and contributing engine enhancements. |
| `translation.html` | medium | auto-generated | How to localize the Report Manager Designer: download the translation kit, edit reportmanres language files with rptranslate.exe, and deploy them. |
| `building.html` | medium | auto-generated | Step-by-step guide to building Report Manager binaries, language resources, and installer packages from the IDE or the command line. |
| `devdriver.html` | medium | auto-generated | How the Report Manager engine renders through pluggable print drivers (GDI, PDF, text, HTML) and the device-independent metafile layer. |
| `pdfoutput.html` | medium | auto-generated | How Report Manager generates native PDF output, including TrueType/Type1 font embedding and linking, compression, and Linux freetype-based font handling. |
| `devnotes.html` | medium | auto-generated | Developer notes on Report Manager internals: NuGet/GitHub packages, BiDi support, TClientDataset buffering, and historical Delphi/CLX compatibility workarounds. |
| `license.html` | medium | auto-generated | Full text of the Report Manager license: Mozilla Public License 1.1, dual-licensed with the GPL, covering use, modification and distribution. |
| `knownissues.html` | medium | auto-generated | Known Report Manager issues and workarounds: Linux/Kylix startup, Qt printer driver bugs, custom page sizes, linked-query crashes, Oracle and ODBC/MySQL connections. |
| `mfeatures.html` | medium | auto-generated | Report Manager to-do list of features not yet implemented: richer HTML/SVG export, RTF output, more chart types, polylines, drill-down and expression functions. |
| `units/rplabelitem.html` | medium | auto-generated | Reference for rplabelitem.pas, which implements TRpLabel (multilanguage label printing) and TRpExpression (printing expressions and database fields). |

## G. Content staleness notes (84 pages)

### `doc/doc/index.html` — Report Manager documentation _(priority: high)_
- Presents the Internet Explorer ActiveX plugin as a current way to embed preview/print, though IE is discontinued and the plugin is marked deprecated elsewhere in the nav.
- Promotes 'Delphi 10.4.2 for .Net' as 'New' though Delphi for .Net is deprecated.

### `doc/doc/requirements.html` — System requirements _(priority: high)_
- Lists supported Windows OS only up to Windows XP (Win98, Millennium, NT, 2000, XP); no Vista/7/8/10/11.
- Describes the Designer as using Qt widgets under X Window System, which no longer reflects the current Windows VCL designer.
- Requires Kylix for Linux compilation, an abandoned toolchain.
- Cites Internet Explorer 5 system DLL dependencies and a Pentium 75 performance baseline.

### `doc/doc/features.html` — Features _(priority: high)_
- Lists supported Delphi versions ending around Delphi 10.4 / XE and Kylix 2-3, omitting current Delphi 11/12 releases.
- Lists the Internet Explorer plugin and BDE/DBExpress as supported integration paths reflecting legacy tooling.
- Mentions Qt driver vs Windows GDI driver selection in the designer, which no longer reflects the current VCL designer.
- Does not mention the newer rpdbHttp / Reportman Agent HTTP driver or SVG output among the database/output options.

### `doc/doc/installwin.html` — Installation in Microsoft Windows _(priority: high)_
- Targets only legacy Windows (WNT/W2000/WXP) as the NT technology examples
- Database config defaults assume a Borland Delphi 6 / C++Builder 6 installation and dbxdrivers.ini/dbxconnections.ini in the Borland Shared directory
- References 'Documents & Settings' path layout from Windows XP era for reportman.ini

### `doc/doc/installlin.html` — Installation in Linux _(priority: high)_
- Sample RPM/tarball names use version 1.0 (reportmand-1.0.i386.rpm, reportmand-1.0.tar.gz)
- Describes Kylix/CLX-era Linux setup: Borland qt libraries, DBExpress dbxdrivers/dbxconnections, kprinter/pdftops/Xpdf print path

### `doc/doc/serverintro.html` — Report Manager Server _(priority: high)_
- States 'as far as I know all drivers supports this' for multithread driver support, an informal/uncertain claim that reads as stale

### `doc/doc/webserverinstall.html` — Installing Report Manager Web Server _(priority: high)_
- Linux instructions reference Kylix runtime libraries (/opt/kylixlibs) and KYLIX_* environment variables, which is obsolete versus the current FPC/Docker build
- References '.borland' designer config directory and Suse 7.3 paths, both long obsolete
- Mentions retrieving HTML model files from 'the cvs development tree' though the project now uses git
- Apache PassEnv compatibility note cites Apache 1.1/1.3.7, very dated
- Does not mention the Docker self-hosted deployment that is now the recommended path (covered on the intro page)

### `doc/doc/openingdata.html` — Opening Data _(priority: high)_
- Tutorial uses the DBExpress driver and the employee.gdb Interbase/Firebird sample as the canonical connection example; newer drivers (FireDAC, Zeos, rpdbHttp) are not mentioned.

### `doc/doc/whatisnew.html` — Report Manager - What is new _(priority: high)_
- Version history goes back to 1.3 with mostly identical legacy entries; entries reference Delphi 4/5/6/7, Kylix 1/2/3 and C++Builder 4/5/6 as if current targets
- Internal link 'See /version/dotnetport.html for more information' uses a stale /version/ path that does not match the site's /doc/ structure
- Some early version dates look inconsistent (e.g. 2.0 dated December 22th 2004 listed after 2.1 dated May 2004, 1.5 dated April 2004)

### `doc/doc/faq.html` — Frequently Asked Questions of Report Manager _(priority: high)_
- Supported-environments answer lists only Delphi 4-7, C++Builder 4-6 and Kylix 1-3; omits modern Delphi (XE/10.x/12), FPC/Lazarus and the newer rpdbHttp/DB Agent driver
- Recommends a Yahoo Groups user group, which no longer exists (Yahoo Groups shut down in 2020)
- Dot-matrix-in-Linux answer describes Kylix/Qt/ghostscript print path as current, predating the FPC/Lazarus and Linux printreptopdf reality
- Code samples use TCLXReport/CLXReport (CLX), no longer the current component naming

### `doc/tutorial/index.html` — Report Manager tutorial: defining data access _(priority: high)_
- Describes only BDE and DBExpress as the data access drivers; omits the current FireDAC/Zeos/IBX/rpdbHttp drivers.

### `doc/tutorial/integrating.html` — Integrating into the application with delphi/kylix _(priority: high)_
- Title/headings and link list present Kylix as a current target alongside Delphi; sidebar already renames this to Delphi/C++Builder.
- References CLX-era components (TCLXReport, TNewCLXReport) as the current palette components.

### `doc/doc/interoperability.html` — Report Manager Interoperability _(priority: medium)_
- Native support list ends at Delphi 6/7 / Delphi 8 for .Net and Kylix; omits modern Delphi (XE/10.x/11/12) and current .NET Core libraries.
- Describes database connection abstraction via dbxconnections.ini/dbxdrivers.ini and Borland tools as the current mechanism.
- Lists ActiveX/ASP/IIS and C# Builder as current interop targets, reflecting legacy tooling.

### `doc/doc/success.html` — Successfull projects _(priority: medium)_
- All testimonials are dated 2003-2004 and reference RM v1.6, Delphi 7/Kylix 3, Firebird 1.03, Interbase v6, and Win98/2000 era environments.
- Contact emails and third-party project URLs are over 20 years old and almost certainly dead.

### `doc/doc/delphicomp.html` — Compiling in Delphi _(priority: medium)_
- Package version table stops at Delphi 2009; no modern Delphi (XE/10.x/11/12) variants listed
- Documents CLX packages for cross-platform development as a current option
- Recommends upgrading Indy to 'latest version 9' for Delphi 7, long obsolete

### `doc/doc/buildercomp.html` — Compiling in C++Builder _(priority: medium)_
- Package version table stops at C++Builder 6/7; no modern C++Builder versions listed
- Describes CLX/Qt printing limitations as current behavior
- References Delphi 6 Update Pack #2 and qtintf.dll fixes as relevant

### `doc/doc/axtivexcomp.html` — Using Report Manager ActiveX control _(priority: medium)_
- Examples target Windows 98 and the Windows Scripting Host (WSH)
- ASP / VBScript / Microsoft Transaction Server usage presented as current integration paths
- References Adobe Acrobat Reader as the PDF viewer

### `doc/doc/compileropts.html` — Compiler Options _(priority: medium)_
- Compiler-define table lists only legacy database backends (DBExpress, BDE/SQL Links, ADO, IBX, IBObjects); no FireDAC, Zeos, or the rpdbHttp/Agent driver
- Version-check example references Delphi 5

### `doc/doc/deploy.html` — Deploying Report Manager _(priority: medium)_
- Deployment tables center on Kylix/Qt CLX runtimes and the Borland Database Engine as current targets
- DBExpress driver list (Interbase, MySQL, DB2, Oracle, Informix, ODBC) presented as the deployment story; no FireDAC/Zeos/HTTP Agent driver
- References XP-theme .manifest and 'Windows NT Systems and upper' as the platform baseline

### `doc/doc/visualnetcomp.html` — Using Report Manager .Net native controls _(priority: medium)_
- Describes legacy .NET Framework assembly layout (System.Drawing, Windows.Forms, ASP.NET Web.Forms) as the current technology set

### `doc/doc/installwebreport.html` — Using and installing WebReportManX control _(priority: medium)_
- Entire feature relies on Internet Explorer ActiveX/.cab/.ocx plugin model, which no modern browser supports
- References hardcoded IP codebase URLs (http://80.32.237.17/...) and Windows XP SP2 ActiveX signing rules as current

### `doc/doc/installserver.html` — Installing Report Manager Server _(priority: medium)_
- References Windows 98/Me and NT/2000/XP as target operating systems
- Linux service install described via runlevels (init scripts), predating systemd

### `doc/doc/dotnetport.html` — Report Manager - Dot net version _(priority: medium)_
- States the native .NET Report Designer is still in progress and charting/PDF417 ("PDF437") barcode are not yet implemented
- Says the port is complete but some features are still not implemented

### `doc/doc/gnuc.html` — Using Report Manager from GNU C _(priority: medium)_
- Describes the Qt-dependent libreportmanapiqt.so and CLX/X-Server preview path as current, which reflects the old Kylix/CLX Linux toolchain rather than current FPC/Lazarus builds
- Lists Excel output (single/multiple sheet) as an output format, which is a legacy/deprecated driver

### `doc/doc/php.html` — Using Report Manager from PHP _(priority: medium)_
- Entire page is a third-party PHP sample contributed via a Yahoo group with a yahoo.com contact address; uses an old repwebexe.bin CGI URL scheme and dated PHPLib-style code (page_open/Template)

### `doc/doc/python.html` — Using Report Manager from Python _(priority: medium)_
- Very short stub page; the recommended Windows path is the ActiveX/COM control via win32com, which reflects the legacy COM integration

### `doc/doc/javascript.html` — Using Report Manager from PHP _(priority: medium)_
- Third-party sample contributed via the Yahoo reportman group; uses the legacy repwebserver.dll /cgi-bin URL scheme
- The page title and breadcrumb/meta description incorrectly say PHP while the content is about JavaScript

### `doc/doc/serverclient.html` — Report Manager Client _(priority: medium)_
- Linux client distribution lists Kylix-era Qt runtime libborqtint.6.9.so as a current requirement
- Note states the screenshots are in Spanish

### `doc/doc/serverclientcustom.html` — Report Manager Custom Client _(priority: medium)_
- References TCLXReport (CLX/Kylix-era component) alongside VCL/PDF report components as a current option

### `doc/doc/serversmp.html` — Multiprocessor support _(priority: medium)_
- Frames Intel hyperthreading as a notable current technology and notes single-processor HT boost is 'not tested yet', reflecting early-2000s hardware context

### `doc/doc/webserveroperations.html` — Operating Report Manager Web Server _(priority: medium)_
- Documents URL/query-string operation and bookmarkable execution URLs as the primary model, whereas the intro page now states parameters travel by POST by default with query-string kept only for backwards compatibility
- Mentions WebReportManX web component for metafile output, a legacy ActiveX-era client

### `doc/doc/preferences.html` — Design preferences _(priority: medium)_
- Describes the Qt/CLX print driver as a current, co-equal choice alongside GDI; CLX/Qt is a legacy Kylix-era driver no longer relevant on modern builds.
- References Windows 9x/NT/Millenium/2000 widget appearance as current.

### `doc/doc/usingcompo.html` — Using report components Delphi/Kylix/Builder _(priority: medium)_
- Component compatibility matrix only covers Delphi 5/6/7, C++Builder 4/6 and Kylix 2/3; nothing about modern Delphi/RAD Studio versions.
- Centers on the CLX/Kylix cross-platform driver as the most common component.

### `doc/doc/commandline.html` — Command line tools _(priority: medium)_
- States Report Metafile files can be viewed with the Internet Explorer plugin, which is a discontinued ActiveX/IE feature.

### `doc/doc/repparams.html` — Using report parameters _(priority: medium)_
- Code samples use Kylix/CLX (CLXReport1, VCL/CLX) as current rather than legacy
- Special parameters reference DBExpress (DBXCONNECTIONS, DBXDRIVERS) and BDE drivers as current

### `doc/doc/linkedquerys.html` — Linked querys _(priority: medium)_
- Page title and headings spell it "Linked querys" while the navigation/menu uses "Linked queries"

### `doc/doc/labels.html` — Printing labels (horizontal movement) _(priority: medium)_
- h3 subtitle still reads "horz.desplacement/vert.despacement" with misspellings

### `doc/doc/exevaluator.html` — Expression evaluator _(priority: medium)_
- Delphi usage example introduced under "Delphi/Kylix/Builder" heading references Kylix as a current target

### `doc/doc/barcodes.html` — Barcode printing _(priority: medium)_
- Barcode limitations section describes Kylix-era Qt 2.3 100dpi rendering as the current Linux behavior; obsolete since the engine no longer depends on Kylix/Qt

### `doc/doc/teechart.html` — TeeChart support _(priority: medium)_
- Describes the Kylix CLX TeeChart variant and Kylix X-Server requirement as current behavior, though Kylix is long deprecated

### `doc/doc/internatsupport.html` — International suppolrt _(priority: medium)_
- Describes Unicode/WideString PDF generation as not implemented, which may no longer reflect the current PDF driver
- Cites Qt as the Linux Unicode rendering path

### `doc/doc/bidi_behavior.html` — Delphi BiDi Behavior _(priority: medium)_
- All Hebrew example cells are corrupted by double-encoding, so the demonstration of BiDi behavior is unreadable

### `doc/doc/compsiterep.html` — Composite reports _(priority: medium)_
- References CLX components as a current composition path

### `doc/doc/openingdatatrouble.html` — Database access information _(priority: medium)_
- Driver table lists only legacy backends (DBExpress, BDE, Zeos, IBX, MyBase, DAO); no mention of FireDAC or the rpdbHttp Agent driver
- States DBExpress drivers were last updated by Borland and BDE last updated at Delphi 6 / 2001
- Entire setup walkthrough is built around SuSE 9.0, Firebird 1.5 RC, and manual symlink hacks that are long obsolete
- Attributes products like DAO, BDE, IBX and MyBase to 'Borland' rather than Embarcadero

### `doc/doc/formfilling.html` — Form filling and printing _(priority: medium)_
- Recommends Adobe Acrobat 6 Professional for PDF-to-image conversion, a very old release

### `doc/doc/inmemorydata.html` — In memory datasets _(priority: medium)_
- Attributes TClientDataset to 'Borland tools' rather than Embarcadero

### `doc/doc/parallel.html` — In memory datasets _(priority: medium)_
- Page title is wrong: it reads 'In memory datasets' (copied from inmemorydata.html) instead of 'Parallel unions'; the breadcrumb and JSON-LD breadcrumb name are likewise wrong

### `doc/doc/htmloutput.html` — Output to html _(priority: medium)_
- Repeatedly benchmarks HTML font rendering against Internet Explorer, a discontinued browser

### `doc/doc/drawfunctions.html` — Draw Functions _(priority: medium)_
- Parameter table row is labeled 'RecWidth' while the TextHeight function signature uses 'RectWidth' (mismatched name)

### `doc/doc/refcommontext.html` — Common properties for text components _(priority: medium)_
- Describes Qt as the Linux/printing font driver as current; engine is now DirectWrite (Windows) and Fontconfig-ICU-HarfBuzz (Linux)

### `doc/doc/refimage.html` — Common properties for TRpImage _(priority: medium)_
- Supported-formats table is built around Windows/Linux QT (TCLXReport) and CLX drivers as current targets, and lists PNG/XPM/GIF support as Qt-only and PNG/GIF as unsupported in GDI/HTML/PDF, which no longer reflects the current engine

### `doc/doc/refchart.html` — Common properties for TRpChart _(priority: medium)_
- States the native chart driver only supports the Line type and that TeeChart is the Windows default / Native is the Linux default to avoid Qt and Kylix dependencies

### `doc/doc/refdatabaseinfo.html` — Database connections _(priority: medium)_
- Driver list centers on legacy BDE, DBExpress, IBX/IBO, ADO and ZeosLib; does not mention current FireDAC or the rpdbHttp (Reportman Agent) driver
- Does not mention the newer HTTP/DataDirect (rpdbHttp) database driver that the current engine supports

### `doc/doc/refreport.html` — Report reference _(priority: medium)_
- PageSizeQt property documented around the Qt library page-size index sequence as the current mechanism

### `doc/doc/licensequestions.html` — License questions _(priority: medium)_
- Examples are framed around Delphi component-palette / DBExpress era tooling rather than current FireDAC/Zeos backends, but as license-philosophy examples they are not strictly outdated

### `doc/doc/building.html` — Building Report Manager Designer and tools _(priority: medium)_
- Describes the build as Delphi 6/7 + Kylix via .bpg project groups and Borland make; the project now builds through MSBuild group projects (reportmanxe2.groupproj) on modern Delphi
- Source is fetched via CVS/WinCVS; the project is now on Git/GitHub
- Distinguishes Qt-dependent vs Pure VCL (xp) builds as current, which no longer reflects the shipping toolchain

### `doc/doc/devdriver.html` — Driver architechture of Report Manager _(priority: medium)_
- Driver table lists Qt/CLX (TRpQtDriver/TCLXReport) and an Excel driver as current; the modern engine renders via GDI, PDF, SVG, HTML, PNG, text/CSV and no longer relies on Qt/CLX
- Describes printer-vs-PDF TrueType font-sizing parity as an unimplemented future enhancement and frames Qt as the Linux drawing layer
- References the ActiveX metafile plugin as a current delivery target

### `doc/doc/pdfoutput.html` — PDF Output _(priority: medium)_
- States font embedding is keyed to freetype 2.1.8 and references the early-stage X print server, reflecting an early-2000s Linux font landscape
- Notes FontConfig-based font matching as only a possible future enhancement

### `doc/doc/devnotes.html` — Developer notes about Report Manager _(priority: medium)_
- The 'BiDi Support, complex languajes' note is duplicated verbatim (two identical h4 blocks)
- Several h4 headings are mis-closed with </p> instead of </h4>, breaking heading structure
- Most notes document Delphi 5/6/7, CLX and Win9x-era bugs as if current; only the NuGet/GitHub and BiDi notes (3.9.15) are modern

### `doc/doc/license.html` — Report Manager License _(priority: medium)_
- Standard verbatim MPL 1.1 legal text; not stale, should remain unchanged

### `doc/doc/knownissues.html` — Known Issues _(priority: medium)_
- Entire page documents Kylix/Qt/CLX-era Linux and Windows issues (Win9x/Me/NT/2000/XP, Kylix 2/3, Qt 3.0.5) that predate the current FPC/Lazarus engine and modern Windows; reads as a historical issue list
- References Oracle 9i / 8.1.7 client and MyODBC as current support concerns
- Workarounds rely on repmand.sh/KYLIX_PRINTBUG and metaprint, tied to the discontinued Kylix runtime

### `doc/doc/mfeatures.html` — Missing Features _(priority: medium)_
- Lists 'Exactly same sizes in preview and print, using TRpVCLDriver and TRpPDFdrivers' as a missing feature, though PDF/printer font parity has since shipped
- Lists 'Monochrome and RLE compressed bitmaps in PDF export' as still missing; PDF output has been substantially reworked since
- Refers to Borland .Net and Qt/GDI driver parity as outstanding items, predating the current .NET library and FPC engine

### `doc/doc/units/rplabelitem.html` — Units documentation - rpprintitem.pas _(priority: medium)_
- Title and H1 say 'rpprintitem.pas' while the H3 heading, meta description and body all document rplabelitem.pas (TRpLabel/TRpExpression) - the title/H1 are mislabeled for this page

### `doc/doc/delphinetcomp.html` — Compiling in Delphi for .Net _(priority: low)_
- Page is a stub that only redirects to the Visual Studio .NET page; documents the discontinued Delphi for .NET compiler

### `doc/doc/kylixcomp.html` — Compiling in Kylix _(priority: low)_
- Documents only Kylix 2/3 packages and CLX; Kylix is a discontinued product

### `doc/doc/python_bind.html` — Python: module reportman _(priority: low)_
- Auto-generated pydoc from a 2004 third-party module targeting Python 2.3 (paths like c:\python23, Python 2.3.3 banner); ctypes described as a separate download though it ships with modern Python
- Module version 0.1.0.0, copyright 2004; TODO list still mentions cross-platform/Mac support as unimplemented

### `doc/doc/replibraries.html` — Report Libraries _(priority: low)_
- PostgreSQL CREATE TABLE example uses the deprecated WITH OIDS clause, removed in modern PostgreSQL versions.

### `doc/doc/refdatainfo.html` — Database configuration in a report reference _(priority: low)_
- Connection driver list (DBExpress, BDE, MyBase, IBX, ADO, IBO) omits FireDAC and the current rpdbHttp HTTP driver

### `doc/doc/refparameters.html` — Report parameters in a report reference _(priority: low)_
- Page is a near-empty stub: only a summary table with class info and no description of the actual parameter item properties (name, type, value, etc.)

### `doc/doc/units.html` — Developer - source code units _(priority: low)_
- Unit inventory is incomplete relative to the current engine (~200 rp*.pas units) and still centers on the CLX/Qt-era set; newer units (SVG/HTML drivers, rpdatahttp, DataDirect) are absent

### `doc/doc/left2.html` — Main Report Manager Index _(priority: low)_
- This appears to be a legacy duplicate of the documentation index (links go to right.html, contrib.html 'Order product', author.html) and lists Component Reference rows with no links; overlaps with the current index.html and may be redundant

### `doc/doc/units/rpclxreport.html` — Units documentation - rpclxreport.pas _(priority: low)_
- Describes the CLX/Qt TRpQtDriver as a current print driver, though CLX/Qt is a legacy Kylix-era target

### `doc/doc/units/rpdatainfo.html` — Units documentation - rpdatainfo.pas _(priority: low)_
- Driver list reads as BDE/DBExpress/IBX/IBO-centric and does not mention newer FireDAC/Zeos or the rpdbHttp driver

### `doc/doc/units/rpexpredlg.html` — Units documentation - rpexpredlg.pas _(priority: low)_
- Documents a CLX-based dialog; CLX is a legacy Kylix-era framework superseded by the VCL variant (rpexpredlgvcl.pas)

### `doc/doc/units/rpgdidriver.html` — Units documentation - rpgdidriver.pas _(priority: low)_
- GDI progress form and page-size selection still carry Qt-era type names (TFRpQtProgress, TPageSizeQt) in a Windows-only driver

### `doc/doc/units/rpgraphutils.html` — Units documentation - rpgraphutils.pas _(priority: low)_
- Documents CLX graphic helpers and a LoadQtTranslator routine for Qt .qm files; CLX/Qt is a legacy Kylix-era target superseded by the VCL variant

### `doc/doc/units/rpmdshfolder.html` — Units documentation - rpmdshfolder.pas _(priority: low)_
- Description cites Windows 2000 as the reference Windows version; the function set is generic and the OS reference is decades out of date.

### `doc/doc/units/rppagesetup.html` — Units documentation - rppagesetup.pas _(priority: low)_
- Describes the dialog as CLX (Kylix/Qt-based); CLX is a discontinued toolkit and this unit targets the legacy Linux/CLX build.

### `doc/doc/units/rppreview.html` — Units documentation - rppreview.pas _(priority: low)_
- Describes CLX/Qt (TRpQtDriver) preview as current; CLX is a discontinued toolkit and this unit targets the legacy Linux/Qt build rather than the current VCL preview.

### `doc/doc/units/rpqtdriver.html` — Units documentation - rpqtdriver.pas _(priority: low)_
- Documents the Qt/CLX print driver as a current output target, though CLX/Kylix is obsolete and this driver is legacy
- Description duplicates 'print driver print driver' in the TRpQtDriver row

### `doc/doc/units/rprfparams.html` — Units documentation - rprfparams.pas _(priority: low)_
- Describes a CLX (Kylix) parameters window as current, though CLX is obsolete

### `doc/doc/units/rpruler.html` — Units documentation - rpruler.pas _(priority: low)_
- Describes CLX ruler drawing as current, though CLX is obsolete

### `doc/doc/units/rptypes.html` — Units documentation - rptypes.pas _(priority: low)_
- TPageSizeQt type references the legacy Qt driver as current

### `doc/doc/units/rpvgraphutils.html` — Units documentation - rpvgraphutils.pas _(priority: low)_
- Body heading shows the unit name as 'rpvgraphutills.pas' (extra l), inconsistent with the actual filename rpvgraphutils.pas in the title and breadcrumb
- Describes CLX-to-GDI conversion as current, though CLX is obsolete

## H. High-priority pages

- `doc/doc/index.html` — 2 typos, 5 obsolete, 2 links, 2 stale
- `doc/doc/requirements.html` — 3 typos, 6 obsolete, 4 stale
- `doc/doc/features.html` — 11 typos, 8 obsolete, 1 links, 4 stale
- `doc/doc/installwin.html` — 5 typos, 5 obsolete, 1 links, 3 stale
- `doc/doc/installlin.html` — 4 typos, 4 obsolete, 1 links, 2 stale
- `doc/doc/serverintro.html` — 3 typos, 1 obsolete, 1 stale
- `doc/doc/webserverintro.html` — 1 links
- `doc/doc/webserverinstall.html` — 9 typos, 6 obsolete, 2 links, 5 stale
- `doc/doc/openingdata.html` — 4 typos, 2 obsolete, 1 stale
- `doc/doc/droppingfields.html` — 4 typos
- `doc/doc/whatisnew.html` — 13 typos, 7 obsolete, 2 links, 3 stale
- `doc/doc/faq.html` — 12 typos, 13 obsolete, 4 stale
- `doc/tutorial/index.html` — 1 typos, 2 obsolete, 1 stale
- `doc/tutorial/dropping.html` — clean
- `doc/tutorial/testing.html` — 1 typos, 1 obsolete
- `doc/tutorial/integrating.html` — 2 typos, 4 obsolete, 2 stale
