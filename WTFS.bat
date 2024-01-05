@echo off
setlocal enabledelayedexpansion
:time_reconnect
:: echo 시간 동기화를 시작합니다.
setlocal enabledelayedexpansion
:: echo NIST에서 시간을 불러옵니다..
:: PowerShell 스크립트를 임시 파일로 생성
echo $NtpData = New-Object byte[] 48 > temp.ps1
echo $Address = [System.Net.Dns]::GetHostAddresses("time.nist.gov")[0] >> temp.ps1
echo $NtpData[0] = 0x1B >> temp.ps1
echo $AddressEndPoint = New-Object System.Net.IPEndPoint $Address, 123 >> temp.ps1
echo $UdpClient = New-Object System.Net.Sockets.UdpClient >> temp.ps1
echo $UdpClient.Connect($AddressEndPoint) >> temp.ps1
echo $UdpClient.Send($NtpData, $NtpData.Length) >> temp.ps1
echo $NtpData = $UdpClient.Receive([ref]$AddressEndPoint) >> temp.ps1
echo $IntPart = [BitConverter]::ToUInt32($NtpData[43..40], 0) >> temp.ps1
echo $FracPart = [BitConverter]::ToUInt32($NtpData[47..44], 0) >> temp.ps1
echo $UnixTime = $IntPart - 2208988800 >> temp.ps1
echo $Ms = ($FracPart * 1000) / 0x100000000 >> temp.ps1
echo $Result = (Get-Date "1970-01-01 00:00:00").AddSeconds($UnixTime).AddMilliseconds($Ms).ToLocalTime() >> temp.ps1
echo $Year = $Result.Year >> temp.ps1
echo $Month = $Result.Month >> temp.ps1
echo $Day = $Result.Day >> temp.ps1
echo $Hour = $Result.Hour >> temp.ps1
echo $Minute = $Result.Minute >> temp.ps1
echo $Second = $Result.Second >> temp.ps1
echo Write-Host "$Year,$Month,$Day,$Hour,$Minute,$Second" >> temp.ps1

:: PowerShell 스크립트 실행 및 결과 캡쳐
for /f "tokens=1-6 delims=," %%a in ('powershell -executionpolicy bypass -File temp.ps1') do (
    set Year=%%a
    set Month=%%b
    set Day=%%c
    set Hour=%%d
    set Minute=%%e
    set Second=%%f
)
:: 임시 PowerShell 스크립트 삭제
del temp.ps1

if "%Year%" == "1900" (
echo 서버 연결에 실패하였습니다. 잠시 후 다시 시도합니다.
%SystemRoot%\System32\timeout.exe 3 > nul
goto time_reconnect
)
:: echo [NIST 서버 응답]
:: echo 일자 : !Year!년 !Month!월 !Day!일
:: echo 시간 : !Hour!시 !Minute!분 !Second!초
time !Hour!:!Minute!:!Second!
date !Year!-!Month!-!Day!
:: echo 수동 동기화를 완료하였습니다.
endlocal

%SystemRoot%\System32\timeout.exe 5 > nul
:: echo 정확한 시간 설정을 위해 자동 동기화를 진행합니다.
echo.
:: echo 시간 동기화를 시작합니다.
:: echo 서버 : NIST서버
net start w32time
setlocal enabledelayedexpansion
:time_retry
:: 시간 서버 설정
w32tm /config /manualpeerlist:time.nist.gov,0x8 /syncfromflags:manual /update > nul

:: 시간 동기화 및 결과 확인
for /f "delims=" %%i in ('w32tm /resync 2^>^&1') do (
    set "line=%%i"
    if "!line!" == "사용 가능한 시간 데이터가 없어 컴퓨터가 동기화하지 못했습니다." (
        echo 동기화 실패, 다시 시도합니다.
        goto time_retry
    )
)
endlocal

echo 시간 동기화가 완료되었습니다.
echo 아무 키나 누르면 종료됩니다.
pause > nul
