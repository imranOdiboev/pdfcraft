; ODIBO PDF engineering installer. Code: MIT OR Apache-2.0.
; The lead packaging step verifies the complete payload before invoking ISCC.
#ifndef PayloadDir
  #error PayloadDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef BuildNumber
  #error BuildNumber is required
#endif
#ifndef BuildCommit
  #error BuildCommit is required
#endif
#define OdiboAppId "{A7A4DC1B-3255-4BC6-9F6F-1DA0B61B6524}"

[Setup]
AppId={{A7A4DC1B-3255-4BC6-9F6F-1DA0B61B6524}
AppName=ODIBO PDF
SetupArchitecture=x64
AppVersion={#AppVersion}
AppVerName=ODIBO PDF {#AppVersion} (test build {#BuildNumber})
AppPublisher=IMR4N
AppPublisherURL=https://github.com/imranOdiboev/pdfcraft
AppSupportURL=https://github.com/imranOdiboev/pdfcraft/blob/main/docs/ODIBO_BUG_REPORT.md
VersionInfoVersion={#AppVersion}
VersionInfoCompany=IMR4N
VersionInfoDescription=ODIBO PDF unsigned engineering test installer
VersionInfoProductName=ODIBO PDF
VersionInfoProductVersion={#AppVersion}
VersionInfoTextVersion={#AppVersion} test {#BuildNumber} {#BuildCommit}
DefaultDirName={localappdata}\Programs\ODIBO PDF
DefaultGroupName=ODIBO PDF
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0
Uninstallable=yes
UninstallDisplayName=ODIBO PDF
UninstallDisplayIcon={app}\odibo-pdf.exe
UsePreviousAppDir=yes
UsePreviousTasks=yes
DirExistsWarning=no
CloseApplications=no
RestartApplications=no
RestartIfNeededByRun=no
SetupMutex=ODIBO.PDF.Setup.A7A4DC1B
SetupIconFile=..\..\assets\odibo\odibo-pdf.ico
WizardStyle=modern
DefaultDialogFontName=Inter
WizardImageFile=
WizardSmallImageFile=
DisableWelcomePage=no
OutputDir={#OutputDir}
OutputBaseFilename=ODIBO-PDF-{#AppVersion}-{#Copy(BuildCommit,1,7)}-Setup-x64
Compression=lzma2
SolidCompression=yes
SetupLogging=yes

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"

[LangOptions]
DialogFontName=Inter
WelcomeFontName=Inter

[CustomMessages]
en.DesktopShortcut=Create a desktop shortcut
ru.DesktopShortcut=Создать ярлык на рабочем столе
en.CloseApp=Close ODIBO PDF and its command-line tools after saving your documents, then try again. Setup will not close them for you.
ru.CloseApp=Сохраните документы, закройте ODIBO PDF и его инструменты командной строки и повторите попытку. Установщик не будет закрывать их автоматически.
en.BadFolder=Choose a new, empty application folder. Do not select a portable copy, a document folder, a profile root, or a system folder.
ru.BadFolder=Выберите новую пустую папку приложения. Не выбирайте portable-копию, папку документов, корень профиля или системную папку.
en.ExistingPath=ODIBO PDF is already installed in another folder. Update that installation in its existing folder.
ru.ExistingPath=ODIBO PDF уже установлен в другой папке. Обновите существующую установку в её текущей папке.
en.LegacyInstall=An earlier machine-wide ODIBO PDF installation was found. Remove it using Windows Settings before installing this per-user test version. Your documents and settings must be kept.
ru.LegacyInstall=Обнаружена прежняя установка ODIBO PDF для всех пользователей. Удалите её через параметры Windows перед установкой этой тестовой версии для текущего пользователя. Сохраните документы и настройки.
en.Downgrade=This installer is older than the installed ODIBO PDF version or build. Use the same build or a newer one.
ru.Downgrade=Этот установщик старее установленной версии или сборки ODIBO PDF. Используйте ту же или более новую сборку.
en.BadMetadata=The installed version information could not be verified. Setup stopped without changing the application. Contact the project with the setup log; do not send personal PDFs.
ru.BadMetadata=Не удалось проверить сведения об установленной версии. Установка остановлена без изменения приложения. Передайте проекту журнал установки; не отправляйте личные PDF.
en.BuildMetadataWriteFailed=Setup could not record the installed build information. The installation is incomplete. Remove ODIBO PDF using Windows Settings and try again. Keep your documents and settings.
ru.BuildMetadataWriteFailed=Не удалось записать сведения об установленной сборке. Установка не завершена. Удалите ODIBO PDF через параметры Windows и повторите попытку. Сохраните документы и настройки.
en.TestNotice=Unsigned engineering test build. No official release, background updater, telemetry or automatic MCP startup. Settings and documents are kept when uninstalling.
ru.TestNotice=Неподписанная инженерная тестовая сборка. Это не официальный релиз. Нет фонового обновления, телеметрии и автоматического запуска MCP. При удалении приложения настройки и документы сохраняются.

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopShortcut}"; Flags: unchecked

[Files]
; Payload is audited independently. No user data or portable markers belong in Setup.
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "portable.txt,ODIBOPDF.portable,ODIBOPDFData,ODIBOPDFData\*,*.pdb,*.part,.git,.git\*,.env,*.pfx,*.key,control.json"

[Icons]
Name: "{userprograms}\ODIBO PDF"; Filename: "{app}\odibo-pdf.exe"; WorkingDir: "{app}"
Name: "{userdesktop}\ODIBO PDF"; Filename: "{app}\odibo-pdf.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Code]
const
  UninstallRoot = 'Software\Microsoft\Windows\CurrentVersion\Uninstall';
  OdiboKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#OdiboAppId}_is1';
  InstallMarker = '.odibo-install-root';
  InstallIdentity = '{#OdiboAppId}';

function NormalPath(const Value: String): String;
begin
  Result := RemoveBackslashUnlessRoot(ExpandFileName(Value));
end;

function SamePath(const A, B: String): Boolean;
begin
  Result := CompareText(NormalPath(A), NormalPath(B)) = 0;
end;

function WithinPath(const Value, Parent: String): Boolean;
begin
  Result := SamePath(Value, Parent) or
    (CompareText(Copy(NormalPath(Value), 1, Length(AddBackslash(NormalPath(Parent)))),
      AddBackslash(NormalPath(Parent))) = 0);
end;

function Digits(const Value: String): Boolean;
var I: Integer;
begin
  Result := (Length(Value) > 0) and (Length(Value) <= 20);
  for I := 1 to Length(Value) do
    if (Value[I] < '0') or (Value[I] > '9') then Result := False;
end;

function DecimalValue(Value: String): String;
begin
  while (Length(Value) > 1) and (Copy(Value, 1, 1) = '0') do Delete(Value, 1, 1);
  Result := Value;
end;

function OlderBuild(const Incoming, Existing: String): Boolean;
var A, B: String;
begin
  A := DecimalValue(Incoming);
  B := DecimalValue(Existing);
  if Length(A) <> Length(B) then Result := Length(A) < Length(B)
  else Result := CompareText(A, B) < 0;
end;

function VersionProblem(): String;
var OldVersion, OldBuild: String; Incoming, Existing: Int64; Order: Integer;
begin
  Result := '';
  if not RegKeyExists(HKCU64, OdiboKey) then Exit;
  if not RegQueryStringValue(HKCU64, OdiboKey, 'ODIBOAppVersion', OldVersion) or
    not RegQueryStringValue(HKCU64, OdiboKey, 'ODIBOBuildNumber', OldBuild) or
    not StrToVersion(OldVersion, Existing) or
    not StrToVersion('{#AppVersion}', Incoming) or not Digits(OldBuild) then begin
    Result := CustomMessage('BadMetadata');
    Exit;
  end;
  Order := ComparePackedVersion(Incoming, Existing);
  if (Order < 0) or ((Order = 0) and OlderBuild('{#BuildNumber}', OldBuild)) then
    Result := CustomMessage('Downgrade');
end;

function MachineInstall(Root: Integer): Boolean;
var Keys: TArrayOfString; I: Integer; Name: String;
begin
  Result := False;
  if not RegGetSubkeyNames(Root, UninstallRoot, Keys) then Exit;
  for I := 0 to GetArrayLength(Keys) - 1 do
    if RegQueryStringValue(Root, UninstallRoot + '\' + Keys[I], 'DisplayName', Name) then
      if (CompareText(Name, 'ODIBO PDF') = 0) or (CompareText(Name, 'ODIBOPDF') = 0) then
        Result := True;
end;

function FolderHasItems(const Folder: String): Boolean;
var Find: TFindRec;
begin
  Result := False;
  if FindFirst(AddBackslash(Folder) + '*', Find) then begin
    try
      repeat
        if (Find.Name <> '.') and (Find.Name <> '..') then Result := True;
      until Result or not FindNext(Find);
    finally
      FindClose(Find);
    end;
  end;
end;

function PreviousInstallFolder(const Folder: String): Boolean;
var Identity: AnsiString;
begin
  { This is a prior-install identity hint, not an authenticity/security boundary. }
  Result := LoadStringFromFile(AddBackslash(Folder) + InstallMarker, Identity) and
    (Identity = InstallIdentity);
end;

function UnsafeAncestor(const Folder: String): Boolean;
var Current, Parent: String; Find: TFindRec;
begin
  Result := False;
  Current := NormalPath(Folder);
  repeat
    if FindFirst(Current, Find) then begin
      try
        { Reject directory junctions/symlinks before touching an install destination. }
        if (Find.Attributes and $400) <> 0 then Result := True;
      finally FindClose(Find); end;
    end;
    if FileExists(AddBackslash(Current) + 'portable.txt') or
      FileExists(AddBackslash(Current) + 'ODIBOPDF.portable') or
      (CompareText(ExtractFileName(Current), 'ODIBOPDFData') = 0) then Result := True;
    Parent := ExtractFileDir(Current);
    if SamePath(Parent, Current) then Break;
    Current := Parent;
  until Current = '';
end;

function FolderProblem(const Folder: String): String;
var Path, ExistingPath, Profile: String;
begin
  Result := '';
  Path := NormalPath(Folder);
  Profile := GetEnv('USERPROFILE');
  if Profile = '' then begin Result := CustomMessage('BadMetadata'); Exit; end;
  if (Length(Path) < 4) or (Copy(Path, 2, 2) <> ':\') or
    SamePath(Path, Profile) or
    WithinPath(Path, ExpandConstant('{userdocs}')) or
    SamePath(Path, ExpandConstant('{userappdata}')) or
    SamePath(Path, ExpandConstant('{localappdata}')) or
    WithinPath(Path, ExpandConstant('{win}')) or
    WithinPath(Path, ExpandConstant('{commonpf32}')) or
    WithinPath(Path, ExpandConstant('{commonpf64}')) or
    WithinPath(Path, ExpandConstant('{userappdata}\ODIBO PDF')) or
    WithinPath(Path, ExpandConstant('{localappdata}\ODIBO PDF')) or
    DirExists(AddBackslash(Path) + 'ODIBOPDFData') or UnsafeAncestor(Path) then begin
    Result := CustomMessage('BadFolder'); Exit;
  end;
  if RegKeyExists(HKCU64, OdiboKey) then begin
    if not RegQueryStringValue(HKCU64, OdiboKey, 'InstallLocation', ExistingPath) or
      not SamePath(Path, ExistingPath) then Result := CustomMessage('ExistingPath');
  end else if FolderHasItems(Path) and not PreviousInstallFolder(Path) then
    Result := CustomMessage('BadFolder');
end;

function LockedExecutable(const Filename: String): Boolean;
var Stream: TFileStream;
begin
  Result := False;
  if not FileExists(Filename) then Exit;
  try
    { Open existing file for exclusive read/write without changing any bytes.
      Windows denies write access to a running mapped executable. }
    Stream := TFileStream.Create(Filename, $0002 or $0010);
    Stream.Free;
  except
    Result := True;
  end;
end;

function InitializeSetup(): Boolean;
var Error: String; Version: Int64;
begin
  Result := False;
  if not Digits('{#BuildNumber}') or not StrToVersion('{#AppVersion}', Version) or
    (Length('{#BuildCommit}') <> 40) then begin
    Log(CustomMessage('BadMetadata'));
    SuppressibleMsgBox(CustomMessage('BadMetadata'), mbError, MB_OK, IDOK); Exit;
  end;
  if MachineInstall(HKLM64) or MachineInstall(HKLM32) or
    FileExists(ExpandConstant('{commonpf64}\ODIBO PDF\odibo-pdf.exe')) or
    FileExists(ExpandConstant('{commonpf32}\ODIBO PDF\odibo-pdf.exe')) or
    FileExists(ExpandConstant('{commonpf64}\ODIBOPDF\odibo-pdf.exe')) or
    FileExists(ExpandConstant('{commonpf32}\ODIBOPDF\odibo-pdf.exe')) then begin
    Log(CustomMessage('LegacyInstall'));
    SuppressibleMsgBox(CustomMessage('LegacyInstall'), mbError, MB_OK, IDOK); Exit;
  end;
  Error := VersionProblem();
  if Error <> '' then begin Log(Error); SuppressibleMsgBox(Error, mbError, MB_OK, IDOK); Exit; end;
  Result := True;
end;

procedure InitializeWizard();
begin
  WizardForm.WelcomeLabel2.Caption := CustomMessage('TestNotice');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var Error: String;
begin
  Result := True;
  if CurPageID = wpSelectDir then begin
    Error := FolderProblem(WizardDirValue());
    if Error <> '' then begin
      Log('ODIBO_FOLDER_REFUSED: ' + Error);
      { NextButtonClick also runs silently. Preserve the interactive error but
        honor /SUPPRESSMSGBOXES so refusal exits instead of awaiting hidden input. }
      SuppressibleMsgBox(Error, mbError, MB_OK, IDOK);
      Result := False;
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := VersionProblem();
  if Result <> '' then Exit;
  Result := FolderProblem(ExpandConstant('{app}'));
  if Result <> '' then Exit;
  if LockedExecutable(ExpandConstant('{app}\odibo-pdf.exe')) or
    LockedExecutable(ExpandConstant('{app}\odibo-pdf-cli.exe')) then
    Result := CustomMessage('CloseApp');
end;

function InitializeUninstall(): Boolean;
begin
  Result := not LockedExecutable(ExpandConstant('{app}\odibo-pdf.exe')) and
    not LockedExecutable(ExpandConstant('{app}\odibo-pdf-cli.exe'));
  if not Result then begin
    Log(CustomMessage('CloseApp'));
    SuppressibleMsgBox(CustomMessage('CloseApp'), mbError, MB_OK, IDOK);
  end;
end;

procedure SaveInstalledBuildMetadata();
begin
  { Inno recreates its uninstall key after [Registry] entries are processed.
    Persist our identity only after its native registration has completed.
    Keep the same names/key used by fail-closed version and downgrade checks. }
  if not RegKeyExists(HKCU64, OdiboKey) then
    RaiseException(CustomMessage('BuildMetadataWriteFailed'));
  if not RegWriteStringValue(HKCU64, OdiboKey, 'ODIBOAppVersion', '{#AppVersion}') or
    not RegWriteStringValue(HKCU64, OdiboKey, 'ODIBOBuildCommit', '{#BuildCommit}') or
    not RegWriteStringValue(HKCU64, OdiboKey, 'ODIBOBuildNumber', '{#BuildNumber}') then
    RaiseException(CustomMessage('BuildMetadataWriteFailed'));
  Log('ODIBO_BUILD_METADATA_WRITTEN');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then SaveInstalledBuildMetadata();
  if CurStep = ssDone then begin
    { Written only after successful installation, outside the uninstall deletion log.
      Like uninsneveruninstall, this hint intentionally survives removal alongside
      any unknown user files, permitting a safe same-folder reinstall. }
    if not SaveStringToFile(ExpandConstant('{app}\') + InstallMarker, InstallIdentity, False) then
      Log('WARNING: Could not save the ODIBO installation-folder identity hint. Reinstall into a fresh empty folder if this folder retains user files.');
  end;
end;
