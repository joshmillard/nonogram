module(..., package.seeall);

--[[
A nonogram-solving brain.  Given a Line object, it applies a series of techniques in order
to try and deduce new information about the state of the line, returning a list of new
index/guess pairs into the line to make moves on if any are found.
--]]

require "Line"

function solve_line(line)
	local newmoves
	newmoves = nil

--[[ 
A trick is a function that take in a line object and tries to determine new information
about the line according to some deductive process, returning either nil if it fails to
develop new info or a list of index/guess values representing one or more moves that should
be made on the board.

If a trick succeeds, we return the non-nil move list and are done. If a trick fails, we
fall forward to the next trick.  If no tricks succeed, we fall out of the for loop and
return a nil move list.

Some tricks work from left-to-right across a line; it's simpler and less error-prone to 
apply the trick once forward and once backward (right-to-left) than to implement the same trick 
in both directions; for these reversible tricks, we call it forward and then, if that
fails to produce anything, we call it backward as well.
--]]


	local tricks = {
		{ try_recurse_without_bounding_clues_and_empties, false },
		{ try_empty, false },
		{ try_full, false },
		{	try_perfect_fit, false },
		{ try_all_empties_accounted_for, false },
		{ try_all_fulls_accounted_for, false },
		{ try_extend_and_bound_edge_clue, true }
	}

	for i,v in ipairs(tricks) do
		newmoves = v[1](line)
		if newmoves then
			return newmoves
		end

		-- if this is a reversible function, try again with the reversed line
		if v[2] then
			newmoves = v[1](line:reverse())
			if newmoves then
				return mirror(newmoves, line)
			end
		end
	end


	return newmoves

end

-- returns a list of moves with positionally reversed indexes, for rectifying reverse line output
function mirror(m, line)
	for i,v in ipairs(m) do
		v[1] = (line:getLength() + 1) - v[1]
	end
	return m
end

--[[ This doesn't get us anything that the empties-and-fulls version doesn't, deprecating

-- check for bounding empty tiles at the edges
function try_recurse_without_bounding_empties(line)
	local starttile 
	local endtile 
	local startclue
	local endclue

	-- find our first non-Empty edge tiles
	starttile = 1
	for i=starttile, line:getLength() do
		if line:getKnown(i) and not line:getState(i) then
			-- this is a bounding empty, subline shoudl start farther out
			starttile = i + 1
		else
			-- non-empty, stop hemming the start in
			break
		end
	end

	endtile = line:getLength()
	for i=endtile, 1, -1 do
		if line:getKnown(i) and not line:getState(i) then
			endtile = i - 1
		else
			break
		end
	end

	-- note: we don't actually do anything with clues if we're just checking for bounding
	--  empties, as by definition no clues get eliminated. For a full check against both bounding
	--  empties AND bounding full clues, we'd need to check and trim clues as well.

	-- sanity check and bail if needed
	if (starttile == 1) and (endtile == line:getLength()) then
		-- we're still aiming for the whole string, which means that we didn't find *any*
		-- bounding empties and should definitely not recurse because nobody likes a stack overflow
		return nil
	end
	if starttile > endtile then
		-- some weird shit here that we're not accounting for
		-- specifically, we're dealing with a full stretch of known-empty tiles, which means
		-- we probably should never have gotten this far.
		print("Bad recursion mojo: starttile larger than endtile!")
		return nil
	end

	local moves
	moves = {}
	-- get our recurse on
	print("Oughta recurse between " .. starttile .. " and " .. endtile)
	-- pass a subline to solve_line, get moves back, adjust those moves by the difference between
	--  starttile and 1 to put them into the proper sync with the original full line, then
	--  return those moves
	moves = solve_line(line:subline(starttile, endtile, 1, table.getn(line:getClues())) )
	if not moves then
		-- came back empty! Eff this.
		return nil
	end

	for i,v in ipairs(moves) do
		v[1] = v[1] + starttile - 1
	end	
	return moves

end
--]]

