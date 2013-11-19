module(..., package.seeall);

-- Nonogram project 2.0

require "Tile"
require "Line"
require "Board"
require "Move"

b = {} -- the board object

-- handy constants for UI element placement
BX = 180
BY = 80
BSIZE = 20

-- a list of levels for now
puzzles = {"dolphin", "ducky", "gender", "longneck", "octopus", "stripes", "vassal"}
puzzleindex = 1

peeking = false -- for peeking at the board during testing

function love.load()

	love.graphics.setMode(600, 600, false, true, 0)
	love.graphics.setCaption("Nonograms!")

--	generate_random_board() 
	load_puzzle("gender")
end

-- event loop
function love.update(dt)

	local mdown = love.mouse.isDown("l", "r")
	local mleft = love.mouse.isDown("l")
	local mright = love.mouse.isDown("r")
	local mx = love.mouse.getX()
	local my = love.mouse.getY()
	local ktoggle = love.keyboard.isDown("lshift")
	
	-- check for mouse button down over board tiles
	if mdown then
		local tx, ty = get_mouse_tile(mx, my)
		if tx ~= nil then
			if not b:getKnown(tx, ty) then
				-- we've clicked on an as-yet-unrevealed tile
				local guess = true
				if mright or (mleft and ktoggle) then
					guess = false
				elseif mleft then
					guess = true
				else
					-- we shouldn't be able to get here!
					print("wtf mouse stuff, freak out!")
				end
				guess_tile(tx, ty, guess)
			end
		end
	end

	-- are we peeking at the board for testing purposes?
	if love.keyboard.isDown("p") then
		peeking = true
	else
		peeking = false
	end

end

-- get which board tile, if any, the mouse is currently over, returning x and y coordinates
function get_mouse_tile(mx, my)
	if mx <= BX + BSIZE or mx > BX + (b:getWidth() + 1)*BSIZE then
		return nil, nil
	end
	if my <= BY + BSIZE or my > BY + (b:getHeight() + 1)*BSIZE then
		return nil, nil
	end
	-- if we've survived this far, we're over the board!  Return tile coordinates.
	local tx = math.ceil( (mx - (BX + BSIZE)) / BSIZE )
	local ty = math.ceil( (my - (BY + BSIZE)) / BSIZE )

	return tx, ty
end


-- draw shit each frame
function love.draw()

	draw_board()
end


-- handle keyboard press events
function love.keypressed(key)
	if key == "escape" then
		love.event.quit()
	elseif key == "r" then
		generate_random_board()
	elseif key == "n" then
		load_next_puzzle()
	elseif key == "m" then
		print_moves() -- just a test thing to see if move lists are storing correctly 
	end
end

-- throwaway test for Move management
function print_moves()
	for i,v in ipairs(b:getMoves()) do
		local x, y, guess, correct, time = v:getMove()
		local glabel, clabel
		if guess then
			glabel = "Full"
		else
			glabel = "Empty"
		end
		if correct then
			clabel = "correct"
		else
			clabel = "wrong"
		end
		print("Move #" .. i .. " (" .. time .. " secs): " .. x .. "," .. y .. " guessed as " .. glabel .. " -- " .. clabel)
	end
end

-- register a guess with the game about a given tile being Full or Empty
function guess_tile(x, y, guess)
	b:setKnown(x, y, true)
	actual = b:getState(x, y)
	if guess == actual then
		b:addMove(x, y, guess, true, b:getElapsed())
	else
		b:addMove(x, y, guess, false, b:getElapsed())
	end
end

-- generate a random board
function generate_random_board()
	b = Board.new(math.random(15) + 5, math.random(15) + 5)
	fill_board_with_noise()
end

-- load a puzzle by name
function load_puzzle(name)
	b = Board.new(1,1)
	b:create_board_from_file(name)
end

-- load the next puzzle in the list
function load_next_puzzle()
	puzzleindex = puzzleindex + 1
	if puzzleindex > table.getn(puzzles) then
		puzzleindex = 1
	end
	load_puzzle(puzzles[puzzleindex])
end

