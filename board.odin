package chess

import "core:fmt"
import "core:math/bits"

Board :: struct {
	white_pawns:     u64,
	black_pawns:     u64,
	white_king:      u64,
	black_king:      u64,
	white_queens:    u64,
	black_queens:    u64,
	white_rooks:     u64,
	black_rooks:     u64,
	white_bishops:   u64,
	black_bishops:   u64,
	white_knights:   u64,
	black_knights:   u64,
	enpassant:       u16,
	castling:        u8,
	half_move_clock: u8,
	full_move_clock: u8,
}

CASTLING_START: u8 : 0b01110111
BLACK_K_CASTLING_VALID: u8 : 0b00110000
BLACK_Q_CASTLING_VALID: u8 : 0b01010000

WHITE_K_CASTLING_VALID: u8 : 0b00000011
WHITE_Q_CASTLING_VALID: u8 : 0b00000101

WHITE_KING_START: u64 : 0x0000000000000010
BLACK_KING_START: u64 : 0x1000000000000000

WHITE_PAWNS_START: u64 : 0x000000000000FF00
BLACK_PAWNS_START: u64 : 0x00FF000000000000

DEFAULT_BOARD :: Board {
	white_pawns   = WHITE_PAWNS_START,
	black_pawns   = BLACK_PAWNS_START,
	white_king    = WHITE_KING_START,
	black_king    = BLACK_KING_START,
	white_queens  = 0x0000000000000008,
	black_queens  = 0x0800000000000000,
	white_rooks   = 0x0000000000000081,
	black_rooks   = 0x8100000000000000,
	white_bishops = 0x0000000000000024,
	black_bishops = 0x2400000000000000,
	white_knights = 0x0000000000000042,
	black_knights = 0x4200000000000000,
	castling      = CASTLING_START,
}

display_bitboard :: proc(bitboard: u64) {
	for y := 7; y >= 0; y -= 1 {
		for x in 0 ..< 8 {
			fmt.printf("%d ", square_occupied(bitboard, get_bitboard_square(x, y)) ? 1 : 0)
		}
		fmt.print("\n")
	}
}

display_pretty_bitboard :: proc(bitboard: u64) {
	fmt.printfln("+----+----+----+----+----+----+----+----+----+")

	for y := 9; y > 0; y -= 1 {
		for x in 0 ..< 9 {

			if y == 9 && x == 0 {
				fmt.print("|    ")
			} else if y == 9 {
				fmt.printf("| %r  ", cast(rune)(96 + x))
			} else if x == 0 {
				fmt.printf("| %d  ", y)
			} else {
				fmt.printf(
					"| %s ",
					square_occupied(bitboard, get_bitboard_square(x - 1, y - 1)) ? "x " : "  ",
				)
			}
		}
		fmt.print("|\n")
		fmt.printfln("+----+----+----+----+----+----+----+----+----+")
	}
}

get_bitboard_square :: proc(x: int, y: int) -> u64 {
	return 1 << cast(u64)(y * 8 + x)
}


bitboard_to_squares :: proc(bitboard: u64) -> [dynamic]u64 {
	squares := make([dynamic]u64)
	bitboard := bitboard

	for bitboard > 0 {
		lowest_bit_mask := bitboard & -bitboard
		append(&squares, lowest_bit_mask)
		bitboard &= bitboard - 1
	}

	return squares
}

is_stalemate :: proc(board: ^Board) -> bool {
	total := count_bitboard_pieces(get_total_bitboard(board, Piece_Color.None))

	if total == 2 do return true

	if total == 3 && (count_bitboard_pieces(board.white_bishops | board.black_bishops) == 1 || count_bitboard_pieces(board.white_knights | board.black_knights) == 1) do return true

	if total == 4 && (count_bitboard_pieces(board.white_knights | board.black_knights) == 2) do return true

	if board.half_move_clock >= 50 do return true

	return false
}

count_bitboard_pieces :: proc(bitboard: u64) -> u8 {
	return cast(u8)bits.count_ones(bitboard)
}

