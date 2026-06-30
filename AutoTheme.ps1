# ================= 配置区域 =================
# 方法1：手动填写经纬度（推荐，最可靠）
$latitude  = 31.3461      # 你的纬度
$longitude = 121.4409     # 你的经度
# ===========================================

# 缓存文件路径（避免重复请求API）
$cacheFile = "$env:TEMP\sun_times_cache.txt"
$today = (Get-Date).ToString("yyyy-MM-dd")

# 尝试从缓存读取今天的日出日落时间
$sunrise = $null
$sunset  = $null
if (Test-Path $cacheFile) {
    $cache = Get-Content $cacheFile | ConvertFrom-Json
    if ($cache.date -eq $today) {
        $sunrise = [datetime]$cache.sunrise
        $sunset  = [datetime]$cache.sunset
    }
}

# 如果缓存没有今天的数据，则请求API
if (-not $sunrise -or -not $sunset) {
    try {
        $url = "https://api.sunrise-sunset.org/json?lat=$latitude&lng=$longitude&formatted=0"
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 5
        if ($response.status -eq "OK") {
            $sunrise = [datetime]$response.results.sunrise
            $sunset  = [datetime]$response.results.sunset
            # 写入缓存
            @{ date=$today; sunrise=$sunrise.ToString("o"); sunset=$sunset.ToString("o") } | ConvertTo-Json | Set-Content $cacheFile
        } else {
            Write-Error "API返回错误"
            exit 1
        }
    } catch {
        Write-Error "无法获取日出日落时间：$_"
        exit 1
    }
}

# 判断当前是否白天
$now = Get-Date
$isDay = ($now -ge $sunrise) -and ($now -le $sunset)

# 设置主题：AppsUseLightTheme 和 SystemUseLightTheme
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$value = if ($isDay) { 1 } else { 0 }

Set-ItemProperty -Path $regPath -Name "AppsUseLightTheme" -Value $value
Set-ItemProperty -Path $regPath -Name "SystemUseLightTheme" -Value $value
Set-ItemProperty -Path $regPath -Name "SystemUsesLightTheme" -Value $value

# 通知系统刷新
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ThemeNotify {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
$HWND_BROADCAST = 0xFFFF
$WM_SETTINGCHANGE = 0x001A
$SMTO_ABORTIFHUNG = 0x0002
[UIntPtr]$result = [UIntPtr]::Zero
[ThemeNotify]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "ImmersiveColorSet", $SMTO_ABORTIFHUNG, 5000, [ref]$result)

Write-Host "主题已切换为 $(if ($isDay) {'浅色'} else {'深色'})"