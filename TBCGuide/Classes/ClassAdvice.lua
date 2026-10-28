-- TBCGuide - class-specific leveling advice
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Original advice written for this project from general TBC game knowledge. Ability training
-- levels quoted here are NOT machine-verified against client data (status = "unverified"); the
-- talent builds (Talents/Builds) are validated against the client's talent tables instead.
-- Class-quest steps inside guides reference real quest ids and are checked by the compiler.

local _, ns = ...

local Advice = {}
ns.ClassAdvice = Advice

Advice.status = "unverified"

Advice.data = {
    WARRIOR = {
        summary = "Strong but gear-dependent. Level as Arms with the best two-hander you can find; you take the most downtime of any class, so eat between pulls and keep First Aid up to date.",
        tips = {
            "Open every pull with Charge, then Rend and Heroic Strike with spare rage. Thunder Clap and Hamstring stop runners.",
            "Use Overpower whenever it lights up. In TBC Arms, Tactical Mastery lets you swap stance without losing much rage.",
            "Defensive Stance and Sunder Armor come from the level 10 class quest. Berserker Stance comes from the level 30 quest chain.",
            "Weapon upgrades matter more than anything else. Take two-handed quest rewards and check the auction house at 20, 30 and 40.",
            "Mortal Strike (40) and Improved Slam are the core of Arms leveling. Fury pays off once you dual-wield good weapons, usually at 60+.",
            "Learn Intercept and Whirlwind in Berserker Stance for faster kills and escapes. Keep a cheap shield for Shield Bash or emergency Shield Wall.",
            "Grouping helps: warriors tank dungeons well from about level 20, and dungeon gear speeds up solo play.",
        },
        trainingLevels = { 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70 },
    },
    PALADIN = {
        summary = "Durable and self-sufficient. Level as Retribution with a slow two-hander. Seal plus Judgement plus auto-attack does most of your damage, and you heal yourself between fights.",
        tips = {
            "Rotation: keep a Seal up and Judge it on cooldown. Use Seal of the Crusader early and Seal of Command once talented. Re-seal after each Judgement.",
            "Blessing of Might (or Wisdom if you run low on mana) and Retribution Aura are your default buffs for questing.",
            "Consecration (20) and Exorcism (vs undead and demons) make multi-pulls easy. Hammer of Justice interrupts healers and fleeing mobs.",
            "Redemption comes from a class quest at level 12, so do it when your trainer sends you.",
            "Seal of Blood (Blood Elf) and Seal of Vengeance (Draenei and other Alliance paladins) arrive at 64 and are strong upgrades.",
            "Crusader Strike is the 41-point Retribution talent and the heart of TBC Retribution. Protection is excellent for dungeon AoE tanking from the 40s.",
        },
        trainingLevels = { 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 62, 64, 66, 68, 70 },
    },
    HUNTER = {
        summary = "The fastest and safest solo leveler. Beast Mastery lets your pet tank while you shoot. Keep the pet's level and happiness up.",
        tips = {
            "At level 10 the class trainer starts the 'Taming the Beast' quests. Finish them to get Tame Beast and your first pet.",
            "Buy ammo and food for your pet in bulk. Running out of arrows or bullets is the most common hunter slowdown.",
            "Rotation: Hunter's Mark, then Serpent Sting and Arcane Shot while the pet holds aggro. Learn Steady Shot at 62.",
            "Use Aspect of the Hawk for damage and Aspect of the Cheetah for travel (watch for dazes). Learn Feign Death at 30.",
            "Train your pet's abilities (Growl, Bite or Claw) from beasts you tame and from pet trainers. Keep the pet within a few levels of you.",
            "Tame a new pet when a better one is available, for example a boar for Charge or a raptor or cat for damage.",
        },
        trainingLevels = { 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70 },
    },
    ROGUE = {
        summary = "Combat Swords with high weapon damage is the steady leveling choice. Mostly use Sinister Strike and Slice and Dice, plus Eviscerate on mobs that are about to die.",
        tips = {
            "Pick your fights: Stealth past packs and open with Cheap Shot or Ambush on dangerous targets.",
            "Poisons unlock at 20 through a class quest. Instant Poison on the main hand is a large damage boost while leveling.",
            "Evasion, Sprint, Gouge and Vanish are your emergency buttons. Use Blind (34) to stop a second mob.",
            "Keep both weapons upgraded, the main hand most of all. Slow main-hand speed boosts Sinister Strike damage.",
            "Lockpicking from your trainer lets you open lockboxes for profit and some quests.",
            "In TBC, Combat Swords and Mutilate (41-point Assassination, daggers) are both viable. Combat is more forgiving solo.",
        },
        trainingLevels = { 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 62, 64, 66, 68, 70 },
    },
    PRIEST = {
        summary = "Shadow is the leveling spec. Wand-finish your kills to save mana. Shadowform at 40 and Vampiric Embrace make you very self-sufficient.",
        tips = {
            "Opener: Power Word: Shield, Shadow Word: Pain, Mind Blast, then wand. Spirit Tap (Shadow) refills mana after kills.",
            "Get a wand as early as possible from Enchanting, the auction house or quest rewards. It is your main damage until your 30s.",
            "Learn Mind Flay early. In TBC Shadow it is the main filler once you have the talent.",
            "Check your trainer for racial priest spells. Different races learn different extra abilities.",
            "Psychic Scream and Fade get you out of trouble. Shield before you get hit to avoid spell pushback.",
            "Holy or Discipline healers are welcome in every dungeon group, so consider dungeon runs for gear.",
        },
        trainingLevels = { 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 62, 64, 66, 68, 70 },
    },
    SHAMAN = {
        summary = "Enhancement with a two-hander levels smoothly. Each totem element comes from a class quest. Dual Wield is an Enhancement talent at level 40 in TBC.",
        tips = {
            "Totem quests: Earth around level 4, Fire around 10, Water around 20 and Air around 30. Your trainer starts each one.",
            "Use Rockbiter early, then Flametongue or Windfury Weapon. Keep Lightning Shield up and Earth Shock casters.",
            "Use Searing Totem plus Stoneskin or Strength of Earth on longer fights. Skip totems on quick kills to save mana.",
            "Ghost Wolf from level 20 speeds up travel. Shamanistic Rage (41-point Enhancement) removes most mana problems.",
            "Stormstrike (Enhancement talent) hits hard with slow weapons. Elemental is good at 70 but heavy on mana while leveling.",
            "Draenei shamans do their totem quests in Azuremyst and Bloodmyst, not in Orgrimmar or Thunder Bluff.",
        },
        trainingLevels = { 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70 },
    },
    MAGE = {
        summary = "Frost is the safest leveling spec. Kite with Frostbolt, Frost Nova and Cone of Cold, and AoE-grind dense packs with Blizzard once you have the talents.",
        tips = {
            "Conjure your own food and water, so you rarely visit vendors. Keep a full stack of each.",
            "Single target: Frostbolt until close, then Frost Nova, step back, and Frostbolt or Fire Blast to finish.",
            "AoE grinding (from about 22 with Improved Blizzard): gather a pack, Frost Nova, Blizzard, Cone of Cold. This is very fast in good spots.",
            "Ice Barrier and Ice Block (talents) and Blink (20) are your escapes. Polymorph handles a second mob.",
            "Learn teleports to the capital cities, and portals from 40. Use them to save travel time.",
            "At 70, Arcane and Fire are the raid DPS specs. Frost stays strong for PvP and dungeon control.",
        },
        trainingLevels = { 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 62, 63, 64, 65, 66, 68, 69, 70 },
    },
    WARLOCK = {
        summary = "Very low downtime: Life Tap for mana, Drain Life and pets for health. Affliction or Demonology both level well with the Voidwalker or Felguard tanking.",
        tips = {
            "Pet quests: Voidwalker at 10, Succubus at 20 and Felhunter at 30. Your trainer starts each one.",
            "DoT and move on: Corruption, Curse of Agony and Immolate. Fear the second mob and Drain Life to keep your health up.",
            "Life Tap and then heal with Drain Life or First Aid instead of drinking. Keep soul shards for Soulstone and Healthstone.",
            "Siphon Life and Dark Pact (Affliction) or Soul Link and Felguard (Demonology, 41 points) make solo play very smooth.",
            "Your summoned mount arrives with a class quest at 40, and the epic mount at 60.",
            "Health Funnel saves your Voidwalker on big pulls. Sacrifice it in emergencies for a shield.",
        },
        trainingLevels = { 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70 },
    },
    DRUID = {
        summary = "Feral levels fastest. Use Bear form from 10, Cat form from 20 and Travel form from 30. Shifting removes snares, and you can heal yourself between fights.",
        tips = {
            "Bear Form comes from a class quest at 10, and Aquatic Form from a quest at 16. Cat Form is trained at 20.",
            "Cat: Prowl, then Ravage or Pounce. Use Claw or Shred to 4-5 combo points, then Rip or Ferocious Bite. Bear is safer for multiple mobs.",
            "Out of combat, shift out and Rejuvenate or Regrowth, then drink only when mana is low. Furor makes shifting cheap.",
            "Travel Form at 30 is a big speed boost before your mount. Teleport: Moonglade gives quick access to the trainer.",
            "Mangle (41-point Feral) and Leader of the Pack are the TBC Feral core. Feral tanks are strong in dungeons.",
            "Moonkin and Restoration are excellent at 70, but Feral or a hybrid build is the leveling choice.",
        },
        trainingLevels = { 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70 },
    },
}

function Advice:For(class) return self.data[class] end

function Advice:PrintFor(class)
    local a = self.data[class]
    if not a then return ns:Print("No advice for " .. tostring(class)) end
    ns:Print("|cffffd100" .. class .. " leveling tips|r")
    DEFAULT_CHAT_FRAME:AddMessage("  " .. a.summary)
    for _, t in ipairs(a.tips) do DEFAULT_CHAT_FRAME:AddMessage("  - " .. t) end
end

-- Is `level` a level at which this class normally gets new trainable ranks?
function Advice:IsTrainingLevel(class, level)
    local a = self.data[class]
    return a and ns.Contains(a.trainingLevels, level) or false
end
