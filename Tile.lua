module(..., package.seeall);

--[[
The fundamental unit of the nonogram board.  A Tile has a secret state (either it is Full or
it's Empty) and may or may not have been revealed at any given point in the solving process.
--]]

function setState(t, s)
	t.Full = s
end

function setKnown(t, s)
	t.Known = s
end

function getState(t)
	return t.Full
end

function getKnown(t)
	return t.Known
end


function new(state, known)
	local o = {}
	o.Full = state or false
	o.Known = known or false

	o.setState = setState
	o.setKnown = setKnown
	o.getState = getState
	o.getKnown = getKnown

	return o
end
