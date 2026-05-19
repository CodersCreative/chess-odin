package chess
import "core:fmt"
import "core:math/bits"
import "core:time"


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

Cache_Entry :: struct {
	key:   u64,
	depth: u8,
	score: i64,
	move:  Move,
}

TRANSPOSITION_TABLE: map[u64]Cache_Entry

start_negamax :: proc(board: ^Board, depth: u8, player: Piece_Color) -> Move {
	_, move := negamax(board, depth, player, bits.I64_MIN + 1, bits.I64_MAX - 1)
	return move
}

negamax :: proc(
	board: ^Board,
	depth: u8,
	player: Piece_Color,
	alpha: i64,
	beta: i64,
) -> (
	i64,
	Move,
) {
	player := player
	zobrist_key := get_zobrist(board, &player)
	if entry, exists := TRANSPOSITION_TABLE[zobrist_key]; exists && entry.depth >= depth {
		return entry.score, entry.move
	}

	win, stalemate := check_win(board)
	inverted_player := invert_color(player)

	if win == player {
		return 200 - (MINIMAX_DEPTH - cast(i64)depth) + get_score(board, player), Move{}
	} else if win == inverted_player {
		return -200 + cast(i64)depth - get_score(board, inverted_player), Move{}
	} else if depth <= 0 || stalemate {
		return get_score(board, player) - get_score(board, inverted_player), Move{}
	}

	alpha_mutable := alpha
	available_moves := get_all_moves_possible(board, player)
	defer delete(available_moves)

	if len(available_moves) == 0 do return 0, Move{}


	left := 0
	for right := 0; right < len(available_moves); right += 1 {
		if available_moves[right].capturing {
			available_moves[left], available_moves[right] =
				available_moves[right], available_moves[left]
			left += 1
		}
	}


	best_score: i64 = bits.I64_MIN
	best_move := available_moves[0]

	for move in available_moves {
		target_piece := get_piece(board, move.to)

		actions := force_move(board, move)
		defer delete(actions.actions)

		score, _ := negamax(board, depth - 1, inverted_player, -beta, -alpha_mutable)
		score = -score

		force_undo(board, actions)

		if score > best_score {
			best_score = score
			best_move = move
		}

		alpha_mutable = max(alpha_mutable, best_score)
		if alpha_mutable >= beta do break
	}

	TRANSPOSITION_TABLE[zobrist_key] = Cache_Entry{zobrist_key, depth, best_score, best_move}

	return best_score, best_move
}

