local Module = {}

local SideVertical = {1, 0, 3, 5}
local FrontVertical = {2, 0, 4, 5}
local Horizontal = {1, 2, 3, 4}

local StringValue = {"W", "O", "G", "R", "B", "Y"} 

local function CopyBuffer(Buffer)
	local BufferSize = buffer.len(Buffer)

	local NewBuffer = buffer.create(BufferSize)
	buffer.copy(NewBuffer, 0, Buffer, 0, BufferSize)

	return NewBuffer
end

local function GetCubeSize(Cube)
	return math.sqrt(buffer.len(Cube) / 6)
end


local function GetOffset(Size, Face, X, Y)
	return Face * Size ^ 2 + Y * Size + X
end

function Module.CubeToString(Cube: buffer)
	local String = ""

	for Offset=0, buffer.len(Cube) - 1 do
		String ..= StringValue[buffer.readi8(Cube, Offset) + 1]
	end

	return String
end

function Module.PrintCube(Cube: buffer)
	local CubeSize = GetCubeSize(Cube)
	local FaceSize = CubeSize ^ 2
	
	local String = ""
	
	for Offset=0, FaceSize * 6 - 1 do
		local Side = Offset < FaceSize and 0
		Side = Side or (Offset > FaceSize * 5 - 1 and 5)
		Side = Side or (math.floor((Offset - FaceSize) / CubeSize) % 4) + 1
		
		local Point = (Side == 0 or Side == 5)

		local X = Offset % CubeSize
		local Y = Point and math.floor((Offset % FaceSize) / CubeSize)
		Y = Y or math.floor((Offset - FaceSize) / (CubeSize * 4))

		if Point and X == 0 then
			String ..= "\n" .. string.rep("  ", CubeSize)
		elseif not Point and (Offset - FaceSize) % (CubeSize * 4) == 0 then
			String ..= "\n"
		end 
		
		local Value = buffer.readi8(
			Cube,
			GetOffset(CubeSize, Side, X, Y)
		)
		
		String ..= StringValue[Value + 1] .. " "
	end
	
	print(String)
end

function Module.RotateFace(Cube, MovedCube, Side, Size, Clockwise)
	local PieceSize = math.floor(Size)

	local Offset = Side * Size ^ 2

	for Row=1, PieceSize do
		for Column=1, PieceSize do
			local OldPos = ((Row - 1) * PieceSize + (Column - 1)) + Offset
			local NewPos = Offset + (Clockwise and 
				((Column * PieceSize) - Row) or
				((PieceSize - Column) * PieceSize + Row) - 1)
			
			buffer.writei8(MovedCube, NewPos, buffer.readi8(Cube, OldPos))
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
		if Side == 5 then
			Level = CubeSize - 1 - Level
		end
		
		Side = Sideway and 1 or 2
		Sideway = false
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
			RotatingSide  = Level == 0 and 4 or 2
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
			local OldPos = GetOffset(CubeSize, SideToMove,
				Module[Calculation](Offset, SideToMove, Level, CubeSize)
			)

			local NewPos = GetOffset(CubeSize, NeighborFace,
				Module[Calculation](Offset, NeighborFace, Level, CubeSize)
			)

			buffer.writei8(MovedCube, NewPos, buffer.readi8(Cube, OldPos))
		end
	end

	return MovedCube
end

function Module.DoNotation(Cube: buffer, Notation: 
	"U" | "D" | "R" | "L" | "F" | "B" | 
	"U'" | "D'" | "R'" | "L'" | "F'" | "B'")
	local Side, Level, Sideway, Direction
	
	local Reverse = string.sub(Notation, #Notation, #Notation) == "'"
	
	local CubeSize = GetCubeSize(Cube)
	local Edge = CubeSize - 1
	
	if Reverse then
		Notation = string.sub(Notation, 1, #Notation - 1)
	end

	if Notation == "U" then
		Side, Level, Sideway, Direction = 1, 0, true, -1
	elseif Notation == "D" then
		Side, Level, Sideway, Direction = 1, Edge, true, 1
	elseif Notation == "R" then
		Side, Level, Sideway, Direction = 2, Edge, false, 1
	elseif Notation == "L" then
		Side, Level, Sideway, Direction = 2, 0, false, -1
	elseif Notation == "F" then
		Side, Level, Sideway, Direction = 1, Edge, false, 1
	elseif Notation == "B" then
		Side, Level, Sideway, Direction = 1, 0, false, -1
	else
		error(`{Notation} is not a thing yet`)
	end
	
	if Reverse then
		Direction = -Direction
	end
	
	return Module.MoveCube(Cube, Side, Level, Sideway, Direction)
end

function Module.CreateCube(Size: number, State: string?)
	local Cube = buffer.create(Size ^ 2 * 6)
	
	for Side=0, 5 do
		for Offset=1, Size ^ 2 do
			local Offset = (Side * Size ^ 2) + (Offset - 1)
			local StateColor = State and string.sub(State, Offset + 1, Offset + 1)
			
			buffer.writei8(
				Cube, 
				Offset, 
				State and table.find(StringValue, StateColor) - 1 or Side
			)
		end
	end

	return Cube
end

return Module
