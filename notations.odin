package chess

import "core:fmt"
import "core:math/bits"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"


load_fen :: proc(board: ^Board, player: ^Piece_Color, fen: string) -> bool {
	board^ = Board{}
	index := 0
	null_spaces: u8 = 0

	for y := 7; y >= 0; y -= 1 {
		for x in 0 ..< 8 {
			if null_spaces > 0 {
				null_spaces -= 1
				continue
			}

			c := fen[index]

			if c > '0' && c < '9' {
				null_spaces = c - 49
				index += 1
				continue
			}

			if c == '/' {
				index += 1
				break
			}

			piece := get_piece_from_fen_piece(c)
			index += 1

			if piece == Piece.None do return false
			force_add_piece(board, piece, get_bitboard_square(x, y))
		}

		if fen[index] == '/' do index += 1
	}

	if fen[index] == '/' do index += 1
	if strings.is_separator(cast(rune)fen[index]) do index += 1

	player^ =
		(fen[index] == 'w') ? Piece_Color.White : (fen[index] == 'b') ? Piece_Color.Black : Piece_Color.None
	if player^ == Piece_Color.None do return false

	index += 1
	if strings.is_separator(cast(rune)fen[index]) do index += 1

	if fen[index] == '-' {
		index += 1
	} else {
		if fen[index] == 'K' {
			board.castling |= WHITE_K_CASTLING_VALID
			index += 1
		}

		if fen[index] == 'k' {
			board.castling |= BLACK_K_CASTLING_VALID
			index += 1
		}

		if fen[index] == 'Q' {
			board.castling |= WHITE_Q_CASTLING_VALID
			index += 1
		}

		if fen[index] == 'q' {
			board.castling |= BLACK_Q_CASTLING_VALID
			index += 1
		}

		if board.castling == 0 do return false
	}

	if strings.is_separator(cast(rune)fen[index]) do index += 1

	if fen[index] == '-' {
		index += 1
	} else {
		x := fen[index] - 97
		y := fen[index + 1] - 49

		if y > 3 {
			board.enpassant |= 1 << (8 + x)
		} else {
			board.enpassant |= 1 << x
		}

		index += 2
	}

	if strings.is_separator(cast(rune)fen[index]) do index += 1

	buffer: [4]u8
	i := 0

	for !strings.is_separator(cast(rune)fen[index]) {
		buffer[i] = fen[index]
		index += 1
		i += 1
	}

	val, _ := strconv.parse_int(string(buffer[:]))
	board.half_move_clock = cast(u8)val


	if strings.is_separator(cast(rune)fen[index]) do index += 1

	i = 0

	for len(fen) > index && !strings.is_separator(cast(rune)fen[index]) {
		buffer[i] = fen[index]
		index += 1
		i += 1
	}

	val, _ = strconv.parse_int(string(buffer[:]))
	board.full_move_clock = cast(u8)val * 2 + ((player^ == Piece_Color.White) ? 0 : 1)

	return true
}


Notation_Details :: struct {
	piece:             General_Piece,
	from_x:            u8,
	from_y:            u8,
	to:                u64,
	capturing:         bool,
	check:             bool,
	checkmate:         bool,
	promotion:         General_Piece,
	king_side_castle:  bool,
	queen_side_castle: bool,
	winner:            Piece_Color,
}


