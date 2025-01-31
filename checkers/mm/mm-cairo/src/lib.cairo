use core::fmt::{Display, Formatter, Error};
use core::dict::Felt252Dict;
use core::dict::Felt252DictEntryTrait;
use core::nullable::null;
type TokenCode = u16;
use alexandria_data_structures::array_ext::ArrayTraitExt;
type Label = TokenCode;
pub mod test;

#[derive(Drop, PartialEq, Copy)]
pub enum Token {
    DelimEndStmt,
    DelimC,
    DelimV,
    DelimF,
    DelimD,
    DelimA,
    DelimE,
    DelimP,
    DelimEndClaim,
    DelimOpenBlock,
    DelimCloseBlock,
    TokUser: TokenCode,
}

pub mod codes {
    use super::TokenCode;

    pub const END_STMT: TokenCode = 0;
    pub const END_CLAIM: TokenCode = 8;
    pub const COPY: TokenCode = 11;
    pub const FIRST_IDENT: TokenCode = 12;
    pub const OPEN_PAREN: TokenCode = 12;
    pub const CLOSE_PAREN: TokenCode = 13;
}


impl TokenDisplay of Display<Token> {
    fn fmt(self: @Token, ref f: Formatter) -> Result<(), Error> {
        match self {
            Token::DelimEndStmt => f.buffer.append(@"$."),
            Token::DelimC => f.buffer.append(@"$c"),
            Token::DelimV => f.buffer.append(@"$v"),
            Token::DelimF => f.buffer.append(@"$f"),
            Token::DelimD => f.buffer.append(@"$d"),
            Token::DelimA => f.buffer.append(@"$a"),
            Token::DelimE => f.buffer.append(@"$e"),
            Token::DelimP => f.buffer.append(@"$p"),
            Token::DelimEndClaim => f.buffer.append(@"$="),
            Token::DelimOpenBlock => f.buffer.append(@"$("),
            Token::DelimCloseBlock => f.buffer.append(@"$)"),
            Token::TokUser(code) => f.buffer.append(@format!("userToken{}", code)),
        };
        Result::Ok(())
    }
}

#[derive(Drop, PartialEq, Copy, Default)]
struct Symbol {
    val: u16,
}

#[generate_trait]
impl SymbolImpl of SymbolTrait {
    fn min(a: Symbol, b: Symbol) -> Symbol {
        let mut min = a;
        if b.val < a.val {
            min = b;
        }
        min
    }
    fn max(a: Symbol, b: Symbol) -> Symbol {
        let mut max = a;
        if b.val > a.val {
            max = b;
        }
        max
    }
}

type Statement = Array<Symbol>;
type Proof = Array<TokenCode>;

#[derive(Drop)]
trait TokenReader {
    fn read(ref self: VecTokens) -> Option<Token>;
    fn read_statement(ref self: VecTokens) -> Statement;
    fn read_claim(ref self: VecTokens) -> Statement;
    fn read_proof(ref self: VecTokens) -> Proof;
}

#[derive(Drop)]
struct VecTokens {
    token_buffer: Array<TokenCode>,
}

