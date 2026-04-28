@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title TrollVNC - Kết nối điều khiển iOS từ xa

:MENU
cls

:: Load config nếu có
set "CFG=%~dp0TrollVNC-Connect.cfg"
set "SAVED_HOST="
set "SAVED_PORT="
if exist "!CFG!" (
    for /f "tokens=1,2 delims==" %%a in ('type "!CFG!"') do (
        if "%%a"=="HOST" set "SAVED_HOST=%%b"
        if "%%a"=="PORT" set "SAVED_PORT=%%b"
    )
)

echo ============================================================
echo   TrollVNC - Kết nối điều khiển iOS từ xa
echo ============================================================
if defined SAVED_HOST (
    echo   [Đã lưu] !SAVED_HOST!:!SAVED_PORT! -- nhấn Enter để kết nối nhanh
)
echo.
echo  [1] Kết nối VNC thông thường (LAN)
echo  [2] Kết nối qua trình duyệt (noVNC / HTTP)
echo  [3] Kết nối Reverse VNC (TrollVNC gọi ra ngoài)
echo  [4] Cài đặt VNC Viewer (tải TightVNC)
echo  [5] Hướng dẫn sử dụng
echo  [6] Thoát
echo.
set /p CHOICE=Chọn [1-6]: 

:: Nhấn Enter = kết nối nhanh với host đã lưu
if "!CHOICE!"=="" (
    if defined SAVED_HOST (
        set "VNC_HOST=!SAVED_HOST!"
        set "VNC_PORT=!SAVED_PORT!"
        goto LAUNCH_VIEWER
    )
)

if "!CHOICE!"=="1" goto CONNECT_VNC
if "!CHOICE!"=="2" goto CONNECT_WEB
if "!CHOICE!"=="3" goto REVERSE_VNC
if "!CHOICE!"=="4" goto INSTALL_VIEWER
if "!CHOICE!"=="5" goto HELP
if "!CHOICE!"=="6" goto EXIT
goto MENU

:: ============================================================
:CONNECT_VNC
cls
echo ============================================================
echo   Kết nối VNC thông thường
echo ============================================================
echo.
echo [*] Đang quét thiết bị trong mạng LAN...
echo     (Có thể mất 10-20 giây)
echo.

:: Lấy tất cả IP, ưu tiên WiFi/Ethernet thật (loại bỏ VMware/VirtualBox/loopback)
set "LOCAL_IP="
set "SUBNET="

for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set "TMP_IP=%%a"
    set "TMP_IP=!TMP_IP: =!"
    :: Bỏ qua loopback và VMware (thường 192.168.112.x, 192.168.56.x, 172.x)
    echo !TMP_IP! | findstr /r "^192\.168\.112\. ^192\.168\.56\. ^172\. ^127\." >nul 2>&1
    if !errorlevel! neq 0 (
        if "!LOCAL_IP!"=="" set "LOCAL_IP=!TMP_IP!"
    )
)

:: Fallback: lấy IP đầu tiên nếu không tìm được
if "!LOCAL_IP!"=="" (
    for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4" ^| findstr /v "127.0.0.1"') do (
        if "!LOCAL_IP!"=="" (
            set "LOCAL_IP=%%a"
            set "LOCAL_IP=!LOCAL_IP: =!"
        )
    )
)

for /f "tokens=1-3 delims=." %%a in ("!LOCAL_IP!") do set "SUBNET=%%a.%%b.%%c"

if "!SUBNET!"=="" (
    echo [!] Không xác định được subnet. Nhập IP thủ công.
    goto MANUAL_IP
)

echo [*] IP máy tính: !LOCAL_IP!
echo [*] Subnet: !SUBNET!.0/24
echo.

:: Quét ARP cache (nhanh, không cần ping từng IP)
set COUNT=0
echo     Thiết bị tìm thấy trong mạng:
echo     --------------------------------
for /f "tokens=1" %%i in ('arp -a ^| findstr /r " [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]* "') do (
    echo %%i | findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul 2>&1
    if !errorlevel!==0 (
        echo %%i | findstr "^!SUBNET!" >nul 2>&1
        if !errorlevel!==0 (
            echo %%i | findstr "\.255$" >nul 2>&1
            if !errorlevel! neq 0 (
                set /a COUNT+=1
                set "IP_!COUNT!=%%i"
                echo     [!COUNT!] %%i
            )
        )
    )
)

