# Swift Coach - Suivi des taches

## Objectif
Ce document sert de point d'entree pour un agent qui reprend le projet.
Il decrit:
- ce qui existe vraiment dans le code
- ce qui est partiel ou mocke
- ce qui reste a faire
- l'ordre recommande de travail
- les criteres d'acceptation par tache

## Resume rapide
Etat actuel du projet:
- UI prototype avancee en SwiftUI
- support local MLX et backend distant deja branches
- experience coach/exercice surtout mockee autour d'un seul exo "Two Sum"
- logique de compilation/revue principalement codee en dur
- couverture de tests encore faible sur les couches critiques

## Fichiers clefs
- App bootstrap: [swiftcoach/swiftcoachApp.swift](/Users/sharikmohamed/Documents/MyProject/swiftcoach/swiftcoach/swiftcoachApp.swift:1)
- Etat global: [swiftcoach/App/AppState.swift](/Users/sharikmohamed/Documents/MyProject/swiftcoach/swiftcoach/App/AppState.swift:1)
- IA locale/distante: [swiftcoach/ViewModels/AIViewModel.swift](/Users/sharikmohamed/Documents/MyProject/swiftcoach/swiftcoach/ViewModels/AIViewModel.swift:1)
- Service local MLX: [swiftcoach/Services/LocalLLMService.swift](/Users/sharikmohamed/Documents/MyProject/swiftcoach/swiftcoach/Services/LocalLLMService.swift:1)
- Service backend HTTP: [swiftcoach/Services/RemoteLLMService.swift](/Users/sharikmohamed/Documents/MyProject/swiftcoach/swiftcoach/Services/RemoteLLMService.swift:1)
- Mode coach mock: [swiftcoach/ViewModels/CoachViewModel.swift](/Users/sharikmohamed/Documents/MyProject/swiftcoach/swiftcoach/ViewModels/CoachViewModel.swift:1)
- Donnees mockees exercice: [swiftcoach/Models/ExerciseModel.swift](/Users/sharikmohamed/Documents/MyProject/swiftcoach/swiftcoach/Models/ExerciseModel.swift:1)
- Vues principales: [swiftcoach/Views/AssistantWorkspaceView.swift](/Users/sharikmohamed/Documents/MyProject/swiftcoach/swiftcoach/Views/AssistantWorkspaceView.swift:1)
- Tests actuels: [swiftcoachTests/swiftcoachTests.swift](/Users/sharikmohamed/Documents/MyProject/swiftcoach/swiftcoachTests/swiftcoachTests.swift:1)

## Etat des features

### Fait
- Shell SwiftUI desktop/mobile en place
- Theme sombre coherent
- Sidebar coach, brief exo, editeur mock, feedback panel, toolbar Swift mobile
- Chargement d'un modele local MLX
- Support d'un backend HTTP distant
- Selection de provider local / codex / claude / gemma
- Prompt builder reutilisable
- Quelques tests unitaires de base

### Partiel
- Backend distant: endpoints metier formalises (`/providers`, `/chat`, `/exercise/generate`, `/review`, `/hint`)
- Integration IA: reponse texte, pas de workflow metier complet
- Edition de code: basique, pas un vrai editeur de prod
- Annotations: rendues en UI mais pas produites par une vraie revue backend
- Chat coach: experience mostly demo
- Etats produit: melange de logique reelle et de simulation

### Mocke / code en dur
- Exercice unique "Two Sum"
- Hints, annotations, console, messages coach
- Evaluation du code par heuristiques string-based
- Resultats de compilation/revue non relies a un moteur Swift reel

## Regles de reprise pour un agent
- Ne pas casser le prototype UI existant sans raison
- Conserver la separation AppState / AIViewModel / CoachViewModel tant qu'une refonte n'est pas necessaire
- Eviter de melanger encore plus le mode demo et le mode reel
- Chaque nouvelle feature doit dire explicitement si elle est:
  - demo
  - reel backend
  - reel local
- Ajouter des tests des qu'une couche de service ou de transformation est touchee

## Priorites recommandees

### P0 - Stabiliser la couche backend reelle
Statut: fait

#### Tache P0.1 - Formaliser le contrat backend
Statut: fait

But:
- definir clairement les endpoints attendus pour l'app

A faire:
- documenter les routes minimales:
  - `GET /providers`
  - `POST /chat`
  - `POST /exercise/generate`
  - `POST /review`
  - `POST /hint`
  - optionnel: `POST /compile`
- definir les payloads request/response Swift decodables
- separer erreurs backend explicites et erreurs reseau

Critere d'acceptation:
- un fichier de modeles reseau existe
- les structs `Codable` sont dediees et non melangees au domaine UI
- les reponses attendues sont documentees dans le repo

Livrables:
- `BACKEND_CONTRACT.md`
- `swiftcoach/Services/BackendAPIModels.swift`

#### Tache P0.2 - Etendre `RemoteLLMService`
Statut: fait

But:
- supporter les futurs usages metier, pas seulement le chat libre

A faire:
- ajouter des methodes pour:
  - fetch exercise
  - fetch review
  - fetch hint
