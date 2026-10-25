# Soumission Play Store — ChessLab 2.0

Préparée le 25/10/2026. **Rien n'a été envoyé à Google** : la clé du compte de
service (`~/.private_keys/play-service-account.json`) n'est pas posée sur ce Mac,
donc `publishBundle` / `publishListing` ne peuvent pas tourner (voir
`./tools/verifier-cle-play.sh`). Tout ce qui suit se fait à la main dans la
console, ou automatiquement une fois la clé posée.

## Ce qui est prêt

| Pièce | Où | État |
| --- | --- | --- |
| Bundle signé 2.0 | `app/build/outputs/bundle/release/app-release.aab` (146 Mo) | `versionName` 2.0, `versionCode` **33**, signé (`jarsigner` : jar verified) |
| Permission `INTERNET` | manifeste fusionné release | **absente** (0 occurrence) |
| Pages de 16 Ko | six bibliothèques natives de l'AAB | toutes `0x4000` |
| Textes de la fiche | `app/src/main/play/listings/{fr-FR,en-US}/` | titre, description courte (76 / 70 car.), description complète (3989 / 3692 car., limite 4000) |
| Notes de version | `app/src/main/play/release-notes/{fr-FR,en-US}/default.txt` | 471 / 427 car. (limite 500) |
| Captures téléphone | `listings/*/graphics/phone-screenshots/` | **sept** par langue, 1080 × 2340, prises sur le Galaxy A16 : accueil, séance du jour, nouvelle partie, analyse + Coach, ouvertures (filtre Classiques), puzzle, finales |
| Icône, image de présentation | `listings/*/graphics/icon`, `feature-graphic` | inchangées |

## À faire, dans l'ordre

1. **Pousser le code AVANT de soumettre** (`git push`) : publier, c'est distribuer
   Stockfish (GPLv3), et les sources correspondant au binaire doivent être
   publiques. `main` contient des dizaines de commits non poussés (2.0).
2. Console → ChessLab → **Production** (ou **Test fermé**, au choix) → *Créer une
   version* → téléverser l'AAB ci-dessus.
3. Coller les notes de version (`release-notes/*/default.txt`), une par langue.
4. *Présence sur le Play Store → Fiche principale* : mettre à jour la description
   courte et la description complète (fichiers ci-dessus), pour `fr-FR` et `en-US`.
5. Même page : remplacer les **captures téléphone** par les sept de chaque langue.
6. *Contenu de l'application* : rien ne change — aucune donnée collectée, pas de
   publicité, pas de permission `INTERNET`, public 13 ans et plus. Relire les
   déclarations d'un coup d'œil, Google les redemande parfois à une nouvelle version.
7. *Envoyer pour examen*.

Avec la clé du compte de service posée, les points 2 à 5 deviennent :

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
cd android
./gradlew publishListing                    # textes + captures
./gradlew publishBundle --track internal    # puis promoteArtifact vers production
```

## Réserves

- Les captures **tablette** (7" et 10") sont celles de la 1.x : elles ne montrent
  pas la séance du jour. À refaire avec `tools/captures-tablette.sh` si vous voulez
  qu'elles suivent.
- Les noms d'ouverture enregistrés dans une partie le sont dans la langue du moment :
  une partie analysée en français garde « Italienne, défense des deux cavaliers » si
  l'on passe l'app en anglais (visible sur la carte « Dernière partie »). Cosmétique,
  non corrigé.
- Le `versionCode` est consommé dès qu'un fichier est déposé, même refusé :
  `version.properties` est déjà à 34 pour la prochaine construction.
