Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;using System.Collections.Generic;
public class SaliaSlice {
public static int[] labels;public static List<int[]> boxes;
public static void Scan(byte[] p,int w,int h){
labels=new int[w*h];boxes=new List<int[]>();int[] q=new int[w*h];
for(int k=0;k<w*h;k++){if(labels[k]!=0||p[k*4+3]<8)continue;int tag=boxes.Count+1;int head=0,tail=1;q[0]=k;labels[k]=tag;int x0=w,y0=h,x1=0,y1=0;
while(head<tail){int v=q[head++],x=v%w,y=v/w;x0=Math.Min(x0,x);x1=Math.Max(x1,x);y0=Math.Min(y0,y);y1=Math.Max(y1,y);
foreach(int n in new int[]{x>0?v-1:-1,x<w-1?v+1:-1,y>0?v-w:-1,y<h-1?v+w:-1}){if(n>=0&&labels[n]==0&&p[n*4+3]>=8){labels[n]=tag;q[tail++]=n;}}}
boxes.Add(new int[]{tag,tail,x0,y0,x1,y1});
}}
public static byte[] Extract(byte[] p,int w,int h,int target,int[][] mains){
var output=new byte[p.Length];int[] owner=new int[boxes.Count+1];
foreach(var b in boxes){double best=double.MaxValue;int cx=(b[2]+b[4])/2,cy=(b[3]+b[5])/2;
foreach(var main in mains){double dx=Math.Max(main[2]-cx,Math.Max(0,cx-main[4])),dy=Math.Max(main[3]-cy,Math.Max(0,cy-main[5]));double d=dx*dx+dy*dy;if(d<best){best=d;owner[b[0]]=main[0];}}
}
for(int i=0;i<w*h;i++){int label=labels[i];
if(label==0&&p[i*4+3]>0){int x=i%w,y=i/w;for(int dy=-2;dy<=2&&label==0;dy++)for(int dx=-2;dx<=2;dx++){int xx=x+dx,yy=y+dy;if(xx>=0&&xx<w&&yy>=0&&yy<h&&labels[yy*w+xx]!=0){label=labels[yy*w+xx];break;}}}
if(label>0&&owner[label]==target)Array.Copy(p,i*4,output,i*4,4);
}return output;
}}
"@
$root=Join-Path (Get-Location) 'assets/characters/yf02/03_salia_cast_side'
$b=[Drawing.Bitmap]::new((Join-Path $root 'source.png'))
$rect=[Drawing.Rectangle]::new(0,0,$b.Width,$b.Height)
$d=$b.LockBits($rect,[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
$p=[byte[]]::new($d.Stride*$b.Height);[Runtime.InteropServices.Marshal]::Copy($d.Scan0,$p,0,$p.Length);$b.UnlockBits($d)
[SaliaSlice]::Scan($p,$b.Width,$b.Height)
$mains=@([SaliaSlice]::boxes | Where-Object {$_[1] -gt 50000} | Sort-Object @{Expression={[int]($_[3]/512)}},@{Expression={$_[2]}})
if($mains.Count -ne 6){throw 'Expected six independent characters'}
$sheet=[Drawing.Bitmap]::new(1536,1024);$sg=[Drawing.Graphics]::FromImage($sheet)
for($i=0;$i -lt 6;$i++){
 $main=$mains[$i];$pixels=[SaliaSlice]::Extract($p,$b.Width,$b.Height,$main[0],[int[][]]$mains)
 $isolated=[Drawing.Bitmap]::new($b.Width,$b.Height)
 $d=$isolated.LockBits($rect,[Drawing.Imaging.ImageLockMode]::WriteOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
 [Runtime.InteropServices.Marshal]::Copy($pixels,0,$d.Scan0,$pixels.Length);$isolated.UnlockBits($d)
 $minFoot=1536;$maxFoot=0
 for($y=$main[5]-10;$y -le $main[5];$y++){for($x=$main[2];$x -le $main[4];$x++){if($isolated.GetPixel($x,$y).A -gt 128){$minFoot=[Math]::Min($x,$minFoot);$maxFoot=[Math]::Max($x,$maxFoot)}}}
 $foot=($minFoot+$maxFoot)/2.0
 $frame=[Drawing.Bitmap]::new(512,512);$g=[Drawing.Graphics]::FromImage($frame);$g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 $g.DrawImage($isolated,[single](256-$foot*0.62),[single](460-$main[5]*0.62),[single]($b.Width*0.62),[single]($b.Height*0.62))
 $frame.Save((Join-Path $root ('frame_{0:d2}.png' -f $i)))
 $sg.DrawImageUnscaled($frame,($i%3)*512,[int][Math]::Floor($i/3)*512)
 Write-Output "frame $i foot=$foot source_bottom=$($main[5])"
 $g.Dispose();$frame.Dispose();$isolated.Dispose()
}
$sheet.Save((Join-Path $root 'sheet.png'));$sg.Dispose();$sheet.Dispose();$b.Dispose()
