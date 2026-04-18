# swiftcoach

Application iOS développée en Swift / SwiftUI.

Le dépôt contient maintenant aussi un backend HTTP dans [backend](/home/ubuntu/myProject/swiftcoach/backend/README.md) pour exposer `codex`, `claude` et `gemma` au frontend iOS. L'app SwiftUI garde le mode local MLX et permet aussi de basculer vers ces providers backend.

## Prérequis
- Xcode 15+
- iOS 17.0+
- Node.js 18+ pour le backend

## Lancer le projet
Ouvre `swiftcoach.xcodeproj` dans Xcode.

Pour le backend:

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```
