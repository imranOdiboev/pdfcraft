#![forbid(unsafe_code)]

use std::path::PathBuf;
use odibo_android_core::{Failure, Result};
use serde_json::Value;

fn execute() -> Result<Value> {
    let args = std::env::args_os().skip(1).collect::<Vec<_>>();
    let usage = Failure("invalid_arguments", "Expected inspect INPUT or rotate INPUT OUTPUT PAGE.");
    match args.as_slice() {
        [command, input] if command == "inspect" => odibo_android_core::inspect_path(&PathBuf::from(input.as_os_str())),
        [command, input, output, page] if command == "rotate" => {
            let page = page.to_str().ok_or(usage)?.parse::<usize>().map_err(|_| usage)?;
            odibo_android_core::rotate_path(&PathBuf::from(input.as_os_str()), &PathBuf::from(output.as_os_str()), page)
        }
        _ => Err(usage),
    }
}

fn main() {
    // Worker panics never disclose PDF content or app-private paths to logs.
    std::panic::set_hook(Box::new(|_| {}));
    let result = std::panic::catch_unwind(execute).unwrap_or(Err(Failure("worker_failed", "The PDF operation failed safely. The original document is unchanged.")));
    match result {
        Ok(value) => println!("{value}"),
        Err(error) => { println!("{}", error.json()); std::process::exit(1); }
    }
}
