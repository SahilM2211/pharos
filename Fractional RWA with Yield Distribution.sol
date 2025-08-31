// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Using direct GitHub URLs for OpenZeppelin imports to ensure compatibility with all IDEs.
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/access/Ownable.sol";

/**
 * @title FractionalRWA
 * @dev A smart contract for a fractionalized Real-World Asset that distributes
 * yield to token holders. The contract itself is an ERC20 token representing shares.
 */
contract FractionalRWA is ERC20, Ownable {

    // --- State Variables ---

    // Struct to hold details about the underlying physical asset.
    struct AssetDetails {
        string assetName;           // e.g., "Main Street Office Building"
        string propertyAddress;     // Physical location
        uint256 totalAppraisalValue; // Total value of the asset in USD
    }

    AssetDetails public assetDetails;

    // --- Revenue Distribution ---
    // This mechanism allows for a secure "pull" payment system.

    uint256 public totalRevenueDeposited;
    uint256 public totalRevenueReleased;
    mapping(address => uint256) private _revenueWithdrawnByShareholder;

    // --- Events ---

    event RevenueDeposited(address indexed depositor, uint256 amount);
    event RevenueWithdrawn(address indexed shareholder, uint256 amount);
    event AppraisalUpdated(uint256 newAppraisalValue);

    // --- Constructor ---

    /**
     * @dev Initializes the contract, minting all shares to the asset manager (deployer).
     * @param _assetName The descriptive name of the RWA.
     * @param _propertyAddress The physical address of the asset.
     * @param _initialAppraisalValue The starting appraisal value in USD.
     * @param _totalShares The total number of fractional shares to create.
     * @param _tokenName The name for the ERC20 share token (e.g., "Main Street Building Shares").
     * @param _tokenSymbol The symbol for the ERC20 share token (e.g., "MSBS").
     */
    constructor(
        string memory _assetName,
        string memory _propertyAddress,
        uint256 _initialAppraisalValue,
        uint256 _totalShares,
        string memory _tokenName,
        string memory _tokenSymbol
    ) ERC20(_tokenName, _tokenSymbol) Ownable(msg.sender) {
        
        require(_totalShares > 0, "Total shares must be greater than zero");

        assetDetails = AssetDetails({
            assetName: _assetName,
            propertyAddress: _propertyAddress,
            totalAppraisalValue: _initialAppraisalValue
        });

        // Mint all fractional shares to the contract deployer, who acts as the asset manager.
        _mint(msg.sender, _totalShares);
    }

    // --- Core Functions ---

    /**
     * @dev The asset manager deposits revenue (e.g., rental income) into the contract.
     * This function must be called with ETH attached to the transaction.
     */
    function depositRevenue() public payable onlyOwner {
        require(msg.value > 0, "Deposit amount must be greater than zero");
        totalRevenueDeposited += msg.value;
        totalRevenueReleased += msg.value;
        emit RevenueDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Allows a shareholder to withdraw their proportional share of the collected revenue.
     */
    function withdrawRevenue() public {
        uint256 userBalance = balanceOf(msg.sender);
        require(userBalance > 0, "You must be a shareholder to withdraw revenue");

        uint256 totalShares = totalSupply();
        uint256 totalReleased = totalRevenueReleased;

        // Calculate the total revenue this shareholder is entitled to.
        uint256 entitlement = (totalReleased * userBalance) / totalShares;
        
        // Find out how much they are owed now by subtracting what they've already withdrawn.
        uint256 amountToWithdraw = entitlement - _revenueWithdrawnByShareholder[msg.sender];

        require(amountToWithdraw > 0, "No revenue available for withdrawal");

        // Update their withdrawn amount *before* sending ETH to prevent re-entrancy attacks.
        _revenueWithdrawnByShareholder[msg.sender] += amountToWithdraw;

        // Transfer the ETH.
        (bool success, ) = msg.sender.call{value: amountToWithdraw}("");
        require(success, "ETH transfer failed");

        emit RevenueWithdrawn(msg.sender, amountToWithdraw);
    }

    /**
     * @dev Allows the asset manager to update the on-chain appraisal value.
     * @param _newAppraisalValue The new total value of the asset.
     */
    function updateAppraisalValue(uint256 _newAppraisalValue) public onlyOwner {
        assetDetails.totalAppraisalValue = _newAppraisalValue;
        emit AppraisalUpdated(_newAppraisalValue);
    }

    /**
     * @dev A view function to check how much revenue a specific shareholder can withdraw.
     * @param _shareholder The address of the shareholder.
     * @return The amount of ETH the shareholder can currently withdraw.
     */
    function getWithdrawableRevenue(address _shareholder) public view returns (uint256) {
        uint256 userBalance = balanceOf(_shareholder);
        if (userBalance == 0) {
            return 0;
        }
        
        uint256 totalShares = totalSupply();
        uint256 totalReleased = totalRevenueReleased;

        uint256 entitlement = (totalReleased * userBalance) / totalShares;
        return entitlement - _revenueWithdrawnByShareholder[_shareholder];
    }
}