impl VecTokensReader of TokenReader {
    fn read(ref self: VecTokens) -> Option<Token> {
        match self.token_buffer.pop_front() {
            Option::Some(code) => {
                Option::Some(
                    match code {
                        0 => Token::DelimEndStmt,
                        1 => Token::DelimC,
                        2 => Token::DelimV,
                        3 => Token::DelimF,
                        4 => Token::DelimD,
                        5 => Token::DelimA,
                        6 => Token::DelimE,
                        7 => Token::DelimP,
                        8 => Token::DelimEndClaim,
                        9 => Token::DelimOpenBlock,
                        10 => Token::DelimCloseBlock,
                        _ => Token::TokUser(code),
                    }
                )
            },
            Option::None => Option::None,
        }
    }
    fn read_statement(ref self: VecTokens) -> Statement {
        let mut stat: Array<Symbol> = array![];
        let mut token = Self::read(ref self).expect('Failed to read token.');

        while let Token::TokUser(l) = token {
            stat.append(Symbol { val: l });
            token = Self::read(ref self).expect('EOF before $.');
        };
        if token != Token::DelimEndStmt {
            panic!("Statement ended with unexpected delimiter.");
        };
        stat
    }
    fn read_claim(ref self: VecTokens) -> Statement {
        let mut claim: Array<Symbol> = Default::default();
        let mut token = self.read().expect('Failed to read token');

        while let Token::TokUser(l) = token {
            claim.append(Symbol { val: l });
            token = Self::read(ref self).expect('Failed to read token');
        };
        if token != Token::DelimEndClaim {
            panic!("Claim ended with unexpected delimiter");
        }

        claim.into()
    }
    fn read_proof(ref self: VecTokens) -> Proof {
        let mut proof: Array<Label> = Default::default();
        let mut token = self.read().expect('Failed to read token');

        while let Token::TokUser(l) = token {
            proof.append(l);
            token = Self::read(ref self).expect('EOF before $.');
        };
        if token != Token::DelimEndStmt {
            panic!("Statment ended with unexpected delimiter");
        }

        proof.into()
    }
}

#[derive(Drop, Default)]
struct ArrayDict<K, V> {
    items: Array<(K, V)>,
}

#[generate_trait]
impl ArrayDictImpl<K, V, +PartialEq<K>, +Drop<K>, +Drop<V>, +Copy<V>> of ArrayDictTrait<K, V> {
    fn add(ref self: ArrayDict<K, V>, key: K, val: V) {
        let lookup = self.get(@key);
        match lookup {
            Option::Some(_) => { panic!("Cannot overwrite existing entry.") },
            Option::None => { self.items.append((key, val)); },
        };
    }
    fn get(self: @ArrayDict<K, V>, key: @K) -> Option<V> {
        let mut val = Option::None;
        for (k, v) in self.items.span() {
            if k == key {
                val = Option::Some(v.clone());
                break;
            }
        };
        val
    }
}

struct Felt252DictStack<V> {
    entries: Felt252Dict<Nullable<V>>,
    len: usize,
}

#[generate_trait]
impl Felt252DictStackImpl<V, +Drop<V>, +PartialEq<V>, +Clone<V>> of Felt252DictStackTrait<V> {
    fn new() -> Felt252DictStack<V> {
        Felt252DictStack { entries: Default::default(), len: 0 }
    }
    fn push(ref self: Felt252DictStack<V>, item: V) {
        self.entries.insert(self.len.into(), NullableTrait::new(item));
        self.len += 1;
    }
    fn pop(ref self: Felt252DictStack<V>) -> V {
        if self.len == 0 {
            panic!("Stack underflow");
        }

        let (entry, mut _frame) = self.entries.entry(self.len.into() - 1);
        let frame = _frame.deref();

        self.entries = entry.finalize(null());
        self.len -= 1;
        frame
    }
    fn get_clone(ref self: Felt252DictStack<V>, key: felt252) -> V {
        let (entry, mut _frame) = self.entries.entry(key);
        let frame = _frame.deref();
        let clone = frame.clone();

        self.entries = entry.finalize(NullableTrait::new(frame));
        clone
    }
}
impl Felt252DictStackDestruct<V, +Drop<V>> of Destruct<Felt252DictStack<V>> {
    fn destruct(self: Felt252DictStack<V>) nopanic {
        self.entries.squash();
    }
}

struct Felt252DictClone<V> {
    entries: Felt252Dict<Nullable<V>>,
}

