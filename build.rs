const COMMANDS: &[&str] = &["get_token", "request_permission"];

fn main() {
  tauri_plugin::Builder::new(COMMANDS)
    .android_path("android")
    .ios_path("ios")
    .build();
}
