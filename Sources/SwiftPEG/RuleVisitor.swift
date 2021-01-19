// Authored by zhuzilin
// https://github.com/zhuzilin/SwiftPEG

import Foundation

class RuleVisitor {
    var lazyReferences: [LazyReference] = []
    // rules = _ rule+
    func visitRules(_ node: Node) -> [String: Expression] {
        guard node.name == "rules" else {
            return [:]
        }
        let rules: [Expression] = visitOneOrMore(node.children[1])
        var ruleDict: [String: Expression] = [:]
        for rule in rules {
            ruleDict[rule.name] = rule
        }
        substituteLazyReference(with: ruleDict)
        return ruleDict
    }

    // In our syntax, OneOrMore will only appear in the following 3 places
    //
    //   rules = _ rule+
    //   ored = term or_term+
    //   sequence = term term+
    //
    func visitOneOrMore(_ node: Node) -> [Expression] {
        let transformFunc: (Node) -> Expression?
        switch node.children[0].name {
            case "rule":
                transformFunc = visitRule
            case "or_term":
                transformFunc = visitOrTerm
            case "term":
                transformFunc = visitTerm
            default:
                return []
        }
        var exprs: [Expression] = []
        for child in node.children {
            if let expr = transformFunc(child) {
                exprs.append(expr)
            } else {
                return []
            }
        }
        return exprs
    }

    // rule = label equals expression
    func visitRule(_ node: Node) -> Expression? {
        guard node.name == "rule" else {
            return nil
        }
        let label: String = visitLabel(node.children[0])
        if var expression = visitExpression(node.children[2]) {
            // To prevent rules like "a = b"
            if expression.type == .lazyReference {
                expression = Sequence([expression])
            }
            expression.name = label
            return expression
        }
        return nil
    }

    // label = ~"[a-zA-Z_][a-zA-Z_0-9]*" _
    func visitLabel(_ node: Node) -> String {
        guard node.name == "label" else {
            return ""
        }
        return node.children[0].text
    }

    // expression = ored / sequence / term
    func visitExpression(_ node: Node) -> Expression? {
        guard node.name == "expression" else {
            return nil
        }
        switch node.children[0].name {
            case "ored":
                return visitOred(node.children[0])
            case "sequence":
                return visitSequence(node.children[0])
            case "term":
                return visitTerm(node.children[0])
            default:
                return nil
        }
    }
    
    // ored = term or_term+
    func visitOred(_ node: Node) -> Expression? {
        guard node.name == "ored" else {
            return nil
        }
        if let term = visitTerm(node.children[0]) {
            let orTerms: [Expression] = visitOneOrMore(node.children[1])
            return OneOf([term] + orTerms)
        }
        return nil
    }
    
    // sequence = term term+
    func visitSequence(_ node: Node) -> Expression? {
        guard node.name == "sequence" else {
            return nil
        }
        if let term = visitTerm(node.children[0]) {
            let otherTerms: [Expression] = visitOneOrMore(node.children[1])
            return Sequence([term] + otherTerms)
        }
        return nil
    }

    // term = not_term / lookahead_term / quantified / atom
    func visitTerm(_ node: Node) -> Expression? {
        guard node.name == "term" else {
            return nil
        }
        switch node.children[0].name {
            case "not_term":
                return visitNotTerm(node.children[0])
            case "lookahead_term":
                return visitLookaheadTerm(node.children[0])
            case "quantified":
                return visitQuantified(node.children[0])
            case "atom":
                return visitAtom(node.children[0])
            default:
                return nil
        }
    }

    // not_term = "!" term _
    func visitNotTerm(_ node: Node) -> Expression? {
        guard node.name == "not_term" else {
            return nil
        }
        if let term = visitTerm(node.children[1]) {
            return Not(term)
        }
        return nil
    }
    
