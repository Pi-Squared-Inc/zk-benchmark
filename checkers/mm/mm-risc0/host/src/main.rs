// These constants represent the RISC-V ELF and the image ID generated by risc0-build.
// The ELF is used for proving and the ID is used for verification.
use methods::{METHOD_ELF, METHOD_ID};
use mmlib_host::{LoadGuestTimer, PreprocessingTimer, ProveTimer, SetupTimer, Timer, TotalTimer, VerifyTimer};
use mmlib_host::{compute_hints, prepare_mm_file, Label, MainTheoremArgs, SplitIdentTable, SplitTokensArgs, ToAxiomArgs, TokenCode};
use risc0_zkvm::sha::{Digest, Digestible};
use risc0_zkvm::{ExitCode, ProverOpts};
use risc0_zkvm::{ExecutorImpl, ExecutorEnv, VerifierContext, get_prover_server};

use clap::Parser;

use std::fs;
use std::time::Instant;

#[derive(Parser)]
#[command(about = "Generate a RiscZero ZK certificate for checking a MetaMath proof")]
#[command(version, arg_required_else_help = true, long_about = None)]
struct Args {
    /// Path to the MetaMath file containing the proof to be verified
    file: String,

    #[command(flatten)]
    main_theorem_args: MainTheoremArgs,

    #[command(flatten)]
    to_axiom_args: ToAxiomArgs,

    #[command(flatten)]
    split_tokens_args: SplitTokensArgs,
}

/// This function runs the proof creation and checking pipeline for a given metamath file.
fn create_and_check_proof(filename: String, target_theorem: MainTheoremArgs, provable_to_axiom: ToAxiomArgs, split_tokens: SplitTokensArgs) {
    // An executor environment describes the configurations for the zkVM
    // including program inputs.
    // A default ExecutorEnv can be created like so:
    // `let env = ExecutorEnv::builder().build().unwrap();`
    // However, this `env` does not have any inputs.
    //
    // To add guest input to the executor environment, use
    // ExecutorEnvBuilder::write().
    // To access this method, you'll need to use ExecutorEnv::builder(), which
    // creates an ExecutorEnvBuilder. When you're done adding input, call
    // ExecutorEnvBuilder::build().
    let preprocessing_timer = PreprocessingTimer::start();
    let (ident_table, axiom_file_tokens) = prepare_mm_file(&filename);
    let tokens = provable_to_axiom.process(&ident_table, axiom_file_tokens);

    let (max_subst_size, last_prop) = compute_hints(&tokens);
    let target_theorem: Option<TokenCode> = target_theorem.process_split(&ident_table, last_prop);

    let splitted_tokens = split_tokens.process_split(&ident_table, tokens);

    let mut tokens_refs: Vec<&'static [TokenCode]> = vec![];
    let mut tokens_lens = vec![];
    let batches: usize = splitted_tokens.len();
    for tok in splitted_tokens {
        tokens_lens.push(tok.len());
        tokens_refs.push(tok.leak());
    }
    println!("{}", preprocessing_timer.stop());
    if let Some(session_file_name) = &split_tokens.restore_session {
        assert_eq!(batches, 2);
        let tokens_len = tokens_lens[1];
        let tokens_ref = tokens_refs[1];
        check_restored_session(session_file_name, target_theorem, tokens_len, tokens_ref, &ident_table);
    } else {
        check_proof(max_subst_size.try_into().unwrap(), target_theorem, batches, tokens_lens, tokens_refs, split_tokens, ident_table);
    }
}

