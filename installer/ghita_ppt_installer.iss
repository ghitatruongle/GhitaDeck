; GhitaPPT Converter - Inno Setup definition
; Version values are supplied by build_installer.ps1 from pubspec.yaml.

#define MyAppName "GhitaPPT Converter"
#ifndef MyAppVersion
  #define MyAppVersion "2.0.0"
#endif
#ifndef MyAppBuild
  #define MyAppBuild "1"
#endif
#ifndef MyAppDisplayVersion
  #define MyAppDisplayVersion "2.0.0-beta+1"
#endif
#define MyAppPublisher "Ghita"
#define MyAppURL "https://github.com/ghitatruongle/GhitaPowerPointConverter"
#define MyAppExeName "ghita_ppt_converter.exe"
#define MyAppCopyright "Copyright (C) 2026 Ghita"
#define MyAppDescription "PowerPoint creator with AI integration"

[Setup]
AppId={{A3F8E1C2-5B7D-4E9A-B6C1-2D3F4A5B6C7D}
AppName={#MyAppName}
AppVersion={#MyAppDisplayVersion}
AppVerName={#MyAppName} {#MyAppDisplayVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppCopyright={#MyAppCopyright}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=GhitaPPT-Setup-{#MyAppDisplayVersion}
SetupIconFile=app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=110
DisableWelcomePage=no
PrivilegesRequired=lowest
Uninstallable=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersion}.{#MyAppBuild}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppDescription}
VersionInfoCopyright={#MyAppCopyright}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}.{#MyAppBuild}
CloseApplications=yes
RestartApplications=no
MinVersion=10.0.17763
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
