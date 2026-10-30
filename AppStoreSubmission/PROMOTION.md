# Promotion — messages prêts à publier

Préparé le 29/10/2026. **Rien n'a été publié** : chaque message se poste à la main,
après relecture. Les règles des communautés changent ; relire celles du jour avant
de poster (encadré « Avant de poster » de chaque section).

Liens à employer partout :

- App Store : <https://apps.apple.com/app/id6793097336>
- Google Play : <https://play.google.com/store/apps/details?id=com.maeder.chesslab>
- Site : <https://thmaed.github.io/ChessLab/>
- Code source : <https://github.com/thmaed/ChessLab>

**Chiffre des puzzles** : la 2.0 en vente en compte 106 094 ; les messages disent donc
« plus de 100 000 ». Passer à « plus de 130 000 » seulement quand la version suivante
(130 935 puzzles) sera en vente — comme le texte promotionnel de l'App Store.

Trois principes, pour que ces messages aident au lieu de lasser :

1. **Dire qu'on est le développeur**, dès la première ligne. Une promotion déguisée se
   repère et se paie.
2. **Un message par communauté, adapté à elle**, jamais le même texte collé partout.
3. **Rester répondre** les premières heures : les questions et les retours font plus
   pour la visibilité que le message lui-même.

Calendrier suggéré : un message tous les deux ou trois jours, pas tous le même jour.
Commencer par r/chessbeginners et la lettre à l'équipe Maia (les plus sûrs), garder
Show HN pour un jour de semaine, vers 15 h (heure de Paris).

---

## 1. Reddit — r/chessbeginners (anglais)

> **NE PAS POSTER** (vérifié le 29/10/2026) : la règle 3 de r/chessbeginners interdit
> toute auto-promotion, retrait automatique, bannissement des comptes qui en vivent.
> Seule voie : demander d'abord l'accord des modérateurs par message (modmail).

**Titre**

> I'm building a 100% free chess trainer as a hobby: bots that play like humans, Stockfish to explain your mistakes, 100k puzzles. What should I improve?

**Texte**

> Hi everyone! I'm the developer, so I'm biased. But one thing first: this is a pure
> hobby project. No ads, no subscription, no in-app purchases, no account. I don't make
> a cent from it and I don't intend to. My goal is simply to build the best chess
> training app I can, and keep it completely free.
>
> **How it works**
>
> - **The bots play like humans.** They're powered by Maia-3, a neural network from the
>   University of Toronto trained on millions of real games. You pick a level and the bot
>   plays the moves a human of that rating would play, mistakes included. It feels very
>   different from a weakened engine that plays perfectly for ten moves and then hangs
>   its queen for no reason.
> - **Stockfish does the evaluation.** After the game, every move is graded, and when you
>   went wrong the app tells you why in one plain sentence. Your own mistakes can then be
>   replayed as puzzles.
>
> **Puzzles**
>
> - Over 100,000 puzzles from the Lichess database, sorted by level and by theme.
> - Your puzzle rating follows your results, so the series stay at your level.
> - The puzzles you miss come back a few days later until they stick.
> - A Woodpecker mode if you like drilling the same set again and again.
>
> There are also opening and endgame courses and a short daily session. Everything runs
> on the device, offline: iPhone, iPad and Android. The code is open source (GPLv3).
>
> **This is where I need you.** What's confusing? What's missing? What would make you
> open it every day? I read everything, and several features in the app already came
> from players' emails. Links in the first comment.

*(Premier commentaire : les deux liens des stores et le site.)*

---

## 2. Reddit — r/chess (anglais)

> **Avant de poster** : r/chess est strict sur l'auto-promotion (souvent limitée à un
> fil ou à certains jours). Si un fil « Self-promotion » ou « Weekly apps » existe, y
> poster plutôt qu'en sujet.

**Titre**

> Open-source chess trainer with human-like opponents (Maia-3) that runs fully offline

**Texte**

