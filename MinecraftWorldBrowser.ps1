param(
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

$source = @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;

[assembly: AssemblyTitle("Minecraft Java World Browser")]
[assembly: AssemblyProduct("Minecraft Java World Browser")]
[assembly: AssemblyDescription("Browse Minecraft Java worlds across popular launcher instance folders")]
[assembly: AssemblyCompany("Local Utility")]
[assembly: AssemblyVersion("3.2.6.0")]
[assembly: AssemblyFileVersion("3.2.6.0")]

namespace MinecraftWorldBrowser
{
    internal static class AppTheme
    {
        public static bool Dark { get; private set; }

        public static Color Ink { get { return InkFor(Dark); } }
        public static Color Muted { get { return MutedFor(Dark); } }
        public static Color Accent { get { return Dark ? Color.FromArgb(132, 166, 255) : Color.FromArgb(74, 118, 232); } }
        public static Color WindowBase { get { return WindowBaseFor(Dark); } }
        public static Color Sidebar { get { return SidebarFor(Dark); } }
        public static Color Canvas { get { return CanvasFor(Dark); } }
        public static Color Surface { get { return SurfaceFor(Dark); } }
        public static Color SurfaceRaised { get { return SurfaceRaisedFor(Dark); } }
        public static Color GlassSurface { get { return GlassSurfaceFor(Dark); } }
        public static Color SidebarCard { get { return SidebarCardFor(Dark); } }
        public static Color Line { get { return LineFor(Dark); } }
        public static Color Header { get { return Dark ? Color.FromArgb(39, 43, 52) : Color.FromArgb(218, 225, 235); } }
        public static Color AlternateRow { get { return Dark ? Color.FromArgb(36, 40, 48) : Color.FromArgb(228, 234, 242); } }
        public static Color Selection { get { return Dark ? Color.FromArgb(51, 67, 96) : Color.FromArgb(205, 218, 248); } }
        public static Color Hover { get { return Dark ? Color.FromArgb(46, 51, 62) : Color.FromArgb(233, 239, 246); } }
        public static Color InputBorder { get { return Dark ? Color.FromArgb(53, 58, 69) : Color.FromArgb(198, 207, 220); } }
        public static Color GlassEdge { get { return Color.Transparent; } }
        public static Color Shadow { get { return NeuDarkShadow; } }
        public static Color NeuLightShadow { get { return Dark ? Color.FromArgb(128, 67, 73, 86) : Color.FromArgb(224, 255, 255, 255); } }
        public static Color NeuDarkShadow { get { return Dark ? Color.FromArgb(190, 11, 13, 18) : Color.FromArgb(185, 173, 184, 199); } }
        public static Color SecondaryFill { get { return GlassSurface; } }
        public static Color SecondaryHover { get { return Dark ? Color.FromArgb(43, 47, 57) : Color.FromArgb(231, 237, 245); } }
        public static Color SecondaryPressed { get { return GlassSurface; } }
        public static Color SecondaryBorder { get { return Color.Transparent; } }
        public static Color DisabledFill { get { return Dark ? Color.FromArgb(34, 37, 44) : Color.FromArgb(218, 224, 233); } }
        public static Color DisabledText { get { return Dark ? Color.FromArgb(119, 125, 137) : Color.FromArgb(135, 145, 158); } }
        public static Color ScrollThumb { get { return Dark ? Color.FromArgb(155, 166, 185) : Color.FromArgb(125, 139, 158); } }
        public static Color ScrollThumbHover { get { return Dark ? Color.FromArgb(210, 218, 232) : Color.FromArgb(74, 118, 232); } }

        public static Color InkFor(bool dark) { return dark ? Color.FromArgb(236, 239, 244) : Color.FromArgb(47, 55, 68); }
        public static Color MutedFor(bool dark) { return dark ? Color.FromArgb(164, 171, 184) : Color.FromArgb(98, 110, 126); }
        public static Color WindowBaseFor(bool dark) { return dark ? Color.FromArgb(34, 37, 44) : Color.FromArgb(223, 229, 238); }
        public static Color SidebarFor(bool dark) { return dark ? Color.FromArgb(34, 37, 44) : Color.FromArgb(223, 229, 238); }
        public static Color CanvasFor(bool dark) { return dark ? Color.FromArgb(34, 37, 44) : Color.FromArgb(223, 229, 238); }
        public static Color SurfaceFor(bool dark) { return dark ? Color.FromArgb(38, 41, 49) : Color.FromArgb(223, 229, 238); }
        public static Color SurfaceRaisedFor(bool dark) { return dark ? Color.FromArgb(39, 42, 50) : Color.FromArgb(223, 229, 238); }
        public static Color GlassSurfaceFor(bool dark) { return dark ? Color.FromArgb(39, 42, 50) : Color.FromArgb(223, 229, 238); }
        public static Color SidebarCardFor(bool dark) { return dark ? Color.FromArgb(39, 42, 50) : Color.FromArgb(223, 229, 238); }
        public static Color LineFor(bool dark) { return dark ? Color.FromArgb(56, 61, 72) : Color.FromArgb(199, 208, 220); }

        public static void SetDark(bool dark) { Dark = dark; }

        public static void Load(string path)
        {
            try { Dark = File.Exists(path) && File.ReadAllText(path, Encoding.UTF8).Trim().Equals("dark", StringComparison.OrdinalIgnoreCase); }
            catch { Dark = false; }
        }

        public static void Save(string path)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllText(path, Dark ? "dark" : "light", Encoding.ASCII);
        }
    }

    internal static class NeumorphicRenderer
    {
        public static void DrawRaised(Graphics graphics, RectangleF bounds, int radius, Color surface, float strength)
        {
            if (graphics == null || bounds.Width <= 1F || bounds.Height <= 1F) return;
            strength = Math.Max(0F, Math.Min(1F, strength));
            for (int depth = 5; depth >= 1; depth--)
            {
                float offset = depth * 0.55F;
                float falloff = (6F - depth) / 5F;
                using (GraphicsPath lightPath = RoundedPath(Offset(bounds, -offset, -offset), radius))
                using (GraphicsPath darkPath = RoundedPath(Offset(bounds, offset, offset), radius))
                using (Brush lightBrush = new SolidBrush(WithStrength(AppTheme.NeuLightShadow, strength * falloff * 0.32F)))
                using (Brush darkBrush = new SolidBrush(WithStrength(AppTheme.NeuDarkShadow, strength * falloff * 0.26F)))
                {
                    graphics.FillPath(lightBrush, lightPath);
                    graphics.FillPath(darkBrush, darkPath);
                }
            }
            using (GraphicsPath face = RoundedPath(bounds, radius))
            using (Brush brush = new SolidBrush(surface)) graphics.FillPath(brush, face);
        }

        public static void DrawInset(Graphics graphics, RectangleF bounds, int radius, float strength)
        {
            if (graphics == null || bounds.Width <= 1F || bounds.Height <= 1F || strength <= 0F) return;
            strength = Math.Max(0F, Math.Min(1F, strength));
            GraphicsState state = graphics.Save();
            try
            {
                using (GraphicsPath clip = RoundedPath(bounds, radius)) graphics.SetClip(clip);
                for (int depth = 1; depth <= 5; depth++)
                {
                    float offset = depth * 0.62F;
                    float falloff = (6F - depth) / 5F;
                    using (GraphicsPath darkPath = RoundedPath(Offset(bounds, offset, offset), radius))
                    using (GraphicsPath lightPath = RoundedPath(Offset(bounds, -offset, -offset), radius))
                    using (Pen darkPen = new Pen(WithStrength(AppTheme.NeuDarkShadow, strength * falloff * 0.54F), 1.6F))
                    using (Pen lightPen = new Pen(WithStrength(AppTheme.NeuLightShadow, strength * falloff * 0.46F), 1.6F))
                    {
                        graphics.DrawPath(darkPen, darkPath);
                        graphics.DrawPath(lightPen, lightPath);
                    }
                }
            }
            finally
            {
                graphics.Restore(state);
            }
        }

        public static GraphicsPath RoundedPath(RectangleF rectangle, float radius)
        {
            GraphicsPath path = new GraphicsPath();
            float safeRadius = Math.Max(1F, Math.Min(radius, Math.Min(rectangle.Width, rectangle.Height) / 2F));
            float diameter = safeRadius * 2F;
            path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }

        private static RectangleF Offset(RectangleF bounds, float x, float y)
        {
            return new RectangleF(bounds.X + x, bounds.Y + y, bounds.Width, bounds.Height);
        }

        private static Color WithStrength(Color color, float strength)
        {
            int alpha = (int)Math.Round(color.A * Math.Max(0F, Math.Min(1F, strength)));
            return Color.FromArgb(alpha, color.R, color.G, color.B);
        }
    }

    internal static class GlassTextRenderer
    {
        public static void Draw(Graphics graphics, string text, Font font, RectangleF bounds, Color color, StringAlignment alignment, StringTrimming trimming)
        {
            if (graphics == null || font == null || String.IsNullOrEmpty(text) || bounds.Width <= 0F || bounds.Height <= 0F) return;
            GraphicsState state = graphics.Save();
            try
            {
                graphics.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
                using (StringFormat format = new StringFormat(StringFormat.GenericTypographic))
                using (Brush brush = new SolidBrush(color))
                {
                    format.Alignment = alignment;
                    format.LineAlignment = StringAlignment.Center;
                    format.Trimming = trimming;
                    format.FormatFlags = StringFormatFlags.NoWrap;
                    graphics.DrawString(text, font, brush, bounds, format);
                }
            }
            finally
            {
                graphics.Restore(state);
            }
        }
    }

    internal static class GlassBackdropRenderer
    {
        private static Bitmap cachedBackdrop;
        private static Size cachedSize;
        private static bool cachedDark;

        public static void Invalidate()
        {
            if (cachedBackdrop != null) cachedBackdrop.Dispose();
            cachedBackdrop = null;
            cachedSize = Size.Empty;
        }

        public static void Paint(Graphics graphics, Control control)
        {
            if (graphics == null || control == null || control.ClientSize.Width <= 0 || control.ClientSize.Height <= 0) return;
            Form form = control as Form ?? control.FindForm();
            if (form == null || form.ClientSize.Width <= 0 || form.ClientSize.Height <= 0)
            {
                graphics.Clear(MaterialPanel.ResolveBackgroundColor(control.Parent));
                return;
            }

            EnsureBackdrop(form.ClientSize);
            Point offset = OffsetFromForm(control, form);
            Rectangle source = new Rectangle(
                Math.Max(0, Math.Min(cachedBackdrop.Width - 1, offset.X)),
                Math.Max(0, Math.Min(cachedBackdrop.Height - 1, offset.Y)),
                Math.Min(control.ClientSize.Width, Math.Max(1, cachedBackdrop.Width - Math.Max(0, offset.X))),
                Math.Min(control.ClientSize.Height, Math.Max(1, cachedBackdrop.Height - Math.Max(0, offset.Y))));
            Rectangle destination = new Rectangle(0, 0, source.Width, source.Height);
            graphics.DrawImage(cachedBackdrop, destination, source, GraphicsUnit.Pixel);
            if (destination.Width < control.ClientSize.Width || destination.Height < control.ClientSize.Height)
            {
                using (Brush fallback = new SolidBrush(AppTheme.WindowBase))
                {
                    if (destination.Width < control.ClientSize.Width) graphics.FillRectangle(fallback, destination.Width, 0, control.ClientSize.Width - destination.Width, control.ClientSize.Height);
                    if (destination.Height < control.ClientSize.Height) graphics.FillRectangle(fallback, 0, destination.Height, control.ClientSize.Width, control.ClientSize.Height - destination.Height);
                }
            }
        }

        public static void PaintInherited(Graphics graphics, Control control)
        {
            Paint(graphics, control);
            List<Control> ancestors = new List<Control>();
            for (Control current = control.Parent; current != null && !(current is Form); current = current.Parent) ancestors.Insert(0, current);
            foreach (Control ancestor in ancestors)
            {
                MaterialPanel material = ancestor as MaterialPanel;
                RoundedPanel rounded = ancestor as RoundedPanel;
                if (material != null) Overlay(graphics, material.MaterialColor.IsEmpty ? material.BackColor : material.MaterialColor, control.ClientRectangle);
                else if (rounded != null) Overlay(graphics, rounded.MaterialColor.IsEmpty ? rounded.BackColor : rounded.MaterialColor, control.ClientRectangle);
            }
        }

        public static void Overlay(Graphics graphics, Color color, Rectangle bounds)
        {
            if (color == Color.Transparent || color.A == 0 || bounds.Width <= 0 || bounds.Height <= 0) return;
            using (Brush brush = new SolidBrush(color)) graphics.FillRectangle(brush, bounds);
        }

        private static Point OffsetFromForm(Control control, Form form)
        {
            int x = 0;
            int y = 0;
            for (Control current = control; current != null && current != form; current = current.Parent)
            {
                x += current.Left;
                y += current.Top;
            }
            return new Point(x, y);
        }

        private static void EnsureBackdrop(Size size)
        {
            int width = Math.Max(1, size.Width);
            int height = Math.Max(1, size.Height);
            if (cachedBackdrop != null && cachedSize.Width == width && cachedSize.Height == height && cachedDark == AppTheme.Dark) return;
            Invalidate();
            cachedSize = new Size(width, height);
            cachedDark = AppTheme.Dark;
            cachedBackdrop = new Bitmap(width, height, PixelFormat.Format32bppPArgb);
            using (Graphics graphics = Graphics.FromImage(cachedBackdrop))
            {
                graphics.Clear(AppTheme.WindowBase);
            }
        }
    }

    internal sealed class NbtReader : IDisposable
    {
        private readonly BinaryReader reader;

        public NbtReader(Stream stream)
        {
            reader = new BinaryReader(stream, Encoding.UTF8, false);
        }

        public Dictionary<string, object> ReadRoot()
        {
            byte type = reader.ReadByte();
            if (type != 10) throw new InvalidDataException("NBT root is not a compound tag.");
            ReadString();
            return ReadCompound();
        }

        private Dictionary<string, object> ReadCompound()
        {
            Dictionary<string, object> result = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            while (true)
            {
                byte type = reader.ReadByte();
                if (type == 0) return result;
                string name = ReadString();
                result[name] = ReadPayload(type);
            }
        }

        private object ReadPayload(byte type)
        {
            switch (type)
            {
                case 1: return reader.ReadSByte();
                case 2: return ReadInt16();
                case 3: return ReadInt32();
                case 4: return ReadInt64();
                case 5: return BitConverter.ToSingle(ReadBytesReversed(4), 0);
                case 6: return BitConverter.ToDouble(ReadBytesReversed(8), 0);
                case 7:
                    int byteLength = ReadLength();
                    return ReadExactly(byteLength);
                case 8: return ReadString();
                case 9:
                    byte elementType = reader.ReadByte();
                    int listLength = ReadLength();
                    List<object> list = new List<object>(listLength);
                    for (int i = 0; i < listLength; i++) list.Add(ReadPayload(elementType));
                    return list;
                case 10: return ReadCompound();
                case 11:
                    int intLength = ReadLength();
                    int[] ints = new int[intLength];
                    for (int i = 0; i < intLength; i++) ints[i] = ReadInt32();
                    return ints;
                case 12:
                    int longLength = ReadLength();
                    long[] longs = new long[longLength];
                    for (int i = 0; i < longLength; i++) longs[i] = ReadInt64();
                    return longs;
                default: throw new InvalidDataException("Unsupported NBT tag type: " + type);
            }
        }

        private int ReadLength()
        {
            int value = ReadInt32();
            if (value < 0 || value > 64000000) throw new InvalidDataException("Invalid NBT array length.");
            return value;
        }

        private string ReadString()
        {
            ushort length = unchecked((ushort)ReadInt16());
            return Encoding.UTF8.GetString(ReadExactly(length));
        }

        private short ReadInt16() { return BitConverter.ToInt16(ReadBytesReversed(2), 0); }
        private int ReadInt32() { return BitConverter.ToInt32(ReadBytesReversed(4), 0); }
        private long ReadInt64() { return BitConverter.ToInt64(ReadBytesReversed(8), 0); }

        private byte[] ReadBytesReversed(int count)
        {
            byte[] bytes = ReadExactly(count);
            if (BitConverter.IsLittleEndian) Array.Reverse(bytes);
            return bytes;
        }

        private byte[] ReadExactly(int count)
        {
            byte[] bytes = reader.ReadBytes(count);
            if (bytes.Length != count) throw new EndOfStreamException();
            return bytes;
        }

        public void Dispose() { reader.Dispose(); }
    }

    internal sealed class WorldInfo
    {
        public Image Icon { get; set; }
        public string Name { get; set; }
        public string Version { get; set; }
        public string GameMode { get; set; }
        public DateTime LastPlayed { get; set; }
        public string Source { get; set; }
        public string Path { get; set; }
        public string RootPath { get; set; }
        public string InstancePath { get; set; }
        public string Loader { get; set; }
        public string Health { get; set; }
        public string Fingerprint { get; set; }
        public int BackupCount { get; set; }
        public bool AutoBackup { get; set; }
        public string Error { get; set; }
        public long Seed { get; set; }
        public string Difficulty { get; set; }
        public bool Cheats { get; set; }
        public bool Hardcore { get; set; }
        public int DataVersion { get; set; }
        public bool Favorite { get; set; }
        public string Tags { get; set; }
        public string Notes { get; set; }
        public long SizeBytes { get; set; }
    }

    internal sealed class WorldMetadata
    {
        public bool Favorite { get; set; }
        public string Tags { get; set; }
        public string Notes { get; set; }
        public bool AutoBackup { get; set; }
        public string LastBackupFingerprint { get; set; }
    }

    internal sealed class BackupHistoryEntry
    {
        public string WorldPath { get; set; }
        public string ArchivePath { get; set; }
        public DateTime CreatedUtc { get; set; }
    }

    internal sealed class BackupManifest
    {
        public string OriginalPath { get; set; }
        public string RootPath { get; set; }
        public string WorldName { get; set; }
        public string Source { get; set; }
        public DateTime CreatedUtc { get; set; }
    }

    internal sealed class DiscoveryProgress
    {
        public long DirectoriesChecked { get; set; }
        public string CurrentDrive { get; set; }
    }

    internal sealed class WorldScanCacheEntry
    {
        public string Fingerprint { get; set; }
        public WorldInfo World { get; set; }
    }

    internal static class WorldScanner
    {
        private static readonly Dictionary<string, WorldScanCacheEntry> cache = new Dictionary<string, WorldScanCacheEntry>(StringComparer.OrdinalIgnoreCase);
        internal static int LastCacheHits { get; private set; }

        public static List<WorldInfo> Scan(IEnumerable<string> roots)
        {
            LastCacheHits = 0;
            List<WorldInfo> worlds = new List<WorldInfo>();
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string root in roots)
            {
                if (!Directory.Exists(root)) continue;
                AddSavesFolder(worlds, seen, root, root, Path.Combine(root, "saves"), DirectSourceName(root));
                string versions = Path.Combine(root, "versions");
                if (!Directory.Exists(versions)) continue;
                foreach (string versionFolder in SafeDirectories(versions))
                {
                    AddSavesFolder(worlds, seen, root, versionFolder, Path.Combine(versionFolder, "saves"), Path.GetFileName(versionFolder));
                }
            }
            return worlds.OrderByDescending(delegate(WorldInfo world) { return world.LastPlayed; }).ThenBy(delegate(WorldInfo world) { return world.Name; }).ToList();
        }

        internal static void ClearCache() { cache.Clear(); }

        internal static string Fingerprint(string worldFolder)
        {
            try
            {
                FileInfo level = new FileInfo(Path.Combine(worldFolder, "level.dat"));
                FileInfo icon = new FileInfo(Path.Combine(worldFolder, "icon.png"));
                DirectoryInfo region = new DirectoryInfo(Path.Combine(worldFolder, "region"));
                long levelTicks = level.Exists ? level.LastWriteTimeUtc.Ticks : 0L;
                long levelLength = level.Exists ? level.Length : 0L;
                long iconTicks = icon.Exists ? icon.LastWriteTimeUtc.Ticks : 0L;
                long regionTicks = region.Exists ? region.LastWriteTimeUtc.Ticks : 0L;
                return levelTicks + ":" + levelLength + ":" + iconTicks + ":" + regionTicks;
            }
            catch { return ""; }
        }

        private static string DirectSourceName(string root)
        {
            string name = Path.GetFileName(root.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            if (String.IsNullOrWhiteSpace(name)) return "\u5168\u5c40\u5b58\u6863";
            if (!name.Equals(".minecraft", StringComparison.OrdinalIgnoreCase)) return name;
            try
            {
                DirectoryInfo instance = Directory.GetParent(root);
                DirectoryInfo container = instance == null ? null : instance.Parent;
                if (instance != null && container != null && IsInstanceContainer(container.Name)) return instance.Name;
            }
            catch { }
            return "\u5168\u5c40\u5b58\u6863";
        }

        private static bool IsInstanceContainer(string name)
        {
            if (String.IsNullOrWhiteSpace(name)) return false;
            string value = name.ToLowerInvariant();
            return value == "instances" || value == "profiles" || value == "modpacks" || value == "packs";
        }

        private static void AddSavesFolder(List<WorldInfo> worlds, HashSet<string> seen, string root, string instancePath, string saves, string source)
        {
            if (!Directory.Exists(saves)) return;
            foreach (string worldFolder in SafeDirectories(saves))
            {
                string fullPath;
                try { fullPath = Path.GetFullPath(worldFolder).TrimEnd(Path.DirectorySeparatorChar); }
                catch { continue; }
                if (!seen.Add(fullPath)) continue;
                if (!File.Exists(Path.Combine(worldFolder, "level.dat")) && !Directory.Exists(Path.Combine(worldFolder, "region"))) continue;
                string fingerprint = Fingerprint(worldFolder);
                WorldInfo world;
                WorldScanCacheEntry cached;
                if (cache.TryGetValue(fullPath, out cached) && cached != null && cached.Fingerprint == fingerprint && cached.World != null)
                {
                    LastCacheHits++;
                    world = CloneWorld(cached.World);
                    world.RootPath = root;
                    world.InstancePath = instancePath;
                    world.Source = source;
                }
                else
                {
                    world = ReadWorld(root, instancePath, worldFolder, source, fingerprint);
                    cache[fullPath] = new WorldScanCacheEntry { Fingerprint = fingerprint, World = CloneWorld(world) };
                }
                worlds.Add(world);
            }
        }

        private static WorldInfo CloneWorld(WorldInfo source)
        {
            return new WorldInfo
            {
                Icon = source.Icon,
                Name = source.Name,
                Version = source.Version,
                GameMode = source.GameMode,
                LastPlayed = source.LastPlayed,
                Source = source.Source,
                Path = source.Path,
                RootPath = source.RootPath,
                InstancePath = source.InstancePath,
                Loader = source.Loader,
                Health = source.Health,
                Fingerprint = source.Fingerprint,
                BackupCount = source.BackupCount,
                AutoBackup = source.AutoBackup,
                Error = source.Error,
                Seed = source.Seed,
                Difficulty = source.Difficulty,
                Cheats = source.Cheats,
                Hardcore = source.Hardcore,
                DataVersion = source.DataVersion,
                Favorite = source.Favorite,
                Tags = source.Tags,
                Notes = source.Notes,
                SizeBytes = source.SizeBytes
            };
        }

        private static IEnumerable<string> SafeDirectories(string path)
        {
            try { return Directory.GetDirectories(path); }
            catch { return new string[0]; }
        }

        private static WorldInfo ReadWorld(string root, string instancePath, string worldFolder, string source, string fingerprint)
        {
            WorldInfo world = new WorldInfo();
            world.Name = Path.GetFileName(worldFolder);
            world.Version = InferVersionFromSource(source);
            world.GameMode = "\u672a\u77e5";
            world.Difficulty = "\u672a\u77e5";
            world.LastPlayed = Directory.GetLastWriteTime(worldFolder);
            world.Source = source;
            world.Path = worldFolder;
            world.RootPath = root;
            world.InstancePath = instancePath;
            world.Loader = InferLoader(instancePath);
            world.Health = "\u6b63\u5e38";
            world.Fingerprint = fingerprint;
            world.Icon = LoadIcon(Path.Combine(worldFolder, "icon.png"));

            string levelPath = Path.Combine(worldFolder, "level.dat");
            if (!File.Exists(levelPath))
            {
                world.Error = "\u7f3a\u5c11 level.dat";
                world.Health = "\u5f02\u5e38";
                return world;
            }

            try
            {
                Dictionary<string, object> rootTag;
                using (FileStream file = File.Open(levelPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                using (GZipStream gzip = new GZipStream(file, CompressionMode.Decompress))
                using (NbtReader nbt = new NbtReader(gzip)) rootTag = nbt.ReadRoot();

                Dictionary<string, object> data = AsCompound(Get(rootTag, "Data"));
                if (data == null) data = rootTag;
                string levelName = AsString(Get(data, "LevelName"));
                if (!String.IsNullOrWhiteSpace(levelName)) world.Name = levelName;

                Dictionary<string, object> version = AsCompound(Get(data, "Version"));
                string versionName = version == null ? null : AsString(Get(version, "Name"));
                if (!String.IsNullOrWhiteSpace(versionName)) world.Version = versionName;
                else
                {
                    int dataVersion = AsInt(Get(data, "DataVersion"), 0);
                    world.DataVersion = dataVersion;
                    if (dataVersion > 0) world.Version = VersionNameFromDataVersion(dataVersion);
                }
                if (world.DataVersion == 0) world.DataVersion = AsInt(Get(data, "DataVersion"), 0);

                int gameType = AsInt(Get(data, "GameType"), -1);
                bool hardcore = AsInt(Get(data, "hardcore"), 0) != 0;
                world.Hardcore = hardcore;
                world.GameMode = hardcore ? "\u6781\u9650" : GameModeName(gameType);
                world.Difficulty = DifficultyName(AsInt(Get(data, "Difficulty"), -1));
                world.Cheats = AsInt(Get(data, "allowCommands"), 0) != 0;
                Dictionary<string, object> worldGen = AsCompound(Get(data, "WorldGenSettings"));
                world.Seed = worldGen == null ? AsLong(Get(data, "RandomSeed"), 0) : AsLong(Get(worldGen, "seed"), AsLong(Get(data, "RandomSeed"), 0));

                long lastPlayed = AsLong(Get(data, "LastPlayed"), 0);
                if (lastPlayed > 0)
                {
                    DateTime epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
                    world.LastPlayed = epoch.AddMilliseconds(lastPlayed).ToLocalTime();
                }
            }
            catch (Exception ex)
            {
                world.Error = "level.dat: " + ex.Message;
                world.Health = "\u5f02\u5e38";
            }
            if (String.IsNullOrEmpty(world.Error) && IsWorldLocked(worldFolder)) world.Health = "\u4f7f\u7528\u4e2d";
            return world;
        }

        private static bool IsWorldLocked(string worldFolder)
        {
            string lockPath = Path.Combine(worldFolder, "session.lock");
            if (!File.Exists(lockPath)) return false;
            try
            {
                using (FileStream stream = File.Open(lockPath, FileMode.Open, FileAccess.ReadWrite, FileShare.None)) { }
                return false;
            }
            catch { return true; }
        }

        private static string InferLoader(string instancePath)
        {
            if (String.IsNullOrWhiteSpace(instancePath)) return "\u539f\u7248";
            try
            {
                string[] parts = instancePath.Split(new char[] { Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar }, StringSplitOptions.RemoveEmptyEntries);
                foreach (string part in parts)
                {
                    string value = part.ToLowerInvariant();
                    if (value.Contains("neoforge")) return "NeoForge";
                    if (value.Contains("fabric")) return "Fabric";
                    if (value.Contains("quilt")) return "Quilt";
                    if (value.Contains("forge")) return "Forge";
                }
                string mods = Path.Combine(instancePath, "mods");
                if (Directory.Exists(mods))
                {
                    foreach (string file in Directory.GetFiles(mods, "*.jar", SearchOption.TopDirectoryOnly))
                    {
                        string value = Path.GetFileName(file).ToLowerInvariant();
                        if (value.Contains("neoforge")) return "NeoForge";
                        if (value.Contains("fabric")) return "Fabric";
                        if (value.Contains("quilt")) return "Quilt";
                        if (value.Contains("forge")) return "Forge";
                    }
                }
            }
            catch { }
            return "\u539f\u7248";
        }

        private static Image LoadIcon(string path)
        {
            if (!File.Exists(path)) return CreateFallbackIcon();
            try
            {
                using (FileStream stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                using (Image source = Image.FromStream(stream)) return new Bitmap(source, new Size(40, 40));
            }
            catch { return CreateFallbackIcon(); }
        }

        internal static Image CreateFallbackIcon()
        {
            Bitmap bitmap = new Bitmap(40, 40);
            using (Graphics graphics = Graphics.FromImage(bitmap))
            {
                graphics.Clear(Color.FromArgb(64, 122, 72));
                using (Brush grass = new SolidBrush(Color.FromArgb(92, 154, 81))) graphics.FillRectangle(grass, 0, 0, 40, 13);
                using (Pen line = new Pen(Color.FromArgb(55, 98, 60)))
                {
                    graphics.DrawLine(line, 0, 13, 39, 13);
                    graphics.DrawRectangle(line, 0, 0, 39, 39);
                }
            }
            return bitmap;
        }

        private static object Get(Dictionary<string, object> map, string key)
        {
            object value;
            return map != null && map.TryGetValue(key, out value) ? value : null;
        }

        private static Dictionary<string, object> AsCompound(object value) { return value as Dictionary<string, object>; }
        private static string AsString(object value) { return value == null ? null : Convert.ToString(value); }
        private static int AsInt(object value, int fallback) { try { return value == null ? fallback : Convert.ToInt32(value); } catch { return fallback; } }
        private static long AsLong(object value, long fallback) { try { return value == null ? fallback : Convert.ToInt64(value); } catch { return fallback; } }

        private static string InferVersionFromSource(string source)
        {
            if (!String.IsNullOrWhiteSpace(source) && source != "\u5168\u5c40\u5b58\u6863")
            {
                Match match = Regex.Match(source, @"(?<!\d)\d+\.\d+(?:\.\d+)?(?!\d)");
                if (match.Success) return match.Value;
            }
            return "1.8.9 \u6216\u66f4\u65e9";
        }

        internal static string VersionNameFromDataVersion(int dataVersion)
        {
            if (dataVersion >= 4189) return "1.21.4 \u6216\u66f4\u9ad8";
            if (dataVersion >= 4080) return "1.21.2 - 1.21.3";
            if (dataVersion >= 3953) return "1.21 - 1.21.1";
            if (dataVersion >= 3837) return "1.20.5 - 1.20.6";
            if (dataVersion >= 3698) return "1.20.3 - 1.20.4";
            if (dataVersion >= 3578) return "1.20.2";
            if (dataVersion >= 3463) return "1.20 - 1.20.1";
            if (dataVersion >= 3337) return "1.19.4";
            if (dataVersion >= 3218) return "1.19.3";
            if (dataVersion >= 3105) return "1.19 - 1.19.2";
            if (dataVersion >= 2975) return "1.18.2";
            if (dataVersion >= 2860) return "1.18 - 1.18.1";
            if (dataVersion >= 2724) return "1.17 - 1.17.1";
            if (dataVersion >= 2566) return "1.16 - 1.16.5";
            if (dataVersion >= 2225) return "1.15 - 1.15.2";
            if (dataVersion >= 1952) return "1.14 - 1.14.4";
            if (dataVersion >= 1519) return "1.13 - 1.13.2";
            if (dataVersion >= 1139) return "1.12 - 1.12.2";
            if (dataVersion >= 819) return "1.11 - 1.11.2";
            if (dataVersion >= 510) return "1.10 - 1.10.2";
            if (dataVersion >= 169) return "1.9 - 1.9.4";
            return "1.8.9 \u6216\u66f4\u65e9";
        }

        private static string GameModeName(int gameType)
        {
            switch (gameType)
            {
                case 0: return "\u751f\u5b58";
                case 1: return "\u521b\u9020";
                case 2: return "\u5192\u9669";
                case 3: return "\u65c1\u89c2";
                default: return "\u672a\u77e5";
            }
        }

        private static string DifficultyName(int difficulty)
        {
            switch (difficulty)
            {
                case 0: return "\u548c\u5e73";
                case 1: return "\u7b80\u5355";
                case 2: return "\u666e\u901a";
                case 3: return "\u56f0\u96be";
                default: return "\u672a\u77e5";
            }
        }
    }

    internal sealed class BufferedDataGridView : DataGridView
    {
        private int resizingColumnIndex = -1;
        private int resizeStartX;
        private int resizeStartWidth;
        private readonly Timer smoothScrollTimer = new Timer();
        private Bitmap scrollFromImage;
        private Bitmap scrollToImage;
        private bool scrollAnimating;
        private int scrollDistance;
        private long scrollStarted;
        private double wheelRowRemainder;
        private const double WheelRowsPerNotch = 2D;
        private const int SmoothScrollDuration = 100;

        public BufferedDataGridView()
        {
            DoubleBuffered = true;
            ResizeRedraw = true;
            SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint, true);
            smoothScrollTimer.Interval = 15;
            smoothScrollTimer.Tick += delegate
            {
                if (!scrollAnimating) return;
                if (AnimationProgress() >= 1D)
                {
                    FinishSmoothScroll();
                    return;
                }
                Invalidate(DataAreaRectangle());
            };
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            if (Rows.Count == 0 || e.Delta == 0) return;
            int before;
            try { before = Math.Max(0, FirstDisplayedScrollingRowIndex); }
            catch { before = 0; }
            int visibleRows = Math.Max(1, DisplayedRowCount(false));
            double rowDelta = -(e.Delta / (double)Math.Max(1, SystemInformation.MouseWheelScrollDelta)) * WheelRowsPerNotch;
            wheelRowRemainder += rowDelta;
            int rowChange = (int)Math.Truncate(wheelRowRemainder);
            if (rowChange == 0) return;
            wheelRowRemainder -= rowChange;
            int maximumFirstRow = Math.Max(0, Rows.Count - visibleRows);
            int target = Math.Max(0, Math.Min(maximumFirstRow, before + rowChange));
            if (target == before) return;

            if (!SystemInformation.IsMenuAnimationEnabled)
            {
                CancelSmoothScroll();
                try { FirstDisplayedScrollingRowIndex = target; }
                catch { }
                return;
            }

            Bitmap fromImage = scrollAnimating ? RenderCurrentScrollFrame() : CaptureDataArea();
            int remainingDistance = scrollAnimating ? scrollDistance - CurrentScrollOffset() : 0;
            CancelSmoothScroll();

            try { FirstDisplayedScrollingRowIndex = target; }
            catch
            {
                if (fromImage != null) fromImage.Dispose();
                return;
            }
            Bitmap toImage = CaptureDataArea();
            if (fromImage == null || toImage == null)
            {
                if (fromImage != null) fromImage.Dispose();
                if (toImage != null) toImage.Dispose();
                return;
            }

            int rowHeight = RowTemplate.Height;
            if (before >= 0 && before < Rows.Count) rowHeight = Math.Max(1, Rows[before].Height);
            int distance = remainingDistance + (target - before) * rowHeight;
            if (distance == 0)
            {
                fromImage.Dispose();
                toImage.Dispose();
                return;
            }

            scrollFromImage = fromImage;
            scrollToImage = toImage;
            scrollDistance = distance;
            scrollStarted = Stopwatch.GetTimestamp() - (long)(smoothScrollTimer.Interval * Stopwatch.Frequency / 1000D);
            scrollAnimating = true;
            smoothScrollTimer.Start();
            Invalidate(DataAreaRectangle());
        }

        internal void ScrollWheelForTest(int delta)
        {
            OnMouseWheel(new MouseEventArgs(MouseButtons.None, 0, 10, ColumnHeadersHeight + 20, delta));
        }

        internal void CompleteScrollForTest()
        {
            if (scrollAnimating) FinishSmoothScroll();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            if (!scrollAnimating || scrollFromImage == null || scrollToImage == null) return;
            Rectangle dataArea = DataAreaRectangle();
            int offset = CurrentScrollOffset();
            GraphicsState state = e.Graphics.Save();
            e.Graphics.SetClip(dataArea);
            using (Brush background = new SolidBrush(DefaultCellStyle.BackColor)) e.Graphics.FillRectangle(background, dataArea);
            e.Graphics.DrawImageUnscaled(scrollToImage, dataArea.X, dataArea.Y + scrollDistance - offset);
            e.Graphics.DrawImageUnscaled(scrollFromImage, dataArea.X, dataArea.Y - offset);
            e.Graphics.Restore(state);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            CancelSmoothScroll();
            wheelRowRemainder = 0D;
            if (e.Button == MouseButtons.Left && e.Y >= 0 && e.Y <= ColumnHeadersHeight && BeginLiveResize(e.X)) return;
            base.OnMouseDown(e);
        }

        protected override void OnSizeChanged(EventArgs e)
        {
            CancelSmoothScroll();
            wheelRowRemainder = 0D;
            base.OnSizeChanged(e);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                smoothScrollTimer.Dispose();
                DisposeScrollImages();
            }
            base.Dispose(disposing);
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (resizingColumnIndex >= 0)
            {
                UpdateLiveResize(e.X);
                return;
            }
            if (e.Y >= 0 && e.Y <= ColumnHeadersHeight && FindDividerColumn(e.X) != null)
            {
                Cursor = Cursors.VSplit;
                return;
            }
            Cursor = Cursors.Default;
            base.OnMouseMove(e);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            if (resizingColumnIndex >= 0)
            {
                EndLiveResize();
                return;
            }
            base.OnMouseUp(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            if (resizingColumnIndex < 0) Cursor = Cursors.Default;
            base.OnMouseLeave(e);
        }

        protected override void OnMouseCaptureChanged(EventArgs e)
        {
            if (!Capture && resizingColumnIndex >= 0) EndLiveResize();
            base.OnMouseCaptureChanged(e);
        }

        internal bool BeginLiveResize(int mouseX)
        {
            DataGridViewColumn column = FindDividerColumn(mouseX);
            return column != null && BeginLiveResizeColumn(column.Index, mouseX);
        }

        internal bool BeginLiveResizeColumn(int columnIndex, int mouseX)
        {
            if (columnIndex < 0 || columnIndex >= Columns.Count) return false;
            DataGridViewColumn column = Columns[columnIndex];
            if (column.Resizable == DataGridViewTriState.False) return false;
            resizingColumnIndex = column.Index;
            resizeStartX = mouseX;
            resizeStartWidth = column.Width;
            Capture = true;
            Cursor = Cursors.VSplit;
            return true;
        }

        internal void UpdateLiveResize(int mouseX)
        {
            if (resizingColumnIndex < 0 || resizingColumnIndex >= Columns.Count) return;
            DataGridViewColumn column = Columns[resizingColumnIndex];
            int newWidth = resizeStartWidth + mouseX - resizeStartX;
            column.Width = Math.Max(Math.Max(24, column.MinimumWidth), Math.Min(2000, newWidth));
            Invalidate();
            Update();
        }

        internal void EndLiveResize()
        {
            resizingColumnIndex = -1;
            Capture = false;
            Cursor = Cursors.Default;
        }

        private DataGridViewColumn FindDividerColumn(int mouseX)
        {
            const int tolerance = 5;
            foreach (DataGridViewColumn column in Columns)
            {
                if (!column.Visible) continue;
                Rectangle rectangle = GetColumnDisplayRectangle(column.Index, true);
                if (rectangle.Width > 0 && Math.Abs(mouseX - rectangle.Right) <= tolerance) return column;
            }
            return null;
        }

        private Rectangle DataAreaRectangle()
        {
            int top = Math.Min(ClientSize.Height, Math.Max(0, ColumnHeadersHeight));
            return new Rectangle(0, top, Math.Max(1, ClientSize.Width), Math.Max(1, ClientSize.Height - top));
        }

        private Bitmap CaptureDataArea()
        {
            Rectangle area = DataAreaRectangle();
            if (ClientSize.Width <= 0 || ClientSize.Height <= 0 || area.Width <= 0 || area.Height <= 0) return null;
            try
            {
                using (Bitmap full = new Bitmap(ClientSize.Width, ClientSize.Height, PixelFormat.Format32bppPArgb))
                {
                    DrawToBitmap(full, ClientRectangle);
                    return full.Clone(area, PixelFormat.Format32bppPArgb);
                }
            }
            catch { return null; }
        }

        private Bitmap RenderCurrentScrollFrame()
        {
            if (!scrollAnimating || scrollFromImage == null || scrollToImage == null) return CaptureDataArea();
            Rectangle area = DataAreaRectangle();
            Bitmap frame = new Bitmap(area.Width, area.Height, PixelFormat.Format32bppPArgb);
            using (Graphics graphics = Graphics.FromImage(frame))
            {
                graphics.Clear(DefaultCellStyle.BackColor);
                int offset = CurrentScrollOffset();
                graphics.DrawImageUnscaled(scrollToImage, 0, scrollDistance - offset);
                graphics.DrawImageUnscaled(scrollFromImage, 0, -offset);
            }
            return frame;
        }

        private int CurrentScrollOffset()
        {
            return (int)Math.Round(scrollDistance * StrongEaseOut(AnimationProgress()));
        }

        private double AnimationProgress()
        {
            if (!scrollAnimating) return 1D;
            double elapsedMilliseconds = (Stopwatch.GetTimestamp() - scrollStarted) * 1000D / Stopwatch.Frequency;
            return Math.Max(0D, Math.Min(1D, elapsedMilliseconds / SmoothScrollDuration));
        }

        private static double StrongEaseOut(double progress)
        {
            double low = 0D;
            double high = 1D;
            double parameter = progress;
            for (int i = 0; i < 10; i++)
            {
                parameter = (low + high) / 2D;
                double x = CubicBezierCoordinate(parameter, 0.23D, 0.32D);
                if (x < progress) low = parameter; else high = parameter;
            }
            return CubicBezierCoordinate(parameter, 1D, 1D);
        }

        private static double CubicBezierCoordinate(double parameter, double firstControl, double secondControl)
        {
            double inverse = 1D - parameter;
            return 3D * inverse * inverse * parameter * firstControl
                + 3D * inverse * parameter * parameter * secondControl
                + parameter * parameter * parameter;
        }

        private void FinishSmoothScroll()
        {
            scrollAnimating = false;
            smoothScrollTimer.Stop();
            DisposeScrollImages();
            Invalidate(DataAreaRectangle());
        }

        private void CancelSmoothScroll()
        {
            if (!scrollAnimating && scrollFromImage == null && scrollToImage == null) return;
            scrollAnimating = false;
            smoothScrollTimer.Stop();
            DisposeScrollImages();
            Invalidate(DataAreaRectangle());
        }

        private void DisposeScrollImages()
        {
            if (scrollFromImage != null) scrollFromImage.Dispose();
            if (scrollToImage != null) scrollToImage.Dispose();
            scrollFromImage = null;
            scrollToImage = null;
        }
    }

    internal sealed class SmoothListControl : Control
    {
        private readonly Timer scrollTimer = new Timer();
        private readonly List<object> items = new List<object>();
        private int selectedIndex = -1;
        private int hoveredIndex = -1;
        private int pressedIndex = -1;
        private double scrollOffset;
        private double animationStartOffset;
        private double animationTargetOffset;
        private long animationStarted;
        private bool scrollAnimating;
        private bool updating;
        private bool draggingScrollBar;
        private int scrollBarDragOffset;
        private const int SmoothScrollDuration = 100;

        public event EventHandler SelectedIndexChanged;
        public event EventHandler ViewportChanged;
        public event EventHandler ItemActivated;
        public event EventHandler CancelRequested;
        public event DrawItemEventHandler DrawItem;

        public SmoothListControl()
        {
            ItemHeight = 36;
            ShowInternalScrollBar = false;
            BackColor = AppTheme.Surface;
            ForeColor = AppTheme.Ink;
            TabStop = true;
            AccessibleRole = AccessibleRole.List;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
            scrollTimer.Interval = 15;
            scrollTimer.Tick += delegate { AdvanceScrollAnimation(); };
        }

        public List<object> Items { get { return items; } }
        public int ItemHeight { get; set; }
        public bool ShowInternalScrollBar { get; set; }

        public int SelectedIndex
        {
            get { return selectedIndex; }
            set
            {
                int normalized = value >= 0 && value < items.Count ? value : -1;
                if (selectedIndex == normalized) return;
                selectedIndex = normalized;
                Invalidate();
                if (!updating && SelectedIndexChanged != null) SelectedIndexChanged(this, EventArgs.Empty);
            }
        }

        public object SelectedItem
        {
            get { return selectedIndex >= 0 && selectedIndex < items.Count ? items[selectedIndex] : null; }
        }

        public int ScrollOffset
        {
            get { return (int)Math.Round(scrollOffset); }
            set { SetScrollOffset(value, true); }
        }

        public int TopIndex
        {
            get { return ItemHeight <= 0 ? 0 : Math.Max(0, (int)Math.Floor(scrollOffset / ItemHeight)); }
            set { SetScrollOffset(Math.Max(0, value) * Math.Max(1, ItemHeight), true); }
        }

        internal double TargetScrollOffsetForTest { get { return animationTargetOffset; } }

        public void BeginUpdate()
        {
            updating = true;
            SuspendLayout();
        }

        public void EndUpdate()
        {
            updating = false;
            ResumeLayout();
            if (selectedIndex >= items.Count) selectedIndex = -1;
            SetScrollOffset(ScrollOffset, true);
            Invalidate();
        }

        public void EnsureVisible(int index, bool animate)
        {
            if (index < 0 || index >= items.Count) return;
            double top = index * Math.Max(1, ItemHeight);
            double bottom = top + Math.Max(1, ItemHeight);
            double target = scrollOffset;
            if (top < scrollOffset) target = top;
            else if (bottom > scrollOffset + ClientSize.Height) target = bottom - ClientSize.Height;
            if (animate) AnimateTo(target); else SetScrollOffset((int)Math.Round(target), true);
        }

        internal void ScrollWheelForTest(int delta)
        {
            OnMouseWheel(new MouseEventArgs(MouseButtons.None, 0, 10, 10, delta));
        }

        internal void CompleteScrollForTest()
        {
            if (!scrollAnimating) return;
            scrollOffset = animationTargetOffset;
            FinishScrollAnimation();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.Clear(BackColor);
            if (items.Count == 0 || ItemHeight <= 0) return;

            int first = Math.Max(0, (int)Math.Floor(scrollOffset / ItemHeight));
            int y = (int)Math.Round(first * ItemHeight - scrollOffset);
            int contentWidth = Math.Max(1, ClientSize.Width - (ShowInternalScrollBar && IsScrollBarNeeded() ? 12 : 0));
            for (int index = first; index < items.Count && y < ClientSize.Height; index++, y += ItemHeight)
            {
                Rectangle bounds = new Rectangle(0, y, contentWidth, ItemHeight);
                DrawItemState state = DrawItemState.None;
                if (index == selectedIndex) state |= DrawItemState.Selected;
                if (index == hoveredIndex) state |= DrawItemState.HotLight;
                if (Focused && index == selectedIndex) state |= DrawItemState.Focus;
                if (DrawItem != null)
                {
                    DrawItemEventArgs args = new DrawItemEventArgs(e.Graphics, Font, bounds, index, state, ForeColor, BackColor);
                    DrawItem(this, args);
                }
                else DrawDefaultItem(e.Graphics, bounds, index, state);
            }
            if (ShowInternalScrollBar) DrawInternalScrollBar(e.Graphics);
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            if (items.Count == 0 || e.Delta == 0) return;
            double current = PresentedScrollOffset();
            double pending = animationTargetOffset - current;
            double delta = -(e.Delta / (double)Math.Max(1, SystemInformation.MouseWheelScrollDelta)) * Math.Max(1, ItemHeight) * 2D;
            double basis = scrollAnimating && Math.Sign(delta) == Math.Sign(pending) ? animationTargetOffset : current;
            animationStartOffset = current;
            animationTargetOffset = ClampOffset(basis + delta);
            if (Math.Abs(animationTargetOffset - animationStartOffset) < 0.5D)
            {
                SetScrollOffset((int)Math.Round(animationTargetOffset), true);
                return;
            }
            if (!SystemInformation.IsMenuAnimationEnabled)
            {
                SetScrollOffset((int)Math.Round(animationTargetOffset), true);
                return;
            }
            animationStarted = Stopwatch.GetTimestamp() - (long)(scrollTimer.Interval * Stopwatch.Frequency / 1000D);
            scrollAnimating = true;
            scrollTimer.Start();
            AdvanceScrollAnimation();
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            Focus();
            if (e.Button == MouseButtons.Left && ShowInternalScrollBar && IsScrollBarNeeded() && e.X >= ClientSize.Width - 14)
            {
                Rectangle thumb = InternalThumbRectangle();
                if (thumb.Contains(e.Location))
                {
                    CommitPresentedScrollOffset();
                    draggingScrollBar = true;
                    scrollBarDragOffset = e.Y - thumb.Top;
                    Capture = true;
                }
                else
                {
                    int direction = e.Y < thumb.Top ? -1 : 1;
                    SetScrollOffset(ScrollOffset + direction * Math.Max(ItemHeight, ClientSize.Height - ItemHeight), true);
                }
                Invalidate();
                return;
            }
            CommitPresentedScrollOffset();
            pressedIndex = IndexAt(e.Y);
            if (e.Button == MouseButtons.Left && pressedIndex >= 0) SelectedIndex = pressedIndex;
            base.OnMouseDown(e);
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (draggingScrollBar)
            {
                Rectangle track = InternalTrackRectangle();
                Rectangle thumb = InternalThumbRectangle();
                int travel = Math.Max(1, track.Height - thumb.Height);
                int pixel = Math.Max(0, Math.Min(travel, e.Y - track.Top - scrollBarDragOffset));
                SetScrollOffset((int)Math.Round(MaximumOffset() * pixel / (double)travel), true);
                return;
            }
            int nextHovered = IndexAt(e.Y);
            if (hoveredIndex != nextHovered)
            {
                hoveredIndex = nextHovered;
                Invalidate();
            }
            base.OnMouseMove(e);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            if (draggingScrollBar)
            {
                draggingScrollBar = false;
                Capture = false;
                Invalidate();
                return;
            }
            int releasedIndex = IndexAt(e.Y);
            if (e.Button == MouseButtons.Left && pressedIndex >= 0 && releasedIndex == pressedIndex && ItemActivated != null) ItemActivated(this, EventArgs.Empty);
            pressedIndex = -1;
            base.OnMouseUp(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            if (!draggingScrollBar && hoveredIndex != -1)
            {
                hoveredIndex = -1;
                Invalidate();
            }
            base.OnMouseLeave(e);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (items.Count == 0) { base.OnKeyDown(e); return; }
            int next = selectedIndex < 0 ? 0 : selectedIndex;
            if (e.KeyCode == Keys.Up) next = Math.Max(0, next - 1);
            else if (e.KeyCode == Keys.Down) next = Math.Min(items.Count - 1, next + 1);
            else if (e.KeyCode == Keys.Home) next = 0;
            else if (e.KeyCode == Keys.End) next = items.Count - 1;
            else if (e.KeyCode == Keys.PageUp) next = Math.Max(0, next - Math.Max(1, ClientSize.Height / Math.Max(1, ItemHeight)));
            else if (e.KeyCode == Keys.PageDown) next = Math.Min(items.Count - 1, next + Math.Max(1, ClientSize.Height / Math.Max(1, ItemHeight)));
            else if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space)
            {
                if (selectedIndex >= 0 && ItemActivated != null) ItemActivated(this, EventArgs.Empty);
                e.Handled = true;
                return;
            }
            else if (e.KeyCode == Keys.Escape)
            {
                if (CancelRequested != null) CancelRequested(this, EventArgs.Empty);
                e.Handled = true;
                return;
            }
            else { base.OnKeyDown(e); return; }
            SelectedIndex = next;
            EnsureVisible(next, false);
            e.Handled = true;
        }

        protected override void OnSizeChanged(EventArgs e)
        {
            SetScrollOffset(ScrollOffset, true);
            base.OnSizeChanged(e);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) scrollTimer.Dispose();
            base.Dispose(disposing);
        }

        private void DrawDefaultItem(Graphics graphics, Rectangle bounds, int index, DrawItemState state)
        {
            bool selected = (state & DrawItemState.Selected) == DrawItemState.Selected;
            bool hot = (state & DrawItemState.HotLight) == DrawItemState.HotLight;
            Color fill = selected ? AppTheme.Selection : (hot ? AppTheme.Hover : BackColor);
            using (Brush brush = new SolidBrush(fill)) graphics.FillRectangle(brush, bounds);
            TextRenderer.DrawText(graphics, Convert.ToString(items[index]), Font, new Rectangle(bounds.X + 12, bounds.Y, Math.Max(1, bounds.Width - 20), bounds.Height), selected ? AppTheme.Accent : ForeColor, TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        }

        private void DrawInternalScrollBar(Graphics graphics)
        {
            if (!IsScrollBarNeeded()) return;
            Rectangle thumb = InternalThumbRectangle();
            int width = draggingScrollBar || hoveredIndex == -2 ? 6 : 4;
            RectangleF painted = new RectangleF(ClientSize.Width - 8 + (6 - width) / 2F, thumb.Y, width, thumb.Height);
            using (GraphicsPath path = RoundedPath(painted, width / 2F))
            using (Brush brush = new SolidBrush(draggingScrollBar ? AppTheme.ScrollThumbHover : AppTheme.ScrollThumb)) graphics.FillPath(brush, path);
        }

        private Rectangle InternalTrackRectangle()
        {
            return new Rectangle(Math.Max(0, ClientSize.Width - 12), 4, 12, Math.Max(1, ClientSize.Height - 8));
        }

        private Rectangle InternalThumbRectangle()
        {
            Rectangle track = InternalTrackRectangle();
            double contentHeight = Math.Max(1D, items.Count * (double)Math.Max(1, ItemHeight));
            int thumbHeight = Math.Max(26, Math.Min(track.Height, (int)Math.Round(track.Height * ClientSize.Height / contentHeight)));
            int travel = Math.Max(0, track.Height - thumbHeight);
            int y = MaximumOffset() <= 0D ? 0 : (int)Math.Round(travel * scrollOffset / MaximumOffset());
            return new Rectangle(track.X, track.Y + y, track.Width, thumbHeight);
        }

        private int IndexAt(int y)
        {
            if (y < 0 || y >= ClientSize.Height || ItemHeight <= 0) return -1;
            int index = (int)Math.Floor((y + scrollOffset) / ItemHeight);
            return index >= 0 && index < items.Count ? index : -1;
        }

        private void AnimateTo(double target)
        {
            animationStartOffset = PresentedScrollOffset();
            animationTargetOffset = ClampOffset(target);
            animationStarted = Stopwatch.GetTimestamp();
            scrollAnimating = true;
            scrollTimer.Start();
        }

        private void AdvanceScrollAnimation()
        {
            if (!scrollAnimating) return;
            double elapsed = (Stopwatch.GetTimestamp() - animationStarted) * 1000D / Stopwatch.Frequency;
            double progress = Math.Max(0D, Math.Min(1D, elapsed / SmoothScrollDuration));
            scrollOffset = animationStartOffset + (animationTargetOffset - animationStartOffset) * StrongEaseOut(progress);
            Invalidate();
            if (ViewportChanged != null) ViewportChanged(this, EventArgs.Empty);
            if (progress >= 1D) FinishScrollAnimation();
        }

        private double PresentedScrollOffset()
        {
            if (!scrollAnimating) return scrollOffset;
            double elapsed = (Stopwatch.GetTimestamp() - animationStarted) * 1000D / Stopwatch.Frequency;
            double progress = Math.Max(0D, Math.Min(1D, elapsed / SmoothScrollDuration));
            return animationStartOffset + (animationTargetOffset - animationStartOffset) * StrongEaseOut(progress);
        }

        private void CommitPresentedScrollOffset()
        {
            if (scrollAnimating) scrollOffset = PresentedScrollOffset();
            animationTargetOffset = scrollOffset;
            FinishScrollAnimation();
        }

        private void FinishScrollAnimation()
        {
            scrollAnimating = false;
            scrollTimer.Stop();
            scrollOffset = ClampOffset(scrollOffset);
            animationTargetOffset = scrollOffset;
            Invalidate();
            if (ViewportChanged != null) ViewportChanged(this, EventArgs.Empty);
        }

        private void SetScrollOffset(int value, bool notify)
        {
            scrollAnimating = false;
            scrollTimer.Stop();
            scrollOffset = ClampOffset(value);
            animationStartOffset = animationTargetOffset = scrollOffset;
            Invalidate();
            if (notify && ViewportChanged != null) ViewportChanged(this, EventArgs.Empty);
        }

        private bool IsScrollBarNeeded() { return MaximumOffset() > 0D; }
        private double MaximumOffset() { return Math.Max(0D, items.Count * (double)Math.Max(1, ItemHeight) - ClientSize.Height); }
        private double ClampOffset(double value) { return Math.Max(0D, Math.Min(MaximumOffset(), value)); }

        private static double StrongEaseOut(double progress)
        {
            double low = 0D;
            double high = 1D;
            double parameter = progress;
            for (int i = 0; i < 10; i++)
            {
                parameter = (low + high) / 2D;
                double x = CubicBezierCoordinate(parameter, 0.23D, 0.32D);
                if (x < progress) low = parameter; else high = parameter;
            }
            return CubicBezierCoordinate(parameter, 1D, 1D);
        }

        private static double CubicBezierCoordinate(double parameter, double firstControl, double secondControl)
        {
            double inverse = 1D - parameter;
            return 3D * inverse * inverse * parameter * firstControl + 3D * inverse * parameter * parameter * secondControl + parameter * parameter * parameter;
        }

        private static GraphicsPath RoundedPath(RectangleF rectangle, float radius)
        {
            GraphicsPath path = new GraphicsPath();
            float diameter = Math.Max(1F, radius * 2F);
            path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    internal sealed class SmoothComboBox : Control
    {
        private readonly List<object> items = new List<object>();
        private int selectedIndex = -1;
        private bool hovered;
        private bool pressed;
        private bool updating;
        private bool popupClosing;
        private long reopenBlockedUntil;
        private ToolStripDropDown popup;
        private SmoothListControl popupList;

        public event EventHandler SelectedIndexChanged;

        public SmoothComboBox()
        {
            DropDownHeight = 260;
            ForeColor = AppTheme.Ink;
            AccessibleRole = AccessibleRole.ComboBox;
            TabStop = true;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
        }

        public List<object> Items { get { return items; } }
        public int DropDownHeight { get; set; }
        public bool DroppedDown { get { return IsPopupVisible(popup); } }

        public int SelectedIndex
        {
            get { return selectedIndex; }
            set
            {
                int normalized = value >= 0 && value < items.Count ? value : -1;
                if (selectedIndex == normalized) return;
                selectedIndex = normalized;
                Invalidate();
                if (!updating && SelectedIndexChanged != null) SelectedIndexChanged(this, EventArgs.Empty);
            }
        }

        public object SelectedItem { get { return selectedIndex >= 0 && selectedIndex < items.Count ? items[selectedIndex] : null; } }

        public void BeginUpdate() { updating = true; }
        public void EndUpdate()
        {
            updating = false;
            if (selectedIndex >= items.Count) selectedIndex = -1;
            Invalidate();
        }

        public int FindStringExact(string value)
        {
            for (int i = 0; i < items.Count; i++) if (String.Equals(Convert.ToString(items[i]), value, StringComparison.CurrentCultureIgnoreCase)) return i;
            return -1;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            RectangleF bounds = new RectangleF(4F, 3F, Math.Max(1, Width - 8F), Math.Max(1, Height - 7F));
            bool inset = pressed || DroppedDown;
            Color fill = hovered && !inset ? AppTheme.SecondaryHover : AppTheme.SecondaryFill;
            NeumorphicRenderer.DrawRaised(e.Graphics, bounds, 15, fill, inset ? 0F : 1F);
            NeumorphicRenderer.DrawInset(e.Graphics, bounds, 15, inset ? 1F : 0F);
            if (DroppedDown || Focused)
            {
                using (GraphicsPath focusPath = NeumorphicRenderer.RoundedPath(new RectangleF(bounds.X + 1F, bounds.Y + 1F, bounds.Width - 2F, bounds.Height - 2F), 14F))
                using (Pen pen = new Pen(Color.FromArgb(165, AppTheme.Accent), 1F)) e.Graphics.DrawPath(pen, focusPath);
            }
            string text = SelectedItem == null ? "" : Convert.ToString(SelectedItem);
            GlassTextRenderer.Draw(e.Graphics, text, Font, new RectangleF(10, 0, Math.Max(1, Width - 36), Height), ForeColor, StringAlignment.Near, StringTrimming.EllipsisCharacter);
            Point center = new Point(Width - 15, Height / 2);
            using (Pen pen = new Pen(AppTheme.Muted, 1.5F))
            {
                e.Graphics.DrawLine(pen, center.X - 3, center.Y - 2, center.X, center.Y + 1);
                e.Graphics.DrawLine(pen, center.X, center.Y + 1, center.X + 3, center.Y - 2);
            }
        }

        internal void PaintForTest(Bitmap bitmap)
        {
            using (Graphics graphics = Graphics.FromImage(bitmap))
            using (PaintEventArgs args = new PaintEventArgs(graphics, ClientRectangle))
            {
                OnPaintBackground(args);
                OnPaint(args);
            }
        }

        protected override void OnMouseEnter(EventArgs e) { hovered = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hovered = false; pressed = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e)
        {
            Focus();
            if (e.Button == MouseButtons.Left)
            {
                pressed = true;
                Invalidate();
                ToggleDropDownFromPointer();
            }
            base.OnMouseDown(e);
        }
        protected override void OnMouseUp(MouseEventArgs e) { pressed = false; Invalidate(); base.OnMouseUp(e); }
        protected override void OnMouseWheel(MouseEventArgs e) { }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space || e.KeyCode == Keys.F4 || (e.Alt && e.KeyCode == Keys.Down))
            {
                if (DroppedDown || popupClosing) CloseDropDown(); else ShowDropDown();
                e.Handled = true;
            }
            else if (e.KeyCode == Keys.Escape && DroppedDown)
            {
                CloseDropDown();
                e.Handled = true;
            }
            else if (!DroppedDown && (e.KeyCode == Keys.Up || e.KeyCode == Keys.Down) && items.Count > 0)
            {
                int direction = e.KeyCode == Keys.Up ? -1 : 1;
                SelectedIndex = Math.Max(0, Math.Min(items.Count - 1, selectedIndex < 0 ? 0 : selectedIndex + direction));
                e.Handled = true;
            }
            base.OnKeyDown(e);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                ToolStripDropDown openPopup = popup;
                popup = null;
                popupList = null;
                popupClosing = false;
                if (openPopup != null && !openPopup.IsDisposed) openPopup.Dispose();
            }
            base.Dispose(disposing);
        }

        internal void ScrollWheelForTest(int delta)
        {
            OnMouseWheel(new MouseEventArgs(MouseButtons.None, 0, 5, 5, delta));
        }

        internal void ApplyTheme()
        {
            BackColor = Color.Transparent;
            ForeColor = AppTheme.Ink;
            if (popupList != null && !popupList.IsDisposed)
            {
                popupList.BackColor = AppTheme.GlassSurface;
                popupList.ForeColor = AppTheme.Ink;
                popupList.Invalidate();
            }
            if (popup != null && !popup.IsDisposed) popup.BackColor = AppTheme.GlassSurface;
            Invalidate();
        }

        private void ShowDropDown()
        {
            if (items.Count == 0 || popupClosing || IsDisposed || Disposing) return;
            EnsurePopupCreated();
            ToolStripDropDown activePopup = popup;
            SmoothListControl activeList = popupList;
            if (activePopup == null || activeList == null || activePopup.IsDisposed || activeList.IsDisposed || activePopup.Visible) return;

            activeList.BeginUpdate();
            activeList.Items.Clear();
            activeList.Items.AddRange(items);
            activeList.SelectedIndex = selectedIndex;
            activeList.EndUpdate();
            int listHeight = Math.Max(34, Math.Min(DropDownHeight, items.Count * activeList.ItemHeight));
            activeList.Size = new Size(Math.Max(Width, 128), listHeight);
            activeList.EnsureVisible(selectedIndex, false);
            ToolStripControlHost host = activePopup.Items.Count == 0 ? null : activePopup.Items[0] as ToolStripControlHost;
            if (host != null) host.Size = activeList.Size;
            activePopup.Size = new Size(activeList.Width + 4, activeList.Height + 4);
            try
            {
                Point location = PointToScreen(new Point(0, Height + 4));
                Rectangle workingArea = Screen.FromControl(this).WorkingArea;
                if (location.Y + activePopup.Height > workingArea.Bottom) location.Y = PointToScreen(new Point(0, -activePopup.Height - 4)).Y;
                location.X = Math.Max(workingArea.Left, Math.Min(workingArea.Right - activePopup.Width, location.X));
                activePopup.Show(location);
                if (Object.ReferenceEquals(popup, activePopup) && !activePopup.IsDisposed) activeList.Focus();
                Invalidate();
            }
            catch (ObjectDisposedException)
            {
                ClearPopupReference(activePopup);
            }
            catch
            {
                ClearPopupReference(activePopup);
                throw;
            }
        }

        private void EnsurePopupCreated()
        {
            if (popup != null && !popup.IsDisposed && popupList != null && !popupList.IsDisposed) return;
            if (popup != null && !popup.IsDisposed) popup.Dispose();

            SmoothListControl newList = new SmoothListControl();
            newList.Name = Name + "PopupList";
            newList.Font = Font;
            newList.BackColor = AppTheme.GlassSurface;
            newList.ForeColor = ForeColor;
            newList.ItemHeight = 34;
            newList.ShowInternalScrollBar = true;

            ToolStripControlHost host = new ToolStripControlHost(newList);
            host.AutoSize = false;
            host.Margin = Padding.Empty;
            host.Padding = Padding.Empty;
            ToolStripDropDown newPopup = new ToolStripDropDown();
            newPopup.AutoSize = false;
            newPopup.Padding = new Padding(2);
            newPopup.Margin = Padding.Empty;
            newPopup.BackColor = AppTheme.GlassSurface;
            newPopup.DropShadowEnabled = true;
            newPopup.Items.Add(host);

            newList.ItemActivated += delegate
            {
                SelectedIndex = newList.SelectedIndex;
                CloseDropDown(newPopup);
            };
            newList.CancelRequested += delegate { CloseDropDown(newPopup); };
            newPopup.Closed += delegate(object sender, ToolStripDropDownClosedEventArgs e)
            {
                if (e.CloseReason == ToolStripDropDownCloseReason.AppClicked)
                    reopenBlockedUntil = Stopwatch.GetTimestamp() + (long)(SystemInformation.DoubleClickTime * Stopwatch.Frequency / 1000D);
                popupClosing = false;
                pressed = false;
                if (!IsDisposed) Invalidate();
            };

            popup = newPopup;
            popupList = newList;
            popupClosing = false;
        }

        private void CloseDropDown()
        {
            ToolStripDropDown openPopup = popup;
            CloseDropDown(openPopup, ToolStripDropDownCloseReason.CloseCalled);
        }

        private void CloseDropDown(ToolStripDropDown expectedPopup)
        {
            CloseDropDown(expectedPopup, ToolStripDropDownCloseReason.CloseCalled);
        }

        private void CloseDropDown(ToolStripDropDown expectedPopup, ToolStripDropDownCloseReason reason)
        {
            if (expectedPopup == null || !Object.ReferenceEquals(popup, expectedPopup) || popupClosing) return;
            if (expectedPopup.IsDisposed)
            {
                ClearPopupReference(expectedPopup);
                return;
            }
            if (!expectedPopup.Visible)
            {
                popupClosing = false;
                return;
            }
            popupClosing = true;
            try { expectedPopup.Close(reason); }
            catch (ObjectDisposedException) { ClearPopupReference(expectedPopup); }
            finally
            {
                if (Object.ReferenceEquals(popup, expectedPopup) && !expectedPopup.IsDisposed && !expectedPopup.Visible) popupClosing = false;
            }
        }

        private void ClearPopupReference(ToolStripDropDown expectedPopup)
        {
            if (!Object.ReferenceEquals(popup, expectedPopup)) return;
            popup = null;
            popupList = null;
            popupClosing = false;
            pressed = false;
            if (!IsDisposed) Invalidate();
        }

        private void ToggleDropDownFromPointer()
        {
            if (DroppedDown || popupClosing) CloseDropDown();
            else if (Stopwatch.GetTimestamp() >= reopenBlockedUntil) ShowDropDown();
        }

        private static bool IsPopupVisible(ToolStripDropDown candidate)
        {
            return candidate != null && !candidate.IsDisposed && candidate.Visible;
        }

        private static GraphicsPath RoundedPath(RectangleF rectangle, float radius)
        {
            GraphicsPath path = new GraphicsPath();
            float diameter = radius * 2F;
            path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    internal sealed class ModernButton : Control
    {
        private bool hovered;
        private bool pressed;
        private readonly Timer hoverTimer = new Timer();
        private float hoverProgress;
        private float pressProgress;
        public Color FillColor { get; set; }
        public Color HoverBackColor { get; set; }
        public Color PressedBackColor { get; set; }
        public Color BorderColor { get; set; }
        public Color HighlightColor { get; set; }
        public int CornerRadius { get; set; }
        public bool IsPrimary { get; set; }
        public string Glyph { get; set; }
        public string GlyphFontName { get; set; }
        public float GlyphFontSize { get; set; }

        public ModernButton()
        {
            CornerRadius = 18;
            FillColor = Color.Empty;
            HoverBackColor = AppTheme.SecondaryHover;
            PressedBackColor = AppTheme.SecondaryPressed;
            BorderColor = Color.Transparent;
            HighlightColor = AppTheme.GlassEdge;
            Glyph = "";
            GlyphFontName = "Segoe MDL2 Assets";
            GlyphFontSize = 10F;
            AccessibleRole = AccessibleRole.PushButton;
            TabStop = true;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.SupportsTransparentBackColor | ControlStyles.ResizeRedraw, true);
            BackColor = Color.Transparent;
            hoverTimer.Interval = 15;
            hoverTimer.Tick += delegate
            {
                float hoverTarget = hovered ? 1F : 0F;
                float pressTarget = pressed ? 1F : 0F;
                hoverProgress += hovered ? 0.14F : -0.18F;
                hoverProgress = Math.Max(0F, Math.Min(1F, hoverProgress));
                pressProgress += pressed ? 0.12F : -0.12F;
                pressProgress = Math.Max(0F, Math.Min(1F, pressProgress));
                Invalidate();
                if (Math.Abs(hoverProgress - hoverTarget) < 0.001F && Math.Abs(pressProgress - pressTarget) < 0.001F) hoverTimer.Stop();
            };
        }

        protected override void OnMouseEnter(EventArgs e) { hovered = true; hoverTimer.Start(); RefreshButtonSurface(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hovered = false; pressed = false; hoverTimer.Start(); RefreshButtonSurface(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { if (e.Button == MouseButtons.Left) { pressed = true; hoverTimer.Start(); } RefreshButtonSurface(); base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { pressed = false; hoverTimer.Start(); RefreshButtonSurface(); base.OnMouseUp(e); }
        protected override void OnMouseCaptureChanged(EventArgs e) { if (!Capture) { pressed = false; hoverTimer.Start(); RefreshButtonSurface(); } base.OnMouseCaptureChanged(e); }
        protected override void OnEnabledChanged(EventArgs e) { if (!Enabled) { pressed = false; pressProgress = 0F; } RefreshButtonSurface(); base.OnEnabledChanged(e); }
        protected override void OnGotFocus(EventArgs e) { RefreshButtonSurface(); base.OnGotFocus(e); }
        protected override void OnLostFocus(EventArgs e) { pressed = false; pressProgress = 0F; RefreshButtonSurface(); base.OnLostFocus(e); }

        protected override bool IsInputKey(Keys keyData)
        {
            Keys key = keyData & Keys.KeyCode;
            return key == Keys.Space || key == Keys.Enter || base.IsInputKey(keyData);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (Enabled && (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter))
            {
                pressed = true;
                pressProgress = 1F;
                RefreshButtonSurface();
                e.Handled = true;
            }
            base.OnKeyDown(e);
        }

        protected override void OnKeyUp(KeyEventArgs e)
        {
            if (pressed && (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter))
            {
                pressed = false;
                pressProgress = 0F;
                RefreshButtonSurface();
                OnClick(EventArgs.Empty);
                e.Handled = true;
            }
            base.OnKeyUp(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            RectangleF bounds = new RectangleF(4F, 3.5F, Math.Max(1F, Width - 8F), Math.Max(1F, Height - 8F));
            Color normal = FillColor.IsEmpty ? AppTheme.SecondaryFill : FillColor;
            float easedHover = hoverProgress * hoverProgress * (3F - 2F * hoverProgress);
            Color animatedFill = BlendColor(normal, HoverBackColor, easedHover);
            Color fill = Enabled ? BlendColor(animatedFill, PressedBackColor, pressProgress * 0.22F) : AppTheme.DisabledFill;
            Color text = Enabled ? BlendColor(ForeColor, AppTheme.Accent, IsPrimary ? 0F : easedHover * 0.58F) : AppTheme.DisabledText;
            NeumorphicRenderer.DrawRaised(e.Graphics, bounds, CornerRadius, fill, Enabled ? 1F - pressProgress : 0.28F);
            if (Enabled) NeumorphicRenderer.DrawInset(e.Graphics, bounds, CornerRadius, pressProgress);
            if (BorderColor != Color.Transparent)
            {
                using (GraphicsPath path = NeumorphicRenderer.RoundedPath(bounds, CornerRadius))
                using (Pen pen = new Pen(Enabled ? BorderColor : AppTheme.Line, 1F)) e.Graphics.DrawPath(pen, path);
            }
            DrawContent(e.Graphics, text, 0);
            if (Focused && ShowFocusCues && Enabled)
            {
                RectangleF focusBounds = new RectangleF(bounds.X + 1F, bounds.Y + 1F, Math.Max(1, bounds.Width - 2F), Math.Max(1, bounds.Height - 2F));
                using (GraphicsPath focusPath = NeumorphicRenderer.RoundedPath(focusBounds, Math.Max(3, CornerRadius - 2)))
                using (Pen focusPen = new Pen(Color.FromArgb(175, AppTheme.Accent), 1F)) e.Graphics.DrawPath(focusPen, focusPath);
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) hoverTimer.Dispose();
            base.Dispose(disposing);
        }

        private void RefreshButtonSurface()
        {
            if (Parent != null) Parent.Invalidate(Bounds);
            Invalidate();
        }

        internal void PaintForTest(Bitmap bitmap)
        {
            using (Graphics graphics = Graphics.FromImage(bitmap))
            using (PaintEventArgs args = new PaintEventArgs(graphics, ClientRectangle))
            {
                OnPaintBackground(args);
                OnPaint(args);
            }
        }

        internal void PaintContentForTest(Bitmap bitmap)
        {
            using (Graphics graphics = Graphics.FromImage(bitmap)) DrawContent(graphics, ForeColor, 0);
        }

        internal int ContentWidthForTest { get { return MeasureContentWidth(); } }

        private int MeasureContentWidth()
        {
            TextFormatFlags flags = TextFormatFlags.SingleLine | TextFormatFlags.NoPadding;
            int textWidth = String.IsNullOrEmpty(Text) ? 0 : TextRenderer.MeasureText(Text, Font, new Size(Int32.MaxValue, Height), flags).Width;
            if (String.IsNullOrEmpty(Glyph)) return textWidth;
            using (Font glyphFont = new Font(GlyphFontName, GlyphFontSize, FontStyle.Regular))
            {
                int glyphWidth = TextRenderer.MeasureText(Glyph, glyphFont, new Size(Int32.MaxValue, Height), flags).Width;
                return glyphWidth + (textWidth > 0 ? 7 : 0) + textWidth;
            }
        }

        private void DrawContent(Graphics graphics, Color color, int verticalOffset)
        {
            if (String.IsNullOrEmpty(Glyph))
            {
                RectangleF textBounds = ClientRectangle;
                textBounds.Offset(0, verticalOffset);
                GlassTextRenderer.Draw(graphics, Text, Font, textBounds, color, StringAlignment.Center, StringTrimming.EllipsisCharacter);
                return;
            }

            TextFormatFlags flags = TextFormatFlags.SingleLine | TextFormatFlags.NoPadding | TextFormatFlags.VerticalCenter;
            using (Font glyphFont = new Font(GlyphFontName, GlyphFontSize, FontStyle.Regular))
            {
                int glyphWidth = TextRenderer.MeasureText(Glyph, glyphFont, new Size(Int32.MaxValue, Height), flags).Width;
                int textWidth = String.IsNullOrEmpty(Text) ? 0 : TextRenderer.MeasureText(Text, Font, new Size(Int32.MaxValue, Height), flags).Width;
                int gap = textWidth > 0 ? 7 : 0;
                int totalWidth = glyphWidth + gap + textWidth;
                int left = Math.Max(6, (ClientSize.Width - totalWidth) / 2);
                RectangleF glyphBounds = new RectangleF(left, verticalOffset, glyphWidth, ClientSize.Height);
                GlassTextRenderer.Draw(graphics, Glyph, glyphFont, glyphBounds, color, StringAlignment.Near, StringTrimming.None);
                RectangleF labelBounds = new RectangleF(left + glyphWidth + gap, verticalOffset, Math.Max(1, ClientSize.Width - left - glyphWidth - gap - 6), ClientSize.Height);
                GlassTextRenderer.Draw(graphics, Text, Font, labelBounds, color, StringAlignment.Near, StringTrimming.EllipsisCharacter);
            }
        }

        internal void SetHoveredForTest(bool value)
        {
            hovered = value;
            hoverProgress = value ? 1F : 0F;
            pressed = false;
            pressProgress = 0F;
        }

        internal void SetPressedForTest(bool value)
        {
            pressed = value;
            pressProgress = value ? 1F : 0F;
        }

        internal float PressProgressForTest { get { return pressProgress; } }

        private static Color BlendColor(Color from, Color to, float progress)
        {
            progress = Math.Max(0F, Math.Min(1F, progress));
            return Color.FromArgb(
                (int)Math.Round(from.A + (to.A - from.A) * progress),
                (int)Math.Round(from.R + (to.R - from.R) * progress),
                (int)Math.Round(from.G + (to.G - from.G) * progress),
                (int)Math.Round(from.B + (to.B - from.B) * progress));
        }

        private static GraphicsPath RoundedPath(RectangleF rectangle, int radius)
        {
            GraphicsPath path = new GraphicsPath();
            float diameter = radius * 2F;
            path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    internal sealed class RoundedPanel : Panel
    {
        public Color BorderColor { get; set; }
        public Color MaterialColor { get; set; }
        public Color HighlightColor { get; set; }
        public Color ShadowColor { get; set; }
        public int CornerRadius { get; set; }
        public bool DrawSheen { get; set; }
        public int SheenHeight { get; set; }

        public RoundedPanel()
        {
            BorderColor = Color.Transparent;
            MaterialColor = AppTheme.GlassSurface;
            HighlightColor = AppTheme.GlassEdge;
            ShadowColor = AppTheme.Shadow;
            CornerRadius = 8;
            DrawSheen = false;
            SheenHeight = 0;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            base.OnPaintBackground(e);
            RectangleF bounds = new RectangleF(4F, 3F, Math.Max(1, Width - 8F), Math.Max(1, Height - 8F));
            Color fill = MaterialColor.IsEmpty ? AppTheme.GlassSurface : MaterialColor;
            NeumorphicRenderer.DrawRaised(e.Graphics, bounds, CornerRadius, fill, ShadowColor == Color.Transparent ? 0F : 1F);
            if (BorderColor != Color.Transparent)
            {
                using (GraphicsPath path = NeumorphicRenderer.RoundedPath(bounds, CornerRadius))
                using (Pen pen = new Pen(BorderColor, 1F)) e.Graphics.DrawPath(pen, path);
            }
        }

        private static GraphicsPath RoundedPath(RectangleF rectangle, int radius)
        {
            GraphicsPath path = new GraphicsPath();
            float diameter = Math.Max(2F, radius * 2F);
            path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    internal sealed class MaterialPanel : Panel
    {
        public Color MaterialColor { get; set; }
        public Color EdgeColor { get; set; }
        public bool DrawRightEdge { get; set; }

        public MaterialPanel()
        {
            MaterialColor = AppTheme.GlassSurface;
            EdgeColor = AppTheme.GlassEdge;
            SetStyle(ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.SupportsTransparentBackColor, false);
            DoubleBuffered = false;
        }

        internal bool UsesTransparentResizeBufferForTest
        {
            get { return DoubleBuffered || GetStyle(ControlStyles.OptimizedDoubleBuffer) || GetStyle(ControlStyles.SupportsTransparentBackColor); }
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            GlassBackdropRenderer.PaintInherited(e.Graphics, this);
            Color fill = MaterialColor.IsEmpty ? BackColor : MaterialColor;
            GlassBackdropRenderer.Overlay(e.Graphics, fill, ClientRectangle);
            if (DrawRightEdge && Width > 0)
            {
                using (Pen edge = new Pen(EdgeColor, 1F)) e.Graphics.DrawLine(edge, Width - 1, 0, Width - 1, Height);
            }
        }

        internal static Color ResolveBackgroundColor(Control control)
        {
            Control current = control;
            while (current != null)
            {
                if (current.BackColor.A == 255) return current.BackColor;
                current = current.Parent;
            }
            return AppTheme.WindowBase;
        }

        internal static Color Blend(Color foreground, Color background)
        {
            int alpha = foreground.A;
            int inverse = 255 - alpha;
            return Color.FromArgb(
                (foreground.R * alpha + background.R * inverse) / 255,
                (foreground.G * alpha + background.G * inverse) / 255,
                (foreground.B * alpha + background.B * inverse) / 255);
        }
    }

    internal static class WindowBackdrop
    {
        private const int DwmwaWindowCornerPreference = 33;
        private const int DwmwaUseImmersiveDarkMode = 20;
        internal static bool UsesSystemBackdropForTest { get { return false; } }

        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr window, int attribute, ref int value, int valueSize);

        public static bool Apply(IntPtr window, bool dark)
        {
            try
            {
                int rounded = 2;
                int darkValue = dark ? 1 : 0;
                DwmSetWindowAttribute(window, DwmwaUseImmersiveDarkMode, ref darkValue, sizeof(int));
                return DwmSetWindowAttribute(window, DwmwaWindowCornerPreference, ref rounded, sizeof(int)) == 0;
            }
            catch { return false; }
        }
    }

    internal sealed class MinimalScrollBar : Control
    {
        private int contentSize = 1;
        private int viewportSize = 1;
        private int currentValue;
        private bool hovered;
        private bool dragging;
        private int dragOffset;

        public Orientation Orientation { get; set; }
        public int SmallChange { get; set; }
        public event EventHandler ValueChanged;

        public int Value
        {
            get { return currentValue; }
            set
            {
                int next = Math.Max(0, Math.Min(MaximumValue, value));
                if (next == currentValue) return;
                currentValue = next;
                Invalidate();
                if (ValueChanged != null) ValueChanged(this, EventArgs.Empty);
            }
        }

        private int MaximumValue { get { return Math.Max(0, contentSize - viewportSize); } }
        internal bool IsNeeded { get { return contentSize > viewportSize; } }

        public MinimalScrollBar()
        {
            Orientation = Orientation.Vertical;
            SmallChange = 1;
            TabStop = false;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
        }

        public void SetMetrics(int content, int viewport, int value)
        {
            contentSize = Math.Max(1, content);
            viewportSize = Math.Max(1, Math.Min(contentSize, viewport));
            bool shouldShow = contentSize > viewportSize;
            if (Visible != shouldShow) Visible = shouldShow;
            int next = Math.Max(0, Math.Min(MaximumValue, value));
            if (currentValue != next) currentValue = next;
            Invalidate();
        }

        protected override void OnMouseEnter(EventArgs e)
        {
            hovered = true;
            Invalidate();
            base.OnMouseEnter(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            if (!dragging) hovered = false;
            Invalidate();
            base.OnMouseLeave(e);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                hovered = true;
                Rectangle thumb = ThumbRectangle();
                int coordinate = Orientation == Orientation.Vertical ? e.Y : e.X;
                int thumbStart = Orientation == Orientation.Vertical ? thumb.Top : thumb.Left;
                int thumbLength = Orientation == Orientation.Vertical ? thumb.Height : thumb.Width;
                if (coordinate >= thumbStart && coordinate <= thumbStart + thumbLength)
                {
                    dragOffset = coordinate - thumbStart;
                }
                else
                {
                    dragOffset = thumbLength / 2;
                    SetValueFromPointer(coordinate);
                }
                dragging = true;
                Capture = true;
                Invalidate();
            }
            base.OnMouseDown(e);
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (dragging) SetValueFromPointer(Orientation == Orientation.Vertical ? e.Y : e.X);
            base.OnMouseMove(e);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                dragging = false;
                Capture = false;
                hovered = ClientRectangle.Contains(e.Location);
                Invalidate();
            }
            base.OnMouseUp(e);
        }

        protected override void OnMouseCaptureChanged(EventArgs e)
        {
            if (!Capture)
            {
                dragging = false;
                Invalidate();
            }
            base.OnMouseCaptureChanged(e);
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            int direction = e.Delta > 0 ? -1 : 1;
            Value += direction * Math.Max(1, SmallChange) * 3;
            base.OnMouseWheel(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle thumb = ThumbRectangle();
            if (hovered || dragging)
            {
                RectangleF track = Orientation == Orientation.Vertical
                    ? new RectangleF((Width - 2F) / 2F, 2F, 2F, Math.Max(1, Height - 4F))
                    : new RectangleF(2F, (Height - 2F) / 2F, Math.Max(1, Width - 4F), 2F);
                using (GraphicsPath path = RoundedPath(track, 1F))
                using (Brush brush = new SolidBrush(AppTheme.Line)) e.Graphics.FillPath(brush, path);
            }

            int thickness = hovered || dragging ? 6 : 4;
            RectangleF paintedThumb = Orientation == Orientation.Vertical
                ? new RectangleF((Width - thickness) / 2F, thumb.Y, thickness, thumb.Height)
                : new RectangleF(thumb.X, (Height - thickness) / 2F, thumb.Width, thickness);
            Color thumbColor = dragging ? AppTheme.Ink : (hovered ? AppTheme.ScrollThumbHover : AppTheme.ScrollThumb);
            using (GraphicsPath path = RoundedPath(paintedThumb, thickness / 2F))
            using (Brush brush = new SolidBrush(thumbColor)) e.Graphics.FillPath(brush, path);
        }

        private void SetValueFromPointer(int coordinate)
        {
            Rectangle thumb = ThumbRectangle();
            int length = Orientation == Orientation.Vertical ? Height : Width;
            int thumbLength = Orientation == Orientation.Vertical ? thumb.Height : thumb.Width;
            int travel = Math.Max(1, length - 4 - thumbLength);
            int pixel = Math.Max(0, Math.Min(travel, coordinate - 2 - dragOffset));
            Value = MaximumValue == 0 ? 0 : (int)Math.Round((double)pixel * MaximumValue / travel);
        }

        private Rectangle ThumbRectangle()
        {
            int length = Math.Max(1, Orientation == Orientation.Vertical ? Height : Width);
            int trackLength = Math.Max(1, length - 4);
            int thumbLength = contentSize <= 0 ? trackLength : (int)Math.Round((double)trackLength * viewportSize / contentSize);
            thumbLength = Math.Max(26, Math.Min(trackLength, thumbLength));
            int travel = Math.Max(0, trackLength - thumbLength);
            int position = MaximumValue == 0 ? 0 : (int)Math.Round((double)travel * currentValue / MaximumValue);
            return Orientation == Orientation.Vertical
                ? new Rectangle(0, 2 + position, Width, thumbLength)
                : new Rectangle(2 + position, 0, thumbLength, Height);
        }

        private static GraphicsPath RoundedPath(RectangleF rectangle, float radius)
        {
            GraphicsPath path = new GraphicsPath();
            float diameter = Math.Max(1F, radius * 2F);
            path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    internal sealed class IndeterminateProgressBar : Control
    {
        private readonly Timer timer = new Timer();
        private float offset;
        private bool running;

        public IndeterminateProgressBar()
        {
            Height = 12;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
            timer.Interval = 16;
            timer.Tick += delegate
            {
                offset += 3.2F;
                if (offset > Width + 70) offset = -70;
                Invalidate();
            };
        }

        public void StartAnimation() { running = true; timer.Start(); Invalidate(); }
        public void StopAnimation() { running = false; timer.Stop(); Invalidate(); }

        protected override void OnVisibleChanged(EventArgs e)
        {
            if (Visible && running) timer.Start(); else timer.Stop();
            base.OnVisibleChanged(e);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) timer.Dispose();
            base.Dispose(disposing);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            RectangleF track = new RectangleF(0, 3, Math.Max(1, Width), 6);
            using (GraphicsPath trackPath = RoundedPath(track, 3))
            using (Brush trackBrush = new SolidBrush(AppTheme.Line)) e.Graphics.FillPath(trackBrush, trackPath);
            if (!running) return;
            RectangleF segment = new RectangleF(offset, 3, 70, 6);
            using (GraphicsPath segmentPath = RoundedPath(segment, 3))
            using (Brush segmentBrush = new SolidBrush(AppTheme.Accent)) e.Graphics.FillPath(segmentBrush, segmentPath);
        }

        private static GraphicsPath RoundedPath(RectangleF rectangle, float radius)
        {
            GraphicsPath path = new GraphicsPath();
            float diameter = radius * 2F;
            path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    internal sealed class WorldDetailsDialog : Form
    {
        private readonly TextBox tagsBox = new TextBox();
        private readonly TextBox notesBox = new TextBox();
        private readonly CheckBox autoBackupBox = new CheckBox();
        public bool Saved { get; private set; }
        public string Tags { get { return tagsBox.Text.Trim(); } }
        public string Notes { get { return notesBox.Text.Trim(); } }
        public bool AutoBackup { get { return autoBackupBox.Checked; } }

        public WorldDetailsDialog(WorldInfo world)
        {
            Text = "\u4e16\u754c\u8be6\u60c5";
            StartPosition = FormStartPosition.CenterParent;
            Size = new Size(620, 610);
            MinimumSize = new Size(540, 540);
            BackColor = AppTheme.Canvas;
            Font = new Font("Microsoft YaHei UI", 9F);
            AutoScaleMode = AutoScaleMode.None;
            ShowInTaskbar = false;
            ShowIcon = false;

            TableLayoutPanel root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5, Padding = new Padding(24, 20, 24, 18), BackColor = Color.Transparent };
            root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 78F));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 198F));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 60F));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 52F));
            Controls.Add(root);

            Panel header = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent };
            PictureBox icon = new PictureBox { Location = new Point(0, 2), Size = new Size(56, 56), SizeMode = PictureBoxSizeMode.Zoom, Image = world.Icon };
            Label title = new Label { Text = world.Name, Location = new Point(72, 2), Size = new Size(470, 32), Font = new Font(Font.FontFamily, 18F, FontStyle.Bold), ForeColor = AppTheme.Ink, AutoEllipsis = true };
            Label subtitle = new Label { Text = world.Version + "   /   " + world.GameMode + "   /   " + world.Loader + (world.Favorite ? "   /   \u5df2\u6536\u85cf" : ""), Location = new Point(74, 40), Size = new Size(450, 24), ForeColor = AppTheme.Muted, AutoEllipsis = true };
            header.Controls.Add(icon);
            header.Controls.Add(title);
            header.Controls.Add(subtitle);
            root.Controls.Add(header, 0, 0);

            RoundedPanel information = new RoundedPanel { Dock = DockStyle.Fill, BackColor = Color.Transparent, MaterialColor = AppTheme.SurfaceRaised, BorderColor = Color.Transparent, CornerRadius = 10, Padding = new Padding(16, 12, 16, 10), Margin = new Padding(0, 0, 0, 10) };
            TableLayoutPanel fields = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 8, BackColor = Color.Transparent };
            fields.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 118F));
            fields.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            for (int i = 0; i < 8; i++) fields.RowStyles.Add(new RowStyle(SizeType.Percent, 12.5F));
            AddField(fields, 0, "\u79cd\u5b50", world.Seed.ToString());
            AddField(fields, 1, "\u96be\u5ea6", world.Difficulty);
            AddField(fields, 2, "\u4f5c\u5f0a", world.Cheats ? "\u5df2\u5f00\u542f" : "\u672a\u5f00\u542f");
            AddField(fields, 3, "DataVersion", world.DataVersion > 0 ? world.DataVersion.ToString() : "-");
            AddField(fields, 4, "\u6700\u540e\u6e38\u73a9", world.LastPlayed.ToString("yyyy-MM-dd HH:mm"));
            AddField(fields, 5, "\u5b58\u6863\u5927\u5c0f", FormatBytes(world.SizeBytes));
            AddField(fields, 6, "\u5b9e\u4f8b", world.Source + " / " + world.Loader);
            AddField(fields, 7, "\u72b6\u6001", world.Health + " / \u5907\u4efd " + world.BackupCount + " \u4efd");
            information.Controls.Add(fields);
            root.Controls.Add(information, 0, 1);

            Panel tagsPanel = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent, Padding = new Padding(0, 6, 0, 6) };
            Label tagsLabel = new Label { Text = "\u6807\u7b7e", Location = new Point(0, 9), Size = new Size(52, 30), ForeColor = AppTheme.Muted, TextAlign = ContentAlignment.MiddleLeft };
            tagsBox.Location = new Point(58, 8);
            tagsBox.Size = new Size(310, 30);
            tagsBox.Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top;
            tagsBox.BorderStyle = BorderStyle.FixedSingle;
            tagsBox.BackColor = AppTheme.SurfaceRaised;
            tagsBox.ForeColor = AppTheme.Ink;
            tagsBox.Text = world.Tags ?? "";
            autoBackupBox.Text = "\u5b58\u6863\u53d8\u5316\u65f6\u81ea\u52a8\u5907\u4efd";
            autoBackupBox.AutoSize = true;
            autoBackupBox.Checked = world.AutoBackup;
            autoBackupBox.ForeColor = AppTheme.Muted;
            autoBackupBox.Location = new Point(390, 11);
            tagsPanel.Controls.Add(tagsLabel);
            tagsPanel.Controls.Add(tagsBox);
            tagsPanel.Controls.Add(autoBackupBox);
            root.Controls.Add(tagsPanel, 0, 2);

            Panel notesPanel = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent };
            Label notesLabel = new Label { Text = "\u5907\u6ce8", Dock = DockStyle.Top, Height = 26, ForeColor = AppTheme.Muted, TextAlign = ContentAlignment.MiddleLeft };
            notesBox.Dock = DockStyle.Fill;
            notesBox.Multiline = true;
            notesBox.ScrollBars = ScrollBars.Vertical;
            notesBox.BorderStyle = BorderStyle.FixedSingle;
            notesBox.BackColor = AppTheme.SurfaceRaised;
            notesBox.ForeColor = AppTheme.Ink;
            notesBox.Text = world.Notes ?? "";
            notesPanel.Controls.Add(notesBox);
            notesPanel.Controls.Add(notesLabel);
            root.Controls.Add(notesPanel, 0, 3);

            Panel actions = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent };
            ModernButton cancel = CreateButton("\u53d6\u6d88", false);
            ModernButton save = CreateButton("\u4fdd\u5b58", true);
            cancel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            save.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            cancel.Location = new Point(actions.Width - 224, 10);
            save.Location = new Point(actions.Width - 108, 10);
            cancel.Click += delegate { Close(); };
            save.Click += delegate { Saved = true; DialogResult = DialogResult.OK; Close(); };
            actions.Controls.Add(cancel);
            actions.Controls.Add(save);
            actions.Resize += delegate { save.Left = actions.ClientSize.Width - save.Width; cancel.Left = save.Left - cancel.Width - 8; };
            root.Controls.Add(actions, 0, 4);
            AcceptButton = null;
            CancelButton = null;
        }

        private void AddField(TableLayoutPanel fields, int row, string caption, string value)
        {
            Label name = new Label { Text = caption, Dock = DockStyle.Fill, ForeColor = AppTheme.Muted, TextAlign = ContentAlignment.MiddleLeft, Margin = new Padding(0) };
            Label content = new Label { Text = value, Dock = DockStyle.Fill, ForeColor = AppTheme.Ink, TextAlign = ContentAlignment.MiddleLeft, AutoEllipsis = true, Margin = new Padding(0) };
            fields.Controls.Add(name, 0, row);
            fields.Controls.Add(content, 1, row);
        }

        private ModernButton CreateButton(string text, bool primary)
        {
            ModernButton button = new ModernButton { Text = text, Size = new Size(108, 36), IsPrimary = primary, BackColor = Color.Transparent, FillColor = AppTheme.SecondaryFill, ForeColor = primary ? AppTheme.Accent : AppTheme.Ink, HoverBackColor = AppTheme.SecondaryHover, PressedBackColor = AppTheme.SecondaryPressed, BorderColor = Color.Transparent, HighlightColor = Color.Transparent, CornerRadius = 9, Cursor = Cursors.Hand };
            return button;
        }

        internal static string FormatBytes(long bytes)
        {
            if (bytes < 1024) return bytes + " B";
            string[] units = new string[] { "KB", "MB", "GB", "TB" };
            double value = bytes;
            int unit = -1;
            do { value /= 1024D; unit++; } while (value >= 1024D && unit < units.Length - 1);
            return value.ToString(value >= 100D ? "0" : (value >= 10D ? "0.0" : "0.00")) + " " + units[unit];
        }
    }

    internal sealed class MainForm : Form
    {
        private const string BackupManifestEntry = ".pcl2-world-browser-backup.txt";
        private readonly string appDirectory;
        private readonly string settingsDirectory;
        private readonly string settingsFile;
        private readonly string onboardingFile;
        private readonly string metadataFile;
        private readonly string backupHistoryFile;
        private readonly string themeFile;
        private readonly bool visualPreview;
        private readonly List<string> roots = new List<string>();
        private readonly Dictionary<string, WorldMetadata> metadata = new Dictionary<string, WorldMetadata>(StringComparer.OrdinalIgnoreCase);
        private readonly List<BackupHistoryEntry> backupHistory = new List<BackupHistoryEntry>();
        private List<WorldInfo> allWorlds = new List<WorldInfo>();
        private readonly Dictionary<string, Tuple<string, long>> worldSizeCache = new Dictionary<string, Tuple<string, long>>(StringComparer.OrdinalIgnoreCase);
        private System.Threading.CancellationTokenSource worldSizeCancellation;
        private int worldSizeCalculationGeneration;
        private readonly SmoothListControl rootList = new SmoothListControl();
        private readonly DataGridView grid = new BufferedDataGridView();
        private readonly TextBox searchBox = new TextBox();
        private readonly SmoothComboBox versionFilter = new SmoothComboBox();
        private readonly SmoothComboBox modeFilter = new SmoothComboBox();
        private readonly Label statusLabel = new Label();
        private readonly Label summaryLabel = new Label();
        private readonly IndeterminateProgressBar scanProgress = new IndeterminateProgressBar();
        private readonly Label detailName = new Label();
        private readonly Label detailPath = new Label();
        private readonly ToolTip toolTip = new ToolTip();
        private readonly MinimalScrollBar rootScroll = new MinimalScrollBar();
        private readonly MinimalScrollBar gridVerticalScroll = new MinimalScrollBar();
        private readonly MinimalScrollBar gridHorizontalScroll = new MinimalScrollBar();
        private readonly ModernButton openButton;
        private readonly ModernButton copyButton;
        private readonly ModernButton refreshButton;
        private readonly ModernButton fullScanButton;
        private readonly ModernButton favoriteFilterButton;
        private readonly ModernButton backupButton;
        private readonly ModernButton detailsButton;
        private readonly ModernButton backupHistoryButton;
        private readonly ModernButton favoriteButton;
        private readonly ModernButton themeButton;
        private ModernButton restoreButton;
        private ModernButton removeRootButton;
        private ModernButton exportButton;
        private ModernButton importButton;
        private bool favoriteOnly;
        private string sortColumn = "LastPlayed";
        private bool sortAscending;
        private FormWindowState renderedWindowState = FormWindowState.Normal;

        internal bool UsesTopLevelResizeBufferForTest
        {
            get { return DoubleBuffered || GetStyle(ControlStyles.OptimizedDoubleBuffer) || GetStyle(ControlStyles.AllPaintingInWmPaint); }
        }

        private static Color Ink { get { return AppTheme.Ink; } }
        private static Color Muted { get { return AppTheme.Muted; } }
        private static Color Accent { get { return AppTheme.Accent; } }
        private static Color WindowBase { get { return AppTheme.WindowBase; } }
        private static Color Sidebar { get { return AppTheme.Sidebar; } }
        private static Color Canvas { get { return AppTheme.Canvas; } }
        private static Color Surface { get { return AppTheme.Surface; } }
        private static Color SurfaceRaised { get { return AppTheme.SurfaceRaised; } }
        private static Color GlassSurface { get { return AppTheme.GlassSurface; } }
        private static Color Line { get { return AppTheme.Line; } }
        private static Color GlassEdge { get { return AppTheme.GlassEdge; } }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            WindowBackdrop.Apply(Handle, AppTheme.Dark);
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            GlassBackdropRenderer.Paint(e.Graphics, this);
        }

        protected override void OnResize(EventArgs e)
        {
            bool stateChanged = WindowState != renderedWindowState;
            renderedWindowState = WindowState;
            base.OnResize(e);
            if (!stateChanged || WindowState == FormWindowState.Minimized || !IsHandleCreated) return;
            PerformLayoutTree(this);
            Invalidate(true);
            Update();
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            if (visualPreview) return;
            Rectangle working = Screen.FromControl(this).WorkingArea;
            int targetWidth = Math.Max(MinimumSize.Width, Math.Min(Width, working.Width - 24));
            int targetHeight = Math.Max(MinimumSize.Height, Math.Min(Height, working.Height - 24));
            Size = new Size(targetWidth, targetHeight);
            Location = new Point(
                working.Left + Math.Max(0, (working.Width - Width) / 2),
                working.Top + Math.Max(0, (working.Height - Height) / 2));
            PerformLayoutTree(this);
        }

        private static void PerformLayoutTree(Control parent)
        {
            parent.PerformLayout();
            foreach (Control child in parent.Controls) PerformLayoutTree(child);
        }

        public MainForm(string appDirectory, bool visualPreview = false)
        {
            this.appDirectory = appDirectory;
            this.visualPreview = visualPreview;
            settingsDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PCL2WorldBrowser");
            settingsFile = Path.Combine(settingsDirectory, "roots.txt");
            onboardingFile = Path.Combine(settingsDirectory, "onboarding-1.2.1.complete");
            metadataFile = Path.Combine(settingsDirectory, "world-metadata.txt");
            backupHistoryFile = Path.Combine(settingsDirectory, "backup-history.txt");
            themeFile = Path.Combine(settingsDirectory, "theme.txt");

            Text = "Minecraft Java \u4e16\u754c\u6d4f\u89c8\u5668";
            StartPosition = FormStartPosition.CenterScreen;
            MinimumSize = new Size(980, 620);
            Size = new Size(1280, 780);
            BackColor = WindowBase;
            Font = new Font("Microsoft YaHei UI", 9F);
            AutoScaleMode = AutoScaleMode.None;
            DoubleBuffered = false;
            SetStyle(ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint, false);
            ResizeRedraw = true;
            SetWindowIcon();
            AllowDrop = true;
            DragEnter += delegate(object sender, DragEventArgs e)
            {
                e.Effect = e.Data != null && e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
            };
            DragDrop += delegate(object sender, DragEventArgs e)
            {
                if (e.Data != null && e.Data.GetDataPresent(DataFormats.FileDrop)) HandleDroppedPaths((string[])e.Data.GetData(DataFormats.FileDrop));
            };

            Panel sidebar = BuildSidebar();
            sidebar.Name = "Sidebar";
            Controls.Add(sidebar);

            MaterialPanel main = new MaterialPanel { Name = "Main", Dock = DockStyle.Fill, Padding = new Padding(24, 22, 24, 18), BackColor = Canvas, MaterialColor = Canvas };
            Controls.Add(main);
            main.BringToFront();

            TableLayoutPanel contentLayout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5, Margin = new Padding(0), Padding = new Padding(0), BackColor = Color.Transparent };
            contentLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            contentLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 70F));
            contentLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 58F));
            contentLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 44F));
            contentLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            contentLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 90F));
            main.Controls.Add(contentLayout);

            Panel header = new Panel { Name = "MainHeader", Dock = DockStyle.Fill, BackColor = Color.Transparent, Margin = new Padding(0) };
            Label title = new Label { Name = "MainTitle", Text = "\u4e16\u754c\u6d4f\u89c8\u5668", Font = new Font(Font.FontFamily, 20F, FontStyle.Bold), ForeColor = Ink, AutoSize = true, Location = new Point(0, 0) };
            Label subtitle = new Label { Text = "Minecraft Java  \u00b7  \u8de8\u542f\u52a8\u5668\u5b58\u6863", ForeColor = Muted, AutoSize = true, Location = new Point(2, 40) };
            header.Controls.Add(title);
            header.Controls.Add(subtitle);
            summaryLabel.Text = "0  \u4e2a\u4e16\u754c   /   0  \u4e2a\u76ee\u5f55";
            summaryLabel.Name = "SummaryLabel";
            summaryLabel.ForeColor = Muted;
            summaryLabel.Font = new Font(Font.FontFamily, 9F, FontStyle.Regular);
            summaryLabel.AutoSize = true;
            summaryLabel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            header.Controls.Add(summaryLabel);
            themeButton = MakeButton("", false);
            themeButton.Name = "ThemeToggleButton";
            themeButton.AccessibleName = "\u5207\u6362\u6df1\u8272\u6a21\u5f0f";
            themeButton.Size = new Size(122, 34);
            themeButton.Font = new Font("Microsoft YaHei UI", 9F);
            themeButton.Click += delegate { ToggleTheme(); };
            toolTip.SetToolTip(themeButton, "\u5207\u6362\u6df1\u8272\u6a21\u5f0f");
            header.Controls.Add(themeButton);
            Action layoutHeader = delegate
            {
                themeButton.Left = Math.Max(0, header.ClientSize.Width - themeButton.Width);
                themeButton.Top = 7;
                summaryLabel.Left = Math.Max(title.Right + 16, themeButton.Left - summaryLabel.Width - 16);
            };
            header.Resize += delegate { layoutHeader(); };
            header.Layout += delegate { layoutHeader(); };
            UpdateThemeButton();
            contentLayout.Controls.Add(header, 0, 0);

            Panel toolbar = new Panel { Name = "CommandToolbar", Dock = DockStyle.Fill, BackColor = Color.Transparent, Margin = new Padding(0) };
            RoundedPanel searchSurface = new RoundedPanel { Name = "SearchSurface", Location = new Point(0, 4), Size = new Size(620, 44), BackColor = Color.Transparent, MaterialColor = GlassSurface, BorderColor = Color.Transparent, HighlightColor = Color.Transparent, ShadowColor = AppTheme.Shadow, CornerRadius = 18, DrawSheen = false, SheenHeight = 0 };
            searchSurface.Cursor = Cursors.IBeam;
            searchBox.Name = "SearchBox";
            searchBox.Width = 580;
            searchBox.Height = 22;
            searchBox.Location = new Point(36, 10);
            searchBox.Font = new Font(Font.FontFamily, 10F);
            searchBox.BorderStyle = BorderStyle.None;
            searchBox.BackColor = GlassSurface;
            searchBox.ForeColor = Ink;
            searchBox.TextChanged += delegate { ApplyFilter(); };
            searchSurface.Controls.Add(searchBox);
            Label searchIcon = new Label { Name = "SearchIcon", Text = "\uE721", ForeColor = Muted, Font = new Font("Segoe MDL2 Assets", 11F), AutoSize = true, Location = new Point(12, 13), BackColor = Color.Transparent };
            searchIcon.Cursor = Cursors.IBeam;
            searchSurface.Controls.Add(searchIcon);
            Label searchHint = new Label { Name = "SearchHint", Text = "\u641c\u7d22\u4e16\u754c\u3001\u7248\u672c\u6216\u8def\u5f84", ForeColor = Muted, AutoSize = true, Location = new Point(40, 13), BackColor = Color.Transparent };
            searchHint.Cursor = Cursors.IBeam;
            searchSurface.Controls.Add(searchHint);
            searchHint.BringToFront();
            Action focusSearch = delegate
            {
                searchBox.Focus();
                searchBox.SelectionStart = searchBox.TextLength;
                searchBox.SelectionLength = 0;
            };
            searchSurface.MouseDown += delegate { focusSearch(); };
            searchIcon.MouseDown += delegate { focusSearch(); };
            searchHint.MouseDown += delegate { focusSearch(); };
            searchBox.GotFocus += delegate { searchHint.Visible = false; };
            searchBox.LostFocus += delegate { searchHint.Visible = searchBox.TextLength == 0; };
            toolbar.Controls.Add(searchSurface);

            fullScanButton = MakeButton("\u5168\u76d8\u626b\u63cf", false);
            fullScanButton.Name = "FullScanButton";
            fullScanButton.Location = new Point(toolbar.Width - fullScanButton.Width, 5);
            fullScanButton.Click += delegate { StartScan(true); };
            toolbar.Controls.Add(fullScanButton);
            refreshButton = MakeButton("\u5237\u65b0", false);
            refreshButton.Name = "RefreshButton";
            refreshButton.Location = new Point(fullScanButton.Left - refreshButton.Width - 8, 5);
            refreshButton.Click += delegate { StartScan(false); };
            toolbar.Controls.Add(refreshButton);
            Action layoutToolbar = delegate
            {
                fullScanButton.Left = toolbar.ClientSize.Width - fullScanButton.Width;
                refreshButton.Left = fullScanButton.Left - refreshButton.Width - 8;
                searchSurface.Width = Math.Max(260, Math.Min(620, refreshButton.Left - 16));
                searchBox.Width = Math.Max(220, searchSurface.ClientSize.Width - 40);
            };
            toolbar.Resize += delegate { layoutToolbar(); };
            toolbar.Layout += delegate { layoutToolbar(); };
            contentLayout.Controls.Add(toolbar, 0, 1);

            Panel filters = new Panel { Name = "FilterBar", Dock = DockStyle.Fill, BackColor = Color.Transparent, Margin = new Padding(0) };
            ConfigureFilterCombo(versionFilter, 0, 184);
            versionFilter.Name = "VersionFilter";
            versionFilter.Items.Add("\u5168\u90e8\u7248\u672c");
            versionFilter.SelectedIndex = 0;
            versionFilter.SelectedIndexChanged += delegate { ApplyFilter(); };
            filters.Controls.Add(versionFilter);
            ConfigureFilterCombo(modeFilter, 194, 128);
            modeFilter.Name = "ModeFilter";
            modeFilter.Items.AddRange(new object[] { "\u5168\u90e8\u6a21\u5f0f", "\u751f\u5b58", "\u521b\u9020", "\u5192\u9669", "\u65c1\u89c2", "\u6781\u9650", "\u672a\u77e5" });
            modeFilter.SelectedIndex = 0;
            modeFilter.SelectedIndexChanged += delegate { ApplyFilter(); };
            filters.Controls.Add(modeFilter);
            favoriteFilterButton = MakeButton("\u4ec5\u6536\u85cf", false);
            favoriteFilterButton.Name = "FavoriteFilterButton";
            favoriteFilterButton.Location = new Point(332, 2);
            favoriteFilterButton.Size = new Size(92, 34);
            favoriteFilterButton.Click += delegate
            {
                favoriteOnly = !favoriteOnly;
                UpdateFavoriteFilterAppearance();
                ApplyFilter();
            };
            filters.Controls.Add(favoriteFilterButton);
            Label sortHint = new Label { Text = "\u70b9\u51fb\u8868\u5934\u6392\u5e8f", ForeColor = Muted, AutoSize = true, Anchor = AnchorStyles.Top | AnchorStyles.Right, Location = new Point(filters.Width - 100, 11) };
            filters.Controls.Add(sortHint);
            filters.Resize += delegate { sortHint.Left = filters.ClientSize.Width - sortHint.Width - 4; };
            contentLayout.Controls.Add(filters, 0, 2);

            TableLayoutPanel browserLayout = new TableLayoutPanel { Name = "BrowserLayout", Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 1, Margin = new Padding(0), Padding = new Padding(0), BackColor = Color.Transparent };
            browserLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            contentLayout.Controls.Add(browserLayout, 0, 3);
            ConfigureGrid();
            grid.Margin = new Padding(0);
            RoundedPanel gridSurface = new RoundedPanel { Name = "GridSurface", Dock = DockStyle.Fill, BackColor = Color.Transparent, MaterialColor = SurfaceRaised, BorderColor = Color.Transparent, HighlightColor = Color.Transparent, ShadowColor = AppTheme.Shadow, CornerRadius = 16, Margin = new Padding(0), Padding = new Padding(4) };
            gridSurface.Controls.Add(grid);
            gridVerticalScroll.Name = "GridVerticalScroll";
            gridVerticalScroll.Orientation = Orientation.Vertical;
            gridVerticalScroll.SmallChange = 1;
            gridVerticalScroll.ValueChanged += delegate
            {
                if (grid.Rows.Count == 0) return;
                try { grid.FirstDisplayedScrollingRowIndex = Math.Min(grid.Rows.Count - 1, gridVerticalScroll.Value); }
                catch { }
            };
            gridHorizontalScroll.Name = "GridHorizontalScroll";
            gridHorizontalScroll.Orientation = Orientation.Horizontal;
            gridHorizontalScroll.SmallChange = 36;
            gridHorizontalScroll.ValueChanged += delegate
            {
                try { grid.HorizontalScrollingOffset = gridHorizontalScroll.Value; }
                catch { }
            };
            gridSurface.Controls.Add(gridVerticalScroll);
            gridSurface.Controls.Add(gridHorizontalScroll);
            gridVerticalScroll.BringToFront();
            gridHorizontalScroll.BringToFront();
            gridSurface.Resize += delegate { LayoutGridScrollBars(gridSurface); };
            grid.Scroll += delegate { UpdateGridScrollBars(); };
            grid.MouseWheel += delegate
            {
                if (IsHandleCreated) BeginInvoke(new Action(UpdateGridScrollBars));
            };
            grid.ColumnWidthChanged += delegate { UpdateGridScrollBars(); };
            grid.RowsAdded += delegate { UpdateGridScrollBars(); };
            grid.RowsRemoved += delegate { UpdateGridScrollBars(); };
            browserLayout.Controls.Add(gridSurface, 0, 0);

            Panel footer = new Panel { Name = "StatusFooter", Dock = DockStyle.Fill, BackColor = Color.Transparent, Margin = new Padding(0) };
            RoundedPanel details = new RoundedPanel { Name = "DetailsPanel", Dock = DockStyle.Top, Height = 60, BackColor = Color.Transparent, MaterialColor = SurfaceRaised, BorderColor = Color.Transparent, HighlightColor = Color.Transparent, ShadowColor = AppTheme.Shadow, CornerRadius = 16, Margin = new Padding(0, 12, 0, 0) };
            detailName.Text = "\u6240\u9009\u5730\u56fe\u5b8c\u6574\u8def\u5f84";
            detailName.ForeColor = Muted;
            detailName.Font = new Font(Font.FontFamily, 9F, FontStyle.Regular);
            detailName.Location = new Point(18, 8);
            detailName.Size = new Size(210, 20);
            detailPath.ForeColor = Ink;
            detailPath.AutoEllipsis = true;
            detailPath.Location = new Point(18, 30);
            detailPath.Size = new Size(640, 28);
            details.Controls.Add(detailName);
            details.Controls.Add(detailPath);
            openButton = MakeButton("\u6253\u5f00\u5b58\u6863", true);
            openButton.Name = "OpenWorldButton";
            openButton.Enabled = false;
            openButton.Location = new Point(0, 10);
            openButton.Width = 112;
            openButton.Click += delegate { OpenSelectedWorld(); };
            details.Controls.Add(openButton);
            copyButton = MakeButton("\u590d\u5236\u8def\u5f84", false);
            copyButton.Name = "CopyPathButton";
            copyButton.Enabled = false;
            copyButton.Location = new Point(0, 10);
            copyButton.Width = 90;
            copyButton.Click += delegate { CopySelectedPath(); };
            details.Controls.Add(copyButton);
            backupButton = MakeButton("\u5907\u4efd", false);
            backupButton.Name = "BackupButton";
            backupButton.Enabled = false;
            backupButton.Location = new Point(0, 10);
            backupButton.Width = 64;
            backupButton.Click += delegate { BackupSelectedWorld(); };
            details.Controls.Add(backupButton);
            backupHistoryButton = MakeButton("\u5386\u53f2", false);
            backupHistoryButton.Name = "BackupHistoryButton";
            backupHistoryButton.Enabled = false;
            backupHistoryButton.Location = new Point(0, 10);
            backupHistoryButton.Width = 64;
            backupHistoryButton.Click += delegate { ShowBackupHistory(); };
            details.Controls.Add(backupHistoryButton);
            detailsButton = MakeButton("\u8be6\u60c5", false);
            detailsButton.Name = "DetailsButton";
            detailsButton.Enabled = false;
            detailsButton.Location = new Point(0, 10);
            detailsButton.Width = 64;
            detailsButton.Click += delegate { ShowSelectedWorldDetails(); };
            details.Controls.Add(detailsButton);
            favoriteButton = MakeButton("\u2606", false);
            favoriteButton.Name = "FavoriteButton";
            favoriteButton.AccessibleName = "\u6536\u85cf\u4e16\u754c";
            favoriteButton.Enabled = false;
            favoriteButton.Location = new Point(0, 10);
            favoriteButton.Width = 40;
            favoriteButton.Font = new Font("Segoe UI Symbol", 14F);
            favoriteButton.Click += delegate { ToggleSelectedFavorite(); };
            toolTip.SetToolTip(favoriteButton, "\u6536\u85cf / \u53d6\u6d88\u6536\u85cf");
            details.Controls.Add(favoriteButton);
            Action layoutDetails = delegate
            {
                openButton.Left = Math.Max(500, details.ClientSize.Width - openButton.Width);
                copyButton.Left = openButton.Left - copyButton.Width - 6;
                backupButton.Left = copyButton.Left - backupButton.Width - 8;
                backupHistoryButton.Left = backupButton.Left - backupHistoryButton.Width - 6;
                detailsButton.Left = backupHistoryButton.Left - detailsButton.Width - 6;
                favoriteButton.Left = detailsButton.Left - favoriteButton.Width - 6;
                detailName.Width = Math.Max(100, favoriteButton.Left - 30);
                detailPath.Width = Math.Max(100, favoriteButton.Left - 30);
            };
            details.Resize += delegate { layoutDetails(); };
            details.Layout += delegate { layoutDetails(); };
            footer.Controls.Add(details);
            statusLabel.Text = "\u51c6\u5907\u626b\u63cf";
            statusLabel.Name = "StatusLabel";
            statusLabel.ForeColor = Muted;
            statusLabel.AutoSize = false;
            statusLabel.Location = new Point(0, 62);
            statusLabel.Size = new Size(620, 24);
            statusLabel.TextAlign = ContentAlignment.MiddleLeft;
            statusLabel.AutoEllipsis = true;
            footer.Controls.Add(statusLabel);
            scanProgress.Name = "ScanProgress";
            scanProgress.Visible = false;
            scanProgress.Size = new Size(190, 12);
            scanProgress.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            scanProgress.Location = new Point(footer.Width - scanProgress.Width, 67);
            footer.Controls.Add(scanProgress);
            footer.Resize += delegate
            {
                scanProgress.Left = footer.ClientSize.Width - scanProgress.Width;
                statusLabel.Width = Math.Max(100, footer.ClientSize.Width - scanProgress.Width - 16);
            };
            contentLayout.Controls.Add(footer, 0, 4);

            Load += delegate
            {
                if (this.visualPreview) return;
                bool firstRun = LoadRoots();
                LoadBackupHistory();
                if (firstRun) PromptForInitialRoot();
                InitializeColumnWidths();
                StartScan(false);
            };
            ConfigureDropTarget(sidebar);
            ConfigureDropTarget(main);
            ConfigureDropTarget(rootList);
            ConfigureDropTarget(grid);
        }

        private void SetWindowIcon()
        {
            try
            {
                string projectIcon = Path.Combine(appDirectory, "assets", "MinecraftWorldBrowser.ico");
                if (File.Exists(projectIcon))
                {
                    Icon = new Icon(projectIcon);
                    return;
                }
                string executable = Process.GetCurrentProcess().MainModule.FileName;
                if (File.Exists(executable))
                {
                    Icon extracted = System.Drawing.Icon.ExtractAssociatedIcon(executable);
                    if (extracted != null) Icon = extracted;
                }
            }
            catch { Icon = SystemIcons.Application; }
        }

        private Panel BuildSidebar()
        {
            MaterialPanel sidebar = new MaterialPanel { Dock = DockStyle.Left, Width = 296, BackColor = Sidebar, MaterialColor = Sidebar, EdgeColor = Line, DrawRightEdge = true, Padding = new Padding(20, 18, 20, 16) };
            TableLayoutPanel layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5, BackColor = Color.Transparent, Margin = new Padding(0), Padding = new Padding(0) };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 58F));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 128F));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 30F));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 236F));
            sidebar.Controls.Add(layout);

            Panel brandPanel = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent, Margin = new Padding(0) };
            PictureBox logo = new PictureBox { Name = "AppLogo", Size = new Size(38, 38), Location = new Point(0, 5), SizeMode = PictureBoxSizeMode.Zoom };
            try
            {
                string previewPath = Path.Combine(appDirectory, "assets", "MinecraftWorldBrowser-icon.png");
                string logoPath = Path.Combine(appDirectory, "assets", "MinecraftWorldBrowser.ico");
                if (File.Exists(previewPath))
                {
                    using (Image preview = Image.FromFile(previewPath)) logo.Image = new Bitmap(preview);
                }
                else if (File.Exists(logoPath))
                {
                    using (Icon icon = new Icon(logoPath, new Size(48, 48))) logo.Image = icon.ToBitmap();
                }
            }
            catch { }
            brandPanel.Controls.Add(logo);
            Label brand = new Label { Text = "\u4e16\u754c\u6d4f\u89c8\u5668", ForeColor = Ink, Font = new Font(Font.FontFamily, 14F, FontStyle.Bold), AutoSize = true, Location = new Point(50, 6) };
            Label brandSub = new Label { Text = "MINECRAFT JAVA", ForeColor = Muted, Font = new Font(Font.FontFamily, 8F, FontStyle.Bold), AutoSize = true, Location = new Point(51, 33) };
            brandPanel.Controls.Add(brand);
            brandPanel.Controls.Add(brandSub);
            layout.Controls.Add(brandPanel, 0, 0);

            RoundedPanel about = new RoundedPanel { Name = "AboutCard", Dock = DockStyle.Fill, BackColor = Color.Transparent, MaterialColor = SurfaceRaised, BorderColor = Color.Transparent, HighlightColor = Color.Transparent, ShadowColor = AppTheme.Shadow, CornerRadius = 16, Margin = new Padding(0, 4, 0, 8), Padding = new Padding(16, 12, 16, 10) };
            Color sidebarCard = AppTheme.SidebarCard;
            Label aboutTitle = new Label { Name = "AboutTitle", Text = "\u7a0b\u5e8f\u4fe1\u606f", ForeColor = Ink, BackColor = Color.Transparent, Font = new Font(Font.FontFamily, 10F, FontStyle.Bold), AutoSize = true, Location = new Point(16, 12) };
            Label aboutBody = new Label { Name = "AboutBody", Text = "\u517c\u5bb9\u4e3b\u6d41 Java \u542f\u52a8\u5668\u5b58\u6863\n\u7248\u672c 3.2.6  \u00b7  SOFT UI", ForeColor = Muted, BackColor = Color.Transparent, Font = new Font(Font.FontFamily, 9F), AutoSize = false, Location = new Point(16, 40), Size = new Size(220, 52) };
            about.Controls.Add(aboutTitle);
            about.Controls.Add(aboutBody);
            layout.Controls.Add(about, 0, 1);

            Label caption = new Label { Text = ".minecraft / \u5b9e\u4f8b\u76ee\u5f55", ForeColor = Muted, Font = new Font(Font.FontFamily, 9F, FontStyle.Bold), Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, Margin = new Padding(2, 0, 0, 0) };
            layout.Controls.Add(caption, 0, 2);

            RoundedPanel rootSurface = new RoundedPanel { Name = "RootSurface", Dock = DockStyle.Fill, BackColor = Color.Transparent, MaterialColor = SurfaceRaised, BorderColor = Color.Transparent, HighlightColor = Color.Transparent, ShadowColor = AppTheme.Shadow, CornerRadius = 16, Margin = new Padding(0), Padding = new Padding(4) };
            rootList.Name = "RootList";
            rootList.BackColor = Surface;
            rootList.ForeColor = Ink;
            rootList.Font = new Font("Segoe UI", 9F);
            rootList.ItemHeight = 38;
            rootList.DrawItem += delegate(object sender, DrawItemEventArgs e)
            {
                if (e.Index < 0 || e.Index >= rootList.Items.Count) return;
                bool selected = (e.State & DrawItemState.Selected) == DrawItemState.Selected;
                bool hovered = (e.State & DrawItemState.HotLight) == DrawItemState.HotLight;
                using (Brush backgroundBrush = new SolidBrush(Surface)) e.Graphics.FillRectangle(backgroundBrush, e.Bounds);
                Rectangle row = new Rectangle(e.Bounds.X + 4, e.Bounds.Y + 2, Math.Max(1, e.Bounds.Width - 10), e.Bounds.Height - 4);
                if (selected)
                {
                    using (Brush selectionBrush = new SolidBrush(AppTheme.Selection)) e.Graphics.FillRectangle(selectionBrush, row);
                }
                else if (hovered)
                {
                    using (Brush hoverBrush = new SolidBrush(AppTheme.Hover)) e.Graphics.FillRectangle(hoverBrush, row);
                }
                string value = Convert.ToString(rootList.Items[e.Index]);
                int textWidth = rootList.Parent == null ? row.Width - 18 : Math.Min(row.Width - 18, rootList.Parent.ClientSize.Width - row.X - 20);
                TextRenderer.DrawText(e.Graphics, value, rootList.Font, new Rectangle(row.X + 10, row.Y, Math.Max(20, textWidth), row.Height), selected ? Accent : Ink, TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
            };
            rootList.SelectedIndexChanged += delegate
            {
                removeRootButton.Enabled = rootList.SelectedIndex >= 0;
                UpdateRootScrollBar();
            };
            rootList.ViewportChanged += delegate { UpdateRootScrollBar(); };
            rootScroll.Name = "RootScroll";
            rootScroll.Orientation = Orientation.Vertical;
            rootScroll.SmallChange = rootList.ItemHeight;
            rootScroll.ValueChanged += delegate
            {
                if (rootList.Items.Count == 0) return;
                rootList.ScrollOffset = rootScroll.Value;
            };
            rootSurface.Controls.Add(rootList);
            rootSurface.Controls.Add(rootScroll);
            rootScroll.BringToFront();
            rootSurface.Resize += delegate { LayoutRootScrollBar(rootSurface); };
            layout.Controls.Add(rootSurface, 0, 3);

            Panel actions = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent, Margin = new Padding(0, 8, 0, 0) };
            ModernButton add = MakeButton("\u6dfb\u52a0\u76ee\u5f55", true);
            add.Name = "AddRootButton";
            add.Location = new Point(0, 4);
            add.Height = 38;
            add.Width = 256;
            add.Anchor = AnchorStyles.Top | AnchorStyles.Left;
            add.Click += delegate { AddRoot(true); };
            actions.Controls.Add(add);
            removeRootButton = MakeButton("\u79fb\u9664\u76ee\u5f55", false);
            removeRootButton.Name = "RemoveRootButton";
            removeRootButton.Location = new Point(0, 48);
            removeRootButton.Height = 38;
            removeRootButton.Width = 256;
            removeRootButton.Anchor = AnchorStyles.Top | AnchorStyles.Left;
            removeRootButton.Enabled = false;
            removeRootButton.Click += delegate { RemoveRoot(); };
            actions.Controls.Add(removeRootButton);
            restoreButton = MakeButton("\u6062\u590d ZIP \u5907\u4efd", false);
            restoreButton.Name = "RestoreButton";
            restoreButton.Location = new Point(0, 92);
            restoreButton.Height = 38;
            restoreButton.Width = 256;
            restoreButton.Anchor = AnchorStyles.Top | AnchorStyles.Left;
            restoreButton.Click += delegate { RestoreBackup(); };
            actions.Controls.Add(restoreButton);
            exportButton = MakeButton("\u5bfc\u51fa\u914d\u7f6e", false);
            exportButton.Name = "ExportConfigButton";
            exportButton.Location = new Point(0, 136);
            exportButton.Height = 38;
            exportButton.Width = 256;
            exportButton.Anchor = AnchorStyles.Top | AnchorStyles.Left;
            exportButton.Click += delegate { ExportConfiguration(); };
            actions.Controls.Add(exportButton);
            importButton = MakeButton("\u5bfc\u5165\u914d\u7f6e", false);
            importButton.Name = "ImportConfigButton";
            importButton.Location = new Point(0, 180);
            importButton.Height = 38;
            importButton.Width = 256;
            importButton.Anchor = AnchorStyles.Top | AnchorStyles.Left;
            importButton.Click += delegate { ImportConfiguration(); };
            actions.Controls.Add(importButton);
            actions.Resize += delegate
            {
                int buttonWidth = Math.Max(1, actions.ClientSize.Width);
                add.Width = buttonWidth;
                removeRootButton.Width = buttonWidth;
                restoreButton.Width = buttonWidth;
                exportButton.Width = buttonWidth;
                importButton.Width = buttonWidth;
            };
            layout.Controls.Add(actions, 0, 4);
            return sidebar;
        }

        private void LayoutRootScrollBar(Control surface)
        {
            rootList.SetBounds(1, 1, Math.Max(20, surface.ClientSize.Width - 2), Math.Max(20, surface.ClientSize.Height - 2));
            rootScroll.SetBounds(Math.Max(1, surface.ClientSize.Width - 11), 5, 8, Math.Max(26, surface.ClientSize.Height - 10));
            rootScroll.BringToFront();
            UpdateRootScrollBar();
        }

        private void UpdateRootScrollBar()
        {
            int contentHeight = rootList.Items.Count * Math.Max(1, rootList.ItemHeight);
            rootScroll.SetMetrics(contentHeight, Math.Max(1, rootList.ClientSize.Height), rootList.ScrollOffset);
        }

        private void LayoutGridScrollBars(Control surface)
        {
            int verticalTop = Math.Max(5, grid.ColumnHeadersHeight + 6);
            gridVerticalScroll.SetBounds(Math.Max(1, surface.ClientSize.Width - 11), verticalTop, 8, Math.Max(26, surface.ClientSize.Height - verticalTop - 15));
            gridHorizontalScroll.SetBounds(8, Math.Max(1, surface.ClientSize.Height - 11), Math.Max(26, surface.ClientSize.Width - 24), 8);
            gridVerticalScroll.BringToFront();
            gridHorizontalScroll.BringToFront();
            UpdateGridScrollBars();
        }

        private void UpdateGridScrollBars()
        {
            int displayedRows = grid.Rows.Count == 0 ? 1 : Math.Max(1, grid.DisplayedRowCount(false));
            int firstRow = 0;
            if (grid.Rows.Count > 0)
            {
                try { firstRow = Math.Max(0, grid.FirstDisplayedScrollingRowIndex); }
                catch { firstRow = 0; }
            }
            gridVerticalScroll.SetMetrics(grid.Rows.Count, displayedRows, firstRow);

            int contentWidth = 0;
            foreach (DataGridViewColumn column in grid.Columns)
            {
                if (column.Visible) contentWidth += column.Width;
            }
            int viewportWidth = Math.Max(1, grid.ClientSize.Width - 2);
            gridHorizontalScroll.SetMetrics(contentWidth, viewportWidth, grid.HorizontalScrollingOffset);
        }

        private void ConfigureGrid()
        {
            grid.Name = "WorldGrid";
            grid.Dock = DockStyle.Fill;
            grid.BackgroundColor = Surface;
            grid.BorderStyle = BorderStyle.None;
            grid.AllowUserToAddRows = false;
            grid.AllowUserToDeleteRows = false;
            grid.AllowUserToResizeRows = false;
            grid.ReadOnly = true;
            grid.MultiSelect = false;
            grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
            grid.CellBorderStyle = DataGridViewCellBorderStyle.SingleHorizontal;
            grid.ScrollBars = ScrollBars.None;
            grid.RowHeadersVisible = false;
            grid.RowTemplate.Height = 56;
            grid.AutoGenerateColumns = false;
            grid.EnableHeadersVisualStyles = false;
            grid.ColumnHeadersBorderStyle = DataGridViewHeaderBorderStyle.Single;
            grid.ColumnHeadersHeightSizeMode = DataGridViewColumnHeadersHeightSizeMode.DisableResizing;
            grid.ColumnHeadersHeight = 42;
            grid.ColumnHeadersDefaultCellStyle.BackColor = AppTheme.Header;
            grid.ColumnHeadersDefaultCellStyle.ForeColor = Ink;
            grid.ColumnHeadersDefaultCellStyle.Font = new Font(Font, FontStyle.Bold);
            grid.ColumnHeadersDefaultCellStyle.Padding = new Padding(8, 0, 8, 0);
            grid.DefaultCellStyle.BackColor = Surface;
            grid.AlternatingRowsDefaultCellStyle.BackColor = AppTheme.AlternateRow;
            grid.DefaultCellStyle.ForeColor = Ink;
            grid.DefaultCellStyle.SelectionBackColor = AppTheme.Selection;
            grid.DefaultCellStyle.SelectionForeColor = Ink;
            grid.DefaultCellStyle.Padding = new Padding(8, 3, 8, 3);
            grid.GridColor = Line;

            DataGridViewImageColumn icon = new DataGridViewImageColumn { Name = "Icon", HeaderText = "", Width = 54, ImageLayout = DataGridViewImageCellLayout.Zoom };
            DataGridViewTextBoxColumn name = new DataGridViewTextBoxColumn { Name = "WorldName", HeaderText = "\u4e16\u754c", AutoSizeMode = DataGridViewAutoSizeColumnMode.None, Width = 360 };
            DataGridViewTextBoxColumn version = new DataGridViewTextBoxColumn { Name = "Version", HeaderText = "Minecraft \u7248\u672c", Width = 140 };
            DataGridViewTextBoxColumn mode = new DataGridViewTextBoxColumn { Name = "Mode", HeaderText = "\u6a21\u5f0f", Width = 80 };
            DataGridViewTextBoxColumn health = new DataGridViewTextBoxColumn { Name = "Health", HeaderText = "\u72b6\u6001", Width = 86 };
            DataGridViewTextBoxColumn size = new DataGridViewTextBoxColumn { Name = "Size", HeaderText = "\u5927\u5c0f", Width = 92 };
            DataGridViewTextBoxColumn date = new DataGridViewTextBoxColumn { Name = "LastPlayed", HeaderText = "\u6700\u540e\u6e38\u73a9", Width = 145 };
            DataGridViewTextBoxColumn instance = new DataGridViewTextBoxColumn { Name = "Instance", HeaderText = "\u52a0\u8f7d\u5668", AutoSizeMode = DataGridViewAutoSizeColumnMode.None, Width = 120 };
            DataGridViewTextBoxColumn source = new DataGridViewTextBoxColumn { Name = "Source", HeaderText = "\u5b58\u6863\u4f4d\u7f6e", AutoSizeMode = DataGridViewAutoSizeColumnMode.None, Width = 360 };
            grid.Columns.AddRange(icon, name, version, mode, health, size, date, instance, source);
            foreach (DataGridViewColumn column in grid.Columns) column.SortMode = column.Name == "Icon" ? DataGridViewColumnSortMode.NotSortable : DataGridViewColumnSortMode.Programmatic;
            grid.SelectionChanged += delegate { UpdateDetails(); };
            grid.CellDoubleClick += delegate(object sender, DataGridViewCellEventArgs e) { if (e.RowIndex >= 0) OpenSelectedWorld(); };
            grid.ColumnHeaderMouseClick += async delegate(object sender, DataGridViewCellMouseEventArgs e)
            {
                if (e.ColumnIndex < 0 || grid.Columns[e.ColumnIndex].Name == "Icon") return;
                string selectedColumn = grid.Columns[e.ColumnIndex].Name;
                if (String.Equals(sortColumn, selectedColumn, StringComparison.OrdinalIgnoreCase)) sortAscending = !sortAscending;
                else { sortColumn = selectedColumn; sortAscending = true; }
                if (selectedColumn == "Size" && allWorlds.Any(delegate(WorldInfo world) { return world.SizeBytes <= 0 && Directory.Exists(world.Path); })) await EnsureWorldSizes();
                ApplyFilter(true);
            };
            grid.CellFormatting += delegate(object sender, DataGridViewCellFormattingEventArgs e)
            {
                WorldInfo world = e.RowIndex >= 0 && e.RowIndex < grid.Rows.Count ? grid.Rows[e.RowIndex].Tag as WorldInfo : null;
                if (world != null && e.ColumnIndex == grid.Columns["Health"].Index)
                    e.CellStyle.ForeColor = world.Health == "\u6b63\u5e38" ? (AppTheme.Dark ? Color.FromArgb(78, 203, 123) : Color.FromArgb(35, 125, 78)) : (world.Health == "\u4f7f\u7528\u4e2d" ? AppTheme.Accent : (AppTheme.Dark ? Color.FromArgb(255, 130, 100) : Color.FromArgb(173, 82, 47)));
                else if (world != null && !String.IsNullOrEmpty(world.Error)) e.CellStyle.ForeColor = AppTheme.Dark ? Color.FromArgb(255, 130, 100) : Color.FromArgb(173, 82, 47);
            };
        }

        private void InitializeColumnWidths()
        {
            DataGridViewColumn name = grid.Columns["WorldName"];
            DataGridViewColumn source = grid.Columns["Source"];
            if (name == null || source == null) return;
            int fixedWidth = grid.Columns["Icon"].Width + grid.Columns["Version"].Width + grid.Columns["Mode"].Width + grid.Columns["Health"].Width + grid.Columns["Size"].Width + grid.Columns["LastPlayed"].Width + grid.Columns["Instance"].Width + 24;
            int available = Math.Max(380, grid.ClientSize.Width - fixedWidth);
            name.Width = Math.Max(220, (int)(available * 0.56));
            source.Width = Math.Max(160, available - name.Width);
            UpdateGridScrollBars();
        }

        private ModernButton MakeButton(string text, bool primary)
        {
            ModernButton button = new ModernButton();
            button.Text = text;
            button.IsPrimary = primary;
            button.Height = 36;
            button.Width = primary ? 158 : 116;
            button.BackColor = Color.Transparent;
            button.FillColor = AppTheme.SecondaryFill;
            button.ForeColor = primary ? Accent : Ink;
            button.HoverBackColor = AppTheme.SecondaryHover;
            button.PressedBackColor = AppTheme.SecondaryPressed;
            button.BorderColor = Color.Transparent;
            button.HighlightColor = Color.Transparent;
            button.CornerRadius = 18;
            button.Cursor = Cursors.Hand;
            return button;
        }

        private void ConfigureFilterCombo(SmoothComboBox combo, int left, int width)
        {
            combo.BackColor = Color.Transparent;
            combo.ForeColor = Ink;
            combo.Location = new Point(left, 4);
            combo.Size = new Size(width, 30);
            combo.DropDownHeight = 260;
        }

        private void ToggleTheme()
        {
            ApplyTheme(!AppTheme.Dark, true);
        }

        private void ApplyTheme(bool dark, bool persist)
        {
            bool previousDark = AppTheme.Dark;
            AppTheme.SetDark(dark);
            GlassBackdropRenderer.Invalidate();
            if (persist)
            {
                try { AppTheme.Save(themeFile); }
                catch { }
            }

            RecolorThemeTree(this, previousDark);
            BackColor = WindowBase;
            MaterialPanel sidebar = Controls["Sidebar"] as MaterialPanel;
            MaterialPanel main = Controls["Main"] as MaterialPanel;
            if (sidebar != null)
            {
                sidebar.BackColor = Sidebar;
                sidebar.MaterialColor = Sidebar;
                sidebar.EdgeColor = Line;
            }
            if (main != null)
            {
                main.BackColor = Canvas;
                main.MaterialColor = Canvas;
            }
            ApplyRoundedTheme("SearchSurface", GlassSurface, 255, 168);
            ApplyRoundedTheme("DetailsPanel", Color.FromArgb(152, 44, 40, 72), 132, 132);
            ApplyRoundedTheme("AboutCard", Color.FromArgb(148, 49, 42, 73), 118, 135);
            ApplyRoundedTheme("GridSurface", Color.FromArgb(210, 28, 27, 49), 202, 145);
            ApplyRoundedTheme("RootSurface", Color.FromArgb(188, 31, 29, 52), 174, 138);
            ApplyEmbeddedSurfaceTheme();

            rootList.BackColor = Surface;
            rootList.ForeColor = Ink;
            searchBox.ForeColor = Ink;
            versionFilter.ApplyTheme();
            modeFilter.ApplyTheme();
            ApplyGridTheme();
            UpdateFavoriteFilterAppearance();
            UpdateThemeButton();
            if (IsHandleCreated) WindowBackdrop.Apply(Handle, AppTheme.Dark);
            Invalidate(true);
            Update();
        }

        private void ApplyRoundedTheme(string name, Color darkMaterial, int lightMaterialAlpha, int lightBorderAlpha)
        {
            Control[] matches = Controls.Find(name, true);
            if (matches.Length == 0) return;
            RoundedPanel panel = matches[0] as RoundedPanel;
            if (panel == null) return;
            panel.BackColor = Color.Transparent;
            panel.MaterialColor = name == "SearchSurface" ? GlassSurface : SurfaceRaised;
            panel.BorderColor = Color.Transparent;
            panel.HighlightColor = Color.Transparent;
            panel.ShadowColor = AppTheme.Shadow;
        }

        private void ApplyEmbeddedSurfaceTheme()
        {
            Control[] searchMatches = Controls.Find("SearchSurface", true);
            RoundedPanel searchSurface = searchMatches.Length == 0 ? null : searchMatches[0] as RoundedPanel;
            if (searchSurface != null)
            {
                Color fill = GlassSurface;
                searchSurface.BackColor = Color.Transparent;
                searchSurface.MaterialColor = fill;
                foreach (Control child in searchSurface.Controls) child.BackColor = child == searchBox ? fill : Color.Transparent;
            }

            Control[] aboutMatches = Controls.Find("AboutCard", true);
            RoundedPanel aboutCard = aboutMatches.Length == 0 ? null : aboutMatches[0] as RoundedPanel;
            if (aboutCard != null)
            {
                aboutCard.BackColor = Color.Transparent;
                foreach (Control child in aboutCard.Controls) child.BackColor = Color.Transparent;
            }
        }

        private void AssertEmbeddedSurfaceTheme()
        {
            RoundedPanel searchSurface = Controls.Find("SearchSurface", true).FirstOrDefault() as RoundedPanel;
            RoundedPanel aboutCard = Controls.Find("AboutCard", true).FirstOrDefault() as RoundedPanel;
            if (searchSurface == null || aboutCard == null) throw new Exception("Embedded material surfaces are missing.");
            if (searchSurface.BackColor != Color.Transparent || searchBox.BackColor != searchSurface.MaterialColor)
                throw new Exception("Search text background does not match its material surface.");
            foreach (Control child in searchSurface.Controls)
            {
                Color expected = child == searchBox ? searchSurface.MaterialColor : Color.Transparent;
                if (child.BackColor != expected) throw new Exception("A search child control has a mismatched background.");
            }
            foreach (Control child in aboutCard.Controls)
            {
                if (child.BackColor != Color.Transparent) throw new Exception("Program information text does not inherit the glass material.");
            }
        }

        private void ApplyGridTheme()
        {
            grid.BackgroundColor = Surface;
            grid.ColumnHeadersDefaultCellStyle.BackColor = AppTheme.Header;
            grid.ColumnHeadersDefaultCellStyle.ForeColor = Ink;
            grid.DefaultCellStyle.BackColor = Surface;
            grid.AlternatingRowsDefaultCellStyle.BackColor = AppTheme.AlternateRow;
            grid.DefaultCellStyle.ForeColor = Ink;
            grid.DefaultCellStyle.SelectionBackColor = AppTheme.Selection;
            grid.DefaultCellStyle.SelectionForeColor = Ink;
            grid.GridColor = Line;
            grid.Invalidate();
        }

        private void RecolorThemeTree(Control parent, bool previousDark)
        {
            Color oldInk = AppTheme.InkFor(previousDark);
            Color oldMuted = AppTheme.MutedFor(previousDark);
            Color oldAccent = previousDark ? Color.FromArgb(132, 166, 255) : Color.FromArgb(74, 118, 232);
            if (parent.ForeColor == oldInk) parent.ForeColor = Ink;
            else if (parent.ForeColor == oldMuted) parent.ForeColor = Muted;
            else if (parent.ForeColor == oldAccent) parent.ForeColor = Accent;

            if (parent.BackColor == AppTheme.WindowBaseFor(previousDark)) parent.BackColor = WindowBase;
            else if (parent.BackColor == AppTheme.SidebarFor(previousDark)) parent.BackColor = Sidebar;
            else if (parent.BackColor == AppTheme.CanvasFor(previousDark)) parent.BackColor = Canvas;
            else if (parent.BackColor == AppTheme.SurfaceFor(previousDark)) parent.BackColor = Surface;
            else if (parent.BackColor == AppTheme.SurfaceRaisedFor(previousDark)) parent.BackColor = SurfaceRaised;
            else if (parent.BackColor == AppTheme.GlassSurfaceFor(previousDark)) parent.BackColor = GlassSurface;
            else if (parent.BackColor == AppTheme.SidebarCardFor(previousDark)) parent.BackColor = AppTheme.SidebarCard;

            ModernButton button = parent as ModernButton;
            if (button != null) ApplyButtonTheme(button);
            foreach (Control child in parent.Controls) RecolorThemeTree(child, previousDark);
        }

        private void ApplyButtonTheme(ModernButton button)
        {
            bool primary = button.IsPrimary;
            button.BackColor = Color.Transparent;
            button.FillColor = AppTheme.SecondaryFill;
            button.ForeColor = primary ? Accent : Ink;
            button.HoverBackColor = AppTheme.SecondaryHover;
            button.PressedBackColor = AppTheme.SecondaryPressed;
            button.BorderColor = Color.Transparent;
            button.HighlightColor = Color.Transparent;
            button.Invalidate();
        }

        private void UpdateThemeButton()
        {
            if (themeButton == null) return;
            themeButton.Glyph = AppTheme.Dark ? "\uE706" : "\uE708";
            themeButton.Text = AppTheme.Dark ? "\u5207\u6362\u4eae\u8272" : "\u5207\u6362\u6697\u8272";
            string description = AppTheme.Dark ? "\u5207\u6362\u6d45\u8272\u6a21\u5f0f" : "\u5207\u6362\u6df1\u8272\u6a21\u5f0f";
            themeButton.AccessibleName = description;
            toolTip.SetToolTip(themeButton, description);
        }

        internal void ThemeSelfTest()
        {
            bool original = AppTheme.Dark;
            ApplyTheme(true, false);
            if (BackColor.GetBrightness() >= 0.2F || grid.DefaultCellStyle.BackColor.GetBrightness() >= 0.25F || Ink.GetBrightness() <= 0.7F || themeButton.Glyph != "\uE706" || themeButton.Text != "\u5207\u6362\u4eae\u8272")
                throw new Exception("Dark theme surfaces or contrast are incorrect.");
            if (themeButton.ContentWidthForTest + 18 > themeButton.ClientSize.Width)
                throw new Exception("Dark theme toggle icon and label are clipped.");
            AssertEmbeddedSurfaceTheme();
            using (Bitmap darkFrame = new Bitmap(Math.Max(1, ClientSize.Width), Math.Max(1, ClientSize.Height)))
            {
                DrawToBitmap(darkFrame, ClientRectangle);
                Color sidebarPixel = darkFrame.GetPixel(10, Math.Min(darkFrame.Height - 1, 300));
                Color mainPixel = darkFrame.GetPixel(Math.Min(darkFrame.Width - 1, 302), Math.Min(darkFrame.Height - 1, 300));
                if (sidebarPixel.GetBrightness() < 0.025F || sidebarPixel.GetBrightness() > 0.35F || mainPixel.GetBrightness() < 0.025F || mainPixel.GetBrightness() > 0.35F)
                    throw new Exception("Dark theme renders a black or light gap: sidebar=" + sidebarPixel + ", main=" + mainPixel + ".");
            }
            ApplyTheme(false, false);
            if (BackColor.GetBrightness() <= 0.5F || grid.DefaultCellStyle.BackColor.GetBrightness() <= 0.7F || themeButton.Glyph != "\uE708" || themeButton.Text != "\u5207\u6362\u6697\u8272")
                throw new Exception("Light theme did not restore correctly.");
            if (themeButton.ContentWidthForTest + 18 > themeButton.ClientSize.Width)
                throw new Exception("Light theme toggle icon and label are clipped.");
            AssertEmbeddedSurfaceTheme();
            ApplyTheme(original, false);
        }

        internal void PrepareVisualPreview()
        {
            roots.Clear();
            roots.Add(@"D:\Games\PCL2\.minecraft");
            roots.Add(@"D:\Minecraft\PrismLauncher\instances");
            roots.Add(@"C:\Users\Player\AppData\Roaming\.minecraft");
            RefreshRootList();
            allWorlds = new List<WorldInfo>
            {
                new WorldInfo { Icon = WorldScanner.CreateFallbackIcon(), Name = "Survival Garden", Version = "1.21.1", GameMode = "\u751f\u5b58", Health = "\u6b63\u5e38", SizeBytes = 1328755507L, LastPlayed = DateTime.Now.AddMinutes(-18), Loader = "Fabric 0.16.9", Path = @"D:\Games\PCL2\.minecraft\versions\1.21.1-Fabric\saves\Survival Garden", Source = "1.21.1-Fabric", Favorite = true },
                new WorldInfo { Icon = WorldScanner.CreateFallbackIcon(), Name = "Creative Studio", Version = "1.20.4", GameMode = "\u521b\u9020", Health = "\u6b63\u5e38", SizeBytes = 486539264L, LastPlayed = DateTime.Now.AddDays(-2), Loader = "Forge 49.0.50", Path = @"D:\Minecraft\PrismLauncher\instances\Creative\.minecraft\saves\Creative Studio", Source = "Creative" },
                new WorldInfo { Icon = WorldScanner.CreateFallbackIcon(), Name = "Redstone Lab", Version = "1.19.2", GameMode = "\u751f\u5b58", Health = "\u6b63\u5e38", SizeBytes = 203423744L, LastPlayed = DateTime.Now.AddDays(-8), Loader = "NeoForge", Path = @"C:\Users\Player\AppData\Roaming\.minecraft\saves\Redstone Lab", Source = ".minecraft" }
            };
            versionFilter.Items.Clear();
            versionFilter.Items.AddRange(new object[] { "\u5168\u90e8\u7248\u672c", "1.21.1", "1.20.4", "1.19.2" });
            versionFilter.SelectedIndex = 0;
            ApplyFilter(true);
            if (grid.Rows.Count > 0)
            {
                grid.Rows[0].Selected = true;
                grid.CurrentCell = grid.Rows[0].Cells["WorldName"];
            }
            statusLabel.Text = "\u5df2\u53d1\u73b0 3 \u4e2a\u4e16\u754c  \u00b7  \u8de8\u542f\u52a8\u5668\u5b58\u6863\u5df2\u5408\u5e76";
        }

        private void UpdateFavoriteFilterAppearance()
        {
            favoriteFilterButton.FillColor = favoriteOnly ? AppTheme.Selection : AppTheme.SecondaryFill;
            favoriteFilterButton.HoverBackColor = favoriteOnly ? AppTheme.Selection : AppTheme.SecondaryHover;
            favoriteFilterButton.PressedBackColor = favoriteOnly ? AppTheme.Selection : AppTheme.SecondaryPressed;
            favoriteFilterButton.BorderColor = Color.Transparent;
            favoriteFilterButton.ForeColor = favoriteOnly ? Accent : Ink;
            favoriteFilterButton.Invalidate();
        }

        internal void FavoriteFilterHoverSelfTest()
        {
            favoriteOnly = true;
            UpdateFavoriteFilterAppearance();
            favoriteFilterButton.SetHoveredForTest(true);
            using (Bitmap bitmap = new Bitmap(favoriteFilterButton.Width, favoriteFilterButton.Height))
            {
                favoriteFilterButton.PaintForTest(bitmap);
                Color hoverPixel = bitmap.GetPixel(16, favoriteFilterButton.Height / 2);
                int surfaceDifference = Math.Abs(hoverPixel.R - AppTheme.Selection.R) + Math.Abs(hoverPixel.G - AppTheme.Selection.G) + Math.Abs(hoverPixel.B - AppTheme.Selection.B);
                if (favoriteFilterButton.ForeColor != Accent || favoriteFilterButton.FillColor != AppTheme.Selection || favoriteFilterButton.HoverBackColor != AppTheme.Selection || surfaceDifference > 8)
                    throw new Exception("Active favorite filter loses its selected neumorphic surface while hovered.");
            }
            favoriteFilterButton.SetHoveredForTest(false);
            favoriteOnly = false;
            UpdateFavoriteFilterAppearance();
        }

        private void RefreshVersionFilter()
        {
            string selected = versionFilter.SelectedIndex > 0 ? Convert.ToString(versionFilter.SelectedItem) : null;
            versionFilter.BeginUpdate();
            versionFilter.Items.Clear();
            versionFilter.Items.Add("\u5168\u90e8\u7248\u672c");
            foreach (string version in allWorlds.Select(delegate(WorldInfo world) { return world.Version; }).Where(delegate(string value) { return !String.IsNullOrWhiteSpace(value); }).Distinct(StringComparer.CurrentCultureIgnoreCase).OrderBy(delegate(string value) { return value; })) versionFilter.Items.Add(version);
            int index = selected == null ? 0 : versionFilter.FindStringExact(selected);
            versionFilter.SelectedIndex = index < 0 ? 0 : index;
            versionFilter.EndUpdate();
        }

        private bool LoadRoots()
        {
            bool firstRun = !File.Exists(onboardingFile);
            LoadMetadata();
            if (File.Exists(settingsFile))
            {
                string[] savedRoots = File.ReadAllLines(settingsFile, Encoding.UTF8);
                foreach (string line in savedRoots) AddRootPath(line, false);
            }
            AddRootPath(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), ".minecraft"), false);
            DiscoverNear(appDirectory, 3);
            string desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            DiscoverLaunchers(desktop);
            string downloads = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
            DiscoverLaunchers(downloads);
            SaveRoots();
            RefreshRootList();
            return firstRun;
        }

        private void PromptForInitialRoot()
        {
            DialogResult answer = MessageBox.Show(this, "\u8fd9\u662f\u7b2c\u4e00\u6b21\u6253\u5f00\u4e16\u754c\u6d4f\u89c8\u5668\u3002\n\n\u662f\u5426\u73b0\u5728\u6dfb\u52a0\u6b63\u5728\u4f7f\u7528\u7684 Minecraft \u6e38\u620f\u76ee\u5f55\u6216\u542f\u52a8\u5668\u76ee\u5f55\uff1f\n\n\u70b9\u201c\u662f\u201d\u9009\u62e9\u76ee\u5f55\uff0c\u70b9\u201c\u5426\u201d\u76f4\u63a5\u8fdb\u5165\u7a0b\u5e8f\u3002", "\u6dfb\u52a0 Minecraft \u76ee\u5f55", MessageBoxButtons.YesNo, MessageBoxIcon.Information);
            if (answer == DialogResult.Yes) AddRoot(false);
            try
            {
                Directory.CreateDirectory(settingsDirectory);
                File.WriteAllText(onboardingFile, "1.2.1", Encoding.ASCII);
            }
            catch { }
        }

        private void DiscoverNear(string start, int levels)
        {
            string current = start;
            for (int i = 0; i <= levels && !String.IsNullOrEmpty(current); i++)
            {
                AddRootPath(Path.Combine(current, ".minecraft"), false);
                AddRootPath(current, false);
                DirectoryInfo parent = null;
                try { parent = Directory.GetParent(current); } catch { }
                current = parent == null ? null : parent.FullName;
            }
        }

        private void DiscoverLaunchers(string folder)
        {
            if (!Directory.Exists(folder)) return;
            try
            {
                foreach (string file in Directory.GetFiles(folder, "*.exe", SearchOption.TopDirectoryOnly))
                {
                    string name = Path.GetFileName(file).ToLowerInvariant();
                    if (LooksLikeLauncherName(name)) AddRootPath(Path.GetDirectoryName(file), true);
                }
                foreach (string child in Directory.GetDirectories(folder))
                {
                    string name = Path.GetFileName(child).ToLowerInvariant();
                    if (LooksLikeLauncherName(name) || name.Contains("minecraft")) AddRootPath(child, true);
                }
            }
            catch { }
        }

        private static bool LooksLikeLauncherName(string name)
        {
            if (String.IsNullOrWhiteSpace(name)) return false;
            string value = name.ToLowerInvariant();
            return value.Contains("pcl") || value.Contains("plain craft") || value.Contains("hmcl")
                || value.Contains("prism") || value.Contains("multimc") || value.Contains("curseforge")
                || value.Contains("modrinth") || value.Contains("atlauncher") || value.Contains("gdlauncher")
                || value.Contains("technic") || value.Contains("ftb") || value.Contains("bakaxl");
        }

        private bool AddRootPath(string path, bool searchChildren)
        {
            if (String.IsNullOrWhiteSpace(path)) return false;
            List<string> candidates = new List<string>();
            try
            {
                path = Path.GetFullPath(path.Trim().Trim('"'));
                if (Path.GetFileName(path).Equals("saves", StringComparison.OrdinalIgnoreCase))
                {
                    DirectoryInfo parent = Directory.GetParent(path);
                    if (parent != null && LooksLikeRoot(parent.FullName)) candidates.Add(parent.FullName);
                }
                if (searchChildren) candidates.AddRange(DiscoverGameRoots(path, 4));
                else
                {
                    if (LooksLikeRoot(path)) candidates.Add(path);
                    string nested = Path.Combine(path, ".minecraft");
                    if (LooksLikeRoot(nested)) candidates.Add(nested);
                }
            }
            catch { return false; }
            bool changed = false;
            foreach (string candidate in candidates)
            {
                if (!roots.Contains(candidate, StringComparer.OrdinalIgnoreCase)) { roots.Add(candidate); changed = true; }
            }
            return changed;
        }

        internal static List<string> DiscoverGameRoots(string start, int maximumDepth)
        {
            List<string> found = new List<string>();
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            Queue<Tuple<string, int>> pending = new Queue<Tuple<string, int>>();
            if (!String.IsNullOrWhiteSpace(start)) pending.Enqueue(Tuple.Create(start, 0));
            while (pending.Count > 0)
            {
                Tuple<string, int> item = pending.Dequeue();
                string current;
                try { current = Path.GetFullPath(item.Item1).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar); }
                catch { continue; }
                if (!seen.Add(current) || !Directory.Exists(current)) continue;
                if (LooksLikeRoot(current))
                {
                    found.Add(current);
                    continue;
                }
                if (item.Item2 >= Math.Max(0, maximumDepth)) continue;
                try
                {
                    DirectoryInfo info = new DirectoryInfo(current);
                    if ((info.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    foreach (string child in Directory.EnumerateDirectories(current))
                    {
                        string name = Path.GetFileName(child);
                        if (IsLauncherSearchNoise(name)) continue;
                        pending.Enqueue(Tuple.Create(child, item.Item2 + 1));
                    }
                }
                catch (UnauthorizedAccessException) { }
                catch (IOException) { }
                catch (ArgumentException) { }
            }
            return found;
        }

        private static bool IsLauncherSearchNoise(string name)
        {
            if (IsSystemDirectory(name)) return true;
            switch ((name ?? String.Empty).ToLowerInvariant())
            {
                case "assets":
                case "libraries":
                case "runtime":
                case "logs":
                case "crash-reports":
                case "resourcepacks":
                case "shaderpacks":
                case "screenshots":
                case "mods":
                case "config":
                case "cache":
                case "caches":
                case "natives":
                case "webcache":
                    return true;
                default:
                    return false;
            }
        }

        private static bool LooksLikeRoot(string path)
        {
            return Directory.Exists(path) && (Directory.Exists(Path.Combine(path, "saves")) || Directory.Exists(Path.Combine(path, "versions")) || File.Exists(Path.Combine(path, "launcher_profiles.json")));
        }

        private void AddRoot(bool scanAfterAdd)
        {
            using (FolderBrowserDialog dialog = new FolderBrowserDialog())
            {
                dialog.Description = "\u9009\u62e9 .minecraft\u3001\u6e38\u620f\u5b9e\u4f8b\u6216\u542f\u52a8\u5668\u6240\u5728\u6587\u4ef6\u5939";
                dialog.ShowNewFolderButton = false;
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                bool changed = AddRootPath(dialog.SelectedPath, true);
                if (!changed)
                {
                    MessageBox.Show(this, "\u6ca1\u6709\u5728\u6240\u9009\u4f4d\u7f6e\u53d1\u73b0 Minecraft Java \u5b58\u6863\u76ee\u5f55\u3002\n\n\u8bf7\u9009\u62e9 .minecraft\u3001\u6e38\u620f\u5b9e\u4f8b\u76ee\u5f55\u6216\u542f\u52a8\u5668\u6240\u5728\u6587\u4ef6\u5939\u3002", "\u672a\u627e\u5230\u6e38\u620f\u76ee\u5f55", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
                SaveRoots();
                RefreshRootList();
                if (scanAfterAdd) StartScan(false);
            }
        }

        private void HandleDroppedPaths(IEnumerable<string> paths)
        {
            bool changed = false;
            foreach (string path in paths ?? new string[0])
            {
                if (Directory.Exists(path)) changed |= AddRootPath(path, true);
            }
            if (!changed)
            {
                statusLabel.Text = "\u6ca1\u6709\u5728\u62d6\u5165\u4f4d\u7f6e\u627e\u5230 Minecraft Java \u5b58\u6863";
                return;
            }
            SaveRoots();
            RefreshRootList();
            StartScan(false);
        }

        private void ConfigureDropTarget(Control target)
        {
            if (target == null) return;
            target.AllowDrop = true;
            target.DragEnter += delegate(object sender, DragEventArgs e)
            {
                e.Effect = e.Data != null && e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
            };
            target.DragDrop += delegate(object sender, DragEventArgs e)
            {
                if (e.Data != null && e.Data.GetDataPresent(DataFormats.FileDrop)) HandleDroppedPaths((string[])e.Data.GetData(DataFormats.FileDrop));
            };
        }

        private void ExportConfiguration()
        {
            using (SaveFileDialog dialog = new SaveFileDialog())
            {
                dialog.Title = "\u5bfc\u51fa\u4e16\u754c\u6d4f\u89c8\u5668\u914d\u7f6e";
                dialog.Filter = "\u4e16\u754c\u6d4f\u89c8\u5668\u914d\u7f6e (*.mwconfig)|*.mwconfig";
                dialog.FileName = "MinecraftWorldBrowser-config.mwconfig";
                dialog.AddExtension = true;
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                try
                {
                    List<string> lines = new List<string> { "MinecraftWorldBrowserConfig=1" };
                    foreach (string root in roots) lines.Add("Root=" + EncodeMetadata(root));
                    foreach (KeyValuePair<string, WorldMetadata> pair in metadata)
                    {
                        WorldMetadata value = pair.Value;
                        lines.Add("Meta=" + EncodeMetadata(pair.Key) + "\t" + (value.Favorite ? "1" : "0") + "\t" + EncodeMetadata(value.Tags) + "\t" + EncodeMetadata(value.Notes) + "\t" + (value.AutoBackup ? "1" : "0") + "\t" + EncodeMetadata(value.LastBackupFingerprint));
                    }
                    File.WriteAllLines(dialog.FileName, lines, new UTF8Encoding(false));
                    statusLabel.Text = "\u914d\u7f6e\u5df2\u5bfc\u51fa";
                }
                catch (Exception ex) { MessageBox.Show(this, ex.Message, "\u5bfc\u51fa\u5931\u8d25", MessageBoxButtons.OK, MessageBoxIcon.Error); }
            }
        }

        private void ImportConfiguration()
        {
            using (OpenFileDialog dialog = new OpenFileDialog())
            {
                dialog.Title = "\u5bfc\u5165\u4e16\u754c\u6d4f\u89c8\u5668\u914d\u7f6e";
                dialog.Filter = "\u4e16\u754c\u6d4f\u89c8\u5668\u914d\u7f6e (*.mwconfig)|*.mwconfig|\u6240\u6709\u6587\u4ef6 (*.*)|*.*";
                dialog.CheckFileExists = true;
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                try
                {
                    bool valid = false;
                    foreach (string line in File.ReadAllLines(dialog.FileName, Encoding.UTF8))
                    {
                        if (line == "MinecraftWorldBrowserConfig=1") { valid = true; continue; }
                        if (!valid) continue;
                        if (line.StartsWith("Root=", StringComparison.OrdinalIgnoreCase)) AddRootPath(DecodeMetadata(line.Substring(5)), true);
                        else if (line.StartsWith("Meta=", StringComparison.OrdinalIgnoreCase))
                        {
                            string[] parts = line.Substring(5).Split('\t');
                            if (parts.Length < 4) continue;
                            string path = DecodeMetadata(parts[0]);
                            if (String.IsNullOrWhiteSpace(path)) continue;
                            metadata[NormalizeWorldPath(path)] = new WorldMetadata { Favorite = parts[1] == "1", Tags = DecodeMetadata(parts[2]), Notes = DecodeMetadata(parts[3]), AutoBackup = parts.Length > 4 && parts[4] == "1", LastBackupFingerprint = parts.Length > 5 ? DecodeMetadata(parts[5]) : "" };
                        }
                    }
                    if (!valid) throw new InvalidDataException("\u914d\u7f6e\u6587\u4ef6\u683c\u5f0f\u65e0\u6548\u3002");
                    SaveRoots();
                    SaveMetadata();
                    RefreshRootList();
                    ApplyMetadataToWorlds();
                    ApplyFilter();
                    statusLabel.Text = "\u914d\u7f6e\u5df2\u5bfc\u5165";
                }
                catch (Exception ex) { MessageBox.Show(this, ex.Message, "\u5bfc\u5165\u5931\u8d25", MessageBoxButtons.OK, MessageBoxIcon.Error); }
            }
        }

        private void RemoveRoot()
        {
            if (rootList.SelectedIndex < 0) return;
            string selected = rootList.SelectedItem as string;
            roots.RemoveAll(delegate(string value) { return String.Equals(value, selected, StringComparison.OrdinalIgnoreCase); });
            SaveRoots();
            RefreshRootList();
            StartScan(false);
        }

        private void SaveRoots()
        {
            try
            {
                Directory.CreateDirectory(settingsDirectory);
                File.WriteAllLines(settingsFile, roots, new UTF8Encoding(false));
            }
            catch { }
        }

        private void LoadMetadata()
        {
            metadata.Clear();
            if (!File.Exists(metadataFile)) return;
            try
            {
                foreach (string line in File.ReadAllLines(metadataFile, Encoding.UTF8))
                {
                    string[] parts = line.Split('\t');
                    if (parts.Length < 4) continue;
                    string path = DecodeMetadata(parts[0]);
                    if (String.IsNullOrWhiteSpace(path)) continue;
                    metadata[NormalizeWorldPath(path)] = new WorldMetadata
                    {
                        Favorite = parts[1] == "1",
                        Tags = DecodeMetadata(parts[2]),
                        Notes = DecodeMetadata(parts[3]),
                        AutoBackup = parts.Length > 4 && parts[4] == "1",
                        LastBackupFingerprint = parts.Length > 5 ? DecodeMetadata(parts[5]) : ""
                    };
                }
            }
            catch { metadata.Clear(); }
        }

        private void SaveMetadata()
        {
            try
            {
                Directory.CreateDirectory(settingsDirectory);
                List<string> lines = new List<string>();
                foreach (KeyValuePair<string, WorldMetadata> pair in metadata.OrderBy(delegate(KeyValuePair<string, WorldMetadata> item) { return item.Key; }))
                {
                    WorldMetadata value = pair.Value;
                    if (!value.Favorite && String.IsNullOrWhiteSpace(value.Tags) && String.IsNullOrWhiteSpace(value.Notes) && !value.AutoBackup && String.IsNullOrWhiteSpace(value.LastBackupFingerprint)) continue;
                    lines.Add(EncodeMetadata(pair.Key) + "\t" + (value.Favorite ? "1" : "0") + "\t" + EncodeMetadata(value.Tags) + "\t" + EncodeMetadata(value.Notes) + "\t" + (value.AutoBackup ? "1" : "0") + "\t" + EncodeMetadata(value.LastBackupFingerprint));
                }
                File.WriteAllLines(metadataFile, lines, new UTF8Encoding(false));
            }
            catch { }
        }

        private void ApplyMetadataToWorlds()
        {
            foreach (WorldInfo world in allWorlds)
            {
                WorldMetadata value;
                if (!metadata.TryGetValue(NormalizeWorldPath(world.Path), out value)) continue;
                world.Favorite = value.Favorite;
                world.Tags = value.Tags;
                world.Notes = value.Notes;
                world.AutoBackup = value.AutoBackup;
                world.BackupCount = backupHistory.Count(delegate(BackupHistoryEntry entry) { return String.Equals(NormalizeWorldPath(entry.WorldPath), NormalizeWorldPath(world.Path), StringComparison.OrdinalIgnoreCase) && File.Exists(entry.ArchivePath); });
            }
        }

        private WorldMetadata MetadataFor(WorldInfo world)
        {
            string key = NormalizeWorldPath(world.Path);
            WorldMetadata value;
            if (!metadata.TryGetValue(key, out value))
            {
                value = new WorldMetadata();
                metadata[key] = value;
            }
            return value;
        }

        private void LoadBackupHistory()
        {
            backupHistory.Clear();
            if (!File.Exists(backupHistoryFile)) return;
            try
            {
                foreach (string line in File.ReadAllLines(backupHistoryFile, Encoding.UTF8))
                {
                    string[] parts = line.Split('\t');
                    if (parts.Length < 3) continue;
                    long ticks;
                    if (!long.TryParse(parts[2], out ticks) || ticks <= 0) continue;
                    backupHistory.Add(new BackupHistoryEntry { WorldPath = DecodeMetadata(parts[0]), ArchivePath = DecodeMetadata(parts[1]), CreatedUtc = new DateTime(ticks, DateTimeKind.Utc) });
                }
            }
            catch { backupHistory.Clear(); }
        }

        private void SaveBackupHistory()
        {
            try
            {
                Directory.CreateDirectory(settingsDirectory);
                File.WriteAllLines(backupHistoryFile, backupHistory.Select(delegate(BackupHistoryEntry entry)
                {
                    return EncodeMetadata(entry.WorldPath) + "\t" + EncodeMetadata(entry.ArchivePath) + "\t" + entry.CreatedUtc.Ticks;
                }).ToList(), new UTF8Encoding(false));
            }
            catch { }
        }

        private void RecordBackup(WorldInfo world, string archivePath)
        {
            backupHistory.Add(new BackupHistoryEntry { WorldPath = world.Path, ArchivePath = archivePath, CreatedUtc = DateTime.UtcNow });
            SaveBackupHistory();
            world.BackupCount++;
        }

        private static string NormalizeWorldPath(string path)
        {
            try { return Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar); }
            catch { return path ?? ""; }
        }

        private static string EncodeMetadata(string value)
        {
            return Convert.ToBase64String(Encoding.UTF8.GetBytes(value ?? ""));
        }

        private static string DecodeMetadata(string value)
        {
            try { return Encoding.UTF8.GetString(Convert.FromBase64String(value ?? "")); }
            catch { return ""; }
        }

        private void RefreshRootList()
        {
            rootList.BeginUpdate();
            rootList.Items.Clear();
            foreach (string root in roots.OrderBy(delegate(string value) { return value; })) rootList.Items.Add(root);
            rootList.EndUpdate();
            rootList.Invalidate();
            UpdateRootScrollBar();
        }

        private async void StartScan(bool discoverAll)
        {
            CancelWorldSizeCalculation();
            bool startSizeCalculation = false;
            UseWaitCursor = true;
            grid.Enabled = false;
            refreshButton.Enabled = false;
            fullScanButton.Enabled = false;
            scanProgress.Visible = discoverAll;
            if (discoverAll) scanProgress.StartAnimation(); else scanProgress.StopAnimation();
            try
            {
                if (discoverAll)
                {
                    statusLabel.Text = "\u6b63\u5728\u5168\u76d8\u641c\u7d22 Minecraft \u6e38\u620f\u76ee\u5f55...";
                    IProgress<DiscoveryProgress> progress = new Progress<DiscoveryProgress>(delegate(DiscoveryProgress update)
                    {
                        if (!IsDisposed) statusLabel.Text = "\u6b63\u5728\u5168\u76d8\u641c\u7d22\uff1a\u5df2\u68c0\u67e5 " + update.DirectoriesChecked.ToString("N0") + " \u4e2a\u6587\u4ef6\u5939\uff0c\u5f53\u524d " + update.CurrentDrive;
                    });
                    List<string> discovered = await Task.Run(delegate { return DiscoverAllRoots(progress); });
                    foreach (string discoveredRoot in discovered) AddRootPath(discoveredRoot, false);
                    SaveRoots();
                    RefreshRootList();
                }
                statusLabel.Text = "\u6b63\u5728\u626b\u63cf " + roots.Count + " \u4e2a\u6e38\u620f\u76ee\u5f55...";
                List<string> snapshot = roots.ToList();
                allWorlds = await Task.Run(delegate { return WorldScanner.Scan(snapshot); });
                ApplyCachedWorldSizes();
                ApplyMetadataToWorlds();
                await RunAutomaticBackups();
                RefreshVersionFilter();
                ApplyFilter();
                startSizeCalculation = true;
            }
            catch (Exception ex)
            {
                statusLabel.Text = "\u626b\u63cf\u5931\u8d25";
                MessageBox.Show(this, ex.Message, "\u626b\u63cf\u5931\u8d25", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                scanProgress.StopAnimation();
                scanProgress.Visible = false;
                grid.Enabled = true;
                refreshButton.Enabled = true;
                fullScanButton.Enabled = true;
                UseWaitCursor = false;
            }
            if (startSizeCalculation && !IsDisposed) StartWorldSizeCalculation();
        }

        private async Task RunAutomaticBackups()
        {
            List<WorldInfo> due = allWorlds.Where(delegate(WorldInfo world)
            {
                return world.AutoBackup && world.Health != "\u4f7f\u7528\u4e2d" && Directory.Exists(world.Path)
                    && !String.Equals(MetadataFor(world).LastBackupFingerprint, world.Fingerprint, StringComparison.Ordinal);
            }).ToList();
            if (due.Count == 0) return;
            statusLabel.Text = "\u6b63\u5728\u6267\u884c\u81ea\u52a8\u5907\u4efd...";
            string folder = Path.Combine(settingsDirectory, "AutomaticBackups");
            List<BackupHistoryEntry> completed = await Task.Run(delegate
            {
                List<BackupHistoryEntry> result = new List<BackupHistoryEntry>();
                try { Directory.CreateDirectory(folder); } catch { return result; }
                foreach (WorldInfo world in due)
                {
                    try
                    {
                        string name = SanitizeFileName(world.Name) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".zip";
                        string destination = UniqueFile(Path.Combine(folder, name));
                        ZipFile.CreateFromDirectory(world.Path, destination, CompressionLevel.Optimal, false);
                        WriteBackupManifest(destination, world);
                        result.Add(new BackupHistoryEntry { WorldPath = world.Path, ArchivePath = destination, CreatedUtc = DateTime.UtcNow });
                    }
                    catch { }
                }
                return result;
            });
            foreach (BackupHistoryEntry entry in completed)
            {
                WorldInfo world = allWorlds.FirstOrDefault(delegate(WorldInfo item) { return String.Equals(NormalizeWorldPath(item.Path), NormalizeWorldPath(entry.WorldPath), StringComparison.OrdinalIgnoreCase); });
                if (world == null) continue;
                backupHistory.Add(entry);
                world.BackupCount++;
                WorldMetadata value = MetadataFor(world);
                value.LastBackupFingerprint = world.Fingerprint;
            }
            if (completed.Count > 0)
            {
                SaveBackupHistory();
                SaveMetadata();
                statusLabel.Text = "\u81ea\u52a8\u5907\u4efd\u5b8c\u6210\uff1a" + completed.Count + " \u4e2a\u5b58\u6863";
            }
        }

        private static List<string> DiscoverAllRoots(IProgress<DiscoveryProgress> progress)
        {
            List<string> starts = new List<string>();
            try
            {
                foreach (DriveInfo drive in DriveInfo.GetDrives())
                {
                    try
                    {
                        if (drive.IsReady && (drive.DriveType == DriveType.Fixed || drive.DriveType == DriveType.Removable)) starts.Add(drive.RootDirectory.FullName);
                    }
                    catch { }
                }
            }
            catch { }

            return DiscoverRootsFrom(starts, progress);
        }

        internal static List<string> DiscoverRootsFrom(IEnumerable<string> starts)
        {
            return DiscoverRootsFrom(starts, null);
        }

        private static List<string> DiscoverRootsFrom(IEnumerable<string> starts, IProgress<DiscoveryProgress> progress)
        {
            List<string> found = new List<string>();
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            Queue<string> pending = new Queue<string>();
            foreach (string start in starts)
            {
                if (!String.IsNullOrWhiteSpace(start)) pending.Enqueue(start);
            }

            long directoriesChecked = 0;
            while (pending.Count > 0)
            {
                string current = pending.Dequeue();
                directoriesChecked++;
                if (progress != null && (directoriesChecked == 1 || directoriesChecked % 200 == 0))
                {
                    string currentDrive = Path.GetPathRoot(current);
                    progress.Report(new DiscoveryProgress { DirectoriesChecked = directoriesChecked, CurrentDrive = String.IsNullOrEmpty(currentDrive) ? current : currentDrive });
                }
                string normalized;
                try
                {
                    normalized = Path.GetFullPath(current);
                    if (!normalized.EndsWith(Path.DirectorySeparatorChar.ToString(), StringComparison.Ordinal)) normalized = normalized.TrimEnd(Path.DirectorySeparatorChar);
                }
                catch { continue; }
                if (!seen.Add(normalized)) continue;

                try
                {
                    DirectoryInfo info = new DirectoryInfo(normalized);
                    if ((info.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    string name = info.Name;
                    if (name.Equals(".minecraft", StringComparison.OrdinalIgnoreCase) || LooksLikeRoot(normalized))
                    {
                        if (!found.Contains(normalized, StringComparer.OrdinalIgnoreCase)) found.Add(normalized);
                        continue;
                    }

                    foreach (string child in Directory.EnumerateDirectories(normalized))
                    {
                        string childName = Path.GetFileName(child);
                        if (IsSystemDirectory(childName)) continue;
                        pending.Enqueue(child);
                    }
                }
                catch (UnauthorizedAccessException) { }
                catch (IOException) { }
                catch (ArgumentException) { }
            }
            return found;
        }

        private static bool IsSystemDirectory(string name)
        {
            if (String.IsNullOrEmpty(name)) return true;
            switch (name.ToLowerInvariant())
            {
                case "$recycle.bin":
                case "system volume information":
                case "windows":
                case "recovery":
                case "msocache":
                case "config.msi":
                    return true;
                default:
                    return false;
            }
        }

        private void ApplyFilter()
        {
            ApplyFilter(false);
        }

        private void ApplyFilter(bool resetViewport)
        {
            WorldInfo selectedWorld = SelectedWorld();
            string selectedPath = selectedWorld == null ? null : selectedWorld.Path;
            string firstVisiblePath = null;
            int previousFirstVisibleIndex = 0;
            int previousHorizontalOffset = grid.HorizontalScrollingOffset;
            if (!resetViewport && grid.Rows.Count > 0)
            {
                try
                {
                    previousFirstVisibleIndex = Math.Max(0, grid.FirstDisplayedScrollingRowIndex);
                    WorldInfo firstVisibleWorld = grid.Rows[previousFirstVisibleIndex].Tag as WorldInfo;
                    firstVisiblePath = firstVisibleWorld == null ? null : firstVisibleWorld.Path;
                }
                catch { }
            }
            string query = searchBox.Text.Trim();
            IEnumerable<WorldInfo> filtered = allWorlds;
            if (query.Length > 0)
            {
                filtered = filtered.Where(delegate(WorldInfo world)
                {
                    return Contains(world.Name, query) || Contains(world.Version, query) || Contains(world.GameMode, query) || Contains(world.Health, query) || Contains(world.Loader, query) || Contains(world.Source, query) || Contains(world.Path, query) || Contains(world.Tags, query) || Contains(world.Notes, query);
                });
            }
            if (versionFilter.SelectedIndex > 0)
            {
                string version = Convert.ToString(versionFilter.SelectedItem);
                filtered = filtered.Where(delegate(WorldInfo world) { return String.Equals(world.Version, version, StringComparison.CurrentCultureIgnoreCase); });
            }
            if (modeFilter.SelectedIndex > 0)
            {
                string mode = Convert.ToString(modeFilter.SelectedItem);
                filtered = filtered.Where(delegate(WorldInfo world) { return String.Equals(world.GameMode, mode, StringComparison.CurrentCultureIgnoreCase); });
            }
            if (favoriteOnly) filtered = filtered.Where(delegate(WorldInfo world) { return world.Favorite; });
            filtered = SortWorlds(filtered);

            grid.SuspendLayout();
            grid.Rows.Clear();
            int selectedRowIndex = -1;
            int firstVisibleRowIndex = -1;
            foreach (WorldInfo world in filtered)
            {
                string displayName = world.Favorite ? "\u2605  " + world.Name : world.Name;
                int index = grid.Rows.Add(world.Icon, displayName, world.Version, world.GameMode, world.Health, world.SizeBytes > 0 ? WorldDetailsDialog.FormatBytes(world.SizeBytes) : "-", world.LastPlayed.ToString("yyyy-MM-dd HH:mm"), world.Loader, world.Path);
                grid.Rows[index].Tag = world;
                string tooltip = (String.IsNullOrEmpty(world.Error) ? "" : world.Error + "\n") + world.Path;
                if (!String.IsNullOrWhiteSpace(world.Tags)) tooltip += "\n\u6807\u7b7e\uff1a" + world.Tags;
                grid.Rows[index].Cells[1].ToolTipText = tooltip;
                if (!String.IsNullOrEmpty(selectedPath) && String.Equals(world.Path, selectedPath, StringComparison.OrdinalIgnoreCase)) selectedRowIndex = index;
                if (!String.IsNullOrEmpty(firstVisiblePath) && String.Equals(world.Path, firstVisiblePath, StringComparison.OrdinalIgnoreCase)) firstVisibleRowIndex = index;
            }
            foreach (DataGridViewColumn column in grid.Columns) column.HeaderCell.SortGlyphDirection = SortOrder.None;
            DataGridViewColumn sortedColumn = grid.Columns[sortColumn];
            if (sortedColumn != null) sortedColumn.HeaderCell.SortGlyphDirection = sortAscending ? SortOrder.Ascending : SortOrder.Descending;
            if (selectedRowIndex >= 0)
            {
                grid.ClearSelection();
                grid.Rows[selectedRowIndex].Selected = true;
                grid.CurrentCell = grid.Rows[selectedRowIndex].Cells["WorldName"];
            }
            grid.ResumeLayout();
            if (grid.Rows.Count > 0)
            {
                int viewportRowIndex = resetViewport ? 0 : (firstVisibleRowIndex >= 0 ? firstVisibleRowIndex : Math.Min(previousFirstVisibleIndex, grid.Rows.Count - 1));
                try { grid.FirstDisplayedScrollingRowIndex = Math.Max(0, viewportRowIndex); }
                catch { }
            }
            try { grid.HorizontalScrollingOffset = Math.Max(0, previousHorizontalOffset); }
            catch { }
            UpdateGridScrollBars();
            int shown = grid.Rows.Count;
            int errors = allWorlds.Count(delegate(WorldInfo world) { return !String.IsNullOrEmpty(world.Error); });
            statusLabel.Text = "\u5171 " + allWorlds.Count + " \u4e2a\u4e16\u754c\uff0c\u5f53\u524d\u663e\u793a " + shown + (errors > 0 ? "\uff0c" + errors + " \u4e2a\u5b58\u6863\u5143\u6570\u636e\u5f02\u5e38" : "");
            summaryLabel.Text = allWorlds.Count + "  \u4e2a\u4e16\u754c   /   " + roots.Count + "  \u4e2a\u76ee\u5f55";
            if (summaryLabel.Parent != null) summaryLabel.Left = summaryLabel.Parent.ClientSize.Width - summaryLabel.Width - 4;
            UpdateDetails();
        }

        private void CancelWorldSizeCalculation()
        {
            worldSizeCalculationGeneration++;
            System.Threading.CancellationTokenSource cancellation = worldSizeCancellation;
            worldSizeCancellation = null;
            if (cancellation != null)
            {
                try { cancellation.Cancel(); }
                catch (ObjectDisposedException) { }
            }
        }

        private void ApplyCachedWorldSizes()
        {
            foreach (WorldInfo world in allWorlds)
            {
                Tuple<string, long> cached;
                if (worldSizeCache.TryGetValue(world.Path, out cached) && cached != null && String.Equals(cached.Item1, world.Fingerprint, StringComparison.Ordinal))
                    world.SizeBytes = cached.Item2;
            }
        }

        private void CacheWorldSize(WorldInfo world)
        {
            if (world == null || String.IsNullOrWhiteSpace(world.Path)) return;
            worldSizeCache[world.Path] = Tuple.Create(world.Fingerprint ?? "", world.SizeBytes);
        }

        private void RefreshWorldSizeRow(WorldInfo world)
        {
            if (world == null || grid.Columns["Size"] == null) return;
            foreach (DataGridViewRow row in grid.Rows)
            {
                WorldInfo rowWorld = row.Tag as WorldInfo;
                if (rowWorld == null || !String.Equals(rowWorld.Path, world.Path, StringComparison.OrdinalIgnoreCase)) continue;
                row.Cells["Size"].Value = world.SizeBytes > 0 ? WorldDetailsDialog.FormatBytes(world.SizeBytes) : "-";
                grid.InvalidateCell(row.Cells["Size"]);
                break;
            }
        }

        private async void StartWorldSizeCalculation()
        {
            CancelWorldSizeCalculation();
            List<WorldInfo> pending = allWorlds.Where(delegate(WorldInfo world) { return world.SizeBytes <= 0 && Directory.Exists(world.Path); }).ToList();
            if (pending.Count == 0) return;

            System.Threading.CancellationTokenSource cancellation = new System.Threading.CancellationTokenSource();
            worldSizeCancellation = cancellation;
            int generation = worldSizeCalculationGeneration;
            int completed = 0;
            statusLabel.Text = "\u6b63\u5728\u540e\u53f0\u8ba1\u7b97\u5b58\u6863\u5927\u5c0f\uff1a0 / " + pending.Count;
            IProgress<Tuple<string, string, long>> progress = new Progress<Tuple<string, string, long>>(delegate(Tuple<string, string, long> update)
            {
                if (generation != worldSizeCalculationGeneration || IsDisposed) return;
                WorldInfo current = allWorlds.FirstOrDefault(delegate(WorldInfo world)
                {
                    return String.Equals(world.Path, update.Item1, StringComparison.OrdinalIgnoreCase) && String.Equals(world.Fingerprint ?? "", update.Item2 ?? "", StringComparison.Ordinal);
                });
                if (current != null)
                {
                    current.SizeBytes = update.Item3;
                    CacheWorldSize(current);
                    RefreshWorldSizeRow(current);
                }
                completed++;
                statusLabel.Text = "\u6b63\u5728\u540e\u53f0\u8ba1\u7b97\u5b58\u6863\u5927\u5c0f\uff1a" + completed + " / " + pending.Count;
            });

            try
            {
                await Task.Run(delegate
                {
                    foreach (WorldInfo world in pending)
                    {
                        cancellation.Token.ThrowIfCancellationRequested();
                        long size = CalculateDirectorySize(world.Path);
                        cancellation.Token.ThrowIfCancellationRequested();
                        progress.Report(Tuple.Create(world.Path, world.Fingerprint ?? "", size));
                    }
                }, cancellation.Token);
                if (generation != worldSizeCalculationGeneration || IsDisposed) return;
                if (String.Equals(sortColumn, "Size", StringComparison.OrdinalIgnoreCase)) ApplyFilter();
                else statusLabel.Text = "\u5b58\u6863\u5927\u5c0f\u8ba1\u7b97\u5b8c\u6210\uff0c\u5171 " + pending.Count + " \u4e2a\u4e16\u754c";
            }
            catch (OperationCanceledException) { }
            finally
            {
                if (Object.ReferenceEquals(worldSizeCancellation, cancellation)) worldSizeCancellation = null;
                cancellation.Dispose();
            }
        }

        private async Task EnsureWorldSizes()
        {
            CancelWorldSizeCalculation();
            List<WorldInfo> pending = allWorlds.Where(delegate(WorldInfo world) { return world.SizeBytes <= 0 && Directory.Exists(world.Path); }).ToList();
            if (pending.Count == 0) return;
            statusLabel.Text = "\u6b63\u5728\u8ba1\u7b97\u5b58\u6863\u5927\u5c0f...";
            Dictionary<string, long> sizes = await Task.Run(delegate
            {
                Dictionary<string, long> result = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
                foreach (WorldInfo world in pending) result[world.Path] = CalculateDirectorySize(world.Path);
                return result;
            });
            foreach (WorldInfo world in pending)
            {
                long value;
                if (sizes.TryGetValue(world.Path, out value))
                {
                    world.SizeBytes = value;
                    CacheWorldSize(world);
                }
            }
        }

        private IEnumerable<WorldInfo> SortWorlds(IEnumerable<WorldInfo> worlds)
        {
            if (sortColumn == "WorldName") return sortAscending ? worlds.OrderBy(delegate(WorldInfo world) { return world.Name; }, StringComparer.CurrentCultureIgnoreCase) : worlds.OrderByDescending(delegate(WorldInfo world) { return world.Name; }, StringComparer.CurrentCultureIgnoreCase);
            if (sortColumn == "Version") return sortAscending ? worlds.OrderBy(delegate(WorldInfo world) { return world.Version; }, StringComparer.CurrentCultureIgnoreCase) : worlds.OrderByDescending(delegate(WorldInfo world) { return world.Version; }, StringComparer.CurrentCultureIgnoreCase);
            if (sortColumn == "Mode") return sortAscending ? worlds.OrderBy(delegate(WorldInfo world) { return world.GameMode; }, StringComparer.CurrentCultureIgnoreCase) : worlds.OrderByDescending(delegate(WorldInfo world) { return world.GameMode; }, StringComparer.CurrentCultureIgnoreCase);
            if (sortColumn == "Health") return sortAscending ? worlds.OrderBy(delegate(WorldInfo world) { return world.Health; }, StringComparer.CurrentCultureIgnoreCase) : worlds.OrderByDescending(delegate(WorldInfo world) { return world.Health; }, StringComparer.CurrentCultureIgnoreCase);
            if (sortColumn == "Size") return sortAscending ? worlds.OrderBy(delegate(WorldInfo world) { return world.SizeBytes; }) : worlds.OrderByDescending(delegate(WorldInfo world) { return world.SizeBytes; });
            if (sortColumn == "Instance") return sortAscending ? worlds.OrderBy(delegate(WorldInfo world) { return world.Loader; }, StringComparer.CurrentCultureIgnoreCase) : worlds.OrderByDescending(delegate(WorldInfo world) { return world.Loader; }, StringComparer.CurrentCultureIgnoreCase);
            if (sortColumn == "Source") return sortAscending ? worlds.OrderBy(delegate(WorldInfo world) { return world.Path; }, StringComparer.CurrentCultureIgnoreCase) : worlds.OrderByDescending(delegate(WorldInfo world) { return world.Path; }, StringComparer.CurrentCultureIgnoreCase);
            return sortAscending ? worlds.OrderBy(delegate(WorldInfo world) { return world.LastPlayed; }) : worlds.OrderByDescending(delegate(WorldInfo world) { return world.LastPlayed; });
        }

        private static bool Contains(string value, string query) { return !String.IsNullOrEmpty(value) && value.IndexOf(query, StringComparison.CurrentCultureIgnoreCase) >= 0; }

        private WorldInfo SelectedWorld()
        {
            return grid.SelectedRows.Count == 0 ? null : grid.SelectedRows[0].Tag as WorldInfo;
        }

        private void UpdateDetails()
        {
            WorldInfo world = SelectedWorld();
            openButton.Enabled = copyButton.Enabled = backupButton.Enabled = backupHistoryButton.Enabled = detailsButton.Enabled = favoriteButton.Enabled = world != null;
            if (world == null)
            {
                detailName.Text = "\u9009\u62e9\u4e00\u4e2a\u4e16\u754c";
                detailPath.Text = "";
                favoriteButton.Text = "\u2606";
                favoriteButton.ForeColor = Ink;
                return;
            }
            detailName.Text = world.Name + "   /   " + world.Version + "   /   " + world.GameMode + "   /   " + world.Health + "   /   " + world.Loader + (String.IsNullOrWhiteSpace(world.Tags) ? "" : "   /   " + world.Tags) + (String.IsNullOrEmpty(world.Error) ? "" : "   [\u5143\u6570\u636e\u5f02\u5e38]");
            detailPath.Text = world.Path;
            favoriteButton.Text = world.Favorite ? "\u2605" : "\u2606";
            favoriteButton.ForeColor = world.Favorite ? Color.FromArgb(235, 145, 20) : Ink;
        }

        private void ToggleSelectedFavorite()
        {
            WorldInfo world = SelectedWorld();
            if (world == null) return;
            world.Favorite = !world.Favorite;
            WorldMetadata value = MetadataFor(world);
            value.Favorite = world.Favorite;
            SaveMetadata();
            statusLabel.Text = world.Favorite ? "\u5df2\u6536\u85cf\uff1a" + world.Name : "\u5df2\u53d6\u6d88\u6536\u85cf\uff1a" + world.Name;
            if (favoriteOnly) ApplyFilter();
            else RefreshFavoriteRow(world);
        }

        private void RefreshFavoriteRow(WorldInfo world)
        {
            if (world == null) return;
            foreach (DataGridViewRow row in grid.Rows)
            {
                WorldInfo rowWorld = row.Tag as WorldInfo;
                if (rowWorld == null || !String.Equals(rowWorld.Path, world.Path, StringComparison.OrdinalIgnoreCase)) continue;
                row.Cells["WorldName"].Value = world.Favorite ? "\u2605  " + world.Name : world.Name;
                grid.InvalidateRow(row.Index);
                break;
            }
            UpdateDetails();
        }

        internal void WorldSizeRowSelfTest()
        {
            WorldInfo world = new WorldInfo
            {
                Name = "Size test",
                Version = "1.21",
                GameMode = "Survival",
                LastPlayed = DateTime.Now,
                Path = Path.Combine(Path.GetTempPath(), "minecraft-world-size-row-test"),
                Fingerprint = "size-fingerprint"
            };
            allWorlds = new List<WorldInfo> { world };
            ApplyFilter();
            if (grid.Rows.Count != 1 || Convert.ToString(grid.Rows[0].Cells["Size"].Value) != "-")
                throw new Exception("An uncalculated world size is not shown as pending.");

            world.SizeBytes = 1536L;
            CacheWorldSize(world);
            RefreshWorldSizeRow(world);
            if (Convert.ToString(grid.Rows[0].Cells["Size"].Value) == "-")
                throw new Exception("A completed background size calculation does not update its row.");

            world.SizeBytes = 0L;
            ApplyCachedWorldSizes();
            if (world.SizeBytes != 1536L) throw new Exception("A matching world-size cache entry is not restored.");
            world.Fingerprint = "changed-fingerprint";
            world.SizeBytes = 0L;
            ApplyCachedWorldSizes();
            if (world.SizeBytes != 0L) throw new Exception("A stale world-size cache entry was reused.");
        }

        internal void FavoriteViewportSelfTest()
        {
            allWorlds = new List<WorldInfo>();
            for (int i = 0; i < 48; i++)
            {
                allWorlds.Add(new WorldInfo
                {
                    Name = "Favorite test " + i,
                    Version = "1.21",
                    GameMode = "Survival",
                    LastPlayed = new DateTime(2026, 1, 1).AddMinutes(i),
                    Source = "Self test",
                    Path = Path.Combine("C:\\favorite-viewport-test", "world-" + i)
                });
            }

            favoriteOnly = false;
            ApplyFilter();
            if (grid.Rows.Count != allWorlds.Count) throw new Exception("Favorite viewport self-test could not populate the world list.");

            grid.ClearSelection();
            grid.Rows[25].Selected = true;
            grid.CurrentCell = grid.Rows[25].Cells["WorldName"];
            grid.FirstDisplayedScrollingRowIndex = 12;
            int expectedFirstIndex = grid.FirstDisplayedScrollingRowIndex;
            int expectedHorizontalOffset = grid.HorizontalScrollingOffset;
            string expectedFirstPath = ((WorldInfo)grid.Rows[expectedFirstIndex].Tag).Path;
            WorldInfo selected = SelectedWorld();
            string expectedSelectedPath = selected.Path;

            selected.Favorite = true;
            RefreshFavoriteRow(selected);
            if (grid.FirstDisplayedScrollingRowIndex != expectedFirstIndex || grid.HorizontalScrollingOffset != expectedHorizontalOffset)
                throw new Exception("Updating a favorite row changes the world-list viewport.");
            if (!Convert.ToString(grid.Rows[25].Cells["WorldName"].Value).StartsWith("\u2605", StringComparison.Ordinal))
                throw new Exception("Favorite row does not update immediately.");

            ApplyFilter();
            WorldInfo restoredFirst = grid.Rows[grid.FirstDisplayedScrollingRowIndex].Tag as WorldInfo;
            WorldInfo restoredSelected = SelectedWorld();
            if (restoredFirst == null || !String.Equals(restoredFirst.Path, expectedFirstPath, StringComparison.OrdinalIgnoreCase))
                throw new Exception("Filtering does not preserve the first visible world.");
            if (restoredSelected == null || !String.Equals(restoredSelected.Path, expectedSelectedPath, StringComparison.OrdinalIgnoreCase))
                throw new Exception("Filtering does not preserve the selected world.");
            if (grid.HorizontalScrollingOffset != expectedHorizontalOffset)
                throw new Exception("Filtering does not preserve horizontal scrolling.");
            grid.FirstDisplayedScrollingRowIndex = 12;
            ApplyFilter(true);
            if (grid.FirstDisplayedScrollingRowIndex != 0)
                throw new Exception("Sorting does not reset the world list to the first row.");
        }

        private async void ShowSelectedWorldDetails()
        {
            WorldInfo world = SelectedWorld();
            if (world == null || !Directory.Exists(world.Path)) return;
            detailsButton.Enabled = false;
            UseWaitCursor = true;
            statusLabel.Text = "\u6b63\u5728\u8ba1\u7b97\u5b58\u6863\u5927\u5c0f...";
            try
            {
                world.SizeBytes = await Task.Run(delegate { return CalculateDirectorySize(world.Path); });
                CacheWorldSize(world);
                RefreshWorldSizeRow(world);
                using (WorldDetailsDialog dialog = new WorldDetailsDialog(world))
                {
                    if (dialog.ShowDialog(this) == DialogResult.OK && dialog.Saved)
                    {
                        world.Tags = dialog.Tags;
                        world.Notes = dialog.Notes;
                        world.AutoBackup = dialog.AutoBackup;
                        WorldMetadata value = MetadataFor(world);
                        value.Favorite = world.Favorite;
                        value.Tags = world.Tags;
                        value.Notes = world.Notes;
                        value.AutoBackup = world.AutoBackup;
                        SaveMetadata();
                        ApplyFilter();
                    }
                }
            }
            catch (Exception ex) { MessageBox.Show(this, ex.Message, "\u65e0\u6cd5\u8bfb\u53d6\u5b58\u6863\u8be6\u60c5", MessageBoxButtons.OK, MessageBoxIcon.Error); }
            finally
            {
                UseWaitCursor = false;
                detailsButton.Enabled = SelectedWorld() != null;
                if (statusLabel.Text == "\u6b63\u5728\u8ba1\u7b97\u5b58\u6863\u5927\u5c0f...") ApplyFilter();
            }
        }

        private async void BackupSelectedWorld()
        {
            WorldInfo world = SelectedWorld();
            if (world == null || !Directory.Exists(world.Path)) return;
            string defaultName = SanitizeFileName(world.Name) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".zip";
            using (SaveFileDialog dialog = new SaveFileDialog())
            {
                dialog.Title = "\u5907\u4efd Minecraft \u4e16\u754c";
                dialog.Filter = "ZIP \u5907\u4efd (*.zip)|*.zip";
                dialog.FileName = defaultName;
                dialog.AddExtension = true;
                dialog.OverwritePrompt = true;
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                string destination = dialog.FileName;
                string worldPath = NormalizeWorldPath(world.Path) + Path.DirectorySeparatorChar;
                if (NormalizeWorldPath(destination).StartsWith(worldPath, StringComparison.OrdinalIgnoreCase))
                {
                    MessageBox.Show(this, "\u5907\u4efd\u6587\u4ef6\u4e0d\u80fd\u4fdd\u5b58\u5728\u5b58\u6863\u76ee\u5f55\u5185\u3002", "\u65e0\u6cd5\u5907\u4efd", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }
                backupButton.Enabled = false;
                UseWaitCursor = true;
                scanProgress.Visible = true;
                scanProgress.StartAnimation();
                statusLabel.Text = "\u6b63\u5728\u5907\u4efd\uff1a" + world.Name;
                try
                {
                    await Task.Run(delegate
                    {
                        if (File.Exists(destination)) File.Delete(destination);
                        ZipFile.CreateFromDirectory(world.Path, destination, CompressionLevel.Optimal, false);
                        WriteBackupManifest(destination, world);
                    });
                    RecordBackup(world, destination);
                    WorldMetadata backupMetadata = MetadataFor(world);
                    backupMetadata.LastBackupFingerprint = world.Fingerprint;
                    SaveMetadata();
                    statusLabel.Text = "\u5907\u4efd\u5b8c\u6210\uff1a" + destination;
                }
                catch (Exception ex)
                {
                    try { if (File.Exists(destination)) File.Delete(destination); } catch { }
                    MessageBox.Show(this, ex.Message, "\u5907\u4efd\u5931\u8d25", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    statusLabel.Text = "\u5907\u4efd\u5931\u8d25";
                }
                finally
                {
                    scanProgress.StopAnimation();
                    scanProgress.Visible = false;
                    UseWaitCursor = false;
                    backupButton.Enabled = SelectedWorld() != null;
                }
            }
        }

        private async void RestoreBackup()
        {
            string archivePath;
            using (OpenFileDialog archive = new OpenFileDialog())
            {
                archive.Title = "\u9009\u62e9 Minecraft \u4e16\u754c ZIP \u5907\u4efd";
                archive.Filter = "ZIP \u5907\u4efd (*.zip)|*.zip";
                archive.CheckFileExists = true;
                if (archive.ShowDialog(this) != DialogResult.OK) return;
                archivePath = archive.FileName;
            }
            BackupManifest manifest;
            try { manifest = ReadBackupManifest(archivePath); }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "\u65e0\u6cd5\u8bfb\u53d6\u5907\u4efd\u4fe1\u606f", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            string destination = null;
            string selectedRoot = null;
            bool overwrite = false;
            if (manifest != null && IsSafeOriginalWorldPath(manifest.OriginalPath))
            {
                string original = NormalizeWorldPath(manifest.OriginalPath);
                if (Directory.Exists(original))
                {
                    DialogResult choice = MessageBox.Show(this,
                        "\u5907\u4efd\u8bb0\u5f55\u7684\u539f\u5b58\u6863\u4f4d\u7f6e\uff1a\n" + original +
                        "\n\n\u8be5\u4f4d\u7f6e\u4ecd\u6709\u5b58\u6863\u3002\n\n\u662f\uff1a\u8986\u76d6\u539f\u5b58\u6863\n\u5426\uff1a\u4fdd\u7559\u539f\u5b58\u6863\uff0c\u65b0\u589e\u4e00\u4e2a\u526f\u672c\n\u53d6\u6d88\uff1a\u505c\u6b62\u6062\u590d",
                        "\u9009\u62e9\u6062\u590d\u65b9\u5f0f", MessageBoxButtons.YesNoCancel, MessageBoxIcon.Warning);
                    if (choice == DialogResult.Cancel) return;
                    overwrite = choice == DialogResult.Yes;
                    destination = overwrite ? original : UniqueDirectory(original);
                }
                else if (!File.Exists(original))
                {
                    DialogResult choice = MessageBox.Show(this,
                        "\u5907\u4efd\u8bb0\u5f55\u7684\u539f\u5b58\u6863\u4f4d\u7f6e\uff1a\n" + original +
                        "\n\n\u662f\u5426\u6062\u590d\u5230\u8fd9\u4e2a\u4f4d\u7f6e\uff1f\n\n\u9009\u62e9\u201c\u5426\u201d\u53ef\u6539\u4e3a\u5176\u4ed6 .minecraft \u76ee\u5f55\u3002",
                        "\u6062\u590d\u5230\u539f\u4f4d\u7f6e", MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question);
                    if (choice == DialogResult.Cancel) return;
                    if (choice == DialogResult.Yes) destination = original;
                }
                if (destination != null) selectedRoot = ResolveManifestRoot(manifest, destination);
            }
            if (destination == null)
            {
                using (FolderBrowserDialog target = new FolderBrowserDialog())
                {
                    target.Description = "\u9009\u62e9\u8981\u6062\u590d\u5230\u7684 .minecraft \u76ee\u5f55";
                    target.ShowNewFolderButton = false;
                    if (roots.Count > 0 && Directory.Exists(roots[0])) target.SelectedPath = roots[0];
                    if (target.ShowDialog(this) != DialogResult.OK) return;
                    selectedRoot = ResolveMinecraftRoot(target.SelectedPath);
                }
                string saves = Path.Combine(selectedRoot, "saves");
                Directory.CreateDirectory(saves);
                string baseName = manifest != null && !String.IsNullOrWhiteSpace(manifest.WorldName) ? manifest.WorldName : Regex.Replace(Path.GetFileNameWithoutExtension(archivePath), @"-\d{8}-\d{6}$", "");
                destination = UniqueDirectory(Path.Combine(saves, SanitizeFileName(baseName)));
            }
            string staging = UniqueDirectory(destination + ".restore-temp");
            restoreButton.Enabled = false;
            UseWaitCursor = true;
            scanProgress.Visible = true;
            scanProgress.StartAnimation();
            statusLabel.Text = "\u6b63\u5728\u6062\u590d\u5907\u4efd...";
            try
            {
                await Task.Run(delegate
                {
                    ExtractWorldArchive(archivePath, staging);
                    if (!File.Exists(Path.Combine(staging, "level.dat")) && !Directory.Exists(Path.Combine(staging, "region"))) throw new InvalidDataException("ZIP \u4e2d\u6ca1\u6709\u627e\u5230\u6709\u6548\u7684 Minecraft \u4e16\u754c\u3002");
                    CommitRestoredWorld(staging, destination, overwrite);
                });
                AddRootPath(selectedRoot, false);
                SaveRoots();
                RefreshRootList();
                statusLabel.Text = "\u6062\u590d\u5b8c\u6210\uff1a" + destination;
                StartScan(false);
            }
            catch (Exception ex)
            {
                try { if (Directory.Exists(staging)) Directory.Delete(staging, true); } catch { }
                MessageBox.Show(this, ex.Message, "\u6062\u590d\u5931\u8d25", MessageBoxButtons.OK, MessageBoxIcon.Error);
                statusLabel.Text = "\u6062\u590d\u5931\u8d25";
            }
            finally
            {
                scanProgress.StopAnimation();
                scanProgress.Visible = false;
                UseWaitCursor = false;
                restoreButton.Enabled = true;
            }
        }

        private void OpenSelectedWorld()
        {
            WorldInfo world = SelectedWorld();
            if (world == null || !Directory.Exists(world.Path)) return;
            try { Process.Start(new ProcessStartInfo("explorer.exe", "\"" + world.Path + "\"") { UseShellExecute = true }); }
            catch (Exception ex) { MessageBox.Show(this, ex.Message, "\u65e0\u6cd5\u6253\u5f00\u6587\u4ef6\u5939", MessageBoxButtons.OK, MessageBoxIcon.Error); }
        }

        private void ShowBackupHistory()
        {
            WorldInfo world = SelectedWorld();
            if (world == null) return;
            List<BackupHistoryEntry> entries = backupHistory.Where(delegate(BackupHistoryEntry entry)
            {
                return String.Equals(NormalizeWorldPath(entry.WorldPath), NormalizeWorldPath(world.Path), StringComparison.OrdinalIgnoreCase);
            }).OrderByDescending(delegate(BackupHistoryEntry entry) { return entry.CreatedUtc; }).ToList();
            if (entries.Count == 0)
            {
                MessageBox.Show(this, "\u8fd8\u6ca1\u6709\u8fd9\u4e2a\u5b58\u6863\u7684\u5907\u4efd\u8bb0\u5f55\u3002", "\u5907\u4efd\u5386\u53f2", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            StringBuilder text = new StringBuilder("\u5907\u4efd\u5386\u53f2\uff1a\n\n");
            foreach (BackupHistoryEntry entry in entries.Take(20)) text.AppendLine(entry.CreatedUtc.ToLocalTime().ToString("yyyy-MM-dd HH:mm") + "   " + entry.ArchivePath);
            MessageBox.Show(this, text.ToString(), "\u5907\u4efd\u5386\u53f2", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        private void CopySelectedPath()
        {
            WorldInfo world = SelectedWorld();
            if (world == null) return;
            try { Clipboard.SetText(world.Path); statusLabel.Text = "\u5df2\u590d\u5236\u5b58\u6863\u8def\u5f84"; }
            catch { }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) CancelWorldSizeCalculation();
            base.Dispose(disposing);
        }

        internal static long CalculateDirectorySize(string root)
        {
            long total = 0;
            Stack<string> pending = new Stack<string>();
            pending.Push(root);
            while (pending.Count > 0)
            {
                string current = pending.Pop();
                try
                {
                    foreach (string file in Directory.EnumerateFiles(current))
                    {
                        try { total += new FileInfo(file).Length; } catch { }
                    }
                    foreach (string child in Directory.EnumerateDirectories(current))
                    {
                        try
                        {
                            DirectoryInfo info = new DirectoryInfo(child);
                            if ((info.Attributes & FileAttributes.ReparsePoint) == 0) pending.Push(child);
                        }
                        catch { }
                    }
                }
                catch { }
            }
            return total;
        }

        private static string SanitizeFileName(string value)
        {
            string result = value ?? "";
            foreach (char invalid in Path.GetInvalidFileNameChars()) result = result.Replace(invalid, '_');
            result = result.Trim().TrimEnd('.');
            return String.IsNullOrWhiteSpace(result) ? "Minecraft World" : result;
        }

        private static string ResolveMinecraftRoot(string selected)
        {
            string full = Path.GetFullPath(selected);
            string nested = Path.Combine(full, ".minecraft");
            if (Directory.Exists(nested) && LooksLikeRoot(nested)) return nested;
            return full;
        }

        private static string UniqueDirectory(string desired)
        {
            if (!Directory.Exists(desired) && !File.Exists(desired)) return desired;
            for (int i = 2; i < 10000; i++)
            {
                string candidate = desired + " (" + i + ")";
                if (!Directory.Exists(candidate) && !File.Exists(candidate)) return candidate;
            }
            return desired + "-" + Guid.NewGuid().ToString("N");
        }

        private static string UniqueFile(string desired)
        {
            if (!File.Exists(desired) && !Directory.Exists(desired)) return desired;
            string directory = Path.GetDirectoryName(desired);
            string name = Path.GetFileNameWithoutExtension(desired);
            string extension = Path.GetExtension(desired);
            for (int i = 2; i < 10000; i++)
            {
                string candidate = Path.Combine(directory, name + " (" + i + ")" + extension);
                if (!File.Exists(candidate) && !Directory.Exists(candidate)) return candidate;
            }
            return Path.Combine(directory, name + "-" + Guid.NewGuid().ToString("N") + extension);
        }

        internal static void WriteBackupManifest(string archivePath, WorldInfo world)
        {
            using (ZipArchive archive = ZipFile.Open(archivePath, ZipArchiveMode.Update))
            {
                ZipArchiveEntry existing = archive.Entries.FirstOrDefault(delegate(ZipArchiveEntry entry) { return entry.FullName.Equals(BackupManifestEntry, StringComparison.OrdinalIgnoreCase); });
                if (existing != null) existing.Delete();
                ZipArchiveEntry manifestEntry = archive.CreateEntry(BackupManifestEntry, CompressionLevel.Optimal);
                using (Stream stream = manifestEntry.Open())
                using (StreamWriter writer = new StreamWriter(stream, new UTF8Encoding(false)))
                {
                    writer.WriteLine("PCL2WorldBrowserBackup=1");
                    writer.WriteLine("OriginalPath=" + EncodeMetadata(world.Path));
                    writer.WriteLine("RootPath=" + EncodeMetadata(world.RootPath));
                    writer.WriteLine("WorldName=" + EncodeMetadata(world.Name));
                    writer.WriteLine("Source=" + EncodeMetadata(world.Source));
                    writer.WriteLine("CreatedUtcTicks=" + DateTime.UtcNow.Ticks);
                }
            }
        }

        internal static BackupManifest ReadBackupManifest(string archivePath)
        {
            using (ZipArchive archive = ZipFile.OpenRead(archivePath))
            {
                ZipArchiveEntry entry = archive.Entries.FirstOrDefault(delegate(ZipArchiveEntry item) { return item.FullName.Equals(BackupManifestEntry, StringComparison.OrdinalIgnoreCase); });
                if (entry == null) return null;
                Dictionary<string, string> values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                using (Stream stream = entry.Open())
                using (StreamReader reader = new StreamReader(stream, Encoding.UTF8, true))
                {
                    string line;
                    while ((line = reader.ReadLine()) != null)
                    {
                        int separator = line.IndexOf('=');
                        if (separator <= 0) continue;
                        values[line.Substring(0, separator)] = line.Substring(separator + 1);
                    }
                }
                string signature;
                if (!values.TryGetValue("PCL2WorldBrowserBackup", out signature) || signature != "1") return null;
                string original;
                string root;
                string name;
                string source;
                string ticksText;
                values.TryGetValue("OriginalPath", out original);
                values.TryGetValue("RootPath", out root);
                values.TryGetValue("WorldName", out name);
                values.TryGetValue("Source", out source);
                values.TryGetValue("CreatedUtcTicks", out ticksText);
                long ticks;
                DateTime created = long.TryParse(ticksText, out ticks) && ticks > 0 ? new DateTime(ticks, DateTimeKind.Utc) : DateTime.MinValue;
                return new BackupManifest { OriginalPath = DecodeMetadata(original), RootPath = DecodeMetadata(root), WorldName = DecodeMetadata(name), Source = DecodeMetadata(source), CreatedUtc = created };
            }
        }

        internal static bool IsSafeOriginalWorldPath(string path)
        {
            if (String.IsNullOrWhiteSpace(path) || !Path.IsPathRooted(path)) return false;
            try
            {
                string full = NormalizeWorldPath(path);
                DirectoryInfo parent = Directory.GetParent(full);
                return parent != null && parent.Name.Equals("saves", StringComparison.OrdinalIgnoreCase) && !String.Equals(full, Path.GetPathRoot(full), StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        private static string ResolveManifestRoot(BackupManifest manifest, string destination)
        {
            if (manifest != null && !String.IsNullOrWhiteSpace(manifest.RootPath))
            {
                try
                {
                    string root = Path.GetFullPath(manifest.RootPath);
                    if (Directory.Exists(root)) return root;
                }
                catch { }
            }
            try
            {
                DirectoryInfo saves = Directory.GetParent(destination);
                return saves != null && saves.Parent != null ? saves.Parent.FullName : Path.GetDirectoryName(destination);
            }
            catch { return Path.GetDirectoryName(destination); }
        }

        internal static void CommitRestoredWorld(string staging, string destination, bool overwrite)
        {
            string parent = Path.GetDirectoryName(destination);
            if (String.IsNullOrWhiteSpace(parent)) throw new InvalidDataException("\u6062\u590d\u76ee\u6807\u8def\u5f84\u65e0\u6548\u3002");
            Directory.CreateDirectory(parent);
            if (!overwrite)
            {
                if (Directory.Exists(destination) || File.Exists(destination)) throw new IOException("\u6062\u590d\u76ee\u6807\u5df2\u5b58\u5728\u3002");
                Directory.Move(staging, destination);
                return;
            }
            if (File.Exists(destination)) throw new IOException("\u539f\u5b58\u6863\u4f4d\u7f6e\u88ab\u540c\u540d\u6587\u4ef6\u5360\u7528\uff0c\u65e0\u6cd5\u8986\u76d6\u3002");
            if (!Directory.Exists(destination))
            {
                Directory.Move(staging, destination);
                return;
            }
            string previous = UniqueDirectory(destination + ".before-restore");
            Directory.Move(destination, previous);
            try
            {
                Directory.Move(staging, destination);
            }
            catch
            {
                try { if (!Directory.Exists(destination) && Directory.Exists(previous)) Directory.Move(previous, destination); } catch { }
                throw;
            }
            try { Directory.Delete(previous, true); } catch { }
        }

        internal static void ExtractWorldArchive(string archivePath, string destination)
        {
            using (ZipArchive archive = ZipFile.OpenRead(archivePath))
            {
                ZipArchiveEntry level = archive.Entries.Where(delegate(ZipArchiveEntry entry)
                {
                    string name = entry.FullName.Replace('\\', '/');
                    return name.Equals("level.dat", StringComparison.OrdinalIgnoreCase) || name.EndsWith("/level.dat", StringComparison.OrdinalIgnoreCase);
                }).OrderBy(delegate(ZipArchiveEntry entry) { return entry.FullName.Length; }).FirstOrDefault();
                if (level == null) throw new InvalidDataException("ZIP \u4e2d\u6ca1\u6709 level.dat\uff0c\u4e0d\u662f\u6709\u6548\u7684 Minecraft \u4e16\u754c\u5907\u4efd\u3002");
                string levelName = level.FullName.Replace('\\', '/');
                string prefix = levelName.Substring(0, levelName.Length - "level.dat".Length);
                string destinationFull = Path.GetFullPath(destination).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
                Directory.CreateDirectory(destinationFull);
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    string archiveName = entry.FullName.Replace('\\', '/');
                    if (!archiveName.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) continue;
                    string relative = archiveName.Substring(prefix.Length).TrimStart('/');
                    if (relative.Length == 0) continue;
                    if (relative.Equals(BackupManifestEntry, StringComparison.OrdinalIgnoreCase)) continue;
                    string target = Path.GetFullPath(Path.Combine(destinationFull, relative.Replace('/', Path.DirectorySeparatorChar)));
                    if (!target.StartsWith(destinationFull, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("ZIP \u5305\u542b\u4e0d\u5b89\u5168\u7684\u8def\u5f84\uff0c\u5df2\u505c\u6b62\u6062\u590d\u3002");
                    if (archiveName.EndsWith("/", StringComparison.Ordinal))
                    {
                        Directory.CreateDirectory(target);
                        continue;
                    }
                    string parent = Path.GetDirectoryName(target);
                    if (!String.IsNullOrEmpty(parent)) Directory.CreateDirectory(parent);
                    using (Stream source = entry.Open())
                    using (FileStream output = File.Create(target)) source.CopyTo(output);
                }
            }
        }
    }

    public static class Program
    {
        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        [STAThread]
        public static int Main(string[] args)
        {
            try
            {
                try { SetProcessDPIAware(); } catch { }
                string appDirectory = AppDomain.CurrentDomain.BaseDirectory;
                string themePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PCL2WorldBrowser", "theme.txt");
                AppTheme.Load(themePath);
                string renderArgument = args == null ? null : args.FirstOrDefault(delegate(string arg) { return arg.StartsWith("--render-preview=", StringComparison.OrdinalIgnoreCase); });
                if (!String.IsNullOrEmpty(renderArgument))
                {
                    string outputPath = renderArgument.Substring("--render-preview=".Length).Trim('"');
                    bool darkPreview = args.Any(delegate(string arg) { return String.Equals(arg, "--dark", StringComparison.OrdinalIgnoreCase); });
                    RenderPreview(appDirectory, outputPath, darkPreview);
                    return 0;
                }
                if (args != null && args.Any(delegate(string arg) { return String.Equals(arg, "--details-preview", StringComparison.OrdinalIgnoreCase); }))
                {
                    Application.EnableVisualStyles();
                    Application.SetCompatibleTextRenderingDefault(false);
                    Bitmap previewIcon = new Bitmap(56, 56);
                    using (Graphics graphics = Graphics.FromImage(previewIcon)) graphics.Clear(Color.FromArgb(76, 145, 84));
                    WorldInfo preview = new WorldInfo { Icon = previewIcon, Name = "Codex Test World", Version = "1.21.1", GameMode = "\u751f\u5b58", Difficulty = "\u56f0\u96be", Cheats = false, Seed = 1234567890123456789L, DataVersion = 3953, LastPlayed = DateTime.Now, SizeBytes = 734003200L, Source = "1.21.1-Fabric 0.16.9", Favorite = true, Tags = "\u4e3b\u5b58\u6863, \u751f\u5b58", Notes = "\u8fd9\u662f\u4e00\u4e2a\u7528\u4e8e\u68c0\u67e5\u6392\u7248\u7684\u8be6\u60c5\u9884\u89c8\u3002" };
                    using (WorldDetailsDialog previewDialog = new WorldDetailsDialog(preview))
                    {
                        previewDialog.ShowInTaskbar = true;
                        previewDialog.StartPosition = FormStartPosition.CenterScreen;
                        Application.Run(previewDialog);
                    }
                    previewIcon.Dispose();
                    return 0;
                }
                if (args != null && args.Any(delegate(string arg) { return String.Equals(arg, "--smoke-test", StringComparison.OrdinalIgnoreCase); }))
                {
                    LayoutSelfTest(appDirectory);
                    return 0;
                }
                Run(appDirectory);
                return 0;
            }
            catch (Exception ex)
            {
                try
                {
                    if (args != null && args.Any(delegate(string arg) { return String.Equals(arg, "--smoke-test", StringComparison.OrdinalIgnoreCase); }))
                        File.WriteAllText(Path.Combine(Path.GetTempPath(), "MinecraftWorldBrowser-smoke-error.txt"), ex.ToString(), Encoding.UTF8);
                }
                catch { }
                return 1;
            }
        }

        [STAThread]
        public static void Run(string appDirectory)
        {
            string themePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PCL2WorldBrowser", "theme.txt");
            AppTheme.Load(themePath);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm(appDirectory));
        }

        public static void RenderPreview(string appDirectory, string outputPath, bool dark)
        {
            if (String.IsNullOrWhiteSpace(outputPath)) throw new ArgumentException("A preview output path is required.");
            AppTheme.SetDark(dark);
            GlassBackdropRenderer.Invalidate();
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            using (MainForm form = new MainForm(appDirectory, true))
            {
                form.ClientSize = new Size(1280, 780);
                form.StartPosition = FormStartPosition.Manual;
                form.Location = new Point(-32000, -32000);
                form.ShowInTaskbar = false;
                form.Show();
                Application.DoEvents();
                CreateControlTree(form);
                form.PerformLayout();
                form.PrepareVisualPreview();
                form.PerformLayout();
                Application.DoEvents();
                using (Bitmap bitmap = new Bitmap(form.ClientSize.Width, form.ClientSize.Height, PixelFormat.Format32bppPArgb))
                {
                    form.DrawToBitmap(bitmap, form.ClientRectangle);
                    Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outputPath)));
                    bitmap.Save(outputPath, ImageFormat.Png);
                }
            }
        }

        private static void CreateControlTree(Control parent)
        {
            parent.CreateControl();
            foreach (Control child in parent.Controls) CreateControlTree(child);
        }

        public static string SelfTest(string testRoot)
        {
            string themeFixture = Path.Combine(testRoot, "theme.txt");
            AppTheme.SetDark(true);
            AppTheme.Save(themeFixture);
            AppTheme.SetDark(false);
            AppTheme.Load(themeFixture);
            if (!AppTheme.Dark) throw new Exception("Dark theme preference was not persisted.");
            AppTheme.SetDark(false);
            if (WorldScanner.VersionNameFromDataVersion(3700) != "1.20.3 - 1.20.4" || WorldScanner.VersionNameFromDataVersion(1343) != "1.12 - 1.12.2") throw new Exception("DataVersion mapping self-test failed.");
            List<string> discoveredRoots = MainForm.DiscoverRootsFrom(new string[] { testRoot });
            if (discoveredRoots.Count != 1 || !String.Equals(discoveredRoots[0], testRoot, StringComparison.OrdinalIgnoreCase)) throw new Exception("Automatic root discovery did not find the fixture.");
            List<WorldInfo> worlds = WorldScanner.Scan(new string[] { testRoot });
            if (worlds.Count != 1) throw new Exception("Expected one world, found " + worlds.Count);
            WorldInfo world = worlds[0];
            if (world.Name != "Codex Test World" || world.Version != "1.20.4" || world.GameMode != "\u521b\u9020" || world.Difficulty != "\u666e\u901a" || !world.Cheats || world.Seed != 123456789L || world.DataVersion != 3700) throw new Exception("Parsed values did not match fixture.");
            if (String.Equals(world.InstancePath, world.Path, StringComparison.OrdinalIgnoreCase) || !String.Equals(world.InstancePath, Path.GetDirectoryName(Path.GetDirectoryName(world.Path)), StringComparison.OrdinalIgnoreCase))
                throw new Exception("World and instance folders are not kept separate.");
            if (MainForm.CalculateDirectorySize(world.Path) <= 0) throw new Exception("World size calculation failed.");
            WorldScanner.Scan(new string[] { testRoot });
            if (WorldScanner.LastCacheHits < 1) throw new Exception("Unchanged world was not reused from the incremental scan cache.");
            string launcherFixture = Path.Combine(testRoot, "launcher-compat");
            string prismRoot = Path.Combine(launcherFixture, "PrismLauncher", "instances", "Prism Profile", ".minecraft");
            string curseRoot = Path.Combine(launcherFixture, "CurseForge", "minecraft", "Instances", "Curse Profile");
            string modrinthRoot = Path.Combine(launcherFixture, "Modrinth", "profiles", "Modrinth Profile");
            foreach (string gameRoot in new string[] { prismRoot, curseRoot, modrinthRoot })
            {
                string saves = Path.Combine(gameRoot, "saves", "Compatibility World");
                Directory.CreateDirectory(saves);
                File.WriteAllText(Path.Combine(saves, "level.dat"), "fixture");
            }
            List<string> launcherRoots = MainForm.DiscoverGameRoots(launcherFixture, 4);
            if (launcherRoots.Count != 3 || !launcherRoots.Contains(prismRoot, StringComparer.OrdinalIgnoreCase) || !launcherRoots.Contains(curseRoot, StringComparer.OrdinalIgnoreCase) || !launcherRoots.Contains(modrinthRoot, StringComparer.OrdinalIgnoreCase))
                throw new Exception("Popular launcher instance roots were not discovered.");
            if (WorldScanner.Scan(launcherRoots).Count != 3) throw new Exception("Popular launcher instance saves were not scanned.");
            string archivePath = Path.Combine(testRoot, "backup-test.zip");
            string restoredPath = Path.Combine(testRoot, "restored-test");
            ZipFile.CreateFromDirectory(world.Path, archivePath, CompressionLevel.Fastest, false);
            MainForm.WriteBackupManifest(archivePath, world);
            BackupManifest manifest = MainForm.ReadBackupManifest(archivePath);
            if (manifest == null || !String.Equals(manifest.OriginalPath, world.Path, StringComparison.OrdinalIgnoreCase) || manifest.WorldName != world.Name || manifest.CreatedUtc == DateTime.MinValue) throw new Exception("Backup location manifest self-test failed.");
            if (!MainForm.IsSafeOriginalWorldPath(manifest.OriginalPath) || MainForm.IsSafeOriginalWorldPath(Path.Combine(testRoot, "not-saves", "world"))) throw new Exception("Original backup path validation failed.");
            MainForm.ExtractWorldArchive(archivePath, restoredPath);
            if (!File.Exists(Path.Combine(restoredPath, "level.dat")) || File.Exists(Path.Combine(restoredPath, ".pcl2-world-browser-backup.txt"))) throw new Exception("Backup restoration self-test failed.");
            string overwriteTarget = Path.Combine(testRoot, "overwrite-target");
            string overwriteStaging = Path.Combine(testRoot, "overwrite-staging");
            Directory.CreateDirectory(overwriteTarget);
            Directory.CreateDirectory(overwriteStaging);
            File.WriteAllText(Path.Combine(overwriteTarget, "old.txt"), "old");
            File.WriteAllText(Path.Combine(overwriteStaging, "level.dat"), "new");
            MainForm.CommitRestoredWorld(overwriteStaging, overwriteTarget, true);
            if (File.Exists(Path.Combine(overwriteTarget, "old.txt")) || !File.Exists(Path.Combine(overwriteTarget, "level.dat"))) throw new Exception("Atomic overwrite restoration self-test failed.");
            string addedTarget = Path.Combine(testRoot, "added-target");
            string addedStaging = Path.Combine(testRoot, "added-staging");
            Directory.CreateDirectory(addedStaging);
            File.WriteAllText(Path.Combine(addedStaging, "level.dat"), "new");
            MainForm.CommitRestoredWorld(addedStaging, addedTarget, false);
            if (!File.Exists(Path.Combine(addedTarget, "level.dat"))) throw new Exception("Add-as-new restoration self-test failed.");
            string unsafeArchive = Path.Combine(testRoot, "unsafe-test.zip");
            using (ZipArchive unsafeZip = ZipFile.Open(unsafeArchive, ZipArchiveMode.Create))
            {
                unsafeZip.CreateEntry("level.dat");
                unsafeZip.CreateEntry("../escape.txt");
            }
            bool rejected = false;
            try { MainForm.ExtractWorldArchive(unsafeArchive, Path.Combine(testRoot, "unsafe-output")); }
            catch (InvalidDataException) { rejected = true; }
            if (!rejected) throw new Exception("Unsafe ZIP path was not rejected.");
            return world.Name + "|" + world.Version + "|" + world.GameMode;
        }

        public static string LayoutSelfTest(string appDirectory)
        {
            using (MainForm form = new MainForm(appDirectory))
            {
                form.Size = new Size(1000, 720);
                form.CreateControl();
                form.PerformLayout();
                Control sidebar = form.Controls["Sidebar"];
                Control main = form.Controls["Main"];
                if (sidebar == null || main == null || sidebar.Width != 296 || main.Left < sidebar.Right)
                    throw new Exception("Main window layout overlaps the sidebar.");
                Control[] progressControls = form.Controls.Find("ScanProgress", true);
                if (progressControls.Length != 1 || progressControls[0].Width < 100)
                    throw new Exception("Scan progress bar is missing from the main window.");
                if (form.Controls.Find("RefreshButton", true).Length != 1 || form.Controls.Find("FullScanButton", true).Length != 1)
                    throw new Exception("Refresh or full scan command is missing.");
                if (form.Controls.Find("ThemeToggleButton", true).Length != 1)
                    throw new Exception("Theme toggle is missing from the main header.");
                Control themeToggle = form.Controls.Find("ThemeToggleButton", true)[0];
                Control summary = form.Controls.Find("SummaryLabel", true)[0];
                themeToggle.Parent.PerformLayout();
                if (summary.Right >= themeToggle.Left)
                    throw new Exception("Theme toggle overlaps the world summary.");
                Control toolbar = form.Controls.Find("CommandToolbar", true)[0];
                Control refresh = form.Controls.Find("RefreshButton", true)[0];
                Control fullScan = form.Controls.Find("FullScanButton", true)[0];
                Control search = form.Controls.Find("SearchSurface", true)[0];
                Control searchInput = form.Controls.Find("SearchBox", true)[0];
                toolbar.PerformLayout();
                if (refresh.Left <= search.Right || fullScan.Right > toolbar.ClientSize.Width || refresh.Right >= fullScan.Left)
                    throw new Exception("Toolbar commands overlap or leave the visible area at minimum width.");
                if (searchInput.Parent != search || searchInput.Top < 6 || searchInput.Bottom > search.ClientSize.Height - 6 || search.Cursor != Cursors.IBeam)
                    throw new Exception("Search input and its visual hit area are not aligned.");
                RoundedPanel searchPanel = search as RoundedPanel;
                if (searchPanel == null || searchPanel.DrawSheen || searchPanel.SheenHeight != 0 || searchInput.BackColor != searchPanel.MaterialColor)
                    throw new Exception("Search input does not share the uniform neumorphic surface.");
                using (Bitmap searchBitmap = new Bitmap(search.Width, search.Height, PixelFormat.Format32bppPArgb))
                {
                    search.DrawToBitmap(searchBitmap, search.ClientRectangle);
                    int sampleX = Math.Max(searchInput.Left + 8, searchInput.Right - 16);
                    int inputY = searchInput.Top + 2;
                    int surfaceY = searchInput.Top - 1;
                    Color inputPixel = searchBitmap.GetPixel(sampleX, inputY);
                    Color surfacePixel = searchBitmap.GetPixel(sampleX, surfaceY);
                    int difference = Math.Abs(inputPixel.R - surfacePixel.R) + Math.Abs(inputPixel.G - surfacePixel.G) + Math.Abs(inputPixel.B - surfacePixel.B);
                    if (difference > 3)
                        throw new Exception("Search input background has a visible rectangular edge: " + inputPixel + " / " + surfacePixel + ", difference=" + difference);
                    Color upperShadowPixel = searchBitmap.GetPixel(search.Width / 2, 1);
                    Color interiorPixel = searchBitmap.GetPixel(search.Width / 2, searchInput.Bottom + 1);
                    if (upperShadowPixel.ToArgb() == interiorPixel.ToArgb())
                        throw new Exception("Search surface lost its raised neumorphic edge.");
                }
                if (form.Controls.Find("VersionFilter", true).Length != 1 || form.Controls.Find("ModeFilter", true).Length != 1 || form.Controls.Find("FavoriteFilterButton", true).Length != 1)
                    throw new Exception("Advanced world filters are missing.");
                SmoothComboBox testVersionFilter = form.Controls.Find("VersionFilter", true)[0] as SmoothComboBox;
                if (testVersionFilter == null) throw new Exception("Version filter does not use the responsive dropdown.");
                int versionSelection = testVersionFilter.SelectedIndex;
                testVersionFilter.ScrollWheelForTest(-SystemInformation.MouseWheelScrollDelta);
                if (testVersionFilter.SelectedIndex != versionSelection) throw new Exception("A closed version filter changes selection from the mouse wheel.");
                form.FavoriteFilterHoverSelfTest();
                form.ThemeSelfTest();
                Control[] logos = form.Controls.Find("AppLogo", true);
                if (logos.Length != 1 || ((PictureBox)logos[0]).Image == null || ((PictureBox)logos[0]).Image.Width < 128)
                    throw new Exception("The high-resolution in-app icon is missing.");
                Control[] grids = form.Controls.Find("WorldGrid", true);
                Control[] footers = form.Controls.Find("StatusFooter", true);
                Control[] statuses = form.Controls.Find("StatusLabel", true);
                Control[] details = form.Controls.Find("DetailsPanel", true);
                Control[] browserLayouts = form.Controls.Find("BrowserLayout", true);
                Control[] gridSurfaces = form.Controls.Find("GridSurface", true);
                if (grids.Length != 1 || footers.Length != 1 || statuses.Length != 1 || details.Length != 1 || browserLayouts.Length != 1 || gridSurfaces.Length != 1 || details[0].Parent != footers[0] || grids[0].Parent != gridSurfaces[0])
                    throw new Exception("World list and footer layout is incomplete.");
                if (statuses[0].Height < statuses[0].PreferredSize.Height || statuses[0].Bottom > footers[0].ClientSize.Height - 1)
                    throw new Exception("Status text is clipped by the footer: status=" + statuses[0].Bounds + ", preferred=" + statuses[0].PreferredSize + ", footer=" + footers[0].ClientSize + ".");
                Control[] worldActions = new Control[] {
                    form.Controls.Find("FavoriteButton", true)[0],
                    form.Controls.Find("DetailsButton", true)[0],
                    form.Controls.Find("BackupButton", true)[0],
                    form.Controls.Find("CopyPathButton", true)[0],
                    form.Controls.Find("OpenWorldButton", true)[0]
                };
                details[0].PerformLayout();
                Control favoriteAction = worldActions[0];
                Control detailsAction = worldActions[1];
                Control backupAction = worldActions[2];
                Control copyAction = worldActions[3];
                Control openAction = worldActions[4];
                Control historyAction = form.Controls.Find("BackupHistoryButton", true)[0];
                if (favoriteAction.Left < 0 || favoriteAction.Right >= detailsAction.Left || detailsAction.Right >= historyAction.Left || historyAction.Right >= backupAction.Left || backupAction.Right >= copyAction.Left || copyAction.Right >= openAction.Left || openAction.Right > details[0].ClientSize.Width)
                    throw new Exception("World action buttons overlap at minimum width.");
                if (form.Controls.Find("RestoreButton", true).Length != 1 || form.Controls.Find("ExportConfigButton", true).Length != 1 || form.Controls.Find("ImportConfigButton", true).Length != 1)
                    throw new Exception("ZIP restore command is missing.");
                Control[] directoryActions = new Control[] {
                    form.Controls.Find("AddRootButton", true)[0],
                    form.Controls.Find("RemoveRootButton", true)[0],
                    form.Controls.Find("RestoreButton", true)[0],
                    form.Controls.Find("ExportConfigButton", true)[0],
                    form.Controls.Find("ImportConfigButton", true)[0]
                };
                foreach (Control action in directoryActions)
                {
                    if (action.Left != 0 || action.Right != action.Parent.ClientSize.Width)
                        throw new Exception("Directory action button is clipped by its parent: " + action.Name + "=" + action.Bounds + ", parent=" + action.Parent.ClientSize + ".");
                }
                if (form.Controls.Find("RootScroll", true).Length != 1 || form.Controls.Find("GridVerticalScroll", true).Length != 1 || form.Controls.Find("GridHorizontalScroll", true).Length != 1)
                    throw new Exception("Minimal scroll bars are missing.");
                if (!(form.Controls.Find("RootList", true)[0] is SmoothListControl)) throw new Exception("Root list does not use pixel-based scrolling.");
                using (SmoothListControl smoothList = new SmoothListControl())
                {
                    smoothList.Size = new Size(220, 114);
                    smoothList.ItemHeight = 38;
                    for (int i = 0; i < 20; i++) smoothList.Items.Add("Root " + i);
                    smoothList.ScrollWheelForTest(-SystemInformation.MouseWheelScrollDelta / 2);
                    double firstTarget = smoothList.TargetScrollOffsetForTest;
                    if (firstTarget <= 0D || firstTarget >= smoothList.ItemHeight * 2D) throw new Exception("Partial wheel input is not mapped to continuous root-list movement.");
                    smoothList.ScrollWheelForTest(-SystemInformation.MouseWheelScrollDelta / 2);
                    double accumulatedTarget = smoothList.TargetScrollOffsetForTest;
                    if (accumulatedTarget <= firstTarget) throw new Exception("Repeated wheel input does not accumulate smoothly.");
                    smoothList.ScrollWheelForTest(SystemInformation.MouseWheelScrollDelta);
                    if (smoothList.TargetScrollOffsetForTest >= accumulatedTarget) throw new Exception("Reversed wheel input does not interrupt the current direction.");
                    smoothList.CompleteScrollForTest();
                }
                BufferedDataGridView testGrid = grids[0] as BufferedDataGridView;
                if (testGrid.ScrollBars != ScrollBars.None) throw new Exception("Native grid scroll bars are still enabled.");
                if (testGrid.ColumnHeadersHeight != 42 || testGrid.ColumnHeadersHeightSizeMode != DataGridViewColumnHeadersHeightSizeMode.DisableResizing)
                    throw new Exception("World-list header height is not fixed.");
                if (testGrid.ColumnHeadersBorderStyle != DataGridViewHeaderBorderStyle.Single)
                    throw new Exception("World-list header uses the thick native raised border.");
                if (testGrid.Columns["Instance"] == null || testGrid.Columns["Source"] == null || testGrid.Columns["Instance"].HeaderText != "\u52a0\u8f7d\u5668" || testGrid.Columns["Instance"].HeaderText == testGrid.Columns["Source"].HeaderText)
                    throw new Exception("Instance information and world location do not use separate columns.");
                testGrid.CreateControl();
                int nameWidth = testGrid.Columns["WorldName"].Width;
                int sourceWidth = testGrid.Columns["Source"].Width;
                int dividerX = 400;
                if (!testGrid.BeginLiveResizeColumn(testGrid.Columns["WorldName"].Index, dividerX)) throw new Exception("Could not start live column resizing.");
                testGrid.UpdateLiveResize(dividerX + 20);
                if (testGrid.Columns["WorldName"].Width != nameWidth + 20)
                    throw new Exception("Column width does not update during dragging.");
                if (testGrid.Columns["Source"].Width != sourceWidth)
                    throw new Exception("Resizing one column changes another column width.");
                testGrid.EndLiveResize();
                MinimalScrollBar testHorizontal = form.Controls.Find("GridHorizontalScroll", true)[0] as MinimalScrollBar;
                testGrid.Columns["WorldName"].Width += 500;
                if (!testHorizontal.IsNeeded) throw new Exception("Horizontal minimal scroll bar does not appear for overflowing columns.");
                testHorizontal.Value = 60;
                if (testGrid.HorizontalScrollingOffset != 60) throw new Exception("Horizontal minimal scroll bar is not linked to the world list.");
                form.WorldSizeRowSelfTest();
                form.FavoriteViewportSelfTest();
                for (int i = 0; i < 40; i++) testGrid.Rows.Add(null, "World " + i, "1.21", "", "", "");
                testGrid.FirstDisplayedScrollingRowIndex = 0;
                testGrid.ScrollWheelForTest(-SystemInformation.MouseWheelScrollDelta / 4);
                if (testGrid.FirstDisplayedScrollingRowIndex != 0)
                    throw new Exception("Partial world-list wheel input moves before enough delta is accumulated.");
                testGrid.ScrollWheelForTest(-SystemInformation.MouseWheelScrollDelta / 4);
                if (testGrid.FirstDisplayedScrollingRowIndex != 1)
                    throw new Exception("Partial world-list wheel input does not accumulate to one row.");
                testGrid.CompleteScrollForTest();
                testGrid.FirstDisplayedScrollingRowIndex = 0;
                testGrid.ScrollWheelForTest(-SystemInformation.MouseWheelScrollDelta);
                int firstWheelTarget = testGrid.FirstDisplayedScrollingRowIndex;
                if (firstWheelTarget != 2) throw new Exception("World-list wheel distance does not match the directory list.");
                testGrid.ScrollWheelForTest(-SystemInformation.MouseWheelScrollDelta);
                if (testGrid.FirstDisplayedScrollingRowIndex <= firstWheelTarget) throw new Exception("Interrupted smooth scrolling does not continue toward the new target.");
                using (MinimalScrollBar testScroll = new MinimalScrollBar())
                {
                    int changeCount = 0;
                    testScroll.ValueChanged += delegate { changeCount++; };
                    testScroll.SetMetrics(100, 10, 0);
                    testScroll.Value = 25;
                    if (!testScroll.Visible || testScroll.Value != 25 || changeCount != 1)
                        throw new Exception("Minimal scroll bar value tracking failed.");
                }
                using (Panel buttonHost = new Panel())
                using (ModernButton testButton = new ModernButton())
                using (Bitmap buttonBitmap = new Bitmap(120, 36))
                {
                    buttonHost.BackColor = Color.White;
                    buttonHost.Size = new Size(120, 36);
                    testButton.BackColor = Color.Transparent;
                    testButton.FillColor = Color.FromArgb(0, 122, 255);
                    testButton.ForeColor = Color.White;
                    testButton.Size = buttonHost.Size;
                    buttonHost.Controls.Add(testButton);
                    buttonHost.DrawToBitmap(buttonBitmap, buttonHost.ClientRectangle);
                    if (buttonBitmap.GetPixel(0, 0).ToArgb() != Color.White.ToArgb() || buttonBitmap.GetPixel(119, 0).ToArgb() != Color.White.ToArgb())
                        throw new Exception("Rounded button corners contain a rectangular background artifact: " + buttonBitmap.GetPixel(0, 0) + " / " + buttonBitmap.GetPixel(119, 0));
                }
                using (Panel patternedHost = new Panel())
                using (ModernButton patternedButton = new ModernButton())
                using (Bitmap pattern = new Bitmap(160, 48, PixelFormat.Format32bppPArgb))
                using (Bitmap baseline = new Bitmap(160, 48, PixelFormat.Format32bppPArgb))
                using (Bitmap rendered = new Bitmap(160, 48, PixelFormat.Format32bppPArgb))
                {
                    for (int y = 0; y < pattern.Height; y++)
                    {
                        for (int x = 0; x < pattern.Width; x++)
                        {
                            pattern.SetPixel(x, y, Color.FromArgb(255, 120 + x / 4, 150 + y, 180 + (x + y) / 8));
                        }
                    }
                    patternedHost.Size = pattern.Size;
                    patternedHost.BackgroundImage = pattern;
                    patternedHost.DrawToBitmap(baseline, patternedHost.ClientRectangle);
                    patternedButton.Location = new Point(20, 6);
                    patternedButton.Size = new Size(120, 36);
                    patternedButton.BackColor = Color.Transparent;
                    patternedButton.FillColor = AppTheme.SecondaryFill;
                    patternedHost.Controls.Add(patternedButton);
                    patternedHost.DrawToBitmap(rendered, patternedHost.ClientRectangle);
                    foreach (Point corner in new Point[] { new Point(20, 6), new Point(139, 6), new Point(20, 41), new Point(139, 41) })
                    {
                        if (rendered.GetPixel(corner.X, corner.Y).ToArgb() != baseline.GetPixel(corner.X, corner.Y).ToArgb())
                            throw new Exception("Rounded button exposes its rectangular control canvas at " + corner + ": " + rendered.GetPixel(corner.X, corner.Y) + " / " + baseline.GetPixel(corner.X, corner.Y));
                    }
                }
                using (Panel pressHost = new Panel())
                using (ModernButton pressButton = new ModernButton())
                using (Bitmap raisedButton = new Bitmap(160, 48, PixelFormat.Format32bppPArgb))
                using (Bitmap insetButton = new Bitmap(160, 48, PixelFormat.Format32bppPArgb))
                {
                    AppTheme.SetDark(false);
                    pressHost.Size = raisedButton.Size;
                    pressHost.BackColor = AppTheme.WindowBase;
                    pressButton.Size = pressHost.Size;
                    pressButton.BackColor = Color.Transparent;
                    pressButton.FillColor = AppTheme.GlassSurface;
                    pressButton.PressedBackColor = AppTheme.GlassSurface;
                    pressButton.CornerRadius = 18;
                    pressHost.Controls.Add(pressButton);
                    pressButton.SetPressedForTest(false);
                    pressHost.DrawToBitmap(raisedButton, pressHost.ClientRectangle);
                    pressButton.SetPressedForTest(true);
                    if (pressButton.PressProgressForTest != 1F) throw new Exception("Neumorphic button press state did not reach its inset target.");
                    pressHost.DrawToBitmap(insetButton, pressHost.ClientRectangle);
                    int changedPixels = 0;
                    for (int y = 1; y < raisedButton.Height - 1; y++)
                    {
                        for (int x = 1; x < raisedButton.Width - 1; x++)
                        {
                            if (raisedButton.GetPixel(x, y).ToArgb() != insetButton.GetPixel(x, y).ToArgb()) changedPixels++;
                        }
                    }
                    if (changedPixels < 180) throw new Exception("Pressed button does not visibly change from raised shadows to inset shadows: changed=" + changedPixels);
                    foreach (Point corner in new Point[] { new Point(0, 0), new Point(159, 0), new Point(0, 47), new Point(159, 47) })
                    {
                        if (insetButton.GetPixel(corner.X, corner.Y).ToArgb() != AppTheme.WindowBase.ToArgb())
                            throw new Exception("Pressed neumorphic button exposes a rectangular corner at " + corner + ".");
                    }
                    Color raisedOuter = raisedButton.GetPixel(158, 24);
                    Color insetOuter = insetButton.GetPixel(158, 24);
                    int raisedDistance = Math.Abs(raisedOuter.R - AppTheme.WindowBase.R) + Math.Abs(raisedOuter.G - AppTheme.WindowBase.G) + Math.Abs(raisedOuter.B - AppTheme.WindowBase.B);
                    int insetDistance = Math.Abs(insetOuter.R - AppTheme.WindowBase.R) + Math.Abs(insetOuter.G - AppTheme.WindowBase.G) + Math.Abs(insetOuter.B - AppTheme.WindowBase.B);
                    if (raisedDistance <= insetDistance) throw new Exception("Outer raised shadow does not disappear when the button is pressed.");
                    pressButton.SetPressedForTest(false);
                    if (pressButton.PressProgressForTest != 0F) throw new Exception("Neumorphic button did not restore its raised state after release.");
                }
                using (Panel roundedHost = new Panel())
                using (RoundedPanel roundedSurface = new RoundedPanel())
                using (Bitmap roundedPattern = new Bitmap(220, 64, PixelFormat.Format32bppPArgb))
                using (Bitmap roundedBaseline = new Bitmap(220, 64, PixelFormat.Format32bppPArgb))
                using (Bitmap roundedRendered = new Bitmap(220, 64, PixelFormat.Format32bppPArgb))
                {
                    for (int y = 0; y < roundedPattern.Height; y++)
                    {
                        for (int x = 0; x < roundedPattern.Width; x++)
                        {
                            roundedPattern.SetPixel(x, y, Color.FromArgb(255, 70 + x / 3, 95 + y, 130 + (x + y) / 7));
                        }
                    }
                    roundedHost.Size = roundedPattern.Size;
                    roundedHost.BackgroundImage = roundedPattern;
                    roundedHost.DrawToBitmap(roundedBaseline, roundedHost.ClientRectangle);
                    roundedSurface.Location = new Point(12, 8);
                    roundedSurface.Size = new Size(196, 48);
                    roundedSurface.BackColor = Color.Transparent;
                    roundedSurface.MaterialColor = Color.FromArgb(128, 255, 255, 255);
                    roundedSurface.CornerRadius = 18;
                    roundedHost.Controls.Add(roundedSurface);
                    roundedHost.DrawToBitmap(roundedRendered, roundedHost.ClientRectangle);
                    foreach (Point corner in new Point[] { new Point(12, 8), new Point(207, 8), new Point(12, 55), new Point(207, 55) })
                    {
                        if (roundedRendered.GetPixel(corner.X, corner.Y).ToArgb() != roundedBaseline.GetPixel(corner.X, corner.Y).ToArgb())
                            throw new Exception("Rounded glass panel exposes its rectangular canvas at " + corner + ": " + roundedRendered.GetPixel(corner.X, corner.Y) + " / " + roundedBaseline.GetPixel(corner.X, corner.Y));
                    }
                }
                foreach (bool darkTextTest in new bool[] { false, true })
                {
                    AppTheme.SetDark(darkTextTest);
                    using (ModernButton textButton = new ModernButton())
                    using (Bitmap textBitmap = new Bitmap(220, 40, PixelFormat.Format32bppPArgb))
                    using (Bitmap textBaseline = new Bitmap(220, 40, PixelFormat.Format32bppPArgb))
                    {
                        textButton.Size = textBitmap.Size;
                        textButton.Text = "Glass button text";
                        textButton.Font = new Font("Segoe UI", 9F);
                        textButton.ForeColor = AppTheme.Ink;
                        for (int y = 0; y < textBitmap.Height; y++)
                        {
                            for (int x = 0; x < textBitmap.Width; x++)
                            {
                                Color pixel = ((x / 3 + y / 3) % 2 == 0)
                                    ? (darkTextTest ? Color.FromArgb(28, 48, 70) : Color.FromArgb(235, 187, 222))
                                    : (darkTextTest ? Color.FromArgb(62, 35, 75) : Color.FromArgb(161, 229, 209));
                                textBitmap.SetPixel(x, y, pixel);
                                textBaseline.SetPixel(x, y, pixel);
                            }
                        }
                        textButton.PaintContentForTest(textBitmap);
                        int changedPixels = 0;
                        Rectangle inspection = new Rectangle(35, 7, 150, 26);
                        for (int y = inspection.Top; y < inspection.Bottom; y++)
                        {
                            for (int x = inspection.Left; x < inspection.Right; x++)
                            {
                                if (textBitmap.GetPixel(x, y).ToArgb() != textBaseline.GetPixel(x, y).ToArgb()) changedPixels++;
                            }
                        }
                        double changedRatio = changedPixels / (double)(inspection.Width * inspection.Height);
                        if (changedRatio <= 0D || changedRatio >= 0.42D)
                            throw new Exception((darkTextTest ? "Dark" : "Light") + " glass button text paints an opaque rectangular background: ratio=" + changedRatio.ToString("0.000"));
                    }
                }
                AppTheme.SetDark(false);
                using (Panel backgroundHost = new Panel())
                using (Panel transparentHost = new Panel())
                using (SmoothComboBox testCombo = new SmoothComboBox())
                using (Bitmap comboBitmap = new Bitmap(184, 30))
                {
                    backgroundHost.BackColor = Color.White;
                    backgroundHost.Size = comboBitmap.Size;
                    transparentHost.BackColor = Color.Transparent;
                    transparentHost.Size = backgroundHost.Size;
                    testCombo.BackColor = Color.Transparent;
                    testCombo.Size = comboBitmap.Size;
                    testCombo.Items.Add("All versions");
                    testCombo.SelectedIndex = 0;
                    backgroundHost.Controls.Add(transparentHost);
                    transparentHost.Controls.Add(testCombo);
                    backgroundHost.DrawToBitmap(comboBitmap, backgroundHost.ClientRectangle);
                    Color topLeft = comboBitmap.GetPixel(0, 0);
                    Color bottomRight = comboBitmap.GetPixel(comboBitmap.Width - 1, comboBitmap.Height - 1);
                if (topLeft.ToArgb() != Color.White.ToArgb() || bottomRight.ToArgb() != Color.White.ToArgb())
                    throw new Exception("Filter dropdown corners contain a dark rectangular artifact: " + topLeft + " / " + bottomRight);
                }
                if (WindowBackdrop.UsesSystemBackdropForTest)
                    throw new Exception("The main window still uses a system backdrop that can flash during maximize transitions.");
                if (form.UsesTopLevelResizeBufferForTest || ((MaterialPanel)sidebar).UsesTransparentResizeBufferForTest || ((MaterialPanel)main).UsesTransparentResizeBufferForTest)
                    throw new Exception("A full-window surface still uses a transparent resize buffer.");
                Size compactClientSize = form.ClientSize;
                form.ClientSize = new Size(1600, 900);
                form.PerformLayout();
                sidebar.PerformLayout();
                main.PerformLayout();
                if (sidebar.Height != form.ClientSize.Height || main.Right != form.ClientSize.Width || main.Height != form.ClientSize.Height || main.Left != sidebar.Right)
                    throw new Exception("Main surfaces leave an unpainted gap after a rapid window-state resize.");
                form.ClientSize = compactClientSize;
                form.PerformLayout();
                sidebar.PerformLayout();
                main.PerformLayout();
                return main.Bounds.ToString();
            }
        }
    }
}
'@

Add-Type -TypeDefinition $source -Language CSharp -ReferencedAssemblies @(
    'System.Windows.Forms',
    'System.Drawing',
    'System.Core',
    'System.IO.Compression',
    'System.IO.Compression.FileSystem'
)

if ($SelfTest) {
    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('PCL2WorldBrowserTest-' + [Guid]::NewGuid().ToString('N'))
    $worldDir = Join-Path $testRoot 'versions\1.20.4\saves\fixture'
    New-Item -ItemType Directory -Path $worldDir -Force | Out-Null

    $bytes = New-Object 'System.Collections.Generic.List[byte]'
    function Add-Byte([byte]$value) { $bytes.Add($value) }
    function Add-BEInt([int]$value) {
        $part = [BitConverter]::GetBytes($value)
        if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($part) }
        $bytes.AddRange($part)
    }
    function Add-BELong([long]$value) {
        $part = [BitConverter]::GetBytes($value)
        if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($part) }
        $bytes.AddRange($part)
    }
    function Add-NbtString([string]$value) {
        $textBytes = [Text.Encoding]::UTF8.GetBytes($value)
        $length = [BitConverter]::GetBytes([uint16]$textBytes.Length)
        if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($length) }
        $bytes.AddRange($length)
        $bytes.AddRange($textBytes)
    }
    function Add-TagHeader([byte]$type, [string]$name) { Add-Byte $type; Add-NbtString $name }

    Add-Byte 10; Add-NbtString ''
    Add-TagHeader 10 'Data'
Add-TagHeader 8 'LevelName'; Add-NbtString 'Codex Test World'
Add-TagHeader 3 'GameType'; Add-BEInt 1
Add-TagHeader 1 'Difficulty'; Add-Byte 2
Add-TagHeader 1 'allowCommands'; Add-Byte 1
Add-TagHeader 4 'RandomSeed'; Add-BELong 123456789
Add-TagHeader 3 'DataVersion'; Add-BEInt 3700
Add-TagHeader 4 'LastPlayed'; Add-BELong 1700000000000
    Add-TagHeader 10 'Version'
    Add-TagHeader 8 'Name'; Add-NbtString '1.20.4'
    Add-Byte 0
    Add-Byte 0
    Add-Byte 0

    $levelPath = Join-Path $worldDir 'level.dat'
    $file = [IO.File]::Create($levelPath)
    try {
        $gzip = New-Object IO.Compression.GZipStream($file, [IO.Compression.CompressionMode]::Compress)
        try {
            $data = $bytes.ToArray()
            $gzip.Write($data, 0, $data.Length)
        } finally { $gzip.Dispose() }
    } finally { $file.Dispose() }

    try {
        $result = [MinecraftWorldBrowser.Program]::SelfTest($testRoot)
        $layout = [MinecraftWorldBrowser.Program]::LayoutSelfTest($PSScriptRoot)
        Write-Output ('SELFTEST OK: ' + $result)
        Write-Output ('LAYOUT OK: ' + $layout)
    } finally {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
    exit 0
}

[MinecraftWorldBrowser.Program]::Run($PSScriptRoot)
