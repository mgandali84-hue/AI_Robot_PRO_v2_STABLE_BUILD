
class MouthShape {
  final String animationName;
  const MouthShape(this.animationName);
}

/// Text-to-mouth phoneme heuristic.
///
/// This does not claim to be a full acoustic phoneme recognizer.
/// It uses the word/text delivered by the TTS progress callback and
/// maps vowel/consonant patterns to GLB mouth animations.
class PhonemeAnalyzer {
  static MouthShape fromWord(String word, {required String language}) {
    final w = word.trim().toLowerCase();
    if (w.isEmpty) return const MouthShape('Mouth_Closed');

    if (language == 'ar') {
      if (RegExp(r'[اىآأإًَٰ]').hasMatch(w)) {
        return const MouthShape('Mouth_A');
      }
      if (RegExp(r'[يٍِ]').hasMatch(w)) {
        return const MouthShape('Mouth_E');
      }
      if (RegExp(r'[وٌُؤ]').hasMatch(w)) {
        return const MouthShape('Mouth_O');
      }
      // Arabic consonant-heavy words: small opening.
      return const MouthShape('Mouth_Closed');
    }

    if (RegExp(r'[aáàâäæ]').hasMatch(w)) {
      return const MouthShape('Mouth_A');
    }
    if (RegExp(r'[eéèêëiíìîï]').hasMatch(w)) {
      return const MouthShape('Mouth_E');
    }
    if (RegExp(r'[oóòôöuúùûü]').hasMatch(w)) {
      return const MouthShape('Mouth_O');
    }
    return const MouthShape('Mouth_Closed');
  }

  static List<String> sequenceForText(String text, {required String language}) {
    final chars = text.runes.map(String.fromCharCode).toList();
    final result = <String>[];
    for (final c in chars) {
      if (RegExp(r'[\s,.،؛!?؟]').hasMatch(c)) {
        result.add('Mouth_Closed');
        continue;
      }
      result.add(fromWord(c, language: language).animationName);
    }
    if (result.isEmpty) result.add('Mouth_Closed');
    return result;
  }
}
