#![forbid(unsafe_code)]

use std::path::PathBuf;
use odibo_android_core::{Failure, Result};
use serde_json::Value;

fn execute() -> Result<Value> {
    let args = std::env::args_os().skip(1).collect::<Vec<_>>();
    execute_args(&args)
}

fn execute_args(args: &[std::ffi::OsString]) -> Result<Value> {
    let usage = Failure("invalid_arguments", "Expected inspect, rotate, combine, split or reorder with valid inputs and a new destination.");
    match args {
        [command, input] if command == "inspect" => odibo_android_core::inspect_path(&PathBuf::from(input.as_os_str())),
        [command, input, output, page] if command == "rotate" => {
            let page = page.to_str().ok_or(usage)?.parse::<usize>().map_err(|_| usage)?;
            odibo_android_core::rotate_path(&PathBuf::from(input.as_os_str()), &PathBuf::from(output.as_os_str()), page)
        }
        [command, output, inputs @ ..] if command == "combine" => {
            let inputs = inputs.iter().map(|path| PathBuf::from(path.as_os_str())).collect::<Vec<_>>();
            odibo_android_core::combine_path(&PathBuf::from(output.as_os_str()), &inputs)
        }
        [command, input, output, indices] if command == "split" || command == "reorder" => {
            let indices = odibo_android_core::parse_indices(indices.to_str().ok_or(usage)?)?;
            let input = PathBuf::from(input.as_os_str());
            let output = PathBuf::from(output.as_os_str());
            if command == "split" { odibo_android_core::split_path(&input, &output, &indices) }
            else { odibo_android_core::reorder_path(&input, &output, &indices) }
        }
        _ => Err(usage),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn invalid_command_shapes_are_refused_before_opening_files() {
        for args in [vec![], vec!["unknown"], vec!["combine", "output"], vec!["combine", "output", "one-input"],
            vec!["rotate", "in", "out", "-1"], vec!["split", "in", "out", "1,,2"], vec!["reorder", "in", "out", ""]] {
            let args = args.iter().map(|arg| std::ffi::OsString::from(*arg)).collect::<Vec<_>>();
            assert_eq!(execute_args(&args).unwrap_err().0, "invalid_arguments");
        }
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
