import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.modules
import qs.services

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                id: perScreen

                required property ShellScreen modelData

                ExclusiveZone {
                    screen: perScreen.modelData
                }
                // Before WidgetFace, so the widgets open above it in the backdrop.
                Parallax {
                    screen: perScreen.modelData
                    outputName: perScreen.modelData.name
                }
                WidgetFace {
                    screen: perScreen.modelData
                    outputName: perScreen.modelData.name
                }
                DesktopWidgets {
                    screen: perScreen.modelData
                    outputName: perScreen.modelData.name
                }
                TopLayer {
                    screen: perScreen.modelData
                }
                Dock {
                    screen: perScreen.modelData
                }
                RegionSelector {
                    screen: perScreen.modelData
                }
            }
        }
    }

    LockScreen {}
    ClipboardMenu {}
    AppMenu {}
    PowerMenu {}
    PolkitDialog {}
    KeysSheet {}
    WallpaperPicker {}
    SettingsWindow {}
    TranslateWindow {}
    WindowSwitcher {}
    StickyGhost {}

    // niri bindlari shu funksiyalarni chaqiradi: qs -c falcon ipc call desk <nom>
    IpcHandler {
        target: "desk"

        function lock(): void {
            Lock.lock();
        }
        function lockPreview(): void {
            Lock.preview = !Lock.preview;
        }
        function menu(): void {
            Ui.togglePopup("menu");
        }
        function region(action: string): void {
            Ui.region(action);
        }
        // Selects an area without the mouse. With done false it only shows the selection.
        function regionPick(x: real, y: real, w: real, h: real, done: bool): void {
            Ui.regionPicked(x, y, w, h, done);
        }
        function screenshotTaken(path: string): void {
            Niri.screenshotTaken(path);
        }
        function translateImage(path: string, width: int, height: int): void {
            Ui.translateImage(path, width, height);
        }
        function power(): void {
            Ui.togglePopup("power");
        }
        function clipboard(): void {
            Ui.togglePopup("clipboard");
        }
        function wallpapers(): void {
            Ui.togglePopup("wallpapers");
        }

        // Switches the open picker's tab, or opens the picker on that tab.
        function wallpapersTab(tab: int): void {
            if (Ui.popup === "wallpapers") {
                Ui.pickerTab = tab;
            } else {
                Ui.pickerOpenTab = tab;
                Ui.popup = "wallpapers";
            }
        }
        function dashboard(): void {
            Ui.togglePopup("dashboard");
        }
        function control(): void {
            Ui.togglePopup("control");
        }
        function settings(): void {
            Ui.settingsOpen = !Ui.settingsOpen;
        }
        function settingsPage(index: int): void {
            Ui.settingsPage = index;
            Ui.settingsOpen = true;
        }
        function state(): string {
            return JSON.stringify({
                popup: Ui.popup,
                region: Ui.regionPhase,
                regionAction: Ui.regionAction,
                zen: Ui.zen,
                settings: Ui.settingsOpen,
                recording: Ui.recording,
                recordCountdown: Ui.recordCountdown,
                recordOptions: Saved.get("record", {}),
                toast: Toasts.current ? Toasts.current.title : "",
                toastSub: Toasts.current ? Toasts.current.sub : "",
                queue: Toasts.queue.length,
                unread: Toasts.unread,
                history: Toasts.history.map(h => h.title),
                dnd: Toasts.doNotDisturb,
                caffeine: Caffeine.enabled,
                sticky: Sticky.ids,
                night: Night.enabled,
                accent: String(Theme.accent),
                pill: String(Theme.pill),
                fontScale: Theme.fontScale,
                bottom: Settings.bottom,
                ribbon: Niri.workspaces.map(w => w.idx),
                layout: Niri.layoutLabel,
                lang: Tr.language,
                sample: Tr.t("Settings"),
                dashTab: Ui.dashTab,
                switcher: Ui.switcherPhase,
                switcherRows: Ui.switcherRows,
                switcherSelected: Ui.switcherSelected,
                rows: Ui.launcherRows,
                selected: Ui.launcherSelected,
                pickerSelected: Ui.pickerSelected,
                pickerFiles: Ui.pickerFiles,
                pickerTab: Ui.pickerTab,
                controlHeight: Ui.controlHeight,
                controlPage: Ui.controlPage,
                widgetEdit: Widgets.editMode,
                widgetsLive: Widgets.shownNow,
                widgetHover: Widgets.hoverId,
                widgets: Widgets.items,
                widgetRects: Widgets.rects,
                spectrumWanted: Spectrum.wanted,
                widgetsBottomInset: Widgets.bottomInset,
                claudeHasData: ClaudeUsage.hasData,
                claudeFive: ClaudeUsage.fiveHour,
                claudeWeek: ClaudeUsage.weekly,
                volume: Audio.percent,
                muted: Audio.muted,
                error: Settings.lastError,
                trayCount: SystemTray.items.values.length,
                weather: Weather.summary,
                timer: Countdown.active ? Countdown.text : "",
                timerPaused: Countdown.paused,
                timerPhase: Countdown.phase,
                charge: { supported: Power.chargeSupported, writable: Power.chargeWritable, actual: Power.chargeActual, wanted: Power.wantedLimit },
                onBattery: Power.onBattery,
                updates: Updates.count,
                updatesFailed: Updates.failed,
                rebootNeeded: Updates.rebootNeeded,
                privacy: { mic: Privacy.mic, camera: Privacy.camera },
                clipPins: ClipPins.pins.length,
                wallpaperAuto: WallpaperAuto.mode,
                sessionWarning: Session.warning,
                polkitActive: Polkit.active,
                polkitRegistered: Polkit.registered,
                songrec: SongRec.listening,
                shownImage: Wallpapers.shownImage,
                shownLive: Wallpapers.shownLive,
            });
        }
        // Testlar uchun: shell'ni boshlang'ich holatga qaytaradi.
        function reset(): void {
            Ui.popup = "";
            Ui.settingsOpen = false;
            Ui.setRecording(false);
            Ui.recordCountdown = 0;
            Toasts.current = null;
            Toasts.queue = [];
            Toasts.history = [];
            Toasts.unread = 0;
            Toasts.doNotDisturb = false;
            Caffeine.enabled = false;
            Sticky.ids = [];
            Countdown.stop();
            Night.setEnabled(Settings.get("nightlight.auto", false));
            Ui.dashTab = 0;
            Widgets.editMode = false;
        }
        function controlPage(name: string): void {
            Ui.popup = "control";
            // An unknown name would show an empty panel, so it opens the main page.
            Ui.controlPage = ["wifi", "bluetooth", "record"].includes(name) ? name : "";
        }
        function dashboardTab(index: int): void {
            Ui.dashTab = Math.max(0, Math.min(2, index));
            Ui.popup = "dashboard";
        }
        function launcherQuery(text: string): void {
            Ui.launcherInject(text);
        }
        function updatesCheck(): void {
            Updates.check();
        }
        function powerRefresh(): void {
            Power.refresh();
        }
        function timer(text: string): void {
            const seconds = Countdown.parse(text);
            if (seconds > 0)
                Countdown.start(seconds);
            else
                Countdown.stop();
        }
        function close(): void {
            Ui.popup = "";
            if (Ui.regionPhase !== "")
                Ui.regionCancel();
        }
        function widgets(): void {
            Widgets.editMode = !Widgets.editMode;
        }
        function widgetsGallery(group: string): void {
            Widgets.editMode = true;
            Widgets.galleryGroup = group;
            Widgets.galleryOpen = true;
        }
        function widgetsArrange(image: string): void {
            Widgets.arrange(image);
        }
        function keys(): void {
            Ui.togglePopup("keys");
        }
        function songrec(): void {
            SongRec.recognize(false);
        }
        function wallpaperShown(path: string, live: bool): void {
            Wallpapers.shownImage = path;
            Wallpapers.shownLive = live;
        }
        function widgetsRestack(): void {
            Widgets.restack();
        }
        function switcher(step: int, sameApp: bool): void {
            Ui.switcherStep(step, sameApp);
        }
        function switcherEnd(confirm: bool): void {
            Ui.switcherEnd(confirm);
        }
        function claude(): void {
            Ui.togglePopup("claude");
        }
        function sticky(): void {
            Sticky.toggle();
        }
        // Workspace keys while a window is sticky: a number, up, down or previous.
        function stickySwitch(target: string): void {
            Sticky.switchTo(target);
        }
        function brightness(step: string): void {
            Brightness.step(step);
        }
        function recording(on: bool): void {
            Ui.setRecording(on);
        }
        function recordingCountdown(seconds: int): void {
            Ui.recordCountdown = Math.max(0, seconds);
        }
        function recordSaved(path: string): void {
            const name = path.split("/").pop();
            Toasts.show(path.endsWith(".gif") ? Tr.t("GIF saved") : Tr.t("Video saved"), name + " · " + Tr.t("click to open"), "record", () => Quickshell.execDetached(["xdg-open", path]));
        }
        function toast(title: string, sub: string): void {
            Toasts.show(title, sub, "check");
        }
    }

    Component.onCompleted: {
        Toasts.start();
        Schedule.check();
        Sticky.ids;
        Night.enabled;
        Power.started;
        Updates.count;
        Countdown.active;
        Privacy.enabled;
        WallpaperAuto.mode;
        Monitors.wantConnect;
    }
}
