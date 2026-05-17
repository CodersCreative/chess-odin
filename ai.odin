package chess
import "core:math/bits"


PAWN_VALUE :: 10
KNIGHT_VALUE :: 30
BISHOP_VALUE :: 30
ROOK_VALUE :: 50
QUEEN_VALUE :: 90
KING_VALUE :: 180

get_score :: proc(board: ^Board, player: Piece_Color) -> i64 {
	black_score :=
		cast(i64)count_bitboard_pieces(board.black_bishops) * BISHOP_VALUE +
		cast(i64)count_bitboard_pieces(board.black_knights) * KNIGHT_VALUE +
		cast(i64)count_bitboard_pieces(board.black_king) * KING_VALUE +
		cast(i64)count_bitboard_pieces(board.black_pawns) * PAWN_VALUE +
		cast(i64)count_bitboard_pieces(board.black_queens) * QUEEN_VALUE +
		cast(i64)count_bitboard_pieces(board.black_rooks) * ROOK_VALUE

	white_score :=
		cast(i64)count_bitboard_pieces(board.white_bishops) * BISHOP_VALUE +
		cast(i64)count_bitboard_pieces(board.white_knights) * KNIGHT_VALUE +
		cast(i64)count_bitboard_pieces(board.white_king) * KING_VALUE +
		cast(i64)count_bitboard_pieces(board.white_pawns) * PAWN_VALUE +
		cast(i64)count_bitboard_pieces(board.white_queens) * QUEEN_VALUE +
		cast(i64)count_bitboard_pieces(board.white_rooks) * ROOK_VALUE

	return (white_score - black_score) * ((player == Piece_Color.Black) ? -1 : 1)
}

start_minimax :: proc(board: ^Board, depth: u8, player: Piece_Color) -> Move {
	_, move := minimax(board, true, depth, player, bits.I64_MIN, bits.I64_MAX)
	return move
}

minimax :: proc(
	board: ^Board,
	maximising: bool,
	depth: u8,
	player: Piece_Color,
	alpha: i64,
	beta: i64,
) -> (
	i64,
	Move,
) {
	win, stalemate := check_win(board)
	inverted_player := invert_color(player)

	if win == player {
		return 200 - (MINIMAX_DEPTH - cast(i64)depth) + get_score(board, player), Move{}
	} else if win == inverted_player {
		return -200 + cast(i64)depth + get_score(board, player), Move{}
	} else if depth <= 0 || stalemate {
		return 0 - (MINIMAX_DEPTH - cast(i64)depth) + get_score(board, player), Move{}
	}

	alpha := alpha
	beta := beta

	available_moves := get_all_moves_possible(board, (maximising) ? player : inverted_player)
	best_score: i64 = (maximising) ? bits.I64_MIN : bits.I64_MAX
	best_move: Move = len(available_moves) == 0 ? Move{} : available_moves[0]

	for move in available_moves {
		target_piece := get_piece(board, move.to)

		en_passant := board.enpassant
		half_move_clock := board.half_move_clock
		full_move_clock := board.full_move_clock

		force_move(board, move)
		score, _ := minimax(board, !maximising, depth - 1, player, alpha, beta)
		force_move(board, Move{from = move.to, to = move.from})

		board.enpassant = en_passant
		board.half_move_clock = half_move_clock
		board.full_move_clock = full_move_clock

		force_add_piece(board, target_piece, move.to)

		if maximising {
			best_score = max(best_score, score)
			alpha = max(alpha, score)
		} else {
			best_score = min(best_score, score)
			beta = min(beta, score)
		}

		if beta < alpha do break

		if best_score == score do best_move = move
	}

	return best_score, best_move
}

