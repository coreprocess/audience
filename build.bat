@echo off

rem go to project directory
set AUDIENCE_PROJECT_ROOT=%~dp0
echo AUDIENCE_PROJECT_ROOT=%AUDIENCE_PROJECT_ROOT%
cd %AUDIENCE_PROJECT_ROOT% || goto :error

rem read build type
set CMAKE_BUILD_TYPE=%1
for %%G in (Debug,Release,RelWithDebInfo,MinSizeRel) do (
  if "%CMAKE_BUILD_TYPE%" == "%%G" goto :build
)
echo Usage: %~0 ^<Debug^|Release^|RelWithDebInfo^|MinSizeRel^>
exit 1

:build

rem build frontend integration
cd .\integrations\frontend || goto :error
call npm install || goto :error

rem go back to project directory
cd %AUDIENCE_PROJECT_ROOT% || goto :error

rem create build directory
if not exist ".\build" mkdir ".\build" || goto :error
cd ".\build" || goto :error

rem initialize cmake cache
if not exist .\CMakeCache.txt cmake -G "Visual Studio 16 2019" -DCMAKE_INSTALL_PREFIX:PATH=..\dist .. || goto :error

rem perform build and install
cmake --build . --config "%CMAKE_BUILD_TYPE%" || goto :error
cmake --build . --config "%CMAKE_BUILD_TYPE%" --target install || goto :error

rem go back to project directory
cd %AUDIENCE_PROJECT_ROOT% || goto :error

rem error and success handling
goto :EOF
:error
exit /b %errorlevel%
