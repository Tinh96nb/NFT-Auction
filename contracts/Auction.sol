// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AuctionNFT {
    address private owner;

    // mapping from symbol to contract address erc
    mapping(string => address) symbolContractToAdress;

    // mapping from symbol to address ern fee
    mapping(string => address) symbolToAddressEarn;

    // status Auction
    enum StatusAuction {NONE, PENDDING, ACEPTED} // 0,1,2
    struct Auction {
        uint128 id;
        address seller;
        uint256 tokenId;
        uint256 startingBid;
        uint256 highestBid;
        address highestBidder; 
        uint128 startTime;
        uint128 duration;
        string typeCoin;
        StatusAuction status;
    }

    ERC721 public NFTContract;
    ERC20 public ICOContract;

    uint128 public auctionId;
    // maping from token id to auction
    mapping (uint256 => Auction) internal tokenIdToAuction;

    // tokenid => adress => amount
    mapping (uint256 => mapping (address => uint)) tokenIdToBids;

    // config for fee ratio
    uint8 ratioFee;

    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address _NFTAddress) {
        NFTContract = ERC721(_NFTAddress);
        owner = msg.sender;
    }

    function createAuction(uint256 _tokenId, uint256 _startingBid) public returns (bool) {
        require(NFTContract.ownerOf(_tokenId) != address(0));
        require(NFTContract.ownerOf(_tokenId) == msg.sender);
        Auction storage auctionCurrent = tokenIdToAuction[_tokenId];
        // validate 1 auction for 1 token on one time
        if (auctionCurrent.id != 0 && auctionCurrent.status != StatusAuction.NONE) {
            return false;
        }
        Auction memory auction =
            Auction(
                uint128(auctionId),
                msg.sender,
                uint256(_tokenId),
                uint256(_startingBid),
                uint256(_startingBid),
                msg.sender,
                uint128(0),
                uint128(0),
                string(''),
                StatusAuction.PENDDING
            );

        tokenIdToAuction[_tokenId] = auction;
        // authorize approve token for contract
        NFTContract.approve(address(this), _tokenId);
        auctionId++;
        return true;
    }

    // creater auction setting option for auction to start auction
    function setOptionAuction(uint256 _tokenId, uint128 _startTime, string memory _symbolCoin) public
    {
        Auction storage auction = tokenIdToAuction[_tokenId];
        // validate status of auction
        require(auction.status == StatusAuction.ACEPTED);
        require(auction.seller == msg.sender);
        // already config address contract erc20 for this type coin
        require(symbolContractToAdress[_symbolCoin] != address(0));

        auction.startTime = _startTime;
        auction.typeCoin = _symbolCoin;
    }

    // owner approve 1 auction after user create auction
    function approveAuction(uint256 _tokenId) public isOwner() {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(auction.status == StatusAuction.PENDDING);
        // current time must be bigger start time
        require(block.timestamp > auction.startTime);
        auction.status = StatusAuction.ACEPTED;
    }

    // 
    function bid(uint256 _tokenId, uint256 _bidPrice) public returns (bool) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(auction.status == StatusAuction.ACEPTED);
        // still on time range bib
        require(block.timestamp >= auction.startTime && block.timestamp <= (auction.startTime + auction.duration));
        require(_bidPrice > auction.highestBid);

        // get contract of type coin
        address addressContract = symbolContractToAdress[auction.typeCoin];
        // transfer coin to this contract 
        if (!paymentToContract(addressContract, _bidPrice)) {
            return false;
        }
        if (auction.highestBid != 0) {
            // save amount coin of current bidder
            tokenIdToBids[_tokenId][auction.highestBidder] += auction.highestBid;
        }
        // set new bidder
        auction.highestBid = _bidPrice;
        auction.highestBidder = msg.sender;
        return true;
    }

    // transfer coin from sender to this contract
    function paymentToContract(address addressContract, uint256 amount) private returns (bool) {
        require(addressContract != address(0));
        require(amount > 0);
        ICOContract = ERC20(addressContract);
        // approve amount coin for this contract
        ICOContract.approve(address(this), amount);
        return ICOContract.transferFrom(msg.sender, address(this), amount);
    }

    // when someone bid higher, bid can be withdraw coin
    function withdraw(uint256 _tokenId) public returns (bool) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        uint amount = tokenIdToBids[_tokenId][msg.sender];
        if (amount > 0) {
            tokenIdToBids[_tokenId][msg.sender] = 0;
            address addressContract = symbolContractToAdress[auction.typeCoin];
            if (!withdrawFromContract(addressContract, amount)) {
                tokenIdToBids[_tokenId][msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    function withdrawFromContract(address addressContract, uint256 amount) private returns (bool) {
        require(addressContract != address(0));
        require(amount > 0);
        ICOContract = ERC20(addressContract);
        return ICOContract.transfer(msg.sender, amount);
    }

    function endAuction(uint256 _tokenId) public {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(msg.sender == auction.seller);
        // ending time to auction
        require(block.timestamp > auction.startTime + auction.duration);

        if (auction.highestBid > 0) {
            uint256 fee = auction.highestBid * ratioFee / 100;
            uint256 restAmount = auction.highestBid - fee;
            // get address contract
            address addressContract = symbolContractToAdress[auction.typeCoin];
            // send coin for seller
            withdrawFromContract(addressContract, restAmount);
        }
        // transer nft token for win bidder
        NFTContract.transferFrom(address(this), auction.highestBidder, _tokenId);
        // set status auction to default
        auction.status = StatusAuction.NONE;
    }

    // set address wallet ern fee each auction success
    function setAddressEarn(string memory _symbol, address addressErn) public isOwner() {
        symbolToAddressEarn[_symbol] = addressErn;
    }

    function setRatioFee(uint8 _ratio) public isOwner() {
        ratioFee = _ratio;
    }

    // set address for contract when auction call type coin
    function settingAddressContract(string memory _symbol, address addressContract) public isOwner() {
        symbolContractToAdress[_symbol] = addressContract;
    }

}