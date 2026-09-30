Report Manager examples for Lazarus
===================================

The three projects use the report sales.rep of this folder: the sales
grouped by customer, with a total per customer and a grand total. Its data
comes from the application (salesdata.pas fills an in-memory TBufDataset),
so they run without a database.

pdfconsole  Console program that writes sales.pdf. It needs only the
            reportman_rtl package (the engine and the PDF export, no LCL):
            for services, web servers and command line tools.

preview     LCL application with a TLCLReport (Reportman page of the
            component palette): preview, print and save as PDF.
            Packages reportman_rtl and reportman_lcl.

designer    LCL application with a TRpDesignerLCL: its users change the
            report in the designer and preview the result. It also needs
            reportman_designlcl.


How the data reaches the report
-------------------------------
A report has datasets (Data configuration in the designer). A dataset can
open its own connection and SQL query (SQLdb, Zeos, the Reportman Agent...)
or the application can give it any TDataSet:

  Report.DataInfo.ItemByName('SALES').Dataset := MyDataset;

sales.rep uses the second way. Its dataset SALES points to a connection of
type MyBase only because the engine requires one for every dataset; it is
not opened while the application provides the data.


Build and run
-------------
Install the three packages (Package > Online Package Manager, "Report
Manager"), open an .lpi in Lazarus and run it. From a terminal:

  lazbuild examples/lazarus/pdfconsole/pdfconsole.lpi
  lazbuild examples/lazarus/preview/preview.lpi
  lazbuild examples/lazarus/designer/designer.lpi

Design your own reports with the designer example, with a TRpDesignerLCL in
your application or with the standalone Report Manager Designer
(https://reportman.es).
