import XCTest
@testable import SwiftPEG

final class swift_pegTests: XCTestCase {
    func testBootstrappingGrammar() {
        // This test will recreate the hardcodeParser used in BootstappingGrammar with
        // the parser generator we have.
        
        // This is the syntax of the hardcodeParser in BootstrappingGrammar
        let hardcodeSyntax: String = #"""
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
             term = not_term / quantified / atom
             quantified = atom quantifier
             atom = reference / literal / regex
             regex = "~" spaceless_literal ~"[ilmsuxa]*"i _
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

        let hardcodeTree: Node = BootstrappingGrammar(rules: "").hardCodeParser.parse(for: hardcodeSyntax)!
        
        let ruleDict: [String: Expression] = RuleVisitor().visitRules(hardcodeTree)
        
        let generatedTree: Node = ruleDict["rules"]!.parse(for: hardcodeSyntax)!
        XCTAssertTrue(hardcodeTree == generatedTree)
    }
    
    func testGrammar() {
        // This test is trying to make sure the ruleGrammar is the same as
        // one generated from Grammar
        let node1: Node = ruleGrammar.parse(for: ruleSyntax, with: "rules")!
        let node2: Node = Grammar(rules: ruleSyntax).parse(for: ruleSyntax, with: "rules")!
        XCTAssertTrue(node1 == node2)
    }
    
    static var allTests = [
        ("BootstrappingGrammar", testBootstrappingGrammar),
        ("Grammar", testGrammar),
    ]
}
