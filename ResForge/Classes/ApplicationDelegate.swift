import Cocoa
import RFSupport

@NSApplicationMain
class ApplicationDelegate: NSObject, NSApplicationDelegate {
    static let githubURL = "https://github.com/andrews05/ResForge"
    
    // Don't configure prefs controller until needed
    private lazy var prefsController: NSWindowController = {
        ValueTransformer.setValueTransformer(LaunchActionTransformer(), forName: .launchActionTransformerName)
        let prefs = NSWindowController(windowNibName: "PrefsWindow")
        prefs.window?.center()
        return prefs
    }()
    
    override init() {
        NSApp.registerServicesMenuSendTypes([.string], returnTypes: [.string])
        UserDefaults.standard.register(defaults: [
            RFDefaults.confirmChanges: false,
            RFDefaults.deleteResourceWarning: true,
            RFDefaults.launchAction: RFDefaults.LaunchActions.displayOpenPanel,
            RFDefaults.showSidebar: true
        ])
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        SupportRegistry.scanForResources()
        // Load plugins
        NotificationCenter.default.addObserver(PluginRegistry.self, selector: #selector(PluginRegistry.bundleLoaded(_:)), name: Bundle.didLoadNotification, object: nil)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .allDomainsMask)
        if let plugins = Bundle.main.builtInPlugInsURL {
            self.scanForPlugins(folder: plugins)
        }
        for url in appSupport {
            self.scanForPlugins(folder: url.appendingPathComponent("ResForge/Plugins"))
        }
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        let launchAction = UserDefaults.standard.string(forKey: RFDefaults.launchAction)
        switch launchAction {
        case RFDefaults.LaunchActions.openUntitledFile:
            return true
        case RFDefaults.LaunchActions.displayOpenPanel:
            NSDocumentController.shared.openDocument(sender)
            return false
        default:
            return false
        }
    }
    
    @IBAction func showInfo(_ sender: Any) {
        let info = InfoWindowController.shared
        if info.window?.isKeyWindow == true {
            info.close()
        } else {
            info.showWindow(sender)
        }
    }
    
    @IBAction func showPrefs(_ sender: Any) {
        self.prefsController.showWindow(sender)
    }
    
    @IBAction func viewWebsite(_ sender: Any) {
        if let url = URL(string: Self.githubURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func scanForPlugins(folder: URL) {
        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        } catch {
            return
        }
        for item in items where item.pathExtension == "plugin" {
            guard let plugin = Bundle(url: item) else {
                continue
            }
            SupportRegistry.scanForResources(in: plugin)
            plugin.load()
        }
    }
}
