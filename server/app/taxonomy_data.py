"""Reference metadata for the 19 plant-parasitic nematode genera recorded in the Philippines."""

PHILIPPINE_GENERA = [
    {
        "name": "Meloidogyne",
        "family": "Meloidogynidae",
        "order": "Rhabditida",
        "vulva_pct": 0.85,
        "similar": ["Globodera", "Rotylenchulus"],
        "traits": [
            {"name": "Female body", "value": "Swollen, pear-shaped", "why": "Only a few genera have swollen, sedentary females. A pear shape with a neck points to root-knot.", "region": "vulva", "illustration": "swollenPear"},
            {"name": "Perineal pattern", "value": "Oval, fingerprint-like striae", "why": "The cuticle pattern around the vulva and anus separates Meloidogyne from cyst nematodes.", "region": "vulva", "illustration": "vulvaPosterior"},
            {"name": "Stylet", "value": "12–15 µm, rounded knobs", "why": "A short stylet with rounded knobs is typical of root-knot females.", "region": "stylet", "illustration": "styletKnobbed"},
        ],
    },
    {
        "name": "Globodera",
        "family": "Heteroderidae",
        "order": "Rhabditida",
        "vulva_pct": 0.88,
        "similar": ["Meloidogyne"],
        "traits": [
            {"name": "Female body", "value": "Round, becomes a brown cyst", "why": "A round cyst without a terminal cone separates Globodera from lemon-shaped Heterodera.", "region": "vulva", "illustration": "cystRound"},
            {"name": "J2 stylet", "value": "~22 µm, rounded knobs", "why": "Juvenile stylet length is a key measurement between cyst species.", "region": "stylet", "illustration": "styletKnobbed"},
        ],
    },
    {
        "name": "Pratylenchus",
        "family": "Pratylenchidae",
        "order": "Rhabditida",
        "vulva_pct": 0.80,
        "similar": ["Radopholus", "Hirschmanniella"],
        "traits": [
            {"name": "Lip region", "value": "Low, flattened, dark framework", "why": "A low, flat head with a heavy framework is the first thing to look for in lesion nematodes.", "region": "head", "illustration": "lipFlat"},
            {"name": "Stylet knobs", "value": "Rounded", "why": "Short, stout stylets (15–17 µm) with rounded knobs separate Pratylenchus from stylet-weak Radopholus males.", "region": "stylet", "illustration": "styletKnobbed"},
            {"name": "Tail", "value": "Conoid, bluntly rounded", "why": "Tail shape separates several Pratylenchus species and rules out the mucronate tail of Hirschmanniella.", "region": "tail", "illustration": "tailRounded"},
        ],
    },
    {
        "name": "Radopholus",
        "family": "Pratylenchidae",
        "order": "Rhabditida",
        "vulva_pct": 0.56,
        "similar": ["Pratylenchus"],
        "traits": [
            {"name": "Vulva position", "value": "~55% (near mid-body)", "why": "A mid-body vulva separates Radopholus from Pratylenchus.", "region": "vulva", "illustration": "vulvaMid"},
            {"name": "Male head", "value": "High, knob-like, stylet weak", "why": "Strong sexual dimorphism in the head is diagnostic for this genus.", "region": "head", "illustration": "lipOffset"},
            {"name": "Tail", "value": "Elongate conoid", "why": "Longer, tapering tails help separate it from lesion nematodes.", "region": "tail", "illustration": "tailConoid"},
        ],
    },
    {
        "name": "Hirschmanniella",
        "family": "Pratylenchidae",
        "order": "Rhabditida",
        "vulva_pct": 0.52,
        "similar": ["Pratylenchus"],
        "traits": [
            {"name": "Body", "value": "Long and slender, over 1 mm", "why": "Body length alone often separates Hirschmanniella from other Pratylenchidae.", "region": "vulva", "illustration": "slender"},
            {"name": "Tail", "value": "Pointed, with a mucro", "why": "A fine terminal spike (mucro) on the tail is characteristic.", "region": "tail", "illustration": "tailMucro"},
        ],
    },
    {
        "name": "Helicotylenchus",
        "family": "Hoplolaimidae",
        "order": "Rhabditida",
        "vulva_pct": 0.62,
        "similar": ["Rotylenchus", "Hoplolaimus"],
        "traits": [
            {"name": "Body posture", "value": "Spiral when relaxed", "why": "A spiral posture narrows the choice to a few Hoplolaimidae.", "region": "vulva", "illustration": "spiral"},
            {"name": "Stylet", "value": "24–30 µm, rounded knobs", "why": "Mid-length stylet separates it from the massive stylet of Hoplolaimus.", "region": "stylet", "illustration": "styletKnobbed"},
            {"name": "Tail", "value": "Dorsally convex, ventral projection", "why": "An asymmetric tail with a small ventral projection separates it from Rotylenchus.", "region": "tail", "illustration": "tailConoid"},
        ],
    },
    {
        "name": "Hoplolaimus",
        "family": "Hoplolaimidae",
        "order": "Rhabditida",
        "vulva_pct": 0.55,
        "similar": ["Helicotylenchus"],
        "traits": [
            {"name": "Stylet", "value": "Over 40 µm, tulip-shaped knobs", "why": "The massive stylet with anteriorly projecting knobs is diagnostic.", "region": "stylet", "illustration": "styletMassive"},
            {"name": "Lip region", "value": "High, offset, heavy framework", "why": "A strongly sclerotised head helps separate it from spiral nematodes.", "region": "head", "illustration": "lipOffset"},
        ],
    },
    {
        "name": "Rotylenchus",
        "family": "Hoplolaimidae",
        "order": "Rhabditida",
        "vulva_pct": 0.58,
        "similar": ["Helicotylenchus"],
        "traits": [
            {"name": "Tail", "value": "Hemispherical, evenly rounded", "why": "The rounded tail is the quickest way to separate Rotylenchus from Helicotylenchus.", "region": "tail", "illustration": "tailRounded"},
            {"name": "Body posture", "value": "Spiral or C-shaped", "why": "Shared with other spiral nematodes; combine with the tail shape.", "region": "vulva", "illustration": "spiral"},
        ],
    },
    {
        "name": "Rotylenchulus",
        "family": "Rotylenchulidae",
        "order": "Rhabditida",
        "vulva_pct": 0.70,
        "similar": ["Meloidogyne", "Tylenchulus"],
        "traits": [
            {"name": "Mature female", "value": "Kidney-shaped", "why": "The reniform shape outside the root is diagnostic.", "region": "vulva", "illustration": "kidney"},
            {"name": "Vulva position", "value": "~70%", "why": "A post-median vulva fits Rotylenchulus females.", "region": "vulva", "illustration": "vulvaPosterior"},
        ],
    },
    {
        "name": "Tylenchorhynchus",
        "family": "Dolichodoridae",
        "order": "Rhabditida",
        "vulva_pct": 0.56,
        "similar": ["Helicotylenchus"],
        "traits": [
            {"name": "Body posture", "value": "Straight to slightly curved", "why": "Stunt nematodes do not spiral when relaxed.", "region": "vulva", "illustration": "straight"},
            {"name": "Esophageal glands", "value": "Abutting, not overlapping", "why": "Glands that end at the intestine separate it from Hoplolaimidae and Pratylenchidae.", "region": "esophagus", "illustration": "glandsAbutting"},
        ],
    },
    {
        "name": "Criconemoides",
        "family": "Criconematidae",
        "order": "Rhabditida",
        "vulva_pct": 0.90,
        "similar": ["Mesocriconema"],
        "traits": [
            {"name": "Cuticle", "value": "Coarse annules, retrorse edges", "why": "Backward-pointing ring edges separate Criconemoides from Mesocriconema.", "region": "vulva", "illustration": "annulatedRetrorse"},
        ],
    },
    {
        "name": "Mesocriconema",
        "family": "Criconematidae",
        "order": "Rhabditida",
        "vulva_pct": 0.92,
        "similar": ["Criconemoides", "Hemicriconemoides"],
        "traits": [
            {"name": "Cuticle", "value": "Smooth, rounded annules", "why": "Rounded annule margins separate it from Criconemoides.", "region": "vulva", "illustration": "annulated"},
        ],
    },
    {
        "name": "Hemicriconemoides",
        "family": "Criconematidae",
        "order": "Rhabditida",
        "vulva_pct": 0.92,
        "similar": ["Hemicycliophora"],
        "traits": [
            {"name": "Cuticle", "value": "Double, close-fitting sheath", "why": "A second cuticle that follows the body separates it from other ring nematodes.", "region": "vulva", "illustration": "sheath"},
        ],
    },
    {
        "name": "Hemicycliophora",
        "family": "Hemicycliophoridae",
        "order": "Rhabditida",
        "vulva_pct": 0.85,
        "similar": ["Hemicriconemoides"],
        "traits": [
            {"name": "Cuticle", "value": "Loose sheath around the body", "why": "A loose sheath that stands away from the body is diagnostic.", "region": "vulva", "illustration": "sheath"},
            {"name": "Stylet", "value": "Over 70 µm", "why": "One of the longest stylets among Tylenchids.", "region": "stylet", "illustration": "styletMassive"},
        ],
    },
    {
        "name": "Tylenchulus",
        "family": "Tylenchulidae",
        "order": "Rhabditida",
        "vulva_pct": 0.80,
        "similar": ["Rotylenchulus"],
        "traits": [
            {"name": "Mature female", "value": "Swollen posterior", "why": "Only the back half swells, unlike root-knot or reniform females.", "region": "vulva", "illustration": "swollenPosterior"},
        ],
    },
    {
        "name": "Ditylenchus",
        "family": "Anguinidae",
        "order": "Rhabditida",
        "vulva_pct": 0.80,
        "similar": ["Aphelenchoides"],
        "traits": [
            {"name": "Stylet", "value": "7–12 µm, small knobs", "why": "A small, delicate stylet separates it from most root parasites.", "region": "stylet", "illustration": "styletSmall"},
            {"name": "Median bulb", "value": "Oval, not filling body width", "why": "An oval bulb separates Ditylenchus from Aphelenchoides.", "region": "esophagus", "illustration": "bulbOval"},
        ],
    },
    {
        "name": "Aphelenchoides",
        "family": "Aphelenchoididae",
        "order": "Rhabditida",
        "vulva_pct": 0.68,
        "similar": ["Ditylenchus"],
        "traits": [
            {"name": "Median bulb", "value": "Large, rectangular, fills body width", "why": "The large median bulb is the clearest sign of Aphelenchoididae.", "region": "esophagus", "illustration": "bulbLarge"},
        ],
    },
    {
        "name": "Xiphinema",
        "family": "Longidoridae",
        "order": "Dorylaimida",
        "vulva_pct": 0.45,
        "similar": ["Longidorus"],
        "traits": [
            {"name": "Stylet", "value": "Odontostyle with flanged base", "why": "A flanged extension and a posterior guide ring separate Xiphinema from Longidorus.", "region": "stylet", "illustration": "styletFlanged"},
        ],
    },
    {
        "name": "Longidorus",
        "family": "Longidoridae",
        "order": "Dorylaimida",
        "vulva_pct": 0.50,
        "similar": ["Xiphinema"],
        "traits": [
            {"name": "Stylet", "value": "Long odontostyle, no flanges", "why": "No basal flanges and an anterior guide ring separate it from Xiphinema.", "region": "stylet", "illustration": "styletNeedle"},
        ],
    },
]
