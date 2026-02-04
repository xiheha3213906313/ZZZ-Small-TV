# 完整视频处理脚本：先镜像处理，再提取帧序列

# ===========================================
# 路径变量配置
# ===========================================
$inputDir = "Input"                     # 输入视频目录
$cropDir = "Work\Crop video"          # 裁剪后视频目录
$mirroredDir = "Work\Mirrored video"  # 镜像处理后视频目录
$frameOutputDir = "Work\Pending frame" # 提取的帧序列目录
$coverImageDir = "Work\Cover image"   # 封面图片目录
$ffmpegPath = "Work\Tools\ffmpeg-master-latest-win64-gpl-shared\bin\ffmpeg.exe"  # ffmpeg可执行文件路径
$ffprobePath = "Work\Tools\ffmpeg-master-latest-win64-gpl-shared\bin\ffprobe.exe" # ffprobe可执行文件路径
$texconvPath = "Work\Tools\texconv.exe"  # texconv可执行文件路径

# ===========================================
# 初始化：清空临时目录
# ===========================================
Write-Progress -Activity "Video Processing" -Status "Initializing" -CurrentOperation "Clearing temporary directories" -PercentComplete 0 -Id 1

$tempDirs = @($cropDir, $mirroredDir, $frameOutputDir, $coverImageDir)
foreach ($tempDir in $tempDirs) {
    if (Test-Path $tempDir) {
        Remove-Item -Path "$tempDir\*" -Force -Recurse  # 清空目录内容
    } else {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null  # 创建目录
    }
}

Write-Progress -Activity "Video Processing" -Status "Initializing" -CurrentOperation "Clearing temporary directories" -Completed -Id 1

# ===========================================
# 生成输出目录名称
# ===========================================
$today = Get-Date
$dateFolderName = "{0:MM}{1:dd}{2:HH}{3:mm}_Login TV v4" -f $today, $today, $today, $today  # 格式：月日小时分钟_Login TV v4
$outputBaseDir = Join-Path "Output" $dateFolderName

# ===========================================
# 步骤1：裁剪视频为4:3比例（960×720分辨率）
# ===========================================

# 准备裁剪输出目录
if (Test-Path $cropDir) {
    Remove-Item -Path "$cropDir\*" -Force  # 清空目录
}
if (-not (Test-Path $cropDir)) {
    New-Item -Path $cropDir -ItemType Directory -Force  # 创建目录
}

# 获取输入视频文件列表
$inputVideoFiles = Get-ChildItem -Path $inputDir -File | Where-Object { 
    $_.Extension -in ".mp4", ".avi", ".mov", ".wmv", ".flv", ".gif" 
} | Sort-Object Name  # 按名称排序

# 检查是否有视频文件
if ($inputVideoFiles.Count -eq 0) {
    Write-Host "Error: No video files found in Input folder!" -ForegroundColor Red
    Write-Host "Supported formats: .mp4, .avi, .mov, .wmv, .flv, .gif" -ForegroundColor Yellow
    Write-Host "Please put video files into Input folder and run the script again." -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
    exit 1
}

# 遍历视频文件进行裁剪处理
$totalVideos = $inputVideoFiles.Count
$currentVideo = 1
$cropCounter = 1

foreach ($inputVideo in $inputVideoFiles) {
    Write-Progress -Activity "Video Processing" -Status "Phase 1/8: Cropping Videos to 4:3" -CurrentOperation "Processing video $currentVideo/$totalVideos" -PercentComplete (($currentVideo / $totalVideos) * 100) -Id 1
    
    $inputPath = Join-Path $inputDir $inputVideo.Name
    $outputPath = Join-Path $cropDir "$cropCounter.mp4"
    
    # 使用ffmpeg进行裁剪处理
    # 1. 调整视频大小确保能裁剪出960×720
    # 2. 从中心裁剪为960×720分辨率
    # 3. 抛弃音频
    & $ffmpegPath -y -i "$inputPath" -vf "scale=iw*sar:ih,scale=960:720:force_original_aspect_ratio=increase,crop=960:720:(iw-960)/2:(ih-720)/2" -an "$outputPath" 2>&1 | Out-Null
    
    $cropCounter++
    $currentVideo++
}

