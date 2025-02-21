import Cocoa
import RFSupport

class ImageWindowController: AbstractEditor, ResourceEditor, PreviewProvider, ExportProvider {
    static let supportedTypes = [
        "PICT",
        "PNG ",
        "cicn",
        "ppat",
        "crsr",
        "icns",
        "ICON",
        "SICN",
        "ICN#",
        "ics#",
        "icm#",
        "icl4",
        "ics4",
        "icm4",
        "icl8",
        "ics8",
        "icm8",
        "CURS",
        "PAT ",
        "PAT#"
    ]
    
    let resource: Resource
    private let manager: RFEditorManager
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var imageSize: NSTextField!
    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!
    
    override var windowNibName: String {
        return "ImageWindow"
    }

    required init(resource: Resource, manager: RFEditorManager) {
        self.resource = resource
        self.manager = manager
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        self.window?.title = resource.defaultWindowTitle
        // Interface builder doesn't allow setting the document view so we have to do it here and configure the constraints
        scrollView.documentView = imageView
        let l = NSLayoutConstraint(item: imageView!, attribute: .leading, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .leading, multiplier: 1, constant: 0)
        let r = NSLayoutConstraint(item: imageView!, attribute: .trailing, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .trailing, multiplier: 1, constant: 0)
        let t = NSLayoutConstraint(item: imageView!, attribute: .top, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .top, multiplier: 1, constant: 0)
        let b = NSLayoutConstraint(item: imageView!, attribute: .bottom, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .bottom, multiplier: 1, constant: 0)
        widthConstraint = NSLayoutConstraint(item: imageView!, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 0)
        heightConstraint = NSLayoutConstraint(item: imageView!, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 0)
        scrollView.addConstraints([widthConstraint,heightConstraint,l,r,t,b])
        imageView.allowsCutCopyPaste = false // Ideally want copy/paste but not cut/delete
        imageView.isEditable = ["PICT", "cicn", "ppat", "PNG "].contains(resource.typeCode)
    
        self.loadImage()
    }
    
    // MARK: -
    
    private func loadImage() {
        imageView.image = Self.image(for: resource)
        if let image = imageView.image {
            // Colour icons use the mask from the black & white version of the same icon - see if we can load it.
            // Note this is only done within the viewer - preview and export should not access other resources.
            let maskType: String?
            switch resource.typeCode {
            case "icl4", "icl8":
                maskType = "ICN#"
            case "icm4", "icm8":
                maskType = "icm#"
            case "ics4", "ics8":
                maskType = "ics#"
            default:
                maskType = nil
            }
            if let maskType = maskType,
               let bw = manager.findResource(type: ResourceType(maskType, resource.typeAttributes), id: resource.id, currentDocumentOnly: true),
               let bwRep = Self.imageRep(for: bw) {
                image.lockFocus()
                NSGraphicsContext.current?.imageInterpolation = .none
                image.representations[0].draw()
                bwRep.draw(in: image.alignmentRect, from: NSZeroRect, operation: .destinationIn, fraction: 1, respectFlipped: true, hints: nil)
                image.unlockFocus()
            }
        }
        self.updateView()
    }
    
    private func updateView() {
        if let image = imageView.image {
            widthConstraint.constant = max(image.size.width, window!.contentMinSize.width)
            heightConstraint.constant = max(image.size.height, window!.contentMinSize.height)
            self.window?.setContentSize(NSMakeSize(widthConstraint.constant, heightConstraint.constant))
            imageSize.stringValue = String(format: "%.0fx%.0f", image.size.width, image.size.height)
        } else if !resource.data.isEmpty {
            imageSize.stringValue = "Invalid or unsupported image format"
        } else if imageView.isEditable {
            imageSize.stringValue = "Paste or drag and drop an image to import"
        } else {
            imageSize.stringValue = "Can't edit resources of this type"
        }
    }
    
