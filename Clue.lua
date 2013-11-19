module(..., package.seeall);

--[[
A clue is a numeric value corresponding to a run of Full tiles in a line of a puzzle.
--]]

function getSize(clue)
	return clue.size
end

function is_solved(clue)
	return clue.solved
end

-- TODO: function for determining and change the "solved" boolean state of the clue


function new(tiles)
	local o = {}

	o.tiles = tiles
	o.size = table.getn(tiles)
	o.solved = false

	o.getSize = getSize
	o.is_solved = is_solved

	return o
end