#[generate_trait]
impl Felt252DictCloneImpl<V, +Drop<V>, +Clone<V>> of Felt252DictCloneTrait<V> {
    fn new() -> Felt252DictClone<V> {
        Felt252DictClone { entries: Default::default() }
    }
    fn insert(ref self: Felt252DictClone<V>, key: felt252, item: V) {
        self.entries.insert(key.into(), NullableTrait::new(item));
    }
    fn get_clone(ref self: Felt252DictClone<V>, key: felt252) -> Option<V> {
        let (entry, mut _frame) = self.entries.entry(key);
        let mut clone: Option<V> = Option::None;
        if !_frame.is_null() {
            let frame = _frame.deref();
            clone = Option::Some(frame.clone());
            self.entries = entry.finalize(NullableTrait::new(frame));
        } else {
            self.entries = entry.finalize(null());
        }
        clone
    }
}
impl Felt252DictCloneDestruct<V, +Drop<V>> of Destruct<Felt252DictClone<V>> {
    fn destruct(self: Felt252DictClone<V>) nopanic {
        self.entries.squash();
    }
}

#[derive(Drop, Default)]
struct Frame {
    c: Array<Symbol>,
    v: Array<Symbol>,
    d: Array<(Symbol, Symbol)>,
    f: Array<(Symbol, Symbol)>,
    f_labels: ArrayDict<Symbol, Label>,
    e: Array<Statement>,
    e_labels: ArrayDict<Statement, Label>,
}

#[generate_trait]
impl VecTokensImpl of VecTokensTrait {
    fn new(tokens: Array<TokenCode>) -> VecTokens {
        VecTokens { token_buffer: tokens, }
    }
}


struct FrameStack {
    entries: Felt252Dict<Nullable<Frame>>,
    len: usize,
}

impl FrameStackDestruct of Destruct<FrameStack> {
    fn destruct(self: FrameStack) nopanic {
        self.entries.squash();
    }
}

#[generate_trait]
impl FrameStackImpl of FrameStackTrait {
    fn new() -> FrameStack {
        FrameStack { entries: Default::default(), len: 0 }
    }

    fn push(ref self: FrameStack) {
        self.entries.insert(self.len.into(), NullableTrait::new(Default::default()));
        self.len += 1;
    }

    fn pop(ref self: FrameStack) {
        self.entries.insert(self.len.into() - 1, null());
        self.len -= 1;
    }

    fn add_c(ref self: FrameStack, token: Symbol) {
        let (entry, mut _frame) = self.entries.entry(self.len.into() - 1);

        let mut unboxed_val = _frame.deref();

        if unboxed_val.c.contains(@token) {
            panic!("Const {:?} already defined", token.val);
        }
        if unboxed_val.v.contains(@token) {
            panic!("Const {:?} already defined as var in scope", token.val);
        }
        unboxed_val.c.append(token);

        self.entries = entry.finalize(NullableTrait::new(unboxed_val));
    }

    fn add_v(ref self: FrameStack, token: Symbol) {
        let (entry, mut _frame) = self.entries.entry(self.len.into() - 1);

        let mut unboxed_val = _frame.deref();

        if unboxed_val.v.contains(@token) {
            panic!("Variable {:?} already defined", token.val);
        }
        if unboxed_val.c.contains(@token) {
            panic!("Variable {:?} already defined as const in scope", token.val);
        }
        unboxed_val.v.append(token);

        self.entries = entry.finalize(NullableTrait::new(unboxed_val));
    }

    fn add_f(ref self: FrameStack, var: Symbol, kind: Symbol, label: Label) {
        if !self.lookup_v(var) {
            panic!("var not defined");
        }
        if !self.lookup_c(kind) {
            panic!("const not defined");
        }

        let (entry, mut _frame) = self.entries.entry(self.len.into() - 1);
        let mut frame = _frame.deref();

        let lookup = frame.f_labels.get(@var);
        match lookup {
            Option::None => {},
            Option::Some(_) => { panic!("f already defined in scope") },
        };
        frame.f.append((var.clone(), kind));
        frame.f_labels.add(var, label);

        self.entries = entry.finalize(NullableTrait::new(frame));
    }

    fn add_e(ref self: FrameStack, stat: Statement, label: Label) {
        let (entry, mut _frame) = self.entries.entry(self.len.into() - 1);
        let mut frame = _frame.deref();

        frame.e.append(stat.clone());
        frame.e_labels.add(stat, label);

        self.entries = entry.finalize(NullableTrait::new(frame));
    }

