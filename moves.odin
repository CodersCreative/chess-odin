package chess

Move :: struct {
	from:      u64,
	to:        u64,
	capturing: u16,
	promotion: General_Piece,
}

get_pawn_moves :: proc(board: ^Board, square: u64, piece: Piece) -> [dynamic]u64 {
	moves: [dynamic]u64
	x, y := get_x_y_from_square(square)
	color := get_piece_color(piece)

	if color == Piece_Color.White {
		move := get_bitboard_square(x, 3)
		if y == 1 && !piece_exists(board, move) do append(&moves, move)

		move = get_bitboard_square(x, y + 1)
		if y < 7 && !piece_exists(board, move) do append(&moves, move)

		move = get_bitboard_square(x + 1, y + 1)
		if x < 7 && y < 7 && piece_exists(board, move) do append(&moves, move)

		move = get_bitboard_square(x - 1, y + 1)
		if x > 0 && y < 7 && piece_exists(board, move) do append(&moves, move)
	} else {
		move := get_bitboard_square(x, 4)
		if y == 6 && !piece_exists(board, move) do append(&moves, move)

		move = get_bitboard_square(x, y - 1)
		if y > 0 && !piece_exists(board, move) do append(&moves, move)

		move = get_bitboard_square(x + 1, y - 1)
		if x < 7 && y > 0 && piece_exists(board, move) do append(&moves, move)

		move = get_bitboard_square(x - 1, y - 1)
		if x > 0 && y > 0 && piece_exists(board, move) do append(&moves, move)
	}

	return moves
}

add_move :: proc(board: ^Board, moves: ^[dynamic]u64, x, y: int, color: Piece_Color) -> bool {
	target := get_bitboard_square(x, y)

	if !piece_exists(board, target) {
		append(moves, target)
		return true
	} else {
		target_piece := get_piece(board, target)
		if get_piece_color(target_piece) != color {
			append(moves, target)
		}
		return false
	}
}


get_rook_moves :: proc(board: ^Board, square: u64, piece: Piece) -> [dynamic]u64 {
	moves: [dynamic]u64
	x, y := get_x_y_from_square(square)
	color := get_piece_color(piece)

	for i := x + 1; i < 8; i += 1 {
		if !add_move(board, &moves, i, y, color) do break
	}

	for i := x - 1; i >= 0; i -= 1 {
		if !add_move(board, &moves, i, y, color) do break
	}

	for i := y + 1; i < 8; i += 1 {
		if !add_move(board, &moves, x, i, color) do break
	}

	for i := y - 1; i >= 0; i -= 1 {
		if !add_move(board, &moves, x, i, color) do break
	}

	return moves
}

