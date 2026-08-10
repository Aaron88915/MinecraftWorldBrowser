param(
    [string]$OutputName = 'MinecraftWorldBrowser.exe'
)

$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
$sourceScript = Join-Path $projectDirectory 'MinecraftWorldBrowser.ps1'
$assetDirectory = Join-Path $projectDirectory 'assets'
$buildDirectory = Join-Path $projectDirectory 'build'
$iconPath = Join-Path $assetDirectory 'MinecraftWorldBrowser.ico'
$previewPath = Join-Path $assetDirectory 'MinecraftWorldBrowser-icon.png'
$exePath = Join-Path $projectDirectory $OutputName
$generatedSource = Join-Path $buildDirectory 'MinecraftWorldBrowser.generated.cs'

New-Item -ItemType Directory -Path $assetDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null

$iconBuilderSource = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

public static class WorldBrowserIconBuilder
{
    public static void Build(string iconPath, string previewPath)
    {
        int[] sizes = new int[] { 16, 24, 32, 48, 64, 128, 256 };
        List<byte[]> images = new List<byte[]>();
        foreach (int size in sizes)
        {
            using (Bitmap bitmap = Draw(size))
            using (MemoryStream memory = new MemoryStream())
            {
                bitmap.Save(memory, ImageFormat.Png);
                images.Add(memory.ToArray());
                if (size == 256) bitmap.Save(previewPath, ImageFormat.Png);
            }
        }

        using (FileStream output = File.Create(iconPath))
        using (BinaryWriter writer = new BinaryWriter(output))
        {
            writer.Write((ushort)0);
            writer.Write((ushort)1);
            writer.Write((ushort)sizes.Length);
            int offset = 6 + (16 * sizes.Length);
            for (int i = 0; i < sizes.Length; i++)
            {
                writer.Write((byte)(sizes[i] == 256 ? 0 : sizes[i]));
                writer.Write((byte)(sizes[i] == 256 ? 0 : sizes[i]));
                writer.Write((byte)0);
                writer.Write((byte)0);
                writer.Write((ushort)1);
                writer.Write((ushort)32);
                writer.Write(images[i].Length);
                writer.Write(offset);
                offset += images[i].Length;
            }
            foreach (byte[] image in images) writer.Write(image);
        }
    }

