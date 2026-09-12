# Publier ChessLab sur Google Play

Le chemin complet, de zéro à « en production ». Rien ici n'est spéculatif :
les commandes sont celles du projet, et les points qui bloquent vraiment sont
signalés comme tels.

> **Comptez trois semaines**, pas trois jours. Ce n'est pas le build qui est
> long — il tient en une commande — c'est le **test fermé de 14 jours** que
> Google impose aux nouveaux comptes personnels (§2).

---

## 0. Avant tout : la licence GPLv3

**Publier ChessLab sur le Play Store, c'est DISTRIBUER Stockfish.** Le moteur
est sous GPLv3, et le binaire de l'app en est une œuvre dérivée. La
distribution impose donc :

- mettre à disposition le **code source complet** correspondant exactement au
  binaire publié ;
- conserver les mentions de copyright et de licence ;
- n'ajouter aucune restriction d'usage supplémentaire.

En pratique : un dépôt public (ou une archive téléchargeable) dont l'URL
figure dans la fiche Play, et un écran « Licences » dans l'app. C'est la même
contrainte que côté iOS — voir le `README.md` à la racine du dépôt. **À régler
avant de soumettre, pas après.**

---

## 1. Le compte développeur

1. <https://play.google.com/console> → créer un compte développeur.
2. **25 $ une fois** (pas d'abonnement annuel, contrairement à Apple).
3. Choisir **personnel** ou **organisation** :

| | Personnel | Organisation |
| --- | --- | --- |
| Vérification d'identité | pièce d'identité | D-U-N-S + documents de société |
| Test fermé obligatoire | **oui — 12 testeurs, 14 jours** | non |
| Délai avant production | ~3 semaines | quelques jours |

La vérification d'identité prend de quelques heures à quelques jours. Lancez-la
tout de suite : elle tourne pendant que vous préparez le reste.

---

## 2. Le test fermé de 14 jours (comptes personnels)

C'est la contrainte qui dicte le calendrier. Pour un compte **personnel** créé
récemment, Google exige, avant d'autoriser la production :

- une piste de **test fermé** ;
- **au moins 12 testeurs** qui ont *opté pour* le test — ce nombre a déjà
  changé (il était de 20 à l'origine) : **relisez-le dans la console** avant de
  recruter ;
- **14 jours continus** — si le nombre de testeurs passe sous 12, le compteur
  repart.

Les testeurs s'ajoutent par adresse Gmail (liste d'e-mails ou groupe Google).
Prévenez-les que leur compte Google doit accepter l'invitation et **garder
l'app installée** pendant les deux semaines.

Une fois les 14 jours écoulés, un bouton « Demander l'accès à la production »
apparaît ; la demande est examinée à la main.

---

## 3. Préparer le binaire

### 3.1 Le trousseau de signature

Il ne vit **pas** dans le dépôt (`*.jks` et `keystore.properties` sont
ignorés par Git). S'il n'existe pas encore :

```bash
keytool -genkeypair -v \
  -keystore ~/.chesslab-android/chesslab-release.jks \
  -alias chesslab -keyalg RSA -keysize 4096 -validity 10000
```

puis `~/.chesslab-android/keystore.properties` :

```properties
storeFile=/Users/<vous>/.chesslab-android/chesslab-release.jks
storePassword=…
keyAlias=chesslab
keyPassword=…
```

> **Sauvegardez ce fichier .jks hors de la machine.** Avec la signature par
> Google Play (activée d'office pour les nouvelles apps), le perdre n'est plus
> fatal — Google détient la clé de signature finale et vous pouvez demander une
> nouvelle clé de téléversement — mais c'est une démarche, et une attente.

### 3.2 Le numéro de version

`android/app/build.gradle.kts` :

```kotlin
versionCode = 1        // ENTIER, à incrémenter à CHAQUE téléversement
versionName = "0.1"    // ce que l'utilisateur lit
```

Google Play refuse deux téléversements avec le même `versionCode`, **même sur
des pistes différentes**. Pour une première publication : `versionCode = 1`,
`versionName = "1.0"`.

### 3.3 Construire

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
cd android
./gradlew :app:bundleRelease
# → app/build/outputs/bundle/release/app-release.aab   (148 Mo, mesuré)
```

**C'est un AAB qu'on téléverse**, pas un APK : Google Play n'accepte plus d'APK
pour une nouvelle app. `assembleRelease` reste utile pour installer à la main
sur un téléphone et vérifier avant d'envoyer.

Vérifiez que le bundle est bien **signé** (sans `keystore.properties`, la tâche
sort un binaire non signé que Play refusera) :

```bash
jarsigner -verify app/build/outputs/bundle/release/app-release.aab
# attendu : « jar verified. »
```

Pour un **APK** (`assembleRelease`), `jarsigner` répond « no manifest » : il
n'est pas le bon outil, la signature y est en v2/v3. C'est `apksigner` qu'il
faut :

```bash
$SDK/build-tools/35.0.0/apksigner verify --print-certs \
  app/build/outputs/apk/release/app-release.apk
# attendu : « Signer #1 certificate DN: CN=ChessLab, … »
```

L'avertissement `PKIX path building failed` qui suit est **normal** : la clé de
téléversement est auto-signée, aucune autorité ne la garantit — c'est le
principe. Seule la ligne « jar verified. » compte.

### 3.4 La taille

| | compressé |
| --- | --- |
| Bundle complet | **148 Mo** (mesuré le 12/09/2026) |
| Plafond Google Play sans Play Asset Delivery | ~200 Mo |

On passe, sans marge confortable. Si un jour ça déborde, la sortie est **Play
Asset Delivery** : les réseaux NNUE (62 Mo compressés) et le modèle Maia
(42 Mo) sont exactement le genre de gros fichiers qu'il sert à livrer à part.

---

## 4. Créer la fiche

Play Console → **Créer une application**. Puis, dans « Développer la présence
sur le Play Store » :

### 4.1 Les visuels

| Élément | Format exigé |
| --- | --- |
| Icône | PNG 512 × 512, 32 bits, ≤ 1 Mo |
| Image de présentation | PNG/JPEG 1024 × 500 (obligatoire) |
| Captures téléphone | 2 à 8, côté court ≥ 320 px, côté long ≤ 3840 px |
| Captures tablette 7" et 10" | facultatives, mais elles évitent la mention « non optimisé pour les tablettes » |

Les captures iOS de `AppStoreSubmission/screenshots/` ne sont **pas**
réutilisables telles quelles (encoches et proportions iPhone). À refaire sur
l'émulateur :

```bash
$SDK/platform-tools/adb exec-out screencap -p > capture.png
```

### 4.2 Les textes

- **Titre** : 30 caractères max.
- **Description courte** : 80 caractères max — c'est elle qu'on lit dans les
  résultats de recherche.
- **Description complète** : 4000 caractères max.

`AppStoreSubmission/METADATA.md` contient la description iOS française et
anglaise déjà rédigée : la base est bonne, il faut la retailler (Apple donne
4000 caractères aussi, mais le sous-titre de 30 et les mots-clés n'ont pas
d'équivalent Play — les mots-clés Play se placent *dans* la description).

Déclarez les **deux langues** (fr-FR et en-US) : l'app est bilingue, la fiche
doit l'être.

### 4.3 Les déclarations obligatoires

Toutes se remplissent dans « Contenu de l'application ». Pour ChessLab :

| Déclaration | Réponse |
| --- | --- |
| **Politique de confidentialité** | URL **obligatoire**, même sans collecte. Une page qui dit « aucune donnée ne quitte l'appareil » suffit, mais elle doit exister et être en ligne. |
| **Sécurité des données** | Aucune donnée collectée, aucune donnée partagée. C'est vrai et c'est vérifiable : l'app n'a pas la permission `INTERNET`. |
| **Classification du contenu** | Questionnaire IARC. Jeu d'échecs sans violence, sans achat, sans contenu utilisateur → « Tout public ». |
| **Public cible** | Si vous cochez « moins de 13 ans », la politique « Families » s'applique et alourdit tout. Ciblez **13 ans et plus**. |
| **Publicités** | Non. |
| **App d'actualité / COVID / finance / administration** | Non. |

> **L'absence de permission `INTERNET` est un argument.** Vérifiez-la avant de
> remplir le formulaire de sécurité des données :
> ```bash
> grep -c "android.permission.INTERNET" app/src/main/AndroidManifest.xml   # doit rendre 0
> ```

---

## 5. Téléverser et publier

1. **Test interne** (`Tests > Test interne`) — jusqu'à 100 testeurs, pas de
   délai d'examen, disponible en quelques minutes. C'est là qu'on envoie le
   premier AAB pour vérifier qu'il s'installe et tourne sur un vrai téléphone.
2. **Test fermé** — la piste qui compte pour les 14 jours (§2).
3. **Test ouvert** — facultatif.
4. **Production** — après l'accès accordé.

Pour chaque version : créer une release, glisser l'AAB, écrire les notes de
version (une par langue déclarée), puis « Envoyer pour examen ».

Le premier examen prend de quelques jours à deux semaines ; les suivants sont
plus rapides.

---

## 6. Ce qu'il reste à faire côté app avant de publier

- [x] ~~La mesure sur un vrai téléphone~~ — faite le 12/09/2026 sur un Galaxy
      A16 (voir `README.md`). Reste le comportement THERMIQUE après une longue
      session.
- [ ] **La page de politique de confidentialité**, en ligne, avec son URL.
- [ ] **La mise à disposition des sources** (GPLv3, §0) et l'écran de licences.
- [ ] **`versionName`** passé à `1.0`, `versionCode` délibéré.
- [ ] Une passe sur un écran étroit et en paysage sur l'appareil réel.
