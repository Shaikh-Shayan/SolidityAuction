// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title NFT1155
 * @dev Implements minting process with ERC1155 standard along with minting fees.
 */
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';

contract PersistentStorageForAuction is ERC1155Holder, Ownable {
  address private nftMarketplaceContractAddress;
  address private nftMintContractAddress;
  address private nftAuctionContractAddress;

  function setValidatorForNftAuctionContractAddress(address _nftAuctionContractAddress)
    public
    onlyOwner
  {
    nftAuctionContractAddress = _nftAuctionContractAddress;
  }

  struct auctionNftDetails {
    uint256 nftId; //Unique id of Nft assign at the time of minting
    uint256 auctionId; //nftSell Id [Id to uiquely identify nft on marketplace]
    uint256 nftBasePrice; //Price decided by seller for nft [and this price is for single copy]/[per copy price]
    address payable nftSellerAddress; //Address of the wallet/Person who want to sell this nft
    address payable  nftBuyerAddress; //Address of the wallet/Person who want to buy this nft
    uint256 nftTotalCopies; //Total number of Copies/supply available on market place for sell
    uint256 nftSellTimeStamp;
    address nftMintContractAddress; //Adress of smart contract where nft is minted
    address payable nftHighestBidder;
    uint256 nftHighestBid;
    uint256 auctionEndTime;
    bool sold;
  }

  struct nftBidHistoryData{
    address bidder;
    uint256 bid;
  }


  mapping(uint256 => auctionNftDetails) public nftDetailsFromSellId;
  mapping(uint256 => nftBidHistoryData[]) public nftBidHistory;

  function fetchMarketplaceAuctionNftDetails(uint256 _auctionId)
    public
    view
    returns (auctionNftDetails memory)
  {
require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );    return nftDetailsFromSellId[_auctionId];
  }

  function fetchNftBidHistoryData(uint256 _auctionId)
    public
    view
    returns (nftBidHistoryData[] memory)
  {
    //require(msg.sender == nftMintContractAddress || msg.sender == nftMarketplaceContractAddress || msg.sender == nftAuctionContractAddress, "You Dont Have Access Permission");
    return nftBidHistory[_auctionId];
  }
  // /**
  //  * @dev Function to put nft for sell on market place
  //  * This function will transfer the nft from owners address to this address
  //  * Assign an unique sell id to the nft
  //  * Create an entry of the nft detail in nftForSell struct with key as a sell id.
  //  * Typecast the artist address into payable address
  //  * If resell happening than update the nft copies own by buyer and set the state of boolean value
  //  */
  function setAuctionNftDetails(
    uint256 _nftId, //Unique id of Nft assign at the time of minting
    uint256 _auctionId, //nftSell Id [Id to uiquely identify nft on marketplace]
    uint256 _nftBasePrice, //Price decided by seller for nft [and this price is for single copy]/[per copy price]
    address _nftSellerAddress, //Address of the wallet/Person who want to sell this nft
    address _nftBuyerAddress, //Address of the wallet/Person who want to buy this nft
    uint256 _nftTotalCopies, //Total number of Copies/supply available on market place for sell
    uint256 _nftSellTimeStamp,
    address _nftMintContractAddress, //Adress of smart contract where nft is minted
    address _nftHighestBidder,
    uint256 _nftHighestBid,
    uint256 _auctionEndTime
  ) external {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );

    nftDetailsFromSellId[_auctionId] = auctionNftDetails(
      _nftId,
      _auctionId,
      _nftBasePrice,
      payable(_nftSellerAddress),
      payable(_nftBuyerAddress),
      _nftTotalCopies,
      _nftSellTimeStamp,
      _nftMintContractAddress,
      payable(_nftHighestBidder),
      _nftHighestBid,
      _auctionEndTime,
      false
    );

    nftBidHistory[_auctionId].push(nftBidHistoryData(
      _nftHighestBidder,
      _nftHighestBid
    ));
  }

  function updateNftBiddingDetail(
    uint256 _auctionId,
    address payable _nftHighestBidder,
    uint256 _nftHighestBid
  ) public {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    nftDetailsFromSellId[_auctionId].nftHighestBidder = payable(_nftHighestBidder);
    nftDetailsFromSellId[_auctionId].nftHighestBid = _nftHighestBid;
  }

  function updateNftSoldStatus(
    uint256 _auctionId
  ) public {
   require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    nftDetailsFromSellId[_auctionId].sold = true;
  }
}
