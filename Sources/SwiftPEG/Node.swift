// Authored by zhuzilin
// https://github.com/zhuzilin/SwiftPEG

import Foundation

public struct Node: CustomStringConvertible, Equatable {
    public let expr: Expression
    // Swift has copy-on-write mechanism on string.
    // So it's fine to have a copy of the full test in every Node.
    let full_text: String
    let start: String.Index
    let end: String.Index
    public var children: [Node] = []
    
    public var expr_name: String { expr.name }
    public var text: String { String(full_text[start..<end]) }
    
    public var description: String {
        toString(withName: true)
    }
    
    public func toString(withName: Bool = false) -> String {
        var str: String = ""
        if withName {
            str += "\(expr_name) = "
            print(expr_name)
        }
        switch expr.type {
            case .literal:
                str += "\(text)"
            case .regex:
                str += "\(text)"
            case .sequence:
                for i in 0..<children.count {
                    str += (i == children.count-1 ? "" : " ") + children[i].toString()
                }
            case .oneOf:
                str += children[0].toString()
            case .lookahead:
                break
            case .not:
                break
            case .optional:
                if children.count == 1 {
                    str += children[0].toString()
                }
            case .zeroOrMore:
                for i in 0..<children.count {
                    str += (i == children.count-1 ? "" : " ") + children[i].toString()
                }
            case .oneOrMore:
                for i in 0..<children.count {
                    str += (i == children.count-1 ? "" : " ") + children[i].toString()
                }
            default:
                break
        }
        return str
    }
    
    public static func ==(lhs: Node, rhs: Node) -> Bool {
        if lhs.text != rhs.text || lhs.expr_name != rhs.expr_name ||
            lhs.expr.type != rhs.expr.type || lhs.children.count != rhs.children.count {
            return false
        }
        for i in 0..<lhs.children.count {
            if lhs.children[i] != rhs.children[i] {
                return false
            }
        }
        return true
    }
}
