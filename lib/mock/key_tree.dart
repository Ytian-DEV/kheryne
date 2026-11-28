import '../core/models/models.dart';

/// One couplet in the dichotomous key.
class KeyQuestion {
  const KeyQuestion({
    required this.id,
    required this.question,
    required this.hint,
    required this.yes,
    required this.no,
    required this.yesIllustration,
    required this.noIllustration,
    required this.yesLabel,
    required this.noLabel,
  });

  final String id;
  final String question;
  final String hint;

  /// Next question id, or `=Genus` for a result.
  final String yes;
  final String no;
  final Illustration yesIllustration;
  final Illustration noIllustration;
  final String yesLabel;
  final String noLabel;
}

/// Practical key to the target genera recorded in the Philippines.
const keyQuestions = <String, KeyQuestion>{
  'stylet': KeyQuestion(
    id: 'stylet',
    question: 'Is the stylet a stomatostylet (with knobs)?',
    hint: 'Look just behind the lips at 40×. A stomatostylet is short with three basal knobs; an odontostyle is a long, thin needle.',
    yes: 'bulb', no: 'flanges',
    yesIllustration: Illustration.styletKnobbed, noIllustration: Illustration.styletNeedle,
    yesLabel: 'Knobbed stylet', noLabel: 'Long needle (odontostyle)',
  ),
  'flanges': KeyQuestion(
    id: 'flanges',
    question: 'Does the stylet base have flanges, with the guide ring far from the lips?',
    hint: 'Follow the needle back to its base. Flanges look like small wings on the extension.',
    yes: '=Xiphinema', no: '=Longidorus',
    yesIllustration: Illustration.styletFlanged, noIllustration: Illustration.styletNeedle,
    yesLabel: 'Flanged base', noLabel: 'Plain base',
  ),
  'bulb': KeyQuestion(
    id: 'bulb',
    question: 'Does the median bulb fill most of the body width?',
    hint: 'The median bulb is the muscular swelling in the esophagus, about a third of the way to the intestine.',
    yes: '=Aphelenchoides', no: 'smallStylet',
    yesIllustration: Illustration.bulbLarge, noIllustration: Illustration.bulbOval,
    yesLabel: 'Large, rectangular bulb', noLabel: 'Small, oval bulb',
  ),
  'smallStylet': KeyQuestion(
    id: 'smallStylet',
    question: 'Is the stylet very small (under 12 µm) with a pointed tail?',
    hint: 'Compare the stylet with the lip region width. A delicate stylet barely longer than the head is "small".',
    yes: '=Ditylenchus', no: 'rings',
    yesIllustration: Illustration.styletSmall, noIllustration: Illustration.styletKnobbed,
    yesLabel: 'Small, delicate stylet', noLabel: 'Medium to long stylet',
  ),
  'rings': KeyQuestion(
    id: 'rings',
    question: 'Is the cuticle coarsely ringed along the whole body?',
    hint: 'Ring nematodes look like a stack of coins. Fine striations visible only at high magnification do not count.',
    yes: 'sheath', no: 'swollen',
    yesIllustration: Illustration.annulated, noIllustration: Illustration.straight,
    yesLabel: 'Coarse rings', noLabel: 'Fine or no rings',
  ),
  'sheath': KeyQuestion(
    id: 'sheath',
    question: 'Is there a second cuticle (sheath) around the body?',
    hint: 'A sheath shows as a thin outline around the rings, most visible at the head and tail.',
    yes: 'longStylet', no: 'retrorse',
    yesIllustration: Illustration.sheath, noIllustration: Illustration.annulated,
    yesLabel: 'Sheath present', noLabel: 'Single cuticle',
  ),
  'longStylet': KeyQuestion(
    id: 'longStylet',
    question: 'Is the sheath loose and the stylet longer than 70 µm?',
    hint: 'Measure the stylet if you have a calibration profile for this objective.',
    yes: '=Hemicycliophora', no: '=Hemicriconemoides',
    yesIllustration: Illustration.styletMassive, noIllustration: Illustration.styletKnobbed,
    yesLabel: 'Loose sheath, very long stylet', noLabel: 'Close-fitting sheath',
  ),
  'retrorse': KeyQuestion(
    id: 'retrorse',
    question: 'Do the ring edges point backwards (retrorse)?',
    hint: 'Look at the body outline. Retrorse rings have a saw-tooth edge that points towards the tail.',
    yes: 'ringFringe', no: '=Mesocriconema',
    yesIllustration: Illustration.annulatedRetrorse, noIllustration: Illustration.annulated,
    yesLabel: 'Saw-tooth edges', noLabel: 'Smooth, rounded rings',
  ),
  'ringFringe': KeyQuestion(
    id: 'ringFringe',
    question: 'Do the retrorse rings bear cuticular spines, scales, or fringes?',
    hint: 'Adult Criconema females have spiny, scaly, or fringed posterior ring margins, whereas Criconemoides rings have plain retrorse edges.',
    yes: '=Criconema', no: '=Criconemoides',
    yesIllustration: Illustration.annulatedRetrorse, noIllustration: Illustration.annulated,
    yesLabel: 'Spines, scales or fringes', noLabel: 'Plain retrorse edges',
  ),
  'swollen': KeyQuestion(
    id: 'swollen',
    question: 'Is the female swollen (not worm-shaped)?',
    hint: 'Swollen females are usually taken from roots, not from soil extracts.',
    yes: 'cyst', no: 'massive',
    yesIllustration: Illustration.swollenPear, noIllustration: Illustration.straight,
    yesLabel: 'Swollen female', noLabel: 'Worm-shaped',
  ),
  'cyst': KeyQuestion(
    id: 'cyst',
    question: 'Is the female round and hardening into a brown cyst?',
    hint: 'Cysts are tan to brown and keep their shape when dry.',
    yes: '=Globodera', no: 'pear',
    yesIllustration: Illustration.cystRound, noIllustration: Illustration.swollenPear,
    yesLabel: 'Round brown cyst', noLabel: 'Soft, white female',
  ),
  'pear': KeyQuestion(
    id: 'pear',
    question: 'Is the female pear-shaped with a perineal pattern?',
    hint: 'Root-knot females sit fully inside a gall; cut the gall open to find them.',
    yes: '=Meloidogyne', no: 'kidney',
    yesIllustration: Illustration.swollenPear, noIllustration: Illustration.kidney,
    yesLabel: 'Pear-shaped', noLabel: 'Other shape',
  ),
  'kidney': KeyQuestion(
    id: 'kidney',
    question: 'Is the whole female kidney-shaped?',
    hint: 'Reniform females curve along their whole length. Citrus nematode females swell only at the back.',
    yes: '=Rotylenchulus', no: '=Tylenchulus',
    yesIllustration: Illustration.kidney, noIllustration: Illustration.swollenPosterior,
    yesLabel: 'Kidney-shaped', noLabel: 'Swollen at the back only',
  ),
  'massive': KeyQuestion(
    id: 'massive',
    question: 'Is the stylet massive (over 40 µm) with tulip-shaped knobs?',
    hint: 'The knobs of a massive stylet look like small tulips pointing forward.',
    yes: '=Hoplolaimus', no: 'spiral',
    yesIllustration: Illustration.styletMassive, noIllustration: Illustration.styletKnobbed,
    yesLabel: 'Massive stylet', noLabel: 'Ordinary stylet',
  ),
  'spiral': KeyQuestion(
    id: 'spiral',
    question: 'Does the body relax into a spiral?',
    hint: 'Gently heat-killed specimens keep their resting posture.',
    yes: 'spiralTail', no: 'overlap',
    yesIllustration: Illustration.spiral, noIllustration: Illustration.straight,
    yesLabel: 'Spiral', noLabel: 'Straight or curved',
  ),
  'spiralTail': KeyQuestion(
    id: 'spiralTail',
    question: 'Is the tail asymmetric, with a small ventral projection?',
    hint: 'Look at the tail tip from the side.',
    yes: '=Helicotylenchus', no: '=Rotylenchus',
    yesIllustration: Illustration.tailConoid, noIllustration: Illustration.tailRounded,
    yesLabel: 'Asymmetric tail', noLabel: 'Evenly rounded tail',
  ),
  'overlap': KeyQuestion(
    id: 'overlap',
    question: 'Do the esophageal glands overlap the intestine?',
    hint: 'Find where the esophagus meets the intestine. Overlapping glands form a lobe that extends past the junction.',
    yes: 'vulva', no: '=Tylenchorhynchus',
    yesIllustration: Illustration.glandsOverlap, noIllustration: Illustration.glandsAbutting,
    yesLabel: 'Overlapping lobe', noLabel: 'Glands end at the junction',
  ),
  'vulva': KeyQuestion(
    id: 'vulva',
    question: 'Is the vulva posterior (over 70% of body length)?',
    hint: 'Measure from the head. The Measure tool computes V% for you.',
    yes: '=Pratylenchus', no: 'long',
    yesIllustration: Illustration.vulvaPosterior, noIllustration: Illustration.vulvaMid,
    yesLabel: 'Posterior vulva', noLabel: 'Near mid-body',
  ),
  'long': KeyQuestion(
    id: 'long',
    question: 'Is the body over 1 mm with a pointed, mucronate tail?',
    hint: 'Hirschmanniella is usually found in flooded rice roots.',
    yes: '=Hirschmanniella', no: '=Radopholus',
    yesIllustration: Illustration.tailMucro, noIllustration: Illustration.tailConoid,
    yesLabel: 'Long body, mucro', noLabel: 'Shorter, tapering tail',
  ),
};

const keyStart = 'stylet';

/// Answers that lead from the start to [genus], used to pre-fill the key
/// from a report.
List<(String questionId, bool yes)> pathTo(String genus) {
  List<(String, bool)>? walk(String id, List<(String, bool)> acc) {
    final q = keyQuestions[id]!;
    for (final (next, ans) in [(q.yes, true), (q.no, false)]) {
      final path = [...acc, (id, ans)];
      if (next == '=$genus') return path;
      if (!next.startsWith('=')) {
        final found = walk(next, path);
        if (found != null) return found;
      }
    }
    return null;
  }

  return walk(keyStart, const []) ?? const [];
}
