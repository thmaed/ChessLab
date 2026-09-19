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
figure dans la fiche Play, et un écran « Licences » dans l'app — il existe
depuis le 13/09/2026 (Réglages → À propos → Licences, `LicencesScreen.kt`),
avec le lien vers le dépôt des sources. C'est la même contrainte que côté
iOS — voir le `README.md` à la racine du dépôt. **Le dépôt public reste à
ouvrir avant de soumettre, pas après.**

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

### 3.0 Les pages de 16 Ko — réglé le 15/09/2026

Google exige, pour toute app qui vise Android 15 (SDK 35) ou plus, que les
bibliothèques natives soient alignées sur des pages de **16 Ko**. Les
appareils récents passent à ce format ; une bibliothèque alignée sur 4 Ko n'y
démarre pas, et le Play Store refuse l'envoi.

Le Galaxy A16 le signalait à chaque installation par une boîte système :
« Cette appli n'est pas compatible avec les pages de 16 ko ». Trois des six
bibliothèques étaient en cause.

Ce qui l'a réglé :

- nos deux moteurs (`libchesslab_engine.so`, `libchesslab_fairy.so`) :
  `target_link_options(… -Wl,-z,max-page-size=16384)` dans le `CMakeLists.txt`
  du module `engine`. Le NDK r27 sait le faire, mais **ne le fait pas** par
  défaut ;
- `libonnxruntime4j_jni.so` : ONNX Runtime **1.20.0 → 1.22.0**.

Les trois autres (`libonnxruntime.so`, `libdatastore_shared_counter.so`,
`libandroidx.graphics.path.so`) l'étaient déjà.

**Vérifier après chaque changement de dépendance native** — c'est une
régression qui ne se voit pas autrement :

```bash
NDK=$ANDROID_HOME/ndk/27.2.12479018
READELF=$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf
unzip -o -q app/build/outputs/apk/release/app-release.apk 'lib/*' -d /tmp/chk
for so in /tmp/chk/lib/arm64-v8a/*.so; do
  echo "$($READELF -l "$so" | grep -m1 LOAD | awk '{print $NF}')  $(basename $so)"
done | sort          # toutes les lignes doivent dire 0x4000
```

Et l'alignement des entrées du ZIP, que l'AGP fait déjà :

```bash
$ANDROID_HOME/build-tools/35.0.0/zipalign -c -P 16 -v 4 app-release.apk | tail -1
```

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

## 3bis. Publier sans les mains (déjà en place)

Le greffon **Gradle Play Publisher** est monté dans le projet. Il fait pour
Google ce que `tools/asc` fait pour Apple : téléverser le binaire et remplir la
fiche, depuis des fichiers VERSIONNÉS dans le dépôt.

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
cd android
./gradlew publishBundle                        # l'AAB, sur la piste interne
./gradlew publishListing                       # textes, captures, visuels
./gradlew publishBundle --track internal       # ou une autre piste
./gradlew promoteArtifact --from-track internal --promote-track production
./gradlew bootstrapListing                     # l'INVERSE : récupérer ce que Google a
```

### La clé, hors dépôt — le compte de service, pas à pas

Pas de fichier `.p8` comme chez Apple : un **compte de service** Google Cloud,
c'est-à-dire un « utilisateur » qui n'est pas une personne, invité dans la Play
Console comme on inviterait un collègue.

> **Un vérificateur existe.** Plutôt que de relire ce qui suit en se demandant
> laquelle des six étapes a raté, lancez :
>
> ```bash
> cd android && ./tools/verifier-cle-play.sh
> ```
>
> Il dit précisément ce qui manque — fichier au mauvais endroit, clé invalide,
> API non activée, compte non invité, droits insuffisants, application
> inexistante — et comment le réparer. `--installer` pose au passage la clé
> depuis `~/Downloads`.

**1. Lier un projet Cloud.** Play Console → **Paramètres** → **Accès à l'API**.
Au premier passage, Google propose de créer un projet Google Cloud ou d'en lier
un existant. Un projet neuf, dédié à l'app, est plus simple à révoquer ensuite.
Cette étape ACTIVE au passage l'API « Google Play Android Developer » ; sans
elle, tout le reste rend `403`.

> **« Accès à l'API » est une page du COMPTE, pas d'une application.** Depuis
> l'intérieur d'une app, le menu de gauche montre les réglages de l'app et la
> page n'y figure pas : il faut remonter à « Toutes les applications ». Direct :
> `https://play.google.com/console/api-access`.
>
> Il faut être **propriétaire** du compte développeur — un utilisateur invité,
> même administrateur, ne la voit pas, sans message ni case grisée : elle est
> simplement absente — et la vérification d'identité doit être terminée, sans
> quoi le menu reste amputé. Pour trancher : **Utilisateurs et autorisations**,
> cherchez votre adresse, regardez la colonne du rôle.
>
> Introuvable malgré tout ? Voir le chemin de secours en fin de section.

