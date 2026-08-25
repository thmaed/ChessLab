# Checklist du tour manuel 1.6 — à faire à la main, sur appareil

Les 701 tests unitaires et 72 tests d'interface couvrent la mécanique : ce
document couvre **ce qu'eux ne peuvent pas voir**. Chaque section dit d'abord
ce qui est déjà prouvé automatiquement, pour que le tour ne re-vérifie pas ce
qui l'est — il ne reste que le rendu, le geste, et l'appareil réel.

**Matériel** : un iPhone (idéalement un petit écran ou le Zoom d'affichage
activé, Réglages ▸ Luminosité et affichage ▸ Zoom d'affichage), un iPad, et —
**nécessaire, pas optionnel** — un appareil en **iOS 18** : la cible de
déploiement est revenue à 18.0, tous les runtimes de test sont en iOS 26, et
le précédent est réel (plateau injouable en iOS 18, invisible pour 330 tests
verts — voir PROGRESS, 16/08). Un passage rapide des sections 1, 2 et 5 sur
l'appareil iOS 18 suffit.

## 1. « Reprendre ici » (Jouer, puis Deux joueurs)

*Déjà prouvé : la troncature, la restauration à l'identique, l'expiration,
les gardes fin-de-partie et moteur — 9 tests. Reste : le geste et le rendu.*

| # | Action | Attendu |
|---|---|---|
| 1.1 | Jouer quelques coups contre l'ordinateur (sans pendule), revenir 2-3 coups en arrière avec ‹, toucher « Reprendre ici » | La partie reprend **immédiatement** — aucune feuille de confirmation |
| 1.2 | Regarder la barre juste après | « Annuler la reprise » occupe la place du bouton touché ; elle s'efface seule après ~8 s |
| 1.3 | Recommencer, puis toucher « Annuler la reprise » | Les coups écartés reviennent, la liste des coups est identique à l'avant-reprise |
| 1.4 | Recommencer, puis jouer un coup pendant les 8 s | La pastille disparaît dès le coup joué |
| 1.5 | Recommencer, puis **abandonner** pendant les 8 s | La pastille disparaît avec la fin de partie — l'abandon ne peut pas être annulé |
| 1.6 | Même tour en **Deux joueurs** (transport en bas) ; en 1.5, remplacer l'abandon par la nulle d'accord | Mêmes comportements ; la bannière d'annulation apparaît sous la barre de transport |
| 1.7 | VoiceOver activé, refaire 1.1 dans les deux modes | Annonce « Partie reprise, N coups écartés. Annulation possible. » dans **les deux** modes |
| 1.8 | Sur iPhone en Zoom d'affichage, refaire 1.1-1.2 | La rangée de contrôle tient sur une ligne, rien ne déborde de l'écran |

## 2. Bulles du Laboratoire — le geste de maintien

*Déjà prouvé : largeurs des tuiles, textes, traductions. Reste : les gestes —
et surtout 2.2, **invérifiable en simulateur** : la parade au vol de toucher
par la présentation n'a jamais tourné sur un vrai écran.*

| # | Action | Attendu |
|---|---|---|
| 2.1 | Laboratoire ▸ lancer une petite série ▸ **toucher** la tuile « LOS (A > B) » | Une bulle explique la statistique, ancrée sur la tuile (pas une feuille plein écran) ; elle s'efface seule après ~10 s |
| 2.2 | **Maintenir** le doigt sur une tuile sans le lever | La bulle apparaît après ~0,3 s et **reste affichée tant que le doigt est posé** — elle ne doit pas clignoter puis disparaître |
| 2.3 | Lever le doigt après un maintien de 2-3 s | La bulle se referme au relâchement |
| 2.4 | Rouvrir une bulle d'un toucher, puis toucher ailleurs | Elle se referme immédiatement |
| 2.5 | Toucher les en-têtes « Répartition (A) » et « Progression de A » | Même bulle, expliquant notamment la bande claire de confiance |
| 2.6 | VoiceOver : double-toucher une tuile | La bulle s'ouvre (c'était cassé, corrigé en 521413f — vérifier sur tuile ET en-tête) |
| 2.7 | Très grande taille de texte (Réglages ▸ Accessibilité) | Le texte de la bulle défile, rien n'est coupé |

## 3. Ouvertures — le rendu de l'index

*Déjà prouvé : structure de l'arbre, absence de doublons, verdicts, filtres,
import, transpositions — côté données. Reste : ce que ça donne à l'œil.*

