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
                QuietClock {
                    screen: perScreen.modelData
                    outputName: perScreen.modelData.name
                }
                TopLayer {
                    screen: perScreen.modelData
                }
            }
        }
    }

    Launcher {}
    WallpaperPicker {}
    SettingsWindow {}

    // niri bindlari shu funksiyalarni chaqiradi: qs -c niri-desk ipc call desk <nom>
    IpcHandler {
        target: "desk"

        function launcher(): void {
            Ui.togglePopup("launcher");
        }
        function clipboard(): void {
            Ui.togglePopup("clipboard");
        }
        function wallpapers(): void {
            Ui.togglePopup("wallpapers");
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
                pomodoro: Pomodoro.phase,
                pomodoroLeft: Pomodoro.remaining,
                pomodoroPaused: Pomodoro.paused,
                aiBusy: Ai.busy,
                aiMessages: Ai.messages.map(m => m.role + ":" + m.text),
                snippets: Library.snippets.length,
                profiles: Library.profiles.length,
                rows: Ui.launcherRows,
                selected: Ui.launcherSelected,
                pickerSelected: Ui.pickerSelected,
                pickerFiles: Ui.pickerFiles,
                controlHeight: Ui.controlHeight,
                target: Settings.labTarget,
                labOpen: Lab.ports.filter(p => p.open).map(p => p.port),
                vpn: Lab.vpnAddress,
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
            Pomodoro.reset();
            Ai.clear();
        }
        function dashboardTab(index: int): void {
            Ui.dashTab = index;
            Ui.popup = "dashboard";
        }
        function pomodoro(seconds: int): void {
            Pomodoro.start();
            Pomodoro.remaining = seconds;
        }
        function launcherQuery(text: string): void {
            Ui.launcherInject(text);
        }
        function close(): void {
            Ui.popup = "";
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
        Library.snippets;
        Schedule.check();
        Sticky.ids;
    }
}