count_pieces :: proc(board: ^Board, piece: Piece) -> u8 {
	#partial switch piece {
	case Piece.White_Pawn:
		return count_bitboard_pieces(board.white_pawns)
	case Piece.Black_Pawn:
		return count_bitboard_pieces(board.black_pawns)
	case Piece.White_King:
		return count_bitboard_pieces(board.white_king)
	case Piece.Black_King:
		return count_bitboard_pieces(board.black_king)
	case Piece.White_Queen:
		return count_bitboard_pieces(board.white_queens)
	case Piece.Black_Queen:
		return count_bitboard_pieces(board.black_queens)
	case Piece.White_Rook:
		return count_bitboard_pieces(board.white_rooks)
	case Piece.Black_Rook:
		return count_bitboard_pieces(board.black_rooks)
	case Piece.White_Bishop:
		return count_bitboard_pieces(board.white_bishops)
	case Piece.Black_Bishop:
		return count_bitboard_pieces(board.black_bishops)
	case Piece.White_Knight:
		return count_bitboard_pieces(board.white_knights)
	case Piece.Black_Knight:
		return count_bitboard_pieces(board.black_knights)
	}

	return 0
}

get_x_y_from_square :: proc(square: u64) -> (x: int, y: int) {
	square := bits.count_trailing_zeros(square)
	x = cast(int)square & 7
	y = cast(int)square >> 3
	return
}


square_occupied :: proc(bitboard: u64, square: u64) -> bool {
	return (bitboard & square) != 0
}

process_algebraic_move :: proc(
	board: ^Board,
	player: Piece_Color,
	details: Notation_Details,
) -> (
	Move,
	bool,
) {
	is_white := player == Piece_Color.White

	if details.king_side_castle {
		return Move {
				from = is_white ? get_bitboard_square(4, 0) : get_bitboard_square(4, 7),
				to = is_white ? get_bitboard_square(6, 0) : get_bitboard_square(6, 7),
				capturing = false,
				promotion = .None,
			},
			true
	} else if details.queen_side_castle {
		return Move {
				from = is_white ? get_bitboard_square(4, 0) : get_bitboard_square(4, 7),
				to = is_white ? get_bitboard_square(2, 0) : get_bitboard_square(2, 7),
				capturing = false,
				promotion = .None,
			},
			true
	}

	specific_piece := get_piece_from_general_piece(details.piece, is_white)
	if specific_piece == Piece.None do return Move{}, false

	pieces_bitboard: u64 = 0
	switch specific_piece {
	case .White_Pawn:
		pieces_bitboard = board.white_pawns
	case .Black_Pawn:
		pieces_bitboard = board.black_pawns
	case .White_King:
		pieces_bitboard = board.white_king
	case .Black_King:
		pieces_bitboard = board.black_king
	case .White_Queen:
		pieces_bitboard = board.white_queens
	case .Black_Queen:
		pieces_bitboard = board.black_queens
	case .White_Rook:
		pieces_bitboard = board.white_rooks
	case .Black_Rook:
		pieces_bitboard = board.black_rooks
	case .White_Bishop:
		pieces_bitboard = board.white_bishops
	case .Black_Bishop:
		pieces_bitboard = board.black_bishops
	case .White_Knight:
		pieces_bitboard = board.white_knights
	case .Black_Knight:
		pieces_bitboard = board.black_knights
	case .None:
		return Move{}, false
	}

	from: u64 = 0

	candidate_squares := bitboard_to_squares(pieces_bitboard)
	defer delete(candidate_squares)

	for square in candidate_squares {
		x, y := get_x_y_from_square(square)

		if details.from_x != 9 && cast(int)details.from_x != x do continue
		if details.from_y != 9 && cast(int)details.from_y != y do continue

		moves := get_moves(board, square)
		defer delete(moves)

		found := false
		for move in moves {
			if move == details.to {
				from = square
				found = true
				break
			}
		}
		if found do break
	}

	if from == 0 do return Move{}, false

	return Move {
			from = from,
			to = details.to,
			capturing = details.capturing,
			promotion = details.promotion,
		},
		true
}

