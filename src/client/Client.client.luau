--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = require(ReplicatedStorage.Packages.network)
local Checkers = require(ReplicatedStorage.Shared.Modules.Core.Checkers.Client)

local StartGameOnClient = network.RemoteEvent("StartGameOnClient", false)
local EndGameOnClient = network.RemoteEvent("EndGameOnClient", false)

StartGameOnClient.Connect(function(board: typeof(workspace.Boards.Board), side: string, isTurn: boolean)
	local currentGame = Checkers.new(board, side, isTurn)
	local GameEndedConnection

	GameEndedConnection = EndGameOnClient.Connect(function()
		currentGame:Destroy()
		GameEndedConnection:Disconnect()
	end)
end)
