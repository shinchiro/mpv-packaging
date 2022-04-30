function Check-7z {
    $7zdir = (Get-Location).Path + "\7z"
    if (-not (Test-Path ($7zdir + "\7za.exe")) -and -not (Test-Path ([Environment]::ExpandEnvironmentVariables("%Programfiles%\7-Zip\7z.exe"))))
    {
        $download_file = (Get-Location).Path + "\7z.zip"
        Write-Host "Downloading 7z" -ForegroundColor Green
        Invoke-WebRequest -Uri "https://download.sourceforge.net/sevenzip/7za920.zip" -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox -OutFile $download_file
        Write-Host "Extracting 7z" -ForegroundColor Green
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($download_file, $7zdir)
        Remove-Item -Force $download_file
    }
    else
    {
        Write-Host "7z already exist. Skipped download" -ForegroundColor Green
    }
}

function Check-PowershellVersion {
    $version = $PSVersionTable.PSVersion.Major
    Write-Host "Checking Windows PowerShell version -- $version" -ForegroundColor Green
    if ($version -le 2)
    {
        Write-Host "Using Windows PowerShell $version is unsupported. Upgrade your Windows PowerShell." -ForegroundColor Red
        throw
    }
}

function Check-Ytplugin {
    $ytdlp = Get-ChildItem "yt-dlp*.exe" -ErrorAction Ignore
    $youtubedl = Get-ChildItem "youtube-dl.exe" -ErrorAction Ignore
    if ($ytdlp) {
        return $ytdlp.ToString()
    }
    elseif ($youtubedl) {
        return $youtubedl.ToString()
    }
    else {
        return $null
    }
}

function Check-Mpv {
    $mpv = (Get-Location).Path + "\mpv.exe"
    $is_exist = Test-Path $mpv
    return $is_exist
}

function Download-Archive ($filename, $link) {
    Write-Host "Downloading" $filename -ForegroundColor Green
    $global:progressPreference = 'Continue'
    Invoke-WebRequest -Uri $link -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox -OutFile $filename
}

function Download-Ytplugin ($plugin, $version) {
    $link = ""
    $plugin_exe = ""
    switch -wildcard ($plugin) {
        "yt-dlp*" {
            Write-Host "Downloading $plugin ($version)" -ForegroundColor Green
            $global:progressPreference = 'Continue'
            $32bit = ""
            if (-Not (Test-Path (Join-Path $env:windir "SysWow64"))) {
                $32bit = "_x86"
            }
            $link = -join("https://github.com/yt-dlp/yt-dlp/releases/download/", $version, "/", $plugin, $32bit, ".exe")
            $plugin_exe = -join($plugin, $32bit, ".exe")
        }
        "youtube-dl" {
            Write-Host "Downloading $plugin ($version)" -ForegroundColor Green
            $global:progressPreference = 'Continue'
            $link = -join("https://yt-dl.org/downloads/", $version, "/youtube-dl.exe")
            $plugin_exe = "youtube-dl.exe"
        }
    }
    Invoke-WebRequest -Uri $link -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox -OutFile $plugin_exe
}

function Extract-Archive ($file) {
    if (Test-Path ([Environment]::ExpandEnvironmentVariables("%Programfiles%\7-Zip\7z.exe"))) {
        & ([Environment]::ExpandEnvironmentVariables("%Programfiles%\7-Zip\7z.exe")) x -y $file | FIND "Extracting archive" | Write-Host -ForegroundColor Green
    }
    else {
        $7za = (Get-Location).Path + "\7z\7za.exe"
        Write-Host "Extracting" $file -ForegroundColor Green
        & $7za x -y $file
    }
}