> Developer here. ChessLab is a free, ad-free chess app for iPhone, iPad and Android
> that runs entirely on the device:
>
> - Nine opponents played by **Maia-3** (University of Toronto), so they play the moves a
>   human of that rating would — including the blunders — rather than a weakened
>   Stockfish.
> - **Stockfish analysis** with every move graded and the mistake explained in plain words.
> - **58 opening courses** with spaced repetition, **78 endgame lessons** checked against
>   tablebases, **100k+ Lichess puzzles**, and 12 variants (Chess960, Atomic, Crazyhouse,
>   Duck Chess…).
> - Photo/screenshot **board scanner**, also on-device.
>
> No account, no tracking; the Android build doesn't even request the internet
> permission. Source code is on GitHub (GPLv3). Happy to answer anything about how it's
> built.

---

## 3. Reddit — r/AndroidApps (anglais)

> **Avant de poster** : ce subreddit demande en général le préfixe **[DEV]** dans le titre
> pour un développeur qui présente son app, et souvent une phrase sur la confidentialité.

**Titre**

> [DEV] ChessLab — free chess trainer, no ads, no account, no internet permission

**Texte**

> Hi, I'm the developer. ChessLab is a complete chess app — play, analyse, train — that
> works entirely offline. It's not "offline mode": the app doesn't request Android's
> INTERNET permission at all, so it *can't* send anything. You can check it in the Play
> Store's permission list.
>
> What's inside: opponents that play like humans (Maia-3 neural network), Stockfish
> analysis that explains mistakes, opening and endgame courses, 100k+ puzzles, a daily
> review session and 12 variants. Free, no ads, no in-app purchases, open source (GPLv3).
>
> Play Store: https://play.google.com/store/apps/details?id=com.maeder.chesslab
>
> Feedback very welcome, especially from tablet users.

---

## 4. Hacker News — Show HN (anglais)

> **Avant de poster** : le titre commence par « Show HN: ». Lien vers le site (ou le dépôt),
> pas vers un store. Rester disponible pour répondre dans les heures qui suivent.

**Titre**

> Show HN: ChessLab – an offline chess trainer with Maia-3 and Stockfish on-device

**URL** : <https://thmaed.github.io/ChessLab/>

