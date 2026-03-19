Place the converted WhisperKit/Core ML model folder here with the exact name:

`whisper-turbo-quran`

Expected bundle path:

`Tilavet App/Resources/Models/whisper-turbo-quran`

Notes:
- Keep the model as a folder reference so WhisperKit can read the full artifact tree.
- The app already falls back to simulated recitation when the bundled model is missing.
- If you keep the model outside the repo, use `Scripts/stage_quran_model.sh /absolute/path/to/whisper-turbo-quran`.
