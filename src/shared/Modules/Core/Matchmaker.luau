--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local matchmaker = {}
matchmaker.__index = matchmaker

function matchmaker.new(boards: { Model })
	local self = setmetatable({}, matchmaker)
	self.boards = boards
	self.GameStarted = Signal.new()

	return self
end

function matchmaker:BeginMatchMaking()
	for _, board: typeof(workspace.Boards.Board) in self.boards do
		--> signal based match-making
		local blackSeat = board.BlackSeat
		local redSeat = board.RedSeat
		local seatedEvent = Signal.new()

		local function occupantChangedSignal()
			seatedEvent:Fire()
		end
		blackSeat:GetPropertyChangedSignal("Occupant"):Connect(occupantChangedSignal)
		redSeat:GetPropertyChangedSignal("Occupant"):Connect(occupantChangedSignal)

		local thread = nil
		seatedEvent:Connect(function()
			if blackSeat.Occupant and redSeat.Occupant then
				thread = task.defer(function()
					for i = 3, 1, -1 do
						board.StatusGui.Status.Text = `Starting Game In:\n{i}`
						task.wait(1)
					end
					self.GameStarted:Fire(
						board,
						game.Players:GetPlayerFromCharacter(redSeat.Occupant.Parent),
						game.Players:GetPlayerFromCharacter(blackSeat.Occupant.Parent)
					)
				end)
			elseif thread then
				coroutine.close(thread)
				board.StatusGui.Status.Text = "Waiting.."
			end
		end)
	end
end

return matchmaker