    fn add_d(ref self: FrameStack, stat: Statement) {
        let (entry, mut _frame) = self.entries.entry(self.len.into() - 1);
        let mut frame = _frame.deref();

        let len = stat.len();
        for i in 0..len {
            for j in 0..len {
                let x = *stat.at(i);
                let y = *stat.at(j);
                if x != y {
                    frame.d.append((SymbolTrait::min(x, y), SymbolTrait::max(x, y)))
                };
            }
        };

        self.entries = entry.finalize(NullableTrait::new(frame));
    }

    fn lookup_c(ref self: FrameStack, token: Symbol) -> bool {
        let mut found: bool = false;
        for i in 0..self.len {
            let (entry, frame) = self.entries.entry(i.into());
            let mut unboxed_val = frame.deref();
            if unboxed_val.c.contains(@token) {
                found = true;
                self.entries = entry.finalize(NullableTrait::new(unboxed_val));
                break;
            }
            self.entries = entry.finalize(NullableTrait::new(unboxed_val));
        };
        found
    }

    fn lookup_v(ref self: FrameStack, token: Symbol) -> bool {
        let mut found: bool = false;
        for i in 0..self.len {
            let (entry, frame) = self.entries.entry(i.into());
            let mut unboxed_val = frame.deref();
            if unboxed_val.v.contains(@token) {
                found = true;
                self.entries = entry.finalize(NullableTrait::new(unboxed_val));
                break;
            }
            self.entries = entry.finalize(NullableTrait::new(unboxed_val));
        };
        found
    }

    fn lookup_f_most_recent(ref self: FrameStack, var: Symbol) -> Label {
        let mut i: usize = self.len - 1;
        let mut lab = Option::None;
        loop {
            let (entry, _frame) = self.entries.entry(i.into());
            let frame = _frame.deref();

            let res = frame.f_labels.get(@var);
            match res {
                Option::Some(l) => {
                    lab = Option::Some(l);
                    self.entries = entry.finalize(NullableTrait::new(frame));
                    break;
                },
                Option::None => {}
            };
            self.entries = entry.finalize(NullableTrait::new(frame));
            if i == 0 {
                break;
            }
            i -= 1;
        };
        lab.expect('Label not found.')
    }

    fn lookup_e_most_recent(ref self: FrameStack, stmt: Statement) -> Label {
        let mut i: usize = self.len - 1;
        let mut lab = Option::None;
        loop {
            let (entry, _frame) = self.entries.entry(i.into());
            let frame = _frame.deref();

            let res = frame.e_labels.get(@stmt);
            match res {
                Option::Some(l) => {
                    lab = Option::Some(l);
                    self.entries = entry.finalize(NullableTrait::new(frame));
                    break;
                },
                Option::None => {}
            };
            self.entries = entry.finalize(NullableTrait::new(frame));
            if i == 0 {
                break;
            }
            i -= 1;
        };
        lab.expect('Label not found.')
    }

    fn lookup_d(ref self: FrameStack, x: @Symbol, y: @Symbol) -> bool {
        let pair = if y.val < x.val {
            (*y, *x)
        } else {
            (*x, *y)
        };
        let mut found: bool = false;
        for i in 0..self.len {
            let (entry, frame) = self.entries.entry(i.into());
            let mut frame = frame.deref();
            if frame.d.contains(@pair) {
                found = true;
                self.entries = entry.finalize(NullableTrait::new(frame));
                break;
            }
            self.entries = entry.finalize(NullableTrait::new(frame));
        };
        found
    }

    fn collect_vars(ref self: FrameStack) -> Array<Symbol> {
        let mut vars: Array<Symbol> = Default::default();
        for i in 0..self.len {
            let (entry, _frame) = self.entries.entry(i.into());
            let frame = _frame.deref();

            let mut frame_vars = frame.v.clone();
            let len = frame_vars.len();
            for j in 0..len {
                vars.append(frame_vars.at(j).clone());
            };
            self.entries = entry.finalize(NullableTrait::new(frame));
        };
        //TODO dedup only works with sorted arrays
        vars = vars.unique();
        vars
    }

