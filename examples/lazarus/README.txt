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


A database: postgresql
----------------------
The reports of the folder postgresql open their own connection and SQL
query, one with each direct driver of the FPC engine:

  sales_sqldb.rep  connection RPSAMPLE_SQLDB, driver FireDAC: the FPC
                   engine opens it with SQLdb (included in FPC)
  sales_zeos.rep   connection RPSAMPLE_ZEOS, driver Zeos

pgreport (console, reportman_rtl) writes both as PDF. The data: the sales of
sampledb.sql, joined with their customers and products. With a PostgreSQL
server running (macOS: brew install postgresql@16 and brew services start
postgresql@16, or Postgres.app; Linux: the postgresql package):

  cd examples/lazarus/postgresql
  ./createdb.sh                 # user and database rpsample, with the data
  lazbuild pgreport.lpi
  ./pgreport                    # sales_sqldb.pdf and sales_zeos.pdf

The connections are in dbxconnections.ini of that folder (pgreport reads it;
another file can be given as its parameter). To open the reports in the
designer, copy its two sections to the connections file of the user. On
macOS and Linux it is ~/.borland/dbxconnections when that file exists (the
Linux packages create it), otherwise ~/.dbxconnections. On Windows run
the commands of createdb.sh with psql (or psql -f sampledb.sql in a database
rpsample).


Build and run
-------------
Install the three packages (Package > Online Package Manager, "Report
Manager"), open an .lpi in Lazarus and run it. From a terminal:

  lazbuild examples/lazarus/pdfconsole/pdfconsole.lpi
  lazbuild examples/lazarus/preview/preview.lpi
  lazbuild examples/lazarus/designer/designer.lpi

On Linux and macOS the engine needs FreeType, fontconfig and HarfBuzz at run
time (to measure and shape the text). Linux desktops have them. On macOS:

  brew install fontconfig harfbuzz

or build them without Homebrew with build/macos/build-deps.sh, which links
them in ~/lib, where the applications started from the Finder find them.
On macOS, Lazarus writes the LCL examples as application bundles
(preview.app, designer.app) next to the project: open them from the Finder
or with "open preview/preview.app". Tested with Lazarus 4.8 (Cocoa) on
macOS 11, Intel; see docs/macos.md.

Design your own reports with the designer example, with a TRpDesignerLCL in
your application or with the standalone Report Manager Designer
(https://reportman.es).