do_action_to_bitboard :: proc(board: ^Board, action: Action) {
	raw_action := action.action

	if action.rev {
		#partial switch action.piece {
		case Piece.White_Pawn:
			board.white_pawns -= raw_action
		case Piece.Black_Pawn:
			board.black_pawns -= raw_action
		case Piece.White_King:
			board.white_king -= raw_action
		case Piece.Black_King:
			board.black_king -= raw_action
		case Piece.White_Queen:
			board.white_queens -= raw_action
		case Piece.Black_Queen:
			board.black_queens -= raw_action
		case Piece.White_Rook:
			board.white_rooks -= raw_action
		case Piece.Black_Rook:
			board.black_rooks -= raw_action
		case Piece.White_Bishop:
			board.white_bishops -= raw_action
		case Piece.Black_Bishop:
			board.black_bishops -= raw_action
		case Piece.White_Knight:
			board.white_knights -= raw_action
		case Piece.Black_Knight:
			board.black_knights -= raw_action
		}
	} else {
		#partial switch action.piece {
		case Piece.White_Pawn:
			board.white_pawns += raw_action
		case Piece.Black_Pawn:
			board.black_pawns += raw_action
		case Piece.White_King:
			board.white_king += raw_action
		case Piece.Black_King:
			board.black_king += raw_action
		case Piece.White_Queen:
			board.white_queens += raw_action
		case Piece.Black_Queen:
			board.black_queens += raw_action
		case Piece.White_Rook:
			board.white_rooks += raw_action
		case Piece.Black_Rook:
			board.black_rooks += raw_action
		case Piece.White_Bishop:
			board.white_bishops += raw_action
		case Piece.Black_Bishop:
			board.black_bishops += raw_action
		case Piece.White_Knight:
			board.white_knights += raw_action
		case Piece.Black_Knight:
			board.black_knights += raw_action
		}
	}
}

ENPASSANT_WHITE: u64 : 0x00000000FF000000
ENPASSANT_BLACK: u64 : 0x000000FF00000000

PROMOTION_WHITE: u64 : 0xFF00000000000000
PROMOTION_BLACK: u64 : 0x00000000000000FF

Action :: struct {
	piece:  Piece,
	action: u64,
	rev:    bool,
}

Actions :: struct {
	actions:         [dynamic]Action,
	enpassant:       u16,
	castling:        u8,
	half_move_clock: u8,
	full_move_clock: u8,
}

do_and_append_action :: proc(board: ^Board, actions: ^Actions, action: Action) {
	append(&actions.actions, action)
	do_action_to_bitboard(board, action)
}

