# Checklist de synchronisation iCloud — à faire à la main, sur deux appareils

Cette vérification ne peut pas être automatisée : `xcodebuild` ne dispose que
d'un simulateur à la fois, et deux simulateurs ne partagent pas de compte
iCloud. Les tests unitaires couvrent la logique de fusion et de migration ;
**ce document couvre ce qu'eux ne peuvent pas voir** — le transport lui-même.

## Avant de commencer

- Deux appareils réels, **connectés au même compte iCloud**.
- Sur chacun : Réglages ▸ *Synchroniser via iCloud* **activé**, puis
  l'application **relancée** — le conteneur SwiftData n'est construit qu'une
  fois au lancement, l'interrupteur ne prend effet qu'au suivant.
- Vérifier dans Réglages que l'état du compte affiche bien « Compte iCloud
  connecté » et non « Non connecté à iCloud — la synchro est en pause ».

Dans tout ce qui suit, laisser **une à deux minutes** entre l'action sur A et
la vérification sur B : CloudKit n'est pas instantané, et l'app ne force une
réconciliation qu'à l'ouverture des écrans concernés (fenêtre de 5 minutes).
Passer l'écran en arrière-plan puis y revenir provoque une nouvelle tentative.

## 1. Répertoires personnels

| # | Sur l'appareil A | Attendu sur l'appareil B |
|---|---|---|
| 1.1 | Importer un PGN dans Ouvertures (« + » en haut à droite) | Le répertoire apparaît dans « Mes répertoires » |
| 1.2 | Importer un cours de **finale** reçu en fichier `.json` | Il apparaît dans **Finales**, pas dans Ouvertures, et le lecteur montre la rangée 1 en bas |
| 1.3 | Renommer un répertoire | Le nouveau nom apparaît, **sans créer de doublon** |
| 1.4 | Ajouter une variante dans l'éditeur | La variante apparaît dans le lecteur |
| 1.5 | Supprimer un répertoire | Il disparaît — et **ne réapparaît pas** au relancement de A |

Le point 1.5 est le plus important : c'est celui qui a déjà régressé une fois
(un fichier local ressuscitait un répertoire supprimé ailleurs).

Le point 1.2 vérifie le correctif du 20/08 : la nature « finale » d'un cours
devait survivre au partage, elle ne survivait à aucune recopie.

## 2. Édition concurrente (le cas qui ne doit RIEN perdre)

1. Couper le réseau sur les deux appareils.
2. Sur A : ajouter une variante au répertoire *R*. Sur B : ajouter une **autre**
   variante au même répertoire *R*.
3. Rétablir le réseau des deux côtés, attendre, ouvrir la liste des ouvertures.

**Attendu** : deux répertoires visibles — *R* (la version la plus récente) et
*R (autre appareil)*. Aucun travail n'est perdu ; c'est à l'utilisateur
d'arbitrer.

**Ne doit pas arriver** : un seul répertoire, l'une des deux variantes ayant
disparu sans trace.

## 3. Progression

| # | Sur A | Attendu sur B |
|---|---|---|
| 3.1 | Réviser quelques positions d'une ouverture | Le compteur « à réviser » diminue aussi sur B |
| 3.2 | Résoudre trois puzzles | Ils comptent dans Progrès sur B |
| 3.3 | Terminer une partie contre l'ordinateur | Elle apparaît dans la bibliothèque d'analyse de B |

## 4. Réglages (nouveau, 20/08)

| # | Sur A | Attendu sur B |
|---|---|---|
| 4.1 | Changer le **thème de plateau** | Le thème suit |
| 4.2 | Changer le **jeu de pièces** | Il suit |
| 4.3 | Passer les essais par puzzle de 1 à 3 | Le réglage suit |
| 4.4 | Changer la notation (française ↔ anglaise) | Elle suit |
| 4.5 | Régler l'Elo et les aides dans Nouvelle partie | Les réglages suivent (visibles au prochain affichage de l'écran) |
| 4.6 | Changer la **langue** | **NE DOIT PAS** suivre — chaque appareil garde la sienne |
| 4.7 | Couper les **sons** | **NE DOIT PAS** suivre |
| 4.8 | Couper la synchro iCloud sur A | **NE DOIT PAS** la couper sur B |

Les points 4.6 à 4.8 sont des vérifications de **non**-propagation, et comptent
autant que les autres : ce sont des décisions produit, pas des oublis.

## 5. Ce qui reste volontairement local

À vérifier une fois, pour confirmer que le comportement est bien celui annoncé
dans l'aide :

- Une **partie en cours** commencée sur A n'apparaît pas sur B. Deux appareils,
  deux parties commencées : il faudrait en sacrifier une, mieux vaut que chacune
  attende là où elle a été jouée.
- La bibliothèque de puzzles embarquée ne se synchronise pas (elle est
  identique sur les deux appareils, et pèse trop pour transiter).

## En cas d'anomalie

Relever, dans l'ordre : l'état du compte affiché dans Réglages, si l'app a bien
été relancée après l'activation, le délai écoulé, et si l'écran concerné a été
quitté puis rouvert. La plupart des « ça ne marche pas » sont l'un de ces
quatre points. Au-delà, noter le scénario exact dans `PROGRESS.md` — un défaut
de synchro non reproduit par écrit ne sera jamais corrigé.
