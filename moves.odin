package chess

get_pawn_moves :: proc(board: ^Board, square: u64, piece: Piece) -> [dynamic]u64 {
	moves: [dynamic]u64
	x, y := get_x_y_from_square(square)

	if piece == Piece.White_Pawn {
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

get_moves :: proc(board: ^Board, square: u64) -> [dynamic]u64 {
	piece := get_piece(board, square)

	#partial switch piece {
	case Piece.White_Pawn, Piece.Black_Pawn:
		return get_pawn_moves(board, square, piece)
	case:
		return make([dynamic]u64)
	}

	return make([dynamic]u64)
}

