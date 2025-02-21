import Cocoa
import RFSupport

struct HFDefaults {
    static let fontSize = "HFDefaultFontSize"
    static let statusBarMode = "HFStatusBarDefaultMode" // This is defined and used by HexFiend automatically, it's just here for reference
}

class HexWindowController: AbstractEditor, ResourceEditor, NSTextFieldDelegate, HFTextViewDelegate {
    static let supportedTypes = ["*"]
    
    let resource: Resource
    @IBOutlet var textView: HFTextView!
    
    @IBOutlet var findView: NSView!
    @IBOutlet var findField: NSTextField!
    @IBOutlet var replaceField: NSTextField!
    @IBOutlet var wrapAround: NSButton!
    @IBOutlet var ignoreCase: NSButton!
    @IBOutlet var searchText: NSButton!
    @IBOutlet var searchHex: NSButton!

    override var windowNibName: String {
        return "HexWindow"
    }
    
    required init(resource: Resource, manager: RFEditorManager) {
        self.resource = resource
        super.init(window: nil)
        
        UserDefaults.standard.register(defaults: [HFDefaults.fontSize: 10])
        NotificationCenter.default.addObserver(self, selector: #selector(self.resourceDataDidChange(_:)), name: .ResourceDataDidChange, object: resource)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        self.window?.title = resource.defaultWindowTitle;
        findView.isHidden = true
        
        let lineCountingRepresenter = HFLineCountingRepresenter()
        lineCountingRepresenter.lineNumberFormat = .hexadecimal
        let statusBarRepresenter = HFStatusBarRepresenter()
        
        textView.layoutRepresenter.addRepresenter(lineCountingRepresenter)
        textView.layoutRepresenter.addRepresenter(statusBarRepresenter)
        textView.controller.addRepresenter(lineCountingRepresenter)
        textView.controller.addRepresenter(statusBarRepresenter)
        let fontSize = UserDefaults.standard.integer(forKey: HFDefaults.fontSize)
        textView.controller.font = NSFont.userFixedPitchFont(ofSize: CGFloat(fontSize))!
        textView.data = resource.data
        textView.controller.undoManager = self.window?.undoManager
        textView.layoutRepresenter.performLayout()
        textView.delegate = self
    }
    
    @objc func resourceDataDidChange(_ notification: NSNotification) {
        if self.window?.isDocumentEdited != true {
            textView.data = resource.data
            self.setDocumentEdited(false) // Will have been set to true by hexDidChangeProperties
        }
    }
    
    func hexTextView(_ view: HFTextView, didChangeProperties properties: HFControllerPropertyBits) {
        if properties.contains(.contentValue) {
            self.setDocumentEdited(true)
        }
    }
    
    @IBAction func saveResource(_ sender: Any) {
        resource.data = textView.data!
        self.setDocumentEdited(false)
    }
    
    @IBAction func revertResource(_ sender: Any) {
        textView.data = resource.data
        self.setDocumentEdited(false)
    }
    
    // We can't catch keyDown events here so hidden buttons are placed in the window to trigger these with cmd+/-
    @IBAction func sizeUp(_ sender: Any) {
        self.adjustFontSize(1)
    }
    
    @IBAction func sizeDown(_ sender: Any) {
        self.adjustFontSize(-1)
    }
    
    private func adjustFontSize(_ mod: CGFloat) {
        let font = textView.controller.font
        let size = font.pointSize + mod
        if 9...16 ~= size {
            textView.controller.font = NSFontManager.shared.convert(font, toSize: size)
            UserDefaults.standard.set(Int(size), forKey: HFDefaults.fontSize)
        }
    }
    
    // MARK: - Find/Replace

    @IBAction func showFind(_ sender: Any) {
        findField.stringValue = self.sanitize(NSPasteboard(name: .find).string(forType: .string) ?? "")
        findView.isHidden = false
        self.window?.makeFirstResponder(findField)
    }

    @IBAction func findNext(_ sender: Any) {
        if !self.find(self.findBytes(), forwards: true) {
            NSSound.beep()
        }
    }

    @IBAction func findPrevious(_ sender: Any) {
        if !self.find(self.findBytes(), forwards: false) {
            NSSound.beep()
        }
    }

    @IBAction func findWithSelection(_ sender: Any) {
        let asHex = self.window?.firstResponder?.className == "HFRepresenterHexTextView"
        searchText.state = asHex ? .off : .on
        searchHex.state = asHex ? .on : .off
        let range = (textView.controller.selectedContentsRanges[0] as! HFRangeWrapper).hfRange()
        let data = textView.controller.data(for: range)
        if asHex {
            findField.stringValue = data.hexadecimal
        } else {
            findField.stringValue = String(data: data, encoding: .macOSRoman)!
        }
        // Save the string in the find pasteboard
        let pasteboard = NSPasteboard(name: .find)
        pasteboard.clearContents()
        pasteboard.setString(findField.stringValue, forType: .string)
    }
    
    @IBAction func scrollToSelection(_ sender: Any) {
        let selection = (textView.controller.selectedContentsRanges[0] as! HFRangeWrapper).hfRange()
        textView.controller.maximizeVisibility(ofContentsRange: selection)
        textView.controller.pulseSelection()
    }
    

    @IBAction func findAction(_ sender: Any) {
        if !findView.isHidden && !self.find(self.findBytes()) {
            NSSound.beep()
        }
    }
        
    @IBAction func find(_ sender: NSSegmentedControl) {
        if !self.find(self.findBytes(), forwards: sender.selectedTag() == 1) {
            NSSound.beep()
        }
    }
        
    @IBAction func replace(_ sender: NSSegmentedControl) {
        let data = self.data(string: replaceField.stringValue)
        if sender.selectedTag() == 0 {
            // Replace and find
            self.replace(data)
            _ = self.find(self.findBytes())
        } else {
            // Replace all
            guard let findBytes = self.findBytes() else {
                NSSound.beep()
                return
            }
            // start from top
            textView.controller.selectedContentsRanges = [HFRangeWrapper.withRange(HFRangeMake(0,0))]
            while self.find(findBytes, noWrap: true) {
                self.replace(data)
            }
        }
    }
        
    @IBAction func hideFind(_ sender: Any) {
        findView.isHidden = true
    }
    
    @IBAction func toggleType(_ sender: Any) {
        ignoreCase.isEnabled = searchText.state == .on
        findField.stringValue = self.sanitize(findField.stringValue)
        replaceField.stringValue = self.sanitize(replaceField.stringValue)
    }
    
    // NSTextFieldDelegate
    func controlTextDidChange(_ obj: Notification) {
        let field = obj.object as! NSTextField
        field.stringValue = self.sanitize(field.stringValue)
        if field == findField {
            // Save the string in the find pasteboard
            let pasteboard = NSPasteboard(name: .find)
            pasteboard.clearContents()
            pasteboard.setString(findField.stringValue, forType: .string)
        }
    }
    
    private func findBytes() -> HFByteArray? {
        if findView.isHidden {
            // Always load from find pasteboard when view is hidden
            findField.stringValue = self.sanitize(NSPasteboard(name: .find).string(forType: .string) ?? "")
        }
        return self.byteArray(data: self.data(string: findField.stringValue))
    }
    
    private func sanitize(_ string: String) -> String {
        if searchHex.state == .on {
            let nonHexChars = NSCharacterSet(charactersIn: "0123456789ABCDEFabcdef").inverted;
            return string.components(separatedBy: nonHexChars).joined()
        }
        return string
    }
    
    private func data(string: String) -> Data {
        if searchHex.state == .on {
            var hexString = string
            if hexString.count % 2 == 1 {
                hexString = "0" + hexString
            }
            return hexString.data(using: .hexadecimal)!
        } else {
            return string.data(using: .macOSRoman)!
        }
    }
    
    private func byteArray(data: Data) -> HFByteArray? {
        if data.isEmpty {
            return nil
        }
        let byteArray = HFBTreeByteArray()
        byteArray.insertByteSlice(HFSharedMemoryByteSlice(unsharedData: data), in:HFRangeMake(0,0))
        return byteArray
    }
    
    private func find(_ findBytes: HFByteArray?, forwards: Bool = true, noWrap: Bool = false) -> Bool {
        guard var findBytes = findBytes else {
            return false
        }
        
        let controller = textView.controller
        let wrap = noWrap ? false : wrapAround.state == .on
        let startRange = HFRangeMake(0, controller.minimumSelectionLocation())
        let endRange = HFRangeMake(controller.maximumSelectionLocation(), controller.contentsLength()-controller.maximumSelectionLocation())
        var range = forwards ? endRange : startRange
        
        var idx = UInt64.max
        if ignoreCase.state == .on && searchText.state == .on {
            // Case-insensitive search is difficult and inefficient - string indices don't necessarily equal byte indices
            // 1. Convert the current search range to a string
            // 2. Perform a string search
            // 3. Create a byte array from the match
            // 4. Proceed to byte search
            let options: NSString.CompareOptions = forwards ? .caseInsensitive : [.caseInsensitive, .backwards]
            var text = String(data: controller.data(for: range), encoding: .macOSRoman)!
            var textRange = text.range(of: findField.stringValue, options: options)
            if let textRange = textRange {
                findBytes = self.byteArray(data: text[textRange].data(using: .macOSRoman)!)!
            } else if wrap {
                range = forwards ? startRange : endRange
                text = String(data: controller.data(for: range), encoding: .macOSRoman)!
                textRange = text.range(of: findField.stringValue, options: options)
                if let textRange = textRange {
                    findBytes = self.byteArray(data: text[textRange].data(using: .macOSRoman)!)!
                }
            }
            if textRange == nil {
               return false
            }
        }
        idx = controller.byteArray.indexOfBytesEqual(to: findBytes, in: range, searchingForwards: forwards, trackingProgress: nil)
        if idx == UInt64.max && wrap {
            range = forwards ? startRange : endRange
            idx = controller.byteArray.indexOfBytesEqual(to: findBytes, in: range, searchingForwards: forwards, trackingProgress: nil)
        }
        
        if idx == UInt64.max {
            return false
        }
        let result = HFRangeMake(idx, findBytes.length())
        controller.selectedContentsRanges = [HFRangeWrapper.withRange(result)]
        if !noWrap {
            controller.maximizeVisibility(ofContentsRange: result)
            controller.pulseSelection()
        }
        return true
    }
    
    private func replace(_ replaceData: Data) {
        if replaceData.isEmpty {
            textView.controller.deleteSelection()
        } else {
            textView.controller.insert(replaceData, replacingPreviousBytes: 0, allowUndoCoalescing: false)
        }
    }
}
