# Notes de version — ChessLab 2.4

Notes DÉTAILLÉES pour le dépôt. Les textes à coller dans App Store Connect sont dans la section « Nouveautés de cette version » de `METADATA.md` (un par langue : fr-FR, en-GB, es-ES, de-DE, it-IT).

> Version `2.4`, build `28` (la 2.3, build 24, est en vente ; les builds 25, 26 et 27 sont sur TestFlight, le 28 les remplace). iOS seulement pour cette version : Android n'a pas de version 2.4 (rien publié sur Play depuis la 2.3) ; ses écarts sont dans `android/PARITE.md`. Préparée le 20/11/2026 ; la version n'est pas soumise à la révision.

## Ce qui est nouveau

- **Coups à la voix** (nouvelle autorisation : micro et reconnaissance vocale). Réglage dans Nouvelle partie, éteint au départ à chaque ouverture. Le micro écoute seul à mon tour ; la phrase est découpée au niveau sonore, reconnue SUR L'APPAREIL (transcripteur d'iOS 26, sinon reconnaissance classique hors ligne avec les coups légaux en indices) puis oubliée. Le coup compris est joué directement ; « annule » le reprend ; un coup impossible ou incompris est dit à voix haute ; une conversation est ignorée. Cinq langues, alphabet radio compris. Interrupteur « Micro » (pastille dans la ligne du joueur, sous le plateau). Sous iOS 18 : ligne orange « la reconnaissance n'est peut-être pas optimale » à l'allumage et conseil des coups courts (« e quatre »), la colonne e se confondant avec c ou a (iPhone XS).
  - Essais du 20/11 : la fin de phrase se juge sur un niveau lissé (une phrase allait jusqu'aux 6 s du maximum), un coup sûr est joué dès 0,3 s de silence (« essai anticipé »), une seule reconnaissance à la fois, mots entendus ajoutés (« petit rock », « au quatre »).
- **À l'aveugle** : cinq niveaux (cases occupées en disques de couleur ou en gris, pièces adverses cachées, vos pièces cachées, tout caché), « Coup d'œil » maintenu et compté, voix hors ligne au choix qui répète vos coups (Règles FIDE, annexe D.2.1).
- **Visualisation** : un module pour voir l'échiquier dans sa tête, en cinq marches (les cases jusqu'au calcul de tête), réglages et statistiques suivant iCloud.
- **Puzzles › Contre la montre** : trois minutes, trois erreurs, difficulté croissante, record synchronisé.
- **Nouvelle partie refaite** : trois blocs, l'adversaire en vedette (quatre jauges), menus, aides en pastilles.
- **iCloud** : liste « Vos appareils », synchronisation revue (notifications silencieuses CloudKit).
- **Aide** : « Nouveautés 2.4 » (le bloc 2.3 devient « Nouveautés 2.3 »), entrée « Jouer à la voix ».

## À savoir avant de publier

- Les textes es/de/it (fiche, aide, ligne orange) n'ont PAS été relus par un locuteur natif.
- **Nouvelle autorisation** (micro, reconnaissance vocale) : décrite dans les notes de révision de `METADATA.md` ; la politique de confidentialité a une section « Le micro » (19/11).
- Captures : seule « 04-adversaires » (écran Nouvelle partie, refondu) était périmée ; refaite le 20/11 pour l'iPhone, l'iPad et l'écran EXTÉRIEUR du Duo, dans les cinq langues (`tools/captures-fiche.sh`, `habiller-captures.py`). L'écran INTÉRIEUR du Duo (non pilotable) et les aperçus vidéo sont inchangés. Le simulateur Duo n'ayant pas de reconnaissance vocale en fr/it (ligne « Coups à la voix » grisée avec « Indisponible »), ces deux captures ont été prises avec une construction de capture forçant « disponible » (réglage de débogage, JAMAIS commité).
- Pas vu à l'écran : la pastille du micro sur l'iPhone Duo replié (le plateau garde sa taille), la ligne orange.
- Whisper a été étudié et laissé de côté (`tools/whisper-spike/README.md`) : rien dans l'app.

---

## English

Version 2.4 (build 26). New: voice moves (recognised on the device, new microphone and speech-recognition permissions), blindfold play, the Visualization module, an “Against the clock” puzzle mode, a redesigned New game screen and a “Your devices” list for iCloud. Details above (French). The es/de/it texts still await native-speaker review.
