//
//  ForthStackEffect.swift
//  EditForth
//
//  Deterministic data-stack model for Ask Forth. Not a neural net.
//  Each colon definition is traced from an empty stack. An underflow is an
//  input (the first pop is TOS). Control-flow snapshots are amended when a
//  later underflow shows that input was there from the start.
//

import Foundation

enum ForthStackEffect {
    /// Always added to the Ask Forth system prompt.
    static let promptRule = """
    A deterministic stack model traces colon definitions from an empty data stack. An underflow is an input; the first missing item is TOS. When the user message contains a Stack model block, copy a comment marked copy. Do not invent a different ( before -- after ) for that definition. If the block says not inferred, say so instead of guessing a stack comment.
    """

    /// Closed colon definitions only. Prose and unclosed ":" return nil.
    static func report(source: String) -> String? {
        let text = forthText(from: source)
        let defs = Analyzer(text).definitions(limit: 50)
        guard !defs.isEmpty else { return nil }
        return format(defs)
    }

    /// Tool entry. A fragment such as `DUP +` is traced as one definition.
    static func toolResult(source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Pass a colon definition, or a fragment such as DUP + ."
        }
        if let report = report(source: trimmed) {
            return report
        }
        let wrapped = ": FRAGMENT\n" + trimmed + "\n;"
        return report(source: wrapped) ?? "Nothing to trace."
    }

    /// Empty when the model matches these cases. Used by the standalone check.
    static func selfCheckFailures() -> [String] {
        var fails: [String] = []
        func check(_ title: String, _ source: String, contains: [String], absent: [String] = []) {
            guard let text = report(source: source) else {
                fails.append("\(title): no report")
                return
            }
            for needle in contains where !text.contains(needle) {
                fails.append("\(title): missing [\(needle)]\n\(text)")
            }
            for needle in absent where text.contains(needle) {
                fails.append("\(title): unexpected [\(needle)]\n\(text)")
            }
        }
        if promptRule.contains("stack_effect") {
            fails.append("promptRule must not name the tool; tools may be off")
        }
        if report(source: "what does DUP do?") != nil {
            fails.append("prose should not produce a report")
        }
        if report(source: "the word : starts a definition") != nil {
            fails.append("unclosed colon should not produce a report")
        }
        check("DUP", ": T DUP ;", contains: [": T ( x -- x x ) — copy"])
        check("SWAP", ": T SWAP ;", contains: [": T ( x1 x2 -- x2 x1 ) — copy"])
        check("OVER", ": T OVER ;", contains: [": T ( x1 x2 -- x1 x2 x1 ) — copy"])
        check("ROT", ": T ROT ;", contains: [": T ( x1 x2 x3 -- x2 x3 x1 ) — copy"])
        check("DROP", ": T DROP ;", contains: [": T ( x -- ) — copy"])
        check("PLUS", ": T + ;", contains: [": T ( n1 n2 -- n3 ) — copy"])
        check("DUP+", ": T DUP + ;", contains: [": T ( x -- n3 ) — copy"])
        check("literals", ": T 10 0 ;", contains: [": T ( -- 10 0 ) — copy"])
        check("do-literals", ": T 10 0 DO I . LOOP ;", contains: [": T ( -- ) — copy"])
        check("do-inputs", ": T DO I . LOOP ;", contains: [": T ( limit index -- ) — copy"])
        check("countdown", ": T BEGIN DUP WHILE 1- REPEAT DROP ;", contains: [": T ( x -- ) — copy"])
        check(
            "while-carry",
            ": STEP ( n -- n' ) BEGIN DUP 0= WHILE 1+ REPEAT ;",
            contains: [": STEP ( n -- n' ) — copy"]
        )
        check("s-quote", ": T S\" hi\" ;", contains: [": T ( -- c-addr u ) — copy"])
        check("file-size", ": T FILE-SIZE ;", contains: [": T ( fileid -- ud ior ) — copy"])
        check("match", ": T ( x1 x2 -- x2 x1 ) SWAP ;", contains: [": T ( x1 x2 -- x2 x1 ) — copy"])
        check(
            "mismatch",
            ": T ( x1 x2 -- x1 x2 ) SWAP ;",
            contains: ["( x1 x2 -- x2 x1 ) — copy", "does not match"]
        )
        check("one-plus", ": T ( n -- n ) 1+ ;", contains: [": T ( n -- n ) — copy"])
        check("unknown", ": T ZORCH ;", contains: ["not inferred", "ZORCH"], absent: ["— copy"])
        check("unbalanced-if", ": T IF DROP THEN ;", contains: ["not inferred"], absent: ["— copy"])
        check("if-else", ": T IF 1 ELSE 2 THEN ;", contains: ["( flag -- "])
        check("qdup-if", ": T ?DUP IF DROP THEN ;", contains: [": T ( x -- ) — copy"])
        check("qdup-open", ": T ?DUP ;", contains: ["not a single effect"], absent: ["— copy"])
        check("exit-flag", ": T IF EXIT THEN ;", contains: [": T ( flag -- ) — copy"])
        check("exit-drop", ": T IF EXIT THEN DROP ;", contains: ["not inferred"], absent: ["— copy"])
        check("no-2plus", ": T 2+ ;", contains: ["not inferred", "2+"], absent: ["— copy"])
        check("rstack", ": T >R ;", contains: ["not inferred", "return stack"])
        check("r-roundtrip", ": T >R R> ;", contains: [": T ( x -- x ) — copy"])
        check("xunit", ": XUNIT [ 1 XBITS LSHIFT ] LITERAL ;", contains: [": XUNIT ( -- x ) — copy"])
        check("locals-bar", ": LO-A LOCALS| x | x ;", contains: [": LO-A ( x -- x ) — copy"])
        check("locals-mul", ": LO-H LOCALS| x y | x y * ;", contains: [": LO-H ( y x -- n3 ) — copy"])
        check("brace-add", ": LO-C {: a b -- n :} a b + ;", contains: [": LO-C ( a b -- n ) — copy"])
        check(
            "brace-tos",
            ": LO-D {: a b -- n :} b ;",
            contains: ["( a b -- b ) — copy", "does not match"]
        )
        check(
            "call",
            ": DOUBLE DUP + ;\n: QUAD DOUBLE DOUBLE ;",
            contains: [": DOUBLE ( x -- n3 ) — copy", ": QUAD ( x -- n3 ) — copy"]
        )
        check(
            "case",
            ": T CASE 1 OF 10 ENDOF 2 OF 20 ENDOF DUP ENDCASE ;",
            contains: ["( x -- "]
        )
        let swap = toolResult(source: "SWAP")
        if !swap.contains("( x1 x2 -- x2 x1 )") {
            fails.append("tool SWAP:\n\(swap)")
        }
        return fails
    }

    // MARK: - Report text

    private static func format(_ defs: [DefResult]) -> String {
        var lines = [
            "Stack model — traced from an empty data stack. An underflow is an input. Copy a comment marked copy. Do not invent a different ( before -- after ). A line marked not inferred has no trustworthy comment."
        ]
        var used = lines[0].count
        var truncated = false
        for def in defs {
            let line = def.lineText
            if used + line.count + 1 > 7_000 {
                truncated = true
                break
            }
            lines.append(line)
            used += line.count + 1
        }
        if truncated || defs.count >= 50 {
            lines.append("[further definitions were not traced]")
        }
        return lines.joined(separator: "\n")
    }

    /// Prefer fenced Forth. Otherwise the whole text, so a .fth file traces as source.
    private static func forthText(from source: String) -> String {
        let fences = fencedForth(in: source)
        if !fences.isEmpty {
            return fences.joined(separator: "\n")
        }
        return source
    }

    private static func fencedForth(in source: String) -> [String] {
        var blocks: [String] = []
        var rest = source[...]
        while let open = rest.range(of: "```") {
            let after = rest[open.upperBound...]
            let lineEnd = after.firstIndex(of: "\n") ?? after.endIndex
            let lang = after[..<lineEnd].trimmingCharacters(in: .whitespaces)
            let bodyStart = lineEnd == after.endIndex ? lineEnd : after.index(after: lineEnd)
            let body = after[bodyStart...]
            guard let close = body.range(of: "```") else { break }
            let code = String(body[..<close.lowerBound])
            let tag = lang.lowercased()
            let forthTag = tag == "forth" || tag == "fth" || tag == "fs" || tag == "f"
            if forthTag || (tag.isEmpty && code.contains(":") && code.contains(";")) {
                blocks.append(code)
            }
            rest = body[close.upperBound...]
        }
        return blocks
    }

    // MARK: - Words

    fileprivate struct Sym: Equatable {
        var name: String
        var wide: Bool
    }

    fileprivate struct Pattern: Equatable {
        var inputs: [Sym]
        var outputs: [Sym]

        static func parse(_ comment: String) -> Pattern? {
            var s = comment.trimmingCharacters(in: .whitespacesAndNewlines)
            if s.hasPrefix("(") { s.removeFirst() }
            if s.hasSuffix(")") { s.removeLast() }
            let parts = s.components(separatedBy: "--")
            guard parts.count >= 2 else { return nil }
            let outs = parts.dropFirst().joined(separator: "--")
            return Pattern(inputs: syms(in: parts[0]), outputs: syms(in: outs))
        }

        private static func syms(in text: String) -> [Sym] {
            text.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
                .map(String.init)
                .filter { !$0.isEmpty && $0 != "|" && $0 != "\\" }
                .map { Sym(name: $0, wide: isWide($0)) }
        }

        static func isWide(_ raw: String) -> Bool {
            var s = raw.lowercased()
            if s.first == "+" { s.removeFirst() }
            if s.hasPrefix("ud") {
                return s.dropFirst(2).allSatisfy(\.isNumber)
            }
            if s.first == "d" {
                return s.dropFirst().allSatisfy(\.isNumber)
            }
            return false
        }

        func cellCount(inputs side: Bool) -> Int {
            (side ? inputs : outputs).reduce(0) { $0 + ($1.wide ? 2 : 1) }
        }
    }

    fileprivate static let builtinPatterns: [String: Pattern] = {
        var map: [String: Pattern] = [:]
        for raw in patternLines.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let space = line.firstIndex(of: " ") else { continue }
            let name = String(line[..<space]).uppercased()
            let comment = String(line[space...]).trimmingCharacters(in: .whitespaces)
            if let pattern = Pattern.parse(comment) {
                map[name] = pattern
            }
        }
        return map
    }()

    fileprivate static let floatWords: Set<String> = [
        "F+", "F-", "F*", "F/", "FNEGATE", "FABS", "FMAX", "FMIN", "FSQRT",
        "FSIN", "FCOS", "FTAN", "FASIN", "FACOS", "FATAN", "FATAN2", "FEXP",
        "FLN", "FLOG", "F**", "FLOOR", "FROUND", "FTRUNC", "FDUP", "FDROP",
        "FSWAP", "FOVER", "FROT", "FNIP", "FTUCK", "F0=", "F0<", "F<", "F>",
        "F=", "F~", "F.", "FS.", "FE.", "FLITERAL", "FLOATS", "FLOAT+",
        "DFLOATS", "DFLOAT+", "FALIGN", "FALIGNED", "PRECISION", "SET-PRECISION",
        "REPRESENT", "FVARIABLE", "FCONSTANT", "F@", "F!", "F>S", "S>F",
        "D>F", "F>D", "F>S"
    ]

    /// `NAME ( before -- after )` one word per line. `d` / `ud` are two cells.
    private static let patternLines = """
    DUP ( x -- x x )
    DROP ( x -- )
    SWAP ( x1 x2 -- x2 x1 )
    OVER ( x1 x2 -- x1 x2 x1 )
    ROT ( x1 x2 x3 -- x2 x3 x1 )
    -ROT ( x1 x2 x3 -- x3 x1 x2 )
    NIP ( x1 x2 -- x2 )
    TUCK ( x1 x2 -- x2 x1 x2 )
    2DUP ( x1 x2 -- x1 x2 x1 x2 )
    2DROP ( x1 x2 -- )
    2SWAP ( x1 x2 x3 x4 -- x3 x4 x1 x2 )
    2OVER ( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )
    2ROT ( x1 x2 x3 x4 x5 x6 -- x3 x4 x5 x6 x1 x2 )
    + ( n1 n2 -- n3 )
    - ( n1 n2 -- n3 )
    * ( n1 n2 -- n3 )
    / ( n1 n2 -- n3 )
    MOD ( n1 n2 -- n3 )
    /MOD ( n1 n2 -- n3 n4 )
    */ ( n1 n2 n3 -- n4 )
    */MOD ( n1 n2 n3 -- n4 n5 )
    NEGATE ( n1 -- n2 )
    ABS ( n1 -- n2 )
    MIN ( n1 n2 -- n3 )
    MAX ( n1 n2 -- n3 )
    1+ ( n1 -- n2 )
    1- ( n1 -- n2 )
    2* ( n1 -- n2 )
    2/ ( n1 -- n2 )
    AND ( x1 x2 -- x3 )
    OR ( x1 x2 -- x3 )
    XOR ( x1 x2 -- x3 )
    INVERT ( x1 -- x2 )
    LSHIFT ( x1 u -- x2 )
    RSHIFT ( x1 u -- x2 )
    = ( n1 n2 -- flag )
    <> ( n1 n2 -- flag )
    < ( n1 n2 -- flag )
    > ( n1 n2 -- flag )
    U< ( u1 u2 -- flag )
    U> ( u1 u2 -- flag )
    >= ( n1 n2 -- flag )
    <= ( n1 n2 -- flag )
    0= ( x -- flag )
    0<> ( x -- flag )
    0< ( n -- flag )
    0> ( n -- flag )
    WITHIN ( n1 n2 n3 -- flag )
    @ ( a-addr -- x )
    ! ( x a-addr -- )
    C@ ( c-addr -- char )
    C! ( char c-addr -- )
    +! ( n a-addr -- )
    2@ ( a-addr -- x1 x2 )
    2! ( x1 x2 a-addr -- )
    CELL+ ( a-addr1 -- a-addr2 )
    CELLS ( n1 -- n2 )
    CELL ( -- n )
    CHAR+ ( c-addr1 -- c-addr2 )
    CHARS ( n1 -- n2 )
    ALIGNED ( addr -- a-addr )
    ALIGN ( -- )
    FILL ( c-addr u char -- )
    ERASE ( addr u -- )
    BLANK ( c-addr u -- )
    MOVE ( addr1 addr2 u -- )
    CMOVE ( c-addr1 c-addr2 u -- )
    CMOVE> ( c-addr1 c-addr2 u -- )
    /STRING ( c-addr1 u1 n -- c-addr2 u2 )
    -TRAILING ( c-addr u1 -- c-addr u2 )
    COMPARE ( c-addr1 u1 c-addr2 u2 -- n )
    TYPE ( c-addr u -- )
    COUNT ( c-addr1 -- c-addr2 u )
    ACCEPT ( c-addr u1 -- u2 )
    HERE ( -- addr )
    ALLOT ( n -- )
    , ( x -- )
    C, ( char -- )
    ALLOCATE ( u -- a-addr ior )
    FREE ( a-addr -- ior )
    RESIZE ( a-addr1 u -- a-addr2 ior )
    S>D ( n -- d )
    D>S ( d -- n )
    D+ ( d1 d2 -- d3 )
    D- ( d1 d2 -- d3 )
    DNEGATE ( d1 -- d2 )
    DABS ( d1 -- d2 )
    D= ( d1 d2 -- flag )
    D< ( d1 d2 -- flag )
    D0= ( d -- flag )
    D0< ( d -- flag )
    D2* ( d1 -- d2 )
    D2/ ( d1 -- d2 )
    DMAX ( d1 d2 -- d3 )
    DMIN ( d1 d2 -- d3 )
    M* ( n1 n2 -- d )
    UM* ( u1 u2 -- ud )
    SM/REM ( d n -- n2 n3 )
    FM/MOD ( d n -- n2 n3 )
    UM/MOD ( ud u1 -- u2 u3 )
    M+ ( d1 n -- d2 )
    DEPTH ( -- n )
    BL ( -- char )
    TRUE ( -- flag )
    FALSE ( -- flag )
    STATE ( -- a-addr )
    BASE ( -- a-addr )
    >IN ( -- a-addr )
    SOURCE ( -- c-addr u )
    SOURCE-ID ( -- n )
    PAD ( -- c-addr )
    KEY ( -- char )
    KEY? ( -- flag )
    EMIT ( char -- )
    CR ( -- )
    SPACE ( -- )
    SPACES ( n -- )
    . ( n -- )
    U. ( u -- )
    .R ( n u -- )
    U.R ( u1 u2 -- )
    .S ( -- )
    THROW ( n -- )
    OPEN-FILE ( c-addr u fam -- fileid ior )
    CREATE-FILE ( c-addr u fam -- fileid ior )
    CLOSE-FILE ( fileid -- ior )
    READ-FILE ( c-addr u1 fileid -- u2 ior )
    WRITE-FILE ( c-addr u fileid -- ior )
    READ-LINE ( c-addr u1 fileid -- u2 flag ior )
    WRITE-LINE ( c-addr u fileid -- ior )
    FILE-SIZE ( fileid -- ud ior )
    FILE-POSITION ( fileid -- ud ior )
    REPOSITION-FILE ( ud fileid -- ior )
    DELETE-FILE ( c-addr u -- ior )
    RENAME-FILE ( c-addr1 u1 c-addr2 u2 -- ior )
    FILE-STATUS ( c-addr u -- x ior )
    FLUSH-FILE ( fileid -- ior )
    RESIZE-FILE ( ud fileid -- ior )
    R/O ( -- fam )
    W/O ( -- fam )
    R/W ( -- fam )
    BIN ( fam1 -- fam2 )
    TIME&DATE ( -- n1 n2 n3 n4 n5 n6 )
    MS ( u -- )
    WORD ( char -- c-addr )
    """

    // MARK: - Tracing

    fileprivate struct Cell {
        var id: Int
        var role: String
        var literal: Int?
        var pair: Int?
    }

    fileprivate struct Token {
        enum Kind { case word, stackComment }
        var text: String
        var line: Int
        var kind: Kind
    }

    fileprivate struct UserWord {
        var pattern: Pattern?
        var immediate: Bool
    }

    fileprivate struct DefResult {
        enum Verdict { case copy, mismatch, notInferred, ambiguous }
        var name: String
        var line: Int
        var traced: String
        var declared: String?
        var verdict: Verdict
        var detail: String

        var lineText: String {
            switch verdict {
            case .copy:
                return detail.isEmpty ? ": \(name) \(traced) — copy" : ": \(name) \(traced) — copy; \(detail)"
            case .mismatch:
                let declared = declared ?? "( ? )"
                return ": \(name) \(traced) — copy; declared \(declared) does not match"
            case .ambiguous:
                return ": \(name) \(traced) — not a single effect: \(detail)"
            case .notInferred:
                if traced.isEmpty {
                    return ": \(name) — not inferred: \(detail)"
                }
                return ": \(name) traced \(traced) — not inferred: \(detail)"
            }
        }
    }

    fileprivate struct Frame {
        enum Kind { case ifThen, elseBranch, begin, whileBody, doLoop, caseHead, ofBody }
        var kind: Kind
        var dataA: [Cell] = []
        var dataB: [Cell] = []
        var retA: [Cell] = []
        var retB: [Cell] = []
        var retCount: Int = 0
        var exits: [[Cell]] = []
        var live: Bool = true
        var line: Int = 1

        mutating func insertDataBottom(_ cell: Cell) {
            switch kind {
            case .ifThen, .elseBranch, .begin:
                dataA.insert(cell, at: 0)
            case .whileBody:
                dataA.insert(cell, at: 0)
                dataB.insert(cell, at: 0)
            case .doLoop, .caseHead, .ofBody:
                dataA.insert(cell, at: 0)
                exits = exits.map { var stack = $0; stack.insert(cell, at: 0); return stack }
            }
        }
    }

    fileprivate final class Analyzer {
        let tokens: [Token]
        var index = 0
        var base = 10
        var users: [String: UserWord] = [:]
        var lastDefined: String?
        var results: [DefResult] = []

        init(_ source: String) {
            tokens = ForthStackEffect.tokenize(source)
        }

        func definitions(limit: Int) -> [DefResult] {
            while index < tokens.count, results.count < limit {
                let token = tokens[index]
                if token.kind == .stackComment {
                    index += 1
                    continue
                }
                let word = token.text.uppercased()
                if word == ":" {
                    parseColon()
                    continue
                }
                if word == "CODE" {
                    skipCode()
                    continue
                }
                if word == "HEX" {
                    base = 16
                    index += 1
                    continue
                }
                if word == "DECIMAL" {
                    base = 10
                    index += 1
                    continue
                }
                if word == "IMMEDIATE" {
                    if let name = lastDefined, var user = users[name.uppercased()] {
                        user.immediate = true
                        users[name.uppercased()] = user
                    }
                    index += 1
                    continue
                }
                if let defining = definingEffect(word) {
                    guard let name = takeName() else { continue }
                    users[name.uppercased()] = UserWord(pattern: defining, immediate: false)
                    lastDefined = name
                    continue
                }
                index += 1
            }
            return results
        }

        private func definingEffect(_ word: String) -> Pattern? {
            switch word {
            case "VARIABLE", "2VARIABLE", "CREATE":
                return Pattern.parse("( -- a-addr )")
            case "CONSTANT", "VALUE":
                return Pattern.parse("( -- n )")
            case "2CONSTANT":
                return Pattern.parse("( -- d )")
            case "BUFFER:":
                return Pattern.parse("( -- a-addr )")
            case "DEFER":
                return nil
            default:
                return nil
            }
        }

        private func takeName() -> String? {
            index += 1
            guard index < tokens.count, tokens[index].kind == .word else { return nil }
            let name = tokens[index].text
            index += 1
            if name == ";" { return nil }
            return name
        }

        private func skipCode() {
            index += 1
            var name: String?
            if index < tokens.count, tokens[index].kind == .word {
                name = tokens[index].text
                index += 1
            }
            while index < tokens.count {
                let word = tokens[index].text.uppercased()
                index += 1
                if word == "END-CODE" { break }
            }
            if let name {
                results.append(DefResult(
                    name: name,
                    line: 0,
                    traced: "",
                    declared: nil,
                    verdict: .notInferred,
                    detail: "CODE word; machine code is not traced"
                ))
                users[name.uppercased()] = UserWord(pattern: nil, immediate: false)
                lastDefined = name
            }
        }

        private func parseColon() {
            let colonLine = tokens[index].line
            index += 1
            guard index < tokens.count, tokens[index].kind == .word else { return }
            let rawName = tokens[index].text
            index += 1
            let noname = rawName.uppercased() == "NONAME"
            let name = noname ? ":NONAME" : rawName
            var body: [Token] = []
            var closed = false
            while index < tokens.count {
                let token = tokens[index]
                index += 1
                if token.kind == .word && token.text == ";" {
                    closed = true
                    break
                }
                body.append(token)
            }
            guard closed else { return }
            let tracer = Tracer(body: body, base: base, users: users)
            let outcome = tracer.run(name: name, line: colonLine)
            results.append(outcome.result)
            users[name.uppercased()] = UserWord(pattern: outcome.registered, immediate: false)
            lastDefined = name
        }
    }

    fileprivate struct TraceOutcome {
        var result: DefResult
        var registered: Pattern?
    }

    fileprivate final class Tracer {
        let body: [Token]
        var index = 0
        var base: Int
        let users: [String: UserWord]
        var data: [Cell] = []
        var ret: [Cell] = []
        var inputs: [Cell] = []
        var frames: [Frame] = []
        var exits: [[Cell]] = []
        var locals: [String: Cell] = [:]
        var nextID = 1
        var nextPair = 1
        var unreachable = false
        var gaveUp = false
        var broken = false
        var ambiguous = false
        var sawFloat = false
        var qdupBefore: [Cell]?
        var notes: [String] = []
        var unknowns: [String] = []
        var declared: String?
        var bracket = 0

        init(body: [Token], base: Int, users: [String: UserWord]) {
            self.body = body
            self.base = base
            self.users = users
        }

        var skipEffects: Bool { unreachable || gaveUp }

        func run(name: String, line: Int) -> TraceOutcome {
            while index < body.count {
                step()
            }
            // A trailing ?DUP never met IF. Keep the nonzero picture and say so.
            clearQdup()
            return finish(name: name, line: line)
        }

        private func finish(name: String, line: Int) -> TraceOutcome {
            if !frames.isEmpty {
                note("unbalanced control flow at ;")
                broken = true
            }
            if !ret.isEmpty && !gaveUp {
                note("return stack still has \(ret.count) item(s) at ;")
                broken = true
            }
            if sawFloat {
                note("float stack is separate and was not checked")
            }
            let outputs = finishExits()
            let traced = renderComment(inputs: inputs, outputs: outputs)
            let detail = detailText()
            let verdict: DefResult.Verdict
            var shown = traced
            if gaveUp || broken || outputs == nil {
                verdict = .notInferred
            } else if ambiguous {
                verdict = .ambiguous
            } else if let declared {
                let check = Self.compare(declared: declared, inputs: inputs, outputs: outputs ?? [])
                if check == "matches" {
                    verdict = .copy
                    shown = normalizeDeclared(declared)
                } else {
                    verdict = .mismatch
                }
            } else {
                verdict = .copy
            }
            let registered: Pattern?
            if verdict == .copy || verdict == .mismatch {
                registered = pattern(inputs: inputs, outputs: outputs ?? [])
            } else {
                registered = nil
            }
            let result = DefResult(
                name: name,
                line: line,
                traced: shown,
                declared: declared.map(normalizeDeclared),
                verdict: verdict,
                detail: detail
            )
            return TraceOutcome(result: result, registered: registered)
        }

        private func finishExits() -> [Cell]? {
            if !unreachable && !gaveUp {
                exits.append(data)
            }
            if exits.isEmpty { return nil }
            let depth = exits[0].count
            if exits.contains(where: { $0.count != depth }) {
                note("exit paths leave different stack depths")
                broken = true
                return exits[0]
            }
            var acc = exits[0]
            for stack in exits.dropFirst() {
                acc = unify(acc, stack)
            }
            return acc
        }

        private func detailText() -> String {
            var parts: [String] = []
            if !unknowns.isEmpty {
                parts.append("unknown word\(unknowns.count == 1 ? "" : "s") \(unknowns.joined(separator: ", "))")
            }
            parts.append(contentsOf: notes)
            if parts.isEmpty && exits.isEmpty {
                parts.append("does not return")
            }
            return parts.joined(separator: "; ")
        }

        private func note(_ text: String) {
            if !notes.contains(text) {
                notes.append(text)
            }
        }

        private func step() {
            let token = body[index]
            index += 1
            if token.kind == .stackComment {
                if declared == nil && !startedCode(before: index - 1) {
                    declared = token.text
                }
                return
            }
            let word = token.text
            let upper = word.uppercased()
            if bracket > 0 {
                applyBracket(upper, line: token.line)
                return
            }
            if upper == "[" {
                bracket += 1
                return
            }
            if let number = parseNumber(word) {
                pushNumber(number, spelling: word)
                return
            }
            if let code = characterLiteral(word) {
                push(fresh(word, literal: code))
                return
            }
            if isFloatLiteral(word) {
                sawFloat = true
                return
            }
            applyWord(upper, display: word, line: token.line)
        }

        private func startedCode(before commentIndex: Int) -> Bool {
            for token in body[..<commentIndex] {
                if token.kind == .word { return true }
            }
            return false
        }

        private func applyBracket(_ word: String, line: Int) {
            switch word {
            case "]":
                bracket = max(0, bracket - 1)
            case "HEX":
                base = 16
            case "DECIMAL":
                base = 10
            case "LITERAL":
                // Compile-time LITERAL still compiles a runtime push.
                if !skipEffects { push(fresh("x")) }
            case "2LITERAL":
                if !skipEffects {
                    push(fresh("x"))
                    push(fresh("x"))
                }
            default:
                break
            }
            _ = line
        }

        private func applyWord(_ upper: String, display: String, line: Int) {
            if let local = locals[upper] {
                guard !skipEffects else { return }
                clearQdup()
                push(local)
                return
            }
            switch upper {
            case "RECURSE":
                clearQdup()
                applyRecurse()
            case "IF":
                opIF(line: line)
            case "ELSE":
                opELSE(line: line)
            case "THEN":
                opTHEN(line: line)
            case "BEGIN":
                clearQdup()
                frames.append(Frame(kind: .begin, dataA: data, retA: ret, live: !skipEffects, line: line))
            case "UNTIL":
                opUNTIL(line: line)
            case "AGAIN":
                opAGAIN(line: line)
            case "WHILE":
                opWHILE(line: line)
            case "REPEAT":
                opREPEAT(line: line)
            case "DO", "?DO":
                opDO(line: line)
            case "LOOP":
                opLOOP(plus: false, line: line)
            case "+LOOP":
                opLOOP(plus: true, line: line)
            case "I":
                opIndex(depth: 1, line: line)
            case "J":
                opIndex(depth: 2, line: line)
            case "LEAVE":
                opLEAVE(line: line)
            case "UNLOOP":
                clearQdup()
                guard !skipEffects else { return }
                if ret.count >= 2 {
                    ret.removeLast(2)
                } else {
                    note("UNLOOP without a DO frame")
                    broken = true
                }
            case "EXIT":
                opEXIT()
            case "?DUP":
                opQdup()
            case "PICK":
                opPick()
            case "ROLL":
                opRoll()
            case ">R":
                clearQdup()
                guard !skipEffects else { return }
                ret.append(pop("x"))
            case "R>":
                clearQdup()
                guard !skipEffects else { return }
                if let cell = ret.popLast() {
                    push(cell)
                } else {
                    note("R> return-stack underflow")
                    broken = true
                    push(fresh("x"))
                }
            case "R@":
                clearQdup()
                guard !skipEffects else { return }
                if let cell = ret.last {
                    push(cell)
                } else {
                    note("R@ outside a return value")
                    broken = true
                    push(fresh("x"))
                }
            case "2>R":
                clearQdup()
                guard !skipEffects else { return }
                let hi = pop("x")
                let lo = pop("x")
                ret.append(lo)
                ret.append(hi)
            case "2R>":
                clearQdup()
                guard !skipEffects else { return }
                guard ret.count >= 2 else {
                    note("2R> return-stack underflow")
                    broken = true
                    return
                }
                let hi = ret.removeLast()
                let lo = ret.removeLast()
                push(lo)
                push(hi)
            case "2R@":
                clearQdup()
                guard !skipEffects else { return }
                guard ret.count >= 2 else {
                    note("2R@ outside a return pair")
                    broken = true
                    return
                }
                push(ret[ret.count - 2])
                push(ret[ret.count - 1])
            case "ABORT", "QUIT":
                clearQdup()
                data.removeAll()
                ret.removeAll()
                unreachable = true
            case "S\"", "S\\\"":
                clearQdup()
                guard !skipEffects else { return }
                push(fresh("c-addr"))
                push(fresh("u"))
            case "C\"":
                clearQdup()
                guard !skipEffects else { return }
                push(fresh("c-addr"))
            case ".\"":
                clearQdup()
            case ".(":
                break
            case "ABORT\"":
                clearQdup()
                guard !skipEffects else { return }
                _ = pop("flag")
            case "[']", "'":
                clearQdup()
                _ = takeBodyName()
                guard !skipEffects else { return }
                push(fresh("xt"))
            case "CHAR", "[CHAR]":
                clearQdup()
                _ = takeBodyName()
                guard !skipEffects else { return }
                push(fresh("char"))
            case "POSTPONE":
                clearQdup()
                guard let name = takeBodyName() else {
                    note("POSTPONE without a word")
                    broken = true
                    return
                }
                applyWord(name.uppercased(), display: name, line: line)
            case "LITERAL":
                clearQdup()
                guard !skipEffects else { return }
                push(fresh("x"))
            case "2LITERAL":
                clearQdup()
                guard !skipEffects else { return }
                push(fresh("x"))
                push(fresh("x"))
            case "TO", "+TO":
                opTO(plus: upper == "+TO")
            case "LOCALS|":
                opLocalsBar()
            case "{:":
                opBrace()
            case "EXECUTE":
                giveUp("EXECUTE stack effect depends on the execution token")
            case "EVALUATE", "INCLUDED", "INCLUDE", "INCLUDE-FILE", "FLOAD", "LOAD":
                giveUp("\(upper) can change the stack")
            case "CATCH":
                giveUp("CATCH stack effect depends on the execution token")
            case "AHEAD", "CS-ROLL", "CS-PICK", "DOES>":
                giveUp("\(upper) is not traced")
            case "CASE":
                opCASE(line: line)
            case "OF":
                opOF(line: line)
            case "ENDOF":
                opENDOF(line: line)
            case "ENDCASE":
                opENDCASE(line: line)
            default:
                if let user = users[upper] {
                    clearQdup()
                    if user.immediate {
                        giveUp("\(display) is immediate; its compile-time effect is not traced")
                    } else if let pattern = user.pattern {
                        apply(pattern)
                    } else {
                        giveUp("\(display) has no known stack effect")
                    }
                } else if let pattern = ForthStackEffect.builtinPatterns[upper] {
                    clearQdup()
                    apply(pattern)
                } else if ForthStackEffect.floatWords.contains(upper) {
                    clearQdup()
                    sawFloat = true
                } else if upper == "]" {
                    break
                } else {
                    clearQdup()
                    giveUpWord(display)
                }
            }
        }

        private func giveUpWord(_ display: String) {
            if !unknowns.contains(display) {
                unknowns.append(display)
            }
            gaveUp = true
        }

        private func giveUp(_ reason: String) {
            note(reason)
            gaveUp = true
        }

        private func applyRecurse() {
            guard !skipEffects else { return }
            guard let declared, let pattern = Pattern.parse(normalizeDeclared(declared)) else {
                giveUp("RECURSE needs a stack comment; the effect is not known yet")
                return
            }
            apply(pattern)
        }

        private func takeBodyName() -> String? {
            guard index < body.count, body[index].kind == .word else { return nil }
            let name = body[index].text
            index += 1
            return name
        }

        // MARK: Control

        private func opIF(line: Int) {
            if let before = qdupBefore {
                qdupBefore = nil
                var zero = before
                if !zero.isEmpty { zero.removeLast() }
                if !data.isEmpty { data.removeLast() }
                frames.append(Frame(kind: .ifThen, dataA: zero, retA: ret, live: !skipEffects, line: line))
                return
            }
            if !skipEffects {
                _ = pop("flag")
            }
            frames.append(Frame(kind: .ifThen, dataA: data, retA: ret, live: !skipEffects, line: line))
        }

        private func opELSE(line: Int) {
            guard let frame = frames.popLast(), frame.kind == .ifThen else {
                note("ELSE without IF")
                broken = true
                return
            }
            let thenData = data
            let thenRet = ret
            let thenLive = !skipEffects
            data = frame.dataA
            ret = frame.retA
            unreachable = !frame.live
            frames.append(Frame(
                kind: .elseBranch,
                dataA: thenData,
                retA: thenRet,
                live: thenLive,
                line: line
            ))
        }

        private func opTHEN(line: Int) {
            guard let frame = frames.popLast() else {
                note("THEN without IF")
                broken = true
                return
            }
            _ = line
            switch frame.kind {
            case .ifThen:
                join(thenData: data, thenRet: ret, thenLive: !skipEffects,
                     elseData: frame.dataA, elseRet: frame.retA, elseLive: frame.live)
            case .elseBranch:
                join(thenData: frame.dataA, thenRet: frame.retA, thenLive: frame.live,
                     elseData: data, elseRet: ret, elseLive: !skipEffects)
            default:
                note("THEN does not match IF")
                broken = true
            }
        }

        private func join(
            thenData: [Cell], thenRet: [Cell], thenLive: Bool,
            elseData: [Cell], elseRet: [Cell], elseLive: Bool
        ) {
            if gaveUp {
                unreachable = false
                return
            }
            switch (thenLive, elseLive) {
            case (true, true):
                if thenData.count != elseData.count {
                    note("IF/ELSE/THEN stack depths differ (\(thenData.count) and \(elseData.count))")
                    broken = true
                    data = thenData
                } else {
                    data = unify(thenData, elseData)
                }
                if thenRet.count != elseRet.count {
                    note("IF/ELSE/THEN return-stack depths differ")
                    broken = true
                }
                ret = thenRet
                unreachable = false
            case (true, false):
                data = thenData
                ret = thenRet
                unreachable = false
            case (false, true):
                data = elseData
                ret = elseRet
                unreachable = false
            case (false, false):
                unreachable = true
            }
        }

        private func opUNTIL(line: Int) {
            _ = line
            guard let frame = frames.popLast(), frame.kind == .begin else {
                note("UNTIL without BEGIN")
                broken = true
                return
            }
            clearQdup()
            if !skipEffects {
                _ = pop("flag")
            }
            if !gaveUp && frame.live && !unreachable {
                if data.count != frame.dataA.count {
                    note("UNTIL stack does not match BEGIN (\(data.count) vs \(frame.dataA.count))")
                    broken = true
                }
            }
            unreachable = !frame.live && unreachable
            if frame.live { unreachable = false }
        }

        private func opAGAIN(line: Int) {
            _ = line
            guard let frame = frames.popLast(), frame.kind == .begin else {
                note("AGAIN without BEGIN")
                broken = true
                return
            }
            clearQdup()
            if !gaveUp && !unreachable && data.count != frame.dataA.count {
                note("AGAIN stack does not match BEGIN")
                broken = true
            }
            unreachable = true
        }

        private func opWHILE(line: Int) {
            guard let frame = frames.popLast(), frame.kind == .begin else {
                note("WHILE without BEGIN")
                broken = true
                return
            }
            clearQdup()
            if !skipEffects {
                _ = pop("flag")
            }
            frames.append(Frame(
                kind: .whileBody,
                dataA: frame.dataA,
                dataB: data,
                retA: frame.retA,
                retB: ret,
                live: frame.live,
                line: line
            ))
        }

        private func opREPEAT(line: Int) {
            _ = line
            guard let frame = frames.popLast(), frame.kind == .whileBody else {
                note("REPEAT without WHILE")
                broken = true
                return
            }
            let bodyLive = !unreachable && !gaveUp
            if bodyLive && data.count != frame.dataA.count {
                note("REPEAT stack does not match BEGIN (\(data.count) vs \(frame.dataA.count))")
                broken = true
            }
            if frame.live {
                // The flag can fail on the first test or after the body has
                // replaced the carried stack. Same depth, either item.
                if bodyLive && data.count == frame.dataB.count {
                    data = unify(data, frame.dataB)
                } else {
                    data = frame.dataB
                }
                ret = frame.retB
                unreachable = false
            } else {
                unreachable = true
            }
        }

        private func opDO(line: Int) {
            clearQdup()
            if !skipEffects {
                let indexCell = pop("index")
                let limit = pop("limit")
                ret.append(limit)
                ret.append(indexCell)
            }
            frames.append(Frame(kind: .doLoop, dataA: data, retCount: ret.count, live: !skipEffects, line: line))
        }

        private func opLOOP(plus: Bool, line: Int) {
            _ = line
            guard let frame = frames.popLast(), frame.kind == .doLoop else {
                note("LOOP without DO")
                broken = true
                return
            }
            if plus && !skipEffects {
                _ = pop("n")
            }
            var paths: [[Cell]] = []
            if !unreachable && !gaveUp {
                if data.count != frame.dataA.count {
                    note("LOOP body depth \(data.count) does not match \(frame.dataA.count) after DO")
                    broken = true
                }
                paths.append(data)
            }
            for leave in frame.exits where leave.count != frame.dataA.count {
                note("LEAVE depth \(leave.count) does not match \(frame.dataA.count) after DO")
                broken = true
            }
            paths.append(contentsOf: frame.exits)
            if paths.isEmpty {
                unreachable = true
            } else {
                var acc = paths[0]
                for stack in paths.dropFirst() where stack.count == acc.count {
                    acc = unify(acc, stack)
                }
                data = acc
                unreachable = false
            }
            if ret.count >= 2 {
                ret.removeLast(2)
            }
        }

        private func opIndex(depth: Int, line: Int) {
            _ = line
            clearQdup()
            guard !skipEffects else { return }
            // Each DO pushes limit then index. J is the outer index.
            let fromTop = depth == 1 ? 1 : 3
            guard ret.count >= fromTop else {
                note(depth == 1 ? "I outside DO" : "J outside a nested DO")
                broken = true
                push(fresh("n"))
                return
            }
            push(ret[ret.count - fromTop])
        }

        private func opLEAVE(line: Int) {
            _ = line
            guard let slot = frames.lastIndex(where: { $0.kind == .doLoop }) else {
                note("LEAVE outside DO")
                broken = true
                return
            }
            if !skipEffects {
                frames[slot].exits.append(data)
            }
            unreachable = true
        }

        private func opEXIT() {
            clearQdup()
            if !skipEffects {
                if !ret.isEmpty {
                    note("EXIT with \(ret.count) item(s) on the return stack")
                    broken = true
                }
                exits.append(data)
            }
            unreachable = true
        }

        private func opQdup() {
            guard !skipEffects else { return }
            if data.isEmpty {
                push(createInput("x"))
            }
            qdupBefore = data
            push(data[data.count - 1])
        }

        private func clearQdup() {
            guard qdupBefore != nil else { return }
            qdupBefore = nil
            ambiguous = true
            note("?DUP was not followed by IF. Nonzero path keeps the extra item; zero path does not")
        }

        private func opPick() {
            clearQdup()
            guard !skipEffects else { return }
            guard let count = data.last?.literal, count >= 0 else {
                giveUp("PICK count is not a literal")
                return
            }
            _ = pop("u")
            deepen(to: count + 1)
            let copied = data[data.count - 1 - count]
            push(copied)
        }

        private func opRoll() {
            clearQdup()
            guard !skipEffects else { return }
            guard let count = data.last?.literal, count >= 0 else {
                giveUp("ROLL count is not a literal")
                return
            }
            _ = pop("u")
            if count == 0 { return }
            deepen(to: count + 1)
            let slot = data.count - 1 - count
            let cell = data.remove(at: slot)
            data.append(cell)
        }

        private func opCASE(line: Int) {
            clearQdup()
            if !skipEffects && data.isEmpty {
                push(createInput("x"))
            }
            frames.append(Frame(kind: .caseHead, dataA: data, live: !skipEffects, line: line))
        }

        private func opOF(line: Int) {
            clearQdup()
            guard let frame = frames.popLast(), frame.kind == .caseHead else {
                note("OF without CASE")
                broken = true
                return
            }
            if skipEffects {
                frames.append(Frame(kind: .ofBody, dataA: data, exits: frame.exits, live: false, line: line))
                return
            }
            _ = pop("x")
            let selector = pop("x")
            let trueStart = data
            var falseStack = data
            falseStack.append(selector)
            frames.append(Frame(kind: .ofBody, dataA: falseStack, exits: frame.exits, live: true, line: line))
            data = trueStart
        }

        private func opENDOF(line: Int) {
            _ = line
            guard let frame = frames.popLast(), frame.kind == .ofBody else {
                note("ENDOF without OF")
                broken = true
                return
            }
            var exits = frame.exits
            if !skipEffects {
                exits.append(data)
            }
            data = frame.dataA
            unreachable = false
            frames.append(Frame(kind: .caseHead, dataA: data, exits: exits, live: true, line: frame.line))
        }

        private func opENDCASE(line: Int) {
            _ = line
            guard let frame = frames.popLast(), frame.kind == .caseHead else {
                note("ENDCASE without CASE")
                broken = true
                return
            }
            if !skipEffects {
                _ = pop("x")
            }
            var exits = frame.exits
            if !skipEffects {
                exits.append(data)
            }
            guard !exits.isEmpty else {
                unreachable = true
                return
            }
            let depth = exits[0].count
            if exits.contains(where: { $0.count != depth }) {
                note("CASE branches leave different stack depths")
                broken = true
                data = exits[0]
            } else {
                var acc = exits[0]
                for stack in exits.dropFirst() {
                    acc = unify(acc, stack)
                }
                data = acc
            }
            unreachable = false
        }

        private func opLocalsBar() {
            clearQdup()
            var names: [String] = []
            while index < body.count {
                let token = body[index]
                index += 1
                if token.kind == .word && token.text == "|" { break }
                if token.kind == .word { names.append(token.text) }
            }
            // LOCALS| : the first name is TOS.
            for name in names {
                let cell = skipEffects ? fresh(name) : pop(name)
                locals[name.uppercased()] = cell
            }
        }

        private func opBrace() {
            clearQdup()
            var phase = 0
            var args: [String] = []
            var vals: [String] = []
            var outs: [String] = []
            while index < body.count {
                let token = body[index]
                index += 1
                if token.kind != .word { continue }
                if token.text == ":}" { break }
                if token.text == "|" { phase = 1; continue }
                if token.text == "--" { phase = 2; continue }
                switch phase {
                case 0: args.append(token.text)
                case 1: vals.append(token.text)
                default: outs.append(token.text)
                }
            }
            if declared == nil {
                let before = args.joined(separator: " ")
                let after = outs.joined(separator: " ")
                declared = "( \(before) -- \(after) )"
            }
            // {: :} reverse init: the last arg is TOS.
            for name in args.reversed() {
                let cell = skipEffects ? fresh(name) : pop(name)
                locals[name.uppercased()] = cell
            }
            for name in vals {
                locals[name.uppercased()] = fresh(name)
            }
        }

        private func opTO(plus: Bool) {
            clearQdup()
            guard let name = takeBodyName() else {
                note("TO without a name")
                broken = true
                return
            }
            guard !skipEffects else { return }
            let value = pop(plus ? "n" : "x")
            let key = name.uppercased()
            if locals[key] != nil {
                locals[key] = plus ? fresh("n") : value
            }
        }

        // MARK: Stack

        private func apply(_ pattern: Pattern) {
            guard !skipEffects else { return }
            var bound: [String: [Cell]] = [:]
            for sym in pattern.inputs.reversed() {
                let cells = popSym(sym)
                if bound[sym.name] == nil {
                    bound[sym.name] = cells
                }
            }
            for sym in pattern.outputs {
                if let cells = bound[sym.name] {
                    for cell in cells { push(cell) }
                } else if sym.wide {
                    pushWide(sym.name)
                } else {
                    push(fresh(sym.name))
                }
            }
        }

        private func popSym(_ sym: Sym) -> [Cell] {
            if !sym.wide {
                return [pop(sym.name)]
            }
            if data.count >= 2 {
                let hi = data.removeLast()
                let lo = data.removeLast()
                return [lo, hi]
            }
            let pair = nextPair
            nextPair += 1
            if data.count == 1 {
                var hi = data.removeLast()
                hi.pair = pair
                let lo = createInput(sym.name, pair: pair)
                return [lo, hi]
            }
            let hi = createInput(sym.name, pair: pair)
            let lo = createInput(sym.name, pair: pair)
            return [lo, hi]
        }

        private func pushWide(_ role: String) {
            let pair = nextPair
            nextPair += 1
            push(fresh(role, pair: pair))
            push(fresh(role, pair: pair))
        }

        private func pop(_ role: String) -> Cell {
            if let cell = data.popLast() {
                return cell
            }
            return createInput(role, pair: nil)
        }

        /// A missing item existed before this definition, including under every open control snapshot.
        private func createInput(_ role: String, pair: Int? = nil) -> Cell {
            let cell = Cell(id: nextID, role: role, literal: nil, pair: pair)
            nextID += 1
            inputs.append(cell)
            for slot in frames.indices {
                frames[slot].insertDataBottom(cell)
            }
            // An earlier exit did not consume this input, so it is still underneath that path.
            if !exits.isEmpty {
                exits = exits.map { var stack = $0; stack.insert(cell, at: 0); return stack }
            }
            return cell
        }

        private func fresh(_ role: String, literal: Int? = nil, pair: Int? = nil) -> Cell {
            let cell = Cell(id: nextID, role: role, literal: literal, pair: pair)
            nextID += 1
            return cell
        }

        private func push(_ cell: Cell) {
            data.append(cell)
        }

        private func deepen(to depth: Int) {
            while data.count < depth {
                let cell = createInput("x", pair: nil)
                data.insert(cell, at: 0)
            }
        }

        private func pushNumber(_ number: ParsedNumber, spelling: String) {
            guard !skipEffects else { return }
            clearQdup()
            switch number {
            case .single(let value):
                push(fresh(spelling, literal: value))
            case .double(let value):
                let pair = nextPair
                nextPair += 1
                push(fresh(spelling, literal: value, pair: pair))
                push(fresh(spelling, literal: nil, pair: pair))
            }
        }

        private func unify(_ left: [Cell], _ right: [Cell]) -> [Cell] {
            zip(left, right).map { a, b in
                a.id == b.id ? a : fresh(a.role == b.role ? a.role : "x")
            }
        }

        // MARK: Comments

        private func renderComment(inputs tosFirst: [Cell], outputs: [Cell]?) -> String {
            guard let outputs else { return "" }
            var names: [Int: String] = [:]
            var used: Set<String> = []
            let before = render(Array(tosFirst.reversed()), names: &names, used: &used)
            let after = render(outputs, names: &names, used: &used)
            return "( \(before)-- \(after))".replacingOccurrences(of: "( --", with: "( --")
                .replacingOccurrences(of: "-- )", with: "-- )")
                .fixingEmptySides()
        }

        private func render(_ cells: [Cell], names: inout [Int: String], used: inout Set<String>) -> String {
            var parts: [String] = []
            var index = 0
            while index < cells.count {
                let cell = cells[index]
                if let pair = cell.pair, index + 1 < cells.count, cells[index + 1].pair == pair {
                    let name = display(cell, names: &names, used: &used)
                    names[cells[index + 1].id] = name
                    parts.append(name)
                    index += 2
                    continue
                }
                parts.append(display(cell, names: &names, used: &used))
                index += 1
            }
            if parts.isEmpty { return "" }
            return parts.joined(separator: " ") + " "
        }

        private func display(_ cell: Cell, names: inout [Int: String], used: inout Set<String>) -> String {
            if let name = names[cell.id] { return name }
            var name = cell.role.isEmpty ? "x" : cell.role
            if used.contains(name) {
                var n = 2
                while used.contains(name + "\(n)") { n += 1 }
                name += "\(n)"
            }
            used.insert(name)
            names[cell.id] = name
            return name
        }

        private func pattern(inputs tosFirst: [Cell], outputs: [Cell]) -> Pattern {
            var names: [Int: String] = [:]
            var used: Set<String> = []
            let before = namedSyms(Array(tosFirst.reversed()), names: &names, used: &used)
            let after = namedSyms(outputs, names: &names, used: &used)
            return Pattern(inputs: before, outputs: after)
        }

        private func namedSyms(_ cells: [Cell], names: inout [Int: String], used: inout Set<String>) -> [Sym] {
            var syms: [Sym] = []
            var index = 0
            while index < cells.count {
                let cell = cells[index]
                if let pair = cell.pair, index + 1 < cells.count, cells[index + 1].pair == pair {
                    let name = display(cell, names: &names, used: &used)
                    names[cells[index + 1].id] = name
                    syms.append(Sym(name: name, wide: true))
                    index += 2
                    continue
                }
                let name = display(cell, names: &names, used: &used)
                syms.append(Sym(name: name, wide: false))
                index += 1
            }
            return syms
        }

        private func normalizeDeclared(_ text: String) -> String {
            var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.hasPrefix("(") { s = "(" + s }
            if !s.hasSuffix(")") { s += ")" }
            let parts = s.dropFirst().dropLast().components(separatedBy: "--")
            guard parts.count >= 2 else { return s }
            let before = parts[0].split(whereSeparator: { $0.isWhitespace }).map(String.init).joined(separator: " ")
            let after = parts.dropFirst().joined(separator: "--")
                .split(whereSeparator: { $0.isWhitespace }).map(String.init).joined(separator: " ")
            if before.isEmpty && after.isEmpty { return "( -- )" }
            if before.isEmpty { return "( -- \(after) )" }
            if after.isEmpty { return "( \(before) -- )" }
            return "( \(before) -- \(after) )"
        }

        static func compare(declared: String, inputs tosFirst: [Cell], outputs: [Cell]) -> String {
            guard let pattern = Pattern.parse(declared) else {
                return "declared comment is not ( before -- after )"
            }
            let ins = Array(tosFirst.reversed())
            func count(_ syms: [Sym]) -> Int { syms.reduce(0) { $0 + ($1.wide ? 2 : 1) } }
            let inN = count(pattern.inputs)
            let outN = count(pattern.outputs)
            if inN != ins.count || outN != outputs.count {
                return "depth \(ins.count) -- \(outputs.count) vs declared \(inN) -- \(outN)"
            }
            var groups: [String: [[Cell]]] = [:]
            var cursor = 0
            for sym in pattern.inputs {
                let n = sym.wide ? 2 : 1
                groups[sym.name, default: []].append(Array(ins[cursor..<(cursor + n)]))
                cursor += n
            }
            cursor = 0
            var produced: [(String, [Cell])] = []
            for sym in pattern.outputs {
                let n = sym.wide ? 2 : 1
                produced.append((sym.name, Array(outputs[cursor..<(cursor + n)])))
                cursor += n
            }
            let inputIDs = Set(ins.map(\.id))
            var usedGroup: [String: Int] = [:]
            var seen: [String: [Int]] = [:]
            for (name, slice) in produced {
                let ids = slice.map(\.id)
                if let previous = seen[name], previous != ids {
                    return "\(name) is repeated but the items differ"
                }
                seen[name] = ids
                if let occurrences = groups[name] {
                    let k = usedGroup[name, default: 0]
                    if k < occurrences.count {
                        usedGroup[name] = k + 1
                        let expected = occurrences[k].map(\.id)
                        if ids != expected {
                            let wrong = ids.contains { inputIDs.contains($0) && !expected.contains($0) }
                            if wrong {
                                return "\(name) is not the item the trace keeps"
                            }
                        }
                    }
                } else if ids.contains(where: { inputIDs.contains($0) }) {
                    return "\(name) is an existing stack item, not a new value"
                }
            }
            return "matches"
        }

        // MARK: Numbers

        enum ParsedNumber {
            case single(Int?)
            case double(Int?)
        }

        func parseNumber(_ token: String) -> ParsedNumber? {
            var chars = Array(token)
            guard !chars.isEmpty else { return nil }
            var isDouble = false
            if chars.last == "." {
                isDouble = true
                chars.removeLast()
                if chars.isEmpty { return nil }
            }
            var negative = false
            if chars.first == "-" {
                negative = true
                chars.removeFirst()
                if chars.isEmpty { return nil }
            }
            var radix = base
            if let prefix = chars.first, prefix == "#" || prefix == "$" || prefix == "%" {
                radix = prefix == "#" ? 10 : (prefix == "$" ? 16 : 2)
                chars.removeFirst()
                if chars.isEmpty { return nil }
                if !negative && chars.first == "-" {
                    negative = true
                    chars.removeFirst()
                }
            }
            guard !chars.isEmpty, (2...36).contains(radix) else { return nil }
            var value: Int = 0
            var overflow = false
            var digits = 0
            for ch in chars {
                guard let digit = digitValue(ch), digit < radix else { return nil }
                digits += 1
                let next = value.multipliedReportingOverflow(by: radix)
                if next.overflow { overflow = true } else { value = next.partialValue }
                let added = value.addingReportingOverflow(digit)
                if added.overflow { overflow = true } else { value = added.partialValue }
            }
            guard digits > 0 else { return nil }
            if negative { value = -value }
            let literal = overflow ? nil : value
            return isDouble ? .double(literal) : .single(literal)
        }

        private func digitValue(_ ch: Character) -> Int? {
            guard let scalar = ch.unicodeScalars.first else { return nil }
            let v = scalar.value
            if v >= 48 && v <= 57 { return Int(v - 48) }
            if v >= 65 && v <= 90 { return Int(v - 65) + 10 }
            if v >= 97 && v <= 122 { return Int(v - 97) + 10 }
            return nil
        }

        func characterLiteral(_ token: String) -> Int? {
            guard token.count == 3, token.first == "'", token.last == "'" else { return nil }
            let mid = token.dropFirst().dropLast()
            guard let scalar = mid.unicodeScalars.first, mid.unicodeScalars.count == 1 else { return nil }
            return Int(scalar.value)
        }

        func isFloatLiteral(_ token: String) -> Bool {
            let pattern = #"^-?([0-9]+\.[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?$|^-?[0-9]+[eE][+-]?[0-9]+$"#
            return token.range(of: pattern, options: .regularExpression) != nil
        }
    }

    // MARK: - Tokenizer

    fileprivate static func tokenize(_ source: String) -> [Token] {
        var tokens: [Token] = []
        var index = source.startIndex
        var line = 1
        func bump() {
            guard index < source.endIndex else { return }
            if source[index] == "\n" { line += 1 }
            index = source.index(after: index)
        }
        func readParenBody() -> String {
            var depth = 1
            var body = ""
            while index < source.endIndex {
                let ch = source[index]
                if ch == "(" { depth += 1 }
                if ch == ")" {
                    depth -= 1
                    if depth == 0 {
                        bump()
                        break
                    }
                }
                body.append(ch)
                bump()
            }
            return body
        }
        func skipQuoted(escaped: Bool) {
            while index < source.endIndex {
                let ch = source[index]
                if escaped && ch == "\\" {
                    bump()
                    if index < source.endIndex { bump() }
                    continue
                }
                if ch == "\"" {
                    bump()
                    break
                }
                bump()
            }
        }

        while index < source.endIndex {
            let ch = source[index]
            if ch == " " || ch == "\t" || ch == "\r" {
                bump()
                continue
            }
            if ch == "\n" {
                bump()
                continue
            }
            let startLine = line
            let start = index
            while index < source.endIndex {
                let c = source[index]
                if c == " " || c == "\t" || c == "\n" || c == "\r" { break }
                bump()
            }
            let text = String(source[start..<index])
            if text == "\\" {
                while index < source.endIndex && source[index] != "\n" { bump() }
                continue
            }
            if text == "(" {
                let body = readParenBody()
                if body.contains("--") {
                    tokens.append(Token(text: body, line: startLine, kind: .stackComment))
                }
                continue
            }
            if text == ".(" {
                _ = readParenBody()
                tokens.append(Token(text: ".(", line: startLine, kind: .word))
                continue
            }
            if text == ".\"" || text == "S\"" || text == "C\"" || text == "ABORT\"" || text == "S\\\"" {
                skipQuoted(escaped: text == "S\\\"")
                tokens.append(Token(text: text, line: startLine, kind: .word))
                continue
            }
            tokens.append(Token(text: text, line: startLine, kind: .word))
        }
        return tokens
    }
}

private extension String {
    func fixingEmptySides() -> String {
        var s = self
        s = s.replacingOccurrences(of: "(  --", with: "( --")
        s = s.replacingOccurrences(of: "--  )", with: "-- )")
        s = s.replacingOccurrences(of: "( -- )", with: "( -- )")
        if s.hasPrefix("( ") == false && s.hasPrefix("(") {
            // keep
        }
        // "( x -- x )" already. Collapse double spaces.
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}
