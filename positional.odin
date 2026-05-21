package chess

import "core:math"
import "core:math/bits"

SCORE_ZERO_VALUE: f16 : 0x64

PAWN_START :: [8]u32 {
	0x64646464,
	0x96969696,
	0x6E6E7882,
	0x69696E7D,
	0x64646478,
	0x695F5A64,
	0x696E6E50,
	0x64646464,
}

PAWN_END :: [8]u32 {
	0x64646464,
	0xFFFFFFFF,
	0xB4B4B4B4,
	0x8C8C8C8C,
	0x78787878,
	0x6E6E6E6E,
	0x69696969,
	0x64646464,
}

KING_START :: [8]u32 {
	0x464C4C32,
	0x464C4C32,
	0x464C4C32,
	0x464C4C32,
	0x5046464C,
	0x5A505050,
	0x78786464,
	0x78826E64,
}

KING_END :: [8]u32 {
	0x32464646,
	0x465A6464,
	0x46647882,
	0x4664828C,
	0x4664828C,
	0x46647882,
	0x465A6464,
	0x32464646,
}

QUEEN_START :: [8]u32 {
	0x505A5A5E,
	0x5A646464,
	0x5A646969,
	0x5E646969,
	0x64646969,
	0x5A696969,
	0x5A646964,
	0x505A5A5E,
}

QUEEN_END :: [8]u32 {
	0x505A5A5E,
	0x5A646969,
	0x5A696E73,
	0x5E697378,
	0x5E697378,
	0x5A696E73,
	0x5A646969,
	0x505A5A5E,
}

ROOK_START :: [8]u32 {
	0x64646469,
	0x8C8C8C8C,
	0x5F646464,
	0x5F646464,
	0x5F646464,
	0x5F646464,
	0x696E6E6E,
	0x6464646E,
}

ROOK_END :: [8]u32 {
	0x14141414,
	0x2D2D2D2D,
	0x64646464,
	0x64646464,
	0x64646464,
	0x64646464,
	0x64646464,
	0x5A64646E,
}

BISHOP_START :: [8]u32 {
	0x505A5A5A,
	0x5A646464,
	0x5A64696E,
	0x5A69696E,
	0x5A646E6E,
	0x5A6E6E6E,
	0x5A696464,
	0x505A5A5A,	
}

BISHOP_END :: [8]u32 {
	0x505A5A5A,
	0x5A646969,
	0x5A696E6E,
	0x5A696E73,
	0x5A696E73,
	0x5A696E6E,
	0x5A646969,
	0x505A5A5A,
}

KNIGHT_START :: [8]u32 {
	0x003C4646,
	0x3C506464,
	0x46646E73,
	0x46697378,
	0x46647378,
	0x46696E73,
	0x3C506469,
	0x003C4646,
}

KNIGHT_END :: [8]u32 {
	0x323C4646,
	0x3C555F5F,
	0x465F6E73,
	0x4664737D,
	0x4664737D,
	0x465F6E73,
	0x3C555F64,
	0x323C4646,
}

END_MOVE_START :: 30

get_positional_score :: proc(piece: Piece, square: u64, full_move: u8) -> i16 {
	is_white := get_piece_color(piece) == Piece_Color.White

	switch piece {

	case Piece.White_Pawn, Piece.Black_Pawn:
		return get_positional_score_with_values(is_white, square, full_move, PAWN_START, PAWN_END)
	case Piece.White_King, Piece.Black_King:
		return get_positional_score_with_values(is_white, square, full_move, KING_START, KING_END)
	case Piece.White_Queen, Piece.Black_Queen:
		return get_positional_score_with_values(
			is_white,
			square,
			full_move,
			QUEEN_START,
			QUEEN_END,
		)
	case Piece.White_Rook, Piece.Black_Rook:
		return get_positional_score_with_values(is_white, square, full_move, ROOK_START, ROOK_END)
	case Piece.White_Bishop, Piece.Black_Bishop:
		return get_positional_score_with_values(
			is_white,
			square,
			full_move,
			BISHOP_START,
			BISHOP_END,
		)
	case Piece.White_Knight, Piece.Black_Knight:
		return get_positional_score_with_values(
			is_white,
			square,
			full_move,
			KNIGHT_START,
			KNIGHT_END,
		)
	case Piece.None:
		return 0
	}
	return 0
}

get_positional_score_with_values :: proc(
	is_white: bool,
	square: u64,
	full_move: u8,
	start: [8]u32,
	end: [8]u32,
) -> i16 {
	x, y := get_x_y_from_square(square)
	if x <= 3 do x = 3 - x
	else do x = x - 4

	if !is_white do y = 7 - y

	start_value: f16 = cast(f16)(start[y] >> cast(u32)(x * 8) & 0xFF) - SCORE_ZERO_VALUE
	end_value: f16 = cast(f16)(end[y] >> cast(u32)(x * 8) & 0xFF) - SCORE_ZERO_VALUE
	value := math.lerp(start_value, end_value, cast(f16)min(1, full_move / END_MOVE_START))

	return cast(i16)value
}