    private func bitmapRep(flatten: Bool=false, palette: Bool=false) -> NSBitmapImageRep {
        let image = imageView.image!
        var rep = image.representations[0] as? NSBitmapImageRep ?? NSBitmapImageRep(data: image.tiffRepresentation!)!
        if palette {
            // Reduce to 8-bit colour by converting to gif
            let data = rep.representation(using: .gif, properties: [.ditherTransparency: false])!
            rep = NSBitmapImageRep(data: data)!
        }
        if flatten {
            // Hide alpha (might be nice to flatten to white background but not really worth the trouble)
            rep.hasAlpha = false
            // Ensure display size matches pixel dimensions
            rep.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        // Update the image
        image.removeRepresentation(image.representations[0])
        image.addRepresentation(rep)
        return rep
    }
    
    // MARK: -
    
    @IBAction func changedImage(_ sender: Any) {
        let rep: NSBitmapImageRep
        switch resource.typeCode {
        case "PICT":
            rep = self.bitmapRep(flatten: true)
        case "cicn":
            rep = self.bitmapRep(palette: true)
        case "ppat":
            rep = self.bitmapRep(flatten: true, palette: true)
        default:
            rep = self.bitmapRep()
        }
        _ = rep.bitmapData // Trigger redraw
        self.updateView()
        self.setDocumentEdited(true)
    }

    @IBAction func saveResource(_ sender: Any) {
        guard imageView.image != nil else {
            return
        }
        let rep = self.bitmapRep()
        switch resource.typeCode {
        case "PICT":
            resource.data = QuickDraw.pict(from: rep)
        case "cicn":
            resource.data = QuickDraw.cicn(from: rep)
        case "ppat":
            resource.data = QuickDraw.ppat(from: rep)
        default:
            resource.data = rep.representation(using: .png, properties: [.interlaced: false])!
        }
        self.setDocumentEdited(false)
    }

    @IBAction func revertResource(_ sender: Any) {
        self.loadImage()
        self.setDocumentEdited(false)
    }
    
    @IBAction func copy(_ sender: Any) {
        if let image = imageView.image {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
    }
    
    @IBAction func paste(_ sender: Any) {
        guard imageView.isEditable else {
            return
        }
        guard let images = NSPasteboard.general.readObjects(forClasses: [NSImage.self]) else {
            return
        }
        if !images.isEmpty {
            imageView.image = images[0] as? NSImage
            self.changedImage(sender)
        }
    }
    
    // MARK: - Export Provider
    
    static func filenameExtension(for resourceType: String) -> String {
        switch resourceType {
        case "PNG ":
            return "png"
        case "icns":
            return "icns"
        default:
            return "tiff"
        }
    }
    
    static func export(_ resource: Resource, to url: URL) throws -> Bool {
        let data: Data
        switch resource.typeCode {
        case "PNG ", "icns":
            data = resource.data
        default:
            data = self.image(for: resource)?.tiffRepresentation ?? Data()
        }
        try data.write(to: url)
        return true
    }
    
    // MARK: - Preview Provider
    
    static func image(for resource: Resource) -> NSImage? {
        guard let rep = self.imageRep(for: resource) else {
            return nil
        }
        let image = NSImage()
        image.addRepresentation(rep)
        return image
    }
    
    static func previewSize(for resourceType: String) -> Int {
        switch resourceType {
        case "PICT", "PNG ":
            return 100
        default:
            return 64
        }
    }
    
    private static func imageRep(for resource: Resource) -> NSImageRep? {
        let data = resource.data
        guard !data.isEmpty else {
            return nil
        }
        switch resource.typeCode {
        case "PICT":
            return self.rep(fromPict: data)
        case "cicn":
            return QuickDraw.rep(fromCicn: data)
        case "ppat":
            return QuickDraw.rep(fromPpat: data)
        case "crsr":
            return QuickDraw.rep(fromCrsr: data)
        case "ICN#", "ICON":
            return Icons.rep(data, width: 32, height: 32, depth: 1)
        case "ics#", "SICN", "CURS":
            return Icons.rep(data, width: 16, height: 16, depth: 1)
        case "icm#":
            return Icons.rep(data, width: 16, height: 12, depth: 1)
        case "icl4":
            return Icons.rep(data, width: 32, height: 32, depth: 4)
        case "ics4":
            return Icons.rep(data, width: 16, height: 16, depth: 4)
        case "icm4":
            return Icons.rep(data, width: 16, height: 12, depth: 4)
        case "icl8":
            return Icons.rep(data, width: 32, height: 32, depth: 8)
        case "ics8":
            return Icons.rep(data, width: 16, height: 16, depth: 8)
        case "icm8":
            return Icons.rep(data, width: 16, height: 12, depth: 8)
        case "PAT ":
            return Icons.rep(data, width: 8, height: 8, depth: 1)
        case "PAT#":
            // This just stacks all the patterns vertically
            return Icons.rep(data[2...], width: 8, height: 8 * Int(data[1]), depth: 1)
        default:
            return NSBitmapImageRep(data: data)
        }
    }
    
    private static func rep(fromPict data: Data) -> NSImageRep? {
        // On systems earlier than 10.15 we can handle the pict natively
        guard #available(macOS 10.15, *) else {
            return NSPICTImageRep(data: data)
        }
        do {
            return try QuickDraw.rep(fromPict: data)
        } catch let error {
            // If the error is because of an unsupported QuickTime compressor, attempt to decode it
            // natively from the offset indicated. This should work for e.g. PNG or JPEG.
            if let range = error.localizedDescription.range(of: "(?<=offset )[0-9]+", options: .regularExpression),
               let offset = Int(error.localizedDescription[range]),
               data.count > offset,
               let rep = NSBitmapImageRep(data: data[offset...]) {
                // Older QuickTime versions (<6.5) stored png data as non-standard RGBX
                // We need to disable the alpha, but first ensure the image has been decoded by accessing the bitmapData
                _ = rep.bitmapData
                rep.hasAlpha = false
                return rep
            }
        }
        return nil
    }
}