function Get-Latest-Mpv($Arch, $channel) {
    $filename = ""
    $download_link = ""
    switch -wildcard ($channel) {
        "daily" {
            $api_gh = "https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest"
            $json = Invoke-WebRequest $api_gh -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing | ConvertFrom-Json
            $filename = $json.assets | where { $_.name -Match "mpv-$Arch" } | Select-Object -ExpandProperty name
            $download_link = $json.assets | where { $_.name -Match "mpv-$Arch" } | Select-Object -ExpandProperty browser_download_url
        }
        "weekly" {
            $i686_link = "https://sourceforge.net/projects/mpv-player-windows/rss?path=/32bit"
            $x86_64_link = "https://sourceforge.net/projects/mpv-player-windows/rss?path=/64bit"
            $rss_link = ''
            switch ($Arch)
            {
                i686 { $rss_link = $i686_link}
                x86_64 { $rss_link = $x86_64_link }
            }
            Write-Host "Fetching RSS feed for mpv" -ForegroundColor Green
            $result = [xml](New-Object System.Net.WebClient).DownloadString($rss_link)
            $latest = $result.rss.channel.item.link[0]
            $tempname = $latest.split("/")[-2]
            $filename = [System.Uri]::UnescapeDataString($tempname)
            $download_link = "https://download.sourceforge.net/mpv-player-windows/" + $filename
        }
    }
    return $filename, $download_link
}

function Get-Latest-Ytplugin ($plugin) {
    switch -wildcard ($plugin) {
        "yt-dlp*" {
            $link = "https://github.com/yt-dlp/yt-dlp/releases.atom"
            Write-Host "Fetching RSS feed for ytp-dlp" -ForegroundColor Green
            $global:progressPreference = 'silentlyContinue'
            $resp = [xml](Invoke-WebRequest $link -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing).Content
            $link = $resp.feed.entry[0].link.href
            $version = $link.split("/")[-1]
            return $version
        }
        "youtube-dl" {
            $link = "https://yt-dl.org/downloads/latest/youtube-dl.exe"
            Write-Host "Fetching RSS feed for youtube-dl" -ForegroundColor Green
            $global:progressPreference = 'silentlyContinue'
            $resp = Invoke-WebRequest $link -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing
            $redirect_link = $resp.Headers.Location
            $version = $redirect_link.split("/")[4]
            return $version
        }
    }
}

function Get-Latest-FFmpeg ($Arch) {
    $api_gh = "https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest"
    $json = Invoke-WebRequest $api_gh -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing | ConvertFrom-Json
    $filename = $json.assets | where { $_.name -Match "ffmpeg-$Arch" } | Select-Object -ExpandProperty name
    $download_link = $json.assets | where { $_.name -Match "ffmpeg-$Arch" } | Select-Object -ExpandProperty browser_download_url
    return $filename, $download_link
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
    $stripped = .\mpv --no-config | select-string "mpv" | select-object -First 1
    $pattern = "-g([a-z0-9-]{7})"
    $bool = $stripped -match $pattern
    return $matches[1]
}

function ExtractGitFromURL($filename) {
    $pattern = "-git-([a-z0-9-]{7})"
    $bool = $filename -match $pattern
    return $matches[1]
}

function ExtractDateFromFile {
    $date = (Get-Item ./mpv.exe).LastWriteTimeUtc
    $day = $date.Day.ToString("00")
    $month = $date.Month.ToString("00")
    $year = $date.Year.ToString("0000")
    return "$year$month$day"
}

function ExtractDateFromURL($filename) {
    $pattern = "mpv-[xi864_]*-([0-9]{8})-git-([a-z0-9-]{7})"
    $bool = $filename -match $pattern
    return $matches[1]
}

