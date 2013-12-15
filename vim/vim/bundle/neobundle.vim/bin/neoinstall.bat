@echo off
FOR /F "usebackq" %%t IN (`where vim`) DO SET _VIM=%%t
set VIM=%_VIM:\vim.exe=%
set _VIMRC=%HOME%\_vimrc
if exist %_VIMRC% goto EXEC_NEOBUNDLE_INSTALL
if not exist %_VIMRC% goto DOTVIMRC

:DOTVIMRC
set VIMRC=%HOME%\.vimrc
if exist %VIMRC% goto EXEC_NEOBUNDLE_INSTALL
if not exist %VIMRC% goto VIMFILES

:VIMFILES
set VIMRC=%HOME%\vimfiles\vimrc
if exist %VIMRC% goto EXEC_NEOBUNDLE_INSTALL
if not exist %VIMRC% goto ORIGIN_VIM

:ORIGIN_VIM
set VIMRC=%VIM%\_vimrc
if exist %VIMRC% goto EXEC_NEOBUNDLE_INSTALL
if not exist %VIMRC% goto NO_EXEC_NEOBUNDLE_INSTALL

@echo on
:EXEC_NEOBUNDLE_INSTALL
vim -N -u %VIMRC% -c "try | NeoBundleInstall! %* | finally | qall! | endtry" -U NONE -i NONE -V1 -e -s


:NO_EXEC_NEOBUNDLE_INSTALL
echo 'vimrc is NotFound.'
