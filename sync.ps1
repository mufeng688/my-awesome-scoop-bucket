# sync.ps1

# 定义要同步的存储桶列表
# 键为你的仓库中存储这些 manifest 的子目录名
# 值为目标存储桶的 Git URL
$bucketsToSync = @{
    "main" = "https://github.com/ScoopInstaller/Main.git"
    "extras" = "https://github.com/ScoopInstaller/Extras.git"
    "versions" = "https://github.com/ScoopInstaller/Versions.git"
    # 如果你想同步第三方存储桶，例如一个国内加速的存储桶，也可以添加到这里
    # "scoop-cn" = "https://gitee.com/your-username/scoop-cn.git"
    # 更多你可以想同步的桶...
}

# 定义临时目录，用于克隆目标存储桶
$tempDir = Join-Path $PSScriptRoot "temp_buckets"

# 确保临时目录存在
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir
}

Write-Host "开始同步 Scoop 存储桶..."

foreach ($bucketName in $bucketsToSync.Keys) {
    $bucketUrl = $bucketsToSync[$bucketName]
    $localBucketPath = Join-Path $tempDir $bucketName
    $targetManifestPath = Join-Path $PSScriptRoot "bucket" # 你的存储桶中存放 manifest 的目录

    Write-Host "处理存储桶: $bucketName from $bucketUrl"

    # 克隆或拉取目标存储桶
    if (Test-Path $localBucketPath -PathType Container) {
        Write-Host "   拉取更新: $localBucketPath"
        try {
            Push-Location $localBucketPath
            git pull
            Pop-Location
        } catch {
            Write-Host "   拉取失败: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "   克隆仓库: $bucketUrl 到 $localBucketPath"
        try {
            git clone $bucketUrl $localBucketPath
        } catch {
            Write-Host "   克隆失败: $_" -ForegroundColor Red
        }
    }

    # 确保目标 manifest 目录存在
    $finalManifestDestination = Join-Path $targetManifestPath $bucketName
    if (-not (Test-Path $finalManifestDestination)) {
        New-Item -ItemType Directory -Path $finalManifestDestination -Force
    }

    # 复制 manifest 文件
    $manifestSourcePath = Join-Path $localBucketPath "bucket" # 假设目标存储桶的 manifest 也在 'bucket' 子目录
    if (Test-Path $manifestSourcePath -PathType Container) {
        Write-Host "   复制 manifest 文件从 $manifestSourcePath 到 $finalManifestDestination"
        # 递归复制所有 .json 文件，并覆盖现有文件
        Get-ChildItem -Path $manifestSourcePath -Filter "*.json" -Recurse | ForEach-Object {
            $destFile = Join-Path $finalManifestDestination $_.Name
            Copy-Item -Path $_.FullName -Destination $destFile -Force
        }
    } else {
        Write-Host "   警告: 目标存储桶 $bucketName 没有 'bucket' 子目录，跳过 manifest 复制。" -ForegroundColor Yellow
    }
}

Write-Host "删除临时目录: $tempDir"
Remove-Item -Recurse -Force $tempDir

Write-Host "同步完成。"

# 将更改提交到 Git
Push-Location $PSScriptRoot
Write-Host "Git: 添加所有更改..."
git add .
Write-Host "Git: 提交更改..."
git commit -m "Auto-sync Scoop buckets"
Write-Host "Git: 推送更改到远程仓库..."
git push
Pop-Location

Write-Host "所有更改已推送到远程仓库。"