**2. Créer le compte de service.** Sur la même page, section **Comptes de
service** → « Créer un compte de service ». Le lien ouvre la console Cloud, sur
le bon projet :

- *Nom* : `chesslab-publisher` (l'adresse s'en déduit) ;
- *Rôle* : **aucun**. Les droits qui comptent ne sont pas ceux de Cloud mais
  ceux de la Play Console, accordés à l'étape 4. En donner ici ne sert à rien
  et élargit la surface ;
- terminer la création.

L'adresse obtenue ressemble à
`chesslab-publisher@<projet>.iam.gserviceaccount.com`.

**3. Sa clé.** Toujours dans la console Cloud, ouvrir le compte de service →
onglet **Clés** → « Ajouter une clé » → « Créer une clé » → **JSON**. Le
fichier se télécharge une seule fois et ne se retélécharge JAMAIS : perdu, il
faut en créer un autre et révoquer le précédent.

**Le renommage n'est pas facultatif.** Google donne au fichier un nom à lui
(`chesslab-472210-a1b2c3d4e5f6.json`) ; le greffon ne lit QUE le chemin
ci-dessous, exactement. Une clé parfaitement valide laissée dans
`~/Downloads` ne sert à rien, et le greffon se contente alors de dire
`SKIPPED` — c'est l'erreur la plus fréquente.

```bash
cd android && ./tools/verifier-cle-play.sh --installer   # le fait pour vous
```

ou à la main :

```bash
mkdir -p ~/.private_keys
mv ~/Downloads/<projet>-<hash>.json ~/.private_keys/play-service-account.json
chmod 600 ~/.private_keys/play-service-account.json
```

C'est là que vit déjà la clé App Store Connect. **Elle ne doit jamais entrer
dans le dépôt** — le `.gitignore` la couvre où qu'elle soit, mais c'est une
ceinture, pas une excuse.

**4. Lui donner les droits.** Retour dans la Play Console → **Accès à l'API** →
« Actualiser les comptes de service » : le nouveau apparaît. « Accorder l'accès »,
puis cocher, pour CETTE application :

| Droit | Pourquoi |
| --- | --- |
| Afficher les informations sur l'application | socle : sans lui, rien ne se lit |
| Gérer la présence sur le Store | `publishListing` — textes, captures, visuels |
| Gérer les versions de test | `publishBundle` sur les pistes interne/fermée |
| Gérer les versions de production | seulement le jour où l'on promeut |

Inviter. La propagation est en général immédiate ; comptez tout de même
quelques minutes avant de vous étonner d'un `401`.

**5. Vérifier.** L'application doit déjà exister dans la console — l'API sait
envoyer des binaires, pas créer une fiche.

```bash
cd android && ./tools/verifier-cle-play.sh
```

Sans cette clé, le greffon se tait : `./gradlew build` marche pour qui n'a pas à
publier. Avec elle, tout s'enchaîne.

#### Chemin de secours : tout depuis Google Cloud

Quand « Accès à l'API » reste introuvable — compte dont on n'est pas
propriétaire, vérification d'identité en cours —, la même chose se monte à la
main. Une seule étape s'ajoute : activer l'API soi-même, ce que la page guidée
faisait au passage.

1. <https://console.cloud.google.com> → créer un projet ;
2. **API et services** → **Bibliothèque** → « Google Play Android Developer
   API » → **Activer**. Sautée, cette étape fait rendre `403` à tout le
   reste — et le vérificateur le dit en toutes lettres ;
