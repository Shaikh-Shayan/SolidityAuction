// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title NFT1155
 * @dev Implements minting process with ERC1155 standard along with minting fees.
 */
import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './PersistentStorage.sol';

contract NFT1155 is ERC1155, ReentrancyGuard, Ownable {
  address private contractAddress; // Variable for storing market place contract aaddress
  address payable private coinscouterOwner; // Variable for storing coinscouterOwner wallet adress where mint fees is transfered
  uint256 private fixMintingFees = 5000000000000000; //Fixed amount minting fees
  uint256 private perCopyMintingFees = 1000000000000000; //Per copy minting fees

  address private storageAddress;
  PersistentStorage _persistentStorage;
  // function setStorage(address _storageAddress)public onlyOwner
  // {
  //   storageAddress = address(_storageAddress);
  //   _persistentStorage = PersistentStorage(storageAddress);
  // }

  //Logs the event whenever a new nft is minted.
  event mintedNftDetail(uint256 nftId, address nftArtist, string nftMetadataUri);

  //constructor with marketplace address as an argument. For approving marketplace as an operator for nft minter.
  constructor(address _marketplaceAddress, address _storageAddress)
    ERC1155('https://gateway.pinata.cloud/ipfs/{ID}')
  {
    contractAddress = _marketplaceAddress; //Initializing the marketplace contract address
    coinscouterOwner = payable(msg.sender); //Initializing the coinscouter owners address
    storageAddress = address(_storageAddress);
    _persistentStorage = PersistentStorage(storageAddress);
    //   for(uint256 i =0;i<10000;i++)
    //   {
    //         tokenIds.increment();
    //   }
  }

  //Function to perform minting it will take two arguments number of copies to mint and the metadataUrl
  function mintNft(uint256 _copies, string memory _JsonURI)
    public
    payable
    nonReentrant
    returns (uint256)
  {
    uint256 _perCopyMintingFees = (perCopyMintingFees * _copies); //Calculating fees as per the copies input.
    uint256 totalFees = (_perCopyMintingFees + fixMintingFees); // Calculating total fees, addition of fixed fees and per copy fees
    require(msg.value == totalFees, 'Please submit the actual minting fees'); //Validation for input fees, not less than or greater than asking fees
    _persistentStorage.incrementNftId(); //Generating new id.
    uint256 newItemid = _persistentStorage.fetchNftId(); //Assigning the new id to this nft
    _mint(msg.sender, newItemid, _copies, ''); //Calling mint function with respective inputs
    _setURI(_JsonURI); //Set uri to change the metadata uri
    setApprovalForAll(contractAddress, true); //Approving marketplace as an operator for this minter.
    payable(coinscouterOwner).transfer(totalFees); //Transfering the fees to owners
    _persistentStorage.setNftMintDetails(
      newItemid,
      _copies,
      _copies,
      msg.sender,
      address(this),
      _JsonURI,
      block.timestamp
    ); //Setting the mintedNftDetails struct with given details
    emit mintedNftDetail(newItemid, msg.sender, _JsonURI); //Calling mintedNftDetail event to add log
    return newItemid; //Returning Id.
  }

  //Function to fetch all the nft ids which the user[caller of this function] is minted
  //This functions only returns the nft ids for detail of that nft need to call storage function
  function fetchMintednft() public view returns (uint256[] memory) {
    uint256 totalItemCount = _persistentStorage.fetchNftId(); //Getting current value of tokenId to track total number of nfts minted
    uint256 itemCount = 0;
    uint256 currentIndex = 0;

    //Loop to find out size of array for data
    for (uint256 i = 10000; i < totalItemCount; i++) {
      if (_persistentStorage.fetchNftMintDetail(i + 1).nftArtist == msg.sender) {
        itemCount += 1;
      }
    }

    //Creating array to store filter data of itemCount size
    uint256[] memory _nftId = new uint256[](itemCount);

    //Loop to store the filter data into the array.
    for (uint256 i = 10000; i < totalItemCount; i++) {
      if (_persistentStorage.fetchNftMintDetail(i + 1).nftArtist == msg.sender) {
        uint256 currentId = i + 1;
        uint256 currentNftId = _persistentStorage.fetchNftMintDetail(currentId).nftId;
        _nftId[currentIndex] = currentNftId;
        currentIndex += 1;
      }
    }
    return _nftId; //Returning filter array of nft Ids which mint by specific user
  }

  //  function fetchMintednft2() public view returns (PersistentStorage.nftMintDetails[] memory) {
  //     uint256 totalItemCount = _persistentStorage.fetchNftId(); //Getting current value of tokenId to track total number of nfts minted
  //     uint256 itemCount = 0;
  //     uint256 currentIndex = 0;

  //     //Loop to find out size of array for data
  //     for (uint256 i = 0; i < totalItemCount; i++) {
  //       if (_persistentStorage.fetchNftMintDetail(i + 1).nftArtist == msg.sender) {
  //         itemCount += 1;
  //       }
  //     }

  //     //Creating array to store filter data of itemCount size
  //     uint256[] memory _nftId = new uint256[](itemCount);
  //     PersistentStorage.nftMintDetails[] memory _nftDetails = new PersistentStorage.nftMintDetails[](itemCount);
  //     //Loop to store the filter data into the array.
  //     for (uint256 i = 0; i < totalItemCount; i++) {
  //       if (_persistentStorage.fetchNftMintDetail(i + 1).nftArtist == msg.sender) {
  //         uint256 currentId = i + 1;
  //         uint256 currentNftId = _persistentStorage.fetchNftMintDetail(currentId).nftId;
  //         PersistentStorage.nftMintDetails memory currentNft =  _persistentStorage.fetchNftMintDetail(currentId);
  //         _nftId[currentIndex] = currentNftId;
  //         _nftDetails[currentIndex] = currentNft;
  //         currentIndex += 1;
  //       }
  //     }
  //     return _nftDetails; //Returning filter array of nft Ids which mint by specific user
  //   }

  //Fetch the nft Artist of specific token id
  function fetchNftArtist(uint256 _nftId) public view returns (address) {
    return _persistentStorage.fetchNftMintDetail(_nftId).nftArtist;
  }

  // //Fetch the nft remainingCopy of specific token id
  function fetchRemainingCopies(uint256 _nftId) public view returns (uint256) {
    return _persistentStorage.fetchNftMintDetail(_nftId).nftRemainingCopies;
  }

  //Fetch the total fees need to mint the nft
  function fetchTotalFee(uint256 _copies) public view returns (uint256) {
    uint256 _perCopyMintingFees = (perCopyMintingFees * _copies);
    uint256 _totalFees = (_perCopyMintingFees + fixMintingFees);
    return _totalFees;
  }

  //Function to update fixed minting fees.
  function updateFixedMintFee(uint256 _mintingfees) public onlyOwner {
    fixMintingFees = _mintingfees;
  }

  //Function to update percopy minting fees.
  function updatePercopyMintFee(uint256 _perCopyMintingFees) public onlyOwner {
    perCopyMintingFees = _perCopyMintingFees;
  }
}
