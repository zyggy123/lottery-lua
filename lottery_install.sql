-- --------------------------------------------------------------------------------------
--  LOTTERY SYSTEM - Installation Script
--  NPC Entry: 500000
--  Description: Creates a lottery master NPC that handles lottery games
-- --------------------------------------------------------------------------------------

-- Configuration Variables
SET
@Entry      := 500000,
@Model      := 19646,    -- Human Male model
@Name       := "Lottery Master",
@Title      := "Lucky Games",
@Icon       := "Speak",
@GossipMenu := 0,
@MinLevel   := 80,
@MaxLevel   := 80,
@Faction    := 35,       -- Friendly to all
@NPCFlag    := 1,        -- Gossip flag
@Scale      := 1.0,
@Type       := 7,        -- Humanoid
@TypeFlags  := 0,
@FlagsExtra := 2;

-- Cleanup existing entries
DELETE FROM `creature_template` WHERE `entry` = @Entry;
DELETE FROM `creature_template_model` WHERE `CreatureID` = @Entry;
DELETE FROM `creature_text` WHERE `CreatureID` = @Entry;
DELETE FROM `smart_scripts` WHERE `entryorguid` = @Entry AND `source_type` = 0;

-- Create NPC Template
INSERT INTO creature_template (
    `entry`, `name`, `subname`, `IconName`, `gossip_menu_id`, 
    `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, 
    `speed_run`, `scale`, `unit_class`, `unit_flags`, `type`, 
    `type_flags`, `RegenHealth`, `flags_extra`, `AIName`, `ScriptName`
) VALUES (
    @Entry, @Name, @Title, @Icon, @GossipMenu,
    @MinLevel, @MaxLevel, @Faction, @NPCFlag, 1,
    1.14286, @Scale, 1, 2, @Type,
    @TypeFlags, 1, @FlagsExtra, '', 'npc_lottery'
);

-- Add NPC Model
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(@Entry, 0, @Model, 1, 1, 0);

-- Add NPC Periodic Yell Text
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(@Entry, 0, 0, 'Step right up! Try your luck in our lottery! Just one Emblem of Frost could win you amazing prizes!', 14, 0, 100, 22, 0, 0, 0, 0, 'Lottery Master Yell');

-- --------------------------------------------------------------------------------------
-- INSTALLATION INSTRUCTIONS:
-- 1. Run this SQL script
-- 2. Place lottery.lua in your lua_scripts folder
-- 3. Restart your server
-- 4. Spawn NPC with: .npc add 500000
-- --------------------------------------------------------------------------------------
