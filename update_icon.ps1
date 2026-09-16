Add-Type -AssemblyName System.Drawing

$src = "C:\Users\This PC\.gemini\antigravity\brain\334be7ec-b839-44e3-bf48-63abba543ea9\bep1979_cartoon_icon_1789555824899.jpg"
$baseDir = "e:\DU AN WEBSITE\Web-Food\food_mobile\android\app\src\main\res"

$sizes = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}

if (!(Test-Path $src)) {
    Write-Error "Không tìm thấy file ảnh nguồn tại $src"
    exit 1
}

$srcImage = [System.Drawing.Image]::FromFile($src)

foreach ($folder in $sizes.Keys) {
    $size = $sizes[$folder]
    $destFolder = Join-Path $baseDir $folder
    if (!(Test-Path $destFolder)) {
        New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
    }
    $destPath = Join-Path $destFolder "ic_launcher.png"

    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $graphics.DrawImage($srcImage, 0, 0, $size, $size)
    $graphics.Dispose()

    $bitmap.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()

    Write-Host "✅ Đã tạo icon ${size}x${size} -> $destPath"
}

$srcImage.Dispose()
Write-Host "🎉 Cập nhật toàn bộ icon app Bếp 1979 thành công!"