Write-Progress -Activity "Video Processing" -Status "Phase 1/8: Cropping Videos to 4:3" -Completed -Id 1

# ===========================================
# 步骤2：镜像处理视频
# ===========================================

# 准备镜像输出目录
if (Test-Path $mirroredDir) {
    Remove-Item -Path "$mirroredDir\*" -Force  # 清空目录
}
if (-not (Test-Path $mirroredDir)) {
    New-Item -Path $mirroredDir -ItemType Directory -Force  # 创建目录
}

# 遍历裁剪后的视频进行镜像处理
$cropVideoFiles = Get-ChildItem -Path $cropDir -File | Sort-Object Name  # 获取裁剪后的视频列表
$totalCropVideos = $cropVideoFiles.Count
$currentCropVideo = 1
$mirrorCounter = 1

foreach ($cropVideo in $cropVideoFiles) {
    Write-Progress -Activity "Video Processing" -Status "Phase 2/8: Mirroring Videos" -CurrentOperation "Processing video $currentCropVideo/$totalCropVideos" -PercentComplete (($currentCropVideo / $totalCropVideos) * 100) -Id 1
    
    $inputPath = Join-Path $cropDir $cropVideo.Name
    $outputPath = Join-Path $mirroredDir "$mirrorCounter.mp4"
    
    # 使用ffmpeg进行垂直镜像处理（vflip）
    # 保持音频不变
    & $ffmpegPath -y -i "$inputPath" -vf "vflip" -c:a copy "$outputPath" 2>&1 | Out-Null
    
    $mirrorCounter++
    $currentCropVideo++
}

Write-Progress -Activity "Video Processing" -Status "Phase 2/8: Mirroring Videos" -Completed -Id 1

# ===========================================
# 步骤3：计算视频帧率
# ===========================================

# 确保Work目录存在
if (-not (Test-Path "Work")) {
    New-Item -Path "Work" -ItemType Directory -Force | Out-Null
}

# 获取镜像处理后的视频文件
$mirroredVideos = Get-ChildItem -Path $mirroredDir -File | Sort-Object Name
$fpsList = @()  # 存储每个视频的帧率

# 遍历视频文件，获取帧率
$totalMirroredVideos = $mirroredVideos.Count
$currentMirroredVideo = 1

foreach ($video in $mirroredVideos) {
    Write-Progress -Activity "Video Processing" -Status "Phase 3/8: Calculating Video FPS" -CurrentOperation "Processing video $currentMirroredVideo/$totalMirroredVideos" -PercentComplete (($currentMirroredVideo / $totalMirroredVideos) * 100) -Id 1
    
    $videoPath = Join-Path $mirroredDir $video.Name
    
    # 使用ffprobe获取视频帧率
    $ffprobeOutput = & $ffprobePath -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$videoPath" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        if ($ffprobeOutput -match '^(\d+)/(\d+)$') {
            # 处理分数形式的帧率，如24/1, 30000/1001等
            $numerator = [int]$matches[1]
            $denominator = [int]$matches[2]
            $fps = [int]($numerator / $denominator)
        } elseif ($ffprobeOutput -match '^\d+(\.\d+)?$') {
            # 处理小数形式的帧率
            $fps = [int][double]$ffprobeOutput
        } else {
            # 默认帧率
            $fps = 25
        }
    } else {
        # 出错时使用默认帧率
        $fps = 25
    }
    
    $fpsList += $fps
    $currentMirroredVideo++
}

Write-Progress -Activity "Video Processing" -Status "Phase 3/8: Calculating Video FPS" -Completed -Id 1

