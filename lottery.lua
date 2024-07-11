local LOTTERY_COST = 1 -- Cost to enter the lottery with Emblem of Frost
local EMBLEM_OF_FROST_ID = 49426 -- ID for Emblem of Frost

local REGISTRATION_TIME_SECONDS = 60 -- 1 minute for the lottery registration period
local CLAIM_TIMEOUT_SECONDS = 120 -- 2 minutes for the prize claim timeout
local PRIZE_ITEM_ID = 49623 -- ID of the awarded prize

local participationTimes = {} -- Table to store the last participation time of each player
local participants = {} -- Table to store the names of players who participated in the lottery
local prizeItemName = "Unknown Prize" -- Default name of the prize

local nextDrawTime = 0 -- Variable to keep track of the next draw time
local winnerName = nil -- Variable to store the name of the current winner
local claimEndTime = 0 -- Time until the prize claim period expires
local isWaitingForClaim = false -- Variable to keep track of whether a prize claim is pending

-- Function to check if a player can enter the lottery based on cooldown and prize claim status
local function canPlayerEnterLottery(player)
    local playerId = player:GetGUIDLow()
    
    -- Check if waiting for prize claim
    if isWaitingForClaim then
        return false
    end

    if not participationTimes[playerId] then
        return true -- If never participated, allow entry
    end

    local currentTime = os.time()
    local lastParticipationTime = participationTimes[playerId]
    local elapsedTime = currentTime - lastParticipationTime

    if elapsedTime >= REGISTRATION_TIME_SECONDS then
        return true -- Enough time has passed since last participation
    else
        return false -- Still in cooldown
    end
end

-- Function to update the player's last participation time
local function updateLastParticipationTime(player)
    local playerId = player:GetGUIDLow()
    participationTimes[playerId] = os.time()
end

-- Function to add a player to the list of participants
local function addParticipant(player)
    local playerName = player:GetName()
    table.insert(participants, playerName)
end

-- Function to display the list of participants in chat
local function showParticipants(player)
    player:SendBroadcastMessage("Participants in the lottery:")
    for index, name in ipairs(participants) do
        player:SendBroadcastMessage(index .. ". " .. name)
    end
end