- unifier la construction d'URL et la validation HTTP
- normaliser les messages d'erreur utilisateur

Critere d'acceptation:
- le service couvre tous les endpoints metier retenus
- pas de duplication de logique HTTP
- erreurs reseau et erreurs backend clairement differenciees

Livrables:
- `swiftcoach/Services/RemoteLLMService.swift`

#### Tache P0.3 - Ajouter des tests HTTP sur la couche backend
Statut: fait

But:
- tester la connexion backend pour de vrai, sans reseau reel

A faire:
- mocker `URLSession` via `URLProtocol`
- tester:
  - succes `/providers`
  - succes `/chat`
  - 4xx avec message backend
  - 5xx sans message backend
  - URL invalide
  - backend indisponible

Critere d'acceptation:
- `RemoteLLMService` a une suite de tests dedies
- les erreurs critiques sont couvertes

Livrables:
- `swiftcoachTests/RemoteLLMServiceTests.swift`

### P1 - Sortir du mode demo sur le workflow exercice
Statut: en cours

#### Tache P1.1 - Isoler le mode demo du mode reel
Statut: fait

But:
- ne plus confondre simulation locale et vrai flux produit

A faire:
- introduire une source de donnees explicite:
  - `demo`
  - `remote`
  - `local`
- eviter que `CoachViewModel` decide a la fois l'UI et la fausse logique metier
- deplacer les mocks `Two Sum` dans un namespace/fichier `Demo`

Critere d'acceptation:
- les donnees mockees sont isolees
- il est clair dans le code quand on est en mode demo

Livrables:
- `swiftcoach/Demo/CoachDemoData.swift`
- `AppState.ExerciseDataSource`
- `CoachViewModel(dataSource:)`

#### Tache P1.2 - Generer un exercice reel depuis un theme
But:
- brancher la sidebar coach sur une vraie creation d'exercice

A faire:
- sur clic theme ou message utilisateur, appeler le backend
- mapper la reponse vers un `Exercise`
- hydrater brief, starter code, hints, metadata

Critere d'acceptation:
- un theme dans la sidebar peut charger un exo sans repasser par les mocks
- l'exercice affiche des donnees backend reelles

#### Tache P1.3 - Brancher une vraie revue de code
But:
- remplacer les annotations heuristiques par une revue retournee par le backend

A faire:
- envoyer code + contexte + sortie eventuelle
- recevoir:
  - summary
  - state
  - annotations structurees
  - hint optionnel
- afficher le resultat dans le panneau feedback

Critere d'acceptation:
- `annotations` ne dependent plus de regex/string matching local
- `CoachViewModel` ne deduit plus `success/error/resolved` uniquement depuis le texte

### P2 - Rendre l'editeur et la session plus credibles
Statut: a faire

#### Tache P2.1 - Introduire un vrai buffer d'edition
But:
- preparer une experience plus proche d'un vrai IDE

A faire:
- centraliser le texte source et le caret
- rendre la toolbar Swift compatible avec une insertion plus propre
- definir une strategie si on garde SwiftUI natif ou si on integre un editeur tiers

Critere d'acceptation:
- la source modifiee dans l'editeur est la source utilisee pour les appels review/compile

#### Tache P2.2 - Historique de session
But:
- garder les exercices, tentatives et feedbacks

A faire:
- definir un store local simple
- sauvegarder exercice courant, code courant, dernier feedback

Critere d'acceptation:
- relancer l'app restaure au moins la session courante

### P3 - Qualite produit
Statut: a faire

#### Tache P3.1 - Ajouter des UI tests utiles
But:
- verifier les parcours critiques

A faire:
- test lancement app
- test changement provider
- test affichage ecran de chargement modele local
- test affichage erreur backend

Critere d'acceptation:
- les UI tests couvrent au moins un flow local et un flow backend

#### Tache P3.2 - Nettoyage architecture
But:
- reduire le couplage entre vues demo et logique metier

A faire:
- clarifier les responsabilites entre:
  - `AIViewModel`
  - `CoachViewModel`
  - `EditorViewModel`
  - modeles reseau
  - modeles domaine

Critere d'acceptation:
- moins de logique metier dispersee dans les vues
- moins de donnees globales mockees au niveau fichier

## Taches deja en cours ou recentes
- Injection du service IA dans `AIViewModel` pour tests
- Tests unitaires de base sur les erreurs/streams IA

## Backlog optionnel
- Mode solution
- Stats par theme
- Auth / sync multi-device
- streaming reponse backend token par token
- vrai compilateur Swift distant
- support multi-exercices

## Recommandation immediate
Ordre conseille pour le prochain agent:
1. Faire P0.1
2. Faire P0.2
3. Faire P0.3
4. Faire P1.1
5. Faire P1.2
6. Faire P1.3

## Definition of done
Une tache est consideree terminee si:
- le code compile
- les tests pertinents existent ou sont mis a jour
- la feature n'est pas seulement visible en UI mais branchee a une source de verite claire
- le mode demo et le mode reel sont explicitement distingues si necessaire