# 定义众数计算函数
function Get-Mode {
    param([double[]]$numbers)
    
    # 统计每个数值出现的次数
    $frequency = @{}
    foreach ($num in $numbers) {
        if ($frequency.ContainsKey($num)) {
            $frequency[$num]++
        } else {
            $frequency[$num] = 1
        }
    }
    
    # 获取最大出现次数
    $maxCount = $frequency.Values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
    
    # 获取所有众数
    $modes = $frequency.Keys | Where-Object { $frequency[$_] -eq $maxCount }
    
    return $modes
}

# 计算最终帧率（使用众数作为最终帧率）
$modes = Get-Mode -numbers $fpsList
$finalFPS = 0

if ($modes.Count -eq 1) {
    # 只有一个众数，直接使用
    $finalFPS = [int]$modes[0]
} else {
    # 有多个众数，计算平均值并截断小数
    $average = ($modes | Measure-Object -Average | Select-Object -ExpandProperty Average)
    $finalFPS = [int]$average
}

# 将结果输出到FPS.txt文件
$fpsOutputPath = "Work\FPS.txt"
Set-Content -Path $fpsOutputPath -Value "FPS=$finalFPS"  # 保存帧率信息

# ===========================================
# 步骤4：提取帧序列
# ===========================================

# 准备帧输出目录
if (Test-Path $frameOutputDir) {
    Remove-Item -Path "$frameOutputDir\*" -Force  # 清空目录
}
if (-not (Test-Path $frameOutputDir)) {
    New-Item -Path $frameOutputDir -ItemType Directory -Force  # 创建目录
}

# 获取镜像处理后的视频文件列表
$mirroredVideoFiles = Get-ChildItem -Path $mirroredDir -File | Sort-Object Name

# 遍历视频文件提取帧序列
$frameCounter = 0  # 初始化帧计数器
$totalMirroredFiles = $mirroredVideoFiles.Count
$currentMirroredFile = 1

foreach ($videoFile in $mirroredVideoFiles) {
    Write-Progress -Activity "Video Processing" -Status "Phase 4/8: Extracting Frame Sequences" -CurrentOperation "Processing video $currentMirroredFile/$totalMirroredFiles" -PercentComplete (($currentMirroredFile / $totalMirroredFiles) * 100) -Id 1
    
    $inputPath = Join-Path $mirroredDir $videoFile.Name
    $outputPattern = Join-Path $frameOutputDir "frame_%04d.png"  # 帧文件名格式：frame_0001.png
    
    # 执行ffmpeg命令提取帧序列
    # 使用-start_number参数指定起始帧号，确保帧序号连续
    & $ffmpegPath -i "$inputPath" -start_number $frameCounter "$outputPattern" 2>&1 | Out-Null
    
    # 更新帧计数器
    $finalFrameCount = (Get-ChildItem -Path $frameOutputDir -Name | Where-Object { $_ -like "frame_*.png" } | Measure-Object).Count
    $frameCounter = $finalFrameCount
    
    # 限制最大帧数为9999（4位数字格式）
    if ($frameCounter -gt 9999) {
        break
    }
    
    $currentMirroredFile++
}

Write-Progress -Activity "Video Processing" -Status "Phase 4/8: Extracting Frame Sequences" -Completed -Id 1

# ===========================================
# 步骤5：使用texconv将PNG转换为DDS格式
# ===========================================

# 设置DDS输出目录
$ddsOutputDir = Join-Path $outputBaseDir "Images"  # DDS输出目录

# 准备DDS输出目录
if (Test-Path $ddsOutputDir) {
    Remove-Item -Path "$ddsOutputDir\*" -Force  # 清空目录
}
if (-not (Test-Path $ddsOutputDir)) {
    New-Item -Path $ddsOutputDir -ItemType Directory -Force  # 创建目录
}

# 获取所有PNG帧文件
$pngFiles = Get-ChildItem -Path $frameOutputDir -Filter "frame_*.png"
$totalFiles = $pngFiles.Count
$currentFile = 0

