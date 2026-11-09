# v8 balance release criteria (release checklist)

This document defines the release checks. Evidence and remaining limitations are recorded in ENDLESS-V8.md and the independent balance audit. It is not a universal balance proof.

## Player-facing goals

- Preserve deterministic, inspectable battles and seeds, paired stairs, sealed worthwhile rooms, and meaningful alternatives.
- Distinguish automatic floor progression from finite build advantages. Every permanent attack/defence source must respect the same explicit budget, including purchases, training, relics and quest rewards.
- Do not scale an already generated enemy to the current player, add arbitrary unavoidable minimum damage, or change old version replays.
- Do not punish good play: some zero-damage victories are desirable. The failure to fix is a single cheap policy making every later encounter and consumable irrelevant.
- Health storage and sustainable recovery must be explicit. Capping health is not on its own evidence of meaningful resource decisions. Hoarded gold is not itself a bug; useful recurring spending should exist without forced taxation.
- Earlier floors should genuinely become easier. Optional guarded rewards must remain useful without allowing unlimited permanent-stat accumulation.

## Required evidence before release

- Frozen v1–v7 tests and old replay routes unchanged; v8 exact-version native and production Web-storage round trips, unknown versions rejected.
- Actual legal move/action sequences through 50 and 100 floors, across seeds and contrasting routes/builds. Report deaths and failed policies honestly, not only successful samples.
- Separate first zero-loss floor from sustained zero-loss suffix. Record health, gold, actual spending, consumed items, builds, route diversity and late-floor damage.
- A conservative legal survival policy must exist for the tested seeded layouts without requiring optional treasure or one random shop type. Describe scope: tested samples are not a universal solvability proof.
- Test every permanent-stat source against the shared cap, including partial gains at the boundary and refusal without charge when exhausted. Test heal-at-cap and quest/relic one-time rewards.
- Sequential route forecast matches real battles, including one-use item consumption, first-strike lethality, and post-survival healing. Never duplicate an armed item across route guards.
- Native UI play checks the growth explanation, actual choice costs, budget at cap, battles and reload. Headless tests do not substitute for this.
- Godot Web engine remains unverified while the browser is WebGL-blocklisted; Chrome storage protocol tests must not be labelled Web gameplay.
- Only publish after full local regression and exact-commit CI; verify root BUILD and deployment success. No preview-only delivery.

Global ranking remains device-local until a separately authorized backend exists. No accounts, billing commitments or player-data uploads are part of this balance batch.
