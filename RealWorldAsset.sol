// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Imports are correct and remain the same.
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/access/Ownable.sol";

/**
 * @title RWAController
 * @dev A robust and feature-rich smart contract for managing the lifecycle
 * of tokenized Real-World Assets (RWA).
 */
// FIX: Simplified the inheritance. ERC721URIStorage already includes ERC721.
contract RWAController is ERC721URIStorage, Ownable {

    // --- State Variables ---

    uint256 private _nextTokenId;
    address private _verifier;

    enum AssetStatus { Pending, Active, Frozen }

    struct Asset {
        string propertyAddress;
        uint256 appraisalValue;
        string legalDocsHash;
        AssetStatus status;
        uint256 lastUpdated;
    }

    mapping(uint256 => Asset) public assets;

    // --- Events ---

    event AssetRegistered(uint256 indexed tokenId, address indexed owner, string propertyAddress);
    event AssetVerified(uint256 indexed tokenId);
    event AssetFrozen(uint256 indexed tokenId);
    event AppraisalUpdated(uint256 indexed tokenId, uint256 newAppraisalValue);

    // --- Modifiers ---

    modifier onlyVerifier() {
        require(msg.sender == _verifier, "Caller is not the verifier");
        _;
    }

    // --- Constructor ---

    constructor(address initialVerifier)
        ERC721("Pharos RWA Token", "PRWAT")
        Ownable(msg.sender)
    {
        require(initialVerifier != address(0), "Verifier address cannot be zero");
        _verifier = initialVerifier;
    }

    // --- Core RWA Functions ---

    function registerAsset(
        address _owner,
        string memory _tokenURI,
        string memory _propertyAddress,
        uint256 _appraisalValue,
        string memory _legalDocsHash
    ) public onlyOwner returns (uint256) {
        require(_owner != address(0), "Owner address cannot be zero");
        
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        assets[tokenId] = Asset({
            propertyAddress: _propertyAddress,
            appraisalValue: _appraisalValue,
            legalDocsHash: _legalDocsHash,
            status: AssetStatus.Pending,
            lastUpdated: block.timestamp
        });

        _safeMint(_owner, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        emit AssetRegistered(tokenId, _owner, _propertyAddress);
        return tokenId;
    }

    function verifyAsset(uint256 _tokenId) public onlyVerifier {
        require(ownerOf(_tokenId) != address(0), "Token does not exist");
        
        Asset storage asset = assets[_tokenId];
        require(asset.status == AssetStatus.Pending, "Asset is not pending verification");

        asset.status = AssetStatus.Active;
        asset.lastUpdated = block.timestamp;

        emit AssetVerified(_tokenId);
    }

    function freezeAsset(uint256 _tokenId) public onlyOwner {
        require(ownerOf(_tokenId) != address(0), "Token does not exist");

        Asset storage asset = assets[_tokenId];
        require(asset.status == AssetStatus.Active, "Asset is not active");

        asset.status = AssetStatus.Frozen;
        asset.lastUpdated = block.timestamp;

        emit AssetFrozen(_tokenId);
    }

    function updateAppraisalValue(uint256 _tokenId, uint256 _newAppraisalValue) public onlyOwner {
        require(ownerOf(_tokenId) != address(0), "Token does not exist");
        
        assets[_tokenId].appraisalValue = _newAppraisalValue;
        
        emit AppraisalUpdated(_tokenId, _newAppraisalValue);
    }

    function setVerifier(address newVerifier) public onlyOwner {
        require(newVerifier != address(0), "Verifier address cannot be zero");
        _verifier = newVerifier;
    }

    // --- Overrides ---

    // FIX: Removed all unnecessary override functions (_burn, tokenURI, supportsInterface).
    // The correct functionality is inherited automatically from the OpenZeppelin contracts.
    // This resolves all three of the TypeErrors you were seeing.

}
