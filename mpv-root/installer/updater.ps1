function Check7z {
    $7zdir = (Get-Location).Path + "\7z"
    if (-not (Test-Path ($7zdir + "\7za.exe")))
    {
        $download_file = (Get-Location).Path + "\7z.zip"
        write-host "Downloading 7z.." -foregroundcolor green
        Invoke-WebRequest -Uri "http://download.sourceforge.net/sevenzip/7za920.zip" -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox -OutFile $download_file
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        write-host "Extracting 7z" -foregroundcolor green
        [System.IO.Compression.ZipFile]::ExtractToDirectory($download_file, $7zdir)
        Remove-Item -Force $download_file
    }
    else
    {
        write-host "7z already exist. Skipped download." -foregroundcolor green
    }
}

function Download-Mpv ($filename) {
    write-host "Downloading" $filename -foregroundcolor green
    $link = "http://download.sourceforge.net/mpv-player-windows/" + $filename
    Invoke-WebRequest -Uri $link -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox -OutFile $filename
}

function Extract-Mpv ($file) {
    $7za = (Get-Location).Path + "\7z\7za.exe"
    write-host "Extracting" $file -foregroundcolor green
    & $7za x -y $file
    Remove-Item -Force $file
}

function Get-Latest($Arch) {
    $i686_link = "https://sourceforge.net/projects/mpv-player-windows/rss?path=/32bit"
    $x86_64_link = "https://sourceforge.net/projects/mpv-player-windows/rss?path=/64bit"
    $link = ''
    switch ($Arch)
    {
        i686 { $link = $i686_link}
        x86_64 { $link = $x86_64_link }
    }
    write-host "Fetching RSS feed" -foregroundcolor green
    $result = [xml](New-Object System.Net.WebClient).DownloadString($link)
    $latest = $result.rss.channel.item.link[0]
    $filename = $latest.split("/")[-2]
    return $filename
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

#
# Main script entry point
#
if (Test-Admin) {
    write-host "Running script with administrator privileges" -foregroundcolor yellow
}
else {
    write-host "Running script without administrator privileges" -foregroundcolor red
}

$arch = (Get-Arch).FileType
$remoteName = Get-Latest $arch

if ((ExtractGitFromFile) -match (ExtractGitFromURL $remoteName))
{
    write-host "You are already using latest mpv build" -foregroundcolor green
}
else
{
    write-host "Newer mpv build available" -foregroundcolor green
    try
    {
        Download-Mpv $remoteName
        Check7z
        Extract-Mpv $remoteName
    }
    catch
    {
        write-host $_.Exception.Message -foregroundcolor red
        exit 1
    }
}