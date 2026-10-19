#ifndef AppSource
  #error AppSource must point at the published application folder
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
[Setup]
AppId={{71FE70EC-FB68-4D29-B05B-9D18671D3B89}
AppName=MacDictate
AppVersion=1.6.0
AppPublisher=Alexander Fisenkov
AppPublisherURL=https://alexfisenkov.github.io/MacDictate/
DefaultDirName={localappdata}\Programs\MacDictate
DefaultGroupName=MacDictate
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
OutputDir={#OutputDir}
OutputBaseFilename=MacDictate_Windows_v1.6.0_x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\MacDictate.exe
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
Source: "{#AppSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MacDictate"; Filename: "{app}\MacDictate.exe"
Name: "{autodesktop}\MacDictate"; Filename: "{app}\MacDictate.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\MacDictate.exe"; Description: "{cm:LaunchProgram,MacDictate}"; Flags: nowait postinstall skipifsilent
