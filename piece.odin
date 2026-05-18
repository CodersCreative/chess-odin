package chess

General_Piece :: enum {
	Pawn,
	King,
	Queen,
	Rook,
	Bishop,
	Knight,
	None,
}

Piece :: enum {
	White_Pawn,
	Black_Pawn,
	White_King,
	Black_King,
	White_Queen,
	Black_Queen,
	White_Rook,
	Black_Rook,
	White_Bishop,
	Black_Bishop,
	White_Knight,
	Black_Knight,
	None,
}

Piece_Color :: enum {
	Black,
	White,
	None,
}

invert_color :: proc(color: Piece_Color) -> Piece_Color {
	switch color {
	case Piece_Color.Black:
		return Piece_Color.White
	case Piece_Color.White:
		return Piece_Color.Black
	case Piece_Color.None:
		return Piece_Color.None
	}

	return Piece_Color.None
}

get_piece_color :: proc(piece: Piece) -> Piece_Color {
	switch piece {
	case Piece.White_Pawn,
	     Piece.White_King,
	     Piece.White_Queen,
	     Piece.White_Rook,
	     Piece.White_Bishop,
	     Piece.White_Knight:
		return Piece_Color.White
	case Piece.Black_Pawn,
	     Piece.Black_King,
	     Piece.Black_Queen,
	     Piece.Black_Rook,
	     Piece.Black_Bishop,
	     Piece.Black_Knight:
		return Piece_Color.Black
	case Piece.None:
		return Piece_Color.None
	}

	return Piece_Color.None
}

get_piece_from_fen_piece :: proc(piece: u8) -> Piece {
	switch piece {
	case 'P':
		return Piece.White_Pawn
	case 'p':
		return Piece.Black_Pawn
	case 'K':
		return Piece.White_King
	case 'k':
		return Piece.Black_King
	case 'Q':
		return Piece.White_Queen
	case 'q':
		return Piece.Black_Queen
	case 'R':
		return Piece.White_Rook
	case 'r':
		return Piece.Black_Rook
	case 'B':
		return Piece.White_Bishop
	case 'b':
		return Piece.Black_Bishop
	case 'N':
		return Piece.White_Knight
	case 'n':
		return Piece.Black_Knight
	}

	return Piece.None
}

piece_to_fen_piece :: proc(piece: Piece) -> u8 {
	switch piece {
	case Piece.White_Pawn:
		return 'P'
	case Piece.Black_Pawn:
		return 'p'
	case Piece.White_King:
		return 'K'
	case Piece.Black_King:
		return 'k'
	case Piece.White_Queen:
		return 'Q'
	case Piece.Black_Queen:
		return 'q'
	case Piece.White_Rook:
		return 'R'
	case Piece.Black_Rook:
		return 'r'
	case Piece.White_Bishop:
		return 'B'
	case Piece.Black_Bishop:
		return 'b'
	case Piece.White_Knight:
		return 'N'
	case Piece.Black_Knight:
		return 'n'
	case Piece.None:
		return ' '
	}

	return ' '
}

piece_to_str :: proc(piece: Piece) -> string {
	switch piece {
	case Piece.White_Pawn:
		return "wp"
	case Piece.Black_Pawn:
		return "bp"
	case Piece.White_King:
		return "wk"
	case Piece.Black_King:
		return "bk"
	case Piece.White_Queen:
		return "wq"
	case Piece.Black_Queen:
		return "bq"
	case Piece.White_Rook:
		return "wr"
	case Piece.Black_Rook:
		return "br"
	case Piece.White_Bishop:
		return "wb"
	case Piece.Black_Bishop:
		return "bb"
	case Piece.White_Knight:
		return "wn"
	case Piece.Black_Knight:
		return "bn"
	case Piece.None:
		return "  "
	}

	return "  "
}


get_general_piece_from_piece :: proc(piece: Piece) -> General_Piece {
	switch piece {
	case Piece.White_Pawn, Piece.Black_Pawn:
		return General_Piece.Pawn
	case Piece.White_King, Piece.Black_King:
		return General_Piece.King
	case Piece.White_Queen, Piece.Black_Queen:
		return General_Piece.Queen
	case Piece.White_Rook, Piece.Black_Rook:
		return General_Piece.Rook
	case Piece.White_Bishop, Piece.Black_Bishop:
		return General_Piece.Bishop
	case Piece.White_Knight, Piece.Black_Knight:
		return General_Piece.Knight
	case Piece.None:
		return General_Piece.None
	}

	return General_Piece.None
}

