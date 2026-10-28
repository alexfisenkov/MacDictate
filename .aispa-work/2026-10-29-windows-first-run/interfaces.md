# Границы и правила

## Канон проекта
Физический Gitroot macos/. Текущий baseline78f3813. Windowscontext windows/CLAUDE.md; notes.md содержит точные существующие имена. Пользовательские CLAUDE/AGENTS не перезаписывать. macOS/iOS/Transcribe runtime не менять. Документы релиза и .aispa-work являются историей; исходники/синтетические данные разрешены в существующем GitHubrepo, секреты и пользовательские медиа нет. Перед hosted CI целевые локальные проверки; только один финальный согласованный запуск, repair лишь по конкретной ошибке. Нет авто push/PR CI. Не трогать прошлые публичные файлы и модели. Глобальный latestMac не смещать Windows-only hotfix.

## Границы, решённые в спецификации
- AppSettings/LocalStore сохраняют прежние поля Language/Hotkey/ModelPath; новые параметры микрофона/setup/UI имеют defaults, старый JSON читается без миграции исходных данных.
- Core владеет readiness/state/PCM signal policy и персистентными данными. Не зависит от WinForms/Win32.
- Native services владеют enumeration/capture/meter и выделенным keyboard message loop. Внешняя поверхность: список микрофонов с ID/Name; cancellable mic test с progressLevel и outcome(success/signal/error); WaveRecorder поддерживает выбранный deviceID, существующий Stop/Dispose cleanup сохраняется. Точные локальные имена может выбрать единый app executor, он записывает их здесь после реализации; ни одна последующая задача не пишет эти native-модули.
- Main/setup UI orchestration владеет состояниями и человекочитаемыми текстами; слушает только metadata hotkey events, не блокирует keyboard callback. Большие download/ASR вне UI thread. Main record origin не делает auto-paste в собственное приложение; global origin сохраняет существующий guard.
- Program/Tray управляют single instance и открытием/повторным показом окна. Ошибки readiness не теряются в скрытых balloon.
- Проверочные CLI contracts: сохранить --smoke-test --report PATH и --transcribe WAV --model BIN --report PATH. Добавить --onboarding-smoke --report PATH с изолированным temporary profile; отчёт явно distinguishes synthetic microphone vs real capture, real/hooked keyboard vs injected seam, captured transcript test-only. Не менять production readiness через общие env flags. App executor документирует flags/тестовые швы.
- Один общий local check: windows/scripts/check-local.sh создаётся app executor: core console harness + Windows cross-build, SDK из .local/dotnet/dotnet либо PATH. Без hosted CI. Windows-native suite запускается отдельным PS script в final workflow.
- Доставка: installer EXE primary, ZIP secondary. Windows-only1.6.1 release with make_latest=false; fixed tag download pin, not global/releases/latest for Windows. CurrentMac1.6.0 untouched. Registry, Windows manifest, docs/checksum/read-back updated delivery executor. Site source stays on main until one final reviewed gh-pages push.

## Исполнители
01 owns windows/src, windows/tests, windows/scripts/check-local.sh, implementation seams; may update interfaces only to record actual contracts. 02 owns web-landing, WindowsREADME/installer/build/acceptance scripts, workflow, release/governance docs and registry, windows csproj version bump after01; no competing writers.

## Что построила задача01
- AppSettings optional fields: uint MicrophoneDeviceId=uint.MaxValue, string UiLanguage=""; старые JSON читаются.
- Native: MicrophoneDevice(uint Id,string Name); MicrophoneTestResult(MicrophoneReadiness State,string Code); WaveRecorder(path,uint deviceId=uint.MaxValue,IProgress<double>? level=null):IAudioCapture. KeyboardService.Observed(HotkeyObservation LeftAlt/Pressed/Injected/Activated), dedicated message-loop thread.
- MainForm acceptance control names: StartStopRecording, CancelOperation, CopyLastDictation, LastDictationText, NextSetupAction.
- CLI --onboarding-smoke --report PATH [--model PATH --fixture-wave PATH]. При двух опциональных флагах один realWhisper проходит через запись/stop/result приложения; ожидаемая fixture фраза quick brown fox. Остальные быстрые error/cancel сценарии synthetic, явно обозначены.
- Report: success,scenario,checks,screenshots (PNG basename рядом),sources,realWhisper,syntheticMicrophone,syntheticHotkeyActivation,realFixturePhraseMatched; physicalWin10/11NOT_TESTED. Existing --smoke-test and --transcribe preserved.
- check-local.sh:46portable tests + Windows cross-build0warnings/errors, root independently confirmed. Native/DPI/physical still pending. SettingsForm removed/replaced main UI.

## Ремонт01
MicrophoneSelection.Reconcile(uint storedId,IReadOnlyCollection<uint> availableIds,MicrophoneReadiness readiness) returnsDeviceId/Readiness; unknown/disconnected selection no longerinherits signal. ModelDownloadRecovery.Classify(Exception) returnsIntegrity orTransferOrStorage; actualintegrityfailure hasseparateRU/ENrecovery. Rootcheck54PASS0warnings afterrepair.

## Что построила задача02
Windows-only channel/candidate1.6.1, csproj-derivedcanonicalnames, source/hashchecker windows/scripts/check-delivery.py. StableWindowsURLостаётсяpublished1.6.0дофинализации. Native scripts test-onboarding.ps1/test-first-launch.ps1 calloneactualWhisperUIscenario, separatecheaplayout125/150. --layout-scale1.25|1.5reportssyntheticLayoutStress/requestedLayoutScale/actualDesktopDpi; resultVisibleBeforeTestScroll musttrueinfinalacceptance, extraTestScrollnotproductionproof. Rootindependentlyconfirmed54PASS/build0warnings,PSsyntax/packaging/delivery/governancePASS. Native/browserchecksnotyetexecuted.

## F1 actual contracts
OperationBoundary.CompleteAfterAsync<TInput,TResult>(prepare,complete,CancellationToken,bool waitForCleanup=false); TextInsertion.TryAsync<TIdentity>(text,identity,observe,canSend,sendChunk,CancellationToken). Bothwiredtoproductionstartup/ASR/insertion. MainForm.RefreshMicrophones(bool=false):bool; MicrophoneRefreshed Action<MicrophoneSelection>, ShowOutcome. TrayApplication optionalDictationInteraction; PasteService.TryPasteAsync optionalCancellationToken. ActualHTMLpinnedEXEfallback2checksPASS. Root59portablePASS/crossbuild0warnings, delivery/arch/governancePASS. Nativeviewport/controller-cancel assertions present, executionpendingWindows.

## F1 bounded follow-up
LocalErrorState.ShowError/Render/Text/Visible and MainForm.ShowLocalError route clipboard/settings errors through visible retainedlocalstate. NativeSmoke assertsimmediate+repeatRender. Root60portablePASS/build0warnings; no thirdfullreviewclaimed (costdeviation announced).