get_bishop_moves :: proc(board: ^Board, square: u64, piece: Piece) -> [dynamic]u64 {
	moves: [dynamic]u64
	x, y := get_x_y_from_square(square)
	color := get_piece_color(piece)

	dirs := [4][2]int{{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

	for dir in dirs {
		for i := 1; i < 8; i += 1 {
			new_x := x + (dir.x * i)
			new_y := y + (dir.y * i)

			if new_x < 0 || new_x > 7 || new_y < 0 || new_y > 7 do break
			if !add_move(board, &moves, new_x, new_y, color) do break
		}
	}

	return moves
}

get_king_moves :: proc(board: ^Board, square: u64, piece: Piece) -> [dynamic]u64 {
	moves: [dynamic]u64
	x, y := get_x_y_from_square(square)
	color := get_piece_color(piece)

	dirs := [8][2]int{{1, 1}, {1, -1}, {-1, 1}, {-1, -1}, {1, 0}, {0, 1}, {-1, 0}, {0, -1}}

	for dir in dirs {
		new_x := x + dir.x
		new_y := y + dir.y

		if !(new_x < 0 || new_x > 7 || new_y < 0 || new_y > 7) do add_move(board, &moves, new_x, new_y, color)
	}

	if color == Piece_Color.Black {
		if board.castling & BLACK_K_CASTLING_VALID == BLACK_K_CASTLING_VALID &&
		   !piece_exists(board, get_bitboard_square(6, 7)) &&
		   !piece_exists(board, get_bitboard_square(5, 7)) {
			king_square := board.black_king
			if !is_in_check(board, Piece_Color.Black) {
				attackers1 := move_possible(board, get_bitboard_square(5, 7), Piece_Color.White)
				defer delete(attackers1)
				attackers2 := move_possible(board, get_bitboard_square(6, 7), Piece_Color.White)
				defer delete(attackers2)
				if len(attackers1) == 0 && len(attackers2) == 0 {
					append(&moves, get_bitboard_square(6, 7))
				}
			}
		}

		if board.castling & BLACK_Q_CASTLING_VALID == BLACK_Q_CASTLING_VALID &&
		   !piece_exists(board, get_bitboard_square(1, 7)) &&
		   !piece_exists(board, get_bitboard_square(2, 7)) &&
		   !piece_exists(board, get_bitboard_square(3, 7)) {
			king_square := board.black_king
			if !is_in_check(board, Piece_Color.Black) {
				attackers1 := move_possible(board, get_bitboard_square(3, 7), Piece_Color.White)
				defer delete(attackers1)
				attackers2 := move_possible(board, get_bitboard_square(2, 7), Piece_Color.White)
				defer delete(attackers2)
				if len(attackers1) == 0 && len(attackers2) == 0 {
					append(&moves, get_bitboard_square(2, 7))
				}
			}
		}
	} else if color == Piece_Color.White {
		if board.castling & WHITE_K_CASTLING_VALID == WHITE_K_CASTLING_VALID &&
		   !piece_exists(board, get_bitboard_square(6, 0)) &&
		   !piece_exists(board, get_bitboard_square(5, 0)) {
			king_square := board.white_king
			if !is_in_check(board, Piece_Color.White) {
				attackers1 := move_possible(board, get_bitboard_square(5, 0), Piece_Color.Black)
				defer delete(attackers1)
				attackers2 := move_possible(board, get_bitboard_square(6, 0), Piece_Color.Black)
				defer delete(attackers2)
				if len(attackers1) == 0 && len(attackers2) == 0 {
					append(&moves, get_bitboard_square(6, 0))
				}
			}
		}

		if board.castling & WHITE_Q_CASTLING_VALID == WHITE_Q_CASTLING_VALID &&
		   !piece_exists(board, get_bitboard_square(1, 0)) &&
		   !piece_exists(board, get_bitboard_square(2, 0)) &&
		   !piece_exists(board, get_bitboard_square(3, 0)) {
			king_square := board.white_king
			if !is_in_check(board, Piece_Color.White) {
				attackers1 := move_possible(board, get_bitboard_square(3, 0), Piece_Color.Black)
				defer delete(attackers1)
				attackers2 := move_possible(board, get_bitboard_square(2, 0), Piece_Color.Black)
				defer delete(attackers2)
				if len(attackers1) == 0 && len(attackers2) == 0 {
					append(&moves, get_bitboard_square(2, 0))
				}
			}
		}
	}

	return moves
}

get_knight_moves :: proc(board: ^Board, square: u64, piece: Piece) -> [dynamic]u64 {
	moves: [dynamic]u64
	x, y := get_x_y_from_square(square)
	color := get_piece_color(piece)

	dirs := [8][2]int{{1, 2}, {-1, 2}, {1, -2}, {-1, -2}, {2, 1}, {2, -1}, {-2, 1}, {-2, -1}}

	for dir in dirs {
		new_x := x + dir.x
		new_y := y + dir.y

		if !(new_x < 0 || new_x > 7 || new_y < 0 || new_y > 7) do add_move(board, &moves, new_x, new_y, color)
	}

	return moves
}

get_queen_moves :: proc(board: ^Board, square: u64, piece: Piece) -> [dynamic]u64 {
	moves := get_rook_moves(board, square, piece)
	append(&moves, ..get_bishop_moves(board, square, piece)[:])
	return moves
}

get_moves :: proc(board: ^Board, square: u64, piece: Piece = Piece.None) -> [dynamic]u64 {
	piece := piece
	if piece == Piece.None do piece = get_piece(board, square)

	#partial switch piece {
	case Piece.White_Pawn, Piece.Black_Pawn:
		return get_pawn_moves(board, square, piece)
	case Piece.White_Rook, Piece.Black_Rook:
		return get_rook_moves(board, square, piece)
	case Piece.White_Bishop, Piece.Black_Bishop:
		return get_bishop_moves(board, square, piece)
	case Piece.White_Queen, Piece.Black_Queen:
		return get_queen_moves(board, square, piece)
	case Piece.White_King, Piece.Black_King:
		return get_king_moves(board, square, piece)
	case Piece.White_Knight, Piece.Black_Knight:
		return get_knight_moves(board, square, piece)
	case:
		return make([dynamic]u64)
	}

	return make([dynamic]u64)
}


get_moves_bitboard :: proc(moves: []u64) -> u64 {
	board: u64 = 0

	for move in moves {
		board |= move
	}

	return board
}