    fn collect_dvs(ref self: FrameStack) -> Array<(Symbol, Symbol)> {
        let mut dvs: Array<(Symbol, Symbol)> = Default::default();
        for i in 0..self.len {
            let (entry, _frame) = self.entries.entry(i.into());
            let frame = _frame.deref();

            let mut frame_dvs = frame.d.clone();
            let len = frame_dvs.len();
            for j in 0..len {
                dvs.append(frame_dvs.at(j).clone());
            };
            self.entries = entry.finalize(NullableTrait::new(frame));
        };
        //TODO dedup only works with sorted arrays
        dvs = dvs.unique();
        dvs
    }

    fn collect_fs(ref self: FrameStack) -> Array<(Symbol, Symbol)> {
        let mut fs: Array<(Symbol, Symbol)> = Default::default();
        let mut i: usize = self.len - 1;
        loop {
            let (entry, _frame) = self.entries.entry(i.into());
            let frame = _frame.deref();

            let mut frame_fs = frame.f.clone();

            let len = frame_fs.len();
            for j in 0..len {
                fs.append(frame_fs.at(j).clone());
            };
            self.entries = entry.finalize(NullableTrait::new(frame));
            if i == 0 {
                break;
            }
            i -= 1;
        };
        fs
    }

    fn make_assertion(ref self: FrameStack, stat: Statement) -> Assertion {
        let mut e_hyps: Array<Statement> = Default::default();

        let mut vars: Array<Symbol> = self.collect_vars();
        let mut dvs: Array<(Symbol, Symbol)> = self.collect_dvs();
        let f_hyps: Array<(Symbol, Symbol)> = self.collect_fs();

        let (entry, mut _frame) = self.entries.entry(self.len.into() - 1);

        let mut frame = _frame.deref();

        for stmt in frame.e.clone() {
            e_hyps.append(stmt);
        };

        let mut mand_vars: Array<Symbol> = Default::default();
        for stmt in e_hyps
            .span() {
                for token in stmt.span() {
                    if vars.contains(token) {
                        mand_vars.append(*token);
                    }
                };
            };
        for symb in stat.span() {
            mand_vars.append(symb.clone());
        };
        //TODO dedup only works with sorted arrays
        mand_vars = mand_vars.unique();

        let mut cartesian: Array<(Symbol, Symbol)> = Default::default();

        for x in mand_vars
            .span() {
                let len = mand_vars.len();
                for i in 0..len {
                    cartesian.append((x.clone(), mand_vars.at(i).clone()));
                };
            };

        let mut mand_dvs: Array<(Symbol, Symbol)> = Default::default();
        for dv in dvs {
            if cartesian.contains(@dv) {
                mand_dvs.append(dv);
            }
        };

        let mut mand_f_hyps: Array<(Symbol, Symbol)> = Default::default();

        let mut mand_vars_done: Array<Symbol> = Default::default();

        for (
            v, k
        ) in f_hyps {
            if mand_vars.contains(@v) && !mand_vars_done.contains(@v) {
                mand_f_hyps.append((k, v));
                mand_vars_done.append(v);
            }
        };

        self.entries = entry.finalize(NullableTrait::new(frame));

        Assertion { dvs: mand_dvs, f_hyps: mand_f_hyps, e_hyps: e_hyps, stat: stat, }
    }
}

#[derive(Drop, Clone)]
pub struct Assertion {
    dvs: Array<(Symbol, Symbol)>,
    f_hyps: Array<(Symbol, Symbol)>,
    e_hyps: Array<Statement>,
    stat: Statement,
}


#[derive(Drop, Clone)]
enum LabelEntry {
    DollarA: Assertion,
    DollarP: Assertion,
    DollarE: Statement,
    DollarF: Statement,
}

struct MM {
    fs: FrameStack,
    labels: Felt252DictClone<LabelEntry>,
}

impl MMDestruct of Destruct<MM> {
    fn destruct(self: MM) nopanic {
        self.fs.destruct();
    }
}

