param([string]$Source = (Join-Path $PSScriptRoot '../output/capture_icon_design/track_approved.png'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Join-Path $PSScriptRoot '../assets/ui/capture/track'
New-Item -ItemType Directory -Force $root | Out-Null
$src = [Drawing.Bitmap]::new($Source)
# Coordinates use the 2048-pixel-wide approved preview; scale to the original.
$ratio = $src.Width / 2048.0
function Slice-Disc($Name, $Cx, $Cy, $Radius, $InnerRadius = 0) {
    $out = [Drawing.Bitmap]::new(256,256)
    for ($y=0; $y -lt 256; $y++) {
        for ($x=0; $x -lt 256; $x++) {
            if ($Name -eq 'suppress_icon' -and $y -lt 30) { continue }
            $dx=($x-127.5)/128*$Radius; $dy=($y-127.5)/128*$Radius
            $distance=[Math]::Sqrt($dx*$dx+$dy*$dy)
            if ($distance -gt $Radius-1) { continue }
            if ($InnerRadius -gt 0 -and $distance -lt $InnerRadius) { continue }
            $c=$src.GetPixel([int](($Cx+$dx)*$ratio),[int](($Cy+$dy)*$ratio))
            if ($Name -ne 'suppress_icon' -and ($InnerRadius -eq 0 -or $distance -gt $Radius-14) -and $c.R -gt 210 -and $c.G -gt 180 -and $c.B -gt 100) { continue }
            $out.SetPixel($x,$y,$c)
        }
    }
    if ($Name -eq 'suppress_icon') {
        # Remove only connected backdrop; preserve the enclosed cream creature.
        $queue=[Collections.Generic.Queue[int]]::new()
        $seen=[bool[]]::new(65536)
        $queue.Enqueue(0); $seen[0]=$true
        while($queue.Count -gt 0) {
            $n=$queue.Dequeue(); $px=$n%256; $py=[int][Math]::Floor($n/256)
            $c=$out.GetPixel($px,$py)
            if ($c.A -ne 0 -and !($c.R -gt 200 -and $c.G -gt 175 -and $c.B -gt 100)) { continue }
            $out.SetPixel($px,$py,[Drawing.Color]::Transparent)
            foreach($v in @(@(($px-1),$py),@(($px+1),$py),@($px,($py-1)),@($px,($py+1)))) {
                $nx=[int]$v[0]; $ny=[int]$v[1]
                if($nx -lt 0 -or $ny -lt 0 -or $nx -ge 256 -or $ny -ge 256){continue}
                $nn=$ny*256+$nx
                if(!$seen[$nn]){$seen[$nn]=$true;$queue.Enqueue($nn)}
            }
        }
    }
    $out.Save((Join-Path $root "$Name.png"),[Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
}
Slice-Disc 'throw_icon' 200 355 94
Slice-Disc 'restrain_icon' 744 355 94
Slice-Disc 'suppress_icon' 1265 355 99
Slice-Disc 'finish_icon' 1845 355 94
Slice-Disc 'completed_frame' 1265 355 140 108
Slice-Disc 'pending_frame' 200 355 122 106
$rope=[Drawing.Bitmap]::new(240,58)
for ($y=0;$y -lt 58;$y++) {
    for ($x=0;$x -lt 240;$x++) {
        $c=$src.GetPixel([int]((360+$x)*$ratio),[int]((326+$y)*$ratio))
        if ($c.R -gt 190 -and $c.G -gt 165) { continue }
        $rope.SetPixel($x,$y,$c)
    }
}
$rope.Save((Join-Path $root 'rope.png'),[Drawing.Imaging.ImageFormat]::Png)
$rope.Dispose(); $src.Dispose()