if !COUNT!==0 (
    echo [!] Không tìm thấy thiết bị nào trong ARP cache.
    echo     Hãy đảm bảo iPhone đang kết nối cùng WiFi với máy tính.
    echo.
    goto MANUAL_IP
)

echo     --------------------------------
echo     [0] Nhập IP thủ công
echo.

if !COUNT!==0 goto MANUAL_IP

set /p SCAN_CHOICE=Chọn thiết bị [0-!COUNT!]: 

if "!SCAN_CHOICE!"=="0" goto MANUAL_IP
if "!SCAN_CHOICE!"=="" goto MANUAL_IP

:: Validate lựa chọn
set "VNC_HOST=!IP_%SCAN_CHOICE%!"
if "!VNC_HOST!"=="" (
    echo [!] Lựa chọn không hợp lệ.
    pause
    goto CONNECT_VNC
)
echo.
echo [*] Đã chọn: !VNC_HOST!
goto ASK_PORT

:MANUAL_IP
set /p VNC_HOST=Nhập địa chỉ IP của thiết bị iOS (vd: 192.168.1.100): 
if "!VNC_HOST!"=="" (
    echo [!] Địa chỉ IP không được để trống.
    pause
    goto CONNECT_VNC
)

:ASK_PORT
:: Gợi ý port từ config đã lưu
set "DEFAULT_PORT=5901"
if defined SAVED_PORT set "DEFAULT_PORT=!SAVED_PORT!"

set /p VNC_PORT=Nhập cổng VNC (mặc định !DEFAULT_PORT!, Enter để dùng mặc định): 
if "!VNC_PORT!"=="" set "VNC_PORT=!DEFAULT_PORT!"

echo.
echo  Preset kết nối:
echo   [1] LAN tốc độ cao (chất lượng cao, ít nén)
echo   [2] Tiết kiệm băng thông (WAN / 4G)
echo   [3] Thiết bị cũ (CPU yếu)
echo   [4] Tùy chỉnh
echo.
set /p PRESET=Chọn preset [1-4]: 

if "%PRESET%"=="1" set PRESET_NAME=LAN tốc độ cao
if "%PRESET%"=="2" set PRESET_NAME=Tiết kiệm băng thông
if "%PRESET%"=="3" set PRESET_NAME=Thiết bị cũ
if "%PRESET%"=="4" set PRESET_NAME=Tùy chỉnh

echo.
echo [*] Đang kết nối tới !VNC_HOST!:!VNC_PORT! (Preset: !PRESET_NAME!)...
echo.

:LAUNCH_VIEWER
:: Lưu config
echo HOST=!VNC_HOST!> "!CFG!"
echo PORT=!VNC_PORT!>> "!CFG!"

:: Kiểm tra TightVNC Viewer
set "TVNC_PATH="
if exist "%ProgramFiles%\TightVNC\tvnviewer.exe" set "TVNC_PATH=%ProgramFiles%\TightVNC\tvnviewer.exe"
if exist "%ProgramFiles(x86)%\TightVNC\tvnviewer.exe" set "TVNC_PATH=%ProgramFiles(x86)%\TightVNC\tvnviewer.exe"

:: Kiểm tra UltraVNC Viewer
set "UVNC_PATH="
if exist "%ProgramFiles%\uvnc bvba\UltraVNC\vncviewer.exe" set "UVNC_PATH=%ProgramFiles%\uvnc bvba\UltraVNC\vncviewer.exe"
if exist "%ProgramFiles(x86)%\uvnc bvba\UltraVNC\vncviewer.exe" set "UVNC_PATH=%ProgramFiles(x86)%\uvnc bvba\UltraVNC\vncviewer.exe"

