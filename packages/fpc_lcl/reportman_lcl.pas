{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit reportman_lcl;

{$warn 5023 off : no warning about unused units}
interface

uses
  rplcldriver, rplclfonts, rpgraphutilslcl, rprflclparams, rppreviewmetalcl, 
  rppreviewcontrol, rpmaskedit, rplclpreview, rppagesetuplcl, rplclreport, 
  rpreglcl, rpwebview2, rplclwebview, rpfrmmonacoeditorlcl, rprulerlcl, 
  rpmdobinsintlcl, rpmdflabelintlcl, rpmdfdrawintlcl, rpmdfbarcodeintlcl, 
  rpmdfchartintlcl, rpmdfsectionintlcl, rpmdfdesignlcl, rpmdesignerlcl, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('rpreglcl', @rpreglcl.Register);
end;

initialization
  RegisterPackage('reportman_lcl', @Register);
end.
