# SwiftPEG

A PEG parser generator written in swift 5.3. The code structure and grammar are largely learnt from the excellent python package [parsimonious](https://github.com/erikrose/parsimonious). If you are doing some parsing using python, you should definitely check it out.

The nice part of this parser generator is that its PEG rule parser is also generated from a PEG syntax with a bootstrap manner, and the bootstrap hardcoding parser can also be generated from itself. The rule syntax is:

```
    rules = _ rule+
    rule = label equals expression
    equals = "=" _
    literal = spaceless_literal _

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

    label = ~"[a-zA-Z_][a-zA-Z_0-9]*" _

    _ = meaninglessness*
    meaninglessness = ~"\s+" / comment
    comment = ~"#[^\r\n]*"
```

Notice that the above syntax is the same as [parsimonious](https://github.com/erikrose/parsimonious).

To write a proper PEG syntax, please follow the [PEG syntax reference](https://www.gnu.org/software/guile/manual/html_node/PEG-Syntax-Reference.html).

## Usage

In your `Package.swift`, add the following code to dependencies:

```swift
.package(name: "SwiftPEG", url: "https://github.com/zhuzilin/SwiftPEG.git", from: "0.1.0"),
```

And add `"SwiftPEG"` to target dependencies.

## Example

Here is an example of a simplified markdown parser.

```swift
let markdownSyntax = #"""
    raw_text = ~"[^\n]+"
    bold_text = ("**" raw_text "**") / ("__" raw_text "__")
    text = (bold_text / raw_text)

    h1 = "# " text
    h2 = "## " text
    h3 = "### " text
    h4 = "#### " text
    h5 = "##### " text
    h6 = "######" text
    header = (h6 / h5 / h4 / h3 / h2 / h1)

    ordered_list = (~"[0~9]+\. " text ~"\n")+

    unordered_list = (~"[-*+] " text ~"\n")+

    link = "[" raw_text "]" "(" raw_text ")"

    image = "![" raw_text "]" "(" raw_text ")"

    paragraph = (header / text)?
    doc = (paragraph ~"\n\n")* paragraph
"""#

// Initialize the parser
let markdownParser: Grammar = Grammar(rules: markdownSyntax)
// Get the AST root node from the parser with the name of the rule you defined in the syntax.
let ast: Node = grammar.parse(for: text, with: "doc")
// Then do what ever you like with the AST
...
```

## API

### Grammar

`Grammar` type has the following public interfaces:

```swift
public class Grammar {
    // Name dict of the parsing rules defined in the syntax
    // It will be generated upon init.
    // If it is empty it means there is some error in the syntax.
    public var ruleDict: [String: Expression] = [:]
    
    public init(rules: String)
    // Return nil if the parsing failed
    public func parse(for text: String, with ruleName: String) -> Node?
    
    func expression(from rules: String) -> [String: Expression] {
        if let tree: Node = ruleGrammar.parse(for: rules, with: "rules") {
            return RuleVisitor().visitRules(tree)
        }
        return [:]
    }
}
```

### Node

`Node` type has the following public interfaces:

```swift
public struct Node: CustomStringConvertible, Equatable {
    // The parser node used to parse this node
    public let expr: Expression
    public var expr_name: String { expr.name }
    // The children nodes
    public var children: [Node] = []
    // The matched text of this Node
    public var text: String

    public var description: String {
        toString(withName: true)
    }
    public func toString(withName: Bool = false) -> String

  	public static func ==(lhs: Node, rhs: Node) -> Bool
}
```

### Expression

Normally you should not work with this type. If you have interest, please check `Expression.swift` for more information.

## TODO

- Support better error handling.
- Optimize the performance with memoization.