3. **IAM et administration** → **Comptes de service** → créer (aucun rôle),
   puis la clé JSON comme à l'étape 3 ;
4. Play Console → **Utilisateurs et autorisations** → **Inviter un
   utilisateur** → coller l'adresse du compte de service, mêmes droits qu'au
   tableau de l'étape 4.

Cette dernière étape demande tout de même le droit de gérer les utilisateurs.
Sans lui, il n'y a pas de contournement : **seul le propriétaire du compte peut
ouvrir l'API**. Le téléversement par le web, lui, ne demande que le droit de
gérer les versions — c'est la sortie quand on n'est qu'invité.

### Ce que l'API ne fera jamais

Deux étapes n'existent pas dans l'API, et resteront web :

- **créer l'application** (nom, langue par défaut, gratuite ou payante) ;
- **les déclarations** : questionnaire de contenu, public cible, sécurité des
  données, politique de confidentialité, présence de publicité.

Il faut les avoir faites une fois, à la main, avant que la moindre commande
serve à quelque chose.

### Les sources de vérité

Tout est dans `android/app/src/main/play/` :

```
default-language.txt          fr-FR
contact-email.txt             À REMPLIR — adresse publique exigée par Google
contact-website.txt
listings/<langue>/title.txt              (30 car.)
listings/<langue>/short-description.txt  (80 car.)
listings/<langue>/full-description.txt   (4000 car.)
listings/<langue>/graphics/icon/                 512 × 512
listings/<langue>/graphics/feature-graphic/     1024 × 500
listings/<langue>/graphics/phone-screenshots/   six captures, 1080 × 2340
release-notes/<langue>/<piste>.txt       (500 car.)
```

Les deux langues (`fr-FR`, `en-US`) sont remplies, textes ET captures. Les
captures viennent d'un vrai téléphone, et la description n'annonce que ce que
l'app Android fait — ni l'import de répertoire PGN, ni l'alerte gaffe, ni la
synchro iCloud, qui sont des fonctions iOS.

**Une seule chose à remplir avant de publier** : `contact-email.txt`. Google
exige une adresse de contact PUBLIQUE sur la fiche ; je n'en ai pas choisi une
à votre place.

### Refaire les captures

Elles ont été prises à l'`adb` sur un Galaxy A16, l'app dans la langue voulue :

```bash
adb shell cmd locale set-app-locales com.chesslab --locales fr-FR
adb shell am force-stop com.chesslab && adb shell am start -n com.chesslab/.MainActivity
adb exec-out screencap -p > 1-accueil.png
```

Sur l'ÉMULATEUR, le clavier flottant de Gboard s'incruste dans l'image dès
qu'un champ de saisie a eu le focus, et ni `ESC` ni la désactivation de l'IME
ne l'enlèvent proprement. D'où les captures prises sur un vrai téléphone.

## 4. Créer la fiche

**La fiche est déjà rédigée et versionnée** (voir §3bis) : cette section décrit
ce que l'API ne sait PAS faire et qu'il faut donc saisir à la main, plus les
formats, pour qui voudrait refaire les visuels.

Play Console → **Créer une application** — cette étape-là n'a pas d'API. Puis,
dans « Développer la présence sur le Play Store » :

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

Écrits et versionnés dans `app/src/main/play/listings/` — `./gradlew
publishListing` les envoie. Limites respectées : titre 30, description courte
80, description complète 4000.

Ils dérivent de `AppStoreSubmission/METADATA.md` mais **ne le recopient pas** :
l'app Android n'a ni import de répertoire PGN, ni alerte gaffe, ni synchro
iCloud, et la fiche ne les annonce donc pas. Elle annonce en revanche ce
qu'iOS n'a pas encore : les puzzles tirés de vos propres fautes.

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

Une fois la fiche créée dans la console et la clé du compte de service posée,
tout passe par Gradle (§3bis) — sauf les déclarations de §4.3, qui restent à la
main une fois pour toutes.

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
- [ ] **`contact-email.txt`** — l'adresse publique de contact, la seule pièce
      de la fiche que je n'ai pas remplie à votre place.
- [ ] Les déclarations de §4.3 dans la console (classification, sécurité des
      données, public cible) : aucune API ne les couvre.