force_move :: proc(board: ^Board, move: Move) -> (actions: Actions) {
	actions.castling = board.castling
	actions.half_move_clock = board.half_move_clock
	actions.full_move_clock = board.full_move_clock

	piece := get_piece(board, move.from)
	target_piece := get_piece(board, move.to)

	if piece == Piece.White_Pawn &&
	   move.to & ENPASSANT_WHITE != 0 &&
	   move.from & WHITE_PAWNS_START != 0 {
		board.enpassant = 0
		x, _ := get_x_y_from_square(move.to)
		board.enpassant |= 1 << cast(u16)(x)
	} else if piece == Piece.Black_Pawn &&
	   move.to & ENPASSANT_BLACK != 0 &&
	   move.from & BLACK_PAWNS_START != 0 {
		board.enpassant = 0
		x, _ := get_x_y_from_square(move.to)
		board.enpassant |= 1 << cast(u16)(x + 8)
	} else if target_piece == Piece.None && board.enpassant != 0 {
		x, y := get_x_y_from_square(move.to)
		if board.enpassant & (1 << cast(u16)(x + 8)) != 0 &&
		   get_piece_color(piece) != Piece_Color.Black {
			square := get_bitboard_square(x, y - 1)
			if get_piece(board, square) == Piece.Black_Pawn do do_and_append_action(board, &actions, Action{piece = Piece.Black_Pawn, action = square, rev = true})
		} else if board.enpassant & (1 << cast(u16)(x)) != 0 &&
		   get_piece_color(piece) != Piece_Color.White {
			square := get_bitboard_square(x, y + 1)
			if get_piece(board, square) == Piece.White_Pawn do do_and_append_action(board, &actions, Action{piece = Piece.White_Pawn, action = square, rev = true})
		}

		board.enpassant = 0
	}

	do_and_append_action(
		board,
		&actions,
		Action {
			piece = piece,
			action = (move.to > move.from) ? move.to - move.from : move.from - move.to,
			rev = !(move.to > move.from),
		},
	)

	board.full_move_clock += 1

	if target_piece != Piece.None {
		board.half_move_clock = 0
		do_and_append_action(
			board,
			&actions,
			Action{piece = target_piece, action = move.to, rev = true},
		)
	} else if piece != Piece.White_Pawn && piece != Piece.Black_Pawn do board.half_move_clock += 1
	else do board.half_move_clock = 0

	if piece == Piece.White_Pawn && move.to & PROMOTION_WHITE != 0 {
		do_and_append_action(board, &actions, Action{piece = piece, action = move.to, rev = true})

		promotion := get_piece_from_general_piece(move.promotion, true)

		do_and_append_action(
			board,
			&actions,
			Action {
				piece = (promotion == Piece.None) ? Piece.White_Queen : promotion,
				action = move.to,
			},
		)
	} else if piece == Piece.Black_Pawn && move.to & PROMOTION_BLACK != 0 {
		do_and_append_action(board, &actions, Action{piece = piece, action = move.to, rev = true})

		promotion := get_piece_from_general_piece(move.promotion, false)
		do_action_to_bitboard(
			board,
			Action {
				piece = (promotion == Piece.None) ? Piece.Black_Queen : promotion,
				action = move.to,
			},
		)
	} else if piece == Piece.White_King && board.castling & 0b00001111 != 0 {
		if move.to == get_bitboard_square(6, 0) &&
		   board.castling & WHITE_K_CASTLING_VALID == WHITE_K_CASTLING_VALID {
			do_and_append_action(
				board,
				&actions,
				Action {
					piece = Piece.White_Rook,
					action = get_bitboard_square(7, 0) - get_bitboard_square(5, 0),
					rev = true,
				},
			)
		} else if move.to == get_bitboard_square(2, 0) &&
		   board.castling & WHITE_Q_CASTLING_VALID == WHITE_Q_CASTLING_VALID {
			do_and_append_action(
				board,
				&actions,
				Action {
					piece = Piece.White_Rook,
					action = get_bitboard_square(3, 0) - get_bitboard_square(0, 0),
				},
			)
		}

		board.castling &= 0b11110000
	} else if piece == Piece.Black_King && board.castling & 0b11110000 != 0 {
		if move.to == get_bitboard_square(6, 7) &&
		   board.castling & BLACK_K_CASTLING_VALID == BLACK_K_CASTLING_VALID {
			do_and_append_action(
				board,
				&actions,
				Action {
					piece = Piece.Black_Rook,
					action = get_bitboard_square(7, 7) - get_bitboard_square(5, 7),
					rev = true,
				},
			)
		} else if move.to == get_bitboard_square(2, 7) &&
		   board.castling & BLACK_Q_CASTLING_VALID == BLACK_Q_CASTLING_VALID {
			do_and_append_action(
				board,
				&actions,
				Action {
					piece = Piece.Black_Rook,
					action = get_bitboard_square(3, 7) - get_bitboard_square(0, 7),
				},
			)
		}

		board.castling &= 0b00001111
	} else if piece == Piece.White_Rook && board.castling & 0b00000110 != 0 {
		if move.from == get_bitboard_square(0, 0) {
			board.castling ~= 0b00000100
		} else if move.from == get_bitboard_square(7, 0) {
			board.castling ~= 0b00000010
		}
	} else if piece == Piece.Black_Rook && board.castling & 0b01100000 != 0 {
		if move.from == get_bitboard_square(0, 7) {
			board.castling ~= 0b01000000
		} else if move.from == get_bitboard_square(7, 7) {
			board.castling ~= 0b00100000
		}
	}

	return
}

