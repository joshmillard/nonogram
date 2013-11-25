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

In principle, each of these tricks could be called independently, and a nonce semi-complete
brain could be composed of a subset of the tricks for demonstrative purposes.  In practice,
they're relying as written on the order of the and assumptions drawn from that, and would
require additional sanity checks (for e.g. an empty clue string) at a per-trick level to
be properly foolproof.
--]]


	local tricks = {
		{ try_recurse_without_bounding_clues_and_empties, false },
		{ try_empty, false },
		{ try_full, false },
		{	try_perfect_fit, false },
		{ try_all_empties_accounted_for, false },
		{ try_all_fulls_accounted_for, false },
		{ try_extend_and_bound_edge_clue, true },
		{ try_off_by_one, true },
		{ try_full_near_edge, true },
		{ try_pad_empties_on_single_clue, false },
		{ try_empty_too_small_edgemost_gap, true },
		{ try_fill_bound_edgemost_clue, true },
		{ try_unbounded_largest_clue, false },
		{ try_single_clue_wider_than_half_the_line, false },
		{ try_shift_and_overlap, false },
		{ try_recursive_fill_bound_edgemost_clue, true },
		{ try_gapped_fulls_longer_than_longest_clue, false },
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

-- utility function: given a list of clues, returns the sum of the sizes of those clues
function sum_of_clues(c)
	local sum = 0
	for i, v in ipairs(c) do
		sum = sum + v:getSize()
	end
	return sum
end

-- debugging utility, just prints what we know about current line
function printline(line)
	-- clues
	local str
	str = "Clues: {"
	for i,v in ipairs(line:getClues()) do
		str = str .. " " .. v:getSize()
	end
	str = str .. " }  "
	for i=1, line:getLength() do
		if line:getKnown(i) then
			if line:getState(i) then
				str = str .. "O"
			else
				str = str .. "X"
			end
		else
			str = str .. "_"
		end
	end
	print(str)
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
-- this is a reversible function
function try_extend_and_bound_edge_clue(line)
	if not (line:getKnown(1) and line:getState(1)) then
		-- either the first tile is a mystery or it's known to be an empty, neither works for us
		return nil
	end

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

-- check to see if, for first clue of size n, tile n+1 is known to be Full; if so, tile 1 can *not*
-- be Full as that would butt up against the known full tile that could not be part of that first
-- clue's tiles.  Mark as empty!
-- REVERSIBLE
function try_off_by_one(line)
	local n = line:getClues()[1]:getSize()
	if line:getKnown(n + 1) and line:getState(n + 1) then
		-- we know that tile n+1 is Full, so tile 1 must be Empty
		if not line:getKnown(1) then
			return { {1, false} }
		end
	end

	return nil
end

-- check to see if there's a full tile nearer the edge than the length of the first clue, and
-- pad out to length of clue accordingly with Fulls
-- REVERSIBLE
function try_full_near_edge(line)
	local s = line:getClues()[1]:getSize()
	local padding = false
	local moves
	moves = {}
	for i=1, s do
		if line:getKnown(i) and line:getState(i) and not padding then
			-- we know this is a Full tile, commence padding!
			padding = true
		elseif not line:getKnown(i) and padding then
			-- this should be Full as well!
			table.insert(moves, {i, true})
		end
	end

	if table.getn(moves) == 0 then
		return nil
	end
	
	return moves
end

-- if there's a single clue and at least one known full, check for tiles out of reach of the
-- possible range of that clue and fill in empties
function try_pad_empties_on_single_clue(line)
	if table.getn(line:getClues()) ~= 1 then
		return nil
	end

	local n = line:getClues()[1]:getSize()
	local leftmost 
	local rightmost
	for i=1, line:getLength() do
		if line:getKnown(i) and line:getState(i) then
			-- found a known Full tile
			if not leftmost then
				leftmost = i
				rightmost = i
			else
				rightmost = i
			end
		end
	end

	if not leftmost then
		-- didn't find a Full tile, bail
		return nil
	end

	local moves
	moves = {}
	-- okay, let's check for empties out of range on either side
	for i=1, rightmost - n do
		if not line:getKnown(i) then
			table.insert(moves, {i, false})
		end
	end
	for i=line:getLength(), leftmost + n, -1 do
		if not line:getKnown(i) then
			table.insert(moves, {i, false})
		end
	end

	if table.getn(moves) == 0 then
		-- didn't actually find anything new
		return nil
	end

	return moves
end


-- Check to see if the gap of Unknown tiles between the edge and the first Empty tile is smaller 
-- than the first clue (with no Full tiles in the interim); if so, those must be Empty tiles.
-- REVERSIBLE
function try_empty_too_small_edgemost_gap(line)
	local n = line:getClues()[1]:getSize()
	local empty = 0
	for i=1, n do
		if line:getKnown(i) and line:getState(i) then
			-- found a full tile in this area, that won't work
			return nil
		elseif line:getKnown(i) and not line:getState(i) then
			-- found an empty tile, that's all we needed to know!
			empty = i
			break
		end
	end

	if empty == 0 then
		-- we didn't find an empty in the clue-length run
		return nil
	end

	-- fill everything from 1 to empty-1 with new Empty tiles
	local moves
	moves = {}
	for i=1, empty - 1 do
		table.insert(moves, {i, false})
	end

	return moves
end


-- check to see if a Full tile bound by an Empty tile can only be in the edgemost clue, and add Fulls
-- as is applicable.  Rationale: given two clues in a list, they can appear at best as clue 1 + single
-- tile gap + clue 2 + empty.  Therefore, if there's a full tile in a run of tiles of size no longer 
-- than clue 1 + clue 2 (no gap) bounded by an empty, only clue 1 can actually be in there.
-- REVERSIBLE
function try_fill_bound_edgemost_clue(line)
	local leftmost = 0
	local rightmost = 0
	local empty = 0
	if table.getn(line:getClues()) < 2 then
		-- if there aren't at least two clues, we don't need to do this because earlier rules
		-- can handle the single-clue situation just fine
		return nil
	end 


	local c1 = line:getClues()[1]:getSize()
	local c2 = line:getClues()[2]:getSize()

	for i=1, c1 + c2 + 1 do
		if line:getKnown(i) and not line:getState(i) then
			-- we found an empty tile, record position and bail
			empty = i
			break
		elseif line:getKnown(i) and line:getState(i) then
			-- we found a full tile; note the first one in leftmost, track farther one in rightmost 
			if leftmost == 0 then
				leftmost = i
			end
			rightmost = i
		end
	end

	if empty == 0 then
		-- we never found an empty tile in the revelant range of tiles, bail
		return nil
	end

	if leftmost == 0 then
		-- we never found a full tile in the empty-bounded range, bail
		return nil
	end

	local moves
	moves = {}
	-- fill in outer empties
	for i=1, rightmost - c1 do
		-- any tiles sufficiently far from the far edged of known full tiles here is Empty
		if not line:getKnown(i) then
			table.insert(moves, {i, false})
		end
	end
	for i=leftmost + c1, empty do
		if not line:getKnown(i) then
			table.insert(moves, {i, false})
		end
	end
	-- and fill in Fulls
	if leftmost < c1 then
		-- bound out to c1 with what must be Fulls
		for i=leftmost + 1, c1 do
			if not line:getKnown(i) then
				table.insert(moves, {i, true})
			end
		end
	end
	if rightmost > empty - c1 then
		for i=empty - c1, rightmost do
			if not line:getKnown(i) then
				table.insert(moves, {i, true})
			end
		end
	end


	if table.getn(moves) == 0 then
		-- no new moves found
		return nil
	end

	return moves
	
end

-- utility function, returns size of largest clue(s) in list
function get_largest_clue(clues)
	local largest = 0
	for i,v in ipairs(clues) do
		if v:getSize() > largest then
			largest = v:getSize()
		end
	end

	return largest
end

-- for the largest clue in the list, if we have any strings of fulls that length that aren't
-- bounded on both ends by empties, add those empties.
function try_unbounded_largest_clue(line)
	local largest
	largest = get_largest_clue(line:getClues())
	if largest == 0 then
		-- hrm, seems like there's no clues, abort
		return nil
	end

	-- iterate across line, looking for largest-length runs of tiles
	local moves
	moves = {}
	local start = 0 
	local run = 0
	for i=1, line:getLength() do
		if line:getKnown(i) and line:getState(i) then
			-- found a full tile
			if start == 0 then
				start = i
				run = 1
			else
				run = run + 1
			end
			-- check if we've hit the length threshold
			if run == largest then
				-- this must be a full clue!  Bound it and reset counters for next possible match
				if start > 1 then -- bounds check so we don't try to index off left side of board
					if not line:getKnown(start - 1) then
						table.insert(moves, {start - 1, false})
print("unbounded capping left at " .. start - 1)	
					end
				end
				if start + run <= line:getLength() then-- bounds check, right side
					if not line:getKnown(start + run) then
						table.insert(moves, {start + run, false})
print("unbounded capping right at " .. start + run)
					end
				end
				start = 0
				run = 0
			end
		else
			-- any time we find a tile that's not a known full, restart the counting
			start = 0
			run = 0
		end
	end

	if table.getn(moves) == 0 then
		-- found nothing
		return nil
	end

	return moves
end

-- a reductive case of a general shift and overlap strategy that's easier to eyeball: if there's
-- a single clue, and it's size is greater than half the length of the line, one or more tiles
-- in the center of the line *must* be Full.
function try_single_clue_wider_than_half_the_line(line)
	if table.getn(line:getClues()) ~= 1 then
		-- either too mahy or too few clues, let's bail
		return nil
	end

	local s = line:getClues()[1]:getSize()
	local l = line:getLength()
	if s*2 <= l then
		-- clue is too short to make use of this trick
		return nil
	end

	local moves
	moves = {}
	for i = (l-s) + 1, s do
		if not line:getKnown(i) then
			table.insert(moves, {i, true})
		end
	end

	if table.getn(moves) == 0 then
		return nil
	end

	return moves
end

-- gettin' serious: this does a full-line check for the leftmost and rightmost placement of
-- the clue list with single-tile gaps, marking any tiles marked as filled by the same clue in
-- both cases as Full.  Does not take into account the additional information available from 
-- Known states; this works simply on the clues and line length.  A version considering the 
-- further constraints of known Fulls and Empties would be even more powerful.
--
-- e.g. {3 1 2} XXXXXXXXXX
-- left:        111_2_33__
-- right:       __111_2_33
-- overlap:       ^
function try_shift_and_overlap(line)
	local leftish = {}
	local rightish = {}
	local number_of_clues = table.getn(line:getClues()) 
	local minimal_length = sum_of_clues(line:getClues()) + number_of_clues - 1
	local shift = line:getLength() - minimal_length

	-- prepad right-side render with 0s
	for i=1, shift do
		table.insert(rightish, 0)
	end

	-- render both with minimal gap contents
	for i, v in ipairs(line:getClues()) do
		for j=1, v:getSize() do
			table.insert(leftish, i)
			table.insert(rightish, i)
		end
		if i < number_of_clues then
			table.insert(leftish, 0)
			table.insert(rightish, 0)
		end
	end

	-- and postpad left-side render with 0s
	for i = minimal_length + 1, line:getLength() do
		table.insert(leftish, 0)
	end			

	local moves
	moves = {}
	-- now compare the strings and try adding a Full where they meet up
	for i=1, line:getLength() do
		if leftish[i] == rightish[i] and leftish[i] ~= 0 then
			if not line:getKnown(i) then
				table.insert(moves, {i, true})
			end
		end
	end
	
	if table.getn(moves) == 0 then
		return nil
	end

	print("Shift and overlap, filling " .. table.getn(moves) .. " tiles.")

	return moves
end

-- a biggie: use the same approach as try_fill_bound_edgemost_clue, but then instead of
-- just trying to do some work on that pre-empty segment, split the line into two segments
-- and call solve_line on each recursively, then add up any returned moves to create a
-- single set of moves to return
function try_recursive_fill_bound_edgemost_clue(line)

	local leftmost = 0
	local rightmost = 0
	local empty = 0
	if table.getn(line:getClues()) < 2 then
		-- if there aren't at least two clues, we don't need to do this because earlier rules
		-- can handle the single-clue situation just fine
		return nil
	end 


	local c1 = line:getClues()[1]:getSize()
	local c2 = line:getClues()[2]:getSize()

	for i=1, c1 + c2 + 1 do
		if line:getKnown(i) and not line:getState(i) then
			-- we found an empty tile, record position and bail
			empty = i
			break
		elseif line:getKnown(i) and line:getState(i) then
			-- we found a full tile; note the first one in leftmost, track farther one in rightmost 
			if leftmost == 0 then
				leftmost = i
			end
			rightmost = i
		end
	end

	if empty == 0 then
		-- we never found an empty tile in the revelant range of tiles, bail
		return nil
	end

	if leftmost == 0 then
		-- we never found a full tile in the empty-bounded range, bail
		return nil
	end

print("recursing with sublines 1 to " .. empty - 1 .. " and " .. empty + 1 .. " to " .. line:getLength())
	-- get two sublines: 1 to (empty - 1) with clue 1, and (empty + 1) to length with clues 2,...
	local moves1
	moves1 = solve_line(line:subline(1, empty - 1, 1, 1) )

	local moves2
	moves2 = solve_line(line:subline(empty + 1, line:getLength(), 2, table.getn(line:getClues())) )
	if moves2 then
		-- adjust move values based on subline start position
		for i,v in ipairs(moves2) do
			v[1] = v[1] + empty 
		end	
	end

	local moves = {}
	if moves1 and moves2 then
		-- only need a union if both came back with something
		moves = get_move_list_union(moves1, moves2)
	elseif moves1 then
		moves = moves1
	elseif moves2 then
		moves = moves2
	else
		-- if they're both empty bail
		return nil
	end

local str = ""
for i,v in ipairs(moves) do
	str = str .. " " .. v[1]
end
print("Found " .. table.getn(moves) .. " new moves:" .. str)

	return moves
	
end

-- check for adjacent runs of full tiles separated by a single unknown tile, where the sum
-- of the two fulls and the gap is greater than the length of the longest clue on the line.
-- Such an unknown tile *must* be Empty.
--
-- e.g. {1 5 1 2} ____OOO_OO_____
--                       ^
function try_gapped_fulls_longer_than_longest_clue(line)
	local largest
	largest = get_largest_clue(line:getClues())

	local left_index = 0
	local right_index = 0
	local left_length = 0
	local right_length = 0
	local gap = 0
	local moves
	moves = {}
	for i=1, line:getLength() do
		if line:getKnown(i) and line:getState(i) then 
			if left_index == 0 then
				-- just starting to build our first run of fulls
				left_index = i
				left_length = 1
			elseif gap == 0 then
				-- we're still building first run
				left_length = left_length + 1
			elseif right_index == 0 then
				-- previous tile was gap, we're just starting in on second run
				right_index = i
				right_length = 1
			else
				-- still building second run
				right_length = right_length + 1
			end
		elseif line:getKnown(i) and not line:getState(i) then
			-- we came across an explicit empty tile, which means nothing to the left of it
			-- can be part of our target pattern.  Reset the tracking variables.
			left_index = 0
			left_length = 0
			right_index = 0
			right_length = 0
			gap = 0
		else
			-- this is an unknown tile that might be an empty
			if gap == 0 and left_index ~= 0 then
				gap = i
			elseif gap > 0 and left_index ~= 0 then
				-- oh no, two gaps in a row!  That ruins this particular process.
				left_index = 0
				left_length = 0
				right_index = 0
				right_length = 0
			else
				-- left_index == 0, ergo we're not building a full run yet and so don't
				-- need to do anything in the face of a gap
			end
		end

		-- after all that, check to see if have a gapped pair of full runs longer than the
		-- longest clue. If not, do nothing; if so, mark the gap as Empty and make the right
		-- run the new left run and keep going.
		if right_length > 0 and left_length + right_length + 1 > largest then
			table.insert(moves, {gap, false})
			left_index = right_index
			left_length = right_length
			right_index = 0
			right_length = 0
			gap = 0
		end

	end	

	if table.getn(moves) == 0 then
		return nil
	end

local str = ""
for i,v in ipairs(moves) do
	str = str .. " " .. v[1]
end
print("Too-long gapped pair: placing Empties at:" .. str) 

	return moves

end

-- give two lists of moves, return the union of thoses lists to eliminate dupes
function get_move_list_union(m1, m2)
	local hash = {}
	for i,v in ipairs(m1) do
		hash.v[1] = v[2]
	end
	for i,v in ipairs(m2) do
		hash.v[1] = v[2]
	end

	local union = {}
	for k,v in pairs(hash) do
		table.insert(union, {k, v})
	end

	return union
end
