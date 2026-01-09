// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

interface IIndix {
    function initialize(uint256, address, uint256) external;
    function pause() external;
    function unpause() external;
    function purchaseSkin(uint256, address) external payable;
    function skins(uint256, address) external view returns (uint256, uint256, string memory, uint256);
}