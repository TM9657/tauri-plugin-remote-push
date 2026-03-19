use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, serde::Deserialize, serde::Serialize)]
pub struct Config {}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PermissionState {
    pub granted: bool,
}
