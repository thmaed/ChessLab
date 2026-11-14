# Notes de version — ChessLab 2.3

Notes DÉTAILLÉES pour le dépôt. Les textes à coller dans App Store Connect sont dans la section « Nouveautés de cette version » de `METADATA.md` (un par langue : fr-FR, en-GB, es-ES, de-DE, it-IT).

> Version `2.3`, build `23` (la 2.2, build 22, est en vente). iOS et Android partent ensemble (Play : fiches dans `android/app/src/main/play/listings/`, état dans `android/PARITE.md`). Préparée le 14/11/2026 ; le build n'est pas archivé, la version n'est pas soumise.

## Ce qui est nouveau

- **Espagnol, allemand et italien, complets**, des deux côtés : interface (catalogue `Localizable.xcstrings` ; `strings_app.xml` généré côté Android), aide, cours d'ouvertures et de finales (137 fichiers JSON, tous les coups dans la notation de la langue), noms d'ouvertures ECO, noms des joueurs par défaut, `InfoPlist`, extension de partage.
- **Notation** : l'italien partage les lettres de l'espagnol (R D T A C), l'allemand a les siennes (K D T L S) ; la notation par défaut suit la langue de l'interface, réglable à part.
- **Sélecteur de langue** : pastilles qui passent à la ligne (`FlowLayout`) au lieu d'une liste ; « Langue du système » devient « Automatique ». Pastilles de notation de même forme.
- **Mode Deux joueurs** (et Chess960 à deux) : les noms par défaut « Blancs » / « Noirs » s'affichent dans la langue choisie.
- **Fiches** : es-ES, de-DE, it-IT à App Store Connect (cette version) et sur Google Play.

## À savoir avant de publier

- Les textes es/de/it n'ont PAS été relus par un locuteur natif.
- Visuels es / de / it (+ es-MX, fr-CA) : captures iPhone et iPad (10 + 10), écran EXTÉRIEUR du Duo (6), aperçu Duo dans la langue, aperçus iPhone/iPad communs (anglais, comme en français), en-têtes et résultats de recherche (`AppStoreSubmission/entete/`, à déposer à la main). NON faits : écran INTÉRIEUR du Duo (posture non pilotable), aperçus iPhone/iPad réenregistrés par langue. en-AU, en-CA, en-US : visuels de la langue principale (en-GB), à vérifier à la soumission.
- Noms de l'app : « ChessLab » est libre en es-ES mais PRIS en de-DE et en it (comme en en-US) ; la fiche porte donc « ChessLab Schach » (de-DE) et « ChessLab Scacchi » (it). Le nom sous l'icône reste « ChessLab ». Code de langue Apple pour l'italien : `it` (pas `it-IT`).
- Vérifié : tests unitaires iOS, tests d'interface sur simulateurs et sur iPhone 11 / XS Max / iPhone3, Galaxy A16 (voir `android/PARITE.md` pour ce qui reste à cocher).

---

## English

Version 2.3 (build 23). New: complete Spanish, German and Italian (interface, help, all opening and endgame courses, opening names, move notation), a more compact language picker with an “Automatic” option, and default player names in two-player mode shown in the chosen language. Details above (French). The es/de/it texts still await native-speaker review.