| # | Action | Attendu |
|---|---|---|
| 3.1 | Ouvrir une grosse ouverture (Scandinave ou London), icône index en haut à droite | Arbre lisible : rails continus sans trous, ligne principale en gras, un étage d'indentation par débranchement |
| 3.2 | Toucher un coup au milieu d'une variante profonde | Le plateau saute à cette position, l'index se referme |
| 3.3 | Toucher une pastille « transposition » | L'index défile jusqu'au coup cible et le surligne ~2 s |
| 3.4 | Sous le plateau | Deux colonnes : Maîtres (fond orangé, pourcentages) / Stockfish (max 3 coups) ; barre d'évaluation fine au-dessus |
| 3.5 | Tourner l'iPad en paysage | Le panneau passe à droite du plateau |

## 4. Harmonisation des barres d'outils

| # | Action | Attendu |
|---|---|---|
| 4.1 | Parcourir : Ouvertures, Finales, Puzzles, Jouer, Deux joueurs, Analyser | Le **même** bouton violet ▦ en haut à droite partout ; il liste uniquement les modes pertinents (pas « Deux joueurs » depuis Deux joueurs, pas « Analyser » depuis Analyser) |
| 4.2 | Dans Jouer et Deux joueurs, ouvrir le menu ⇪ | Il ne contient **que** de l'export (copier/partager FEN et PGN) — plus de section « Continuer ailleurs » |
| 4.3 | Dans Jouer et Analyser, chercher le sélecteur de thème 🎨 | Absent — le thème ne se règle plus que dans Réglages, et s'applique partout |
| 4.4 | Accueil iPhone : icônes en haut à droite | Aide verte, Progression bleue, Réglages dorés |
| 4.5 | Accueil iPad : mêmes entrées dans la barre latérale | **Mêmes couleurs** que sur iPhone |

## 5. Finales retravaillées

*Déjà prouvé : chaque coup de chaque ligne est tranché par la tablebase.
Reste : la pédagogie se juge en lisant.*

| # | Action | Attendu |
|---|---|---|
| 5.1 | Finales ▸ « Pions électriques » | Titre **en français** ; 4 chapitres (principale, miroir, deux pièges) ; les commentaires racontent la menace réciproque |
| 5.2 | « Le pion passé éloigné » | Le pion part de **a4** (plus a5) ; la technique enseignée est réellement nécessaire |
| 5.3 | « La triangulation » | La ligne va jusqu'au **mat** (♕b6#), plus d'arrêt sur « la conversion est mécanique » |
| 5.4 | Analyse d'une partie : provoquer une gaffe puis regarder le plateau | La pastille (?? rouge) reste lisible **au-dessus** des flèches du moteur qui arrivent sur sa case |

## 6. Aide

| # | Action | Attendu |
|---|---|---|
| 6.1 | Accueil ▸ Aide | « Nouveautés de la version 1.6 » en tête, huit points concis |
| 6.2 | Descendre tout en bas | Carte « Remerciements » (cœur rose) pour Nils Gauthey, après la carte contact |
| 6.3 | Carte Laboratoire | Elle dit « Changer de mode », puis « Laboratoire » — plus aucune mention de « Continuer au Laboratoire » |
| 6.4 | Passer l'app en anglais (Réglages ▸ Langue) et rouvrir l'aide | Tout est traduit, remerciements compris |

## 7. Chess960 (nouveau — si le build embarque le lot 2)

*Déjà prouvé : les règles (perft 1,2 M nœuds contre python-chess), la
mécanique de partie sans moteur. Reste : le moteur réel et le geste.*

| # | Action | Attendu |
|---|---|---|
| 7.1 | Accueil ▸ tuile « Variantes » ▸ Chess960 ▸ « Aléatoire » puis Commencer | Une partie démarre sur la position tirée ; le n° est dans le titre |
| 7.2 | Saisir 518 comme numéro | L'aperçu montre la rangée classique, et la partie est une partie normale |
| 7.3 | Jouer jusqu'au roque : toucher le roi | Les cases de SES tours sont proposées ; toucher la tour exécute le roque (roi g/c, tour f/d) |
| 7.4 | Laisser le moteur roquer (position où il le fera) | Son roque s'affiche O-O dans le ruban, la partie continue normalement |
| 7.5 | Elo bas vs haut, avec pendule | Le moteur joue au niveau et au rythme attendus, la pendule décompte |
| 7.6 | Exporter le PGN et l'importer sur Lichess (analyse) | Lichess le lit : variante 960, position de départ, roques compris |

## Décisions encore ouvertes (hors tour)

- `AppStoreSubmission/RELEASE_NOTES-1.4.0.md` est supprimé dans l'arbre de
  travail (pas par le code) alors que les notes 1.5.0 le disent « conservé » :
  confirmer la suppression (et corriger la mention) ou restaurer le fichier.
- L'archive App Store attend un certificat *Apple Distribution* (équipe
  3N3BN259H6) et une connexion App Store Connect — voir la conversation du
  24/08 et `AppStoreSubmission/CHECKLIST.md`.