fn check_restored_session(session_file_name: &String, target_theorem: Option<TokenCode>, tokens_len: usize, tokens_ref: &[u16], ident_table: &SplitIdentTable) {
    println!("Restoring session from {}", session_file_name);
    let serialized_image_id = fs::read(session_file_name.to_owned() + ".id").unwrap();
    let image_id = Digest::from_bytes(serialized_image_id.try_into().unwrap());
    let serialized_image = fs::read(session_file_name).unwrap();
    let image = bincode::deserialize(serialized_image.as_slice()).unwrap();
    let env = ExecutorEnv::builder()
        .write(&tokens_len).unwrap()
        .write_slice(&tokens_ref)
        .build().unwrap();
    let mut exec = ExecutorImpl::new(env, image).unwrap();
    let now = Instant::now();
    let session = exec.run().unwrap();
    println!("Resumed session execution duration: {:.2?}", now.elapsed());
    let now = Instant::now();
    let prover = get_prover_server(&ProverOpts::default()).unwrap();
    let prove_info = prover.prove_session(&VerifierContext::default(), &session).unwrap();
    println!("Resumed session proving duration: {:.2?}", now.elapsed());
    let receipt = prove_info.receipt;

    // Extract the session stats
    let stats = prove_info.stats;
    println!("Resumed session was processed successfully");
    println!("Resumed session guest cycles: {}", stats.user_cycles);
    println!("Resumed session total cycles: {}", stats.total_cycles);

    MainTheoremArgs::display_target_stmt_split(target_theorem, receipt.journal.decode().map_err(|e| e.into()), ident_table);

    // The receipt was verified at the end of proving, but the below code is an
    // example of how someone else could verify this receipt.
    receipt.verify(image_id).unwrap();
}

fn check_proof(max_subst_size: usize, target_theorem: Option<Label>, batches: usize, tokens_lens: Vec<usize>, tokens_refs: Vec<&[TokenCode]>, split_tokens: SplitTokensArgs, ident_table: SplitIdentTable) {
    println!("Creating environment");

    // An executor environment describes the configurations for the zkVM
    // including program inputs.
    // An default ExecutorEnv can be created like so:
    // `let env = ExecutorEnv::builder().build().unwrap();`
    // However, this `env` does not have any inputs.
    //
    // To add guest input to the executor environment, we use
    // ExecutorEnvBuilder::write().
    // We call this twice, once for the target theorem and once for the axiom file.
    let setup_timer = SetupTimer::start();
    let mut env = ExecutorEnv::builder();
    env.write(&max_subst_size).unwrap();
    env.write(&target_theorem).unwrap();
    env.write(&batches).unwrap();
    for i in 0..batches {
        env.write(&tokens_lens[i]).unwrap();
        env.write_slice(&tokens_refs[i]);
    }
    let env = env.build().unwrap();

    // Obtain the default prover.
    let prover = get_prover_server(&ProverOpts::default()).unwrap();
    println!("{}", setup_timer.stop());

    println!("Proving file");

    // Proof information by proving the specified ELF binary.
    // This struct contains the receipt along with statistics about execution of the guest
    let load_guest_timer = LoadGuestTimer::start();
    let mut image_id = METHOD_ID;
    let mut exec = ExecutorImpl::from_elf(env, METHOD_ELF).unwrap();
    println!("{}", load_guest_timer.stop());
    let prove_timer = ProveTimer::start();
    let now = Instant::now();
    let mut session = exec.run().unwrap();
    let memory_image = &session.post_image;
    let mut post_image_id = memory_image.compute_id();
    println!("Batch 0 execution duration: {:.2?}", now.elapsed());
    let now = Instant::now();
    let mut prove_info = prover.prove_session(&VerifierContext::default(), &session).unwrap();
    println!("Batch 0 proving duration: {:.2?}", now.elapsed());
    for batch in 1..batches {
        if let Some(session_file_name) = &split_tokens.save_session {
            let post_image_id = session.post_image.compute_id();
            let serialized_post_image = bincode::serialize(&session.post_image).unwrap();
            fs::write(session_file_name, serialized_post_image.as_slice()).unwrap();
            fs::write(session_file_name.to_owned() + ".id", post_image_id.as_bytes()).unwrap();
        }
        // Extract the receipt.
        let receipt = prove_info.receipt;
        receipt.verify_integrity_with_context(&VerifierContext::default()).unwrap();
        let receipt_claim = receipt.claim().unwrap();
        let claim_value = receipt_claim.as_value().unwrap();
        // Verify that the execution was paused
        assert_eq!(session.exit_code, ExitCode::Paused(0));
        // Verify that the pre-state is correct
        assert_eq!(claim_value.pre.digest(), image_id.into());

        image_id = post_image_id.into();

        // Extract the session stats
        let stats = prove_info.stats;
        println!("Batch {} was processed successfully", batch - 1);
        println!("Batch {} guest cycles: {}", batch - 1, stats.user_cycles);
        println!("Batch {} total cycles: {}", batch - 1, stats.total_cycles);

        let now = Instant::now();
        session = exec.run().unwrap();
        post_image_id = session.post_image.compute_id();
        println!("Batch {} execution duration: {:.2?}", batch, now.elapsed());
        let now = Instant::now();
        prove_info = prover.prove_session(&VerifierContext::default(), &session).unwrap();
        println!("Batch {} proving duration: {:.2?}", batch, now.elapsed());
    }
    println!("{}", prove_timer.stop());

    println!("Proof complete");

    // Extract the receipt.
    let receipt = prove_info.receipt;

    // Extract the session stats
    let stats = prove_info.stats;
    println!("Batch {} was processed successfully", batches - 1);
    println!("Batch {} guest cycles: {}", batches - 1, stats.user_cycles);
    println!("Batch {} total cycles: {}", batches - 1, stats.total_cycles);

    MainTheoremArgs::display_target_stmt_split(target_theorem, receipt.journal.decode().map_err(|e| e.into()), &ident_table);

    println!("guest cycles: {}", stats.user_cycles);

    // The receipt was verified at the end of proving, but the below code is an
    // example of how someone else could verify this receipt.
    let verify_timer = VerifyTimer::start();
    receipt.verify(image_id).unwrap();
    println!("{}", verify_timer.stop());
}

