use serde::{ser::Serializer, Serialize};

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, thiserror::Error)]
pub enum Error {
  #[error(transparent)]
  Io(#[from] std::io::Error),
  #[cfg(mobile)]
  #[error(transparent)]
  PluginInvoke(#[from] tauri::plugin::mobile::PluginInvokeError),
}

impl Serialize for Error {
  fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
  where
    S: Serializer,
  {
    serializer.serialize_str(self.to_string().as_ref())
  }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn io_error_serializes_as_string() {
        let error = Error::Io(std::io::Error::new(std::io::ErrorKind::NotFound, "file not found"));
        let json = serde_json::to_string(&error).unwrap();
        assert_eq!(json, "\"file not found\"");
    }

    #[test]
    fn io_error_display() {
        let error = Error::Io(std::io::Error::new(std::io::ErrorKind::Other, "test error"));
        assert_eq!(error.to_string(), "test error");
    }

    #[test]
    fn io_error_from_conversion() {
        let io_err = std::io::Error::new(std::io::ErrorKind::PermissionDenied, "access denied");
        let error: Error = io_err.into();
        assert_eq!(error.to_string(), "access denied");
    }
}
