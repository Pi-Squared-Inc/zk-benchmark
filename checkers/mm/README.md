# ZK-enabled Metamath checkers

## Requirements

This requires some basic build tools, Rust/Cargo (most easily
installed via [rustup]), and the risc0 toolchain. A typical
install process is:

    sudo apt install build-essential libssl-dev pkg-config
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    rustup target add riscv32i-unknown-none-elf
    cargo install cargo-binstall
    cargo binstall 'cargo-risczero@1.0.5'
    cargo risczero install
    curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
    curl -L https://sp1.succinct.xyz | bash
    . ~/.bashrc
    sp1up

### Requiremens for zkwasm

The checker for zkwasm requires that
- `wasm-pack` is installed
- the `zkwasm` sources be patched and then compiled (with or without CUDA support).
- a set of public parameters to be used by the ckecer is generated by `zkwasm`

To do that, please follow the [`setup.sh`](mm-wasm/setup.sh) script from the `mm-wasm` directory

### Additional requirements for Cairo (ZK certificate generation)

Check [`mm-cairo/README.md`](mm-cairo/README.md#generating-zk-certificates--profiling-zk-proving).

## GPU support

### `mm-cairo`

Although recent version of lambdaworks seem to support GPU, the cairo prover was discontinued
and we are building it from an older version which does not seem to compile with the
"cuda" feature.

### `mm-jolt`

Currently yhere seems to be no GPU support available for Jolt, although there is an
in-progress mention it as a [possible future improvement](https://github.com/a16z/jolt/blob/main/book/src/future/improvements-since-release.md#prover-cost-improvements-all-in-progress).

### `mm-nexus`

Doesn't seem to support GPU

### `mm-risc0`

The CUDA feature can be enabled by adding "cuda" as a feature to the `risc0-zkvm` dependency in
[`mm-risc0/host/Cargo.toml`](mm-risc0/host/Cargo.toml).

### `mm-sp1`

The CUDA feature can be enabled by adding "cuda" as a feature to the `sp1-sdk` dependency in
[`mm-sp1/host/Cargo.toml`](mm-sp1/host/Cargo.toml).

Note though that the feature is [experimental](https://docs.succinct.xyz/generating-proofs/hardware-acceleration/cuda.html)
and that it relies on docker being able to access the GPU.

### `mm-wasm`

The instructions in [`mm-wasm/setup.sh`](mm-wasm/setup.sh) enable CUDA support for `zkwasm`
by passing `--feature cuda` to the `cargo install` command for `zkwasm-cli`.


## `mm-*` tools in `checker/mm`

Currently, we provide the following tools: `mm-cairo`, `mm-jolt`, `mm-nexus`, `mm-risc0`, `mm-sp1`, `mm-wasm`

They each consist of a _guest_ program which runs on the specific VM and a _host_ program which is our interface to
running the guest, providing input for it and processing its output.

### Build

for each of these tools, running `cargo build -r` from their corresponding directory (`checker/mm/mm-*`) should suffice for building them
except for `mm-cairo` which requires an additional `scarb build` for building the guest

### Executable location

Except for `mm-wasm` (which is detailed below), all checkers use the following location

   `MAIN_PI2_DIR/.build/checker/release/mm-*`

You can also use `cargo run -r --` from their corresponding directory (`checker/mm/mm-*`).

Note: Except for `mm-risc0`, all checkers require being run from their specific project directory (to be able to detect their corresponding `guest` program)

### Basic Usage

All tools use `clap` for command-line argument parsing so invoking them with no arguments or with `--help` will produce
a usage message of the form:
```
mm-jolt$ ../../../.build/checker/release/mm-jolt
Generate a Jolt ZK certificate for checking a MetaMath proof

Usage: mm-jolt [OPTIONS] <FILE> [MAIN_THEOREM]

Arguments:
  <FILE>          Path to the MetaMath file containing the proof to be verified
  [MAIN_THEOREM]  Name of the proposition in the file whose verification to certify

Options:
      --infer-main-theorem  Infer `main_theorem` as the last proposition in the file
  -h, --help                Print help
  -V, --version             Print version
```

All tools support at least the CLI shown above, so at a minimum all tools require just the path to a metamath file as an argument to start.

Providing the optional `MAIN_THEOREM` argument will require that a provable statement with that label exists in the file
to be checked. If checking the __whole__ file succeeds, the statement corresponding to that label will be sent as output
by the guest and displayed by the host.

### Specific options and output for specific tools

#### `mm-cairo`

```
mm-cairo$ ../../../.build/checker/release/mm-cairo ../common/metamath-files/metamath-test/tiny.mm

Reading metamath file ../common/metamath-files/metamath-test/tiny.mm
Metamath file has 3 lines.
Serializing metamath file
File is 13 tokens long
Success
cairo steps: 4147
```

#### `mm-nexus`

```
mm-nexus$ ../../../.build/checker/release/mm-nexus ../common/metamath-files/metamath-test/tiny.mm
Compiling guest program... done. Time elapsed: 114.96s
File is 13 tokens long
Running the checker directly to obtain the hints.
Setting up Nova public parameters... done. Time elapsed: 30.16s
Proving execution of vm... done. Time elapsed: 1360.80s
Verifying execution...  Succeeded! Time elapsed: 4.69s
>>>>> Logging
<<<<<
Target theorem: true

```

Because `mm-nexus` seems very (too) slow in proof mode and does not have any _developer mode_ setting, we provide
the `--only-run` CLI option:
```
      --only-run            Whether to only run the program (skipping proving)
```


#### `mm-jolt`

Note: `mm-jolt` seems to require being run from the project directory (to be able to detect the guest)

```
mm-jolt$ ../../../.build/checker/release/mm-jolt ../common/metamath-files/metamath-test/tiny.mm
build_check_proof took 47.726081157s

Reading metamath file ../common/metamath-files/metamath-test/tiny.mm
Metamath file has 3 lines.
Serializing metamath file
File is 13 tokens long
Running the checker directly to obtain the hints.
Serializing target theorem
Trace length: 2317
prove took 2.824056613s
Public input size: 16, output size: 1
verify took 100.285137ms
valid: true
```

#### `mm-risc0`
```
mm-risc0$ RISC0_DEV_MODE=1 ../../../.build/checker/release/mm-risc0 ../common/metamath-files/metamath-test/tiny.mm

Reading metamath file ../common/metamath-files/metamath-test/tiny.mm
Metamath file has 3 lines.
Serializing metamath file
File is 13 tokens long
Running the checker directly to obtain the hints.
Serializing target theorem
Serializing provable-to-axiom tokens []
The stream of tokens will be processed in a single batch
Creating environment
WARNING: proving in dev mode. This will not generate valid, secure proofs.
Proving file
Batch 0 execution duration: 14.51ms
WARNING: Proving in dev mode does not generate a valid receipt. Receipts generated from this process are invalid and should never be used in production.
Batch 0 proving duration: 2.24ms
Proof complete
Batch 0 was processed successfully
Batch 0 guest cycles: 7171
Batch 0 total cycles: 131072
guest cycles: 7171
```

This is the most developed zkvm implementation. RiscZero seems to provide additional support for things like continuations (pause/resume proof)/composition (recursion).

If not interested in the ZK certificate/actual time it takes to produce it, then the executable should be run with the
`RISC0_DEV_MODE=1` variable set in the environment (disables proving, but still computes relevant info such as number of cycles).

In addition to the basic arguments, `mm-risc0` also supports the following:

- arguments for turning provable statements into axioms
  ```
        --to-axiom [<SYMBOL>...]       Turns proof statements whose claim starts with any of the provided
        symbols into axioms. Default targets are #Pattern and #Variable
        --all-to-axiom                 Turn all proof statments into axioms
  ```
- arguments allowing to pause/resume the execution of the zkvm after a label is encountered
  ```
        --split-tokens-at <SYMBOL>     Splits the token stream after the provided name of an axiom/provable statement
        --save-session <FILE_NAME>     Saves the intermediate zkvm image into given file
        --restore-session <FILE_NAME>  Restores the intermediate zkvm image from given file
  ```

  `--save-session` and `--restore-session` can only be used with `--split-tokens-at`.
  `--save-session` saves the session after the first batch of tokens is processed to given file
  `--restore-session` restores the session from file and processes only the second batch of tokens

## `mm-sp1`

```
mm-sp1$ ../../../.build/checker/release/mm-sp1 ../common/metamath-files/metamath-test/tiny.mm

Reading metamath file common/metamath-files/metamath-test/tiny.mm
Metamath file has 3 lines.
Serializing metamath file
File is 13 tokens long
Running the checker directly to obtain the hints.
Serializing target theorem
Setup the program for proving.
Generate the proof
Successfully generated proof!
Successfully verified proof!
```

`mm-sp1` does not have a dev mode option, but allows to execute the program without proving
to report the number of cycles:

```
mm-sp1$ ../../../.build/checker/release/mm-sp1 ../common/metamath-files/metamath-test/ti
ny.mm --execute

Reading metamath file ../common/metamath-files/metamath-test/tiny.mm
Metamath file has 3 lines.
Serializing metamath file
File is 13 tokens long
Running the checker directly to obtain the hints.
Serializing target theorem
Executing the program
Program executed successfully.
Number of cycles: 8400
```

## `mm-wasm`

The `mm-wasm` Rust project is just a helper used to serialize the input
into the format used by the guest, while execution, proving, and verification
are all done through the zkwasm CLI.

Hence `mm-wasm` should be executed though the [Checker](mm-wasm/Checker) script
provided in the `mm-wasm` directory.

Prior to going through the actual checking process, the `Checker` script will
check that the required tools were made available.

### Usage

```bash
$ ./Checker --help
Usage:
        ./run.sh <MM_FILE> [--execute]
the --execute flag triggers a dry-run
```

### Example

The `Checker` script can be run from any directory.

```
pi2$ checker/mm/mm-wasm/Checker checker/mm/common/metamath-files/metamath-test/tiny.mm
[INFO]: 🎯  Checking for the Wasm target...
[INFO]: 🌀  Compiling to Wasm...
   Compiling method v0.1.0 (/home/traian/pi2/checker/mm/mm-wasm/guest)
    Finished `release` profile [optimized] target(s) in 0.59s
[INFO]: ⬇️  Installing wasm-bindgen...
[INFO]: Optimizing wasm binaries with `wasm-opt`...
[INFO]: Optional fields missing from Cargo.toml: 'description', 'repository', and 'license'. These are not necessary, but recommended
[INFO]: ✨   Done in 2.91s
[INFO]: 📦   Your wasm pkg is ready to publish at /home/traian/pi2/checker/mm/mm-wasm/guest/pkg.
warning: /home/traian/pi2/checker/mm/mm-wasm/Cargo.toml: unused manifest key: workspace.excludes
   Compiling mmlib-host v0.1.0 (/home/traian/pi2/checker/mm/common/mmlib-host)
   Compiling mm-wasm v0.1.0 (/home/traian/pi2/checker/mm/mm-wasm/host)
    Finished `release` profile [optimized + debuginfo] target(s) in 7.34s
     Running `/home/traian/pi2/checker/../.build/checker/release/mm-wasm /home/traian/pi2/checker/mm/common/metamath-files/metamath-test/tiny.mm /home/traian/pi2/checker/mm/common/metamath-files/metamath-test/tiny.mm.zkwasm.bin`

Metamath file read: /home/traian/pi2/checker/mm/common/metamath-files/metamath-test/tiny.mm
Metamath file read as (# of lines): 3
Serializing metamath file
Metamath file preparsed as (# of tokens): 13
Running the checker directly to obtain the hints.
Serializing target theorem
Creating environment
[1/8] Load image...
[2/8] Load params...
[3/8] Executing...
total guest instructions used 8857
total host api used {}
[4/8] Context output is not specified. Skip writing context output...
[5/8] Writing traces to "./output/traces"...
[6/8] Build circuit(s)...
[7/8] Creating proof(s)...
[8/8] Saving proof load info to "./output/metamath.loadinfo.json"...

real    1m43.823s
user    12m6.651s
sys     1m42.308s
[1/2] Reading proofs from "./output"
loading instance from: metamath.0.instance.data
loading instance size: 0
[2/2] Found 1 proofs, verifying..
Verification succeeded!

real    0m4.442s
user    3m26.819s
sys     0m0.532s
```

## `mm-lurk`

### Requirements

- [Lurk](https://github.com/argumentcomputer/lurk) interpreter.
- Python3

### Lurk installation

Clone the lurk repository and build/install with cargo:
```
git clone https://github.com/argumentcomputer/lurk.git
cd lurk
cargo install --path .
```

Can also be installed with:
```
checker/mm/mm-lurk/checker build
```

### Usage

To run, e.g., anatomy.mm

```
checker/mm/mm-lurk/checker run checker/mm/common/metamath-files/metamath-test/anatomy.mm
```

To run test suite:

```
checker/mm/mm-lurk/checker test
```

## `mmtool` in `checker/mm/common`

This tool runs the checker natively (not in a zkvm) and computes various statistics, both
static and dynamic


### Build

Run `cargo build -r` from its corresponding directory (`checker/mm/common/mmtool`)

### Executable location

`MAIN_PI2_DIR/.build/checker/release/mmtool`

You can also use `cargo run -r --` from its corresponding directory (`checker/mm/common/mmtool`).

### Basic usage

Same as the basic usage for the `mm-*` tools described above

### Sample output

```
../../../../.build/checker/release/mmtool ../../common/metamath-files/metamath-test/tiny.mm

Reading metamath file ../../common/metamath-files/metamath-test/tiny.mm
Metamath file has 3 lines.
Serializing provable-to-axiom tokens []
Metamath file preparsed as 13 tokens.
Maximum id used 16
Proof stats: total lemma size: 0
Proof stats: total claim size: 1
Proof stats: max stack depth: 0
Proof stats: max stack size: 0
Proof stats: max cumulated subst size per proof: 1

Proof stats: Propositions count: 1
Proof stats: Constants count: 1
Proof stats: Variables count: 0
Proof stats: Variable Hypotheses count: 0
Proof stats: Logical Hypotheses count: 0
Proof stats: Disjoint vars pairs count: 0
Proof stats: Proof steps count: 1

Proof info: Last checked proposition: thm
```

## Python support for executing and collecting statistics

Check the `Statistics` class in [`mmtool_report.py`](common/mmtool/mmtool/mmtool_report.py)
It assumes that relevant information in the program output is specified as strings of the
form `<pattern>: <value>`, allows associating labels for patterns, and collecting and
updating dictionary-like structures from runs of executables.