# 使用texconv -r 指令一次性处理所有PNG文件，提高处理速度
Write-Progress -Activity "Video Processing" -Status "Phase 5/8: Converting PNG to DDS" -CurrentOperation "Initializing conversion..." -PercentComplete 0 -Id 1

# 转换参数：
# -f BC7_UNORM_SRGB: 使用BC7压缩格式，带SRGB颜色空间
# -m 1: 生成1个mipmap
# --srgb-out: 输出为SRGB格式
# -alpha: 保留alpha通道
# -y: 覆盖现有文件
# -ft dds: 输出格式为DDS
# -r: 递归处理（虽然当前目录没有子目录，但使用-r可以一次性处理所有文件）
$inputPattern = Join-Path $frameOutputDir "frame_*.png"

# 执行转换并解析输出以实时更新进度条
& $texconvPath -f BC7_UNORM_SRGB -m 1 --srgb-in --srgb-out -alpha -y -ft dds -r -o "$ddsOutputDir" "$inputPattern" 2>&1 | ForEach-Object {
    $line = $_.ToString()
    # 匹配 texconv 输出中的 "writing" 关键字来统计已处理文件数
    if ($line -match "writing") {
        $currentFile++
        if ($totalFiles -gt 0) {
            $percent = ($currentFile / $totalFiles) * 100
            if ($percent -gt 100) { $percent = 100 }
            Write-Progress -Activity "Video Processing" -Status "Phase 5/8: Converting PNG to DDS" -CurrentOperation "Converting: $currentFile / $totalFiles" -PercentComplete $percent -Id 1
        }
    }
}

Write-Progress -Activity "Video Processing" -Status "Phase 5/8: Converting PNG to DDS" -Completed -Id 1

# ===========================================
# 步骤6：生成INI配置文件
# ===========================================

# 确保输出目录存在
if (-not (Test-Path $outputBaseDir)) {
    New-Item -Path $outputBaseDir -ItemType Directory -Force | Out-Null
}

# 读取之前计算的FPS值
$fpsFile = "Work\FPS.txt"
if (Test-Path $fpsFile) {
    $fpsContent = Get-Content -Path $fpsFile -Raw
    if ($fpsContent -match 'FPS=(\d+\.?\d*)') {
        $fps = [double]$matches[1]  # 提取FPS值
    } else {
        $fps = 16.0  # 默认FPS
    }
} else {
    $fps = 16.0  # 默认FPS
}

# 计算总帧数（用于INI配置）
$frameCount = (Get-ChildItem -Path $frameOutputDir -File -Filter "frame_*.png" | Measure-Object).Count
$endValue = $frameCount - 1  # INI配置中的结束帧号

# ===========================================
# 生成High配置文件
# ===========================================
$highIniName = "[High] LoginTV.ini"
$highIniPath = Join-Path $outputBaseDir $highIniName
$highContent = @'
;patreon.com/UncleBexo

[Constants]
global persist $active = 0

[TextureOverrideGlow]
hash = dd6b8aa6
this = ResourceGlow
$active = 2

[ResourceGlow]
filename = Glow.jpg

[TextureOverrideCheckLoadingTV]
hash = 06eecc31
$active = 1

;[TextureOverrideCheckLoadingTV2]
;hash = b36ffb41
;$active = 2

[TextureOverride_LoginTV_]
hash = ed2e55b0
local $fps = {0}
local $end = {1}
local $framevar = ((time * $fps % $end) + 1) // 1

if $active == 2

'@ -f $fps, $endValue

