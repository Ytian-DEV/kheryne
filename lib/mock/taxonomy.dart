import '../core/models/models.dart';

/// Reference taxonomy, NeMys 2026 accepted names.
const nemysTaxonomy = <TaxonOrder>[
  TaxonOrder('Rhabditida', [
    TaxonFamily('Meloidogynidae', 'Rhabditida', ['Meloidogyne', 'Meloidoderella']),
    TaxonFamily('Heteroderidae', 'Rhabditida', [
      'Heterodera', 'Globodera', 'Cactodera', 'Punctodera', 'Betulodera', 'Dolichodera',
      'Paradolichodera', 'Verutus', 'Atalodera', 'Bellodera', 'Camelodera', 'Cryphodera',
      'Ekphymatodera', 'Hylonema', 'Rhizonemella', 'Zealandodera',
    ]),
    TaxonFamily('Pratylenchidae', 'Rhabditida', [
      'Pratylenchus', 'Zygotylenchus', 'Radopholus', 'Achlysiella', 'Apratylenchoides',
      'Hoplotylus', 'Radopholoides', 'Zygradus', 'Hirschmanniella', 'Nacobbus', 'Bursadera',
      'Meloinema', 'Apratylenchus',
    ]),
    TaxonFamily('Hoplolaimidae', 'Rhabditida', [
      'Helicotylenchus', 'Hoplolaimus', 'Rotylenchus', 'Scutellonema', 'Aorolaimus',
      'Peltamigratus', 'Afritylenchus', 'Antarctylus', 'Aphasmatylenchus', 'Orientylus',
      'Rotylenchoides', 'Varotylus',
    ]),
    TaxonFamily('Rotylenchulidae', 'Rhabditida', ['Rotylenchulus', 'Acontylus', 'Bilobodera', 'Senegalonema']),
    TaxonFamily('Dolichodoridae', 'Rhabditida', [
      'Belonolaimus', 'Carphodorus', 'Ibipora', 'Morulaimus', 'Dolichodorus', 'Neodolichodorus',
      'Tylenchorhynchus', 'Telotylenchus', 'Trophurus', 'Paratrophurus', 'Quinisulcius',
      'Sauertylenchus', 'Trichotylenchus', 'Histotylenchus', 'Macrotrophurus',
    ]),
    TaxonFamily('Merliniidae', 'Rhabditida', [
      'Merlinius', 'Amplimerlinius', 'Geocenamus', 'Nagelus', 'Scutylenchus', 'Macrotylenchus',
      'Paramerlinius', 'Telomerlinius', 'Pratylenchoides',
    ]),
    TaxonFamily('Criconematidae', 'Rhabditida', [
      'Criconema', 'Ogma', 'Crossonema', 'Croserinema', 'Lobocriconema', 'Neolobocriconema',
      'Orphreyus', 'Pateracephalanema', 'Criconemoides', 'Mesocriconema', 'Bakernema',
      'Neobakernema', 'Nothocriconemoides', 'Hemicriconemoides',
    ]),
    TaxonFamily('Hemicycliophoridae', 'Rhabditida', ['Hemicycliophora', 'Caloosia', 'Hemicaloosia']),
    TaxonFamily('Tylenchulidae', 'Rhabditida', [
      'Tylenchulus', 'Trophotylenchulus', 'Boomerangia', 'Paratylenchus', 'Cacopaurus',
      'Sphaeronema', 'Meloidodera', 'Meloidoderita', 'Tylenchocriconema',
    ]),
    TaxonFamily('Anguinidae', 'Rhabditida', [
      'Anguina', 'Ditylenchus', 'Subanguina', 'Nothotylenchus', 'Litylenchus', 'Nothanguina',
      'Orrina', 'Pterotylenchus', 'Safianema', 'Zeatylenchus', 'Cotylenchus', 'Diptenchus',
      'Nothotylenchoides',
    ]),
    TaxonFamily('Aphelenchoididae', 'Rhabditida', ['Aphelenchoides', 'Bursaphelenchus']),
  ]),
  TaxonOrder('Dorylaimida', [
    TaxonFamily('Longidoridae', 'Dorylaimida', [
      'Xiphinema', 'Longidorus', 'Paralongidorus', 'Longidoroides', 'Siddiqia', 'Xiphidorus',
      'Australodorus', 'Paraxiphidorus',
    ]),
  ]),
  TaxonOrder('Triplonchida', [
    TaxonFamily('Trichodoridae', 'Triplonchida', [
      'Trichodorus', 'Paratrichodorus', 'Nanidorus', 'Monotrichodorus', 'Allotrichodorus',
      'Ecuadorus', 'Atlantadorus',
    ]),
  ]),
];

/// Classification system the user picked in Settings.
enum ClassificationSystem { nemys2026, classic }

extension ClassificationSystemLabel on ClassificationSystem {
  String get label => switch (this) {
        ClassificationSystem.nemys2026 => 'NeMys 2026: Rhabditida',
        ClassificationSystem.classic => 'Classic: Tylenchida',
      };

  /// Order name to display for a family. Only the order changes between
  /// systems; families and genera are the same.
  String orderFor(String nemysOrder, String family) {
    if (this == ClassificationSystem.nemys2026 || nemysOrder != 'Rhabditida') return nemysOrder;
    return family == 'Aphelenchoididae' ? 'Aphelenchida' : 'Tylenchida';
  }
}
