# ChessLab — la règle qui gouverne les deux apps

**L'app iOS FAIT FOI. L'app Android la suit.**

Toute évolution demandée sur l'app iPhone — une fonction, un écran, un
libellé, un barème, une correction — se répercute sur la version Android dans
le même chantier, sans qu'il faille le redemander. Une modification qui ne
part que d'un côté crée une divergence, et une divergence ne se rattrape
jamais toute seule : elle se découvre des mois plus tard, sur l'appareil,
quand quelqu'un s'étonne que le même bouton ne fasse pas la même chose.

Concrètement, à chaque demande portant sur l'app iPhone :

1. la faire côté iOS (`ChessLab/`, tests dans `ChessLabTests/`) ;
2. la porter côté Android (`android/`, tests JVM + instrumentés) dans le même
   mouvement, en lisant le code Swift plutôt qu'en réinventant — les fichiers
   Kotlin nomment leur pendant Swift en tête de leur documentation ;
3. si le portage ne peut pas se faire tout de suite, l'INSCRIRE dans
   `android/PARITE.md`, qui tient la liste des écarts, plutôt que de le
   laisser dans une tête ;
4. le dire dans le message de commit, des deux côtés.

## Les seuls écarts ASSUMÉS

Ils sont peu nombreux et tous décidés explicitement :

- **iCloud** : hors périmètre Android. Le transfert entre appareils Android
  passe par un fichier `.clab` exporté et importé à la main (décision du
  12/09/2026).
- **Aucun échange iOS ↔ Android** : le fichier `.clab` circule entre appareils
  Android seulement (même décision).
- **Répétition espacée** : FSRS-5 pour les ouvertures, SM-2 pour les puzzles,
  des deux côtés — ce n'est pas un écart mais une distinction qu'on oublie.
- Les écarts mineurs et documentés dans le code lui-même (deux, côté
  entraînement, signalés en commentaire à l'endroit exact).

Tout le reste doit être IDENTIQUE : fonctions, enchaînements d'écrans,
barèmes, seuils, libellés dans les deux langues, et jusqu'aux couleurs qui
portent un sens (le vert de la revue, le gris de l'analyse en direct, le rouge
translucide de la menace).

## Où regarder

| | |
| --- | --- |
| `android/PARITE.md` | la liste des écarts restants, tenue à jour, cochée après vérification SUR APPAREIL |
| `android/README.md` | l'état du portage et comment construire |
| `android/PUBLIER.md` | le chemin vers le Play Store, GPLv3 comprise |
| `PROGRESS.md` | le journal du projet iOS |

## Ce qui ne doit JAMAIS entrer dans le dépôt

Le trousseau de signature Android (`*.jks`, `android/keystore.properties`, qui
vivent dans `~/.chesslab-android/`), la clé du compte de service Google Play
et la clé App Store Connect (`~/.private_keys/`). Le `.gitignore` les couvre ;
c'est une ceinture, pas une excuse pour les déposer.

## La promesse produit

Aucun compte, aucun réseau, aucune donnée qui sort de l'appareil. Côté
Android, cela se vérifie d'une ligne : le manifeste ne déclare **pas** la
permission `INTERNET`. Toute demande qui l'exigerait doit être discutée avant
d'être écrite.
