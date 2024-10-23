namespace TestReportmanX
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e)
        {
            string pdfOutput = "c:\\users\\toni\\downloads\\testrepxnochinoxx.pdf";
            string additional = "c:\\users\\toni\\downloads\\additional.pdf";
            string reportName = "c:\\users\\toni\\downloads\\testrepxnochino.rep";


            this.axReportManx1.filename = reportName;

            MemoryStream mstream = new MemoryStream();
            using (FileStream fstream = new FileStream(additional, FileMode.Open))
            {
                byte[] bytes = new byte[16000];
                int readed = fstream.Read(bytes,0, 16000);
                while (readed>0)
                {
                    mstream.Write(bytes, 0, readed);
                    readed = fstream.Read(bytes, 0, 16000);
                }
            }
            mstream.Seek(0, SeekOrigin.Begin);
            string base64 = Convert.ToBase64String(mstream.ToArray());

            this.axReportManx1.AddEmbeddedFile("test.pdf", "application/pdf", base64);

            this.axReportManx1.SaveToPDF("c:\\users\\toni\\downloads\\testrepxnochinoxx.pdf", false);
        }
    }
}
