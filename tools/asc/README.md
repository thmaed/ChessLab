# App Store Connect sans les mains

`release.sh` archive l'app, téléverse le build, puis remplit la fiche de la
version dans App Store Connect : textes des deux langues, captures, aperçus
vidéo, build rattaché, notes pour la révision. Il s'arrête **avant** la
soumission : il reste à relire et à cliquer « Soumettre pour révision ».

    tools/asc/release.sh              # tout
    tools/asc/release.sh --no-build   # fiche seulement
    tools/asc/.venv/bin/python tools/asc/asc.py status   # ce qu'Apple a

Sources de vérité, toutes dans le dépôt :

- `AppStoreSubmission/METADATA.md` — nom, sous-titre, mots-clés, promo,
  description, nouveautés, URLs, notes réviseurs. Le script lit les blocs
  ``` sous chaque étiquette en gras et vérifie les limites de caractères.
- `AppStoreSubmission/screenshots/<format>/en/*.png` — dix captures au plus
  par format (limite d'Apple), dans l'ordre des noms ; le surplus va dans
  `hors-fiche/`.
- `AppStoreSubmission/videos/*.mov` — les aperçus, 886 × 1920 (iPhone) et
  1200 × 1600 (iPad 13").

Formats côté Apple : les captures iPhone de 1284 × 2778 sont le jeu
« 6,5 pouces » de l'API (`APP_IPHONE_65`, le dossier `iphone-6.7` garde son
nom historique) ; le « 6,7 pouces » exige 1290 × 2796 et refuse tout le
reste. L'iPad 13" est `APP_IPAD_PRO_3GEN_129`.
- Version et build : `MARKETING_VERSION` et `CURRENT_PROJECT_VERSION` de la
  cible applicative.

## L'extension de partage (depuis le 07/11/2026)

L'app embarque une extension, `ChessLabShare` (identifiant
`com.chesslab.ChessLab.Share`), qui reçoit les images de « Partager ». Elle
a son propre identifiant, son propre profil, et le groupe d'app
`group.com.chesslab.ChessLab` est porté par les DEUX. État au 07/11/2026,
tout est en place et l'export signé a été vérifié (archive → `.ipa`, groupe
présent dans les droits de l'app et de l'extension) :

- identifiant de l'extension et capacité « App Groups » sur les deux
  identifiants : créés par l'API ;
- le groupe lui-même : créé et rattaché sur developer.apple.com — l'API n'a
  pas de point d'entrée pour cela, et Xcode refuse la clé d'API en signature
  automatique ;
- profils « ChessLab App Store 2026 » (régénéré : un changement de
  capacité invalide le profil) et « ChessLab Share App Store 2026 », créés par
  l'API et déclarés dans `ExportOptions.plist`.

À retenir : toute NOUVELLE capacité d'app invalide le profil de distribution,
qu'il faut alors recréer (même procédure, par l'API). Version et build de
l'extension sont ceux de l'app (2.1 / 21) : les monter ENSEMBLE, sinon
App Store Connect refuse le téléversement.

## Secrets, hors dépôt

`~/.private_keys/` (permissions 700, ignoré par Git où qu'il soit) :

- `AuthKey_<KEY_ID>.p8` — clé d'API App Store Connect, rôle App Manager.
- `asc.env` — `ASC_KEY_ID` et `ASC_ISSUER_ID`.
- `dist/` — clé privée, CSR et certificat « Apple Distribution » créés par
  l'API le 06/09/2026 (expire le 06/09/2027), importés dans le trousseau de
  session. Le profil « ChessLab App Store 2026 » (même échéance) a été créé
  par l'API et installé dans `~/Library/Developer/Xcode/UserData/Provisioning
  Profiles/`. Pour un nouveau Mac : réimporter `dist/dist_2026.key` et
  `dist/dist_2026.cer` avec `security import`, réinstaller le profil.

Pourquoi une signature manuelle : la clé d'API n'a pas accès aux certificats
gérés dans le nuage par Xcode (« Cloud signing permission error »), donc
`ExportOptions.plist` désigne explicitement le certificat et le profil.

## Ce que l'API ne fait pas

- L'étiquette de confidentialité (« Data Not Collected ») : pas d'API.
- Ajouter une langue : la fiche est en français et en **anglais du
  Royaume-Uni** (`en-GB`) depuis l'origine. Un « English (U.S.) » neuf est
  refusé, le nom « ChessLab » y étant déjà pris par une autre app.
- Le clic de soumission, par choix.
