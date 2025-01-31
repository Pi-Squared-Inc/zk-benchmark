//! An end-to-end example of using the SP1 SDK to generate a proof of a program that can be executed
//! or have a core proof generated.
//!
//! You can run this script using the following command:
//! ```shell
//! RUST_LOG=info cargo run --release -- --execute
//! ```
//! or
//! ```shell
//! RUST_LOG=info cargo run --release -- --prove
//! ```

use sp1_sdk::{ProverClient, EnvProver, SP1Stdin, include_elf};

use mmlib_host::{LoadGuestTimer, PreprocessingTimer, ProveTimer, SetupTimer, Timer, TotalTimer, VerifyTimer};
use mmlib_host::{compute_hints, prepare_mm_file, MainTheoremArgs};

use clap::Parser;

/// The ELF (executable and linkable format) file for the Succinct RISC-V zkVM.
pub const GUEST_ELF: &[u8] = include_elf!("mm-sp1-guest");

/// The arguments for the command.
#[derive(Parser)]
#[command(about = "Generate a SP1 ZK certificate for checking a MetaMath proof")]
#[command(version, arg_required_else_help = true, long_about = None)]
struct Args {
    /// Path to the MetaMath file containing the proof to be verified
    file: String,

    #[command(flatten)]
    main_theorem_args: MainTheoremArgs,

    /// Whether to only run the program (skipping proving)
    #[arg(long)]
    execute: bool,
}


fn main() {
    // Parse the command line arguments.
    let args = Args::parse();

    let file = &args.file;
    let main_theorem = args.main_theorem_args;
    let execute = args.execute;

    let total_timer = TotalTimer::start();
    execute_or_prove(file, main_theorem, execute);
    println!("{}", total_timer.stop());
}

fn execute_or_prove(file: &str, main_theorem: MainTheoremArgs, execute: bool) {
    let preprocessing_timer = PreprocessingTimer::start();
    let (ident_table, tokens, max_subst_size, target_theorem) = preprocess_file(file, main_theorem);
    println!("{}", preprocessing_timer.stop());

    let setup_timer = SetupTimer::start();
    let (client, stdin) = setup(max_subst_size, target_theorem, tokens);
    println!("{}", setup_timer.stop());

    if execute {
        execute_pgm(&client, stdin, target_theorem, ident_table);
    } else {
        prove_pgm(client, stdin);
    }
}

fn preprocess_file(file: &str, main_theorem: MainTheoremArgs) -> (mmlib_host::SplitIdentTable, Vec<u16>, u32, Option<u16>) {
    let (ident_table, tokens) = prepare_mm_file(file);
    let (max_subst_size, last_prop) = compute_hints(&tokens);
    let target_theorem = main_theorem.process(&ident_table, last_prop);
    (ident_table, tokens, max_subst_size, target_theorem)
}

fn setup(max_subst_size: u32, target_theorem: Option<u16>, tokens: Vec<u16>) -> (EnvProver, SP1Stdin) {
    // Setup the logger.
    sp1_sdk::utils::setup_logger();

    // Setup the prover client.
    let client = ProverClient::from_env();

    // Setup the inputs.
    let mut stdin = SP1Stdin::new();

    stdin.write(&max_subst_size);
    stdin.write(&target_theorem);
    stdin.write(&tokens);
    (client, stdin)
}

fn prove_pgm(client: EnvProver, stdin: SP1Stdin) {
    println!("Setup the program for proving.");
    let load_guest_timer = LoadGuestTimer::start();
    let (pk, vk) = client.setup(GUEST_ELF);
    println!("{}", load_guest_timer.stop());

    println!("Generate the proof");
    let prove_timer = ProveTimer::start();
    let proof = client
        .prove(&pk, &stdin)
        .run()
        .expect("failed to generate proof");
    println!("Successfully generated proof!");
    println!("{}", prove_timer.stop());

    // Verify the proof.
    let verify_timer = VerifyTimer::start();
    client.verify(&proof, &vk).expect("failed to verify proof");
    println!("Successfully verified proof!");
    println!("{}", verify_timer.stop());
}

fn execute_pgm(client: &EnvProver, stdin: SP1Stdin, target_theorem: Option<u16>, ident_table: mmlib_host::SplitIdentTable) {
    println!("Executing the program");
    let (mut output, report) = client.execute(GUEST_ELF, &stdin).run().unwrap();
    println!("Program executed successfully.");

    // Read the output.
    if target_theorem.is_some() {
        let decoded = output.read::<Vec<u16>>();
        MainTheoremArgs::display_target_stmt(target_theorem, Ok(decoded), &ident_table);
    }

    // Record the number of cycles executed.
    println!("Number of cycles: {}", report.total_instruction_count());
}

#[cfg(test)]
mod test {
    use super::*;
    const MM_PATH: &str = "../../common/metamath-files";

    fn test_execute(file: &str) {
        execute_or_prove(file, MainTheoremArgs::default(), true);
    }

    fn test_driver(file: &str) {
        test_execute(format!("{}/{}", MM_PATH, file).as_str());
    }

    fn test_prove(file: &str) {
        execute_or_prove(file, MainTheoremArgs::default(), false);
    }

    #[test]
    fn test_disjointness_alt_lemma_works() {
        test_driver("theory/disjointness-alt-lemma.mm");
    }

    #[test]
    fn test_prove_impreflex_infer_main_theorem() {
        execute_or_prove(format!("{}/theory/impreflex-compressed-goal.mm", MM_PATH).as_str(), MainTheoremArgs::infer_main_theorem(), true);
    }

    #[test]
    fn test_impreflex_compressed_goal_works() {
        test_driver("theory/impreflex-compressed-goal.mm");
    }

