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