#[generate_trait]
impl MMImpl of MMTrait {
    fn new() -> MM {
        MM { fs: FrameStackImpl::new(), labels: Felt252DictCloneTrait::<LabelEntry>::new() }
    }

    fn read(ref self: MM, ref tokens: VecTokens) -> bool {
        self.fs.push();
        let mut label: Option<Label> = Option::None;
        let mut found_end_label = false;
        loop {
            match tokens.read() {
                Option::Some(tok) => {
                    match tok {
                        Token::DelimCloseBlock => { break; },
                        Token::DelimC => {
                            for tok in tokens.read_statement() {
                                self.fs.add_c(tok);
                            }
                        },
                        Token::DelimV => {
                            for tok in tokens.read_statement() {
                                self.fs.add_v(tok);
                            }
                        },
                        Token::DelimF => {
                            let stat = tokens.read_statement();
                            let label_u: Label = label.expect('$f must have a label').into();
                            if stat.len() != 2 {
                                panic!("$f must have length 2");
                            }
                            self.fs.add_f(stat[1].clone(), stat[0].clone(), label_u.clone());
                            let data = LabelEntry::DollarF(stat.clone());
                            self.labels.insert(label_u.into(), data);
                            label = Option::None;
                        },
                        Token::DelimA => {
                            let label_u = label.expect('$a must have a label');
                            let data = LabelEntry::DollarA(
                                self.fs.make_assertion(tokens.read_statement())
                            );
                            self.labels.insert(label_u.into(), data);
                            label = Option::None;
                        },
                        Token::DelimE => {
                            let label_u: Label = label.expect('$e must have label').into();
                            let stat = tokens.read_statement();
                            self.fs.add_e(stat.clone(), label_u.clone());
                            let data = LabelEntry::DollarE(stat);
                            self.labels.insert(label_u.into(), data);
                            label = Option::None;
                        },
                        Token::DelimP => {
                            let label_u: Label = label.expect('$e must have label').into();

                            let claim = tokens.read_claim();
                            let proof = tokens.read_proof();

                            self.verify(label_u, claim.clone(), proof);

                            let data = LabelEntry::DollarP(self.fs.make_assertion(claim));
                            self.labels.insert(label_u.into(), data);
                            label = Option::None;
                        },
                        Token::DelimD => { self.fs.add_d(tokens.read_statement()); },
                        Token::DelimOpenBlock => {
                            let out = self.read(ref tokens);
                            if out == false {
                                found_end_label = true;
                                break;
                            }
                        },
                        Token::TokUser(x) => { label = Option::Some(x); },
                        Token::DelimEndStmt | Token::DelimEndClaim => { panic!("Unexpected $.") },
                    }
                },
                Option::None => { break; },
            };
        };
        if found_end_label {
            return false;
        }
        self.fs.pop();
        true
    }

    fn verify_assertion(
        ref self: MM, assertion: Assertion, ref stack: Felt252DictStack<Statement>
    ) -> Statement {
        let Assertion { dvs: distinct, f_hyps: mand_var, e_hyps: hyp, stat: result, } = assertion;

        // Find the number of hypotheses to pop from the stack
        let npop = mand_var.len() + hyp.len();

        let sp = stack.len - npop;
        let mut sp = sp;
        let mut subst: Felt252DictClone<Statement> = Felt252DictCloneTrait::new();

        for (
            k, v
        ) in mand_var {
            let entry: Statement = stack.get_clone(sp.into());
            let mut entry_rhs = entry.span();

            if *entry_rhs.pop_front().unwrap() != k {
                panic!(
                    "stack entry doesn't match mandatory var hypothesis, found {:?} and {:?}",
                    entry[0].val,
                    k.val
                )
            }

            subst.insert(v.val.into(), entry_rhs.into());
            sp += 1;
        };

        // Check that the disjoint-variable restrictions are satisfied
        for (
            x, y
        ) in distinct {
            let x_vars = self.find_vars(subst.get_clone(x.val.into()).unwrap());
            let y_vars = self.find_vars(subst.get_clone(y.val.into()).unwrap());

            let x_vars_len: usize = x_vars.len();
            for i in 0..x_vars_len {
                let y_vars_len: usize = y_vars.len();
                for j in 0..y_vars_len {
                    let x = x_vars[i];
                    let y = y_vars[j];

                    if x == y || !self.fs.lookup_d(x, y) {
                        panic!("Disjoint violation");
                    }
                };
            }
        };

        // Obtain the logical-type hypotheses from the stack
        for h in hyp {
            let entry: Statement = stack.get_clone(sp.into());

            if !self.check_subst(h, ref subst, entry) {
                panic!("Stack entry doesn't match hypothesis")
            };
            sp += 1;
        };

        for _ in 0..npop {
            stack.pop();
        };

        let substituted = self.apply_subst(result, ref subst);
        stack.push(substituted.clone());
        substituted
    }