force_add_piece :: proc(board: ^Board, piece: Piece, to: u64) {
	if piece != Piece.None do do_action_to_bitboard(board, Action{piece = piece, action = to})
}

force_undo :: proc(board: ^Board, actions: Actions) {
	for i := (len(actions.actions) - 1); i >= 0; i -= 1 {
		action := actions.actions[i]
		do_action_to_bitboard(
			board,
			Action{piece = action.piece, action = action.action, rev = !action.rev},
		)
	}

	board.castling = actions.castling
	board.enpassant = actions.enpassant
	board.half_move_clock = actions.half_move_clock
	board.full_move_clock = actions.full_move_clock
}

move_possible :: proc(board: ^Board, to: u64, by: Piece_Color) -> [dynamic]u64 {
	froms := make([dynamic]u64)
	pieces := get_all_player_pieces(board, by)

	for square in pieces {
		piece := get_piece(board, square)
		if get_piece_color(piece) != by do continue

		moves := get_moves(board, square, piece)

		for target in moves {
			if target == to do append(&froms, square)
		}
	}

	return froms
}

get_total_bitboard :: proc(board: ^Board, player: Piece_Color) -> u64 {
	bitboard: u64

	#partial switch player {
	case Piece_Color.Black:
		bitboard =
			board.black_bishops |
			board.black_king |
			board.black_knights |
			board.black_pawns |
			board.black_queens |
			board.black_rooks
	case Piece_Color.White:
		bitboard =
			board.white_bishops |
			board.white_king |
			board.white_knights |
			board.white_pawns |
			board.white_queens |
			board.white_rooks
	case Piece_Color.None:
		return(
			board.white_pawns |
			board.black_pawns |
			board.white_king |
			board.black_king |
			board.white_queens |
			board.black_queens |
			board.white_rooks |
			board.black_rooks |
			board.white_bishops |
			board.black_bishops |
			board.white_knights |
			board.black_knights \
		)
	}

	return bitboard
}

get_all_player_pieces :: proc(board: ^Board, player: Piece_Color) -> [dynamic]u64 {
	return bitboard_to_squares(get_total_bitboard(board, player))
}

is_in_check :: proc(board: ^Board, player: Piece_Color) -> bool {
	#partial switch player {
	case Piece_Color.Black:
		black_king_squares := bitboard_to_squares(board.black_king)
		if len(black_king_squares) == 0 do return false
		return len(move_possible(board, black_king_squares[0], Piece_Color.White)) != 0
	case Piece_Color.White:
		white_king_squares := bitboard_to_squares(board.white_king)
		if len(white_king_squares) == 0 do return false
		return len(move_possible(board, white_king_squares[0], Piece_Color.Black)) != 0
	}

	return false
}

get_valid_king_moves :: proc(board: ^Board, player: Piece_Color) -> [dynamic]u64 {
	valid_moves: [dynamic]u64

	#partial switch player {
	case Piece_Color.Black:
		black_king_squares := bitboard_to_squares(board.black_king)
		if len(black_king_squares) == 0 do return valid_moves
		moves := get_moves(board, black_king_squares[0], Piece.Black_King)

		for move in moves {
			if len(move_possible(board, move, Piece_Color.White)) == 0 do append(&valid_moves, move)
		}
	case Piece_Color.White:
		white_king_squares := bitboard_to_squares(board.white_king)
		if len(white_king_squares) == 0 do return valid_moves
		moves := get_moves(board, white_king_squares[0], Piece.White_King)

		for move in moves {
			if len(move_possible(board, move, Piece_Color.Black)) == 0 do append(&valid_moves, move)
		}
	}

	return valid_moves
}

is_checkmate :: proc(board: ^Board, player: Piece_Color) -> bool {
	if !is_in_check(board, player) do return false
	return len(get_valid_king_moves(board, player)) == 0
}

check_win :: proc(board: ^Board) -> (Piece_Color, bool) {
	if board.white_king == 0 do return Piece_Color.Black, false
	else if board.black_king == 0 do return Piece_Color.White, false
	else if is_checkmate(board, Piece_Color.Black) do return Piece_Color.White, false
	else if is_checkmate(board, Piece_Color.White) do return Piece_Color.Black, false
	else do return Piece_Color.None, is_stalemate(board)
}


