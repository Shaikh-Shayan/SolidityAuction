// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/**
 * @title Bidding
 * @dev Implements selling, buying, trading, and royalties feature.
 */
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './NFT1155.sol';
import './PersistentStorage.sol';
import './PersistentStorageForAuction.sol';

contract Auction is ReentrancyGuard, ERC1155Holder, Ownable {
  address private storageAddress;
  PersistentStorage _persistentStorage;

  address private auctionStorageAddress;
  PersistentStorageForAuction _auctionStorageAddress;

  address payable coinscouterOwnerAddress; // Storing the owner adress to whom transfer the royalties
  address payable nftArtistAddress; // Storing the Nft Creator/Artist address to whom transfer the royalties

  uint256 public coinscouterRoyaltiesPercent = 5; //Storing royalties percentage value of coinscouter Owner default 5 percentage of selling price of nft
  uint256 public artistRoyaltiesPercent = 5; //Storing royalties percentage value of nft Artist default 5 percentage of selling price of nft

  //Initializing Variables
  constructor(address _storageAddress, address _storageAddressAuction) {
    // Initializing the coinscouterOwnerAddress with the adress who deploy the contract
    coinscouterOwnerAddress = payable(msg.sender);
    storageAddress = address(_storageAddress);
    _persistentStorage = PersistentStorage(storageAddress);

    auctionStorageAddress = address(_storageAddressAuction);
    _auctionStorageAddress = PersistentStorageForAuction(auctionStorageAddress);
  }

  address payable public nftOwner;
  //uint256 public auctionEndTime;

  //current state of the auctionEndTime
  // address public _nftHighestBidder;
  // uint256 public _nftHighestBid;

  mapping(address => uint256) public pendingReturns;

  bool ended = false;

  event HighestBidIncrease(address bidder, uint256 amount);
  event AuctionEnded(address winner, uint256 amount);

  event auctionStartEvent(
    uint256 indexed nftId, //Unique id of Nft assign at the time of minting
    uint256 indexed auctionId, //nftSell Id [Id to uiquely identify nft on marketplace]
    uint256 indexed nftBasePrice, //Price decided by seller for nft [and this price is for single copy]/[per copy price]
    address nftSellerAddress, //Address of the wallet/Person who want to sell this nft
    address nftBuyerAddress, //Address of the wallet/Person who want to buy this nft
    uint256 nftTotalCopies, //Total number of Copies/supply available on market place for sell
    uint256 nftSellTimeStamp,
    address nftMintContractAddress, //Adress of smart contract where nft is minted
    address nftHighestBidder,
    uint256 nftHighestBid,
    uint256 auctionEndTime
  );

  event auctionBidEvent(
    uint256 indexed nftId,
    uint256 indexed auctionId,
    uint256 indexed nftBasePrice,
    uint256 bid,
    address bidder,
    uint256 time
  );

  event auctionEndEvent(
    uint256 indexed nftId, //Unique id of Nft assign at the time of minting
    uint256 indexed auctionId, //nftSell Id [Id to uiquely identify nft on marketplace]
    uint256 indexed buyId,
    address nftSellerAddress, //Address of the wallet/Person who want to sell this nft
    address nftBuyerAddress, //Address of the wallet/Person who want to buy this nft
    uint256 nftSellTimeStamp,
    address nftMintContractAddress //Adress of smart contract where nft is minted
  );

  //Put nft on Auction for sell
  function nftAuction(
    uint256 _nftId, //Unique id of Nft assign at the time of minting
    uint256 _nftPrice, //Price decided by seller for nft [and this price is for single copy]/[per copy price]
    uint256 _nftCopiesForSell, //Copies which put on available for sell on market place
    uint256 _auctionEndTime
  ) public payable nonReentrant {
    require(_nftCopiesForSell == 1, 'Only one copy can put on auction at a time');
    require(_nftPrice > 0, 'Price is too low'); //Check for the assign price it should be more than decided limit
    _persistentStorage.incrementSellId();
    uint256 _auctionId = _persistentStorage.fetchSellId();
    address _nftMintContractAddress = _persistentStorage
      .fetchNftMintDetail(_nftId)
      .nftMintContractAddress;
    address _nftArtistAddress; // Storing the Nft Creator/Artist address to whom transfer the royalties
    _nftArtistAddress = NFT1155(_nftMintContractAddress).fetchNftArtist(_nftId);
    _auctionEndTime = block.timestamp + _auctionEndTime;
    _auctionStorageAddress.setAuctionNftDetails(
      _nftId,
      _auctionId,
      _nftPrice,
      msg.sender,
      address(0),
      _nftCopiesForSell,
      block.timestamp,
      _nftMintContractAddress,
      address(0),
      0,
      _auctionEndTime 
    );

    //Transfering nft from owner wallet address to the marketPlace address
    IERC1155(_nftMintContractAddress).safeTransferFrom(
      msg.sender,
      storageAddress,
      _nftId,
      _nftCopiesForSell,
      '0xaa'
    );

    // Typecast the Artist address into payable address type
    nftArtistAddress = payable(_nftArtistAddress);
    //Log the sell event
    emit auctionStartEvent(
      _nftId,
      _auctionId,
      _nftPrice,
      msg.sender,
      address(0),
      _nftCopiesForSell,
      block.timestamp,
      _nftMintContractAddress,
      address(0),
      0,
      _auctionEndTime
    );
  }

  //Once nft is on auction, user can bid on that by calling nftBid() function
  function nftBid(uint256 _auctionId) public payable nonReentrant{
    uint256 _auctionEndTime = _auctionStorageAddress
      .fetchMarketplaceAuctionNftDetails(_auctionId)
      .auctionEndTime;
    uint256 _nftHighestBid = _auctionStorageAddress
      .fetchMarketplaceAuctionNftDetails(_auctionId)
      .nftHighestBid;
    address _nftHighestBidder = _auctionStorageAddress
      .fetchMarketplaceAuctionNftDetails(_auctionId)
      .nftHighestBidder;
    if (block.timestamp > _auctionEndTime) {
      revert('The Auction Has Already Ended');
    }

    if (msg.value <= _nftHighestBid) {
      revert('There is alredy a higher or equal bid');
    }

    if (_nftHighestBid != 0) {
      pendingReturns[_nftHighestBidder] += _nftHighestBid;
      payable(_nftHighestBidder).transfer(_nftHighestBid);
    }
    _auctionStorageAddress.updateNftBiddingDetail(_auctionId, payable(msg.sender), msg.value);

    // _nftHighestBidder = msg.sender;
    // _nftHighestBid = msg.value;
    emit HighestBidIncrease(msg.sender, msg.value);
  }


  //Once aution time ends so below function is executed.
  function nftAuctionEnd(uint256 _auctionId) public payable nonReentrant {
    address _nftSeller = _auctionStorageAddress.fetchMarketplaceAuctionNftDetails(_auctionId).nftSellerAddress;
    require(msg.sender == _nftSeller, 'Only seller can end the auction');
     uint256 _auctionEndTime = _auctionStorageAddress
      .fetchMarketplaceAuctionNftDetails(_auctionId)
      .auctionEndTime;
    if (block.timestamp < _auctionEndTime) {
      revert('The Auciton is not ended yet');
    }

    if (ended) {
      revert('The functions auctionEnded has alredy been called');
    }
    ended = true;
 //    highestBidder = msg.sender;
//     highestBid = msg.value;
//     emit HighestBidIncrease(msg.sender, msg.value);
    uint256 _nftPrice = _auctionStorageAddress.fetchMarketplaceAuctionNftDetails(_auctionId).nftHighestBid; //Calculating the total fees as per the copies want to buy
    uint256 _nftId = _auctionStorageAddress.fetchMarketplaceAuctionNftDetails(_auctionId).nftId;
    uint256 _nftCopiesForBuy = _auctionStorageAddress.fetchMarketplaceAuctionNftDetails(_auctionId).nftTotalCopies;
    address _nftMintContractAddress = _persistentStorage
      .fetchNftMintDetail(_nftId)
      .nftMintContractAddress;
    address _nftBuyer = _auctionStorageAddress.fetchMarketplaceAuctionNftDetails(_auctionId).nftHighestBidder;

    


    //Check/Validate that given price is must be equal to seller asking price
    require(
      _nftPrice > 0 ,
      'Please submit the asking price in order to complete the purchase'
    );
    //Transfer the royalties to coinscouterOwnerAddress
    payable(coinscouterOwnerAddress).transfer((_nftPrice * coinscouterRoyaltiesPercent) / 100);

    //Transfer the royalties to artist
    payable(nftArtistAddress).transfer((_nftPrice * artistRoyaltiesPercent) / 100);

    //After eiminating royalties Transfer the remaining price/value to seller
    _auctionStorageAddress.fetchMarketplaceAuctionNftDetails(_auctionId).nftSellerAddress.transfer(
      _nftPrice - ((_nftPrice * (coinscouterRoyaltiesPercent + artistRoyaltiesPercent)) / 100)
    );

    IERC1155(_nftMintContractAddress).setApprovalForAll(storageAddress, true);
    //Transfer the nft to the buyer
    IERC1155(_nftMintContractAddress).safeTransferFrom(
      storageAddress,
      _nftBuyer,
      _nftId,
      _nftCopiesForBuy,
      '0xaa'
    );
    _auctionStorageAddress.fetchMarketplaceAuctionNftDetails(_auctionId).nftHighestBidder = payable(_nftBuyer);

    //Updating remaining copies of this nft on market place
    // uint256 _nftRemainingCopiesAfterSell = _persistentStorage
    //   .fetchMarketplaceNftDetails(_sellId)
    //   .nftRemainingCopiesAfterSell - _nftCopiesForBuy;
    // _persistentStorage.updateMarketplaceNftDetails(_sellId, _nftRemainingCopiesAfterSell);

    uint256 _buyId = _persistentStorage.fetchTrackUserNft(_nftBuyer).counter + 1;

    //Creating entry for User struct
    _persistentStorage.setUserNftDetails(
      _nftId,
      _auctionId,
      _buyId,
      _nftCopiesForBuy,
      _nftCopiesForBuy,
      _nftPrice,
      _nftBuyer,
      block.timestamp
    );

    //Logs/emit buy Event
      emit auctionEndEvent(
      _nftId,
      _auctionId,
      _buyId,
      _nftSeller,
      _nftBuyer,
      block.timestamp,
      _nftMintContractAddress
    );
    //Inserting track data into the Counter Struct
    _persistentStorage.setTrackUserNftsCounter(
      _nftBuyer,
      _persistentStorage.fetchTrackUserNft(_nftBuyer).counter + 1
    );
    _persistentStorage.setTrackUserNftsKey(_nftBuyer, _buyId);
    _auctionStorageAddress.updateNftSoldStatus(_auctionId);

  }

  /**
   * @dev Function to fetch nfts which are avalable on marketplace for sell
   * This function will returns all the nfts which are on sell on market place
   */
  function fetchAuctionNfts() public view returns (uint256[] memory) {
    //PersistentStorageForAuction.auctionNftDetails
    uint256 _totalItemCount = _persistentStorage.fetchSellId();
    uint256 itemCount = 0;
    uint256 currentIndex = 0;

    for (uint256 i = 10000; i < _totalItemCount; i++) {
      if (_auctionStorageAddress.fetchMarketplaceAuctionNftDetails(i + 1).sold == false) {
        itemCount += 1;
      }
    }

    uint256[] memory nftsOnMarketPlace = new uint256[](itemCount);
    for (uint256 i = 10000; i < _totalItemCount; i++) {
      if (_auctionStorageAddress.fetchMarketplaceAuctionNftDetails(i + 1).sold == false) {
        uint256 currentId = i + 1;
        uint256 currentNft = _auctionStorageAddress.fetchMarketplaceAuctionNftDetails(currentId).auctionId;
        nftsOnMarketPlace[currentIndex] = currentNft;
        currentIndex += 1;
      }
    }
    return nftsOnMarketPlace;
  }
}





