# models/

Binary model files live here. All are git-ignored (see `.gitignore`).

## WhisperIME (Android voice IME — see D25)

`codefone-setup.sh` pushes the following to `/sdcard/Android/data/org.woheller69.whisper/files/` on each provisioned Pixel:

| File | Size | Source |
| --- | --- | --- |
| `whisper-tiny.en.tflite` | 41 MB | Bundled with `org.woheller69.whisper` APK (extracted once on first app launch to the app's external files dir). Copy from any instance that has run the app, e.g. `adb pull /sdcard/Android/data/org.woheller69.whisper/files/whisper-tiny.en.tflite`. |
| `filters_vocab_en.bin` | 573 KB | Same source. |

Optional larger multilingual models (drop-in replacements, select via the WhisperIME settings UI):

| File | Size |
| --- | --- |
| `whisper-base.TOP_WORLD.tflite` | 107 MB |
| `whisper-small.TOP_WORLD.tflite` | 307 MB |

If these files are missing when `codefone-setup.sh` runs, it will warn but continue. Voice input will not work until they are present. To populate them without a reference device, install the WhisperIME APK on any Android device, launch the app once (it downloads the model into its external files dir), then `adb pull` the files into this folder.
