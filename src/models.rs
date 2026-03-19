use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, serde::Deserialize, serde::Serialize)]
pub struct Config {}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PermissionState {
    pub granted: bool,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn permission_state_serializes_with_camel_case() {
        let state = PermissionState { granted: true };
        let json = serde_json::to_value(&state).unwrap();
        assert_eq!(json, serde_json::json!({"granted": true}));
    }

    #[test]
    fn permission_state_deserializes_from_camel_case() {
        let state: PermissionState = serde_json::from_value(serde_json::json!({"granted": true})).unwrap();
        assert!(state.granted);
    }

    #[test]
    fn permission_state_default_is_not_granted() {
        let state = PermissionState::default();
        assert!(!state.granted);
    }

    #[test]
    fn permission_state_roundtrip() {
        let original = PermissionState { granted: false };
        let json = serde_json::to_string(&original).unwrap();
        let deserialized: PermissionState = serde_json::from_str(&json).unwrap();
        assert_eq!(original.granted, deserialized.granted);
    }

    #[test]
    fn config_serializes_to_empty_object() {
        let config = Config {};
        let json = serde_json::to_value(&config).unwrap();
        assert_eq!(json, serde_json::json!({}));
    }

    #[test]
    fn config_deserializes_from_empty_object() {
        let _config: Config = serde_json::from_value(serde_json::json!({})).unwrap();
    }
}
