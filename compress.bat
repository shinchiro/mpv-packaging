@echo OFF

cd /d "%~dp0"
for %%A in (%*) do (
    7za a -m0=lzma2 -mx=9 -ms=on "%%~nxA.7z" "%%~fA\*"
)
