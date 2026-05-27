package chess
import "core:container/avl"
import "core:fmt"
import "core:math/bits"
import "core:slice"
import "core:time"

PAWN_VALUE :: 100
KNIGHT_VALUE :: 320
BISHOP_VALUE :: 330
ROOK_VALUE :: 500
QUEEN_VALUE :: 900
KING_VALUE :: 1800

get_piece_score_with_positional :: proc(board: ^Board, bitboard: u64, piece: Piece) -> i64 {
	score: i64 = 0
	squares := bitboard_to_squares(bitboard)
	defer delete(squares)

	for square in squares {
		score += cast(i64)get_positional_score(piece, square, board.full_move_clock)
	}
	return score
}

get_score :: proc(board: ^Board, player: Piece_Color) -> i64 {
	black_score :=
		cast(i64)count_bitboard_pieces(board.black_bishops) * BISHOP_VALUE +
		cast(i64)count_bitboard_pieces(board.black_knights) * KNIGHT_VALUE +
		cast(i64)count_bitboard_pieces(board.black_king) * KING_VALUE +
		cast(i64)count_bitboard_pieces(board.black_pawns) * PAWN_VALUE +
		cast(i64)count_bitboard_pieces(board.black_queens) * QUEEN_VALUE +
		cast(i64)count_bitboard_pieces(board.black_rooks) * ROOK_VALUE +
		get_piece_score_with_positional(board, board.black_bishops, Piece.Black_Bishop) +
		get_piece_score_with_positional(board, board.black_knights, Piece.Black_Knight) +
		get_piece_score_with_positional(board, board.black_king, Piece.Black_King) +
		get_piece_score_with_positional(board, board.black_pawns, Piece.Black_Pawn) +
		get_piece_score_with_positional(board, board.black_queens, Piece.Black_Queen) +
		get_piece_score_with_positional(board, board.black_rooks, Piece.Black_Rook)

	white_score :=
		cast(i64)count_bitboard_pieces(board.white_bishops) * BISHOP_VALUE +
		cast(i64)count_bitboard_pieces(board.white_knights) * KNIGHT_VALUE +
		cast(i64)count_bitboard_pieces(board.white_king) * KING_VALUE +
		cast(i64)count_bitboard_pieces(board.white_pawns) * PAWN_VALUE +
		cast(i64)count_bitboard_pieces(board.white_queens) * QUEEN_VALUE +
		cast(i64)count_bitboard_pieces(board.white_rooks) * ROOK_VALUE +
		get_piece_score_with_positional(board, board.white_bishops, Piece.White_Bishop) +
		get_piece_score_with_positional(board, board.white_knights, Piece.White_Knight) +
		get_piece_score_with_positional(board, board.white_king, Piece.White_King) +
		get_piece_score_with_positional(board, board.white_pawns, Piece.White_Pawn) +
		get_piece_score_with_positional(board, board.white_queens, Piece.White_Queen) +
		get_piece_score_with_positional(board, board.white_rooks, Piece.White_Rook)

	return (white_score - black_score) * ((player == Piece_Color.Black) ? -1 : 1)
}

get_value :: proc(piece: Piece) -> u16 {
	switch piece {
	case Piece.White_Pawn, Piece.Black_Pawn:
		return PAWN_VALUE
	case Piece.White_King, Piece.Black_King:
		return KING_VALUE
	case Piece.White_Queen, Piece.Black_Queen:
		return QUEEN_VALUE
	case Piece.White_Rook, Piece.Black_Rook:
		return ROOK_VALUE
	case Piece.White_Bishop, Piece.Black_Bishop:
		return BISHOP_VALUE
	case Piece.White_Knight, Piece.Black_Knight:
		return KNIGHT_VALUE
	case Piece.None:
		return 0
	}

	return 0
}

Cache_Entry :: struct {
	key:   u64,
	depth: u8,
	score: i64,
	move:  Move,
}

TRANSPOSITION_TABLE: map[u64]Cache_Entry