    fn apply_subst(
        ref self: MM, stat: Statement, ref subst: Felt252DictClone<Statement>
    ) -> Statement {
        let mut result = array![];

        for tok in stat {
            let res = subst.get_clone(tok.val.into());
            match res {
                Option::Some(s) => { result.append_span(s.span()); },
                Option::None => { result.append(tok); },
            }
        };
        result
    }

    fn check_subst(
        ref self: MM, stat: Statement, ref subst: Felt252DictClone<Statement>, result: Statement
    ) -> bool {
        let mut i: usize = 0;
        let mut j: usize = 0;
        let mut diff = false;

        let mut stat_span = stat.span();
        while let Option::Some(stmt_tok) = stat_span.pop_front() {
            i += 1;
            if let Option::Some(replacement) = subst.get_clone((*stmt_tok.val).into()) {
                let mut k = 0;
                while k < replacement.len() {
                    let subst_tok = replacement.get(k).unwrap();
                    k += 1;
                    let result_tok = result.get(j);
                    j += 1;
                    match result_tok {
                        Option::Some(result_tok) => {
                            if subst_tok.unbox() != result_tok.unbox() {
                                diff = true;
                                break;
                            }
                        },
                        _ => {
                            diff = true;
                            break;
                        }
                    };
                };
            } else {
                let result_tok = result.get(j);
                j += 1;
                match result_tok {
                    Option::Some(result_tok) => {
                        if stmt_tok != result_tok.unbox() {
                            diff = true;
                            break;
                        }
                    },
                    _ => {
                        diff = true;
                        break;
                    }
                }
            }
        };
        if diff {
            return false;
        }
        i == stat.len()
    }

    fn find_vars(ref self: MM, stat: Statement) -> Array<Symbol> {
        let mut vars: Array<Symbol> = array![];
        for x in stat {
            if !vars.contains(@x) && self.fs.lookup_v(x) {
                vars.append(x);
            }
        };

        vars
    }

