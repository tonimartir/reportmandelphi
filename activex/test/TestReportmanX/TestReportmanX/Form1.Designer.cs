namespace TestReportmanX
{
    partial class Form1
    {
        /// <summary>
        ///  Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///  Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(Form1));
            button1 = new Button();
            axReportManx1 = new Axreportman.AxReportManX();
            ((System.ComponentModel.ISupportInitialize)axReportManx1).BeginInit();
            SuspendLayout();
            // 
            // button1
            // 
            button1.Location = new Point(25, 29);
            button1.Name = "button1";
            button1.Size = new Size(427, 76);
            button1.TabIndex = 0;
            button1.Text = "Test Reportman";
            button1.UseVisualStyleBackColor = true;
            button1.Click += button1_Click;
            // 
            // axReportManx1
            // 
            axReportManx1.Location = new Point(374, 184);
            axReportManx1.Name = "axReportManx1";
            axReportManx1.OcxState = (AxHost.State)resources.GetObject("axReportManx1.OcxState");
            axReportManx1.Size = new Size(75, 20);
            axReportManx1.TabIndex = 1;
            // 
            // Form1
            // 
            AutoScaleDimensions = new SizeF(8F, 20F);
            AutoScaleMode = AutoScaleMode.Font;
            ClientSize = new Size(800, 450);
            Controls.Add(axReportManx1);
            Controls.Add(button1);
            Name = "Form1";
            Text = "Form1";
            ((System.ComponentModel.ISupportInitialize)axReportManx1).EndInit();
            ResumeLayout(false);
        }

        #endregion

        private Button button1;
        private Axreportman.AxReportManX axReportManx1;
    }
}
