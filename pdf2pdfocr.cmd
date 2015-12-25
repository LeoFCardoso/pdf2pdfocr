@ECHO off
::
:: This cmd script must be used in Windows installations (Cygwin)
:: to let the final user use the "Send To" menu option in Windows Explorer.
:: Please copy it to a desired location and create a shortcut in SendTo folder
:: Ref.: http://www.howtogeek.com/howto/windows-vista/customize-the-windows-vista-send-to-menu/
::
@rem Query Registry for Cygwin install dir (Local Machine and Current Users)
SETLOCAL ENABLEEXTENSIONS
SET KEY_NAME=HKEY_LOCAL_MACHINE\SOFTWARE\Cygwin\setup
SET VALUE_NAME=rootdir
FOR /F "usebackq skip=2 tokens=1-2*" %%A IN (`REG QUERY %KEY_NAME% /v %VALUE_NAME% 2^>nul`) DO (
	SET CYGWIN_PATH=%%C
)
IF NOT defined CYGWIN_PATH (
	SET KEY_NAME=HKEY_CURRENT_USER\SOFTWARE\Cygwin\setup
	FOR /F "usebackq skip=2 tokens=1-2*" %%A IN (`REG QUERY %KEY_NAME% /v %VALUE_NAME% 2^>nul`) DO (
		SET CYGWIN_PATH=%%C
	)
)
@rem echo Cygwin Path is %CYGWIN_PATH%
:Loop_Param
SET FILE_NAME=%1
IF NOT [%FILE_NAME%]==[] (
	ECHO Processing %FILE_NAME%
	FOR /F "delims=" %%Z IN ('%CYGWIN_PATH%\bin\cygpath.exe -au %FILE_NAME%') DO (
		%CYGWIN_PATH%\bin\bash.exe --login pdf2pdfocr.sh -st "%%Z" | MORE
	)
	ECHO --------------------------------------------------------------------
	SHIFT
	GOTO :Loop_Param
)
@rem
PAUSE