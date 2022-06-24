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

contract PersistentStorage is ERC1155Holder, Ownable {
  uint256 private nftId = 10000;
  uint256 private sellId = 10000;
  //using Counters for Counters.Counter; //Counter utility from openzeppelin
  //Counters.Counter public nftId; // tokenIds as an primary key for nfts
  //Counters.Counter public sellId; //Unique Id for every nft which put on sell on marketplace
  // Counters.Counter public itemsSold; //Storing status of nft if true then all are sold.
  address private nftMarketplaceContractAddress;
  address private nftMintContractAddress;
  address private nftAuctionContractAddress;

  function setApproveMarketPlace(address _nftMintContractAddress, address _nftMarketplaceAddress)
    public
    onlyOwner
  {
    IERC1155(_nftMintContractAddress).setApprovalForAll(_nftMarketplaceAddress, true);
  }

  //Set Authenticate Contract Address
  function setValidatorForNftMintContractAddress(address _nftMintContractAddress) public onlyOwner {
    nftMintContractAddress = _nftMintContractAddress;
  }

  //Set Authenticate Contract Address
  function setValidatorForNftMarketplaceContractAddress(address _nftMarketplaceContractAddress)
    public
    onlyOwner
  {
    nftMarketplaceContractAddress = _nftMarketplaceContractAddress;
  }

  //Set Authenticate Contract Address
  function setValidatorForNftAuctionContractAddress(address _nftAuctionContractAddress)
    public
    onlyOwner
  {
    nftAuctionContractAddress = _nftAuctionContractAddress;
  }

  //Mint contract storages
  //Storing details of nft which minted
  struct nftMintDetails {
    uint256 nftId;
    uint256 nftTotalCopies;
    uint256 nftRemainingCopies;
    address nftArtist;
    address nftMintContractAddress;
    string nftMetadataUri;
    uint256 nftMintTimeStamp;
  }

  //Maps id to minted nfts
  mapping(uint256 => nftMintDetails) private idToMintednft;

  //Set the mint
  function setNftMintDetails(
    uint256 _nftId,
    uint256 _nftTotalCopies,
    uint256 _nftRemainingCopies,
    address _nftArtist,
    address _nftMintContractAddress,
    string memory _nftMetadataUri,
    uint256 _nftMintTimeStamp
  ) external {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    idToMintednft[_nftId] = nftMintDetails(
      _nftId,
      _nftTotalCopies,
      _nftRemainingCopies,
      _nftArtist,
      _nftMintContractAddress,
      _nftMetadataUri,
      _nftMintTimeStamp
    );
  }

  function fetchNftMintDetail(uint256 _nftId) public view returns (nftMintDetails memory) {
    //require(msg.sender == nftMintContractAddress || msg.sender == nftMarketplaceContractAddress || msg.sender == nftAuctionContractAddress, "You Dont Have Access Permission");
    return idToMintednft[_nftId];
  }

  function updateNftMintDetail(uint256 _nftId, uint256 _copies) public {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    idToMintednft[_nftId].nftRemainingCopies = _copies;
  }

  function fetchNftId() public view returns (uint256) {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    return nftId;
    //return nftId.current();
  }

  function incrementNftId() public {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    nftId += 1;
    //nftId.increment();
  }

  /**
   * @dev Struct for storing nft data which available on marketPlace for sell.
   * Called when user put any nft on sell
   * On every resell/trade nftRemainingCopiesAfterSell will be updated
   * Seller Adress is always remain same but the track of buyers can be manage by user struct for specific sellId
   */
  struct marketplaceNftDetails {
    uint256 nftId;
    uint256 sellId;
    uint256 nftPrice;
    uint256 nftTotalCopiesForSell;
    uint256 nftRemainingCopiesAfterSell;
    address nftMintContractAddress;
    address payable nftSellerAddress;
    address payable nftBuyerAddress;
    uint256 nftSellTimeStamp;
  }

  //Mapping of sellId to nft details[This mapping will return entire details of nft from sell Id]
  mapping(uint256 => marketplaceNftDetails) private nftDetailsFromSellId;

  /**
   * @dev Function to put nft for sell on market place
   * This function will transfer the nft from owners address to this address
   * Assign an unique sell id to the nft
   * Create an entry of the nft detail in nftForSell struct with key as a sell id.
   * Typecast the artist address into payable address
   * If resell happening than update the nft copies own by buyer and set the state of boolean value
   */
  function setMarketplaceNftDetails(
    uint256 _nftId,
    uint256 _sellId,
    uint256 _nftPrice,
    uint256 _nftTotalCopiesForSell,
    uint256 _nftRemainingCopiesAfterSell,
    address _nftMintContractAddress,
    address _nftSellerAddress,
    address _nftBuyerAddress,
    uint256 _nftSellTimeStamp
  ) external {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    nftDetailsFromSellId[_sellId] = marketplaceNftDetails(
      _nftId,
      _sellId,
      _nftPrice,
      _nftTotalCopiesForSell,
      _nftRemainingCopiesAfterSell,
      _nftMintContractAddress,
      payable(_nftSellerAddress),
      payable(_nftBuyerAddress),
      _nftSellTimeStamp
    );
  }

  function fetchMarketplaceNftDetails(uint256 _sellId)
    public
    view
    returns (marketplaceNftDetails memory)
  {
    //require(msg.sender == nftMintContractAddress || msg.sender == nftMarketplaceContractAddress || msg.sender == nftAuctionContractAddress, "You Dont Have Access Permission");
    return nftDetailsFromSellId[_sellId];
  }

  function fetchSellId() public view returns (uint256) {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    //return sellId.current();
    return sellId;
  }

  function incrementSellId() public {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    sellId += 1;
    //sellId.increment();
  }

  //  function incrementitemsSold() public {
  //   require(msg.sender == nftMintContractAddress || msg.sender == nftMarketplaceContractAddress || msg.sender == nftAuctionContractAddress, "You Dont Have Access Permission");
  //   itemsSold.increment();
  // }
  function updateMarketplaceNftDetails(uint256 _sellId, uint256 _copies) public {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    nftDetailsFromSellId[_sellId].nftRemainingCopiesAfterSell = _copies;
  }

  /**
   * @dev Struct for storing user data when they buy or sell any nft on marketPlace.
   * Called when user buy any nft.
   * On every resell/trade nftRemainingCopies will be updated
   * Seller Adress is always remain same but the track of buyers can be manage by user struct for specific sellId
   */
  struct userNftDetails {
    uint256 nftId;
    uint256 sellId;
    uint256 buyId;
    uint256 nftCopiesBuy;
    uint256 nftRemainingCopiesAfterReSell;
    uint256 nftBuyPrice;
    address nftBuyerAddress;
    uint256 nftBuyTimeStamp;
  }

  //Mapping of user address to there nfts. [This mapping will returns data of specific address/user from wallet address]
  mapping(address => mapping(uint256 => userNftDetails)) private userOwnNftFromAddress;

  function setUserNftDetails(
    uint256 _nftId,
    uint256 _sellId,
    uint256 _buyId,
    uint256 _nftTotalCopiesForBuy,
    uint256 _nftRemainingCopiesAfterReSell,
    uint256 _nftBuyPrice,
    address _nftBuyerAddress,
    uint256 _nftBuyTimeStamp
  ) external {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    userOwnNftFromAddress[_nftBuyerAddress][_buyId] = userNftDetails(
      _nftId,
      _sellId,
      _buyId,
      _nftTotalCopiesForBuy,
      _nftRemainingCopiesAfterReSell,
      _nftBuyPrice,
      _nftBuyerAddress,
      _nftBuyTimeStamp
    );
  }

  function fetchUserNftDetails(address _nftBuyerAddress, uint256 _buyId)
    public
    view
    returns (userNftDetails memory)
  {
    //require(msg.sender == nftMintContractAddress || msg.sender == nftMarketplaceContractAddress || msg.sender == nftAuctionContractAddress, "You Dont Have Access Permission");
    return userOwnNftFromAddress[_nftBuyerAddress][_buyId];
  }

  function updateUserNftDetails(
    address _nftBuyerAddress,
    uint256 _buyId,
    uint256 _copies
  ) public {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    userOwnNftFromAddress[_nftBuyerAddress][_buyId].nftRemainingCopiesAfterReSell = _copies;
  }

  /**
   * @dev Struct for tracking and managing nft which bought by user.
   * Counter will increment whenever a nft is bought with respect to buyer and used to store total number of nft which user own currently
   * Index store keys of the mapping
   * Seller Adress is always remain same but the track of buyers can be manage by user struct for specific sellId
   */
  struct trackUserNfts {
    uint256 counter; //Counter to check how many number of copies own by Address
    uint256[] key; // Sell Id as an key of mapping
  }

  //Mapping for managing the tracking of address to there nfts
  mapping(address => trackUserNfts) private trackOwnNfts;

  function setTrackUserNftsCounter(address _nftBuyerAddress, uint256 _counter) external {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    trackOwnNfts[_nftBuyerAddress].counter = _counter;
  }

  function setTrackUserNftsKey(address _nftBuyerAddress, uint256 _key) external {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    trackOwnNfts[_nftBuyerAddress].key.push(_key);
  }

  function fetchTrackUserNft(address _nftBuyerAddress) public view returns (trackUserNfts memory) {
    require(
      msg.sender == nftMintContractAddress ||
        msg.sender == nftMarketplaceContractAddress ||
        msg.sender == nftAuctionContractAddress,
      'You Dont Have Access Permission'
    );
    return trackOwnNfts[_nftBuyerAddress];
  }
}