# 添加framevar条件（High配置）
Write-Progress -Activity "Video Processing" -Status "Phase 6/8: Generating INI Files" -CurrentOperation "Generating High INI - Adding framevar conditions" -PercentComplete 0 -Id 1
for ($i = 0; $i -le $endValue; $i++) {
    Write-Progress -Activity "Video Processing" -Status "Phase 6/8: Generating INI Files" -CurrentOperation "Generating High INI - Adding framevar conditions" -PercentComplete (($i / $endValue) * 25) -Id 1
    if ($i -eq 0) {
        $highContent += "if `$framevar == $i`n    ps-t7 = ResourceOverride_LoginTV_$i`n"
    } else {
        $highContent += "else if `$framevar == $i`n    ps-t7 = ResourceOverride_LoginTV_$i`n"
    }
}

$highContent += "endif`n
"

# 添加ResourceOverride部分（High配置）
for ($i = 0; $i -le $endValue; $i++) {
    Write-Progress -Activity "Video Processing" -Status "Phase 6/8: Generating INI Files" -CurrentOperation "Generating High INI - Adding ResourceOverride" -PercentComplete (25 + ($i / $endValue) * 25) -Id 1
    $frameName = "frame_{0:D4}.dds" -f $i
    $highContent += "[ResourceOverride_LoginTV_$i]`nfilename = Images\$frameName`n`n"
}

# 保存High配置文件
Set-Content -LiteralPath $highIniPath -Value $highContent

# ===========================================
# 生成Low_Mid配置文件
# ===========================================
$lowMidIniName = "[Low_Mid] LoginTV.ini.backup"
$lowMidIniPath = Join-Path $outputBaseDir $lowMidIniName
$lowMidContent = @'
;patreon.com/UncleBexo

[TextureOverrideGlow]
hash = dd6b8aa6
this = ResourceGlow

[ResourceGlow]
filename = Glow.jpg

[TextureOverride_LoginTV_]
hash = ed2e55b0
local $fps = {0}
local $end = {1}
local $framevar = ((time * $fps % $end) + 1) // 1

'@ -f $fps, $endValue

# 添加framevar条件（Low_Mid配置）
for ($i = 0; $i -le $endValue; $i++) {
    Write-Progress -Activity "Video Processing" -Status "Phase 6/8: Generating INI Files" -CurrentOperation "Generating Low_Mid INI - Adding framevar conditions" -PercentComplete (50 + ($i / $endValue) * 25) -Id 1
    if ($i -eq 0) {
        $lowMidContent += "if `$framevar == $i`n    ps-t2 = ResourceOverride_LoginTV_$i`n"
    } else {
        $lowMidContent += "else if `$framevar == $i`n    ps-t2 = ResourceOverride_LoginTV_$i`n"
    }
}

$lowMidContent += "endif`n
"

# 添加ResourceOverride部分（Low_Mid配置）
for ($i = 0; $i -le $endValue; $i++) {
    Write-Progress -Activity "Video Processing" -Status "Phase 6/8: Generating INI Files" -CurrentOperation "Generating Low_Mid INI - Adding ResourceOverride" -PercentComplete (75 + ($i / $endValue) * 25) -Id 1
    $frameName = "frame_{0:D4}.dds" -f $i
    $lowMidContent += "[ResourceOverride_LoginTV_$i]`nfilename = Images\$frameName`n`n"
}

# 保存Low_Mid配置文件
Set-Content -LiteralPath $lowMidIniPath -Value $lowMidContent

# 复制Glow.jpg到配置文件同目录
$glowSourcePath = "Work\Glow.jpg"
$glowTargetPath = Join-Path $outputBaseDir "Glow.jpg"
Copy-Item -Path $glowSourcePath -Destination $glowTargetPath -Force  # 复制发光效果图片

Write-Progress -Activity "Video Processing" -Status "Phase 6/8: Generating INI Files" -Completed -Id 1

# ===========================================
# 步骤7：提取封面和生成预览拼图
# ===========================================
Write-Progress -Activity "Video Processing" -Status "Phase 7/8: Extracting Middle Frames" -CurrentOperation "Initializing" -PercentComplete 0 -Id 1

