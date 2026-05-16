package chess
import "core:math/bits"

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
	win := check_win(board)
	inverted_player := invert_color(player)

	if win == player {
		return 50 - (MINIMAX_DEPTH - cast(i64)depth), Move{}
	} else if win == inverted_player {
		return -50 + cast(i64)depth, Move{}
	} else if depth <= 0 {
		return 0, Move{}
	}

	alpha := alpha
	beta := beta

	available_moves := get_all_moves_possible(board, (maximising) ? player : inverted_player)
	best_score: i64 = (maximising) ? bits.I64_MIN : bits.I64_MAX
	best_move: Move = len(available_moves) == 0 ? Move{} : available_moves[0]

	for move in available_moves {
		target_piece := get_piece(board, move.to)
		force_move(board, move)

		score, _ := minimax(board, !maximising, depth - 1, player, alpha, beta)

		force_move(board, Move{from = move.to, to = move.from})
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

