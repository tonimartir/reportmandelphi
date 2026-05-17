{*******************************************************}
{                                                       }
{       Rpexpredlgvcl                                   }
{       Compatibility wrapper for rpchatdialogvcl       }
{       Report Manager                                  }
{                                                       }
{*******************************************************}

unit rpexpredlgvcl;

interface

{$I rpconf.inc}
{$R rpexpredlg.dcr}

uses
  SysUtils, Classes,
  rpalias, rpeval, rpreport, rpmetafile, rpchatdialogvcl;

type
  TRpChatMode = rpchatdialogvcl.TRpChatMode;
  TRpExpreDialogVCL = rpchatdialogvcl.TRpExpreDialogVCL;
  TRpChatDialogComponent = rpchatdialogvcl.TRpChatDialogComponent;
  TFRpExpredialogVCL = rpchatdialogvcl.TFRpExpredialogVCL;
  TFRpChatDialogVCL = rpchatdialogvcl.TFRpChatDialogVCL;

function ChangeExpression(formul: string; aval: TRpCustomEvaluator): string;
function ChangeExpressionW(formul: Widestring; aval: TRpCustomEvaluator): Widestring;
function ExpressionCalculateW(formul: Widestring; aval: TRpCustomEvaluator): Variant;

implementation

function ChangeExpression(formul: string; aval: TRpCustomEvaluator): string;
begin
 Result := rpchatdialogvcl.ChangeExpression(formul, aval);
end;

function ChangeExpressionW(formul: Widestring; aval: TRpCustomEvaluator): Widestring;
begin
 Result := rpchatdialogvcl.ChangeExpressionW(formul, aval);
end;

function ExpressionCalculateW(formul: Widestring; aval: TRpCustomEvaluator): Variant;
begin
 Result := rpchatdialogvcl.ExpressionCalculateW(formul, aval);
end;

end.