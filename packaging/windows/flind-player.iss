; Inno Setup script for Flind Player (Windows x64).
;
; Build (from the repository root):
;   ISCC.exe /DVersion=0.5.0 /DTag=v0.5.0 /DSourceDir=build\windows\x64\runner\Release packaging\windows\flind-player.iss
;
; Requires Inno Setup 7.x (x64compatible / PrivilegesRequiredOverridesAllowed).

#ifndef Version
  #error Version is required (pass /DVersion=x.y.z)
#endif
#ifndef Tag
  #define Tag "dev"
#endif
#ifndef SourceDir
  #define SourceDir "build\windows\x64\runner\Release"
#endif

#define AppName "Flind Player"
#define AppExe "flind_player.exe"
#define AppUrl "https://github.com/Q-wind520/flind-player"

[Setup]
AppId={{bb0bd0c2-8d74-42cd-bf62-e6d298019c44}
AppName={#AppName}
AppVersion={#Version}
AppVerName={#AppName} {#Version}
AppPublisher=top.qwind.app
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=FlindPlayer-{#Tag}-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
LicenseFile=..\..\LICENSE
SetupIconFile=..\..\docs\FlindPlayer.ico
UninstallDisplayIcon={app}\{#AppExe}
DisableDirPage=auto

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