start_negamax :: proc(board: ^Board, max_depth: u8, player: Piece_Color) -> Move {
	best_move := Move{}
	available_moves := get_all_moves_possible(board, player)
	defer delete(available_moves)

	if len(available_moves) == 0 do return Move{}

	left := 0
	for right := 0; right < len(available_moves); right += 1 {
		if available_moves[right].capturing > available_moves[left].capturing {
			available_moves[left], available_moves[right] =
				available_moves[right], available_moves[left]
			left += 1
		}
	}

	start := time.tick_now()

	for current_depth: u8 = 1; current_depth <= max_depth; current_depth += 1 {
		move := initial_negamax(
			board,
			current_depth,
			player,
			bits.I64_MIN + 1,
			bits.I64_MAX - 1,
			&available_moves,
		)

		if move != (Move{}) {
			best_move = move
		}

		if time.tick_diff(start, time.tick_now()) >= AI_MOVE_DURATION_SEC * time.Second {
			fmt.println(current_depth)
			time.sleep(time.Second)
			break
		}
	}

	return best_move
}

initial_negamax :: proc(
	board: ^Board,
	depth: u8,
	player: Piece_Color,
	alpha: i64,
	beta: i64,
	available_moves: ^[dynamic]Move,
) -> Move {
	player := player
	inverted_player := invert_color(player)

	best_score: i64 = bits.I64_MIN
	best_move := available_moves[0]
	alpha := alpha

	scores := make([dynamic]i64, 0, len(available_moves), context.allocator)
	defer delete(scores)

	for i := 0; i < len(available_moves); i += 1 {
		move := available_moves[i]
		actions := force_move(board, move)

		score := negamax(board, depth - 1, inverted_player, -beta, -alpha)
		score = -score
		append(&scores, score)

		force_undo(board, actions)
		delete(actions.actions)

		if score > best_score {
			best_score = score
			best_move = move
		}

		alpha = max(alpha, best_score)
		if alpha >= beta do break
		if i > 0 {
			for x := i - 1; x >= 0; x -= 1 {
				if scores[x] < scores[x + 1] {
					available_moves[x], available_moves[x + 1] =
						available_moves[x + 1], available_moves[x]
				}
			}
		}

	}

	return best_move
}

negamax :: proc(board: ^Board, depth: u8, player: Piece_Color, alpha: i64, beta: i64) -> i64 {
	player := player
	zobrist_key := get_zobrist(board, &player)
	if entry, exists := TRANSPOSITION_TABLE[zobrist_key]; exists && entry.depth >= depth {
		return entry.score
	}

	win, stalemate := check_win(board)
	inverted_player := invert_color(player)

	if win == player {
		return 1800 - (MINIMAX_DEPTH - cast(i64)depth) + get_score(board, player)
	} else if win == inverted_player {
		return -1800 + cast(i64)depth - get_score(board, inverted_player)
	} else if stalemate {
		return get_score(board, player) - get_score(board, inverted_player)
	} else if depth <= 0 {
		score := quiescence(board, player, alpha, beta)
		return score
	}

	alpha := alpha
	available_moves := get_all_moves_possible(board, player)
	defer delete(available_moves)

	if len(available_moves) == 0 do return 0

	left := 0
	for right := 0; right < len(available_moves); right += 1 {
		if available_moves[right].capturing > available_moves[left].capturing {
			available_moves[left], available_moves[right] =
				available_moves[right], available_moves[left]
			left += 1
		}
	}

	best_score: i64 = bits.I64_MIN
	best_move := available_moves[0]

	for move in available_moves {
		actions := force_move(board, move)

		score := -negamax(board, depth - 1, inverted_player, -beta, -alpha)

		force_undo(board, actions)
		delete(actions.actions)

		if score > best_score {
			best_score = score
			best_move = move
		}

		alpha = max(alpha, best_score)
		if alpha >= beta do break
	}

	TRANSPOSITION_TABLE[zobrist_key] = Cache_Entry{zobrist_key, depth, best_score, best_move}

	return best_score
}

quiescence :: proc(board: ^Board, player: Piece_Color, alpha: i64, beta: i64) -> i64 {
	inverted_player := invert_color(player)
	baseline := get_score(board, player) - get_score(board, inverted_player)
	alpha := alpha

	if baseline >= beta do return beta
	if baseline > alpha do alpha = baseline

	available_moves := get_all_moves_possible(board, player)
	defer delete(available_moves)

	left := 0
	for right := 0; right < len(available_moves); right += 1 {
		if available_moves[right].capturing > available_moves[left].capturing {
			available_moves[left], available_moves[right] =
				available_moves[right], available_moves[left]
			left += 1
		}
	}

	for i := 0; i < left; i += 1 {
		move := available_moves[i]
		actions := force_move(board, move)

		score := -quiescence(board, inverted_player, -beta, -alpha)

		force_undo(board, actions)
		delete(actions.actions)

		if score >= beta do return beta
		if score > alpha do alpha = score
	}

	return alpha
}

