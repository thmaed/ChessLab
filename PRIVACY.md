# Politique de confidentialité — ChessLab

*Dernière mise à jour : 19 septembre 2026*

**ChessLab ne collecte aucune donnée personnelle, n'en transmet aucune, et ne
communique avec aucun serveur.**

Ce n'est pas une intention : c'est une propriété vérifiable de l'application.
Elle ne demande pas la permission `INTERNET` d'Android, sans laquelle aucun
programme ne peut ouvrir la moindre connexion. Vous pouvez le constater
vous-même en la faisant fonctionner en mode avion : tout y marche, y compris
l'analyse des parties et les adversaires artificiels, qui calculent sur votre
téléphone.

## Ce que l'application ne fait pas

- Aucun compte, aucune inscription, aucune identification.
- Aucune mesure d'audience, aucun traceur, aucune publicité.
- Aucun service tiers, aucun partage avec qui que ce soit.
- Aucune transmission de quoi que ce soit vers l'extérieur.

## Ce qui est enregistré, et où

Tout reste dans l'espace privé de l'application, sur votre téléphone :

| Ce qui est gardé | Pourquoi |
| --- | --- |
| Vos parties | les revoir et les analyser |
| Votre progression (ouvertures, finales, puzzles) | vous proposer les bonnes révisions |
| Vos réglages | les retrouver au lancement suivant |
| Vos répertoires d'ouvertures importés | les relire |

Android réserve cet espace à l'application : aucune autre application ne peut y
accéder, et il disparaît entièrement quand vous désinstallez ChessLab.

## Permissions

**Vibreur** — le seul retour haptique du plateau. Elle est accordée à
l'installation et ne donne accès à aucune donnée.

**Appareil photo** — le scanner de position photographie un échiquier réel.
L'application ne demande **pas** la permission `CAMERA` : elle passe par
l'application photo de votre système, qui lui rend une image et garde la caméra
pour elle. L'image est déposée dans le cache privé de ChessLab, lue une fois
pour reconnaître les pièces, et n'est envoyée nulle part.

## Quand vous exportez quelque chose

L'application sait exporter une partie (PGN), une position (FEN) ou une
sauvegarde de vos données (`.clab`). Cela n'arrive **que sur votre demande**,
par le bouton de partage, et c'est **vous** qui choisissez la destination :
messagerie, fichiers, une autre application. ChessLab ne décide de rien et
n'envoie rien de lui-même. Une fois le fichier remis à l'application que vous
avez choisie, il suit la politique de confidentialité de celle-ci.

## Supprimer vos données

Désinstallez l'application : tout part avec elle. Vous pouvez aussi vider ses
données depuis les réglages Android (Applications → ChessLab → Stockage).

Il n'y a rien à nous demander d'effacer : nous ne détenons rien.

## Enfants

L'application ne collecte aucune donnée, d'aucun utilisateur, quel que soit son
âge.

## Modifications

Toute modification de cette politique sera publiée sur cette page, avec sa
date. L'historique complet est consultable dans le dépôt du code source.

## Code source

ChessLab embarque Stockfish, publié sous licence GPLv3. Le code source de
l'application est disponible : <https://github.com/thmaed/ChessLab>

## Contact

thmaed@icloud.com

---

# Privacy Policy — ChessLab

*Last updated: 19 September 2026*

**ChessLab collects no personal data, transmits none, and talks to no server.**

This is not a promise, it is a verifiable property of the app. It does not
request Android's `INTERNET` permission, without which no program can open a
connection at all. You can check this yourself by running it in airplane mode:
everything works, including game analysis and the computer opponents, which
compute on your phone.

## What the app does not do

- No account, no sign-up, no identification.
- No analytics, no trackers, no advertising.
- No third-party services, no sharing with anyone.
- No transmission of anything to the outside.

## What is stored, and where

Everything stays in the app's private storage, on your phone:

| What is kept | Why |
| --- | --- |
| Your games | to review and analyse them |
| Your progress (openings, endgames, puzzles) | to schedule the right reviews |
| Your settings | to restore them next time |
| Opening repertoires you import | to read them again |

Android reserves this storage for the app: no other app can reach it, and it is
removed entirely when you uninstall ChessLab.

## Permissions

**Vibrate** — the board's haptic feedback, and nothing else. It is granted at
install time and gives access to no data.

**Camera** — the position scanner photographs a real chessboard. The app does
**not** request the `CAMERA` permission: it goes through your system's camera
app, which hands back an image and keeps the camera to itself. The image is
placed in ChessLab's private cache, read once to recognise the pieces, and sent
nowhere.

## When you export something

The app can export a game (PGN), a position (FEN) or a backup of your data
(`.clab`). This happens **only when you ask**, through the share button, and
**you** choose the destination: mail, files, another app. ChessLab decides
nothing and sends nothing by itself. Once the file is handed to the app you
chose, it follows that app's privacy policy.

## Deleting your data

Uninstall the app: everything goes with it. You can also clear its data from
Android settings (Apps → ChessLab → Storage).

There is nothing to ask us to erase: we hold nothing.

## Children

The app collects no data, from any user, of any age.

## Changes

Any change to this policy will be published on this page, with its date. The
full history is visible in the source code repository.

## Source code

ChessLab embeds Stockfish, released under the GPLv3 licence. The app's source
code is available at <https://github.com/thmaed/ChessLab>

## Contact

thmaed@icloud.com
