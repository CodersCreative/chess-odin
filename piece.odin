package chess

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

