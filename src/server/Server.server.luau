--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local modules = ReplicatedStorage.Shared.Modules
local network = require(ReplicatedStorage.Packages.network)
local checkers = require(modules.Core.Checkers)
local matchmaker = require(modules.Core.Matchmaker).new(workspace.Boards:GetChildren())

local StartGameOnClient = network.RemoteEvent("StartGameOnClient", false)
local EndGameOnClient = network.RemoteEvent("EndGameOnClient", false)
local ChangeTurn = network.RemoteEvent("ChangeTurn", false)

matchmaker:BeginMatchMaking()

matchmaker.GameStarted:Connect(function(board: typeof(workspace.Boards.Board), redPlayer: Player, blackPlayer: Player)
	print(`Game Started! {redPlayer.Name} vs {blackPlayer.Name}!`)

	local currentGame = checkers.startGame(board, redPlayer, blackPlayer)
	StartGameOnClient.Fire(redPlayer, board, "Red", currentGame.currentTurn == redPlayer)
	StartGameOnClient.Fire(blackPlayer, board, "Black", currentGame.currentTurn == blackPlayer)

	while not currentGame:HasGameEnded() do
		local player, block, move
		local connection: RBXScriptConnection = StartGameOnClient.Connect(function(mover, ...)
			if mover == currentGame.currentTurn then
				player, block, move = mover, ...
			end
		end)

		local start = os.time() + 30
		while not player and not currentGame.destroyed and start - os.time() > 0 do
			board.StatusGui.Status.Text = `It is {currentGame.currentTurn.DisplayName}'s turn! \n {start - os.time()}`
			task.wait()
		end
		connection:Disconnect()

		if player then
			currentGame:ApplyMove(player, block, move)
			ChangeTurn.Fire(currentGame.currentTurn)
		elseif not currentGame.destroyed and currentGame.currentTurn.Parent then
			if currentGame.currentTurn.Character then
				currentGame.currentTurn.Character.Humanoid.Jump = true
			end
			break
		end
	end
	EndGameOnClient.FireList({ redPlayer, blackPlayer })

	if board.BlackSeat.Occupant and board.RedSeat.Occupant then
		local prevBlackOccupant = board.BlackSeat.Occupant
		local prevRedOccupant = board.RedSeat.Occupant
		local winner: Player = currentGame:HasGameEnded()
		board.StatusGui.Status.Text = `{winner.DisplayName} won!`
		task.wait(2)
		if board.BlackSeat.Occupant == prevBlackOccupant and board.RedSeat.Occupant == prevRedOccupant then
			currentGame:Destroy()
			matchmaker.GameStarted:Fire(board, redPlayer, blackPlayer)
		end
	end
end)
