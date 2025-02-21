import Cocoa

class Icons {
    static func rep(_ data: Data, width: Int, height: Int, depth: Int) -> NSBitmapImageRep? {
        if depth == 1 {
            return self.bwRep(data, width: width, height: height)
        }
        return self.colorRep(data, width: width, height: height, depth: depth)
    }
    
    private static func bwRep(_ data: Data, width: Int, height: Int) -> NSBitmapImageRep? {
        let bytesPerRow = width / 8
        let planeLength = bytesPerRow * height
        if data.count < planeLength {
            return nil
        }
        // Assume alpha if sufficient data
        let alpha = data.count >= planeLength*2
        var plane = [UInt8](data)
        // Invert bitmap plane
        for i in 0..<planeLength {
            plane[i] ^= 0xff
        }
        
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: width,
                                   pixelsHigh: height,
                                   bitsPerSample: 1,
                                   samplesPerPixel: alpha ? 2 : 1,
                                   hasAlpha: alpha,
                                   isPlanar: true,
                                   colorSpaceName: .deviceWhite,
                                   bytesPerRow: bytesPerRow,
                                   bitsPerPixel: 1)!
        rep.bitmapData!.assign(from: &plane, count: rep.bytesPerPlane * rep.numberOfPlanes)
        return rep
    }

    private static func colorRep(_ data: Data, width: Int, height: Int, depth: Int) -> NSBitmapImageRep? {
        if data.count < (width * height * depth / 8) {
            return nil
        }
        
        var plane: [UInt8]
        if depth == 4 {
            plane = []
            for byte in data {
                plane += clut4[Int(byte >> 4)]
                plane += clut4[Int(byte & 0x0f)]
            }
        } else if depth == 8 {
            // Map every byte to the full colour from the palette
            plane = data.flatMap { clut8[Int($0)] }
        } else {
            return nil
        }
        
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: width,
                                   pixelsHigh: height,
                                   bitsPerSample: 8,
                                   samplesPerPixel: 3,
                                   hasAlpha: false,
                                   isPlanar: false,
                                   colorSpaceName: .deviceRGB,
                                   bytesPerRow: width * 3,
                                   bitsPerPixel: 0)!
        rep.bitmapData!.assign(from: plane, count: rep.bytesPerPlane)
        return rep
    }
    
    // Sourced from clut id 4 in the Mac OS System file
    static let clut4: [[UInt8]] = [
        [255, 255, 255],
        [252, 243, 5],
        [255, 100, 2],
        [221, 8, 6],
        [242, 8, 132],
        [70, 0, 165],
        [0, 0, 212],
        [2, 171, 234],
        [31, 183, 20],
        [0, 100, 17],
        [86, 44, 5],
        [144, 113, 58],
        [192, 192, 192],
        [128, 128, 128],
        [64, 64, 64],
        [0, 0, 0]
    ]
    
    // Sourced from clut id 8 in the Mac OS System file
    static let clut8: [[UInt8]] = [
        [255, 255, 255],
        [255, 255, 204],
        [255, 255, 153],
        [255, 255, 102],
        [255, 255, 51],
        [255, 255, 0],
        [255, 204, 255],
        [255, 204, 204],
        [255, 204, 153],
        [255, 204, 102],
        [255, 204, 51],
        [255, 204, 0],
        [255, 153, 255],
        [255, 153, 204],
        [255, 153, 153],
        [255, 153, 102],
        [255, 153, 51],
        [255, 153, 0],
        [255, 102, 255],
        [255, 102, 204],
        [255, 102, 153],
        [255, 102, 102],
        [255, 102, 51],
        [255, 102, 0],
        [255, 51, 255],
        [255, 51, 204],
        [255, 51, 153],
        [255, 51, 102],
        [255, 51, 51],
        [255, 51, 0],
        [255, 0, 255],
        [255, 0, 204],
        [255, 0, 153],
        [255, 0, 102],
        [255, 0, 51],
        [255, 0, 0],
        [204, 255, 255],
        [204, 255, 204],
        [204, 255, 153],
        [204, 255, 102],
        [204, 255, 51],
        [204, 255, 0],
        [204, 204, 255],
        [204, 204, 204],
        [204, 204, 153],
        [204, 204, 102],
        [204, 204, 51],
        [204, 204, 0],
        [204, 153, 255],
        [204, 153, 204],
        [204, 153, 153],
        [204, 153, 102],
        [204, 153, 51],
        [204, 153, 0],
        [204, 102, 255],
        [204, 102, 204],
        [204, 102, 153],
        [204, 102, 102],
        [204, 102, 51],
        [204, 102, 0],
        [204, 51, 255],
        [204, 51, 204],
        [204, 51, 153],
        [204, 51, 102],
        [204, 51, 51],
        [204, 51, 0],
        [204, 0, 255],
        [204, 0, 204],
        [204, 0, 153],
        [204, 0, 102],
        [204, 0, 51],
        [204, 0, 0],
        [153, 255, 255],
        [153, 255, 204],
        [153, 255, 153],
        [153, 255, 102],
        [153, 255, 51],
        [153, 255, 0],
        [153, 204, 255],
        [153, 204, 204],
        [153, 204, 153],
        [153, 204, 102],
        [153, 204, 51],
        [153, 204, 0],
        [153, 153, 255],
        [153, 153, 204],
        [153, 153, 153],
        [153, 153, 102],
        [153, 153, 51],
        [153, 153, 0],
        [153, 102, 255],
        [153, 102, 204],
        [153, 102, 153],
        [153, 102, 102],
        [153, 102, 51],
        [153, 102, 0],
        [153, 51, 255],
        [153, 51, 204],
        [153, 51, 153],
        [153, 51, 102],
        [153, 51, 51],
        [153, 51, 0],
        [153, 0, 255],
        [153, 0, 204],
        [153, 0, 153],
        [153, 0, 102],
        [153, 0, 51],
        [153, 0, 0],
        [102, 255, 255],
        [102, 255, 204],
        [102, 255, 153],
        [102, 255, 102],
        [102, 255, 51],
        [102, 255, 0],
        [102, 204, 255],
        [102, 204, 204],
        [102, 204, 153],
        [102, 204, 102],
        [102, 204, 51],
        [102, 204, 0],
        [102, 153, 255],
        [102, 153, 204],
        [102, 153, 153],
        [102, 153, 102],
        [102, 153, 51],
        [102, 153, 0],
        [102, 102, 255],
        [102, 102, 204],
        [102, 102, 153],
        [102, 102, 102],
        [102, 102, 51],
        [102, 102, 0],
        [102, 51, 255],
        [102, 51, 204],
        [102, 51, 153],
        [102, 51, 102],
        [102, 51, 51],
        [102, 51, 0],
        [102, 0, 255],
        [102, 0, 204],
        [102, 0, 153],
        [102, 0, 102],
        [102, 0, 51],
        [102, 0, 0],
        [51, 255, 255],
        [51, 255, 204],
        [51, 255, 153],
        [51, 255, 102],
        [51, 255, 51],
        [51, 255, 0],
        [51, 204, 255],
        [51, 204, 204],
        [51, 204, 153],
        [51, 204, 102],
        [51, 204, 51],
        [51, 204, 0],
        [51, 153, 255],
        [51, 153, 204],
        [51, 153, 153],
        [51, 153, 102],
        [51, 153, 51],
        [51, 153, 0],
        [51, 102, 255],
        [51, 102, 204],
        [51, 102, 153],
        [51, 102, 102],
        [51, 102, 51],
        [51, 102, 0],
        [51, 51, 255],
        [51, 51, 204],
        [51, 51, 153],
        [51, 51, 102],
        [51, 51, 51],
        [51, 51, 0],
        [51, 0, 255],
        [51, 0, 204],
        [51, 0, 153],
        [51, 0, 102],
        [51, 0, 51],
        [51, 0, 0],
        [0, 255, 255],
        [0, 255, 204],
        [0, 255, 153],
        [0, 255, 102],
        [0, 255, 51],
        [0, 255, 0],
        [0, 204, 255],
        [0, 204, 204],
        [0, 204, 153],
        [0, 204, 102],
        [0, 204, 51],
        [0, 204, 0],
        [0, 153, 255],
        [0, 153, 204],
        [0, 153, 153],
        [0, 153, 102],
        [0, 153, 51],
        [0, 153, 0],
        [0, 102, 255],
        [0, 102, 204],
        [0, 102, 153],
        [0, 102, 102],
        [0, 102, 51],
        [0, 102, 0],
        [0, 51, 255],
        [0, 51, 204],
        [0, 51, 153],
        [0, 51, 102],
        [0, 51, 51],
        [0, 51, 0],
        [0, 0, 255],
        [0, 0, 204],
        [0, 0, 153],
        [0, 0, 102],
        [0, 0, 51],
        [238, 0, 0],
        [221, 0, 0],
        [187, 0, 0],
        [170, 0, 0],
        [136, 0, 0],
        [119, 0, 0],
        [85, 0, 0],
        [68, 0, 0],
        [34, 0, 0],
        [17, 0, 0],
        [0, 238, 0],
        [0, 221, 0],
        [0, 187, 0],
        [0, 170, 0],
        [0, 136, 0],
        [0, 119, 0],
        [0, 85, 0],
        [0, 68, 0],
        [0, 34, 0],
        [0, 17, 0],
        [0, 0, 238],
        [0, 0, 221],
        [0, 0, 187],
        [0, 0, 170],
        [0, 0, 136],
        [0, 0, 119],
        [0, 0, 85],
        [0, 0, 68],
        [0, 0, 34],
        [0, 0, 17],
        [238, 238, 238],
        [221, 221, 221],
        [187, 187, 187],
        [170, 170, 170],
        [136, 136, 136],
        [119, 119, 119],
        [85, 85, 85],
        [68, 68, 68],
        [34, 34, 34],
        [17, 17, 17],
        [0, 0, 0]
    ]
}
