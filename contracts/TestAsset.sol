// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestAsset is ERC20, Ownable {
    constructor() ERC20("CMDEV Vault Asset", "CVA") {
        _mint(msg.sender, 10000 * 1e18);
    }
}
