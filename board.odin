package chess

import "core:fmt"
import "core:math/bits"

Board :: struct {
	white_pawns:   u64,
	black_pawns:   u64,
	white_king:    u64,
	black_king:    u64,
	white_queens:  u64,
	black_queens:  u64,
	white_rooks:   u64,
	black_rooks:   u64,
	white_bishops: u64,
	black_bishops: u64,
	white_knights: u64,
	black_knights: u64,
}

DEFAULT_BOARD :: Board {
	white_pawns   = 0x000000000000FF00,
	black_pawns   = 0x00FF000000000000,
	white_king    = 0x0000000000000010,
	black_king    = 0x1000000000000000,
	white_queens  = 0x0000000000000008,
	black_queens  = 0x0800000000000000,
	white_rooks   = 0x0000000000000081,
	black_rooks   = 0x8100000000000000,
	white_bishops = 0x0000000000000024,
	black_bishops = 0x2400000000000000,
	white_knights = 0x0000000000000042,
	black_knights = 0x4200000000000000,
}

display_bitboard :: proc(bitboard: u64) {
	for y in 0 ..< 8 {
		for x in 0 ..< 8 {
			fmt.printf("%d ", square_occupied(bitboard, get_bitboard_square(x, y)) ? 1 : 0)
		}
		fmt.print("\n")
	}
}

get_bitboard_square :: proc(x: int, y: int) -> u64 {
	return cast(u64)(y * 8 + x)
}

bitboard_to_squares :: proc(bitboard: u64) -> [dynamic]u64 {
	squares := make([dynamic]u64)
	temp_board := bitboard

	for temp_board > 0 {
		trailing_zeros := bits.count_trailing_zeros(temp_board)
		append(&squares, cast(u64)trailing_zeros)
		temp_board &= temp_board - 1
	}

	return squares
}

get_x_y_from_square :: proc(square: u64) -> (x: int, y: int) {
	x = cast(int)square % 8
	y = cast(int)square / 8
	return
}

square_occupied :: proc(bitboard: u64, square: u64) -> bool {
	return (bitboard & (1 << square)) != 0
}

do_action_to_bitboard :: proc(board: ^Board, piece: Piece, raw_action: u64) {
	#partial switch piece {
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

force_move :: proc(board: ^Board, move: Move) {
	piece := get_piece(board, move.from)
	target_piece := get_piece(board, move.to)
	do_action_to_bitboard(board, piece, (1 << move.to) - (1 << move.from))

	if target_piece != Piece.None do do_action_to_bitboard(board, target_piece, -(1 << move.to))
}

force_add_piece :: proc(board: ^Board, piece: Piece, to: u64) {
	if piece != Piece.None do do_action_to_bitboard(board, piece, (1 << to))
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

get_player_bitboard :: proc(board: ^Board, player: Piece_Color) -> u64 {
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
	}

	return bitboard
}

get_all_player_pieces :: proc(board: ^Board, player: Piece_Color) -> [dynamic]u64 {
	return bitboard_to_squares(get_player_bitboard(board, player))
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

check_win :: proc(board: ^Board) -> Piece_Color {
	if is_checkmate(board, Piece_Color.Black) do return Piece_Color.White
	else if is_checkmate(board, Piece_Color.White) do return Piece_Color.Black
	else do return Piece_Color.None
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

		for to in to_positions do append(&moves, Move{from, to})
		return moves
	}

	pieces := get_all_player_pieces(board, player)
	for square in pieces {
		piece := get_piece(board, square)
		if get_piece_color(piece) != player do continue

		cur_moves := get_moves(board, square, piece)

		for pos in cur_moves {
			append(&moves, Move{from = square, to = pos})
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
	combined :=
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
		board.black_knights
	return (combined & (1 << square)) != 0
}

display_board :: proc(board: ^Board) {
	fmt.printfln("+----+----+----+----+----+----+----+----+----+")

	for y in 0 ..< 9 {
		for x in 0 ..< 9 {

			if y == 0 && x == 0 {
				fmt.print("|    ")
			} else if y == 0 {
				fmt.printf("| %r  ", cast(rune)(96 + x))
			} else if x == 0 {
				fmt.printf("| %d  ", 9 - y)
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
	return fmt.tprintf("%r%d", cast(rune)(97 + x), 8 - y)
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

