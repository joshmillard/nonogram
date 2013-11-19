module(..., package.seeall);

--[[
A Line is a list of Tile objects, a corresponding list of Clue objects calculated from
the state of those Tiles, and some bookkeeping info about e.g. whether this line has
changed since the last time an effort was made to solve it.
--]]

require "Tile"
require "Clue"

-- create a new list of Clue objects based on the content of a line
function create_clues(line) 
	local building = false
	local tiles = {}
	line.clue_list = {}
	for i=1, line:getLength() do
		-- count up distinct runs of Tiles with a Full state and create a set of clues
		-- that corresponds to that set of runs
		if line:getState(i) and not building then
			-- first Full tile in a sequence
			building = true
			table.insert(tiles, line:getTile(i))

		elseif line:getState(i) and building then
			-- we're already building a list of Full tiles and found another, keep adding
			table.insert(tiles, line:getTile(i))

		elseif building then
			-- we're building but we've hit an Empty tile, so let's close this clue out
			table.insert(line.clue_list, Clue.new(tiles))
			building = false
			tiles = {}
		end
	end
	-- need to close out any clue-in-progress at the end of the loop, if the last clue
	--  in the line was a Full
	if building then
		table.insert(line.clue_list, Clue.new(tiles))
	end
end

-- check the Known state of constituent tiles and update solved accordingly
function check_solved(line)
	for i=1, line.length do
		if line.tile_list[i]:getKnown() == false and line.tile_list[i]:getState() == true then
			-- we found an unrevealed Full tile, so this line can't be considered solved
			line.solved = false
			return
		end
		-- if we got out, we must know about every Full tile already, huzzah!
		line.solved = true
	end
end

function getLength(line)
	return line.length
end

function getState(line, i)
	return line.tile_list[i]:getState()
end

function getKnown(line, i)
	return line.tile_list[i]:getKnown()
end

function getTile(line, i)
	return line.tile_list[i]
end

function getClues(line)
	return line.clue_list
end

function setState(line, i, s)
	line.tile_list[i] = s
end

function is_solved(line)
	return line.solved
end

-- return a new Line object with tiles and clues reversed
function reverse(line)
	local newtiles = {}
	for i,v in ipairs(line.tile_list) do
		table.insert(newtiles, 1, v)
	end
	return new(newtiles)
end

-- return a new Line object that is a subset of the original line's tiles and clues
function subline(line, starttile, endtile, startclue, endclue)
	local newtiles = {}
	for i=starttile, endtile do
		table.insert(newtiles, line:getTile(i))
	end
	
	local newclues = {}
	for i=startclue, endclue do
		table.insert(newclues, line:getClues()[i])
	end

	local newline = new(newtiles)
	newline:setClues(newclues)

	return newline
end	

-- instantiate a Line object with a list of Tiles
function new(tiles)
	local o = {}

	o.tile_list = tiles or {}
	o.length = table.getn(o.tile_list)
	o.solved = false
	o.changed = false
	o.clue_list = {}

	o.getLength = getLength
	o.getState = getState
	o.getKnown = getKnown
	o.getTile = getTile
	o.getClues = getClues
	o.setState = setState
	o.create_clues = create_clues
	o.check_solved = check_solved
	o.is_solved = is_solved
	o.reverse = reverse

	create_clues(o)

	return o
end
