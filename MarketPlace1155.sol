// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

/**
 * @title MarketPlace1155
 * @dev Implements selling, buying, trading, and royalties feature.
 */
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './NFT1155.sol';
import './PersistentStorage.sol';

contract MarketPlace1155 is ReentrancyGuard, ERC1155Holder, Ownable {
  address private storageAddress;
  PersistentStorage _persistentStorage;

  // function setStorage(address _storageAddress) public {
  //   storageAddress = address(_storageAddress);
  //   _persistentStorage = PersistentStorage(storageAddress);
  // }

  address payable coinscouterOwnerAddress; // Storing the owner adress to whom transfer the royalties
  address payable nftArtistAddress; // Storing the Nft Creator/Artist address to whom transfer the royalties

  uint256 public coinscouterRoyaltiesPercent = 5; //Storing royalties percentage value of coinscouter Owner default 5 percentage of selling price of nft
  uint256 public artistRoyaltiesPercent = 5; //Storing royalties percentage value of nft Artist default 5 percentage of selling price of nft

  constructor(address _storageAddress) {
    // Initializing the coinscouterOwnerAddress with the adress who deploy the contract
    coinscouterOwnerAddress = payable(msg.sender);

    storageAddress = address(_storageAddress);
    _persistentStorage = PersistentStorage(storageAddress);
  }

  //Event to log sell
  // event MarketItemCreated(
  //   uint256 indexed sellId, //nftSell Id [Id to uiquely identify nft on marketplace]
  //   address indexed nftMintContractAddress, //Adress of smart contract where nft is minted
  //   uint256 indexed nftId, //Unique id of Nft assign at the time of minting
  //   address nftSellerAddress, //Address of the wallet/Person who want to sell this nft
  //   address nftBuyerAddress, //Address of the wallet/Person who want to buy this nft
  //   uint256 nftTotalCopies, //Total number of Copies/supply available on market place for sell
  //   uint256 nftPrice, //Price decided by seller for nft [and this price is for single copy]/[per copy price]
  //   bool sold //Boolean value to track that all copies of nft is sold out or not.
  // );

  event sellEvent(
    uint256 indexed nftId, //Unique id of Nft assign at the time of minting
    uint256 indexed sellId, //nftSell Id [Id to uiquely identify nft on marketplace]
    uint256 indexed nftPrice, //Price decided by seller for nft [and this price is for single copy]/[per copy price]
    address nftSellerAddress, //Address of the wallet/Person who want to sell this nft
    address nftBuyerAddress, //Address of the wallet/Person who want to buy this nft
    uint256 nftTotalCopies, //Total number of Copies/supply available on market place for sell
    uint256 nftSellTimeStamp,
    address nftMintContractAddress //Adress of smart contract where nft is minted
  );

  event buyEvent(
    uint256 indexed nftId, //Unique id of Nft assign at the time of minting
    uint256 indexed sellId, //nftSell Id [Id to uiquely identify nft on marketplace]
    uint256 indexed buyId, //nftSell Id [Id to uiquely identify nft on marketplace]
    uint256 nftPrice, //Price decided by seller for nft [and this price is for single copy]/[per copy price]
    address nftSellerAddress, //Address of the wallet/Person who want to sell this nft
    address nftBuyerAddress, //Address of the wallet/Person who want to buy this nft
    uint256 nftCopiesBuy, //Total number of Copies/supply available on market place for sell
    uint256 nftBuyTimeStamp,
    address nftMintContractAddress //Adress of smart contract where nft is minted
  );

  /**
   * @dev Function to put nft for sell on market place
   * This function will transfer the nft from owners address to this storage address
   * Assign an unique sell id to the nft
   * Create an entry of the nft detail in nftForSell struct with key as a sell id.
   * Typecast the artist address into payable address
   * If resell happening than update the nft copies own by buyer and set the state of boolean value
   */
  function sellNft(
    uint256 _nftId, //Unique id of Nft assign at the time of minting
    uint256 _nftPrice, //Price decided by seller for nft [and this price is for single copy]/[per copy price]
    uint256 _nftCopiesForSell, //Copies which put on available for sell on market place
    uint256 _nftPreviousBuyId //If its resell than previous buyId else 0
  ) public payable nonReentrant {
    require(_nftPrice > 0, 'Price is too low'); //Check for the assign price it should be more than decided limit
    //Generatig new sell Id
    _persistentStorage.incrementSellId();
    uint256 _sellId = _persistentStorage.fetchSellId();
    address _nftMintContractAddress = _persistentStorage
      .fetchNftMintDetail(_nftId)
      .nftMintContractAddress;
    address _nftArtistAddress; // Storing the Nft Creator/Artist address to whom transfer the royalties
    _nftArtistAddress = NFT1155(_nftMintContractAddress).fetchNftArtist(_nftId);
    //Creating entry into the nftDetailsFromSellId Struct
    _persistentStorage.setMarketplaceNftDetails(
      _nftId,
      _sellId,
      _nftPrice,
      _nftCopiesForSell,
      _nftCopiesForSell,
      _nftMintContractAddress,
      payable(msg.sender),
      payable(address(0)),
      block.timestamp
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

    //Updating mycreated values.
    if (_nftPreviousBuyId == 0) {
      if (_persistentStorage.fetchNftMintDetail(_nftId).nftRemainingCopies <= 0) {
        revert('Insufficient Balance');
      }
      if (_persistentStorage.fetchNftMintDetail(_nftId).nftRemainingCopies > 0) {
        uint256 _nftRemainingCopies = _persistentStorage
          .fetchNftMintDetail(_nftId)
          .nftRemainingCopies - _nftCopiesForSell;
        _persistentStorage.updateNftMintDetail(_nftId, _nftRemainingCopies);
      }
    }
    //Check if its resell or not.
    if (_nftPreviousBuyId > 0) {
      //Updating copiesBuy from User struct and set the new values after selling that
      uint256 nftRemainingCopiesAfterReSell = _persistentStorage
        .fetchUserNftDetails(msg.sender, _nftPreviousBuyId)
        .nftRemainingCopiesAfterReSell - _nftCopiesForSell;
      _persistentStorage.updateUserNftDetails(
        msg.sender,
        _nftPreviousBuyId,
        nftRemainingCopiesAfterReSell
      );
    }

    //Log the sell event
    emit sellEvent(
      _nftId,
      _sellId,
      _nftPrice,
      msg.sender,
      address(0),
      _nftCopiesForSell,
      block.timestamp,
      _nftMintContractAddress
    );
  }

  /**
   * @dev Function to buy nft for market place
   * This function will transfer the nft from market place address to the owner address
   * Assign an unique buy id to the nft
   * Create an entry of the nft detail in User struct with key as a buyer address.
   * Typecast the artist address into payable address
   * Calculate the fees of nft with respect to the number of copies they buy.
   * Validate that gives fees is equal to the asking fees. No less no more.
   * Royalties transfer [It will transfer Royalties to nft artist and coinscouter owner(by default it will transfer 5 percent)]
   * Transfer the price/value to the nft seller
   * Transfer the nft ownership to the buyer
   * If resell happening than update the nft copies own by buyer and set the state of boolean value
   */
  function buyNft(
    uint256 _sellId, //nftSell Id [Id to uiquely identify nft on marketplace]
    uint256 _nftCopiesForBuy //Copies which user want to buy from market place
  ) public payable nonReentrant {
    uint256 _nftPrice = _persistentStorage.fetchMarketplaceNftDetails(_sellId).nftPrice *
      _nftCopiesForBuy; //Calculating the total fees as per the copies want to buy
    uint256 _nftId = _persistentStorage.fetchMarketplaceNftDetails(_sellId).nftId;
    address _nftMintContractAddress = _persistentStorage
      .fetchNftMintDetail(_nftId)
      .nftMintContractAddress;

    //Check/Validate that given price is must be equal to seller asking price
    require(
      msg.value == _nftPrice,
      'Please submit the asking price in order to complete the purchase'
    );
    //Transfer the royalties to coinscouterOwnerAddress
    payable(coinscouterOwnerAddress).transfer((msg.value * coinscouterRoyaltiesPercent) / 100);

    //Transfer the royalties to artist
    payable(nftArtistAddress).transfer((msg.value * artistRoyaltiesPercent) / 100);

    //After eiminating royalties Transfer the remaining price/value to seller
    _persistentStorage.fetchMarketplaceNftDetails(_sellId).nftSellerAddress.transfer(
      msg.value - ((msg.value * (coinscouterRoyaltiesPercent + artistRoyaltiesPercent)) / 100)
    );

    IERC1155(_nftMintContractAddress).setApprovalForAll(storageAddress, true);
    //Transfer the nft to the buyer
    IERC1155(_nftMintContractAddress).safeTransferFrom(
      storageAddress,
      msg.sender,
      _nftId,
      _nftCopiesForBuy,
      '0xaa'
    );
    _persistentStorage.fetchMarketplaceNftDetails(_sellId).nftBuyerAddress = payable(msg.sender);

    //Updating remaining copies of this nft on market place
    uint256 _nftRemainingCopiesAfterSell = _persistentStorage
      .fetchMarketplaceNftDetails(_sellId)
      .nftRemainingCopiesAfterSell - _nftCopiesForBuy;
    _persistentStorage.updateMarketplaceNftDetails(_sellId, _nftRemainingCopiesAfterSell);

    uint256 _buyId = _persistentStorage.fetchTrackUserNft(msg.sender).counter + 1;

    //Creating entry for User struct
    _persistentStorage.setUserNftDetails(
      _nftId,
      _sellId,
      _buyId,
      _nftCopiesForBuy,
      _nftCopiesForBuy,
      _nftPrice,
      msg.sender,
      block.timestamp
    );

    //Logs/emit buy Event
    emit buyEvent(
      _nftId,
      _sellId,
      _buyId,
      _nftPrice,
      msg.sender,
      address(0),
      _nftCopiesForBuy,
      block.timestamp,
      _nftMintContractAddress
    );
    //Inserting track data into the Counter Struct
    _persistentStorage.setTrackUserNftsCounter(
      msg.sender,
      _persistentStorage.fetchTrackUserNft(msg.sender).counter + 1
    );
    _persistentStorage.setTrackUserNftsKey(msg.sender, _buyId);
  }

  /**
   * @dev Function to fetch nfts which are avalable on marketplace for sell
   * This function will returns all the nfts which are on sell on market place
   */
  function fetchMarketNfts() public view returns (uint256[] memory) {
    uint256 _totalItemCount = _persistentStorage.fetchSellId();
    uint256 itemCount = 0;
    uint256 currentIndex = 0;

    for (uint256 i = 10000; i < _totalItemCount; i++) {
      if (_persistentStorage.fetchMarketplaceNftDetails(i + 1).nftRemainingCopiesAfterSell > 0) {
        itemCount += 1;
      }
    }

    uint256[] memory nftsOnMarketPlace = new uint256[](itemCount);
    for (uint256 i = 10000; i < _totalItemCount; i++) {
      if (_persistentStorage.fetchMarketplaceNftDetails(i + 1).nftRemainingCopiesAfterSell > 0) {
        uint256 currentId = i + 1;
        uint256 currentNft = _persistentStorage.fetchMarketplaceNftDetails(currentId).sellId;
        nftsOnMarketPlace[currentIndex] = currentNft;
        currentIndex += 1;
      }
    }
    return nftsOnMarketPlace;
  }

  /**
   * @dev Function to fetch nfts which are own by the specific address
   * This function will returns all the nfts buyId which are on own by the caller address of this function
   */
  function fetchMyNFTs() public view returns (uint256[] memory) {
    uint256 totalItemCount = _persistentStorage.fetchTrackUserNft(msg.sender).counter;
    uint256[] memory itemsOwn = new uint256[](totalItemCount);

    uint256 counter = 0;
    uint256 currentIndex = 0;

    itemsOwn = _persistentStorage.fetchTrackUserNft(msg.sender).key;
    for (uint256 i = 0; i < totalItemCount; i++) {
      if (
        _persistentStorage
          .fetchUserNftDetails(msg.sender, itemsOwn[i])
          .nftRemainingCopiesAfterReSell > 0
      ) {
        counter = counter + 1;
      }
    }
    uint256[] memory buyId = new uint256[](counter);
    for (uint256 i = 0; i < totalItemCount; i++) {
      if (
        _persistentStorage
          .fetchUserNftDetails(msg.sender, itemsOwn[i])
          .nftRemainingCopiesAfterReSell > 0
      ) {
        uint256 currentBuyId = _persistentStorage
          .fetchUserNftDetails(msg.sender, itemsOwn[i])
          .buyId;
        buyId[currentIndex] = currentBuyId;
        currentIndex += 1;
      }
    }

    return buyId;
  }

  /**
   * @dev Function to update thee coinscouter owner Royalties Percentage input in whole number
   * Only update by the owner.
   */
  function setCoinscouterPercent(uint256 _coinscouterRoyaltiesPercent) public onlyOwner {
    coinscouterRoyaltiesPercent = _coinscouterRoyaltiesPercent;
  }

  /**
   * @dev Function to update thee nft artist Royalties Percentage input in whole number
   * Only update by the owner.
   */
  function setArtistPercent(uint256 _artistRoyaltiesPercent) public onlyOwner {
    artistRoyaltiesPercent = _artistRoyaltiesPercent;
  }
}
