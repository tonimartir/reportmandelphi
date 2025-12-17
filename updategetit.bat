@echo off
REM updategetit.bat - Copia los archivos específicos del DPK a GetIt\Reportman_PDF\Source\Common

REM Carpeta destino
set DEST=.\getIt\Reportman_PDF\Source\Common

REM Crear la carpeta destino si no existe
if not exist "%DEST%" (
    mkdir "%DEST%"
)

REM Lista de archivos a copiar
set FILES=rptypes.pas rpmdshfolder.pas rpmdconsts.pas rptranslator.pas rpmzlib.pas rpzlib77.pas rpzlibadler.pas rpzlibinfblock.pas rpzlibinfcodes.pas rpzlibinffast.pas rpzlibinftrees.pas rpzlibinfutil.pas rpzlibtrees.pas rpzlibzdeflate.pas rpzlibzinflate.pas rpzlibzutil.pas rpzlibzlib.pas rpmetafile.pas rpmdcharttypes.pas rpreport.pas rpbasereport.pas rpprintitem.pas rpsubreport.pas rpeval.pas rpsecutil.pas rpsection.pas rpmunits.pas rptypeval.pas rpparser.pas rpalias.pas rpdatainfo.pas rpparams.pas rpdataset.pas rpdatatext.pas rpevalfunc.pas rplabelitem.pas rpmdbarcode.pas rpbarcodecons.pas rpxmlstream.pas rpdrawitem.pas rpmdchart.pas rppdfdriver.pas rppdffile.pas rpinfoprovid.pas rpinfoprovgdi.pas rpmreg.pas rpcompobase.pas rphtmldriver.pas rpcsvdriver.pas rpsvgdriver.pas rppdfreport.pas rptextdriver.pas rpclientdataset.pas rplastsav.pas rpDelphiZXIngQRCode.pas rpdirectwriterenderer.pas rptruetype.pas rpICU.pas rpHarfBuzz.pas rpFreeType2.pas rptranslator.dcr reportmanres.res dbxdrivers.res rpalias.dcr rpeval.dcr rplastsav.dcr rppdfreport.dcr rpinfoprovft.pas rpcompilerep.pas rpfontconfig.pas

REM Copiar cada archivo
for %%F in (%FILES%) do (
    echo Copiando %%F a %DEST%
    copy "%%F" "%DEST%" /Y
)

echo Todos los archivos se han copiado.
pause
