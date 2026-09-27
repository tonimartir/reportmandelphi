{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit reportman_rtl;

{$warn 5023 off : no warning about unused units}
interface

uses
  rptypes, rpmdshfolder, rpmdconsts, rptranslator, rpmzlib, rpzlib77, 
  rpzlibadler, rpzlibinfblock, rpzlibinfcodes, rpzlibinffast, rpzlibinftrees, 
  rpzlibinfutil, rpzlibtrees, rpzlibzdeflate, rpzlibzinflate, rpzlibzutil, 
  rpzlibzlib, rpmetafile, rpmunits, rptypeval, rpeval, rpprintitem, 
  rplabelitem, rpsection, rpsecutil, rpsubreport, rpbasereport, rpreport, 
  rpcompilerep, rpmdcharttypes, rpparser, rpalias, rpdatainfo, rpparams, 
  rpdataset, rpdatatext, rpevalfunc, rpmdbarcode, rpbarcodecons, rpxmlstream, 
  rpdrawitem, rpmdchart, rppdfdriver, rppdffile, rpinfoprovid, rpcompobase, 
  rphtmldriver, rpcsvdriver, rpsvgdriver, rppdfreport, rptextdriver, 
  rplastsav, rpinfoprovfpc, rpfreetype2, rpHarfBuzz, rpICU, rpinfoprovft, 
  rpdirectwrite, RpDirectWriteRenderer, rpinfoprovgdi, rpfontconfig, 
  rpDelphiZXIngQRCode, rpfpcutils, rpmreg, rpcolumnar, rpbase64fpc,
  rpjsonfpc, rphttpclientfpc, rpnetencodingfpc, rpioutilsfpc, rpsysutilsfpc,
  rpaireportcontracts, rpreportdesignercontracts, rpauthmanager, rpdatahttp,
  LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('rpmreg', @rpmreg.Register);
end;

initialization
  RegisterPackage('reportman_rtl', @Register);
end.
