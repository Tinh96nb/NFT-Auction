// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTAA is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;

    mapping (uint256 => string) private idToUri;

    constructor() ERC721('BNUToken', 'BNU') {
    }

    function mint(address to, string memory dataUri) public returns (uint256) {
        tokenIds.increment();
        uint256 newItemId = tokenIds.current();
        _mint(to, newItemId);
        idToUri[newItemId] = dataUri;
        return newItemId;
    }

    function tokenUri(uint256 tokenId) public view returns (string memory) {
        return idToUri[tokenId]; 
    }
}