    // lookahead_term = "&" term _
    func visitLookaheadTerm(_ node: Node) -> Expression? {
        guard node.name == "lookahead_term" else {
            return nil
        }
        if let term = visitTerm(node.children[1]) {
            return Lookahead(term)
        }
        return nil
    }
    
    // or_term = "/" _ term
    func visitOrTerm(_ node: Node) -> Expression? {
        guard node.name == "or_term" else {
            return nil
        }
        return visitTerm(node.children[2])
    }
    
    // quantified = atom quantifier
    // quantifier = ~"[*+?]" _
    func visitQuantified(_ node: Node) -> Expression? {
        guard node.name == "quantified" else {
            return nil
        }
        if let atom = visitAtom(node.children[0]) {
            let qualifier: Node = node.children[1]
            switch qualifier.children[0].text {
                case "?":
                    return Optional(atom)
                case "+":
                    return OneOrMore(atom)
                case "*":
                    return ZeroOrMore(atom)
                default:
                    return nil
            }
        }
        return nil
    }
    
    // atom = reference / literal / regex / parenthesized
    func visitAtom(_ node: Node) -> Expression? {
        guard node.name == "atom" else {
            return nil
        }
        switch node.children[0].name {
            case "reference":
                return visitReference(node.children[0])
            case "literal":
                return visitLiteral(node.children[0])
            case "regex":
                return visitRegex(node.children[0])
            case "parenthesized":
                return visitExpression(node.children[0].children[2])
            default:
                return nil
        }
    }
    
    // reference = label !equals
    func visitReference(_ node: Node) -> Expression? {
        guard node.name == "reference" else {
            return nil
        }
        let lazyReference: LazyReference = LazyReference(name: visitLabel(node.children[0]))
        lazyReferences.append(lazyReference)
        return lazyReference
    }
    
    // literal = spaceless_literal _
    func visitLiteral(_ node: Node) -> Expression? {
        guard node.name == "literal" else {
            return nil
        }

        let withQuote: String = node.children[0].text
        let literal: String = String(withQuote[withQuote.index(withQuote.startIndex, offsetBy: 1)..<withQuote.index(withQuote.endIndex, offsetBy: -1)])
        return Literal(literal)
    }
    
    // regex = "~" spaceless_literal ~"[ilmsuxa]*"i _
    func visitRegex(_ node: Node) -> Expression? {
        guard node.name == "regex" else {
            return nil
        }
        // TODO: The second literal should only contain space, add check.
        // Notice we need to get the spaceless literal
        let escaped_spaceless_literal = node.children[1].text
        // Also, the parsed regex needs to be "reverse-escaped"
        // For example, the matched "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\""
        // needs to be turn back to ""[^"\\]*(?:\\.[^"\\]*)*""
        let spaceless_literal = escaped_spaceless_literal
                                    .replacingOccurrences(of: #"\\"#, with: #"\"#)
                                    .replacingOccurrences(of: #"\""#, with: "\"")
        let withQuote: String = spaceless_literal
        let regex: String = String(withQuote[withQuote.index(withQuote.startIndex, offsetBy: 1)..<withQuote.index(withQuote.endIndex, offsetBy: -1)])
        return Regex(regex)
    }
    
    func substituteLazyReference(with ruleDict: [String: Expression]) {
        for lazyReference in lazyReferences {
            if let parent = lazyReference.parent {
                let label = lazyReference.name
                let rule: Expression = ruleDict[label]!
                switch parent.type {
                    case .sequence:
                        fallthrough
                    case .oneOf:
                        let compound = parent as! Compound
                        compound.members[lazyReference.parentMemberIdx] = rule
                    case .lookahead:
                        fallthrough
                    case .not:
                        fallthrough
                    case .optional:
                        fallthrough
                    case .zeroOrMore:
                        fallthrough
                    case .oneOrMore:
                        let singleton = parent as! Singleton
                        singleton.member = rule
                    default:
                        break
                }
            }
        }
    }
}