# 获取输入视频文件列表
$inputVideoFiles = Get-ChildItem -Path $inputDir -File | Where-Object { 
    $_.Extension -in ".mp4", ".avi", ".mov", ".wmv", ".flv", ".gif" 
} | Sort-Object Name

# 遍历视频文件提取中间帧
$coverCounter = 1
foreach ($inputVideo in $inputVideoFiles) {
    $inputPath = Join-Path $inputDir $inputVideo.Name
    
    # 构建输出文件名
    $outputFileName = "{0}.jpg" -f $coverCounter
    $outputPath = Join-Path $coverImageDir $outputFileName
    
    # 通用的缩放和裁剪过滤器，确保输出300x300
    # 1. 先缩放到至少300x300，保持原始宽高比
    # 2. 然后居中裁剪为300x300
    $vfFilter = "scale=300:300:force_original_aspect_ratio=increase,crop=300:300:(iw-300)/2:(ih-300)/2"
    
    # 检测是否为GIF文件
    if ($inputVideo.Extension -eq ".gif") {
        # 获取GIF总帧数
        $frameCountOutput = & $ffprobePath -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 "$inputPath" 2>&1
        if ($LASTEXITCODE -eq 0 -and $frameCountOutput -match '^\d+$') {
            $totalFrames = [int]$frameCountOutput
            $middleFrame = [math]::Ceiling($totalFrames / 2)  # 计算中间帧序号
            # 使用帧序号提取中间帧
            & $ffmpegPath -y -i "$inputPath" -vf "select=eq(n\,$($middleFrame-1)),$vfFilter" -vframes 1 -q:v 2 "$outputPath" 2>&1 | Out-Null
        } else {
            # 使用默认方式处理
            & $ffmpegPath -y -i "$inputPath" -ss 0.5 -vframes 1 -vf "$vfFilter" -q:v 2 "$outputPath" 2>&1 | Out-Null
        }
    } else {
        # 获取视频时长
        $durationOutput = & $ffprobePath -v error -select_streams v:0 -show_entries stream=duration -of csv=p=0 "$inputPath" 2>&1
        if ($LASTEXITCODE -eq 0 -and $durationOutput -match '^\d+(\.\d+)?$') {
            $duration = [double]$durationOutput
            $middleTime = $duration / 2  # 计算中间帧时间（秒）
        } else {
            $middleTime = 1.0  # 默认使用1秒位置
        }
        
        # 使用ffmpeg提取中间帧，调整为300x300正方形
        & $ffmpegPath -y -i "$inputPath" -ss $middleTime -vframes 1 -vf "$vfFilter" -q:v 2 "$outputPath" 2>&1 | Out-Null
    }
    
    $coverCounter++
}

Write-Progress -Activity "Video Processing" -Status "Phase 7/8: Extracting Middle Frames" -Completed -Id 1

# 继续步骤7：生成预览拼图
Write-Progress -Activity "Video Processing" -Status "Phase 7/8: Generating Preview Puzzle" -CurrentOperation "Initializing" -PercentComplete 50 -Id 1

# 获取封面图片，最多处理9张
$coverImages = @(Get-ChildItem -Path $coverImageDir -File | Where-Object { $_.Extension -eq ".jpg" } | Sort-Object Name | Select-Object -First 9)
$imageCount = $coverImages.Count

