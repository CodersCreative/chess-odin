package chess

start_minimax :: proc(board: ^Board, depth: u8, player: Piece_Color) -> (u64, bool) {
	return minimax(board, true, depth, player)
}

minimax :: proc(board: ^Board, maximising: bool, depth: u8, player: Piece_Color) -> (u64, bool) {
	return 0, false
}

