// Authored by zhuzilin
// https://github.com/zhuzilin/SwiftPEG

import Foundation

class BootstrappingGrammar: Grammar {
    var hardCodeParser: Expression {
        // Hard-code enough of the rules to parse the grammar that describes the
        // grammar description language, to bootstrap:
        let comment = Regex(#"#[^\r\n]*"#, name: "comment")
        let meaninglessness = OneOf([Regex(#"\s+"#), comment], name: "meaninglessness")
        let ignorable = ZeroOrMore(meaninglessness, name: "_")

        let equals = Sequence([Literal("="), ignorable], name: "equals")
        let label = Sequence([Regex(#"[a-zA-Z_][a-zA-Z_0-9]*"#), ignorable], name: "label")
        let reference = Sequence([label, Not(equals)], name: "reference")
        let quantifier = Sequence([Regex(#"[*+?]"#), ignorable], name: "quantifier")
        // This pattern supports empty literals. TODO: A problem?
        let spaceless_literal = Regex(#""[^"\\]*(?:\\.[^"\\]*)*""#,
                                     name: "spaceless_literal")
        let literal = Sequence([spaceless_literal, ignorable], name: "literal")
        let regex = Sequence([Literal("~"),
                            spaceless_literal,
                            Regex(#"[ilmsuxa]*"#),
                            ignorable],
                            name: "regex")
        let atom = OneOf([reference, literal, regex], name: "atom")
        let quantified = Sequence([atom, quantifier], name: "quantified")

        let term = OneOf([quantified, atom], name: "term")
        let not_term = Sequence([Literal("!"), term, ignorable], name: "not_term")
        term.members = [not_term] + term.members

        let sequence = Sequence([term, OneOrMore(term)], name: "sequence")
        let or_term = Sequence([Literal("/"), ignorable, term], name: "or_term")
        let ored = Sequence([term, OneOrMore(or_term)], name: "ored")
        let expression = OneOf([ored, sequence, term], name: "expression")
        let rule = Sequence([label, equals, expression], name: "rule")
        let rules = Sequence([ignorable, OneOrMore(rule)], name: "rules")

        // Use those hard-coded rules to parse the (more extensive) rule syntax.
        // (For example, unless I start using parentheses in the rule language
        // definition itself, I should never have to hard-code expressions for
        // those above.)
        return rules
    }
    
    override func expression(from rules: String) -> [String: Expression] {
        // Turn the parse tree into a map of expressions:
        if let ruleTree: Node = hardCodeParser.parse(for: ruleSyntax) {
            return RuleVisitor().visitRules(ruleTree)
        }
        return [:]
    }
}

// The grammar for parsing PEG grammar definitions:
// This is a nice, simple grammar. We may someday add to it, but it's a safe bet
// that the future will always be a superset of this.
let ruleSyntax: String = #"""
    # Ignored things (represented by _) are typically hung off the end of the
    # leafmost kinds of nodes. Literals like "/" count as leaves.

    rules = _ rule+
    rule = label equals expression
    equals = "=" _
    literal = spaceless_literal _

    # So you can't spell a regex like `~"..." ilm`:
    spaceless_literal = ~"\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\""is

    expression = ored / sequence / term
    or_term = "/" _ term
    ored = term or_term+
    sequence = term term+
    not_term = "!" term _
    lookahead_term = "&" term _
    term = not_term / lookahead_term / quantified / atom
    quantified = atom quantifier
    atom = reference / literal / regex / parenthesized
    regex = "~" spaceless_literal ~"[ilmsuxa]*"i _
    parenthesized = "(" _ expression ")" _
    quantifier = ~"[*+?]" _
    reference = label !equals

    # A subsequent equal sign is the only thing that distinguishes a label
    # (which begins a new rule) from a reference (which is just a pointer to a
    # rule defined somewhere else):
    label = ~"[a-zA-Z_][a-zA-Z_0-9]*" _

    # _ = ~"\s*(?:#[^\r\n]*)?\s*"
    _ = meaninglessness*
    meaninglessness = ~"\s+" / comment
    comment = ~"#[^\r\n]*"
"""#

let ruleGrammar: BootstrappingGrammar = BootstrappingGrammar(rules: ruleSyntax)