-- Function to initiate the lottery draw and handle prize claiming
local function performLotteryDraw()
    if not isWaitingForClaim then
        if #participants > 0 then
            local winningIndex = math.random(1, #participants)
            local winningPlayerName = participants[winningIndex]

            -- Update winner details
            winnerName = winningPlayerName
            prizeItemName = "Unknown Prize" -- Reset prize name
            claimEndTime = os.time() + CLAIM_TIMEOUT_SECONDS -- Set expiration time for prize claim

            -- Announce the winner globally
            SendWorldMessage(winnerName .. " has won the lottery prize! Congratulations!")

            -- Clear the list of participants for the next lottery round
            participants = {}

            -- Set the state for waiting for prize claim
            isWaitingForClaim = true

            -- Schedule check for prize claim after timeout
            CreateLuaEvent(checkPrizeClaim, CLAIM_TIMEOUT_SECONDS * 1000, 1)
        else
            SendWorldMessage("No participants in the lottery this time. Better luck next time!")
            nextDrawTime = os.time() + REGISTRATION_TIME_SECONDS -- Update time for next draw
        end
    end
end

-- Function to check if the winner has claimed the prize in time
local function checkPrizeClaim()
    if isWaitingForClaim then
        if winnerName and os.time() > claimEndTime then
            local winner = GetPlayerByName(winnerName)
            if winner and winner:IsInWorld() then
                -- Check if the winner has the prize in inventory
                if winner:HasItem(PRIZE_ITEM_ID) then
                    -- Prize has been claimed
                    awardPrize(winner)
                else
                    -- Prize not claimed in time
                    SendWorldMessage("Lottery prize not claimed by " .. winnerName .. ". The prize is forfeited. The lottery restarts.")
                    winnerName = nil -- Reset winner details
                    claimEndTime = 0 -- Reset claim expiration time
                    nextDrawTime = os.time() + REGISTRATION_TIME_SECONDS -- Update time for next draw
                    isWaitingForClaim = false -- Reset waiting for claim state
                end
            else
                -- Winner is no longer in the world, so prize is considered unclaimed
                SendWorldMessage("Lottery prize not claimed by " .. winnerName .. ". The prize is forfeited. The lottery restarts.")
                winnerName = nil -- Reset winner details
                claimEndTime = 0 -- Reset claim expiration time
                nextDrawTime = os.time() + REGISTRATION_TIME_SECONDS -- Update time for next draw
                isWaitingForClaim = false -- Reset waiting for claim state
            end
        end
    end
end

-- Function to initiate the waiting message for prize claim after draw
local function initiateClaimTimeoutMessage()
    if isWaitingForClaim then
        local winner = GetPlayerByName(winnerName)
        if winner and winner:IsInWorld() then
            SendWorldMessage("Participant " .. winnerName .. " is expected to claim the prize for 2 minutes.")
        end
    end
end

-- Function to award the prize to the winner
local function awardPrize(player)
    local itemName = GetItemLink(PRIZE_ITEM_ID) -- Get item name for message
    prizeItemName = itemName -- Update prize name for display in "Prize" option

    player:AddItem(PRIZE_ITEM_ID, 1) -- Add prize directly to player's inventory

    -- Inform the server about the winner
    SendWorldMessage("Congratulations to " .. player:GetName() .. " for winning the lottery!")

    -- Inform the player about winning the prize
    player:SendBroadcastMessage("Congratulations! You have claimed the lottery prize: " .. itemName)

    -- Reset winner details after prize claim
    winnerName = nil
    prizeItemName = "Unknown Prize" -- Reset prize name
    nextDrawTime = os.time() + REGISTRATION_TIME_SECONDS -- Update time for next draw
    isWaitingForClaim = false -- Reset waiting for claim state
end

-- Function to handle NPC interaction
local function onGossipHello(event, player, object)
    player:GossipClearMenu()
    
    if not isWaitingForClaim then
        player:GossipMenuAddItem(0, "Enter the lottery for " .. LOTTERY_COST .. " Emblem of Frost", 1, 1)
    end
    
    if winnerName and os.time() <= claimEndTime then
        player:GossipMenuAddItem(0, "Claim Lottery Prize", 1, 2)
    end
    
    player:GossipMenuAddItem(0, "Players", 1, 3)
    player:GossipMenuAddItem(0, "Countdown", 1, 4)
    player:GossipMenuAddItem(0, "Rules", 1, 5)
    player:GossipMenuAddItem(0, "Close", 1, 6)
    
    player:GossipSendMenu(1, object)
end

-- Function to handle option selection in NPC menu
local function onGossipSelect(event, player, object, sender, intid, code)
    if intid == 1 then
        -- Check if the player can enter the lottery
        if canPlayerEnterLottery(player) then
            if player:HasItem(EMBLEM_OF_FROST_ID, LOTTERY_COST) then
                player:RemoveItem(EMBLEM_OF_FROST_ID, LOTTERY_COST)
                updateLastParticipationTime(player) -- Update last participation time
                addParticipant(player) -- Add player to the list of participants
                player:SendBroadcastMessage("You have entered the lottery. Good luck!")
                nextDrawTime = os.time() + REGISTRATION_TIME_SECONDS -- Update time for next draw
            else
                player:SendBroadcastMessage("You don't have enough Emblems of Frost to enter the lottery!")
            end
        else
            player:SendBroadcastMessage("You must wait " .. (REGISTRATION_TIME_SECONDS / 60) .. " minutes before entering the lottery again.")
        end
    elseif intid == 2 then
        -- Check if there's a winner and if it's within the prize claim period
        if winnerName and os.time() <= claimEndTime then
            local winner = GetPlayerByName(winnerName)
            if winner and winner:GetGUIDLow() == player:GetGUIDLow() then
                -- Winner can claim the prize
                awardPrize(player)
            else
                player:SendBroadcastMessage("Only the current winner can claim the prize.")
            end
        end
    elseif intid == 3 then
        -- Implementation of "Players" option
        showParticipants(player)
    elseif intid == 4 then
        -- Implementation of "Countdown" option
        if winnerName and os.time() <= claimEndTime then
            local timeRemaining = claimEndTime - os.time()
            local hours = math.floor(timeRemaining / 3600)
            local minutes = math.floor((timeRemaining % 3600) / 60)
            local seconds = math.floor(timeRemaining % 60)
            player:SendBroadcastMessage(string.format("Time until %s claims the prize: %02d:%02d:%02d", winnerName, hours, minutes, seconds))
        else
            local timeRemaining = nextDrawTime - os.time()
            local hours = math.floor(timeRemaining / 3600)
            local minutes = math.floor((timeRemaining % 3600) / 60)
            local seconds = math.floor(timeRemaining % 60)
            player:SendBroadcastMessage(string.format("Time until next draw: %02d:%02d:%02d", hours, minutes, seconds))
        end
    elseif intid == 5 then
        -- Implementation of "Rules" option with expanded rules
        player:SendBroadcastMessage("Lottery Rules:")
        player:SendBroadcastMessage("1. Enter with " .. LOTTERY_COST .. " Emblem of Frost.")
        player:SendBroadcastMessage("2. You can enter once every " .. (REGISTRATION_TIME_SECONDS / 60) .. " minutes.")
        player:SendBroadcastMessage("3. The lottery draw occurs every " .. (REGISTRATION_TIME_SECONDS / 60) .. " minutes.")
        player:SendBroadcastMessage("4. If you win, you have " .. (CLAIM_TIMEOUT_SECONDS / 60) .. " minutes to claim your prize.")
        player:SendBroadcastMessage("5. The prize is " .. GetItemLink(PRIZE_ITEM_ID) .. ".")
        player:SendBroadcastMessage("6. If the prize is not claimed in time, it's forfeited and a new lottery begins.")
        player:SendBroadcastMessage("7. You can't enter a new lottery while waiting for a winner to claim their prize.")
        player:SendBroadcastMessage("8. The winner is chosen randomly from all participants.")
    elseif intid == 6 then
        -- Implementation of "Close" option
    end
    player:GossipComplete() -- Finalize gossip interaction with NPC
end

local NPC_ID = 500000 -- Choose an available NPC ID for your NPC

-- Register gossip events for NPC
RegisterCreatureGossipEvent(NPC_ID, 1, onGossipHello)
RegisterCreatureGossipEvent(NPC_ID, 2, onGossipSelect)

-- Function to initiate lottery draw after registration period
local function initiateLotteryDraw()
    performLotteryDraw() -- Perform lottery draw
end

-- Initiate lottery draw every registration period
CreateLuaEvent(initiateLotteryDraw, REGISTRATION_TIME_SECONDS * 1000, 0)

-- Initiate check for prize claim after draw
CreateLuaEvent(checkPrizeClaim, 1000, 0)

-- Initiate message for waiting for prize claim after draw
CreateLuaEvent(initiateClaimTimeoutMessage, 1000, 0)

print("Lottery script successfully loaded for NPC with ID " .. NPC_ID)