fn main() {
    let args = Args::parse();

    let total_timer = TotalTimer::start();
    create_and_check_proof(args.file, args.main_theorem_args, args.to_axiom_args, args.split_tokens_args);
    println!("{}", total_timer.stop());
}

#[cfg(test)]
mod tests {
    use super::*;
    const MM_PATH: &str = "../../common/metamath-files";

    // The following tests are for the simple metamath files in the theory folder:
    // disjointness-alt-lemma.mm
    // impreflex-compressed-goal.mm
    // impreflex-compressed.mm
    // impreflex.mm
    // perceptron-goal.mm
    // perceptron.mm
    // simple-broken.mm
    // simple-compressed.mm
    // simple.mm
    // svm5-goal.mm
    // svm5.mm
    // transfer-batch-1k-goal.mm
    // transfer-goal.mm
    // transfer-largest-slice.mm
    // transfer-simple-compressed-goal.mm
    // transfer-simple-goal.mm
    // transfer-task-specific.mm
    // transfer.mm
    // transfer5000.mm

    // TODO: Note that many of these files also exist in the generation folder
    // We should consider deduplicating, or directly testing the generation files

    fn test_driver(filename: &str) {
        create_and_check_proof(format!("{}/{}", MM_PATH, filename), MainTheoremArgs::default(), ToAxiomArgs::default(), SplitTokensArgs::default());
    }


    #[test]
    fn test_disjointness_alt_lemma_works() {
        create_and_check_proof(format!("{}/theory/disjointness-alt-lemma.mm", MM_PATH), MainTheoremArgs::from_main_theorem("disjointness-alt-lemma"), ToAxiomArgs::default(), SplitTokensArgs::default());
    }

    #[test]
    fn test_impreflex_infer_main_theorem() {
        create_and_check_proof(format!("{}/theory/impreflex-compressed-goal.mm", MM_PATH), MainTheoremArgs::infer_main_theorem(), ToAxiomArgs::default(), SplitTokensArgs::default());
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

    // TODO this file is very long so I am commenting it out for now
    // #[test]
    // fn test_nf_works() {
    //     test_stub("metamath-test/nf.mm");
    // }

    // TODO this file does not seem to have a main theorem so I am commenting it out for now
    // #[test]
    // fn test_peano_fixed_works() {
    //     test_stub("metamath-test/peano-fixed.mm");
    // }

    // TODO this file is very long so I am commenting it out for now
    // #[test]
    // fn test_ql_works() {
    //     test_stub("metamath-test/ql.mm");
    // }

    // TODO this file is very long so I am commenting it out for now
    // #[test]
    // fn test_set_2010_08_29_works() {
    //     test_stub("metamath-test/set.2010-08-29.mm");
    // }

    // TODO this file is very long so I am commenting it out for now
    // #[test]
    // fn test_set_works() {
    //     test_stub("metamath-test/set.mm");
    // }

    // This file is very long so I am commenting it out for now
    // #[test]
    // #[should_panic]
    // fn test_set_dist_bad1_panics() {
    //     test_stub("metamath-test/set-dist-bad1.mm");
    // }



}