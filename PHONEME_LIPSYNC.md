# AI Robot PRO v2 - Phoneme/Lip Sync

1. TTS speaks the answer.
2. `flutter_tts` progress callback provides the current word.
3. `PhonemeAnalyzer` classifies vowel patterns into A/E/O/closed shapes.
4. `ModelViewer.animationName` switches the GLB to the matching mouth animation.
5. The GLB morph targets deform the mouth mesh.

For true audio phoneme recognition, replace `PhonemeAnalyzer` with a native/on-device
phoneme model or a cloud speech/phoneme service. Do not put secret API keys in the APK.
