using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace BountyStudio
{
    internal static class Program
    {
        internal static string AppRoot;
        private static Mutex appMutex;
        private static IntPtr webViewLoader;

        [STAThread]
        private static void Main()
        {
            AppRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Bounty Studio", "App");
            bool created;
            appMutex = new Mutex(true, "Local\\BountyStudio.Desktop.v2", out created);
            if (!created)
            {
                appMutex.Dispose();
                MessageBox.Show("O Bounty Studio ja esta aberto.", "Bounty Studio", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            try
            {
                Directory.CreateDirectory(AppRoot);
                EmbeddedPayload.Extract(AppRoot);
                AppDomain.CurrentDomain.AssemblyResolve += ResolveWebViewAssembly;
                Assembly.LoadFrom(Path.Combine(AppRoot, "Microsoft.Web.WebView2.Core.dll"));
                Assembly.LoadFrom(Path.Combine(AppRoot, "Microsoft.Web.WebView2.WinForms.dll"));
                webViewLoader = LoadLibrary(Path.Combine(AppRoot, "WebView2Loader.dll"));
                if (webViewLoader == IntPtr.Zero)
                {
                    int error = Marshal.GetLastWin32Error();
                    throw new InvalidOperationException("O componente interno do WebView2 nao pode ser carregado. Codigo do Windows: " + error);
                }
            }
            catch (Exception ex)
            {
                WriteBootError(ex);
                appMutex.Dispose();
                MessageBox.Show("Nao foi possivel preparar o Bounty Studio." + Environment.NewLine + Environment.NewLine + ex.Message,
                    "Bounty Studio", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            try
            {
                try { File.Delete(Path.Combine(AppRoot, "boot-error.log")); } catch { }
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Type formType = Assembly.GetExecutingAssembly().GetType("BountyStudio.MainForm", true);
                Application.Run((Form)Activator.CreateInstance(formType));
                GC.KeepAlive(webViewLoader);
            }
            catch (Exception ex)
            {
                WriteBootError(ex);
                MessageBox.Show("O Bounty Studio nao conseguiu abrir a janela do painel." + Environment.NewLine + Environment.NewLine + ex,
                    "Bounty Studio", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally { appMutex.Dispose(); }
        }

        private static void WriteBootError(Exception ex)
        {
            try
            {
                Directory.CreateDirectory(AppRoot);
                File.AppendAllText(Path.Combine(AppRoot, "boot-error.log"), DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + Environment.NewLine + ex + Environment.NewLine + Environment.NewLine, Encoding.UTF8);
            }
            catch { }
        }

        private static Assembly ResolveWebViewAssembly(object sender, ResolveEventArgs args)
        {
            string name = new AssemblyName(args.Name).Name;
            if (name != "Microsoft.Web.WebView2.Core" && name != "Microsoft.Web.WebView2.WinForms") return null;
            string path = Path.Combine(AppRoot, name + ".dll");
            return File.Exists(path) ? Assembly.LoadFrom(path) : null;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr LoadLibrary(string fileName);
    }

    internal static class EmbeddedPayload
    {
        private const string ManifestResourceName = "BountyStudio.Payload.Manifest";

        internal static void Extract(string appRoot)
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            using (Stream manifestStream = assembly.GetManifestResourceStream(ManifestResourceName))
            {
                if (manifestStream == null) throw new InvalidDataException("O manifesto interno do aplicativo esta ausente.");
                using (StreamReader reader = new StreamReader(manifestStream, Encoding.UTF8))
                {
                    string line;
                    while ((line = reader.ReadLine()) != null)
                    {
                        if (String.IsNullOrWhiteSpace(line)) continue;
                        string[] columns = line.Split('|');
                        if (columns.Length != 3) throw new InvalidDataException("O manifesto interno do aplicativo esta invalido.");
                        ExtractOne(assembly, appRoot, columns[0], columns[1], columns[2]);
                    }
                }
            }
        }

        private static void ExtractOne(Assembly assembly, string appRoot, string resourceName, string relativePath, string expectedHash)
        {
            string root = Path.GetFullPath(appRoot).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
            string path = Path.GetFullPath(Path.Combine(root, relativePath));
            if (!path.StartsWith(root, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("Caminho de recurso invalido.");
            string directory = Path.GetDirectoryName(path);
            if (!Directory.Exists(directory)) Directory.CreateDirectory(directory);
            if (File.Exists(path) && String.Equals(HashFile(path), expectedHash, StringComparison.OrdinalIgnoreCase)) return;

            using (Stream resource = assembly.GetManifestResourceStream(resourceName))
            {
                if (resource == null) throw new InvalidDataException("Recurso interno ausente: " + resourceName);
                using (MemoryStream memory = new MemoryStream())
                {
                    resource.CopyTo(memory);
                    byte[] bytes = memory.ToArray();
                    if (!String.Equals(HashBytes(bytes), expectedHash, StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException("Falha na verificacao de integridade: " + relativePath);
                    AtomicWrite(path, bytes);
                }
            }
        }

        private static string HashFile(string path)
        {
            using (FileStream stream = File.OpenRead(path))
            using (SHA256 sha = SHA256.Create()) return Hex(sha.ComputeHash(stream));
        }

        private static string HashBytes(byte[] bytes)
        {
            using (SHA256 sha = SHA256.Create()) return Hex(sha.ComputeHash(bytes));
        }

        private static string Hex(byte[] bytes)
        {
            StringBuilder text = new StringBuilder(bytes.Length * 2);
            foreach (byte value in bytes) text.Append(value.ToString("x2"));
            return text.ToString();
        }

        private static void AtomicWrite(string path, byte[] bytes)
        {
            string temp = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
            File.WriteAllBytes(temp, bytes);
            if (File.Exists(path))
            {
                try { File.Replace(temp, path, null); }
                catch { File.Delete(path); File.Move(temp, path); }
            }
            else File.Move(temp, path);
        }
    }

    internal static class NativeWindowChrome
    {
        [DllImport("dwmapi.dll", PreserveSig = true)]
        private static extern int DwmSetWindowAttribute(IntPtr window, int attribute, ref int value, int valueSize);

        internal static void Apply(IntPtr window)
        {
            if (window == IntPtr.Zero) return;
            try
            {
                int enabled = 1;
                int result = DwmSetWindowAttribute(window, 20, ref enabled, sizeof(int));
                if (result != 0) DwmSetWindowAttribute(window, 19, ref enabled, sizeof(int));

                int rounded = 2;
                DwmSetWindowAttribute(window, 33, ref rounded, sizeof(int));

                // Keep the native caption in the same restrained dark palette as the app.
                int captionColor = 0x000A0A09; // COLORREF for RGB(9, 10, 10)
                int captionTextColor = 0x00F5F2EE; // COLORREF for RGB(238, 242, 245)
                int borderColor = 0x0033312D; // COLORREF for RGB(45, 49, 51)
                DwmSetWindowAttribute(window, 35, ref captionColor, sizeof(int));
                DwmSetWindowAttribute(window, 36, ref captionTextColor, sizeof(int));
                DwmSetWindowAttribute(window, 34, ref borderColor, sizeof(int));
            }
            catch { }
        }
    }

    internal sealed class StudioProgressIndicator : Control
    {
        private readonly System.Windows.Forms.Timer animationTimer;
        private float phase;

        internal StudioProgressIndicator()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Size = new Size(460, 9);
            animationTimer = new System.Windows.Forms.Timer { Interval = 24 };
            animationTimer.Tick += delegate
            {
                phase = (phase + 0.018F) % 1F;
                Invalidate();
            };
            animationTimer.Start();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            if (ClientSize.Width < 2 || ClientSize.Height < 2) return;
            Graphics graphics = e.Graphics;
            graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            RectangleF rail = new RectangleF(0.5F, 1.5F, ClientSize.Width - 1F, ClientSize.Height - 3F);
            using (System.Drawing.Drawing2D.GraphicsPath railPath = RoundedPath(rail, rail.Height))
            using (Brush railBrush = new SolidBrush(Color.FromArgb(38, 213, 190, 137)))
                graphics.FillPath(railBrush, railPath);

            float segmentWidth = Math.Min(112F, ClientSize.Width * 0.28F);
            float x = phase * (ClientSize.Width + segmentWidth) - segmentWidth;
            RectangleF segment = new RectangleF(x, rail.Y, segmentWidth, rail.Height);
            using (System.Drawing.Drawing2D.GraphicsPath segmentPath = RoundedPath(segment, rail.Height))
            using (System.Drawing.Drawing2D.LinearGradientBrush shine = new System.Drawing.Drawing2D.LinearGradientBrush(segment,
                Color.FromArgb(0, 213, 190, 137), Color.FromArgb(0, 213, 190, 137), 0F))
            {
                System.Drawing.Drawing2D.ColorBlend blend = new System.Drawing.Drawing2D.ColorBlend();
                blend.Positions = new float[] { 0F, 0.5F, 1F };
                blend.Colors = new Color[] { Color.FromArgb(0, 213, 190, 137), Color.FromArgb(235, 229, 207, 157), Color.FromArgb(0, 213, 190, 137) };
                shine.InterpolationColors = blend;
                graphics.FillPath(shine, segmentPath);
            }
        }

        private static System.Drawing.Drawing2D.GraphicsPath RoundedPath(RectangleF bounds, float radius)
        {
            System.Drawing.Drawing2D.GraphicsPath path = new System.Drawing.Drawing2D.GraphicsPath();
            float diameter = Math.Min(radius, Math.Min(bounds.Width, bounds.Height));
            path.AddArc(bounds.X, bounds.Y, diameter, diameter, 180F, 90F);
            path.AddArc(bounds.Right - diameter, bounds.Y, diameter, diameter, 270F, 90F);
            path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0F, 90F);
            path.AddArc(bounds.X, bounds.Bottom - diameter, diameter, diameter, 90F, 90F);
            path.CloseFigure();
            return path;
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing && animationTimer != null)
            {
                animationTimer.Stop();
                animationTimer.Dispose();
            }
            base.Dispose(disposing);
        }
    }

    [DataContract]
    internal sealed class GitHubReleaseInfo
    {
        [DataMember(Name = "tag_name")] internal string TagName { get; set; }
        [DataMember(Name = "draft")] internal bool Draft { get; set; }
        [DataMember(Name = "prerelease")] internal bool Prerelease { get; set; }
        [DataMember(Name = "assets")] internal List<GitHubReleaseAsset> Assets { get; set; }
    }

    [DataContract]
    internal sealed class GitHubReleaseAsset
    {
        [DataMember(Name = "name")] internal string Name { get; set; }
        [DataMember(Name = "browser_download_url")] internal string DownloadUrl { get; set; }
        [DataMember(Name = "digest")] internal string Digest { get; set; }
        [DataMember(Name = "size")] internal long Size { get; set; }
    }

    internal static class GitHubUpdater
    {
        private const long MaximumDownloadSize = 200L * 1024L * 1024L;

        internal static bool TryStartUpdate(Action<string> log, out string status)
        {
            status = "Abrindo o painel";
            if (String.Equals(Environment.GetEnvironmentVariable("BOUNTY_STUDIO_SKIP_UPDATE"), "1", StringComparison.Ordinal))
            {
                status = "Abrindo a versão restaurada após uma falha de atualização";
                return false;
            }
            string repository = BuildInfo.GitHubRepository;
            if (!IsRepositoryName(repository))
            {
                status = "Build local sem repositório de atualizações configurado";
                return false;
            }

            string stagedPath = null;
            try
            {
                ServicePointManager.SecurityProtocol = ServicePointManager.SecurityProtocol | (SecurityProtocolType)3072;
                GitHubReleaseInfo release = ReadLatestRelease(repository);
                Version latest = ParseVersion(release.TagName);
                Version current = ParseVersion(BuildInfo.Version);
                if (latest == null || current == null) throw new InvalidDataException("A versão da release ou do aplicativo não usa SemVer compatível.");
                if (latest <= current)
                {
                    status = "Versão " + BuildInfo.Version + " atualizada";
                    return false;
                }

                GitHubReleaseAsset asset = null;
                if (release.Assets != null)
                {
                    foreach (GitHubReleaseAsset item in release.Assets)
                    {
                        if (item != null && String.Equals(item.Name, "BountyStudio.exe", StringComparison.Ordinal)) { asset = item; break; }
                    }
                }
                if (asset == null) throw new InvalidDataException("A release mais recente não contém BountyStudio.exe.");
                string expectedHash = ReadDigest(asset.Digest);
                Uri downloadUri = ValidateDownloadUri(repository, asset.DownloadUrl);
                if (asset.Size <= 0 || asset.Size > MaximumDownloadSize) throw new InvalidDataException("O tamanho do executável de atualização não é válido.");

                string updateDirectory = Path.Combine(Program.AppRoot, "updates");
                Directory.CreateDirectory(updateDirectory);
                stagedPath = Path.Combine(updateDirectory, "BountyStudio.download.exe");
                DownloadAndVerify(downloadUri, stagedPath, asset.Size, expectedHash);

                string script = Path.Combine(updateDirectory, "apply-update.ps1");
                if (!File.Exists(script)) throw new FileNotFoundException("O auxiliar de atualização está ausente.", script);
                string target = Application.ExecutablePath;
                ProcessStartInfo start = new ProcessStartInfo
                {
                    FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "System32", "WindowsPowerShell", "v1.0", "powershell.exe"),
                    Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File " + Quote(script) +
                        " -ParentPid " + Process.GetCurrentProcess().Id.ToString() + " -StagedPath " + Quote(stagedPath) +
                        " -TargetPath " + Quote(target) + " -ExpectedSha256 " + Quote(expectedHash),
                    WorkingDirectory = Path.GetDirectoryName(target),
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                if (!File.Exists(start.FileName)) throw new FileNotFoundException("O Windows PowerShell não foi encontrado.", start.FileName);
                Process.Start(start);
                status = "Atualização " + release.TagName + " validada; reiniciando";
                if (log != null) log(status);
                return true;
            }
            catch (Exception ex)
            {
                if (!String.IsNullOrEmpty(stagedPath)) { try { File.Delete(stagedPath); } catch { } }
                status = "Não foi possível verificar a atualização; abrindo a versão atual";
                if (log != null) log("Atualizador: " + ex);
                return false;
            }
        }

        private static GitHubReleaseInfo ReadLatestRelease(string repository)
        {
            string url = "https://api.github.com/repos/" + repository + "/releases/latest";
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(url);
            request.Method = "GET";
            request.Accept = "application/vnd.github+json";
            request.UserAgent = "BountyStudio-Updater/" + BuildInfo.Version;
            request.Timeout = 15000;
            request.ReadWriteTimeout = 15000;
            request.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;
            using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
            {
                if (response.StatusCode != HttpStatusCode.OK) throw new WebException("GitHub respondeu com " + (int)response.StatusCode + ".");
                using (Stream stream = response.GetResponseStream())
                {
                    DataContractJsonSerializer serializer = new DataContractJsonSerializer(typeof(GitHubReleaseInfo));
                    GitHubReleaseInfo release = serializer.ReadObject(stream) as GitHubReleaseInfo;
                    if (release == null || release.Draft || release.Prerelease) throw new InvalidDataException("A resposta não contém uma release estável válida.");
                    return release;
                }
            }
        }

        private static void DownloadAndVerify(Uri uri, string destination, long expectedSize, string expectedHash)
        {
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(uri);
            request.Method = "GET";
            request.UserAgent = "BountyStudio-Updater/" + BuildInfo.Version;
            request.Timeout = 30000;
            request.ReadWriteTimeout = 45000;
            using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
            {
                Uri finalUri = response.ResponseUri;
                if (finalUri == null || finalUri.Scheme != Uri.UriSchemeHttps ||
                    !(String.Equals(finalUri.Host, "github.com", StringComparison.OrdinalIgnoreCase) ||
                      String.Equals(finalUri.Host, "release-assets.githubusercontent.com", StringComparison.OrdinalIgnoreCase) ||
                      String.Equals(finalUri.Host, "objects.githubusercontent.com", StringComparison.OrdinalIgnoreCase)))
                    throw new InvalidDataException("O download foi redirecionado para uma origem não autorizada.");

                using (Stream input = response.GetResponseStream())
                using (FileStream output = new FileStream(destination, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    byte[] buffer = new byte[81920];
                    long total = 0;
                    int count;
                    while ((count = input.Read(buffer, 0, buffer.Length)) > 0)
                    {
                        total += count;
                        if (total > MaximumDownloadSize || total > expectedSize) throw new InvalidDataException("O download ultrapassou o tamanho publicado pelo GitHub.");
                        output.Write(buffer, 0, count);
                    }
                    output.Flush();
                    if (total != expectedSize) throw new InvalidDataException("O tamanho do download não confere com a release.");
                }
            }

            string actualHash;
            using (FileStream file = File.OpenRead(destination))
            using (SHA256 sha = SHA256.Create()) actualHash = Hex(sha.ComputeHash(file));
            if (!String.Equals(actualHash, expectedHash, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("A verificação SHA-256 do executável falhou.");
        }

        private static string ReadDigest(string digest)
        {
            if (String.IsNullOrEmpty(digest) || !digest.StartsWith("sha256:", StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("A release não publicou um digest SHA-256; a atualização foi cancelada.");
            string hash = digest.Substring(7);
            if (hash.Length != 64) throw new InvalidDataException("O digest SHA-256 da release é inválido.");
            foreach (char character in hash) if (!Uri.IsHexDigit(character)) throw new InvalidDataException("O digest SHA-256 da release é inválido.");
            return hash;
        }

        private static Uri ValidateDownloadUri(string repository, string value)
        {
            Uri uri;
            if (!Uri.TryCreate(value, UriKind.Absolute, out uri) || uri.Scheme != Uri.UriSchemeHttps ||
                !String.Equals(uri.Host, "github.com", StringComparison.OrdinalIgnoreCase) ||
                !uri.AbsolutePath.StartsWith("/" + repository + "/releases/download/", StringComparison.OrdinalIgnoreCase) ||
                !uri.AbsolutePath.EndsWith("/BountyStudio.exe", StringComparison.Ordinal))
                throw new InvalidDataException("A URL do executável não pertence à release configurada.");
            return uri;
        }

        private static bool IsRepositoryName(string repository)
        {
            if (String.IsNullOrWhiteSpace(repository)) return false;
            string[] parts = repository.Split('/');
            if (parts.Length != 2 || parts[0].Length == 0 || parts[1].Length == 0) return false;
            for (int part = 0; part < parts.Length; part++)
                foreach (char character in parts[part])
                    if (!(Char.IsLetterOrDigit(character) || character == '-' || character == '_' || character == '.')) return false;
            return true;
        }

        private static Version ParseVersion(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return null;
            string clean = value.Trim();
            if (clean.StartsWith("v", StringComparison.OrdinalIgnoreCase)) clean = clean.Substring(1);
            if (clean.IndexOf('-') >= 0 || clean.IndexOf('+') >= 0) return null;
            string[] parts = clean.Split('.');
            if (parts.Length == 2) clean += ".0";
            Version parsed;
            return Version.TryParse(clean, out parsed) ? parsed : null;
        }

        private static string Hex(byte[] bytes)
        {
            StringBuilder result = new StringBuilder(bytes.Length * 2);
            foreach (byte value in bytes) result.Append(value.ToString("x2"));
            return result.ToString();
        }

        private static string Quote(string value) { return "\"" + value.Replace("\"", "\\\"") + "\""; }
    }

    internal sealed class MainForm : Form
    {
        internal const string Address = "http://127.0.0.1:8787";
        private static readonly Color WindowColor = Color.FromArgb(9, 10, 10);
        private static readonly Color PanelColor = Color.FromArgb(18, 19, 18);
        private static readonly Color TextColor = Color.FromArgb(242, 241, 236);
        private static readonly Color MutedColor = Color.FromArgb(164, 162, 153);
        private static readonly Color AccentColor = Color.FromArgb(213, 190, 137);

        private readonly string appRoot;
        private readonly string dataRoot;
        private readonly string logPath;
        private readonly WebView2 browser;
        private readonly Panel loadingPanel;
        private readonly Label loadingStatus;
        private readonly Label loadingDetails;
        private readonly StudioProgressIndicator progress;
        private readonly Button retryButton;
        private readonly LinkLabel runtimeLink;
        private readonly object logLock = new object();
        private Process serverProcess;
        private CoreWebView2Environment webViewEnvironment;
        private IntPtr jobHandle = IntPtr.Zero;
        private bool closing;
        private bool starting;

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            NativeWindowChrome.Apply(Handle);
        }

        public MainForm()
        {
            appRoot = Program.AppRoot;
            dataRoot = Path.Combine(appRoot, "dados");
            logPath = Path.Combine(appRoot, "logs", "launcher.log");
            Directory.CreateDirectory(Path.Combine(appRoot, "logs"));
            Directory.CreateDirectory(dataRoot);
            CreateJob();

            Text = "Bounty Studio - Live Control";
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(1280, 850);
            MinimumSize = new Size(1000, 700);
            FormBorderStyle = FormBorderStyle.Sizable;
            MaximizeBox = true;
            BackColor = WindowColor;
            ForeColor = TextColor;
            Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
            try { Icon = new Icon(Path.Combine(appRoot, "BountyStudio.ico")); } catch (Exception ex) { Log("Icon: " + ex.Message); }

            browser = new WebView2
            {
                Dock = DockStyle.Fill,
                Visible = false,
                ZoomFactor = 1.0,
                DefaultBackgroundColor = Color.FromArgb(255, 9, 10, 10)
            };
            Controls.Add(browser);

            loadingPanel = new Panel { Dock = DockStyle.Fill, BackColor = WindowColor };
            Controls.Add(loadingPanel);
            loadingPanel.BringToFront();

            Panel card = new Panel { Size = new Size(760, 470), BackColor = PanelColor };
            card.Paint += delegate(object sender, PaintEventArgs e)
            {
                System.Drawing.Graphics g = e.Graphics;
                g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                Rectangle bounds = new Rectangle(0, 0, card.Width - 1, card.Height - 1);
                int radius = 24;
                using (System.Drawing.Drawing2D.GraphicsPath shape = new System.Drawing.Drawing2D.GraphicsPath())
                {
                    shape.AddArc(bounds.X, bounds.Y, radius, radius, 180, 90);
                    shape.AddArc(bounds.Right - radius, bounds.Y, radius, radius, 270, 90);
                    shape.AddArc(bounds.Right - radius, bounds.Bottom - radius, radius, radius, 0, 90);
                    shape.AddArc(bounds.X, bounds.Bottom - radius, radius, radius, 90, 90);
                    shape.CloseFigure();
                    using (Brush fill = new System.Drawing.Drawing2D.LinearGradientBrush(bounds, Color.FromArgb(25, 25, 23), Color.FromArgb(15, 16, 15), 24F)) g.FillPath(fill, shape);
                    using (Pen border = new Pen(Color.FromArgb(57, 56, 51))) g.DrawPath(border, shape);
                }
                using (Brush glow = new SolidBrush(Color.FromArgb(15, AccentColor))) g.FillEllipse(glow, 520, 38, 205, 205);
                using (Pen orbit = new Pen(Color.FromArgb(38, AccentColor), 1F))
                {
                    g.DrawEllipse(orbit, 535, 59, 176, 176);
                    g.DrawEllipse(orbit, 555, 79, 136, 136);
                    g.DrawArc(orbit, 520, 92, 205, 105, 205, 128);
                }
                Point[] heroGem = { new Point(607, 87), new Point(654, 87), new Point(684, 120), new Point(630, 184), new Point(577, 120) };
                using (Pen gem = new Pen(Color.FromArgb(205, AccentColor), 2.2F)) g.DrawPolygon(gem, heroGem);
                using (Pen facets = new Pen(Color.FromArgb(120, 222, 208, 168), 1.2F))
                {
                    g.DrawLine(facets, 577, 120, 684, 120);
                    g.DrawLine(facets, 607, 87, 630, 184);
                    g.DrawLine(facets, 654, 87, 630, 184);
                }
                using (Pen accent = new Pen(AccentColor, 3F)) g.DrawLine(accent, 43, 0, 158, 0);
                using (Pen divider = new Pen(Color.FromArgb(46, 46, 42), 1F)) g.DrawLine(divider, 48, 258, 513, 258);
                using (Brush dot = new SolidBrush(Color.FromArgb(125, AccentColor)))
                {
                    g.FillEllipse(dot, 560, 273, 4, 4); g.FillEllipse(dot, 590, 296, 3, 3); g.FillEllipse(dot, 678, 253, 4, 4);
                    g.FillEllipse(dot, 705, 291, 3, 3); g.FillEllipse(dot, 541, 229, 3, 3); g.FillEllipse(dot, 696, 67, 3, 3);
                }
                using (Font meta = new Font("Segoe UI Semibold", 8F, FontStyle.Bold))
                using (Brush metaBrush = new SolidBrush(Color.FromArgb(132, 133, 127)))
                    g.DrawString("LIVE OVERLAY     ·     1200 × 360", meta, metaBrush, 540, 328);
            };
            using (System.Drawing.Drawing2D.GraphicsPath cardShape = new System.Drawing.Drawing2D.GraphicsPath())
            {
                int r = 24; cardShape.AddArc(0, 0, r, r, 180, 90); cardShape.AddArc(card.Width-r, 0, r, r, 270, 90);
                cardShape.AddArc(card.Width-r, card.Height-r, r, r, 0, 90); cardShape.AddArc(0, card.Height-r, r, r, 90, 90); cardShape.CloseFigure();
                card.Region = new Region(cardShape);
            }
            loadingPanel.Controls.Add(card);
            Panel iconBadge = new Panel { Size = new Size(58, 58), Location = new Point(48, 46), BackColor = Color.FromArgb(27, 27, 24) };
            iconBadge.Paint += delegate(object sender, PaintEventArgs e)
            {
                e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                Point[] gem = { new Point(19, 8), new Point(38, 8), new Point(50, 22), new Point(29, 50), new Point(8, 22) };
                using (Pen outline = new Pen(AccentColor, 2F)) e.Graphics.DrawPolygon(outline, gem);
                using (Pen facet = new Pen(Color.FromArgb(126, 123, 111), 1.2F))
                {
                    e.Graphics.DrawLine(facet, 8, 22, 50, 22);
                    e.Graphics.DrawLine(facet, 19, 8, 29, 50);
                    e.Graphics.DrawLine(facet, 38, 8, 29, 50);
                }
                using (Pen glow = new Pen(Color.FromArgb(90, AccentColor), 1F)) e.Graphics.DrawLine(glow, 19, 8, 29, 8);
            };
            card.Controls.Add(iconBadge);
            Label kicker = new Label { Text = "Bounty Studio", Font = new Font("Segoe UI Semibold", 18F, FontStyle.Bold), ForeColor = AccentColor, AutoSize = false, TextAlign = ContentAlignment.MiddleLeft, Location = new Point(122, 45), Size = new Size(430, 34) };
            card.Controls.Add(kicker);
            Label title = new Label { Text = "Live Control", Font = new Font("Segoe UI Semibold", 31F, FontStyle.Bold), ForeColor = TextColor, AutoSize = false, TextAlign = ContentAlignment.MiddleLeft, Location = new Point(48, 132), Size = new Size(480, 56) };
            card.Controls.Add(title);
            Label tagline = new Label { Text = "Bônus, Preferred List e overlay em um só lugar.", Font = new Font("Segoe UI", 10F), ForeColor = MutedColor, AutoSize = false, TextAlign = ContentAlignment.MiddleLeft, Location = new Point(50, 198), Size = new Size(458, 36) };
            card.Controls.Add(tagline);
            loadingStatus = new Label { Text = "Preparando o painel...", Font = new Font("Segoe UI Semibold", 10F, FontStyle.Bold), ForeColor = AccentColor, AutoSize = false, TextAlign = ContentAlignment.MiddleLeft, Location = new Point(50, 278), Size = new Size(460, 27) };
            card.Controls.Add(loadingStatus);
            loadingDetails = new Label { Text = "Iniciando o servidor local", Font = new Font("Segoe UI", 9F), ForeColor = MutedColor, AutoSize = false, TextAlign = ContentAlignment.MiddleLeft, Location = new Point(50, 307), Size = new Size(460, 24) };
            card.Controls.Add(loadingDetails);
            progress = new StudioProgressIndicator { Location = new Point(50, 360), Size = new Size(460, 9) };
            card.Controls.Add(progress);
            retryButton = new Button
            {
                Text = "Tentar novamente", Visible = false, Location = new Point(50, 386), Size = new Size(162, 38),
                FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(42, 39, 32), ForeColor = TextColor,
                Font = new Font("Segoe UI Semibold", 9F, FontStyle.Bold), Cursor = Cursors.Hand, UseVisualStyleBackColor = false
            };
            retryButton.FlatAppearance.BorderSize = 0;
            retryButton.Click += delegate { StartApplication(); };
            card.Controls.Add(retryButton);
            runtimeLink = new LinkLabel
            {
                Text = "Instalar WebView2 Runtime da Microsoft", Visible = false,
                LinkColor = AccentColor, ActiveLinkColor = AccentColor, VisitedLinkColor = AccentColor,
                AutoSize = false, TextAlign = ContentAlignment.MiddleLeft, Location = new Point(50, 438), Size = new Size(470, 20), Font = new Font("Segoe UI", 8.5F)
            };
            runtimeLink.LinkClicked += delegate { OpenRuntimeDownload(); };
            card.Controls.Add(runtimeLink);

            loadingPanel.Resize += delegate
            {
                card.Left = Math.Max(0, (loadingPanel.ClientSize.Width - card.Width) / 2);
                card.Top = Math.Max(0, (loadingPanel.ClientSize.Height - card.Height) / 2);
            };
            card.Left = (ClientSize.Width - card.Width) / 2;
            card.Top = (ClientSize.Height - card.Height) / 2;

            Shown += delegate { StartApplication(); };
            FormClosing += OnFormClosing;
        }

        private async void StartApplication()
        {
            if (starting || closing) return;
            starting = true;
            retryButton.Visible = false;
            runtimeLink.Visible = false;
            progress.Visible = true;
            SetLoading("Verificando atualizações...", "Consultando a release estável do GitHub", AccentColor);
            try
            {
                string updateStatus = null;
                bool updateStarted = await Task.Run(delegate { return GitHubUpdater.TryStartUpdate(Log, out updateStatus); });
                if (updateStarted)
                {
                    closing = true;
                    Close();
                    return;
                }
                SetLoading("Preparando o painel...", updateStatus ?? "Iniciando o servidor local", AccentColor);
                await Task.Run(new Action(StartLocalServer));
                SetLoading("Abrindo o aplicativo...", "Carregando a interface integrada", AccentColor);
                string version = CoreWebView2Environment.GetAvailableBrowserVersionString();
                if (String.IsNullOrEmpty(version)) throw new InvalidOperationException("O WebView2 Runtime nao foi encontrado neste Windows.");
                string profile = Path.Combine(appRoot, "WebView2Data");
                Directory.CreateDirectory(profile);
                webViewEnvironment = await CoreWebView2Environment.CreateAsync(null, profile, null);
                await browser.EnsureCoreWebView2Async(webViewEnvironment);
                ConfigureBrowser(browser.CoreWebView2, true);
                await NavigateToPanel();
                if (closing) return;
                Text = "Bounty Studio";
                browser.Visible = true;
                browser.BringToFront();
                loadingPanel.Visible = false;
            }
            catch (Exception ex)
            {
                Log(ex.ToString());
                if (!closing) ShowFailure(ex);
            }
            finally { starting = false; }
        }

        private void StartLocalServer()
        {
            Directory.CreateDirectory(dataRoot);
            MigrateExistingProjectData();
            if (HealthCheck()) return;

            ProcessStartInfo start = new ProcessStartInfo
            {
                FileName = PowerShellPath(),
                Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File " + Quote(Path.Combine(appRoot, "servidor-windows.ps1")) + " -Port 8787 -NoBrowser",
                WorkingDirectory = appRoot,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            serverProcess = new Process { StartInfo = start, EnableRaisingEvents = true };
            serverProcess.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (!String.IsNullOrEmpty(e.Data)) Log(e.Data); };
            serverProcess.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (!String.IsNullOrEmpty(e.Data)) Log(e.Data); };
            if (!serverProcess.Start()) throw new InvalidOperationException("Nao foi possivel iniciar o servidor local.");
            serverProcess.BeginOutputReadLine();
            serverProcess.BeginErrorReadLine();
            AssignToJob(serverProcess);

            for (int i = 0; i < 60 && !closing; i++)
            {
                if (HealthCheck()) return;
                if (serverProcess.HasExited && i > 4 && !HealthCheck()) break;
                Thread.Sleep(350);
            }
            throw new InvalidOperationException("O servidor local nao respondeu. Consulte logs\\launcher.log na pasta de dados do aplicativo.");
        }

        private async Task NavigateToPanel()
        {
            TaskCompletionSource<bool> navigation = new TaskCompletionSource<bool>();
            EventHandler<CoreWebView2NavigationCompletedEventArgs> handler = null;
            handler = delegate(object sender, CoreWebView2NavigationCompletedEventArgs args)
            {
                if (args.IsSuccess) navigation.TrySetResult(true);
                else navigation.TrySetException(new InvalidOperationException("O painel nao carregou: " + args.WebErrorStatus));
            };
            browser.CoreWebView2.NavigationCompleted += handler;
            try
            {
                browser.Source = new Uri(Address + "/painel");
                Task finished = await Task.WhenAny(navigation.Task, Task.Delay(TimeSpan.FromSeconds(25)));
                if (finished != navigation.Task) throw new TimeoutException("O painel demorou demais para carregar.");
                await navigation.Task;
            }
            finally { browser.CoreWebView2.NavigationCompleted -= handler; }
        }

        private void ConfigureBrowser(CoreWebView2 core, bool mainWindow)
        {
            core.Settings.AreDevToolsEnabled = false;
            core.Settings.AreDefaultContextMenusEnabled = false;
            core.Settings.IsStatusBarEnabled = false;
            core.Settings.IsZoomControlEnabled = true;
            core.NavigationStarting += delegate(object sender, CoreWebView2NavigationStartingEventArgs e)
            {
                if (!IsAllowedLocalUrl(e.Uri)) e.Cancel = true;
            };
            core.NewWindowRequested += delegate(object sender, CoreWebView2NewWindowRequestedEventArgs e)
            {
                if (mainWindow) HandleNewWindowRequested(core, e);
                else e.Handled = true;
            };
            core.WindowCloseRequested += delegate
            {
                if (!mainWindow && IsHandleCreated) BeginInvoke((MethodInvoker)delegate { Close(); });
            };
            if (mainWindow)
                core.DownloadStarting += OnDownloadStarting;
        }

        private async void HandleNewWindowRequested(CoreWebView2 source, CoreWebView2NewWindowRequestedEventArgs e)
        {
            if (!IsAllowedLocalUrl(e.Uri)) { e.Handled = true; return; }
            CoreWebView2Deferral deferral = e.GetDeferral();
            OverlayWindow overlay = null;
            try
            {
                overlay = new OverlayWindow(webViewEnvironment, e.Uri);
                await overlay.InitializeAsync();
                if (closing) { e.Handled = true; overlay.Dispose(); return; }
                e.NewWindow = overlay.Browser.CoreWebView2;
                overlay.Show(this);
            }
            catch (Exception ex)
            {
                e.Handled = true;
                if (overlay != null) overlay.Dispose();
                Log("Overlay interno: " + ex);
            }
            finally { deferral.Complete(); }
        }

        private void OnDownloadStarting(object sender, CoreWebView2DownloadStartingEventArgs e)
        {
            e.Handled = true;
            CoreWebView2Deferral deferral = e.GetDeferral();
            try
            {
                BeginInvoke((MethodInvoker)delegate
                {
                    try
                    {
                        using (SaveFileDialog dialog = new SaveFileDialog())
                        {
                            string suggested = Path.GetFileName(e.DownloadOperation.ResultFilePath);
                            if (String.IsNullOrWhiteSpace(suggested)) suggested = "bounty-overlay.webm";
                            dialog.Title = "Salvar overlay transparente";
                            dialog.FileName = suggested;
                            dialog.DefaultExt = "webm";
                            dialog.AddExtension = true;
                            dialog.Filter = "Video transparente WebM (*.webm)|*.webm";
                            string downloads = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
                            if (Directory.Exists(downloads)) dialog.InitialDirectory = downloads;
                            if (dialog.ShowDialog(this) == DialogResult.OK) e.ResultFilePath = dialog.FileName;
                            else e.Cancel = true;
                        }
                    }
                    catch (Exception ex) { e.Cancel = true; Log("Download: " + ex); }
                    finally { deferral.Complete(); }
                });
            }
            catch { e.Cancel = true; deferral.Complete(); }
        }

        internal static bool IsAllowedLocalUrl(string value)
        {
            Uri uri;
            return Uri.TryCreate(value, UriKind.Absolute, out uri) &&
                String.Equals(uri.Scheme, Uri.UriSchemeHttp, StringComparison.OrdinalIgnoreCase) &&
                String.Equals(uri.Host, "127.0.0.1", StringComparison.OrdinalIgnoreCase) && uri.Port == 8787;
        }

        private void ShowFailure(Exception ex)
        {
            progress.Visible = false;
            loadingStatus.Text = "Nao foi possivel abrir o painel";
            loadingStatus.ForeColor = Color.FromArgb(232, 123, 112);
            string message = ex.Message;
            if (ex is WebView2RuntimeNotFoundException || message.IndexOf("WebView2 Runtime", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                loadingDetails.Text = "Instale o componente oficial da Microsoft para este aplicativo.";
                runtimeLink.Visible = true;
            }
            else loadingDetails.Text = message.Length > 120 ? message.Substring(0, 117) + "..." : message;
            retryButton.Visible = true;
            retryButton.BringToFront();
        }

        private static void OpenRuntimeDownload()
        {
            try { Process.Start(new ProcessStartInfo { FileName = "https://developer.microsoft.com/microsoft-edge/webview2/", UseShellExecute = true }); }
            catch { }
        }

        private void SetLoading(string title, string details, Color color)
        {
            loadingStatus.Text = title;
            loadingStatus.ForeColor = color;
            loadingDetails.Text = details;
        }

        private void MigrateExistingProjectData()
        {
            string marker = Path.Combine(appRoot, "project-data-migrated.txt");
            if (File.Exists(marker) || File.Exists(Path.Combine(dataRoot, "bounty-state.json"))) return;
            string executableDirectory = Path.GetDirectoryName(Application.ExecutablePath);
            List<string> roots = new List<string>();
            if (IsProjectRoot(executableDirectory)) roots.Add(executableDirectory);
            DirectoryInfo parent = Directory.GetParent(executableDirectory);
            if (parent != null && IsProjectRoot(parent.FullName)) roots.Add(parent.FullName);

            foreach (string root in roots)
            {
                string sourceData = Path.Combine(root, "dados");
                if (!Directory.Exists(sourceData) || (File.GetAttributes(sourceData) & FileAttributes.ReparsePoint) != 0) continue;
                try
                {
                    CopySmallDataFile(sourceData, "creature-info-cache.json", 5 * 1024 * 1024);
                    CopyGifCache(sourceData, "sprites", 64 * 1024 * 1024);
                    CopyGifCache(sourceData, "charm-icons", 16 * 1024 * 1024);
                    CopySmallDataFile(sourceData, "bounty-state.json", 2 * 1024 * 1024);
                    File.WriteAllText(marker, "Migrated from " + root + Environment.NewLine, Encoding.UTF8);
                    Log("Configuracao e caches existentes migrados de " + root);
                    return;
                }
                catch (Exception ex) { Log("Migracao de dados nao concluida: " + ex.Message); }
            }
        }

        private static bool IsProjectRoot(string path)
        {
            return !String.IsNullOrEmpty(path) &&
                File.Exists(Path.Combine(path, "src", "BountyStudio.Web", "overlay.html")) &&
                File.Exists(Path.Combine(path, "src", "BountyStudio.Server", "servidor-windows.ps1"));
        }

        private void CopySmallDataFile(string sourceData, string fileName, long maximumBytes)
        {
            string source = Path.Combine(sourceData, fileName);
            string target = Path.Combine(dataRoot, fileName);
            if (!File.Exists(source) || File.Exists(target) || (File.GetAttributes(source) & FileAttributes.ReparsePoint) != 0) return;
            FileInfo info = new FileInfo(source);
            if (info.Length <= maximumBytes) File.Copy(source, target, false);
            else Log("Arquivo ignorado por exceder limite: " + fileName);
        }

        private void CopyGifCache(string sourceData, string directoryName, long maximumBytes)
        {
            string sourceDirectory = Path.Combine(sourceData, directoryName);
            string targetDirectory = Path.Combine(dataRoot, directoryName);
            if (!Directory.Exists(sourceDirectory) || (File.GetAttributes(sourceDirectory) & FileAttributes.ReparsePoint) != 0) return;
            Directory.CreateDirectory(targetDirectory);
            string[] files = Directory.GetFiles(sourceDirectory, "*.gif", SearchOption.TopDirectoryOnly);
            if (files.Length > 2000) return;
            long copied = 0;
            foreach (string source in files)
            {
                FileInfo info = new FileInfo(source);
                if ((info.Attributes & FileAttributes.ReparsePoint) != 0 || info.Length > 25 * 1024 * 1024) continue;
                string target = Path.Combine(targetDirectory, info.Name);
                if (File.Exists(target) || copied + info.Length > maximumBytes) continue;
                File.Copy(source, target, false);
                copied += info.Length;
            }
        }

        private void CreateJob()
        {
            try
            {
                jobHandle = CreateJobObject(IntPtr.Zero, null);
                if (jobHandle == IntPtr.Zero) return;
                ExtendedLimitInformation limits = new ExtendedLimitInformation();
                limits.BasicLimitInformation.LimitFlags = 0x00002000;
                if (!SetInformationJobObject(jobHandle, 9, ref limits, (uint)Marshal.SizeOf(typeof(ExtendedLimitInformation))))
                {
                    CloseHandle(jobHandle);
                    jobHandle = IntPtr.Zero;
                }
            }
            catch { jobHandle = IntPtr.Zero; }
        }

        private void AssignToJob(Process process)
        {
            if (jobHandle == IntPtr.Zero || process == null) return;
            try { AssignProcessToJobObject(jobHandle, process.Handle); }
            catch (Exception ex) { Log("Processo sem gerenciamento de encerramento: " + ex.Message); }
        }

        private static bool HealthCheck()
        {
            try
            {
                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(Address + "/api/health");
                request.Timeout = 800;
                request.ReadWriteTimeout = 800;
                request.Proxy = null;
                using (HttpWebResponse response = (HttpWebResponse)request.GetResponse()) return response.StatusCode == HttpStatusCode.OK;
            }
            catch { return false; }
        }

        private static string PowerShellPath()
        {
            string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
            if (!File.Exists(path)) throw new FileNotFoundException("O Windows PowerShell 5.1 nao foi encontrado.");
            return path;
        }

        private static string Quote(string value) { return "\"" + value.Replace("\"", "\\\"") + "\""; }

        private void Log(string text)
        {
            try
            {
                lock (logLock)
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(logPath));
                    File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + text + Environment.NewLine, Encoding.UTF8);
                    FileInfo info = new FileInfo(logPath);
                    if (info.Length > 1024 * 1024)
                    {
                        string old = File.ReadAllText(logPath, Encoding.UTF8);
                        File.WriteAllText(logPath, old.Substring(Math.Max(0, old.Length - 512 * 1024)), Encoding.UTF8);
                    }
                }
            }
            catch { }
        }

        private void OnFormClosing(object sender, FormClosingEventArgs e)
        {
            closing = true;
            if (jobHandle != IntPtr.Zero) { CloseHandle(jobHandle); jobHandle = IntPtr.Zero; }
            try { if (serverProcess != null && !serverProcess.HasExited) serverProcess.Kill(); } catch { }
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct BasicLimitInformation
        {
            public long PerProcessUserTimeLimit;
            public long PerJobUserTimeLimit;
            public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize;
            public UIntPtr MaximumWorkingSetSize;
            public uint ActiveProcessLimit;
            public UIntPtr Affinity;
            public uint PriorityClass;
            public uint SchedulingClass;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct IoCounters
        {
            public ulong ReadOperationCount;
            public ulong WriteOperationCount;
            public ulong OtherOperationCount;
            public ulong ReadTransferCount;
            public ulong WriteTransferCount;
            public ulong OtherTransferCount;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct ExtendedLimitInformation
        {
            public BasicLimitInformation BasicLimitInformation;
            public IoCounters IoInfo;
            public UIntPtr ProcessMemoryLimit;
            public UIntPtr JobMemoryLimit;
            public UIntPtr PeakProcessMemoryUsed;
            public UIntPtr PeakJobMemoryUsed;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetInformationJobObject(IntPtr job, int infoClass, ref ExtendedLimitInformation info, uint length);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);
    }

    internal sealed class OverlayWindow : Form
    {
        private readonly CoreWebView2Environment environment;
        private readonly string address;
        internal WebView2 Browser { get; private set; }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            NativeWindowChrome.Apply(Handle);
        }

        internal OverlayWindow(CoreWebView2Environment environment, string address)
        {
            this.environment = environment;
            this.address = address;
            Text = "Bounty Studio";
            StartPosition = FormStartPosition.CenterParent;
            ClientSize = new Size(1200, 360);
            MinimumSize = new Size(820, 280);
            BackColor = Color.FromArgb(13, 19, 27);
            FormBorderStyle = FormBorderStyle.Sizable;
            try { Icon = new Icon(Path.Combine(Program.AppRoot, "BountyStudio.ico")); } catch { }
            Browser = new WebView2 { Dock = DockStyle.Fill, DefaultBackgroundColor = Color.Transparent };
            Controls.Add(Browser);
        }

        internal async Task InitializeAsync()
        {
            await Browser.EnsureCoreWebView2Async(environment);
            Browser.CoreWebView2.Settings.AreDevToolsEnabled = false;
            Browser.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
            Browser.CoreWebView2.Settings.IsStatusBarEnabled = false;
            Browser.CoreWebView2.NewWindowRequested += delegate(object sender, CoreWebView2NewWindowRequestedEventArgs e) { e.Handled = true; };
            Browser.CoreWebView2.NavigationStarting += delegate(object sender, CoreWebView2NavigationStartingEventArgs e) { if (!MainForm.IsAllowedLocalUrl(e.Uri)) e.Cancel = true; };
            Browser.CoreWebView2.WindowCloseRequested += delegate { if (IsHandleCreated) BeginInvoke((MethodInvoker)delegate { Close(); }); };
        }
    }
}
