package chess

import "core:fmt"
main :: proc() {
	board := DEFAULT_BOARD
	display_board(&board)
	board.black_pawns = 0
	board.white_pawns = 0
	moves := get_moves(&board, get_bitboard_square(1, 7))
	fmt.println(moves)
	display_bitboard(get_moves_bitboard(moves[:]))
}

