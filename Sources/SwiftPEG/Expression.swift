// Authored by zhuzilin
// https://github.com/zhuzilin/SwiftPEG

import Foundation

public enum ExpressionType {
    case none

    case literal
    case regex

    case compound
    case sequence
    case oneOf

    case singleton
    case lookahead
    case not
    case optional
    case zeroOrMore
    case oneOrMore
    
    case lazyReference
}

public class Expression: CustomStringConvertible {
    public var name: String
    public var type: ExpressionType
    
    init(name: String, type: ExpressionType = .none) {
        self.name = name
        self.type = type
    }

    public func parse(for text: String, at pos: String.Index) -> Node? {
        return nil
    }

    public func parse(for text: String) -> Node? {
        return parse(for: text, at: text.startIndex)
    }
    
    public var description: String {
        "\(name)(\(type))"
    }
}

public class Literal: Expression {
    let literal: String

    init(_ literal: String, name: String = "") {
        self.literal = literal
        super.init(name: name, type: .literal)
    }

    public override func parse(for text: String, at pos: String.Index) -> Node? {
        if text[pos...].hasPrefix(literal) {
            return Node(expr: self, full_text: text, start: pos,
                        end: text.index(pos, offsetBy: literal.count))
        }
        return nil
    }
    
    public override var description: String {
        "\"\(literal)\""
    }
}

public class Regex: Expression {
    let pattern: String

    init(_ pattern: String, name: String = "") {
        self.pattern = "^" + pattern
        super.init(name: name, type: .regex)
    }

    public override func parse(for text: String, at pos: String.Index) -> Node? {
        let substr = text[pos...]
        if let range = substr.range(of: pattern, options: .regularExpression) {
            let matched_string = substr[range]
            return Node(expr: self, full_text: text, start: pos,
                        end: text.index(pos, offsetBy: matched_string.count))
        } else {
            return nil
        }
    }
    
    public override var description: String {
        return "~\"\(pattern)\""
    }
}

public class Compound: Expression {
    public var members: [Expression]
    var separator: String { " " }
    
    init(_ exprs: [Expression], name: String = "", type: ExpressionType = .compound) {
        members = exprs
        super.init(name: name, type: type)
        for i in 0..<members.count {
            if members[i].type == .lazyReference {
                let lazyReference = members[i] as! LazyReference
                lazyReference.parent = self
                lazyReference.parentMemberIdx = i
            }
        }
    }
    
    public override var description: String {
        var str: String = ""
        for i in 0..<members.count {
            let member = members[i]
            var memberStr: String
            if member.type == .sequence || member.type == .oneOf {
                memberStr = "\(member.name)(\(member.type))"
            } else {
                memberStr = "\(member)"
            }
            str += (i == 0 ? "" : separator) + memberStr
        }
        return str
    }
}

public class Sequence: Compound {
    init(_ members: [Expression], name: String = "") {
        super.init(members, name: name, type: .sequence)
    }
    
    public override func parse(for text: String, at pos: String.Index) -> Node? {
        var new_pos: String.Index = pos
        var children: [Node] = []
        for expr in members {
            if let node = expr.parse(for: text, at: new_pos) {
                children.append(node)
                new_pos = node.end
            } else {
                return nil
            }
        }
        return Node(expr: self, full_text: text, start: pos, end: new_pos, children: children)
    }
}

public class OneOf: Compound {
    override var separator: String { " | " }

    init(_ members: [Expression], name: String = "") {
        super.init(members, name: name, type: .oneOf)
    }
    
    public override func parse(for text: String, at pos: String.Index) -> Node? {
        for expr in members {
            if let node = expr.parse(for: text, at: pos) {
                return Node(expr: self, full_text: text, start: pos, end: node.end, children: [node])
            }
        }
        return nil
    }
}

public class Singleton: Expression {
    public var member: Expression
    var prefix: String { "" }
    var suffix: String { "" }
    
    init(_ expr: Expression, name: String = "", type: ExpressionType = .singleton) {
        member = expr
        super.init(name: name, type: type)
        if member.type == .lazyReference {
            let lazyReference = member as! LazyReference
            lazyReference.parent = self
        }
    }
    
    public override var description: String {
        "\(prefix)(\(member))\(suffix)"
    }
}

public class Lookahead: Singleton {
    override var prefix: String { "&" }
    
    init(_ member: Expression, name: String = "") {
        super.init(member, name: name, type: .lookahead)
    }
    
    public override func parse(for text: String, at pos: String.Index) -> Node? {
        if member.parse(for: text, at: pos) != nil {
            return Node(expr: self, full_text: text, start: pos, end: pos)
        }
        return nil
    }
}

public class Not: Singleton {
    override var prefix: String { "!" }
    
    init(_ member: Expression, name: String = "") {
        super.init(member, name: name, type: .not)
    }
    
    public override func parse(for text: String, at pos: String.Index) -> Node? {
        if member.parse(for: text, at: pos) == nil {
            return Node(expr: self, full_text: text, start: pos, end: pos)
        }
        return nil
    }
}

public class Optional: Singleton {
    override var suffix: String { "?" }
    
    init(_ member: Expression, name: String = "") {
        super.init(member, name: name, type: .optional)
    }
    
    public override func parse(for text: String, at pos: String.Index) -> Node? {
        if let node = member.parse(for: text, at: pos) {
            return Node(expr: self, full_text: text, start: pos, end: node.end, children: [node])
        }
        return Node(expr: self, full_text: text, start: pos, end: pos)
    }
}

public class ZeroOrMore: Singleton {
    override var suffix: String { "*" }
    
    init(_ member: Expression, name: String = "") {
        super.init(member, name: name, type: .zeroOrMore)
    }
    
    public override func parse(for text: String, at pos: String.Index) -> Node? {
        var new_pos: String.Index = pos
        var children: [Node] = []
        while true {
            if let node = member.parse(for: text, at: new_pos) {
                if node.end == node.start {
                    break
                }
                children.append(node)
                new_pos = node.end
            } else {
                break
            }
        }
        return Node(expr: self, full_text: text, start: pos, end: new_pos, children: children)
    }
}

public class OneOrMore: Singleton {
    let min: Int
    override var suffix: String { "+" }
    
    init(_ member: Expression, min: Int = 1, name: String = "") {
        self.min = min
        super.init(member, name: name, type: .zeroOrMore)
    }

    public override func parse(for text: String, at pos: String.Index) -> Node? {
        var new_pos: String.Index = pos
        var children: [Node] = []
        while true {
            if let node = member.parse(for: text, at: new_pos) {
                if node.end == node.start {
                    break
                }
                children.append(node)
                new_pos = node.end
            } else {
                break
            }
        }
        guard children.count >= min else {
            return nil
        }
        return Node(expr: self, full_text: text, start: pos, end: new_pos, children: children)
    }
}


// lazy reference used to connect rules
public class LazyReference: Expression {
    public var parent: Expression?
    public var parentMemberIdx: Int = -1
    init(name: String) {
        super.init(name: name, type: .lazyReference)
    }
}
