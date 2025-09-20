// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Using direct GitHub URLs for OpenZeppelin imports to ensure compatibility with all IDEs.
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/access/Ownable.sol";

/**
 * @title RegulatedRWA
 * @dev An ERC721 contract for a Real-World Asset with built-in transfer restrictions.
 * Only addresses on a verified allowlist can hold or receive this asset token.
 * This is crucial for assets that must adhere to KYC/AML regulations.
 */
contract RegulatedRWA is ERC721, Ownable {

    // --- State Variables ---

    // The address responsible for managing the identity allowlist (e.g., a compliance department).
    address public identityManager;

    // The on-chain allowlist. Maps an address to its verification status.
    mapping(address => bool) public isVerified;

    // Struct to hold essential on-chain data about the physical asset.
    struct AssetDetails {
        string assetDescription;    // e.g., "Fine Art - 'The Starry Night'"
        string legalEntity;         // The legal owner or SPV
        uint256 appraisalValue;     // Value in USD
        string assetDocsHash;       // IPFS hash of legal/title documents
    }

    // Since this contract represents a single unique asset, we store its details directly.
    AssetDetails public assetDetails;
    
    // --- Events ---

    event IdentityVerified(address indexed user);
    event IdentityRevoked(address indexed user);
    event IdentityManagerUpdated(address indexed newManager);
    event AssetDetailsUpdated(string newDescription, uint256 newAppraisalValue);

    // --- Modifiers ---

    modifier onlyIdentityManager() {
        require(msg.sender == identityManager, "Caller is not the Identity Manager");
        _;
    }

    // --- Constructor ---

    /**
     * @dev Sets up the contract, defining the asset and its compliance manager.
     * @param _assetDescription A short description of the RWA.
     * @param _initialAppraisal The starting appraisal value.
     * @param _initialIdentityManager The address for the compliance role.
     */
    constructor(
        string memory _assetDescription,
        uint256 _initialAppraisal,
        address _initialIdentityManager
    ) ERC721("Regulated Asset Token", "RAT") Ownable(msg.sender) {
        require(_initialIdentityManager != address(0), "Identity manager cannot be the zero address");
        identityManager = _initialIdentityManager;

        assetDetails = AssetDetails({
            assetDescription: _assetDescription,
            legalEntity: "To be set", // Can be updated later
            appraisalValue: _initialAppraisal,
            assetDocsHash: "" // Can be updated later
        });

        // The contract itself represents one unique RWA, so we mint token ID 0 to the owner.
        // First, the owner must be verified.
        isVerified[msg.sender] = true;
        emit IdentityVerified(msg.sender);
        
        _mint(msg.sender, 0);
    }

    // --- Identity Management Functions (for the Compliance Role) ---

    /**
     * @dev Adds a new address to the verified allowlist.
     * Can only be called by the Identity Manager.
     */
    function addVerifiedIdentity(address _user) public onlyIdentityManager {
        require(_user != address(0), "User cannot be the zero address");
        require(!isVerified[_user], "User is already verified");
        isVerified[_user] = true;
        emit IdentityVerified(_user);
    }

    /**
     * @dev Removes an address from the verified allowlist.
     * Can only be called by the Identity Manager.
     */
    function revokeVerifiedIdentity(address _user) public onlyIdentityManager {
        require(isVerified[_user], "User is not verified");
        isVerified[_user] = false;
        emit IdentityRevoked(_user);
    }

    // --- Administrative Functions (for the Asset Owner) ---

    /**
     * @dev Allows the contract owner to appoint a new Identity Manager.
     */
    function setIdentityManager(address _newManager) public onlyOwner {
        require(_newManager != address(0), "New manager cannot be the zero address");
        identityManager = _newManager;
        emit IdentityManagerUpdated(_newManager);
    }

    /**
     * @dev Allows the contract owner to update asset details on-chain.
     */
    function updateAssetDetails(string memory _newDescription, uint256 _newAppraisal) public onlyOwner {
        assetDetails.assetDescription = _newDescription;
        assetDetails.appraisalValue = _newAppraisal;
        emit AssetDetailsUpdated(_newDescription, _newAppraisal);
    }

    // --- Overridden Transfer Hook (The Core Compliance Logic) ---

    /**
     * @dev This is an internal function hook that is called by all ERC721 transfer functions.
     * We override it to add our compliance check.
     * The `to` address MUST be on the verified allowlist for any transfer to succeed.
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address)
    {
        // For a transfer to happen (not minting or burning), the from address must not be zero.
        if (_ownerOf(tokenId) != address(0)) {
             require(isVerified[to], "Recipient address is not on the verified allowlist");
        }
       
        return super._update(to, tokenId, auth);
    }
}