**Premier commentaire (de l'auteur)**

> I built ChessLab, a chess training app for iOS and Android whose design constraint is
> "nothing leaves the device": no account, no server, and the Android build doesn't
> declare the INTERNET permission at all.
>
> Some details that might interest people here:
>
> - Opponents are **Maia-3** (CSSLab, University of Toronto), a model trained to predict
>   human moves at a given rating. On iOS it runs through Core ML, on Android through
>   ONNX Runtime.
> - **Stockfish** is embedded natively on both platforms for analysis; the app explains a
>   mistake in one sentence and only names what's visible on the board.
> - A **board scanner** reads a photo or screenshot with an on-device detector.
> - The iOS app is the reference and the Android port follows it feature for feature;
>   the parity list is a document in the repo.
> - GPLv3, source on GitHub. The 100k+ puzzles come from the Lichess CC0 database.
>
> I'd love feedback on the training design, and on anything that feels off.

---

## 5. Forum Lichess (anglais)

> **Avant de poster** : choisir le forum « General Chess Discussion » ou « Off-Topic »
> selon les règles ; le ton promotionnel y est mal reçu, insister sur ce qui est rendu à
> la communauté (licence libre, crédits).

**Titre**

> A free, open-source offline trainer built on Lichess's puzzle database

**Texte**

> Hello! I'm the developer of ChessLab, a free and open-source (GPLv3) chess trainer for
> iPhone, iPad and Android. Its 100,000+ puzzles come from the Lichess puzzle database
> (CC0) — thank you for publishing it; the app credits it.
>
> It's meant as an offline companion: human-like opponents (Maia-3), Stockfish analysis
> that explains mistakes, opening and endgame courses, and a daily review session. No
> account, no ads, nothing sent anywhere.
>
> Site and links: https://thmaed.github.io/ChessLab/
>
> If you try it, I'm interested in what you think of the puzzle training in particular.

---

## 6. Lettre à l'équipe Maia — CSSLab, Université de Toronto (anglais)

> **Avant d'envoyer** : trouver l'adresse de contact actuelle sur le site du CSSLab ou du
> projet Maia. Lettre courte : ils reçoivent beaucoup de messages.

**Objet**

> ChessLab: an open-source mobile app using Maia-3 on-device

**Texte**

> Hello,
>
> I'm the developer of ChessLab, a free, open-source (GPLv3) chess training app for iOS
> and Android. Its nine computer opponents are played by Maia-3, running fully on the
> device (Core ML on iOS, ONNX Runtime on Android), so players face moves a human of
> their level would make.
>
> I wanted to thank you for releasing Maia-3 under an open licence, and let you know how
> it's being used. The app credits the project and the AGPLv3 licence, and the source is
> at https://github.com/thmaed/ChessLab.
>
> If it's ever useful to you as an example of Maia on phones, I'd be glad to share any
> details or measurements.
>
> Best regards,
> Thierry Maeder

---

## 7. Reddit — r/echecs (français)

> **Avant de poster** : petite communauté francophone ; vérifier les règles, poster en
> texte.

**Titre**

> J'ai créé une app d'échecs gratuite, sans pub et sans compte — vos retours m'intéressent

**Texte**

> Bonjour ! Je suis le développeur de ChessLab, une app d'échecs gratuite pour iPhone,
> iPad et Android, pensée en français dès le départ.
>
> - Des adversaires qui jouent **comme des humains** de votre niveau (le réseau Maia-3),
>   gaffes comprises.
> - Une **analyse qui explique** pourquoi un coup était mauvais, et qui transforme vos
>   erreurs en puzzles.
> - 58 ouvertures et 78 finales en cours, plus de **100 000 puzzles**, une séance du jour.
>
> Tout tourne sur l'appareil : aucun compte, rien n'est envoyé. Code ouvert (GPLv3).
>
> Je cherche surtout des retours de joueurs de club : qu'est-ce qui vous manque, qu'est-ce
> qui n'est pas clair ? Liens en commentaire.

---

## 8. Lettre aux clubs d'échecs (français)

> **Avant d'envoyer** : à un club à la fois, adressée à la personne qui s'occupe des
> jeunes ou de la formation ; mentionner le club par son nom.

**Objet**

> Une app gratuite pour l'entraînement de vos joueurs

**Texte**

> Bonjour,
>
> Je suis le développeur de ChessLab, une app d'échecs gratuite pour iPhone, iPad et
> Android, sans publicité et sans compte — rien n'est collecté, ce qui la rend simple à
> recommander à des jeunes.
>
> Elle propose des cours d'ouvertures et de finales, plus de 100 000 puzzles classés par
> niveau, une analyse qui explique les erreurs, et des adversaires à la mesure de chaque
> joueur. Un mode deux joueurs sur le même appareil permet aussi de jouer au club.
>
> Si elle peut servir à vos joueurs, je serais heureux d'avoir votre avis, et d'ajuster ce
> qui manquerait pour un usage en club.
>
> Site : https://thmaed.github.io/ChessLab/
>
> Bien à vous,
> Thierry Maeder

---

## 9. Créateurs de contenu échecs (anglais / français)

> **Avant d'envoyer** : choisir des chaînes de taille moyenne qui parlent d'apps ou
> d'entraînement ; un message personnalisé (citer une vidéo récente) par chaîne.

**Texte (anglais)**

> Hi [name], I enjoyed your video on [topic]. I'm the developer of ChessLab, a free,
> ad-free chess trainer (iOS and Android) whose opponents are played by Maia-3, so they
> make the mistakes a human of your viewers' level would. Everything runs offline and it's
> open source. If it ever fits a video on training tools, I'd be happy to answer
> questions — no strings attached. https://thmaed.github.io/ChessLab/

**Texte (français)**

> Bonjour [nom], j'ai aimé votre vidéo sur [sujet]. Je développe ChessLab, une app
> d'échecs gratuite et sans pub (iOS et Android), dont les adversaires jouent comme des
> humains de votre niveau grâce au réseau Maia-3. Tout fonctionne hors ligne et le code
> est ouvert. Si elle trouve sa place dans une vidéo sur l'entraînement, je réponds
> volontiers à vos questions — sans contrepartie. https://thmaed.github.io/ChessLab/