:: Kiểm tra RealVNC Viewer
set "RVNC_PATH="
if exist "%ProgramFiles%\RealVNC\VNC Viewer\vncviewer.exe" set "RVNC_PATH=%ProgramFiles%\RealVNC\VNC Viewer\vncviewer.exe"
if exist "%ProgramFiles(x86)%\RealVNC\VNC Viewer\vncviewer.exe" set "RVNC_PATH=%ProgramFiles(x86)%\RealVNC\VNC Viewer\vncviewer.exe"

if defined TVNC_PATH (
    echo [*] Dùng TightVNC Viewer...
    start "" "%TVNC_PATH%" %VNC_HOST%::%VNC_PORT%
    goto CONNECT_VNC_DONE
)

if defined UVNC_PATH (
    echo [*] Dùng UltraVNC Viewer...
    start "" "%UVNC_PATH%" %VNC_HOST%::%VNC_PORT%
    goto CONNECT_VNC_DONE
)

if defined RVNC_PATH (
    echo [*] Dùng RealVNC Viewer...
    start "" "%RVNC_PATH%" %VNC_HOST%:%VNC_PORT%
    goto CONNECT_VNC_DONE
)

echo [!] Không tìm thấy VNC Viewer đã cài.
echo     Vui lòng cài TightVNC hoặc UltraVNC (chọn mục 4).
echo     Hoặc mở trình duyệt và truy cập: http://%VNC_HOST%:5801
echo.
pause
goto MENU

:CONNECT_VNC_DONE
echo [OK] Đã mở VNC Viewer. Nhập mật khẩu nếu được yêu cầu.
pause
goto MENU

:: ============================================================
:CONNECT_WEB
cls
echo ============================================================
echo   Kết nối qua trình duyệt (noVNC)
echo ============================================================
echo.
echo  Yêu cầu: TrollVNC phải được khởi động với tùy chọn -H (HTTP port).
echo  Ví dụ trên iOS: trollvncserver -p 5901 -H 5801
echo.
set /p WEB_HOST=Nhập địa chỉ IP của thiết bị iOS (vd: 192.168.1.100): 
if "%WEB_HOST%"=="" (
    echo [!] Địa chỉ IP không được để trống.
    pause
    goto CONNECT_WEB
)

set /p WEB_PORT=Nhập cổng HTTP (mặc định 5801, Enter để dùng mặc định): 
if "%WEB_PORT%"=="" set WEB_PORT=5801

set /p USE_HTTPS=Dùng HTTPS/WSS? (y/N): 
if /i "%USE_HTTPS%"=="y" (
    set WEB_URL=https://%WEB_HOST%:%WEB_PORT%/
) else (
    set WEB_URL=http://%WEB_HOST%:%WEB_PORT%/
)

echo.
echo [*] Đang mở trình duyệt tới: %WEB_URL%
start "" "%WEB_URL%"
echo [OK] Trình duyệt đã được mở. Nhập mật khẩu nếu được yêu cầu.
pause
goto MENU

:: ============================================================
:REVERSE_VNC
cls
echo ============================================================
echo   Reverse VNC - Chờ thiết bị iOS kết nối vào máy này
echo ============================================================
echo.
echo  Chế độ này: máy tính Windows LẮNG NGHE, thiết bị iOS GỌI RA.
echo  Hữu ích khi iOS ở sau NAT/firewall.
echo.
echo  Bước 1: Chạy script này để mở cổng lắng nghe.
echo  Bước 2: Trên iOS, chạy lệnh:
echo          trollvncserver -reverse ^<IP_may_tinh^>:5500 -n "My iPhone"
echo.

set /p LISTEN_PORT=Nhập cổng lắng nghe (mặc định 5500, Enter để dùng mặc định): 
if "%LISTEN_PORT%"=="" set LISTEN_PORT=5500

:: Kiểm tra UltraVNC (hỗ trợ Listen mode tốt nhất)
set "UVNC_PATH="
if exist "%ProgramFiles%\uvnc bvba\UltraVNC\vncviewer.exe" set "UVNC_PATH=%ProgramFiles%\uvnc bvba\UltraVNC\vncviewer.exe"
if exist "%ProgramFiles(x86)%\uvnc bvba\UltraVNC\vncviewer.exe" set "UVNC_PATH=%ProgramFiles(x86)%\uvnc bvba\UltraVNC\vncviewer.exe"

