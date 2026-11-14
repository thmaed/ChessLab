# Métadonnées App Store Connect — ChessLab

**Version courante : 2.3, build 24** (fixés dans `project.pbxproj`). La 2.2 (build 22) est EN VENTE (READY_FOR_SALE, vérifié par `asc.py status` le 14/11/2026). Voir `RELEASE_NOTES-2.3.md` pour le détail. **Préparée le 14/11/2026 : fiche à cinq langues (fr-FR, en-GB, es-ES, de-DE, it-IT), nouveautés et notes de révision posées dans App Store Connect (version 2.3) ; le build n'est PAS archivé ni téléversé, la version n'est PAS soumise (attendre l'accord de Thierry). Les textes es/de/it attendent une relecture par un locuteur natif ; leurs captures et aperçus ne sont pas faits.**

> **Variantes régionales (14/11/2026)** — en-AU, en-CA (texte de l'anglais UK), es-MX (texte de es-ES), fr-CA (texte de fr-FR) et **en-US** reprennent le texte de leur langue-source, sans rien réécrire (`VARIANTS` dans `tools/asc/asc.py`). « ChessLab » seul est PRIS en en-US, en allemand et en italien : la fiche américaine s'appelle **« ChessLab: Chess Trainer »**, l'allemande « ChessLab Schach », l'italienne « ChessLab Scacchi ». Le nom sous l'icône reste « ChessLab ». Visuels : es-MX et fr-CA ont leur jeu (celui de es-ES / fr-FR) ; les variantes anglaises reprennent ceux de la langue principale (en-GB).

Tout ce qui suit est à copier-coller directement dans les champs correspondants d'App Store Connect. Les limites de caractères d'Apple sont respectées (vérifiées).

> **Convention d'édition** : dans les blocs à coller, JAMAIS de retour à la ligne à l'intérieur d'un paragraphe — App Store Connect rend chaque saut de ligne tel quel, une césure à 78 colonnes hacherait le texte sur la fiche. Une ligne par paragraphe ; les titres EN CAPITALES gardent leur propre ligne.

> **Révisé le 29/09/2026** — la description annonçait « sept variantes de plus » dans les deux langues, alors que le hub en compte douze depuis la 1.8 : Crazyhouse, Duck Chess, Barricades et Barricades aléatoires y sont entrées sans que la description permanente suive (la fiche Google Play, elle, avait été corrigée le 19/09). Corrigé ici, les deux descriptions vérifiées sous la limite. Captures et aperçus vidéo de la 1.8 conservés — rien du contenu n'a changé.

---

## Nouveautés de cette version — 2.3 (4000 car. max)

C'est le champ « What's New in This Version ». Rédigé pour l'utilisateur final : ce qu'il va sentir, pas ce qui a été refactorisé. Un texte par langue de la fiche (fr-FR, en-GB, es-ES, de-DE, it-IT) ; les trois derniers sont à faire relire par un locuteur natif.

> Version 2.3, build 23. Contenu : espagnol, allemand et italien complets (interface, aide, cours d'ouvertures et de finales, noms d'ouvertures), sélecteur de langue en pastilles (option « Automatique »), noms des joueurs par défaut traduits en mode Deux joueurs. Détail dans `RELEASE_NOTES-2.3.md`.

### Français

```
CHESSLAB 2.3

CINQ LANGUES, COMPLÈTES
ChessLab parle maintenant français, anglais, espagnol, allemand et italien : toute l'interface, l'aide, tous les cours d'ouvertures et de finales expliqués coup par coup, et les noms des ouvertures. Choisissez la langue dans Réglages, ou laissez « Automatique » suivre celle de l'appareil.

La notation des coups suit la langue (R D T F C en français, K Q R B N en anglais, R D T A C en espagnol et en italien, K D T L S en allemand) et se règle à part si vous préférez.

UN CHOIX DE LANGUE PLUS SIMPLE
Les langues se choisissent d'un toucher sur de petites pastilles, toutes visibles d'un coup d'œil.

DEUX JOUEURS
Les noms par défaut des joueurs (Blancs, Noirs) s'affichent maintenant dans la langue choisie.
```

### English

```
CHESSLAB 2.3

FIVE LANGUAGES, COMPLETE
ChessLab now speaks French, English, Spanish, German and Italian: the whole interface, the help, every opening and endgame course explained move by move, and the opening names. Pick your language in Settings, or leave it on “Automatic” to follow your device.

Move notation follows the language (K Q R B N in English, R D T F C in French, R D T A C in Spanish and Italian, K D T L S in German) and can be set separately if you prefer.

A SIMPLER LANGUAGE PICKER
Languages are chosen with a tap on small chips, all visible at a glance.

TWO PLAYERS
The default player names (White, Black) now appear in the language you chose.
```

### Español

```
CHESSLAB 2.3

CINCO IDIOMAS, COMPLETOS
ChessLab ahora habla francés, inglés, español, alemán e italiano: toda la interfaz, la ayuda, todos los cursos de aperturas y finales explicados jugada a jugada y los nombres de las aperturas. Elige el idioma en Ajustes, o deja «Automático» para seguir el del dispositivo.

La notación de las jugadas sigue el idioma (R D T A C en español y en italiano, K Q R B N en inglés, R D T F C en francés, K D T L S en alemán) y se puede ajustar por separado si lo prefieres.

UN SELECTOR DE IDIOMA MÁS SENCILLO
Los idiomas se eligen con un toque en pequeñas pastillas, todas visibles de un vistazo.

DOS JUGADORES
Los nombres por defecto de los jugadores (Blancas, Negras) aparecen ahora en el idioma elegido.
```

### Deutsch

```
CHESSLAB 2.3

FÜNF SPRACHEN, VOLLSTÄNDIG
ChessLab spricht jetzt Französisch, Englisch, Spanisch, Deutsch und Italienisch: die gesamte Oberfläche, die Hilfe, alle Eröffnungs- und Endspielkurse Zug für Zug erklärt und die Namen der Eröffnungen. Wähle die Sprache in den Einstellungen oder lass „Automatisch“ der Sprache deines Geräts folgen.

Die Zugnotation folgt der Sprache (K D T L S auf Deutsch, K Q R B N auf Englisch, R D T F C auf Französisch, R D T A C auf Spanisch und Italienisch) und lässt sich bei Bedarf getrennt einstellen.

EINFACHERE SPRACHAUSWAHL
Die Sprachen wählst du mit einem Tipp auf kleine Chips, alle auf einen Blick sichtbar.

ZWEI SPIELER
Die Standardnamen der Spieler (Weiß, Schwarz) erscheinen jetzt in der gewählten Sprache.
```

### Italiano

```
CHESSLAB 2.3

CINQUE LINGUE, COMPLETE
ChessLab ora parla francese, inglese, spagnolo, tedesco e italiano: tutta l'interfaccia, la guida, tutti i corsi di aperture e di finali spiegati mossa per mossa e i nomi delle aperture. Scegli la lingua in Impostazioni, oppure lascia «Automatico» per seguire quella del dispositivo.

La notazione delle mosse segue la lingua (R D T A C in italiano e in spagnolo, K Q R B N in inglese, R D T F C in francese, K D T L S in tedesco) e si può impostare a parte se preferisci.

UN SELETTORE DI LINGUA PIÙ SEMPLICE
Le lingue si scelgono con un tocco su piccoli chip, tutti visibili a colpo d'occhio.

DUE GIOCATORI
I nomi predefiniti dei giocatori (Bianco, Nero) compaiono ora nella lingua scelta.
```

---

## Français (langue principale)

**Nom de l'app** (30 car. max) :
```
ChessLab
```

**Sous-titre** (30 car. max — 30 utilisés) :
```
Jeu d'échecs, analyse, puzzles
```
_29/10/2026 (ASO) : les mots que l'on CHERCHE (« jeu d'échecs », « analyse », « puzzles ») plutôt
qu'une formule ; ils comptent comme mots-clés, qui n'ont donc plus à les répéter. Pas de « gratuit »
ici : Apple refuse les informations tarifaires dans le sous-titre et les mots-clés (règle 2.3.7)._

**Mots-clés** (100 car. max — 95 utilisés, séparés par des virgules, sans espace) :
```
stockfish,maia,tactique,ouverture,finale,entrainement,chess960,coach,elo,pgn,adversaire,scanner
```

**Texte promotionnel** (170 car. max — modifiable sans nouvelle revue) :
_En ligne sur la 2.0 depuis le 29/10/2026 avec « plus de 100 000 puzzles » (la 2.0 en a 106 094) ;
le texte ci-dessous, à 130 000, part avec la version suivante._
```
Sans publicité, sans compte, sans réseau. Neuf adversaires qui jouent comme des humains, l'analyse Stockfish et plus de 130 000 puzzles — tout sur votre appareil.
```

**Description** (4000 car. max) :
```
Entièrement gratuite, sans publicité, sans compte : rien ne quitte votre appareil.

ChessLab est un compagnon d'échecs complet pour iPhone et iPad : jouer, analyser, s'entraîner et expérimenter, avec Stockfish intégré, sans jamais quitter l'app.

DES ADVERSAIRES QUI JOUENT COMME DES HUMAINS
Neuf personnages joués par Maia-3, un réseau entraîné sur des millions de parties humaines : il ne cherche pas le meilleur coup, il joue celui qu'un humain de ce niveau jouerait, gaffes comprises. Chacun a son style, son répertoire et son tempérament, et un niveau réglable sur l'échelle humaine. Ou affrontez Stockfish, du débutant (~900 Elo) au maximum (~3190). Pendule en option, indice, alerte avant un coup risqué et barre d'évaluation à volonté.

ANALYSER ET COMPRENDRE
Chaque coup est classé (imprécision, erreur, gaffe, coup brillant…), chaque joueur reçoit sa précision, et l'app dit pourquoi un coup était mauvais. Le Coach ajoute la part des joueurs de votre niveau qui le jouent. À la fin, elle propose de transformer vos erreurs et vos mats manqués en puzzles. Entrée par PGN, FEN, éditeur de position ou scanner photo.

SÉANCE DU JOUR
Chaque jour, ce qu'il faut revoir : positions d'ouverture dues, puzzles ratés, une finale. Une série de jours et des médailles pour tenir la durée.

OUVERTURES
58 ouvertures rédigées à la main (multilingues) et relues au moteur : chaque coup est expliqué, des flèches colorées relient le plateau à la liste, et la répétition espacée les ancre. Importez aussi vos propres répertoires en PGN.

FINALES
78 cours prouvés par table de finales : aucun coup enseigné ne lâche le gain, aucune défense proposée ne perd la nulle. Et l'entraînement libre, où tout coup qui préserve le verdict est accepté.

PUZZLES
Plus de 130 000 problèmes de la base Lichess, filtrables par niveau et par thème, plus les vôtres : tirés de vos erreurs, ou importés de vos propres fichiers PGN. Cote personnelle et « À mon niveau ».

VARIANTES ET PLUS
Chess960 et onze variantes contre l'ordinateur (Roi de la colline, Trois échecs, Horde, Atomique, Crazyhouse, Duck Chess, Barricades…), chacune avec sa propre analyse. Mode deux joueurs, et Laboratoire pour comparer deux réglages de Stockfish.

IPHONE ET IPAD
Grand échiquier et panneaux côte à côte sur iPad, clavier et trackpad, portrait et paysage. En français, anglais, espagnol, allemand et italien. Synchronisation iCloud optionnelle, désactivée par défaut.

VIE PRIVÉE
Hors ligne par défaut : aucun serveur ChessLab, aucune mesure d'audience, aucune publicité. Vos parties restent sur votre appareil.

ChessLab intègre le moteur Stockfish (licence GPLv3), le réseau Maia-3 de l'Université de Toronto (licence AGPLv3) et des jeux de pièces vectorielles libres — cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) et merida (GPLv2+). Code source complet et mentions de licence disponibles depuis l'app (Réglages → Licences).
```

---

## English (secondary localization — App Store Connect: "English (U.K.)", en-GB — la fiche a toujours été en anglais britannique ; un « English (U.S.) » neuf est refusé, le nom « ChessLab » y étant pris par une autre app)

**Name** (30 char. max):
```
ChessLab
```

**Subtitle** (30 char. max — 29 used):
```
Chess game, analysis, puzzles
```

**Keywords** (100 char. max — 97 used):
```
stockfish,maia,tactics,openings,endgame,training,chess960,coach,elo,pgn,opponent,scanner,variants
```

**Promotional text** (170 char. max):
```
No ads, no account, no network. Nine opponents who play like humans, Stockfish analysis and over 130,000 puzzles — all on your device.
```

**Description** (4000 char. max):
```
Completely free, no ads, no account: nothing leaves your device.

ChessLab is a complete chess companion for iPhone and iPad: play, analyse, train and experiment, with Stockfish built in, without ever leaving the app.

OPPONENTS THAT PLAY LIKE HUMANS
Nine characters played by Maia-3, a network trained on millions of human games: it does not look for the best move, it plays the one a human of that level would play, blunders included. Each has a style, a repertoire and a temperament, and a level set on the human scale. Or take on Stockfish, from beginner (~900 Elo) to maximum (~3190). Optional clock, hints, a warning before risky moves and an evaluation bar, all on demand.

ANALYSE AND UNDERSTAND
Every move is graded (inaccuracy, mistake, blunder, brilliant…), each player gets an accuracy score, and the app tells you why a move was bad. The Coach adds the share of players at your level who play it. At the end, it offers to turn your mistakes and missed mates into puzzles. Load a game by PGN, FEN, position editor or photo scanner.

DAILY SESSION
Every day, what to review: opening positions that are due, missed puzzles, an endgame. A streak of days and medals to keep you going.

OPENINGS
58 hand-written openings (multilingual), checked against the engine: every move is explained, coloured arrows tie the board to the move list, and spaced repetition makes them stick. Import your own repertoires as PGN too.

ENDGAMES
78 courses proven by endgame tablebases: no move taught gives up a win, no defence offered loses a draw. Plus free training, where any move that keeps the verdict is accepted.

PUZZLES
Over 130,000 problems from the Lichess database, filtered by level and theme, plus your own: drawn from your mistakes, or imported from your own PGN files. Personal rating and “At my level”.

VARIANTS AND MORE
Chess960 and eleven variants against the computer (King of the Hill, Three-Check, Horde, Atomic, Crazyhouse, Duck Chess, Barricades…), each with its own analysis. Two-player mode, and a Laboratory to compare two Stockfish settings.

IPHONE AND IPAD
A large board with side-by-side panels on iPad, keyboard and trackpad, portrait and landscape. In French, English, Spanish, German and Italian. Optional iCloud sync, off by default.

PRIVACY
Offline by default: no ChessLab server, no analytics, no ads. Your games stay on your device.

ChessLab embeds the Stockfish engine (GPLv3 license), the University of Toronto's Maia-3 network (AGPLv3 license) and free vector piece sets — cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) and merida (GPLv2+). Full source code and license notices are available from within the app (Settings → Licenses).
```

---

## Español (España) — es-ES (2.3 — localisation à ajouter dans App Store Connect ; relue le 14/11/2026 par Claude Opus 5.5, faute de locuteur natif)

**Nombre** (30 car. max) :
```
ChessLab
```

**Subtítulo** (30 car. max — 26 utilisés) :
```
Ajedrez, análisis y puzles
```

**Palabras clave** (100 car. max — 90 utilisés) :
```
stockfish,maia,táctica,apertura,finales,entrenamiento,chess960,coach,elo,pgn,rival,escáner
```

**Texto promocional** (170 car. max — 149 utilisés) :
```
Sin publicidad, sin cuenta, sin red. Nueve rivales que juegan como humanos, el análisis de Stockfish y más de 130 000 puzles: todo en tu dispositivo.
```

**Descripción** (4000 car. max — 2888 utilisés) :
```
Totalmente gratuita, sin publicidad, sin cuenta: nada sale de tu dispositivo.

ChessLab es un compañero de ajedrez completo para iPhone y iPad: jugar, analizar, entrenar y experimentar, con Stockfish integrado, sin salir nunca de la app.

ADVERSARIOS QUE JUEGAN COMO HUMANOS
Nueve personajes interpretados por Maia-3, una red entrenada con millones de partidas humanas: no busca la mejor jugada, sino la que jugaría un humano de ese nivel, errores incluidos. Cada uno tiene su estilo, su repertorio y su temperamento, y un nivel ajustable en la escala humana. O enfréntate a Stockfish, del principiante (~900 Elo) al máximo (~3190). Reloj opcional, pista, aviso antes de una jugada arriesgada y barra de evaluación a voluntad.

ANALIZAR Y ENTENDER
Cada jugada se clasifica (imprecisión, error, error grave, jugada brillante…), cada jugador recibe su precisión y la app explica por qué una jugada era mala. El Coach añade la proporción de jugadores de tu nivel que la juegan. Al final propone convertir tus errores y tus mates perdidos en puzles. Entrada por PGN, FEN, editor de posiciones o escáner de fotos.

SESIÓN DIARIA
Cada día, lo que hay que repasar: posiciones de apertura pendientes, puzles fallados, un final. Una racha de días y medallas para mantener el ritmo.

APERTURAS
58 aperturas escritas a mano (en cinco idiomas) y revisadas con el motor: cada jugada se explica, unas flechas de colores unen el tablero con la lista y la repetición espaciada las fija. Importa también tus propios repertorios en PGN.

FINALES
78 cursos demostrados con tablas de finales: ninguna jugada enseñada deja escapar la victoria, ninguna defensa propuesta pierde las tablas. Y el entrenamiento libre, donde se acepta toda jugada que conserve el veredicto.

PUZLES
Más de 130 000 problemas de la base de Lichess, filtrables por nivel y por tema, más los tuyos: sacados de tus errores o importados de tus propios archivos PGN. Puntuación personal y «A mi nivel».

VARIANTES Y MÁS
Chess960 y once variantes contra el ordenador (Rey de la colina, Tres jaques, Horda, Atómico, Crazyhouse, Duck Chess, Barricadas…), cada una con su propio análisis. Modo de dos jugadores y Laboratorio para comparar dos ajustes de Stockfish.

IPHONE Y IPAD
Tablero grande y paneles lado a lado en iPad, teclado y trackpad, vertical y horizontal. En francés, inglés, español, alemán e italiano. Sincronización iCloud opcional, desactivada por defecto.

PRIVACIDAD
Sin conexión por defecto: ningún servidor de ChessLab, ninguna medición de audiencia, ninguna publicidad. Tus partidas se quedan en tu dispositivo.

ChessLab integra el motor Stockfish (licencia GPLv3), la red Maia-3 de la Universidad de Toronto (licencia AGPLv3) y juegos de piezas vectoriales libres: cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) y merida (GPLv2+). Código fuente completo y avisos de licencia disponibles desde la app (Ajustes → Licencias).
```

---

## Deutsch — de-DE (2.3 — localisation à ajouter dans App Store Connect ; relue le 14/11/2026 par Claude Opus 5.5, faute de locuteur natif)

**Name** (30 car. max — « ChessLab » seul est déjà pris par une autre app en allemand, constaté le 14/11/2026, comme en en-US) :
```
ChessLab Schach
```

**Untertitel** (30 car. max — 24 utilisés) :
```
Schach, Analyse, Puzzles
```

**Schlüsselwörter** (100 car. max — 87 utilisés) :
```
stockfish,maia,taktik,eröffnung,endspiel,training,chess960,coach,elo,pgn,gegner,scanner
```

**Werbetext** (170 car. max — 148 utilisés) :
```
Ohne Werbung, ohne Konto, ohne Netz. Neun Gegner, die wie Menschen spielen, die Stockfish-Analyse und über 130 000 Puzzles – alles auf deinem Gerät.
```

**Beschreibung** (4000 car. max — 2985 utilisés) :
```
Völlig kostenlos, ohne Werbung, ohne Konto: Nichts verlässt dein Gerät.

ChessLab ist ein kompletter Schachbegleiter für iPhone und iPad: spielen, analysieren, trainieren und experimentieren – mit eingebautem Stockfish, ohne die App je zu verlassen.

GEGNER, DIE WIE MENSCHEN SPIELEN
Neun Charaktere, gespielt von Maia-3, einem Netz, das auf Millionen menschlicher Partien trainiert wurde: Es sucht nicht den besten Zug, sondern den, den ein Mensch dieser Stärke spielen würde – Patzer inklusive. Jeder hat seinen Stil, sein Repertoire und sein Temperament, mit einstellbarer Stärke auf der menschlichen Skala. Oder tritt gegen Stockfish an, vom Anfänger (~900 Elo) bis zum Maximum (~3190). Optionale Uhr, Hinweis, Warnung vor einem riskanten Zug und Bewertungsbalken nach Wunsch.

ANALYSIEREN UND VERSTEHEN
Jeder Zug wird bewertet (Ungenauigkeit, Fehler, Patzer, brillanter Zug …), jeder Spieler erhält seine Genauigkeit, und die App sagt, warum ein Zug schlecht war. Der Coach ergänzt den Anteil der Spieler deiner Stufe, die ihn spielen. Am Ende schlägt sie vor, deine Fehler und verpassten Matts in Puzzles zu verwandeln. Eingabe per PGN, FEN, Stellungseditor oder Foto-Scanner.

TAGESTRAINING
Jeden Tag das, was zu wiederholen ist: fällige Eröffnungsstellungen, verfehlte Puzzles, ein Endspiel. Eine Tagesserie und Medaillen helfen dir, dranzubleiben.

ERÖFFNUNGEN
58 von Hand geschriebene Eröffnungen (in fünf Sprachen), von der Engine geprüft: Jeder Zug wird erklärt, farbige Pfeile verbinden Brett und Liste, und die verteilte Wiederholung verankert sie. Importiere auch eigene Repertoires als PGN.

ENDSPIELE
78 mit Endspieltabellen bewiesene Kurse: Kein gelehrter Zug gibt den Gewinn aus der Hand, keine empfohlene Verteidigung verliert das Remis. Dazu das freie Training, in dem jeder Zug zählt, der das Urteil bewahrt.

PUZZLES
Mehr als 130 000 Aufgaben aus der Lichess-Datenbank, filterbar nach Stufe und Thema, plus deine eigenen: aus deinen Fehlern erzeugt oder aus eigenen PGN-Dateien importiert. Persönliche Wertung und „Auf meiner Stufe“.

VARIANTEN UND MEHR
Chess960 und elf Varianten gegen den Computer (King of the Hill, Drei-Schach, Horde, Atomschach, Crazyhouse, Duck Chess, Barrikaden …), jede mit eigener Analyse. Zwei-Spieler-Modus und Labor, um zwei Stockfish-Einstellungen zu vergleichen.

IPHONE UND IPAD
Großes Brett und Bedienfelder nebeneinander auf dem iPad, Tastatur und Trackpad, Hoch- und Querformat. Auf Französisch, Englisch, Spanisch, Deutsch und Italienisch. Optionale iCloud-Synchronisierung, standardmäßig aus.

DATENSCHUTZ
Standardmäßig offline: kein ChessLab-Server, keine Reichweitenmessung, keine Werbung. Deine Partien bleiben auf deinem Gerät.

ChessLab enthält die Engine Stockfish (Lizenz GPLv3), das Netz Maia-3 der University of Toronto (Lizenz AGPLv3) und freie Vektor-Figurensätze: cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) und merida (GPLv2+). Vollständiger Quellcode und Lizenzhinweise sind in der App abrufbar (Einstellungen → Lizenzen).
```

---

## Italiano — it (2.3 — localisation à ajouter dans App Store Connect ; relue le 14/11/2026 par Claude Opus 5.5, faute de locuteur natif)

**Nome** (30 car. max — « ChessLab » seul est déjà pris par une autre app en italien, constaté le 14/11/2026 ; le code de langue Apple est `it`, pas `it-IT`) :
```
ChessLab Scacchi
```

**Sottotitolo** (30 car. max — 24 utilisés) :
```
Scacchi, analisi, puzzle
```

**Parole chiave** (100 car. max — 92 utilisés) :
```
stockfish,maia,tattica,apertura,finale,allenamento,chess960,coach,elo,pgn,avversario,scanner
```

**Testo promozionale** (170 car. max — 154 utilisés) :
```
Senza pubblicità, senza account, senza rete. Nove avversari che giocano come umani, l'analisi Stockfish e oltre 130 000 puzzle: tutto sul tuo dispositivo.
```

**Descrizione** (4000 car. max — 2987 utilisés) :
```
Totalmente gratuita, senza pubblicità, senza account: nulla esce dal tuo dispositivo.

ChessLab è un compagno di scacchi completo per iPhone e iPad: giocare, analizzare, allenarsi e sperimentare, con Stockfish integrato, senza mai uscire dall'app.

AVVERSARI CHE GIOCANO COME UMANI
Nove personaggi interpretati da Maia-3, una rete addestrata su milioni di partite umane: non cerca la mossa migliore, ma quella che giocherebbe un umano di quel livello, errori compresi. Ognuno ha il suo stile, il suo repertorio e il suo temperamento, e un livello regolabile sulla scala umana. Oppure affronta Stockfish, dal principiante (~900 Elo) al massimo (~3190). Orologio facoltativo, suggerimento, avviso prima di una mossa rischiosa e barra di valutazione a piacere.

ANALIZZARE E CAPIRE
Ogni mossa è classificata (imprecisione, errore, errore grave, mossa brillante…), ogni giocatore riceve la sua precisione e l'app spiega perché una mossa era debole. Il Coach aggiunge la quota di giocatori del tuo livello che la giocano. Alla fine propone di trasformare i tuoi errori e i tuoi matti mancati in puzzle. Inserimento tramite PGN, FEN, editor di posizioni o scanner di foto.

SESSIONE DEL GIORNO
Ogni giorno, ciò che c'è da ripassare: posizioni d'apertura in scadenza, puzzle sbagliati, un finale. Una serie di giorni e medaglie per mantenere il ritmo.

APERTURE
58 aperture scritte a mano (in cinque lingue) e riviste con il motore: ogni mossa è spiegata, frecce colorate collegano la scacchiera all'elenco e la ripetizione dilazionata le fissa. Importa anche i tuoi repertori in PGN.

FINALI
78 corsi dimostrati con le tablebase dei finali: nessuna mossa insegnata lascia sfuggire la vittoria, nessuna difesa proposta perde la patta. E l'allenamento libero, dove si accetta ogni mossa che conserva il verdetto.

PUZZLE
Oltre 130 000 problemi dal database di Lichess, filtrabili per livello e per tema, più i tuoi: tratti dai tuoi errori o importati dai tuoi file PGN. Punteggio personale e «Al mio livello».

VARIANTI E ALTRO
Chess960 e undici varianti contro il computer (Re della collina, Tre scacchi, Orda, Atomico, Crazyhouse, Duck Chess, Barricate…), ognuna con la propria analisi. Modalità a due giocatori e Laboratorio per confrontare due impostazioni di Stockfish.

IPHONE E IPAD
Scacchiera grande e pannelli affiancati su iPad, tastiera e trackpad, verticale e orizzontale. In francese, inglese, spagnolo, tedesco e italiano. Sincronizzazione iCloud facoltativa, disattivata per impostazione predefinita.

PRIVACY
Offline per impostazione predefinita: nessun server ChessLab, nessuna misurazione del pubblico, nessuna pubblicità. Le tue partite restano sul tuo dispositivo.

ChessLab integra il motore Stockfish (licenza GPLv3), la rete Maia-3 dell'Università di Toronto (licenza AGPLv3) e set di pezzi vettoriali liberi: cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) e merida (GPLv2+). Codice sorgente completo e avvisi di licenza disponibili dall'app (Impostazioni → Licenze).
```

---

## Champs communs (indépendants de la langue)

- **Catégorie principale** : Jeux (Games)
- **Sous-catégorie** : Plateau (Board)
- **Catégorie secondaire** (optionnel) : Éducation
- **Copyright** : `© 2026 Thierry Maeder` — déduit du certificat de signature local (« Apple Development: Thierry Maeder (N982QZWW97) »), qui indique un compte individuel. À vérifier contre developer.apple.com/account ▸ Membership pour l'orthographe exacte avant de coller.
- **URL du support** : `https://thmaed.github.io/ChessLab/support.html` (page déposée dans `docs/support.html`, publique — reste à activer GitHub Pages pour qu'elle soit servie, voir `README.md`). En repli immédiat, le temps d'activer Pages : `https://github.com/thmaed/ChessLab/issues`.
- **URL marketing** (optionnel) : `https://github.com/thmaed/ChessLab`
- **URL de la politique de confidentialité** : `https://thmaed.github.io/ChessLab/privacy-policy.html` (page déposée dans `docs/privacy-policy.html`, publique — même remarque sur l'activation de GitHub Pages).
- **Coordonnées de contact** (non publiques, pour Apple uniquement) : nom, adresse, téléphone, email valides — à renseigner dans App Store Connect.

### Export compliance (chiffrement)
`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` est déjà réglé dans le projet. L'app n'implémente aucune cryptographie propre. La seule activité réseau possible, la synchronisation iCloud (optionnelle, désactivée par défaut), passe par CloudKit — chiffrement standard fourni par le système Apple, donc **exempté** au sens de l'export compliance. Si App Store Connect pose la question : aucune cryptographie propriétaire, exempté.

### App Privacy (étiquette de confidentialité)
Réponse à la question « Collectez-vous des données ? » : **Non**. Aucun SDK tiers d'analytics, de publicité ou de suivi n'est intégré (les seules dépendances tierces sont ChessKit et le moteur Stockfish vendorisé, qui tournent entièrement localement). Le champ « scan de l'appareil photo » sert uniquement à la reconnaissance locale d'une position, jamais à un envoi réseau. La synchronisation iCloud (optionnelle) stocke les données dans l'iCloud **privé** de l'utilisateur (base CloudKit privée), à laquelle le développeur n'a aucun accès : Apple ne considère pas cela comme une collecte de données par le développeur. Résultat attendu dans le questionnaire App Store Connect : « Data Not Collected » pour toutes les catégories.

### Classification par âge
Le nouveau questionnaire d'âge (contenu, pas de violence, pas de contenu généré par les utilisateurs partagé publiquement, pas de jeu d'argent, pas d'accès web non restreint) doit répondre « aucun » partout → note **4+**.

### App Accessibility (App Information ▸ Accessibility)
Réponses déduites du code (vérifié, pas deviné) :
- **VoiceOver** : Oui — `accessibilityLabel`/`Value`/`Hint` sur 17 fichiers, coups annoncés en SAN.
- **Larger Text** (Dynamic Type) : Oui — quasi tous les textes utilisent des styles sémantiques (`.body`, `.headline`…), réactifs par défaut.
- **Reduced Motion** : Oui — `accessibilityReduceMotion` géré dans `Theme.swift` et `ChessBoardView.swift`.
- **Dark Interface** : Oui — l'app est en sombre forcé partout (`.preferredColorScheme(.dark)`).
- **Sufficient Contrast** : probablement oui (texte blanc sur fond très sombre), mais pas d'audit WCAG automatisé fait — à confirmer visuellement avant de cocher.
- **Voice Control** : aucune adaptation spécifique trouvée dans le code — ne cocher que si testé manuellement sur appareil.
- **Captions** : non applicable, pas de contenu audio/vidéo narratif.

### Version et build

**2.3, build 24** (le 23, téléversé le 14/11, est remplacé : il affichait « 2.3 » au-dessus des nouveautés 2.2 dans l'Aide) — `MARKETING_VERSION = 2.3`, `CURRENT_PROJECT_VERSION = 24` (aux quatre configurations, app et extension de partage ; la 2.2, build 22, est en vente : à revérifier par `asc.py build` avant l'archive). Nouveautés détaillées dans `RELEASE_NOTES-2.3.md`.

**2.2, build 22** — `MARKETING_VERSION = 2.2`, `CURRENT_PROJECT_VERSION = 22` (aux quatre configurations, app et extension de partage ; la 2.1, build 21, est en vente et le 22 n'a jamais quitté le dépôt : à revérifier par `asc.py build` avant l'archive, et à monter si Xcode en a envoyé un à l'insu du dépôt). Nouveautés détaillées dans `RELEASE_NOTES-2.2.md`.

**2.1, build 21** — `MARKETING_VERSION = 2.1`, `CURRENT_PROJECT_VERSION = 21` (la 2.0, build 19, est en vente ; le build 20, téléversé le 04/11 sans la tâche Woodpecker de la séance, est écarté). Nouveautés détaillées dans `RELEASE_NOTES-2.1.md`.

**2.0, build 19** — `MARKETING_VERSION = 2.0`, `CURRENT_PROJECT_VERSION = 19` (la 1.9.2, build 17, est la dernière soumise : le 18 est le premier numéro libre, à revérifier par `asc.py build` avant l'archive). Nouveautés détaillées dans `RELEASE_NOTES-2.0.md`.

**1.9.1, build 16** — fixés le 23/10/2026, aux deux configurations de la cible applicative. La 1.9.0 (build 15) est **READY_FOR_SALE** : le 16 est le premier numéro libre (vérifié par l'API le 23/10). Version de correction : la case d'origine de l'échiquier et un coin du recadrage ne répondaient plus en iOS 18.

**1.9.0, build 15** — fixés le 13/10/2026 (`MARKETING_VERSION = 1.9.0`, `CURRENT_PROJECT_VERSION = 15`), aux deux configurations de la cible applicative. La 1.8.1 (build 14) est **READY_FOR_SALE** : le 15 est le premier numéro libre (vérifié par l'API le 13/10). Nouveautés détaillées dans `RELEASE_NOTES-1.9.0.md`, texte prêt à coller ci-dessus.

Pourquoi 1.9.0 : un appareil nouveau pris en charge de bout en bout (iPhone Duo, SDK iOS 27.1), avec des dispositions nouvelles pour les écrans plus larges que hauts et une politique d'orientation qui change. Plus qu'une correction.

**1.8.1, build 14** — 29/09/2026, version de corrections (nom du joueur, balises PGN, fenêtres partagées sur iPad).

**Historique du 06/09/2026** — 1.8.0, build 13 : App Store Connect avait déjà reçu des builds 11 et 12 le matin même, depuis Xcode, et exige un numéro strictement supérieur. Le build 13 est celui téléversé par `tools/asc/release.sh`.

Historique : la 1.7.1 (build 10.1) avait été fixée le 05/09 et n'est jamais partie ; la 1.8.0 l'absorbe.

Vérifié dans `ChessLab.xcodeproj/project.pbxproj` (26/08/2026) : la cible applicative (`com.chesslab.ChessLab`) porte `MARKETING_VERSION = 1.6` aux deux configurations, Debug et Release — correct. Mais `CURRENT_PROJECT_VERSION` **dérive tout seul** au fil des builds locaux (`8.1` le 25/08, `8.2` observé le 26/08, sans action délibérée) — le dernier build réellement soumis était le 7 (1.5.0). App Store Connect exige un entier (ou une liste d'entiers séparés par des points) strictement supérieur au dernier build soumis, donc n'importe laquelle de ces valeurs conviendrait numériquement (`8` > `7`), mais la dérive elle-même est le problème : ne PAS archiver avec la valeur trouvée « par hasard » au dernier build local — la fixer consciemment (`8` tout rond est le plus simple) au moment de l'archive, pas avant, sinon elle continuera de bouger.

⏳ **1.6.0 : pas encore soumise.** Succède au build 7 de la 1.5.0, en ligne depuis le 20/08/2026.

Les cibles de TEST (`ChessLabTests`, `ChessLabUITests`) sont restées en `1.2.0` / build 3. **Sans effet sur la soumission** : leurs bundles ne sont pas livrés. À aligner un jour par propreté, pas avant d'expédier.

Incrémenter `CURRENT_PROJECT_VERSION` à chaque nouveau build renvoyé à Apple, même version marketing.

### ⚠️ À FAIRE AVANT DE SOUMETTRE — pousser le code source

Les notes réviseurs (plus bas) affirment que « the complete source code of the app — **matching this submitted build** — is published publicly at github.com/thmaed/ChessLab ». Ce n'est pas une formule de style : Stockfish étant GPLv3, le binaire ChessLab est une œuvre dérivée GPLv3, et la publication du code correspondant est une **obligation de licence**, pas un argument commercial.

Vérifier donc, juste avant d'archiver :

```
git status -sb        # doit indiquer 'main...origin/main' sans 'ahead'
git push origin main
```

Au 19/08/2026, `main` est poussé au fil de l'eau (la nuit de travail du 18-19/08 a été poussée commit par commit). Vérifier malgré tout au moment de soumettre (`git log --oneline origin/main..HEAD | wc -l` doit rendre 0) : soumettre sans pousser publierait un binaire dont les sources annoncées ne correspondent pas.

### Historique des versions
- **2.3** — build 23, préparée (non soumise) : espagnol, allemand et italien complets (interface, aide, cours, noms d'ouvertures, notation), sélecteur de langue en pastilles, noms des joueurs par défaut traduits (`RELEASE_NOTES-2.3.md`).
- **2.2** — build 22, en vente : scanner fiabilisé (photos d'écran, revue des cases douteuses, partage depuis Photos par l'extension ChessLabShare), export PGN et copie iCloud des collections de puzzles, réglage « Afficher le thème du puzzle », Laboratoire Chess960, Stockfish 19, jauge d'avancement de l'analyse (`RELEASE_NOTES-2.2.md`).
- **2.1** — build 21, en vente depuis le 05/11/2026 : collections de puzzles importées, écran Puzzles repensé, réussite partielle, 130 935 puzzles (`RELEASE_NOTES-2.1.md`).
- **2.0** — build 18 : séance du jour, analyse → puzzles avec récapitulatif, Coach (Maia-3), cote de puzzle, ouvertures illustrées, reprise de partie, limite de temps en option ; correctifs (reprise après capture d'une tour, coup de mat noté) (`RELEASE_NOTES-2.0.md`).
- **1.9.2** — build 17, soumise : correctif de la prise au tap-tap sous iOS 18.
- **1.9.1** — build 16 : la pièce du coin haut gauche de l'échiquier (h1 aux Noirs, a8 aux Blancs) et un coin du recadrage du scanner ne répondaient plus au toucher en iOS 18 (`RELEASE_NOTES-1.9.1.md`).
- **1.9.0** — build 15, en ligne : iPhone Duo, dispositions pour écrans plus larges que hauts (`RELEASE_NOTES-1.9.0.md`).
- **1.8.1** — build 14, en ligne : nom du joueur traduit et réglable, PGN exporté avec ses sept balises, disposition iPhone dans une fenêtre d'iPad plus étroite que 744 pt, échiquier servi en premier (`RELEASE_NOTES-1.8.1.md`).
- **1.8.0** — soumise le 06/09/2026, build 13, fiche remplie par `tools/asc/` : neuf personnages joués par Maia-3 (style, répertoire, tempérament, illustration, niveau mémorisé par personnage sur l'échelle humaine), filet Stockfish à quatre cas, Progrès par personnage, camp Maia au Laboratoire, licence AGPLv3, borne Fairy-Stockfish à 2850 (`RELEASE_NOTES-1.8.0.md` — absorbe la 1.7.1).
- **1.7.1** — jamais soumise, absorbée par la 1.8.0 : visite guidée bilingue (11 étapes, rejouable depuis l'Aide), coups en ligne colorés dans TOUTES les analyses de variantes, grille des modes sur l'accueil iPad/Mac, stabilité du moteur des variantes en profondeur (6 mécanismes corrigés, suite de torture), Aide remise à jour (version lue du bundle, module Variantes à douze tuiles), zéro warning de compilation (`RELEASE_NOTES-1.7.1.md` — couvre 1.6 → 1.7.1).
- **1.7.0** — jamais soumise, absorbée par la 1.7.1 : quatre variantes de plus au hub, qui passe à douze — **Crazyhouse** (les prises changent de camp et se reposent), **Duck Chess** (un canard bloque une case, tour en deux temps), **Barricades** (d4 et e5 murées dès le départ) et **Barricades aléatoires** (deux murs qui changent de case à chaque coup), toutes contre l'ordinateur. Plus le correctif d'un défaut moteur récurrent des Variantes (« le moteur n'a pas pu être démarré » après une analyse ou un retour en arrière), et une passe de mise en page menée sur les deux extrêmes du parc — grandes fenêtres en classe *regular* (iPad plein écran, Split View, Stage Manager) et petits iPhone (`RELEASE_NOTES-1.7.0.md` — couvre 1.6 → 1.7).
- **1.6.0** — soumise le 28/08/2026 : module Variantes porté à 8 façons de jouer (Chess960 complet, six variantes Fairy-Stockfish, et Coup Volé — variante maison sur Stockfish standard), analyse de fin de partie commune aux 7 non-Chess960, nouveau lecteur d'Ouvertures en arbre, Finales à 78 cours avec recherche, « Changer de mode » uniformisé, correctifs de fiabilité moteur, stockage allégé (175 → 60 Mo) (notes supprimées après soumission ; détail dans l'historique Git).
- **1.5.0** — module Finales (77 cours prouvés par tablebase, 9 familles), entraînement libre arbitré au verdict, correctif majeur iOS 18, ~900 positions ajoutées aux ouvertures, verdicts d'analyse affinés, sélecteur « Changer de mode » avec reprise de position, Stockfish 17.1 (notes supprimées après soumission ; détail dans l'historique Git).
- **1.4.0** — préparée, **jamais soumise** : répertoires d'ouvertures personnels (import PGN + partage par fichier), les 58 ouvertures relues au moteur, un seul essai par puzzle, lecteur d'ouvertures à plateau ancré (`RELEASE_NOTES-1.4.0.md`, conservé comme document historique). Son contenu est livré avec la 1.5.
- **1.3.0** — préparée, **jamais soumise** : échiquier tolérant au doigt, score de précision recalibré, revue d'analyse fiabilisée, iPhone en portrait. Son contenu est livré avec la 1.4 ; aucune note de version distincte n'a été rédigée.
- **1.2.0** — Ouvertures repensées, interface iPad/Mac, synchro iCloud (`RELEASE_NOTES-1.2.0.md`, regroupe 1.0.2 et 1.1.0).

---

## App Review Notes (paste into App Store Connect → App Review Information → Notes)

English, for the Apple reviewer. Opens with the nature of the update (2.3 : localization update), puis la proposition de valeur (sept modes, entièrement gratuits), la permission caméra, le seul appel réseau, la situation de licence (moteur GPLv3, sources publiques), et qu'aucun compte de test n'est nécessaire.

```
WHAT'S IN THIS UPDATE (2.3): a localization update. ChessLab is now available in Spanish, German and Italian, in addition to French and English: the whole interface, the help, every opening and endgame course and the opening names. The language is chosen in Settings (or follows the device language), and move notation follows the language (it can be set separately). Two small interface changes come with it: the language picker is now a row of compact chips, and the default player names in two-player mode (White, Black) are shown in the chosen language. No change to features, permissions, privacy or licensing: no new permission, still no network call of ours, no account, no data collected. To check: Settings → Language, pick Español, Deutsch or Italiano; the app then follows that language.

ChessLab is a free chess app — no paywall, no ads, no in-app purchases, no account, no login, no server. Nothing to set up before reviewing. It bundles seven modes: play against the embedded Stockfish engine (Elo ~900 to ~3190) or against one of nine "characters" played by the Maia-3 neural network (University of Toronto, AGPLv3), which predicts human moves at a given level and runs entirely on-device via Core ML; two players on one device; full game analysis with Stockfish; 58 hand-written opening courses with spaced-repetition training; over 130,000 Lichess puzzles; an engine-vs-engine laboratory; and twelve variants (Chess960, King of the Hill, Three-Check, Horde, Racing Kings, Atomic, Antichess, Crazyhouse, Duck Chess, two Barricades, and a house variant, Stolen Move).

CAMERA: the Scanner uses the camera only to photograph a chess diagram — a screenshot or a physical board seen from above — and reconstruct the position with on-device recognition. Photos never leave the device. On Simulator (no camera), use the "Paste" entry in the Scanner screen with any chess diagram in the clipboard: it skips the camera and exercises the same recognition.

NETWORK: there is no ChessLab server, no API, no analytics, no ads. The only network activity is an optional iCloud sync, OFF by default. Turned on (Settings → Sync), CloudKit syncs the user's own saved games and progress through their OWN private iCloud database; the bundled puzzles and courses stay local. No data reaches the developer, hence "Data Not Collected". With sync off — the default — the app makes no network call at all.

ENGINE LICENSE (GPLv3): ChessLab embeds the Stockfish engine, compiled from its own sources, so the binary as a whole is a GPLv3 derivative work. The complete source code matching this build is published at https://github.com/thmaed/ChessLab. Notices for every third-party component (Stockfish/GPLv3, Maia-3/AGPLv3 — compatible per its section 13, the app provides no network service —, ChessKit/MIT, the piece sets cburnett/GPLv2+ & CC BY-SA 3.0, chessnut/Apache 2.0, merida/GPLv2+, the Lichess puzzles/CC0) are shown in-app under Settings → Licences.
```
