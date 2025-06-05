local Module = {}

local SideVertical = {1, 0, 3, 5}
local FrontVertical = {2, 0, 4, 5}
local Horizontal = {1, 2, 3, 4}

local function CopyBuffer(Buffer)
	local BufferSize = buffer.len(Buffer)

	local NewBuffer = buffer.create(BufferSize)
	buffer.copy(NewBuffer, 0, Buffer, 0, BufferSize)

	return NewBuffer
end

local function GetCubeSize(Cube)
	return math.sqrt(buffer.len(Cube) / 6)
end

function Module.GetOffset(Size, Face, X, Y)
	return Face * Size ^ 2 + Y * Size + X
end

function Module.RotateFace(Cube, MovedCube, Side, Size, Clockwise)
	local PieceSize = math.floor(Size)

	local Offset = Side * Size ^ 2

	for Row=1, PieceSize do
		for Column=1, PieceSize do
			local Index = buffer.readi8(Cube, ((Row - 1) * PieceSize + (Column - 1)) + Offset)

			buffer.writei8(MovedCube, Offset + (Clockwise and 
				((Column * PieceSize) - Row) or
				((PieceSize - Column) * PieceSize + Row) - 1), 
				Index
			)
		end
	end
end

function Module.GetSideVertical(Offset, Side, Level, CubeSize)
	local Sideway = Side == 0 or Side == 5

	CubeSize -= 1

	Offset = (Side == 5 or Side == 1) and CubeSize - Offset or Offset
	Level = Side < 2 and Level or CubeSize - Level

	return Sideway and Offset or Level, 
		Sideway and Level or Offset
end

function Module.GetFrontVertical(Offset, Side, Level, CubeSize)
	CubeSize -= 1

	return Side == 4 and CubeSize - Level or Level,
		Side == 4 and CubeSize - Offset or Offset
end

function Module.GetHorizontal(Offset, Side, Level, CubeSize)
	return Offset, Level
end

function Module.MoveCube(Cube: buffer, Side: number, Level: number, Sideway: boolean, Direction: IntValue)
	local MovedCube = CopyBuffer(Cube)
	local CubeSize = GetCubeSize(Cube)

	if Side == 0 or Side == 5 then
		Side = Sideway and 1 or 2
		Sideway = false

		if Side == 5 then
			Level = CubeSize - 1 - Level
		end
	end

	local IsHorizontal = (Side > 0 or Side < 5) and Sideway
	local SimplifiedSide = (Side - 1) % 2 + 1

	local Line = (IsHorizontal and Horizontal) or (SimplifiedSide == 1 and SideVertical or FrontVertical)
	local Calculation = "Get" .. ((IsHorizontal and "Horizontal") or (SimplifiedSide == 1 and "SideVertical" or "FrontVertical"))

	Level = IsHorizontal and Level or Side <= 2 and Level or CubeSize - 1 - Level

	if Level == 0 or Level == CubeSize - 1 then
		local FaceDirection = Direction < 0
		local RotatingSide

		if IsHorizontal then
			RotatingSide = Level == 0 and 0 or 5
		elseif SimplifiedSide == 1 then 
			RotatingSide = Level == 0 and 4 or 2
		else
			RotatingSide = Level == 0 and 1 or 3
		end

		for i=1, math.abs(Direction) do
			Module.RotateFace(
				Cube,
				MovedCube, 
				RotatingSide,
				CubeSize, 
				Level == 0 and FaceDirection or Level == CubeSize - 1 and not FaceDirection
			)
		end
	end

	for i, SideToMove in Line do
		local NeighborFace = Line[(table.find(Line, SideToMove) + Direction - 1) % 4 + 1]

		for Offset=0, CubeSize - 1 do
			local OldPos = Module.GetOffset(CubeSize, SideToMove,
				Module[Calculation](Offset, SideToMove, Level, CubeSize)
			)

			local NewPos = Module.GetOffset(CubeSize, NeighborFace,
				Module[Calculation](Offset, NeighborFace, Level, CubeSize)
			)

			buffer.writei8(MovedCube, NewPos, buffer.readi8(Cube, OldPos))
		end
	end

	return MovedCube
end

function Module.CreateCube(Size: number)
	local Cube = buffer.create(Size ^ 2 * 6)

	for Side=0, 5 do
		for Offset=1, Size ^ 2 do
			buffer.writei8(Cube, (Side * Size ^ 2) + (Offset - 1), Side)
		end
	end

	return Cube
end

return Module
