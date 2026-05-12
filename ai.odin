package chess

start_minimax :: proc(board: ^Board, depth: u8, player: Piece_Color) -> (u64, u64) {
	return minimax(board, true, depth, player)
}

// returns (from, to) or (score, to)
minimax :: proc(board: ^Board, maximising: bool, depth: u8, player: Piece_Color) -> (u64, u64) {
	win := check_win(board)

	inverted_player := invert_color(player)
	available_moves := get_all_moves_possible(board, player)

	for move in available_moves {
	}

	return 0, 0
}

