// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract OnChainChess {
    struct Game {
        uint256 id;
        address whitePlayer;
        address blackPlayer;
        // Using the first 3 bits for the piece type (1-6), and the 4th bit for the color (0 for white, 1 for black)
        // e.g., 0x08 (1000) represents a black piece, and 0x00 (0000) represents a white piece.
        // This way, 0x01 represents a white Pawn, and 0x09 (1001) represents a black Pawn.
        uint8[8][8] board;
        bool whiteTurn;
        bool gameActive;
    }

    uint256 public gameIdCounter = 0;
    mapping(uint256 => Game) public games;

    event GameCreated(uint256 indexed gameId, address indexed whitePlayer, address indexed blackPlayer);
    event MoveMade(uint256 indexed gameId, address indexed player, uint8 fromX, uint8 fromY, uint8 toX, uint8 toY);
    event GameEnded(uint256 indexed gameId, address indexed winner);

    function createGame(address opponent) external returns (uint256 gameId) {
        require(opponent != msg.sender, "Cannot play against yourself");

        gameId = ++gameIdCounter;
        Game storage newGame = games[gameId];
        newGame.id = gameId;
        newGame.whitePlayer = msg.sender;
        newGame.blackPlayer = opponent;
        newGame.whiteTurn = true;
        newGame.gameActive = true;
        initializeBoard(newGame.board);

        emit GameCreated(gameId, msg.sender, opponent);
        return gameId;
    }

    function getGameDetails(uint256 gameId) public view returns (address whitePlayer, address blackPlayer, bool gameActive) {
        Game storage game = games[gameId];
        return (game.whitePlayer, game.blackPlayer, game.gameActive);
    }

    function makeMove(uint256 gameId, uint8 fromX, uint8 fromY, uint8 toX, uint8 toY) external {
        Game storage game = games[gameId];
        require(game.gameActive, "Game is not active");
        require(isPlayerTurn(game), "Not your turn");
        require(isValidMove(game, fromX, fromY, toX, toY), "Invalid move");

        // Execute move
        game.board[toY][toX] = game.board[fromY][fromX];
        game.board[fromY][fromX] = 0;
        game.whiteTurn = !game.whiteTurn; // Switch turns

        emit MoveMade(gameId, msg.sender, fromX, fromY, toX, toY);

        // Check for endgame conditions
        if (isCheckmate(game) || isStalemate(game)) {
            game.gameActive = false;
            address winner = game.whiteTurn ? game.blackPlayer : game.whitePlayer; // Last move was the winning move
            emit GameEnded(gameId, winner);
        }
    }

    function initializeBoard(uint8[8][8] storage board) internal {
        // Initialize pawns
        for (uint8 i = 0; i < 8; i++) {
            board[1][i] = 0x01; // White pawns
            board[6][i] = 0x09; // Black pawns (0x08 for black + 0x01 for Pawn)
        }

        // Initialize other pieces for white
        board[0][0] = board[0][7] = 0x04; // White rooks
        board[0][1] = board[0][6] = 0x02; // White knights
        board[0][2] = board[0][5] = 0x03; // White bishops
        board[0][3] = 0x05; // White queen
        board[0][4] = 0x06; // White king

        // Initialize other pieces for black (0x08 for black pieces)
        board[7][0] = board[7][7] = 0x0C; // Black rooks (0x08 for black + 0x04 for Rook)
        board[7][1] = board[7][6] = 0x0A; // Black knights (0x08 for black + 0x02 for Knight)
        board[7][2] = board[7][5] = 0x0B; // Black bishops (0x08 for black + 0x03 for Bishop)
        board[7][3] = 0x0D; // Black queen (0x08 for black + 0x05 for Queen)
        board[7][4] = 0x0E; // Black king (0x08 for black + 0x06 for King)
    }

    function isPlayerTurn(Game storage game) internal view returns (bool) {
        if (game.whiteTurn) {
            return msg.sender == game.whitePlayer;
        } else {
            return msg.sender == game.blackPlayer;
        }
    }

    function isValidMove(Game storage game, uint8 fromX, uint8 fromY, uint8 toX, uint8 toY) internal view returns (bool) {
        // Ensure the move is within the board
        if (fromX >= 8 || fromY >= 8 || toX >= 8 || toY >= 8) {
            return false;
        }

        // Ensure there is a piece at the from location
        uint8 piece = game.board[fromY][fromX];
        if (piece == 0) {
            return false;
        }

        // Determine piece color (0 for white, 1 for black)
        bool isPieceWhite = piece & 0x08 == 0;
        if (isPieceWhite != game.whiteTurn) {
            return false; // It's not this piece's turn
        }

        // Determine target square occupancy
        uint8 targetPiece = game.board[toY][toX];
        bool isTargetOccupied = targetPiece != 0;
        bool isTargetWhite = targetPiece & 0x08 == 0;
        if (isTargetOccupied && isPieceWhite == isTargetWhite) {
            return false; // Can't capture your own piece
        }

        // Remove the color bit to just work with piece types
        piece &= 0x07;
        targetPiece &= 0x07;

        // Movement validation for each piece type
        // Note: This does not account for blocking pieces in the path for some types

        // Pawn movement (already handled)

        // Knight movement (2x1 or 1x2 in any direction)
        if (piece == 2) { // Knight
            int8 dx = int8(toX) - int8(fromX);
            int8 dy = int8(toY) - int8(fromY);
            if (!((abs(dx) == 2 && abs(dy) == 1) || (abs(dx) == 1 && abs(dy) == 2))) {
                return false;
            }
            // Knights can jump over pieces, no need to check path
            return true;
        }

        // Bishop movement (diagonal)
        if (piece == 3) {
            if (!isDiagonalMove(fromX, fromY, toX, toY) || !isPathClear(game, fromX, fromY, toX, toY)) {
                return false;
            }
            return true;
        }

        // Rook movement (straight lines)
        if (piece == 4) {
            if (!isStraightMove(fromX, fromY, toX, toY) || !isPathClear(game, fromX, fromY, toX, toY)) {
                return false;
            }
            return true;
        }

        // Queen movement (straight lines or diagonal)
        if (piece == 5) {
            if (!(isStraightMove(fromX, fromY, toX, toY) || isDiagonalMove(fromX, fromY, toX, toY)) || !isPathClear(game, fromX, fromY, toX, toY)) {
                return false;
            }
            return true;
        }

        // King movement (one square in any direction)
        if (piece == 6) {
            int8 dx = int8(toX) - int8(fromX);
            int8 dy = int8(toY) - int8(fromY);
            if (abs(dx) > 1 || abs(dy) > 1) {
                return false;
            }
            return true;
        }

        // If none of the valid conditions are met, return false
        return false;
    }

    // Helper functions for movement checks
    function isDiagonalMove(uint8 fromX, uint8 fromY, uint8 toX, uint8 toY) internal pure returns (bool) {
        return abs(int8(toX) - int8(fromX)) == abs(int8(toY) - int8(fromY));
    }

    function isStraightMove(uint8 fromX, uint8 fromY, uint8 toX, uint8 toY) internal pure returns (bool) {
        return (fromX == toX) || (fromY == toY);
    }

    function isPathClear(Game storage game, uint8 fromX, uint8 fromY, uint8 toX, uint8 toY) internal pure returns (bool) {
        // Simplified path clearance check (to be implemented)
        // Should iterate over the squares between the from and to positions (exclusive)
        // and return false if any square is occupied.
        return true; // Placeholder: Implement actual path checking logic
    }

    // Helper function for absolute value of int8
    function abs(int8 x) internal pure returns (int8) {
        return x >= 0 ? x : -x;
    }

    function isCheckmate(Game storage game) internal view returns (bool) {
        // Stub: Implement checkmate logic
        return false;
    }

    function isStalemate(Game storage game) internal view returns (bool) {
        // Stub: Implement stalemate logic
        return false;
    }
}
