---
name: session
description: Démarre une session de travail sur un jalon du projet Citadelle
argument-hint: "[jalon, ex: T1]"
disable-model-invocation: true
---

# Session de travail — Citadelle

Jalon visé : **$ARGUMENTS**

---

## 1. Orientation — avant toute chose

Lis intégralement, dans cet ordre : `CLAUDE.md`, `DESIGN.md`, puis `JOURNAL.md` en commençant par la dernière entrée.

Puis vérifie l'état de départ :

```bash
git status
godot --headless --quit --path .
```

Si l'arbre git n'est pas propre, arrête-toi et signale-le. Si le projet ne parse pas déjà, répare ça avant tout le reste — ne construis rien sur une base cassée.

Si aucun jalon n'est passé en argument, propose celui qui vient logiquement d'après `JOURNAL.md` et attends ma confirmation.

---

## 2. Plan — avant d'écrire une ligne de code

Produis un plan court, en texte, structuré ainsi :

- les DTO à créer ou modifier dans `contracts/`, et pourquoi
- les classes de domaine à écrire, avec leur signature publique
- les cas de test qui prouveront que ça marche
- les adapters et les harnais de dev à écrire
- **ce que je dois faire moi dans l'éditeur** — décris l'arbre de nœuds, les types et les propriétés, ne crée rien
- ce que tu ne feras **pas** dans cette session, et pourquoi

Puis arrête-toi. N'écris aucun code avant que j'aie validé le plan.

---

## 3. Exécution — ordre imposé

Un commit par étape, jamais les couches mélangées :

1. `src/domain/contracts/` — les DTO seuls
2. `src/domain/<systeme>/` — la logique pure, aucun `Node`
3. `tests/` — la couverture de ce qui a été écrit à l'étape 2
4. `src/adapters/` et `scenes/dev/*.gd` — les vues et le harnais

Lance la vérification après chaque étape, pas seulement à la fin.

---

## 4. Vérification

```bash
godot --headless --quit --path .
addons/gdUnit4/runtest.sh -a tests
```

Une étape n'est pas terminée tant que ces deux commandes ne passent pas sans erreur ni warning de script. Lance-les toi-même. Ne me demande pas de les lancer, et n'annonce jamais un travail fini au motif que le code « devrait » compiler.

---

## 5. Arrête-toi et demande si

- un DTO de `contracts/` doit changer de forme
- une décision marquée `OUVERT` dans `DESIGN.md` bloque l'avancement
- un `.tscn` ou `project.godot` doit être modifié
- une dépendance externe paraît nécessaire
- le jalon s'avère nettement plus gros que prévu

Ne tranche jamais une question de design à ma place. Propose, argumente, attends la réponse.

---

## 6. Clôture

Ajoute une entrée datée à `JOURNAL.md` :

- jalon traité et son état — terminé ou partiel
- décisions prises, et la raison de chacune
- ce qui reste à faire, et le prochain jalon logique
- ce que j'ai à faire dans l'éditeur avant la prochaine session

Si une question `OUVERT` a été tranchée pendant la session, mets `DESIGN.md` à jour dans le même commit — le journal seul ne suffit pas, la prochaine session lira le design.

Termine par un résumé de cinq lignes maximum.
