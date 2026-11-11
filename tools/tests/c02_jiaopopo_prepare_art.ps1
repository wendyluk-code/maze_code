param([string]$Source='F:/maze_code/output/character_c02_dispatch/art_review',[string]$ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Private.Windows.GdiPlus,System.Private.Windows.Core -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
public static class C02Art {
  public static Rectangle Bounds(Bitmap source, Rectangle cell) {
    int x0=cell.Right,y0=cell.Bottom,x1=cell.Left,y1=cell.Top;
    for(int y=cell.Top;y<cell.Bottom;y++) for(int x=cell.Left;x<cell.Right;x++)
      if(source.GetPixel(x,y).A>12) { x0=Math.Min(x0,x); y0=Math.Min(y0,y); x1=Math.Max(x1,x); y1=Math.Max(y1,y); }
    return Rectangle.FromLTRB(x0,y0,x1+1,y1+1);
  }
  public static void Fit(Bitmap source, Bitmap output, Rectangle crop, Rectangle cell, int margin) {
    double scale=Math.Min((cell.Width-2.0*margin)/crop.Width,(cell.Height-2.0*margin)/crop.Height);
    int w=(int)Math.Round(crop.Width*scale),h=(int)Math.Round(crop.Height*scale);
    using(Graphics g=Graphics.FromImage(output)) {
      g.CompositingMode=CompositingMode.SourceCopy;
      g.InterpolationMode=InterpolationMode.HighQualityBicubic;
      g.DrawImage(source,new Rectangle(cell.X+(cell.Width-w)/2,cell.Y+(cell.Height-h)/2,w,h),crop,GraphicsUnit.Pixel);
    }
  }
}
'@
$iconDir=Join-Path $ProjectRoot 'assets/ui/combat_skills'
$smokeDir=Join-Path $ProjectRoot 'assets/combat/jiaopopo'
New-Item -ItemType Directory -Force -Path $iconDir,$smokeDir | Out-Null
$jar=[Drawing.Bitmap]::new((Join-Path $Source 'jar.png'))
$icon=[Drawing.Bitmap]::new(512,512)
[C02Art]::Fit($jar,$icon,[C02Art]::Bounds($jar,[Drawing.Rectangle]::new(0,0,$jar.Width,$jar.Height)),[Drawing.Rectangle]::new(0,0,512,512),24)
$icon.Save((Join-Path $iconDir 'jiaopopo.png'),[Drawing.Imaging.ImageFormat]::Png)
$sheet=[Drawing.Bitmap]::new((Join-Path $Source 'smoke_sheet.png'))
$output=[Drawing.Bitmap]::new(1024,512)
for($i=0;$i -lt 8;$i++) {
  $column=$i%4; $row=[int][Math]::Floor($i/4)
  $left=[int][Math]::Floor($column*$sheet.Width/4.0); $top=[int][Math]::Floor($row*$sheet.Height/2.0)
  $right=[int][Math]::Floor(($column+1)*$sheet.Width/4.0); $bottom=[int][Math]::Floor(($row+1)*$sheet.Height/2.0)
  $crop=[C02Art]::Bounds($sheet,[Drawing.Rectangle]::FromLTRB($left,$top,$right,$bottom))
  [C02Art]::Fit($sheet,$output,$crop,[Drawing.Rectangle]::new($column*256,$row*256,256,256),8)
}
$output.Save((Join-Path $smokeDir 'smoke.png'),[Drawing.Imaging.ImageFormat]::Png)
$jar.Dispose(); $icon.Dispose(); $sheet.Dispose(); $output.Dispose()
Write-Output '已按批准素材整理：图标512×512，烟图1024×512（8帧256×256），保留透明通道。'
