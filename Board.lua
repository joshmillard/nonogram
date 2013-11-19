module(..., package.seeall);

--[[
The Board object's our overarching container for all the guts of a nonogram puzzle
and solution process.  It maintains a list of Tiles that make up the board, Lines
(as rows and columns) referenceing those Tiles in single-line containers for line-based
solving, a record of Move objects for tracking the when and how of move choices by
the player or AI, etc.
--]]

require "Line"
require "Tile"
require "Move"

-- create the Tiles and Lines to populate a board of width*height size
function create_blank_board(b, width, height)

	b.name = "blank"
	b.width = width
	b.height = height
	
	-- create a bunch of tiles!
	b.tile_matrix = {}
	for y=1, height do
		b.tile_matrix[y] = {}
		for x=1, width do
			b.tile_matrix[y][x] = Tile.new()
		end
	end

	-- and then a bunch of rows made of those
	b.row_list = {}
	for y=1, height do
		local tlist = {}
		for x=1, width do
			table.insert(tlist, b.tile_matrix[y][x])
		end
		b.row_list[y] = Line.new(tlist)
	end

	-- and also a bunch of columns!
	b.column_list = {}
	for x=1, width do
		local tlist = {}
		for y=1, height do
			table.insert(tlist, b.tile_matrix[y][x])
		end
		b.column_list[x] = Line.new(tlist)
	end

end

-- create a board based on a puzzle file in the game directory
function create_board_from_file(b, puzzlename)
	local name, width, height, tiles = read_puzzle_from_file(puzzlename)
	if name == nil then
		-- something went wrong reading from file, abort!
		print("Something ain't right here!")
		return 
	end	

	-- create a set of tiles/lines matching the puzzle size
	b:create_blank_board(width, height)
	-- set the name
	b.name = name
	-- toggle the state of the tiles accordingly
	for y=1, b.height do
		for x=1, b.width do
			b.tile_matrix[y][x]:setState(tiles[y][x])
		end
	end			
	-- and get clues for our rows and columns	
	b:calculate_clues()
end

-- read a puzzle defintion from provided file and 
function read_puzzle_from_file(puzzlename)
	local prefix = "puzzles/"
	local filename = prefix .. puzzlename .. ".puz"
	if not love.filesystem.isFile(filename) then
		-- no such file, eff this!
		return nil
	end
	-- iterator to read the file, churn that into a table just for comfort
	local lines = love.filesystem.lines(filename)
	local l = {}
	for i in lines do
		table.insert(l, i)
	end


	-- grab the header info
	local name = table.remove(l, 1)
	if name == "" then
		name = "oddly blank"
	end

	local width = tonumber(table.remove(l, 1))
	if width < 1 then
		print("puzzle impossibly narrow!")
		return nil
	end

	local height = tonumber(table.remove(l, 1))
	if height < 1 then
		print("puzzle impossible short!")
		return nil
	end

	-- and proceed to read in the board data; 0 = Empty, 1 = Full
	local data = {}
	for y=1, height do
		data[y] = {}
		local str = l[y]
		if string.len(str) ~= width then
			print("Malformed file definition: bad string length!")
			return nil
		end
		for x=1, width do
			local val = tonumber(string.sub(str, x, x))
			if val == 1 then
				-- Full tile
				data[y][x] = true
			elseif val == 0 then
				-- Empty tile
				data[y][x] = false
			else
				print("Bad tile character in file definition!")
				return nil
			end
		end
	end

	return name, width, height, data

end

function calculate_clues(board)
	for y=1, board.height do
		board.row_list[y]:create_clues()
	end
	for x=1, board.width do
		board.column_list[x]:create_clues()
	end
end

function fillTile(board, x, y)
	-- set the state of the tile at x,y on the board to Full
	if board.tile_matrix[y] == nil then
		print("No y row in tile_matrix!")
		return
	end
	board.tile_matrix[y][x]:setState(true) 
	-- at this point, we've changed the state of the board, which meanbs we've changed
	-- what the clues should say, so we trigger a recalculation of those for both the row
	-- and the column this tile is in
	board.row_list[y]:create_clues()
	board.column_list[x]:create_clues()
end

function addMove(board, x, y, guess, correct, time)
	table.insert(board.move_list, Move.new(x, y, guess, correct, time) )
	if not correct then
		board.errors = board.errors + 1
	end
end

function getMoves(board)
	return board.move_list
end

function getWidth(board)
	return board.width
end

function getHeight(board)
	return board.height
end

function getName(board)
	return board.name
end

function is_solved(board)
	return board.solved
end

function is_row_solved(board, r)
	return board.row_list[r]:is_solved()
end

function is_column_solved(board, l)
	return board.column_list[l]:is_solved()
end

function setKnown(board, x, y, k)
	board.tile_matrix[y][x]:setKnown(k)
--[[ 
If we're changing Known state, we're potentially changing some key information about
the greater board state: the solvedness of the row and the column to which this Tile belongs,
the solvedness of clues on that lines, and the solvedness of the board as a whole
--]]
	board.row_list[y]:check_solved()
	board.column_list[x]:check_solved()
end

function getState(board, x, y)
  if board.tile_matrix[y] == nil then
    print("No y row in tile_matrix!")
    return false
  end
	return board.tile_matrix[y][x]:getState()
end

function getKnown(board, x, y)
	if board.tile_matrix[y] == nil then
		print("No y row in tile_matrix!  WTF!")
		return false
	end
	return board.tile_matrix[y][x]:getKnown()
end

function getRowClues(board, r)
	return board.row_list[r]:getClues()
end

function getColumnClues(board, c)
	return board.column_list[c]:getClues()
end

function getElapsed(board)
	return love.timer.getTime() - board.start_time
end

function getErrorCount(board)
	return board.errors
end

function new(width, height)

	local o = {}

	o.name = "default"
	o.width = width
	o.height = height
	o.solved = false
	o.row_list = {}
	o.column_list = {}
	o.tile_matrix = {}
	o.move_list = {}
	o.start_time = love.timer.getTime()
	o.errors = 0

	o.create_blank_board = create_blank_board
	o.fillTile = fillTile
	o.getWidth = getWidth
	o.getHeight = getHeight
	o.getName = getName
	o.is_solved = is_solved
	o.getState = getState
	o.getKnown = getKnown	
	o.setKnown = setKnown
	o.getRowClues = getRowClues
	o.getColumnClues = getColumnClues
	o.getElapsed = getElapsed
	o.addMove = addMove
	o.getMoves = getMoves
	o.getErrorCount = getErrorCount
	o.create_board_from_file = create_board_from_file
	o.calculate_clues = calculate_clues
	o.is_row_solved = is_row_solved
	o.is_column_solved = is_column_solved

	o:create_blank_board(o.width, o.height)

	return o

end
