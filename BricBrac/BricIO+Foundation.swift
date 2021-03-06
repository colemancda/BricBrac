//
//  BricIO+Cocoa.swift
//  Bric-à-brac
//
//  Created by Marc Prud'hommeaux on 7/20/15.
//  Copyright © 2015 io.glimpse. All rights reserved.
//

import Foundation
import CoreFoundation

public extension Bric {

    /// Validates the given JSON string and throws an error if there was a problem
    public static func parseCocoa(_ string: String, options: JSONParser.Options = .CocoaCompat) throws -> NSObject {
        return try FoundationBricolage.parseJSON(Array(string.unicodeScalars), options: options).object
    }

    /// Validates the given array of unicode scalars and throws an error if there was a problem
    public static func parseCocoa(_ scalars: [UnicodeScalar], options: JSONParser.Options = .CocoaCompat) throws -> NSObject {
        return try FoundationBricolage.parseJSON(scalars, options: options).object
    }
}


/// Bricolage that represents the elements as Cocoa NSObject types with reference semantics
public final class FoundationBricolage: NSObject, Bricolage {
    public typealias NulType = NSNull
    public typealias BolType = NSNumber
    public typealias StrType = NSString
    public typealias NumType = NSNumber
    public typealias ArrType = NSMutableArray
    public typealias ObjType = NSMutableDictionary

    public let object: NSObject

    public init(str: StrType) { self.object = str }
    public init(num: NumType) { self.object = num }
    public init(bol: BolType) { self.object = bol }
    public init(arr: ArrType) { self.object = arr }
    public init(obj: ObjType) { self.object = obj }
    public init(nul: NulType) { self.object = nul }

    public static func createNull() -> NulType { return NSNull() }
    public static func createTrue() -> BolType { return true }
    public static func createFalse() -> BolType { return false }
    public static func createObject() -> ObjType { return ObjType() }
    public static func createArray() -> ArrType { return ArrType() }

    public static func createString(_ scalars: [UnicodeScalar]) -> StrType? {
        return String(String.UnicodeScalarView() + scalars) as NSString
    }

    public static func createNumber(_ scalars: [UnicodeScalar]) -> NumType? {
        if let str: NSString = createString(Array(scalars)) {
            return NSDecimalNumber(string: str as String) // needed for 0.123456789e-12
        } else {
            return nil
        }
    }

    public static func putKeyValue(_ obj: ObjType, key: StrType, value: FoundationBricolage) -> ObjType {
        obj.setObject(value.object, forKey: key)
        return obj
    }

    public static func putElement(_ arr: ArrType, element: FoundationBricolage) -> ArrType {
        arr.add(element.object)
        return arr
    }
}


extension FoundationBricolage : Bricable, Bracable {
    public func bric() -> Bric {
        return FoundationBricolage.toBric(object)
    }

    fileprivate static let bolTypes = Set(arrayLiteral: "B", "c") // "B" on 64-bit, "c" on 32-bit
    fileprivate static func toBric(_ object: Any) -> Bric {
        if let bol = object as? BolType , bolTypes.contains(String(cString: bol.objCType)) {
            if let b = bol as? Bool {
                return Bric.bol(b)
            } else {
                return Bric.bol(false)
            }
        }
        if let str = object as? StrType {
            return Bric.str(str as String)
        }
        if let num = object as? NumType {
            if let d = num as? Double {
                return Bric.num(d)
            } else {
                return Bric.num(0.0)
            }
        }
        if let arr = object as? ArrType {
            return Bric.arr(arr.map(toBric))
        }
        if let obj = object as? ObjType {
            var dict: [String: Bric] = [:]
            for (key, value) in obj {
                dict[String(describing: key)] = toBric(value as AnyObject)
            }
            return Bric.obj(dict)
        }

        return Bric.nul
    }

    public static func brac(bric: Bric) -> FoundationBricolage {
        switch bric {
        case .nul:
            return FoundationBricolage(nul: FoundationBricolage.createNull())
        case .bol(let bol):
            return FoundationBricolage(bol: bol ? FoundationBricolage.createTrue() : FoundationBricolage.createFalse())
        case .str(let str):
            return FoundationBricolage(str: FoundationBricolage.StrType(string: str))
        case .num(let num):
            return FoundationBricolage(num: FoundationBricolage.NumType(value: num))
        case .arr(let arr):
            let nsarr = FoundationBricolage.createArray()
            for a in arr {
                _ = FoundationBricolage.putElement(nsarr, element: FoundationBricolage.brac(bric: a))
            }
            return FoundationBricolage(arr: nsarr)
        case .obj(let obj):
            let nsobj = FoundationBricolage.createObject()
            for (k, v) in obj {
                _ = FoundationBricolage.putKeyValue(nsobj, key: k as NSString, value: FoundationBricolage.brac(bric: v))
            }
            return FoundationBricolage(obj: nsobj)
        }
    }
}

/// Bricolage that represents the elements as Core Foundation types with reference semantics
public final class CoreFoundationBricolage: Bricolage {
    public typealias NulType = CFNull
    public typealias BolType = CFBoolean
    public typealias StrType = CFString
    public typealias NumType = CFNumber
    public typealias ArrType = CFMutableArray
    public typealias ObjType = CFMutableDictionary

    public let ptr: UnsafeMutableRawPointer

    public init(str: StrType) { self.ptr = Unmanaged.passRetained(str).toOpaque() }
    public init(num: NumType) { self.ptr = Unmanaged.passRetained(num).toOpaque() }
    public init(bol: BolType) { self.ptr = Unmanaged.passRetained(bol).toOpaque() }
    public init(arr: ArrType) { self.ptr = Unmanaged.passRetained(arr).toOpaque() }
    public init(obj: ObjType) { self.ptr = Unmanaged.passRetained(obj).toOpaque() }
    public init(nul: NulType) { self.ptr = Unmanaged.passRetained(nul).toOpaque() }

    deinit {
        Unmanaged<AnyObject>.fromOpaque(ptr).release()
    }

    public static func createNull() -> NulType { return kCFNull }
    public static func createTrue() -> BolType { return kCFBooleanTrue }
    public static func createFalse() -> BolType { return kCFBooleanFalse }
    public static func createObject() -> ObjType { return CFDictionaryCreateMutable(nil, 0, nil, nil) }
    public static func createArray() -> ArrType { return CFArrayCreateMutable(nil, 0, nil) }

    public static func createString(_ scalars: [UnicodeScalar]) -> StrType? {
        return String(String.UnicodeScalarView() + scalars) as CoreFoundationBricolage.StrType?
    }

    public static func createNumber(_ scalars: [UnicodeScalar]) -> NumType? {
        if let str = createString(Array(scalars)) {
            return NSDecimalNumber(string: str as String) // needed for 0.123456789e-12
        } else {
            return nil
        }
    }

    public static func putKeyValue(_ obj: ObjType, key: StrType, value: CoreFoundationBricolage) -> ObjType {
        CFDictionarySetValue(obj, UnsafeRawPointer(Unmanaged<CFString>.passRetained(key).toOpaque()), value.ptr)
        return obj
    }

    public static func putElement(_ arr: ArrType, element: CoreFoundationBricolage) -> ArrType {
        CFArrayAppendValue(arr, element.ptr)
        return arr
    }
}
