--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local objects = ReplicatedStorage.Objects

local checkersServer = {}
checkersServer.__index = checkersServer

type Tile = typeof(objects.TileType)
type Block = typeof(objects.RedHead)

export type CheckersServer = typeof(setmetatable(
	{} :: {
		board: Folder,
		redHeads: Folder,
		blackHeads: Folder,
		destroyed: boolean,
		redPlayer: Player,
		blackPlayer: Player,
		currentTurn: Player,
		BlackSeatConnection: RBXScriptConnection?,
		RedSeatConnection: RBXScriptConnection?,
	},
	checkersServer
))

function checkersServer.startGame(
	board: typeof(workspace.Boards.Board),
	redPlayer: Player,
	blackPlayer: Player
): CheckersServer
	local self = setmetatable({}, checkersServer)
	self.board = board.Board
	self.redHeads = board.Red
	self.blackHeads = board.Black

	self.destroyed = false

	self.redPlayer = redPlayer
	self.blackPlayer = blackPlayer
	self.side = {
		[self.redPlayer] = self.redHeads.Name,
		[self.blackPlayer] = self.blackHeads.Name,
	}

	self.currentTurn = redPlayer

	-- set up board
	local fadeInInfo = TweenInfo.new(0.6, Enum.EasingStyle.Bounce)
	local FadeTweenHeight = Vector3.new(0, 2, 0)
	for row = 1, 3 do
		for col = 1, 4 do
			local redHead = objects.RedHead:Clone()
			local blackHead = objects.BlackHead:Clone()
			for _, block in { redHead, blackHead } do
				block.Transparency = 1
				block.face.Transparency = 1
			end

			redHead.Parent = board.Red
			blackHead.Parent = board.Black

			local redColumn = if row % 2 == 0 then col * 2 - 1 else col * 2
			local blackColumn = if row % 2 == 1 then col * 2 - 1 else col * 2
			local redRow = row
			local blackRow = 9 - row

			local redPosition: Tile = self.board[redColumn][redRow]
			local blackPosition: Tile = self.board[blackColumn][blackRow]
			redHead.CFrame = CFrame.new(
				redPosition.Position + Vector3.new(0, 0.75, 0) + FadeTweenHeight,
				board.BlackSeat.Position - board.BlackSeat.CFrame.LookVector * 1000
			)
			blackHead.CFrame = CFrame.new(
				blackPosition.Position + Vector3.new(0, 0.75, 0) + FadeTweenHeight,
				board.RedSeat.Position - board.RedSeat.CFrame.LookVector * 1000
			)

			redHead:SetAttribute("Position", Vector2.new(redColumn, redRow))
			blackHead:SetAttribute("Position", Vector2.new(blackColumn, blackRow))

			redPosition.Occupant.Value = redHead
			blackPosition.Occupant.Value = blackHead

			for _, block in { redHead, blackHead } do
				task.spawn(function()
					task.wait(row * 0.1 + col * 0.1)
					TweenService:Create(block, fadeInInfo, {
						CFrame = block.CFrame - FadeTweenHeight,
					}):Play()
					TweenService:Create(block, TweenInfo.new(fadeInInfo.Time * 0.8), { Transparency = 0 }):Play()
					TweenService:Create(block.face, fadeInInfo, { Transparency = 0 }):Play()
				end)
			end
		end
	end

	local function endGame()
		self:Destroy()
	end
	self.BlackSeatConnection = board.BlackSeat:GetPropertyChangedSignal("Occupant"):Connect(endGame)
	self.RedSeatConnection = board.RedSeat:GetPropertyChangedSignal("Occupant"):Connect(endGame)

	return self
end

function checkersServer:_validateMove(player: Player, block, position: { Col: number, Row: number }): (boolean?, Block?)
	-- Conditions for a valid move:
	-- 	1. it is the player's turn. (already checked on the server)
	--	2. "block" and "position" are valid arguments.
	--	3. Tile exists.
	--	4. position's Row and Column must match and must be no more than 2.
	--	5. No Block on desired move.
	--	6. If it is a jump move (2 on row and column), half it and check if there's a block on that position.
	--	7. If it is a backward move compared to the color, check if that block's crown's transparency is set to 0.
	if
		typeof(block) ~= "Instance"
		or (not block.Parent or block.Parent.Name ~= self.side[player])
		or (typeof(position) ~= "table" or typeof(position.Col) ~= "number" or typeof(position.Row) ~= "number")
	then
		return
	end
	block = block :: Block

	local blockPosition: Vector2 = block:GetAttribute("Position")
	local newPositionX, newPositionY = blockPosition.X + position.Col, blockPosition.Y + position.Row
	if (newPositionX <= 0 or newPositionX > 8) or (newPositionY <= 0 or newPositionY > 8) then
		return
	end

	if math.abs(position.Col) ~= math.abs(position.Row) or position.Col > 2 then
		return
	end

	if block.Parent.Name == "Red" and position.Row < 0 and block.Crown.Transparency == 1 then
		return
	elseif block.Parent.Name == "Black" and position.Row > 0 and block.Crown.Transparency == 1 then
		return
	end

	local jumpedBlock: Block?
	if math.abs(position.Col) == 2 then
		local jumpedPosition: Tile = self.board[blockPosition.X + position.Col / 2][blockPosition.Y + position.Row / 2]
		if not jumpedPosition.Occupant.Value then
			return
		else
			jumpedBlock = jumpedPosition.Occupant.Value
		end
	end

	local tile = self.board[blockPosition.X + position.Col][blockPosition.Y + position.Row]
	if tile.Occupant.Value then
		return
	end

	return true, jumpedBlock
end

function checkersServer:ApplyMove(player: Player, block: Block, position: { Col: number, Row: number })
	local isValid, jumpedBlock = self:_validateMove(player, block, position)

	if isValid then
		local blockPosition: Vector2 = block:GetAttribute("Position")
		local newPosition = Vector2.new(blockPosition.X + position.Col, blockPosition.Y + position.Row)
		local tile: Tile = self.board[newPosition.X][newPosition.Y]

		block:SetAttribute("Position", newPosition)
		self.board[blockPosition.X][blockPosition.Y].Occupant.Value = nil
		tile.Occupant.Value = block

		block.CFrame = CFrame.new(tile.Position + Vector3.new(0, 0.75, 0)) * block.CFrame.Rotation

		if jumpedBlock then
			local jumpedBlockPosition: Vector2 = jumpedBlock:GetAttribute("Position")
			self.board[jumpedBlockPosition.X][jumpedBlockPosition.Y].Occupant.Value = nil
			jumpedBlock:Destroy()
		else
			self.currentTurn = if self.currentTurn == self.redPlayer then self.blackPlayer else self.redPlayer
		end

		if
			(newPosition.Y == 8 and block.Parent.Name == "Red") or (newPosition.Y == 1 and block.Parent.Name == "Black")
		then
			block.Crown.Transparency = 0
		end
	end
end

function checkersServer:HasGameEnded()
	if #self.redHeads:GetChildren() == 0 then
		return self.blackPlayer
	elseif #self.blackHeads:GetChildren() == 0 then
		return self.redPlayer
	end

	return false
end
function checkersServer:Destroy()
	self.destroyed = true

	self.redHeads:ClearAllChildren()
	self.blackHeads:ClearAllChildren()

	for i, v in self.board:GetDescendants() do
		if v:IsA("BasePart") then
			v.Occupant.Value = nil
		end
	end

	self.BlackSeatConnection:Disconnect()
	self.RedSeatConnection:Disconnect()
end

return checkersServer