if defined UVNC_PATH (
    echo.
    echo [*] Đang mở UltraVNC ở chế độ Listen trên cổng %LISTEN_PORT%...
    start "" "%UVNC_PATH%" -listen %LISTEN_PORT%
    echo [OK] UltraVNC đang lắng nghe. Hãy khởi động TrollVNC trên iOS.
    pause
    goto MENU
)

:: Kiểm tra TightVNC
set "TVNC_PATH="
if exist "%ProgramFiles%\TightVNC\tvnviewer.exe" set "TVNC_PATH=%ProgramFiles%\TightVNC\tvnviewer.exe"
if exist "%ProgramFiles(x86)%\TightVNC\tvnviewer.exe" set "TVNC_PATH=%ProgramFiles(x86)%\TightVNC\tvnviewer.exe"

if defined TVNC_PATH (
    echo.
    echo [*] Đang mở TightVNC ở chế độ Listen trên cổng %LISTEN_PORT%...
    start "" "%TVNC_PATH%" -listen %LISTEN_PORT%
    echo [OK] TightVNC đang lắng nghe. Hãy khởi động TrollVNC trên iOS.
    pause
    goto MENU
)

echo [!] Không tìm thấy UltraVNC hoặc TightVNC.
echo     Vui lòng cài đặt (chọn mục 4) để dùng Reverse VNC.
pause
goto MENU

:: ============================================================
:INSTALL_VIEWER
cls
echo ============================================================
echo   Tải VNC Viewer
echo ============================================================
echo.
echo  [1] Tải TightVNC (khuyến nghị cho kết nối thông thường)
echo  [2] Tải UltraVNC (khuyến nghị cho Reverse VNC / Repeater)
echo  [3] Quay lại
echo.
set /p DL_CHOICE=Chọn [1-3]: 

if "%DL_CHOICE%"=="1" (
    echo [*] Đang mở trang tải TightVNC...
    start "" "https://www.tightvnc.com/download.php"
    pause
    goto MENU
)
if "%DL_CHOICE%"=="2" (
    echo [*] Đang mở trang tải UltraVNC...
    start "" "https://uvnc.com/downloads/ultravnc.html"
    pause
    goto MENU
)
goto MENU

:: ============================================================
:HELP
cls
echo ============================================================
echo   Hướng dẫn sử dụng TrollVNC
echo ============================================================
echo.
echo  THIẾT LẬP TRÊN iOS:
echo  --------------------
echo  1. Cài TrollVNC từ Havoc hoặc build từ source.
echo  2. Vào Settings ^> TrollVNC để cấu hình.
echo  3. Hoặc chạy lệnh trên iOS:
echo.
echo     Cơ bản:
echo       trollvncserver -p 5901 -n "My iPhone"
echo.
echo     LAN tốc độ cao:
echo       trollvncserver -p 5901 -n "My iPhone" -s 0.75 -d 0.008 -Q 1 -t 32 -P 35
echo.
echo     Tiết kiệm băng thông (WAN/4G):
echo       trollvncserver -p 5901 -n "My iPhone" -s 0.5 -d 0.025 -Q 2 -t 64 -P 50
echo.
echo     Với HTTP/noVNC (trình duyệt):
echo       trollvncserver -p 5901 -H 5801 -n "My iPhone"
echo.
echo     Với mật khẩu:
echo       export TROLLVNC_PASSWORD=matkhau
echo       trollvncserver -p 5901 -n "My iPhone"
echo.
echo  KẾT NỐI TỪ WINDOWS:
echo  --------------------
echo  - VNC Viewer: nhập ^<IP_iOS^>:5901
echo  - Trình duyệt: http://^<IP_iOS^>:5801
echo  - Reverse: chạy UltraVNC/TightVNC ở Listen mode, rồi
echo              chạy TrollVNC với -reverse ^<IP_Windows^>:5500
echo.
echo  CỔNG MẶC ĐỊNH:
echo  --------------------
echo  - VNC:  5901
echo  - HTTP: 5801
echo  - Reverse Listen: 5500
echo.
pause
goto MENU

:: ============================================================
:EXIT
cls
echo Tạm biệt!
timeout /t 2 >nul
exit /b 0
