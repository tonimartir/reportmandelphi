@echo off
REM updategetit.bat - Copia los archivos específicos del DPK a GetIt\Reportman_PDF\Source\Common

REM Carpeta destino
set DEST=.\getIt\Source\Common

REM Crear la carpeta destino si no existe
if not exist "%DEST%" (
    mkdir "%DEST%"
)

REM Lista de archivos a copiar
set FILES=rptypes.pas rpmdshfolder.pas rpmdconsts.pas rptranslator.pas rpmzlib.pas rpzlib77.pas rpzlibadler.pas rpzlibinfblock.pas rpzlibinfcodes.pas rpzlibinffast.pas rpzlibinftrees.pas rpzlibinfutil.pas rpzlibtrees.pas rpzlibzdeflate.pas rpzlibzinflate.pas rpzlibzutil.pas rpzlibzlib.pas rpmetafile.pas rpmdcharttypes.pas rpreport.pas rpbasereport.pas rpprintitem.pas rpsubreport.pas rpeval.pas rpsecutil.pas rpsection.pas rpmunits.pas rptypeval.pas rpparser.pas rpalias.pas rpdatainfo.pas rpparams.pas rpdataset.pas rpdatatext.pas rpevalfunc.pas rplabelitem.pas rpmdbarcode.pas rpbarcodecons.pas rpxmlstream.pas rpdrawitem.pas rpmdchart.pas rppdfdriver.pas rppdffile.pas rpinfoprovid.pas rpinfoprovgdi.pas rpmreg.pas rpcompobase.pas rphtmldriver.pas rpcsvdriver.pas rpsvgdriver.pas rppdfreport.pas rptextdriver.pas rpclientdataset.pas rplastsav.pas rpDelphiZXIngQRCode.pas rpdirectwriterenderer.pas rptruetype.pas rpICU.pas rpHarfBuzz.pas rpFreeType2.pas rptranslator.dcr reportmanres.res dbxdrivers.res rpalias.dcr rpeval.dcr rplastsav.dcr rppdfreport.dcr rpinfoprovft.pas rpcompilerep.pas rpfontconfig.pas rptypes.pas rpmdshfolder.pas rpmdconsts.pas rptranslator.pas rpmzlib.pas rpzlib77.pas rpzlibadler.pas rpzlibinfblock.pas rpzlibinfcodes.pas rpzlibinffast.pas rpzlibinftrees.pas rpzlibinfutil.pas rpzlibtrees.pas rpzlibzdeflate.pas rpzlibzinflate.pas rpzlibzutil.pas rpzlibzlib.pas rpmetafile.pas rpmdcharttypes.pas rpreport.pas rpbasereport.pas rpprintitem.pas rpsubreport.pas rpeval.pas rpsecutil.pas rpsection.pas rpmunits.pas rptypeval.pas rpparser.pas rpalias.pas rpdatainfo.pas rpparams.pas rpdataset.pas rpdatatext.pas rpevalfunc.pas rplabelitem.pas rpmdbarcode.pas rpbarcodecons.pas rpxmlstream.pas rpdrawitem.pas rpmdchart.pas rppdfdriver.pas rppdffile.pas rpinfoprovid.pas rpinfoprovgdi.pas rpcompilerep.pas rpdirectwriterenderer.pas rpfreetype2.pas rpinfoprovft.pas rpICU.pas rpHarfbuzz.pas rpfontconfig.pas rpmreg.pas rpcompobase.pas rphtmldriver.pas rpcsvdriver.pas rpsvgdriver.pas rppdfreport.pas rptextdriver.pas rpclientdataset.pas rplastsav.pas rptruetype.pas rpDelphiZXIngQRCode.pas rpexceldriver.pas rpexceldriver.dfm rpexpredlgvcl.pas rpexpredlgvcl.dfm rpfmainmetaviewvcl.pas rpfmainmetaviewvcl.dfm rpgdidriver.pas rpgdidriver.dfm rpgraphutilsvcl.pas rpgraphutilsvcl.dfm rpmdclitreevcl.pas rpmdclitreevcl.dfm rpmdfaboutvcl.pas rpmdfaboutvcl.dfm rpmdfembeddedfile.pas rpmdfembeddedfile.dfm rpmdfsearchvcl.pas rpmdfsearchvcl.dfm rprfvparams.pas rprfvparams.dfm rpmdprintconfigvcl.pas rpmdprintconfigvcl.dfm rpgdifonts.pas rpmaskedit.pas rpvgraphutils.pas rpregvcl.pas rpexpredlg.dcr rpactivexreport.dcr rpmaskedit.dcr rpmdesignervcl.dcr rprulervcl.dcr rpvclreport.dcr rpwebmetaclient.dcr rpvclreport.pas rpvpreview.pas rpvpreview.dfm rppreviewcontrol.pas rppagesetupvcl.pas rppagesetupvcl.dfm rpwebmetaclient.pas rppreviewmeta.pas rpdbgridvcl.pas rpdbdatetimepicker.pas rpactivexreport.pas rpfmetaviewvcl.pas rpfmetaviewvcl.dfm rpmregdesignvcl.pas rpmdesignervcl.pas rprulervcl.pas rpmdfmainvcl.pas rpmdfdesignvcl.pas rpmdfstrucvcl.pas rpdbbrowservcl.pas rpmdobjinspvcl.pas rpmdobinsintvcl.pas rpmdfextsecvcl.pas rpmdflabelintvcl.pas rpmdfdrawintvcl.pas rpmdfbarcodeintvcl.pas rpmdfchartintvcl.pas rpmdfsectionintvcl.pas rpmdfdinfovcl.pas rpmdfdatasetsvcl.pas rpfparamsvcl.pas rpmdfsampledatavcl.pas rpmdfdatatextvcl.pas rpmdfconnectionvcl.pas rpdbxconfigvcl.pas rpmdfgridvcl.pas rpmdsysinfo.pas rpmdfopenlibvcl.pas rpmdftreevcl.pas rpeditconnvcl.pas rpmdfwizardvcl.pas rpmdfselectfields.pas rpcolumnar.pas rppanel.pas rpmdfmainvcl.dfm rpmdfdesignvcl.dfm rpmdfstrucvcl.dfm rpdbbrowservcl.dfm rpmdobjinspvcl.dfm rpmdfextsecvcl.dfm rpmdfdinfovcl.dfm rpmdfdatasetsvcl.dfm rpfparamsvcl.dfm rpmdfsampledatavcl.dfm rpmdfdatatextvcl.dfm rpmdfconnectionvcl.dfm rpdbxconfigvcl.dfm rpmdfgridvcl.dfm rpmdsysinfo.dfm rpmdfopenlibvcl.dfm rpmdftreevcl.dfm rpeditconnvcl.dfm rpmdfwizardvcl.dfm rpmdfselectfields.dfm

REM Copiar cada archivo
for %%F in (%FILES%) do (
    echo Copiando %%F a %DEST%
    copy "%%F" "%DEST%" /Y
)

echo Todos los archivos se han copiado.
pause