if ($imageCount -gt 0) {
    # 确保白色占位图存在
    $whiteImagePath = "Work\white.png"
    if (-not (Test-Path $whiteImagePath)) {
        # 创建300x300的白色图片作为占位图
        & $ffmpegPath -y -f lavfi -i "color=white:300x300" -vframes 1 $whiteImagePath 2>&1 | Out-Null
    }

    # 确定拼图布局（行数、列数）
    $rows = 0
    $cols = 0
    $totalCells = 0

    switch ($imageCount) {
        1 { $rows=1; $cols=1; $totalCells=1 }
        2 { $rows=1; $cols=2; $totalCells=2 }
        3 { $rows=2; $cols=2; $totalCells=4 }
        4 { $rows=2; $cols=2; $totalCells=4 }
        5 { $rows=3; $cols=2; $totalCells=6 }
        6 { $rows=2; $cols=3; $totalCells=6 }
        7 { $rows=3; $cols=3; $totalCells=9 }
        8 { $rows=3; $cols=3; $totalCells=9 }
        9 { $rows=3; $cols=3; $totalCells=9 }
        default { $rows=1; $cols=1; $totalCells=1 }
    }

    # 补全图片列表（不足的空位用白色占位图填充）
    $fullImageList = @($coverImages.FullName)
    $emptyCells = $totalCells - $imageCount
    for ($i=0; $i -lt $emptyCells; $i++) {
        $fullImageList += $whiteImagePath
    }

    # 构建输出路径
    $outputPuzzlePath = Join-Path $outputBaseDir "Preview.jpg"

    # 根据图片数量执行不同的拼接逻辑
    if ($imageCount -eq 1) {
        # 1张图：直接复制
        Copy-Item -Path $fullImageList[0] -Destination $outputPuzzlePath -Force
    } else {
        # 多张图：动态生成ffmpeg命令
        $inputs = $fullImageList | ForEach-Object { "-i", "`"$_`"" }
        
        $filterParts = @()
        for ($r = 0; $r -lt $rows; $r++) {
            $rowInputs = ""
            for ($c = 0; $c -lt $cols; $c++) {
                $idx = $r * $cols + $c
                $rowInputs += "[$($idx):v]"
            }
            if ($rows -gt 1) {
                $filterParts += "${rowInputs}hstack=inputs=${cols}[line${r}]"
            } else {
                $filterParts += "${rowInputs}hstack=inputs=${cols}"
            }
        }
        
        $filterComplex = $filterParts -join ";"
        if ($rows -gt 1) {
            $vstackInputs = ""
            for ($r = 0; $r -lt $rows; $r++) {
                $vstackInputs += "[line${r}]"
            }
            $filterComplex += ";${vstackInputs}vstack=inputs=${rows}"
        }
        
        $ffmpegArgs = @("-y") + $inputs + @(
            "-filter_complex", "`"$filterComplex`"",
            "-q:v", "2",
            "`"$outputPuzzlePath`""
        )
        & $ffmpegPath @ffmpegArgs 2>&1 | Out-Null
    }
}

# 完成进度条
Write-Progress -Activity "Video Processing" -Status "Phase 7/8: Generating Preview Puzzle" -Completed -Id 1

# ===========================================
# 步骤8：清空临时目录
# ===========================================

# 清空所有临时目录，保持整洁
$tempDirs = @($cropDir, $mirroredDir, $frameOutputDir, $coverImageDir)
$totalTempDirs = $tempDirs.Count
$currentTempDir = 1

foreach ($tempDir in $tempDirs) {
    Write-Progress -Activity "Video Processing" -Status "Phase 8/8: Clearing Temporary Directories" -CurrentOperation "Clearing $tempDir" -PercentComplete (($currentTempDir / $totalTempDirs) * 100) -Id 1
    if (Test-Path $tempDir) {
        Remove-Item -Path "$tempDir\*" -Force -Recurse  # 清空目录内容
    }
    $currentTempDir++
}

Write-Progress -Activity "Video Processing" -Status "Phase 8/8: Clearing Temporary Directories" -Completed -Id 1

# ===========================================
# 显示最终结果
# ===========================================
Write-Host "\n=== Video Processing Complete! ===" -ForegroundColor Green
Write-Host "Total Frames Extracted: $frameCounter" -ForegroundColor Cyan
Write-Host "Total DDS Files Converted: $($pngFiles.Count)" -ForegroundColor Cyan
Write-Host "Output Directory: $outputBaseDir" -ForegroundColor Cyan
Write-Host "\nThank You for Using!" -ForegroundColor Green