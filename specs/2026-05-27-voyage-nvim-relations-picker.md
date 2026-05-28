# Spec: Voyage.nvim relations picker hiérarchique

## 1. Meta
- Date: 2026-05-27
- Statut: DRAFT
- Auteur: Codex + tlambert
- Portée: plugin Neovim dédié Voyage (sans dépendance Telescope)

## 2. Contexte / Problème
Objectif: naviguer les relations entre notes via Voyage (`vo`) dans une UI popup type picker avec:
- champ de recherche,
- liste hiérarchique pliable,
- preview fichier à droite,
- conservation des ancêtres quand un enfant match la recherche.

Un picker Telescope standard est mal adapté au besoin hiérarchique (liste flat par défaut et gestion fold/unfold plus complexe).

## 3. Objectifs
- Ouvrir une fenêtre popup 2 panneaux (résultats gauche, preview droite).
- Interroger Voyage sur une note source et afficher un arbre de relations.
- Filtrer en live tout en gardant les ancêtres des nœuds matchés.
- Supporter fold/unfold clavier sur l’arbre.
- Charger la preview à la demande (lazy) et rester fluide.
- Limiter les dépendances (Voyage obligatoire, pas Telescope requis).

## 4. Non-objectifs
- Pas de multi-select.
- Pas d’actions batch.
- Pas de persistance d’état entre sessions.
- Pas d’intégration LSP.
- Pas de support d’autres backends que Voyage en V1.

## 5. Scope
In:
- Commande utilisateur calquée sur le pattern Scretch:
  - `:Voyage <function>`
  - sans argument: fallback sur `:Voyage new` (ouverture picker sur note courante)
  - completion des fonctions publiques (hors `setup`)
- Appel à `vo` avec sortie machine (JSON) dédiée plugin.
- Arbre initial limité par profondeur configurée (défaut: 2).
- Recherche textuelle sur libellé/chemin, avec règle: match enfant => ancêtres visibles; siblings non-matchés cachés.
- Navigation clavier:
  - panneau résultats: `j/k` déplacement, `h/l` fold/unfold, `<Tab>` focus preview, `<CR>` ouvrir la note.
  - panneau preview: `j/k` scroll, `<CR>` ouvrir la note en cours de preview, `<Tab>` retour résultats.
- Gestion erreurs non bloquante (message utilisateur) si preview impossible.
- Documentation Vim help en fichier texte:
  - `doc/voyage.txt` consultable via `:h voyage`
  - génération/maintenance du tag help `voyage`

Out:
- Telescope integration native.
- Tri/stratégies avancés côté plugin (V1 suit l’ordre fourni par Voyage).
- Caching persistant.

## 6. Risques et Impacts
- Couplage fort au format machine `vo`.
- Taille de payload JSON si graphe large.
- Jank UI si rerender complet à chaque frappe.

Mitigations:
- Versionner le contrat JSON (`schema_version`).
- Arbre rendu à profondeur bornée + filtre incrémental en mémoire.
- Preview lazy + garde sur fichiers trop gros/binaires avec message non bloquant.

## 7. Approche proposée
- Plugin Lua pur avec API Neovim (`vim.api`, `vim.uv`, `vim.fn.jobstart` ou équivalent async).
- UI popup custom (buffers/floating windows) au lieu de Telescope.
- Entrypoint commande dans `plugin/voyage.lua`, suivant l’ergonomie de `plugin/scretch.lua`.
- Pipeline:
  1. Résoudre la note courante.
  2. Exécuter `vo` en mode machine.
  3. Construire modèle arbre interne (`id`, `path`, `label`, `children`, `expanded`, `depth`).
  4. Générer une vue linéarisée des nœuds visibles.
  5. Appliquer filtre avec propagation visibilité vers ancêtres.
  6. Rendre panneau résultats + preview lazy du nœud sélectionné.

Contrat Voyage v0.1.1 (confirmé):
- Commande:
  - `vo --format json --tree --depth <N> <path-note.md>`