get_algebraic_notation_move_details :: proc(text: string) -> (Notation_Details, bool) {
	text := strings.trim_space(text)
	if len(text) == 0 do return Notation_Details{}, false

	index := 0

	if text == "1-0" do return Notation_Details{winner = Piece_Color.White, from_x = 9, from_y = 9}, true
	if text == "0-1" do return Notation_Details{winner = Piece_Color.Black, from_x = 9, from_y = 9}, true
	if text == "1/2-1/2" do return Notation_Details{winner = Piece_Color.None, from_x = 9, from_y = 9}, true

	if strings.has_prefix(text, "O-O-O") || strings.has_prefix(text, "0-0-0") {
		return Notation_Details{queen_side_castle = true, from_x = 9, from_y = 9}, true
	}
	if strings.has_prefix(text, "O-O") || strings.has_prefix(text, "0-0") {
		return Notation_Details{king_side_castle = true, from_x = 9, from_y = 9}, true
	}

	first_char := text[index]
	piece := General_Piece.Pawn

	if first_char == 'N' ||
	   first_char == 'B' ||
	   first_char == 'R' ||
	   first_char == 'Q' ||
	   first_char == 'K' {
		white_piece := get_piece_from_fen_piece(first_char)
		piece = get_general_piece_from_piece(white_piece)
		index += 1
	}

	from_x: u8 = 9
	from_y: u8 = 9
	capturing := false

	for index < len(text) {
		c := text[index]

		if c == 'x' {
			capturing = true
			index += 1
			continue
		}

		if c == '=' || c == '+' || c == '#' do break

		if index + 1 < len(text) {
			next_c := text[index + 1]
			if next_c >= '1' && next_c <= '8' {
				is_target := true
				for k := index + 2; k < len(text); k += 1 {
					rem := text[k]
					if (rem >= 'a' && rem <= 'h') || rem == 'x' {
						is_target = false
						break
					}
				}

				if is_target {
					break
				}
			}
		}

		if c >= 'a' && c <= 'h' {
			from_x = c - 'a'
		} else if c >= '1' && c <= '8' {
			from_y = c - '1'
		}
		index += 1
	}

	to: u64 = 0
	if index + 1 < len(text) {
		to = get_square_from_notation(text[index], text[index + 1])
		index += 2
	} else {
		return Notation_Details{}, false
	}

	if to == 0 do return Notation_Details{}, false

	promotion := General_Piece.None
	if index < len(text) && text[index] == '=' {
		index += 1
		if index < len(text) {
			white_piece := get_piece_from_fen_piece(text[index])
			if white_piece == Piece.None do white_piece = Piece.White_Pawn
			promotion = get_general_piece_from_piece(white_piece)
			index += 1
		} else {
			return Notation_Details{}, false
		}
	}

	check := false
	checkmate := false
	if index < len(text) {
		if text[index] == '+' do check = true
		if text[index] == '#' do checkmate = true
	}

	return Notation_Details {
			piece = piece,
			from_x = from_x,
			from_y = from_y,
			to = to,
			capturing = capturing,
			check = check,
			checkmate = checkmate,
			promotion = promotion,
			king_side_castle = false,
			queen_side_castle = false,
			winner = Piece_Color.None,
		},
		true
}

get_fen :: proc(board: ^Board, player: ^Piece_Color) -> string {
	characters: [dynamic]u8
	null_spaces: u8 = 0


	for y := 7; y >= 0; y -= 1 {
		for x in 0 ..< 8 {
			piece := get_piece(board, get_bitboard_square(x, y))
			if piece == Piece.None {
				null_spaces += 1
			} else {
				if null_spaces > 0 {
					append(&characters, 48 + null_spaces)
					null_spaces = 0
				}

				append(&characters, piece_to_fen_piece(piece))
			}
		}
		if null_spaces > 0 {
			append(&characters, 48 + null_spaces)
			null_spaces = 0
		}
		if y > 0 do append(&characters, '/')
	}

	append(&characters, ' ')
	append(&characters, (player^ == Piece_Color.White) ? 'w' : 'b')
	append(&characters, ' ')

	c_len := len(characters)

	if board.castling & WHITE_K_CASTLING_VALID == WHITE_K_CASTLING_VALID do append(&characters, 'K')
	if board.castling & WHITE_Q_CASTLING_VALID == WHITE_Q_CASTLING_VALID do append(&characters, 'Q')

	if board.castling & BLACK_K_CASTLING_VALID == BLACK_K_CASTLING_VALID do append(&characters, 'k')
	if board.castling & BLACK_Q_CASTLING_VALID == BLACK_Q_CASTLING_VALID do append(&characters, 'q')

	if c_len == len(characters) do append(&characters, '-')

	append(&characters, ' ')

	if board.enpassant == 0 do append(&characters, '-')
	else {
		y := 2
		x := bits.count_trailing_zeros(board.enpassant)
		if x >= 8 {
			x -= 8
			y = 5
		}
		n := square_to_notation(get_bitboard_square(cast(int)x, y))

		append(&characters, n[0])
		append(&characters, n[1])
	}

	append(&characters, ' ')

	append_int_to_array(&characters, cast(int)board.half_move_clock)

	append(&characters, ' ')

	append_int_to_array(&characters, max(cast(int)(board.full_move_clock / 2), 1))

	return string(characters[:])
}

append_int_to_array :: proc(arr: ^[dynamic]u8, num: int) {
	builder := strings.builder_from_slice(arr[:])
	builder.buf = arr^

	fmt.sbprintf(&builder, "%d", num)
	arr^ = builder.buf
}


get_pgn :: proc(board: ^Board, player: ^Piece_Color) -> string {
	return ""
}

