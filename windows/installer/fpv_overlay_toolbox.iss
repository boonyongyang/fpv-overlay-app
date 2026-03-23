#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

#ifndef MyAppDir
  #error MyAppDir must be provided by the packaging script.
#endif

#ifndef MyOutputDir
  #define MyOutputDir "dist\windows"
#endif

#define MyAppName "FPV Overlay Toolbox"
#define MyAppPublisher "FPV Overlay Toolbox"
#define MyAppExeName "fpv-overlay-toolbox.exe"
#define MyInstallerBaseName "fpv-overlay-toolbox-windows-" + MyAppVersion + "-setup"

[Setup]
AppId={{B9A2177A-152C-4A62-9A0D-65E390B296A9}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\FPV Overlay Toolbox
DefaultGroupName=FPV Overlay Toolbox
DisableProgramGroupPage=yes
OutputDir={#MyOutputDir}
OutputBaseFilename={#MyInstallerBaseName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#MyAppDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\FPV Overlay Toolbox"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\FPV Overlay Toolbox"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch FPV Overlay Toolbox"; Flags: nowait postinstall skipifsilent