- Contrainte CLI:
  - `--format json` est valide uniquement avec `--tree`.
- Payload succès:
  - `schema_version` (string, attendu: `"1.0.0"` en v0.1.1)
  - `root` (node)
  - node: `id`, `label`, `path`, `dangling` (bool), `children` ([]node)
  - convention dangling:
    - `dangling = true`
    - `id = "dangling:<label>"`
    - `path = ""`
- Payload erreur JSON (si `--format json`):
  - `schema_version` (string)
  - `error.code` (string)
  - `error.message` (string)

## 8. Alternatives considérées
- Telescope picker custom:
  - Avantage: UI existante.
  - Inconvénient: gestion native hiérarchique/fold + focus preview atypique, complexité de contournement.
  - Décision: rejetée pour V1.
- Parser la sortie texte de `vo`:
  - Rejetée (fragile et coûteuse à maintenir).

## 9. Plan d'implémentation
1. Créer squelette plugin Lua (`setup`, config, commande user).
2. Implémenter adaptateur Voyage (exec async + decode JSON + erreurs).
3. Implémenter modèle arbre + linéarisation visible + fold/unfold.
4. Implémenter moteur de filtre avec conservation ancêtres.
5. Implémenter UI popup 2 panneaux + gestion focus et mappings.
6. Implémenter preview lazy + fallback erreurs non bloquantes.
7. Ajouter tests unitaires Lua (commande, filtre/visibilité, fold/unfold, focus) + validation manuelle E2E.
8. Rédiger la doc `doc/voyage.txt` (commandes, config, mappings, exemples) + vérifier `:h voyage`.

## 10. Plan de test
- Unitaire:
  - `:Voyage` sans argument appelle la fonction `new`.
  - completion de `:Voyage <Tab>` expose les fonctions publiques (hors `setup`).
  - Filtre conserve ancêtres des nœuds matchés.
  - Siblings non matchés cachés.
  - Fold/unfold met à jour correctement la vue visible.
- Intégration plugin:
  - Ouverture picker depuis une note valide.
  - Changement focus résultats/preview via `<Tab>`.
  - `<CR>` ouvre la note correcte depuis chaque panneau.
  - Preview lazy charge le contenu complet du fichier sélectionné.
- Résilience:
  - `vo` absent/erreur JSON -> message non bloquant.
  - Preview fichier binaire/trop gros/inaccessible -> message non bloquant.

## 11. Critères d'acceptation
- AC-1: Le picker s’ouvre en popup 2 panneaux (résultats + preview) avec focus initial sur résultats.
- AC-2: La profondeur initiale est configurable et vaut `2` par défaut.
- AC-3: En recherche, si un enfant match, tous ses ancêtres restent visibles.
- AC-4: En recherche, les siblings non matchés d’une branche matchée ne sont pas affichés.
- AC-5: `j/k` naviguent dans le panneau actif; `h/l` fold/unfold dans résultats.
- AC-6: `<Tab>` bascule le focus entre résultats et preview.
- AC-7: `<CR>` ouvre la note ciblée depuis résultats ou preview.
- AC-8: Le preview charge le fichier complet de manière lazy et reste réactif.
- AC-9: En cas d’échec preview, un message non bloquant est affiché.
- AC-10: Le plugin fonctionne sans dépendance Telescope.
- AC-11: Les données affichées proviennent de `vo --format json --tree --depth <N>` et respectent `schema_version="1.0.0"` en v0.1.1.
- AC-12: Si l’appel JSON échoue côté `vo`, le plugin exploite `error.code/error.message` et affiche une erreur non bloquante.
- AC-13: La commande `:Voyage <function>` est disponible avec fallback sans argument vers `new`.
- AC-14: Une doc texte `doc/voyage.txt` est fournie et accessible via `:h voyage`.
- AC-15: Le plugin inclut des tests unitaires couvrant au minimum commande, filtrage hiérarchique et navigation de base.
