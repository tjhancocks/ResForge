import Foundation
import RFSupport

class ElementKTYP: KeyElement {
    private var tValue: UInt32 = 0
    @objc private var value: String {
        get { tValue.stringValue }
        set { tValue = FourCharCode(newValue) }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
        _ = self.setCase(value)
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
    
    override var formatter: Formatter {
        self.sharedFormatter("TNAM") { MacRomanFormatter(stringLength: 4, exactLengthRequired: true) }
    }
}
