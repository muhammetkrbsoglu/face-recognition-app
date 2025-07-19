<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

This project is a Flutter-based face recognition door unlock system using ArcFace and TFLite. All UI and messages must be in Turkish. Use MVVM or clean modular structure. Required packages: camera, tflite_flutter, local_auth, sqflite, path_provider. No Firebase or online APIs. All face data and embeddings are stored locally. Show feedback (Snackbar, Toast, Animation) after every user action. Handle all errors with Turkish messages and log to console during development.

### Architecture
- **Core Services**: Found in `lib/core/services/`, these include essential utilities like `secure_storage.dart` and `error_handler.dart`.
- **Face Recognition**: Implemented in `lib/services/` and `lib/models/`. Key services include `face_recognition_service.dart` and `face_embedding_service.dart`.
- **UI Features**: Located in `lib/features/` and `lib/views/`, following MVVM principles.
- **Data Storage**: Uses `sqflite` for local database management, with models defined in `lib/models/`.

### Developer Workflows