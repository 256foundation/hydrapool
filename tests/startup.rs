use std::{path::Path, process::Command};

#[test]
fn missing_config_is_reported_to_stderr() {
    let config = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("Cargo.toml")
        .join("missing.toml");
    let output = Command::new(env!("CARGO_BIN_EXE_hydrapool"))
        .arg("--config")
        .arg(&config)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(1));
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("Failed to load config"), "{stderr}");
    assert!(stderr.contains("missing.toml"), "{stderr}");
}