-- check for bounding full clues and capping empties
function try_recurse_without_bounding_clues_and_empties(line)
	local starttile 
	local endtile 
	local startclue
	local endclue

	if table.getn(line:getClues()) == 0 then
		-- if the clue list is empty, there's no reason to bother with all this, let's let
		-- the simple try_empty routine deal with it.
		return nil
	end

	-- find our first non-Empty edge tiles
	starttile = 1
	startclue = 1
	local counting = false
	local count = 0
	for i=starttile, line:getLength() do
		if line:getKnown(i) then
			if not line:getState(i) then
				-- this is a bounding empty, subline should start farther out
				starttile = i + 1
			else
				-- we've got a Full here, let's proceed making sure the whole thing is here
				if not counting then
					counting = true
					count = 1
				else
					count = count + 1
				end
				if count == line:getClues()[startclue]:getSize() then
					-- we've got a whole clue here, let's increment startclue and set starttile
					startclue = startclue + 1
					count = 0
					counting = false
					starttile = i + 1
					-- at this point it's clear the next tile is Empty; if it isn't already known to
					-- be such, we should send back that move and call it.
					if not line:getKnown(i + 1) then
						print("in recurse, found uncapped clue...")
						return { {i + 1, false} }
					end
				end
			end
		else			 
			-- non-empty, stop hemming the start in
			break
		end
	end

	endtile = line:getLength()
	endclue = table.getn(line:getClues())
	counting = false
	count = 0
	for i=endtile, 1, -1 do
		if line:getKnown(i) then
			if not line:getState(i) then
				endtile = i - 1
			else
				if not counting then
					counting = true
					count = 1
				else
					count = count + 1
				end
				if count == line:getClues()[endclue]:getSize() then
					endclue = endclue - 1
					count = 0
					counting = false
					endtile = i - 1
					if not line:getKnown(i - 1) then
						return { {i - 1, false} }
					end
				end
			end
		else
			break
		end
	end

	-- note: we don't actually do anything with clues if we're just checking for bounding
	--  empties, as by definition no clues get eliminated. For a full check against both bounding
	--  empties AND bounding full clues, we'd need to check and trim clues as well.

	-- sanity check and bail if needed
	if (starttile == 1) and (endtile == line:getLength()) then
		-- we're still aiming for the whole string, which means that we didn't find *any*
		-- bounding empties and should definitely not recurse because nobody likes a stack overflow
		return nil
	end
	if starttile > endtile then
		-- some weird shit here that we're not accounting for
		-- specifically, we're dealing with a full stretch of known-empty tiles, which means
		-- we probably should never have gotten this far.
		print("Bad recursion mojo: starttile larger than endtile!")
		return nil
	end

	local moves
	moves = {}
	-- get our recurse on
	print("Oughta recurse between " .. starttile .. " and " .. endtile)
	-- pass a subline to solve_line, get moves back, adjust those moves by the difference between
	--  starttile and 1 to put them into the proper sync with the original full line, then
	--  return those moves
	moves = solve_line(line:subline(starttile, endtile, startclue, endclue) )
	if not moves then
		-- came back empty! Eff this.
		return nil
	end

	for i,v in ipairs(moves) do
		v[1] = v[1] + starttile - 1
	end	
	return moves

end

-- checks the line to see if it has an empty clue list
function try_empty(line)
	-- the size of the clue list is non-zero, this rubric fails.
	if table.getn(line:getClues()) > 0 then
		return nil
	end

	-- otherwise, let's return the index of every not-Known tile
	local moves
	moves = {}
	for i=1, line:getLength() do
		if not line:getKnown(i) then
			table.insert(moves, {i, false})
		end
	end

	return moves
end
		
-- checks the line to see if it has a single line-length clue
function try_full(line)
	if table.getn(line:getClues()) ~= 1 then
		-- if we don't have exactly one clue, this doesn't apply
		return nil
	end

	if line:getClues()[1]:getSize() ~= line:getLength() then
		-- if the clue isn't the length of the clue, this doesn't apply
		return nil
	end

	-- all Unknown tiles must be Full
	local moves
	moves = {}
	for i=1, line:getLength() do
		if not line:getKnown(i) then
			table.insert(moves, {i, true})
		end
	end

	return moves