    #[test]
    fn test_impreflex_compressed_works() {
        test_driver("theory/impreflex-compressed.mm");
    }

    #[test]
    fn test_impreflex_works() {
        test_driver("theory/impreflex.mm");
    }

    #[test]
    fn test_perceptron_goal_works() {
        test_driver("theory/perceptron-goal.mm");
    }

    #[test]
    fn test_perceptron_works() {
        test_driver("theory/perceptron.mm");
    }

    #[test]
    #[should_panic]
    fn test_simple_broken_panics() {
        test_driver("theory/simple-broken.mm");
    }

    #[test]
    fn test_simple_compressed_works() {
        test_driver("theory/simple-compressed.mm");
    }

    #[test]
    fn test_simple_works() {
        test_driver("theory/simple.mm");
    }

    #[test]
    fn test_svm5_works() {
        test_driver("theory/svm5.mm");
    }

    #[test]
    fn test_transfer_batch_1k_goal_works() {
        test_driver("theory/transfer-batch-1k-goal.mm");
    }

    #[test]
    fn test_transfer_goal_works() {
        test_driver("theory/transfer-goal.mm");
    }

    #[test]
    fn test_transfer_largest_slice_works() {
        test_driver("theory/transfer-largest-slice.mm");
    }

    #[test]
    fn test_transfer_simple_compressed_goal_works() {
        test_driver("theory/transfer-simple-compressed-goal.mm");
    }

    #[test]
    fn test_transfer_simple_goal_works() {
        test_driver("theory/transfer-simple-goal.mm");
    }

    #[test]
    fn test_transfer_task_specific_works() {
        test_driver("theory/transfer-task-specific.mm");
    }

    // TODO This file is very long so I am commenting it out for now
    // #[test]
    // fn test_transfer_works() {
    //     test_stub("theory/transfer.mm");
    // }


    #[test]
    fn test_transfer5000_works() {
        test_driver("theory/transfer5000.mm");
    }



    // The following tests come from David A Wheeler's metamath-test suite
    // Which can be found at https://github.com/david-a-wheeler/metamath-test
    // It includes a variety of positive and negative tests for metamath files.
    // We specifically run the tests found in the run-testsuite script:

    // pass anatomy.mm "Simple 'anatomy' test"
    // fail anatomy-bad1.mm "Simple incorrect 'anatomy' test "
    // fail anatomy-bad2.mm "Simple incorrect 'anatomy' test "
    // fail anatomy-bad3.mm "Simple incorrect 'anatomy' test "
    // pass big-unifier.mm
    // fail big-unifier-bad1.mm
    // fail big-unifier-bad2.mm
    // fail big-unifier-bad3.mm
    // pass demo0.mm
    // fail demo0-bad1.mm
    // pass demo0-includer.mm "Test simple file inclusion"  (Note: we do not run this test, as we do not support file inclusion)
    // pass emptyline.mm 'A file with one empty line' (Note: we do not run this test, as we do not support files that do not prove things)
    // pass hol.mm
    // pass iset.mm
    // pass miu.mm
    // pass nf.mm
    // pass peano-fixed.mm
    // pass ql.mm
    // pass set.2010-08-29.mm
    // pass set.mm
    // fail set-dist-bad1.mm

    #[test]
    fn test_anatomy_works() {
        test_driver("metamath-test/anatomy.mm");
    }

    #[test]
    fn test_anatomy_bin_works() {
        test_driver("metamath-test/anatomy.mm.bin");
    }


    #[test]
    #[should_panic]
    fn test_anatomy_bad1_panics() {
        test_driver("metamath-test/anatomy-bad1.mm");
    }

    #[test]
    #[should_panic]
    fn test_anatomy_bad2_panics() {
        test_driver("metamath-test/anatomy-bad2.mm");
    }

    #[test]
    #[should_panic]
    fn test_anatomy_bad3_panics() {
        test_driver("metamath-test/anatomy-bad3.mm");
    }

    #[test]
    fn test_big_unifier_works() {
        test_driver("metamath-test/big-unifier.mm");
    }

    #[test]
    #[should_panic]
    fn test_big_unifier_bad1_panics() {
        test_driver("metamath-test/big-unifier-bad1.mm");
    }

    #[test]
    #[should_panic]
    fn test_big_unifier_bad2_panics() {
        test_driver("metamath-test/big-unifier-bad2.mm");
    }

    #[test]
    #[should_panic]
    fn test_big_unifier_bad3_panics() {
        test_driver("metamath-test/big-unifier-bad3.mm");
    }

    #[test]
    fn test_demo0_works() {
        test_driver("metamath-test/demo0.mm");
    }

    #[test]
    #[should_panic]
    fn test_demo0_bad1_panics() {
        test_driver("metamath-test/demo0-bad1.mm");
    }

    // We do not support file inclusion, so this test is not run
    // #[test]
    // fn test_demo0_includer_works() {
    //     test_stub("metamath-test/demo0-includer.mm");
    // }

    // We do not support files that do not prove things, so this test is not run
    // #[test]
    // fn test_emptyline_works() {
    //     test_stub("metamath-test/emptyline.mm");
    // }

    // TODO this file is very long so I am commenting it out for now
    // #[test]
    // fn test_hol_works() {
    //     test_stub("metamath-test/hol.mm");
    // }

    // TODO this file is very long so I am commenting it out for now
    // #[test]
    // fn test_iset_works() {
    //     test_stub("metamath-test/iset.mm");
    // }

    #[test]
    fn test_miu_works() {
        test_driver("metamath-test/miu.mm");
    }

}
