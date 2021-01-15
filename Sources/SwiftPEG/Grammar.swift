// Authored by zhuzilin
// https://github.com/zhuzilin/SwiftPEG

import Foundation

public class Grammar {
    public var ruleDict: [String: Expression] = [:]
    
    public init(rules: String) {
        ruleDict = expression(from: rules);
    }
    
    public func parse(for text: String, with ruleName: String) -> Node? {
        if let rule: Expression = ruleDict[ruleName] {
            return rule.parse(for: text)
        }
        return nil
    }
    
    func expression(from rules: String) -> [String: Expression] {
        if let tree: Node = ruleGrammar.parse(for: rules, with: "rules") {
            return RuleVisitor().visitRules(tree)
        }
        return [:]
    }
}
