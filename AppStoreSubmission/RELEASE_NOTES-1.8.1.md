# Notes de version — ChessLab 1.8.1

Notes DÉTAILLÉES pour le dépôt. Le texte à coller dans App Store Connect est la section « Nouveautés de cette version » de `METADATA.md` (limite 4 000 caractères).

> ⏳ **Pas encore soumise.** Version `1.8.1`, build `14` (la 1.8, build 13, est READY_FOR_SALE depuis sa révision). Couvre le 13/09 → 29/09/2026. Rien n'a changé du contenu — mêmes modes, mêmes 58 ouvertures, mêmes 78 finales, mêmes 12 variantes : les captures et les aperçus vidéo de la 1.8 restent valables (décision du 29/09).

> ⚠️ **La description est corrigée au passage, dans les deux langues.** Elle annonçait « sept variantes de plus » alors que le hub en compte douze depuis la 1.8 — Crazyhouse, Duck Chess, Barricades et Barricades aléatoires y sont entrées sans que la description permanente suive. La fiche Google Play avait été corrigée le 19/09, pas celle de l'App Store.

---

## Français

Cette version est née d'un retour de testeur, reçu en anglais le 27/09/2026. Trois défauts sur quatre étaient exacts, et le quatrième a conduit à une révision de la mise en page sur iPad.

**Le nom du joueur**

L'app s'affichait entièrement en anglais, sauf le nom du joueur, qui restait « Vous ». C'était vrai : la bibliothèque stocke ce mot EN CLAIR — il sert aussi de repère pour savoir de quel côté on jouait dans les plus anciens enregistrements — et la ligne de bibliothèque l'affichait tel quel. Un point de résolution unique traduit désormais les noms « spéciaux » dans les deux sens (Vous/You, Blancs/White, Noirs/Black, Ordinateur/Computer), et c'est la langue du jour qui décide, pas celle du jour de la partie : une partie jouée en anglais puis relue en français se retourne elle aussi.

Le même testeur cherchait, sans le trouver, comment signer ses parties. **Réglages → Votre nom** existe maintenant, juste sous la langue. Vide, il vaut « Vous ». Rempli, il remplace ce mot partout où il s'affiche — y compris dans les parties déjà enregistrées — et part dans les balises PGN. Il suit les appareils par iCloud quand la synchronisation est active, et il est nettoyé de ce qui casserait une balise (guillemets, crochets) puis borné à 40 caractères.

**Le PGN exporté est enfin un PGN**

Un export ne contenait que la suite des coups : ni balises, ni résultat. C'était exact — la bibliothèque ChessKit ne sérialise que les balises renseignées, et l'app n'en renseignait aucune. Toute partie partagée ou copiée porte désormais les sept balises obligatoires du standard (Event, Site, Date, Round, White, Black, Result), et le résultat clôt aussi la suite des coups. Les balises d'un PGN importé ne sont jamais écrasées : on ne comble que les manques. Les douze variantes, qui composaient leurs en-têtes à la main, passent par le même constructeur et gagnent au passage les joueurs, le site et la date. Les parties DÉJÀ rangées avant cette version sont complétées à la réouverture avec ce que l'enregistrement sait d'elles.

**Les fenêtres partagées sur iPad**

Le testeur voyait, « parfois », l'écran partir hors cadre à droite. Le rognage qu'il photographiait est un artefact d'iPadOS pendant qu'on fait glisser le bord d'une fenêtre, et il le disait lui-même. Mais dessous il y avait un vrai défaut : iPadOS garde la classe d'affichage « large » bien en dessous de la largeur d'un écran d'iPad, et l'app montrait encore barre latérale + détail dans une fenêtre de 700 points — la barre en prenait 290, et il restait à l'échiquier moins de place que sur un iPhone. Sous 744 points, la largeur en portrait de l'iPad le plus étroit jamais vendu, l'app prend désormais la disposition iPhone : une colonne, échiquier pleine largeur.

**L'échiquier reprend la place que le panneau lui prenait**

Essayée sur iPad Pro 11 pouces, la même fenêtre réduite a montré deux autres travers. En deux colonnes, l'échiquier et le panneau se disputaient la largeur à parts égales, et le panneau en emportait 43 % : le partage est maintenant explicite — l'échiquier prend son carré, le panneau prend ce qui reste, borné entre 340 et 420 points. En colonne unique, la liste des coups gagnait sa place contre l'échiquier : elle passe dans la feuille, comme sur iPhone, dès qu'il ne reste plus assez de hauteur pour les deux, et le bouton « Coups joués » prend le relais. Mesuré : l'échiquier passe de 626 à 706 points en paysage sur un 13 pouces, de 401 à 463 sur un mini, et de 916 à 1 032 en portrait barre latérale repliée. Les iPad en plein écran avec la barre ouverte ne bougent pas.

