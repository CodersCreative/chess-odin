package chess
import "core:math/bits"
import "core:prof/spall"
import "core:time"

PAWN_VALUE :: 100
KNIGHT_VALUE :: 320
BISHOP_VALUE :: 330
ROOK_VALUE :: 500
QUEEN_VALUE :: 900
KING_VALUE :: 1800

get_piece_score_with_positional :: proc(board: ^Board, bitboard: u64, piece: Piece) -> i64 {
	score: i64 = 0
	squares := bitboard_to_squares(bitboard, context.temp_allocator)

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

Search_Context :: struct {
	stop_check:   proc() -> bool,
	node_counter: ^i64,
}

capture_sort_moves :: proc(moves: ^[dynamic]Move) -> int {
	left := 0
	for right := 0; right < len(moves); right += 1 {
		if moves[right].capturing > moves[left].capturing {
			moves[left], moves[right] = moves[right], moves[left]
			left += 1
		}
	}

	return left
}

start_negamax :: proc(
	board: ^Board,
	max_depth: u8,
	player: Piece_Color,
	ctx: ^Search_Context = nil,
) -> Move {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	best_move := Move{}
	available_moves := get_all_moves_possible(board, player, context.temp_allocator)

	if len(available_moves) == 0 do return Move{}

	capture_sort_moves(&available_moves)

	start := time.tick_now()

	for current_depth: u8 = 1; current_depth <= max_depth; current_depth += 1 {
		initial_negamax(
			board,
			current_depth,
			player,
			bits.I64_MIN + 1,
			bits.I64_MAX - 1,
			&available_moves,
			ctx,
		)

		if time.tick_diff(start, time.tick_now()) >= AI_MOVE_DURATION_SEC * time.Second {
			break
		}
	}

	return (len(available_moves) > 0) ? available_moves[0] : Move{}
}

initial_negamax :: proc(
	board: ^Board,
	depth: u8,
	player: Piece_Color,
	alpha: i64,
	beta: i64,
	available_moves: ^[dynamic]Move,
	ctx: ^Search_Context = nil,
) {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	player := player
	inverted_player := invert_color(player)

	best_score: i64 = bits.I64_MIN
	alpha := alpha

	scores := make([dynamic]i64, 0, len(available_moves), context.allocator)
	defer delete(scores)

	for i := 0; i < len(available_moves); i += 1 {
		if ctx != nil && ctx.stop_check != nil && ctx.stop_check() do break

		move := available_moves[i]
		actions := force_move(board, move)

		score := negamax(board, depth - 1, inverted_player, -beta, -alpha, ctx)
		score = -score
		append(&scores, score)

		force_undo(board, actions)
		delete(actions.actions)

		if score > best_score {
			best_score = score
		}

		alpha = max(alpha, best_score)
		if alpha >= beta do break
	}

	for i := 1; i < len(available_moves) && i < len(scores); i += 1 {
		for j := i; j > 0 && scores[j] > scores[j - 1]; j -= 1 {
			available_moves[j], available_moves[j - 1] = available_moves[j - 1], available_moves[j]
			scores[j], scores[j - 1] = scores[j - 1], scores[j]
		}
	}
}

evaluate_score :: proc(
	board: ^Board,
	depth: u8,
	player: Piece_Color,
	alpha: i64,
	beta: i64,
) -> i64 {

	win, stalemate := check_win(board)
	inverted_player := invert_color(player)

	if win == player {
		return 1800 - (MINIMAX_DEPTH - cast(i64)depth) + get_score(board, player)
	} else if win == inverted_player {
		return -1800 + cast(i64)depth - get_score(board, inverted_player)
	} else if stalemate {
		return get_score(board, player) - get_score(board, inverted_player)
	} else {
		return 0
	}
}

negamax :: proc(
	board: ^Board,
	depth: u8,
	player: Piece_Color,
	alpha: i64,
	beta: i64,
	ctx: ^Search_Context = nil,
) -> i64 {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	if ctx != nil && ctx.stop_check != nil && ctx.stop_check() do return 0

	player := player
	zobrist_key := get_zobrist(board, &player)
	if entry, exists := TRANSPOSITION_TABLE[zobrist_key]; exists && entry.depth >= depth {
		return entry.score
	}

	score := evaluate_score(board, depth, player, alpha, beta)
	if score != 0 do return score

	if depth <= 0 {
		score := quiescence(board, player, alpha, beta, 4, ctx)
		return score
	}

	alpha := alpha
	available_moves := get_all_moves_possible(board, player, context.temp_allocator)

	if len(available_moves) == 0 do return 0

	capture_sort_moves(&available_moves)

	best_score: i64 = bits.I64_MIN
	best_move := available_moves[0]

	for move in available_moves {
		if ctx != nil && ctx.stop_check != nil && ctx.stop_check() do break

		actions := force_move(board, move)

		if ctx != nil && ctx.node_counter != nil {
			ctx.node_counter^ += 1
		}

		score := -negamax(board, depth - 1, invert_color(player), -beta, -alpha, ctx)

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

quiescence :: proc(
	board: ^Board,
	player: Piece_Color,
	alpha: i64,
	beta: i64,
	depth: u8 = 4,
	ctx: ^Search_Context = nil,
) -> i64 {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	if ctx != nil && ctx.stop_check != nil && ctx.stop_check() do return 0

	inverted_player := invert_color(player)
	baseline := get_score(board, player) - get_score(board, inverted_player)
	alpha := alpha

	score := evaluate_score(board, depth, player, alpha, beta)
	if score != 0 do return score

	if baseline >= beta do return beta
	if baseline > alpha do alpha = baseline

	available_moves := get_all_moves_possible(board, player, context.temp_allocator)

	left := capture_sort_moves(&available_moves)

	for i := 0; i < left; i += 1 {
		if ctx != nil && ctx.stop_check != nil && ctx.stop_check() do break

		move := available_moves[i]

		capture_value := cast(i64)move.capturing
		if baseline + capture_value + 100 < alpha do continue

		actions := force_move(board, move)

		if ctx != nil && ctx.node_counter != nil {
			ctx.node_counter^ += 1
		}

		score := -quiescence(board, inverted_player, -beta, -alpha, depth - 1, ctx)

		force_undo(board, actions)
		delete(actions.actions)

		if score >= beta do return beta
		if score > alpha do alpha = score
	}

	return alpha
}

