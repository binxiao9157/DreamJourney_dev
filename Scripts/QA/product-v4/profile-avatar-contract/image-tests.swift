import UIKit
import ImageIO
import UniformTypeIdentifiers

func require(_ ok: @autoclosure () -> Bool, _ label: String) { if !ok() { fatalError(label) }; print("PASS: \(label)") }
let dir=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("avatar-"+UUID().uuidString)
try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
defer {try? FileManager.default.removeItem(at:dir)}
func write(_ data:Data,_ name:String)throws->URL {let u=dir.appendingPathComponent(name);try data.write(to:u);return u}
func pixels(_ data:Data)->[UInt8] {let cg=UIImage(data:data)!.cgImage!;var p=[UInt8](repeating:0,count:256*256*4);p.withUnsafeMutableBytes { b in let c=CGContext(data:b.baseAddress,width:256,height:256,bitsPerComponent:8,bytesPerRow:1024,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!;c.draw(cg,in:CGRect(x:0,y:0,width:256,height:256)) };return p}
let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=false
let large=UIGraphicsImageRenderer(size:CGSize(width:4000,height:3000),format:format).image{c in UIColor.red.setFill();c.fill(CGRect(x:1500,y:1000,width:1000,height:1000))}
let processed=try ProfileAvatarImageProcessor.jpeg(from:write(large.pngData()!,"large.png"))
let out=UIImage(data:processed)!;require(out.size==CGSize(width:256,height:256) && processed.count<=131072,"large transparent PNG -> bounded 256 JPEG")
let p=pixels(processed);require(p[0]>240 && p[1]>240 && p[2]>240,"transparent margins become white")
let center=(128*256+128)*4;require(p[center]>220 && p[center+1]<30,"center crop retains center content")
let small=UIGraphicsImageRenderer(size:CGSize(width:100,height:100),format:format).image{c in UIColor.red.setFill();c.fill(CGRect(x:0,y:0,width:50,height:100));UIColor.blue.setFill();c.fill(CGRect(x:50,y:0,width:50,height:100))}
let rotated=NSMutableData();let dest=CGImageDestinationCreateWithData(rotated,UTType.jpeg.identifier as CFString,1,nil)!
CGImageDestinationAddImage(dest,small.cgImage!,[kCGImagePropertyOrientation:6] as CFDictionary);require(CGImageDestinationFinalize(dest),"orientation fixture encoded")
let rd=try ProfileAvatarImageProcessor.jpeg(from:write(rotated as Data,"rotated.jpg"));let rp=pixels(rd)
let left=(128*256+20)*4,right=(128*256+230)*4,top=(20*256+128)*4,bottom=(230*256+128)*4
require(abs(Int(rp[left])-Int(rp[right]))<30 && abs(Int(rp[top])-Int(rp[bottom]))>180,"EXIF rotation applied to pixels")
let heic=NSMutableData()
if let hd=CGImageDestinationCreateWithData(heic,UTType.heic.identifier as CFString,1,nil) {
    CGImageDestinationAddImage(hd,small.cgImage!,nil)
    require(CGImageDestinationFinalize(hd),"HEIC fixture encoded")
    let h=try ProfileAvatarImageProcessor.jpeg(from:write(heic as Data,"static.heic"))
    require(UIImage(data:h)?.size==CGSize(width:256,height:256),"static HEIC converted to JPEG")
} else { fatalError("HEIC encoder unavailable; test not passed") }
func rejects(_ data:Data,_ name:String)throws {let u=try write(data,name);do {_ = try ProfileAvatarImageProcessor.jpeg(from:u);fatalError("accepted \(name)")}catch {print("PASS: rejected \(name)")}}
try rejects(Data("not an image".utf8),"invalid.jpg")
try rejects(Data(repeating:0,count:30*1024*1024+1),"oversize.jpg")
let gif=NSMutableData();let gd=CGImageDestinationCreateWithData(gif,UTType.gif.identifier as CFString,2,nil)!;CGImageDestinationAddImage(gd,small.cgImage!,nil);CGImageDestinationAddImage(gd,large.cgImage!,nil);require(CGImageDestinationFinalize(gd),"animated fixture encoded");try rejects(gif as Data,"animated.gif")
print("IMAGE_PROCESSOR_PASS")
