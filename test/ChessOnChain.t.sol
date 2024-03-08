// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/ChessOnChain.sol";
import "forge-std/Test.sol";

contract OnChainChessTest is Test {
    OnChainChess chess;
    address player1 = address(1);
    address player2 = address(2);

    function setUp() public {
        chess = new OnChainChess();
    }

    function testCreateGame() public {
        vm.prank(player1);
        uint256 gameId = chess.createGame(player2);

        (address whitePlayer, address blackPlayer, bool gameActive) = chess.getGameDetails(gameId);
        assertEq(whitePlayer, player1);
        assertEq(blackPlayer, player2);
        assertTrue(gameActive);
    }

    // Example utility function in test to mimic address calling
    function cheatCall(address caller, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory result) = address(chess).delegatecall(abi.encodePacked(data, caller));
        require(success);
        return result;
    }

    // Add more tests here...
}
