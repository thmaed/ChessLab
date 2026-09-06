# Notes de version — ChessLab 1.8.0

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> ⏳ **PAS ENCORE SOUMISE.** Couvre la 1.7.1 (jamais partie : visite guidée, analyses de variantes, stabilité moteur) PLUS la 1.8.0 des 5-6/09/2026 : les personnages joués par Maia-3. Build : 11. Si la 1.7.1 part avant, retirer d'ici ce qui lui appartient.

---

## Français

**Neuf personnages à affronter**

Le mode « Contre l'ordinateur » propose désormais deux façons de choisir son adversaire : le niveau Elo de Stockfish, inchangé, ou un **personnage**. Neuf sont dessinés et prêts : **Lena « Tornade »** l'attaquante, **Nils « Béton »** le mur, **Milo « Gambit »** le romantique, **Nadia « Finale »** la technicienne, **Sacha « Traquenard »** le piégeur, **Ana « Ressort »** la contre-attaquante, **Yuri « Grippe-sou »** le matérialiste, **Pablo « Yolo »** l'impulsif, et **Maia « Neutre »**, le réseau tel quel, l'étalon.

Ils sont joués par **Maia-3**, un réseau de neurones entraîné par l'Université de Toronto sur des millions de parties humaines, qui ne cherche pas le meilleur coup mais le coup qu'un humain de tel niveau jouerait. À 800 il laisse des pièces en prise et tombe dans le mat du berger une fois sur cinq ; à 2 200 presque jamais. Il tourne entièrement sur l'appareil, sans réseau, en quelques millisecondes.

Chaque personnage ajoute son caractère à cette base : un **style** (treize traits de coup — échec, capture, sacrifice, coup vers le roi, roque, échange, pion faible, tension… — pondérés et bornés, pour colorer la distribution humaine sans jamais acheter une gaffe), un **répertoire d'ouvertures** propre (Milo joue le Gambit du roi et le Budapest, Nils le London et la Caro-Kann, Nadia la Catalane et le Berlin…), un **tempérament** (rythme, seuil d'abandon, propositions de nulle, et une humeur qui change avec le score : Nils se calme quand il mène, Ana s'anime quand elle perd), et une illustration.

**Le niveau, sur l'échelle humaine**

Le niveau d'un personnage se règle au curseur et se mémorise par personnage. Il suit l'échelle humaine de Maia, proche de celle de Lichess : un personnage à 1 500 joue comme un joueur de 1 500. Ce n'est PAS l'échelle du mode « Niveau Elo » : Stockfish bridé à 1 500 est nettement plus fort qu'un humain de 1 500, parce qu'il ne laisse jamais une pièce en prise et voit toute tactique courte. L'app le dit sur la carte de chaque personnage plutôt que de laisser croire que les deux chiffres se comparent.

**Stockfish reste l'analyste, et assure derrière**

Indice, alerte en cas de coup risqué, barre d'évaluation et analyse de fin de partie : rien ne change, c'est toujours Stockfish. Pendant une partie contre un personnage, il n'intervient que dans quatre cas, tous écrits dans l'Aide : un mat en un ou deux disponible (dès le niveau 1 400), une finale à sept pièces ou moins (dès 1 600, Stockfish bridé au niveau du personnage), une répétition ou la règle des cinquante coups en position gagnée, et le modèle indisponible. L'écran de fin compte ces interventions.

**Progrès, Laboratoire, Aide**

L'écran Progrès affiche votre bilan par personnage, avec le plus haut niveau battu. Au Laboratoire, un camp peut être joué par Maia pour mesurer un personnage contre Stockfish. L'Aide et la visite guidée présentent les personnages ; l'écran Licences mentionne Maia-3 (AGPLv3).

**Variantes : la force au-delà de 2 850**

Fairy-Stockfish n'accepte un Elo qu'entre 500 et 2 850 ; au-delà, le réglage était rejeté en silence et l'adversaire retombait à 1 350 sans le dire. Désormais, au-dessus de 2 850, plus de bridage du tout, comme le maximum de Stockfish.

---

## English

**Nine characters to face**

The "Against the computer" mode now offers two ways to pick an opponent: Stockfish's Elo level, unchanged, or a **character**. Nine are drawn and ready: **Lena "Tornado"** the attacker, **Nils "Concrete"** the wall, **Milo "Gambit"** the romantic, **Nadia "Endgame"** the technician, **Sacha "Trap"** the trapper, **Ana "Spring"** the counter-attacker, **Yuri "Penny-pincher"** the materialist, **Pablo "Yolo"** the impulsive one, and **Maia "Neutral"**, the network as is, the reference.