    private static Bitmap Draw(int size)
    {
        Bitmap bitmap = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (Graphics graphics = Graphics.FromImage(bitmap))
        {
            graphics.Clear(Color.Transparent);
            graphics.SmoothingMode = size <= 24 ? SmoothingMode.HighQuality : SmoothingMode.AntiAlias;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            graphics.CompositingQuality = CompositingQuality.HighQuality;

            float scale = size / 256f;
            RectangleF background = new RectangleF(9 * scale, 9 * scale, 238 * scale, 238 * scale);
            using (GraphicsPath path = Rounded(background, 45 * scale))
            using (Brush brush = new SolidBrush(Color.FromArgb(255, 39, 48, 50))) graphics.FillPath(brush, path);

            RectangleF mapBorder = new RectangleF(48 * scale, 43 * scale, 128 * scale, 130 * scale);
            using (GraphicsPath path = Rounded(mapBorder, 14 * scale))
            using (Brush brush = new SolidBrush(Color.FromArgb(255, 239, 243, 240))) graphics.FillPath(brush, path);

            RectangleF map = new RectangleF(58 * scale, 53 * scale, 108 * scale, 110 * scale);
            using (GraphicsPath clipPath = Rounded(map, 7 * scale))
            {
                GraphicsState state = graphics.Save();
                graphics.SetClip(clipPath);
                using (Brush land = new SolidBrush(Color.FromArgb(255, 77, 151, 86))) graphics.FillRectangle(land, map);
                using (Brush landLight = new SolidBrush(Color.FromArgb(255, 116, 177, 92))) graphics.FillRectangle(landLight, 58 * scale, 53 * scale, 50 * scale, 45 * scale);
                using (Brush earth = new SolidBrush(Color.FromArgb(255, 173, 126, 70))) graphics.FillRectangle(earth, 58 * scale, 128 * scale, 108 * scale, 35 * scale);
                using (Brush water = new SolidBrush(Color.FromArgb(255, 43, 139, 174)))
                {
                    PointF[] river = new PointF[] {
                        new PointF(111 * scale, 48 * scale), new PointF(145 * scale, 48 * scale),
                        new PointF(132 * scale, 83 * scale), new PointF(150 * scale, 111 * scale),
                        new PointF(133 * scale, 145 * scale), new PointF(98 * scale, 172 * scale),
                        new PointF(78 * scale, 172 * scale), new PointF(112 * scale, 137 * scale),
                        new PointF(119 * scale, 109 * scale), new PointF(100 * scale, 81 * scale)
                    };
                    graphics.FillPolygon(water, river);
                }
                graphics.Restore(state);
            }

            using (Pen handleShadow = new Pen(Color.FromArgb(255, 28, 33, 35), 30 * scale))
            using (Pen handle = new Pen(Color.FromArgb(255, 240, 177, 68), 20 * scale))
            {
                handleShadow.StartCap = handleShadow.EndCap = LineCap.Round;
                handle.StartCap = handle.EndCap = LineCap.Round;
                graphics.DrawLine(handleShadow, 174 * scale, 174 * scale, 213 * scale, 215 * scale);
                graphics.DrawLine(handle, 174 * scale, 174 * scale, 213 * scale, 215 * scale);
            }

            RectangleF lens = new RectangleF(126 * scale, 117 * scale, 81 * scale, 81 * scale);
            using (Brush glass = new SolidBrush(Color.FromArgb(88, 215, 245, 239))) graphics.FillEllipse(glass, lens);
            using (Pen rim = new Pen(Color.FromArgb(255, 244, 247, 245), 15 * scale)) graphics.DrawEllipse(rim, lens);
        }
        return bitmap;
    }

    private static GraphicsPath Rounded(RectangleF rectangle, float radius)
    {
        GraphicsPath path = new GraphicsPath();
        float diameter = radius * 2;
        path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
        path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
        path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }
}
'@

Add-Type -TypeDefinition $iconBuilderSource -Language CSharp -ReferencedAssemblies @('System.Drawing')
[WorldBrowserIconBuilder]::Build($iconPath, $previewPath)

$scriptText = Get-Content -LiteralPath $sourceScript -Raw -Encoding UTF8
$match = [regex]::Match($scriptText, '(?s)\$source\s*=\s*@''\r?\n(?<source>.*?)\r?\n''@')
if (-not $match.Success) { throw 'Could not extract the embedded C# source.' }
[IO.File]::WriteAllText($generatedSource, $match.Groups['source'].Value, (New-Object Text.UTF8Encoding($false)))

$compilerCandidates = @(
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
)
$compiler = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $compiler) { throw 'The .NET Framework C# compiler was not found.' }

$arguments = @(
    '/nologo',
    '/target:winexe',
    '/optimize+',
    '/codepage:65001',
    '/platform:anycpu',
    ('/win32icon:' + $iconPath),
    ('/out:' + $exePath),
    '/reference:System.dll',
    '/reference:System.Core.dll',
    '/reference:System.Drawing.dll',
    '/reference:System.IO.Compression.dll',
    '/reference:System.IO.Compression.FileSystem.dll',
    '/reference:System.Windows.Forms.dll',
    $generatedSource
)
& $compiler $arguments
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath)) { throw 'EXE compilation failed.' }

$icon = New-Object Drawing.Icon($iconPath)
try {
    if ($icon.Width -lt 16 -or $icon.Height -lt 16) { throw 'Generated icon is invalid.' }
} finally { $icon.Dispose() }

Write-Output ('BUILD OK: ' + $exePath)
Write-Output ('ICON OK:  ' + $iconPath)
