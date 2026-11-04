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
            }
        }
    }

    LockScreen {}
    ClipboardMenu {}
    AppMenu {}
    WallpaperPicker {}
    SettingsWindow {}

    // niri bindlari shu funksiyalarni chaqiradi: qs -c niri-desk ipc call desk <nom>
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
        function clipboard(): void {
            Ui.togglePopup("clipboard");
        }
        function wallpapers(): void {
            Ui.togglePopup("wallpapers");
        }

        function wallpapersTab(tab: int): void {
            Ui.pickerTab = tab;
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
                zen: Ui.zen,
                settings: Ui.settingsOpen,
                recording: Ui.recording,
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
                claudeHasData: ClaudeUsage.hasData,
                claudeFive: ClaudeUsage.fiveHour,
                claudeWeek: ClaudeUsage.weekly,
                volume: Audio.percent,
                muted: Audio.muted,
                error: Settings.lastError,
                trayCount: SystemTray.items.values.length,
                weather: Weather.summary
            });
        }
        // Testlar uchun: shell'ni boshlang'ich holatga qaytaradi.
        function reset(): void {
            Ui.popup = "";
            Ui.settingsOpen = false;
            Ui.setRecording(false);
            Toasts.current = null;
            Toasts.queue = [];
            Toasts.history = [];
            Toasts.unread = 0;
            Toasts.doNotDisturb = false;
            Caffeine.enabled = false;
            Sticky.ids = [];
            Night.enabled = Settings.get("nightlight.auto", false);
            Ui.dashTab = 0;
            Widgets.editMode = false;
        }
        function controlPage(name: string): void {
            Ui.popup = "control";
            Ui.controlPage = name;
        }
        function dashboardTab(index: int): void {
            Ui.dashTab = Math.max(0, Math.min(2, index));
            Ui.popup = "dashboard";
        }
        function launcherQuery(text: string): void {
            Ui.launcherInject(text);
        }
        function close(): void {
            Ui.popup = "";
        }
        function widgets(): void {
            Widgets.editMode = !Widgets.editMode;
        }
        function widgetsRestack(): void {
            Widgets.restack();
        }
        function claude(): void {
            Ui.togglePopup("claude");
        }
        function sticky(): void {
            Sticky.toggle();
        }
        function brightness(step: string): void {
            Brightness.step(step);
        }
        function recording(on: bool): void {
            Ui.setRecording(on);
        }
        function toast(title: string, sub: string): void {
            Toasts.show(title, sub, "check");
        }
    }

    Component.onCompleted: {
        Toasts.start();
        Schedule.check();
        Sticky.ids;
    }
}
