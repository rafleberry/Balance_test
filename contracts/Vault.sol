// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./utils/TransferHelper.sol";

import "hardhat/console.sol";

contract Vault is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    // Deposit Asset
    ERC20 public asset;

    // One time Max Deposit
    uint256 public maxDeposit;

    // One time Max Withdraw
    uint256 public maxWithdraw;

    // Vault Pause Flag
    bool public paused;

    // Depositors Address array
    address[] public depositors;

    // Depositor Status Mapping
    mapping(address => bool) public isDepositor;

    event Deposit(
        address indexed asset,
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event Withdraw(
        address indexed asset,
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event SetMaxDeposit(uint256 maxDeposit);

    event SetMaxWithdraw(uint256 maxWithdraw);

    modifier unPaused() {
        require(!paused, "PAUSED");
        _;
    }

    constructor(ERC20 _asset) ERC20("CMDEV Vault", "CMV") {
        asset = _asset;
        maxDeposit = type(uint256).max;
        maxWithdraw = type(uint256).max;
    }

    function deposit(uint256 assets, address receiver)
        public
        virtual
        nonReentrant
        unPaused
        returns (uint256 shares)
    {
        require(assets != 0, "ZERO_ASSETS");
        require(assets <= maxDeposit, "EXCEED_ONE_TIME_MAX_DEPOSIT");

        require(
            IERC20(asset).allowance(msg.sender, address(this)) >= assets,
            "INSUFFICIENT_ALLOWANCE"
        );

        // Transfer and get transfered amount
        uint256 prevBal = IERC20(asset).balanceOf(address(this));
        TransferHelper.safeTransferFrom(
            address(asset),
            msg.sender,
            address(this),
            assets
        );
        uint256 newBal = IERC20(asset).balanceOf(address(this));
        uint256 transferAmt = newBal - prevBal;

        // Total Assets amount until now
        uint256 total = IERC20(asset).balanceOf(address(this)) - transferAmt;

        // Calculate share amount to be mint
        shares = totalSupply() == 0 || total == 0
            ? transferAmt
            : (totalSupply() * transferAmt) / total;

        // Mint ENF token to receiver
        _mint(receiver, shares);

        if (!isDepositor[receiver]) {
            depositors.push(receiver);
        }

        emit Deposit(address(asset), msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver)
        public
        virtual
        nonReentrant
        unPaused
        returns (uint256 shares)
    {
        require(assets != 0, "ZERO_ASSETS");
        require(assets <= maxWithdraw, "EXCEED_ONE_TIME_MAX_WITHDRAW");

        // Total Assets amount until now
        uint256 totalDeposit = convertToAssets(balanceOf(msg.sender));

        require(assets <= totalDeposit, "EXCEED_TOTAL_DEPOSIT");

        // Calculate share amount to be burnt
        shares = (totalSupply() * assets) / totalAssets();

        // Shares could exceed balance of caller
        if (balanceOf(msg.sender) < shares) shares = balanceOf(msg.sender);

        _burn(msg.sender, shares);

        TransferHelper.safeTransfer(address(asset), receiver, assets);

        // If msg sender has no asset left, remove him from depositor list
        if (convertToAssets(balanceOf(msg.sender)) == 0) {
            isDepositor[msg.sender] = false;

            for (uint256 i = 0; i < depositors.length; i++) {
                if (depositors[i] == msg.sender) {
                    depositors[i] = depositors[depositors.length - 1];
                    depositors.pop();
                    break;
                }
            }
        }

        emit Withdraw(address(asset), msg.sender, receiver, assets, shares);
    }

    function getTopTwo() public view returns (address, address) {
        address[] memory deps = depositors;
        quickSort(deps, int256(0), int256(deps.length - 1));

        if (deps.length >= 2) {
            return (deps[deps.length - 1], deps[deps.length - 2]);
        } else if (deps.length == 1) {
            return (deps[0], address(0));
        } else {
            return (address(0), address(0));
        }
    }

    function totalDepositors() public view returns (uint256) {
        return depositors.length;
    }

    function quickSort(
        address[] memory arr,
        int256 left,
        int256 right
    ) internal view {
        int256 i = left;
        int256 j = right;
        if (i == j) return;
        uint256 pivot = balanceOf(arr[uint256(left + (right - left) / 2)]);
        while (i <= j) {
            while (balanceOf(arr[uint256(i)]) < pivot) i++;
            while (pivot < balanceOf(arr[uint256(j)])) j--;
            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (
                    arr[uint256(j)],
                    arr[uint256(i)]
                );
                i++;
                j--;
            }
        }
        if (left < j) quickSort(arr, left, j);
        if (i < right) quickSort(arr, i, right);
    }

    function totalAssets() public view virtual returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    function convertToShares(uint256 assets)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 supply = totalSupply();

        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    ///////////////////////////////////////////////////////////////
    //                 SET CONFIGURE LOGIC                       //
    ///////////////////////////////////////////////////////////////

    function setMaxDeposit(uint256 _maxDeposit) public onlyOwner {
        require(_maxDeposit > 0, "INVALID_MAX_DEPOSIT");
        maxDeposit = _maxDeposit;

        emit SetMaxDeposit(maxDeposit);
    }

    function setMaxWithdraw(uint256 _maxWithdraw) public onlyOwner {
        require(_maxWithdraw > 0, "INVALID_MAX_WITHDRAW");
        maxWithdraw = _maxWithdraw;

        emit SetMaxWithdraw(maxWithdraw);
    }

    ////////////////////////////////////////////////////////////////////
    //                      PAUSE/RESUME                              //
    ////////////////////////////////////////////////////////////////////

    function pause() public onlyOwner {
        require(!paused, "CURRENTLY_PAUSED");
        paused = true;
    }

    function resume() public onlyOwner {
        require(paused, "CURRENTLY_RUNNING");
        paused = false;
    }
}
