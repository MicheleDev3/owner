# Adopt Me style pets & eggs

A Roblox pet system where pets and eggs **follow you and equip like in Adopt Me**:

- **Backpack**: press the 🎒 button (or `B`) and click a pet or egg to equip it. Click it again to put it away. Equipping a different one swaps it (one out at a time, like Adopt Me; change `MaxEquipped` in `PetConfig`).
- **Follow**: the pet walks to a spot behind you and to your right, stays on the ground (even when you jump), faces where it's walking, and turns to face your direction when you stop. If it falls too far behind, it teleports back to you.
- **Equip effect**: the pet pops up out of the ground with a bouncy grow, sparkles, a puff of smoke and a sound; putting it away shrinks it with a puff. Set your own sounds in `PetConfig.Effects`.
- **Animation**: pets trot with a small bounce and sit down after standing still for a few seconds. Eggs hop and waddle side to side.
- Other players see everyone's pets. Each client animates all pets locally, so movement is smooth and costs the server nothing.

## Files

| File | Goes in Studio as |
|---|---|
| `src/shared/PetConfig.lua` | ModuleScript `ReplicatedStorage.Shared.PetConfig` |
| `src/shared/PetModelBuilder.lua` | ModuleScript `ReplicatedStorage.Shared.PetModelBuilder` |
| `src/shared/PetEffects.lua` | ModuleScript `ReplicatedStorage.Shared.PetEffects` |
| `src/shared/PetAnimator.lua` | ModuleScript `ReplicatedStorage.Shared.PetAnimator` |
| `src/server/PetServer.server.lua` | Script in `ServerScriptService` |
| `src/client/PetFollow.client.lua` | LocalScript in `StarterPlayer.StarterPlayerScripts` |
| `src/client/PetInventoryUI.client.lua` | LocalScript in `StarterPlayer.StarterPlayerScripts` |
| `src/client/PetEquipEffects.client.lua` | LocalScript in `StarterPlayer.StarterPlayerScripts` |

## Install

**With Rojo:** run `rojo serve`, then connect from the Rojo plugin in Studio.

**By hand:** in `ReplicatedStorage`, create a Folder named `Shared`. Then create each script from the table above and paste in its contents.

## Using your own pet models

Put a Model in `ReplicatedStorage.PetModels` with the same name as the item in `PetConfig.Items`, for example `Dog`. Its PrimaryPart's LookVector should point forward. Items without a custom model use a built-in placeholder.

## Pet animations

Rigged pets (Motor6D joints) can play real animations. Make them in Studio's Animation Editor, publish them, then add a Folder named `Animations` inside the pet model in `ReplicatedStorage.PetModels` with `Animation` objects named:

| Name | When it plays |
|---|---|
| `Idle` | standing still (looped) |
| `Walk` | following you (looped, speeds up/slows down with the pet) |
| `Run` | catching up fast (looped, optional; uses `Walk` if missing) |
| `Sit` | after standing still for 3 seconds (looped, optional; uses `Idle` if missing) |
| `Equip` | once, when the pet pops in |

Animations only play if they're owned by the game's owner (you, or your group for group games). Pets with an `Animations` folder skip the built-in bounce/tilt.

## Humanoid pets (walking NPC pets)

If your pet model has a `Humanoid` and `HumanoidRootPart`, put a Script inside it with the contents of `pet-scripts/PetWalkHandler.server.lua` and store the model in `ReplicatedStorage.PetModels`. When it's equipped, the server clones it, names it after the owner's UserId, and the script walks it Adopt Me style. It uses the `PetPosition` / `PetWalkingPosition` / `PetBackStopPosition` / `PetBackPosition` / `PetProtector` parts on the character if they exist, otherwise built-in offsets.

## Adding pets or eggs

Add an entry to `PetConfig.Items` with `Kind = "Pet"` or `Kind = "Egg"`. Starter items are given in `PetServer.server.lua`; replace that with your DataStore loading.
