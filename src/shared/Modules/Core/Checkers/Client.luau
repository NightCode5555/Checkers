--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = require(ReplicatedStorage.Packages.network)
local objects = ReplicatedStorage:WaitForChild("Objects")

local ChangeTurn = network.RemoteEvent("ChangeTurn", false)
local StartGameOnClient = network.RemoteEvent("StartGameOnClient", false)

local checkersClient = {}
checkersClient.__index = checkersClient

local moves = {
	-- forward for Red, backward for Black
	{ Col = 1, Row = 1 },
	{ Col = 1, Row = -1 },
	-- backward for Red, forward for Black
	{ Col = -1, Row = 1 },
	{ Col = -1, Row = -1 },
}

type Tile = typeof(objects.TileType)
type Block = typeof(objects.RedHead)
type GreenBlock = typeof(objects.GreenBlock)

function checkersClient.new(board: typeof(workspace.Boards.Board), side: string, isTurn: boolean)
	local self = setmetatable({}, checkersClient)
	self.side = board[side] :: Folder
	self.board = board.Board
	self.greenBlocks = Instance.new("Folder", workspace)
	self.highlightedBlock = nil
	self.isTurn = isTurn
	self.ChangeTurnConnection = ChangeTurn.Connect(function()
		self.isTurn = true
	end)

	for i, block in self.side:GetChildren() do
		self:DetectClickOnBlock(block)
	end
	self.AddedBlockConnection = self.side.ChildAdded:Connect(function(block)
		self:DetectClickOnBlock(block)
	end)

	return self
end

function checkersClient:DetectClickOnBlock(block: Block)
	local clickDetector = Instance.new("ClickDetector", block)
	clickDetector.MouseClick:Connect(function()
		if not self.isTurn or not self.greenBlocks.Parent then
			return
		end
		self.greenBlocks:ClearAllChildren()

		for i, move in moves do
			if
				((move.Row < 0 and self.side.Name == "Red") or (move.Row > 0 and self.side.Name == "Black"))
				and block.Crown.Transparency ~= 0
			then
				continue
			end

			local blockPosition: Vector2 = block:GetAttribute("Position")
			local newPositionX, newPositionY = blockPosition.X + move.Col, blockPosition.Y + move.Row
			local tile: Tile?
			if newPositionX > 0 and newPositionX <= 8 and newPositionY > 0 and newPositionY <= 8 then
				local potentialTile: Tile = self.board[newPositionX][newPositionY]
				if potentialTile.Occupant.Value and potentialTile.Occupant.Value.Parent ~= self.side then
					local newjumpPositionX, newjumpPositionY =
						blockPosition.X + move.Col * 2, blockPosition.Y + move.Row * 2
					if
						newjumpPositionX > 0
						and newjumpPositionX <= 8
						and newjumpPositionY > 0
						and newjumpPositionY <= 8
					then
						local jumpTile: Tile = self.board[newjumpPositionX][newjumpPositionY]
						if not jumpTile.Occupant.Value then
							tile = jumpTile
							move = { Col = move.Col * 2, Row = move.Row * 2 }
						end
					end
				elseif not potentialTile.Occupant.Value then
					tile = potentialTile
				end
			end

			if tile then
				local newGreenBlock = objects.GreenBlock:Clone()
				newGreenBlock.Parent = self.greenBlocks
				newGreenBlock.Position = tile.Position + Vector3.new(0, 0.75, 0)

				self:DetectClickOnGreenBlock(block, newGreenBlock, move)
			end
		end
	end)
end

function checkersClient:DetectClickOnGreenBlock(
	block: Block,
	greenBlock: GreenBlock,
	position: { Col: number, Row: number }
)
	local clickDetector = Instance.new("ClickDetector", greenBlock)
	clickDetector.MouseClick:Connect(function()
		self.isTurn = false
		StartGameOnClient.Fire(block, position)
		self.greenBlocks:ClearAllChildren()
	end)
end

function checkersClient:Destroy()
	self.greenBlocks:Destroy()
	self.ChangeTurnConnection:Disconnect()
	self.AddedBlockConnection:Disconnect()
end

return checkersClient