    fn decompress_and_verify(ref self: MM, stat: Statement, proof: Proof) {
        // Find index of closing parenthesis for compressed proof
        let mut ep = 0;
        loop {
            if *proof.at(ep) == codes::CLOSE_PAREN {
                break;
            }
            if ep == proof.len() {
                panic!("Failed to find matching parenthesis");
            }
            ep += 1;
        };

        let mut labels: Array<Label> = self.get_labels(@stat);
        let hyp_end = labels.len();

        let mut i: usize = 1;
        while i < ep {
            labels.append(proof.at(i).clone());
            i += 1;
        };
        let label_end = labels.len();
        let mut proof_indices: Array<Option<usize>> = Default::default();
        let mut i: usize = ep + 1;
        while i != proof.len() {
            let c = *proof[i];
            if c == codes::COPY {
                proof_indices.append(Option::None);
            } else {
                proof_indices.append(Option::Some((c - codes::COPY - 1).into()));
            }
            i += 1;
        };

        if proof_indices.is_empty() {
            // we didn't do the proof yet
            return;
        }

        let mut subproofs: Array<Statement> = array![];
        let mut stack: Felt252DictStack<Statement> = Felt252DictStackTrait::<Statement>::new();
        let mut previous_proof: Statement = array![];
        let mut previous_proof_exists = false;

        for pf_int in proof_indices {
            match pf_int {
                Option::None => {
                    if !previous_proof_exists {
                        panic!("Error: found unexpected Z");
                    }
                    let last_proof = previous_proof.clone();
                    subproofs.append(last_proof);
                },
                Option::Some(i) => {
                    if i < hyp_end {
                        let label = *labels[i];
                        let data = self.labels.get_clone(label.into()).unwrap();
                        match data {
                            LabelEntry::DollarA(a) |
                            LabelEntry::DollarP(a) => {
                                let new_prev = self.verify_assertion(a, ref stack);
                                previous_proof = new_prev;
                                previous_proof_exists = true;
                            },
                            LabelEntry::DollarF(x) |
                            LabelEntry::DollarE(x) => {
                                stack.push(x.clone());
                                previous_proof = x;
                                previous_proof_exists = true;
                            },
                        }
                    } else if hyp_end <= i && i < label_end {
                        let label_name = *labels[i];
                        let step_data = self.labels.get_clone(label_name.into()).unwrap();
                        match step_data {
                            LabelEntry::DollarA(a) |
                            LabelEntry::DollarP(a) => {
                                let prev_statement = self.verify_assertion(a, ref stack);
                                previous_proof = prev_statement;
                                previous_proof_exists = true;
                            },
                            LabelEntry::DollarE(x) |
                            LabelEntry::DollarF(x) => {
                                previous_proof = x.clone();
                                previous_proof_exists = true;
                                stack.push(x);
                            }
                        }
                    } else if label_end <= i {
                        let pf = subproofs[i - label_end];
                        stack.push(pf.clone());
                        previous_proof = pf.clone();
                        previous_proof_exists = true;
                    } else {
                        panic!("Bad compression")
                    }
                }
            }
        };

        if stack.len != 1 {
            panic!("Stack has an entry greater than >1 at end");
        };
        let remainder = stack.pop();

        if remainder != stat {
            panic!("assertion proved doesn't match");
        }
    }

    fn get_labels(ref self: MM, stat: @Statement) -> Array<Label> {
        let Assertion { dvs: _, f_hyps: mand_hyp_statements, e_hyps: hype_statements, stat: _, } =
            self
            .fs
            .make_assertion(stat.clone());

        let mut labels: Array<Label> = Default::default();
        for (
            _, v
        ) in mand_hyp_statements {
            let x = self.fs.lookup_f_most_recent(v);
            labels.append(x);
        };
        for s in hype_statements {
            let x = self.fs.lookup_e_most_recent(s);
            labels.append(x);
        };
        labels
    }

    fn verify(ref self: MM, _stat_label: Label, stat: Statement, proof: Proof) {
        let mut stack: Felt252DictStack<Statement> = Felt252DictStackTrait::<Statement>::new();

        if *proof.at(0) == codes::OPEN_PAREN {
            self.decompress_and_verify(stat, proof);
            return;
        }

        if proof.is_empty() {
            return;
        }

        for label in proof {
            let stepdat = self.labels.get_clone(label.into()).unwrap();
            match stepdat {
                LabelEntry::DollarA(a) |
                LabelEntry::DollarP(a) => { self.verify_assertion(a, ref stack); },
                LabelEntry::DollarF(x) | LabelEntry::DollarE(x) => { stack.push(x); },
            };
        };
        if stack.len != 1 {
            panic!("Stack has an entry greater than >1 at end");
        };
        let remainder = stack.pop();

        if remainder != stat {
            panic!("assertion proved doesn't match");
        }
    }
}


fn main(mm_proof: Array<felt252>) -> Array<felt252> {

    let mut mm_proof_tok: Array<TokenCode> = array![];
    for x in mm_proof {
        mm_proof_tok.append(x.try_into().unwrap());
    };
    check_proof(mm_proof_tok);
    array![]
}

fn check_proof(mm_proof: Array<TokenCode>) {
    let mut mm = MMTrait::new();
    let mut token_reader = VecTokensTrait::new(mm_proof);
    mm.read(ref token_reader);
}
