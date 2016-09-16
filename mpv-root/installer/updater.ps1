function Check-7z {
    $7zdir = (Get-Location).Path + "\7z"
    if (-not (Test-Path ($7zdir + "\7za.exe")))
    {
        $download_file = (Get-Location).Path + "\7z.zip"
        Write-Host "Downloading 7z" -foregroundcolor green
        Invoke-WebRequest -Uri "http://download.sourceforge.net/sevenzip/7za920.zip" -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox -OutFile $download_file
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        Write-Host "Extracting 7z" -foregroundcolor green
        [System.IO.Compression.ZipFile]::ExtractToDirectory($download_file, $7zdir)
        Remove-Item -Force $download_file
    }
    else
    {
        Write-Host "7z already exist. Skipped download" -ForegroundColor green
    }
}

function Check-Youtubedl {
    $youtubedl = (Get-Location).Path + "\youtube-dl.exe"
    $is_exist = Test-Path $youtubedl
    if (-not $is_exist) {
        Write-Host "youtube-dl doesn't exist" -ForegroundColor Cyan
    }
    return $is_exist
}

function Check-Mpv {
    $mpv = (Get-Location).Path + "\mpv.exe"
    $is_exist = Test-Path $mpv
    if (-not $is_exist) {
        Write-Host "mpv doesn't exist" -ForegroundColor Cyan
    }
    return $is_exist
}

function Download-Mpv ($filename) {
    Write-Host "Downloading" $filename -ForegroundColor Green
    $link = "http://download.sourceforge.net/mpv-player-windows/" + $filename
    Invoke-WebRequest -Uri $link -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox -OutFile $filename
}

function Download-Youtubedl ($version) {
    Write-Host "Downloading youtube-dl ($version)" -ForegroundColor Green
    $link = "https://github.com/rg3/youtube-dl/releases/download/" + $version + "/youtube-dl.exe"
    Invoke-WebRequest -Uri $link -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox -OutFile "youtube-dl.exe"
}

function Extract-Mpv ($file) {
    $7za = (Get-Location).Path + "\7z\7za.exe"
    Write-Host "Extracting" $file -ForegroundColor Green
    & $7za x -y $file
    Remove-Item -Force $file
}

function Get-Latest-Mpv($Arch) {
    $i686_link = "https://sourceforge.net/projects/mpv-player-windows/rss?path=/32bit"
    $x86_64_link = "https://sourceforge.net/projects/mpv-player-windows/rss?path=/64bit"
    $link = ''
    switch ($Arch)
    {
        i686 { $link = $i686_link}
        x86_64 { $link = $x86_64_link }
    }
    Write-Host "Fetching RSS feed for mpv" -ForegroundColor Green
    $result = [xml](New-Object System.Net.WebClient).DownloadString($link)
    $latest = $result.rss.channel.item.link[0]
    $filename = $latest.split("/")[-2]
    return $filename
}

function Get-Latest-Youtubedl {
    $link = "https://github.com/rg3/youtube-dl/releases.atom"
    Write-Host "Fetching RSS feed for youtube-dl" -ForegroundColor Green
    $result = [xml](New-Object System.Net.WebClient).DownloadString($link)
    $version = $result.feed.entry[0].title.split(" ")[-1]
    return $version
}

function Get-Arch {
    # Reference: http://superuser.com/a/891443
    $FilePath = [System.IO.Path]::Combine((Get-Location).Path, 'mpv.exe')
    [int32]$MACHINE_OFFSET = 4
    [int32]$PE_POINTER_OFFSET = 60

    [byte[]]$data = New-Object -TypeName System.Byte[] -ArgumentList 4096
    $stream = New-Object -TypeName System.IO.FileStream -ArgumentList ($FilePath, 'Open', 'Read')
    $stream.Read($data, 0, 4096) | Out-Null

    # DOS header is 64 bytes, last element, long (4 bytes) is the address of the PE header
    [int32]$PE_HEADER_ADDR = [System.BitConverter]::ToInt32($data, $PE_POINTER_OFFSET)
    [int32]$machineUint = [System.BitConverter]::ToUInt16($data, $PE_HEADER_ADDR + $MACHINE_OFFSET)

    $result = "" | select FilePath, FileType
    $result.FilePath = $FilePath

    switch ($machineUint)
    {
        0      { $result.FileType = 'Native' }
        0x014c { $result.FileType = 'i686' } # 32bit
        0x0200 { $result.FileType = 'Itanium' }
        0x8664 { $result.FileType = 'x86_64' } # 64bit
    }

    $result
}

function ExtractGitFromFile {
    $stripped = .\mpv --no-config | select-string "mpv git"
    $pattern = "mpv ([a-z0-9-]+.)\B"
    $bool = $stripped -match $pattern
    return $matches[1]
}

function ExtractGitFromURL($filename) {
    $pattern = "-?(git-[a-z0-9-]+.).7z"
    $bool = $filename -match $pattern
    return $matches[1]
}

function Test-Admin
{
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Upgrade-Mpv {
    $need_download = $false
    $remoteName = ""

    if (Check-Mpv) {
        $arch = (Get-Arch).FileType
        $remoteName = Get-Latest-Mpv $arch
        if ((ExtractGitFromFile) -match (ExtractGitFromURL $remoteName))
        {
            Write-Host "You are already using latest mpv build ($remoteName)" -ForegroundColor Green
            $need_download = $false
        }
        else {
            Write-Host "Newer mpv build available" -ForegroundColor Green
            $need_download = $true
        }
    }
    else {
        $need_download = $true
        Write-Host "Assuming System Type is 64-bit" -ForegroundColor Magenta
        $remoteName = Get-Latest-Mpv "x86_64"
    }

    if ($need_download) {
        Download-Mpv $remoteName
        Check-7z
        Extract-Mpv $remoteName
    }
}

function Upgrade-Youtubedl {
    $need_download = $false
    $latest_release = Get-Latest-Youtubedl

    if (Check-Youtubedl) {
        if ((.\youtube-dl --version) -match ($latest_release)) {
            Write-Host "You are already using latest youtube-dl ($latest_release)" -ForegroundColor Green
            $need_download = $false
        }
        else {
            Write-Host "Newer youtube-dl build available" -ForegroundColor Green
            $need_download = $true
        }
    }
    else {
        $need_download = $true
    }

    if ($need_download) {
        Download-Youtubedl $latest_release
    }
}

#
# Main script entry point
#
if (Test-Admin) {
    Write-Host "Running script with administrator privileges" -ForegroundColor Yellow
}
else {
    Write-Host "Running script without administrator privileges" -ForegroundColor Red
}

try {
    Upgrade-Mpv
    Upgrade-Youtubedl
}
catch [System.Exception] {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
