use bincode::enc::write::Writer;
use cairo1_run::cairo_run_program;
use cairo1_run::Cairo1RunConfig;
use cairo1_run::FuncArg;
use cairo_lang_runner::Arg;
use cairo_lang_runner::StarknetState;
use cairo_lang_sierra::program::VersionedProgram;
use cairo_vm::types::layout_name::LayoutName;
use starknet_types_core::felt::Felt;
use std::io;
use std::io::Write;
use std::str::FromStr;

extern crate alloc;

use cairo_lang_runner::SierraCasmRunner;

use mmlib_host::{read_mm_file, MainTheoremArgs};

use alloc::string::{String, ToString};
use alloc::vec;
use std::fs;

use clap::Parser;

#[derive(Parser)]
#[command(about = "Generate a Cairo ZK certificate for checking a MetaMath proof")]
#[command(version, arg_required_else_help = true, long_about = None)]
struct Args {
    /// Path to the MetaMath file containing the proof to be verified
    file: String,

    /// Path to generate the trace file at if generating proof trace
    #[arg(long = "trace-file")]
    trace_file: Option<String>,

    /// Path to generate the memory file at if generating proof trace
    #[arg(long = "memory-file")]
    memory_file: Option<String>,

    /// Generate zk certificate
    #[arg(long = "cert-gen", default_value = "false")]
    certgen: bool,

    /// Path to dump program args
    #[arg(long = "args-file")]
    args_file: Option<String>,

    #[command(flatten)]
    main_theorem_args: MainTheoremArgs,
}

pub struct FileWriter {
    buf_writer: io::BufWriter<std::fs::File>,
    bytes_written: usize,
}

impl Writer for FileWriter {
    fn write(&mut self, bytes: &[u8]) -> Result<(), bincode::error::EncodeError> {
        self.buf_writer
            .write_all(bytes)
            .map_err(|e| bincode::error::EncodeError::Io {
                inner: e,
                index: self.bytes_written,
            })?;

        self.bytes_written += bytes.len();

        Ok(())
    }
}

impl FileWriter {
    fn new(buf_writer: io::BufWriter<std::fs::File>) -> Self {
        Self {
            buf_writer,
            bytes_written: 0,
        }
    }

    fn flush(&mut self) -> io::Result<()> {
        self.buf_writer.flush()
    }
}

fn main() {
    let args = Args::parse();

    let cairo_build_dir = std::env::var("CAIRO_BUILD_DIR").unwrap_or("target/dev/".to_string());
    let path = format!("{}/mm_cairo.sierra.json", cairo_build_dir);

    let sierra_program = serde_json::from_str::<VersionedProgram>(
        &fs::read_to_string(path.as_str()).expect(format!("Could not read file {}", path).as_str()),
    )
    .expect("Invalid sierra file.")
    .into_v1()
    .expect("Could not convert sierra file to v1.");

    if args.main_theorem_args.main_theorem.is_some() || args.main_theorem_args.infer_main_theorem {
        println!("Warning: target theorem is specified but selecting a theorem is not currently supported. All proofs will be checked.");
    }

    let (_ident_table, res) = read_mm_file(&args.file);

    if let Some(args_file) = args.args_file {
        let mut arr = vec![];
        for token in res {
            arr.push(Felt::from_str(token.to_string().as_str()).expect(
                format!("Could not convert \"{}\" to felt252.", token.to_string()).as_str(),
            ));
        }

        let program_args = arr.into_iter().map(|felt| felt.to_string()).reduce(|acc, elt| format!("{acc} {elt}")).unwrap();
        std::fs::write(args_file, format!("[{program_args}]")).unwrap();
    } else if args.certgen {
        let mut arr = vec![];
        for token in res {
            arr.push(Felt::from_str(token.to_string().as_str()).expect(
                format!("Could not convert \"{}\" to felt252.", token.to_string()).as_str(),
            ));
        }

        let cairo_args = vec![FuncArg::Array(arr)];
        let mut run_config = Cairo1RunConfig::default();
        run_config.layout = LayoutName::recursive;
        run_config.args = &cairo_args;
        run_config.trace_enabled = true;
        run_config.proof_mode = true;

        let (runner, _, _) = cairo_run_program(&sierra_program.program, run_config).unwrap();

        let trace_file = std::fs::File::create(args.trace_file.unwrap()).unwrap();
        let memory_file = std::fs::File::create(args.memory_file.unwrap()).unwrap();

        let relocated_trace = runner.relocated_trace.unwrap();
        let mut trace_writer =
            FileWriter::new(io::BufWriter::with_capacity(3 * 1024 * 1024, trace_file));

        cairo_vm::cairo_run::write_encoded_trace(&relocated_trace, &mut trace_writer).unwrap();
        trace_writer.flush().unwrap();
        let mut memory_writer =
            FileWriter::new(io::BufWriter::with_capacity(5 * 1024 * 1024, memory_file));

        cairo_vm::cairo_run::write_encoded_memory(&runner.relocated_memory, &mut memory_writer)
            .unwrap();
        memory_writer.flush().unwrap();
    } else {
        let mut arr = vec![];
        for token in res {
            arr.push(Arg::Value(
                Felt::from_str(token.to_string().as_str()).expect(
                    format!("Could not convert \"{}\" to felt252.", token.to_string()).as_str(),
                ),
            ));
        }
        let cairo_args = vec![Arg::Array(arr)];
        let runner =
            SierraCasmRunner::new(sierra_program.program, None, Default::default(), None).unwrap();
        let result = runner
            .run_function_with_starknet_context(
                runner
                    .find_function("::main")
                    .expect("Could not find main function of cairo program."),
                &cairo_args,
                None,
                StarknetState::default(),
            )
            .unwrap();
        match result.value {
            cairo_lang_runner::RunResultValue::Success(_) => {
                println!("Success")
            }
            cairo_lang_runner::RunResultValue::Panic(res) => {
                let mut panic_msg = "".to_string();
                for x in res {
                    panic_msg.extend(String::from_utf8(x.to_bytes_be().to_vec()));
                }
                panic!("Cairo mm checker panicked: {}", panic_msg);
            }
        }
        println!(
            "cairo steps: {}",
            result.used_resources.basic_resources.n_steps
        );
    }
}