function Test-Admin
{
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Create-XML {
@"
<settings>
  <channel>unset</channel>
  <autodelete>unset</autodelete>
  <getffmpeg>unset</getffmpeg>
</settings>
"@ | Set-Content "settings.xml" -Encoding UTF8
}

function Check-ChannelRelease {
    $channel = ""
    $file = "settings.xml"

    if (-not (Test-Path $file)) {
        $result = Read-KeyOrTimeout "Choose mpv updates frequency, weekly or daily? [1=weekly/2=daily] (default=1)" "D1"
        Write-Host ""
        if ($result -eq 'D1') {
            $channel = "weekly"
        }
        elseif ($result -eq 'D2') {
            $channel = "daily"
        }
        else {
            throw "Please enter valid input key."
        }
        Create-XML
        [xml]$doc = Get-Content $file
        $doc.settings.channel = $channel
        $doc.Save($file)
    }
    else {
        [xml]$doc = Get-Content $file
        $channel = $doc.settings.channel
    }
    return $channel
}

function Check-Autodelete($archive) {
    $autodelete = ""
    $file = "settings.xml"

    if (-not (Test-Path $file)) { exit }
    [xml]$doc = Get-Content $file
    if ($doc.settings.autodelete -eq "unset") {
        $result = Read-KeyOrTimeout "Delete archives after extract? [Y/n] (default=Y)" "Y"
        Write-Host ""
        if ($result -eq 'Y') {
            $autodelete = "true"
        }
        elseif ($result -eq 'N') {
            $autodelete = "false"
        }
        else {
            throw "Please enter valid input key."
        }
        $doc.settings.autodelete = $autodelete
        $doc.Save($file)
    }
    if ($doc.settings.autodelete -eq "true") {
        if (Test-Path $archive)
        {
            Remove-Item -Force $archive
        }
    }
}

function Check-GetFFmpeg() {
    $get_ffmpeg = ""
    $file = "settings.xml"

    if (-not (Test-Path $file)) { exit }
    [xml]$doc = Get-Content $file
    if ($doc.settings.getffmpeg -eq "unset") {
        Write-Host "FFmpeg doesn't exist. " -ForegroundColor Green -NoNewline
        $result = Read-KeyOrTimeout "Proceed with downloading? [Y/n] (default=n)" "N"
        Write-Host ""
        if ($result -eq 'Y') {
            $get_ffmpeg = "true"
        }
        elseif ($result -eq 'N') {
            $get_ffmpeg = "false"
        }
        else {
            throw "Please enter valid input key."
        }
        $doc.settings.getffmpeg = $get_ffmpeg
        $doc.Save($file)
    }
    else {
        $get_ffmpeg = $doc.settings.getffmpeg
    }
    return $get_ffmpeg
}

function Upgrade-Mpv {
    $need_download = $false
    $remoteName = ""
    $download_link = ""
    $arch = ""
    $channel = ""

    if (Check-Mpv) {
        $arch = (Get-Arch).FileType
        $channel = Check-ChannelRelease
        $remoteName, $download_link = Get-Latest-Mpv $arch $channel
        $localgit = ExtractGitFromFile
        $localdate = ExtractDateFromFile
        $remotegit = ExtractGitFromURL $remoteName
        $remotedate = ExtractDateFromURL $remoteName
        if ($localgit -match $remotegit)
        {
            if ($localdate -match $remotedate)
            {
                Write-Host "You are already using latest mpv build -- $remoteName" -ForegroundColor Green
                $need_download = $false
            }
            else {
                Write-Host "Newer mpv build available" -ForegroundColor Green
                $need_download = $true
            }
        }
        else {
            Write-Host "Newer mpv build available" -ForegroundColor Green
            $need_download = $true
        }
    }
    else {
        Write-Host "mpv doesn't exist. " -ForegroundColor Green -NoNewline
        $result = Read-KeyOrTimeout "Proceed with downloading? [Y/n] (default=y)" "Y"
        Write-Host ""

        if ($result -eq 'Y') {
            $need_download = $true
            if (Test-Path (Join-Path $env:windir "SysWow64")) {
                Write-Host "Detecting System Type is 64-bit" -ForegroundColor Green
                $arch = "x86_64"
            }
            else {
                Write-Host "Detecting System Type is 32-bit" -ForegroundColor Green
                $arch = "i686"
            }
            $channel = Check-ChannelRelease
            $remoteName, $download_link = Get-Latest-Mpv $arch $channel
        }
        elseif ($result -eq 'N') {
            $need_download = $false
        }
        else {
            throw "Please enter valid input key."
        }
    }

    if ($need_download) {
        Download-Archive $remoteName $download_link
        Check-7z
        Extract-Archive $remoteName
    }
    Check-Autodelete $remoteName
}

function Upgrade-Ytplugin {
    $yt = Check-Ytplugin
    if ($yt) {
        $latest_release = Get-Latest-Ytplugin((Get-Item $yt).BaseName)
        if ((& $yt --version) -match ($latest_release)) {
            Write-Host "You are already using latest" (Get-Item $yt).BaseName "-- $latest_release" -ForegroundColor Green
        }
        else {
            Write-Host "Newer" (Get-Item $yt).BaseName "build available" -ForegroundColor Green
            & $yt --update
        }
    }
    else {
        Write-Host "ytdlp or youtube-dl doesn't exist. " -ForegroundColor Green -NoNewline
        $result = Read-KeyOrTimeout "Proceed with downloading? [Y/n] (default=n)" "N"
        Write-Host ""

        if ($result -eq 'Y') {
            $result_exe = Read-KeyOrTimeout "Download ytdlp or youtubedl? [1=ytdlp/2=youtubedl] (default=1)" "D1"
            Write-Host ""
            if ($result_exe -eq 'D1') {
                $latest_release = Get-Latest-Ytplugin "yt-dlp"
                Download-Ytplugin "yt-dlp" $latest_release
            }
            elseif ($result_exe -eq 'D2') {
                $latest_release = Get-Latest-Ytplugin "youtube-dl"
                Download-Ytplugin "youtube-dl" $latest_release
            }
            else {
                throw "Please enter valid input key."
            }
        }
    }
}

function Upgrade-FFmpeg {
    $get_ffmpeg = Check-GetFFmpeg
    if ($get_ffmpeg -eq "false") {
        exit
    }

    if (Test-Path (Join-Path $env:windir "SysWow64")) {
        $arch = "x86_64"
    }
    else {
        $arch = "i686"
    }

    $need_download = $false
    $remote_name, $download_link = Get-Latest-FFmpeg $arch
    $ffmpeg = (Get-Location).Path + "\ffmpeg.exe"
    $ffmpeg_exist = Test-Path $ffmpeg

    if ($ffmpeg_exist) {
        $ffmpeg_file = .\ffmpeg -version | select-string "ffmpeg" | select-object -First 1
        $file_pattern = "git-[0-9-]+([a-z0-9-]{8})"
        $url_pattern = "git-([a-z0-9-]{8})"
        $bool = $ffmpeg_file -match $file_pattern
        $local_git = $matches[1]
        $bool = $remote_name -match $url_pattern
        $remote_git = $matches[1]

        if ($local_git -match $remote_git) {
            Write-Host "You are already using latest ffmpeg build -- $remote_name" -ForegroundColor Green
            $need_download = $false
        }
        else {
            Write-Host "Newer ffmpeg build available" -ForegroundColor Green
            $need_download = $true
        }
    }
    else {
        $need_download = $true
    }

    if ($need_download) {
        Download-Archive $remote_name $download_link
        Check-7z
        Extract-Archive $remote_name
    }
    Check-Autodelete $remote_name
}

function Read-KeyOrTimeout ($prompt, $key){
    $seconds = 9
    $startTime = Get-Date
    $timeOut = New-TimeSpan -Seconds $seconds

    Write-Host "$prompt " -ForegroundColor Green

    # Basic progress bar
    [Console]::CursorLeft = 0
    [Console]::Write("[")
    [Console]::CursorLeft = $seconds + 2
    [Console]::Write("]")
    [Console]::CursorLeft = 1

    while (-not [System.Console]::KeyAvailable) {
        $currentTime = Get-Date
        Start-Sleep -s 1
        Write-Host "#" -ForegroundColor Green -NoNewline
        if ($currentTime -gt $startTime + $timeOut) {
            Break
        }
    }
    if ([System.Console]::KeyAvailable) {
        $response = [System.Console]::ReadKey($true).Key
    }
    else {
        $response = $key
    }
    return $response.ToString()
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
    Check-PowershellVersion
    # Sourceforge only support TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Upgrade-Mpv
    Upgrade-Ytplugin
    Upgrade-FFmpeg
    Write-Host "Operation completed" -ForegroundColor Magenta
}
catch [System.Exception] {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