load_pgn_from_path :: proc(board: ^Board, player: ^Piece_Color, path: string) -> bool {
	byte_data, ok := os.read_entire_file(strings.trim_space(path), context.allocator)
	if ok != nil {
		fmt.println(ok)
		return false
	}
	defer delete(byte_data, context.allocator)
	return load_pgn(board, player, strings.trim_space(string(byte_data)))
}

load_pgn :: proc(board: ^Board, player: ^Piece_Color, pgn: string) -> bool {
	index := 0

	for index < len(pgn) {
		if strings.is_space(cast(rune)pgn[index]) {
			index += 1
			continue
		}

		if pgn[index] == '[' {
			for index < len(pgn) && pgn[index] != ']' {
				index += 1
			}
			if index < len(pgn) do index += 1
			continue
		}

		if pgn[index] == '{' {
			for index < len(pgn) && pgn[index] != '}' {
				index += 1
			}
			if index < len(pgn) do index += 1
			continue
		}

		if pgn[index] == '(' {
			paren_depth := 1
			index += 1
			for index < len(pgn) && paren_depth > 0 {
				if pgn[index] == '(' do paren_depth += 1
				else if pgn[index] == ')' do paren_depth -= 1
				index += 1
			}
			continue
		}

		if pgn[index] == ')' || pgn[index] == '}' || pgn[index] == '.' || pgn[index] == ']' {
			index += 1
			continue
		}

		if pgn[index] == '$' {
			index += 1
			for index < len(pgn) && pgn[index] >= '0' && pgn[index] <= '9' {
				index += 1
			}
			continue
		}

		if pgn[index] >= '0' && pgn[index] <= '9' {
			is_move_number := false
			peek := index
			for peek < len(pgn) && pgn[peek] >= '0' && pgn[peek] <= '9' {
				peek += 1
			}

			if peek < len(pgn) && (pgn[peek] == '.' || pgn[peek] == '-') {
				is_move_number = true
			}

			if is_move_number {
				index = peek
				for index < len(pgn) && pgn[index] == '.' {
					index += 1
				}
				continue
			}
		}

		start_token := index
		for index < len(pgn) &&
		    !strings.is_space(cast(rune)pgn[index]) &&
		    pgn[index] != '[' &&
		    pgn[index] != '{' &&
		    pgn[index] != '(' &&
		    pgn[index] != '$' {
			index += 1
		}

		token := pgn[start_token:index]
		token = strings.trim_space(token)
		if len(token) == 0 do continue

		if token == "1-0" || token == "0-1" || token == "1/2-1/2" || token == "*" {
			break
		}

		details, parse_ok := get_algebraic_notation_move_details(token)
		if !parse_ok do return false

		move, process_ok := process_algebraic_move(board, player^, details)
		if !process_ok do return false

		force_move(board, move)

		player^ = (player^ == Piece_Color.White) ? Piece_Color.Black : Piece_Color.White
	}

	return true
}

ZOBRIST_PIECES: [12][64]u64
ZOBRIST_CASTLING: [16]u64
ZOBRIST_ENPASSANT: [8]u64
ZOBRIST_PLAYER: u64
ZOBRIST_INIT := false

init_zobrist :: proc() {
	if ZOBRIST_INIT do return
	rand.reset(67)

	for i in 0 ..< 12 {
		for j in 0 ..< 64 {
			ZOBRIST_PIECES[i][j] = rand.uint64()
		}
	}
	for i in 0 ..< 16 {
		ZOBRIST_CASTLING[i] = rand.uint64()
	}
	for i in 0 ..< 8 {
		ZOBRIST_ENPASSANT[i] = rand.uint64()
	}
	ZOBRIST_PLAYER = rand.uint64()
	ZOBRIST_INIT = true
}

get_zobrist :: proc(board: ^Board, player: ^Piece_Color) -> u64 {
	if !ZOBRIST_INIT do init_zobrist()

	hash: u64 = 0

	for sq in 0 ..< 64 {
		piece := get_piece(board, 1 << cast(u64)sq)
		if piece != Piece.None {
			hash ~= ZOBRIST_PIECES[int(piece)][sq]
		}
	}

	hash ~= ZOBRIST_CASTLING[board.castling & 0x0F]

	if board.enpassant != 0 {
		hash ~= ZOBRIST_ENPASSANT[bits.count_trailing_zeros(board.enpassant) % 8]
	}

	if player^ == Piece_Color.Black {
		hash ~= ZOBRIST_PLAYER
	}

	return hash
}

