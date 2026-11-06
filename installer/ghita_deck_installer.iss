; Version values are supplied by build_installer.ps1 from pubspec.yaml.

#define MyAppName "GhitaDeck"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.1"
#endif
#ifndef MyAppBuild
  #define MyAppBuild "1"
#endif
#ifndef MyAppDisplayVersion
  #define MyAppDisplayVersion "0.0.1+1"
#endif
#ifndef MyAppFileBase
  #define MyAppFileBase "0.0.1"
#endif
#define MyAppPublisher "Ghita"
#define MyAppURL "https://github.com/ghitatruongle/GhitaDeck"
#define MyAppExeName "ghita_deck.exe"
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
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; T18.2: the directory page is ALWAYS shown (the user can pick any location),
; and upgrades default to the directory chosen previously.
DisableDirPage=no
AllowNoIcons=yes
UsePreviousAppDir=yes
OutputDir=output
OutputBaseFilename=GhitaDeck-Setup-{#MyAppFileBase}
SetupIconFile=app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=110
DisableWelcomePage=no
; Default install = Program Files (system-wide, UAC); the wizard still lets the
; user browse to any custom directory and, via the override dialog, install
; per-user on machines without admin rights (T18.2).
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
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
; Vietnamese is the default wizard language (the app is VI-primary); Inno
; Setup ships no Vietnamese .isl, so the visible strings are overridden in
; [Messages] below. English stays selectable and uses Default.isl as-is.
Name: "vietnamese"; MessagesFile: "compiler:Default.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
; T18.3: auto-start is OPT-IN — unchecked by default; the Run key is written
; only when the user ticks it.
Name: "autostart"; Description: "Khởi động GhitaDeck cùng Windows"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: files; Name: "{app}\ghita_ppt_converter.exe"
Type: files; Name: "{group}\GhitaPPT Converter.lnk"
Type: files; Name: "{group}\Uninstall GhitaPPT Converter.lnk"

[Icons]
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

[Registry]
; T18.3: opt-in auto-start. The Run key belongs to the USER who logs in, not
; the elevated admin account, so HKCU is correct here (Inno resolves HKCU to
; the original interactive user even in admin install mode — the
; UsedUserAreasWarning below is expected and benign). uninsdeletevalue keeps
; the key tidy when the app is uninstalled.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; T18.5: Group B only — regenerable data. User data (Group A: documents,
; drafts, narration audio, preferences + AI keys) is never touched here; the
; optional removal branch lives in [Code] and defaults to "keep".
Type: filesandordirs; Name: "{localappdata}\GhitaPPT\image_cache"
Type: files; Name: "{userappdata}\GhitaPPT\engine.log"
Type: filesandordirs; Name: "{localappdata}\GhitaDeck\image_cache"
Type: files; Name: "{userappdata}\GhitaDeck\engine.log"

[Code]
// T18 — installer polish: free-space precheck, opt-in user-data removal on
// uninstall, and a report the verification script can assert against.
//
// Data groups (see installer/README.md): Group A is kept unless the user
// opts in; Group B is always removed. Both folder-name generations are listed.

const
  // ~300 MB: comfortably above the ~160 MB install size, so a nearly-full disk
  // is caught before half the files are copied.
  MinFreeBytes = 300 * 1024 * 1024;

var
  RemoveUserData: Boolean;

function InitializeSetup(): Boolean;
var
  FreeBytes, TotalBytes: Int64;
begin
  Result := True;
  if GetSpaceOnDisk64(ExpandConstant('{sd}'), FreeBytes, TotalBytes) then
  begin
    if FreeBytes < MinFreeBytes then
    begin
      if MsgBox('Ổ đĩa còn ít dung lượng trống (' +
                IntToStr(FreeBytes div (1024 * 1024)) + ' MB).' + #13#10 +
                'GhitaDeck cần khoảng 300 MB để cài đặt.' + #13#10#13#10 +
                'Vẫn tiếp tục?', mbConfirmation, MB_YESNO) = IDNO then
        Result := False;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    RegDeleteValue(HKEY_CURRENT_USER,
      'Software\Microsoft\Windows\CurrentVersion\Run', 'GhitaPPT Converter');
    RegDeleteValue(HKEY_CURRENT_USER,
      'Software\Microsoft\Windows\CurrentVersion\Run', 'GhitaPPT');
  end;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
  RemoveUserData := False;
  // Silent uninstall keeps user data — never destroy documents without an
  // explicit answer.
  if not UninstallSilent then
    RemoveUserData := MsgBox(
      'Gỡ GhitaDeck?' + #13#10#13#10 +
      'Dữ liệu của bạn (deck, ghi chú, bản nháp, cài đặt và API key) sẽ được GIỮ LẠI.' + #13#10#13#10 +
      'Chọn "Có" để xoá TOÀN BỘ dữ liệu người dùng kèm theo.' + #13#10 +
      'Chọn "Không" để chỉ gỡ ứng dụng và giữ nguyên dữ liệu.',
      mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    // Group B — always safe to remove (regenerated on the next launch).
    DelTree(ExpandConstant('{localappdata}\GhitaDeck\image_cache'), True, True, True);
    DeleteFile(ExpandConstant('{userappdata}\GhitaDeck\engine.log'));
    RemoveDir(ExpandConstant('{userappdata}\GhitaDeck'));

    DelTree(ExpandConstant('{localappdata}\GhitaPPT\image_cache'), True, True, True);
    DeleteFile(ExpandConstant('{userappdata}\GhitaPPT\engine.log'));
    RemoveDir(ExpandConstant('{userappdata}\GhitaPPT'));

    if RemoveUserData then
    begin
      // Group A — only after the explicit opt-in above.
      DelTree(ExpandConstant('{userdocs}\GhitaDeck'), True, True, True);
      DelTree(ExpandConstant('{userdocs}\GhitaPPT'), True, True, True);
      DelTree(ExpandConstant('{userappdata}\Ghita\GhitaDeck'),
              True, True, True);
      DelTree(ExpandConstant('{userappdata}\Ghita\GhitaPPT Converter'),
              True, True, True);
    end;
  end;
end;

[Messages]
; Only the "vietnamese" entry needs overrides; "english" falls back to
; compiler:Default.isl in full.
vietnamese.SetupAppTitle=Trình cài đặt GhitaDeck
vietnamese.SetupWindowTitle=Trình cài đặt %1
vietnamese.WelcomeLabel1=Chào mừng đến với trình cài đặt GhitaDeck
vietnamese.WelcomeLabel2=Trình cài đặt sẽ cài [name/ver] lên máy của bạn.%n%nNên đóng các ứng dụng khác trước khi tiếp tục.
vietnamese.ExitSetupTitle=Thoát trình cài đặt
vietnamese.ExitSetupMessage=Chưa cài xong. Nếu thoát bây giờ, ứng dụng sẽ không được cài đặt.%n%nVẫn thoát?
vietnamese.ButtonYes=&Có
vietnamese.ButtonNo=&Không
vietnamese.SelectDirDesc=Chọn thư mục để cài đặt GhitaDeck.
vietnamese.SelectDirLabel3=Trình cài đặt sẽ cài [name] vào thư mục sau.
vietnamese.SelectDirBrowseLabel=Bấm "Tiếp" để dùng thư mục này. Nếu muốn đổi, bấm "Duyệt...".
vietnamese.SelectTasksDesc=Chọn các tác vụ bổ sung cần thực hiện khi cài đặt.
vietnamese.SelectTasksLabel2=Chọn các tác vụ bổ sung mà trình cài đặt sẽ thực hiện, sau đó bấm "Tiếp".
vietnamese.ReadyLabel1=Trình cài đặt đã sẵn sàng cài [name] lên máy của bạn.
vietnamese.ReadyLabel2a=Bấm "Cài đặt" để bắt đầu, hoặc bấm "Quay lại" nếu muốn xem lại các thiết lập.
vietnamese.InstallingLabel=Đang cài [name], vui lòng chờ...
vietnamese.FinishedHeadingLabel=Hoàn tất cài đặt [name]
vietnamese.FinishedLabel=Trình cài đặt đã cài xong [name] lên máy của bạn.
vietnamese.FinishedLabelNoIcons=Trình cài đặt đã cài xong [name] lên máy của bạn.
vietnamese.ConfirmUninstall=Bạn có chắc muốn gỡ hoàn toàn %1 và tất cả các thành phần của nó?
vietnamese.UninstallStatusLabel=Đang gỡ %1 khỏi máy của bạn, vui lòng chờ...
vietnamese.UninstalledAll=%1 đã được gỡ khỏi máy của bạn.
vietnamese.ErrorTitle=Lỗi
vietnamese.SetupFileCorrupt=Tệp cài đặt bị hỏng, không thể tiếp tục.
