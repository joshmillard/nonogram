module(..., package.seeall);

--[[ 
The Move object is a simple container for information about a single move in a
puzzle solution process: it tracks which tile was guessed, what the guess
was (Full or Empty), whether the guess was correct, and at what time since
puzzle start the guess was made.
--]]


function getMove(move)
	return move.x, move.y, move.guess, move.correct, move.time
end

function new(x, y, guess, correct, time)

	local o = {}
	o.x = x
	o.y = y
	o.guess = guess
	o.correct = correct
	o.time = time

	o.getMove = getMove

	return o

end