-- fill up existing board with noise
function fill_board_with_noise()
	-- set some tiles at random
	for y=1, b:getHeight() do
		local t_str = ""
		for x=1, b:getWidth() do
			if math.random() > 0.5 then
				b:fillTile(x, y)
			end
			if b:getState(x, y) then
				t_str = t_str .. "0"
			else
				t_str = t_str .. "-"
			end
		end
		--print(t_str)
	end
end

-- draw the current board state
function draw_board()

	-- misc. info
	love.graphics.setColor(200,200,200)
	love.graphics.print("Puzzle: " .. b:getName(), 20, 10)
	love.graphics.print("Size: " .. b:getWidth() .. "x" .. b:getHeight(), 20, 25)
	love.graphics.print("Elapsed time: " .. math.floor(b:getElapsed()) .. " secs", 20, 40)
	love.graphics.print("Errors: " .. b:getErrorCount(), 20, 55)

	-- draw frame
	love.graphics.setColor(40,40,40)
	love.graphics.rectangle("fill", BX + BSIZE, BY + BSIZE, b:getWidth() * BSIZE, b:getHeight() * BSIZE)

	love.graphics.setLine(1, "smooth")
	for x=1, b:getWidth() + 1 do
		if (x % 5 == 1) or (x == b:getWidth() + 1) then
			love.graphics.setColor(150,150,0)
		else
			love.graphics.setColor(100,100,100)
		end
		love.graphics.line(BX + x*BSIZE, BY + BSIZE, BX + x*BSIZE, BY + (b:getHeight() + 1)*BSIZE)
	end
	for y=1, b:getHeight() + 1 do
		if (y % 5 == 1) or (y == b:getHeight() + 1) then
			love.graphics.setColor(150,150,0)
		else
			love.graphics.setColor(100,100,100)
		end
		love.graphics.line(BX + BSIZE, BY + y*BSIZE, BX + (b:getWidth() + 1)*BSIZE, BY + y*BSIZE)
	end

	-- draw known tiles
	for x=1, b:getWidth() do
		for y=1, b:getHeight() do
			local state = b:getState(x, y)
			local known = b:getKnown(x, y)
			if known or peeking then
				-- only draw a symbol if we know the current state of the tile
				if state then
					-- it's a Full tile!
					love.graphics.setColor(200,200,200)
					love.graphics.rectangle("fill", BX + x*BSIZE + 1, BY + y*BSIZE + 1, BSIZE - 2, BSIZE - 2)
				else
					-- it's an Empty tile!
					love.graphics.setLine(2)
					love.graphics.setColor(150,0,0)
					love.graphics.line(BX + x*BSIZE + 6, BY + y*BSIZE + 6, 
						BX + (x+1)*BSIZE - 6, BY + (y+1)*BSIZE - 6)
					love.graphics.line(BX + x*BSIZE + 6, BY + (y+1)*BSIZE - 6,
						BX + (x+1)*BSIZE - 6, BY + y*BSIZE + 6)
				end
			end
		end
	end

	-- draw clues
	local c_solved = {100,100,100}
	local c_unsolved = {200,200,255}

	for y=1, b:getHeight() do
		local cl = b:getRowClues(y)

		local color
		if b:is_row_solved(y) then
			color = c_solved
		else
			color = c_unsolved
		end

		local str = ""
		for i=table.getn(cl), 1, -1 do
			str = cl[i]:getSize() .. "  " .. str
		end
		if str == "" then
			-- empty clue list, let's give 'em a zero
			str = "0"
		end
		love.graphics.setColor(color)
		love.graphics.printf(str, 0, BY + y*BSIZE, BX + 5, "right")
	end

	for x=1, b:getWidth() do
		local cl = b:getColumnClues(x)

		local color
		if b:is_column_solved(x) then
			color = c_solved
		else
			color = c_unsolved
		end
		
		if table.getn(cl) == 0 then
			love.graphics.setColor(color)
			love.graphics.print("0", BX + x*BSIZE + 2, BY - 15 + 10)
		else
			for i=1, table.getn(cl) do
				love.graphics.setColor(color)
				love.graphics.print(cl[table.getn(cl) - i + 1]:getSize(), BX + x*BSIZE + 2, BY - i*15 + 10)
			end
		end
	end

end

