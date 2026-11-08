# Range-Bureau.ps1 - range les icones du Bureau en 4 coins :
#   haut gauche = apps, haut droite = dossiers et fichiers,
#   bas gauche  = launchers, bas droite = jeux.
# Lancer : irm https://raw.githubusercontent.com/ReflxTryomph/LeFour/claude/micro-freeze-fortnite-a282pi/scripts/Range-Bureau.ps1 | iex
# Ne supprime rien. Positions d'avant sauvegardees dans Documents\bureau-positions-avant.csv

$code = @"
using System;
using System.Runtime.InteropServices;

namespace LeFourDesk {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }

  [ComImport, Guid("85CB6900-4D95-11CF-960C-0080C7F4EE85"), InterfaceType(ComInterfaceType.InterfaceIsDual)]
  public interface IShellWindows {
    int Count { get; }
    [return: MarshalAs(UnmanagedType.IDispatch)] object Item([In, MarshalAs(UnmanagedType.Struct)] object index);
    [return: MarshalAs(UnmanagedType.IUnknown)] object _NewEnum();
    void Register([MarshalAs(UnmanagedType.IDispatch)] object pid, int hwnd, int swClass, out int plCookie);
    void RegisterPending(int lThreadId, [In, MarshalAs(UnmanagedType.Struct)] ref object pvarloc, [In, MarshalAs(UnmanagedType.Struct)] ref object pvarlocRoot, int swClass, out int plCookie);
    void Revoke(int lCookie);
    void OnNavigate(int lCookie, [In, MarshalAs(UnmanagedType.Struct)] ref object pvarLoc);
    void OnActivated(int lCookie, bool fActive);
    [return: MarshalAs(UnmanagedType.IDispatch)] object FindWindowSW([In, MarshalAs(UnmanagedType.Struct)] ref object pvarLoc, [In, MarshalAs(UnmanagedType.Struct)] ref object pvarLocRoot, int swClass, out int pHWND, int swfwOptions);
  }

  [ComImport, Guid("6D5140C1-7436-11CE-8034-00AA006009FA"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IOleServiceProvider {
    void QueryService(ref Guid guidService, ref Guid riid, [MarshalAs(UnmanagedType.IUnknown)] out object ppvObject);
  }

  [ComImport, Guid("000214E2-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IShellBrowser {
    void GetWindow(out IntPtr phwnd);
    void ContextSensitiveHelp(int fEnterMode);
    void InsertMenusSB(IntPtr hmenuShared, IntPtr lpMenuWidths);
    void SetMenuSB(IntPtr hmenuShared, IntPtr holemenuRes, IntPtr hwndActiveObject);
    void RemoveMenusSB(IntPtr hmenuShared);
    void SetStatusTextSB(IntPtr pszStatusText);
    void EnableModelessSB(int fEnable);
    void TranslateAcceleratorSB(IntPtr pmsg, ushort wID);
    void BrowseObject(IntPtr pidl, uint wFlags);
    void GetViewStateStream(uint grfMode, out IntPtr ppStrm);
    void GetControlWindow(uint id, out IntPtr phwnd);
    void SendControlMsg(uint id, uint uMsg, IntPtr wParam, IntPtr lParam, out IntPtr pret);
    void QueryActiveShellView([MarshalAs(UnmanagedType.IUnknown)] out object ppshv);
  }

  [ComImport, Guid("1af3a467-214f-4298-908e-06b03e0b39f9"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IFolderView2 {
    void GetCurrentViewMode(out uint pViewMode);
    void SetCurrentViewMode(uint ViewMode);
    void GetFolder(ref Guid riid, [MarshalAs(UnmanagedType.IUnknown)] out object ppv);
    void Item(int iItemIndex, out IntPtr ppidl);
    void ItemCount(uint uFlags, out int pcItems);
    void Items(uint uFlags, ref Guid riid, [MarshalAs(UnmanagedType.IUnknown)] out object ppv);
    void GetSelectionMarkedItem(out int piItem);
    void GetFocusedItem(out int piItem);
    void GetItemPosition(IntPtr pidl, out POINT ppt);
    void GetSpacing(ref POINT ppt);
    void GetDefaultSpacing(out POINT ppt);
    [PreserveSig] int GetAutoArrange();
    void SelectItem(int iItem, uint dwFlags);
    void SelectAndPositionItems(uint cidl, [MarshalAs(UnmanagedType.LPArray)] IntPtr[] apidl, [MarshalAs(UnmanagedType.LPArray)] POINT[] apt, uint dwFlags);
    void SetGroupBy(IntPtr key, int fAscending);
    void GetPropertyItem(int iItem, IntPtr propkey, IntPtr ppropvar);
    void SetText(int iType, IntPtr pwszText);
    void SetCurrentFolderFlags(uint dwMask, uint dwFlags);
    void GetCurrentFolderFlags(out uint pdwFlags);
  }

  public class Desk {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    static extern int SHGetNameFromIDList(IntPtr pidl, uint sigdnName, [MarshalAs(UnmanagedType.LPWStr)] out string ppszName);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();

    IFolderView2 fv;

    public Desk() {
      Type t = Type.GetTypeFromCLSID(new Guid("9BA05972-F6A8-11CF-A442-00A0C90A8F39"));
      IShellWindows sw = (IShellWindows)Activator.CreateInstance(t);
      object loc = 0; object root = null; int hwnd;
      object disp = sw.FindWindowSW(ref loc, ref root, 8, out hwnd, 1);
      IOleServiceProvider sp = (IOleServiceProvider)disp;
      Guid sid = new Guid("4C96BE40-915C-11CF-99D3-00AA004AE837");
      Guid iid = typeof(IShellBrowser).GUID;
      object o;
      sp.QueryService(ref sid, ref iid, out o);
      IShellBrowser sb = (IShellBrowser)o;
      object view;
      sb.QueryActiveShellView(out view);
      fv = (IFolderView2)view;
    }

    public int Count { get { int n; fv.ItemCount(2, out n); return n; } }

    string Name(int i, uint sigdn) {
      IntPtr p; fv.Item(i, out p);
      try { string s; if (SHGetNameFromIDList(p, sigdn, out s) == 0) return s; return ""; }
      finally { Marshal.FreeCoTaskMem(p); }
    }
    public string DisplayName(int i) { return Name(i, 0); }
    public string ParsingName(int i) { return Name(i, 0x80028000); }

    public int[] Position(int i) {
      IntPtr p; fv.Item(i, out p);
      try { POINT pt; fv.GetItemPosition(p, out pt); return new int[] { pt.X, pt.Y }; }
      finally { Marshal.FreeCoTaskMem(p); }
    }

    public int[] Spacing() { POINT pt = new POINT(); fv.GetSpacing(ref pt); return new int[] { pt.X, pt.Y }; }

    public void NoAutoArrange() { fv.SetCurrentFolderFlags(1, 0); }

    public void Move(int i, int x, int y) {
      IntPtr p; fv.Item(i, out p);
      try {
        POINT pt = new POINT(); pt.X = x; pt.Y = y;
        fv.SelectAndPositionItems(1, new IntPtr[] { p }, new POINT[] { pt }, 0x80);
      } finally { Marshal.FreeCoTaskMem(p); }
    }
  }
}
"@

$ErrorActionPreference = 'Stop'
$B   = [Environment]::GetFolderPath('Desktop')
$Doc = [Environment]::GetFolderPath('MyDocuments')

# 1. Si le rangement en dossiers (Jeux / Apps / Fichiers) a ete fait, on le defait d'abord
$csv = Get-ChildItem "$B\Fichiers\rangement-*.csv" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
if ($csv) {
    Import-Csv $csv.FullName | ForEach-Object { if (Test-Path $_.Vers) { Move-Item $_.Vers $_.De -Force } }
    Move-Item $csv.FullName $Doc -Force
    foreach ($d in 'Jeux','Apps','Fichiers') {
        if ((Test-Path "$B\$d") -and -not (Get-ChildItem "$B\$d" -Force)) { Remove-Item "$B\$d" }
    }
    Write-Host 'Dossiers Jeux / Apps / Fichiers defaits, tout est revenu sur le Bureau.' -ForegroundColor Green
    Start-Sleep 3
}

# 2. Connexion au Bureau
if (-not ('LeFourDesk.Desk' -as [type])) { Add-Type -TypeDefinition $code }
[LeFourDesk.Desk]::SetProcessDPIAware() | Out-Null
Add-Type -AssemblyName System.Windows.Forms
$desk = New-Object LeFourDesk.Desk
$desk.NoAutoArrange()

# 3. Classement
$launchers = '^(Steam|Epic Games( Launcher)?|Rockstar Games Launcher|Ubisoft Connect|Riot Client|Battle\.net|EA( app)?|Xbox|GOG Galaxy)$'
$jeux      = 'Fortnite|^VALORANT$|Rocket League|Rainbow Six|Siege|Roblox Player|FiveM|Grand Theft|GTA|Minecraft|Call of Duty|Counter-Strike|Apex|Fall Guys|Overwatch|League of Legends'
$items = for ($i = 0; $i -lt $desk.Count; $i++) {
    $nom  = $desk.DisplayName($i)
    $path = $desk.ParsingName($i)
    $base = [IO.Path]::GetFileNameWithoutExtension($nom)
    $ext  = [IO.Path]::GetExtension($path).ToLower()
    $zone = if ($base -match $launchers -or $nom -match $launchers) { 'BG' }
        elseif ($nom -match $jeux) { 'BD' }
        elseif ($path -like '::*' -or $ext -in '.lnk','.url','.exe','.appref-ms') { 'HG' }
        elseif ((Test-Path -LiteralPath $path -PathType Leaf) -and -not ($ext -in '.lnk','.url')) { 'HD' }
        elseif (Test-Path -LiteralPath $path -PathType Container) { 'HD' }
        else { 'HG' }
    $pos = $desk.Position($i)
    [pscustomobject]@{ Index = $i; Nom = $nom; Zone = $zone; X = $pos[0]; Y = $pos[1]; Corbeille = ($path -like '::{645FF040*') }
}
$items | Select-Object Nom, X, Y | Export-Csv "$Doc\bureau-positions-avant.csv" -NoTypeInformation -Encoding UTF8

# 4. Placement
$scr = [System.Windows.Forms.Screen]::PrimaryScreen
$vs  = [System.Windows.Forms.SystemInformation]::VirtualScreen
$wa  = $scr.WorkingArea
$ox  = $wa.Left - $vs.Left; $oy = $wa.Top - $vs.Top
$W   = $wa.Width; $H = $wa.Height
$sp  = $desk.Spacing(); $sx = [Math]::Max($sp[0], 70); $sy = [Math]::Max($sp[1], 70)
$m   = 8
$rows = [Math]::Max(1, [Math]::Floor(($H / 2 - $m) / $sy))

foreach ($z in 'HG','HD','BG','BD') {
    $liste = @($items | Where-Object Zone -eq $z | Sort-Object @{e = { -not $_.Corbeille }}, Nom)
    for ($k = 0; $k -lt $liste.Count; $k++) {
        $col = [Math]::Floor($k / $rows); $row = $k % $rows
        $x = if ($z -in 'HG','BG') { $m + $col * $sx } else { $W - $m - ($col + 1) * $sx }
        $y = if ($z -in 'HG','HD') { $m + $row * $sy } else { $H - $m - ($row + 1) * $sy }
        $desk.Move($liste[$k].Index, [int]($ox + $x), [int]($oy + $y))
    }
}

$noms = @{ HG = 'Haut gauche (apps)'; HD = 'Haut droite (dossiers/fichiers)'; BG = 'Bas gauche (launchers)'; BD = 'Bas droite (jeux)' }
$items | Group-Object Zone | ForEach-Object { Write-Host ("{0} : {1}" -f $noms[$_.Name], (($_.Group | ForEach-Object Nom) -join ', ')) }
Write-Host "`nBureau range. Anciennes positions : $Doc\bureau-positions-avant.csv" -ForegroundColor Green
