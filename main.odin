package main

import "core:fmt"

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

square_occupied :: proc(bitboard: u64, square: u64) -> bool {
	return (bitboard & (1 << square)) != 0
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

display_board :: proc(board: ^Board) {
	for y in 0 ..< 8 {
		for x in 0 ..< 8 {
			fmt.printf("%s ", piece_to_str(get_piece(board, get_bitboard_square(x, y))))
		}
		fmt.print("\n")
	}
}

main :: proc() {
	board := DEFAULT_BOARD
	display_board(&board)
}

