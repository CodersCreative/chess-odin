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

load_pgn :: proc(board: ^Board, player: ^Piece_Color, path: string) -> bool {
	pgn2 := `[Event "Wch1"]
[Site "U.S.A."]
[Date "1886.??.??"]
[Round "9"]
[White "Zukertort, Johannes"]
[Black "Steinitz, Wilhelm"]
[Result "0-1"]
[ECO "D26h"]
[Annotator "JvR"]

1.d4 d5 2.c4 e6 3.Nc3 Nf6 4.Nf3 dxc4 5.e3 c5 6.Bxc4 cxd4 7.exd4 Be7 8.O-O
O-O 9.Qe2 Nbd7 {This knight wants to blockades on d5.} 10.Bb3 Nb6 11.Bf4
( 11.Re1 {keeps the initiative.} )
11...Nbd5 12.Bg3 Qa5 13.Rac1 Bd7 14.Ne5 Rfd8 15.Qf3 Be8 16.Rfe1 Rac8 17.
Bh4 {Intends 18.Nxd5 exd5.} 17...Nxc3 18.bxc3 Qc7 {Black pressures on the
hanging pawns.} 19.Qd3
( 19.Bg3 {!} 19...Bd6 20.c4 {(Lasker).} )
19...Nd5 20.Bxe7 Qxe7 21.Bxd5 {?!}
( 21.c4 Qg5 22.Rcd1 Nf4 23.Qg3 {steers towards a slight advantage in
the endgame.} )
21...Rxd5 22.c4 Rdd8 23.Re3 {The attack will fail.}
( 23.Rcd1 {is solid.} )
23...Qd6 24.Rd1 f6 25.Rh3 {!?} 25...h6 {!}
( 25...fxe5 26.Qxh7+ Kf8 27.Rg3 {!} 27...Rd7
( 27...Rc7 28.Qh8+ Ke7 29.Rxg7+ Bf7 30.Qh4+ {(Euwe)} )
28.Qh8+ Ke7 29.Qh4+ Kf7 30.Qh7 {} )
26.Ng4 Qf4 {!} 27.Ne3 Ba4 {!} 28.Rf3 Qd6 29.Rd2
( 29.Rxf6 {?} 29...Bxd1 {!} )
29...Bc6 {?}
( 29...b5 {!} 30.Qg6 {!?}
( 30.cxb5 Rc1+ 31.Nd1 Qxd4 32.Qxd4 Rxd4 33.Rxd4 Bxd1 $19 {
(Vukovic).} )
30...Qf8 31.Ng4 Rxc4 {!} 32.Nxh6+ Kh8 33.h3 gxh6 34.Rxf6 Qg7 {is good
for Black).} )
30.Rg3 {?}
( 30.d5 {!} 30...Qe5 {!}
( 30...exd5 {(Steinitz)} 31.Nf5 {(Euwe)} )
31.Qb1 {Forestalls ..b5 and protects the first rank.} 31...exd5 32.
cxd5 {} 32...Bxd5 {??} 33.Rf5 )
30...f5 {Threatens ..f4.} 31.Rg6 {!?}
( 31.Nd1 f4 32.Rh3 e5 {!} 33.d5 Bd7 $19 )
31...Be4 32.Qb3 Kh7`

	pgn := `
1. e4 d5 2. Nc3 d4 3. Nd5 Nf6 4. Nxf6+ exf6 5. Nf3 Nc6 6. Bd3 Ne5 7. Nxe5 fxe5
8. Bb5+ c6 9. Bc4 b5 10. Bb3 Be6 11. d3 Bb4+ 12. Bd2 a5 13. a3 Bxd2+ 14. Qxd2
O-O 15. O-O a4 16. Bxe6 fxe6 17. f3 c5 18. c3 c4 19. cxd4 Qxd4+ 20. Kh1 cxd3 21.
Rab1 Rac8 22. Rfd1 Rc2 23. Qxd3 Qf2 24. Qf1 Rxf3 25. Qxf2 Rfxf2 26. Rg1 Rce2 27.
Rbe1 Rxb2 28. Rb1 Rxg2 29. Rxb2 Rxb2 30. Rd1 b4 31. Rd8+ Kf7 32. Ra8 bxa3 33.
Rxa4 a2 34. Kg1 Kf6 35. Kf1 Rb1+ 36. Ke2 a1=Q 37. Rxa1 Rxa1 38. Ke3 Ra3+ 39. Kf2
Kg5 40. h3 Kf4 41. h4 Ra2+ 42. Ke1 Ke3 43. Kf1 Kf3 44. Ke1 Ke3 45. Kd1 Kd3 46.
Ke1 Re2+ 47. Kf1 Ke3 48. Kg1 Kf3 49. Kf1 Re3 50. Kg1 Kxe4 51. Kf2 Kf4 52. Kg2
Re2+`


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
		fmt.println(token)
		details, parse_ok := get_algebraic_notation_move_details(token)
		fmt.println(parse_ok)
		if !parse_ok do return false
		display_board(board)
		move, process_ok := process_algebraic_move(board, player^, details)

		fmt.println(process_ok)
		fmt.println(details)
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

