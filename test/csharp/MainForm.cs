using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using Newtonsoft.Json;

namespace TestApp;

public class MainForm : Form
{
    private readonly HttpClient _http = new();
    private TextBox _txtOutput = new();
    private Button _btnLocal = new();
    private Button _btnServer = new();
    private Label _lblUrl = new();
    private TextBox _txtUrl = new();

    public MainForm()
    {
        Text = "Dependency Check";
        Width = 520;
        Height = 380;
        StartPosition = FormStartPosition.CenterScreen;

        _lblUrl.Text = "Java server:";
        _lblUrl.Location = new System.Drawing.Point(12, 15);
        _lblUrl.AutoSize = true;

        _txtUrl.Text = "http://localhost:9090/api/check";
        _txtUrl.Width = 320;
        _txtUrl.Location = new System.Drawing.Point(90, 12);

        _btnLocal.Text = "1. Test C# libs";
        _btnLocal.Width = 120;
        _btnLocal.Location = new System.Drawing.Point(12, 45);
        _btnLocal.Click += (s, e) => TestLocal();

        _btnServer.Text = "2. Test Java server";
        _btnServer.Width = 120;
        _btnServer.Location = new System.Drawing.Point(145, 45);
        _btnServer.Click += async (s, e) => await TestServer();

        _txtOutput.Multiline = true;
        _txtOutput.ReadOnly = true;
        _txtOutput.ScrollBars = ScrollBars.Vertical;
        _txtOutput.Font = new System.Drawing.Font("Consolas", 10);
        _txtOutput.Location = new System.Drawing.Point(12, 80);
        _txtOutput.Size = new System.Drawing.Size(480, 250);
        _txtOutput.Text = "Нажми кнопки по порядку:\n1. Test C# libs — проверяет Newtonsoft.Json (без сервера)\n2. Test Java server — проверяет все Java либы (нужен запущенный сервер)";

        Controls.AddRange(new Control[] { _lblUrl, _txtUrl, _btnLocal, _btnServer, _txtOutput });
    }

    private void TestLocal()
    {
        var sb = new StringBuilder();
        sb.AppendLine("=== C# LOCAL CHECKS ===");

        // WinForms
        sb.AppendLine("[OK] WinForms");

        // Newtonsoft.Json
        try
        {
            var obj = new { lib = "Newtonsoft.Json", version = "13.0.3", status = "OK" };
            string json = JsonConvert.SerializeObject(obj, Formatting.Indented);
            var back = JsonConvert.DeserializeObject<dynamic>(json)!;
            sb.AppendLine("[OK] Newtonsoft.Json — serialize + deserialize работает");
            sb.AppendLine("     " + json.Replace("\n", "\n     "));
        }
        catch (Exception ex)
        {
            sb.AppendLine("[FAIL] Newtonsoft.Json: " + ex.Message);
        }

        // HttpClient
        sb.AppendLine("[OK] HttpClient (System.Net.Http)");

        // .NET version
        sb.AppendLine($"[OK] .NET {Environment.Version}");

        sb.AppendLine("\nC# проверка завершена.");
        _txtOutput.Text = sb.ToString();
    }

    private async Task TestServer()
    {
        _txtOutput.Text = "Подключаюсь к " + _txtUrl.Text + " ...";
        try
        {
            string json = await _http.GetStringAsync(_txtUrl.Text);
            var obj = JsonConvert.DeserializeObject<Dictionary<string, string>>(json)!;

            var sb = new StringBuilder();
            sb.AppendLine("=== JAVA SERVER CHECKS ===");
            foreach (var kv in obj)
            {
                string icon = kv.Value.StartsWith("OK") ? "[OK]" : "[FAIL]";
                sb.AppendLine($"{icon} {kv.Key}: {kv.Value}");
            }
            sb.AppendLine("\nJava проверка завершена.");
            _txtOutput.Text = sb.ToString();
        }
        catch (Exception ex)
        {
            _txtOutput.Text = "[FAIL] Не удалось подключиться:\n" + ex.Message +
                              "\n\nЗапусти Java сервер:\n  cd test\\java\n  mvn spring-boot:run -o -Dmaven.repo.local=..\\..\\libs\\maven";
        }
    }
}
