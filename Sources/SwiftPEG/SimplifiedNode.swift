//
//  SimplifiedNode.swift
//  SwiftPEG
//
//  Created by Zilin Zhu on 2021/1/19.
//

import Foundation

public struct SimplifiedNode: CustomStringConvertible {
    let full_text: String
    public let start: String.Index
    public let end: String.Index
    public var children: [SimplifiedNode] = []

    public let name: String
    public var text: String { String(full_text[start..<end]) }

    public var description: String {
        if children.count == 0 {
            return "<\(name)\\>"
        }
        let header: String = "<\(name)>"
        let tail: String = "</\(name)>"

        var childStr: String = ""
        for i in 0..<children.count {
            let child = children[i]
            childStr += "\(child)" + (i != children.count - 1 ? "\n" : "")
        }

        if childStr.count < 80 {
            childStr = childStr.replacingOccurrences(of: "\n", with: ", ")
            if header.count + childStr.count + tail.count < 80 {
                return header + " " + childStr + " " + tail
            } else {
                return header + "\n  " + childStr + "\n" + tail
            }
        } else {
            childStr = childStr.replacingOccurrences(of: "\n", with: "\n  ")
            return header + "\n  " + childStr + "\n" + tail
        }
    }
}

public func simplify(for node: Node) -> SimplifiedNode? {
    guard node.name != "" else {
        print("can only simplify node with name")
        return nil
    }
    var simplifiedNode = SimplifiedNode(full_text: node.full_text, start: node.start, end: node.end, name: node.name)
    for child in node.children {
        simplifiedNode.children += simplifyNodeToList(for: child)
    }
    return simplifiedNode
}

func simplifyNodeToList(for node: Node) -> [SimplifiedNode] {
    if node.name != "" {
        return [simplify(for: node)!]
    }
    var result: [SimplifiedNode] = []
    for child in node.children {
        result += simplifyNodeToList(for: child)
    }
    return result
}