**Le reste, venu de la parité avec Android**

- **Mémorisation** : la carte de progression qui manquait à iOS — positions vues, acquises, à raffermir, dues, révisions de la semaine, taux de réussite. Elle existait côté Android ; quand c'est Android qui a pris de l'avance, on relève iOS.
- **Barre d'évaluation activée par défaut** dans tous les modes qui l'offrent, iOS n'étant pas cohérent avec lui-même sur ce point.
- **Duck Chess** : la prise du roi était annoncée « échec et mat », alors que la notation de l'app écrit « ++ » et jamais « # » — le canard masque le coup qui vient, et la partie se gagne en PRENANT le roi. Elle se nomme désormais « roi capturé ». Et l'écran de fin disait « Vous a gagné », tournure empruntée au jeu à deux ; il dit « Vous avez gagné ».
- **Annonces VoiceOver** des coups revues.
- **Licences** : le détecteur du scanner (YOLO11 d'Ultralytics, AGPLv3) y est déclaré, il y manquait.

---

## English

This release came out of a tester's report, received on 27 September 2026. Three of his four points were exact, and the fourth led to a layout revision on iPad.

**The player's name**

The app was entirely in English except the player's name, which stayed "Vous". That was true: the library stores that word VERBATIM — it also tells which side you played in the oldest records — and the library row showed it as-is. A single resolution point now translates the "special" names both ways (Vous/You, Blancs/White, Noirs/Black, Ordinateur/Computer), and today's language decides, not the language of the day you played: a game played in English and read back in French turns around too.

The same tester was looking, in vain, for a way to sign his games. **Settings → Your name** now exists, right under the language. Left empty, it means "You". Filled in, it replaces that word everywhere it shows — including in games already recorded — and goes into the PGN tags. It follows your devices over iCloud when sync is on, and it is stripped of anything that would break a tag (quotes, brackets) then capped at 40 characters.

**An exported PGN is finally a PGN**

An export contained only the moves: no tags, no result. That was exact — the ChessKit library only serialises the tags that are set, and the app set none. Any game shared or copied now carries the seven mandatory tags of the standard (Event, Site, Date, Round, White, Black, Result), and the result also closes the move text. The tags of an imported PGN are never overwritten: only the gaps are filled. The twelve variants, which composed their headers by hand, go through the same builder and gain the players, the site and the date along the way. Games ALREADY stored before this version are completed when reopened, from what the record knows about them.

**Shared windows on iPad**

The tester saw, "sometimes", the screen running off the right edge. The clipping he photographed is an iPadOS artefact while you drag a window's edge, and he said so himself. But underneath there was a real defect: iPadOS keeps the "regular" size class well below the width of any iPad screen, and the app still showed sidebar + detail in a 700-point window — the sidebar took 290 of them, leaving the board less room than on an iPhone. Below 744 points, the portrait width of the narrowest iPad ever sold, the app now takes the iPhone layout: one column, board at full width.

**The board takes back the room the panel was taking**

Tried on an 11-inch iPad Pro, the same reduced window showed two more flaws. In two columns, board and panel were competing for the width on equal terms, and the panel took 43 % of it: the split is now explicit — the board takes its square, the panel takes what is left, bounded between 340 and 420 points. In a single column, the move list was winning its place against the board: it moves into the sheet, as on iPhone, as soon as there is no longer enough height for both, and the "Moves played" button takes over. Measured: the board goes from 626 to 706 points in landscape on a 13-inch, from 401 to 463 on a mini, and from 916 to 1,032 in portrait with the sidebar folded. Full-screen iPads with the sidebar open do not move.

**The rest, from parity with Android**

- **Memorisation**: the progress card iOS was missing — positions seen, acquired, to firm up, due, reviews this week, success rate. It existed on Android; when Android is the one ahead, iOS is raised.
- **Evaluation bar on by default** in every mode that offers it, iOS not being consistent with itself on that point.
- **Duck Chess**: capturing the king was announced as "checkmate", while the app's own notation writes "++" and never "#" — the duck hides the move to come, and the game is won by TAKING the king. It is now called "king captured". And the end screen said "Vous a gagné", a turn of phrase borrowed from two-player mode; it now says "You won".
- **VoiceOver move announcements** revised.
- **Licences**: the scanner's detector (Ultralytics YOLO11, AGPLv3) is declared there; it was missing.