get_all_moves_possible :: proc(board: ^Board, player: Piece_Color) -> [dynamic]Move {
	if is_checkmate(board, invert_color(player)) do return make([dynamic]Move)

	moves: [dynamic]Move

	if is_in_check(board, player) {
		to_positions := get_valid_king_moves(board, player)
		king_squares := bitboard_to_squares(
			(player == Piece_Color.Black) ? board.black_king : board.white_king,
		)
		if len(king_squares) == 0 do return moves
		from := king_squares[0]

		for to in to_positions {
			append(
				&moves,
				Move{from = from, to = to, capturing = get_piece(board, to) != Piece.None},
			)
		}
		return moves
	}

	pieces := get_all_player_pieces(board, player)
	for square in pieces {
		piece := get_piece(board, square)
		if get_piece_color(piece) != player do continue

		cur_moves := get_moves(board, square, piece)

		for pos in cur_moves {
			append(
				&moves,
				Move{from = square, to = pos, capturing = get_piece(board, pos) != Piece.None},
			)
		}

	}

	return moves
}

get_piece :: proc(board: ^Board, square: u64) -> Piece {
	if square_occupied(board.white_pawns, square) do return Piece.White_Pawn
	else if square_occupied(board.black_pawns, square) do return Piece.Black_Pawn
	else if square_occupied(board.white_king, square) do return Piece.White_King
	else if square_occupied(board.black_king, square) do return Piece.Black_King
	else if square_occupied(board.white_queens, square) do return Piece.White_Queen
	else if square_occupied(board.black_queens, square) do return Piece.Black_Queen
	else if square_occupied(board.white_rooks, square) do return Piece.White_Rook
	else if square_occupied(board.black_rooks, square) do return Piece.Black_Rook
	else if square_occupied(board.white_bishops, square) do return Piece.White_Bishop
	else if square_occupied(board.black_bishops, square) do return Piece.Black_Bishop
	else if square_occupied(board.white_knights, square) do return Piece.White_Knight
	else if square_occupied(board.black_knights, square) do return Piece.Black_Knight
	else do return Piece.None
}

piece_exists :: proc(board: ^Board, square: u64) -> bool {
	return (get_total_bitboard(board, Piece_Color.None) & square) != 0
}

display_board :: proc(board: ^Board) {
	fmt.printfln("+----+----+----+----+----+----+----+----+----+")

	for y := 9; y > 0; y -= 1 {
		for x in 0 ..< 9 {

			if y == 9 && x == 0 {
				fmt.print("|    ")
			} else if y == 9 {
				fmt.printf("| %r  ", cast(rune)(96 + x))
			} else if x == 0 {
				fmt.printf("| %d  ", y)
			} else {
				fmt.printf(
					"| %s ",
					piece_to_str(get_piece(board, get_bitboard_square(x - 1, y - 1))),
				)
			}
		}
		fmt.print("|\n")
		fmt.printfln("+----+----+----+----+----+----+----+----+----+")
	}
}

square_to_notation :: proc(square: u64) -> string {
	x, y := get_x_y_from_square(square)
	return fmt.tprintf("%r%d", cast(rune)(97 + x), y + 1)
}

HISTORY_WIDTH :: 6

display_history :: proc(history: []HistoryMove) {
	history_len := len(history)
	height := cast(int)(history_len / HISTORY_WIDTH) + ((history_len % HISTORY_WIDTH == 0) ? 0 : 1)

	for y in 0 ..< height {
		for x in 0 ..< HISTORY_WIDTH {
			index := y * HISTORY_WIDTH + x
			if index >= history_len do continue
			move := history[index]
			fmt.printf(
				"%s : %s-%s | ",
				piece_to_str(move.piece),
				square_to_notation(move.move.from),
				square_to_notation(move.move.to),
			)
		}
		fmt.print("\n")
	}

	fmt.print("\n")
}