They are played by **Maia-3**, a neural network trained at the University of Toronto on millions of human games, which does not look for the best move but for the move a human of a given level would play. At 800 it hangs pieces and falls for the scholar's mate one time in five; at 2200 almost never. It runs entirely on the device, offline, in a few milliseconds.

Each character adds their own temper on top: a **style** (thirteen move traits — check, capture, sacrifice, move toward the king, castling, trade, weak pawn, tension… — weighted and bounded, to colour the human distribution without ever buying a blunder), their own **opening repertoire** (Milo plays the King's Gambit and the Budapest, Nils the London and the Caro-Kann, Nadia the Catalan and the Berlin…), a **temperament** (pace, resignation threshold, draw offers, and a mood that shifts with the score: Nils calms down when ahead, Ana livens up when behind), and an illustration.

**The level, on the human scale**

A character's level is set with the slider and remembered per character. It follows Maia's human scale, close to Lichess's: a character at 1500 plays like a 1500 player. This is NOT the "Elo level" mode's scale: Stockfish limited to 1500 is much stronger than a 1500 human, because it never hangs a piece and sees every short tactic. The app says so on each character's card rather than letting the two numbers look comparable.

**Stockfish remains the analyst, and the safety net**

Hints, risky-move warning, evaluation bar and post-game analysis: nothing changes, it is still Stockfish. During a game against a character it only steps in in four cases, all written in Help: a mate in one or two available (from level 1400), an endgame with seven pieces or fewer (from 1600, Stockfish limited to the character's level), a repetition or the fifty-move rule in a won position, and the model being unavailable. The end-of-game screen counts these interventions.

**Progress, Lab, Help**

The Progress screen shows your record against each character, with the highest level beaten. In the Lab, one side can be played by Maia to measure a character against Stockfish. Help and the guided tour introduce the characters; the Licenses screen mentions Maia-3 (AGPLv3).

**Variants: strength above 2850**

Fairy-Stockfish only accepts an Elo between 500 and 2850; above that, the setting was silently rejected and the opponent dropped to 1350 without saying so. Now, above 2850, the strength is no longer limited at all, like Stockfish's maximum.

---

## Notes internes (ne pas coller dans App Store Connect)

- **Version et build — FIXÉS le 06/09.** `MARKETING_VERSION = 1.8.0`, `CURRENT_PROJECT_VERSION = 11` aux deux configurations de la cible applicative. Vérifier au `git diff` avant l'archive que l'IDE n'a pas fait dériver le build.

- **Ce que Maia-3 est, sur pièces.** Transformeur encodeur à 64 jetons (une case chacun), entrée = 12 plans de pièces × 8 positions d'historique par case, plateau retourné quand les Noirs jouent, ni droits de roque ni en passant (inférés de l'historique) ; deux Elo continus (soi, adversaire) ; sortie = 4 352 logits + une tête W/D/L humaine. Modèle 23M (22,9 M de paramètres, 56,6 % de coups humains prédits) converti en Core ML fp16 : 43 Mo, dans `ChessLab/Maia3_23M.mlpackage` — le 5M (10 Mo, 55,4 %) a servi au spike et a été remplacé le 06/09. Calcul forcé sur CPU : le GPU du simulateur rend des logits de coups nuls en fp16 (mesuré, `MaiaModel.swift`). Encodeur, coups légaux et modèle prouvés sur 56 fixtures générées par l'implémentation de référence (`MaiaFixtureTests`).

- **Licence.** Maia-3 est AGPLv3, code et poids. Compatible avec le binaire GPLv3 (GPLv3 §13), aucun service réseau. Texte intégral et provenance dans `Vendor/Maia3/`, entrée dans l'écran Licences, mention à ajouter aux notes réviseurs (faite dans `METADATA.md`).

- **Pourquoi le niveau ne suit pas l'échelle Stockfish.** Mesuré au Laboratoire (`tools/maia3-spike/calibration/`) : Camille réglée sur 2 200 fait 18 % contre Stockfish bridé à « 1 100 » (Skill Level 3, profondeur 4). Aucune consigne ne rattrape les paliers bas. La courbe consigne → niveau prévue par l'étude est abandonnée ; le niveau affiché est celui de Maia, et la carte le dit.

- **Taille du bundle.** +43 Mo (modèle 23M) +74 Ko (répertoires) +neuf portraits PNG. Ressources à ~145 Mo, sous le seuil cellulaire de 200 Mo.

- **Captures et vidéos.** Aucune capture ne montre encore la galerie des personnages — c'est l'image la plus parlante de cette version, à ajouter (`AppStoreScreenshotUITests`, écran Nouvelle partie en mode Personnage).