end

-- check the line to see if the clues plus minimal gaps add up to a perfectly full line
function try_perfect_fit(line)
	local sum = 0
	local numclues = table.getn(line:getClues())
	local clues = line:getClues()
	local tiles = {}

	-- length of each clues plus a single tile gap between each clue
	sum = sum_of_clues(line:getClues()) + (numclues - 1)
	if sum ~= line:getLength() then
		-- our total number of tiles is different (hopefully less!) than the length of the line
		return nil
	end

	-- Still here?  Great!  Let's mock up a version of what the line should look like...
	for i=1, numclues do
		for j=1, clues[i]:getSize() do
			table.insert(tiles, true)
		end
		-- also add a single-tile gap between each clue
		if i < numclues then
			table.insert(tiles, false)
		end
	end

	-- And render Unknown tiles to match our mockup
	local moves
	moves = {}
	for i=1, line:getLength() do
		if not line:getKnown(i) then
			table.insert(moves, {i, tiles[i]})
		end
	end

	return moves
end

-- check the line to see if we have all the empties we need, in which case fill gaps with fulls
function try_all_empties_accounted_for(line)
	local found = 0
	local target = line:getLength() - sum_of_clues(line:getClues())

	for i=1, line:getLength() do
		if line:getKnown(i) and not line:getState(i) then
			-- this is a known Empty!
			found = found + 1
		end
	end
	
	if found ~= target then
		-- incorrect (hopefully too few!) empties found
		return nil
	end
		
	-- we've found as meany empties as there should be on this line, let's send back some fulls
	local moves
	moves = {}
	for i=1, line:getLength() do
		if not line:getKnown(i) then
			table.insert(moves, {i, true})
		end
	end

	return moves

end

-- check the lien to se if we have all the fulls we need, in which case fill gaps with empties
function try_all_fulls_accounted_for(line)
	local found = 0
	local target = sum_of_clues(line:getClues())

	for i=1, line:getLength() do
		if line:getKnown(i) and line:getState(i) then
			-- this is a known Full!
			found = found + 1
		end
	end
	
	if found ~= target then
		-- wrong number of fulls found
		return nil
	end
	
	-- fill out the gaps with empties
	local moves
	moves = {}
	for i=1, line:getLength() do
		if not line:getKnown(i) then
			table.insert(moves, {i, false})
		end
	end

	return moves
end

-- check for a full tile at line edge and extend it to clue length, add bounding empty
-- TODO: This works left-to-right; we should call it twice, once with the actual line and
--  once with a reversed-order line.  TODO: add a "reverse()" method to the Line object to
--  make it super simple and clean to get reverse-order version for these purposes.
function try_extend_and_bound_edge_clue(line)
	if not (line:getKnown(1) and line:getState(1)) then
		-- either the first tile is a mystery or it's known to be an empty, neither works for us
		return nil
	end

--TODO: it's not sufficient to jsut check the above; we need to also return nil if there's
-- a full clue and bounding empty here.  Though that shouldn't occur once we're properly
-- checking for bounding empties and bounding bounded clues up at the top, so maybe the real
-- to do item here is to get recursive calls of trimmed strings going...
--   duck level shows current error
	local target = line:getClues()[1]:getSize()
	local moves
	moves = {}
	for i=2, target do
		-- we can start at tile 2 because we already Know tile 1 is a Full
		if not line:getKnown(i) then
			table.insert(moves, {i, true})
		end
	end
	if not line:getKnown(target + 1) then
		table.insert(moves, {target + 1, false})
	end

	return moves

end


-- utility function: given a list of clues, returns the sum of the sizes of those clues
function sum_of_clues(c)
	local sum = 0
	for i, v in ipairs(c) do
		sum = sum + v:getSize()
	end
	return sum
end
